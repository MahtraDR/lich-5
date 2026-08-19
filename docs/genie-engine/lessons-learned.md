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

## Ruby / tooling gotchas
- **AsciiOnlySource rubocop cop** rejects non-ASCII **including in comments** (an em-dash
  broke a build). Use `\xNN`/ASCII-producing escapes for sentinels (Genie's `¤` → `\x01`).
- `.gitignore` has a blanket `*.md` — design/spec docs are **force-added** (`git add -f`).
- **`GenieScript < Script` must set `@thread_group = ThreadGroup.new`** (WizardScript sets it
  at the tail of its init). Missing it → `"bind argument must be an instance of ThreadGroup"`.
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
