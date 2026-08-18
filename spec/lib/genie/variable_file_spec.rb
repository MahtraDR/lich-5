# frozen_string_literal: true

require_relative '../../../lib/genie'
require 'tmpdir'

RSpec.describe Lich::Genie::VariableFile do
  describe '.dump / .load round-trip' do
    it 'serializes and parses #var {key} {value} lines' do
      entries = { 'mode' => 'hunt', 'target' => 'a large kobold' }
      dumped = described_class.dump(entries)
      expect(dumped).to eq("#var {mode} {hunt}\n#var {target} {a large kobold}\n")

      Dir.mktmpdir do |dir|
        path = File.join(dir, 'variables.cfg')
        File.write(path, dumped)
        expect(described_class.load(path)).to eq(entries)
      end
    end

    it 'returns empty for a missing file and empty dump for no entries' do
      expect(described_class.load('/nonexistent/variables.cfg')).to eq({})
      expect(described_class.dump({})).to eq('')
    end

    it 'loads only lines that parse to exactly three args (matches Genie LoadRow)' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'variables.cfg')
        # 1-arg and 2-arg and 4-arg lines are skipped; any 3-token line loads
        # (Genie's LoadRow ignores arg[0] and takes arg[1]/arg[2]).
        File.write(path, "#var {ok} {yes}\ngarbage\none two\n#var {two} {a b c}\na b c d\n")
        expect(described_class.load(path)).to eq({ 'ok' => 'yes', 'two' => 'a b c' })
      end
    end

    it 'creates the directory and writes atomically' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'Config', 'variables.cfg')
        described_class.save(path, { 'x' => '1' })
        expect(File.read(path)).to eq("#var {x} {1}\n")
      end
    end
  end
end
