# frozen_string_literal: true

require 'rspec'
require 'ostruct'

# Setup load path (standalone spec, no spec_helper dependency)
LIB_DIR = File.join(File.expand_path('../../../..', __dir__), 'lib') unless defined?(LIB_DIR)

# Ensure Lich::DragonRealms namespace exists
module Lich; module DragonRealms; end; end

# Mock Lich::Messaging — always reopen (no guard) because other specs
# may define Lich::Messaging without msg/messages/clear_messages!.
module Lich
  module Messaging
    @messages = []

    class << self
      def messages
        @messages ||= []
      end

      def clear_messages!
        @messages = []
      end

      def msg(type, message)
        @messages ||= []
        @messages << { type: type, message: message }
      end
    end
  end
end

# Mock Lich::Util for issue_command
module Lich
  module Util
    def self.issue_command(_command, _start, _end_pattern, **_opts)
      []
    end
  end
end unless defined?(Lich::Util)

# ── Mock DRC ──────────────────────────────────────────────────────────
# Define at top level first (crafting spec does the same), then alias
# into Lich::DragonRealms so code inside the namespace resolves correctly.
module DRC
  def self.bput(_command, *_patterns)
    nil
  end

  def self.right_hand
    nil
  end

  def self.left_hand
    nil
  end

  def self.message(_msg); end

  def self.fix_standing; end
end unless defined?(DRC)

Lich::DragonRealms::DRC = DRC unless defined?(Lich::DragonRealms::DRC)

# ── Mock DRCI ─────────────────────────────────────────────────────────
module DRCI
  def self.in_hands?(_item)
    false
  end

  def self.get_item?(_item, _container = nil)
    true
  end

  def self.put_away_item?(_item, _container = nil)
    true
  end

  def self.tie_item?(_item, _container = nil)
    true
  end

  def self.untie_item?(_item, _container = nil)
    true
  end

  def self.wear_item?(_item)
    true
  end

  def self.remove_item?(_item)
    true
  end

  def self.put_away_item_unsafe?(_item, _container = nil, _preposition = 'in')
    true
  end

  def self.dispose_trash(_item, _container = nil, _verb = nil); end
end unless defined?(DRCI)

Lich::DragonRealms::DRCI = DRCI unless defined?(Lich::DragonRealms::DRCI)

# ── Mock DRStats ──────────────────────────────────────────────────────
module DRStats
  def self.moon_mage?
    false
  end

  def self.trader?
    false
  end
end unless defined?(DRStats)

Lich::DragonRealms::DRStats = DRStats unless defined?(Lich::DragonRealms::DRStats)

# ── Mock UserVars ─────────────────────────────────────────────────────
module UserVars
  @moons = {}
  @sun = {}

  class << self
    attr_accessor :moons, :sun
  end
end unless defined?(UserVars)

# Stub game helper methods
module Kernel
  def pause(_seconds = nil); end

  def waitrt?; end

  def echo(_msg); end

  def fput(_cmd); end

  def get_data(_key)
    OpenStruct.new(observe_finished_messages: [])
  end
end

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-moonmage.rb')

DRCMM = Lich::DragonRealms::DRCMM unless defined?(DRCMM)

