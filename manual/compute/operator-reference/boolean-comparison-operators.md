# Boolean and Comparison Operators

Boolean and comparison operators reduce to `1` (true) or `0` (false). They work inside compute scope or when targeted by the meta-compute operator `~`. The result is always an integer value.

## Boolean Operators

| Operator | Meaning | Short-circuit |
|---|---|---|
| `and` | Logical AND — truthy only if all operands are truthy | Yes (stops at first falsy) |
| `or` | Logical OR — truthy if any operand is truthy | Yes (stops at first truthy) |
| `xor` | Exclusive OR — truthy if exactly one operand is truthy | No (evaluates all) |

### Truthy and Falsy

A non-zero value is **truthy**; zero is **falsy**. This applies to integers, floats, and imaginary values.

### AND (`and`)

The `and` operator short-circuits on the first falsy operand:

```mantra
{ ~ and 1 2 3 }
```

Expected `OUTPUT`:

```text
1
```

All operands are truthy, so the result is `1`.

```mantra
{ ~ and 1 0 3 }
```

Expected `OUTPUT`:

```text
0
```

The `0` is falsy — evaluation short-circuits there, returning `0`.

### OR (`or`)

The `or` operator short-circuits on the first truthy operand:

```mantra
{ ~ or 0 1 0 }
```

Expected `OUTPUT`:

```text
1
```

The first truthy value (`1`) stops evaluation.

### XOR (`xor`)

`xor` evaluates all operands (no short-circuit) and returns `1` when an **odd**
number of operands are truthy:

```mantra
{ ~ xor 1 0 }
```

Expected `OUTPUT`:

```text
1
```

One truthy operand (odd count) → `1`.

```mantra
{ ~ xor 1 0 1 }
```

Expected `OUTPUT`:

```text
0
```

Two truthy operands (even count) → `0`.

```mantra
{ ~ xor 1 1 1 }
```

Expected `OUTPUT`:

```text
1
```

Three truthy operands (odd count) → `1`.

### NOT (Unary Modifier)

`not` is a unary modifier bit that negates the result of a boolean operator. It
can be combined with any binary boolean operator:

| Combined operator | Meaning |
|---|---|
| `not and` | NAND (negated AND) |
| `not or` | NOR (negated OR) |
| `not xor` | NXOR (negated XOR, equivalence) |

The `not` modifier (`TK_BOOLEAN_NOT` = `$00800000`) occupies the same bit as
`TK_RELATIONAL_NOT`, so it also works with comparison operators to negate the
comparison result.

### Boolean with Floats

Floats follow the same truthy/falsy rules — non-zero is truthy, zero is falsy:

```mantra
{ ~ and 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
0
```

```mantra
{ ~ or 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
1
```

## Comparison Operators

| Operator | Meaning | Example | Result |
|---|---|---|---|
| `<` | Less than | `{ ~ < 1.5 2.0 }` | `1` |
| `<=` | Less than or equal | `{ ~ <= 2.0 2.0 }` | `1` |
| `>` | Greater than | `{ ~ > 3.0 2.0 }` | `1` |
| `>=` | Greater than or equal | `{ ~ >= 2.0 2.0 }` | `1` |
| `==` | Equal | `{ ~ == 2.0 2.0 }` | `1` |
| `!=` | Not equal | `{ ~ != 1.5 2.0 }` | `1` |

### Basic Comparisons

```mantra
{ ~ < 1.5 2.0 }
```

Expected `OUTPUT`:

```text
1
```

```mantra
{ ~ > 3.0 2.0 }
```

Expected `OUTPUT`:

```text
1
```

```mantra
{ ~ >= 2.0 2.0 }
```

Expected `OUTPUT`:

```text
1
```

### Integer Comparisons

Integer comparisons use `Int64` (64-bit signed) values, so they handle large
numbers without overflow:

```mantra
{ ~ < 1 2 }
```

Expected `OUTPUT`:

```text
1
```

```mantra
print { ~> 9223372036854775806 2147483647 }
```

Expected `OUTPUT`:

```text
1
```

`9223372036854775806` (near Int64.MaxValue) is correctly greater than `2147483647`
(Int32.MaxValue). The `~>` syntax combines the tilde meta-compute flag directly
with the comparison operator in a single token.

### Equality and Inequality

```mantra
{ ~ == 2.0 2.0 }
```

Expected `OUTPUT`:

```text
1
```

```mantra
{ ~ != 1.5 2.0 }
```

Expected `OUTPUT`:

```text
1
```

### Chained Comparisons

Chained comparison operators (`< a b c`) evaluate left to right and short-circuit
on the first `false` result. The compute engine walks the right-sibling chain,
comparing each adjacent pair with the same relational operator:

```mantra
{ ~> 10 5 3 }
```

This evaluates `10 > 5` (true) then `5 > 3` (true) → `1`.

If any pair fails, the chain stops and returns `0`. The consumed operands are
deleted from the tree during the fold, leaving only the result.

Boolean operators fold similarly. `and`, `or`, `xor` walk right siblings,
applying the operation cumulatively. The first operand provides the initial
value (`PrevValue <> 0` → boolean); each subsequent operand is folded in.

### Tilde-Combined Syntax

The `~` meta-compute flag can be combined directly with comparison operators
in a single token:

| Token | Meaning |
|---|---|
| `~<` | Tilde + less than |
| `~<=` | Tilde + less than or equal |
| `~>` | Tilde + greater than |
| `~>=` | Tilde + greater than or equal |
| `~==` | Tilde + equal |
| `~!=` | Tilde + not equal |

This is equivalent to `~ <` with a space — the tokenizer handles both forms.

## How It Works

### Compute Dispatch

When compute is triggered (by `~` or backtick scope), the runtime dispatches
based on the operator type:

1. **Comparison operators** — `ComputeRelational` uses the `TRelationalOps`
   record (`OPS_RELATIONAL_INT` for integers, `OPS_RELATIONAL_FLOAT` for floats)
   to perform the comparison.
2. **Boolean operators** — `ComputeBoolean` applies standard boolean logic
   (`and`, `or`, `xor`) on truthy/falsy values.

### Type Resolution

The compute engine selects the operation table based on the head node's type:

- `TIntegerNode.Compute` → `OPS_RELATIONAL_INT` (Int64 comparisons)
- `TFloatNode.Compute` → `OPS_RELATIONAL_FLOAT` (Double comparisons)

### Token Structure

Boolean and comparison operators share the same bit position in the token ID
(bits 31-24, the META byte):

- Comparison operators: `TK_RELATIONAL_*` constants
- Boolean operators: `TK_BOOLEAN_*` constants (plus `TK_BOOLEAN_OP` = `$00100000`)
- The `not` modifier: `TK_BOOLEAN_NOT` = `$00800000` (same as `TK_RELATIONAL_NOT`)

## Related Pages

- [Basic Floats](../float-arithmetic/basic-floats.md)
- [Mixed Numeric Forms](../float-arithmetic/mixed-numeric-forms.md)
- [Addition and Multiplication](../integer-arithmetic/addition-multiplication.md)
- [Meta-Compute Operator](../meta-compute-operator.md)
- [Supported Reductions](../compute-scope/supported-reductions.md)
