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

    it 'tolerates thousands separators leniently in the integer part (like .NET)' do
      expect(described_class.string_to_double('1,000')).to eq(1000.0)
      expect(described_class.string_to_double('1,23')).to eq(123.0)     # grouping not validated
      expect(described_class.string_to_double('1,2,3.5')).to eq(123.5)
      expect(described_class.string_to_double('1,,2')).to eq(12.0)      # doubled comma ok
      expect(described_class.string_to_double('5,')).to eq(5.0)         # trailing ok
    end

    it 'returns -1.0 (not 0) on empty/nil/parse failure' do
      expect(described_class.string_to_double(nil)).to eq(-1.0)
      expect(described_class.string_to_double('')).to eq(-1.0)
      expect(described_class.string_to_double('   ')).to eq(-1.0)
      expect(described_class.string_to_double('abc')).to eq(-1.0)
      expect(described_class.string_to_double('5px')).to eq(-1.0)
    end

    # These are the divergences the old Float()-based parse got wrong: Ruby's Float()
    # accepts hex/underscores/"Infinity" and misparses a comma after the decimal, none
    # of which .NET's double.Parse(en-US) does. All confirmed against the s2d oracle.
    it 'rejects forms .NET does not accept (were wrongly parsed before)' do
      expect(described_class.string_to_double('0x1F')).to eq(-1.0)  # Ruby Float would give 31.0
      expect(described_class.string_to_double('1_000')).to eq(-1.0) # Ruby Float would give 1000.0
      expect(described_class.string_to_double('Infinity')).to eq(-1.0)
      expect(described_class.string_to_double('1.5,3')).to eq(-1.0) # comma after decimal
      expect(described_class.string_to_double(',5')).to eq(-1.0)    # leading comma
      expect(described_class.string_to_double('+-5')).to eq(-1.0)
      expect(described_class.string_to_double('1.2.3')).to eq(-1.0)
    end

    it 'parses "NaN" case-insensitively (with optional sign), like .NET' do
      expect(described_class.string_to_double('NaN').nan?).to be(true)
      expect(described_class.string_to_double('nan').nan?).to be(true)
      expect(described_class.string_to_double('-nan').nan?).to be(true)
    end

    it 'parses leading-dot / trailing-dot / signed fractions and exponents' do
      expect(described_class.string_to_double('.5')).to eq(0.5)
      expect(described_class.string_to_double('5.')).to eq(5.0)
      expect(described_class.string_to_double('+.5')).to eq(0.5)
      expect(described_class.string_to_double('1E+5')).to eq(100_000.0)
      expect(described_class.string_to_double('1e999')).to eq(Float::INFINITY)
      expect(described_class.string_to_double('.')).to eq(-1.0)
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

    # Value parity with VB Conversions.ToInteger is exact (verified via the `toint`
    # oracle over 20k inputs). DELIBERATE divergence: where C# would THROW -- a
    # non-numeric string or a value beyond Int32 -- this helper stays lenient (-1 for
    # unparseable via string_to_double; a Ruby arbitrary-precision Integer for large
    # values). Genie's throw is reconciled at the call sites (substr clamps -- the
    # documented substr-out-of-range item; `\` overflow-checks to Int64 in math_eval),
    # so we match Genie where a value is produced and don't crash on the edges.
    it 'is lenient (does not raise) where Conversions.ToInteger would throw' do
      expect(described_class.to_integer('abc')).to eq(-1) # C#: InvalidCastException
      expect(described_class.to_integer('3000000000')).to eq(3_000_000_000) # C#: OverflowException
    end
  end

  describe '.to_long' do
    it 'banker\'s-rounds like to_integer and shares its value parity with Conversions.ToLong' do
      expect(described_class.to_long('4.5')).to eq(4)
      expect(described_class.to_long(2.5)).to eq(2)
      expect(described_class.to_long('1,000')).to eq(1000)
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

    it 'handles special values .NET-style (Unicode infinity, signed zero)' do
      infinity = [0x221E].pack('U') # U+221E, kept out of source per AsciiOnlySource cop
      expect(described_class.format_double(Float::NAN)).to eq('NaN')
      expect(described_class.format_double(Float::INFINITY)).to eq(infinity)
      expect(described_class.format_double(-Float::INFINITY)).to eq("-#{infinity}")
      expect(described_class.format_double(-0.0)).to eq('-0')
    end

    # Byte-exact with .NET double.ToString(), verified via the Genie4 differential fuzzer
    # (genie-port-lab/reference/fuzz_format.rb): fixed-point for exponent in [-4, 16],
    # scientific otherwise, shortest round-trip digits throughout.
    it 'matches .NET formatting at magnitude boundaries' do
      expect(described_class.format_double(1e16)).to eq('10000000000000000')  # fixed
      expect(described_class.format_double(1e17)).to eq('1E+17')              # -> scientific
      expect(described_class.format_double(1e-4)).to eq('0.0001')            # fixed
      expect(described_class.format_double(1e-5)).to eq('1E-05')             # -> scientific
      expect(described_class.format_double(8.7**18)).to eq('81535464022366910') # shortest, not exact-int
      expect(described_class.format_double(22.0 / 7)).to eq('3.142857142857143')
    end
  end
end
