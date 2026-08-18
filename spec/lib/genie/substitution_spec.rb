# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Substitution do
  subject(:substitution) { described_class.new(variables: variables, specials: specials) }

  let(:variables) do
    v = Lich::Genie::Variables.new(game_state: { 'health' => '100' })
    v.local_set('name', 'Grocha')
    v.local_set('list', 'a|b|c')
    v.local_set('foo', 'X')
    v.global_set('gold', '500')
    v
  end

  let(:specials) do
    Lich::Genie::Specials.new(clock: -> { Time.new(2026, 8, 18, 14, 5, 9) }, timer_elapsed: -> { 42 })
  end

  describe 'local (%) and global ($) variables' do
    it 'expands local variables' do
      expect(substitution.expand('%name says hi')).to eq('Grocha says hi')
    end

    it 'expands global variables from the store and from game state' do
      expect(substitution.expand('You have $gold coins')).to eq('You have 500 coins')
      expect(substitution.expand('hp is $health')).to eq('hp is 100')
    end

    it 'leaves undefined variables literally in place' do
      expect(substitution.expand('%unknown here')).to eq('%unknown here')
    end

    it 'matches the longest defined prefix of an identifier' do
      # 'foobar' is undefined but 'foo' is defined -> 'X' + 'bar'
      expect(substitution.expand('%foobar')).to eq('Xbar')
    end
  end

  describe 'array and .length forms' do
    it 'accesses a pipe-delimited element by 0-based index' do
      expect(substitution.expand('%list(1)')).to eq('b')
    end

    it 'reports element count via .length' do
      expect(substitution.expand('%list.length')).to eq('3')
    end
  end

  describe 'right-to-left, single-level expansion' do
    it 'does not re-scan the text a variable expands into' do
      variables.local_set('a', '%b')
      variables.local_set('b', 'DEEP')
      expect(substitution.expand('%a')).to eq('%b')
    end
  end

  describe '$-argument substitution' do
    it 'replaces $0 (full string) and numbered args' do
      args = ['spell target', 'spell', 'target']
      expect(substitution.expand('do $0', args: args)).to eq('do spell target')
      expect(substitution.expand('cast $1 at $2', args: args)).to eq('cast spell at target')
    end

    it 'replaces $argcount with the token count' do
      expect(substitution.expand('n=$argcount', args: ['a b', 'a', 'b'])).to eq('n=2')
    end

    it 'reproduces the naive "$1 hits $10" quirk' do
      # low-to-high Replace means "$1" is substituted before "$10"
      expect(substitution.expand('$10', args: ['', 'ONE'])).to eq('ONE0')
    end
  end

  describe 'escaping' do
    it 'treats \\% as a literal percent' do
      expect(substitution.expand('100\% done')).to eq('100% done')
    end
  end

  describe '@-special variables' do
    it 'expands date/time specials and the timer' do
      expect(substitution.expand('t=@time24@')).to eq('t=14:05:09')
      expect(substitution.expand('elapsed @timer@')).to eq('elapsed 42')
    end
  end
end
