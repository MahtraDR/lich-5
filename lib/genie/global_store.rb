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
    # Concurrency note (prototype): set/delete reload-then-write; a competing write
    # in the small window between reload and rename can still lose a key. Config
    # writes are rare and low-stakes; true locking can come later.
    class GlobalStore
      # @param file [String, nil] path to variables.cfg, or nil for in-memory
      def initialize(file: nil)
        @file = file
        @values = {}
        @persistent = {}
        @mtime = nil
        load_file
      end

      # @param name [String]
      # @return [String, nil]
      def get(name)
        reload_if_changed
        @values[name]
      end

      # @param name [String]
      # @return [Boolean]
      def key?(name)
        reload_if_changed
        @values.key?(name)
      end

      # @param name [String]
      # @param value [Object] coerced to String
      # @param persist [Boolean] true for #var/#svar (saved), false for #tvar (memory)
      # @return [String] the stored value
      def set(name, value, persist: true)
        reload_if_changed
        @values[name] = value.to_s
        @persistent[name] = persist
        save_file if persist && @file
        @values[name]
      end

      # @param name [String]
      # @return [String, nil] the removed value, if any
      def delete(name)
        reload_if_changed
        removed = @values.delete(name)
        was_persistent = @persistent.delete(name)
        save_file if was_persistent && @file
        removed
      end

      # @return [Array<String>]
      def keys
        reload_if_changed
        @values.keys
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

      # Pick up external changes: reload persisted keys from the file, keep in-memory
      # temp (non-persistent) keys.
      def reload_if_changed
        return unless @file && File.exist?(@file)

        current = File.mtime(@file)
        return if current == @mtime

        @values.reject! { |key, _| @persistent[key] }
        @persistent.reject! { |_, persist| persist }
        VariableFile.load(@file).each do |key, value|
          @values[key] = value
          @persistent[key] = true
        end
        @mtime = current
      end

      def save_file
        VariableFile.save(@file, @values.select { |key, _| @persistent[key] })
        @mtime = File.mtime(@file) if File.exist?(@file)
      end
    end
  end
end
