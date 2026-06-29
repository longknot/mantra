# Repeat Operator

The repeat operator `:` clones a source template and expands it into zero or
more copies. It is the fundamental expansion mechanism in Mantra — every tree
duplication, iterative rewrite, and fixpoint loop flows through this single
operator.

```mantra
LHS : RHS
```

- **LHS** — the source/template to be expanded
- **RHS** — the driver that controls how expansion happens

The colon expression is consumed during evaluation. The original repeat node
and LHS are deleted, replaced by the expanded copies in the tree.

## Quick Example

```mantra
print { [ 7 ] : 3 }
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

The source `[ 7 ]` is cloned three times. Each copy is an independent
duplication of the template.

## How It Works

The evaluation flow is orchestrated by `TRepeatNode.Evaluate` in `nodes.pas`:

1. **Evaluate LHS** — The left side is evaluated unless it contains selection
   nodes (`?` / `:=?`), which are preserved as structural patterns.
2. **Resolve repeat driver** — `ResolveRepeatDriver` scans the RHS for the
   effective driver node (integer, recurse `...`, variable, or iterator
   binding). Unresolved variables cause the repeat to exit without expanding.
3. **Set source pointer** — `Context.Data` is set to point to the LHS source
   node, so the expansion callback knows what to clone.
4. **Expand** — `Node[RHS].Expand(Context)` performs the actual cloning. The
   driver node type determines which `Expand` method runs (integer, recurse,
   etc.).
5. **Evaluate expanded result** — `Node[RHS].Evaluate(Context)` runs once over
   the expanded tree, enabling compute reduction and nested scope collapses.
6. **Clean up** — The original LHS and the repeat node are deleted; only the
   expanded RHS remains.

## Driver Types

The RHS determines which expansion strategy the runtime uses.

| Driver | Syntax | Expand Method | Behavior |
|---|---|---|---|
| Integer literal | `: 3` | `TIntegerNode.Expand` | Clone LHS exactly n times |
| Variable | `: n` | `TIntegerNode.Expand` | Resolve variable, then clone |
| Recurse | `: ...` | `TRecurseNode.Expand` | Fixpoint expansion until stall |
| Range | `: [ 1 .. 5 ]` | `TIntegerNode.Expand` | Unwrap and resolve range |
| Iterator binding | `: 5 @ i` | `TIntegerNode.Expand` | Clone with `i` bound to 1..n |

### Integer (Bounded Repeat)

An integer driver clones the source a fixed number of times. The count can be
a literal, a variable, or a CLI-set value via `--set`:

```mantra
print { [ 7 ] : 3 }
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

When the count is `<= 0`, the target is deleted entirely — the repeat
produces no output. When the count is driven by a variable that cannot be
resolved, the repeat exits without expanding. See
[Bounded Repeat](repeat-operator/bounded-repeat.md) for details on state
selection mode (`$`), iterator bindings, and bounded inference.

### Recurse (Fixpoint Repeat)

The `...` driver enables iterative expansion until a rule stalls or a hard
limit (`MAX_FIXPOINT_STEPS = 1024`) is reached. It is the go-to choice when
you don't know how many iterations are needed:

```mantra
{ [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] : ... }
```

Expected `OUTPUT`:

```text
[]
```

The rule `[ x -- ] => [ rhs x ]` removes one element per iteration. The loop
runs until the array is empty and no rule matches. See
[Fixpoint Repeat](repeat-operator/fixpoint-repeat.md) for the full mechanics.

## Repeat and Evaluation Scopes

The repeat operator is not triggered at the top level — it requires an
evaluation scope `{ ... }` (or a compute scope `` ` ... ` ``) to activate:

```mantra
print { 1 2 3 : 2 }
```

Expected `OUTPUT`:

```text
1 2 3 1 2 3
```

Without the evaluation scope, the colon expression remains structural and is
never expanded. See [Repeat with Evaluation
Scopes](repeat-with-evaluation-scopes.md) for the `{ ... }` interaction.

## Repeat and Compute Scopes

When a repeat sits inside a compute scope, each cloned copy is reduced
arithmetically after expansion:

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

See [Repeat with Compute Scopes](repeat-with-compute-scopes.md) for details.

## Repeat and Selection

The most common pattern is combining repeat with selection to apply a rewrite
rule multiple times:

```mantra
{ ( [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] ) : 2 }
```

Expected `OUTPUT`:

```text
( [ 3 ] )
```

Each iteration evaluates the selection again, applying one rewrite. For
iterative state-selection that tracks focus across steps, use `$?` with
repeat. See [Selection](selection.md) and [State
Selection](selection/state-selection.md).

## Nested Repeats

When a repeat appears inside another repeat's template, the inner repeat
evaluates during subject preparation — once before the outer clones. All outer
copies are therefore identical. Use staged repeat (`::`) with iterator binding
when you need per-clone variation. See [Nested Repeats](nested-repeats.md).

## Staged Repeat (`::`)

Mantra also supports the `::` operator, which evaluates a fresh clone of the
subject independently for each driver value, rather than evolving a single
result. See [Staged Repeat](staged-repeat.md) for the full semantics.

## Key Behaviors

| Behavior | Detail |
|---|---|
| LHS with `?` / `:=?` | Not pre-evaluated; selection templates preserved |
| LHS with `\|=` | Switches to bounded inference; RHS = max search depth |
| Driver `n <= 0` | Target deleted; no output produced |
| Driver `n > 0` (normal) | Source cloned n times with Transform/Complete |
| Driver `n > 0` (state `$`) | Up to n iterative rewrites via ExpandStateSelection |
| Driver `...` | Fixpoint expansion (up to 1024 steps) |
| Unresolved variable | Repeat exits without expanding |
| After expansion | Final Evaluate pass enables compute on copies |

## Related Pages

- [Bounded Repeat](repeat-operator/bounded-repeat.md) — Integer-driven cloning
- [Fixpoint Repeat](repeat-operator/fixpoint-repeat.md) — `...` recurse driver
- [Expansion Behavior](expansion-behavior.md) — How tree expansion works
- [Nested Repeats](nested-repeats.md) — Repeats inside repeats
- [Staged Repeat](staged-repeat.md) — `::` independent evaluation
- [Repeat with Evaluation Scopes](repeat-with-evaluation-scopes.md) — `{ ... }` wrapper
- [Repeat with Compute Scopes](repeat-with-compute-scopes.md) — `` ` ... ` `` reduction
- [Common Repeat Examples](common-repeat-examples.md) — Reference examples
- [Selection](selection.md) — Rule-based rewrites
- [State Selection](selection/state-selection.md) — Iterative `$?` rewrites
