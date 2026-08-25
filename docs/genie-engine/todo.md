# Genie engine — outstanding work (self-driven; no testers required)

Living checklist of everything we can chase down **without** a live tester. Items that
genuinely need a tester are quarantined at the bottom. Keep this updated as we go.

**Tooling (all in `genie-port-lab/`, isolated .NET 8 SDK at `genie-port-lab/.dotnet`):**
- Real Genie4 oracle: `genie-port-lab/oracle/` (net8.0 console wrapping Genie4's Eval.cs +
  MathEval.cs). Rebuild: `dotnet build -c Release`. Modes: `math`, `evalmath`, `eval`, `evalbool`.
- Differential fuzzers: `reference/fuzz_oracle.rb` (numeric), `fuzz_format.rb` (evalmath
  strings), `fuzz_eval.rb` (eval string funcs), `corpus_sweep.rb` (compile every script).
- Run engine tests: `bundle exec rspec spec/lib/genie/` + `bundle exec rubocop lib/genie/ spec/lib/genie/`.
- CAVEAT: dotnet processes suspend when the laptop sleeps -> long fuzz runs can look "hung".

---

## P1 — Parity tests we can build now (oracle-backed, high value)

- [x] **`Utility.ParseArgs` oracle + fuzzer. DONE v0.9.6.** Extracted ParseArgs+AddArrayItem
      verbatim into oracle `Shims.cs`; added `parseargs`/`parseargs_` modes (serialize as
      `<count>\x1f<tok>...`); `reference/fuzz_parseargs.rb` fuzzes brace/quote/escape/underscore.
      Found the char-buffer `Text.parse_args` was wrong ~6 ways (dropped `\`, dropped interior/
      unbalanced quotes, no single-quote strip, brace-as-buffer not token-boundary, split on TAB,
      never threw) -> REWROTE as a faithful substring port (keeps quirks: negative depth, quotes
      active inside braces, lone-quote THROW, underscore-gates-first-token). 40k cases x2 modes,
      0 divergences; 16 regressions in text_spec.rb. See lessons-learned.md.
- [x] **`StringToDouble` / `ToInteger` / `ToLong` fuzzer. DONE v0.9.8.** Oracle modes `s2d`
      (Utility.StringToDouble), `toint` (Conversions.ToInteger), `tolong` (Conversions.ToLong);
      `reference/fuzz_numeric.rb`. FIXED `Numeric.string_to_double`: the old `Float()`-based parse
      was too lenient vs .NET double.Parse(en-US) -- wrongly accepted `0x1F`->31, `1_000`->1000,
      `Infinity`, and misparsed `1.5,3`; missed `NaN`. Rewrote with an explicit .NET grammar
      (lenient `,` groups in the INTEGER part only, case-insensitive `nan`, no hex/underscore/
      Infinity) -> 20k s2d cases x5 seeds = 0 diffs; no regression in math/format/eval fuzzers.
      `to_integer`/`to_long` VALUE parity is exact; their only diffs are overflow/non-numeric where
      C# THROWS -- left lenient (reconciled at call sites: `\` overflow-checks Int64 in math_eval,
      substr clamps) -> see P3. 7 regressions added to numeric_spec.rb.
- [ ] **Extend `fuzz_eval.rb` to `match`/`matchre`/`replacere`.** Regex + capture-group parity
      (deliberately excluded so far). Watch for catastrophic-backtracking hangs on the oracle.
- [ ] **Corpus execute-sweep (runtime robustness).** Beyond `corpus_sweep.rb` (compile only):
      run each corpus script headless against a synthetic/empty stream, catch exceptions,
      infinite-loop-guard trips, and runtime unknown-verb no-ops. Not parity, but finds crashes.
- [ ] **Property/invariant tests.** e.g. `format_double` <-> parse round-trip; substitution
      idempotence; `parse_args` join/split stability. No oracle needed.

## P2 — Engine feature gaps (recognized-but-stubbed / partial)

- [ ] **`waiteval` is a SILENT no-op.** Mapped in `lexer.rb` (`:waiteval`) but has no arm in
      `interpreter.rb#run_script_row` -> recognized at compile, does nothing at runtime (script
      races past a wait). Implement `waiteval (cond)` = block until the eval condition is true
      (like Genie). Check corpus frequency first.
- [ ] **`wait` / `move` / `nextroom` are prototype.** They resume on the next line, not on a
      real prompt / room-change (interpreter.rb docstring "Scope note (prototype)"). Align with
      Genie's prompt/room-change semantics.
