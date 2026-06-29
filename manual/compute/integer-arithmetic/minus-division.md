# Minus and Division in Compute

Minus (`-`) and division (`/`) behave differently from addition (`+`) and
multiplication (`*`) in Mantra's compute system. They are **not reduction
triggers** — they participate in arithmetic through unary negation, reciprocal
inversion, and combined operator folding. This means they can accumulate
sign/inversion state without immediately collapsing to a single numeric result,
and they interact with `+` and `*` through a structured combine table.

## Quick Reference

| Behavior | Example | Output |
|---|---|---|
| Unary minus (negation) | `{ ~ - ( 3 ) }` | `- 3` |
| Double minus cancellation | `{ ~ - ( - 3 ) }` | `+ 3` |
| Minus chain (no collapse) | `{ ~- 10 2 3 }` | `- 10 - 2 - 3` |
| Plus-minus combination | `{ ~ + 1 2 3 - 1 2 3 }` | `+ 0` |
| Unary division (reciprocal) | `{ ~ / 8.0 }` | `+ 0.125` |
| Wrapped division | `{ ~ / ( 2.0 ) }` | `+ 0.5` |
| Mixed plus-division | `{ ~ + / 8.0 2 }` | `+ 0.625` |
| Nested recursive division | `~ { + 2.0 / ( + 1.0 / ( ... ) ) : 3 }` | `+ 2.73333333333334` |

## Minus: Negation and Chaining

### Unary Minus

When `-` appears with the `~` meta-compute flag and a single operand, it
negates the value:

```mantra
{ ~ - ( - 3 ) }
```

Expected `OUTPUT`:

```text
+ 3
```

The inner `- 3` negates to `-3`, and the outer `-` negates again, producing
`+ 3`. Double negation always cancels.

### Minus Chains

Unlike `+` and `*`, minus does **not** trigger immediate binary reduction. When
multiple minus signs appear in sequence, they accumulate without collapsing:

```mantra
{ ~- 10 2 3 }
```

Expected `OUTPUT`:

```text
- 10 - 2 - 3
```

The output shows the minus signs distributed across operands. The runtime tracks
the minus state in the operator token's bit flags rather than performing
sequential subtractions.

### Minus Combined with Plus

When `+` and `-` appear together, the runtime uses its operator combine table to
determine the result. The `+` acts as the reduction trigger, while `-`
contributes sign information:

```mantra
{ ~ + 1 2 3 - 1 2 3 }
```

Expected `OUTPUT`:

```text
+ 0
```

Here `+ 1 2 3` accumulates to `6`, and `- 1 2 3` also accumulates to `6` with a
negation flag. The combine table resolves `+` with `-` through addition where
one operand has been negated: `6 + (-6) = 0`.

### Float Minus with Plus

Minus also works with float operands, applying sign inversion during the
combine step:

```mantra
{ ~ + - 1.5 2.5 }
```

Expected `OUTPUT`:

```text
- 4
```

The `-` flag applies to the accumulated value, and the combine logic with `+`
produces the negated result.

### Minus in Selection Context

Minus can appear outside compute scope in selection expressions. When combined
with selection policies, it operates on matched values:

```mantra
print { - selector first [ 1 ] ? [ [ x ] => 10, [ x ] => 20 ] }
```

Expected `OUTPUT`:

```text
10
```

The selection applies the `first` policy, matching `[ 1 ]` with `[ x ] => 10`,
yielding `10`. The `-` prefix here is part of the expression structure rather
than a compute negation.

## Division: Reciprocals and Inversion

### Unary Division as Reciprocal

When `/` appears with `~` and a single operand, it computes the reciprocal
(1 divided by the value):

```mantra
{ ~ / 8.0 }
```

Expected `OUTPUT`:

```text
+ 0.125
```

The result is `1 / 8.0 = 0.125`, displayed with a `+` prefix indicating a
positive float value.

### Wrapped Division

Division on a grouped expression also produces a reciprocal:

