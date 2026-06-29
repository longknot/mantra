# Nested Repeats

Nested repeats occur when a repeat expression appears inside another repeat or
inside a scope that is itself repeated. They are one of the more subtle patterns
in Mantra because the evaluation order matters — the runtime evaluates inner
repeats during the outer repeat's subject preparation phase, which can produce
unexpected results if you're not aware of the lifecycle.

```mantra
{ [ template : inner_count ] : outer_count }
```

Expected `OUTPUT` (with concrete values):

```text
[ template template ] [ template template ] [ template template ]
```

The inner repeat expands first within the template, then the outer repeat clones
the entire result.

## Reading Nested Repeats

Start with the **innermost** repeat form, then read outward through the
surrounding scope and container. The rule of thumb:

1. Identify the innermost `:` (or `::`) driver.
2. Determine what the inner repeat produces from its template.
3. Treat that result as the template for the next outer repeat.
4. Repeat until you reach the outermost level.

Every nested repeat example in this manual includes expected output so you can
verify your mental model against actual runtime behavior.

## How It Works

The evaluation flow for nested repeats is defined by `TRepeatNode.Evaluate` in
`nodes.pas`. The outer repeat follows these steps:

1. **Evaluate LHS** — The left side of the outer repeat is evaluated. This step
   is critical: it processes all descendants of the LHS, including any inner
   repeat nodes. If the inner repeat sits inside the outer template, it
   evaluates *before* the outer iteration begins.
2. **Resolve outer repeat driver** — The outer RHS is scanned for the repeat
   count (integer, variable, or `...`).
3. **Expand** — The already-evaluated template is cloned the requested number
   of times. Each clone undergoes `Transform` and `Complete`.
4. **Evaluate expanded result** — `Node[RHS].Evaluate(Context)` runs once over
   the expanded tree, triggering any nested compute or deferred evaluation.
5. **Clean up** — The original LHS and repeat node are deleted; only the
   expanded copies remain.

The key insight: **inner repeats evaluate during subject preparation**, not
during each outer clone. The template is evaluated once, the inner repeat fires,
and then the result is cloned. This differs from the intuitive "evaluate per
iteration" model — but it matches the current runtime semantics.

### When Inner Repeats Evaluate Per-Clone

If you need the inner repeat to produce different results for each outer
iteration, you need a mechanism that delays inner evaluation. The staged repeat
operator `::` with iterator binding provides this behavior (see
[Staged Repeat with Iterator](#staged-repeat-with-iterator-below)).

## Examples

### Two-Level Repeat in Evaluation Scopes

The canonical nested repeat — an inner repeat inside a list template that the
outer repeat clones:

```mantra
{ [ 1 2 3 : 2 ] : 3 }
```

Expected `OUTPUT`:

```text
[ 1 2 3 1 2 3 ] [ 1 2 3 1 2 3 ] [ 1 2 3 1 2 3 ]
```

The inner `1 2 3 : 2` evaluates first during subject preparation, producing
`1 2 3 1 2 3` inside the list brackets. Then the outer `: 3` clones that
result three times.

### Nested Repeats with Compute Scopes

When compute scopes wrap inner repeats, the compute reduces after each inner
repetition, and the outer repeat clones the reduced result:

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Expected `OUTPUT`:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

The inner `` `+ 1 + 2 + 3` `` reduces to `` + 6 ``. The inner `: 2` produces
`` + 6 + 6 ``. The outer `: 3` clones that array three times.

This fixture is tested in `tests/cases/backtick_nested_repeat_compute.in`.

### Nested Repeats with Parentheses

Parentheses group the inner repeat result structurally:

```mantra
{ ( 1 : 2 ) : 3 }
```

Expected `OUTPUT`:

```text
( 1 1 ) ( 1 1 ) ( 1 1 )
```

The inner `1 : 2` produces `1 1` inside parentheses. The outer `: 3` clones
the parenthesized group three times.

### Bounded Repeat with Selection — Compute on Next Iteration

Nested repeats interact with selection and tilde (`~`) compute targeting. The
inner repeat drives a selection rewrite, and the tilde defers compute to the
next iteration:

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ < 1 < 2 ] )
```

With two steps, the deferred tilde compute from step 1 fires:

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 2 }
```

Expected `OUTPUT`:

```text
( [ done ] )
```

Step 1 rewrites `[ 9 ]` to the tilde-marked `[ ~< 1 2 ]`. Step 2 evaluates the
tilde (compute reduces `< 1 2`), then matches `[ 1 ]` to produce `[ done ]`.

These fixtures are tested in `tests/cases/repeat_next_iteration_compute_1.in`
and `tests/cases/repeat_next_iteration_compute_2.in`.

### Fixpoint Recurse with State Selection

