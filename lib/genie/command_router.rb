# frozen_string_literal: true

module Lich
  module Genie
    # No-op script-control port (the default). Used headless (specs) or when no host
    # script system is wired: there are no running scripts to enumerate and every
    # lifecycle action is a silent no-op, so `#script abort/pause/...` do nothing.
    class NullScriptControl
      def names = []
      def abort(_name) = nil
      def pause(_name) = nil
      def resume(_name) = nil
      def pauseorresume(_name) = nil
      def reload(_name) = nil
    end

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
      # @param mover [#call, nil] callable(room_arg) that walks to a room (#goto)
      # @param script_control [#names, #abort, #pause, #resume, #pauseorresume,
      #   #reload, nil] host script-registry port for `#script` (defaults to a no-op)
      # @param script_name [String, nil] name of the script issuing commands, so
      #   `#script abort all` can abort the caller LAST (see {#apply_script_action})
      def initialize(vars:, eval:, echo:, send:, hooks:, mover: nil, script_control: nil, script_name: nil)
        @vars = vars
        @eval = eval
        @echo = echo
        @send = send
        @hooks = hooks
        @mover = mover || ->(_room) {}
        @script_control = script_control || NullScriptControl.new
        @script_name = script_name
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
        when 'goto' then goto_room(argument)
        when 'script' then do_script(args, argument)
        when 'mapper', 'automapper' then '' # reset/etc: no-op (we route movement via go2/DRC)
        when 'queue' then do_queue(args)
        else dispatch_fe(keyword, args, argument)
        end
      end

      # --- engine-side: #script host control -------------------------------

      # Genie lifecycle subcommands routed to the host script registry (the injected
      # script-control port). Informational subcommands (list/vars/trace/debug/
      # explorer/default) stay front-end effects via emit_generic.
      LIFECYCLE_SCRIPT_ACTIONS = {
        'abort' => :abort, 'pause' => :pause, 'resume' => :resume,
        'pauseorresume' => :pauseorresume, 'reload' => :reload
      }.freeze

      # #script {abort|pause|resume|pauseorresume|reload} [all [except <name>] | <name>]
      # (Command.cs:2188 -> FormMain.Command_ScriptAbort/Pause/Resume). Before this,
      # `#script ...` fell through to a <genieHook> tag nothing consumes, so aborts were
      # silent no-ops -- which broke the combat suite's sh.cmd/sk.cmd (`#script abort all`
      # / `#script abort all except <name>`). The name/"all"/"except" resolution mirrors
      # FormMain exactly; the actual kill/pause/unpause is the host port's job.
      def do_script(args, argument)
        return emit_generic('script', args, argument) if args.length < 2

        action = LIFECYCLE_SCRIPT_ACTIONS[args[1].to_s.downcase]
        return emit_generic('script', args, argument) if action.nil?

        apply_script_action(action, args[2..].join(' '))
      end

      # `#queue clear` empties Genie's timed CommandQueue (Command.cs:1155). The in-Lich
      # engine sends commands immediately (waitrt? pacing, no timed queue exists), so there
      # is nothing to leak and `#queue clear` is a satisfied no-op -- and it is the ONLY
      # form the corpus uses (144/144 are `#queue clear`, all defensive clears on abort/
      # reset). A populate subcommand (add/list) would need a real host queue; none appear
      # in the corpus, so those announce as unsupported instead of silently emitting a
      # front-end hook nothing consumes.
      def do_queue(args)
        return '' if args.length < 2 || args[1].to_s.casecmp?('clear')

        @echo&.call("--- Genie: #queue #{args[1]} not supported (the in-Lich engine sends immediately)")
        ''
      end

      def apply_script_action(action, spec)
        target, except = parse_script_spec(spec)
        names = matching_scripts(target, except)
        # Genie aborts every match INCLUDING the caller (FormMain iterates the whole
        # list). In Lich a self-kill terminates this thread immediately (kill is not
        # cooperative), which would strand the rest of an "abort all" -- so abort the
        # issuing script LAST, after every other match has already been killed.
        if action == :abort && @script_name && names.include?(@script_name)
          names = names.reject { |n| n == @script_name } << @script_name
        end
        names.each { |name| @script_control.public_send(action, name) }
        ''
      end

      # Port of FormMain's "all"/"except"/exact-name resolution (Command_ScriptAbort):
      # split off `except <name>`, then an "all " prefix (or an empty spec) means "all
      # scripts" (target ""), otherwise the trimmed spec is an exact script name.
      # Returns [target, except]. NOTE: `except` is trimmed here (Genie left it raw);
      # our args arrive as clean single-space-joined tokens, so trimming only guards
      # against an accidental trailing space stranding the script meant to survive.
      def parse_script_spec(spec)
        text = spec.to_s
        except = ''
        idx = text.downcase.index('except ')
        if idx&.positive?
          except = text[(idx + 7)..].to_s.strip
          text = text[0...idx].rstrip
        end
        target = "#{text} ".downcase.start_with?('all ') ? '' : text.strip
        [target, except]
      end

      # Names of running host scripts to act on: empty target => all; a set except
      # name is always spared. Exact-name match (case-sensitive), like Genie.
      def matching_scripts(target, except)
        @script_control.names.map(&:to_s).reject(&:empty?).select do |name|
          (target.empty? || name == target) && (except.empty? || name != except)
        end
      end

      # #goto <room>: walk there (Genie automapper). Room-number translation +
      # the actual walk are the injected mover's job (Lich-side); see the glue.
      def goto_room(argument)
        room = argument.to_s.strip
        @mover.call(room) unless room.empty?
        ''
      end

      # Front-end effects: emit a self-describing normalized event. Payloads are
      # ported from the Command.cs runtime handlers (line refs on each method).
      def dispatch_fe(keyword, args, argument)
        case keyword
        when 'class', 'classes' then emit_class(args)
        when 'trigger', 'triggers' then emit_trigger(args)
        when 'untrigger' then (args.length >= 2 ? emit('untrigger', 'pattern' => args[1].to_s) : '')
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

      # #if {cond} {then} {else}: evaluate cond, then run the taken branch (Command.cs:1088).
      # Genie routes the branch back through ParseCommand, which FIRST splits it on the
      # separator char (`;`) and executes each sub-command -- so a branch like
      # `{#class a off;#var harn 0;#class spellcast off}` runs ALL of its parts, not just
      # the first. run_branch mirrors that; treating the branch as one command (the old
      # behavior) silently dropped every sub-command after the first, which broke the
      # combat suite's spellcast trigger (its whole body lives in an #if branch).
      def do_if(args)
        return '' if args.length < 3

        branch = @eval.do_eval(args[1].to_s) ? args[2] : args[3]
        return '' if branch.nil?

        run_branch(branch.to_s)
      end

      # Run a `;`-separated command line (an #if branch), returning the LAST row's
      # result -- Genie's ParseCommand resets sResult per row, so only the final row's
      # value bubbles up to the caller (which sends it to the game if non-empty). Each
      # `#`-row executes for its side effects (nested #if/#var/#class); a non-`#` row is
      # plain text whose value only surfaces as the branch result (Genie leaves it unsent
      # here because #if calls ParseCommand with bSendToGame=false).
      def run_branch(text)
        result = ''
        Text.safe_split(text, ';').each do |piece|
          row = piece.to_s.strip
          next if row.empty?

          result = row.start_with?('#') ? compute(row).to_s : row
        end
        result
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

      # #trigger {pattern} {commands} {class}  |  #trigger clear  |  #trigger [list]
      # (Command.cs:1386; bare #trigger lists in Genie).
      def emit_trigger(args)
        return emit('trigger', 'action' => 'list') if args.length < 2 || args[1].to_s.casecmp?('list')
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
