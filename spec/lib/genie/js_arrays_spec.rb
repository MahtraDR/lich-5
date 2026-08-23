# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::JsArrays do
  # Minimal store backing arrays in locals and exposing globals for the *Global ops.
  let(:locals) { {} }
  let(:globals) { {} }
  let(:store) do
    l = locals
    g = globals
    Object.new.tap do |o|
      o.define_singleton_method(:local_get) { |name| l[name] }
      o.define_singleton_method(:local_set) { |name, value| l[name] = value.to_s }
      o.define_singleton_method(:global_get) { |name| g[name] }
    end
  end
  let(:js) { described_class.new(store) }

  describe 'mutators (js ...)' do
    it 'doPush appends (and seeds an empty/unset array)' do
      expect(js.call('doPush', %w[arr a])).to be_nil
      expect(locals['arr']).to eq('a')
      js.call('doPush', %w[arr b])
      expect(locals['arr']).to eq('a|b')
    end

    it 'doUnshift prepends' do
      locals['arr'] = 'b|c'
      js.call('doUnshift', %w[arr a])
      expect(locals['arr']).to eq('a|b|c')
    end

    it 'doInsert inserts at a position and clamps out-of-range to append' do
      locals['arr'] = 'a|d'
      js.call('doInsert', ['arr', 'b|c', '1'])
      expect(locals['arr']).to eq('a|b|c|d')
      js.call('doInsert', ['arr', 'z', '99'])
      expect(locals['arr']).to eq('a|b|c|d|z')
    end

    it 'doRemove deletes the first occurrence (and no-ops when absent)' do
      locals['arr'] = 'a|b|c|b'
      js.call('doRemove', %w[arr b])
      expect(locals['arr']).to eq('a|c|b')
      js.call('doRemove', %w[arr zzz])
      expect(locals['arr']).to eq('a|c|b')
    end

    it 'doRemove of the only element empties the array' do
      locals['arr'] = 'solo'
      js.call('doRemove', %w[arr solo])
      expect(locals['arr']).to eq('')
    end

    it 'doReplace overwrites an index; appends at length; ignores out-of-range' do
      locals['arr'] = 'a|b|c'
      js.call('doReplace', %w[arr 1 B])
      expect(locals['arr']).to eq('a|B|c')
      js.call('doReplace', %w[arr 3 d])
      expect(locals['arr']).to eq('a|B|c|d')
      js.call('doReplace', %w[arr 9 x])
      expect(locals['arr']).to eq('a|B|c|d')
    end

    it 'doConcat joins a second list' do
      locals['arr'] = 'a|b'
      js.call('doConcat', ['arr', 'c|d'])
      expect(locals['arr']).to eq('a|b|c|d')
    end

    it 'doSort sorts ascending (0) and descending (1)' do
      locals['arr'] = 'delta|alpha|charlie|bravo'
      js.call('doSort', %w[arr 0])
      expect(locals['arr']).to eq('alpha|bravo|charlie|delta')
      js.call('doSort', %w[arr 1])
      expect(locals['arr']).to eq('delta|charlie|bravo|alpha')
    end

    it 'buildArray turns prose into a Genie array' do
      js.call('buildArray', ['loot', 'a gold ring, an iron key and some copper coins'])
      expect(locals['loot']).to eq('gold ring|iron key|copper coins')
    end

    it 'buildArrayStr keeps only items matching the pattern' do
      js.call('buildArrayStr', ['gems', 'a red ruby, a blue sapphire and a red garnet', 'red'])
      expect(locals['gems']).to eq('red ruby|red garnet')
    end
  end

  describe 'value-returning (jscall v ...)' do
    it 'doPop/doShift return the removed item and mutate; 0 when empty' do
      locals['arr'] = 'a|b|c'
      expect(js.call('doPop', ['arr'])).to eq('c')
      expect(locals['arr']).to eq('a|b')
      expect(js.call('doShift', ['arr'])).to eq('a')
      expect(locals['arr']).to eq('b')
      js.call('doShift', ['arr'])
      expect(js.call('doPop', ['arr'])).to eq('0')
    end

    it 'findIndex returns the index or -1' do
      locals['arr'] = 'a|b|c'
      expect(js.call('findIndex', %w[arr b])).to eq('1')
      expect(js.call('findIndex', %w[arr zzz])).to eq('-1')
    end

    it 'checkExists returns 1/0' do
      locals['arr'] = 'a|b'
      expect(js.call('checkExists', %w[arr b])).to eq('1')
      expect(js.call('checkExists', %w[arr z])).to eq('0')
    end

    it 'doXCompare maps a source hit to the target at the same index (the mining op)' do
      locals['sizes'] = 'tiny|small|medium|large'
      locals['volumes'] = '1|2|4|8'
      expect(js.call('doXCompare', %w[sizes volumes medium])).to eq('4')
      expect(js.call('doXCompare', %w[sizes volumes huge])).to eq('-1')
    end

    it 'findMax/findMin compare numerically; index variants return the index' do
      locals['nums'] = '3|41|5|9'
      expect(js.call('findMax', ['nums'])).to eq('41')
      expect(js.call('findMin', ['nums'])).to eq('3')
      expect(js.call('findMaxIndex', ['nums'])).to eq('1')
      expect(js.call('findMinIndex', ['nums'])).to eq('0')
    end

    it 'findMaxGlobal/findMinGlobal return the global NAME with the max/min value' do
      locals['stats'] = 'str|agi|sta'
      globals['str'] = '40'
      globals['agi'] = '75'
      globals['sta'] = '20'
      expect(js.call('findMaxGlobal', ['stats'])).to eq('agi')
      expect(js.call('findMinGlobal', ['stats'])).to eq('sta')
    end

    it 'zipArrays appends the second, skipping duplicates, without mutating' do
      locals['a'] = 'x|y'
      locals['b'] = 'y|z'
      expect(js.call('zipArrays', %w[a b])).to eq('x|y|z')
      expect(locals['a']).to eq('x|y') # zip returns a value, does not store
    end
  end

  describe 'edge cases' do
    it 'treats an unset array as empty' do
      expect(js.call('findIndex', %w[missing a])).to eq('-1')
      expect(js.call('checkExists', %w[missing a])).to eq('0')
      expect(js.call('doPop', ['missing'])).to eq('0')
      expect(js.call('findMax', ['missing'])).to eq('')
    end

    it 'reports :unknown for a function outside the library' do
      expect(js.call('doSomethingElse', ['arr'])).to eq(:unknown)
    end
  end
