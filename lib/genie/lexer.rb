# frozen_string_literal: true

module Lich
  module Genie
    # Compiles Genie script source into a flat instruction list + label map.
    # Clean-room port of Genie4 Script.cs AppendString/AddLine/GetFunctionType/
    # AddLabel. See docs/genie-engine/interpreter-spec.md sections 2.1 and 6.
    #
    # Faithful behaviors preserved:
    #   * blank lines are skipped; a leading '#' marks a comment line (skipped, as
    #     Genie does in its file reader). An unknown keyword raises unless warnings
    #     are ignored.
    #   * a line beginning with `%` becomes `setvariable ...` and one beginning
    #     with `$` becomes `put #var ...` (a leading ` = ` collapses to a space).
    #   * `if <c> then <cmd>` / `while <c> do <cmd>` split into a block-opening line
    #     plus the trailing command; `else <cmd>`, `elseif <c>`, and `} <cmd>` split
    #     similarly; `elseif` desugars to `else` + `if`.
    #   * `if_N ...` rewrites to `if %argcount >= N ...`.
    #   * a `U+00A4` (Genie's sentinel) inside a line acts as an inline newline.
    #
    # TODO(js-block): multi-line js/jsblock accumulation is deferred.
    class Lexer
      # A single compiled instruction.
      Instruction = Struct.new(:file_id, :file_row, :content, :function)

      # The compiled program.
      #
      # @!attribute instructions [Array<Instruction>]
      # @!attribute labels [Hash{String=>Integer}] lowercased label name => index
      # @!attribute files [Array<String>] file id => name
      # @!attribute warnings [Array<Hash>] unknown lines collected during compile
      Program = Struct.new(:instructions, :labels, :files, :warnings)

      # Genie's non-ASCII inline-newline sentinel (built via an ASCII-producing
      # escape so the source stays ASCII-only).
      MULTILINE_SEP = [0xA4].pack('U')

      # UTF-8 byte-order mark (built at runtime so the source stays ASCII-only, per the
      # AsciiOnlySource cop). Stripped from line starts -- Genie's StreamReader drops it.
      BOM = [0xFEFF].pack('U')

      # First-word keyword => function symbol.
      FUNCTION_MAP = {
        'action' => :action, 'include' => :include, 'echo' => :echo,
        'put' => :put, 'send' => :send, 'do' => :do_func, 'exit' => :exit_func,
        'goto' => :goto_func, 'save' => :save,
        'var' => :setvariable, 'vars' => :setvariable, 'variable' => :setvariable,
        'setvar' => :setvariable, 'setvariable' => :setvariable,
        'unvar' => :deletevariable, 'unvariable' => :deletevariable,
        'unsetvar' => :deletevariable, 'unsetvariable' => :deletevariable,
        'counter' => :counter, 'shift' => :shift, 'pause' => :pause, 'delay' => :delay,
        'waitfor' => :waitfor, 'waitforre' => :waitforre, 'waiteval' => :waiteval,
        'match' => :match, 'matchre' => :matchre, 'matchwait' => :matchwait,
        'wait' => :wait, 'move' => :move, 'nextroom' => :nextroom,
        'gosub' => :gosub_func, 'return' => :return_func,
        'if' => :if_func, 'while' => :while_func, 'else' => :else_func, 'elseif' => :elseif_func,
        'timer' => :timer, 'random' => :random, 'math' => :math_func,
        'eval' => :eval_func, 'evaluate' => :eval_func,
        'evalmath' => :evalmath_func, 'evaluatemath' => :evalmath_func,
        'debug' => :debuglevel, 'debuglevel' => :debuglevel,
        'js' => :js, 'javascript' => :js, 'jscall' => :jscall,
        'plugin' => :plugin, 'pluginscript' => :pluginscript,
        '{' => :blockstart, 'begin' => :blockstart, '}' => :blockend, 'end' => :blockend
      }.freeze

      # @param lines [Array<String>] source lines
      # @param file_name [String] friendly name of the main file
      # @param include_loader [#call, nil] filename => source String, for `include`
      # @param ignore_warnings [Boolean] if true, unknown lines are skipped not raised
      # @return [Program]
      def self.compile(lines, file_name: 'script', include_loader: nil, ignore_warnings: false)
        new(include_loader: include_loader, ignore_warnings: ignore_warnings).compile(lines, file_name)
      end

      # @return [ScriptFunctions] the function symbol for a keyword (:unknown if none)
      def self.function_type(keyword)
        FUNCTION_MAP.fetch(keyword, :unknown)
      end

      def initialize(include_loader: nil, ignore_warnings: false)
        @include_loader = include_loader
        @ignore_warnings = ignore_warnings
        @instructions = []
        @labels = {}
        @files = []
        @warnings = []
        @in_jsblock = false
      end

      # @return [Program]
      def compile(lines, file_name)
        file_id = add_file(file_name)
        Array(lines).each_with_index { |raw, i| append_line(raw, file_id, i + 1) }
        Program.new(@instructions, @labels, @files, @warnings)
      end

      private

      def add_file(name)
        @files << name
        @files.length - 1
      end

      def add_instruction(file_id, file_row, content, function)
        @instructions << Instruction.new(file_id, file_row, content, function)
      end

      # Process one raw source line (splitting on the inline-newline sentinel).
      def append_line(raw, file_id, file_row)
        raw.to_s.split(MULTILINE_SEP).each do |part|
          # Strip a leading UTF-8 BOM (Genie's .NET StreamReader does this transparently;
          # Ruby's File.read keeps it, which would break `include`/`#comment` on line 1).
          row = part.strip.delete_prefix(BOM)
          next if row.empty? # blank lines skipped
          next if skip_jsblock(row) # <% ... %> JS blocks are deferred (Decision 2); skip
          next if row.start_with?('#') # Genie treats a leading '#' as a comment (LoadFile)

          process_row(row, file_id, file_row)
        end
      end

      # Track/skip `<% ... %>` JavaScript blocks (Genie AppendFile jsblock handling:
      # opener line starts with `<%`, closer line ends with `%>`). JS execution is
      # deferred (design Decision 2), so the block body is skipped, not compiled.
      # @return [Boolean] true if +row+ was part of a JS block (caller should skip it)
      def skip_jsblock(row)
        if @in_jsblock
          @in_jsblock = false if row.end_with?('%>')
          return true
        end
        return false unless row.start_with?('<%')

        # An opener; stay in the block unless it also closes on the same line.
        @in_jsblock = !(row.length > 2 && row.end_with?('%>'))
        true
      end

      def process_row(row, file_id, file_row)
        row = rewrite_prefix(row)

        if label?(row)
          add_label(row, file_id, file_row)
          return
        end

        keyword = Text.keyword_string(row).downcase
        argument = Text.argument_string(row)
        row, keyword, argument = rewrite_if_n(row, keyword, argument) if keyword.start_with?('if_')

        function = self.class.function_type(keyword)
        return if dispatch_structural(function, row, argument, file_id, file_row)

        add_instruction(file_id, file_row, row, function)
      end

      # `%x = y` -> `setvariable x y`; `$x = y` -> `put #var x y`.
      def rewrite_prefix(row)
        if row.start_with?('%')
          row = "setvariable #{row[1..]}"
          row = row.sub(' = ', ' ') if row.include?(' = ')
        elsif row.start_with?('$')
          row = "put #var #{row[1..]}"
          row = row.sub(' = ', ' ') if row.include?(' = ')
        end
        row
      end

      def label?(row)
        row.rstrip.end_with?(':') && !row.strip.include?(' ')
      end

      def add_label(row, file_id, file_row)
        name = row.rstrip[0...-1]
        @labels[name.downcase] = @instructions.length
        add_instruction(file_id, file_row, row, :label)
      end

      # `if_N ...` -> `if %argcount >= N ...` (keyword becomes `if`).
      def rewrite_if_n(_row, keyword, argument)
        number = keyword[3..]
        row = if argument.downcase.start_with?('then')
                "if %argcount >= #{number} #{argument}"
              else
                "if %argcount >= #{number} then #{argument}"
              end
        [row, 'if', Text.argument_string(row)]
      end

      # Handle the functions that split/expand a line. Returns true if the row was
      # fully handled here (caller should not add it again).
      def dispatch_structural(function, row, argument, file_id, file_row)
        case function
        when :include
          handle_include(argument)
          true
        when :pluginscript
          true # deferred (plugins out of scope for now)
        when :if_func
          split_conditional(row, argument, file_id, file_row, 'then')
        when :while_func
          split_conditional(row, argument, file_id, file_row, 'do')
        when :else_func
          split_prefixed(argument, 'else', argument.strip, file_id, file_row)
        when :elseif_func
          split_prefixed(argument, 'else', "if #{argument.strip}", file_id, file_row)
        when :blockend
          split_prefixed(argument, '}', argument.strip, file_id, file_row)
        when :unknown
          @warnings << { file_id: file_id, file_row: file_row, content: row }
          raise Error, "Unknown script command: #{row}" unless @ignore_warnings

          true
        else
          false
        end
      end

      # Emit +head+ as its own line then recurse on +tail+, but only when +argument+
      # carried a trailing command. Returns true when it split.
      def split_prefixed(argument, head, tail, file_id, file_row)
        return false if argument.empty?

        function = head == '}' ? :blockend : :else_func
        add_instruction(file_id, file_row, head, function)
        append_line(tail, file_id, file_row)
        true
      end

      # Split `if <c> then <cmd>` / `while <c> do <cmd>`. Returns false for the
      # block-opening form (`... then` / `... do` with no trailing command), which
      # the caller then adds as-is.
      def split_conditional(row, argument, file_id, file_row, marker)
        return false if argument.rstrip.downcase.end_with?(" #{marker}")

        separator = " #{marker} "
        arg_idx = argument.downcase.index(separator)
        row_idx = row.downcase.index(separator)
        return invalid_conditional(row, marker, file_id, file_row) if arg_idx.nil? || row_idx.nil?

        remainder = argument[(arg_idx + separator.length)..].to_s.strip
        return invalid_conditional(row, marker, file_id, file_row) if remainder.empty?

        head = row[0...(row_idx + separator.length)].strip
        add_instruction(file_id, file_row, head, marker == 'then' ? :if_func : :while_func)
        append_line(remainder, file_id, file_row)
        true
      end

      # A malformed `if ... then` / `while ... do`. Under ignore_warnings this is
      # recorded and skipped (best-effort compile of a large corpus) instead of
      # aborting the whole parse. Returns true (the row is considered handled).
      def invalid_conditional(row, marker, file_id, file_row)
        message = "Invalid #{marker == 'then' ? 'IF' : 'WHILE'} statement: #{row}"
        raise Error, message unless @ignore_warnings

        @warnings << { file_id: file_id, file_row: file_row, content: row }
        true
      end

      def handle_include(filename)
        name = filename.strip
        return if @files.include?(name)

        included_id = add_file(name)
        return if name.downcase.end_with?('.js') # pure JS library; deferred (Decision 2)
        return unless @include_loader

        source = @include_loader.call(name)
        return unless source

        source.split(/\r?\n/).each_with_index { |line, i| append_line(line, included_id, i + 1) }
      end
    end
  end
end
