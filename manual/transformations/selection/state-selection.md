# State Selection

State selection uses `$?` to enable iterative rewrite workflows where the
selection node persists across repeat iterations, tracking match state and
allowing multiple rewrites in a single expansion cycle.

```mantra
subject $? rules
```

The `$` meta flag on a selection tells the runtime to use a specialized
expansion path instead of the default single-step behavior. The selection
node is cloned and then iteratively transformed until a limit is reached or
no further matches occur.

## When to Use State Selection

Use `$?` when you need:

- **Multiple rewrites per expansion** -- A single `?` performs at most one
  rewrite. `$?` combined with `: n` or `: ...` applies the rule repeatedly
  across iterations.
- **Focus and match tracking** -- State selection exposes `$focus` and
  `$match` replacement variables that refer to the currently matched
  subtree and the full match, respectively.
- **Bounded fixpoint iteration** -- With `: ...`, state selection runs
  until no rule matches or the maximum fixpoint steps (1024) is reached.

For single-step rewrites without state tracking, use `?` instead. See
[Selection Operator](selection-operator.md).

## How It Works

The runtime detects state-selection mode by checking for `TK_DOLLAR` on the
selection node. When a repeat (`:`) encounters `$?`, it routes to
`ExpandStateSelection` instead of the standard expansion path:

1. **Clone** -- The source tree is cloned once to preserve the selection
   structure.
2. **Iterative transform** -- The loop finds the selection node and calls
   `Transform` on it, decrementing the iteration counter. Unlike `Evaluate`,
   `Transform` keeps the selection node alive if a rewrite succeeds, allowing
   the next iteration to match again.
3. **Stall cleanup** -- When `Transform` fails to match (no rewrite step),
   `CLEANUP_SELECTION_ON_STALL` removes the rules (`RHS`) and collapses the
   node to the remaining `LHS`.
4. **Finalize** -- After the loop exits (limit reached or stall detected),
   `CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT` performs a final cleanup of any
   remaining selection node, then calls `Complete` and propagates operators.

### Key Differences from `?`

| Behavior | `?` | `$?` |
|---|---|---|
| Rewrites per evaluation | At most 1 | Up to `n` (repeat count) or fixpoint limit |
| Selection node after rewrite | Removed (collapsed to LHS) | Preserved for next iteration (via `Transform`) |
| Repeat interaction | Each `: n` iteration re-evaluates the selection | `ExpandStateSelection` runs the loop internally |
| `$focus` / `$match` | Not used | Available in replacement templates |

## Examples

### Iterative Removal

The canonical example: removing one element per iteration from an array.

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ 2 3 ] )
```

With `: 1`, one rewrite step removes the first element. The rule `[ x -- ]`
matches `x` as the head and `--` as the tail; `rhs x` returns the siblings
after `x`.

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 2 }
```

Expected `OUTPUT`:

```text
( [ 3 ] )
```

Two steps remove the first two elements.

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 3 }
```

Expected `OUTPUT`:

```text
( [] )
```

Three steps exhaust the array.

### Fixpoint Iteration with `: ...`

Instead of a fixed count, `: ...` runs until no rule matches (stall) or the
maximum fixpoint steps (1024) is reached:

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : ... }
```

Expected `OUTPUT`:

```text
( [] )
```

The loop continues until the empty array `[]` no longer matches `[ x -- ]`,
at which point `Transform` stalls, cleanup removes the selection node, and
the result is returned.

### No Match with `$?`

When no rule matches, the subject is returned unchanged after the repeat
cycle:

```mantra
{ 1 $? [] : 1 }
```

Expected `OUTPUT`:

```text
1
```

An empty ruleset cannot match anything, so the integer `1` is returned as-is.

## Focus and Match Variables

State selection exposes two special replacement variables prefixed with `$`:

- **`$focus`** -- The currently focused (inner) subtree. The focus is set by
  the `.` marker in the pattern (e.g., `.x` marks `x` as the focus). Only
  one focus marker is allowed per rule.
- **`$match`** -- The full matched structure (all nodes captured by the
  pattern).

You can combine them with selectors like `lhs`, `rhs`, and `all`:

- `lhs $match` -- First child of the matched subtree
- `rhs $match` -- Siblings after the first child
- `all $match` -- The entire matched subtree including all siblings

### Focus Example

```mantra
~ { 1 [ 2 ] 3 $? [ [ .x ] =>> $focus ] : 1 }
```

Expected `OUTPUT`:

```text
2
```

The `.` on `.x` marks the matched node as the focus. The replacement `$focus`
resolves to the inner content `2`, unwrapped by the `~` compute scope.

### Focus vs. Match

```mantra
~ { 1 [ 2 ] 3 $? [ [ .x ] =>> [ $match $focus ] ] : 1 }
```

Expected `OUTPUT`:

```text
[ [ 2 ] 2 ]
```

`$match` is the full matched node `[ 2 ]`, while `$focus` is the inner value
`2`. The replacement produces `[ [ 2 ] 2 ]`.

### Strict Match Without Focus

When the pattern does not use `.`, there is no focused subtree:

```mantra
print ~ { 1 [ 2 ] 3 $? [ [ x ] =>> $focus ] : 1 }
```

Expected `OUTPUT`:

```text
1 [ 2 ] 3
```

Without a `.x` focus marker, `$focus` falls back and the original subject is
returned unchanged. Use `$focus` only when the pattern includes a `.` marker.

### Match with Selectors

`$match` defaults to the `all` selector (entire matched subtree). You can
explicitly apply `lhs`, `rhs`, or `all`:

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> lhs $match ] : 1 }
```

Expected `OUTPUT`:

```text
1
```

`lhs $match` returns the first child of the matched structure.

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> rhs $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

`rhs $match` returns the siblings after the first child.

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> all $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ]
```

## Related Pages

- [Selection Operator](selection-operator.md) -- The basic `?` operator
- [Focus and Match Selectors](focus-match-selectors.md) -- `$focus` and `$match`
  in isolation
- [Root Selection](root-selection.md) -- Full-match mode with `^`
