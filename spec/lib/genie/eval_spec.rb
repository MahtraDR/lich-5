# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Eval do
  subject(:evaluator) { described_class.new(globals: globals) }

  let(:globals) { { 'knownvar' => 'x' } }

  def truthy(expr)
    evaluator.do_eval(expr)
  end

  def str(expr)
    evaluator.eval_string(expr)
  end

  describe 'numeric comparisons' do
    it 'compares numbers' do
      expect(truthy('100 > 50')).to be(true)
      expect(truthy('50 >= 50')).to be(true)
      expect(truthy('10 < 5')).to be(false)
      expect(truthy('5 = 5')).to be(true)
      expect(truthy('5 == 5')).to be(true)
      expect(truthy('5 != 6')).to be(true)
      expect(truthy('5 <> 6')).to be(true)
    end
  end

  describe 'string comparisons' do
    it 'compares strings case-sensitively for equality' do
      expect(truthy('"foo" = "foo"')).to be(true)
      expect(truthy('"foo" = "FOO"')).to be(false)
      expect(truthy('"foo" != "bar"')).to be(true)
    end

    it 'always yields false for relational operators on strings' do
      expect(truthy('"foo" > "bar"')).to be(false)
      expect(truthy('"foo" < "bar"')).to be(false)
    end

    it 'uses string (not numeric) comparison when either side is quoted' do
      # "05" vs 5 is string comparison ("05" != "5"); numerically they'd be equal.
      expect(truthy('"05" = 5')).to be(false)
      expect(truthy('05 = 5')).to be(true) # both numeric tokens -> numeric comparison
      expect(truthy('"5" = "5"')).to be(true)
    end

    # An unquoted value with a leading '.' (e.g. a script name like ".sc") must be a
    # STRING token, not a malformed number -- Tirost's `if $magicloop != 0` where
    # $magicloop = ".sc" relies on this being true. Regression for the .sc split bug.
    it 'treats a leading-dot bareword (".sc") as a string, not a number' do
      expect(truthy('.sc != 0')).to be(true)
      expect(truthy('.sc = 0')).to be(false)
      expect(truthy('.sc = .sc')).to be(true)
      expect(truthy('3x != 0')).to be(true) # digits+letters -> string too
    end

    it 'still parses genuine numbers with leading dot / minus' do
      expect(truthy('.5 > 0')).to be(true)
      expect(truthy('-3 < 0')).to be(true)
    end
  end

  describe 'keyword aliases' do
    it 'maps eq/and/or/not/true/false' do
      expect(truthy('5 eq 5')).to be(true)
      expect(truthy('1 and 1')).to be(true)
      expect(truthy('0 or 1')).to be(true)
      expect(truthy('true')).to be(true)
      expect(truthy('false')).to be(false)
      expect(truthy('not 0')).to be(true)
    end

    it 'does not substitute keywords inside quoted strings' do
      expect(str('"true or false"')).to eq('true or false')
    end
  end

  describe 'logical operators and precedence' do
    it 'evaluates comparisons before and/or' do
      expect(truthy('100 > 50 && 80 > 20')).to be(true)
      expect(truthy('100 > 50 && 10 > 20')).to be(false)
      expect(truthy('0 > 1 || 5 > 1')).to be(true)
    end

    it 'treats only strictly-positive numbers as truthy in and/or' do
      expect(truthy('1 && 1')).to be(true)
      expect(truthy('1 && 0')).to be(false)
      expect(truthy('0 || 0')).to be(false)
    end

    it 'honours parentheses' do
      expect(truthy('(0 || 1) && 1')).to be(true)
      expect(truthy('0 || 1 && 0')).to be(false) # equal precedence, left-assoc
    end
  end

  describe 'truthiness of bare values' do
    it 'treats a bare non-empty string as false' do
      expect(truthy('"hello"')).to be(false)
      expect(truthy('hello')).to be(false)
    end

    it 'treats positive numbers as true and zero/negatives as false' do
      expect(truthy('1')).to be(true)
      expect(truthy('42')).to be(true)
      expect(truthy('0')).to be(false)
    end
  end

  describe 'functions' do
    it 'contains / instr' do
      expect(truthy('contains("hello world", "world")')).to be(true)
      expect(truthy('contains("hello", "xyz")')).to be(false)
    end

    it 'indexof (1-based, 0 when missing)' do
      expect(str('indexof("hello", "l")')).to eq('3')
      expect(str('indexof("hello", "z")')).to eq('0')
    end

    it 'startswith / endswith / match' do
      expect(truthy('startswith("hello", "he")')).to be(true)
      expect(truthy('endswith("hello", "lo")')).to be(true)
      expect(truthy('match("hello", "hello")')).to be(true)
    end

    it 'replace / tolower / toupper / trim' do
      expect(str('replace("a-b-c", "-", "+")')).to eq('a+b+c')
      expect(str('tolower("ABC")')).to eq('abc')
      expect(str('toupper("abc")')).to eq('ABC')
      expect(str('trim("  hi  ")')).to eq('hi')
    end

    it 'len / count' do
      expect(str('len("hello")')).to eq('5')
      expect(str('count("a.b.c.d", ".")')).to eq('3')
    end

    it 'substr with 2 and 3 args' do
      expect(str('substr("hello", 1)')).to eq('ello')
      expect(str('substr("hello", 1, 3)')).to eq('ell')
    end

    it 'element (pipe-delimited, 0-based)' do
      expect(str('element("a|b|c", 1)')).to eq('b')
      expect(str('element("a|b|c", 5)')).to eq('c') # clamp to last
    end

    it 'matchre exposes capture groups' do
      expect(truthy('matchre("HP: 42/100", "(\\d+)/(\\d+)")')).to be(true)
      expect(evaluator.result_list).to eq(['42/100', '42', '100'])
    end

    it 'def/defined against the globals lookup' do
      expect(truthy('def("knownvar")')).to be(true)
      expect(truthy('defined("missingvar")')).to be(false)
    end
  end

  describe 'edge cases' do
    it 'returns false / empty for an empty expression' do
      expect(truthy('')).to be(false)
      expect(str('')).to eq('')
    end

    it 'tolerates an unbalanced closing paren' do
      expect(truthy('1 > 0)')).to be(true)
    end
  end
end
