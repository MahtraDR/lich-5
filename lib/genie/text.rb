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

      # Port of Utility.SafeSplit: split on +sep+ (a single char, default ';') while
      # honoring {...} brace groups and "..." quotes, so a separator inside a group is
      # not a split point. Braces/quotes are LEFT INTACT (unlike parse_args). Used to
      # break a trigger/command body into its `;`-separated sub-commands.
      #
      # @param str [String]
      # @param sep [String] one-character separator
      # @return [Array<String>]
      def safe_split(str, sep = ';')
        s = str.to_s
        parts = []
        buffer = +''
        in_quote = false
        depth = 0
        i = 0
        while i < s.length
          ch = s[i]
          if ch == '\\' && i + 1 < s.length
            buffer << ch << s[i + 1]
            i += 2
            next
          elsif ch == '"'
            in_quote = !in_quote
            buffer << ch
          elsif in_quote
            buffer << ch
          elsif ch == '{'
            depth += 1
            buffer << ch
          elsif ch == '}'
            depth -= 1 if depth.positive?
            buffer << ch
          elsif ch == sep && depth.zero?
            parts << buffer
            buffer = +''
          else
            buffer << ch
          end
          i += 1
        end
        parts << buffer
        parts
      end

      # Port of Utility.ParseArgs (Utility.cs:390): split a command line into an
      # argument list on ' ' spaces, honoring "..." quoted strings and {...} brace
      # groups so a space inside either is not a split point. This is a FAITHFUL
      # port of the C# algorithm, which is subtler than it looks -- it slices the
      # source with a start pointer rather than accumulating a char buffer, so:
      #
      #   * A `\` escape makes the NEXT char non-special (it won't open a quote/brace
      #     or split) but BOTH the backslash and the escaped char stay in the token
      #     verbatim: `a\ b` -> ["a\ b"], NOT ["a b"].
      #   * Only `"` toggles quoting inside the loop; a backslash inside a quoted run
      #     is a plain char (no escaping there). Interior/unbalanced quotes are KEPT
      #     in the token: `a"b"c` -> ['a"b"c'], `"hello` -> ['"hello'].
      #   * A brace boundary is a TOKEN boundary like a space, even without a space:
      #     `x{y}z` -> ["x", "y", "z"]. Outer braces are stripped, inner kept; `{}`
      #     yields one empty token. A `}` decrements depth even below zero, so a
      #     stray `}` makes later spaces stop splitting (`a}b c` -> ["a}b c"]).
      #   * Wrapping quotes are stripped only if BOTH ends match, and BOTH `"..."`
      #     and '...' are stripped (single quotes only here, not in the loop). A
      #     token that is a lone `"` or `'` makes Genie THROW (its AddArrayItem does
      #     Substring(1, len-2), i.e. length -1) -- we replicate the throw.
      #   * The bTreatUnderscoreAsSpace flag replaces `_`->` ` in every token EXCEPT
      #     the first (Genie gates it on oList.Count > 0).
      #
      # @param str [String]
      # @param treat_underscore_as_space [Boolean]
      # @return [Array<String>]
      # @raise [Error] on a malformed argument string (matches Genie's rethrow)
      def parse_args(str, treat_underscore_as_space: false)
        s = str.to_s
        list = []
        begin
          inside_string = false
          string_char = nil
          bracket_depth = 0
          escape = false
          sp = 0
          cp = 0
          len = s.length
          while cp < len
            ch = s[cp]
            if escape
              escape = false
            elsif inside_string
              inside_string = false if ch == string_char
            elsif ch == '"'
              inside_string = true
              string_char = ch
            elsif ch == '{'
              if bracket_depth.zero?
                l = cp - sp
                add_array_item(list, s[sp, l], treat_underscore_as_space) if l.positive?
                sp = cp
              end
              bracket_depth += 1
            elsif ch == '}'
              bracket_depth -= 1
              if bracket_depth.zero?
                l = cp - sp
                if l.positive?
                  add_array_item(list, s[sp + 1, l - 1], treat_underscore_as_space)
                else
                  add_array_item(list, '')
                end
                sp = cp + 1
              end
            elsif ch == ' '
              if bracket_depth.zero?
                l = cp - sp
                add_array_item(list, s[sp, l], treat_underscore_as_space) if l.positive?
                sp = cp + 1
              end
            elsif ch == '\\'
              escape = true
            end
            cp += 1
          end
          l = len - sp
          add_array_item(list, s[sp, l], treat_underscore_as_space) if l.positive?
        rescue StandardError
          raise Error, "Invalid string in Parse Arguments: #{s}"
        end
        list
      end

      # Port of Utility.AddArrayItem (Utility.cs:494): strip a wrapping "..." then a
      # wrapping '...' (each only when BOTH ends match), optionally replace `_`->` `,
      # and append. The underscore flag is honored only when the list is non-empty
      # (Genie's IIf(oList.Count > 0, flag, false)), so the first token is never
      # underscore-expanded. Faithfully replicates C#'s Substring(1, len-2), which
      # THROWS on a lone-quote token (length -1) -- caught + rethrown by parse_args.
      #
      # @return [void]
      def add_array_item(list, text, treat_underscore_as_space = false)
        text = text.to_s
        text = csharp_substring(text, 1, text.length - 2) if text.start_with?('"') && text.end_with?('"')
        text = csharp_substring(text, 1, text.length - 2) if text.start_with?("'") && text.end_with?("'")
        gate = !list.empty? && treat_underscore_as_space
        text = text.gsub('_', ' ') if gate && text.include?('_')
        list << text
      end

      # Faithful String.Substring(startIndex, length): raises (like C#'s
      # ArgumentOutOfRangeException) on a negative length or an out-of-range slice,
      # instead of Ruby's silent nil/clamp. Only reached with startIndex 1 here, so
      # the trigger is a lone-quote token (length -1).
      #
      # @return [String]
      def csharp_substring(str, start, length)
        raise ArgumentError, 'substring out of range' if length.negative? || start.negative? || (start + length) > str.length

        str[start, length]
      end
    end
  end
end
