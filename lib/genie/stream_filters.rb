# frozen_string_literal: true

module Lich
  module Genie
    # Model A (design doc Decision 6): `#gag`/`#ignore`/`#sub`/`#substitute` are
    # applied on Lich's client-bound downstream stream, NOT emitted as <genieHook>
    # tags. This holds the gag + substitution registries and the pure #apply that a
    # single Lich DownstreamHook runs per line.
    #
    # Universal (works on any front-end, zero front-end code) and non-destructive:
    # the DownstreamHook runs at games.rb after the raw line is already in
    # $_SERVERBUFFER_ and delivered to scripts, so reget/log.lic/other scripts still
    # see the original -- only the client display is filtered.
    #
    # Keyed by pattern string so an #ungag/#unsub of the same pattern removes it.
    # Patterns are Genie regexes (invalid ones fall back to a literal match). Class
    # gating (a gag only active when its class is on) is not yet modeled -- filters
    # apply unconditionally; the class is retained for a future gate.
    class StreamFilters
      Gag = Struct.new(:regex, :klass)
      Sub = Struct.new(:regex, :replacement, :klass)

      def initialize
        @gags = {}
        @subs = {}
        @mutex = Mutex.new
      end

      # @return [void]
      def add_gag(pattern, klass: nil)
        return if pattern.to_s.empty?

        @mutex.synchronize { @gags[pattern.to_s] = Gag.new(compile(pattern), klass.to_s) }
      end

      # @return [void]
      def remove_gag(pattern)
        @mutex.synchronize { @gags.delete(pattern.to_s) }
      end

      # @return [void]
      def add_sub(pattern, replacement, klass: nil)
        return if pattern.to_s.empty?

        @mutex.synchronize { @subs[pattern.to_s] = Sub.new(compile(pattern), replacement.to_s, klass.to_s) }
      end

      # @return [void]
      def remove_sub(pattern)
        @mutex.synchronize { @subs.delete(pattern.to_s) }
      end

      # Apply all gags then subs to one downstream line.
      # @param line [String]
      # @return [String, nil] the rewritten line, or nil to suppress it (gag)
      def apply(line)
        return line unless line.is_a?(String)

        gags, subs = @mutex.synchronize { [@gags.values, @subs.values] }
        return nil if gags.any? { |gag| gag.regex.match?(line) }

        subs.reduce(line) { |acc, sub| acc.gsub(sub.regex, sub.replacement) }
      end

      private

      def compile(pattern)
        Regexp.new(pattern.to_s)
      rescue RegexpError
        Regexp.new(Regexp.escape(pattern.to_s))
      end
    end
  end
end
