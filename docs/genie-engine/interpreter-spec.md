# Genie Script Interpreter — Ruby Port Spec

Ground-truth extraction from `Genie4/Script/Script.cs` (4417 lines), `Utility/Utility.cs`,
`Lists/Globals.cs`, `RegexOptions.cs`. Line numbers refer to `Script.cs` unless noted.
This is the authoritative behavior spec for the clean-room Ruby port.

> **Two fidelity caveats up front:**
> 1. **`while` has NO back-edge.** The `evalwhile*` block states are set but never consumed
>    to jump backward. Genie's `while` is a one-shot `if`-style guard; real loops are
>    label+`goto`. Do **not** synthesize a loop back-edge.
> 2. Several verbs (`if`/`while`/`else`/`waiteval`/`timer`/`debuglevel`/`js`/`jscall`/`plugin`/
>    `action`) read the **raw** `sRowContent`, not the variable-substituted `ParsedLine`.
>    Replicate per-verb (see verb table).

---

## 0. Core data structures

- **`ScriptLine`** {`iFileId`, `iFileRow` (1-based), `sRowContent`, `oFunction:ScriptFunctions`}.
  The whole program is `m_oScript` = flat ordered array; the PC is an index `I` into it.
- **`Line`** = one call-stack frame: `iIndex` (PC / return address), `bSkipBlock`, `iBlockDepth`
  (`TargetBlockDepthValue`), `oBlockList` (block-state stack), `oArgList` (`$0..$n`),
  `bLastRowWasEvaluation` (single-line `if…then <cmd>` marker).
- **`CurrentLine`** = the call stack (`oLineList`). **Index 0 = base/main frame; last = active.**
  All accessors operate on the **top** frame: `LineValue` (PC get/set), `AddJump`/`RemoveJump`
  (push/pop; never pops base), `AddBlock`/`RemoveBlock`/`BlockValue`/`BlockCount`, `ArgList`,
  `SkipBlock`, `TargetBlockDepthValue`, `LastRowWasEvaluation`, `Clear` (wipe stack),
  `ClearBlocks` (clear active frame's block list only).
- **`BlockState`**: `noeval, evaltrue, evalfalse, evalwhiletrue, evalwhilefalse`.
- **`ScriptState`**: `finished, running, pausing, delayed, wait, waitfor, waitdo, waiteval, move,
  matchwait, actionwait, actioninstant, scripterror`.
- Storage: `m_oScriptLabels` (label→index, lowercased), `m_oLocalVarList` (`%`-vars, SortedList,
  **case-sensitive keys**), `m_oActions`, `MatchList`.
- Concurrency: all public entry points take `Monitor.TryEnter(m_oThreadLock, 3500ms)`. In Ruby,
  one `Mutex` guards `TickScript`, `TriggerParse`, `TriggerVariableChanged`, `TriggerMove`,
  `TriggerPrompt`, `RunScript`, `SetRoundTime`, `SetBufferEnd`, Pause/Resume/Abort/Reload.

> **Threading note for the Lich port:** Genie ran this as a cooperative state machine ticked
> every 10ms on the UI thread. In Lich we run it on a per-script worker thread that *blocks*
> on the downstream buffer for waits. The `ScriptState` machine + `TickScript` resume logic
> can either be preserved (a Ruby tick loop) or collapsed into blocking reads. Preserving the
> state machine is the most faithful; evaluate during Phase 1.

---

## 1. Control flow

**Main loop `RunScript(iArrayIndex=-1)`** (1743): start at `LineValue` if arg is -1; loop
`for I = start; I <= Count; I++`. Each iteration first writes `LineValue = I` (so gosub/return/
reload see the PC). Break if state≠running or paused. If `I >= Count`: finish. Else fetch
`m_oScript[I]`, do block bookkeeping for `{`/`}` (§2), then if `!SkipBlock`:
`I = RunScriptRow(oLine, I)` (return value becomes new `I`; loop `I++` advances). If an action
set `m_bStopRunning`, reset and `return` (abandon thread). Per-invocation wall-clock guard:
if elapsed > `Config.iScriptTimeout` → "Possible infinite loop", finish.

**Jump mechanic:** handlers return a target index; the loop's `I++` means execution resumes at
`target+1`. Labels are their own instruction, so landing on `labelIndex`+`I++` = first line after.

- **`goto`** (2487): resolve lowercased label; add `%lastlabel`; **`ClearBlocks()`** (drop block
  depth on active frame); return label index. Unknown → error + `AbortOnScriptError`. Does NOT
  touch the call stack. No round-time wait.
- **`gosub`** (2516): `gosub clear` wipes the stack. Else `AddJump(iRowIndex, <args-after-label>)`
  pushes a frame (return addr = current PC; `$0`=full arg string, `$1..$n`=parsed tokens);
  depth check vs `Config.iMaxGoSubDepth`; return label index. Forbidden inside actions.
- **`return`** (2552): `RemoveJump()` pops top frame (only if Count>1); return the now-active
  frame's `LineValue` (the gosub line's index) → resumes after the gosub. Empty stack → error+abort.
