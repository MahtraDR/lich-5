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
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        )
        interpreter.run
      end

      private

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
      def send_command(text)
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

    # Emits a front-end effect as a <genieHook> tag on the client stream. Front-ends
    # that do not implement the protocol safely ignore the unknown tag.
    class LichHookSink
      def emit(op, payload)
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
        'stance' => -> { XMLData.stance_text }, 'preparedspell' => -> { XMLData.prepared_spell },
        'roundtime' => -> { [XMLData.roundtime_end.to_i - Time.now.to_i, 0].max },
        'casttime' => -> { [XMLData.cast_roundtime_end.to_i - Time.now.to_i, 0].max },
        'casttimeremaining' => -> { [XMLData.cast_roundtime_end.to_i - Time.now.to_i, 0].max },
        'gametime' => -> { XMLData.server_time },
        # hands
        'lefthand' => -> { GameObj.left_hand&.name || 'Empty' },
        'lefthandnoun' => -> { GameObj.left_hand&.noun.to_s },
        'righthand' => -> { GameObj.right_hand&.name || 'Empty' },
        'righthandnoun' => -> { GameObj.right_hand&.noun.to_s },
        # room
        'roomname' => -> { s = XMLData.room_name.to_s; s.empty? ? XMLData.room_title : s },
        'roomtitle' => -> { XMLData.room_title }, 'roomdesc' => -> { XMLData.room_description },
        'roomexits' => -> { XMLData.room_exits_string }, 'gameroomid' => -> { XMLData.room_id },
        'roomobjs' => -> { Array(GameObj.loot).map(&:name).join('|') },
        'roomplayers' => -> { Array(GameObj.pcs).map(&:name).join('|') },
        'roomnote' => -> { '' }, 'inside' => -> { XMLData.room_inside ? 1 : 0 },
        # creatures
        'monstercount' => -> { Array(GameObj.npcs).length },
        'monsterlist' => -> { Array(GameObj.npcs).map(&:name).join('|') },
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

      def key?(name)
        key = name.to_s.downcase
        RESOLVERS.key?(key) || !Reserved.indicator_id(key).nil? || Reserved.spell_timer?(name)
      end

      def [](name)
        key = name.to_s.downcase
        if (resolver = RESOLVERS[key])
          resolver.call.to_s
        elsif (icon = Reserved.indicator_id(key))
          XMLData.indicator[icon] == 'y' ? '1' : '0'
        elsif Reserved.spell_timer?(name)
          Reserved.spell_timer(active_spells, name).to_s
        end
      rescue StandardError
        nil
      end

      private

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
