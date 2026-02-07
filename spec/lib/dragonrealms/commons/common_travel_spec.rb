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

# ── Mock DRC ──────────────────────────────────────────────────────────
# Define at top level first, then alias into Lich::DragonRealms so code
# inside the namespace resolves correctly.
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

  def self.put_away_item_unsafe?(_item, _container = nil, _preposition = 'in')
    true
  end

  def self.dispose_trash(_item, _container = nil, _verb = nil); end
end unless defined?(DRCI)

Lich::DragonRealms::DRCI = DRCI unless defined?(Lich::DragonRealms::DRCI)

# ── Mock DRRoom ───────────────────────────────────────────────────────
module DRRoom
  def self.npcs
    []
  end
end unless defined?(DRRoom)

Lich::DragonRealms::DRRoom = DRRoom unless defined?(Lich::DragonRealms::DRRoom)

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

# ── Mock DRCA ─────────────────────────────────────────────────────────
module DRCA
  def self.perc_mana
    0
  end
end unless defined?(DRCA)

Lich::DragonRealms::DRCA = DRCA unless defined?(Lich::DragonRealms::DRCA)

# Mock Room for walk_to — use allow() stubs in before(:each) for current
class Room
  class << self
    def current
      @current ||= OpenStruct.new(id: 1, dijkstra: [nil, {}])
    end

    def current=(room)
      @current = room
    end
  end
end unless defined?(Room)

# Mock Map — always define needed methods (games_spec.rb Map lacks dijkstra/list)
class Map
  class << self
    def list
      []
    end

    def dijkstra(_id, _target = nil)
      [nil, {}]
    end

    def [](_id)
      nil
    end
  end
end unless defined?(Map)

# Mock XMLData — always define needed methods
module XMLData
  class << self
    def room_description
      ''
    end

    def room_title
      ''
    end

    def room_exits
      []
    end
  end
end

# Mock UserVars — always define needed methods
module UserVars
  @friends ||= []
  @hunting_nemesis ||= []

  class << self
    attr_accessor :friends, :hunting_nemesis
  end
end unless defined?(UserVars)

# Mock Flags — always define needed methods
module Flags
  class << self
    def add(_name, *_patterns); end

    def delete(_name); end

    def reset(_name); end

    def [](_name); end
  end
end unless defined?(Flags)

# Mock Script — always define needed methods
class Script
  class << self
    def running
      []
    end

    def running?(_name)
      false
    end
  end
end unless defined?(Script)

# Stub game helper methods
module Kernel
  def pause(_seconds = nil); end

  def waitrt?; end

  def echo(_msg); end

  def fput(_cmd); end

  def move(_dir); end

  def start_script(_name, _args = [], **_opts)
    Object.new
  end

  def kill_script(_handle); end

  def get_data(key)
    return { 'Crossing' => { 'locksmithing' => { 'id' => 19_073 } } } if key == 'town'

    {}
  end
end

# Load the module under test
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'common-travel.rb')

DRCT = Lich::DragonRealms::DRCT unless defined?(DRCT)

RSpec.describe DRCT do
  before(:each) do
    Lich::Messaging.clear_messages!
    allow(Room).to receive(:current).and_return(OpenStruct.new(id: 19_073, dijkstra: [nil, {}]))
  end

  # ─── refill_lockpick_container ─────────────────────────────────────

  describe '.refill_lockpick_container' do
    let(:lockpick_type) { 'steel' }
    let(:hometown) { 'Crossing' }
    let(:container) { 'lockpick ring' }

    before(:each) do
      allow(DRCT).to receive(:walk_to).and_return(true)
      allow(DRCT).to receive(:buy_item)
      allow(DRC).to receive(:fix_standing)
      allow(XMLData).to receive(:room_exits).and_return([])
    end

    it 'returns immediately when count is 0' do
      expect(DRCI).not_to receive(:put_away_item_unsafe?)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 0)
    end

    it 'calls DRCI.put_away_item_unsafe? with on preposition' do
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .and_return(true)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 1)
    end

    it 'buys and stores multiple lockpicks when count > 1' do
      expect(DRCT).to receive(:buy_item).exactly(3).times
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .exactly(3).times
        .and_return(true)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 3)
    end

    it 'breaks and logs error when put_away_item_unsafe? returns false' do
      expect(DRCI).to receive(:put_away_item_unsafe?)
        .with('my lockpick', 'my lockpick ring', 'on')
        .and_return(false)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 3)

      expect(Lich::Messaging.messages.last[:type]).to eq('bold')
      expect(Lich::Messaging.messages.last[:message]).to include('DRCT:')
      expect(Lich::Messaging.messages.last[:message]).to include('Failed to put lockpick')
    end

    it 'only buys one lockpick when first put fails' do
      expect(DRCT).to receive(:buy_item).once
      allow(DRCI).to receive(:put_away_item_unsafe?).and_return(false)

      DRCT.refill_lockpick_container(lockpick_type, hometown, container, 5)
    end
  end
end