The `: ...` fixpoint driver can nest with state selection (`$?`) to apply
selection rules until stall:

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : ... }
```

Expected `OUTPUT`:

```text
( [] )
```

The runtime delegates to `ExpandStateSelection` which iteratively applies the
rule `[ x -- ] => [ rhs x ]` — each step removes the head element. The sequence
`[ 1 2 3 ]` → `[ 2 3 ]` → `[ 3 ]` → `[]` stalls when no elements remain.

This fixture is tested in `tests/cases/repeat_fixpoint_recurse_state.in`.

### Staged Repeat with Inner Repeat

The staged repeat operator `::` supports iterator bindings, which delay inner
evaluation until each outer iteration materializes. This lets the inner repeat
produce different results per outer clone:

```mantra
print { scope { [ + 1 - ( ... ) : m ] :: 2 @ m } }
```

Expected `OUTPUT`:

```text
[ + 1 - () ] [ + 1 - ( + 1 - () ) ]
```

The outer `:: 2 @ m` produces two clones. In the first, `m` is bound to `1`,
so the inner `: m` repeats once. In the second, `m` is bound to `2`, so the
inner repeat fires twice, nesting deeper.

This fixture is tested in `tests/cases/staged_repeat_inner_recurse_flat.in`.

### Staged Repeat with Inner Repeat Materialized

A simpler staged-repeat nesting example:

```mantra
print { [ 1 : m ] :: 2 @ m }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 1 1 ]
```

The outer `:: 2 @ m` iterates twice. First clone: `m = 1`, inner `: 1` produces
`[ 1 ]`. Second clone: `m = 2`, inner `: 2` produces `[ 1 1 ]`.

This fixture is tested in `tests/cases/staged_repeat_inner_repeat_materialized.in`.

### Iterator Shadowing

When an iterator variable shadows an outer variable, staged repeat ensures the
binding is specialized per-iteration:

```mantra
n = 1;
print { scope { [ n ] :: 3 @ n } }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ] [ 3 ]
```

The iterator `n` takes values 1, 2, 3. Each clone evaluates with its own
iterator binding, shadowing the outer `n = 1`.

This fixture is tested in `tests/cases/staged_repeat_iterator_shadowing.in`.

## Ordinary Repeat vs. Staged Repeat for Nesting

The two repeat operators behave differently with nested inner repeats:

| Feature | Ordinary `:` | Staged `::` |
|---|---|---|
| Inner repeat timing | Evaluates during subject preparation (once, before outer clones) | Evaluates per-iteration (after iterator binding) |
| Iterator binding | No `@` support on `:` (iteration index not exposed) | `@ name` binds per-iteration value |
| Per-clone variation | All clones are identical | Each clone can differ based on iterator |
| Recurse handling | Outer repeat claims inner `...` nodes during transform | Outer stays flat; inner recurse is per-item |
| Driver types | Integer, variable, `...` | Integer, range, sequence, parenthesized expression |

Choose `::` when you need the inner repeat to produce different results per
outer iteration. Choose `:` when all clones should be identical — the inner
repeat fires once and the result is cloned.

## Key Behaviors Summary

| Pattern | Behavior |
|---|---|
| `{ [ A : inner ] : outer }` | Inner `A : inner` evaluates once; result cloned `outer` times |
| `{ ( A : inner ) : outer }` | Same as above, but parentheses wrap each clone |
| `{ [ `expr` : inner ] : outer }` | Compute reduces inside inner repeat first, then outer clones |
| `subject :: n @ var` | Inner re-evaluates per-iteration with `var` bound to 1..n |
| `subject : ...` (fixpoint) | Recurse expands until stall or `MAX_FIXPOINT_STEPS` (1024) |
| Unresolved variable in driver | Repeat exits without expanding |

## Common Pitfalls

1. **Expecting per-clone inner evaluation with `:`** — The inner repeat in
   ordinary `:` fires during subject preparation, not during each outer clone.
   All outer copies are identical. Use `::` with `@` binding for per-clone
   variation.

2. **Outer repeat consuming inner `...` recurse nodes** — When an inner repeat
   uses `: ...`, the outer transform may descend into and claim the recurse
   node. The result becomes a single nested structure instead of flat outer
   items. Use `::` (staged repeat) to keep the outer repeat flat.

3. **Variable shadowing confusion** — With ordinary `:`, an outer variable
   resolves during subject preparation before iterator bindings exist. With
   `::`, the iterator shadowing works as expected since evaluation happens
   per-iteration after binding.

4. **Selection templates in LHS not pre-evaluated** — If the outer LHS contains
   `?` or `:=?`, `TRepeatNode.Evaluate` intentionally skips pre-evaluation to
   preserve structural patterns. This is correct behavior but can be surprising
   if you expect the selection to fire before the outer repeat clones.

## When to Use Nested Repeats

Use nested repeats when you need:

- **Structured grids or matrices** — Outer repeat for rows, inner repeat for
  columns (all identical).
- **Per-item variation** — Staged repeat with iterator binding for sequences
  where each position differs.
- **Recursive depth control** — Inner fixpoint recurse driven by an outer
  iterator value for variable-depth expansions.
- **Deferred compute** — Tilde (`~`) marking combined with bounded repeat for
  multi-step compute pipelines.

## Related Pages

- [Repeat Operator](repeat-operator.md)
- [Bounded Repeat](repeat-operator/bounded-repeat.md)
- [Fixpoint Repeat](repeat-operator/fixpoint-repeat.md)
- [Repeat with Evaluation Scopes](repeat-with-evaluation-scopes.md)
- [Repeat with Compute Scopes](repeat-with-compute-scopes.md)
- [Common Repeat Examples](common-repeat-examples.md)
- [Selection](selection.md)