- **`exit`** (2594): set `I = Count`, finish. Terminal.
- **`label`** (2577): pass-through; **error if `BlockCount > 1`** (passing a label from within a
  nested block is illegal; being in one block is OK).
- **Hot reload** (`HotReload`/`FindNewJumpLineIndex`, 1943): re-parse file on `_pendingReload`,
  remap frame indices by nearest matching (content, fileId, fileRow). **Phase-1: may stub** to
  "return label index", but keep the `ClearBlocks`/jump semantics.

---

## 2. Block model (`if`/`elseif`/`else`/`while`/`{`/`}`)

**Compilation (`AddLine`, 3766):** `if <c> then <cmd>` splits into an `if` line (ending at `then`)
+ a recursively-added `<cmd>` line; bare ` then` = block-opening `if`. Same for `while … do`.
`else <cmd>` → `else` + `<cmd>`. **`elseif <c>` desugars to `else` + `if <c>` as two sibling
lines** (governed by single-line-skip, §2.4). `{`/`begin`→`blockstart`, `}`/`end`→`blockend`.
`if_N` → `if %argcount >= N …`.

**Runtime transitions** (in `RunScript` before `RunScriptRow` for `{`/`}`):
- **`{` blockstart** (1868): if `SkipBlock` and `TargetBlockDepthValue<=0`, set it to current
  `BlockCount`; `AddBlock()` (push noeval); `LastRowWasEvaluation=false`.
- **`}` blockend** (1881): `RemoveBlock()`; if `SkipBlock` and `TargetBlockDepthValue>=BlockCount`,
  clear `SkipBlock` and `TargetBlockDepthValue=0` (resume).
- **`if`** (2607): if row ends ` then`, `LastRowWasEvaluation=true`. `EvalIfStatement(arg)`
  true→`BlockValue=evaltrue`; false→`BlockValue=evalfalse` + `SkipBlock=true`.
- **`while`** (2629): same but `evalwhiletrue`/`evalwhilefalse`; `do`→LastRowWasEvaluation.
  **No back-edge** — behaves as `if`.
- **`else`** (2651): if row ends `else`, LastRowWasEvaluation. If `BlockValue==evaltrue` (matching
  if was true) → `SkipBlock=true` (skip else); else run else. Relies on the if's marker still
  being top-of-block after its `}` popped.

**Single-line forms (§2.4, 1908):** an evaluation line that set `SkipBlock=true` also set
`LastRowWasEvaluation=true`; the next line is skipped, then `SkipBlock` cleared — UNLESS that next
line is itself an `if` (lets `if…then if…then` chains skip). Cleared on every `blockstart`.

`EvalIfStatement` (3506) strips a trailing ` then`, calls `Eval.DoEval`, copies `Eval.ResultList`
into `ArgList` (capture groups). `EvalWhileStatement` (3533) is a bare `Eval.DoEval`.

---

## 3. Variable substitution (`ParseVariables`/`ParseVariable`, 2318)

Applied to `sRowContent` → `ParsedLine` at top of `RunScriptRow`. Passes, in order:

1. **`$`-args** (if text has `$`): protect `\$`; for `i=0..iArgumentCount-1` naive
   `Replace("$"+i, ArgList[i] or "")` **low→high** (so `$10` is hit by `$1` first — replicate
   this quirk); `$argcount`→`ArgList.Count-1`; restore `\$`→`$`.
