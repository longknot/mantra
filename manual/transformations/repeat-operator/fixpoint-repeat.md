# Fixpoint Repeat

The `...` repeat driver enables fixpoint-like recursive expansion. Instead of a
fixed integer count, the runtime keeps applying transformations until no further
change occurs (stall) or a hard safety limit is reached.

```mantra
subject : ...
```

The `...` syntax creates a `TRecurseNode` at parse time. When it appears as the
RHS of `:`, the repeat routes to `TRecurseNode.Expand` instead of the integer
path (`TIntegerNode.Expand`).

The runtime bounds all fixpoint iterations to `MAX_FIXPOINT_STEPS = 1024` (in
`nodes.pas`) to prevent infinite loops.

## When to Use Fixpoint Repeat

Use `: ...` when you need:

- **Automatic termination** -- The loop stops when no rewrite step applies,
  so you don't need to calculate the exact number of iterations.
- **Recursive rule application** -- Rules that reference themselves (e.g.,
  `recurse`) apply repeatedly until a base case is reached.
- **State selection exhaustion** -- Combined with `$?`, it applies selection
  rules until the subject is fully consumed or no matches remain.

For a fixed number of iterations, use [Bounded Repeat](bounded-repeat.md) with
an integer driver (`: n`) instead.

## Syntax

```
LHS : ...
```

- **LHS** -- the source/template to be expanded
- **`...`** -- the recurse token (`TK_TRIPLEDOT`), which creates `TRecurseNode`

The `...` driver can also appear inside wrapped forms like `: [ ... ]`, where
the repeat resolves the effective driver through `ResolveRepeatDriver`.

## How It Works

The evaluation flow is orchestrated by `TRepeatNode.Evaluate` and
`TRecurseNode.Expand` in `nodes.pas`:

1. **Evaluate LHS** — The left side is evaluated unless it contains selection
   nodes (`?` / `:=?`), which are preserved as structural patterns.
2. **Resolve repeat driver** — `ResolveRepeatDriver` identifies the `...` recurse
   node as the driver.
3. **Set source pointer** — `Context.Data` points to the LHS source node,
   accessible via `TryGetRepeatExpandSource`.
4. **Expand** — `TRecurseNode.Expand` takes two paths based on whether the
   source uses state-selection mode:
   - **Plain mode**: Calls `FixRecursion` on the source (adds implicit `...`
     recursion marker unless the source contains a selection node), then clones
     the source once, normalizes iterator bindings, applies operators, and
     finalizes via `Complete`.
   - **State-selection mode** (`$`): Delegates to `ExpandStateSelection` in
     `helpers.pas`, which runs a bounded iteration loop (up to
     `MAX_FIXPOINT_STEPS`) that repeatedly finds and transforms selection
     nodes.
5. **Inline expansion** — The recurse node replaces itself with the expanded
   result via `GlobalTree.ExpandInline`.
6. **Evaluate expanded result** — If the recurse node has RHS siblings
   (`N <> EOT`), they are evaluated.
7. **Clean up** — The original LHS and repeat node are deleted; only the
   expanded result remains.

### Plain Recurse vs. State Selection

| Mode | Syntax | Behavior |
|---|---|---|
| Plain | `subject : ...` | Single expansion with recursion marker |
| State selection | `subject $? rules : ...` | Iterative rewrites until stall or 1024 steps |

The distinction is determined by `UsesStateSelectionMode`, which checks for
`TK_DOLLAR` (`$`) on any selection node within the source tree.

#### FixRecursion detail

`FixRecursion` (in `TBaseNode`) walks the source tree looking for an existing
`OBJ_RECURSE` node. If none is found, it appends a new `TRecurseNode` as the
last sibling. However, if `SKIP_IMPLICIT_RECURSE_FOR_SELECTION` is enabled
(currently `True`), it skips adding the recursion marker whenever the source
contains any selection node (`OBJ_SELECTION` or `OBJ_INLINE_SELECTION`),
regardless of the `$` flag. This prevents duplicate recursion markers when
selection-based rewrites are involved.

#### NormalizeRepeatIteratorClone

After cloning, `NormalizeRepeatIteratorClone` resolves any iterator bindings
(`@`) in the cloned subtree. If an iterator token reference exists in the
context, `NormalizeResolvableVariables` substitutes the current iteration value
into the clone. This enables index-aware repetition even in fixpoint mode.

## Examples

### Plain Fixpoint Recurse

The simplest form — a source with no selection nodes:

```mantra
{ [ 1 2 ] : ... }
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

The `FixRecursion` method adds an implicit `...` recursion marker to the source,
then `TRecurseNode.Expand` clones it once and finalizes. Since there are no
selection nodes to drive further rewrites, the result is the original structure.

This fixture is tested in `tests/cases/repeat_fixpoint_recurse_plain.in`.

### State Selection with Fixpoint

The most common pattern — combining `$?` with `: ...` to exhaustively apply
rules until no matches remain:

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ) : ... }
```

