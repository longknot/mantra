# Repeat with Evaluation Scopes

The repeat operator `:` expands a template by cloning it multiple times. Evaluation
scopes `{ ... }` are the natural wrapper for repeat — they evaluate the repeat
and collapse to the expanded result.

```mantra
{ template : count }
```

The evaluation scope evaluates the repeat, and the `{ ... }` wrapper disappears,
leaving only the expanded copies.

## How It Works

The interaction follows the `TRepeatNode.Evaluate` lifecycle in `nodes.pas`:

1. **Enter evaluation scope** -- `{ ... }` calls `Evaluate` on its children.
2. **Evaluate LHS** -- The left side of `:` is evaluated unless it contains
   selection nodes (`?` / `:=?`), which are preserved as structural patterns.
3. **Resolve repeat driver** -- The right side is scanned for the repeat driver
   (integer, variable, or `...` for recurse).
4. **Expand** -- The template is cloned the requested number of times. Each
   clone undergoes `Transform` and `Complete` operations.
5. **Evaluate expanded result** -- `Node[RHS].Evaluate(Context)` runs once over
   the expanded tree, triggering any nested compute or evaluation.
6. **Collapse** -- The repeat node and LHS are deleted. The evaluation scope
   `{ ... }` then collapses to its first child via `GlobalTree.Expand`.

The evaluation scope wrapper disappears after step 6 — only the repeated
result remains.

## Basic Repeat in an Evaluation Scope

Without an evaluation scope, repeat is not triggered — the colon expression
remains structural. The braces activate evaluation:

```mantra
print { 1 2 3 : 2 }
```

Expected `OUTPUT`:

```text
1 2 3 1 2 3
```

The template `1 2 3` is cloned two times, and the evaluation scope collapses to
reveal the result.

Parentheses group structurally but still allow the inner repeat to evaluate
because the evaluation scope `{ ... }` processes the children:

```mantra
print { ( 1 2 3 : 2 ) }
```

Expected `OUTPUT`:

```text
( 1 2 3 1 2 3 )
```

The parentheses are preserved as a grouping wrapper around the expanded result.

## Examples

### Scalar Repeat

A single value can be repeated:

```mantra
print { 1 : 3 }
```

Expected `OUTPUT`:

```text
1 1 1
```

### List Repeat

Lists are treated as a single template unit:

```mantra
print { [ 1 2 3 ] : 2 }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
[ 1 2 3 ]
```

Each copy of the list becomes a sibling in the result, printed on separate lines.

### Repeat Inside a List Container

When the evaluation scope sits inside a list, the list persists and the scope
collapses within it:

```mantra
print { [ 1 2 3 : 2 ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 1 2 3 ]
```

### Fixed Scope Repeat

Fixed scopes `' ... '` prevent evaluation of their contents, but the fixed
scope itself can be repeated as a template:

```mantra
print { 'hello' : 3 }
```

Expected `OUTPUT`:

```text
( hello ) ( hello ) ( hello )
```

Each copy retains the fixed scope semantics — the contents `hello` will not be
transformed, even though the scope wrapper is cloned.

### Negative Count — Delete

A count of `0` or less deletes the template entirely:

```mantra
print { 1 2 : 0 }
```

Expected `OUTPUT`:

```text
(no output — template deleted)
```

### Single Count — Identity

A count of `1` returns the template unchanged:

```mantra
print { ( 1 2 3 ) : 1 }
```

Expected `OUTPUT`:

```text
( 1 2 3 )
```

### Variable-Driven Repeat

The repeat driver can be a variable resolved from the runtime context:

```mantra
print { [ 7 ] : n }
```

With `--set n=3` on the CLI:

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

The `ResolveRepeatDriver` helper in `TRepeatNode.Evaluate` scans the RHS for
resolvable variables, supporting both direct counts (`: n`) and wrapped forms
(`: [ n ]`).

### Recurse / Fixpoint Repeat

The `...` operator drives a bounded fixpoint expansion. When the template
contains no selection nodes, a single copy is produced:

