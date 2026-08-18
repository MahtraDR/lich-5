# frozen_string_literal: true

module Lich
  module Genie
    # Variable substitution over a script line. Clean-room port of Genie4
    # Script.cs ParseVariables/ParseVariable (+ Globals.cs global/@-special paths).
    # See docs/genie-engine/interpreter-spec.md section 3.
    #
    # Passes, in order:
    #   1. $-args  ($0..$N, $argcount) -- naive low-to-high Replace (so "$1" also
    #      hits "$10"; a faithful Genie quirk), with "\$" escaping.
    #   2. %/$ vars -- a RIGHT-TO-LEFT scan expanding %local and $global at each
    #      unescaped sigil. Right-to-left gives single-level, positional expansion:
    #      a value that itself contains %/$ is not re-scanned.
    #   3. @-specials via {Specials}.
    #
    # Undefined variables are left literally in place (matching Genie), which is how
    # the evaluators detect "unresolved" text.
    class Substitution
      # ASCII sentinels (the AsciiOnlySource cop forbids Genie's original non-ASCII
      # sentinel) used to shield escaped sigils during a pass.
      SENTINEL_PCT = "\x01"
      SENTINEL_DOLLAR = "\x02"

      # @param variables [Variables] the local/global store
      # @param specials [Specials] the @...@ resolver
      # @param arg_limit [Integer] highest numbered arg recognized ($0..$arg_limit)
      def initialize(variables:, specials: Specials.new, arg_limit: 9)
        @variables = variables
        @specials = specials
        @arg_limit = arg_limit
      end

      # Expand all variable forms in a line.
      #
      # @param text [String]
      # @param args [Array<String>] the active frame's arg list ($0 = full arg
      #   string, $1..$n = parsed tokens)
      # @return [String]
      def expand(text, args: [])
        result = text.to_s
        result = expand_dollar_args(result, args) if result.include?('$')
        result = expand_vars(result) if result.include?('%') || result.include?('$')
        result = expand_at_specials(result) if result.include?('@')
        result
      end

      private

      def expand_dollar_args(text, args)
        text = text.gsub('\\$', SENTINEL_DOLLAR)
        (0..@arg_limit).each do |i|
          value = i < args.length ? args[i].to_s : ''
          text = text.gsub("$#{i}", value)
        end
        text = text.gsub('$argcount', [args.length - 1, 0].max.to_s)
        text.gsub(SENTINEL_DOLLAR, '$')
      end

      def expand_vars(text)
        text = text.gsub('\\%', SENTINEL_PCT).gsub('\\$', SENTINEL_DOLLAR)
        pos = text.length - 1
        while pos >= 0
          case text[pos]
          when '%' then text = text[0...pos] + parse_variable(text[pos..], :local)
          when '$' then text = text[0...pos] + parse_variable(text[pos..], :global)
          end
          pos -= 1
        end
        text.gsub(SENTINEL_PCT, '%').gsub(SENTINEL_DOLLAR, '$')
      end

      def expand_at_specials(text)
        @specials.substitutions.each { |token, value| text = text.gsub(token, value) }
        text
      end

      # Resolve a single variable reference beginning at a sigil.
      #
      # @param line [String] the text from the sigil to end-of-line
      # @param scope [:local, :global]
      # @return [String] the expansion + trailing text, or `line` unchanged if undefined
      def parse_variable(line, scope)
        return line if line.length <= 1

        after = line[1..]
        space_idx = after.index(' ')
        svar = space_idx ? after[0...space_idx] : after

        array = resolve_array(line, svar, scope)
        return array unless array.nil?

        resolve_prefix(line, svar, scope)
      end

      # `name(idx)` array element access.
      #
      # @return [String, nil] nil if this is not a resolvable array reference
      def resolve_array(line, svar, scope)
        open = svar.index('(')
        return nil unless open

        close = svar.index(')', open + 1)
        return nil unless close && close > open

        name = svar[0...open]
        idx_str = svar[(open + 1)...close]
        return nil unless @variables.key?(scope, name) && idx_str =~ /\A-?\d+\z/

        parts = @variables.get(scope, name).to_s.split('|', -1)
        idx = idx_str.to_i
        remainder = line[(close + 2)..].to_s
        return parts[idx].to_s + remainder if idx >= 0 && idx <= parts.length - 1
        return remainder if scope == :local # invalid index -> empty value (local only)

        nil # global with invalid index falls through to prefix matching
      end

      # Longest-prefix identifier match, including the `name.length` element-count form.
      def resolve_prefix(line, svar, scope)
        pos = svar.length
        while pos >= 1
          current = svar[0...pos]
          if current.downcase.end_with?('.length') && @variables.key?(scope, svar[0...(pos - 7)])
            count = @variables.get(scope, svar[0...(pos - 7)]).to_s.count('|') + 1
            return count.to_s + line[(pos + 1)..].to_s
          elsif @variables.key?(scope, current)
            return @variables.get(scope, current).to_s + line[(pos + 1)..].to_s
          end
          pos -= 1
        end
        line # undefined -> literal
      end
    end
  end
end
