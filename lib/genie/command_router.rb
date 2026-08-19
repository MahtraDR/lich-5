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

      # Engine-side commands run in Lich; everything else is a front-end effect.
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
        when 'send' then send_to_game(argument)
        else dispatch_fe(keyword, args, argument)
        end
      end

      # Front-end effects: emit a self-describing normalized event. Payloads are
      # ported from the Command.cs runtime handlers (line refs on each method).
      def dispatch_fe(keyword, args, argument)
        case keyword
        when 'class', 'classes' then emit_class(args)
        when 'trigger', 'triggers' then emit_trigger(args)
        when 'gag', 'gags', 'ignore', 'ignores', 'squelch' then emit_gag('gag', args)
        when 'ungag' then emit_gag('ungag', args)
        when 'sub', 'subs', 'substitute' then emit_sub('substitute', args)
        when 'unsub' then emit_sub('unsub', args)
        when 'highlight', 'highlights' then emit_highlight(args)
        when 'preset', 'presets' then emit_preset(args)
        when 'window' then emit_window(args)
        when 'macro', 'macros' then emit_pair('macro', 'key', 'command', args)
        when 'unmacro' then emit_key('unmacro', 'key', args)
        when 'alias', 'aliases' then emit_pair('alias', 'pattern', 'command', args)
        when 'unalias' then emit_key('unalias', 'pattern', args)
        when 'play', 'playwave', 'playsound' then emit_sound(argument)
        when 'link' then emit_link(args)
        when 'img', 'image' then emit_image(args)
        when 'name', 'names' then emit_name(args)
        when 'unname' then emit_unname(args)
        when 'beep', 'bell' then emit('beep', {})
        when 'flash' then emit('flash', {})
        when 'layout' then emit_layout(args)
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

      def send_to_game(argument)
        @send.call(argument)
        ''
      end

      # --- front-end effects: structured payloads --------------------------

      # #class name on|off  |  #class +name -name ...  (Command.cs:1254)
      def emit_class(args)
        return '' if args.length < 2

        first = args[1].to_s
        if first.start_with?('+', '-')
          args[1..].each do |token|
            next unless token.start_with?('+', '-') && token.length > 1

            emit('class', 'name' => token[1..].downcase, 'enabled' => token.start_with?('+'))
          end
        elsif args.length >= 3
          emit('class', 'name' => first.downcase, 'enabled' => TRUTHY.include?(args[2].to_s.downcase))
        end
        ''
      end

      # #trigger {pattern} {commands} {class}  |  #trigger clear  (Command.cs:1386)
      def emit_trigger(args)
        return emit('trigger', 'action' => 'clear') if args.length == 2 && args[1].to_s.casecmp?('clear')
        return '' if args.length < 3

        emit('trigger', 'pattern' => args[1].to_s, 'commands' => args[2].to_s, 'class' => args[3].to_s)
      end

      # #gag/#ignore {pattern} {class}. NOTE: per design Decision 6 the sink applies
      # gag/sub as a Lich DownstreamHook (Model A), not a rendered front-end tag; the
      # normalized event here is what the sink consumes.
      def emit_gag(op, args)
        return '' if args.length < 2

        emit(op, 'pattern' => args[1].to_s, 'class' => args[2].to_s)
      end

      # #sub/#substitute {pattern} {replacement} {class}. See Decision 6 (Model A).
      def emit_sub(op, args)
        return '' if args.length < 2

        emit(op, 'pattern' => args[1].to_s, 'replacement' => args[2].to_s, 'class' => args[3].to_s)
      end

      # #highlight {line|string|beginswith|regex} {color} {pattern} [case] [sound]
      # [class] [active]  |  #highlight clear  (Command.cs:1906). Genie's pattern is
      # ArrayToString(oArgs,3) -- greedy to end-of-line -- reproduced faithfully.
      HIGHLIGHT_KINDS = { 'line' => 'line', 'lines' => 'line', 'string' => 'string',
                          'strings' => 'string', 'beginswith' => 'beginswith',
                          'regexp' => 'regex', 'regex' => 'regex' }.freeze

      def emit_highlight(args)
        return '' if args.length < 2

        kind = args[1].to_s.downcase
        return emit('highlight', 'clear' => true) if kind == 'clear'

        normalized = HIGHLIGHT_KINDS[kind]
        return '' if normalized.nil? || args.length < 4

        emit('highlight',
             'kind' => normalized, 'whole_row' => normalized == 'line',
             'color' => args[2].to_s, 'pattern' => args[3..].join(' '),
             'case_sensitive' => args[4].to_s.casecmp?('true'),
             'sound' => args[5].to_s, 'class' => args[6].to_s,
             'active' => args.length > 7 ? args[7].to_s.casecmp?('true') : true)
      end

      # #preset {name} {value} (Command.cs:1826); value coloring is the front-end's job.
      def emit_preset(args)
        return '' if args.length < 3

        emit('preset', 'name' => args[1].to_s.downcase, 'value' => args[2].to_s)
      end

      # #window {add|show|position|remove|close|hide} {name} [dims] (Command.cs:2352).
      def emit_window(args)
        return '' if args.length < 2

        action = args[1].to_s.downcase
        case action
        when 'add', 'show'
          emit('window', 'action' => action, 'name' => args[2..].join(' '),
                         'width' => 300, 'height' => 200, 'top' => 10, 'left' => 10)
        when 'position'
          emit('window', 'action' => 'position', 'name' => args[2].to_s,
                         'width' => int_or_nil(args[3]), 'height' => int_or_nil(args[4]),
                         'top' => int_or_nil(args[5]), 'left' => int_or_nil(args[6]))
        when 'remove', 'close', 'hide'
          emit('window', 'action' => action, 'name' => args[2..].join(' '))
        else ''
        end
      end

      # #play/#playwave/#playsound <file>|stop (Command.cs:1570; uses the arg string).
      def emit_sound(argument)
        arg = argument.to_s.strip
        return '' if arg.empty?

        arg.casecmp?('stop') ? emit('playsound', 'stop' => true) : emit('playsound', 'file' => arg)
      end

      # #link [>window] {text} {command} (Command.cs:335).
      def emit_link(args)
        if args.length > 3 && args[1].to_s.start_with?('>')
          emit('link', 'window' => args[1].to_s[1..], 'text' => args[2].to_s, 'command' => args[3..].join(' '))
        elsif args.length > 2
          emit('link', 'window' => '', 'text' => args[1].to_s, 'command' => args[2..].join(' '))
        else
          ''
        end
      end

      # #img/#image [>window] [w:N] [h:N] {file} -- tokens are order-independent
      # (Command.cs:397).
      def emit_image(args)
        window = ''
        width = 0
        height = 0
        filename = ''
        args[1..].each do |tok|
          t = tok.to_s
          if t.start_with?('>') then window = t[1..]
          elsif (m = t.match(/\A(?:w|width):(\d+)\z/i)) then width = m[1].to_i
          elsif (m = t.match(/\A(?:h|height):(\d+)\z/i)) then height = m[1].to_i
          else filename = t
          end
        end
        return '' if filename.empty?

        emit('image', 'filename' => filename, 'window' => window, 'width' => width, 'height' => height)
      end

      # #name {value} {target...} -- applies +value+ (color/class) to each name
      # (Command.cs:2045); emit one event per target.
      def emit_name(args)
        return '' if args.length < 3

        value = args[1].to_s
        args[2..].each { |target| emit('name', 'name' => target.to_s, 'value' => value) }
        ''
      end

      # #unname {name...} (Command.cs:2105).
      def emit_unname(args)
        return '' if args.length < 2

        args[1..].each { |target| emit('unname', 'name' => target.to_s) }
        ''
      end

      # #layout [load|save] {name} (Command.cs:2324); no args -> load @windowsize@.
      def emit_layout(args)
        return emit('layout', 'action' => 'load', 'name' => '@windowsize@') if args.length < 2

        action = args[1].to_s.downcase
        return '' unless %w[load save].include?(action)

        emit('layout', 'action' => action, 'name' => args[2..].join(' '))
      end

      # #macro/#alias {a} {b} (Command.cs:1604/1186).
      def emit_pair(op, key1, key2, args)
        return '' if args.length < 3

        emit(op, key1 => args[1].to_s, key2 => args[2].to_s)
      end

      # #unmacro/#unalias {a} (Command.cs:1662/1244).
      def emit_key(op, key, args)
        return '' if args.length < 2

        emit(op, key => args[1].to_s)
      end

      # Unknown/unspecified front-end op: tokenized args + raw (safe to ignore).
      def emit_generic(keyword, args, argument)
        emit(keyword, 'args' => args[1..], 'raw' => argument)
      end

      def int_or_nil(token)
        s = token.to_s.strip
        return nil if s.empty? || s == '0'

        Integer(s, exception: false)
      end

      def emit(op, payload)
        @hooks&.emit(op, payload)
        ''
      end
    end
  end
end
