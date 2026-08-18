# frozen_string_literal: true

module Lich
  module Genie
    # Storage for a Genie script's variables. Genie keeps two separate namespaces,
    # addressed by sigil, not by a fallback chain:
    #   * local (`%name`)  -- per-script, set by `var`/`setvariable` (m_oLocalVarList)
    #   * global (`$name`) -- shared, set by the `#var`/`#tvar`/`#svar` bar-commands
    #
    # Reserved locals (scriptname, numbered args, lastlabel, ...) are ordinary local
    # entries the interpreter seeds. Reserved globals that reflect live game state
    # (health, roundtime, standing, ...) are resolved through an injected
    # `game_state` object so this class stays free of any Lich/XMLData dependency.
    #
    # Ported from Genie4 Lists/Globals.cs + Script.cs local var handling. Keys are
    # case-sensitive strings and values are always stored as strings.
    class Variables
      # @param game_state [#[], #key?, nil] live game-state lookup for reserved
      #   globals (e.g. an XMLData adapter); consulted after the global store
      # @param globals_backend [#[]=, #[], #key?, #delete, nil] optional persistent
      #   global store (e.g. Lich Vars); consulted between the store and game_state
      def initialize(game_state: nil, globals_backend: nil)
        @local = {}
        @global = {}
        @game_state = game_state
        @globals_backend = globals_backend
      end

      # --- local (%) --------------------------------------------------------

      # @param name [String]
      # @return [String, nil]
      def local_get(name)
        @local[name]
      end

      # @param name [String]
      # @param value [Object] coerced to String
      # @return [String]
      def local_set(name, value)
        @local[name] = value.to_s
      end

      # @param name [String]
      # @return [String, nil] the removed value, if any
      def local_delete(name)
        @local.delete(name)
      end

      # @param name [String]
      # @return [Boolean]
      def local_key?(name)
        @local.key?(name)
      end

      # --- global ($) -------------------------------------------------------

      # @param name [String]
      # @return [String, nil] store, then persistent backend, then game state
      def global_get(name)
        return @global[name] if @global.key?(name)
        return @globals_backend[name] if @globals_backend&.key?(name)

        @game_state && @game_state[name]
      end

      # @param name [String]
      # @param value [Object] coerced to String
      # @return [String]
      def global_set(name, value)
        @global[name] = value.to_s
      end

      # @param name [String]
      # @return [String, nil]
      def global_delete(name)
        @global.delete(name)
      end

      # @param name [String]
      # @return [Boolean]
      def global_key?(name)
        @global.key?(name) ||
          (@globals_backend&.key?(name) || false) ||
          (@game_state&.key?(name) || false)
      end

      # Uniform accessors so shared resolution logic (e.g. Substitution) can work
      # against either namespace by symbol.
      #
      # @param scope [:local, :global]
      # @param name [String]
      # @return [String, nil]
      def get(scope, name)
        scope == :local ? local_get(name) : global_get(name)
      end

      # @param scope [:local, :global]
      # @param name [String]
      # @return [Boolean]
      def key?(scope, name)
        scope == :local ? local_key?(name) : global_key?(name)
      end
    end
  end
end
