# frozen_string_literal: true

module Lich
  module Genie
    # Routes a Genie `#command` (bar command) issued from a script (`put #...`) or
    # nested as a value/branch of another command. Clean-room port of the relevant
    # half of Genie4 Core/Command.cs `ParseCommand`.
    #
    # Two concerns, mirroring Genie:
    #   * **engine-side** commands run in Lich: `#var`/`#tvar`/`#svar`/`#unvar`
    #     (variable store), `#echo`, `#eval`/`#evalmath`/`#math`/`#if` (computation),
    #     `#send` (to game).
    #   * **front-end** commands (`#class`, `#trigger`, `#highlight`, `#gag`, `#sub`,
    #     `#macro`, ...) emit a self-describing effect via {#emit} so a front-end can
    #     reproduce them (see docs/genie-engine/hook-protocol.md). Lich renders none.
    #
    # Faithful behaviors preserved from Command.cs:
    #   * a `#command`'s **result string** (only functions like `#evalmath`/`#eval`/
    #     `#if` produce one) is sent to the game when routed at top level, and is the
    #     substituted value when the command is used as a `#var` value (ParseAllArgs).
    #   * `#var {key} {value}` runs +value+ back through the router, so an inline
    #     `#evalmath (...)` in a value is evaluated (Command.cs:943 ParseAllArgs).
    #   * args are tokenized with Genie's {Text.parse_args} (brace/quote grouping), so
    #     `#trigger {re} {cmds} {class}` and `#class name on` split like Genie.
    class CommandRouter
      TRUTHY = %w[on true 1 yes enable enabled].freeze

      # Front-end effect ops that carry structured, self-describing payloads.
      STRUCTURED_FE_OPS = %w[class trigger gag ignore squelch ungag sub substitute unsub].freeze

      # Front-end effect ops emitted with tokenized args (+ raw) pending a finalized
      # payload schema (hook-protocol.md Phase 4). Anything here is a front-end effect.
      TOKENIZED_FE_OPS = %w[
        highlight unhighlight preset class classes window name names layout
        macro macros alias aliases playsound playwave play link img image
        beep flash gauge icon
      ].freeze

      # @param vars [Variables] local/global variable store
      # @param eval [Eval] boolean/string expression evaluator (for #eval/#if)
      # @param echo [#call] local echo sink
      # @param send [#call] game-command sink (applies pacing / loop guard)
      # @param hooks [#emit, nil] front-end effect sink
      def initialize(vars:, eval:, echo:, send:, hooks:)
        @vars = vars
        @eval = eval
        @echo = echo
        @send = send
        @hooks = hooks
      end

      # Route a top-level `#command` (leading '#'); a non-empty result is sent to the
      # game, matching Command.cs "get result from function then send result to game".
      # @param line [String] the command text, including the leading '#'
      # @return [void]
      def route(line)
        result = compute(line)
        @send.call(result) if result && !result.empty?
      end

      # Evaluate a value that may itself be a `#function` (e.g. a `#var` value of
      # `#evalmath (...)`). Non-`#` values are returned unchanged.
      # @param value [String]
      # @return [String]
      def evaluate_value(value)
        text = value.to_s
        return text unless text.lstrip.start_with?('#')

        compute(text)
      end

      private

      # Dispatch a `#command`, returning its result string ("" for side-effect-only
      # commands; the computed value for the function commands).
      def compute(line)
        body = line.to_s.strip.sub(/\A#/, '')
        args = Text.parse_args(body)
        return '' if args.empty?

        keyword = args[0].to_s.downcase
        argument = Text.argument_string(body)
        dispatch(keyword, args, argument)
      end

      def dispatch(keyword, args, argument)
        case keyword
        when 'var', 'vars', 'variable', 'setvar', 'setvariable' then set_variable(args, persist: true)
        when 'tvar', 'tempvar', 'tempvariable' then set_variable(args, persist: false)
        when 'svar', 'servervar', 'servervariable' then set_variable(args, persist: true)
        when 'unvar', 'unsetvar', 'unvariable', 'unsetvariable' then delete_variable(args)
        when 'echo' then do_echo(args, argument)
        when 'eval' then @eval.eval_string(argument)
        when 'evalmath' then eval_math(argument)
        when 'math' then do_math(args)
        when 'if' then do_if(args)
        when 'send' then (@send.call(argument) && '')
        when 'class' then (emit_class(args) && '')
        when 'trigger' then (emit_trigger(args) && '')
        when 'gag', 'ignore', 'squelch' then (emit_gag('gag', args) && '')
        when 'ungag' then (emit_gag('ungag', args) && '')
        when 'sub', 'substitute' then (emit_sub('substitute', args) && '')
        when 'unsub' then (emit_sub('unsub', args) && '')
        else emit_generic(keyword, args, argument)
        end
      end

      # --- engine-side: variables ------------------------------------------

      def set_variable(args, persist:)
        return '' if args.length < 3 # Genie lists/manages with < 3 args; no-op here

        key = args[1].to_s
        value = evaluate_value(args[2..].join(' '))
        @vars.global_set(key, value, persist: persist)
        ''
      end

      def delete_variable(args)
        @vars.global_delete(args[1].to_s.strip) if args.length >= 2
        ''
      end

      # --- engine-side: computation ----------------------------------------

      def eval_math(argument)
        Numeric.format_double(MathEval.evaluate(argument))
      rescue Error
        '0'
      end

      # #math {var} {expr}: keyword-based arithmetic into a global (Command.cs:1051).
      def do_math(args)
        return '' if args.length < 3

        key = args[1].to_s
        current = Numeric.string_to_double(@vars.global_get(key) || '0')
        @vars.global_set(key, Numeric.format_double(MathCalc.calc(current, args[2..].join(' '))), persist: true)
        ''
      rescue Error
        ''
      end

      # #if {cond} {then} {else}: evaluate cond, route the taken branch (Command.cs:1088).
      def do_if(args)
        return '' if args.length < 3

        branch = @eval.do_eval(args[1].to_s) ? args[2] : args[3]
        return '' if branch.nil?

        branch.to_s.lstrip.start_with?('#') ? compute(branch.to_s) : branch.to_s
      end

      # --- engine-side: echo -----------------------------------------------

      # `#echo >window text` routes to a named-window front-end echo; plain `#echo
      # text` echoes locally. Colored/main-window color parsing is deferred.
      def do_echo(args, argument)
        if args.length >= 2 && args[1].to_s.start_with?('>')
          window = args[1].to_s[1..]
          text = args[2..].join(' ')
          @hooks&.emit('echo', { 'window' => window, 'text' => text })
        else
          @echo.call(argument)
        end
        ''
      end

      # --- front-end effects: structured payloads --------------------------

      # #class name on|off  |  #class +name -name ...  (Command.cs:1254)
      def emit_class(args)
        return if args.length < 2

        first = args[1].to_s
        if first.start_with?('+', '-')
          args[1..].each do |token|
            next unless token.start_with?('+', '-') && token.length > 1

            emit('class', 'name' => token[1..].downcase, 'enabled' => token.start_with?('+'))
          end
        elsif args.length >= 3
          emit('class', 'name' => first.downcase, 'enabled' => TRUTHY.include?(args[2].to_s.downcase))
        end
      end

      # #trigger {pattern} {commands} {class}  |  #trigger clear  (Command.cs:1386)
      def emit_trigger(args)
        keyword = args[1].to_s.downcase
        return emit('trigger', 'action' => 'clear') if args.length == 2 && keyword == 'clear'
        return if args.length < 3

        emit('trigger', 'pattern' => args[1].to_s, 'commands' => args[2].to_s, 'class' => args[3].to_s)
      end

      # #gag/#ignore {pattern} {class}. NOTE: per design Decision 6 the sink applies
      # gag/sub as a Lich DownstreamHook (Model A), not a rendered front-end tag; the
      # normalized event here is what the sink consumes.
      def emit_gag(op, args)
        return if args.length < 2

        emit(op, 'pattern' => args[1].to_s, 'class' => args[2].to_s)
      end

      # #sub/#substitute {pattern} {replacement} {class}. See Decision 6 (Model A).
      def emit_sub(op, args)
        return if args.length < 2

        emit(op, 'pattern' => args[1].to_s, 'replacement' => args[2].to_s, 'class' => args[3].to_s)
      end

      # Front-end op with tokenized args pending a finalized schema; unknown commands
      # fall through here too (safe to ignore on a front-end that doesn't render them).
      def emit_generic(keyword, args, argument)
        emit(keyword, 'args' => args[1..], 'raw' => argument)
        ''
      end

      def emit(op, payload)
        @hooks&.emit(op, payload)
      end
    end
  end
end
