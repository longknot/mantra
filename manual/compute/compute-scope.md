# Compute Scope

Compute scope is a backtick-delimited block that tells the runtime to **reduce
arithmetic operators** inside its contents. It is the primary way to trigger
numeric computation in Mantra.

```mantra
` expression `
```

Without compute scope, Mantra treats expressions as symbolic trees — operators
and operands coexist but are never reduced. Compute scope forces that reduction
to happen.

## How It Works

During evaluation, the runtime processes a compute scope in three steps:

1. **Evaluate children** — `inherited Evaluate(Context)` walks the subtree,
   resolving variables, collapsing nested evaluation scopes, and processing any
   `~` (tilde) meta flags on descendant nodes.
2. **Compute the result** — `Node[LHS].Compute(Context)` triggers the compute
   engine on the first child. The compute engine walks operators and their
   operands, performing arithmetic reduction for any supported operation.
3. **Collapse the scope** — `GlobalTree.Expand(PrevIndex, Index)` removes the
   backtick wrapper, leaving only the computed contents in the tree.

The net effect: everything inside `` ` ... ` `` is evaluated, then computed,
then the backticks disappear.

## Basic Examples

### Simple Addition

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

The `+` operator and its operands are summed to a single result.

### Addition Inside a List

```mantra
`[ + 1 2 3 ]`
```

Output:

```text
[ + 6 ]
```

### Repeat Inside Compute Scope

```mantra
`[ + 1 2 3 ] : 3`
```

Output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

Step by step:

1. The compute scope evaluates children first.
2. Compute runs on `[ + 1 2 3 ]`, reducing `+ 1 2 3` to `+ 6`.
3. The `: 3` repeat produces three copies of `[ + 6 ]`.

## Compute Triggers

Mantra provides two ways to trigger compute:

| Trigger | Syntax | Scope |
|---|---|---|
| Compute scope | `` ` expression ` `` | Everything inside the backticks |
| Meta-compute operator | `~ expression` | A single node or subtree |

Use compute scope when you want to compute an entire block. Use `~` when you
need to target a specific node inside an evaluation scope. See
[Meta-Compute Operator](meta-compute-operator.md) for details on `~`.

## Compute Scope vs. No Compute

Without a compute trigger, expressions remain symbolic:

```mantra
[ + 1 2 3 ]
```

Output:

```text
[ + 1 + 2 + 3 ]
```

The same expression inside compute scope is reduced:

```mantra
`[ + 1 2 3 ]`
```

Output:

```text
[ + 6 ]
```

## Variables Inside Compute Scope

Variables resolve to tree snapshots. When a variable appears inside compute
scope, the resolved tree is computed:

```mantra
x = [ + 1 2 3 ]
`x`
```

Output:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The variable `x` is stored as the unreduced tree `[ + 1 + 2 + 3 ]`. When
referenced inside `` ` ... ` ``, the stored tree is cloned and then computed,
producing `[ + 6 ]`.

## Nested Compute Scopes

Compute scopes can nest. The inner scope computes first:

```mantra
` + ` 1 2 ` 3 `
```

Output:

```text
+ 6
```

## Compute Scope with Evaluation Scope

Compute scope inherits from evaluation scope (`TEvaluationNode`), so it supports
all evaluation features -- variable resolution, repeat expansion, and selection
rewriting -- in addition to arithmetic reduction:

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Output:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

Step by step:

1. The evaluation scope `{ ... }` processes its children.
2. Inside, `+ 1 + 2 + 3` is not in compute scope, so it stays symbolic.
3. The `: 2` repeat clones the inner expression twice.
4. Wait -- actually, the backtick `` `+ 1 + 2 + 3` `` computes first, reducing
   to `+ 6`. Then `: 2` repeats `+ 6` twice: `+ 6 + 6`.
5. The outer `: 3` repeats `[ + 6 + 6 ]` three times.

## Compute Scope with Mixed Types

When integers and floats appear together in a compute scope, the result
promotes to the widest type:

```mantra
` + 1 2.5 3 `
```

Output:

```text
+ 6.5
```

## Boolean Operations in Compute Scope

Boolean operators reduce inside compute scope. Truth values are `1` (true) and
`0` (false):

### AND

```mantra
` and 1 2 3 `
```

Output:

```text
1
```

All operands are nonzero, so the result is `1` (true).

### OR

```mantra
` or 0 0 3 `
```

Output:

```text
1
```

At least one operand is nonzero, so the result is `1` (true).

### XOR

```mantra
` xor 1 0 `
```

Output:

```text
1
```

## Comparison Operators in Compute Scope

Comparison operators return `1` (true) or `0` (false):

```mantra
` > 5 3 `
```

Output:

```text
1
```

```mantra
` < 5 3 `
```

Output:

```text
0
```

## What Compute Scope Cannot Do

Compute scope only reduces **supported operations**. If an operator or operand
type has no compute implementation, it passes through unchanged:

- Unknown identifiers are not computed (they may resolve as variables or
  native functions).
- Structural operators (`?`, `=>`, `&`) are not reduced by compute scope --
  they require evaluation scope with their own semantics.
- Fixed nodes (marked with `\\`) are protected from computation even inside
  compute scope.

## Runtime Behavior

### Scope Collapse

After compute completes, the backtick scope is always removed from the tree via
`GlobalTree.Expand`. This means the backticks are a **processing directive**,
not a persistent container. The output contains only the computed result.

### Single-Pass Computation

Compute scope fires the compute engine once. Unlike the `~` meta flag, which
is consumed and cleared after a single use, compute scope triggers compute as
part of its standard evaluation lifecycle -- the flag is the scope type itself,
not a bit on a node.

### Inheritance from Evaluation Node

`TComputeNode` inherits from `TEvaluationNode`. This means a compute scope
first evaluates its contents (resolving variables, processing nested scopes,
handling `~` flags) before running the compute engine. The evaluation step
ensures that all dynamic references are resolved before numeric reduction
begins.

## Common Patterns

### Computing with Repeat

Combine repeat (`:`) with compute scope to generate sequences of computed
values:

```mantra
`[ + 1 2 3 ] : 3`
```

Output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

### Computing After Variable Assignment

Store an unreduced expression, then compute it later:

```mantra
x = + 10 20
print `x`
```

Output:

```text
+ 30
```

### Nested Compute and Repeat

Compute the result of a repeat operation:

```mantra
`[ + 1 2 : 4 ]`
```

The repeat `+ 1 2 : 4` produces `+ 1 2 + 1 2 + 1 2 + 1 2`, which then computes
to `+ 8` (all values under `+` are summed).

Output:

```text
[ + 8 ]
```

### Compute Scope with Print

Use `print` with compute scope for explicit output:

```mantra
print `* 3 4`
```

Output:

```text
* 12
```

## See Also

- [Meta-Compute Operator](meta-compute-operator.md) -- The `~` tilde flag for
  targeted subtree computation
- [Integer Arithmetic](integer-arithmetic.md) -- Integer operations supported
  by the compute engine
- [Float Arithmetic](float-arithmetic.md) -- Float operations and type
  promotion
- [Supported Reductions](compute-scope/supported-reductions.md) -- Full list of
  reduction families
- [Eval Option](compute-scope/eval-option.md) -- Using `--eval=EXPR` for
  command-line experiments
- [Operator Reference](operator-reference.md) -- All operators and their
  categories