RSpec.describe Lich::DragonRealms::DRCMM do
  before(:each) do
    Lich::Messaging.clear_messages!
  end

  # ─── Deprecated get_telescope ──────────────────────────────────────

  describe '.get_telescope' do
    context 'when get_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when already in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_telescope? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(false)
        allow(DRCI).to receive(:get_item?).with('telescope').and_return(false)

        DRCMM.get_telescope(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get telescope')
      end
    end
  end

  # ─── Deprecated store_telescope ────────────────────────────────────

  describe '.store_telescope' do
    context 'when store_telescope? succeeds' do
      it 'returns without logging an error when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging an error when in container' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when not in hands' do
        storage = {}
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_telescope? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'backpack' }
        allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
        allow(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(false)

        DRCMM.store_telescope(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store telescope')
      end
    end
  end

  # ─── Deprecated get_bones ──────────────────────────────────────────

  describe '.get_bones' do
    context 'when get_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)

        DRCMM.get_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)

        DRCMM.get_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_bones? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(false)

        DRCMM.get_bones(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to get bones')
      end
    end
  end

  # ─── Deprecated store_bones ────────────────────────────────────────

  describe '.store_bones' do
    context 'when store_bones? succeeds' do
      it 'returns without logging when tied' do
        storage = { 'tied' => 'belt' }
        allow(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)

        DRCMM.store_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)

        DRCMM.store_bones(storage)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_bones? fails' do
      it 'logs an error message' do
        storage = { 'container' => 'pouch' }
        allow(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(false)

        DRCMM.store_bones(storage)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include('Failed to store bones')
      end
    end
  end

  # ─── Deprecated get_div_tool ───────────────────────────────────────

  describe '.get_div_tool' do
    context 'when get_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
        allow(DRCI).to receive(:untie_item?).with('charts', 'satchel').and_return(true)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:remove_item?).with('mirror').and_return(true)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when get_div_tool? fails' do
      it 'logs an error message with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(false)

        DRCMM.get_div_tool(tool)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to get divination tool 'charts'")
      end
    end
  end

  # ─── Deprecated store_div_tool ─────────────────────────────────────

  describe '.store_div_tool' do
    context 'when store_div_tool? succeeds' do
      it 'returns without logging when tied' do
        tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
        allow(DRCI).to receive(:tie_item?).with('charts', 'satchel').and_return(true)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when worn' do
        tool = { 'name' => 'mirror', 'worn' => true }
        allow(DRCI).to receive(:wear_item?).with('mirror').and_return(true)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end

      it 'returns without logging when in container' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages).to be_empty
      end
    end

    context 'when store_div_tool? fails' do
      it 'logs an error message with tool name' do
        tool = { 'name' => 'charts', 'container' => 'satchel' }
        allow(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(false)

        DRCMM.store_div_tool(tool)

        expect(Lich::Messaging.messages.last[:type]).to eq('bold')
        expect(Lich::Messaging.messages.last[:message]).to include('DRCMM:')
        expect(Lich::Messaging.messages.last[:message]).to include("Failed to store divination tool 'charts'")
      end
    end
  end

  # ─── get_telescope? (DRCI predicate version) ──────────────────────

  describe '.get_telescope?' do
    it 'returns true when already in hands' do
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)

      expect(DRCMM.get_telescope?('telescope', {})).to be true
    end

    it 'calls untie_item? when tied' do
      storage = { 'tied' => 'belt' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
      expect(DRCI).to receive(:untie_item?).with('telescope', 'belt').and_return(true)

      expect(DRCMM.get_telescope?('telescope', storage)).to be true
    end

    it 'calls get_item? with container when container specified' do
      storage = { 'container' => 'backpack' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
      expect(DRCI).to receive(:get_item?).with('telescope', 'backpack').and_return(true)

      expect(DRCMM.get_telescope?('telescope', storage)).to be true
    end

    it 'calls get_item? without container when no storage specified' do
      storage = {}
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)
      expect(DRCI).to receive(:get_item?).with('telescope').and_return(true)

      expect(DRCMM.get_telescope?('telescope', storage)).to be true
    end
  end

  # ─── store_telescope? (DRCI predicate version) ────────────────────

  describe '.store_telescope?' do
    it 'returns true when not in hands' do
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(false)

      expect(DRCMM.store_telescope?('telescope', {})).to be true
    end

    it 'calls tie_item? when tied' do
      storage = { 'tied' => 'belt' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
      expect(DRCI).to receive(:tie_item?).with('telescope', 'belt').and_return(true)

      expect(DRCMM.store_telescope?('telescope', storage)).to be true
    end

    it 'calls put_away_item? with container when container specified' do
      storage = { 'container' => 'backpack' }
      allow(DRCI).to receive(:in_hands?).with('telescope').and_return(true)
      expect(DRCI).to receive(:put_away_item?).with('telescope', 'backpack').and_return(true)

      expect(DRCMM.store_telescope?('telescope', storage)).to be true
    end
  end

  # ─── get_bones? (DRCI predicate version) ──────────────────────────

  describe '.get_bones?' do
    it 'calls untie_item? when tied' do
      storage = { 'tied' => 'belt' }
      expect(DRCI).to receive(:untie_item?).with('bones', 'belt').and_return(true)

      expect(DRCMM.get_bones?(storage)).to be true
    end

    it 'calls get_item? with container when container specified' do
      storage = { 'container' => 'pouch' }
      expect(DRCI).to receive(:get_item?).with('bones', 'pouch').and_return(true)

      expect(DRCMM.get_bones?(storage)).to be true
    end

    it 'calls get_item? without container when no storage specified' do
      storage = {}
      expect(DRCI).to receive(:get_item?).with('bones').and_return(true)

      expect(DRCMM.get_bones?(storage)).to be true
    end
  end

  # ─── store_bones? (DRCI predicate version) ────────────────────────

  describe '.store_bones?' do
    it 'calls tie_item? when tied' do
      storage = { 'tied' => 'belt' }
      expect(DRCI).to receive(:tie_item?).with('bones', 'belt').and_return(true)

      expect(DRCMM.store_bones?(storage)).to be true
    end

    it 'calls put_away_item? with container when container specified' do
      storage = { 'container' => 'pouch' }
      expect(DRCI).to receive(:put_away_item?).with('bones', 'pouch').and_return(true)

      expect(DRCMM.store_bones?(storage)).to be true
    end

    it 'calls put_away_item? without container when no storage specified' do
      storage = {}
      expect(DRCI).to receive(:put_away_item?).with('bones').and_return(true)

      expect(DRCMM.store_bones?(storage)).to be true
    end
  end

  # ─── get_div_tool? (DRCI predicate version) ───────────────────────

  describe '.get_div_tool?' do
    it 'calls untie_item? when tied' do
      tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
      expect(DRCI).to receive(:untie_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.get_div_tool?(tool)).to be true
    end

    it 'calls remove_item? when worn' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRCI).to receive(:remove_item?).with('mirror').and_return(true)

      expect(DRCMM.get_div_tool?(tool)).to be true
    end

    it 'calls get_item? with container when in container' do
      tool = { 'name' => 'charts', 'container' => 'satchel' }
      expect(DRCI).to receive(:get_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.get_div_tool?(tool)).to be true
    end
  end

  # ─── store_div_tool? (DRCI predicate version) ─────────────────────

  describe '.store_div_tool?' do
    it 'calls tie_item? when tied' do
      tool = { 'name' => 'charts', 'container' => 'satchel', 'tied' => true }
      expect(DRCI).to receive(:tie_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.store_div_tool?(tool)).to be true
    end

    it 'calls wear_item? when worn' do
      tool = { 'name' => 'mirror', 'worn' => true }
      expect(DRCI).to receive(:wear_item?).with('mirror').and_return(true)

      expect(DRCMM.store_div_tool?(tool)).to be true
    end

    it 'calls put_away_item? with container when in container' do
      tool = { 'name' => 'charts', 'container' => 'satchel' }
      expect(DRCI).to receive(:put_away_item?).with('charts', 'satchel').and_return(true)

      expect(DRCMM.store_div_tool?(tool)).to be true
    end
  end
end
