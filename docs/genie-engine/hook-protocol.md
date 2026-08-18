# genieHook Protocol — front-end-agnostic Genie front-end effects

**Audience:** front-end developers (Lichborne first, but any front-end). This is the canonical,
shareable contract for the front-end effects a Genie script can trigger. Lich runs the Genie
*automation* engine; when a script touches a Genie *front-end* feature (highlights, windows,
gauges, colors, sounds, echo-to-window), Lich emits a `<genieHook>` event carrying the full Genie
semantics. Lich renders nothing itself and contains no front-end-specific code.

> Status: **framework defined; per-op payload catalog filled during Phase 4** (after extracting
> Genie's `Core/Command.cs` front-end handlers). Op names below are the target set; payload
> fields are authoritative only once marked ✅.

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
| `highlight` | `highlight`, `unhighlight` | add/remove a highlight (pattern, color, class, regex/literal, match scope, sound) | ⏳ |
| `preset` | `preset` | named color preset / class-based text coloring | ⏳ |
| `class` | `class` | enable/disable a named class (gates highlights/actions) | ⏳ |
| `window` | `window` | create/show/hide/clear a named window/stream | ⏳ |
| `echo` | `echo <window>` | echo text into a named window (vs main) | ⏳ |
| `gag` | `gag`/`ignore`, `ungag` | suppress lines matching a pattern | ⏳ |
| `substitute` | `sub`/`substitute` | rewrite matching text | ⏳ |
| `gauge` | (Genie gauges) | bind a gauge/bar to a variable/value | ⏳ |
| `variable` | `var` (display-relevant) | surface a named/string variable for on-screen display | ⏳ |
| `macro` | `macro` | define a hotkey → command(s) | ⏳ |
| `alias` | `alias` | define an input alias | ⏳ |
| `playsound` | `playsound`/`playwave`/`play` | play a sound file | ⏳ |
| `link` / `image` | `link`, `image`/`img` | open a link / show an image | ⏳ |
| `beep` / `flash` | `beep`, `flash` | audible/visual alert | ⏳ |
| `layout` | `layout` | apply a named layout | ⏳ |

Legend: ✅ finalized · ⏳ payload TBD (Phase 4).

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
