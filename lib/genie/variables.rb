# frozen_string_literal: true

module Lich
  module Genie
    # A Genie script's variable view. Two namespaces addressed by sigil (not a
    # fallback chain):
    #   * local (`%name`)  -- per-script, in-memory (set by `var`/`setvariable`)
    #   * global (`$name`) -- shared via an injected {GlobalStore} (#var/#tvar/#svar)
    #
    # Reserved globals that reflect live game state (`$health`, ...) are resolved
    # through an injected `game_state` object, consulted after the store, so this
    # class stays free of any Lich/XMLData dependency.
    class Variables
      # @param game_state [#[], #key?, nil] reserved-global resolver (e.g. XMLData adapter)
      # @param global_store [GlobalStore, nil] shared global store (in-memory if nil)
      def initialize(game_state: nil, global_store: nil)
        @local = {}
        @game_state = game_state
        @store = global_store || GlobalStore.new(file: nil)
      end

      # --- local (%) --------------------------------------------------------

      # @return [String, nil]
      def local_get(name)
        @local[name]
      end

      # @return [String]
      def local_set(name, value)
        @local[name] = value.to_s
      end

      # @return [String, nil] the removed value, if any
      def local_delete(name)
        @local.delete(name)
      end

      # @return [Boolean]
      def local_key?(name)
        @local.key?(name)
      end

      # --- global ($) -------------------------------------------------------

      # @return [String, nil] store value, else reserved game state
      def global_get(name)
        value = @store.get(name)
        return value unless value.nil?

        @game_state && @game_state[name]
      end

      # @param persist [Boolean] true for #var/#svar, false for #tvar
      # @return [String]
      def global_set(name, value, persist: true)
        @store.set(name, value, persist: persist)
      end

      # @return [String, nil]
      def global_delete(name)
        @store.delete(name)
      end

      # @return [Boolean]
      def global_key?(name)
        @store.key?(name) || (@game_state&.key?(name) || false)
      end

      # --- uniform accessors (used by shared resolution logic) --------------

      # @param scope [:local, :global]
      # @return [String, nil]
      def get(scope, name)
        scope == :local ? local_get(name) : global_get(name)
      end

      # @param scope [:local, :global]
      # @return [Boolean]
      def key?(scope, name)
        scope == :local ? local_key?(name) : global_key?(name)
      end
    end
  end
end
