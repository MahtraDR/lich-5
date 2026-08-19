# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::TriggerRunner do
  let(:vars) { Lich::Genie::Variables.new(game_state: { 'unixtime' => '1000' }) }
  let(:evaluator) do
    globals = Object.new
    globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
    Lich::Genie::Eval.new(globals: globals)
  end
  let(:sent) { [] }
  let(:launched) { [] }
  let(:hooks) { [] }
  let(:game) { Object.new.tap { |o| s = sent; o.define_singleton_method(:send_command) { |t| s << t } } }
  let(:hook_sink) { Object.new.tap { |o| h = hooks; o.define_singleton_method(:emit) { |op, pl| h << [op, pl] } } }
  let(:runner) do
    described_class.new(
      vars: vars, eval: evaluator, game: game,
      launch: ->(name, args) { launched << [name, args] },
      hooks: hook_sink, echo: ->(_t) {}
    )
  end

  it 'sends a plain game command with captures substituted' do
    runner.fire('put attack $1', ['kobold'])
    expect(sent).to eq(['put attack kobold'])
  end

  it 'runs a #command (updates a global via #var)' do
    runner.fire('#var mode hunting', [])
    expect(vars.global_get('mode')).to eq('hunting')
  end

  it 'evaluates an inline #evalmath over a reserved var (the corpus pattern)' do
    runner.fire('#var deadline #evalmath ($unixtime + 20)', [])
    expect(vars.global_get('deadline')).to eq('1020')
  end

  it 'runs several ;-separated commands, not splitting inside braces' do
    runner.fire('#var a 1;#if {1 = 1} {#var b 2};put done', [])
    expect(vars.global_get('a')).to eq('1')
    expect(vars.global_get('b')).to eq('2')
    expect(sent).to eq(['put done'])
  end

  it 'launches a script when a command starts with the script char' do
    runner.fire('.helper $1', ['now'])
    expect(launched).to eq([['helper', 'now']])
    expect(sent).to be_empty
  end

  it 'emits a class toggle hook from within a trigger body' do
    runner.fire('#class combat off', [])
    expect(hooks).to eq([['class', { 'name' => 'combat', 'enabled' => false }]])
  end
end