end

# End-to-end: the js/jscall verbs through the full pipeline (lexer -> interpreter ->
# JsArrays), inspecting the shared Variables store afterward.
RSpec.describe 'Genie js/jscall verbs (end-to-end)' do
  def run(source)
    vars = Lich::Genie::Variables.new
    echoes = []
    Lich::Genie::Engine.run(source, variables: vars, echo: ->(t) { echoes << t })
    { vars: vars, echoes: echoes }
  end

  it 'runs a js mutation and reads the array back' do
    source = <<~GENIE
      setvariable arr a|b|c
      js doPush("arr", "d")
      echo %arr
      exit
    GENIE
    expect(run(source)[:echoes]).to eq(['a|b|c|d'])
  end

  it 'stores a jscall return into the target local (doXCompare)' do
    source = <<~GENIE
      setvariable sizes tiny|small|medium|large
      setvariable volumes 1|2|4|8
      setvariable size medium
      jscall vol doXCompare("sizes", "volumes", "%size")
      echo %vol
      exit
    GENIE
    result = run(source)
    expect(result[:vars].local_get('vol')).to eq('4')
    expect(result[:echoes]).to eq(['4'])
  end

  it 'announces an unsupported js function instead of failing silently' do
    result = run("js doMagic(\"arr\")\nexit\n")
    expect(result[:echoes]).to include(a_string_matching(/#js not supported.*doMagic/))
  end

  it 'runs js inside an action body (not sent to the game)' do
    # buildArray from a captured line, then read it back
    source = <<~GENIE
      action js doPush("captured", "$1") when ^You grab the (\\w+)
      waitfor DONE
      echo %captured
      exit
    GENIE
    vars = Lich::Genie::Variables.new
    echoes = []
    game = Object.new.tap { |o| o.define_singleton_method(:send_command) { |_t| raise 'js leaked to game' } }
    input = Object.new.tap do |o|
      lines = ['You grab the ruby', 'DONE']
      o.define_singleton_method(:next_line) { |timeout: nil| _ = timeout; lines.shift }
    end
    Lich::Genie::Engine.run(source, variables: vars, echo: ->(t) { echoes << t }, game: game, input: input)
    expect(vars.local_get('captured')).to eq('ruby')
    expect(echoes).to eq(['ruby'])
  end
end
