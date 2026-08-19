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

    @enabled = nil
    @config_dir = nil
    @global_store = nil

    class << self
      # Whether the Genie engine is active for `.cmd` scripts. Persisted
      # PER-CHARACTER in lich.db3 (survives relogin and reset-to-branch; other
      # characters are unaffected, so their WizardScript `.cmd`/`.wiz` keep working).
      # @return [Boolean]
      def enabled?
        @enabled = load_enabled if @enabled.nil?
        @enabled == true
      end

      # @return [Boolean]
      def enabled
        enabled?
      end

      # @param value [Object] truthy value (true/on/yes/1) enables the engine
      def enabled=(value)
        @enabled = truthy?(value)
        save_enabled(@enabled)
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

      private

      def truthy?(value)
        value.to_s =~ /\A(1|on|true|yes)\z/i ? true : false
      end

      # Per-character key so enabling on one character never affects others.
      def settings_key
        game = safe_xml(:game)
        char = safe_xml(:name)
        "genie_enabled:#{game}:#{char}"
      end

      def safe_xml(attribute)
        return '' unless defined?(XMLData) && XMLData.respond_to?(attribute)

        XMLData.public_send(attribute).to_s
      rescue StandardError
        ''
      end

      def persistence_available?
        defined?(Lich) && Lich.respond_to?(:db) && Lich.db
      rescue StandardError
        false
      end

      def load_enabled
        return false unless persistence_available?

        truthy?(Lich.db.get_first_value('SELECT value FROM lich_settings WHERE name=?;', [settings_key]))
      rescue StandardError
        false
      end

      def save_enabled(value)
        return unless persistence_available?

        Lich.db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
        Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);', [settings_key, value.to_s])
      rescue StandardError
        nil
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
require_relative 'genie/command_router'
require_relative 'genie/lexer'
require_relative 'genie/interpreter'
require_relative 'genie/engine'
