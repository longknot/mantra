# Meta-Compute Operator

The `~` (tilde) meta flag targets **compute behavior** at a specific node or
subtree. It forces arithmetic reduction on its target even when the target
appears outside a backtick compute scope.

## Overview

Mantra separates evaluation from compute. Evaluation scope (`{ ... }`) applies
structural transformations -- variable substitution, repeat expansion, selection
rewriting. Compute scope (`` ` ... ` ``) reduces arithmetic operators to numeric
results.

The `~` meta flag bridges these two layers. When you prefix any expression with
`~`, you tell the runtime: **compute this subtree right now**, regardless of
what scope surrounds it.

```mantra
{ ~ + 1 2 3 }
```

Output:

```text
+ 6
```

Without `~`, the evaluation scope `{ ... }` would process structural transforms
but leave `+ 1 2 3` unreduced. With `~`, the `+` operator is computed to `6`
inside the evaluation scope.

## How It Works

During evaluation, the runtime dispatches through `Evaluate` -> `Compute`. After
`DoEvaluate` runs on a node, the runtime checks whether the `TK_TILDE` bit is
set on that node's data. If it is, the runtime immediately invokes the node's
`Compute` method to reduce any supported arithmetic operators, then clears the
tilde flag so the computation happens exactly once.

The flag is **consumed** after it triggers -- once compute fires, the `~` bit
is cleared. This prevents the same subtree from being computed twice during
recursive evaluation.

## Basic Usage

### Compute Inside Evaluation Scope

The most common pattern: force compute inside an evaluation scope that
normally wouldn't trigger arithmetic reduction.

```mantra
[ { ~ + 1 2 3 } ]
```

Output:

```text
[ + 6 ]
```

The evaluation scope `{ ... }` collapses, and the tilde forces `+ 1 2 3` to
reduce to `+ 6` before the scope disappears.

### Compute With Variable Lookup

Variables store tree snapshots. When a variable resolves to an arithmetic
expression, `~` forces that expression to compute.

```mantra
x = + 1 2
print { ~ x }
```

Output:

```text
+ 3
```

Without `~`, the variable `x` would resolve to the tree `+ 1 2`, but the
evaluation scope wouldn't reduce the arithmetic. With `~`, the resolved
expression is computed to `+ 3`.

## Targeted Subtree Computation

`~` can target different levels of the tree. The scope of the tilde depends on
what node it directly prefixes.

### Tilde on a Single Operator Node

When `~` prefixes an operator node, only that operator and its immediate
operands are computed:

```mantra
[ { [ ~ + 1 2 3 : 2 ] : 3 } ]
```

Output:

```text
[ [ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ] ]
```

Step by step:

1. The inner repeat `~ + 1 2 3 : 2` -- the `~` is on the `+` node, so `+ 1 2
   3` computes to `6`. The `: 2` repeats the result `+ 6` twice, producing
   `+ 6 + 6`.
2. The outer `: 3` repeats `+ 6 + 6` three times, each wrapped in brackets.

### Tilde on a Bracket Group

When `~` prefixes a bracket group, the entire group is computed as a unit:

```mantra
[ { ~ [ + 1 2 3 : 2 ] : 3 } ]
```

Output:

```text
[ [ + 12 ] [ + 12 ] [ + 12 ] ]
```

Step by step:

1. The inner `+ 1 2 3 : 2` repeats `+ 1 2 3` twice: `+ 1 2 3 + 1 2 3`.
2. The `~` on the bracket `[ ... ]` forces the entire group to compute: all
   operands under `+` are summed, so `1 + 2 + 3 + 1 + 2 + 3 = 12`, yielding
   `+ 12`.
3. The outer `: 3` repeats `+ 12` three times, each in brackets.

The difference is subtle but important: tilde on the operator computes first,
then repeats. Tilde on the group repeats first, then computes the entire
result.

## Comparison: Tilde Placement

| Placement | Input | Output |
|---|---|---|
| `~` on `+` | `[ { [ ~ + 1 2 3 : 2 ] : 3 } ]` | `[ [ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ] ]` |
| `~` on `[` | `[ { ~ [ + 1 2 3 : 2 ] : 3 } ]` | `[ [ + 12 ] [ + 12 ] [ + 12 ] ]` |

In the first case, `+ 1 2 3` is computed to `6` **before** repeating. Each
repeat produces `+ 6`, and three groups of two `+ 6` remain separate.

In the second case, the repeat happens **before** computing. The bracket
contains `+ 1 2 3 + 1 2 3`, which computes to `+ 12`. Three copies of `+ 12`
are produced.

## Supported Operators

