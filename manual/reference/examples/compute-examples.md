# Compute Examples

This page collects compact, runnable examples that demonstrate the compute scope
and the `~` (tilde) meta flag for triggering arithmetic and logical reduction.
All examples correspond to real test fixtures in `tests/cases/` unless otherwise
noted.

---

## Basic Arithmetic

### Integer Addition

Sum three integers in a compute scope.

**Input:**

```mantra
` + 1 2 3`
```

**Output (`--debug`):**

```text
+ 6
```

The operator is preserved while the operands are reduced to their sum.

### Mixed Addition and Subtraction

Compute scopes fold siblings left-to-right, respecting sign operators.

**Input:**

```mantra
` + 10 - 3 2`
```

**Output (`--debug`):**

```text
+ 9
```

---

## Float Operations

### Float Multiplication

When a float participates in the expression, the result is promoted to floating
point.

**Input:**

```mantra
{ ~ * 1.5 2 }
```

**Output (`--debug`):**

```text
* 3
```

### Float Division

**Input:**

```mantra
` / 7 2`
```

**Output (`--debug`):**

```text
/ 3
```

Integer division truncates (7 div 2 = 3).

---

## Multiple Compute Scopes

Multiple backtick scopes are reduced independently within the same parent.

**Input:**

```mantra
[ ` + 1 2 ` ` + 3 4 ` ]
```

**Output:**

```text
[ + 3 + 7 ]
```

The test fixture `multi_compute_nodes` confirms this behavior. Each scope
reduces its own operands separately.

---

## Boolean Logic

### Boolean AND

Integer truth values reduce with boolean operators.

**Input:**

```mantra
{ ~ and 1 2 3 }
```

**Output (`--debug`):**

```text
1
```

Non-zero operands are treated as true; the result is `1` (true).

---

## Compute with Repeat

### Repeat Inside Compute Scope

A repeat operator inside backticks first duplicates its template, then reduces
each copy.

**Input:**

```mantra
`[ + 1 2 3 ] : 3`
```

**Output:**

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The test fixture `backtick_repeat_list_compute` confirms this behavior. The
list `[ + 1 2 3 ]` is repeated 3 times; each clone is independently computed
to `+ 6`.

### Nested Repeat with Compute

Compute and repeat can be nested. Inner compute reduces first, then the repeat
duplicates the reduced form.

**Input:**

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

**Output:**

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

The test fixture `backtick_nested_repeat_compute` confirms this behavior. The
inner compute scope reduces `+ 1 + 2 + 3` to `+ 6`, which is repeated twice
to `[ + 6 + 6 ]`, then the outer repeat clones that list three times.

---

## Variable Lookup in Compute Scopes

Variables are resolved from context before compute reduction.

**Input:**

```mantra
x = [ + 1 2 3 ]
`x`
```

**Output:**

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The test fixture `assignment_lookup_compute` confirms this behavior. The
variable `x` is first assigned, then the compute scope resolves it and
reduces the expression.

### Variable from CLI Set

Pre-defined variables via `--set` are also available inside compute scopes.

**Input (with `--set x=[ + 1 2 3 ]`):**

```mantra
print `x`
```

**Output:**

```text
[ + 6 ]
```

The test fixture `cli_set_expression_compute` confirms this behavior.

---

## Unary Operations

### Negation

Unary minus negates the value.

**Input:**

```mantra
` - 5`
```

**Output (`--debug`):**

```text
-5
```

---

## How It Works

- **Backtick scope (`` `...` ``)** — triggers arithmetic reduction on the
  contained expression.
- **`~` (tilde) meta flag** — marks a targeted node/subtree for compute
  evaluation. Can be combined with `{ }` evaluation scope as in
  `{ ~ * 1.5 2 }`.
- **Operator preservation** — the operator token is kept in the output (e.g.,
  `+ 6` rather than `6`) because Mantra treats code as tree structure.
- **Integer vs. float** — integer arithmetic uses `Int64` with truncating
  division. Float arithmetic uses `Double` with IEEE division (NaN on
  division by zero).
- **Boolean operators** — `and`, `or`, `xor`, `not` operate on integer
  truth values (0 = false, non-zero = true).
- **Relational operators** — `==`, `<>`, `<`, `<=`, `>`, `>=` produce `0`
  or `1`.

### Reduction order

When multiple operators appear in a compute scope, siblings are processed
left-to-right. Addition and multiplication trigger folding; subtraction and
division are deferred unless preceded by a folding operator.

### Type promotion

If any operand in a compute scope is a float, the entire expression is
evaluated as floating-point arithmetic.

---

## Reference

- Test fixtures: `tests/cases/*compute*`
- Source: `src/compute.pas` (arithmetic, relational, boolean operations)
- Source: `src/nodes.pas` (`TComputeNode`, `TIntegerNode.Compute`,
  `TFloatNode.Compute`)
- Manual: [Compute Operator Reference](../../compute/operator-reference.md)
