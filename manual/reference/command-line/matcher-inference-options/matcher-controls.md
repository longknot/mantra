# Matcher Controls

Matcher controls change how the structural pattern matcher behaves during rule
matching and rewriting. The two CLI flags — `--backtracking` and `--no-guards` —
affect which matches succeed, how aggressively the matcher explores alternatives,
and whether guard conditions are enforced.

Both flags set global variables applied at startup. They affect all matcher
operations for the entire session and cannot be toggled mid-execution.

For related matcher configuration, see:

- [Dispatch Flags](dispatch-flags.md) — implicit rule dispatch via `{ head ... }` syntax
- [Inference Budget Flags](inference-budget-flags.md) — beam width and congruence budget for `|=` proof search
- [Event Log Flag](event-log-flag.md) — diagnostic and trace event emission

## `--backtracking`

Enable matcher backtracking for infix `--` (match-any) patterns.

```bash
mantra --backtracking program.m
```

### Default Behavior: Greedy Match (no backtracking)

By default, `--` in patterns performs a greedy match. When `--` appears as an
infix segment (between two literal patterns), the matcher consumes as many
subject elements as possible and does not retry with shorter assignments if the
rest of the pattern fails.

A single infix `--` almost always succeeds with the greedy approach, because
there is only one wildcard to adjust. Problems arise when a pattern contains
**multiple** infix `--` segments — the first `--` greedily consumes everything,
leaving nothing for subsequent segments to match.

### Example: Single `--` without backtracking

```mantra
# tests/cases/matcher_match_any_infix_basic.in
print { [ 1 2 3 4 ] ? [ [ 1 -- 4 ] => [ ok ] ] }
```

Output:

```
[ ok ]
```

With only one `--` segment, the greedy match works: `--` absorbs `[ 2 3 ]` and
the literal `4` matches. No backtracking is needed.

### Example: Multiple `--` without backtracking (greedy failure)

```mantra
# Without --backtracking, the first -- consumes [ 2 3 5 2 3 4 ], leaving nothing for 2 -- 3 4
# The pattern [ 1 -- 2 -- 3 4 ] would fail to match [ 1 2 3 5 2 3 4 ].
print { [ 1 2 3 5 2 3 4 ] ? [ [ 1 -- 2 -- 3 4 ] => [ ok ] ] }
```

Without backtracking, the pattern fails because the first `--` consumes too
many elements. The output would be the original unmatched subject.

### Example: Multiple infix match-any with backtracking

```bash
# tests/cases/matcher_match_any_infix_backtracking.args
--backtracking
```

```mantra
# tests/cases/matcher_match_any_infix_backtracking.in
print { [ 1 2 3 5 2 3 4 ] ? [ [ 1 -- 2 -- 3 4 ] => [ ok ] ] }
```

Output:

```
[ ok ]
```

The pattern `[ 1 -- 2 -- 3 4 ]` contains two `--` segments. With
`--backtracking`, the matcher explores shorter assignments for the first `--`
until the full pattern matches. Here, the first `--` matches `[ 2 3 5 ]` and
the second `--` matches `[]`, so the pattern succeeds.

### How Backtracking Works

The `TryMatchWildcardRemainderWithBacktracking` function in `matcher_ir.pas`
implements a systematic search over split points:

1. The matcher identifies the wildcard (`--` or `---`) and the next literal
   pattern node that must follow it.
2. It iterates through possible split positions in the subject — either from
   the end toward the start (for `---` long-match-any, which prefers the
   longest assignment) or from the start toward the end (for `--` match-any,
   which prefers the shortest assignment).
3. At each split point, it saves the current bindings, attempts to match the
   remaining pattern against the remaining subject, and commits the result if
   the match succeeds.
4. If no split point produces a full match, the entire wildcard segment fails.

The key difference from greedy matching is that the greedy approach picks one
split point (the most extreme — longest or shortest) and never revisits it,
while backtracking tries every possible split position until it finds one that
lets the entire pattern succeed.

### When to Use Backtracking

| Scenario | Backtracking needed? |
|---|---|
| Patterns with a single `--` segment | No (greedy match works) |
| Multiple `--` segments in one pattern | Yes |
| Patterns with `---` (long-match-any) infix | Yes (preference for longest match) |
| Deterministic test fixtures with `--` | Pin explicitly with `--backtracking` |
| Performance-sensitive production code | Prefer single-`--` patterns to avoid backtracking overhead |

