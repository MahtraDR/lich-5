# frozen_string_literal: true

module Lich
  module Genie
    # Process-wide registry of Genie `#trigger`s. Unlike front-end effects, a trigger
    # RUNS COMMANDS when a game line matches, so it is automation and lives in Lich
    # (clean-room port of Genie Globals.Triggers + FormMain.ParseTriggers).
    #
    # Faithful behaviors:
    #   * a trigger is active by default; `#class NAME off` sets `active=false` for
    #     every trigger whose class is NAME, `on` sets it true (Trigger.ToggleClass,
    #     Globals.cs:966). A trigger with no class is always active. A trigger added
    #     while its class is "off" is still created active (Genie's ctor default).
    #   * on a matching line the regex capture groups (1..n) are passed to the action.
    #   * keyed by pattern string, so `#untrigger PATTERN` / re-adding replaces it.
    #
    # The registry only decides WHAT fires; a caller-supplied executor runs the action
    # (see {#apply}). Matching is done under a lock, then actions are yielded OUTSIDE
    # the lock so an action that touches the registry (e.g. `#class`) can't deadlock.
    class Triggers
      Trigger = Struct.new(:pattern, :regex, :commands, :klass, :active)

      def initialize
        @triggers = {}
        @mutex = Mutex.new
      end

      # @return [void]
      def add(pattern, commands, klass: '')
        return if pattern.to_s.empty?

        @mutex.synchronize do
          @triggers[pattern.to_s] = Trigger.new(pattern.to_s, compile(pattern), commands.to_s, klass.to_s, true)
        end
      end

      # @return [void]
      def remove(pattern)
        @mutex.synchronize { @triggers.delete(pattern.to_s) }
      end

      # @return [void]
      def clear
        @mutex.synchronize { @triggers.clear }
      end

      # Toggle every trigger whose class == +name+ (Genie ToggleClass).
      # @return [void]
      def set_class(name, enabled)
        key = name.to_s
        return if key.empty?

        on = enabled ? true : false
        @mutex.synchronize do
          @triggers.each_value { |t| t.active = on if t.klass.casecmp?(key) }
        end
      end

      # @return [Array<Hash>] one entry per trigger, for display/inspection
      def list
        @mutex.synchronize do
          @triggers.values.map do |t|
            { 'pattern' => t.pattern, 'class' => t.klass, 'active' => t.active, 'commands' => t.commands }
          end
        end
      end

      # @return [Integer] number of registered triggers
      def count
        @mutex.synchronize { @triggers.length }
      end

      # Fire every active trigger matching +line+. Yields [commands, captures] for
      # each (captures = regex groups 1..n as strings). Matches are collected under the
      # lock and yielded outside it, so an action that touches the registry (e.g.
      # `#class`, `#trigger`) is safe.
      # @param line [String]
      # @yield [commands, captures]
      # @return [void]
      def apply(line)
        return unless line.is_a?(String)

        matches = @mutex.synchronize do
          @triggers.values.select(&:active).filter_map do |t|
            (md = t.regex.match(line)) && [t.commands, md.captures.map(&:to_s)]
          end
        end
        matches.each { |commands, captures| yield(commands, captures) }
      end

      # Diagnostic: every trigger whose regex matches +line+, with its class and
      # active state -- so a trace can tell "the pattern did not match" apart from
      # "it matched but its class is off" (the usual reason a trigger looks dead).
      # Does NOT run any actions.
      # @param line [String]
      # @return [Array<Hash>]
      def diagnose(line)
        return [] unless line.is_a?(String)

        @mutex.synchronize do
          @triggers.values.filter_map do |t|
            next unless t.regex.match?(line)

            { 'pattern' => t.pattern, 'class' => t.klass, 'active' => t.active }
          end
        end
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
