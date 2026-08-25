# Genie engine port — lessons learned (gotchas & non-obvious findings)

Hard-won discoveries from building + live-testing the port. Read before touching the
relevant area. (Architecture/decisions live in `../genie-engine-port.md`; behavior
specs in `interpreter-spec.md` / `expressions-spec.md`.)

## Genie language / parser
- **Comment char is `#` at line start**, handled in Genie's *file reader* (`LoadFile`,
  Script.cs:3695 `StartsWith("#") == false`), NOT in `AddLine`. Blank lines skipped.
  `<% ... %>` delimits JS blocks (jsblock). Our lexer skips `#`-lines.
- **No `$stance` reserved var** — enumerate `SetDefaultGlobalVars` (Globals.cs) for the
  real reserved list before adding any. (`$stance` was added erroneously, then removed.)
- **`math`/`counter` use `Utility.MathCalc`** (keyword-based: add/sub/set/multiply/divide/
  mod, with a **negative-arg→0 clamp** quirk), NOT `MathEval`. Only `evalmath` uses `MathEval`.
- **`while` has no back-edge** — it's an if-style guard; real loops are label+`goto`. Do
  not synthesize a loop.
- **Expression quirks** (must reproduce): `^` left-associative (`2^3^2==64`); `%` remainder
  takes the **dividend's** sign → Ruby `Float#remainder` (NOT `%`, which follows the divisor);
  `\` integer division truncates toward zero (Ruby `/` floors); `log`=base-10, `ln`=natural;
  **banker's rounding** (`round(half: :even)`); comparisons numeric only when BOTH operands
  are number tokens else string; relational (`>`/`<`) on strings always false; only strictly-
  positive numbers are truthy; `StringToDouble` returns **-1** on parse failure.
- **Variable substitution**: right-to-left, single-level (a var's expansion isn't re-scanned);
  `%local` and `$global` are separate namespaces (not a fallback chain); undefined vars are
  left literal; array `%x(i)` + `%x.length`; the naive `$1`-also-hits-`$10` replace quirk.

## `#command` router (Core/Command.cs port)
- **A `#command`'s *value* is re-parsed as a command** (`ParseAllArgs` → `ParseCommand`,
  Command.cs:943). So `#var t #evalmath ($unixtime + 5)` **evaluates** the inline `#evalmath` and
  stores the number — do NOT store the literal. Only the *function* commands (`#eval`, `#evalmath`,
  `#if`) return a result string; side-effect commands (`#var`, `#class`, `#echo`) return `""`. A
  top-level `#command`'s non-empty result is then **sent to the game** ("get result from function
  then send result to game", Command.cs:262).
- **Args use `Utility.ParseArgs`** (our `Text.parse_args`): `{...}` brace groups + `"..."` quotes are
  stripped, so `#trigger {re} {cmds} {class}` → `["trigger", re, cmds, class]` and `#class name on`
  splits cleanly. `#trigger` = `{pattern}{commands}{class?}` (Command.cs:1442, AddTrigger order);
  `#class name on|off` or `#class +a -b` (Command.cs:1254).
- **Engine vs front-end split lives in the router, not the lexer.** `put #x` is lexed as a normal
  `put`; the *value* (post-substitution) starting with `#` is what routes. So variable substitution
  (incl. `\\$` → literal `$` escaping) has already run — passing the substituted arg is correct, and
  escaped `$vars` in trigger bodies survive for the front-end to evaluate.
- **`gag`/`sub` are emitted as normalized events, not `<genieHook>` tags** — the sink installs a
  DownstreamHook (Decision 6). The router still emits them via `hooks.emit` (one event channel); the
  sink picks the transport.
- **Two runaway guards, both ported.** (1) send-history: 10 same / 30 total game sends in 10s
  (Script.cs:4390). (2) **per-run wall-clock deadline** (`SCRIPT_TIMEOUT_SECONDS`=5s, Genie
  `Config.iScriptTimeout`=5000, Script.cs:1857): a continuous row loop that never yields to a
  wait/send — e.g. a pure-FE `#class`/`#trigger`/`#var` config block that `goto`s its own
  include-return label — trips this even with zero game sends. Reset the deadline at each `run_rows`
  entry (= Genie resetting oTimerStart per RunScript; a wait resumes into a fresh run). The include
  idiom `goto %<caller-return-label>` still needs a caller that sets the label; standalone dry-runs
  inject a terminal label (see spec/fixtures/genie + fixtures_spec).
- **The guards must NOT count roundtime/wait time as loop time (v0.8.2).** Two live-combat false
  positives, both because a legitimate WAIT was being charged against a runaway guard:
  (a) **Long-RT sends tripped the wall-clock.** Our thread model paces on RT by BLOCKING in
  `LichGamePort#send_command` (`waitrt?`) *inside* a row, unlike Genie's cooperative tick where a
  send yields. So a 20s `invoke` / a `barrage` between two sends pushed the next runaway check past
  the 5s deadline and killed the script (`[Script timeout in ...(row): Possible infinite loop.]`
  right after a legit command). Fix: **reset `@run_deadline` AFTER each game send** — RT-wait time
  is then excluded, and the wall-clock guards only send-LESS loops (pure goto/var/hook), which is
  its actual purpose. (b) **A combat loop that waits each cycle tripped the send-history total.** A
  loop like `assess -> matchwait -> act -> goto` is game-responsive, but 30 sends inside the rolling
  10s window trip guard (1) even though every cycle waited. Fix: **clear `@send_history` on each
  `run_rows` entry** (a wait-resume). Now only a loop that spins WITHOUT ever waiting keeps
  accumulating across iterations. Net division of labor: wall-clock = send-less spin; send-history =
  send-driven spin with no waits. Regressions in interpreter_spec (a clock-advancing game for RT;
  a 40-attack pause-paced loop).
- **`#command` arg formats (Command.cs runtime handlers, all ported to command_router.rb):**
  `#trigger {pat}{cmds}{class?}`; `#class name on|off` or `#class +a -b`; `#highlight {line|string|
  beginswith|regex} {color} {pattern...} [case] [sound] [class] [active]` (+`clear`; **pattern is
  greedy to EOL** — `ArrayToString(oArgs,3)` — so trailing fields only work with a single braced
  pattern; a bare `#highlight red foo` is a LIST/display and emits nothing); `#preset {name}{value}`;
  `#window {add|show|position|remove|close|hide} {name} [dims]` (add/show dims are hardcoded
  300x200@10,10); `#macro/#alias {a}{b}` + `#unmacro/#unalias {a}`; `#name {value} {targets...}`
  (one Add per target, key=name val=value) + `#unname {names...}`; `#play/#playwave/#playsound
  <file>|stop` (uses the arg STRING, not tokens); `#link [>win] {text}{cmd}`; `#img [>win][w:N][h:N]
  {file}` (order-independent tokens); `#beep/#bell`+`#flash` (no args); `#layout {load|save}{name}`.
  **No Genie handler exists for `#unhighlight` (use `#highlight clear`) or `#gauge`** — do not invent.