Expected `OUTPUT`:

```text
( [] )
```

The runtime delegates to `ExpandStateSelection` which:

1. Clones the source tree.
2. Applies the operator from the recurse node (`DstOp`).
3. Enters a bounded loop (up to `MAX_FIXPOINT_STEPS = 1024`):
   - `FindSelectionWithPrev` locates the `$?` selection node.
   - `Transform` is called — the rule `[ x -- ] => [ rhs x ]` matches the head
     element `x` and the tail `--`, replacing with `rhs x` (everything after
     the first element).
   - The iteration counter decrements.
4. When the array becomes empty `[]`, the pattern `[ x -- ]` no longer matches —
   the loop breaks.
5. `CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT` (currently `True`) removes the
   leftover selection node.
6. `Complete` finalizes the result, and operators are propagated to siblings.

Each iteration removes one element: `[ 1 2 3 ]` → `[ 2 3 ]` → `[ 3 ]` → `[]`.

This fixture is tested in `tests/cases/repeat_fixpoint_recurse_state.in`.

#### Comparison: Bounded vs. Fixpoint with State Selection

| Driver | Steps | Termination |
|---|---|---|
| `: n` | Exactly `n` (or fewer if stalled) | Counter reaches 0 or rule stalls |
| `: ...` | Up to 1024 | Rule stalls or 1024 steps reached |

With `: 3`, the same example produces `( [] )` as well — the array is exactly
three elements, so it exhausts in three steps. With `: 5`, it also produces
`( [] )` — the loop exits when the rule stalls (empty array), not when the
counter reaches zero.

### Recursive Rules with Named Functions

Fixpoint recurse is also used implicitly by recursive rule declarations. A
`rule` with a self-referencing pattern applies transformations until the
remaining structure no longer matches:

```mantra
rule recurse {
  recurse x -- => [ x , recurse rhs x ]
}
print { recurse 1 2 3 }
```

Expected `OUTPUT`:

```text
[ 1 , [ 2 , [ 3 , recurse ] ] ]
```

The rule matches `recurse` followed by any elements. Each step extracts the
head `x` and recursively processes the tail via `rhs x`. When no more elements
remain, the `recurse` keyword stays as a base-case marker. The fixpoint bound
(`MAX_FIXPOINT_STEPS = 1024`) prevents infinite recursion.

This fixture is tested in `tests/cases/rule_recurse_rhs_tail_terminates.in`.

## ExpandStateSelection Internals

The `ExpandStateSelection` function in `helpers.pas` is the workhorse for
iterative state-selection rewrites. Signature:

```pascal
function ExpandStateSelection(
  Tree: TCustomTree;
  Context: TContext;
  Src, DstOp: Integer;
  IterLimit: Int64;
  CleanupAfter: Boolean = True
): Integer;
```

- **`Tree`** — the global tree (`GlobalTree`)
- **`Context`** — the current evaluation context
- **`Src`** — index of the source node to clone
- **`DstOp`** — operator flags from the recurse node (meta flags like `~`, `$`, etc.)
- **`IterLimit`** — maximum iteration count (1024 for fixpoint, `n` for bounded)
- **`CleanupAfter`** — whether to remove remaining selection nodes on exit

The loop uses `FindSelectionWithPrev` instead of `FindSelectionNode` because it
needs both the selection node index and its predecessor to perform transforms
and cleanup correctly.

## Key Behaviors

| Behavior | Detail |
|---|---|
| Plain `: ...` | Single expansion with implicit recursion marker |
| `$?` with `: ...` | Iterative rewrites via `ExpandStateSelection` (up to 1024 steps) |
| No selection in source | Falls through to plain mode; clones once |
| `FixRecursion` | Skips if `SKIP_IMPLICIT_RECURSE_FOR_SELECTION = True` and source has selection |
| `CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT` | Removes leftover `$?` node after loop exits |
| `MAX_FIXPOINT_STEPS` | Hard limit of 1024 to prevent infinite loops |
| Iterator bindings (`@`) | Resolved via `NormalizeRepeatIteratorClone` after cloning |

## Fixpoint Repeat vs. Bounded Repeat

| Feature | Bounded (`: n`) | Fixpoint (`: ...`) |
|---|---|---|
| Driver | Integer literal or variable | `...` recurse token |
| Steps | Exactly `n` (or fewer if stalled) | Up to `MAX_FIXPOINT_STEPS` (1024) |
| Control | Explicit count from user | Implicit fixpoint convergence |
| Use case | Known iteration count | Unknown iteration count |

## Related Pages

- [Bounded Repeat](bounded-repeat.md)
- [State Selection](../selection/state-selection.md)
- [Selection Operator](../selection/selection-operator.md)
- [Repeat with Compute Scopes](../repeat-with-compute-scopes.md)
- [Compute Scopes](../../syntax/compute-scopes.md)
