# frozen_string_literal: true

module Lich
  module Genie
    # Opt-in "surface assess exist-ids" shim.
    #
    # DragonRealms sends each creature in the ASSESS combat stream as an id-bearing
    # link tag -- `<d cmd='look #78195083'>an elder Adan'f sorcerer</d>` -- but Lich
    # strips that tag before scripts see it, so the exist-id disappears from the
    # visible text. Front-ends like ProfanityFE re-surface it as `[#78195083]`, which
    # is why scripts such as Tirost's `commonbg.cmd` match `\[#(\d+)\]`. That makes
    # those scripts depend on a specific front-end.
    #
    # This shim moves that surfacing into Lich so it is front-end AND engine
    # independent: on each completed assess block it re-emits the creature lines with
    # the exist-id spliced into the visible text (`Name [#id]`), in the exact place a
    # front-end would put it. The UNMODIFIED Genie scripts then match `[#id]` whether
    # they run under native Genie (Lich proxies the emitted line to the client) OR
    # under the in-Lich Genie engine (the line is fed to the Genie scripts' match
    # buffer). The id is taken straight from the tag -- no re-parsing of ASSESS.
    #
    # The original assess output is passed through untouched (XMLData/Creature parsing
    # is unaffected); the enriched lines are ADDED, so nothing downstream breaks.
    #
    # Off by default; enable per character with `Lich::Genie::AssessIds.enabled = true`.
    module AssessIds
      # The ASSESS creature link: `<d cmd='look #NNN'>display name</d>` (single or
      # double quotes; `-?\d+` matches DR's id form). The captured group 1 is the id.
      LOOK_TAG = %r{<d\s+cmd=['"]look #(-?\d+)['"][^>]*>.*?</d>}i
      ASSESS_OPEN = /<pushStream id=['"]assess['"]/
      POP = /<popStream/

      module_function

      # --- per-character toggle (persisted in lich_settings) ----------------

      # @return [Boolean]
      def enabled?
        read_flag(settings_key)
      end

      # Turn the shim on/off for the current character. Enabling installs the hook
      # immediately (best-effort); it also self-installs when the Genie engine's
      # downstream hook is set up, so it survives relogin under the in-Lich engine.
      # @param value [Object] truthy (true/on/yes/1) enables
      def enabled=(value)
        on = truthy?(value)
        write_flag(settings_key, on)
        on ? install! : (@active = false)
      end

      # @return [Boolean] whether the hook is currently doing work
      def active?
        @active ? true : false
      end

      # Install the pass-through DownstreamHook (idempotent) and arm the shim. The
      # hook only OBSERVES the stream and emits extra enriched lines; it returns the
      # server string unchanged, so the client display and XML parsing are untouched.
      # @return [void]
      def install!
        @active = true
        return if @installed
        return unless defined?(Lich::Common::DownstreamHook)

        @installed = true
        Lich::Common::DownstreamHook.add('genie-assess-ids', lambda { |server_string|
          observe(server_string)
          server_string
        }, persist: true)
      end

      # --- pure enrichment (unit-testable, no Lich deps) --------------------

      # Splice the exist-id into one raw assess line's visible text, returning the
      # stripped, enriched line -- or nil if the line carries no creature link.
      #
      #   "...facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2)..."
      #   -> "...facing an elder Adan'f sorcerer [#78195083] (2)..."
      #
      # @param raw_line [String]
      # @return [String, nil]
      def enrich(raw_line)
        text = raw_line.to_s
        return nil unless text =~ LOOK_TAG

        surfaced = text.gsub(LOOK_TAG) { |tag| "#{tag} [##{Regexp.last_match(1)}]" }
        line = strip_line(surfaced).to_s.strip
        line.empty? ? nil : line
      end

      # Enrich every creature line in a raw assess block (text spanning the
      # pushStream..popStream), dropping the header/blank/non-creature lines.
      # @param block [String]
      # @return [Array<String>]
      def enrich_block(block)
        block.to_s.split(/\r?\n/).filter_map { |line| enrich(line) }
      end

      # --- stream observation ----------------------------------------------

      # Accumulate an assess block across chunks; on its closing popStream, emit the
      # enriched creature lines. Never raises into the hook chain.
      # @param server_string [String]
      # @return [void]
      def observe(server_string)
        return unless @active

        chunk = server_string.to_s
        @buffer = if @buffer
                    @buffer + chunk
                  elsif chunk =~ ASSESS_OPEN
                    chunk
                  end
        return if @buffer.nil? || !(@buffer =~ POP)

        open_at = @buffer =~ ASSESS_OPEN
        segment = open_at ? @buffer[open_at..] : @buffer
        block = segment[/\A.*?<popStream[^>]*>/m] || segment
        @buffer = nil
        deliver(enrich_block(block))
      rescue StandardError => e
        @buffer = nil
        safe_respond("--- Lich: genie assess-ids error: #{e}")
      end

      # Deliver enriched lines to whichever match channel this environment uses:
      #   * native Genie (front-end == 'genie'): the client game stream (what Genie
      #     matches IS what it displays), via _respond.
      #   * otherwise (the in-Lich Genie engine, or any other FE): the running
      #     scripts' downstream buffers, via Script.new_downstream -- so Genie
      #     `matchwait`/`matchre` sees it without a duplicate line on the front-end.
      # @param lines [Array<String>]
      # @return [void]
      def deliver(lines)
        return if lines.nil? || lines.empty?

        native_genie = defined?($frontend) && $frontend == 'genie'
        lines.each do |line|
          if native_genie
            safe_client(line)
          elsif defined?(Script) && Script.respond_to?(:new_downstream)
            Script.new_downstream(line)
          end
        end
      end

      # --- helpers ----------------------------------------------------------

      # strip_xml is a top-level (private on Object) def in a running Lich, so
      # respond_to?(:strip_xml) is FALSE even though it is callable; call it directly
      # and fall back to a naive tag-strip only when it is genuinely absent (headless
      # specs). See GenieScript.strip_xml_line for the same rationale.
      def strip_line(text)
        strip_xml(text).to_s
      rescue NameError
        text.to_s.gsub(/<[^>]+>/, '')
      end

      def safe_respond(message)
        respond(message)
      rescue StandardError
        nil
      end

      def safe_client(line)
        _respond(line)
      rescue StandardError
        nil
      end

      def truthy?(value)
        value.to_s =~ /\A(1|on|true|yes)\z/i ? true : false
      end

      def settings_key
        "genie_assess_ids:#{safe_xml(:game)}:#{safe_xml(:name)}"
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

      def read_flag(key)
        return false unless persistence_available?

        truthy?(Lich.db.get_first_value('SELECT value FROM lich_settings WHERE name=?;', [key]))
      rescue StandardError
        false
      end

      def write_flag(key, value)
        return unless persistence_available?

        Lich.db.execute('CREATE TABLE IF NOT EXISTS lich_settings (name TEXT NOT NULL, value TEXT, PRIMARY KEY(name));')
        Lich.db.execute('INSERT OR REPLACE INTO lich_settings(name,value) values(?,?);', [key, value.to_s])
      rescue StandardError
        nil
      end
    end
  end
end
