# frozen_string_literal: true

module Lich
  module Genie
    # Pure, game-agnostic helpers for Genie's structured reserved variables, so the
    # (Lich-coupled) LichGameState resolver stays thin and this logic is unit-testable.
    #
    # Covers the two structured namespaces the real scripts use heavily:
    #   * $SpellTimer.<Spell>.active / .duration  (dotted object vars)
    #   * indicator flags ($bleeding, $dead, $standing, ...) via ICONMAP ids
    #
    # Spell-name matching is space-insensitive: Genie uses CamelCase ("BlufmorGaraen")
    # while the game/Lich uses spaced names ("Blufmor Garaen").
    module Reserved
      SPELL_TIMER = /\ASpellTimer\.(?<spell>.+)\.(?<field>active|duration)\z/i

      # Genie flag name => Lich indicator id (from ICONMAP).
      INDICATOR_IDS = {
        'bleeding'  => 'IconBLEEDING',
        'dead'      => 'IconDEAD',
        'hidden'    => 'IconHIDDEN',
        'invisible' => 'IconINVISIBLE',
        'kneeling'  => 'IconKNEELING',
        'prone'     => 'IconPRONE',
        'sitting'   => 'IconSITTING',
        'standing'  => 'IconSTANDING',
        'stunned'   => 'IconSTUNNED',
        'webbed'    => 'IconWEBBED',
        'joined'    => 'IconJOINED',
        'poisoned'  => 'IconPOISONED',
        'diseased'  => 'IconDISEASED'
      }.freeze

      module_function

      # @param name [String]
      # @return [Boolean] whether +name+ is a $SpellTimer.<spell>.<field> reference
      def spell_timer?(name)
        name.to_s.match?(SPELL_TIMER)
      end

      # Resolve a SpellTimer reference against an active-spells hash (DR semantics:
      # a spell present in the hash is active, its value is the duration).
      #
      # @param active_spells [Hash{String=>Integer}] name => duration
      # @param name [String] e.g. "SpellTimer.BlufmorGaraen.active"
      # @return [Integer, nil] 1/0 for active, the duration for duration, nil if not a match
      def spell_timer(active_spells, name)
        match = name.to_s.match(SPELL_TIMER)
        return nil unless match

        target = despace(match[:spell])
        entry = active_spells.find { |spell, _| despace(spell) == target }
        case match[:field].downcase
        when 'active' then entry ? 1 : 0
        when 'duration' then entry ? entry[1] : 0
        end
      end

      # @param name [String]
      # @return [String, nil] the ICONMAP id for an indicator flag, or nil
      def indicator_id(name)
        INDICATOR_IDS[name.to_s.downcase]
      end

      def despace(text)
        text.to_s.downcase.delete(' ')
      end
    end
  end
end
