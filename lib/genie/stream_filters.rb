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
    # Patterns are Genie regexes (invalid ones fall back to a literal match).
    #
    # Class gating: a classed gag/sub is only applied while its class is ON, exactly
    # like #triggers (Genie's #class toggles gags/subs/triggers/highlights alike -- the
    # ClassList in Globals.cs -- distinct from the SCRIPT-LOCAL action-class store). A
    # filter with no class is always active; a filter added while its class is off is
    # still created active (Genie's ctor default, matching Triggers). #class on/off is
    # wired here via {#set_class} (LichHookSink), the same call that toggles triggers.
    class StreamFilters
      Gag = Struct.new(:regex, :klass, :active)
      Sub = Struct.new(:regex, :replacement, :klass, :active)

      def initialize
        @gags = {}
        @subs = {}
        @mutex = Mutex.new
      end

      # @return [void]
      def add_gag(pattern, klass: nil)
        return if pattern.to_s.empty?

        @mutex.synchronize { @gags[pattern.to_s] = Gag.new(compile(pattern), klass.to_s, true) }
      end

      # @return [void]
      def remove_gag(pattern)
        @mutex.synchronize { @gags.delete(pattern.to_s) }
      end

      # @return [void]
      def add_sub(pattern, replacement, klass: nil)
        return if pattern.to_s.empty?

        @mutex.synchronize { @subs[pattern.to_s] = Sub.new(compile(pattern), replacement.to_s, klass.to_s, true) }
      end

      # @return [void]
      def remove_sub(pattern)
        @mutex.synchronize { @subs.delete(pattern.to_s) }
      end

      # Toggle every gag/sub whose class == +name+ (Genie ToggleClass; same semantics
      # as {Triggers#set_class}). A no-class filter is never matched here, so it stays on.
      # @return [void]
      def set_class(name, enabled)
        key = name.to_s
        return if key.empty?

        on = enabled ? true : false
        @mutex.synchronize do
          @gags.each_value { |gag| gag.active = on if gag.klass.casecmp?(key) }
          @subs.each_value { |sub| sub.active = on if sub.klass.casecmp?(key) }
        end
      end

      # Apply all ACTIVE gags then ACTIVE subs to one downstream line.
      # @param line [String]
      # @return [String, nil] the rewritten line, or nil to suppress it (gag)
      def apply(line)
        return line unless line.is_a?(String)

        gags, subs = @mutex.synchronize { [@gags.values, @subs.values] }
        return nil if gags.any? { |gag| gag.active && gag.regex.match?(line) }

        subs.reduce(line) { |acc, sub| sub.active ? acc.gsub(sub.regex, sub.replacement) : acc }
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
