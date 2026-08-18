# frozen_string_literal: true

module Lich
  module Genie
    # Numeric coercion/formatting helpers reproducing the .NET/VB semantics the
    # Genie engine relies on. See docs/genie-engine/expressions-spec.md "Cross-cutting".
    module Numeric
      module_function

      # Port of Utility.StringToDouble: en-US parse, returns -1.0 (NOT 0) on
      # empty/nil/parse-failure. Tolerates thousands separators like .NET.
      #
      # @param str [String, nil]
      # @return [Float]
      def string_to_double(str)
        return -1.0 if str.nil?

        s = str.to_s.strip
        return -1.0 if s.empty?

        begin
          Float(s)
        rescue ArgumentError, TypeError
          begin
            Float(s.delete(','))
          rescue ArgumentError, TypeError
            -1.0
          end
        end
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

      # Stringify a double the way .NET's default double.ToString() ("G"/shortest
      # round-trip) does: integers print without a decimal point; other values use
      # the shortest representation. Used to store math/eval results back into vars.
      #
      # @param value [Numeric]
      # @return [String]
      def format_double(value)
        f = value.to_f
        return 'NaN' if f.nan?
        return f.positive? ? 'Infinity' : '-Infinity' if f.infinite?

        if f == f.to_i && f.abs < 1e15
          f.to_i.to_s
        else
          f.to_s
        end
      end
    end
  end
end
