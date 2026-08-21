# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Variables do
  subject(:variables) { described_class.new(game_state: game_state, global_store: store) }

  let(:game_state) { { 'health' => '100' } }
  let(:store) { Lich::Genie::GlobalStore.new(file: nil) }

  describe 'local variables' do
    it 'stores, reads, and deletes, coercing values to strings' do
      variables.local_set('count', 3)
      expect(variables.local_get('count')).to eq('3')
      expect(variables.local_key?('count')).to be(true)
      variables.local_delete('count')
      expect(variables.local_key?('count')).to be(false)
    end

    it 'is case-sensitive' do
      variables.local_set('Name', 'a')
      expect(variables.local_key?('name')).to be(false)
    end
  end

  describe 'global variables' do
    it 'reads from the store' do
      variables.global_set('gold', 500)
      expect(variables.global_get('gold')).to eq('500')
      expect(variables.global_key?('gold')).to be(true)
    end

    it 'falls back to reserved game state when not in the store' do
      expect(variables.global_get('health')).to eq('100')
      expect(variables.global_key?('health')).to be(true)
      expect(variables.global_get('missing')).to be_nil
    end

    it 'lets a stored global shadow reserved game state' do
      variables.global_set('health', '42')
      expect(variables.global_get('health')).to eq('42')
    end

    it 'passes the persist flag through to the store' do
      variables.global_set('temp', 'x', persist: false)
      expect(variables.global_get('temp')).to eq('x')
    end

    it 'keeps local and global namespaces separate' do
      variables.local_set('x', 'local')
      variables.global_set('x', 'global')
      expect(variables.get(:local, 'x')).to eq('local')
      expect(variables.get(:global, 'x')).to eq('global')
    end
  end

  describe 'authoritative (live-wins) game state' do
    # A resolver may declare some names live-authoritative (SpellTimer.*, skill vars):
    # names it synthesizes each read with no writer to refresh a stored copy. For those,
    # live state must win over a stale value migrated into the store, or the stale copy
    # shadows reality forever (Ignite reading perpetually inactive -> endless recast).
    let(:game_state) do
      live = { 'SpellTimer.Ignite.active' => '1', 'health' => '100' }
      Object.new.tap do |o|
        o.define_singleton_method(:[]) { |n| live[n] }
        o.define_singleton_method(:key?) { |n| live.key?(n) }
        o.define_singleton_method(:authoritative?) { |n| n.start_with?('SpellTimer.') }
      end
    end

    it 'lets live state win over a stale stored value for authoritative names' do
      variables.global_set('SpellTimer.Ignite.active', '0') # e.g. migrated from a Genie variables.cfg
      expect(variables.global_get('SpellTimer.Ignite.active')).to eq('1')
    end

    it 'still falls back to the store for authoritative names the resolver returns nil for' do
      variables.global_set('SpellTimer.Unknown.active', '0')
      expect(variables.global_get('SpellTimer.Unknown.active')).to eq('0')
    end

    it 'does NOT flip precedence for non-authoritative reserved names (stored #var still wins)' do
      variables.global_set('health', '42')
      expect(variables.global_get('health')).to eq('42')
    end
  end
end
