# frozen_string_literal: true

require_relative '../../../lib/genie'

# Property / invariant specs: each checks a structural property over MANY random
# inputs (not hand-picked examples), catching bugs the example specs miss.
# Seeded for determinism. Exhaustive exploration lives in
# genie-port-lab/reference/property_invariants.rb; this is the CI regression subset.
RSpec.describe 'Genie pure-helper invariants' do
  # Per-example iteration count (a method, not a constant, to stay out of
  # Lint/ConstantDefinitionInBlock). ~0.2s total; the exhaustive runner is separate.
  def iter = 3000

  before { srand(20_260_824) }

  # A random FINITE double: half from raw 64-bit patterns (subnormals + huge),
  # half from structured magnitudes; non-finite values are retried out (the
  # numeric invariants are over finite doubles only).
  def rand_finite_double
    f =
      if rand(2).zero?
        [rand(2**64)].pack('Q').unpack1('D')
      else
        sign = rand(2).zero? ? 1 : -1
        case rand(5)
        when 0 then sign * rand * 10.0**rand(-30..30)
        when 1 then (sign * rand(0..2_000_000_000)).to_f
        when 2 then sign * rand(0..999_999) / 10.0**rand(0..6)
        when 3 then sign * 1.0 * 10.0**rand(-6..17)
        else sign * 10.0**rand(-300..300) * (1 + rand)
        end
      end
    f.nan? || f.infinite? ? rand_finite_double : f
  end

  def bits(f) = [f].pack('D')

  describe Lich::Genie::Numeric do
    it 'round-trips format_double -> string_to_double bit-exactly for finite doubles' do
      iter.times do
        d = rand_finite_double
        back = described_class.string_to_double(described_class.format_double(d))
        expect(bits(back)).to eq(bits(d)), "d=#{d.inspect} formatted=#{described_class.format_double(d).inspect}"
      end
    end

    it 'emits a well-formed .NET fixed/scientific layout for finite doubles' do
      fixed = /\A-?(?:\d+|\d+\.\d+)\z/
      sci   = /\A-?\d(?:\.\d+)?E[+-]\d{2,}\z/
      leadzero = /\A-?0\d/
      iter.times do
        d = rand_finite_double
        s = described_class.format_double(d)
        expect(s).to match(Regexp.union(fixed, sci)), "d=#{d.inspect} -> #{s.inspect}"
        expect(s).not_to match(leadzero), "d=#{d.inspect} -> #{s.inspect}"
      end
    end

    it 'is a canonical form: format_double is stable across a parse for finite doubles' do
      iter.times do
        s1 = described_class.format_double(rand_finite_double)
        s2 = described_class.format_double(described_class.string_to_double(s1))
        expect(s2).to eq(s1)
      end
    end

    it 'to_integer stays within 0.5 of the input, is idempotent, and is identity on integral doubles' do
      iter.times do
        sign = rand(2).zero? ? 1 : -1
        x = sign * rand(0..2**52) / (10.0**rand(0..6))
        r = described_class.to_integer(x)
        expect(r).to be_a(Integer)
        expect((r - x).abs).to be <= 0.5
        expect(described_class.to_integer(r.to_f)).to eq(r)
        n = sign * rand(0..2**52)
        expect(described_class.to_integer(n.to_f)).to eq(n)
      end
    end
  end

  describe Lich::Genie::Text do
    split_alpha = ['a', 'b', 'c', '1', ' ', '  ', '{', '}', '"', '\\', ';', ',', '|', 'x', '_']
    seps = [';', ',', '|', '/', ':', '#', '{', '"', '\\', 'z']
    safe_tok = ('a'..'z').to_a + ('0'..'9').to_a

    it 'safe_split(s, sep).join(sep) reconstructs the input for any single-char sep' do
      iter.times do
        s = Array.new(rand(0..14)) { split_alpha.sample }.join
        sep = seps.sample
        expect(described_class.safe_split(s, sep).join(sep)).to eq(s), "s=#{s.inspect} sep=#{sep.inspect}"
      end
    end

    it 'parse_args round-trips plain space-joined safe tokens' do
      iter.times do
        toks = Array.new(rand(1..6)) { Array.new(rand(1..6)) { safe_tok.sample }.join }
        expect(described_class.parse_args(toks.join(' '))).to eq(toks)
      end
    end
  end

  describe Lich::Genie::Substitution do
    safe_tok = ('a'..'z').to_a + ('0'..'9').to_a
    nosigil = ('a'..'z').to_a + ('0'..'9').to_a + [' ', '(', ')', '.', '|', '_', '\\']
    # %local + @special only: NO '$' and NO backslash. expand un-escapes and the
    # $-arg pass runs first, so those two break idempotence BY DESIGN.
    sub_alpha = ['a', 'b', 'c', 'o', 'g', 'l', '1', '2', '%', '@', ' ', '(', ')', '.', '|', '_']
    clock = -> { Time.new(2026, 8, 24, 14, 5, 9) }

    it 'expand is a no-op on text containing no %, $, or @' do
      vars = Lich::Genie::Variables.new
      vars.local_set('foo', 'X')
      vars.global_set('bar', 'Y')
      sub = described_class.new(variables: vars,
                                specials: Lich::Genie::Specials.new(clock: clock, timer_elapsed: -> { 42 }))
      iter.times do
        s = Array.new(rand(0..16)) { nosigil.sample }.join
        expect(sub.expand(s, args: %w[all one two])).to eq(s)
      end
    end

    it 'expand is idempotent for %local/@special input with sigil-free values' do
      iter.times do
        vars = Lich::Genie::Variables.new
        rand(0..4).times do
          name = Array.new(rand(1..4)) { safe_tok.sample }.join
          val = Array.new(rand(0..6)) { (safe_tok + ['|']).sample }.join
          rand(2).zero? ? vars.local_set(name, val) : vars.global_set(name, val)
        end
        sub = described_class.new(variables: vars,
                                  specials: Lich::Genie::Specials.new(clock: clock, timer_elapsed: -> { 7 }))
        s = Array.new(rand(0..18)) { sub_alpha.sample }.join
        once = sub.expand(s)
        expect(sub.expand(once)).to eq(once), "s=#{s.inspect} once=#{once.inspect}"
      end
    end
  end
end
