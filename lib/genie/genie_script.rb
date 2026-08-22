# frozen_string_literal: true

require 'json'
require 'zlib'

module Lich
  module Genie
    # Lich integration glue. `GenieScript` is a `Lich::Common::Script` subclass so
    # it inherits Lich's full script lifecycle (registry, pause/kill, buffers,
    # `;list`), but instead of eval'ing Ruby labels its thread body runs the Genie
    # {Interpreter} wired to Lich via the port adapters below.
    #
    # This file requires a running Lich (it references Game/XMLData/$_CLIENT_/put/
    # respond) and must load AFTER lib/common/script.rb. The headless engine in
    # lib/genie/*.rb has no such dependency.
    #
    # NOTE: prototype. `;pause` is enforced only at put/gets boundaries; the reserved
    # game-state variable map (LichGameState) covers common names and will be aligned
    # with Genie's full SetDefaultGlobalVars list. Pacing will move to the command
    # broker (design doc Decision 5).
    class GenieScript < Lich::Common::Script
      # rubocop:disable Lint/MissingSuper
      def initialize(file_name, cli_vars = [], _publish = true)
        @name = /.*[\/\\]+([^.]+)\./.match(file_name).captures.first
        @file_name = file_name
        @vars = []
        @killer_mutex = Mutex.new
        unless cli_vars.empty?
          cli_vars = cli_vars.split(' ') if cli_vars.is_a?(String)
          cli_vars.each_index { |idx| @vars[idx + 1] = cli_vars[idx] }
          @vars[0] = @vars[1..].join(' ')
        end
        if @vars.first =~ /^quiet$/i
          @quiet = true
          @vars.shift
        else
          @quiet = false
        end
        @downstream_buffer = LimitedArray.new
        @downstream_buffer.max_size = 400
        @want_downstream = true
        @want_downstream_xml = false
        @upstream_buffer = LimitedArray.new
        @want_upstream = false
        @unique_buffer = LimitedArray.new
        @at_exit_procs = []
        @patchfor = {}
        @die_with = []
        @paused = false
        @hidden = false
        @no_pause_all = false
        @no_kill_all = false
        @silent = false
        @safe = false
        @no_echo = false
        @match_stack_labels = []
        @match_stack_strings = []
        @label_order = ['~start']
        @labels = { '~start' => '' }
        @current_label = '~start'
        @thread_group = ThreadGroup.new
        @genie_source = read_source(file_name)
      end
      # rubocop:enable Lint/MissingSuper

      # Thread body: run the Genie interpreter wired to Lich.
      # @return [void]
      def run_genie
        GenieScript.ensure_downstream_hook! # gag/sub + trigger firing on the game stream
        # Shared, per-character global store backed by GenieProfiles/Config/variables.cfg,
        # so #var/#svar persist and are visible across concurrent Genie scripts + characters.
        variables = Variables.new(game_state: LichGameState.new, global_store: Lich::Genie.global_store)
        variables.local_set('scriptname', @name)

        interpreter = Engine.build(
          @genie_source,
          name: @name,
          variables: variables,
          args: @vars,
          ignore_warnings: true,
          include_loader: method(:load_include),
          game: LichGamePort.new,
          input: LichInputPort.new(self),
          echo: ->(text) { respond(text) },
          hooks: LichHookSink.new,
          launch: ->(name, args) { launch_script(name, args) },
          mover: ->(room) { genie_goto(room) },
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        )
        interpreter.run
      end

      @downstream_installed = false

      class << self
        # Install (once) the single Lich DownstreamHook that powers Model A gag/sub
        # AND fires #triggers. Triggers run FIRST on the raw game line (so a gagged
        # line still fires triggers), then gag/sub filter the client display.
        # @return [void]
        def ensure_downstream_hook!
          return if @downstream_installed

          @downstream_installed = true
          # One-time-per-session banner so a tester sees the running build in their log
          # without having to ask (and can still echo Lich::Genie::VERSION on demand).
          respond "--- Genie engine v#{Lich::Genie::VERSION} active"
          # Self-install the opt-in assess exist-id shim so it survives relogin under
          # the in-Lich engine (native-Genie users install it from autostart instead).
          Lich::Genie::AssessIds.install! if Lich::Genie::AssessIds.enabled?
          runner = trigger_runner
          Lich::Common::DownstreamHook.add('genie-downstream', lambda { |server_string|
            begin
              # Triggers match the DISPLAYED main-window text (Genie strips XML before
              # matching), so build the match line with Lich's strip_xml, NOT a naive
              # tag-strip. strip_xml removes the CONTENT of GUI-only elements
              # (spell/component/right/left/prompt); a naive gsub keeps that text and
              # GLUES it onto the real line -- e.g. after a `cast`, DR sends
              # `<spell>None</spell>You gesture.`, which a tag-strip turns into
              # "NoneYou gesture." so a `^You gesture` trigger never matches (the round-4
              # "spellcast trigger doesn't fire / double cast" bug). gag/sub still operate
              # on the raw server_string below. strip_xml returns nil for blank lines.
              line = strip_xml_line(server_string).strip
              if Lich::Genie.trace_triggers && !line.empty?
                respond "--- genie rx: #{line[0, 100].inspect}"
                # Show WHICH triggers match this line and whether their class is on --
                # distinguishes "did not match" from "matched but class off" (dead-looking).
                Lich::Genie.triggers.diagnose(line).each do |m|
                  state = m['active'] ? 'ACTIVE' : "INACTIVE (class '#{m['class']}' off)"
                  respond "--- genie trigger MATCH [#{state}]: /#{m['pattern'][0, 60]}/"
                end
              end
              Lich::Genie.triggers.apply(line) do |commands, captures|
                # The ';' COUNT is a rendering-proof signal: if a front-end eats ';' in
                # echoed text, the command string itself is still intact (count > 0);
                # count 0 means the separators were genuinely stripped before storage.
                respond "--- genie trigger FIRED [#{commands.count(';')} ';']: #{commands[0, 60]}" if Lich::Genie.trace_triggers
                runner.fire(commands, captures)
              end
            rescue StandardError => e
              respond "--- Lich: genie trigger error: #{e}"
            end
            Lich::Genie.stream_filters.apply(server_string)
          }, persist: true)
        end

        # Build a trigger-match line from a raw server chunk with Lich's strip_xml.
        #
        # CRITICAL: strip_xml is a TOP-LEVEL `def` in a real Lich (global_defs.rb),
        # which Ruby makes a PRIVATE method on Object. `respond_to?(:strip_xml)` is
        # therefore FALSE (it excludes private methods) even though strip_xml is fully
        # callable here with an implicit receiver. The old `respond_to?` guard thus
        # ALWAYS took the naive-gsub fallback -- the strip_xml path was dead code, so
        # the R5 "spellcast doesn't fire / double-cast" bug was never actually fixed
        # for prepared-spell casts (their `<spell>None</spell>You gesture.` prefix
        # glued to "NoneYou gesture."; only prefix-free `wave` casts happened to work).
        # Call strip_xml directly and fall back to the naive strip ONLY when it is
        # genuinely absent (headless specs), detected via NameError. strip_xml may
        # return nil (blank line) -> coerce to "".
        # @return [String]
        def strip_xml_line(server_string)
          strip_xml(server_string).to_s
        rescue NameError
          server_string.gsub(/<[^>]+>/, '')
        end

        # Global-scoped runner that executes trigger actions (shared global store, so
        # trigger #vars persist and are visible to scripts).
        # @return [TriggerRunner]
        def trigger_runner
          @trigger_runner ||= begin
            vars = Variables.new(game_state: LichGameState.new, global_store: Lich::Genie.global_store)
            globals = Object.new
            globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
            TriggerRunner.new(
              vars: vars, eval: Eval.new(globals: globals),
              game: LichGamePort.new,
              launch: ->(name, args) { Lich::Common::Script.start(name, args) },
              hooks: LichHookSink.new, echo: ->(text) { respond(text) },
              mover: ->(room) { genie_walk(room) } # triggers walk but don't matchwait, so no ARRIVED inject
            )
          end
        end

        # Walk to a Genie room. Genie `#goto`/$roomid use the CURRENT zone's local
        # node id, stamped on Lich rooms as genie_zone/genie_id (Map.by_genie_ref).
        # Path A fallback (unstamped or no map): treat the number as a Lich room id
        # or game uid. Delegates the walk to DRCT.walk_to (go2 under the hood).
        # @return [Symbol] :arrived, :failed, or :unknown
        def genie_walk(room)
          target = resolve_genie_room(room.to_s.strip)
          return :unknown if target.nil?

          Lich::DragonRealms::DRCT.walk_to(target, false) ? :arrived : :failed
        rescue StandardError => e
          respond "--- Lich: genie #goto error: #{e}"
          :failed
        end

        # Genie node id (+ current zone) -> Lich room id; falls back to Lich id / uid.
        # @return [Integer, nil]
        def resolve_genie_room(node)
          return nil if node.empty?

          zone = Lich::Common::Map.current&.genie_zone
          room = Lich::Common::Map.by_genie_ref(zone, node) if zone
          return room.id if room
          return unless node =~ /\A\d+\z/

          id = node.to_i
          return id if Lich::Common::Map.list[id]

          Array(Lich::Common::Map.ids_from_uid(id)).first
        end
      end

      private

      # Launch another script from within a Genie script (`put .name args`). Reuses
      # Lich's launcher, so `.cmd` targets route back through the Genie engine while
      # `.lic` targets run as normal Lich scripts. Non-blocking, like Genie.
      def launch_script(name, args)
        Lich::Common::Script.start(name, args)
      rescue StandardError => e
        respond "--- Lich: genie could not launch script '#{name}': #{e}"
      end

      # `#goto <room>` from a script: walk there, then inject Genie's automapper
      # result line into THIS script's downstream so its `matchwait YOU HAVE
      # ARRIVED` / `... FAILED` resolves (the ARRIVED/FAILED shim).
      def genie_goto(room)
        arrived = GenieScript.genie_walk(room) == :arrived
        @downstream_buffer.push(arrived ? 'YOU HAVE ARRIVED' : 'YOU HAVE FAILED')
      end

      # Resolve an `include <name>` against the Lich scripts dir (and custom/),
      # trying a `.cmd` extension when none is given. Returns the file's source or nil.
      def load_include(name)
        candidates = name.include?('.') ? [name] : [name, "#{name}.cmd"]
        dirs = [SCRIPT_DIR, File.join(SCRIPT_DIR, 'custom')]
        candidates.each do |candidate|
          dirs.each do |dir|
            path = File.join(dir, candidate)
            return File.read(path) if File.exist?(path)
          end
        end
        respond "--- Lich: genie include not found: #{name}"
        nil
      end

      def read_source(file_name)
        begin
          Zlib::GzipReader.open(file_name) { |f| return f.readlines.map(&:chomp) }
        rescue StandardError
          nil
        end
        File.readlines(file_name).map(&:chomp)
      rescue StandardError => e
        respond "--- Lich: error reading script file (#{file_name}): #{e}"
        []
      end
    end

    # Sends a Genie command to the game via Lich's `put` (echo + prefix + send).
    # Pacing/broker mediation will be layered here per design Decision 5.
    class LichGamePort
      # Wait out any active roundtime before sending (Genie paces on RT, so scripts
      # don't spam a command during RT and hit the "...wait N seconds" retry loop).
      # waitrt? returns immediately when there's no RT.
      def send_command(text)
        waitrt?
        put(text)
      end
    end

    # Reads the next downstream line from the running script's buffer, honoring the
    # interpreter's deadline via Script#gets(timeout).
    class LichInputPort
      def initialize(script)
        @script = script
      end

      def next_line(timeout: nil)
        @script.gets(timeout)
      end
    end

    # Consumes the interpreter's normalized front-end effect events and dispatches
    # each to the right place:
    #   * gag/sub  -> Model A stream rewrite (Decision 6)
    #   * trigger  -> Lich-side trigger registry (automation; fires commands)
    #   * class    -> gates triggers AND emits a <genieHook> tag (front-end highlights)
    #   * others   -> a <genieHook> tag (front-ends that don't implement it ignore it)
    class LichHookSink
      MODEL_A_OPS = %w[gag ungag substitute unsub].freeze

      def emit(op, payload)
        case op
        when *MODEL_A_OPS then apply_stream_filter(op, payload)
        when 'trigger' then apply_trigger(payload)
        when 'untrigger' then Lich::Genie.triggers.remove(payload['pattern'])
        when 'class'
          Lich::Genie.triggers.set_class(payload['name'], payload['enabled'])
          emit_tag(op, payload) # front-ends still need class state for highlight gating
        else emit_tag(op, payload)
        end
      rescue StandardError
        nil
      end

      private

      def apply_trigger(payload)
        triggers = Lich::Genie.triggers
        case payload['action']
        when 'clear' then triggers.clear
        when 'list' then list_triggers(triggers)
        else triggers.add(payload['pattern'], payload['commands'], klass: payload['class'])
        end
      end

      def list_triggers(triggers)
        entries = triggers.list
        return respond('--- Lich: genie: no triggers loaded') if entries.empty?

        respond "--- Lich: genie triggers (#{entries.length}):"
        entries.each do |t|
          state = t['active'] ? 'on' : 'off'
          klass = t['class'].to_s.empty? ? '' : " [class: #{t['class']} #{state}]"
          respond "    /#{t['pattern']}/#{klass} -> #{t['commands']}"
        end
      end

      def apply_stream_filter(op, payload)
        filters = Lich::Genie.stream_filters
        case op
        when 'gag' then filters.add_gag(payload['pattern'], klass: payload['class'])
        when 'ungag' then filters.remove_gag(payload['pattern'])
        when 'substitute' then filters.add_sub(payload['pattern'], payload['replacement'], klass: payload['class'])
        when 'unsub' then filters.remove_sub(payload['pattern'])
        end
      end

      def emit_tag(op, payload)
        return unless defined?($_CLIENT_) && $_CLIENT_&.alive?

        $_CLIENT_.puts(%(<genieHook v="1" op="#{op}" data='#{JSON.generate(payload)}'/>))
      rescue StandardError
        nil
      end
    end

    # Resolves Genie's reserved/live global variables (Genie's SetDefaultGlobalVars
    # set) from Lich's live game state -- the Lich equivalent of Genie's stream
    # parser updating those vars. NOT sourced from config files (Genie never saved
    # reserved vars). User `#var` config is handled separately by the GlobalStore.
    #
    # Time-family vars resolve to their @-special literal so the substitution's
    # @-pass formats them (DRY with Specials). `$roomnote`/`$account`/`$zone*` have
    # no Lich equivalent and return Genie-like defaults.
    class LichGameState
      DIRECTIONS = %w[north northeast east southeast south southwest west northwest up down out].freeze
      TIME_SPECIALS = %w[time time24 militarytime date year month dayofmonth dayofyear
                         datetime datetime24 unixtime].freeze

      RESOLVERS = {
        # vitals
        'health' => -> { XMLData.health }, 'mana' => -> { XMLData.mana },
        'stamina' => -> { XMLData.stamina }, 'spirit' => -> { XMLData.spirit },
        'concentration' => -> { XMLData.concentration }, 'encumbrance' => -> { XMLData.encumbrance_value },
        'maxhealth' => -> { XMLData.max_health }, 'maxmana' => -> { XMLData.max_mana },
        'maxstamina' => -> { XMLData.max_stamina }, 'maxspirit' => -> { XMLData.max_spirit },
        'maxconcentration' => -> { XMLData.max_concentration },
        # character / connection
        'name' => -> { XMLData.name }, 'charactername' => -> { XMLData.name },
        'game' => -> { XMLData.game }, 'gamename' => -> { XMLData.game },
        'gamehost' => -> { 'eaccess.play.net' }, 'gameport' => -> { 7910 },
        'account' => -> { '' }, 'level' => -> { XMLData.level },
        'connected' => -> { 1 }, 'client' => -> { 'Lich' },
        'version' => -> { defined?(LICH_VERSION) ? LICH_VERSION : '' },
        # state
        'preparedspell' => -> { XMLData.prepared_spell },
        'roundtime' => -> { [XMLData.roundtime_end.to_i - Time.now.to_i, 0].max },
        'casttime' => -> { [XMLData.cast_roundtime_end.to_i - Time.now.to_i, 0].max },
        'casttimeremaining' => -> { [XMLData.cast_roundtime_end.to_i - Time.now.to_i, 0].max },
        'gametime' => -> { XMLData.server_time },
        # hands
        'lefthand' => -> { GameObj.left_hand&.name || 'Empty' },
        'lefthandnoun' => -> { GameObj.left_hand&.noun.to_s },
        'righthand' => -> { GameObj.right_hand&.name || 'Empty' },
        'righthandnoun' => -> { GameObj.right_hand&.noun.to_s },
        # room -- bridged to DRRoom (DR) / GameObj (GS), not re-derived from raw XML
        'roomname' => -> { LichGameState.clean_room_name },
        'roomtitle' => -> { XMLData.room_title }, 'roomdesc' => -> { XMLData.room_description },
        'roomexits' => -> { Array(XMLData.room_exits).join(', ') }, 'gameroomid' => -> { XMLData.room_id },
        # $roomid is Genie's automapper current-room (zone-local) node id. It is
        # stamped on Lich rooms as genie_id; return the current room's, or "0" when
        # unmapped -- which matches Genie's "mapper lost" value that scripts guard with
        # `if $roomid = 0`. Configured targets ($part.room, ...) are Genie node ids and
        # resolve via the current zone in #goto (Map.by_genie_ref).
        'roomid' => -> { Lich::Common::Map.current&.genie_id || '0' },
        'roomobjs' => -> { LichGameState.room_objects.join('|') },
        'roomplayers' => -> { LichGameState.room_players.join('|') },
        'roomnote' => -> { '' }, 'inside' => -> { XMLData.room_inside ? 1 : 0 },
        # creatures
        'monstercount' => -> { LichGameState.room_creatures.length },
        'monsterlist' => -> { LichGameState.room_creatures.join('|') },
        # misc reserved
        'prompt' => -> { XMLData.prompt }, 'zoneid' => -> { 0 }, 'zonename' => -> { 0 },
        'scriptlist' => -> { 'none' }, 'spelltime' => -> { 0 }, 'spellpreptime' => -> { 0 },
        'repeatregex' => lambda {
          '^\.\.\.wait|^Sorry\, you may only type ahead|^You are still stunned|' \
          '^You can\'t do that while|^You don\'t seem to be able'
        }
      }.merge(
        DIRECTIONS.to_h { |dir| [dir, -> { Array(XMLData.room_exits).include?(dir) ? 1 : 0 }] }
      ).merge(
        TIME_SPECIALS.to_h { |token| [token, -> { "@#{token}@" }] }
      ).freeze

      # Room contents bridged to the existing room modules: DragonRealms keeps clean
      # parsed arrays in DRRoom; GemStone uses GameObj. Never re-derived from raw XML.
      def self.dr?
        XMLData.game.to_s.start_with?('DR')
      end

      def self.room_players
        dr? ? Array(Lich::DragonRealms::DRRoom.pcs) : Array(GameObj.pcs).map(&:name)
      end

      def self.room_creatures
        dr? ? Array(Lich::DragonRealms::DRRoom.npcs) : Array(GameObj.npcs).map(&:name)
      end

      def self.room_objects
        dr? ? Array(Lich::DragonRealms::DRRoom.room_objs) : Array(GameObj.loot).map(&:name)
      end

      # Genie's $roomname is the room title without surrounding brackets. DR's
      # room_title is double-bracketed ("[[Name]]"), so strip all leading/trailing.
      def self.clean_room_name
        XMLData.room_title.to_s.gsub(/\A\[+/, '').gsub(/\]+\z/, '')
      end

      def key?(name)
        key = name.to_s.downcase
        RESOLVERS.key?(key) || !Reserved.indicator_check(key).nil? ||
          Reserved.spell_timer?(name) || (skills_available? && Reserved.skill_var?(name))
      end

      # Names this resolver owns LIVE with no external writer to refresh a stored copy:
      # the SpellTimer and EXPTracker/skill namespaces (a real Genie plugin rewrote
      # these each tick; Lich synthesizes them). For these, live state must win over a
      # value migrated into variables.cfg, or the stale copy shadows reality forever.
      # Scalar reserved vars are deliberately excluded -- scripts shadow some (e.g.
      # `#var inside 1`) and expect their #var to stick.
      def authoritative?(name)
        Reserved.spell_timer?(name) || (skills_available? && Reserved.skill_var?(name))
      end

      def [](name)
        key = name.to_s.downcase
        if (resolver = RESOLVERS[key])
          resolver.call.to_s
        elsif (check = Reserved.indicator_check(key))
          # Lich status predicates (checkbleeding, checkstanding, ...) work for DR + GS
          send(check) ? '1' : '0'
        elsif Reserved.spell_timer?(name)
          Reserved.spell_timer(active_spells, name).to_s
        elsif skills_available? && Reserved.skill_var?(name)
          # $<Skill>.LearningRate/.Ranks/.Percent -> DRSkill (Genie EXPTracker plugin)
          Reserved.skill_var(name, skills: Lich::DragonRealms::DRSkill).to_s
        end
      rescue StandardError
        nil
      end

      private

      # DRSkill (the EXPTracker equivalent) exists only in DragonRealms.
      def skills_available?
        XMLData.game.to_s.start_with?('DR') && defined?(Lich::DragonRealms::DRSkill)
      end

      # Active-spell map for SpellTimer resolution: DR uses dr_active_spells directly
      # (name => duration); GemStone derives an equivalent from Effects::Spells.
      def active_spells
        if XMLData.game.to_s.start_with?('DR')
          XMLData.dr_active_spells || {}
        else
          registry = Lich::Gemstone::Effects::Spells
          registry.to_h.each_with_object({}) do |(effect, _exp), acc|
            next unless effect.is_a?(String) && registry.active?(effect)

            acc[effect] = registry.time_left(effect).to_i
          end
        end
      end
    end
  end
end
