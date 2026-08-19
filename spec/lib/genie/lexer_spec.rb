# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Lexer do
  def compile(lines, **opts)
    described_class.compile(Array(lines), **opts)
  end

  def functions(program)
    program.instructions.map(&:function)
  end

  def contents(program)
    program.instructions.map(&:content)
  end

  describe 'basic classification' do
    it 'classifies verbs and preserves content' do
      program = compile(['echo hi', 'put foo'])
      expect(functions(program)).to eq([:echo, :put])
      expect(contents(program)).to eq(['echo hi', 'put foo'])
    end

    it 'skips blank lines' do
      program = compile(['echo a', '', '   ', 'echo b'])
      expect(functions(program)).to eq([:echo, :echo])
    end

    it 'splits a line on the U+00A4 inline-newline sentinel' do
      program = compile(["echo a#{[0xA4].pack('U')}echo b"])
      expect(functions(program)).to eq([:echo, :echo])
    end
  end

  describe 'labels' do
    it 'records a lowercased label at the instruction index' do
      program = compile(['echo a', 'Start:', 'echo b'])
      expect(program.labels).to eq({ 'start' => 1 })
      expect(program.instructions[1].function).to eq(:label)
    end

    it 'does not treat a line with a space as a label' do
      program = compile(['echo done:'])
      expect(functions(program)).to eq([:echo])
    end
  end

  describe '%/$ line prefixes' do
    it 'rewrites %x = y to setvariable and $x = y to put #var' do
      program = compile(['%health = 100', '$mode = hunt'])
      expect(contents(program)).to eq(['setvariable health 100', 'put #var mode hunt'])
      expect(functions(program)).to eq([:setvariable, :put])
    end
  end

  describe 'if / while splitting' do
    it 'splits an inline if...then...' do
      program = compile(['if %hp > 50 then put advance'])
      expect(functions(program)).to eq([:if_func, :put])
      expect(contents(program)).to eq(['if %hp > 50 then', 'put advance'])
    end

    it 'keeps a block-opening if...then as a single instruction' do
      program = compile(['if %hp > 50 then'])
      expect(functions(program)).to eq([:if_func])
    end

    it 'splits an inline while...do...' do
      program = compile(['while %hp > 50 do put advance'])
      expect(functions(program)).to eq([:while_func, :put])
    end

    it 'raises on a malformed if with no then' do
      expect { compile(['if %hp > 50 put advance']) }.to raise_error(Lich::Genie::Error)
    end
  end

  describe 'else / elseif' do
    it 'splits an inline else' do
      program = compile(['else put retreat'])
      expect(functions(program)).to eq([:else_func, :put])
    end

    it 'desugars elseif into else + if' do
      program = compile(['elseif %hp > 20 then put heal'])
      expect(functions(program)).to eq([:else_func, :if_func, :put])
      expect(contents(program)).to eq(['else', 'if %hp > 20 then', 'put heal'])
    end
  end

  describe 'blocks' do
    it 'classifies block markers' do
      program = compile(['{', '}'])
      expect(functions(program)).to eq([:blockstart, :blockend])
    end

    it 'splits a } with a trailing command' do
      program = compile(['} put foo'])
      expect(functions(program)).to eq([:blockend, :put])
    end
  end

  describe 'if_N' do
    it 'rewrites if_N to an argcount check and splits' do
      program = compile(['if_2 then echo ready'])
      expect(functions(program)).to eq([:if_func, :echo])
      expect(contents(program)).to eq(['if %argcount >= 2 then', 'echo ready'])
    end
  end

  describe 'include' do
    it 'skips an include with no loader but records the file' do
      program = compile(['include lib.cmd', 'echo done'])
      expect(functions(program)).to eq([:echo])
      expect(program.files).to include('lib.cmd')
    end

    it 'expands an include through the loader' do
      loader = ->(name) { name == 'lib.cmd' ? "echo from-lib\nput ready" : nil }
      program = compile(['include lib.cmd', 'echo main'], include_loader: loader)
      expect(functions(program)).to eq([:echo, :put, :echo])
    end
  end

  describe 'comments' do
    it 'skips lines beginning with # (Genie comment char)' do
      program = compile(['# a comment', 'echo hi', '   # indented comment', 'put go'])
      expect(functions(program)).to eq([:echo, :put])
    end
  end

  describe 'unknown commands' do
    it 'raises by default' do
      expect { compile(['frobnicate x']) }.to raise_error(Lich::Genie::Error)
    end

    it 'skips and records a warning when warnings are ignored' do
      program = compile(['frobnicate x', 'echo ok'], ignore_warnings: true)
      expect(functions(program)).to eq([:echo])
      expect(program.warnings.map { |w| w[:content] }).to eq(['frobnicate x'])
    end
  end

  describe 'JavaScript blocks (<% ... %>) -- deferred, skipped' do
    it 'skips a multi-line JS block but keeps surrounding script' do
      program = compile(['echo before', '<%', 'if (x !== undefined) {', '  doThing();', '}', '%>', 'echo after'])
      expect(functions(program)).to eq(%i[echo echo])
      expect(contents(program)).to eq(['echo before', 'echo after'])
    end

    it 'does not misread a real if that merely contains <% (a < and a %var)' do
      program = compile(['if (%y<%khri.length) then echo go'])
      expect(functions(program)).to eq(%i[if_func echo])
    end

    it 'skips a single-line <% ... %> block' do
      program = compile(['echo a', '<% var x = 1 %>', 'echo b'])
      expect(functions(program)).to eq(%i[echo echo])
    end
  end

  describe 'robustness for real-world corpora' do
    it 'strips a leading UTF-8 BOM so line 1 parses' do
      bom = [0xFEFF].pack('U')
      program = compile(["#{bom}include lib.cmd", "#{bom}echo hi"], ignore_warnings: true)
      expect(functions(program)).to eq([:echo])
      expect(program.files).to include('lib.cmd')
    end

    it 'skips a .js include (pure JavaScript) without parsing it as Genie' do
      loader = ->(_name) { "function doSort() { if (a !== b) { return 1; } }" }
      program = compile(['include js_arrays.js', 'echo ok'], include_loader: loader, ignore_warnings: true)
      expect(functions(program)).to eq([:echo])
      expect(program.warnings).to be_empty
      expect(program.files).to include('js_arrays.js')
    end

    it 'records a warning (does not crash) on a malformed if under ignore_warnings' do
      program = compile(['if (bad javascript) {', 'echo ok'], ignore_warnings: true)
      expect(functions(program)).to eq([:echo])
      expect(program.warnings).not_to be_empty
    end
  end
end
