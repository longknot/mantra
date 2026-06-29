# Compute and Operators

Mantra programs are tree structures. By default, operators like `+`, `-`, `*`,
`/` and their operands remain **symbolic** — they are formatted as tree nodes
but not reduced to numeric results. Compute is the mechanism that turns symbolic
expressions into computed values.

## Symbolic vs Computed

The same expression behaves differently depending on context:

```mantra
[ + 1 2 3 ]
```

OUTPUT (symbolic — no compute trigger):

```text
[ + 1 + 2 + 3 ]
```

```mantra
`[ + 1 2 3 ]`
```

OUTPUT (computed — inside backtick scope):

```text
[ + 6 ]
```

Without a compute trigger, the formatter renders the tree structure: the `+`
operator is shown before each sibling operand. With a compute trigger, all
operands under `+` are summed into a single result.

## How Compute Is Triggered

There are two ways to ask the runtime to reduce an expression:

| Trigger | Syntax | Scope |
| --- | --- | --- |
| **Compute scope** | `` ` ... ` `` | Wraps an entire expression block |
| **Meta-compute (tilde)** | `~ node` | Targets a single node or subtree |

Backtick scopes compute everything inside them. The tilde `~` meta-flag
computes only the specific node it prefixes, making it useful for selective
reduction inside evaluation scopes or larger trees.

```mantra
{ ~ + 1 2 3 }
```

OUTPUT:

```text
+ 6
```

The evaluation scope `{ ... }` alone would not reduce the arithmetic. The tilde
forces compute on just the `+` node.

## What Compute Supports

The compute engine handles several numeric families, each with its own reduction
rules:

| Type | Operators | Details |
| --- | --- | --- |
| **Integer** | `+`, `-`, `*`, `/` | 64-bit signed (`Int64`) |
| **Float** | `+`, `-`, `*`, `/` | Floating-point with mixed-type promotion |
| **Boolean** | `and`, `or`, `xor` | Truth values as `1` (true) / `0` (false) |
| **Comparison** | `<`, `<=`, `>`, `>=`, `=` | Return `1` or `0` |
| **Imaginary** | `+`, `*`, `/` | Suffixes `i`, `j`, `k` for quaternion axes |
| **Functions** | `sin`, `cos`, `tan`, `sqrt`, `floor`, `ceil`, `round`, ... | Math functions with domain checking |

When operands span integer and float, the result promotes to the widest type.
Imaginary values are grouped by component (real, `i`, `j`, `k`) into separate
buckets that combine independently.

## Compute Triggers in Detail

### Backtick Compute Scope

Backticks wrap an expression and mark the entire contents as computable:

```mantra
` + 1 2 3 `
```

All supported operators inside the scope are reduced. The backtick scope itself
collapses during formatting.

### Tilde Meta-Compute

The `~` prefix on any node triggers compute on that node and its descendants,
even outside backtick scope. The flag is consumed after use — it fires once per
evaluation pass. This is essential for computing inside evaluation scopes, after
variable resolution, or when only specific parts of a tree should reduce.

### Fixed Protection

The `\` (backslash) meta-flag and `' ... '` (single-quote) fixed scopes
protect subtrees from computation. A fixed node inside a compute scope stays
symbolic while its siblings are still reduced.

## Where This Fits

Compute is one stage of the evaluation pipeline:

1. **Parse** — source text becomes an AST
2. **Execute/Evaluate** — variables resolve, repeats expand, selections rewrite
3. **Compute** — arithmetic reduces inside backtick scope or under tilde
4. **Format** — the result tree becomes output text

See [Evaluation Model](../language-model/evaluation-model.md) for the full
pipeline and [Evaluation vs Compute](../language-model/evaluation-model/evaluation-vs-compute.md)
for the distinction between structural evaluation and arithmetic reduction.

## Topics

### Scopes and Triggers

- [Compute Scope](compute-scope.md) — Backtick scopes, supported reductions, and
  the `--eval` CLI option
- [Meta-Compute Operator](meta-compute-operator.md) — The `~` tilde flag: how it
  works, placement, combining with backticks, and runtime behavior
- [Symbolic and Non-Computed Forms](symbolic-non-computed-forms.md) — When and
  why expressions remain symbolic: no compute scope, unsupported operators,
  non-numeric operands, fixed scopes, and how to make them computable

### Numeric Types

- [Integer Arithmetic](integer-arithmetic.md) — Addition, subtraction,
  multiplication, and division with 64-bit signed integers, operator combining
  rules, unary operations, and overflow behavior
- [Float Arithmetic](float-arithmetic.md) — Floating-point operations with
  mixed-type promotion from integer
- [Boolean and Comparison](boolean-comparison.md) — Truth values, boolean logic
  (`and`, `or`, `xor`), and comparison operators (`<`, `>`, `<=`, `>=`, `=`)
- [Imaginary and Quaternion Forms](imaginary-quaternion.md) — Quaternion
  arithmetic with `i`, `j`, `k` suffixes: bucket-based addition, multiplication,
  and inversion

### Operators

- [Operator Reference](operator-reference.md) — Arithmetic operators, boolean and
  comparison operators, and structural operators with examples