2. **`%`/`$` vars** (if text has `%`): protect `\%`,`\$`; **scan right-to-left**, expanding `%name`
   via local list and `$name` via globals at each unescaped sigil (right-to-left = single-level,
   positional; expansion isn't re-scanned). Else (no `%`) → `Globals.ParseGlobalVars` ($ + @).
3. **`@`-specials** (if text has `@`): `@timer@`→elapsed secs; `Globals.ParseSpecialVariables`
   (`@time@`,`@time24@`,`@date@`,`@militarytime@`,`@unixtime@`,`@year@`,`@month@`[=minutes, a
   quirk—preserve],`@spelltime@`, etc. — copy format strings verbatim).

**`ParseVariable`** (2405): name ends at first space. Array form `name(idx)`: split value on `|`,
return element+remainder (invalid idx → empty for locals). Longest-prefix match; `name.length`
→ element count. **Undefined → literal `%name`/`$name` left in place** (triggers eval warnings).
Locals (`%`) and globals (`$`) are separate namespaces, not a fallback chain.

**Engine-set vars:** `scriptname`, `0..9`+`argcount`, `lastlabel`, `lastcommand`,
`lastscripterror`, `s` (save), `r` (random), `c` (counter), `t` (timer; stored literally as
`"@timer@"` while running so it re-expands live). Escaping `\%`/`\$` → literal.

---

## 4. match / matchwait

- **Register** (`EvalMatch`, 3297): `match <label> <text>` / `matchre <label> <regex>`.
  `match clear` empties list. Stores {Text, Label, IgnoreCase, IsRegExp, precompiled Regex}.
  `matchre` strips `/…/`, `/i` (→IgnoreCase). Invalid regex → error+abort.
- **Block** (`EvalMatchWait`, 3281): `matchwait [timeout_secs]`. timeout>0 → set deadline +
  `m_bMatchTimeoutState`. state=`matchwait`; loop breaks.
- **Select** (`TriggerParse`, 1264): on each game line, iterate MatchList **in insertion order**,
  first hit wins: literal `Contains`, or regex `Match(text.Trim())` (groups 0..N → ArgList,
  `$0`=whole match). Set label, `m_bWaitForMatch`, `MatchList.Clear()`, break.
- **Resume** (`TickScript`, 1634): when `m_bWaitForMatch && m_bBufferEnd`: set `%lastlabel`,
  **`ClearBlocks()`**, `RunScript(labelIndex)`. Timeout → `RunScript()` (fall through past
  `matchwait`). **RT-gated:** the jump waits for round-time even though selection already happened.

---

## 5. action (async triggers)

- **Register** (`EvalAction`, 3068; uses **raw row**): optional `(class)` toggle; sub-commands
  `remove`/`clear`/`add`/`instant`; split on ` when ` → `<commands> when <trigger>`. Trigger is
  variable-expanded unless it starts `eval `. `e/`/`eval ` prefix → `IsEvalAction`. Precompile
  regex for non-eval. Keyed by trigger (replaces existing). Class active-state via `ClassList`.
- **Fire on text** (`TriggerParse`, 1315): iterate `m_oActions` (**sorted by trigger key**), for
  each active non-eval action `oRegExp.Match(text)`; success → groups 1..N + `ParseAction`.
  Async (any state), skipped when paused/done.
- **Fire on var change** (`TriggerVariableChanged`, 1394): eval-actions whose key references the
  changed var; evaluate `EvalString`; nonempty and ≠"0" → `ParseAction`. `AddLocalVariable`
  fires this after every local set. Also resumes `waiteval`.
- **Execute** (`ParseAction`, 2155): split action on `Config.cSeparatorChar` via `SafeSplit`.
  Rows starting `%`→`setvariable`, `$`→`put #var`. `$`-subst from capture args (`$0`=trigger
  text). **Forbidden in actions:** `gosub`, `{`, `}`, `return` (each → error+abort). Inline
  `if…then…`. Run `RunScriptRow(oLine, -1)`; if it returned a goto (`>-1`): set
  `m_bStopRunning`, state=`actioninstant`(if instant) else `actionwait`, **`Clear()`** call
  stack, `MatchList.Clear()`, `LineValue=target`, return — hijacks interpreter to the target.
- **Gating:** `SetClass` flips `IsActive` per class; instant actions bypass the RT gate.

---

## 6. Verb table (`GetFunctionType` 4037 → `ScriptFunctions` 555 → `RunScriptRow` 2472)

| Keyword(s) | Effect |
|---|---|
| `action` | register/toggle async trigger (raw row) |
| `include` | parse-time file include (no runtime) |
| `echo` | print in scriptecho color |
| `put` | `SendText(text)` (direct; RT/queue in client), set `%lastcommand` |
| `send` | `SendText(text, queue=true)` |
| `do` | snapshot MatchList; parse `{cmd}{regex}`; repeat-on-match; `SendText(queue,docommand)` |
| `exit` | terminate |
| `goto` / `gosub` / `return` | see §1 |
| `save` | set `%s` |
| `var`/`vars`/`variable`/`setvar`/`setvariable` | set local var |
| `unvar`/`unvariable`/`unsetvar`/`unsetvariable` | delete local var |
| `counter` | `DoMath("c", arg)` |
| `shift` | shift numbered args, dec `%argcount`, rebuild `%0` |
| `pause` | state=pausing until now+ms (default 1000) |
| `delay` | state=delayed (RT-exempt) until now+ms |
| `waitfor` / `waitforre` | wait for game line contains/regex |
| `waiteval` | state=waiteval, resume when expr true (raw row) |
| `match`/`matchre`/`matchwait`/`wait` | §4; `wait`=resume on next prompt |
| `move` / `nextroom` | send (or not) + resume on room move |
| `if`/`while`/`else`/`elseif` | §2 (`elseif` parse-time desugar) |
| `timer` | start/stop/setstart/clear `%t` (raw row) |
| `random` | set `%r` = rand(min,max) |
| `math` | `DoMath(var, "op number")` (Utility.MathCalc) |
| `eval`/`evaluate` | var = `Eval.EvalString(expr)`; groups→ArgList |
| `evalmath`/`evaluatemath` | var = `MathEval.Evaluate(expr)`; error→0 |
| `debug`/`debuglevel` | set DebugLevel (raw row) |
| `js`/`javascript`/`jscall` | run Jint JS (raw row); `jscall` assigns result |
| `plugin`/`pluginscript` | plugin invoke / parse-time expand |
| `{`/`begin`, `}`/`end`, `label:` | block push/pop, label marker |

See expressions-spec.md for `Eval`, `MathEval`, and `Utility.MathCalc` (math/counter) details.

---

## 7. Round-time & pacing

- `SetRoundTime(iTime)` (1015): `m_oRoundTimeEnd = now + iTime*1000 + dRTOffset*1000` (seconds;
  offset may be negative). Called when the server reports RT.
- **RT gate** (`TickScript`, 1541): if state ∉ {delayed, actioninstant} and `now < RoundTimeEnd`,
  do nothing this tick. So all resumes (pause/wait/waitfor/matchwait-jump/actionwait) stall until
  RT clears. This is how `put`/`send`/`do` pacing works.
- `SendText(text, queue, docommand)` (4385) → `EventSendText`. `put`→queue=false, `send`→true,
  `do`→queue=true+docommand. `#`-prefixed sends bypass loop tracking (client directives).

---

## 8. Loop safety (`SendText`, 4385; constants 694)

On each non-`#` non-empty send: purge history older than **10s** (`LOOP_WINDOW_SECONDS`); enqueue
`(text, now)`; count case-insensitive duplicates. **Loop if** duplicates ≥ **10**
(`LOOP_SAME_CMD_LIMIT`) **OR** total in window ≥ **30** (`LOOP_TOTAL_CMD_LIMIT`) → print error +
trace, finish script, **do not send**. Distinct from the per-`RunScript` wall-clock timeout
(`Config.iScriptTimeout`) and gosub-depth guard (`Config.iMaxGoSubDepth`).

---

## 9. Helpers to port (Utility.cs)

`GetKeywordString` (902, first word), `GetArgumentString` (916, after first space), `ParseArgs`
(390, tokenize honoring `"…"`/`{…}`/`\`), `SafeSplit` (727, split ignoring quotes/braces/escapes),
`EvalDoubleTime` (652, `StringToDouble*1000` or default ms), `MathCalc` (828, math/counter),
`Count` (930), `ValidateRegExp` (113). **Read `RegexOptions.cs`** and replicate the base regex
flags in every Ruby `Regexp.new`.

## 10. State machine driver (`TickScript`, 1523) — resume conditions

After paused/done early-return and the RT gate, dispatch on state: `scripterror`→run scripterror
label; `pausing`/`delayed`→run at deadline; `wait`→on prompt after deadline; `waitfor`→on
buffer-end + resume flag; `waitdo`→on buffer-end; `waiteval`→on event flag; `move`→on move flag;
`matchwait`→§4.4; `actionwait`/`actioninstant`→clear stop-flag + run. `RunScript()` resumes at the
active frame's `LineValue`.