- **gag/sub = Model A DownstreamHook, NOT a hook tag** (Decision 6). The interpreter emits normalized
  `gag`/`ungag`/`substitute`/`unsub` events; `LichHookSink` routes them to a process-wide
  `StreamFilters` (lib/genie/stream_filters.rb) behind ONE persist:true `DownstreamHook`. `DownstreamHook.add`
  needs a **Proc** (a `Method` is rejected by `HookRegistry#add`) — pass `->(line){apply(line)}`. A hook
  returning `nil` suppresses the line; a String rewrites it. Runs after `$_SERVERBUFFER_`, so
  reget/log/other scripts keep the original.

## Script launch + triggers (from live tester feedback)
- **Genie's ScriptChar is `.` (Config default).** Outgoing text starting with `.` RUNS A SCRIPT, it
  is not sent to the game (`ParseCommand` -> `RunScript` -> `ClassCommand_RunScript`: strip the `.`,
  first token = name, rest = `$1..$n`). So `put .helper foo` launches helper.cmd. We intercept in
  `Interpreter#send_text` (the choke point for put/send/do + actions) and call an injected `launch`
  port (glue -> `Script.start`, so `.cmd` re-enters the engine, `.lic` runs normally). This was the
  tester's #1 blocker; before the fix `.name` went to the game as a literal command.
- **`#trigger` is AUTOMATION, not a front-end effect.** It fires command(s) on matching game text,
  so Lich must execute it (a `<genieHook>` no front-end consumes = dead combat triggers). Ported as
  a process-wide `Triggers` registry (`lib/genie/triggers.rb`) + `TriggerRunner`
  (`lib/genie/trigger_runner.rb`, reuses CommandRouter+Substitution) fired from ONE Lich
  DownstreamHook. Reclassified out of the hook catalog. `gag`/`sub`/`trigger` all Lich-side now.
- **Class-gating default = ON.** `Trigger.IsActive` defaults true (Globals.cs:942); `#class NAME
  off` sets IsActive=false for triggers whose class==NAME (`ToggleClass`, :966), `on` re-enables;
  classless triggers always fire; a trigger added while its class is off is still created active.
  Real scripts add all triggers first, THEN toggle specific classes off in a setup section.
- **Triggers must fire on the RAW line, before gags.** One combined downstream hook fires triggers
  first, then applies gag/sub — otherwise a gagged line (returned nil) would never reach the trigger
  matcher. (So gag/sub self-install was removed from StreamFilters; the glue installs the one hook.)
- **Trigger bodies use ParseCommand semantics, NOT script-line semantics:** a leading `#` is a bar
  command (run it) and a bare line is a game/`.script` send — the OPPOSITE of a script line where
  `#` is a comment and `#commands` need `put`. So trigger actions are `Text.safe_split(';')` then
  dispatched (`#`->router, `.`->launch, else->game), never lexed as script rows.
- **`#trigger` (bare) / `#trigger list` lists loaded triggers** (respond); `#untrigger {pat}` removes
  one; `#trigger clear` removes all. Tester wanted visibility into loaded triggers.
- Reserved-var doc gap the tester caught: `$lefthandnoun`/`$righthandnoun` existed in RESOLVERS but
  weren't documented; `$roomplayers` IS supported (DRRoom.pcs). Keep the user-guide reserved list in
  sync with `LichGameState::RESOLVERS`.

## Real-corpus parsing (GenieHunter / Mastercraft / ubercombat)
- **`<% ... %>` = JavaScript block** (Genie AppendFile: opener line starts `<%`, closer line ends
  `%>`; body is JS). We SKIP it (JS deferred). Detect the opener by START-of-line `<%` so
  `if (%y<%khri.length)` (a `<` followed by `%khri`) is NOT mistaken for a block.
