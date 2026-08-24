# frozen_string_literal: true

module Lich
  module Genie
    # Recursive-descent arithmetic evaluator backing the `evalmath` verb. Faithful
    # port of Genie4 Script/MathEval.cs. See docs/genie-engine/expressions-spec.md
    # Part B for the exact grammar, operator table, and per-operator quirks.
    #
    # Precedence (low -> high): (+ -) < (* / \ %) < ^ < unary(+ -) < ! < atoms.
    # Notable Genie quirks preserved:
    #   * `^` is LEFT-associative  (2^3^2 == 64, not 512)
    #   * `\` is integer division, truncating toward zero
    #   * `%` remainder takes the sign of the dividend
    #   * `log` is base-10 (NOT natural); `ln` is natural
    #   * rounding is banker's (half-to-even)
    module MathEval
      FUNCTIONS = %w[
        sin cos tan arcsin arccos arctan sqrt max min
        floor ceiling log log10 ln round abs neg pos
      ].freeze

      module_function

      # @param expression [String]
      # @return [Float]
      # @raise [Error] on a malformed expression (evalmath rescues this -> "0")
      def evaluate(expression)
        s = expression.to_s.strip
        raise Error, "Invalid expression: #{expression}" if s.empty?
        return Numeric.string_to_double(s) if Numeric.numeric?(s)

        Parser.new(Tokenizer.tokenize(s)).parse
      rescue Error
        raise
      rescue StandardError
        raise Error, "Invalid expression: #{expression}"
      end

      # Tokenizes an arithmetic expression into a flat array of token hashes.
      module Tokenizer
        module_function

        # @return [Array<Hash>]
        def tokenize(str)
          tokens = []
          i = 0
          len = str.length

          while i < len
            c = str[i]
            case c
            when ' ', "\t"
              i += 1
            when /[0-9.#]/
              j = i
              j += 1 while j < len && str[j] =~ /[0-9.#]/
              tokens << { type: :num, val: str[i...j].delete('#').to_f }
              i = j
            when /[A-Za-z_]/
              j = i
              j += 1 while j < len && str[j] =~ /[A-Za-z0-9_]/
              name = str[i...j]
              tokens << { type: FUNCTIONS.include?(name.downcase) ? :func : :ident, val: name }
              i = j
            when '+', '-', '*', '/', '\\', '%', '^', '!', '&'
              tokens << { type: :op, val: c }
              i += 1
            when '('
              tokens << { type: :lparen }
              i += 1
            when ')'
              tokens << { type: :rparen }
              i += 1
            when ','
              tokens << { type: :comma }
              i += 1
            else
              raise Error, "Invalid character '#{c}'"
            end
          end

          tokens
        end
      end

      # Recursive-descent parser/evaluator over the token stream.
      class Parser
        def initialize(tokens)
          @tokens = tokens
          @pos = 0
        end

        # @return [Float]
        def parse
          value = level1
          raise Error, 'Unexpected trailing tokens' unless peek.nil?

          value
        end

        private

        def peek
          @tokens[@pos]
        end

        def advance
          tok = @tokens[@pos]
          @pos += 1
          tok
        end

        def expect(type)
          tok = advance
          raise Error, "Expected #{type}" unless tok && tok[:type] == type

          tok
        end

        def op?(sym)
          (tok = peek) && tok[:type] == :op && tok[:val] == sym
        end

        # binary + -
        def level1
          value = level2
          while op?('+') || op?('-')
            oper = advance[:val]
            rhs = level2
            value = oper == '+' ? value + rhs : value - rhs
          end
          value
        end

        # * / \ %
        def level2
          value = level3
          while op?('*') || op?('/') || op?('\\') || op?('%')
            oper = advance[:val]
            rhs = level3
            value = apply_multiplicative(oper, value, rhs)
          end
          value
        end

        def apply_multiplicative(oper, lhs, rhs)
          case oper
          when '*' then lhs * rhs
          when '/' then lhs / rhs
          when '\\' then integer_divide(lhs, rhs)
          when '%' then modulo(lhs, rhs)
          end
        end

        # C# double `%` (Genie4 MathEval.cs:222 `operand1 % operand2`): truncated
        # remainder carrying the DIVIDEND's sign, with `x % 0 => NaN`. Ruby's
        # Float#remainder matches fmod for ordinary magnitudes but returns 0.0 when the
        # DIVISOR dwarfs the dividend (`-95 % 24^21` -> 0.0 instead of -95). In that case
        # trunc(lhs/rhs) is 0, so the remainder is exactly the dividend -- special-case it;
        # otherwise Float#remainder is precise (and beats a subtract-formula, which loses
        # precision for large dividends like `77^12 % 83`). Both edges were caught by the
        # Genie4 differential fuzzer (genie-port-lab/reference/fuzz_oracle.rb).
        def modulo(lhs, rhs)
          return Float::NAN if rhs.zero?
          return lhs if lhs.abs < rhs.abs

          lhs.remainder(rhs)
        end

        def integer_divide(lhs, rhs)
          la = Numeric.to_long(lhs)
          lb = Numeric.to_long(rhs)
          raise Error, 'Division by zero' if lb.zero?

          (la.to_f / lb).to_i.to_f # to_i truncates toward zero, matching C# long division
        end

        # ^  (left-associative, per Genie)
        def level3
          value = level4
          while op?('^')
            advance
            value **= level4
          end
          value
        end

        # unary + - (at most one)
        def level4
          if op?('+') || op?('-')
            oper = advance[:val]
            value = level5
            oper == '-' ? -value : value
          else
            level5
          end
        end

        # postfix factorial (at most one)
        def level5
          value = level6
          if op?('!')
            advance
            value = factorial(value)
          end
          value
        end

        def factorial(operand)
          n = Numeric.to_integer(operand)
          return 1.0 if n <= 1

          (2..n).reduce(1) { |acc, k| acc * k }.to_f
        end

        # atoms: ( expr ) | func( args ) | ident | number
        def level6
          tok = peek
          raise Error, 'Unexpected end of expression' if tok.nil?

          case tok[:type]
          when :lparen
            advance
            value = level1
            expect(:rparen)
            value
          when :func
            call_function(advance[:val].downcase)
          when :ident
            constant(advance[:val].downcase)
          when :num
            advance[:val]
          else
            raise Error, "Unexpected token #{tok[:type]}"
          end
        end

        def constant(name)
          case name
          when 'e' then Math::E
          when 'pi' then Math::PI
          else 0.0 # unknown identifier -> 0, per Genie
          end
        end

        def call_function(name)
          expect(:lparen)
          args = [level1]
          while (tok = peek) && tok[:type] == :comma
            advance
            args << level1
          end
          expect(:rparen)
          apply_function(name, args)
        end

        def apply_function(name, args)
          case name
          when 'sin' then Math.sin(args[0])
          when 'cos' then Math.cos(args[0])
          when 'tan' then Math.tan(args[0])
          when 'arcsin' then Math.asin(args[0])
          when 'arccos' then Math.acos(args[0])
          when 'arctan' then Math.atan(args[0])
          when 'sqrt' then Math.sqrt(args[0])
          when 'floor' then args[0].floor.to_f
          when 'ceiling' then args[0].ceil.to_f
          when 'abs' then args[0].abs
          when 'log' then Math.log10(args[0]) # base-10, NOT natural (Genie quirk)
          when 'log10' then Math.log10(args[0])
          when 'ln' then Math.log(args[0])
          when 'round' then round_function(args)
          when 'neg' then -args[0]
          when 'pos' then args[0]
          when 'max' then args.max
          when 'min' then args.min
          else 0.0
          end
        end

        def round_function(args)
          if args.length >= 2
            args[0].round(Numeric.to_integer(args[1]), half: :even).to_f
          else
            args[0].round(half: :even).to_f
          end
        end
      end
    end
  end
end
