# frozen_string_literal: true

module Lich
  module Genie
    # Boolean/string expression evaluator backing `if`, `elseif`, `while`, `eval`,
    # and `waiteval`. Clean-room port of Genie4 Script/Eval.cs. See
    # docs/genie-engine/expressions-spec.md Part A for exact tokenization, keyword
    # aliasing, precedence, comparison rules, functions, and truthiness.
    #
    # Precedence (per parenthesized section): comparisons > NOT > AND/OR, each
    # left-associative; AND and OR share one precedence level. Numeric comparison
    # only when BOTH operands are number tokens; otherwise string (case-sensitive,
    # relational operators on strings always yield false). Only strictly-positive
    # numbers are truthy.
    #
    # Instantiate per script (mirrors Genie's per-script m_oEval) so `matchre`
    # capture groups accumulate in #result_list for the caller to copy into $0..$n.
    #
    # TODO(regex-parity): matchre/replacere use default Ruby regex options for now.
    #   Align with Genie4 RegexOptions.cs when the shared Genie::Regex helper lands.
    class Eval
      SEPARATORS = "!=<>,&|"

      FUNCTION_NAMES = %w[
        instr instring contains indexof lastindexof match startswith endswith
        replace tolower toupper trim len length substr substring matchre replacere
        count element def defined
      ].freeze

      COMPARATORS = %w[= == != <> > >= < <=].freeze
      LOGICALS = %w[&& ||].freeze

      Section = Struct.new(:text, :type)

      # @param globals [#key?, #include?, nil] optional lookup for def()/defined()
      def initialize(globals: nil)
        @globals = globals
        @result_list = []
      end

      # @return [Array<String>] capture groups (0..n) from the most recent matchre
      attr_reader :result_list

      # @param text [String]
      # @return [Boolean] for if/while
      def do_eval(text)
        section_true?(evaluate(build_sections(text)))
      rescue Error
        false
      end

      # @param text [String]
      # @return [String] for eval/waiteval
      def eval_string(text)
        evaluate(build_sections(text)).text
      rescue Error
        ''
      end

      private

      # --- Tokenization -----------------------------------------------------

      def build_sections(text)
        @result_list = []
        tokenize(replace_keywords(text.to_s))
      end

      def replace_keywords(text)
        return keyword_sub(text) unless text.include?('"')

        result = +''
        quoted = false
        buffer = +''
        text.each_char do |ch|
          if ch == '"'
            result << (quoted ? buffer : keyword_sub(buffer)) << ch
            buffer = +''
            quoted = !quoted
          else
            buffer << ch
          end
        end
        result << (quoted ? buffer : keyword_sub(buffer))
        result
      end

      def keyword_sub(segment)
        segment.gsub(/\b(eq|and|or|not|true|false)\b/) do
          { 'eq' => '=', 'and' => '&&', 'or' => '||',
            'not' => '!', 'true' => '1', 'false' => '0' }[Regexp.last_match(1)]
        end
      end

      def tokenize(text)
        sections = []
        sp = 0
        current = :separator
        inside_string = false
        cp = 0
        len = text.length
        flush = ->(endpos) { section_enqueue(sections, text[sp...endpos], current) }

        while cp < len
          ch = text[cp]
          if inside_string
            inside_string = false if ch == '"'
            cp += 1
          elsif ch == '"'
            flush.call(cp)
            sp = cp
            current = :string
            inside_string = true
            cp += 1
          elsif SEPARATORS.include?(ch)
            unless current == :separator
              flush.call(cp)
              sp = cp
              current = :separator
            end
            cp += 1
          elsif current != :function && (ch =~ /[0-9]/ || ch == '.' || ch == '-')
            unless current == :number
              flush.call(cp)
              sp = cp
              current = :number
            end
            cp += 1
          elsif ch == '('
            flush.call(cp)
            sections << Section.new('(', :section_start)
            cp += 1
            sp = cp
            current = :separator
          elsif ch == ')'
            flush.call(cp)
            sections << Section.new(')', :section_end)
            cp += 1
            sp = cp
            current = :separator
          elsif ch == ' ' || ch == "\t"
            if current == :function
              cp += 1 # absorb: a function/bareword token may contain spaces
            else
              flush.call(cp)
              sp = cp
              current = :separator
              cp += 1
            end
          elsif current == :number
            # A non-numeric char inside a would-be number (e.g. ".sc", "3x") means the
            # whole run is a bareword, not a number -- reclassify WITHOUT flushing so the
            # leading digits/'.'/'-' stay part of the token (mirrors Genie's bIgnoreNumber).
            # The `current != :function` guard on the number branch above then stops any
            # later digit from restarting a number mid-token.
            current = :function
            cp += 1
          else
            unless current == :function
              flush.call(cp)
              sp = cp
              current = :function
            end
            cp += 1
          end
        end
        flush.call(len)
        sections
      end

      def section_enqueue(sections, raw, type)
        seg = raw.gsub(/\A[ \t]+/, '').gsub(/[ \t]+\z/, '')
        return if seg.empty?

        case type
        when :function
          enqueue_function(sections, seg)
        when :separator
          sections << Section.new(seg == '!' ? '!' : seg, seg == '!' ? :negate : :separator)
        when :string
          text = seg.length > 1 && seg.start_with?('"') && seg.end_with?('"') ? seg[1...-1] : seg
          sections << Section.new(text, :string)
        else
          sections << Section.new(seg, type)
        end
      end

      def enqueue_function(sections, seg)
        case seg.downcase
        when 'eq' then sections << Section.new('=', :separator)
        when 'and' then sections << Section.new('&&', :separator)
        when 'or' then sections << Section.new('||', :separator)
        when 'not' then sections << Section.new('!', :negate)
        when 'true' then sections << Section.new('1', :number)
        when 'false' then sections << Section.new('0', :number)
        else
          sections << Section.new(seg, FUNCTION_NAMES.include?(seg.downcase) ? :function : :string)
        end
      end

      # --- Evaluation -------------------------------------------------------

      def evaluate(sections)
        loop do
          end_idx = sections.index { |s| s.type == :section_end }
          break unless end_idx

          start_idx = nil
          (end_idx - 1).downto(0) do |i|
            if sections[i].type == :section_start
              start_idx = i
              break
            end
          end

          if start_idx.nil?
            sections.delete_at(end_idx) # tolerate an unmatched ')'
            next
          end

          inner = sections[(start_idx + 1)...end_idx]
          func_idx = start_idx - 1
          if func_idx >= 0 && sections[func_idx].type == :function
            sections[func_idx..end_idx] = [call_function(sections[func_idx].text, collect_args(inner))]
          else
            sections[start_idx..end_idx] = [reduce_section(inner)]
          end
        end

        reduce_section(sections)
      end

      def reduce_section(sections)
        work = sections.dup
        fold(work) { |s| s.type == :separator && COMPARATORS.include?(s.text) }
        fold_negation(work)
        fold(work) { |s| s.type == :separator && LOGICALS.include?(s.text) }
        work.find { |s| s.type == :number || s.type == :string } || Section.new('', :string)
      end

      # Left-associative fold of a binary operator selected by the block. Rescans
      # from the start after each reduction so chained operators fold left-to-right.
      #
      # @param work [Array<Section>] the section list, mutated in place
      # @yieldparam section [Section] a candidate operator section
      # @yieldreturn [Boolean] whether this section is the operator to fold on
      # @return [void]
      # @raise [Error] if an operator is missing its left or right operand
      def fold(work, &sel)
        i = 0
        while i < work.length
          if sel.call(work[i])
            raise Error, 'Malformed expression' if i.zero? || i + 1 >= work.length

            op = work[i].text
            res = COMPARATORS.include?(op) ? apply_comparison(work[i - 1], op, work[i + 1])
                                           : apply_logical(work[i - 1], op, work[i + 1])
            work[(i - 1)..(i + 1)] = [res]
            i = 0
          else
            i += 1
          end
        end
      end

      def fold_negation(work)
        i = 0
        while i < work.length
          if work[i].type == :negate
            raise Error, 'Malformed expression' if i + 1 >= work.length

            res = Section.new(section_true?(work[i + 1]) ? '0' : '1', :number)
            work[i..(i + 1)] = [res]
            i = 0
          else
            i += 1
          end
        end
      end

      # Compare two operands. Numeric comparison ONLY when both operands are number
      # tokens; otherwise string comparison (case-sensitive), where relational
      # operators (>, >=, <, <=) always yield false -- a faithful Genie behavior.
      #
      # @param left [Section]
      # @param op [String] one of COMPARATORS
      # @param right [Section]
      # @return [Section] a number section holding "1" (true) or "0" (false)
      def apply_comparison(left, op, right)
        if left.type == :number && right.type == :number
          d1 = Numeric.string_to_double(left.text)
          d2 = Numeric.string_to_double(right.text)
          bool = case op
                 when '=', '==' then d1 == d2
                 when '!=', '<>' then d1 != d2
                 when '>' then d1 > d2
                 when '>=' then d1 >= d2
                 when '<' then d1 < d2
                 when '<=' then d1 <= d2
                 end
        else
          bool = case op
                 when '=', '==' then left.text == right.text
                 when '!=', '<>' then left.text != right.text
                 else false # relational operators on strings always yield false
                 end
        end
        Section.new(bool ? '1' : '0', :number)
      end

      def apply_logical(left, op, right)
        return Section.new('0', :number) unless left.type == :number && right.type == :number

        d1 = Numeric.string_to_double(left.text)
        d2 = Numeric.string_to_double(right.text)
        bool = op == '||' ? (d1 > 0 || d2 > 0) : (d1 > 0 && d2 > 0)
        Section.new(bool ? '1' : '0', :number)
      end

      # Genie truthiness: only "1" or a strictly-positive integer number token is
      # true. Any string (even a non-empty one) and any non-integer number is false.
      #
      # @param section [Section]
      # @return [Boolean]
      def section_true?(section)
        return false if section.text == '0'
        return true if section.text == '1'
        return false unless section.type == :number

        begin
          Integer(section.text) > 0
        rescue ArgumentError, TypeError
          false
        end
      end

      def collect_args(inner)
        inner.select { |s| s.type == :number || s.type == :string }.map(&:text)
      end

      # --- Functions --------------------------------------------------------

      def call_function(name, args)
        case name.downcase
        when 'instr', 'instring', 'contains' then num_bool(args[0].to_s.include?(args[1].to_s))
        when 'indexof' then number((args[0].to_s.index(args[1].to_s) || -1) + 1)
        when 'lastindexof' then number((args[0].to_s.rindex(args[1].to_s) || -1) + 1)
        when 'match' then num_bool(args[0].to_s == args[1].to_s)
        when 'startswith' then num_bool(args[0].to_s.start_with?(args[1].to_s))
        when 'endswith' then num_bool(args[0].to_s.end_with?(args[1].to_s))
        when 'replace' then string(args[0].to_s.gsub(args[1].to_s, args[2].to_s))
        when 'tolower' then string(args[0].to_s.downcase)
        when 'toupper' then string(args[0].to_s.upcase)
        when 'trim' then string(args[0].to_s.strip)
        when 'len', 'length' then number(args[0].to_s.length)
        when 'substr', 'substring' then string(substr(args))
        when 'matchre' then matchre(args[0].to_s, args[1].to_s)
        when 'replacere' then string(replacere(args[0].to_s, args[1].to_s, args[2].to_s))
        when 'count' then number(count_occurrences(args[0].to_s, args[1].to_s))
        when 'element' then string(element(args[0].to_s, args[1].to_s))
        when 'def', 'defined' then num_bool(defined_global?(args[0].to_s))
        else raise Error, "Invalid function name: #{name}"
        end
      end

      def num_bool(bool)
        Section.new(bool ? '1' : '0', :number)
      end

      def number(value)
        Section.new(value.to_s, :number)
      end

      def string(value)
        Section.new(value.to_s, :string)
      end

      # Genie substr/substring. With 3 args a negative length shifts the start left
      # (or zeroes it and uses the original start as the length) before clamping;
      # with 2 args it returns the tail, or "" when the start is out of range.
      #
      # @param args [Array<String>] [source, start] or [source, start, length]
      # @return [String]
      def substr(args)
        s = args[0].to_s
        if args.length >= 3
          start = Numeric.to_integer(args[1])
          length = Numeric.to_integer(args[2])
          orig_start = start
          if length < 0
            if start + length >= 0
              start += length
              length = length.abs
            else
              start = 0
              length = orig_start
            end
          end
          start = 0 if start < 0
          length = 0 if length < 0
          if start + length > s.length
            start <= s.length ? s[start..].to_s : ''
          else
            s[start, length].to_s
          end
        else
          start = Numeric.to_integer(args[1])
          start >= 0 && start <= s.length ? s[start..].to_s : ''
        end
      end

      def matchre(subject, pattern)
        match = Regexp.new(pattern).match(subject.strip)
        if match
          @result_list = match.to_a.map(&:to_s)
          num_bool(true)
        else
          num_bool(false)
        end
      end

      def replacere(subject, pattern, replacement)
        regex = Regexp.new(pattern)
        subject.gsub(regex) do
          matchdata = Regexp.last_match
          replacement.gsub(/\$(\d+)/) { matchdata[Regexp.last_match(1).to_i].to_s }
        end
      end

      def count_occurrences(haystack, needle)
        return 0 if needle.empty?

        count = 0
        pos = 0
        while (idx = haystack.index(needle, pos))
          count += 1
          pos = idx + needle.length
        end
        count
      end

      def element(value, index_str)
        parts = value.delete('(').delete(')').split('|', -1)
        idx = Numeric.to_integer(index_str)
        idx = parts.length - 1 if idx >= parts.length
        idx += parts.length if idx < 0
        idx = 0 if idx < 0
        parts[idx].to_s
      end

      def defined_global?(name)
        return false unless @globals
        return @globals.key?(name) if @globals.respond_to?(:key?)
        return @globals.include?(name) if @globals.respond_to?(:include?)

        false
      end
    end
  end
end
