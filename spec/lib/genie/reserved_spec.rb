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

  describe '.spell_timer' do
    # Genie uses spaceless CamelCase; the game/Lich uses spaced names.
    let(:active) { { 'Blufmor Garaen' => 42, 'Dragons Breath' => 5 } }

    it 'matches space-insensitively and reports active as 1/0' do
      expect(described_class.spell_timer(active, 'SpellTimer.BlufmorGaraen.active')).to eq(1)
      expect(described_class.spell_timer(active, 'SpellTimer.Vertigo.active')).to eq(0)
    end

    it 'returns the duration for an active spell, 0 when inactive' do
      expect(described_class.spell_timer(active, 'SpellTimer.DragonsBreath.duration')).to eq(5)
      expect(described_class.spell_timer(active, 'SpellTimer.Vertigo.duration')).to eq(0)
    end

    it 'returns nil for a non-SpellTimer name' do
      expect(described_class.spell_timer(active, 'health')).to be_nil
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
