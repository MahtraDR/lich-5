# frozen_string_literal: true

module Lich
  module Genie
    # Convenience facade tying the pipeline together: compile source with {Lexer},
    # build a {Variables} store, and construct/run an {Interpreter}. Used by the
    # GenieScript Lich glue and by tests.
    module Engine
      module_function

      # @param source [String, Array<String>] script source (or pre-split lines)
      # @param include_loader [#call, nil]
      # @param ignore_warnings [Boolean]
      # @return [Lexer::Program]
      def compile(source, include_loader: nil, ignore_warnings: false)
        lines = source.is_a?(Array) ? source : source.to_s.split(/\r?\n/)
        Lexer.compile(lines, include_loader: include_loader, ignore_warnings: ignore_warnings)
      end

      # Build an interpreter for +source+. Any remaining keyword ports (game:,
      # input:, echo:, hooks:, clock:, specials:) are passed through to Interpreter.
      #
      # @param source [String, Array<String>]
      # @param name [String]
      # @param variables [Variables, nil]
      # @param game_state [#[], #key?, nil] reserved-global resolver
      # @return [Interpreter]
      def build(source, name: 'genie', variables: nil, game_state: nil,
                ignore_warnings: false, include_loader: nil, **ports)
        program = compile(source, include_loader: include_loader, ignore_warnings: ignore_warnings)
        store = variables || Variables.new(game_state: game_state)
        Interpreter.new(program: program, variables: store, name: name, **ports)
      end

      # Build and run in one call.
      # @return [void]
      def run(source, **opts)
        build(source, **opts).run
      end
    end
  end
end
