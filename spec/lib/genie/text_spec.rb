# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Text do
  describe '.safe_split' do
    it 'splits on the separator' do
      expect(described_class.safe_split('a;b;c')).to eq(%w[a b c])
    end

    it 'does not split on a separator inside braces' do
      expect(described_class.safe_split('#if {a = 1} {put x;put y};done'))
        .to eq(['#if {a = 1} {put x;put y}', 'done'])
    end

    it 'does not split inside quotes' do
      expect(described_class.safe_split('say "hi; there";bow')).to eq(['say "hi; there"', 'bow'])
    end

    it 'leaves braces and quotes intact (unlike parse_args)' do
      expect(described_class.safe_split('{a};{b}')).to eq(['{a}', '{b}'])
    end

    it 'keeps a trailing empty segment for a dangling separator' do
      expect(described_class.safe_split('a;')).to eq(['a', ''])
    end

    it 'preserves an escaped separator' do
      expect(described_class.safe_split('a\\;b;c')).to eq(['a\\;b', 'c'])
    end
  end
end
