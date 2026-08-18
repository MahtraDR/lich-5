# frozen_string_literal: true

module Lich
  # The Genie scripting engine: a clean-room Ruby port of the Genie4 (C#) script
  # interpreter, so Genie scripts run natively under Lich. See the design and the
  # behavior specs under docs/genie-engine-port.md and docs/genie-engine/.
  #
  # Enable with Lich::Genie.enabled = true. When enabled, `.cmd` scripts route to
  # this engine and `.wiz` handling is disabled; when disabled (the default),
  # WizardScript continues to handle `.cmd`/`.wiz`.
  module Genie
    # Raised for any Genie-engine evaluation/parse error. Callers that mirror
    # Genie's "swallow and default" behavior (e.g. `evalmath`) rescue this.
    class Error < StandardError; end

    @enabled = false

    class << self
      # @return [Boolean] whether the Genie engine is active for `.cmd` scripts
      attr_accessor :enabled

      # @return [Boolean]
      def enabled?
        @enabled == true
      end
    end
  end
end

require_relative 'genie/numeric'
require_relative 'genie/text'
require_relative 'genie/math_calc'
require_relative 'genie/math_eval'
require_relative 'genie/eval'
require_relative 'genie/variables'
require_relative 'genie/specials'
require_relative 'genie/substitution'
require_relative 'genie/call_stack'
require_relative 'genie/lexer'
require_relative 'genie/interpreter'
require_relative 'genie/engine'
