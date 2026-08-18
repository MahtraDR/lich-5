# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Variables do
  subject(:variables) { described_class.new(game_state: game_state, globals_backend: backend) }

  let(:game_state) { { 'health' => '100' } }
  let(:backend) { { 'persisted' => 'kept' } }

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
    it 'reads from the store first' do
      variables.global_set('gold', '500')
      expect(variables.global_get('gold')).to eq('500')
    end

    it 'falls back to the persistent backend, then to game state' do
      expect(variables.global_get('persisted')).to eq('kept')
      expect(variables.global_get('health')).to eq('100')
      expect(variables.global_key?('health')).to be(true)
      expect(variables.global_get('missing')).to be_nil
    end

    it 'keeps local and global namespaces separate' do
      variables.local_set('x', 'local')
      variables.global_set('x', 'global')
      expect(variables.get(:local, 'x')).to eq('local')
      expect(variables.get(:global, 'x')).to eq('global')
    end
  end
end
