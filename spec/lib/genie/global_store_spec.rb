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

    it 'picks up external changes when the file mtime advances' do
      store = described_class.new(file: path)
      store.set('shared', 'first', persist: true)

      # Simulate another character's process writing the shared file.
      Lich::Genie::VariableFile.save(path, { 'shared' => 'second', 'extra' => 'new' })
      File.utime(Time.now + 5, Time.now + 5, path)

      expect(store.get('shared')).to eq('second')
      expect(store.get('extra')).to eq('new')
    end
  end
end
