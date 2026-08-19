# frozen_string_literal: true

module Lich
  module Genie
    # Runs a matched trigger's action string (Genie FormMain.TriggerAction). A trigger
    # body is `;`-separated commands executed in the global scope (no script locals),
    # where -- unlike a script line -- a leading `#` is a bar command and a leading `.`
    # launches a script. Regex captures are available as `$1..$n`.
    #
    # Reuses the same {CommandRouter} + {Substitution} as the interpreter, so trigger
    # actions behave exactly like the equivalent `put #...` lines. Collaborators are
    # injected so this runs headless in specs.
    class TriggerRunner
      # @param vars [Variables] global-scoped store (shared with scripts)
      # @param eval [Eval] expression evaluator for #eval/#if
      # @param game [#send_command] game sink
      # @param launch [#call] callable(name, args) to start a script
      # @param hooks [#emit, nil] front-end effect sink
      # @param echo [#call] local echo sink
      def initialize(vars:, eval:, game:, launch:, hooks: nil, echo: nil)
        @game = game
        @launch = launch
        @echo = echo || ->(_text) {}
        @substitution = Substitution.new(variables: vars)
        @router = CommandRouter.new(
          vars: vars, eval: eval, hooks: hooks,
          echo: @echo, send: ->(text) { send_text(text) }
        )
      end

      # Execute +commands+ with the given regex +captures+ ($1..$n).
      # @param commands [String]
      # @param captures [Array<String>]
      # @return [void]
      def fire(commands, captures)
        args = [''] + Array(captures).map(&:to_s) # $0 unused; $1 => captures[0]
        Text.safe_split(commands, ';').each do |piece|
          dispatch(@substitution.expand(piece, args: args))
        end
      end

      private

      def dispatch(text)
        stripped = text.to_s.strip
        return if stripped.empty?

        stripped.start_with?('#') ? @router.route(stripped) : send_text(stripped)
      end

      # A trigger's non-`#` command: a leading `.` launches a script (Genie ScriptChar),
      # anything else goes to the game.
      def send_text(text)
        stripped = text.to_s.lstrip
        return if stripped.empty?

        if stripped.start_with?('.')
          body = stripped[1..].to_s
          name = Text.keyword_string(body)
          @launch.call(name, Text.argument_string(body)) unless name.empty?
        else
          @game&.send_command(text)
        end
      end
    end
  end
end
