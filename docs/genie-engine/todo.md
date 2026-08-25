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
- [x] **`match`/`matchre`/`replacere` regex fuzzer. DONE v0.9.9.** `reference/fuzz_regex.rb` +
      new oracle mode `matchrecaps` (serializes Eval.ResultList so capture groups are observable).
      Found+fixed 2 divergences: matchre STRIPPED the subject (Genie doesn't -> broke bool AND
      captures on leading/trailing whitespace), and replacere only handled `$digits` (Genie is full
      .NET Regex.Replace: $$/$&/$`/$'/$_/$+/${n}/${name}, out-of-range->literal). matchre/
      matchre_caps/replacere now 100% (5k x8 seeds). KNOWN: `replace(s,"")` empty-needle -> Genie
      throws ArgumentException, we're lenient (documented, substr/count precedent). Untested edge:
      Unicode \d\w\s + multiline ^$ (Ruby vs .NET default) -- see eval.rb note.
- [x] **Corpus execute-sweep. DONE v0.9.9.** `reference/corpus_execute_sweep.rb` runs all 1499
      corpus .cmd headless against a synthetic/EOF stream (fake ports + virtual clock so waits
      resolve/guards fire authentically; per-script hard-timeout thread). 0 Ruby exceptions, 0
      timeouts on the stream. Static+harness analysis surfaced 3 unguarded crash sites (reachable
      on a live line; Genie guards all 3 in Script.cs) -> FIXED: matchwait->undefined label
      (NoMethodError; 91 literal offenders in corpus), malformed matchre pattern (RegexpError;
      precompile at add_match), malformed waitforre pattern (RegexpError). 3 regressions in
      interpreter_spec.rb.
- [x] **Property/invariant tests. DONE v0.9.9.** `reference/property_invariants.rb` (exhaustive,
      40k x5 seeds) + `spec/lib/genie/property_spec.rb` (8-example CI subset). All HOLD: format_double
      <-> string_to_double bit-exact round-trip + canonical-form stability + well-formed layout;
      to_integer within 0.5/idempotent/identity; safe_split.join round-trip; parse_args plain-token
      round-trip; expand no-op on sigil-free text + idempotent on %local/@special (the $/backslash
      cases correctly DON'T -- expand un-escapes + $-arg pass runs first; invariant refined). No bugs.

## P2 — Engine feature gaps (recognized-but-stubbed / partial)

- [x] **`waiteval` SILENT no-op -> IMPLEMENTED v0.10.0.** Corpus: 5 uses (2 in the oldtriggers
      template; real ones swimhaven `!matchre($scriptlist,...)` + hunt.cmd `$roomid = %starter.room`)
      -- all reference LIVE/reserved vars that move with the stream, so we re-evaluate the RAW
      (re-substituted) condition on each incoming line via resume_line (Genie re-checks on a variable
      change; per-line is the observable equivalent). `waiteval_satisfied?` in interpreter.rb. NOTE:
      swimhaven's `$scriptlist` is still stubbed to 'none' (separate gap), so that one resumes early.
- [ ] **`wait` / `move` / `nextroom` are prototype (DEFERRED, needs tester).** They resume on the
      next LINE; Genie's `wait` resumes on the next PROMPT (TriggerPrompt) and `move` on a ROOM
      CHANGE (TriggerMove) -- Script.cs:1573/1621, EvalWait/EvalMove. Faithful semantics need (a)
      prompt + room-change SIGNALS plumbed from the Lich glue into the interpreter's wait resume, and
      (b) validation that it doesn't regress combat -- these are the HIGHEST-frequency verbs (wait
      711, move 367) on TESTER-VALIDATED combat, and this is exactly the script-flow layer the
      "script-flow replay fixture" tester-once item exists for. Changing it blind is too high-risk;
      left as the working prototype until we have that fixture. nextroom: 0 corpus uses.
- [x] **`execute_action` if/math/shift -> IMPLEMENTED v0.10.0.** Refactored to
      `dispatch_action_command` + added `math` (many `action math <ctr> add 1` in commoncombattriggers
      -- these used to fall through to the game as literal "math ..."), `shift` (-> do_shift), and
      `if (cond) then <cmd>` (`action (move) if (%movewait=0) then shift`; re-substitutes+evals the
      condition, runs the THEN command back through the dispatch).
- [ ] **eval-actions (`action e/...` / variable-change triggers).** Unimplemented; 1 corpus use
      (an automapper edge). Same machinery as Genie's TriggerVariableChanged (also what waiteval uses
      natively). Low value; our waiteval per-line model sidesteps needing it. Leave until a real dep.
- [x] **`#queue` host-control -> RESOLVED v0.10.0 (recognized no-op).** Corpus is 144/144
      `#queue clear` (zero populate sites) -- scripts only DEFENSIVELY clear Genie's timed
      CommandQueue on abort/reset. The in-Lich engine sends immediately (waitrt? pacing, no queue), so
      there's nothing to leak and `#queue clear` is a satisfied no-op; recognized in command_router
      (`do_queue`) so it no longer emits a stray FE hook. A populate subcommand (none in corpus)
      announces unsupported. A real CommandQueue port would be wasted effort for 0 populate sites.
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
- [ ] **`replace(s, "")` (empty needle) (v0.9.9).** Genie's `String.Replace("", ...)` throws
      ArgumentException (uncaught, propagates out of EvalString); ours is lenient (Ruby gsub inserts
      the replacement between every char). Left lenient, matching the substr-out-of-range + count
      decisions -- and faithfully raising is awkward anyway (eval_string's `rescue Error` would
      swallow it to ""). fuzz_regex reports it every run so it stays visible.
- [ ] **matchre/replacere Unicode + multiline (v0.9.9).** Validated byte-for-byte vs Genie for
      ASCII, newline-free subjects. UNTESTED: .NET `\d\w\s` are Unicode-aware and its `^ $` anchor
      only string start/end, vs Ruby's ASCII / line-anchored. A non-ASCII or embedded-newline
      subject to matchre/replacere could diverge -- revisit with a Unicode/newline corpus if it bites.
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
