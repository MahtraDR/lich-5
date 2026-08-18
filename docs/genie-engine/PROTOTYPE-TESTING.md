# Genie engine prototype -- how to test

The Genie scripting engine now runs `.cmd` scripts end-to-end inside Lich. This is a
working prototype: the interpreter, expression/variable engines, control flow, waits,
matchwait, actions, and front-end `<genieHook>` emission are all implemented and covered
by 105 passing specs. Some pieces are still stubbed (see Limitations).

## Enable it

The engine is **off by default** (so `.cmd`/`.wiz` continue to run under WizardScript).
Turn it on for the session from your client:

```
;e Lich::Genie.enabled = true
```

While enabled: `.cmd` files run on the **Genie engine**, and `.wiz` handling is disabled.
To go back to the old behavior:

```
;e Lich::Genie.enabled = false
```

## Run the sample

1. Copy the sample into your Lich `scripts` directory:
   `docs/genie-engine/examples/genie-hello.cmd` -> `<SCRIPT_DIR>/genie-hello.cmd`
2. Enable the engine (above).
3. Run it: `;genie-hello`

Expected output (echoed to your client): a greeting, three counted iterations (one per
second), then `doubled is 6` and `isdone flag is 1`. It sends **no** game commands, so
it is safe to run on a live character.

## What works

- Verbs: `echo`, `put`, `send`, `goto`, `gosub`/`return`, `if`/`elseif`/`else`, `while`,
  `{ }` blocks, `pause`/`delay`, `wait`, `match`/`matchre`/`matchwait`, `waitfor`/`waitforre`,
  `move`/`nextroom`, `setvariable`/`unvar`/`save`/`counter`/`math`/`eval`/`evalmath`/`random`/
  `shift`, `action` (async triggers), labels.
- Variables: `%local`, `$global`, `%name(idx)` arrays, `%name.length`, `@time@`/`@timer@`
  specials, `$1..$n` args, longest-prefix + undefined-left-literal semantics.
- Expressions: full `if`/`while`/`eval` boolean/string engine and `evalmath`/`math`/`counter`
  arithmetic, faithful to Genie's quirks.
- Persistent config variables: `#var`/`#svar` save to
  `<SCRIPT_DIR>/GenieProfiles/Config/variables.cfg` (account-wide, cross-character, survives
  restart -- Genie's own format); `#tvar` is session-only. **Drop an existing Genie
  `variables.cfg` into that folder to reuse your config as-is.** `$name` reads it back.
- Front-end bar commands issued from a script (e.g. `put #highlight ...`) emit a
  `<genieHook>` tag to the client (front-ends that do not implement it ignore it).
- Runaway-command watchdog (10 identical / 30 total sends in 10s stops the script).
- Standard Lich lifecycle: `;list`, `;kill`, pause at put/gets boundaries.

## Limitations (prototype)

- `js`/`jscall`/`plugin` are stubbed (no-ops for now).
- `wait`/`move` resume on the next line (no prompt/room-change detection yet).
- `gag`/`sub` (Model A downstream rewriting) not yet wired into the stream.
- Reserved game-state globals (`$health`, `$roundtime`, ...) cover a common subset; the full
  Genie reserved list will be aligned next.
- Command pacing goes straight through `put`; it will move to the command broker.

## Report back

If a real Genie script misbehaves, the most useful thing is the script text + what it did
vs. what Genie does. Those become fixtures under `spec/fixtures/genie/`.
