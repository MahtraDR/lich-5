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
        variables = Variables.new(game_state: LichGameState.new)
        variables.local_set('scriptname', @name)

        interpreter = Engine.build(
          @genie_source,
          name: @name,
          variables: variables,
          args: @vars,
          ignore_warnings: true,
          game: LichGamePort.new,
          input: LichInputPort.new(self),
          echo: ->(text) { respond(text) },
          hooks: LichHookSink.new,
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        )
        interpreter.run
      end

      private

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

    # Resolves Genie reserved global variables from Lich's XMLData. Prototype map;
    # extend to Genie's full reserved set as needed.
    class LichGameState
      RESOLVERS = {
        'health'        => -> { XMLData.health },
        'mana'          => -> { XMLData.mana },
        'stamina'       => -> { XMLData.stamina },
        'spirit'        => -> { XMLData.spirit },
        'concentration' => -> { XMLData.concentration },
        'roundtime'     => -> { XMLData.roundtime },
        'name'          => -> { XMLData.name },
        'charactername' => -> { XMLData.name },
        'game'          => -> { XMLData.game },
        'roomtitle'     => -> { XMLData.room_title },
        'roomdesc'      => -> { XMLData.room_description }
      }.freeze

      def key?(name)
        RESOLVERS.key?(name.to_s.downcase)
      end

      def [](name)
        resolver = RESOLVERS[name.to_s.downcase]
        return nil unless resolver

        resolver.call.to_s
      rescue StandardError
        nil
      end
    end
  end
end
