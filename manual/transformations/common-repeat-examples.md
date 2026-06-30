# Common Repeat Examples

This page collects repeat examples that are useful when learning the language.
Each example includes the Mantra code, expected output, and a brief explanation
of what's happening. Cross-references to dedicated pages are included where a
topic warrants deeper coverage.

All examples here correspond to actual test fixtures in `tests/cases/` unless
noted otherwise.

---

## Basic Repeat

The simplest repeat clones a template a fixed number of times. The repeat
operator `:` takes a source (LHS) and a count (RHS). An evaluation scope
`{ ... }` is required to trigger the expansion.

```mantra
print { [ 7 ] : 3 }
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

Each copy is an independent clone of the source `[ 7 ]`.

Without an evaluation scope, the repeat stays structural and is never
triggered. Parentheses group structurally but the inner repeat still evaluates
because the surrounding `{ ... }` processes the children:

```mantra
print { ( [ 7 ] : 3 ) }
```

Expected `OUTPUT`:

```text
( [ 7 ] [ 7 ] [ 7 ] )
```

*Fixture: `tests/cases/cli_set_repeat_count.in` (via variable driver)*

---

## Range Drivers

A range `a .. b` expands into a sibling chain of values. When used as a repeat
driver, the count equals the number of values in the range.

```mantra
print { 1 : 1 .. 5 }
```

Expected `OUTPUT`:

```text
1 1 1 1 1
```

The range `1 .. 5` produces 5 values, so `1` is repeated 5 times.

*Fixture: `tests/cases/repeat_range_plain_sequence.in`*

---

## Repeat with Compute Scopes

When a repeat expression sits inside a compute scope (backticks), the runtime
reduces any computable operations within each repeated copy. Compute reduction
happens **after** repetition — each cloned copy carries the template expression,
and the final evaluation pass reduces all copies simultaneously.

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The addition `+ 1 2 3` reduces to `+ 6` inside every repeated copy.

*Fixture: `tests/cases/backtick_repeat_list_compute.in`*

---

## Nested Repeats with Compute

Multiple levels of repeat can interact with compute scopes. The outer repeat
evaluates first, then the inner repeat expands inside each copy.

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Expected `OUTPUT`:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

The inner `` `+ 1 + 2 + 3` `` reduces to `` + 6 ``, then repeats twice to
produce `` + 6 + 6 ``. The outer repeat clones this result three times.

*Fixture: `tests/cases/backtick_nested_repeat_compute.in`*

See [Nested Repeats](nested-repeats.md) for the full lifecycle explanation.

---

## Variable-Driven Repeat

The repeat count can be stored in a variable and passed via the CLI with
`--set`. The runtime resolves the variable from context before expanding.

```mantra
print { [ 7 ] : n }
```

Run with `--set n=3`:

```bash
mantra --set n=3 -e 'print { [ 7 ] : n }'
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

Unresolved variables cause the repeat to exit without expanding.

*Fixture: `tests/cases/cli_set_repeat_count.in`*

---

## Zero and Negative Repeat Counts

When the repeat count is `<= 0`, the target is deleted entirely. This provides
a conditional expansion pattern where zero or negative suppresses output.

```mantra
print { [ 7 ] : 0 }
```

Expected `OUTPUT`: (empty — no output produced)

```mantra
print { [ 7 ] : -1 }
```

Expected `OUTPUT`: (empty — no output produced)

See [Bounded Repeat](repeat-operator/bounded-repeat.md) for the full integer
driver semantics.

---

## Iterator Binding

The repeat operator supports iterator bindings via `@` which expose the current
iteration index to the LHS template. The iterator variable takes values 1
through `n` during expansion.

### Basic Iterator (Count)

```mantra
print { i : 1 @ i }
```

Expected `OUTPUT`:

```text
1
```

*Fixture: `tests/cases/repeat_iterator_count_basic.in`*

### Iterator Sequence

```mantra
print { i : 5 @ i }
```

Expected `OUTPUT`:

```text
1 2 3 4 5
```

Each position binds `i` to 1, 2, 3, 4, 5 respectively.

*Fixture: `tests/cases/repeat_iterator_count_sequence.in`*

### Iterator with Range

```mantra
print { i : 2 .. 2 @ i }
```

Expected `OUTPUT`:

```text
2
```

*Fixture: `tests/cases/repeat_iterator_range_basic.in`*

```mantra
print { i : 1 .. 5 @ i }
```

Expected `OUTPUT`:

```text
1 2 3 4 5
```

*Fixture: `tests/cases/repeat_iterator_range_sequence.in`*

### Stepped Range with Compute

A stepped range with `by` step produces iterator values at the specified
interval. Combined with tilde (`~`) and compute, each iteration evaluates
the expression independently:

```mantra
print { i : -1.0 .. 1.0 by 1.0 @ i }
```

Expected `OUTPUT`:

```text
- 1 0 1
```

*Fixture: `tests/cases/repeat_iterator_stepped_range.in`*

### Character Range Iterator

Character ranges work as iterators, binding a single character per iteration:

```mantra
print { i : "b" .. "b" @ i }
```

Expected `OUTPUT`:

```text
"b"
```

