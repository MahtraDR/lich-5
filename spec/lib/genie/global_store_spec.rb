# frozen_string_literal: true

require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::GlobalStore do
  describe 'in-memory (no file)' do
    subject(:store) { described_class.new(file: nil) }

    it 'stores, reads, and deletes values regardless of persist flag' do
      store.set('a', 1, persist: true)
      store.set('b', 2, persist: false)
      expect(store.get('a')).to eq('1')
      expect(store.get('b')).to eq('2')
      expect(store.key?('a')).to be(true)
      store.delete('a')
      expect(store.key?('a')).to be(false)
    end
  end

  describe 'file-backed' do
    around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } }

    def path = File.join(@dir, 'Config', 'variables.cfg')

    it 'persists #var (persist:true) to variables.cfg but not #tvar (persist:false)' do
      store = described_class.new(file: path)
      store.set('mode', 'hunt', persist: true)
      store.set('scratch', 'temp', persist: false)

      # A fresh store reading the same file sees only the persistent var.
      reopened = described_class.new(file: path)
      expect(reopened.get('mode')).to eq('hunt')
      expect(reopened.key?('scratch')).to be(false)
    end

    it 'deletes a persistent var from the file' do
      store = described_class.new(file: path)
      store.set('gone', 'x', persist: true)
      store.delete('gone')
      expect(described_class.new(file: path).key?('gone')).to be(false)
    end

    it 'keeps the value in memory and does NOT raise when persistence fails' do
      # A locked variables.cfg (Windows "Permission denied" on rename) must not abort
      # the script/trigger that set the var -- regression for Tirost's harn crash.
      store = described_class.new(file: path)
      allow(Lich::Genie::VariableFile).to receive(:save).and_raise(Errno::EACCES.new('locked'))
      expect { store.set('harn', '34', persist: true) }.not_to raise_error
      expect(store.get('harn')).to eq('34') # still usable this session
    end

    it 'skips redundant disk writes when the persisted content is unchanged' do
      store = described_class.new(file: path)
      store.set('x', '1', persist: true)
      expect(Lich::Genie::VariableFile).not_to receive(:save)
      store.set('x', '1', persist: true) # same value -> no rewrite
    end

    it 'picks up external changes when the file mtime advances' do
      store = described_class.new(file: path)
      store.set('shared', 'first', persist: true)

      # Simulate another character's process writing the shared file.
      Lich::Genie::VariableFile.save(path, { 'shared' => 'second', 'extra' => 'new' })
      File.utime(Time.now + 5, Time.now + 5, path)

      expect(store.get('shared')).to eq('second')
      expect(store.get('extra')).to eq('new')
    end

    # Regression: the store is shared by a script's thread AND the downstream/socket
    # thread firing #triggers. Concurrent #var writes used to race reload_if_changed's
    # transient "empty then repopulate", truncating variables.cfg and permanently
    # dropping globals mid-combat (RIME/$qspell/$backpack going literal). Hammer two
    # writers plus a reader and assert no persisted key is ever lost.
    it 'never loses persistent keys under concurrent writers (thread safety)' do
      store = described_class.new(file: path)
      store.set('backpack', 'sling bag', persist: true) # a stable pre-set global
      errors = []

      writers = Array.new(2) do |w|
        Thread.new do
          100.times { |i| store.set("k#{w}_#{i % 5}", (w * 1000 + i).to_s, persist: true) }
        rescue StandardError => e
          errors << e
        end
      end
      reader = Thread.new do
        300.times { store.get('backpack') }
      rescue StandardError => e
        errors << e
      end
      (writers + [reader]).each(&:join)

      expect(errors).to be_empty
      expect(store.get('backpack')).to eq('sling bag') # survived the churn
      # A fresh store reading the on-disk file must also still see it (no truncation).
      expect(described_class.new(file: path).get('backpack')).to eq('sling bag')
    end
  end
end
