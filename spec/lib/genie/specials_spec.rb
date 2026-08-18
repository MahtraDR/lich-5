# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Specials do
  subject(:specials) do
    described_class.new(clock: -> { Time.new(2026, 8, 18, 14, 5, 9) }, timer_elapsed: -> { 42 })
  end

  let(:subs) { specials.substitutions }

  it 'exposes the script timer' do
    expect(subs['@timer@']).to eq('42')
  end

  it 'formats 24-hour and military time' do
    expect(subs['@time24@']).to eq('14:05:09')
    expect(subs['@militarytime@']).to eq('1405')
  end

  it 'formats 12-hour time and date' do
    expect(subs['@time@']).to eq('02:05:09 PM')
    expect(subs['@date@']).to eq('08/18/2026')
  end

  it 'preserves the Genie @month@ = minutes quirk' do
    # Genie's @month@ uses .NET "mm" which is MINUTES, not the calendar month.
    expect(subs['@month@']).to eq('05')
    expect(subs['@dayofmonth@']).to eq('18')
    expect(subs['@year@']).to eq('2026')
  end
end