The `~` flag triggers the same compute engine as backtick scopes. Any operator
supported by compute scope will reduce when prefixed with `~`:

- **Arithmetic**: `+`, `-`, `*`, `/`
- **Comparisons**: `<`, `>`, `<=`, `>=`, `=`
- **Boolean**: `and`, `or`, `xor`
- **Mathematical functions**: `sin`, `cos`, `tan`, `floor`, `ceil`, `round`,
  `sqrt`, etc.

### With Integer Arithmetic

```mantra
[ { ~ - 10 3 } ]
```

Output:

```text
[ - 7 ]
```

### With Float Arithmetic

```mantra
[ { ~ * 2.5 4 } ]
```

Output:

```text
[ * 10 ]
```

### With Comparison Operators

```mantra
[ { ~ > 5 3 } ]
```

Output:

```text
[ > 1 ]
```

Comparison operators return `1` for true and `0` for false.

## Tilde vs Backtick Compute Scope

Both `~` and backticks trigger compute, but they differ in scope and placement:

| Feature | `~` (tilde) | `` ` `` (backtick) |
|---|---|---|
| Syntax | Prefixes a single node or subtree | Wraps an expression in a scope |
| Scope | Targets exactly one node/group | Wraps everything inside the scope |
| Placement | Inside any scope | Standalone construct |
| Flag consumed | Yes -- cleared after compute | N/A -- scope collapses naturally |
| Use case | Precise targeting within a tree | Broad compute of an entire block |

### When to Use Each

- Use **`~`** when you need to compute a specific node inside an evaluation
  scope or when you want fine-grained control over which subtree gets computed.
- Use **`` ` ``** when you want to compute an entire expression block.

### Combining `~` with Backtick

You can nest `~` inside a backtick scope for even more control:

```mantra
`[ { ~ + 1 2 3 : 2 } : 3]`
```

Output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The backtick scope handles the outer repeat, while `~` ensures the inner
arithmetic is computed.

## Fixed Nodes and Tilde

The `\\` (backslash) fixed flag protects a node from transformation. If a node
carries the `TK_FIXED` flag, the compute engine skips that node and recurses
only into its siblings. This means you can shield specific parts of a subtree
from being computed:

```mantra
[ { ~ + 1 \\ 2 3 } ]
```

The `2` is protected from computation. The tilde still recurses into siblings,
so the unreduced `+ 1 2 3` structure is preserved where the fixed node sits.

## Tilde in Selection Rules

When used inside selection rewrite rules, `~` ensures that matched and replaced
expressions are computed:

```mantra
[ 1 2 3 ] ? [ x ~ => x + 1 ]
```

The tilde on the replacement forces the arithmetic `x + 1` to compute for each
matched value.

## Runtime Behavior

### Flag Consumption

The `TK_TILDE` flag is set in the high byte of a node's `Data` field. After the
runtime triggers compute on that node, it clears the flag with an XOR operation.
This ensures the computation fires exactly once per evaluation pass.

### Fixed/Unfix Gating

The compute method first checks for `TK_UNFIX` and `TK_FIXED` flags. If a node
is fixed, compute skips it and only recurses into its right siblings. This
provides fine-grained control over which parts of a tree participate in
reduction.

### Recursive Compute

When `~` is placed on a parent node, compute recurses into all children by
default. This means `~ + 1 2 3` will compute the entire `+` chain, not just the
head operator.

## Common Patterns

### Computing Repeat Results

Force compute on the result of a repeat operation:

```mantra
[ { ~ [ + 1 2 : 4 ] } ]
```

The repeat produces `+ 1 2 + 1 2 + 1 2 + 1 2`, which then computes to `+ 8`
(all values under `+` are summed).

### Selective Compute in Mixed Expressions

Use `~` to compute only certain parts of a larger expression:

```mantra
[ { + ~ - 10 3 ~ * 2 3 } ]
```

The `- 10 3` computes to `7` and `* 2 3` computes to `6`, while the outer `+`
combines them.

### Computing After Variable Resolution

Variables store unreduced tree snapshots. Use `~` to force computation after
resolution:

```mantra
x = + 10 20 30
y = * 2 3
print { ~ + x y }
```

Both `x` and `y` resolve to their tree forms, and `~` forces the combined
expression to compute.

## See Also

- [Meta Flags](../syntax/meta-flags.md) -- All meta flags (`~`, `\\`, `$`, `^`, `.`, `@`)
- [Compute Scope](compute-scope.md) -- Backtick compute scope
- [Evaluation vs Compute](../language-model/evaluation-model/evaluation-vs-compute.md) -- The evaluation/compute distinction
- [Operator Reference](operator-reference.md) -- All supported operators
