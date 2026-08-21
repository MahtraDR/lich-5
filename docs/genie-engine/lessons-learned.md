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