```mantra
{ ~ / ( 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

The grouping ensures the entire expression `2.0` is treated as the operand for
reciprocal computation: `1 / 2.0 = 0.5`.

### Division with Explicit Plus

Adding an explicit `+` inside the grouped operand does not change the result:

```mantra
{ ~ / ( + 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

The `+` inside the group is a no-op for a single value, so the reciprocal of
`2.0` is still `0.5`.

### Mixed Plus and Division

When `+` and `/` appear together, the combine table resolves them through a
combination of inversion and addition:

```mantra
{ ~ + / 8.0 2 }
```

Expected `OUTPUT`:

```text
+ 0.625
```

The `/` applies reciprocal inversion to `8.0` (yielding `0.125`), and the
combine logic with `+` and operand `2` produces `0.625`. The exact arithmetic
follows the operator combine table where the unary operations are applied before
the binary step.

### Nested Recursive Division

Division participates in recursive fixpoint computation via `...`. Nested
reciprocal computations accumulate through repeat:

```mantra
~ { + 2.0 / ( + 1.0 / ( ... ) ) : 3 }
```

Expected `OUTPUT`:

```text
+ 2.73333333333334
```

The `: 3` repeat clones the expression three times. Each iteration applies the
reciprocal of the nested `...` (empty scope cleanup), building the accumulated
result through the combine table.

### Division by Zero

Division by zero is handled differently for integers and floats:

- **Integer division** raises an exception (`Division by zero`).
- **Float division** produces `NaN` (not-a-number).

The `IntInv` procedure explicitly checks for zero before computing `1 div X`,
while `FloatDiv` returns `0/0` (NaN) when the denominator is `0.0`.

## How the Combine Table Works

Minus and division operators carry state in token bit flags rather than
immediately reducing. The runtime uses a combine lookup table (LUT) to resolve
what happens when two arithmetic operators meet:

| y (x) | . | + | - | * | / |
|---|---|---|---|---|---|
| . | . | + | - | * | / |
| + | + | + | - | + | / |
| - | - | - | + | - | -/ |
| * | * | * | -* | * | */ |
| / | / | / | -/ | / | + |

Key patterns:
- `+` combined with `-` applies negation during addition.
- `-` combined with `-` cancels to `+`.
- `/` combined with `/` cancels to `+` (double reciprocal).
- `*` combined with `/` produces `*/` (multiply with inversion).
- The `+` and `*` operators are the **reduction triggers** — they force binary
  combination. Minus and division accumulate state until a trigger appears.

### Operator Bit Flags

Each operator token carries flags in its upper bytes:

```
[31..24] META | [23..16] RESERVED | [15..8] OPERATOR | [7..0] ID
```

The operator byte encodes accumulated minus/division state:

| Value | Meaning |
|---|---|
| `$0` | No accumulated operator |
| `$1` | Plus |
| `$2` | Minus |
| `$4` | Multiply |
| `$8` | Divide |
| `$6` | Minus + Multiply |
| `$A` | Minus + Divide |
| `$C` | Multiply + Divide |
| `$E` | Minus + Multiply + Divide |

When `TryCombineBinary` processes two operands, it first applies unary
operations (`Neg` for minus, `Inv` for division) to each value, then performs
the binary operation (`Mul` or `Add` depending on whether multiply is present).

## Reduction Triggers

The compute system distinguishes between **reduction triggers** and
**state-carrying** operators:

- **Reduction triggers** (`+`, `*`): Force immediate binary combination when
  two trigger-flagged operands meet.
- **State carriers** (`-`, `/`): Modify the sign or apply inversion without
  forcing reduction. They accumulate in the operator flags until a trigger
  resolves them.

This is why `{ ~- 10 2 3 }` produces `- 10 - 2 - 3` (no trigger, so no
collapse) while `{ ~ + 1 2 3 - 1 2 3 }` produces `+ 0` (the `+` triggers the
combination).

You can test whether an operator is a reduction trigger using the runtime
function `IsReductionTrigger(Op)` — it returns true only for `+` and `*`.

## Unary Operations

Both minus and division have dedicated unary procedures:

| Operation | Integer | Float |
|---|---|---|
| Negation (`-`) | `IntNeg(X) = -X` | `FloatNeg(X) = -X` |
| Inversion (`/`) | `IntInv(X) = 1 div X` | `FloatInv(X) = 1.0 / X` |

These are called by `ComputeUnary` during the combine step. When an operator
token has the `TK_MINUS` flag set, `Neg` is applied. When it has the
`TK_DIVIDE` flag set, `Inv` is applied. Both can be present simultaneously.

## Common Patterns

### Negating a Computed Sum

To negate the result of a sum, prefix with `-`:

```mantra
{ ~ - ( + 1 2 3 ) }
```

Expected `OUTPUT`:

```text
- 6
```

### Alternating Signs

Minus chains can create alternating sign patterns when combined with repeat:

```mantra
{ ~ - 1 : 3 }
```

This repeats the negated value, producing multiple negated instances.

### Reciprocal of a Sum

Wrap a sum in parentheses before applying division:

```mantra
{ ~ / ( + 2 3 ) }
```

Expected `OUTPUT`:

```text
+ 0.2
```

The sum `2 + 3 = 5` is computed first, then the reciprocal `1 / 5 = 0.2`.

### Integer Division

Integer division uses Pascal's `div` operator, which truncates toward zero:

```mantra
print { ~ / 7 2 }
```

Expected `OUTPUT`:

```text
3
```

`7 div 2 = 3` (integer truncation, not rounding).

## Pitfalls

### Minus Does Not Trigger Reduction

Unlike `+` and `*`, minus alone will not collapse multiple operands into a
single value. If you expect `{ ~ - 10 2 3 }` to produce a single number like
`5`, it will not — it distributes the minus signs instead. Use explicit
grouping or combine with `+` to force reduction.

### Division by Zero Behavior

Integer division by zero raises an exception that stops execution. Float
division by zero silently produces NaN. Always guard against zero denominators
in production code.

### Operator Order Matters

The combine table is not commutative in all cases. `+` combined with `-` may
produce different intermediate flags than `-` combined with `+`, even though
the final numeric result may be equivalent. The combine LUT uses specific bit
positions that depend on operand order.

### Unary Division Is Reciprocal, Not Subtraction

A common mistake is to expect `/ 8.0` to subtract or divide in a binary sense.
In Mantra's compute model, unary `/` always means reciprocal (1/x). For binary
division, use explicit grouping or combine with other operators through the
fold table.

## Related Pages

- [Addition and Multiplication](addition-multiplication.md) — The reduction
  triggers that force binary combination
- [Integer Arithmetic](../integer-arithmetic.md) — Overview of integer compute
- [Float Arithmetic](../float-arithmetic.md) — Float-specific compute behavior
- [Arithmetic Operators](../operator-reference/arithmetic-operators.md) — Full
  operator reference
- [Meta-Compute Operator](../meta-compute-operator.md) — The `~` operator that
  targets compute at a node
