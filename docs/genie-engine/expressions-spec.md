# Genie Expression Evaluators — Ruby Port Spec

Ground-truth extraction from `Genie4/Script/Eval.cs`, `Genie4/Script/MathEval.cs`, and
`Genie4/Utility/Utility.cs`. This is the authoritative behavior spec for the Ruby port.

> **Important correction:** three distinct evaluators exist, not two.
> - **`Eval`** (`Eval.cs`) — boolean/string. Used by `if`/`elseif`/`while` and `eval`/`waiteval`.
> - **`MathEval`** (`MathEval.cs`) — recursive-descent arithmetic. Used **only** by `evalmath`.
> - **`Utility.MathCalc`** (`Utility.cs:828`) — keyword-based. Used by **`math`** and **`counter`**.

---

## PART A — `Eval` (boolean/string)

**Pipeline** (`EvalString`:45 / `DoEval`:851): `ReplaceKeyWords` → `Parse` (builds `oSections`) →
`ParseQueue` → `GetStringResult` (for `eval`) or `GetBooleanResult` (for `if`/`while`).
`m_RegExpResultList` cleared at entry; populated by the `matchre` function for `$0..$n`.

### Tokenizer (`Parse`:144, `SectionEnqueue`:282)
`SEPARATORS = "!=<>,&|"`. Single-pass scanner → `Section{ sBlock, BlockType, bParsed }`.
`ParseType`: `Separator, Number, String, SectionStart, SectionEnd, Function, Negate`.
- Only `"` starts a string (single-quote disabled). Quoted content strips surrounding quotes if len>1.
- Consecutive separator chars coalesce → `==`, `!=`, `<=`, `>=`, `<>`, `&&`, `||` are single tokens.
- Numeric char = digit OR `.` OR leading `-` (when `bIgnoreNumber==false`) → `NumberType`.
- `(` → SectionStart, `)` → SectionEnd.
- Space/tab: splits token unless inside a `FunctionType` token (then sets `bIgnoreNumber` so barewords
  may contain spaces/digits, e.g. `dead man`).
- Anything else → `FunctionType`, `bIgnoreNumber=true`.

`SectionEnqueue` post-processing (trim; drop empty):
- If `FunctionType`, lowercase switch: `eq→=`, `and→&&`, `or→||`, `not→!`(Negate), `true→1`, `false→0`.
  **Default:** if `|token|` NOT in the function list → reclassify as `StringType` (bareword → literal).
- `SeparatorType` token `!` → `NegateType`.

**Function list** (barewords in it stay callable): `instr, instring, contains, indexof, lastindexof,
match, startswith, endswith, replace, tolower, toupper, trim, len, length, substr, substring,
matchre, replacere, count, element, def, defined`.

### Keyword aliasing (`ReplaceKeyWords`:54, regex:83)
Applied only OUTSIDE double-quoted strings. Canonical list is exactly six:
`eq→=`, `and→&&`, `or→||`, `not→!`, `true→1`, `false→0`. **No `ne/ge/le/gt/lt` keywords.**
Faithful-port note: due to a `RegexOptions` AND-bug the keyword pass is effectively lowercase-only,
but mixed-case forms are still caught by the tokenizer's `.ToLower()` function branch when the token
is whitespace/paren-delimited. Reproduce: lowercase whole-word replace of the six outside quotes,
plus case-insensitive alias handling in the function branch.

### Precedence & comparisons (`ParseSection`:473)
Three ordered passes per parenthesized section → **comparisons > NOT > AND/OR**, each left-associative;
AND and OR are equal precedence (single pass, left-to-right).

`ParseCompare`:621 — **numeric iff BOTH operands are `NumberType`**; else string. Numeric parse via
`StringToDouble` (returns **-1** on failure, en-US).

| Op | Numeric | String |
|---|---|---|
| `=` `==` | `d1==d2` | `String.Equals` (ordinal, **case-sensitive**) |
| `!=` `<>` | `d1!=d2` | negated equals |
| `>` `>=` `<` `<=` | usual | **always 0 (false)** for strings |
| `\|\|` | `(d1>0)\|\|(d2>0)` | 0 if either operand non-numeric |
| `&&` | `(d1>0)&&(d2>0)` | 0 if either operand non-numeric |

Only strictly-positive numbers are truthy in `&&`/`||`. `ParseCompare` swallows errors → leaves unparsed.

### Functions (`ParseFunction`:869) — ordinal/case-sensitive
| Function | Arity | Semantics | Type |
|---|---|---|---|
| `instr`/`instring`/`contains` | 2 | `a.Contains(b)` | Num |
| `indexof` | 2 | `a.IndexOf(b)+1` (0 if none) | Num |
| `lastindexof` | 2 | `a.LastIndexOf(b)+1` | Num |
| `match` | 2 | `String.Equals(a,b)` | Num |
| `startswith`/`endswith` | 2 | prefix/suffix test | Num |
| `replace` | 3 | literal replace-all | Str |
| `tolower`/`toupper`/`trim` | 1 | as named | Str |
| `len`/`length` | 1 | `a.Length` | Num |
| `substr`/`substring` | 2\|3 | see below | Str |
| `matchre` | 2 | `Regex.Match(a,b)`; fills `$0..$n` on success | Num |
| `replacere` | 3 | `Regex.Replace(a,b,c)` | Str |
| `count` | 2 | non-overlapping occurrences (step by match len) | Num |
| `element` | 2 | strip `()`, split on `\|`, 0-based index w/ clamp | Str |
| `def`/`defined` | 1 | global var exists | Num |

