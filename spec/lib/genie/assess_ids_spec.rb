# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::AssessIds do
  # Tirost's real ASSESS target parse (commonbg.cmd:84). The whole point of the
  # shim is that THIS unmodified pattern matches the enriched line.
  let(:commonbg_target) { /^You \(.*?\).*?\[#(\d+)\].*?at.*?range\./ }

  after do
    described_class.instance_variable_set(:@buffer, nil)
    described_class.instance_variable_set(:@active, nil)
    described_class.instance_variable_set(:@installed, nil)
  end

  describe '.enrich' do
    it 'splices the exist-id after the creature name so commonbg matches' do
      raw = "You (incredibly balanced) are facing " \
            "<d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2) at melee range."
      line = described_class.enrich(raw)
      expect(line).to eq('You (incredibly balanced) are facing an elder ' \
                         "Adan'f sorcerer [#78195083] (2) at melee range.")
      m = commonbg_target.match(line)
      expect(m).not_to be_nil
      expect(m[1]).to eq('78195083') # the captured target id
    end

    it 'handles a name-first flanking line (double-quoted cmd)' do
      raw = '<d cmd="look #78195079">An elder Adan\'f sorcerer</d> ' \
            '(1: stunned and very badly balanced) is flanking you at melee range.'
      expect(described_class.enrich(raw)).to eq(
        "An elder Adan'f sorcerer [#78195079] (1: stunned and very badly balanced) " \
        'is flanking you at melee range.'
      )
    end

    it 'returns nil for a line with no creature link (header/blank)' do
      expect(described_class.enrich('You assess your combat situation...')).to be_nil
      expect(described_class.enrich('')).to be_nil
    end
  end

  describe '.enrich_block' do
    it 'enriches every creature line and drops the rest' do
      block = <<~ASSESS
        <pushStream id='assess'/>You assess your combat situation...
        You (incredibly balanced) are facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2) at melee range.
        <d cmd='look #78195087'>An elder Adan'f sorcerer</d> (3: nimbly balanced) is behind you at melee range.
        <popStream/>
      ASSESS
      lines = described_class.enrich_block(block)
      expect(lines.length).to eq(2)
      expect(lines[0]).to match(commonbg_target)
      expect(lines[0][commonbg_target, 1]).to eq('78195083')
      expect(lines[1]).to eq("An elder Adan'f sorcerer [#78195087] (3: nimbly balanced) " \
                             'is behind you at melee range.')
    end
  end

  describe '.observe (assess block state machine)' do
    before { described_class.install! } # arms @active (no DownstreamHook headless)

    it 'emits enriched lines once, on the block-closing popStream' do
      delivered = []
      allow(described_class).to receive(:deliver) { |lines| delivered.concat(lines) }

      # No popStream yet -> nothing delivered.
      described_class.observe("<pushStream id='assess'/>You (bal) are facing " \
                              "<d cmd='look #11'>a foo</d> (1) at melee range.\r\n")
      expect(delivered).to be_empty

      # Second chunk closes the block -> deliver the accumulated creatures.
      described_class.observe("<d cmd='look #22'>A bar</d> (2) is behind you at " \
                              "pole weapon range.\r\n<popStream/>")
      expect(delivered.length).to eq(2)
      expect(delivered[0][commonbg_target, 1]).to eq('11')
      expect(delivered[1]).to include('A bar [#22]')
    end

    it 'ignores non-assess stream traffic' do
      allow(described_class).to receive(:deliver)
      described_class.observe('An elder Adan\'f sorcerer swings at you.')
      expect(described_class).not_to have_received(:deliver)
    end

    it 'is inert when not armed' do
      described_class.instance_variable_set(:@active, false)
      allow(described_class).to receive(:deliver)
      described_class.observe("<pushStream id='assess'/><d cmd='look #1'>a foo</d> (1) is behind you at melee range.<popStream/>")
      expect(described_class).not_to have_received(:deliver)
    end
  end

  describe '.enabled? default' do
    it 'defaults to false with no persistence available' do
      expect(described_class.enabled?).to be(false)
    end
  end
end
