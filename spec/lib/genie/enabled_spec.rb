# frozen_string_literal: true

require_relative '../../../lib/genie'

# The per-character enable toggle must survive relogins. The key is derived from
# live XMLData (empty until the character stream arrives), so these guard the
# caching/scoping logic that made the toggle "not stick": a premature (pre-login)
# check must not memoize a false that poisons the real, logged-in read.
RSpec.describe Lich::Genie do
  before do
    described_class.reset_enabled_cache!
    # Back the DB with an in-memory store keyed exactly like lich_settings.
    @store = {}
    allow(described_class).to receive(:persistence_available?).and_return(true)
    allow(described_class).to receive(:read_enabled) { |key| @store[key] == 'true' }
    allow(described_class).to receive(:write_enabled) { |key, value| @store[key] = value.to_s }
    # Default: logged in as DR:Alice unless a test overrides.
    stub_character('DR', 'Alice')
  end

  after { described_class.reset_enabled_cache! }

  def stub_character(game, name)
    allow(described_class).to receive(:safe_xml).with(:game).and_return(game)
    allow(described_class).to receive(:safe_xml).with(:name).and_return(name)
  end

  it 'persists an enabled toggle under the per-character key' do
    described_class.enabled = true
    expect(@store).to eq('genie_enabled:DR:Alice' => 'true')
    expect(described_class.enabled?).to be(true)
  end

  it 'reads a value written by a previous process (relog) fresh' do
    @store['genie_enabled:DR:Alice'] = 'true' # as if a prior session saved it
    described_class.reset_enabled_cache! # fresh process
    expect(described_class.enabled?).to be(true)
  end

  it 'keeps characters independent' do
    described_class.enabled = true # Alice on
    stub_character('DR', 'Bob')
    expect(described_class.enabled?).to be(false) # Bob unaffected
  end

  it 'does NOT let a pre-login check poison the post-login read (the relog bug)' do
    @store['genie_enabled:DR:Alice'] = 'true'
    # Pre-login: XMLData not yet populated -> key is genie_enabled:: -> miss/false.
    stub_character('', '')
    expect(described_class.enabled?).to be(false) # premature check
    # Character stream arrives; the real check must now see the stored true.
    stub_character('DR', 'Alice')
    expect(described_class.enabled?).to be(true)
  end

  it 'does not cache a pre-login read (re-reads live until scoped)' do
    stub_character('', '')
    described_class.enabled? # pre-login read
    stub_character('DR', 'Alice')
    @store['genie_enabled:DR:Alice'] = 'true'
    expect(described_class.enabled?).to be(true)
  end
end