`substr(s,start,length)`: if `length<0`: if `start+length>=0` then `start+=length; length=|length|`
else `start=0; length=orig_start`. Clamp `start<0→0`, `length<0→0`. If `start+length>s.Length`
→ substring to end, else fixed length. `substr(s,start)`: substring-to-end if `0<=start<=len`
else no-op. Integer coercion = VB `ToInteger` = **banker's rounding**.

### Truthiness (`IsSectionTrue`:1256, `GetBooleanResult`:416)
`"0"`→false, `"1"`→true, else `NumberType` && `int>0`→true, else (**any string**)→false.
Bare non-empty string in `if` is **false**. Empty/unparseable expr → `false`. `GetStringResult`
returns first unparsed Number/String section's text; empty expr → `""`.

### Edge cases
Unbalanced parens tolerated (no throw). No variable lookup inside `Eval` — substitution happens before.
Quoted `"5"` is a String, so `"5" = 5` is a string compare (false).

---

## PART B — `MathEval` (arithmetic, `evalmath` only)

`Evaluate`:141 — if whole string `IsNumeric`, return directly; else `calc_scan` → `level0`.
Errors → `InvalidCastException("Invalid expression: …")`; `evalmath` then sets target var to `"0"`.
All arithmetic is IEEE `double`; culture forced en-US by callers.

### Operators (`init_operators`:69) — `+`/`-` registered twice (binary L1 + unary L4)
| Token | Level | Role |
|---|---|---|
| `+` `-` | L1 | binary add/sub |
| `*` `/` `\` `%` | L2 | mul / float-div / **int-div** / mod |
| `^` | L3 | power (**left-assoc!** `2^3^2==64`) |
| `+` `-` | L4 | unary (≤1 prefix sign) |
| `!` | L5 | factorial (postfix, applied once) |
| `&` | L5 | registered but no-op → 0 |

Precedence low→high: `+ -` < `* / \ %` < `^` < unary `+ -` < `!` < atoms/parens/functions.

### Grammar
```
level1 := level2 ( ("+"|"-")@L1 level2 )*
level2 := level3 ( ("*"|"/"|"\"|"%")@L2 level3 )*
level3 := level4 ( "^"@L3 level4 )*          # left-assoc
level4 := ("+"|"-")@L4 ? level5              # unary, ≤1
level5 := level6 "!"?                        # factorial, once
level6 := "(" level1 ")" | IDENT | FUNC "(" args ")" | NUMBER
```

### `calc_op` operand order (`:157`)
`^`=`Pow(op1,op2)`; `+`(L1)=`op2+op1`; `-`(L1)=`op1-op2`; `*`=`op2*op1`; `/`=`op1/op2` (div0→Inf/NaN);
`\`=`ToLong(op1)/ToLong(op2)` integer division (banker's round to Int64); `%`=`op1%op2`;
unary `-`=`-op1`, unary `+`=`op1`; `!`=factorial (`0!=1`, negatives→1, arg truncated via ToInteger).

### Functions (`calc_function`:242, `m_funcs`:63)
`sin cos tan arcsin arccos arctan` (radians), `sqrt floor ceiling abs neg pos`,
`log`=**log10** (not natural!), `log10`, `ln`=natural log, `round(x[,n])` banker's rounding,
`max/min` (fold over args). Constants: `e`→Math.E, `pi`→Math.PI (case-insensitive); other ident → 0.

`calc_scan`:418 is a table-driven DFA; `_`∈identifiers, `#`∈digits. Faithful port can use a normal
tokenizer producing the same token classes (identifier/number/operator/paren/punct).

---

## PART C — `math` / `counter` (`Utility.MathCalc`:828) — NOT MathEval

`math <var> <expr>` → `DoMath(var, expr)`; `counter <expr>` → `DoMath("c", expr)` (fixed var `c`).
`DoMath` reads current value via `StringToDouble` (missing → 0), applies `MathCalc`, stores
`double.ToString()` back, fires `TriggerVariableChanged`. `math` bar-command variant uses **globals**;
script `math`/`counter` use **local** vars — same `MathCalc`.

`MathCalc(value, expr)`: `keyword`=first word, `n=StringToDouble(rest)` **clamped `n<0→0`**, then:

| Keyword | Op |
|---|---|
| `add` / `+` | `value+n` |
| `sub`/`substract`/`subtract` / `-` | `value-n` |
| `set` / `=` | `n` |
| `multiply` / `*` | `value*n` |
| `divide` / `/` | `value/n` |
| `mod`/`modulus` / `%` | `value%n` if value≠0 else 0 |
| else | throw `"Invalid #MATH expression"` → echo error, result 0 |

**Quirk to preserve:** the `n<0→0` clamp means `math x subtract -5` subtracts 0, not -5.

---

## Cross-cutting formatting/rounding (must reproduce)
- `StringToDouble`: en-US, returns **-1.0** on empty/nil/parse-failure.
- VB `ToInteger`/`ToLong`: **banker's rounding** (half-to-even) — affects `substr`, `round(x,n)`,
  factorial, `\` integer division.
- Result stringification = .NET `double.ToString()` "G" (en-US): integers print without `.0`;
  reproduce shortest round-trip formatting.
