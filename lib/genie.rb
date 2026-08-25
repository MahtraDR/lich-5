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
    # Engine build id. BUMP THIS on every shipped change so a tester can confirm they
    # actually picked up a branch update: `;eq echo Lich::Genie::VERSION`. The deploy
    # path (`;lich5-update --branch=...`) overwrites files from a tarball WITHOUT moving
    # git HEAD, so `git log`/commit hashes are not a reliable "which version am I on"
    # signal -- this constant is. Format: MAJOR.MINOR.PATCH (YYYY-MM-DD).
    VERSION = '0.10.4 (2026-08-25)'

    # Raised for any Genie-engine evaluation/parse error. Callers that mirror
    # Genie's "swallow and default" behavior (e.g. `evalmath`) rescue this.
    class Error < StandardError; end

    @enabled_by_key = nil
    @config_dir = nil
    @global_store = nil

    class << self
      # Whether the Genie engine is active for `.cmd` scripts. Persisted
      # PER-CHARACTER in lich.db3 (survives relogin and reset-to-branch; other
      # characters are unaffected, so their WizardScript `.cmd`/`.wiz` keep working).
      #
      # The per-character key (`genie_enabled:<game>:<char>`) is derived from live
      # XMLData, which is EMPTY until the character stream arrives. So we cache per
      # resolved key and, crucially, do NOT cache a lookup made before login (empty
      # game/char) -- otherwise a premature check would memoize a false "off" that
      # never re-reads, and the toggle would appear not to persist across relogs.
      # @return [Boolean]
      def enabled?
        key = settings_key
        return read_enabled(key) unless character_scoped? # pre-login: read live, never cache

        @enabled_by_key ||= {}
        @enabled_by_key[key] = read_enabled(key) unless @enabled_by_key.key?(key)
        @enabled_by_key[key] == true
      end

      # @return [Boolean]
      def enabled
        enabled?
      end

      # @param value [Object] truthy value (true/on/yes/1) enables the engine
      def enabled=(value)
        on = truthy?(value)
        (@enabled_by_key ||= {})[settings_key] = on
        write_enabled(settings_key, on)
      end

      # Drop the per-character enabled cache (test/administrative).
      # @return [void]
      def reset_enabled_cache!
        @enabled_by_key = nil
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

      # Process-wide gag/substitute registry (Model A, Decision 6), shared across
      # all Genie scripts and applied on the client-bound downstream stream.
      # @return [StreamFilters]
      def stream_filters
        @stream_filters ||= StreamFilters.new
      end

      # Process-wide trigger registry (Genie #trigger), shared across all Genie
      # scripts. Triggers fire commands on matching game lines (automation).
      # @return [Triggers]
      def triggers
        @triggers ||= Triggers.new
      end

      # Diagnostic: when true, the downstream hook echoes each (XML-stripped) line it
      # checks and each trigger that fires -- so a tester can see whether the stream is
      # reaching the trigger matcher live. Toggle with `;e Lich::Genie.trace_triggers = true`.
      attr_accessor :trace_triggers

      private

      def truthy?(value)
        value.to_s =~ /\A(1|on|true|yes)\z/i ? true : false
      end

      # Per-character key so enabling on one character never affects others.
      def settings_key
        "genie_enabled:#{safe_xml(:game)}:#{safe_xml(:name)}"
      end

      # True once the character stream has populated both game and name, so the
      # per-character key actually identifies a character (not `genie_enabled::`).
      def character_scoped?
        !safe_xml(:game).empty? && !safe_xml(:name).empty?
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

      def read_enabled(key)
        return false unless persistence_available?

        truthy?(Lich.db.get_first_value('SELECT value FROM lich_settings WHERE name=?;', [key]))
      rescue StandardError
        false
      end

      def write_enabled(key, value)
        return unless persistence_available?

        Lich.db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
        Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);', [key, value.to_s])
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
require_relative 'genie/assess_ids'
require_relative 'genie/variable_file'
require_relative 'genie/global_store'
require_relative 'genie/stream_filters'
require_relative 'genie/triggers'
require_relative 'genie/variables'
require_relative 'genie/specials'
require_relative 'genie/substitution'
require_relative 'genie/call_stack'
require_relative 'genie/js_arrays'
require_relative 'genie/command_router'
require_relative 'genie/trigger_runner'
require_relative 'genie/lexer'
require_relative 'genie/interpreter'
require_relative 'genie/engine'
