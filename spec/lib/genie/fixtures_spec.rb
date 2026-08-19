# frozen_string_literal: true

require_relative '../../../lib/genie'

# Integration regression against a corpus of REAL Genie scripts (captured under
# spec/fixtures/genie). Guards two things end-to-end: (1) the lexer keeps 100%
# parse coverage of the real scripts, and (2) a full standalone script runs to
# completion through the whole pipeline and emits the expected structured hooks.
RSpec.describe 'Genie real-script fixtures' do
  fixtures_dir = File.expand_path('../../fixtures/genie', __dir__)

  # Records commands the interpreter would send to the game.
  recording_game = Class.new do
    attr_reader :commands

    def initialize = (@commands = [])
    def send_command(text) = (@commands << text)
  end

  # No downstream input (these fixtures are config/setup scripts, not hunting loops).
  nil_input = Class.new do
    def next_line(**) = nil
  end

  # Resolve `include <name>` from the fixtures dir (sc.cmd includes spellbook.cmd).
  include_loader = lambda do |name|
    path = File.join(fixtures_dir, name)
    File.exist?(path) ? File.read(path) : nil
  end

  describe 'parse coverage (lexer regression)' do
    %w[commoncombattriggers.cmd sc.cmd spellbook.cmd].each do |file|
      it "compiles #{file} with zero unknown-command warnings" do
        source = File.read(File.join(fixtures_dir, file))
        program = Lich::Genie::Engine.compile(source, include_loader: include_loader, ignore_warnings: true)
        expect(program.warnings).to be_empty
        expect(program.instructions).not_to be_empty
        expect(program.labels).not_to be_empty
      end
    end
  end

  describe 'end-to-end: commoncombattriggers.cmd' do
    # The file is an include driven by a caller-set return label; drive it into
    # SetTriggersCCT with a terminal return label so it runs once and exits (see
    # lessons-learned: pure-FE goto-return idiom needs a caller).
    def run_cct(fixtures_dir, game_klass, input_klass)
      source = "var combattriggerreturn exitcct\ngoto SetTriggersCCT\n" \
               "#{File.read(File.join(fixtures_dir, 'commoncombattriggers.cmd'))}\nexitcct:\nexit\n"
      game = game_klass.new
      hooks = []
      sink = Object.new.tap { |o| o.define_singleton_method(:emit) { |op, pl| hooks << [op, pl] } }
      variables = Lich::Genie::Variables.new(game_state: { 'unixtime' => '1000000', 'preparedspell' => 'None' })
      Lich::Genie::Engine.build(
        source, name: 'cct', variables: variables, ignore_warnings: true,
        game: game, input: input_klass.new, echo: ->(_t) {}, hooks: sink,
        clock: -> { 0.0 }
      ).run
      { commands: game.commands, hooks: hooks }
    end

    it 'runs to completion emitting only structured class + trigger hooks' do
      result = run_cct(fixtures_dir, recording_game, nil_input)

      expect(result[:commands]).to be_empty # pure front-end/config script; nothing goes to the game
      ops = result[:hooks].map(&:first).uniq.sort
      expect(ops).to eq(%w[class trigger])
      expect(result[:hooks].count { |op, _| op == 'trigger' }).to be >= 30
      expect(result[:hooks].count { |op, _| op == 'class' }).to be >= 20
    end

    it 'emits self-describing trigger payloads (pattern/commands/class)' do
      result = run_cct(fixtures_dir, recording_game, nil_input)
      _, payload = result[:hooks].find { |op, _| op == 'trigger' }
      expect(payload.keys).to contain_exactly('pattern', 'commands', 'class')
      expect(payload['pattern']).to be_a(String).and(satisfy { |s| !s.empty? })
      expect(payload['commands']).to be_a(String).and(satisfy { |s| !s.empty? })
    end

    it 'evaluates config-section conditionals into class toggles with boolean enabled flags' do
      result = run_cct(fixtures_dir, recording_game, nil_input)
      classes = result[:hooks].select { |op, _| op == 'class' }.map(&:last)
      expect(classes).to all(include('name', 'enabled'))
      enabled_flags = classes.map { |c| c['enabled'] }
      expect(enabled_flags).to include(true).and include(false) # both on and off toggles fired
      expect(enabled_flags).to all(satisfy { |v| [true, false].include?(v) })
    end
  end
end
