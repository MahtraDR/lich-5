# genieHook Protocol — front-end-agnostic Genie front-end effects

**Audience:** front-end developers (Lichborne first, but any front-end). This is the canonical,
shareable contract for the front-end effects a Genie script can trigger. Lich runs the Genie
*automation* engine; when a script touches a Genie *front-end* feature (highlights, windows,
gauges, colors, sounds, echo-to-window), Lich emits a `<genieHook>` event carrying the full Genie
semantics. Lich renders nothing itself and contains no front-end-specific code.

> Status: **framework defined; per-op payload catalog complete (Phase 4).** All bar-command front-end
> effects with a runtime handler in Genie's `Core/Command.cs` are finalized ✅, ported in
> `lib/genie/command_router.rb`, and covered by specs. Any `#command` without a finalized op falls
> back to a tokenized `{args, raw}` payload (safe to ignore). Payload fields marked ✅ are authoritative.

## Design goals
1. **Front-end agnostic.** No assumptions about a front-end's widget model. Hooks describe
   *intent + full Genie parameters*, not a specific UI.
2. **Complete & self-describing.** A front-end can reproduce Genie's exact behavior from the hook
   alone, without re-deriving anything from the raw stream.
3. **Safe to ignore.** A front-end that doesn't implement a hook (or any hooks) drops it
   harmlessly; the script's automation is unaffected.
4. **Versioned & extensible.** New ops/fields can be added without breaking older front-ends.

## Transport
- Hooks ride the **existing downstream stream to `$_CLIENT_`** (the same channel as game XML), so
  no new socket/IPC is required. Emitted alongside `send_to_client` (`lib/games.rb:1122`).
- Wire form: a single self-closing, namespaced XML-ish tag on its own line:

  ```
  <genieHook v="1" op="<name>" ...attributes... />
  ```

  - `v` — protocol version (integer). Current: `1`.
  - `op` — the operation name (see catalog).
  - Payload is carried as **XML attributes** (preferred for simple scalars) and/or a single
    `data` attribute containing a **JSON object** for structured/nested payloads. Each op's entry
    specifies which. All attribute values are XML-entity-encoded (`Lich::Common::XmlEntities`).
- The tag is namespaced (`genieHook`) and unknown to the game protocol, so existing XML parsers
  that don't recognize it will skip it. Front-ends match on `<genieHook` at line start.

## Capability negotiation & degradation
- A new `Frontend` capability **`:genie_hooks`** is added to the registry
  (`lib/common/front-end.rb`). Front-ends that render hooks advertise it.
- Emission policy (configurable): either (a) emit always (non-capable front-ends ignore the tag),
  or (b) suppress emission when the connected front-end lacks `:genie_hooks`. Default: **emit
  always** — simplest, and keeps logs/replays complete.
- Regardless of front-end support, **automation always runs**. Front-end effects are best-effort.

## Op catalog (target set — payloads finalized in Phase 4)
Derived from Genie's front-end bar-commands (`Core/Command.cs`). Grouped by concern:

| op | Genie source verb(s) | Purpose | Payload status |
|---|---|---|---|
| `highlight` | `highlight` | add a highlight (kind, color, pattern, class, case, sound, active) | ✅ |
| `preset` | `preset` | named color preset / class-based text coloring | ✅ |
| `class` | `class` | enable/disable a named class (gates highlights/actions) | ✅ |
| `window` | `window` | add/show/position/remove/close/hide a named window | ✅ |
| `echo` | `echo >window` | echo text into a named window (vs main) | ✅ |
| `gag` / `ungag` | `gag`/`ignore`/`squelch`, `ungag` | suppress lines matching a pattern | ✅ |
| `substitute` / `unsub` | `sub`/`substitute`, `unsub` | rewrite matching text | ✅ |
| `trigger` | `trigger` | register/clear a regex trigger → command(s), optional class | ✅ |
| `macro` / `unmacro` | `macro`, `unmacro` | define/remove a hotkey → command(s) | ✅ |
| `alias` / `unalias` | `alias`, `unalias` | define/remove an input alias | ✅ |
| `name` / `unname` | `name`, `unname` | color/class a player/creature name | ✅ |
| `playsound` | `playsound`/`playwave`/`play` | play a sound file (or `stop`) | ✅ |
| `link` | `link` | clickable text → command, optional window | ✅ |
| `image` | `image`/`img` | show an image (window, width, height) | ✅ |
| `beep` / `flash` | `beep`/`bell`, `flash` | audible/visual alert (no args) | ✅ |
| `layout` | `layout` | load/save a named layout | ✅ |

Legend: ✅ finalized · ⏳ payload TBD.
**Not ported (no Genie runtime handler):** `#unhighlight` (removal is only `#highlight clear`) and
`#gauge`/`#gauge` (no bar command exists in `Core/Command.cs` — Genie gauges are driven elsewhere).
Any unrecognized `#command` still emits `{op, {"args": [...], "raw": "..."}}` (safe to ignore).

## Finalized payloads (✅)
These are emitted by `lib/genie/command_router.rb` (the `Core/Command.cs` port) and asserted in
`spec/lib/genie/command_router_spec.rb`. Fields are authoritative.

