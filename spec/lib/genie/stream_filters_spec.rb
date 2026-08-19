# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::StreamFilters do
  subject(:filters) { described_class.new }

  describe 'gag' do
    it 'suppresses a matching line (returns nil)' do
      filters.add_gag('a boring line')
      expect(filters.apply('this is a boring line indeed')).to be_nil
    end

    it 'passes a non-matching line through unchanged' do
      filters.add_gag('a boring line')
      expect(filters.apply('an exciting line')).to eq('an exciting line')
    end

    it 'treats the pattern as a regex' do
      filters.add_gag('^You see nothing')
      expect(filters.apply('You see nothing unusual.')).to be_nil
      expect(filters.apply('Ahead, You see nothing')).to eq('Ahead, You see nothing')
    end

    it 'falls back to a literal match for an invalid regex' do
      filters.add_gag('what (is this')
      expect(filters.apply('what (is this even')).to be_nil
    end

    it 'stops suppressing after ungag' do
      filters.add_gag('spam')
      filters.remove_gag('spam')
      expect(filters.apply('spam spam spam')).to eq('spam spam spam')
    end
  end

  describe 'substitute' do
    it 'rewrites matching text' do
      filters.add_sub('kobold', 'KOBOLD')
      expect(filters.apply('a fierce kobold and a kobold')).to eq('a fierce KOBOLD and a KOBOLD')
    end

    it 'supports regex capture-group replacement' do
      filters.add_sub('(\\d+) coins', 'lots of coins')
      expect(filters.apply('you find 250 coins')).to eq('you find lots of coins')
    end

    it 'stops rewriting after unsub' do
      filters.add_sub('kobold', 'KOBOLD')
      filters.remove_sub('kobold')
      expect(filters.apply('a kobold')).to eq('a kobold')
    end
  end

  describe 'combined + edge cases' do
    it 'applies a gag before subs (gag wins)' do
      filters.add_gag('hide me')
      filters.add_sub('me', 'ME')
      expect(filters.apply('please hide me now')).to be_nil
    end

    it 'applies multiple subs in sequence' do
      filters.add_sub('foo', 'bar')
      filters.add_sub('bar', 'baz')
      # foo->bar then bar->baz, so an original "foo bar" becomes "baz baz"
      expect(filters.apply('foo bar')).to eq('baz baz')
    end

    it 'ignores empty patterns and non-string lines' do
      filters.add_gag('')
      filters.add_sub('', 'x')
      expect(filters.apply('untouched')).to eq('untouched')
      expect(filters.apply(nil)).to be_nil
    end
  end
end