```mantra
{ [ 1 2 ] : ... }
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

The fixpoint is bounded by `MAX_FIXPOINT_STEPS = 1024` to prevent infinite
loops. When combined with state-selection mode (`$`), `...` iteratively
applies rewrite rules until no more match or the limit is reached.

## Advanced Patterns

### Nested Evaluation Scopes

Evaluation scopes can be nested. The inner scope evaluates first, then the
outer scope processes the result:

```mantra
{ { 1 2 : 2 } : 3 }
```

Expected `OUTPUT`:

```text
1 2 1 2 1 2 1 2 1 2 1 2
```

The inner scope `{ 1 2 : 2 }` expands to `1 2 1 2`. The outer scope `: 3`
then repeats that result three times.

### Nested Repeats with Compute

Evaluation scopes can wrap repeated expressions that contain compute:

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Expected `OUTPUT`:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

The inner repeat produces two copies of the computed result `+ 6` inside a
list. The outer repeat clones that list three times.

### Repeat with Selection Rewrites

When the LHS of `:` contains selection nodes (`?`), the LHS is **not**
pre-evaluated — the selection is preserved as a structural pattern. After
expansion, the selection is evaluated in the expanded result:

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ < 1 < 2 ] )
```

The selection rewrites `[ 9 ]` using the fallback rule `[ x -- ] => [ ~< 1 2 ]`.
The `~` tilde marks compute for the next iteration.

### Repeat with Selection — Multiple Copies

Increasing the count clones the rewritten result:

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 2 }
```

Expected `OUTPUT`:

```text
( [ done ] )
```

Here the first iteration matches and rewrites, and the second iteration
operates on the already-transformed structure.

### Compute on Next Iteration

The `~` tilde meta-operator marks nodes for compute during the evaluation of
the expanded result (step 5 of the lifecycle). This defers compute until after
the repeat has produced all its clones:

```mantra
print [ { [ ~ + 1 2 3 : 2 ] : 3 } ]
```

Expected `OUTPUT`:

```text
[ [ + 6 6 ] [ + 6 6 ] [ + 6 6 ] ]
```

The tilde marks `+` for compute in each iteration. The inner repeat `: 2`
produces two copies with compute folding the operands, and the outer `: 3`
produces three copies of that result.

### Iterator-Bound Repeat

The `@` meta-flag can bind an iterator value during repeat. When the repeat
driver is a range, each iteration exposes the current value:

```mantra
print { i : 1 @ i }
```

Expected `OUTPUT`:

```text
1
```

```mantra
print { i : 2 .. 2 @ i }
```

Expected `OUTPUT`:

```text
2
```

The iterator `i` is bound to the range value in each iteration, allowing the
template to reference the current position.

## Scope Comparison

Different scope types interact with repeat in different ways:

| Scope | Syntax | Repeat behavior | Wrapper removed? |
|---|---|---|---|
| Evaluation | `{ ... }` | Evaluates repeat, collapses result | Yes |
| Compute | `` ` ... ` `` | Evaluates repeat, then computes | Yes |
| Fixed | `' ... '` | No evaluation inside | No |
| Parentheses | `( ... )` | Groups but allows inner evaluation | No |
| List | `[ ... ]` | Containers persist around expansion | No |

## Key Details

- **LHS evaluation gating**: If the LHS contains selection nodes (`?` / `:=?`),
  `TRepeatNode.Evaluate` skips the LHS pre-evaluation to preserve rewrite
  templates. This is checked via `FindObject(OBJ_SELECTION)`.
- **Repeat driver resolution**: `ResolveRepeatDriver` scans the RHS for
  resolvable variables. It supports `: n`, `: [ n ]`, and `: ...` patterns
  without blindly evaluating all RHS nodes first.
- **Clone and finalize**: `TIntegerNode.Expand` calls `FixRecursion` on the
  source (implicit recurse insertion), then clones via `CloneSubtree` and
  applies `Transform` and `Complete` to each copy.
- **Operator propagation**: The operator from the integer node is appended to
  the first cloned copy via `AppendOperator`, ensuring structural continuity.
- **Fixpoint bound**: All recursive expansions respect `MAX_FIXPOINT_STEPS = 1024`.

## Pitfalls

| Pitfall | Explanation |
|---|---|
| Repeat without evaluation scope | `1 2 3 : 2` alone never expands — you need `{ ... }` or `` ` ... ` `` to trigger it |
| Selection LHS not pre-evaluated | Selection templates in the LHS are preserved structurally; they rewrite during expansion, not before |
| Variable not in context | If the driver variable isn't defined, the repeat silently exits — use `--set` or assign first |
| Zero or negative count | The template is deleted entirely — no output is produced |
| Fixpoint without selection | `: ...` on a plain template produces a single copy — it needs `$` + selection for iterative rewriting |

## Related Pages

- [Repeat Operator](repeat-operator.md)
- [Repeat with Compute Scopes](repeat-with-compute-scopes.md)
- [Compute Scopes](../syntax/compute-scopes.md)
- [Guards and Selectors](guards-and-selectors.md)
- [State Selection](state-selection.md)
- [Nested Repeats](nested-repeats.md)
- [Meta-Compute Operator](../compute/meta-compute-operator.md)