*Fixture: `tests/cases/repeat_iterator_char_range_basic.in`*

---

## Fixpoint Recurse

The `...` (recurse) driver enables iterative expansion until a rule stalls or
the hard limit `MAX_FIXPOINT_STEPS = 1024` is reached.

### Plain Recurse

```mantra
{ [ 1 2 ] : ... }
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

The recurse node expands the source once; since there's no selection rule to
keep transforming, the result is a single copy.

*Fixture: `tests/cases/repeat_fixpoint_recurse_plain.in`*

### Fixpoint with State Selection

The `: ...` fixpoint driver combined with state selection (`$?`) applies
selection rules until no rule matches:

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : ... }
```

Expected `OUTPUT`:

```text
( [] )
```

The rule `[ x -- ] => [ rhs x ]` removes the head element each iteration:
`[ 1 2 3 ]` → `[ 2 3 ]` → `[ 3 ]` → `[]`. When the array is empty, no
rule matches and the fixpoint stalls.

*Fixture: `tests/cases/repeat_fixpoint_recurse_state.in`*

See [Fixpoint Repeat](repeat-operator/fixpoint-repeat.md) for details.

---

## Repeat with Selection and Compute

Repeat can drive selection rewrites where compute is deferred to subsequent
iterations using the tilde (`~`) marker.

### Single-Step Selection with Deferred Compute

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ < 1 < 2 ] )
```

The selection rewrites `[ 9 ]` to `[ ~< 1 2 ]`. The tilde defers compute to
the next iteration. With only 1 step, the compute hasn't fired yet.

*Fixture: `tests/cases/repeat_next_iteration_compute_1.in`*

### Multi-Step Selection with Deferred Compute Resolution

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 2 }
```

Expected `OUTPUT`:

```text
( [ done ] )
```

Step 1: rewrites `[ 9 ]` to `[ ~< 1 2 ]`. Step 2: the tilde compute reduces
`< 1 2` → `1`, then the selection matches `[ 1 ]` → `[ done ]`.

*Fixture: `tests/cases/repeat_next_iteration_compute_2.in`*

---

## Symbolic RHS and Variable Resolution

When the RHS of a repeat contains unresolved symbolic variables, the repeat
may remain structural or resolve after assignment.

### Unresolved Symbolic RHS

```mantra
print { + x : + p }
```

Expected `OUTPUT`:

```text
+ x : + p
```

The variable `p` is not bound, so the repeat exits without expanding.

*Fixture: `tests/cases/repeat_symbolic_variable_rhs.in`*

### Assigned Symbolic RHS with Dynamic Resolution

When a symbolic RHS is stored in a variable and the count variable is later
assigned, the repeat resolves dynamically:

```mantra
s1 = + x : + p;
s2 = + x : + 2 p 2;

print { s1 };
print { s2 };

{ p = 3 };
print { s2 };
```

Expected `OUTPUT`:

```text
+ x : + p
+ x + x ( + x : + p ) + x + x
+ x + x + x + x + x + x + x
```

Initially `p` is unbound, so `s1` stays structural. After `p = 3`, `s2`
resolves and expands.

*Fixture: `tests/cases/repeat_symbolic_variable_rhs_assigned.in`*

---

## Staged Repeat (`::`)

Staged repeat evaluates a fresh clone of the subject independently for each
driver value. See [Staged Repeat](staged-repeat.md) for full semantics.

### Staged Count

```mantra
print { 1 :: 3 }
```

Expected `OUTPUT`:

```text
1 1 1
```

*Fixture: `tests/cases/staged_repeat_count_basic.in`*

### Staged with Iterator Range

```mantra
print { i :: 1 .. 3 @ i }
```

Expected `OUTPUT`:

```text
1 2 3
```

*Fixture: `tests/cases/staged_repeat_iterator_range.in`*

### Staged with Sequence Driver

```mantra
print { [ x ] :: [ a, b, c ] @ x }
```

Expected `OUTPUT`:

```text
[ a ] [ b ] [ c ]
```

*Fixture: `tests/cases/staged_repeat_sequence_comma.in`*

### Staged Without Iterator Binding

Without `@ variable`, the driver still controls the number of evaluations:

```mantra
print { [ item ] :: [ a b c ] }
```

Expected `OUTPUT`:

```text
[ item ] [ item ] [ item ]
```

*Fixture: `tests/cases/staged_repeat_sequence_without_binding.in`*

### Staged Empty Driver

```mantra
print { [ x ] :: [ ] @ x }
```

Expected `OUTPUT`: (nothing produced)

*Fixture: `tests/cases/staged_repeat_sequence_empty.in`*

### Staged with Expression Driver

```mantra
values = ( a b c );
print { [ x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ a ] [ b ] [ c ]
```

*Fixture: `tests/cases/staged_repeat_sequence_assigned_expression.in`*

### Iterator Shadowing

The iterator binding shadows outer variables:

```mantra
n = 1;
print { scope { [ n ] :: 3 @ n } }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ] [ 3 ]
```

The iterator `n` takes values 1, 2, 3, shadowing the outer `n = 1`.

*Fixture: `tests/cases/staged_repeat_iterator_shadowing.in`*