- **`include foo.js` is a pure-JS library** (loaded into Genie's JS engine) — skip it, don't parse
  as Genie. **UTF-8 BOM**: Genie's StreamReader strips it; Ruby doesn't -> strip a leading BOM per
  line or `include`/`#comment` on line 1 breaks (built via `[0xFEFF].pack('U')` for AsciiOnlySource).
- **`ignore_warnings` must never hard-raise.** Live runs compile with ignore_warnings; a malformed
  `if/while` (often JS that slipped through) is recorded as a warning and skipped, not raised.
- **Faithful residual warnings:** `deletevariable` (Genie's `GetFunctionType` only maps `unvar`/
  `unvariable`/`unsetvar`/`unsetvariable` -> deletevariable, NOT `deletevariable` itself), `mif`,
  and bare junk lines (`****`, `*fixed`) are unknown in Genie too — do NOT add them (stay faithful).
- **Expression functions are the workhorse:** `matchre()` (8660x in the corpus), `contains`, `def`,
  `toupper`/`tolower`, `count`, `replace` — all already in `Eval#call_function` and verified.
- **`.name` launches a script from put/send/do AND `#send`** (tester-confirmed: `#send .uncon` runs
  uncon.cmd; `put .loadcombattriggers` runs loadcombattriggers.cmd). Handled in `send_text`.

## Movement / room navigation (IMPLEMENTED via mapdb genie stamps)
- **Genie map data is stamped INTO the shared Lich mapdb** (not a side table): each Room carries
  `genie_zone`/`genie_id`/`genie_pos` (strings; `genie_pos` = `"x,y,z"`), resolved by
  `Map.by_genie_ref(zone, node)`. The fields + resolver already existed in map_dr.rb (the map authors
  anticipated this). Stamped once (Saga-style title+desc match, ~78% coverage, 84 zones), yearly
  top-up; `(genie_zone, genie_id)` verified 100% unique so `by_genie_ref` is unambiguous.
- **`$roomid` is ZONE-LOCAL** (Genie loads one zone map at a time; `#goto` is single-zone, cross-zone
  is an unimplemented Genie stub). So identity = `(zone, node)` — exactly why `by_genie_ref` takes two
  args. Resolver: `$roomid` -> `Map.current&.genie_id || "0"` (`"0"` == Genie "mapper lost", which
  `if $roomid = 0` guards). `#goto <n>` -> `Map.by_genie_ref(Map.current.genie_zone, n)` -> `DRCT.walk_to`
  (go2). Path-A fallback when unstamped/no-map: treat `n` as a Lich room id or game uid.
- **ARRIVED/FAILED shim:** go2/DRCT don't emit Genie's automapper result lines, but the `automove`
  idiom does `put #goto`; `matchwait YOU HAVE ARRIVED|FAILED`. So after the walk, push
  `"YOU HAVE ARRIVED"`/`"YOU HAVE FAILED"` into the script's `@downstream_buffer`
  (`LimitedArray#push` signals `gets`/`wait_shift`) so the matchwait resolves. Triggers that `#goto`
  walk but skip the inject (they don't matchwait). `mover` is a CommandRouter port so `#goto` works
  from scripts, triggers, and `#if` branches.
- `Room < Map` (subclass, inherits class methods); `@@list` is an id-indexed array (`Map.list[id]`);
  `DRCT.walk_to(id, restart_on_fail=false)` returns true/false — pass `false` so a failed walk doesn't
  restart the GenieScript.

## Movement / room navigation (historical notes)
- Room-nav scripts (Mastercraft especially) use **`$roomid`** (Genie's automapper current-room
  number, 81x) compared to configured target rooms (`$MC_PREFERRED.ROOM`, `$part.room`, ...), then
  call an in-script `automove:` sub that does **`put #goto <roomnum>`** + `put #mapper reset` and
  matchwaits on Genie automapper output (`YOU HAVE ARRIVED` / `YOU HAVE FAILED`). Genie's reserved
  var is `gameroomid`; **`$roomid` is set by the automapper**, which we don't have.
- We bridge `$roomid` -> `XMLData.room_id` (Lich mapdb UID). Two ways to make nav work:
  **(A, no map merge)** users set their target-room config vars to LICH room ids; bridge `#goto N`
  -> `go2 N` / `DRC.walk_to(N)`; least work. **(B, map merge)** keep Genie roomids in configs and add
  a Genie<->Lich room translation table (the "merge genie map data" project); more faithful, needs
  the data + upkeep. CAVEAT for both: the `automove` sub scrapes Genie automapper *messages*, which
  go2/DRC.walk_to don't emit — a `#goto` bridge also needs a compat shim that emits
  `YOU HAVE ARRIVED`/`YOU HAVE FAILED` (or the scripts need minor edits). Movement is Phase-6.

## Tester-found bugs (Tirost, sc.cmd author)
- **A leading-dot bareword (`.sc`) must tokenize as a STRING in `Eval`, not a number.** Tirost stashes
  a script name in a var (`$magicloop = .sc`) then `if $magicloop != 0 then put $magicloop` to launch
  it. The Eval tokenizer started a NUMBER token on `.`, split `.sc` -> number(".")+string("sc"), so
  `.sc != 0` mis-reduced to FALSE and the launch never fired. Fix: when a would-be number hits a
  non-numeric char, reclassify the whole run as a bareword WITHOUT flushing (mirrors Genie's
  `bIgnoreNumber`); `.5`/`-3` still parse as numbers. So the visible symptom was "put $var doesn't
  launch," but the real bug was the GUARD (`!= 0`) evaluating wrong.
- **SpellTimer name normalization strips spaces, apostrophes, AND hyphens** (plugin's
  `spellNameToVariableName`), so `$SpellTimer.GlythtidesGift` matches game "Glythtide's Gift". Our
  `despace` only stripped spaces -> broadened to `gsub(/[\s'-]/,'')`. Plugin also exposes `.charge`
  (charge count) in addition to `.active`/`.duration`, all in roisaen; Tirost uses only
  active/duration with threshold compares, so the plugin's Indefinite=999 vs our dr_active_spells
  1000 is immaterial. `.charge` unused by Tirost (defer). The SpellTimer plugin ~= our
  dr_active_spells bridge; no plugin port needed.
- **Tirost's full suite (sc.cmd + 16 includes + spellbook, 14,696 instrs) parses 100% clean.**
- **`send`/`do` must route `#commands` and `.scripts` too, not just `put`.** Genie runs put/send/do
  all through ParseCommand. We only routed `put #`; `send #class ... on` went to the game as text.
  Fix: centralize `#`-routing + `.`-launch in `send_text` (the shared sink for put/send/do + action
  bodies).
- **RT-gate game sends (`waitrt?` before `put` in LichGamePort).** Genie paces on roundtime. Without
  it, a script's deliberate `...wait`-retry loop (Tirost's `matchre ...wait` failsafe) re-sends every
  ~1s during RT and trips the infinite-loop guard. `waitrt?` (no-op when no RT) makes sends wait out
  RT first, so the retry rarely fires. This is the "RT pacing" item -- solved Genie-internally, NOT
  via a broker (there is none in this lich; design Decision 5 was aspirational).
- **Triggers/gags must match the DISPLAYED text, not the raw stream.** `DownstreamHook.run`
  (games.rb:1082) gets the XML-laden `server_string`, so `^`-anchored trigger patterns on tag-wrapped
  lines never matched (looked like triggers/`#class` were dead). Strip tags (`gsub(/<[^>]+>/,'')`)
  before trigger matching; gag/sub still rewrite the real line.
- **`#var` persistence MUST be best-effort -- a disk-write failure cannot abort the script/trigger.**
  The decisive "triggers/`#class` don't fire" report (round 3) was NOT a trigger bug at all: the
  triggers fired, but their `#var harn` action wrote `variables.cfg` via temp-file + `File.rename`,
  which on Windows raised `Permission denied @ rb_file_s_rename` (the file is rewritten on EVERY
  combat `#var`, and an AV/indexer/concurrent script briefly locks it). The raised exception
  unwound the trigger action mid-way, so `harn` never updated and the follow-up `#class harness off`
  never ran -> harn-spam + dead-looking triggers. The tester's log (`genie trigger error:
  Permission denied @ rb_file_s_rename ... variables.cfg.tmp.<pid>`) was the smoking gun; the
  headless `apply` "no FIRE" was a red herring (that trigger was legitimately class-off). Two-part
  fix: (1) `VariableFile.atomic_replace` retries the rename (10x/50ms) then falls back to a direct
  overwrite, always cleaning up the temp file; (2) `GlobalStore#save_file` rescues ALL persist
  errors (never raises into script/trigger -- the in-memory value is already set, which is what
  script logic reads), logs once, and skips redundant writes (unchanged content) to cut churn.
  General principle: reserved/config persistence is a side effect; script control flow must not
  depend on it succeeding.
- **`#if {cond} {then} {else}` MUST run EVERY `;`-separated sub-command in the taken branch.**
  Genie's `ParseCommand` splits its input on the separator char (`;`) FIRST, then dispatches each
  row (Command.cs:240,248); `#if` routes the taken branch back through `ParseCommand`
  (Command.cs:1100), so `{#var harn 0;#class spellprepared off;#class spellcast off}` runs all
  three. Our `do_if` originally called `compute(branch)` -- treating the whole branch as ONE
  command -- so only the first row ran (with the rest mangled into its args) and everything after
  the first `;` vanished. The combat suite's **spellcast trigger** (commoncombattriggers.cmd) wraps
  its entire reset block, ending in `#class spellcast off`, inside a single `#if {(\$pf=0)} {...}`
  branch, so the class never turned off and the triggers looked dead -- the real "round 4" cause,
  distinct from the earlier persistence crash. Fix: `do_if` -> `run_branch`, which `safe_split`s the
  branch on `;` (brace-aware, so nested `#if {..} {..}` is preserved), runs each row, and returns
  the LAST row's result (Genie resets `sResult` per row, so only the final row bubbles up to the
  caller that sends it to the game). Verify branch coverage headlessly, not just parsing.
- **Build the trigger match line with Lich's `strip_xml`, NOT a naive `gsub(/<[^>]+>/,'')`.** A naive
  tag-strip keeps the TEXT of GUI-only elements and glues it onto the real line. After a `cast`, DR
  sends `<spell>None</spell>You gesture.` in one chunk; the naive strip yields `"NoneYou gesture."`,
  so the `^You gesture` spellcast trigger never matches -> its var resets + `#class spellcast off`
  never run -> the script casts twice and "doesn't read the variable changes" (the real round-4/5
  cause; class-gating and the `;` were fine all along). `strip_xml_simple` (global_defs.rb) removes
  the content of `compDef|inv|component|right|left|spell|prompt` elements, decodes entities, and
  returns nil for blank lines -- exactly what Genie matches (main-window text). The genie-downstream
  hook now uses `strip_xml`. TELL: a trace line showing the prompt as `&gt` (missing its own `;` from
  `&gt;`) or a game line with a glued prefix (`NoneYou gesture.`, `spiritwood cubeYour worn items`)
  means the raw-chunk text nodes are being concatenated -- switch to strip_xml. Also: a front-end can
  eat `;` in ECHOED output, so a traced command may look like it lost its separators when the stored
  string is intact -- use a rendering-proof signal (a COUNT) to check, not the echoed text.
