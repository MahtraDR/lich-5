# frozen_string_literal: true

module Lich
  module Genie
    # Shared store for a character's Genie global variables. One namespace with a
    # per-key persistence flag (Genie's bSaveToFile): persistent keys (#var/#svar)
    # are backed by variables.cfg; temp keys (#tvar) live only in memory. Reserved
    # game-state globals are resolved elsewhere ({Variables} via game_state).
    #
    # File-backed when +file+ is given (account-wide, cross-character via the shared
    # file); pure in-memory when nil (tests / #tvar-only). Reloads on external mtime
    # change so concurrent character processes see each other's persisted changes.
    #
    # Concurrency: this ONE store instance is shared by every Genie thread in the
    # process -- each running script's thread AND the downstream/socket thread that
    # fires #triggers (their `#var` actions land here too, e.g. a combat trigger's
    # `#var rimon 1`). All public methods are therefore serialized under @mutex.
    # Without it, a script's `#var` racing a trigger's `#var` corrupted the store:
    # reload_if_changed briefly EMPTIES the persistent keys before repopulating, so a
    # concurrent save_file could snapshot the emptied map and truncate variables.cfg,
    # permanently dropping globals ($qspell/$backpack/RIME going literal mid-combat).
    # {Triggers} and {StreamFilters} are locked for the same cross-thread reason.
    class GlobalStore
      # @param file [String, nil] path to variables.cfg, or nil for in-memory
      def initialize(file: nil)
        @file = file
        @values = {}
        @persistent = {}
        @mtime = nil
        @mutex = Mutex.new
        load_file
      end

      # @param name [String]
      # @return [String, nil]
      def get(name)
        @mutex.synchronize do
          reload_if_changed
          @values[name]
        end
      end

      # @param name [String]
      # @return [Boolean]
      def key?(name)
        @mutex.synchronize do
          reload_if_changed
          @values.key?(name)
        end
      end

      # @param name [String]
      # @param value [Object] coerced to String
      # @param persist [Boolean] true for #var/#svar (saved), false for #tvar (memory)
      # @return [String] the stored value
      def set(name, value, persist: true)
        @mutex.synchronize do
          reload_if_changed
          @values[name] = value.to_s
          @persistent[name] = persist
          save_file if persist && @file
          @values[name]
        end
      end

      # @param name [String]
      # @return [String, nil] the removed value, if any
      def delete(name)
        @mutex.synchronize do
          reload_if_changed
          removed = @values.delete(name)
          was_persistent = @persistent.delete(name)
          save_file if was_persistent && @file
          removed
        end
      end

      # @return [Array<String>]
      def keys
        @mutex.synchronize do
          reload_if_changed
          @values.keys
        end
      end

      private

      def load_file
        return unless @file && File.exist?(@file)

        VariableFile.load(@file).each do |key, value|
          @values[key] = value
          @persistent[key] = true
        end
        @mtime = File.mtime(@file)
      end

      # Pick up external changes (another character's process): reload persisted keys
      # from the file, keep in-memory temp (non-persistent) keys. Called only from
      # within @mutex, so no other Genie thread can observe an intermediate state.
      #
      # Rebuilds ATOMICALLY -- read the file first, then swap the maps in one step --
      # so @values is never transiently empty even if the read raises (a bad/locked
      # read leaves the in-memory copy intact rather than wiping it).
      def reload_if_changed
        return unless @file && File.exist?(@file)

        current = File.mtime(@file)
        return if current == @mtime

        loaded = VariableFile.load(@file)
        rebuilt = @values.reject { |key, _| @persistent[key] } # keep temp keys
        persistent = {}
        @persistent.each { |key, persist| persistent[key] = persist unless persist }
        loaded.each do |key, value|
          rebuilt[key] = value
          persistent[key] = true
        end
        @values = rebuilt
        @persistent = persistent
        @last_saved = VariableFile.dump(loaded)
        @mtime = current
      end

      # Persist is BEST-EFFORT: a failed disk write (e.g. Windows file lock) must
      # never raise into the script/trigger that set the variable -- the in-memory
      # value is already stored, which is what script logic reads. Skip redundant
      # writes (unchanged content) to cut churn. Failures are logged once, quietly.
      def save_file
        content = VariableFile.dump(@values.select { |key, _| @persistent[key] })
        return if content == @last_saved

        VariableFile.save(@file, @values.select { |key, _| @persistent[key] })
        @last_saved = content
        @mtime = File.mtime(@file) if File.exist?(@file)
      rescue StandardError => e
        return if @warned_persist

        @warned_persist = true
        Lich.log("Genie: variables.cfg persist failed (values kept in memory): #{e}") if defined?(Lich) && Lich.respond_to?(:log)
      end
    end
  end
end