## `--no-guards`

Disable matcher rule guards (experimental).

```bash
mantra --no-guards program.m
```

### Rule Guards

Rule guards are conditions attached to rewrite rules that must evaluate to
true before the rule fires. The guard follows the replacement template,
separated by `~`:

```mantra
pattern => replacement ~( condition )
```

The `condition` is evaluated after the structural match succeeds and variable
bindings are established. If it evaluates to false, the rule is rejected and
the matcher proceeds to the next rule in the list.

Guards are evaluated via `EvaluateGuardTemplate` in `matcher_ir.pas`. The
global `MatcherGuardsEnabled` variable controls whether this check runs.

### Example: Guards suppressed by `--no-guards`

```bash
# tests/cases/matcher_no_guards_false_guard_applies.args
--no-guards
--debug
```

```mantra
# tests/cases/matcher_no_guards_false_guard_applies.in
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Output:

```
3
```

The rule has a guard `~( < x y )` that checks whether `x < y`. With the match
`x = 3` and `y = 2`, the guard `(< 3 2)` evaluates to false, so the rule
would normally be rejected. With `--no-guards`, the structural match succeeds
regardless, and the result `x` (which is `3`) is returned.

### Example: Guard failure without `--no-guards` (no match)

When a guard fails and there is no fallback rule, the subject is returned
unchanged:

```bash
# tests/cases/matcher_guard_false_no_fallback.args
--debug
```

```mantra
# tests/cases/matcher_guard_false_no_fallback.in
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Output:

```
[ 3 ] [ 2 ]
```

The same pattern and guard as above, but without `--no-guards`. The guard
`(< 3 2)` is false, and since there is no second rule to fall back on, the
subject `[ 3 ] [ 2 ]` is returned unchanged.

### Example: Guard failure with fallback rule

When a guard fails, the matcher tries the next rule in the list:

```bash
# tests/cases/matcher_guard_fallback_rule.args
--debug
```

```mantra
# tests/cases/matcher_guard_fallback_rule.in
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Output:

```
2
```

Two rules share the same structural pattern `[ x -- ] [ y -- ]`. The first
rule has the guard `~( < x y )` which fails (`3 < 2` is false). The matcher
then tries the second rule, which has no guard and succeeds, returning `y`
(which is `2`).

### Warning

`--no-guards` is experimental. Disabling guards changes the semantics of
rules that rely on guards for correctness. Use it only when:

- Testing matcher behavior in isolation from guard logic
- Intentionally ignoring guard conditions for exploration
- Running legacy programs where guards were not intended to block execution

The global `MatcherGuardsEnabled` variable in `matcher_ir.pas` defaults to
`True`. The `--no-guards` flag sets it to `False` for the entire session.

## Internal Behavior

Both flags set global variables in `matcher_ir.pas` that control matcher
behavior for all subsequent operations:

| Variable | Type | Default | Set by |
|---|---|---|---|
| `MatcherGuardsEnabled` | `Boolean` | `True` | `--no-guards` sets to `False` |
| `MatcherBacktrackingEnabled` | `Boolean` | `False` | `--backtracking` sets to `True` |
| `MatcherSelectionStrategy` | `TSelectionStrategyKind` | `sskFirst` | Set by `selector` blocks (not CLI) |
| `MatcherExhaustiveSelection` | `Boolean` | `False` | Set by `selector` blocks (not CLI) |

The `MatcherSelectionStrategy` and `MatcherExhaustiveSelection` variables are
controlled by `selector` constructs in Mantra programs rather than CLI flags.
They determine which rule is chosen when multiple rules match the same subject:

- **`sskFirst`** (default) — picks the first matching rule
- **`sskRandom`** — picks a random matching rule
- **`sskShrink`** — picks the matching rule with the smallest match span
- **`sskFirstRule`** — picks the first rule in order, regardless of match quality
- **`sskRandomRule`** — picks a random rule from the rule list

When `MatcherExhaustiveSelection` is `True`, the matcher continues searching
for matches after the first one instead of stopping.

## Combining Flags

Matcher control flags can be combined with other matcher and inference flags:

```bash
# Backtracking with event logging for debugging
mantra --backtracking --event-log=trace program.m

# Disabling guards with head dispatch off
mantra --no-guards --no-head-dispatch program.m

# Backtracking with inference beam search
mantra --backtracking --beam-width=2 program.m
```
