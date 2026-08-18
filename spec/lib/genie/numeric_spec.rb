# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Numeric do
  describe '.string_to_double' do
    it 'parses valid numbers' do
      expect(described_class.string_to_double('5')).to eq(5.0)
      expect(described_class.string_to_double(' 5.5 ')).to eq(5.5)
      expect(described_class.string_to_double('-3')).to eq(-3.0)
      expect(described_class.string_to_double('1e3')).to eq(1000.0)
    end

    it 'tolerates thousands separators' do
      expect(described_class.string_to_double('1,000')).to eq(1000.0)
    end

    it 'returns -1.0 (not 0) on empty/nil/parse failure' do
      expect(described_class.string_to_double(nil)).to eq(-1.0)
      expect(described_class.string_to_double('')).to eq(-1.0)
      expect(described_class.string_to_double('   ')).to eq(-1.0)
      expect(described_class.string_to_double('abc')).to eq(-1.0)
      expect(described_class.string_to_double('5px')).to eq(-1.0)
    end
  end

  describe '.numeric?' do
    it 'reports whether the whole trimmed string is a number' do
      expect(described_class.numeric?('42')).to be(true)
      expect(described_class.numeric?(' 3.14 ')).to be(true)
      expect(described_class.numeric?('1 + 1')).to be(false)
      expect(described_class.numeric?('')).to be(false)
    end
  end

  describe '.to_integer' do
    it 'uses banker\'s rounding (half to even)' do
      expect(described_class.to_integer(2.5)).to eq(2)
      expect(described_class.to_integer(3.5)).to eq(4)
      expect(described_class.to_integer(-2.5)).to eq(-2)
      expect(described_class.to_integer('4.5')).to eq(4)
    end
  end

  describe '.format_double' do
    it 'prints integers without a decimal point' do
      expect(described_class.format_double(5.0)).to eq('5')
      expect(described_class.format_double(-12.0)).to eq('-12')
      expect(described_class.format_double(0.0)).to eq('0')
    end

    it 'prints non-integers in shortest form' do
      expect(described_class.format_double(0.5)).to eq('0.5')
      expect(described_class.format_double(3.14)).to eq('3.14')
    end

    it 'handles special values .NET-style' do
      expect(described_class.format_double(Float::NAN)).to eq('NaN')
      expect(described_class.format_double(Float::INFINITY)).to eq('Infinity')
      expect(described_class.format_double(-Float::INFINITY)).to eq('-Infinity')
    end
  end
end