- **`class`** — `{"name": <string, lowercased>, "enabled": <bool>}`. One hook per class token, so
  `#class +a -b` emits two. `#class name on|true|1` → enabled; `off|false|0` → disabled.
- **`trigger`** — add: `{"pattern": <regex string>, "commands": <string>, "class": <string, "" if
  omitted>}`; clear: `{"action": "clear"}`. `commands` is the raw Genie command string (may contain
  its own `#…`/`;`-separated commands) for the front-end's trigger engine to run — Lich does not
  execute it. Escaped `\\$var` in Genie source arrives here as a literal `$var` (front-end-evaluated).
- **`echo`** — `{"window": <string>, "text": <string>}` for `#echo >window text`. Plain `#echo text`
  is a **local** echo (not a hook).
- **`gag` / `ungag`** — `{"pattern": <string>, "class": <string>}`.
- **`substitute` / `unsub`** — `{"pattern": <string>, "replacement": <string>, "class": <string>}`.
- **`highlight`** — add: `{"kind": "line"|"string"|"beginswith"|"regex", "whole_row": <bool>,
  "color": <string>, "pattern": <string>, "case_sensitive": <bool>, "sound": <string>,
  "class": <string>, "active": <bool, default true>}`; clear: `{"clear": true}`. Requires a
  sub-keyword (`#highlight line ...`); a bare `#highlight red foo` is a *list/display* in Genie and
  emits nothing. Genie reads `pattern` greedily to end-of-line (`ArrayToString(oArgs,3)`) — faithfully
  reproduced, so trailing `case/sound/class/active` are only honored when `pattern` is a single
  brace-wrapped token.
- **`preset`** — `{"name": <string, lowercased>, "value": <string>}` (color parsing is the FE's job).
- **`window`** — `{"action": "add"|"show"|"position"|"remove"|"close"|"hide", "name": <string>, ...}`.
  `add`/`show` carry Genie's hardcoded `width:300, height:200, top:10, left:10`; `position` carries
  `width/height/top/left` as ints or `null` (empty or `0` → `null`).
- **`macro` / `unmacro`** — `{"key": <string>, "command": <string>}` / `{"key": <string>}`.
- **`alias` / `unalias`** — `{"pattern": <string>, "command": <string>}` / `{"pattern": <string>}`.
- **`name` / `unname`** — one event per target: `{"name": <target>, "value": <color/class>}` /
  `{"name": <target>}` (Genie applies `oArgs[1]` to each following name token).
- **`playsound`** — `{"file": <string>}` or `{"stop": true}` (from `#play stop`). `#play`/`#playwave`/
  `#playsound` all map to this op.
- **`link`** — `{"window": <string, "" if none>, "text": <string>, "command": <string>}`.
- **`image`** — `{"filename": <string>, "window": <string>, "width": <int, 0 default>,
  "height": <int, 0 default>}`. Genie parses `>window`/`w:`/`h:` tokens order-independently.
- **`beep` / `flash`** — `{}` (no payload).
- **`layout`** — `{"action": "load"|"save", "name": <string>}`; bare `#layout` → `{"action":"load",
  "name":"@windowsize@"}`.

> **Model A note (Decision 6):** `gag`/`ungag`/`substitute`/`unsub` are *normalized events* the Lich
> **sink** consumes to install a `DownstreamHook` (stream-side rewrite), NOT rendered `<genieHook>`
> tags. They share this catalog's shape so the engine emits one event type; the sink chooses the
> transport. All other ops here ride the `<genieHook>` stream.

Engine-side `#commands` (`#var`/`#tvar`/`#svar`/`#unvar`, `#eval`/`#evalmath`/`#math`/`#if`, `#send`)
execute inside Lich and emit **no** hook. An inline `#function` used as a value (e.g. `#var t
#evalmath ($unixtime + 5)`) is evaluated by the engine, matching Genie's `ParseAllArgs` recursion.

## Example (illustrative — fields not yet authoritative)
```
<genieHook v="1" op="highlight" data='{"pattern":"a kobold","color":"#ff0000","bgcolor":null,"class":"combat","regex":false,"scope":"line","sound":null}'/>
<genieHook v="1" op="window" data='{"name":"thoughts","action":"create"}'/>
<genieHook v="1" op="echo" data='{"window":"thoughts","text":"pathing to bank","color":null}'/>
<genieHook v="1" op="playsound" data='{"file":"alert.wav","volume":1.0}'/>
```

## Notes for front-end implementers
- Treat unknown `op` or unknown JSON fields as ignorable (forward-compat).
- `class`/`preset`/`highlight` interact (classes gate highlights; presets supply colors) — mirror
  Genie's model: a highlight may reference a `class` (on/off gating) and a color that may be a
  named preset. The hooks carry both the resolved color and the class name.
- Persistence is the front-end's choice. Genie persists these in `.cfg` files; hooks represent
  *runtime application* of script-issued changes. A front-end may also import Genie config
  directly (e.g. Lichborne already ships a Genie config importer) — orthogonal to this protocol.