- **`respond_to?(:strip_xml)` is FALSE in a running Lich -- the guard silently killed the fix above
  (v0.8.1).** `strip_xml` is a **top-level `def`** in global_defs.rb, which Ruby makes a **private**
  method on Object. `respond_to?(sym)` excludes private methods (only `respond_to?(sym, true)` sees
  them), so the guard `respond_to?(:strip_xml) ? strip_xml(x) : naive(x)` ALWAYS took the naive
  fallback -- the strip_xml branch was dead code from the day it was added. R5 therefore only *looked*
  fixed: prefix-free `wave`/pf casts ("You gesture." with no `<spell>None</spell>`) matched under the
  naive strip, while every prepared-spell `cast` still double-cast. It resurfaced as "back to square
  one on spellcast" a version later, unrelated to whatever else changed. Fix: **call `strip_xml`
  directly** (private methods are callable with an implicit receiver) inside a `begin/rescue NameError`
  that only falls back to the naive strip when strip_xml is genuinely absent (headless specs). See
  `GenieScript.strip_xml_line`. General rule: to feature-detect a Lich top-level helper, `rescue
  NameError` around a real call -- never `respond_to?` (it can't see private/top-level defs).
- **Synthesized reserved namespaces with no writer (SpellTimer.*, skill/EXPTracker vars) must read
  LIVE, not from a stale persisted store.** In real Genie the SpellTimer plugin rewrote
  `#var SpellTimer.<spell>.active/.duration` every percwindow tick, so scripts read a fresh stored
  value. Lich has NO such plugin -- we synthesize those names live from `dr_active_spells`/`DRSkill`.
  But `Variables#global_get` read the store BEFORE live state (so a script's own `#var` wins, e.g.
  `#var inside 1`). A tester migrating a Genie `variables.cfg` brings along stale `SpellTimer.*`
  entries; with no writer to refresh them, they shadow the live value FOREVER -- e.g.
  `$SpellTimer.Ignite.active` stuck at 0 -> the script recasts Ignite endlessly (Ignite is one of the
  few spells guarded on `.active` rather than `.duration`). Fix: `game_state` may declare names
  `authoritative?` (live-wins, store as fallback); `LichGameState` marks the SpellTimer + skill
  namespaces. Scalar reserved vars are intentionally NOT authoritative, so scripts that shadow one
  keep working. Semantics confirmed against the plugin: `.active` = presence in the percwindow
  (== a key in `dr_active_spells`), `.duration` = roisaen; no per-spell special-casing for Ignite.
  Diagnose live: `;eq echo Lich::Genie.global_store.keys.grep(/SpellTimer/)` (stale entries?) and
  `;eq echo XMLData.dr_active_spells` (is the spell present under that name?).
- **`#script abort/pause/resume` were silent no-ops -- implement the keyword, don't let it fall to a
  `<genieHook>` (v0.9.1).** `command_router` had no `script` keyword, so `#script abort all` /
  `#script abort all except <name>` fell through `dispatch_fe -> emit_generic` into a `<genieHook
  op="script">` tag nothing consumes -- so sh.cmd ("stop combat") and sk.cmd ("skin dead stuff"),
  which lean on `#script abort all [except ...]`, did nothing. Genie's chain is Command.cs:2188
  (`case "script"`, subcommand switch) -> `FormMain.Command_ScriptAbort` (the name/"all"/"except"
  matching, FormMain.cs:5561). We put the MATCHING in `CommandRouter` (testable headless) and the
  kill/pause/unpause behind an injected `script_control` port (`LichScriptControl` in genie_script.rb).
  Faithful matching, straight from FormMain: split off `except <name>`; a spec whose (`+" "`) form
  starts with `"all "` -- or an EMPTY spec (`#script abort` with no arg) -- targets ALL; otherwise the
  trimmed spec is an EXACT (case-sensitive) script name; the `except` name is always spared. Two
  deliberate deviations from literal Genie, both safety: (1) **"all" is scoped to running GenieScript
  (.cmd) instances only** -- a literal "abort all" over Lich's `Script.running` would also kill the
  mapper/infomon/command-broker/unrelated .lic; Genie had no such daemons. (2) **the issuing script is
  aborted LAST.** Genie's `AbortScript` is cooperative (flags the script to stop at its next tick), so
  self-abort in a `foreach` doesn't interrupt the loop; Lich `Script#kill` is NOT cooperative (kills
  the thread), so aborting self mid-iteration would strand the rest of an "abort all" -- so the router
  moves `@script_name` to the end of the abort list. Diagnose live: `,e echo
  Lich::Common::Script.running.select { |s| s.is_a?(Lich::Genie::GenieScript) }.map(&:name)`.
- **A "the engine picks the wrong spell" report was NOT an engine bug -- reconstruct the full
  script control-flow + live game-state before touching the engine.** Report: `,cl` (queue
  Chain Lightning) never switched sc.cmd off Lightning Bolt. The engine was exonerated
  end-to-end: the queueing script and sc share the one in-process GlobalStore (no per-instance
  cache), the spellcast reset trigger's deeply-nested 34-`;` `#if {($pf=0)} {...#var rspell 0;
  #var rspellname 0...}` clears BOTH vars (verified headless -> R4 run_branch is correct for
  arbitrarily nested branches), and nothing in the whole suite ever sets `autolb 1`, so the
  flag cascade could not have chosen LB. Real cause: a GAME-STATE var, `pvpjustice = 1` (a
  justice/law-enforcement zone) set the whole session, and sc's own adaptive-TM logic
  deliberately routes AoE spells (Chain Lightning) to single-target Lightning Bolt via its
  AdaptiveLB path -- identical in native Genie. TELL: the losing branch is reachable ONLY via a
  specific game-state flag; grep the suite for every WRITER of the "expected" var -- if nothing
  sets the value that would produce the observed command, the decision comes from a DIFFERENT
  var/path, not the engine. Method: build a timeline from the trace log (who launched/exited,
  every command issued), grep the .cmd sources for each variable's readers AND writers, and
  only after the script logic fully explains the observation do you suspect the engine.
