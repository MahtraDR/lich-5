# frozen_string_literal: true

module Lich
  module Genie
    # Small string helpers ported from Genie's Utility.cs, used pervasively by the
    # verb handlers. Faithful to the C# behavior (e.g. argument_string does NOT
    # re-trim its result, matching GetArgumentString).
    module Text
      module_function

      # Port of Utility.GetKeywordString: the first whitespace-delimited word.
      #
      # @param str [String]
      # @return [String]
      def keyword_string(str)
        s = str.to_s.strip
        idx = s.index(' ')
        idx ? s[0...idx] : s
      end

      # Port of Utility.GetArgumentString: everything after the first space, or "".
      # Note: the result is intentionally NOT trimmed (matches the C#).
      #
      # @param str [String]
      # @return [String]
      def argument_string(str)
        s = str.to_s.strip
        idx = s.index(' ')
        idx ? s[(idx + 1)..] : ''
      end

      # Port of Utility.ParseArgs: split on whitespace while honoring "..." quoted
      # strings (quotes stripped), {...} brace groups (outer braces stripped, inner
      # kept, an empty {} yields an empty token), and \ escapes.
      #
      # @param str [String]
      # @return [Array<String>]
      def parse_args(str)
        s = str.to_s
        tokens = []
        buffer = +''
        started = false
        in_quote = false
        brace_depth = 0
        i = 0

        while i < s.length
          ch = s[i]
          if ch == '\\' && i + 1 < s.length
            buffer << s[i + 1]
            started = true
            i += 2
            next
          elsif in_quote
            ch == '"' ? (in_quote = false) : (buffer << ch)
          elsif brace_depth.positive?
            if ch == '{'
              brace_depth += 1
              buffer << ch
            elsif ch == '}'
              brace_depth -= 1
              buffer << ch if brace_depth.positive?
            else
              buffer << ch
            end
          elsif ch == '"'
            in_quote = true
            started = true
          elsif ch == '{'
            brace_depth = 1
            started = true
          elsif ch == ' ' || ch == "\t"
            if started
              tokens << buffer
              buffer = +''
              started = false
            end
          else
            buffer << ch
            started = true
          end
          i += 1
        end
        tokens << buffer if started
        tokens
      end
    end
  end
end
