# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::CommandRouter do
  let(:vars) { Lich::Genie::Variables.new }
  let(:evaluator) { Lich::Genie::Eval.new(globals: globals_adapter) }
  let(:globals_adapter) do
    Object.new.tap { |o| o.define_singleton_method(:key?) { |name| vars.global_key?(name) } }
  end
  let(:echoes) { [] }
  let(:sends) { [] }
  let(:hooks) { [] }
  let(:hook_sink) do
    collected = hooks
    Object.new.tap { |o| o.define_singleton_method(:emit) { |op, payload| collected << [op, payload] } }
  end
  let(:moves) { [] }
  let(:router) do
    described_class.new(
      vars: vars, eval: evaluator, hooks: hook_sink,
      echo: ->(t) { echoes << t }, send: ->(t) { sends << t },
      mover: ->(room) { moves << room }
    )
  end

  describe 'engine-side variables' do
    it 'sets and persists a #var' do
      router.route('#var mode hunt')
      expect(vars.global_get('mode')).to eq('hunt')
    end

    it 'evaluates an inline #evalmath in a #var value (the 275x corpus pattern)' do
      router.route('#var timer #evalmath (100 + 20)')
      expect(vars.global_get('timer')).to eq('120')
    end

    it 'evaluates an inline #eval in a #var value' do
      router.route('#var flag #eval (3 > 1)')
      expect(vars.global_get('flag')).to eq('1')
    end

    it 'strips braces around a #var value like Genie ParseArgs' do
      router.route('#var greeting {hello there}')
      expect(vars.global_get('greeting')).to eq('hello there')
    end

    it '#tvar does not persist but is readable in-session' do
      router.route('#tvar scratch 7')
      expect(vars.global_get('scratch')).to eq('7')
    end

    it 'deletes a var with #unvar' do
      router.route('#var doomed 1')
      router.route('#unvar doomed')
      expect(vars.global_get('doomed')).to be_nil
    end
  end

  describe 'engine-side computation' do
    it 'sends the result of a top-level #evalmath to the game' do
      router.route('#evalmath (6 * 7)')
      expect(sends).to eq(['42'])
    end

    it '#math applies keyword arithmetic into a global' do
      router.route('#var n 5')
      router.route('#math n add 10')
      expect(vars.global_get('n')).to eq('15')
    end

    it '#if routes the then-branch when true and the else-branch when false' do
      router.route('#if {1 > 0} {#var picked then} {#var picked else}')
      expect(vars.global_get('picked')).to eq('then')
      router.route('#if {1 > 2} {#var picked then} {#var picked else}')
      expect(vars.global_get('picked')).to eq('else')
    end

    it '#if sends a plain then-branch to the game' do
      router.route('#if {1 = 1} {attack} {flee}')
      expect(sends).to eq(['attack'])
    end

    it '#goto routes to the mover (not the game); #mapper is a no-op' do
      router.route('#goto 93')
      router.route('#mapper reset')
      expect(moves).to eq(['93'])
      expect(sends).to be_empty
      expect(hooks).to be_empty
    end
  end

  describe 'engine-side echo' do
    it 'echoes plain text locally' do
      router.route('#echo hello world')
      expect(echoes).to eq(['hello world'])
      expect(hooks).to be_empty
    end

    it 'routes #echo >window to a front-end echo hook' do
      router.route('#echo >thoughts pathing to bank')
      expect(hooks).to eq([['echo', { 'window' => 'thoughts', 'text' => 'pathing to bank' }]])
    end
  end

  describe 'front-end effects (structured payloads)' do
    it '#class name on|off emits a structured enable/disable' do
      router.route('#class recovery on')
      router.route('#class bgstart off')
      expect(hooks).to eq([
                            ['class', { 'name' => 'recovery', 'enabled' => true }],
                            ['class', { 'name' => 'bgstart', 'enabled' => false }]
                          ])
    end

    it '#class +a -b toggles multiple classes' do
      router.route('#class +combat -idle')
      expect(hooks).to eq([
                            ['class', { 'name' => 'combat', 'enabled' => true }],
                            ['class', { 'name' => 'idle', 'enabled' => false }]
                          ])
    end

    it '#trigger emits pattern/commands/class' do
      router.route('#trigger {^You feel ready} {#var dbtimer 0;#class db off} {db}')
      expect(hooks).to eq([['trigger', {
        'pattern'  => '^You feel ready',
        'commands' => '#var dbtimer 0;#class db off',
        'class'    => 'db'
      }]])
    end

    it '#trigger clear emits a clear action' do
      router.route('#trigger clear')
      expect(hooks).to eq([['trigger', { 'action' => 'clear' }]])
    end

    it '#trigger (bare) and #trigger list emit a list action' do
      router.route('#trigger')
      router.route('#trigger list')
      expect(hooks).to eq([['trigger', { 'action' => 'list' }], ['trigger', { 'action' => 'list' }]])
    end

    it '#untrigger emits a removal by pattern' do
      router.route('#untrigger {^You feel ready}')
      expect(hooks).to eq([['untrigger', { 'pattern' => '^You feel ready' }]])
    end

    it '#gag and #sub emit normalized events (sink applies Model A downstream)' do
      router.route('#gag {a boring line} {spam}')
      router.route('#sub {kobold} {KOBOLD}')
      expect(hooks).to eq([
                            ['gag', { 'pattern' => 'a boring line', 'class' => 'spam' }],
                            ['substitute', { 'pattern' => 'kobold', 'replacement' => 'KOBOLD', 'class' => '' }]
                          ])
    end

    it '#highlight (line) emits full self-describing payload' do
      router.route('#highlight line yellow {a hungry kobold}')
      expect(hooks).to eq([['highlight', {
        'kind' => 'line', 'whole_row' => true, 'color' => 'yellow',
                            'pattern' => 'a hungry kobold', 'case_sensitive' => false,
                            'sound' => '', 'class' => '', 'active' => true
      }]])
    end

    it '#highlight regex normalizes kind and defaults active=true' do
      router.route('#highlight regexp red {^You die} true alarm.wav combat')
      _, p = hooks.first
      expect(p['kind']).to eq('regex')
      expect(p['whole_row']).to be(false)
      expect(p['case_sensitive']).to be(true)
      expect(p['sound']).to eq('alarm.wav')
      expect(p['class']).to eq('combat')
      expect(p['active']).to be(true)
    end

    it '#highlight clear emits a clear event' do
      router.route('#highlight clear')
      expect(hooks).to eq([['highlight', { 'clear' => true }]])
    end

    it 'emits macro/alias/preset/name pairs' do
      router.route('#macro {ctrl+a} {attack}')
      router.route('#alias {kk} {attack kobold}')
      router.route('#preset {roomname} {#00ff00}')
      router.route('#name combat {a goblin} {an orc}')
      expect(hooks).to eq([
                            ['macro', { 'key' => 'ctrl+a', 'command' => 'attack' }],
                            ['alias', { 'pattern' => 'kk', 'command' => 'attack kobold' }],
                            ['preset', { 'name' => 'roomname', 'value' => '#00ff00' }],
                            ['name', { 'name' => 'a goblin', 'value' => 'combat' }],
                            ['name', { 'name' => 'an orc', 'value' => 'combat' }]
                          ])
    end

    it 'emits window/playsound/link/image/flash payloads' do
      router.route('#window add {thoughts}')
      router.route('#playsound alert.wav')
      router.route('#playsound stop')
      router.route('#link >map {bank} {go bank}')
      router.route('#image >combat w:64 h:32 sword.png')
      router.route('#flash')
      expect(hooks).to eq([
                            ['window', { 'action' => 'add', 'name' => 'thoughts',
                                         'width' => 300, 'height' => 200, 'top' => 10, 'left' => 10 }],
                            ['playsound', { 'file' => 'alert.wav' }],
                            ['playsound', { 'stop' => true }],
                            ['link', { 'window' => 'map', 'text' => 'bank', 'command' => 'go bank' }],
                            ['image', { 'filename' => 'sword.png', 'window' => 'combat',
                                        'width' => 64, 'height' => 32 }],
                            ['flash', {}]
                          ])
    end

    it 'falls back to tokenized {args, raw} for a genuinely unknown op' do
      router.route('#frobnicate {a} {b}')
      expect(hooks).to eq([['frobnicate', { 'args' => %w[a b], 'raw' => '{a} {b}' }]])
    end
  end
end
