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

  # Every expected value below was confirmed against Genie4's real Utility.ParseArgs
  # via the differential oracle (genie-port-lab/oracle, `parseargs` mode). These are
  # regressions for divergences the pre-port char-buffer implementation got wrong.
  describe '.parse_args' do
    it 'splits on spaces and collapses leading/trailing/multiple spaces' do
      expect(described_class.parse_args('a b c')).to eq(%w[a b c])
      expect(described_class.parse_args('  a   b  ')).to eq(%w[a b])
    end

    it 'returns [] for an empty string' do
      expect(described_class.parse_args('')).to eq([])
    end

    it 'strips wrapping double quotes but not interior/unbalanced ones' do
      expect(described_class.parse_args('"hello world"')).to eq(['hello world'])
      expect(described_class.parse_args('a"b"c')).to eq(['a"b"c'])
      expect(described_class.parse_args('"hello')).to eq(['"hello'])
    end

    it 'strips wrapping single quotes but not interior/unbalanced ones' do
      expect(described_class.parse_args("'hello'")).to eq(['hello'])
      expect(described_class.parse_args("a'b")).to eq(["a'b"])
    end

    it 'strips both wrapping layers when a token is single- and double-quoted' do
      expect(described_class.parse_args(%q("'x'"))).to eq(['x'])
    end

    it 'raises on a lone-quote token (matches Genie AddArrayItem throw)' do
      expect { described_class.parse_args('"') }.to raise_error(Lich::Genie::Error)
      expect { described_class.parse_args("'") }.to raise_error(Lich::Genie::Error)
      expect { described_class.parse_args('a "') }.to raise_error(Lich::Genie::Error)
    end

    it 'treats a pair of quotes as one empty token' do
      expect(described_class.parse_args('""')).to eq([''])
      expect(described_class.parse_args("''")).to eq([''])
    end

    it 'keeps backslash escapes literally and does not split on an escaped space' do
      expect(described_class.parse_args('a\\ b')).to eq(['a\\ b'])
      expect(described_class.parse_args('a\\')).to eq(['a\\'])
    end

    it 'keeps a backslash-escaped brace/quote and the backslash itself' do
      expect(described_class.parse_args('a\\{b}')).to eq(['a\\{b}'])
      expect(described_class.parse_args('\\{a b\\}')).to eq(['\\{a', 'b\\}'])
    end

    it 'does not treat tab as a delimiter (Genie splits on space only)' do
      expect(described_class.parse_args("a\tb")).to eq(["a\tb"])
    end

    it 'strips outer braces, keeps inner, and treats a brace as a token boundary' do
      expect(described_class.parse_args('{a b} c')).to eq(['a b', 'c'])
      expect(described_class.parse_args('{a{b}c}')).to eq(['a{b}c'])
      expect(described_class.parse_args('x{y}z')).to eq(%w[x y z])
      expect(described_class.parse_args('{a}{b}')).to eq(%w[a b])
    end

    it 'yields one empty token for empty braces' do
      expect(described_class.parse_args('{}')).to eq([''])
    end

    it 'lets a stray } drive depth negative so later spaces stop splitting' do
      expect(described_class.parse_args('a}b c')).to eq(['a}b c'])
    end

    it 'keeps quote toggling active inside braces (a } inside quotes does not close)' do
      expect(described_class.parse_args('{a"}"b}')).to eq(['a"}"b'])
    end

    it 'unclosed open brace keeps its literal brace and stops splitting' do
      expect(described_class.parse_args('a{b')).to eq(['a', '{b'])
      expect(described_class.parse_args('{a b')).to eq(['{a b'])
    end

    it 'replaces _ with space in every token but the first when underscore flag set' do
      expect(described_class.parse_args('a_b c_d', treat_underscore_as_space: true))
        .to eq(['a_b', 'c d'])
      expect(described_class.parse_args('a_b c_d')).to eq(%w[a_b c_d])
    end
  end
end
