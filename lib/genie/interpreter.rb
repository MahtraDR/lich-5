# frozen_string_literal: true

module Lich
  module Genie
    # Executes a compiled Genie program. Clean-room port of Genie4 Script.cs
    # RunScript/RunScriptRow/TickScript, adapted to Lich's thread-per-script model
    # (Option A, design doc Decision 4): instead of a 10ms cooperative tick, the
    # interpreter runs rows until a wait verb, then blocks on the injected input
    # port (with a deadline) while still firing async actions. See
    # docs/genie-engine/interpreter-spec.md.
    #
    # Collaborators are injected (DIP) so this runs headless in specs:
    #   * game  -- responds to #send_command(String)
    #   * input -- responds to #next_line(timeout:) => String or nil (nil on timeout)
    #   * echo  -- callable(String) for script echo/errors
    #   * hooks -- responds to #emit(op, payload) for <genieHook> front-end effects
    #   * clock -- callable => monotonic Float seconds
    #
    # Scope note (prototype): js/jscall/plugin are stubbed; `wait`/`move` resume on
    # the next line (no prompt/room-change detection outside Lich); actions support
    # put/send/echo/goto/setvariable. These are marked and expanded later.
    class Interpreter
      LOOP_WINDOW_SECONDS = 10.0
      LOOP_SAME_CMD_LIMIT = 10
      LOOP_TOTAL_CMD_LIMIT = 30

      # Per-run wall-clock deadline: if a continuous row loop (no wait/send yield)
      # runs longer than this, abort as a runaway (Genie Config.iScriptTimeout,
      # default 5000ms; Script.cs:1857). Catches tight goto loops that emit only
      # hooks/vars, which the send-history guard above never sees.
      SCRIPT_TIMEOUT_SECONDS = 5.0

      # Genie's ScriptChar (Config.m_cScriptChar, default '.'): outgoing text that
      # starts with it runs another script instead of going to the game -- that's how
      # `put .helper` launches helper.cmd (Command.cs:2557 / ClassCommand_RunScript).
      SCRIPT_CHAR = '.'

      # @param program [Lexer::Program]
      # @param variables [Variables]
      # @param name [String] script name (for messages)
      # @param game [#send_command]
      # @param input [#next_line]
      # @param echo [#call]
      # @param hooks [#emit]
      # @param clock [#call]
      # @param launch [#call] callable(name, args_string) to start another script
      # @param specials [Specials]
      def initialize(program:, variables:, name: 'genie', args: [], game: nil, input: nil,
                     echo: nil, hooks: nil, clock: nil, launch: nil, mover: nil, specials: nil,
                     script_control: nil)
        @program = program
        @vars = variables
        @name = name
        @game = game
        @input = input
        @echo = echo || ->(_text) {}
        @hooks = hooks
        @launch = launch || ->(_name, _args) {}
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @timer_start = nil
        @call_stack = CallStack.new
        # Wire @timer@ to this interpreter's script timer unless a custom Specials given.
        resolved_specials = specials || Specials.new(timer_elapsed: -> { @timer_start ? now - @timer_start : 0 })
        @substitution = Substitution.new(variables: @vars, specials: resolved_specials)
        @eval = Eval.new(globals: GlobalsAdapter.new(@vars))
        @router = CommandRouter.new(
          vars: @vars, eval: @eval, hooks: @hooks, mover: mover,
          script_control: script_control, script_name: name,
          echo: ->(text) { echo_line(text) },
          send: ->(text) { send_text(text) }
        )
        @js_arrays = JsArrays.new(@vars)
        @state = :running
        @match_list = []
        @actions = []
        @send_history = []
        @action_jumped = false
        seed_args(args)
      end

      # Run the program to completion.
      # @return [void]
      def run
        @state = :running
        until @state == :finished
          case @state
          when :running then run_rows
          when :pausing then wait_deadline(@pause_end)
          when :delayed then wait_deadline(@delay_end)
          when :matchwait then resume_matchwait
          when :waitfor then resume_line { |line| waitfor_match?(line) }
          when :wait then resume_line { |_line| true } # prototype: resume on next line
          when :move then resume_line { |_line| true } # prototype: resume on next line
          else @state = :finished
          end
        end
      end

      private

      # Adapts Variables to the #key? interface Eval's def()/defined() expects.
      class GlobalsAdapter
        def initialize(variables) = (@variables = variables)
        def key?(name) = @variables.global_key?(name)
      end

      # Seed the base frame's arg list ($0..$n) and the numbered local vars
      # (%0..%n) + %argcount, mirroring Genie's script-launch argument setup.
      def seed_args(args)
        return if args.nil? || args.empty?

        @call_stack.arg_list.replace(args.map(&:to_s))
        args.each_index { |i| @vars.local_set(i.to_s, args[i].to_s) }
        @vars.local_set('argcount', [args.length - 1, 0].max.to_s)
      end

      def now
        @clock.call
      end

      # --- main row loop (RunScript) ----------------------------------------

      def run_rows
        # A run_rows entry is the initial start OR a resume from a wait
        # (matchwait/pause/waitfor/wait/move) -- i.e. the script just made real
        # progress (a game round-trip or a genuine wait), NOT a tight loop. Reset BOTH
        # runaway guards here: the wall-clock deadline (Genie resets oTimerStart per
        # RunScript call) AND the send-history window. Clearing send-history is what
        # keeps a legit combat loop that waits every cycle (assess -> matchwait -> act
        # -> goto) from eventually tripping the 30-sends/10s total; only a loop that
        # spins WITHOUT ever waiting keeps accumulating across iterations.
        @run_deadline = now + SCRIPT_TIMEOUT_SECONDS
        @send_history.clear
        while @state == :running
          index = @call_stack.line_value
          if index >= @program.instructions.length
            finish
            break
          end

          instruction = @program.instructions[index]
          break if runaway?(instruction)

          on_blockstart if instruction.function == :blockstart
          on_blockend if instruction.function == :blockend

          if @call_stack.skip_block
            skip_row(instruction, index)
          else
            new_index = run_script_row(instruction, index)
            @call_stack.line_value = new_index + 1 if @state == :running
          end
        end
      end

      def skip_row(instruction, index)
        @call_stack.skip_block = false if @call_stack.last_row_was_evaluation && instruction.function != :if_func
        @call_stack.line_value = index + 1
      end

      # --- block bookkeeping (spec section 2.2) -----------------------------

      def on_blockstart
        @call_stack.target_block_depth = @call_stack.block_count if @call_stack.skip_block && @call_stack.target_block_depth <= 0
        @call_stack.add_block(:noeval)
        @call_stack.last_row_was_evaluation = false
      end

      def on_blockend
        @call_stack.remove_block
        return unless @call_stack.skip_block && @call_stack.target_block_depth >= @call_stack.block_count

        @call_stack.skip_block = false
        @call_stack.target_block_depth = 0
      end

      # --- verb dispatch (RunScriptRow) -------------------------------------

      # @return [Integer] the (possibly jumped) instruction index
      def run_script_row(instruction, index)
        parsed = substitute(instruction.content)
        arg = Text.argument_string(parsed)

        case instruction.function
        when :echo then echo_line(arg)
        when :put then do_put(arg)
        when :send then send_text(arg)
        when :do_func then send_text(arg)
        when :move then return do_move(arg, index)
        when :nextroom then return do_move('', index)
        when :goto_func then return do_goto(arg, index)
        when :gosub_func then return do_gosub(arg, index)
        when :return_func then return do_return
        when :exit_func then finish
        when :save then local_set('s', arg)
        when :setvariable then local_set(Text.keyword_string(arg), Text.argument_string(arg))
        when :deletevariable then @vars.local_delete(arg.strip)
        when :counter then math_into('c', arg)
        when :math_func then math_into(Text.keyword_string(arg), Text.argument_string(arg))
        when :eval_func then do_eval(arg)
        when :evalmath_func then do_evalmath(arg)
        when :random then do_random(arg)
        when :shift then do_shift
        when :pause then return do_pause(arg, index)
        when :delay then return do_delay(arg, index)
        when :waitfor then return enter_wait(:waitfor, index) { @wait_string = arg; @wait_regex = false }
        when :waitforre then return enter_wait(:waitfor, index) { @wait_string = arg; @wait_regex = true }
        when :wait then return enter_wait(:wait, index)
        when :match then add_match(arg, false)
        when :matchre then add_match(arg, true)
        when :matchwait then return do_matchwait(arg, index)
        when :if_func then do_if(instruction, arg)
        when :while_func then do_while(instruction, arg)
        when :else_func then do_else(instruction)
        when :action then do_action(Text.argument_string(instruction.content))
        when :timer then do_timer(Text.argument_string(instruction.content))
        when :js then run_js(arg)
        when :jscall then run_jscall(arg)
        when :plugin, :pluginscript then announce_unsupported('#plugin/#pluginscript', arg)
        when :debuglevel then nil # no-op (debug verbosity has no meaning in Lich)
        end

        index
      end

      # --- IO verbs ---------------------------------------------------------

      def do_put(arg)
        send_text(arg)
      end

      # The single sink for put/send/do (and action bodies). Genie routes ALL of
      # these through ParseCommand, so a leading '#' is a bar command and a leading
      # '.' launches a script -- for put AND send AND do (not just put).
      def send_text(text)
        return if text.nil? || text.strip.empty?

        stripped = text.lstrip
        return @router.route(stripped) if stripped.start_with?('#')
        return launch_script(stripped) if stripped.start_with?(SCRIPT_CHAR)
        return if loop_guard_tripped?(text)

        @game&.send_command(text)
        # A game send is a progress point -- and send_command may have just BLOCKED in
        # waitrt? for a long roundtime (e.g. a 20s invoke or a barrage). Reset the
        # wall-clock deadline AFTER the send so RT-wait time is not counted as
        # "continuous loop time"; otherwise a long RT between two sends falsely trips
        # the runaway timeout mid-combat (this killed sc right after invoke/barrage).
        # The wall-clock now guards only send-LESS loops (pure goto/var/hook); loops
        # that emit game commands are caught by the send-history guard instead.
        @run_deadline = now + SCRIPT_TIMEOUT_SECONDS
        local_set('lastcommand', text)
      end

      # A `.name args` line launches another script (Genie ScriptChar). Strip the
      # leading char; first word is the script name, the rest are its args.
      def launch_script(text)
        body = text[SCRIPT_CHAR.length..].to_s
        name = Text.keyword_string(body)
        return if name.empty?

        @launch.call(name, Text.argument_string(body))
      end

      # Per-run deadline watchdog (Script.cs:1857): abort a continuous row loop that
      # exceeds SCRIPT_TIMEOUT_SECONDS with no wait/send yield (e.g. a goto loop that
      # only emits hooks/vars). Message mirrors Genie's "filename(row)" format.
      def runaway?(instruction)
        return false unless now > @run_deadline

        file = @program.files[instruction.file_id] || @name
        echo_line("[Script timeout in #{file}(#{instruction.file_row}): Possible infinite loop.]")
        finish
        true
      end

      # Runaway-command watchdog (spec section 8): 10 identical or 30 total in 10s.
      def loop_guard_tripped?(text)
        return false if text.start_with?('#')

        current = now
        @send_history.reject! { |(_, at)| current - at > LOOP_WINDOW_SECONDS }
        @send_history << [text, current]
        same = @send_history.count { |(cmd, _)| cmd.casecmp?(text) }
        return false unless same >= LOOP_SAME_CMD_LIMIT || @send_history.length >= LOOP_TOTAL_CMD_LIMIT

        echo_line("[Script error: possible infinite loop detected: #{@name}]")
        finish
        true
      end

      # --- control flow -----------------------------------------------------

      def do_goto(arg, index)
        label = arg.strip.downcase
        target = @program.labels[label]
        return abort_with("Unknown label from GOTO: #{label}", index) if target.nil?

        local_set('lastlabel', label)
        @call_stack.clear_blocks
        target
      end

      def do_gosub(arg, index)
        label = Text.keyword_string(arg).downcase
        return (@call_stack.clear || index) if label == 'clear'

        target = @program.labels[label]
        return abort_with("Unknown label from GOSUB: #{label}", index) if target.nil?

        @call_stack.add_jump(index, Text.argument_string(arg))
        target
      end

      def do_return
        return @call_stack.line_value if @call_stack.remove_jump

        abort_with('RETURN failed: no gosub bookmarks to return to', @call_stack.line_value)
      end

      # --- conditionals -----------------------------------------------------

      def do_if(instruction, arg)
        @call_stack.last_row_was_evaluation = true if instruction.content.rstrip.downcase.end_with?(' then')
        condition = arg.sub(/\s+then\s*\z/i, '')
        if @eval.do_eval(condition)
          @call_stack.block_value = :evaltrue
        else
          @call_stack.block_value = :evalfalse
          @call_stack.skip_block = true
        end
        copy_capture_groups
      end

      def do_while(instruction, arg)
        # NOTE: Genie's while has no back-edge; it behaves as an if-guard (spec 2.3).
        @call_stack.last_row_was_evaluation = true if instruction.content.rstrip.downcase.end_with?(' do')
        condition = arg.sub(/\s+do\s*\z/i, '')
        if @eval.do_eval(condition)
          @call_stack.block_value = :evalwhiletrue
        else
          @call_stack.block_value = :evalwhilefalse
          @call_stack.skip_block = true
        end
      end

      def do_else(instruction)
        @call_stack.last_row_was_evaluation = true if instruction.content.rstrip.downcase == 'else'
        @call_stack.skip_block = true if @call_stack.block_value == :evaltrue
      end

      def copy_capture_groups
        groups = @eval.result_list
        @call_stack.arg_list.replace(groups) unless groups.empty?
      end

      # --- variables / math -------------------------------------------------

      def math_into(var, expression)
        current = Numeric.string_to_double(@vars.local_get(var) || '0')
        result = MathCalc.calc(current, expression)
        local_set(var, Numeric.format_double(result))
      rescue Error => e
        echo_line("[#{e.message}]")
      end

      def do_eval(arg)
        var = Text.keyword_string(arg)
        local_set(var, @eval.eval_string(Text.argument_string(arg)))
        copy_capture_groups
      end

      def do_evalmath(arg)
        var = Text.keyword_string(arg)
        result = MathEval.evaluate(Text.argument_string(arg))
        local_set(var, Numeric.format_double(result))
      rescue Error
        local_set(var, '0')
      end

      def do_random(arg)
        low = Numeric.to_integer(Text.keyword_string(arg))
        high = Numeric.to_integer(Text.argument_string(arg))
        low, high = high, low if low > high
        local_set('r', rand(low..high).to_s)
      end

      def do_shift
        args = @call_stack.arg_list
        return if args.length <= 1

        args.delete_at(1)
        args[0] = args[1..].join(' ')
      end

      # --- waits ------------------------------------------------------------

      def enter_wait(state, index)
        yield if block_given?
        @state = state
        @call_stack.line_value = index + 1
        index
      end

      def do_pause(arg, index)
        @pause_end = now + parse_seconds(arg, 1.0)
        enter_wait(:pausing, index)
      end

      def do_delay(arg, index)
        @delay_end = now + parse_seconds(arg, 1.0)
        enter_wait(:delayed, index)
      end

      def do_move(arg, index)
        send_text(arg) unless arg.strip.empty?
        enter_wait(:move, index)
      end

      def add_match(arg, regex)
        if arg.strip.downcase == 'clear'
          @match_list = []
          return
        end
        label = Text.keyword_string(arg)
        pattern = Text.argument_string(arg)
        @match_list << { label: label.downcase, pattern: pattern, regex: regex }
      end

      def do_matchwait(arg, index)
        seconds = arg.strip.empty? ? 0 : Numeric.string_to_double(arg)
        @match_timeout = seconds.positive? ? now + seconds : nil
        @matchwait_index = index
        @state = :matchwait
        @call_stack.line_value = index
        index
      end

      # Resume loop for waitfor/wait/move: read lines, fire actions, test predicate.
      def resume_line
        loop do
          return if @state == :finished

          line = @input&.next_line(timeout: nil)
          next unless line

          fire_actions(line)
          return if consume_action_jump

          if yield(line)
            @state = :running
            return
          end
        end
      end

      def resume_matchwait
        loop do
          return if @state == :finished

          remaining = @match_timeout ? [@match_timeout - now, 0].max : nil
          line = @input&.next_line(timeout: remaining)
          if line
            fire_actions(line)
            return if consume_action_jump

            label = match_line(line)
            next if label.nil?

            local_set('lastlabel', label)
            @call_stack.clear_blocks
            @match_list = []
            @call_stack.line_value = @program.labels[label]
            @state = :running
            return
          elsif @match_timeout && now >= @match_timeout
            @match_list = []
            @call_stack.line_value = @matchwait_index + 1
            @state = :running
            return
          end
        end
      end

      def wait_deadline(deadline)
        loop do
          return if @state == :finished

          remaining = deadline - now
          if remaining <= 0
            @state = :running
            return
          end
          line = @input&.next_line(timeout: remaining)
          next unless line

          fire_actions(line)
          return if consume_action_jump
        end
      end

      def waitfor_match?(line)
        if @wait_regex
          !Regexp.new(@wait_string).match(line).nil?
        else
          line.downcase.include?(@wait_string.downcase)
        end
      end

      def match_line(line)
        hit = @match_list.find do |entry|
          if entry[:regex]
            (@last_match = Regexp.new(entry[:pattern]).match(line.strip))
          else
            line.include?(entry[:pattern])
          end
        end
        return nil unless hit

        @call_stack.arg_list.replace(@last_match.to_a.map(&:to_s)) if hit[:regex] && @last_match
        hit[:label]
      end

      # --- actions (basic, prototype) --------------------------------------

      def do_action(raw)
        text = raw.strip
        keyword = Text.keyword_string(text).downcase
        instant = false

        case keyword
        when 'clear'
          @actions = []
          return
        when 'remove'
          removed = Text.argument_string(text).strip
          @actions.reject! { |action| action[:source] == removed }
          return
        when 'add'
          text = Text.argument_string(text)
        when 'instant'
          instant = true
          text = Text.argument_string(text)
        end

        return if text.start_with?('(') # (class) on/off toggle -- deferred (front-end gating)

        commands, trigger = text.split(/\s+when\s+/i, 2)
        return if trigger.nil? || trigger.empty?

        begin
          regex = Regexp.new(trigger)
        rescue RegexpError
          echo_line("[Genie: invalid action trigger regex: #{trigger}]")
          return
        end
        @actions << { trigger: regex, source: trigger, commands: commands, active: true, instant: instant }
      end

      def fire_actions(line)
        @actions.each do |action|
          next unless action[:active]

          match = action[:trigger].match(line)
          next unless match

          execute_action(action[:commands], match)
          break if @action_jumped || @state == :finished
        end
      end

      def execute_action(commands, match)
        commands.to_s.split(';').each do |raw|
          command = raw.strip.gsub(/\$(\d+)/) { match[Regexp.last_match(1).to_i].to_s }
          next if command.empty?

          if command.start_with?('#')
            @router.route(substitute(command))
            next
          end

          keyword = Text.keyword_string(command).downcase
          argument = Text.argument_string(command)
          case keyword
          when 'goto'
            target = @program.labels[argument.strip.downcase]
            if target
              @action_jumped = true
              @action_jump_target = target
              break
            end
          when 'echo' then echo_line(argument)
          when 'put', 'send' then send_text(substitute(argument))
          when 'setvariable', 'var' then local_set(Text.keyword_string(argument), Text.argument_string(argument))
          when 'js' then run_js(substitute(argument))
          when 'jscall' then run_jscall(substitute(argument))
          else send_text(substitute(command))
          end
        end
      end

      def consume_action_jump
        return false unless @action_jumped

        @call_stack.clear
        @match_list = []
        @call_stack.line_value = @action_jump_target
        @action_jumped = false
        @state = :running
        true
      end

      # --- timer / misc -----------------------------------------------------

      def do_timer(raw)
        case Text.keyword_string(raw).downcase
        when 'start', 'setstart', '' then @timer_start = now
        when 'stop', 'clear' then @timer_start = nil
        end
      end

      # --- js_arrays bridge (the only JS used across the corpus) --------------

      # `js FUNC(args)`: run a js_arrays op for its side effect (array mutation).
      # @param call_text [String] the substituted text after the `js` verb
      def run_js(call_text)
        parsed = parse_js_call(call_text)
        return announce_unsupported('#js', call_text) if parsed.nil?

        announce_unsupported('#js', call_text) if @js_arrays.call(*parsed) == :unknown
      end

      # `jscall VAR FUNC(args)`: run a js_arrays op and store its return in local VAR.
      # @param call_text [String] the substituted text after the `jscall` verb
      def run_jscall(call_text)
        target = Text.keyword_string(call_text)
        parsed = parse_js_call(Text.argument_string(call_text))
        return announce_unsupported('#jscall', call_text) if parsed.nil? || target.empty?

        result = @js_arrays.call(*parsed)
        return announce_unsupported('#jscall', call_text) if result == :unknown

        local_set(target, result.to_s)
      end

      # Parse a `FUNC(arg, arg, ...)` js call. @return [[String, Array<String>], nil]
      def parse_js_call(text)
        match = text.to_s.strip.match(/\A([A-Za-z_]\w*)\s*\((.*)\)\s*\z/m)
        return nil if match.nil?

        [match[1], split_js_args(match[2])]
      end

      # Split a js arg list on top-level commas, honoring double-quotes, and strip the
      # surrounding quotes (js_arrays args are quoted strings or bare numbers).
      def split_js_args(raw)
        return [] if raw.strip.empty?

        args = []
        buffer = +''
        quoted = false
        raw.each_char do |char|
          if char == '"' then quoted = !quoted
          elsif char == ',' && !quoted then (args << buffer.strip) && (buffer = +'')
          else buffer << char
          end
        end
        args << buffer.strip
      end

      def announce_unsupported(verb, detail)
        echo_line("[Genie: #{verb} not supported in the in-Lich engine: #{detail.to_s.strip}]")
      end

      # --- helpers ----------------------------------------------------------

      def substitute(content)
        @substitution.expand(content, args: @call_stack.arg_list)
      end

      def local_set(name, value)
        @vars.local_set(name, value)
      end

      def echo_line(text)
        @echo.call(text.to_s)
      end

      def parse_seconds(arg, default)
        return default if arg.strip.empty?

        value = Numeric.string_to_double(arg)
        value.positive? ? value : default
      end

      def finish
        @state = :finished
      end

      def abort_with(message, index)
        echo_line("[#{message}]")
        finish
        index
      end
    end
  end
end
