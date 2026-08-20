# Running Genie Scripts in Lich — User Guide

This guide shows you, step by step, how to run **Genie-style `.cmd` scripts** directly in Lich.
No prior experience required. Every section has examples you can copy and try.

> ⚠️ **This is a testing preview — you are a tester.** This feature is **not yet part of official
> Lich.** It lives on a development branch and needs testers before it can be submitted and merged.
> You'll install it from that branch (below), try it out, and report anything that looks wrong.
> Expect occasional updates while it's being polished. It is safe: it's off until you turn it on, and
> it only affects `.cmd` files.
>
> - **Fork:** `MahtraDR/lich-5`
> - **Branch:** `feature/genie-scripting-engine`

> **The short version:** With this build, Lich can *run your Genie `.cmd` scripts as-is*. You install
> the testing branch, turn the feature on once per character, and your `.cmd` files start working.
> Nothing changes until you turn it on, and you can turn it back off at any time.

---

## Table of contents

1. [What this is (and what it is not)](#1-what-this-is-and-what-it-is-not)
2. [Before you start: five things that will put you at ease](#2-before-you-start-five-things-that-will-put-you-at-ease)
   - [Prerequisite — install the testing build (from the fork)](#prerequisite--install-the-testing-build-from-the-fork)
3. [Step 1 — Turn the engine on](#3-step-1--turn-the-engine-on)
4. [Step 2 — Write and run your first script](#4-step-2--write-and-run-your-first-script)
5. [Step 3 — Turn it back off (so you know you can)](#5-step-3--turn-it-back-off-so-you-know-you-can)
6. [The building blocks of a script](#6-the-building-blocks-of-a-script)
7. [Variables](#7-variables)
8. [Making decisions: `if` / `else`](#8-making-decisions-if--else)
9. [Loops: labels, `goto`, and `gosub`](#9-loops-labels-goto-and-gosub)
10. [Reacting to the game: `match`, `waitfor`, and `action`](#10-reacting-to-the-game-match-waitfor-and-action)
11. [Front-end effects: highlights, gags, substitutions, and more](#11-front-end-effects-highlights-gags-substitutions-and-more)
12. [Splitting a script into multiple files: `include`](#12-splitting-a-script-into-multiple-files-include)
13. [Reserved variables reference](#13-reserved-variables-reference)
14. [Running, listing, and stopping scripts](#14-running-listing-and-stopping-scripts)
15. [Troubleshooting](#15-troubleshooting)
16. [Frequently asked questions](#16-frequently-asked-questions)
17. [Quick reference card](#17-quick-reference-card)

---

## 1. What this is (and what it is not)

Genie is a game client with its own scripting language. Its scripts end in **`.cmd`**. This feature
teaches Lich to **run those `.cmd` scripts natively** — the same automation you had in Genie, now
running inside Lich.

**What it does:**

- Runs your `.cmd` automation: sending commands, waiting for text, loops, math, variables,
  triggers, and more.
- Remembers your saved variables between sessions.
- Applies **gags** (hide lines) and **substitutions** (rewrite lines) to what you see.
- Announces front-end effects (highlights, macros, colored classes, windows, sounds) in a
  universal format so any capable front-end can display them.

**What it is not:**

- It is **not** a replacement for your existing Lich `.lic` scripts. Those keep working exactly as
  before.
- It does **not** change anything until *you* turn it on, per character.

---

## 2. Before you start: five things that will put you at ease

1. **It is OFF by default.** If you do nothing, nothing changes.
2. **It is per-character.** Turning it on for one character does **not** affect any other character.
3. **It is remembered.** Turn it on once; it stays on for that character across relogs. Turn it off
   once; it stays off.
4. **It is reversible.** One command turns it off and you are back to exactly how things were.
5. **Your `.lic` scripts are untouched.** This only affects `.cmd` files.

> **One thing to know:** while the engine is **on**, `.wiz` (old Wizard) scripts are turned off for
> that character, because `.cmd` and `.wiz` cannot both be interpreted at once. If you rely on
> `.wiz` scripts, leave the engine off (or turn it off before running them).

---

## Prerequisite — install the testing build (from the fork)

Because this feature isn't in official Lich yet, you first update Lich to the testing branch. This
is the same one-line update you may already use, pointed at the branch:

```
;lich5-update --branch=MahtraDR:feature/genie-scripting-engine
```

Then **fully close and restart Lich** (log out and back in). That's it — you're now running the
testing build.

> **Read this — it matters:**
> - You must **re-run that update command whenever there's a new version to test**, then restart.
>   Simply relogging does **not** pull new changes.
> - This replaces your Lich files with the testing branch's copy. Your characters, settings, and
>   saved variables are not touched, but any local edits you made to Lich's own files will be
>   overwritten by the update.
> - To go back to official Lich later, run your normal update command (without the `--branch=...`
>   part) and restart.

Once you've updated and restarted, continue to Step 1.

---

## 3. Step 1 — Turn the engine on

Log in with the character you want to use. Then type this in your game window:

```
;e Lich::Genie.enabled = true
```

That's it. You should see no error. To confirm it worked, type:

```
;eq echo Lich::Genie.enabled?
```

You should see:

```
true
```

**You only ever have to do this once per character.** It is remembered across relogs.

To turn it on for another character, log in as that character and run the same command there.

> **Tip:** If you want to double-check what's stored for your characters, run:
> ```
> ;eq echo Lich.db.execute("SELECT * FROM lich_settings WHERE name LIKE 'genie_enabled:%';")
> ```
> You'll see one row per character you've enabled, like `["genie_enabled:DR:Yourname", "true"]`.

---

## 4. Step 2 — Write and run your first script

Let's make the simplest possible script.

1. In your Lich **`scripts`** folder, create a new text file named **`mytest.cmd`**.
2. Put exactly this inside it:

   ```
   echo Hello from my first Genie script!
   ```

3. Save the file.
4. In the game, run it by typing its name **without** the `.cmd`:

   ```
   ;mytest
   ```

You should see `Hello from my first Genie script!` printed in your window.

`echo` prints to **you** only — it does not send anything to the game.

Now let's actually do something in the game. Change `mytest.cmd` to:

```
echo I am going to look around now.
put look
```

Run `;mytest` again. This time the script prints a message to you, then sends the **`look`** command
to the game, exactly as if you had typed `look` yourself.

- `echo` → shows text to you.
- `put` (or `send`) → sends a command to the game.

Congratulations — you're scripting. 🎉

---

## 5. Step 3 — Turn it back off (so you know you can)

Any time you want to go back to how things were:

```
;e Lich::Genie.enabled = false
```

Confirm with:

```
;eq echo Lich::Genie.enabled?
```

which now shows `false`. Your `.cmd` files will no longer run through the Genie engine, and `.wiz`
scripts work normally again. Turn it back on whenever you like.

---

## 6. The building blocks of a script

A script is just a list of lines, read top to bottom.

### Comments and blank lines

- A line that **starts with `#`** is a comment and is ignored.
- Blank lines are ignored.

```
# This is a comment. The engine skips it.

echo This line runs.
```

### Sending commands vs. showing text

```
put stand           # sends "stand" to the game
send get my pack    # "send" does the same thing as "put"
echo done standing  # shows text to you only
```

### Waiting

Sometimes you need to slow down. Use `pause` (seconds):

```
put stand
pause 1
put open my pack
pause 0.5
put get coin from my pack
```

`pause` with no number waits 1 second. `pause 3` waits 3 seconds.

---

## 7. Variables

Variables let a script remember things. There are three kinds, told apart by their first symbol.

| Symbol | Name | Lives where | Example |
|---|---|---|---|
| `%` | **Local** | Only inside the running script | `%count` |
| `$` | **Global** | Shared and **saved to disk**, across scripts and characters | `$mymode` |
| `$` | **Reserved** | Provided by the game (read-only) | `$health` |

Reserved variables also start with `$`; you just don't create them — the game fills them in
(see [section 13](#13-reserved-variables-reference)).

### Local variables (`%`)

Set one, then use it by writing `%name` anywhere:

```
%target = kobold
echo My target is %target
put attack %target
```

You can also write it the long way with `setvariable` (same effect):

```
setvariable target kobold
```

### Global variables (`$`) — saved between sessions

Set a global with `$name = value`. Globals are **saved to a file automatically** and are still there
next time you log in — even on other characters.

```
$mymode = hunting
echo Mode is now $mymode
```

Later, in any script (or after relogging), `$mymode` still equals `hunting` until you change it.

> **Where are globals saved?** In a file named `variables.cfg` inside a `GenieProfiles/Config`
> folder next to your scripts. You don't need to touch it — the engine manages it — but you can open
> it to see your saved values.

### Doing math

Use `math` for simple arithmetic on a variable:

```
%count = 0
math count add 1      # %count is now 1
math count add 5      # %count is now 6
math count subtract 2 # %count is now 4
math count multiply 3 # %count is now 12
```

There's a handy shortcut called `counter` that works on a variable named `%c`:

```
counter add 1   # adds 1 to %c
echo I have looped %c times
```

For a full expression, use `evalmath`:

```
evalmath total (2 + 3 * 4)   # %total becomes 14
echo total is %total
```

### Comparing and testing

`eval` stores the result of a comparison (`1` for true, `0` for false):

```
%hp = 55
eval healthy %hp > 50
echo healthy = %healthy      # prints "healthy = 1"
```

---

## 8. Making decisions: `if` / `else`

### One-line form

```
if %hp < 30 then put drink my potion
```

### Block form (multiple lines)

Use braces `{ }` to run several lines when the test is true:

```
if %hp < 30 then
{
  echo Health is low!
  put drink my healing potion
  pause 2
}
```

### `if` / `else`

```
if $health > 50 then
{
  put advance
}
else
{
  put retreat
}
```

### `elseif` for several choices

```
if %stance = offense then put attack
elseif %stance = defense then put parry
else echo I do not know that stance.
```

### Comparisons you can use

- `=` equal, `!=` not equal
- `>` greater, `<` less, `>=` at least, `<=` at most

> **Good to know:** numbers compare as numbers (`10 > 9` is true). If either side isn't a plain
> number, they compare as **text**. So `"$roomname" = "Town Square"` compares the room name as text —
> wrap text values in quotes when you compare them.

---

## 9. Loops: labels, `goto`, and `gosub`

### The one surprising rule

In Genie, **`while` does not loop.** It behaves like a one-time `if`. To actually repeat something,
you use a **label** and **`goto`**. This trips up newcomers, so here it is up front.

### A label is a landmark

A label is a word followed by a colon on its own line:

```
top:
```

### `goto` jumps to a label

Here is a counter that loops five times:

```
%c = 0
loopstart:
counter add 1
echo pass number %c
if %c < 5 then goto loopstart
echo done
exit
```

- `goto loopstart` jumps back up to the `loopstart:` label.
- `exit` ends the script (optional at the very end, but tidy).

> **Safety net:** the engine watches for runaway loops. If a loop sends the *same* command 10 times
> in 10 seconds, or 30 commands total in 10 seconds, or spins for more than 5 seconds without
> pausing, it stops the script and prints **"Possible infinite loop."** This protects you from a
> stuck script. If you see that message, add a `pause` or a proper stopping condition to your loop.

### `gosub` runs a mini-routine and comes back

`gosub` jumps to a label, runs until `return`, then continues where it left off. Great for reusable
steps. You can pass arguments, read inside as `$1`, `$2`, …

```
gosub greet Traveler
gosub greet Friend
echo all greeted
exit

greet:
echo Hello, $1!
return
```

Output:

```
Hello, Traveler!
Hello, Friend!
all greeted
```

---

## 10. Reacting to the game: `match`, `waitfor`, and `action`

Real scripts wait for the game to say something, then react.

### `waitfor` — pause until a line appears

```
put stand
waitfor You are now standing
put forward
```

The script waits until a line containing "You are now standing" arrives, then continues. For a
regular-expression version, use `waitforre`.

### `match` + `matchwait` — branch on what happens

Set up several possible outcomes with `match` (each names a label), then `matchwait` pauses until one
of them is seen and jumps to that label:

```
top:
match killed falls to the ground
match missed You miss
matchwait

killed:
echo Target down!
exit

missed:
echo Missed, trying again.
put attack
goto top
```

- `match killed falls to the ground` → if a line contains "falls to the ground", jump to `killed:`.
- `matchwait` → wait for one of the matches (optionally with a timeout: `matchwait 15`).
- Use `matchre` instead of `match` for regular-expression patterns.

Here's a small, generic hunting loop that attacks until the creature dies:

```
huntloop:
match dead falls to the ground
match again a creature
matchwait 20

again:
put attack creature
goto huntloop

dead:
echo The creature is dead.
put search
exit
```

### `action` — a background trigger

An `action` watches **every** incoming line while your script runs and reacts automatically, no
matter what else the script is doing. The form is:

```
action <commands> when <pattern>
```

Example — automatically stand up if you ever get knocked down:

```
action put stand when you are knocked to the ground

# ... the rest of your script does its normal thing ...
top:
put attack creature
matchwait 20
goto top
```

Anytime a line matching "you are knocked to the ground" appears, the action fires `put stand` on its
own.

You can capture pieces of the matching line with `$1`, `$2`, … and use them:

```
action echo I was hit by $1 when hit by (a|an) (\w+)
```

Managing actions:

```
action clear                         # remove all actions
action remove you are knocked to the ground   # remove one by its pattern
```

---

## 11. Effects and triggers: `#` commands

Genie scripts use **`#` commands** (sent with `put`) for two kinds of things: **automation** that
Lich runs itself, and **display effects** that a front-end shows. They behave differently in Lich.

### Group A — Automation: triggers, gags, substitutions (work everywhere, right now)

These run in Lich itself, so they work on **any** front-end immediately.

**Trigger** — run command(s) automatically whenever a game line matches, for as long as you're
connected (not just while a script runs):

```
put #trigger {^You are no longer stunned} {put stand} {recovery}
```

Format: `#trigger {pattern} {commands} {class}`. The `pattern` is a regular expression; `commands`
is what to run when it matches (use `$1`, `$2`, … for captured groups); `class` (optional) is a
group name you can switch on/off. Multiple commands are separated with `;`:

```
put #trigger {^(\w+) glances at you} {echo $1 is watching;put face $1} {social}
```

Manage them:

```
put #trigger              # list all loaded triggers (also: put #trigger list)
put #untrigger ^You are no longer stunned   # remove one by its pattern
put #trigger clear        # remove them all
```

**Classes turn groups of triggers on and off.** A trigger with a `class` only fires while that class
is on. Classes start **on**; turn them off/on with `#class`:

```
put #class recovery off    # the "recovery" trigger above stops firing
put #class recovery on     # ...and starts again
```

> `put #trigger` prints your loaded triggers to your window, so you can always see what's active —
> handy while testing.

**Gag** — hide any line matching a pattern:

```
put #gag a small bird flies past
```

From now on, lines containing "a small bird flies past" won't be shown to you.

**Substitute** — rewrite matching text:

```
put #sub {a fierce creature} {*** DANGER ***}
```

Now "a fierce creature" is displayed as "*** DANGER ***".

To undo them:

```
put #ungag a small bird flies past
put #unsub a fierce creature
```

> **Important and reassuring:** gags and substitutions only change what is **displayed**. Other
> scripts, your logs, and the game itself still see the original text. Nothing is lost.
>
> Patterns are treated as regular expressions. `put #gag ^You see nothing` hides only lines that
> *start* with "You see nothing".

### Group B — Display effects: highlights, macros, windows, sounds…

These change how the game *looks or sounds*. Lich announces them in a **universal format** that any
front-end can choose to display. Examples:

```
put #highlight line yellow {a treasure chest}
put #macro {ctrl+a} {attack creature}
put #playsound alert.wav
```

**What happens today:** whether the *visual/audio* effect (the yellow highlight, the macro key, the
sound) actually appears depends on whether your front-end has added support for these announcements
yet. If it hasn't, the commands are simply ignored — they will never cause an error, and your script
keeps running normally. As front-ends add support, these light up automatically with no change to
your scripts.

> **A note on `#class`:** classes do double duty. They gate your **triggers** (Group A, working now)
> *and* they can color text via highlights (Group B, front-end-dependent). So `#class x off` always
> stops class-`x` triggers immediately; the coloring part waits on front-end support.

> **You don't need to memorize the `#` commands.** If your existing `.cmd` scripts already use them,
> they'll just work (or be safely ignored). This section is here so you know what they are.

---

## 12. Splitting a script into multiple files: `include`

Large setups are easier to manage in pieces. `include` pulls another `.cmd` file's labels into your
script, so you can `gosub` into them.

**`helper.cmd`** (a library of routines):

```
standup:
put stand
waitfor You are now standing
return

restup:
put rest
waitfor You rest
return
```

**`main.cmd`** (uses the library):

```
include helper.cmd

gosub standup
echo I am standing.
gosub restup
echo I am resting.
exit
```

Run `;main` and it will use the routines from `helper.cmd`. Put included files in your `scripts`
folder (a `scripts/custom` folder is also searched). If you leave off the extension
(`include helper`), the engine will look for `helper.cmd` automatically.

---

## 13. Reserved variables reference

Reserved variables are filled in by the game. You **read** them; you don't set them. Use them like
any `$` variable.

### Vitals

| Variable | Meaning |
|---|---|
| `$health`, `$mana`, `$stamina`, `$spirit`, `$concentration` | Current values |
| `$maxhealth`, `$maxmana`, `$maxstamina`, `$maxspirit`, `$maxconcentration` | Maximums |
| `$encumbrance` | Encumbrance value |

```
if $health < 40 then put drink my potion
echo Mana: $mana / $maxmana
```

### Your room

| Variable | Meaning |
|---|---|
| `$roomname` | The room's title (brackets removed) |
| `$roomdesc` | The room description |
| `$roomexits` | Obvious exits, comma-separated |
| `$roomid` | Current room's Genie room number (`0` if the room isn't mapped yet) |
| `$north`, `$south`, `$east`, `$west`, `$northeast`, `$northwest`, `$southeast`, `$southwest`, `$up`, `$down`, `$out` | `1` if that exit exists, else `0` |
| `$roomplayers` | Other players present (separated by `|`) |
| `$monstercount` | Number of creatures present |
| `$monsterlist` | Creatures present (separated by `|`) |
| `$roomobjs` | Notable objects present (separated by `|`) |

```
if $north = 1 then put go north
echo There are $monstercount creatures here.
```

**Moving by room number.** `put #goto <room>` walks you to a Genie room number using Lich's own
pathfinder (go2), and `$roomid` tells you the room you're in — so the classic Genie pattern works:

```
if $roomid != 8 then put #goto 8
```

Genie room numbers are matched to Lich's map behind the scenes. A room that hasn't been matched yet
reports `$roomid = 0` ("location unknown"), just like Genie's mapper when it's lost.

### Your hands

| Variable | Meaning |
|---|---|
| `$lefthand`, `$righthand` | What's in each hand ("Empty" if nothing) |
| `$lefthandnoun`, `$righthandnoun` | Just the one-word noun of the held item (e.g. `sword`) |

```
if "$righthand" = "Empty" then put get my weapon
put stow $lefthandnoun
```

### Status

Each of these is `1` when true, `0` when false:

`$standing`, `$kneeling`, `$sitting`, `$prone`, `$hidden`, `$invisible`, `$bleeding`, `$dead`,
`$stunned`, `$webbed`, `$joined`, `$poisoned`, `$diseased`

```
if $standing = 0 then put stand
if $bleeding = 1 then put tend my wounds
```

### Spell timers

Check whether a spell is active and how long it has left. Replace `MyBuff` with the spell's name
(spaces don't matter — `MyBuff` matches "My Buff"):

| Variable | Meaning |
|---|---|
| `$SpellTimer.MyBuff.active` | `1` if the spell is active, else `0` |
| `$SpellTimer.MyBuff.duration` | Time remaining |

```
if $SpellTimer.MyBuff.active = 0 then put cast mybuff
echo MyBuff has $SpellTimer.MyBuff.duration left.
```

### Skills & experience (the EXPTracker equivalent)

Per-skill training data, sourced from Lich (no plugin needed). Use the skill name with spaces
written as underscores (e.g. `Small_Edged`, `Targeted_Magic`):

| Variable | Meaning |
|---|---|
| `$<Skill>.LearningRate` | Mindstate / learning rate (0–34; 34 = mind-locked) |
| `$<Skill>.Ranks` (or `.Rank`) | Skill ranks |
| `$<Skill>.Percent` | Percent toward the next rank |

```
if $Perception.LearningRate < 30 then put forage for herbs
if $Scouting.Ranks > 15 then put scout aware
```

### Time

`$unixtime` (seconds since 1970) is handy for "do this again in N seconds" timers:

```
$nextcast = #evalmath ($unixtime + 60)
# ...later...
if $unixtime > $nextcast then put cast myspell
```

Also available: `$time`, `$date`, `$year`, `$month`, and related time values.

### Other

| Variable | Meaning |
|---|---|
| `$preparedspell` | The spell you currently have prepared |
| `$roundtime` | Seconds of round time remaining |
| `$casttime`, `$casttimeremaining` | Seconds of cast round time remaining |
| `$prompt` | Your current game prompt |
| `$name` (or `$charactername`) | Your character's name |
| `$game` (or `$gamename`) | The game you're playing (e.g. `DR`) |
| `$level` | Your character level |
| `$roomtitle`, `$roomdesc`, `$gameroomid`, `$inside` | Raw room title, description, room id, and `1`/`0` for indoors |

> If you know a Genie reserved variable that isn't listed here, try it — many of the standard ones
> are supported. If one you rely on is missing or returns nothing, please report it (it's easy to
> add), and note the exact variable name.

---

## 14. Running, listing, and stopping scripts

- **Run a script:** `;name` (leave off `.cmd`). Example: `;mytest`.
- **Pass information to a script:** type it after the name. `;mytest kobold 3` makes `$1` be
  `kobold` and `$2` be `3` inside the script.
- **See what's running:** `;list`
- **Stop one script:** `;kill name` (or `;k name`)
- **Stop everything:** `;killall`
- **Pause / unpause a script:** `;pause name` / `;unpause name`

### Launching one script from another

Inside a script, a command that begins with a period (`.`) **launches another script** instead of
being sent to the game — exactly like Genie's `.scriptname`:

```
put .setup            # runs setup.cmd
put .buffs full       # runs buffs.cmd with $1 = "full"
send .helper          # send works too
```

The first word after the `.` is the script name; anything after it becomes that script's `$1`, `$2`,
… arguments. A `.cmd` target runs through the Genie engine; a `.lic` target runs as a normal Lich
script. The launched script runs alongside yours (it doesn't pause the caller).

> Ordinary commands are unaffected — `put attack kobold` still goes to the game. Only a leading `.`
> means "launch a script."

Example script that uses arguments:

```
# Run with:  ;mytest kobold 3
echo I will attack $1, and repeat $2 times.
%c = 0
loop:
counter add 1
put attack $1
matchwait 15
if %c < $2 then goto loop
exit
```

---

## 15. Troubleshooting

**"My `.cmd` script gives errors about syntax / `eval` / `matchre`."**
The engine is probably **off** for this character, so Lich is trying to read your `.cmd` as an old
Wizard script. Turn the engine on:

```
;e Lich::Genie.enabled = true
```

Confirm with `;eq echo Lich::Genie.enabled?` (should be `true`), then run your script again.

**"I turned it on, but after relogging it's off again."**
First make sure you're on a current testing build — re-run the update and restart Lich:

```
;lich5-update --branch=MahtraDR:feature/genie-scripting-engine
```

The setting is saved per character; verify what's stored:

```
;eq echo Lich.db.execute("SELECT * FROM lich_settings WHERE name LIKE 'genie_enabled:%';")
```

You should see a row for your character with the value `true`. If it says `true` but the engine
still acts off after a fresh login, please report it (see below) — that's exactly the kind of thing
testers help catch.

**"I see 'Possible infinite loop' and my script stopped."**
A loop ran too fast or forever. Add a `pause` inside the loop, or a proper stopping condition (a
`match`/`matchwait`, or an `if ... then goto done`). See [section 9](#9-loops-labels-goto-and-gosub).

**"A highlight/macro/sound in my script does nothing."**
Those are front-end effects (Group B in [section 11](#11-front-end-effects-highlights-gags-substitutions-and-more)).
The automation still runs; the visual/audio part appears only if your front-end supports it yet.
Gags and substitutions (Group A) work everywhere right now.

**"My `.wiz` scripts stopped working."**
That's expected while the engine is on. Turn it off (`;e Lich::Genie.enabled = false`) to use `.wiz`
again, or convert them.

**"A variable prints literally, like `%count` or `$mymode`, instead of a value."**
That variable was never set (undefined variables are left as-is). Set it first, and check spelling —
`%local` and `$global` are different variables even with the same name.

---

## Reporting problems (you're a tester)

This is a preview, and your feedback is what gets it merged into official Lich. If something doesn't
work or looks wrong, note it down and send it to the branch maintainer (fork `MahtraDR/lich-5`,
branch `feature/genie-scripting-engine`). Helpful details:

- What you did (the exact command or the script you ran — feel free to trim/rename it).
- What you expected vs. what happened.
- Any error text you saw in your window.
- Your character's game and name (so per-character behavior can be checked).

Small, specific reports ("`;foo` printed X but I expected Y") are the most useful.

---

## 16. Frequently asked questions

**Do I have to convert my Genie `.cmd` scripts?**
No. Put them in your `scripts` folder and run them.

**Will this change my other characters?**
No. It's per character. Enable it only where you want it.

**Will it touch my `.lic` scripts?**
No. Only `.cmd` files are affected, and only when the engine is on.

**Is it safe to turn on and off repeatedly?**
Yes. It's a simple toggle with no side effects.

**Where are my saved (`$`) variables kept?**
In `GenieProfiles/Config/variables.cfg` near your scripts. They're shared across your characters,
matching how Genie saved them.

**Can I run more than one `.cmd` at once?**
Yes, just like other Lich scripts. They share your saved global variables.

**Is anything not supported yet?**
A few advanced Genie features are still in progress — notably in-script JavaScript blocks
(`<% ... %>` / `#js`) and plugins. Ordinary automation, variables, math, triggers, gags,
substitutions, launching other scripts (`.name`), and room navigation (`#goto` / `$roomid`, where
the map has been matched) all work today. Front-end visual effects work as your front-end adds
support for them.

---

## 17. Quick reference card

**Turn on/off (per character):**

```
;e Lich::Genie.enabled = true
;e Lich::Genie.enabled = false
;eq echo Lich::Genie.enabled?
```

**Output & sending:**

```
echo text-to-me
put command-to-game
send command-to-game
pause 2
```

**Variables:**

```
%local = value
$global = value          # saved to disk
setvariable name value   # same as %name = value
math name add 5
counter add 1            # works on %c
evalmath name (2 + 3)
eval name %x > 3         # 1 or 0
```

**Decisions:**

```
if COND then command
if COND then { ... }
else { ... }
elseif COND then command
```

**Loops & routines:**

```
label:
goto label
gosub label args   ...   return
exit
```

**Reacting:**

```
waitfor text
waitforre pattern
match labelname text
matchre labelname pattern
matchwait 15
action commands when pattern
action remove pattern
action clear
```

**Launch another script (leading `.`):**

```
put .scriptname args    # runs scriptname.cmd with $1.. = args
```

**Triggers & filters (run in Lich, work now):**

```
put #trigger {pattern} {commands} {class}
put #trigger              # list loaded triggers
put #untrigger pattern
put #trigger clear
put #class name on|off    # gate a group of triggers
put #gag pattern
put #ungag pattern
put #sub {pattern} {replacement}
put #unsub pattern
```

**Display effects (front-end dependent):**

```
put #highlight line color {text}
put #macro {key} {command}
put #playsound file
```

**Files:**

```
include helper.cmd
```

**Common reserved variables:**

```
$health $mana $stamina $spirit $concentration
$roomname $roomexits $north $south $east $west
$lefthand $righthand
$standing $bleeding $stunned $hidden
$SpellTimer.MyBuff.active  $SpellTimer.MyBuff.duration
$unixtime  $preparedspell  $roundtime
```

---

*Happy scripting. Start small — a one-line `echo` script — and build up from there. Everything in
this guide is something you can copy, paste, and run today.*