- **`js`/`jscall` = reimplement the ONE community library natively, don't embed a JS engine
  (v0.9.2).** Corpus audit: the only JavaScript used anywhere (Tirost/Mastercraft/ubercombat =
  zero; public repo DR-Genie-Scripts = 9 files) is a single shared library `js_arrays.js` that
  gives Genie the array type it lacks -- every user copies it verbatim. So `lib/genie/js_arrays.rb`
  is a Ruby port of its ~two dozen ops (doPush/Pop/Shift/Unshift/Insert/Remove/Replace/Concat/
  Sort, findIndex/checkExists/doXCompare, find(Max|Min)(|Index|Global), zipArrays, buildArray[Str]).
  Wiring: arrays are `|`-delimited strings in LOCAL vars (getVar/setVar == local_get/local_set);
  `js FUNC(args)` mutates in place, `jscall VAR FUNC(args)` stores the return in local VAR. Handled
  in `run_script_row` AND `execute_action` (action bodies). KEY: the lexer ALREADY skips
  `include *.js` (it's the JS source we replaced -- `handle_include` returns on `.js`), so a script's
  `include js_arrays.js` is a clean no-op and the verbs route to our shim (verified: real
  Miner/mining.cmd + mm_train.cmd compile 0-warning and their `jscall doXCompare(...)` runs, dotted
  target var `this.volume` included). Two deliberate divergences from the JS: (1) `%name`/`$name`
  args are already resolved by our substitution pass, so we do NOT re-resolve (the JS's getVar/
  getGlobal on args is redundant here); (2) the JS's numeric find(Max|Min) use a buggy string
  compare (findMinIndex even returns the value) -- unused by any real script, so we implement the
  documented NUMERIC intent. Unknown js funcs + `#plugin`/`#pluginscript` now ANNOUNCE (echo a
  `[Genie: ... not supported ...]`) instead of silently no-op'ing. STILL a gap: class-scoped
  actions (`action (class) js ...`) are deferred by `do_action` [FIXED v0.9.3, below].

- **Class-scoped actions: implement them, don't defer -- and their class store is SCRIPT-LOCAL,
  NOT `#class` (v0.9.3).** `do_action` used to `return if text.start_with?('(')`, silently dropping
  every `action (class) ... when ...`. Genie's `action` verb (Script.cs EvalAction + ClassActionList)
  supports: `action (class) on|off|1|0|true|false|activate|inactivate` to TOGGLE a class, and
  `action (class) {cmds} when {re}` to scope a new action to it. CRITICAL faithful detail: action
  classes live in a per-script `ClassActionList.ClassList`, toggled ONLY by `action (class) on/off`
  -- they are INDEPENDENT of the front-end `#class` list (verified in the corpus: 0 scripts toggle an
  action-class via `#class`; all use `action (mapper) on/off` etc.). So the fix is entirely
  interpreter-local -- a `@action_classes` hash, no Lich glue/port needed. Semantics ported exactly:
  a new action inherits its class's current state; a never-seen class registers ON; `set_action_class`
  flips `active` on all actions already in the class. Also route `action` inside `execute_action` so a
  FIRING action can toggle its own class (the mapper idiom `... ;action (mapper) off`). No eval-actions
  (`action e/...`/variable-change triggers) exist in the corpus -- deferred. Verified: real
  automapper.cmd (116 action lines) compiles 0-warning and an off->on toggle gates firing e2e.
  Remaining action-body gaps (pre-existing, NOT class-scoping): `execute_action` still doesn't handle
  `if`/`math`/`shift` command bodies (1 `if` case in the corpus) -- those fall through to the game;
  next item if it bites.

- **Differential fuzzing against a REAL Genie4 oracle beats hand-picked specs (v0.9.4).** We can
  run Genie4's actual C# evaluators headless on macOS: the quirk-laden `Script/Eval.cs` +
  `Script/MathEval.cs` are WinForms-free, so a small `net8.0` console (genie-port-lab/oracle/, linked
  to those files + a 2-symbol shim for `Utility.StringToDouble`/`Globals.VariableList`) exposes
  `math`/`eval`/`evalbool` CLIs. A Ruby fuzzer (genie-port-lab/reference/fuzz_oracle.rb) throws
  thousands of random expressions at both and diffs. Result: 0 value-diffs across ~19k valid cases --
  BUT it caught a modulo bug specs never would: **Ruby's `Float#remainder` returns 0.0 when the
  DIVISOR dwarfs the dividend** (`-95 % 24^21` -> 0.0, not -95), while a subtract-formula loses
  precision for huge DIVIDENDS (`77^12 % 83`). Genie4's `%` is C# `double % double` (exact fmod,
  dividend sign, `x%0`->NaN). Fix in math_eval.rb `modulo`: `return lhs if lhs.abs < rhs.abs`
  (trunc(lhs/rhs)==0 so remainder IS the dividend), else `Float#remainder`; `rhs.zero? -> NaN`.
  General lesson: for any ported pure-computation layer, build the source oracle and fuzz it -- it
  finds float/edge divergences no tester or example-based spec will. (Needs .NET 8 SDK; net6-windows
  full app won't build on macOS, only the pure files.)
- **Domain errors + number FORMATTING now match C#/.NET byte-for-byte (v0.9.5), found by a STRING
  fuzzer.** The value-fuzzer compared numeric results with tolerance and missed formatting. A second
  fuzzer (genie-port-lab/reference/fuzz_format.rb) compares the `evalmath` STRING (our
  `format_double(evaluate)` vs Genie's Command.cs `EvalMath` = `double.ToString()` en-US). It exposed,
  and we fixed to 0 diffs across 30k exprs: (1) DOMAIN errors -- `sqrt(-x)`/`log(<0)`/asin(|x|>1) now
  return NaN (rescue Math::DomainError), `log(0)`->-Inf, and floor/ceiling/round pass NaN/Inf through
  (Ruby's raise -> mirror C#); (2) `^` = C# Math.Pow: NaN for neg-base+fractional-exp (Ruby gives a
  Complex), but Pow(1,y)==Pow(x,0)==1 even for NaN; (3) format_double rewritten to .NET
  double.ToString(): U+221E infinity glyph (built via `[0x221E].pack('U')` -- the AsciiOnlySource cop
  rejects even a \u escape that yields non-ASCII), `-0`, shortest-round-trip digits, fixed-point for
  leading-digit exponent in [-4,16] else scientific (`1E-05`,`1.2676...E+30`, min-2 exp digits); the
  old `f.to_i.to_s` emitted EXACT-integer digits (`...912`) not .NET's shortest (`...910`) above 2^53;
  (4) `\` integer div now truncates toward zero via exact bignum (no float precision loss) and errors
  on Int64 overflow like Genie's ToLong; (5) IEEE `-0` preserved through floor/ceiling/round/sqrt(-0).
  LESSON: fuzz the FORMATTED string, not just the numeric value -- float formatting is where the
  subtle, invisible divergences live, and the oracle makes them byte-verifiable.
- **`Text.parse_args` was subtly WRONG in ~6 ways -- caught by a ParseArgs oracle + fuzzer,
  rewritten to a faithful port (v0.9.6).** `Utility.cs` (ParseArgs + AddArrayItem) is WinForms-free,
  so we extracted a VERBATIM copy into the oracle's `Shims.cs` (namespace `GenieClient`), added
  `parseargs`/`parseargs_` modes (serialize the ArrayList as `<count>\x1f<tok>...` -- the leading
  count keeps `""`=0 tokens distinct from `{}`=one empty token), and fuzzed brace/quote/escape/
  underscore strings via `genie-port-lab/reference/fuzz_parseargs.rb`. The old char-BUFFER
  implementation diverged from Genie's start-pointer SUBSTRING algorithm on: (1) it DROPPED
  backslashes (`a\ b`->`["a b"]`; Genie keeps both: `["a\ b"]` -- the escape only makes the next
  char non-special, both stay); (2) it DROPPED interior/unbalanced quotes (`a"b"c`->`["abc"]`,
  `"hello`->`["hello"]`; Genie keeps them: `['a"b"c']`, `['"hello']` -- quotes are stripped only
  when they WRAP the whole token, via AddArrayItem); (3) no single-quote stripping (`'hello'`->
  Genie `["hello"]`); (4) it treated a brace as a buffer-append, not a TOKEN BOUNDARY -- `x{y}z`->
  Genie `["x","y","z"]` (a brace group is always its own token, even with no surrounding space),
  and it also let a `{` swallow the pending token; (5) it split on TAB (`\t`) -- Genie splits on
  ASCII space ONLY; (6) it never threw. Genie quirks now replicated: a stray `}` drives depth
  BELOW zero so later spaces stop splitting (`a}b c`->`["a}b c"]`); a `"` still toggles quoting
  INSIDE braces (so a `}` inside quotes doesn't close: `{a"}"b}`->`['a"}"b']`); a lone-quote token
  (`"` or `'`) THROWS -- Genie's AddArrayItem does `Substring(1, len-2)` = length -1 ->
  ArgumentOutOfRangeException, rethrown as "Invalid string in Parse Arguments"; we replicate with
  `csharp_substring` raising -> `parse_args` rescues + re-raises `Error` (GenieScript's
  StandardError rescue keeps the engine stable); `bTreatUnderscoreAsSpace` replaces `_`->` ` in
  every token EXCEPT the first (Genie gates it on `oList.Count > 0`). Result: 40k fuzz cases x2
  modes, 0 divergences; 16 regressions in `text_spec.rb`; the whole existing suite stayed green
  (real callers -- command_router, call_stack, variable_file -- unaffected). LESSON: even a
  "boring" tokenizer that "looks right" and passes example specs can be wrong in half a dozen
  ways a char-buffer reimplementation invents; port the ACTUAL algorithm (substring semantics),
  and let the oracle prove it.
- **`Numeric.string_to_double` was too lenient -- rewrote to .NET's grammar (v0.9.8).** Oracle
  modes `s2d` (Utility.StringToDouble), `toint`/`tolong` (VB Conversions.ToInteger/ToLong; needs
  `Microsoft.VisualBasic.CompilerServices`), fuzzed by `reference/fuzz_numeric.rb`. The old
  `Float(s) rescue Float(s.delete(','))` leaned on Ruby's `Float()`, which accepts things .NET's
  `double.Parse(en-US, Float|AllowThousands)` does NOT: `0x1F`->31 (hex), `1_000`->1000
  (underscores), `Infinity`; and it MISPARSED `1.5,3`->1.53 (a comma after the decimal, which .NET
  rejects) and MISSED `NaN` (.NET parses it, case-insensitive, optional sign; but NOT "Infinity"
  text). Because string_to_double drives numeric COMPARISONS in Eval (`0x1F < 5` etc.), the
  leniency changed real branching. Rewrote with an explicit grammar: `\A[+-]?(?:\d[\d,]*(?:\.\d*)?
  |\.\d+)(?:[eE][+-]?\d+)?\z` (commas only in the INTEGER part, .NET-lenient about grouping:
  `1,23`/`12,34`/`1,,2` all parse) plus a `\A[+-]?nan\z/i` special-case, validate FIRST, then strip
  commas and `Float()`. 20k s2d cases x5 seeds = 0 diffs; math/format/eval fuzzers unregressed.
  `to_integer`/`to_long` VALUE parity with Conversions is exact (banker's rounding + parse); their
  ONLY diffs are the cases where C# THROWS -- non-numeric (InvalidCastException) or out-of-range
  (OverflowException: >Int32 for ToInteger, >Int64 for ToLong). Left lenient (-1 / Ruby bignum),
  matching the substr-out-of-range precedent: the throw is reconciled or edge at every call site
  (`\` already Int64-overflow-checks in math_eval#integer_divide; substr clamps; round-digits/
  factorial/element take small ints), and the script-level effect of Genie's throw is unobservable
  from the isolated evaluator. LESSON: a "tolerant" parse helper that delegates to the host
  language's parser silently inherits that parser's grammar (Ruby Float's hex/underscore/Infinity)
  -- pin the SOURCE runtime's grammar explicitly and fuzz it.
- **Regex parity (match/matchre/replacere) + capture groups (v0.9.9).** `reference/fuzz_regex.rb`
  fuzzes these via the oracle's `eval` mode, and a NEW oracle mode `matchrecaps` runs a matchre(...)
  then serializes Genie's real `Eval.ResultList` (m_RegExpResultList) so CAPTURE-GROUP parity is
  observable (it isn't through `eval`, which returns only "1"/"0"). Two real bugs: (1) our matchre
  matched `subject.strip` while Genie does `Regex.Match(args[0], args[1])` with NO trim (Eval.cs:1149)
  -- diverged on leading/trailing whitespace in BOTH the boolean and the captures; fixed by dropping
  .strip. (2) our replacere only expanded `$digits`, but Genie's replacere is .NET `Regex.Replace`
  (Eval.cs:1176) with the full substitution grammar -- $$ $& $` $' $_ $+ ${name} ${number} $number
  (maximal digit run), and an out-of-range/invalid ref is emitted LITERALLY (leading $ included);
  ported as `expand_replacement`. matchre/matchre_caps/replacere now 100% (5k x8 seeds). LEFT
  lenient: `replace(s,"")` empty-needle (Genie throws ArgumentException) -- substr/count precedent.
  UNTESTED edge: matchre/replacere use DEFAULT .NET RegexOptions, so .NET's Unicode `\d\w\s` and
  string-anchored `^ $` differ from Ruby's ASCII/line-anchored -- a non-ASCII/newline subject could
  diverge (corpus is ASCII+newline-free). LESSON: side-effect state (capture groups in ResultList)
  needs its OWN oracle projection; a function's return value alone hides half the contract.
- **Corpus EXECUTE-sweep -> 3 runtime crash-hardening fixes (v0.9.9).** `reference/corpus_execute_
  sweep.rb` runs all 1499 corpus .cmd headless against a synthetic/EOF stream: fake ports + a virtual
  clock (real monotonic + fake accumulator) so timed waits resolve instantly while the engine's
  genuine runaway guards still fire, each script in a hard-timeout thread. 0 Ruby exceptions / 0
  timeouts on the stream itself. But a synthetic stream only exercises the matchwaits it happens to
  feed; STATIC analysis + harness validation surfaced 3 unguarded sites that crash on the right LIVE
  line -- and Genie explicitly guards all 3 (Script.cs), so they're parity bugs too: (1) matchwait
  jumping to an UNDEFINED label stored nil -> `NoMethodError` later at the row-index compare (91
  literal offenders in the corpus; Genie prints "Unknown label from MATCH command", Script.cs:1665)
  -> abort like do_goto; (2) a malformed `matchre` pattern -> unrescued `RegexpError` (Genie wraps
  matchwait in try/catch + compiles at construct time) -> precompile at add_match, drop the bad
  entry; (3) malformed `waitforre` -> same, and worse (waitfor has no timeout) -> rescue + finish.
  3 regressions in interpreter_spec.rb. LESSON: a runtime sweep proves "doesn't crash on THIS
  stream," not "can't crash" -- pair it with static reachability analysis for the inputs the stream
  never produced.
- **Property/invariant tests (v0.9.9), no oracle.** `reference/property_invariants.rb` (40k x5 seeds)
  + `spec/lib/genie/property_spec.rb` (CI subset). All HOLD, no bugs: format_double<->string_to_double
  bit-exact round-trip (incl. subnormals/Float::MAX via raw bit patterns) + format_double is a stable
  canonical form across a parse + always a well-formed .NET fixed/sci layout (no bad leading zeros);
  to_integer within 0.5/idempotent/identity-on-integrals; safe_split(s,sep).join(sep)==s; parse_args
  round-trips plain space-joined tokens. REFINED invariant: `expand` is idempotent ONLY for
  %local/@special sigil-free input -- it is NOT for `$`/backslash input BY DESIGN (expand un-escapes
  `\$`->`$` and runs the $-arg pass first; both are single-application). LESSON: a failing property is
  as often a mis-stated invariant as a bug -- confirm the property reflects Genie's actual behavior
  before "fixing" the code.

## DR game-state (the big surprises)
- **`XMLData` is shared GS/DR.** DR-specific state lives in DR modules.
- **DR `room_title` is DOUBLE-bracketed**: `"[[Bosque Deriel, Burial Ground]]"`
  (xmlparser.rb:607/626). Strip ALL surrounding brackets for `$roomname`.
- **DR does NOT populate `XMLData.indicator`.** Status flags ($standing/$kneeling/$sitting/
  $prone/$bleeding/$dead/$hidden/$invisible/$stunned/$webbed/$joined/$poisoned/$diseased)
  must resolve via Lich's **`check*` global predicates** (`checkstanding`, `checkbleeding`,
  ... aliased `standing?`/etc. at global_defs.rb:2936+). These work for DR **and** GS.
- **DR room contents live in `DRRoom`, not `GameObj`** (GameObj is GS): `DRRoom.pcs`/`npcs`/
  `room_objs`; `DRRoom.exits`/`title`/`description` delegate to `XMLData`. Use `room_exits`
  (array) for `$roomexits`, not `room_exits_string` (which has the "Obvious paths:" prefix).
  `DRStats.position` is **combat** position, unrelated to body posture.
- **DR spell timers**: `XMLData.dr_active_spells` = `{"Spell Name" => duration}` (presence =
  active; roisaen units, anlaen*30, Indefinite=1000, Fading=0). GS: `Effects::Spells`
  (`active?`/`time_left` in minutes). **Spell-name match is space-insensitive** — Genie
  "BlufmorGaraen" ↔ game "Blufmor Garaen".
- **Reserved vs config vars**: reserved/live vars (health, room, `$SpellTimer.*`, indicators)
  are set by the parser from the live stream and are **NOT in config files** — bridge them
  from Lich state. Only user `#var` vars live in `variables.cfg`.

## Cross-engine interop (native Genie-over-Lich AND the in-Lich engine)
- **The only channel BOTH environments share is the game stream.** Native Genie is a client behind
  Lich's proxy: it sees whatever Lich writes to the client (server stream + any Lich `respond`), runs
  its own scripts/plugins/reserved vars. The in-Lich engine runs Genie scripts as Lich scripts that
  read live Lich state + the downstream stream. So a "works in both" feature must produce data in Lich
  and let the scripts consume it via the stream (matchwait/trigger) or via a shared var NAME backed
  per-environment (the `$SpellTimer.*` model: a Genie plugin fills it natively, we synthesize it).
- **A Lich script's `respond`/`_respond` reaches native Genie but NOT the in-Lich engine's triggers.**
  `respond` writes to the client (`puts_main_stream`) + `Script.new_script_output` (only scripts with
  `want_script_output=true`). The in-Lich engine's triggers run on the server `DownstreamHook`; its
  `matchwait` reads the script `downstream_buffer` (fed by `Script.new_downstream` with the ORIGINAL,
  pre-hook stripped server line). So to feed the in-Lich engine you push via `Script.new_downstream`;
  to feed native Genie you write to the client. Different calls, same content.
- **Making Lich-echoed text matchable in the in-Lich engine (v0.9.7, Tirost's "match what Lich
  prints back" ask).** Native Genie sees everything Lich writes to the client (go2's "you're already
  there", "--- Lich: <script> has exited", another script's output), because it IS the client. The
  in-Lich engine did not: `matchwait` only saw `want_downstream` server lines, and triggers only fired
  on the server `DownstreamHook`. Two-part fix: (1) **`GenieScript#want_script_output = true`** so
  `Script.new_script_output` (called by every `respond`/`_respond`) feeds Lich-echoed lines into the
  script's `downstream_buffer` -> `matchwait`/`matchre` see them. (2) A **single global script-output
  trigger tap**: prepend a module onto `Lich::Common::Script`'s singleton so `new_script_output` also
  runs the Genie trigger pipeline ONCE per line (the choke point is global, so no once-per-running-
  script double-fire), guarded by a per-thread re-entrancy flag (`Thread.current[:genie_in_script_
  trigger]`) so a trigger action that itself `respond`s can't recurse (`fire`/`apply` are synchronous,
  so thread-local suffices). WATCH: want_script_output also feeds a Genie script's OWN `echo` (echo
  verb -> respond) back into its match buffer, which native Genie does not do (it matches the game
  stream, not its own echo) -- if a working combat script regresses on a self-echo match, this is the
  lever to revisit.
- **`put ,name` / `send ,name` now runs a LICH script/command (v0.9.7).** home.cmd's `put ,go2 2572`
  came back as "Please rephrase that command." -- the interpreter routed `#` to the bar-command router
  and `.` (SCRIPT_CHAR) to a Genie-script launch, but a leading Lich command char (`,`/`;`) fell
  through to the game socket. In native-Genie-over-Lich, `,go2` reaches Lich's client-input path
  (`do_client`), which sees the `,` and dispatches it. Fixed at the `LichGamePort#send_command`
  boundary (the in-Lich equivalent of "send to Lich's proxy"): a leading `,`/`;` (matched like Lich's
  own `$lich_char_regex = union(',',';')`) routes to `do_client(text.dup)` -- so `,go2`, `,kill`,
  `,pause`, `,list`, etc. all work exactly as if typed -- and skips RT pacing (a Lich command is not
  RT-gated). Everything else still goes through `put`. `.name` still launches a GENIE script; `,name`
  runs a LICH one.
- **AssessIds delivery was chunking-fragile -- rewritten line-based (v0.9.7).** The old `observe`
  block-buffered from `<pushStream id='assess'>` to the FIRST `<popStream>` and processed that slice
  once. DR's current form sends each assess line as its own `<popStream/><pushStream id="assess"/>...
  \r\n`; when the server BATCHED the whole block into one chunk, the first-popStream slice dropped
  every assess line but the first (the "assess ids sometimes don't show up" bug). Rewrote to process
  the stream LINE BY LINE (split on `\n`, buffer only a trailing partial), tracking inside-assess
  state across lines via push/pop markers and enriching any assess line that carries a `look #id`
  link. Proven on Tirost's real raw capture (2026-08-24): the summary line `You (adeptly balanced) are
  facing <d cmd='look #86948248'>a jeol moradu</d> (3) at melee range.` enriches to exactly what his
  `^You \(.*?\).*?\[#(\d+)\].*?at.*?range\.` (commonbg.cmd) matches. The "doubled `[#id]`" he saw is
  two DIFFERENT creatures on one status line ("A jeol moradu [#a] ... is behind a jeol moradu [#b]"),
  not a true duplicate. DECISION (per user): keep the TEXT-splice approach as the drop-in for his
  existing regex-matching scripts; do NOT re-render from the parsed `Creature` module (structured data
  is great for `Creature.targets` queries but re-rendering text would be less faithful to his regexes).
- **Assess exist-ids: surface them in Lich, don't reinvent them (v0.9.0 `AssessIds` shim).** DR sends
  each creature as `<d cmd='look #NNN'>name</d>` in a `<pushStream id='assess'>..<popStream/>` block
  (Lich already parses this into the `Creature` module). The `[#nnnnn]` scripts match is a FRONT-END
  annotation (ProfanityFE), not game text, so id-targeting scripts silently depend on that FE. The
  opt-in shim re-emits each assess creature line with the id spliced back into the visible text
  (`name [#id]`) so the UNMODIFIED scripts match in both engines / any FE. Key design points: (1) it
  PASSES THE STREAM THROUGH unchanged and only ADDS lines, so XMLData/Creature parsing is untouched;
  (2) delivery is environment-aware -- `$frontend == 'genie'` -> `_respond` (native Genie matches its
  displayed text); else -> `Script.new_downstream` (in-Lich engine `matchwait`, no duplicate FE line);
  (3) the id is read straight from the tag (no re-parse); (4) per-character toggle
  `Lich::Genie::AssessIds.enabled = true`, self-installs from `ensure_downstream_hook!` for the in-Lich
  engine, needs an autostart `install!` line for native-Genie-only. The pure `enrich`/`enrich_block`
  transform is unit-tested against Tirost's real `commonbg.cmd` regex so format fidelity can't drift.

## Persistence / config model
- Genie persists globals to the **global** `Config/variables.cfg` → account-wide/cross-char.
  Format: `#var {key} {value}` (parsed by ParseArgs → our `Text.parse_args`). Only
  `bSaveToFile` (`#var`) is written; `#tvar` is memory-only.
- We store under `<SCRIPT_DIR>/GenieProfiles/Config/variables.cfg`.
- **R6 — globals reset to their literal text mid-combat (v0.8.0).** Symptom: after a long
  combat run, `$rimon`/RIME stopped registering, then `$qspell`/`$backpack` went literal
  (`put my cube in my $backpack`, `[Unknown label from GOTO: $qspell]`), and every global
  read literal in the scripts launched *after* the buffer script exited. Root cause: the one
  process-wide `GlobalStore` is written by BOTH a running script's thread (`#var`) AND the
  downstream/socket thread firing `#triggers` (a combat trigger's `#var rimon 1`) — with **no
  mutex**. Its `reload_if_changed` briefly EMPTIES the persistent keys before repopulating, so
  a concurrent `save_file` could snapshot the emptied map and **truncate `variables.cfg`**;
  a later reload then dropped the keys from memory too — permanent, progressive loss. (Quiet =
  one writer = fine; combat = two writers racing = corruption, which is why it was intermittent
  and worsened over a run.) `Triggers`/`StreamFilters` were already mutex-guarded for the exact
  same cross-thread reason; `GlobalStore` was the one shared collection that wasn't. Fix:
  serialize all `GlobalStore` public methods under `@mutex`, and rebuild `reload_if_changed`
  **atomically** (read file → build new maps → swap; never leave `@values` transiently empty,
  and a failed read keeps the in-memory copy). Regression: two-writer + reader thread hammer in
  `global_store_spec.rb`. **Lesson: any collection reachable from both a script thread and the
  trigger/downstream thread needs a lock — audit the shared `Lich::Genie.*` singletons.**

## Ruby / tooling gotchas
- **AsciiOnlySource rubocop cop** rejects non-ASCII **including in comments** (an em-dash
  broke a build). Use `\xNN`/ASCII-producing escapes for sentinels (Genie's `¤` → `\x01`).
- `.gitignore` has a blanket `*.md` — design/spec docs are **force-added** (`git add -f`).
- **`GenieScript < Script` must set `@thread_group = ThreadGroup.new`** (WizardScript sets it
  at the tail of its init). Missing it → `"bind argument must be an instance of ThreadGroup"`.
- **The per-character `enabled` toggle key is built from LIVE `XMLData`** (`genie_enabled:<game>:
  <char>`), which is **empty until the character stream arrives**. Never single-slot-memoize it: an
  `enabled?` call before login computes key `genie_enabled::`, reads a miss, and would cache a false
  that poisons the real post-login read (the toggle "won't stick across relogs"). Cache **per
  resolved key** and **skip caching** when game/char are empty (read live, self-heal). Fixed in
  `enabled?`/`enabled=` (per-key `@enabled_by_key`, `character_scoped?` guard). Diagnose stored keys:
  `;eq echo Lich.db.execute("SELECT * FROM lich_settings WHERE name LIKE 'genie_enabled:%';")`.
- **When `Lich::Genie.enabled` is false, `.cmd` falls back to WizardScript**, which transpiles
  to Ruby and throws syntax errors on Genie syntax (e.g. `matchre "x", (?i)obvious`). If you
  see `Kernel#eval` syntax errors in a `.cmd` run, the engine wasn't enabled.
- `send_command` is single-send (verified by the hunting spec + headless). A doubled command
  echo in a pasted terminal transcript was a copy-paste artifact, not a bug.
- Naming collision: `$frontend == 'genie'` means the Genie **client**, distinct from our
  `Lich::Genie` engine namespace.

## angua deployment reality (Lich runs there)
- Lich runs from `/home/grocha/lich-5-mine`, launched per character. Engine `.rb` files load
  at **Lich startup** → must relogin/restart to pick up changes.
- The user updates via **`;lich5-update --branch=MahtraDR:feature/genie-scripting-engine`**
  (downloads a tarball, overwrites files, does **NOT** move git HEAD — `git log` is
  misleading). **Must re-run it to get new commits.** `%2F` in the branch URL works.
- `lich.db3` is **shared across characters** (bare `lich_settings` keys are install-wide).
  The Genie toggle is therefore keyed by `game:character` for true per-character behavior.
- `scp` of individual files works for fast iteration but is overwritten by the user's next
  reset/update; the git branch (origin) is the source of truth.
- Read run output from **log.lic** transcripts: `logs/DR-<Char>/YYYY/MM/YYYY-MM-DD_HH-MM-SS.log`.
- Inspect live state with `;eq echo <ruby>` (e.g. `;eq echo XMLData.dr_active_spells`).
