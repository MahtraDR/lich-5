# frozen_string_literal: true

module Lich
  module Genie
    # Backs the `math` and `counter` script verbs. This is a faithful port of
    # Utility.MathCalc (Genie4 Utility/Utility.cs:828) and is DISTINCT from
    # {MathEval}, which backs only `evalmath`.
    #
    # Genie quirk preserved: the argument is clamped to >= 0, so
    # `math x subtract -5` subtracts 0, not -5.
    module MathCalc
      module_function

      # @param value [Numeric] the current value of the target variable
      # @param expression [String] e.g. "add 5", "subtract 2", "set 10", "mod 3"
      # @return [Float] the new value
      # @raise [Error] on an unrecognized operation keyword
      def calc(value, expression)
        keyword = Text.keyword_string(expression).downcase
        arg = Numeric.string_to_double(Text.argument_string(expression))
        arg = 0.0 if arg < 0 # Genie quirk: negative args clamp to 0
        v = value.to_f

        case keyword
        when 'add', '+'
          v + arg
        when 'sub', 'substract', 'subtract', '-'
          v - arg
        when 'set', '='
          arg
        when 'multiply', '*'
          v * arg
        when 'divide', '/'
          v / arg # divide-by-zero yields Infinity, matching .NET double math
        when 'mod', 'modulus', '%'
          # C# `%` remainder takes the sign of the dividend; Ruby's Float#remainder
          # matches (Float#% would take the sign of the divisor). Guard on value==0.
          v != 0 ? v.remainder(arg) : 0.0
        else
          raise Error, "Invalid #MATH expression: #{expression}"
        end
      end
    end
  end
end
