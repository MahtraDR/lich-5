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
  def run_script(source, input_lines: [], game_state: nil, include_loader: nil)
    clock = [0.0]
    game = FakeGame.new
    echoes = []
    hooks = []
    hook_sink = Object.new.tap do |o|
      o.define_singleton_method(:emit) { |op, payload| hooks << [op, payload] }
    end
    Lich::Genie::Engine.run(
      source,
      name: 'test',
      game_state: game_state,
      include_loader: include_loader,
      game: game,
      input: FakeInput.new(input_lines, clock),
      echo: ->(text) { echoes << text },
      hooks: hook_sink,
      clock: -> { clock[0] }
    )
    { commands: game.commands, echoes: echoes, hooks: hooks }
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
        put #highlight red kobold
        exit
      GENIE
      result = run_script(source)
      expect(result[:hooks]).to eq([['highlight', { 'raw' => 'red kobold' }]])
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
  end
end
