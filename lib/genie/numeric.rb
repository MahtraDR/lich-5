# frozen_string_literal: true

module Lich
  module Genie
    # Numeric coercion/formatting helpers reproducing the .NET/VB semantics the
    # Genie engine relies on. See docs/genie-engine/expressions-spec.md "Cross-cutting".
    module Numeric
      module_function

      # .NET (net6, en-US) renders infinity as U+221E. Built from the codepoint so the
      # source stays ASCII (the AsciiOnlySource cop rejects even a \u escape that yields
      # a non-ASCII char) while emitting exactly what Genie's double.ToString() produces.
      INFINITY_SIGN = [0x221E].pack('U')

      # The grammar .NET's `double.Parse(s, en-US)` accepts under its default
      # NumberStyles (Float | AllowThousands): an optional sign, then digits with
      # lenient `,` group separators in the INTEGER part only (`1,23`, `12,34`,
      # `1,,2` all parse), an optional fraction, and an optional exponent -- OR a
      # leading-dot fraction (`.5`). Verified against the real evaluator via the s2d
      # oracle. Validating with this FIRST is what keeps us faithful: Ruby's `Float()`
      # would otherwise (wrongly, vs Genie) accept `0x1F`->31, `1_000`->1000, and
      # `Infinity`, and would misparse `1.5,3` instead of rejecting it.
      S2D_GRAMMAR = /\A[+-]?(?:\d[\d,]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?\z/
      # .NET parses "NaN" (case-insensitive, optional sign) to NaN, but NOT "Infinity".
      S2D_NAN = /\A[+-]?nan\z/i

      # Port of Utility.StringToDouble (Utility.cs:609): en-US `double.Parse`, returning
      # -1.0 (NOT 0) on nil/failure. This drives numeric COMPARISONS in Eval, so a
      # too-lenient parse changes real script branching (e.g. comparing `0x1F`).
      #
      # @param str [String, nil]
      # @return [Float]
      def string_to_double(str)
        return -1.0 if str.nil?

        s = str.to_s.strip
        return Float::NAN if s.match?(S2D_NAN)
        return -1.0 unless s.match?(S2D_GRAMMAR)

        Float(s.delete(','))
      rescue ArgumentError, TypeError
        -1.0
      end

      # @return [Boolean] whether the whole (trimmed) string parses as a number,
      #   matching Genie's IsNumeric fast path in MathEval.Evaluate.
      def numeric?(str)
        s = str.to_s.strip
        return false if s.empty?

        begin
          Float(s)
          true
        rescue ArgumentError, TypeError
          false
        end
      end

      # Port of VB Conversions.ToInteger: banker's rounding (half-to-even).
      #
      # @param value [Numeric, String]
      # @return [Integer]
      def to_integer(value)
        d = value.is_a?(String) ? string_to_double(value) : value.to_f
        d.round(half: :even)
      end

      # Port of VB Conversions.ToLong. Ruby Integer is arbitrary precision, so
      # this is identical to {to_integer} for our purposes.
      #
      # @return [Integer]
      def to_long(value)
        to_integer(value)
      end

      # Stringify a double byte-for-byte as .NET's default double.ToString() (net6,
      # en-US) does -- which is what Genie's `evalmath`/`math` store back into vars
      # (Command.cs EvalMath). .NET uses the SHORTEST round-trippable digits, fixed-point
      # notation when the leading digit's power-of-ten exponent is in [-4, 16], and
      # scientific ("1.5E+30", "1E-05", min 2 exponent digits) otherwise. Ruby's
      # Float#to_s yields the same shortest DIGITS, so we reuse them and re-lay-out.
      # Verified byte-exact against the real Genie4 evaluator via the differential fuzzer
      # (genie-port-lab/reference/fuzz_format.rb).
      #
      # @param value [Numeric]
      # @return [String]
      def format_double(value)
        f = value.to_f
        return 'NaN' if f.nan?
        return f.positive? ? INFINITY_SIGN : "-#{INFINITY_SIGN}" if f.infinite?
        return (1.0 / f).negative? ? '-0' : '0' if f.zero? # preserve -0 like .NET

        digits, exp = shortest_digits(f.abs) # value == d.igits * 10**exp
        body = exp.between?(-4, 16) ? fixed_notation(digits, exp) : scientific_notation(digits, exp)
        f.negative? ? "-#{body}" : body
      end

      # Shortest significant digits (no dot, no leading/trailing zeros) of a positive
      # finite double, plus the power-of-ten exponent of the FIRST digit. Reuses Ruby's
      # shortest Float#to_s. @return [[String, Integer]]
      def shortest_digits(x)
        str = x.to_s
        mantissa, sci = str.include?('e') ? str.split('e') : [str, '0']
        intpart, frac = mantissa.split('.')
        digits = intpart + (frac || '')
        exp = sci.to_i + intpart.length - 1 # exponent of the first char of `digits`
        lead = digits.length - digits.sub(/\A0+/, '').length
        digits = digits.sub(/\A0+/, '').sub(/0+\z/, '')
        digits = '0' if digits.empty?
        [digits, exp - lead]
      end

      def fixed_notation(digits, exp)
        if exp.negative?
          "0.#{'0' * (-exp - 1)}#{digits}"
        elsif digits.length <= exp + 1
          digits + ('0' * (exp + 1 - digits.length))
        else
          "#{digits[0, exp + 1]}.#{digits[(exp + 1)..]}"
        end
      end

      def scientific_notation(digits, exp)
        mantissa = digits.length > 1 ? "#{digits[0]}.#{digits[1..]}" : digits
        "#{mantissa}E#{exp.negative? ? '-' : '+'}#{format('%02d', exp.abs)}"
      end
    end
  end
end
