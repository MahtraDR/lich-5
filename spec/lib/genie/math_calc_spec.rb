# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::MathCalc do
  describe '.calc' do
    it 'handles the basic operations and their symbol aliases' do
      expect(described_class.calc(10, 'add 5')).to eq(15.0)
      expect(described_class.calc(10, '+ 5')).to eq(15.0)
      expect(described_class.calc(10, 'subtract 4')).to eq(6.0)
      expect(described_class.calc(10, 'sub 4')).to eq(6.0)
      expect(described_class.calc(10, 'substract 4')).to eq(6.0) # Genie's misspelling
      expect(described_class.calc(10, 'set 3')).to eq(3.0)
      expect(described_class.calc(10, '= 3')).to eq(3.0)
      expect(described_class.calc(10, 'multiply 3')).to eq(30.0)
      expect(described_class.calc(10, 'divide 4')).to eq(2.5)
    end

    it 'clamps negative arguments to 0 (Genie quirk)' do
      expect(described_class.calc(10, 'subtract -5')).to eq(10.0)
      expect(described_class.calc(10, 'set -5')).to eq(0.0)
      expect(described_class.calc(10, 'add -5')).to eq(10.0)
    end

    it 'takes remainder with the sign of the dividend' do
      expect(described_class.calc(-5, 'mod 3')).to eq(-2.0)
      expect(described_class.calc(5, 'modulus 3')).to eq(2.0)
      expect(described_class.calc(5, '% 3')).to eq(2.0)
    end

    it 'returns 0 for mod when the current value is 0' do
      expect(described_class.calc(0, 'mod 3')).to eq(0.0)
    end

    it 'yields Infinity for divide-by-zero (matching .NET double math)' do
      expect(described_class.calc(10, 'divide 0')).to eq(Float::INFINITY)
    end

    it 'raises on an unknown operation' do
      expect { described_class.calc(10, 'frobnicate 5') }.to raise_error(Lich::Genie::Error)
    end
  end
end
