# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Triggers do
  subject(:triggers) { described_class.new }

  # Collect what would fire for a line.
  def fired(line)
    out = []
    triggers.apply(line) { |commands, captures| out << [commands, captures] }
    out
  end

  it 'fires an active trigger and passes regex captures' do
    triggers.add('You hit (\\w+) for (\\d+)', 'echo hit $1 for $2')
    expect(fired('You hit kobold for 25')).to eq([['echo hit $1 for $2', %w[kobold 25]]])
  end

  it 'does not fire a non-matching line' do
    triggers.add('^You die', 'put stand')
    expect(fired('You feel fine')).to eq([])
  end

  it 'fires multiple matching triggers' do
    triggers.add('kobold', 'put attack')
    triggers.add('kobold', 'echo seen') # same pattern replaces
    triggers.add('goblin', 'put flee')
    expect(fired('a kobold and a goblin').map(&:first)).to contain_exactly('echo seen', 'put flee')
  end

  describe 'class gating' do
    it 'does not fire a trigger whose class is off, and resumes when on' do
      triggers.add('rest', 'put stand', klass: 'combat')
      triggers.set_class('combat', false)
      expect(fired('you rest')).to eq([])
      triggers.set_class('combat', true)
      expect(fired('you rest')).to eq([['put stand', []]])
    end

    it 'always fires a classless trigger' do
      triggers.add('rest', 'put stand')
      triggers.set_class('combat', false)
      expect(fired('you rest')).to eq([['put stand', []]])
    end

    it 'is case-insensitive on the class name' do
      triggers.add('rest', 'put stand', klass: 'Combat')
      triggers.set_class('combat', false)
      expect(fired('you rest')).to eq([])
    end
  end

  describe 'management' do
    it 'removes a trigger by pattern (#untrigger)' do
      triggers.add('spam', 'echo x')
      triggers.remove('spam')
      expect(fired('spam spam')).to eq([])
    end

    it 'clears all triggers' do
      triggers.add('a', 'echo a')
      triggers.add('b', 'echo b')
      triggers.clear
      expect(triggers.count).to eq(0)
    end

    it 'lists triggers with class + active state' do
      triggers.add('a', 'put x', klass: 'combat')
      triggers.set_class('combat', false)
      expect(triggers.list).to eq([{ 'pattern' => 'a', 'class' => 'combat', 'active' => false, 'commands' => 'put x' }])
    end

    it 'falls back to a literal match for an invalid regex' do
      triggers.add('what (is', 'echo hi')
      expect(fired('what (is this')).to eq([['echo hi', []]])
    end
  end

  describe '#diagnose' do
    it 'reports matching triggers with class + active state, without firing' do
      triggers.add('^You gesture', 'put x', klass: 'spellcast')
      triggers.add('^You tap', 'put y', klass: 'harness')
      triggers.set_class('spellcast', false) # class off -> would not fire

      result = triggers.diagnose('You gesture.')
      expect(result).to eq([{ 'pattern' => '^You gesture', 'class' => 'spellcast', 'active' => false }])
    end

    it 'returns an empty array when nothing matches' do
      triggers.add('^You gesture', 'put x')
      expect(triggers.diagnose('nothing here')).to eq([])
    end
  end
end
