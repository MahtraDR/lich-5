# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Reserved do
  describe '.spell_timer?' do
    it 'recognizes SpellTimer.<spell>.<field> references' do
      expect(described_class.spell_timer?('SpellTimer.BlufmorGaraen.active')).to be(true)
      expect(described_class.spell_timer?('SpellTimer.Dragons Breath.duration')).to be(true)
      expect(described_class.spell_timer?('health')).to be(false)
      expect(described_class.spell_timer?('SpellTimer.Foo.bar')).to be(false)
    end
  end

  describe '.skill_var (EXPTracker bridge)' do
    # Fake DRSkill: getxp = mindstate/learning rate, getrank = ranks, getpercent = %.
    let(:skills) do
      Object.new.tap do |o|
        o.define_singleton_method(:getxp) { |s| { 'Small Edged' => 12, 'Perception' => 34 }[s] || 0 }
        o.define_singleton_method(:getrank) { |s| { 'Scouting' => 150 }[s] || 0 }
        o.define_singleton_method(:getpercent) { |s| { 'Athletics' => 88 }[s] || 0 }
      end
    end

    it 'recognizes $<Skill>.LearningRate/.Ranks/.Percent references' do
      expect(described_class.skill_var?('Athletics.LearningRate')).to be(true)
      expect(described_class.skill_var?('Scouting.Ranks')).to be(true)
      expect(described_class.skill_var?('Small_Edged.Percent')).to be(true)
      expect(described_class.skill_var?('health')).to be(false)
      expect(described_class.skill_var?('SpellTimer.Foo.active')).to be(false)
    end

    it 'maps LearningRate to mindstate and underscores to spaces' do
      expect(described_class.skill_var('Small_Edged.LearningRate', skills: skills)).to eq(12)
      expect(described_class.skill_var('Perception.LearningRate', skills: skills)).to eq(34)
    end

    it 'maps Ranks/Rank to rank and Percent to percent' do
      expect(described_class.skill_var('Scouting.Ranks', skills: skills)).to eq(150)
      expect(described_class.skill_var('Scouting.Rank', skills: skills)).to eq(150)
      expect(described_class.skill_var('Athletics.Percent', skills: skills)).to eq(88)
    end

    it 'returns 0 for an unknown skill and nil for a non-skill name' do
      expect(described_class.skill_var('Nonexistent.LearningRate', skills: skills)).to eq(0)
      expect(described_class.skill_var('health', skills: skills)).to be_nil
    end
  end

  describe '.spell_timer' do
    # Genie uses the collapsed form; the game/Lich uses the display name.
    let(:active) { { 'Blufmor Garaen' => 42, 'Dragons Breath' => 5, "Glythtide's Gift" => 8 } }

    it 'matches space-insensitively and reports active as 1/0' do
      expect(described_class.spell_timer(active, 'SpellTimer.BlufmorGaraen.active')).to eq(1)
      expect(described_class.spell_timer(active, 'SpellTimer.Vertigo.active')).to eq(0)
    end

    it "strips apostrophes and hyphens like SpellTimer (\"Glythtide's Gift\" -> GlythtidesGift)" do
      expect(described_class.spell_timer(active, 'SpellTimer.GlythtidesGift.active')).to eq(1)
      expect(described_class.spell_timer(active, 'SpellTimer.GlythtidesGift.duration')).to eq(8)
    end

    it 'returns the duration for an active spell, 0 when inactive' do
      expect(described_class.spell_timer(active, 'SpellTimer.DragonsBreath.duration')).to eq(5)
      expect(described_class.spell_timer(active, 'SpellTimer.Vertigo.duration')).to eq(0)
    end

    it 'returns nil for a non-SpellTimer name' do
      expect(described_class.spell_timer(active, 'health')).to be_nil
    end
  end

  describe '.time_var (TimeTracker -> moonwatch bridge)' do
    it 'recognizes $Time.isDay / $Time.is<Moon>Up references only' do
      expect(described_class.time_var?('Time.isDay')).to be(true)
      expect(described_class.time_var?('Time.isXibarUp')).to be(true)
      expect(described_class.time_var?('Time.isYavashUp')).to be(true)
      expect(described_class.time_var?('Time.isKatambaUp')).to be(true)
      expect(described_class.time_var?('Time.isPlutoUp')).to be(false)
      expect(described_class.time_var?('health')).to be(false)
    end

    it 'maps a moon to 1/0 by presence in the visible list (case-insensitive)' do
      visible = %w[xibar katamba]
      expect(described_class.time_var('Time.isXibarUp', visible_moons: visible, day: nil)).to eq(1)
      expect(described_class.time_var('Time.isKatambaUp', visible_moons: visible, day: nil)).to eq(1)
      expect(described_class.time_var('Time.isYavashUp', visible_moons: visible, day: nil)).to eq(0)
      expect(described_class.time_var('Time.isXibarUp', visible_moons: ['XIBAR'], day: nil)).to eq(1)
    end

    it 'maps isDay from the day flag' do
      expect(described_class.time_var('Time.isDay', visible_moons: nil, day: true)).to eq(1)
      expect(described_class.time_var('Time.isDay', visible_moons: nil, day: false)).to eq(0)
    end

    it 'returns nil when the data is unavailable (so the store #var wins as fallback)' do
      expect(described_class.time_var('Time.isXibarUp', visible_moons: nil, day: nil)).to be_nil
      expect(described_class.time_var('Time.isDay', visible_moons: nil, day: nil)).to be_nil
      # an empty visible list is DATA (moonwatch ran, no moons up), not "unavailable"
      expect(described_class.time_var('Time.isXibarUp', visible_moons: [], day: nil)).to eq(0)
    end

    it 'returns nil for a non-Time name' do
      expect(described_class.time_var('health', visible_moons: %w[xibar], day: true)).to be_nil
    end
  end

  describe '.indicator_check' do
    it 'maps every Genie status flag to its Lich check* predicate' do
      {
        'standing' => :checkstanding, 'kneeling' => :checkkneeling,
        'sitting' => :checksitting, 'prone' => :checkprone,
        'bleeding' => :checkbleeding, 'dead' => :checkdead,
        'hidden' => :checkhidden, 'invisible' => :checkinvisible,
        'stunned' => :checkstunned, 'webbed' => :checkwebbed,
        'joined' => :checkgrouped, 'poisoned' => :checkpoison,
        'diseased' => :checkdisease
      }.each do |flag, predicate|
        expect(described_class.indicator_check(flag)).to eq(predicate)
      end
    end

    it 'is case-insensitive and nil for unknown flags' do
      expect(described_class.indicator_check('STANDING')).to eq(:checkstanding)
      expect(described_class.indicator_check('Kneeling')).to eq(:checkkneeling)
      expect(described_class.indicator_check('nonsense')).to be_nil
    end
  end
end
