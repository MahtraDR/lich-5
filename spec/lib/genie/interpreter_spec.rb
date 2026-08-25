# frozen_string_literal: true

require_relative '../../../lib/genie'

# Records commands sent to the "game".
class FakeGame
  attr_reader :commands

  def initialize = (@commands = [])
  def send_command(text) = (@commands << text)
end

# Feeds queued downstream lines; simulates time passing on a timed wait so
# pause/matchwait-timeout resume deterministically instead of hanging.
class FakeInput
  def initialize(lines, clock_ref)
    @lines = lines.dup
    @clock = clock_ref
    @nils = 0
  end

  def next_line(timeout: nil)
    return @lines.shift unless @lines.empty?

    @nils += 1
    raise 'input exhausted (script waited with no more input)' if @nils > 1000

    @clock[0] += timeout if timeout
    nil
  end
end

# End-to-end tests: real Genie scripts compiled and run through the full pipeline
# (Lexer -> Interpreter -> Substitution/Eval/MathCalc) against fake ports.
RSpec.describe Lich::Genie::Interpreter do
  def run_script(source, input_lines: [], game_state: nil, include_loader: nil, clock: nil, mover: nil)
    clock_ref = [0.0]
    clock_proc = clock || -> { clock_ref[0] }
    game = FakeGame.new
    echoes = []
    hooks = []
    launches = []
    moves = []
    hook_sink = Object.new.tap do |o|
      o.define_singleton_method(:emit) { |op, payload| hooks << [op, payload] }
    end
    Lich::Genie::Engine.run(
      source,
      name: 'test',
      game_state: game_state,
      include_loader: include_loader,
      game: game,
      input: FakeInput.new(input_lines, clock_ref),
      echo: ->(text) { echoes << text },
      hooks: hook_sink,
      launch: ->(name, args) { launches << [name, args] },
      mover: mover || ->(room) { moves << room },
      clock: clock_proc
    )
    { commands: game.commands, echoes: echoes, hooks: hooks, launches: launches, moves: moves }
  end

  describe 'control flow, variables, expressions (no waits)' do
    it 'runs assignments, eval, math and a conditional' do
      source = <<~GENIE
        setvariable x 5
        eval y %x > 3
        echo x=%x y=%y
        math x add 10
        echo x=%x
        if %x = 15 then echo fifteen
        exit
      GENIE
      result = run_script(source)
      expect(result[:echoes]).to eq(['x=5 y=1', 'x=15', 'fifteen'])
    end

    it 'skips the body of a false block-if' do
      source = <<~GENIE
        setvariable hp 20
        if %hp > 50 then
        {
          echo healthy
        }
        echo done
        exit
      GENIE
      expect(run_script(source)[:echoes]).to eq(['done'])
    end
  end

  describe 'gosub / return' do
    it 'calls a subroutine and returns' do
      source = <<~GENIE
        put start
        gosub greet World
        put end
        exit
        greet:
        echo hello $1
        return
      GENIE
      result = run_script(source)
      expect(result[:commands]).to eq(%w[start end])
      expect(result[:echoes]).to eq(['hello World'])
    end
  end

  describe 'matchwait hunting loop' do
    it 'attacks on each kobold and stops after two' do
      source = <<~GENIE
        top:
        match found kobold
        match none nothing
        matchwait
        found:
        put attack
        counter add 1
        if %c >= 2 then goto done
        goto top
        none:
        goto top
        done:
        echo killed %c
        exit
      GENIE
      result = run_script(source, input_lines: ['a hungry kobold lurks', 'you wait', 'another kobold appears'])
      expect(result[:commands]).to eq(%w[attack attack])
      expect(result[:echoes]).to eq(['killed 2'])
    end
  end

  describe 'pause' do
    it 'resumes after the pause window elapses' do
      source = <<~GENIE
        put before
        pause 2
        put after
        exit
      GENIE
      expect(run_script(source)[:commands]).to eq(%w[before after])
    end
  end

  describe 'async actions' do
    it 'hijacks control to a label when a trigger fires during matchwait' do
      source = <<~GENIE
        action goto danger when you are bleeding
        match ok all clear
        matchwait
        danger:
        put flee
        exit
      GENIE
      result = run_script(source, input_lines: ['you are bleeding badly'])
      expect(result[:commands]).to eq(['flee'])
    end

    it 'stops firing a trigger after action remove (spellbook pattern)' do
      source = <<~GENIE
        action var flag 1 when you feel woozy
        action remove you feel woozy
        match ok all clear
        matchwait 1
        echo flag is %flag
        exit
      GENIE
      # The removed action must NOT fire, so %flag stays undefined (literal).
      result = run_script(source, input_lines: ['you feel woozy suddenly'])
      expect(result[:echoes]).to eq(['flag is %flag'])
    end
  end

  describe 'class-scoped actions' do
    # Defines a class-scoped action that sets %hits when it fires, waits (so input can
    # trigger it), then echoes %hits. When the action is suppressed %hits stays literal.
    def watch_result(setup)
      source = <<~GENIE
        #{setup}
        match ok all clear
        matchwait 1
        echo hits=%hits
        exit
      GENIE
      run_script(source, input_lines: ['ping'])[:echoes]
    end

    it 'fires a class-scoped action while its class is on (the default)' do
      expect(watch_result('action (watch) var hits fired when ^ping')).to eq(['hits=fired'])
    end

    it 'does not fire after action (class) off' do
      expect(watch_result("action (watch) var hits fired when ^ping\naction (watch) off")).to eq(['hits=%hits'])
    end

    it 'starts inactive when defined while its class is already off' do
      expect(watch_result("action (watch) off\naction (watch) var hits fired when ^ping")).to eq(['hits=%hits'])
    end

    it 're-enables with action (class) on' do
      setup = "action (watch) var hits fired when ^ping\naction (watch) off\naction (watch) on"
      expect(watch_result(setup)).to eq(['hits=fired'])
    end

    it 'accepts on/off synonyms (false then 1)' do
      setup = "action (watch) var hits fired when ^ping\naction (watch) false\naction (watch) 1"
      expect(watch_result(setup)).to eq(['hits=fired'])
    end

    it 'leaves other classes unaffected when one is toggled' do
      source = <<~GENIE
        action (a) var ha yes when ^ping
        action (b) var hb yes when ^ping
        action (a) off
        match ok all clear
        matchwait 1
        echo a=%ha b=%hb
        exit
      GENIE
      expect(run_script(source, input_lines: ['ping'])[:echoes]).to eq(['a=%ha b=yes'])
    end

    it 'lets a firing action disable its own class (the mapper idiom)' do
      source = <<~GENIE
        action (loop) var last $1;action (loop) off when ^ping(\\d)
        match ok all clear
        matchwait 1
        echo last=%last
        exit
      GENIE
      # First ping fires (last=1) then turns the class off; the second must not fire.
      expect(run_script(source, input_lines: %w[ping1 ping2])[:echoes]).to eq(['last=1'])
    end
  end

  describe 'reserved game-state globals' do
    it 'resolves $globals from the injected game state' do
      source = <<~GENIE
        echo hp is $health at $roomname
        exit
      GENIE
      result = run_script(source, game_state: { 'health' => '75', 'roomname' => 'Town Square' })
      expect(result[:echoes]).to eq(['hp is 75 at Town Square'])
    end
  end

  describe 'include' do
    it 'loads a helper file and gosubs into its label across files' do
      source = <<~GENIE
        gosub greetlib Sun
        echo back
        exit
        include lib.cmd
      GENIE
      loader = ->(name) { name == 'lib.cmd' ? "greetlib:\necho hi $1\nreturn" : nil }
      result = run_script(source, include_loader: loader)
      expect(result[:echoes]).to eq(['hi Sun', 'back'])
    end
  end

  describe 'front-end hooks' do
    it 'emits a genieHook for a front-end bar command' do
      source = <<~GENIE
        put #highlight line red {a kobold}
        exit
      GENIE
      result = run_script(source)
      expect(result[:hooks]).to eq([['highlight', {
        'kind' => 'line', 'whole_row' => true, 'color' => 'red',
                                     'pattern' => 'a kobold', 'case_sensitive' => false,
                                     'sound' => '', 'class' => '', 'active' => true
      }]])
      expect(result[:commands]).to be_empty
    end

    it 'sets a global variable via #var and reads it back' do
      source = <<~GENIE
        put #var mode hunt
        echo mode is $mode
        exit
      GENIE
      expect(run_script(source)[:echoes]).to eq(['mode is hunt'])
    end

    it 'evaluates an inline #evalmath over a reserved var into a #var (corpus pattern)' do
      source = <<~GENIE
        put #var hpsnapshot #evalmath ($health + 5)
        echo snapshot is $hpsnapshot
        exit
      GENIE
      result = run_script(source, game_state: { 'health' => '75' })
      expect(result[:echoes]).to eq(['snapshot is 80'])
    end

    it 'emits structured class + trigger hooks like commoncombattriggers.cmd' do
      source = <<~GENIE
        put #class recovery on
        put #trigger {^You're unconscious} {#send .uncon} {recovery}
        put #class bgstart off
        exit
      GENIE
      result = run_script(source)
      expect(result[:hooks]).to eq([
                                     ['class', { 'name' => 'recovery', 'enabled' => true }],
                                     ['trigger', { 'pattern' => "^You're unconscious",
                                                   'commands' => '#send .uncon', 'class' => 'recovery' }],
                                     ['class', { 'name' => 'bgstart', 'enabled' => false }]
                                   ])
      expect(result[:commands]).to be_empty
    end

    it 'aborts a pure-FE goto loop via the per-run script-timeout deadline' do
      # A goto loop that only emits hooks never trips the send-history guard; the
      # wall-clock deadline (Genie iScriptTimeout) must catch it. Clock advances 1s
      # per call so the 5s deadline trips deterministically without real waiting.
      ticking = [0.0]
      source = <<~GENIE
        spin:
        put #class churn on
        goto spin
      GENIE
      result = run_script(source, clock: -> { ticking[0] += 1.0 })
      expect(result[:commands]).to be_empty
      expect(result[:echoes].last).to match(/Possible infinite loop/)
      # It emitted some class hooks before the deadline, then stopped (did not hang).
      expect(result[:hooks].map(&:first).uniq).to eq(['class'])
    end

    it 'does not trip the wall-clock deadline while a game send blocks on a long RT' do
      # Regression: LichGamePort#send_command calls waitrt? and BLOCKS for the whole
      # roundtime before sending. A 20s invoke / long barrage would then push the next
      # runaway check past the 5s deadline and falsely kill the script mid-combat.
      # Model that block by advancing the clock 6s (> the 5s deadline) inside each send;
      # all three sequential sends must still go through, with no timeout.
      clock_ref = [0.0]
      sent = []
      rt_game = Object.new.tap do |g|
        g.define_singleton_method(:send_command) do |text|
          sent << text
          clock_ref[0] += 6.0 # simulate a 6s roundtime block inside the send (waitrt?)
        end
      end
      echoes = []
      no_hooks = Object.new.tap { |o| o.define_singleton_method(:emit) { |_op, _p| } }
      source = <<~GENIE
        put invoke my sword
        put retreat
        put sheath my sword
        exit
      GENIE
      Lich::Genie::Engine.run(
        source, name: 'test', game: rt_game, input: FakeInput.new([], clock_ref),
        echo: ->(text) { echoes << text }, hooks: no_hooks,
        launch: ->(_n, _a) {}, mover: ->(_r) {}, clock: -> { clock_ref[0] }
      )
      expect(sent).to eq(['invoke my sword', 'retreat', 'sheath my sword'])
      expect(echoes.join).not_to match(/Possible infinite loop/)
    end

    it 'does not trip the send-history guard for a combat loop that waits each cycle' do
      # Regression: a loop that sends a command then WAITS (matchwait/pause) every
      # cycle is game-responsive, not a runaway -- but 40 sends inside the rolling 10s
      # window used to trip the 30-total send guard. A wait resumes into a fresh
      # run_rows, which now clears the send history, so only a wait-LESS loop keeps
      # accumulating. Here 40 attacks paced by a 0.1s pause must all fire.
      source = <<~GENIE
        setvariable i 0
        top:
        put attack
        math i add 1
        pause 0.1
        if %i < 40 then goto top
        exit
      GENIE
      result = run_script(source)
      expect(result[:commands].length).to eq(40)
      expect(result[:commands].uniq).to eq(['attack'])
      expect(result[:echoes].join).not_to match(/Possible infinite loop/)
    end

    it 'launches another script with put .name (Genie ScriptChar), not a game command' do
      source = <<~GENIE
        put .helper foo bar
        exit
      GENIE
      result = run_script(source)
      expect(result[:launches]).to eq([['helper', 'foo bar']])
      expect(result[:commands]).to be_empty
    end

    it 'launches a script with send .name and with no args' do
      source = <<~GENIE
        send .setup
        exit
      GENIE
      result = run_script(source)
      expect(result[:launches]).to eq([['setup', '']])
      expect(result[:commands]).to be_empty
    end

    it "launches a script held in a variable (Tirost's `put \$magicloop` = `.sc`)" do
      # $magicloop = ".sc"; a guarded `put $magicloop` must (a) evaluate the guard
      # true and (b) launch the .sc script, not send ".sc" to the game.
      source = <<~GENIE
        $magicloop = .sc
        if $magicloop != 0 then put $magicloop
        exit
      GENIE
      result = run_script(source)
      expect(result[:launches]).to eq([['sc', '']])
      expect(result[:commands]).to be_empty
    end

    it 'still sends ordinary commands to the game' do
      source = <<~GENIE
        put attack kobold
        exit
      GENIE
      result = run_script(source)
      expect(result[:commands]).to eq(['attack kobold'])
      expect(result[:launches]).to be_empty
    end

    it 'routes #commands issued via send and do (not only put), like Genie ParseCommand' do
      # send #class / do #var must route through the command router, NOT go to the
      # game as literal text. Tester's #class toggles rely on this.
      source = <<~GENIE
        send #class combat on
        do #var mode hunt
        echo mode is $mode
        exit
      GENIE
      result = run_script(source)
      expect(result[:hooks]).to eq([['class', { 'name' => 'combat', 'enabled' => true }]])
      expect(result[:echoes]).to eq(['mode is hunt'])
      expect(result[:commands]).to be_empty # nothing leaked to the game
    end

    it 'launches a script via send .name and do .name' do
      result = run_script("send .helper\ndo .other\nexit")
      expect(result[:launches]).to eq([['helper', ''], ['other', '']])
      expect(result[:commands]).to be_empty
    end

    it 'routes #goto <room> to the mover, not the game' do
      source = <<~GENIE
        put #goto 93
        exit
      GENIE
      result = run_script(source)
      expect(result[:moves]).to eq(['93'])
      expect(result[:commands]).to be_empty
    end

    it 'drives the automove pattern: #goto then matchwait on the arrival line' do
      # Mirrors mastercraft automove: set matches, #goto, matchwait for the mapper
      # result. The mover walks and (in Lich) injects YOU HAVE ARRIVED downstream;
      # here we pre-queue that line to stand in for the injected shim message.
      source = <<~GENIE
        top:
        match arrived YOU HAVE ARRIVED
        match failed YOU HAVE FAILED
        put #goto 93
        matchwait
        arrived:
        echo made it to %c
        exit
        failed:
        echo lost
        exit
      GENIE
      moves = []
      result = run_script(source, input_lines: ['YOU HAVE ARRIVED'], mover: ->(r) { moves << r })
      expect(moves).to eq(['93'])
      expect(result[:echoes]).to eq(['made it to %c'])
    end

    it 'routes a #command fired from within an async action' do
      source = <<~GENIE
        action #class panic on when you are bleeding
        match ok all clear
        matchwait 1
        exit
      GENIE
      result = run_script(source, input_lines: ['you are bleeding badly'])
      expect(result[:hooks]).to eq([['class', { 'name' => 'panic', 'enabled' => true }]])
    end
  end

  describe 'waiteval + richer action bodies (P2 gaps)' do
    it 'waiteval blocks until its condition becomes true (re-evaluated per line)' do
      # A per-line action bumps %n; waiteval was a SILENT no-op before, racing past.
      source = <<~GENIE
        %n = 0
        action math n add 1 when .
        waiteval (%n > 2)
        echo done %n
        exit
      GENIE
      result = run_script(source, input_lines: %w[a b c d])
      expect(result[:echoes]).to eq(['done 3'])
    end

    it 'runs math/if inside action bodies instead of sending them to the game' do
      source = <<~GENIE
        %n = 0
        action if (1 = 1) then math n add 5 when ^bump
        match done ok
        matchwait 1
        done:
        echo n=%n
        exit
      GENIE
      result = run_script(source, input_lines: %w[bump ok])
      expect(result[:echoes]).to eq(['n=5'])
      expect(result[:commands]).to be_empty # math/if handled locally, nothing leaked to the game
    end
  end

  # Runtime crash hardening surfaced by the corpus execute-sweep: three unguarded
  # sites that would raise on a live game line. Genie guards all three (Script.cs).
  describe 'match/waitfor robustness (runtime crash hardening)' do
    it 'aborts gracefully when a match targets an undefined label' do
      source = "match hit a goblin\nmatchwait\nexit\n"
      result = run_script(source, input_lines: ['you see a goblin here'])
      expect(result[:echoes].join).to match(/Unknown label from MATCH command: hit/)
    end

    it 'does not crash on a malformed matchre pattern' do
      source = "matchre done (unbalanced\nmatchwait 1\ndone:\necho ok\nexit\n"
      expect { run_script(source, input_lines: ['some line']) }.not_to raise_error
    end

    it 'does not crash on a malformed waitforre pattern' do
      source = "waitforre (nope\nexit\n"
      expect { run_script(source, input_lines: ['a line']) }.not_to raise_error
    end
  end
end
