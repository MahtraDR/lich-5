# frozen_string_literal: true

require 'tmpdir'

module Lich
  # The Genie scripting engine: a clean-room Ruby port of the Genie4 (C#) script
  # interpreter, so Genie scripts run natively under Lich. See the design and the
  # behavior specs under docs/genie-engine-port.md and docs/genie-engine/.
  #
  # Enable with Lich::Genie.enabled = true. When enabled, `.cmd` scripts route to
  # this engine and `.wiz` handling is disabled; when disabled (the default),
  # WizardScript continues to handle `.cmd`/`.wiz`.
  #
  # Persistence uses Genie's own config-file model (no Lich DB): a Genie-style
  # `Config/` tree under {config_dir}. See docs Decision 7.
  module Genie
    # Raised for any Genie-engine evaluation/parse error. Callers that mirror
    # Genie's "swallow and default" behavior (e.g. `evalmath`) rescue this.
    class Error < StandardError; end

    @enabled = false
    @config_dir = nil
    @global_store = nil

    class << self
      # @return [Boolean] whether the Genie engine is active for `.cmd` scripts
      attr_accessor :enabled

      # @return [Boolean]
      def enabled?
        @enabled == true
      end

      # Root of the Genie config tree (mirrors Genie's layout). Defaults to
      # <SCRIPT_DIR>/GenieProfiles under Lich, or a temp dir when running headless.
      # @return [String]
      def config_dir
        @config_dir ||= File.join(defined?(SCRIPT_DIR) ? SCRIPT_DIR : Dir.tmpdir, 'GenieProfiles')
      end

      # @param path [String]
      def config_dir=(path)
        @config_dir = path
        @global_store = nil # rebuild against the new location
      end

      # Account-wide variables file (matches Genie's hardcoded Config/variables.cfg).
      # @return [String]
      def variables_file
        File.join(config_dir, 'Config', 'variables.cfg')
      end

      # Process-wide (per-character session) global store, shared across all
      # concurrently-running Genie scripts.
      # @return [GlobalStore]
      def global_store
        @global_store ||= GlobalStore.new(file: variables_file)
      end

      # Test/administrative hook to drop the memoized store.
      # @return [void]
      def reset_global_store!
        @global_store = nil
      end
    end
  end
end

require_relative 'genie/numeric'
require_relative 'genie/text'
require_relative 'genie/math_calc'
require_relative 'genie/math_eval'
require_relative 'genie/eval'
require_relative 'genie/reserved'
require_relative 'genie/variable_file'
require_relative 'genie/global_store'
require_relative 'genie/variables'
require_relative 'genie/specials'
require_relative 'genie/substitution'
require_relative 'genie/call_stack'
require_relative 'genie/lexer'
require_relative 'genie/interpreter'
require_relative 'genie/engine'