- [ ] **`execute_action` command coverage.** Action bodies only handle goto/put/send/var/echo/
      js/jscall/action/`#`-routing; `if`/`math`/`shift` fall through to the game (1 `if` case in
      the corpus: `action (move) if (...) then shift;...`). Broaden to full row execution.
- [ ] **eval-actions (`action e/...` / variable-change triggers).** Unimplemented; 0 corpus
      uses today. Genie fires these on variable change (Script.cs TriggerVariableChanged).
- [ ] **`#queue` host-control.** Not implemented (companion to the shipped `#script`). Port
      Genie4's queue semantics (Command.cs) + a host queue port, like `#script`.
- [ ] **Non-`js_arrays` JavaScript.** `#js`/`#jscall` cover the `js_arrays` library natively;
      any OTHER JS `announce`s as unsupported. Fine unless a corpus script needs more (audit).
- [ ] **`#plugin` / `#pluginscript`.** Announce-only (no plugin host). Confirm nothing in the
      corpus depends on a specific plugin beyond EXPTracker/SpellTimer (already bridged).

## P3 — Known divergences (documented; decide fix vs leave)

- [ ] **`substr`/`substring` out-of-range.** Genie throws `ArgumentOutOfRangeException`; ours
      clamps to `""` (fuzz_eval: 26/3000). Can't tell the SCRIPT-level effect of Genie's throw
      from the isolated evaluator (needs Script.cs or a tester) -> left lenient. Decide: match
      Genie's throw (risk: script-level propagation unknown) vs keep safe clamp.
- [ ] **Scientific-notation numeric LITERALS (`1e3`) in MathEval.** Genie's `math` returns `0`
      (its tokenizer rejects them, inconsistently — `1e28` behaved differently); ours raises ->
      evalmath rescues to `'0'`, so the `#evalmath` END result matches. Low priority; investigate
      Genie's actual tokenizer behavior via the oracle before touching our lexer.
- [ ] **`Conversions.ToInteger`/`ToLong` throw vs our leniency (v0.9.8).** VB Conversions THROW on
      a non-numeric string (InvalidCastException) or an out-of-range value (OverflowException:
      >Int32 for ToInteger, >Int64 for ToLong); our `Numeric.to_integer`/`to_long` stay lenient
      (-1 for unparseable, a Ruby bignum for large). VALUE parity is exact (fuzz_numeric: 0 value
      diffs); only the throw-cases differ. Reconciled/edge at every call site: `\` already
      Int64-overflow-checks (math_eval), substr clamps (the substr-out-of-range item above),
      round-digits/factorial/element take small integers. Decision: leave lenient (like substr) --
      the script-level effect of Genie's throw is unobservable from the isolated evaluator.
- [ ] **`count(s, "")` (empty needle).** INFINITE LOOP in Genie4's own Eval.cs (hangs the
      oracle); ours returns cleanly. A Genie bug — decision: do NOT replicate (leave documented).

## P4 — Robustness / infra / housekeeping

- [ ] **Fix `corpus_coverage_spec.rb` paths.** It reads `~/Downloads/genie-scripts/Tirost`
      (moved to `genie-port-lab/scripts/tirost`) -> Tirost cases now skip. Repoint (or honor a
      `GENIE_DOWNLOADS`/new env var) so the corpus coverage specs actually run.
- [ ] **`.cfg` importer.** Migrate a real Genie `variables.cfg`/config tree (partial today).
- [ ] **gag/sub class-gating.** Stream filters don't yet honor `#class` on/off (triggers +
      actions do).
- [ ] **RT pacing via command broker (Decision 5).** Currently paced Genie-internally via
      `waitrt?`; broker integration is aspirational.

## Needs a tester (ONCE) — not self-serviceable

- [ ] **Script-flow replay fixture.** Capture ONE native-Genie session log (game stream in +
      commands out). Replaying the stream through our engine and diffing emitted commands
      validates SCRIPT-FLOW parity (matchwait/action/goto/trigger sequencing) — the layer the
      oracle can't reach (`Script.cs` is Globals/network/WinForms-coupled, not extractable).
      After capture it's a reusable fixture, not an ongoing dependency.
- [ ] **Breadth: script GENRES beyond DR combat.** Runtime coverage is DR-combat-heavy
      (Tirost) + crafting (Mastercraft) + public repo compile-clean. Foraging/travel/GS-genre
      runtime behavior is unproven.
