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
end
