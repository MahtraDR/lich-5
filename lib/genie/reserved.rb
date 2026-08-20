# frozen_string_literal: true

module Lich
  module Genie
    # Pure, game-agnostic helpers for Genie's structured reserved variables, so the
    # (Lich-coupled) LichGameState resolver stays thin and this logic is unit-testable.
    #
    # Covers the two structured namespaces the real scripts use heavily:
    #   * $SpellTimer.<Spell>.active / .duration  (dotted object vars)
    #   * indicator flags ($bleeding, $dead, $standing, ...) via Lich check* predicates
    #
    # Spell-name matching mirrors the Genie SpellTimer plugin's spellNameToVariableName
    # (strips spaces, apostrophes, and hyphens): Genie scripts use the collapsed form
    # ("BlufmorGaraen", "GlythtidesGift") while the game/Lich uses the display name
    # ("Blufmor Garaen", "Glythtide's Gift").
    module Reserved
      SPELL_TIMER = /\ASpellTimer\.(?<spell>.+)\.(?<field>active|duration)\z/i

      # `$<Skill>.LearningRate` / `.Ranks` / `.Rank` / `.Percent` -- the Genie
      # EXPTracker plugin's per-skill variables. Genie uses underscores for spaces
      # ("Small_Edged"); we map them to the game's spaced names for the skill lookup.
      SKILL_VAR = /\A(?<skill>[A-Za-z][A-Za-z_]*)\.(?<field>learningrate|ranks?|percent)\z/i

      # Genie flag name => Lich global status predicate. These work for both DR and
      # GS (unlike XMLData.indicator, which DR does not populate).
      INDICATOR_CHECKS = {
        'bleeding'  => :checkbleeding,
        'dead'      => :checkdead,
        'hidden'    => :checkhidden,
        'invisible' => :checkinvisible,
        'kneeling'  => :checkkneeling,
        'prone'     => :checkprone,
        'sitting'   => :checksitting,
        'standing'  => :checkstanding,
        'stunned'   => :checkstunned,
        'webbed'    => :checkwebbed,
        'joined'    => :checkgrouped,
        'poisoned'  => :checkpoison,
        'diseased'  => :checkdisease
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
      # @return [Boolean] whether +name+ is a $<Skill>.<field> (EXPTracker) reference
      def skill_var?(name)
        name.to_s.match?(SKILL_VAR)
      end

      # Resolve a $<Skill>.LearningRate/.Ranks/.Percent reference (Genie EXPTracker)
      # against a skills provider (e.g. DR's DRSkill: getxp = mindstate/learning rate,
      # getrank = ranks, getpercent = % to next rank). Genie underscores map to spaces.
      #
      # @param name [String] e.g. "Small_Edged.LearningRate"
      # @param skills [#getxp, #getrank, #getpercent]
      # @return [Integer, nil] the value, or nil if +name+ isn't a skill reference
      def skill_var(name, skills:)
        match = name.to_s.match(SKILL_VAR)
        return nil unless match

        skill = match[:skill].tr('_', ' ')
        case match[:field].downcase
        when 'learningrate' then skills.getxp(skill)
        when 'rank', 'ranks' then skills.getrank(skill)
        when 'percent' then skills.getpercent(skill)
        end
      end

      # @param name [String]
      # @return [Symbol, nil] the Lich status-predicate method for a flag, or nil
      def indicator_check(name)
        INDICATOR_CHECKS[name.to_s.downcase]
      end

      # Collapse a spell name for matching: strip spaces, apostrophes, and hyphens
      # (matches the SpellTimer plugin's spellNameToVariableName).
      def despace(text)
        text.to_s.downcase.gsub(/[\s'-]/, '')
      end
    end
  end
end
