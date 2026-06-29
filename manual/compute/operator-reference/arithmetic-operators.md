# Arithmetic Operators

Arithmetic operators reduce numeric operands to computed results inside **compute scope** (`` ` ... ` ``) or when targeted by the **meta-compute operator** `~`. Without a compute trigger, they remain as symbolic tree structures.

## Quick Reference

| Operator | Meaning | Form | Example | Output |
|---|---|---|---|---|
| `+` | Addition | Prefix variadic | `{ ~ + 1 2 3 }` | `+ 6` |
| `*` | Multiplication | Prefix variadic | `{ ~ * 3 4 }` | `* 12` |
| `-` | Negation / subtraction | Prefix | `{ ~ - 5 }` | `- 5` |
| `/` | Division / reciprocal | Prefix | `{ ~ / 8.0 }` | `+ 0.125` |

## Reduction Triggers

Arithmetic operators need one of two triggers to reduce:

- **Meta-compute operator** `~` — targets a specific node for computation
- **Compute scope** `` ` ... ` `` — marks an entire expression as computable

### Symbolic vs. Computed

Without compute scope, operators preserve their tree structure:

```mantra
[ + 1 2 3 ]
```

Expected `OUTPUT`:

```text
[ + 1 + 2 + 3 ]
```

With compute scope, the same expression reduces:

```mantra
{ ~ + 1 2 3 }
```

Expected `OUTPUT`:

```text
+ 6
```

## Addition (`+`)

The `+` operator is **variadic** — it accepts any number of numeric operands and sums them left to right. It is a **reduction trigger**: when two `+`-flagged operands meet, they combine immediately.

### Basic Addition

```mantra
{ ~ + 1 2 3 }
```

Expected `OUTPUT`:

```text
+ 6
```

### Multiple Backtick Scopes

Each backtick scope is independent — they reduce separately:

```mantra
[ ` + 1 2 ` ` + 3 4 ` ]
```

Expected `OUTPUT`:

```text
[ + 3 + 7 ]
```

### Addition with Repeat

When addition is inside a repeated structure, each copy reduces independently:

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

### Large Integer Addition

Addition supports Int64 values — operands and results can exceed the 32-bit signed range:

```mantra
{ ~ + 2147483647 1 }
```

Expected `OUTPUT`:

```text
+ 2147483648
```

### Addition with Variables

When a variable holds an arithmetic tree, wrapping it in compute scope triggers reduction:

```mantra
x = [ + 1 2 3 ]
`x`
```

Expected `OUTPUT`:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

See [Addition and Multiplication](integer-arithmetic/addition-multiplication.md) for the full treatment of addition with nested expressions, repeat, and variables.

## Multiplication (`*`)

The `*` operator is **variadic** — it multiplies all operands left to right. Unlike addition, it is **not** a reduction trigger: two `*`-flagged operands do not combine automatically.

### Basic Multiplication

```mantra
{ ~ * 3 4 }
```

Expected `OUTPUT`:

```text
* 12
```

### Variadic Multiplication

```mantra
{ ~ * 2 3 4 }
```

Expected `OUTPUT`:

```text
* 24
```

### Large Integer Multiplication

Int64 multiplication handles values beyond 32-bit range:

```mantra
{ ~ * 3037000499 2 }
```

Expected `OUTPUT`:

```text
* 6074000998
```

### Mixed Float and Integer

When a float appears among operands, the integer promotes to float and the result is a float:

```mantra
{ ~ * 1.5 2 }
```

Expected `OUTPUT`:

```text
* 3
```

The product `3.0` formats as `* 3` (compact whole-number form).

See [Addition and Multiplication](integer-arithmetic/addition-multiplication.md) for multiplication with repeat, nested expressions, and symbolic variables.

## Negation and Subtraction (`-`)

The `-` operator handles **unary negation** and **subtraction**. Behavior depends on operand count:

- **Single operand** — negates the value
- **Two operands** — subtracts the second from the first (but note: the output preserves the `-` operator flag with both operands visible)
- **Multiple operands** — chains subtraction left to right

### Unary Negation

```mantra
{ ~ - ( 5 ) }
```

Expected `OUTPUT`:

```text
- 5
```

### Double Negation

```mantra
{ ~ - ( - 5 ) }
```

Expected `OUTPUT`:

```text
+ 5
```

Two negations cancel to produce a positive result.

### Negation as Operand

A negated value can be an operand of addition:

```mantra
{ ~ + - 1.5 2.5 }
```

Expected `OUTPUT`:

```text
- 4
```

The minus operator applies unary negation to the accumulated sum `1.5 + 2.5 = 4`, producing `- 4`.

### Multi-Operand Subtraction

```mantra
{ ~ - 10 3 2 }
```

Expected `OUTPUT`:

```text
- 10 3 2
```

Note: When `-` has multiple operands, the output preserves the operator and operands rather than computing a single result. The `-` operator does not reduce multi-operand chains the same way `+` does.

### Subtraction with Float Results

```mantra
{ ~ - 5.5 2.2 }
```

Expected `OUTPUT`:

```text
- 5.5 2.2
```

See [Minus and Division](integer-arithmetic/minus-division.md) for the complete treatment of negation chains, plus/minus mixing, and division behavior.

## Division (`/`)

The `/` operator handles **division** and **unary reciprocal** (inverse). Behavior depends on operand count:

- **Single operand** — computes the reciprocal (`1 / value`)
- **Two operands** — divides the first by the second

### Unary Reciprocal

```mantra
{ ~ / 8.0 }
```

Expected `OUTPUT`:

```text
+ 0.125
```

The result uses `+` prefix because the reciprocal is positive.

### Wrapped Operand

Parenthesized expressions evaluate before division:

```mantra
{ ~ / ( 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

### Division with Two Operands

```mantra
{ ~ / 10 3 }
```

Expected `OUTPUT`:

```text
/ 10 + 0.333333333333333
```

Note: When `/` has two operands, the output preserves both operands (`/ 10`) and the computed result (`+ 0.333333333333333`).

### Division with Integer Operand

```mantra
{ ~ / 7 2 }
```

Expected `OUTPUT`:

```text
/ 7 + 0.5
```

### Division Inside Addition

Division sub-expressions compute before addition due to operator precedence:

```mantra
{ ~ + / 8.0 2 }
```

Expected `OUTPUT`:

```text
+ 0.625
```

### Division with Addition Wrapper

When addition is wrapped inside division:

```mantra
{ ~ / ( + 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

### Recursive Division

Division participates in recursive fixpoint expansion:

```mantra
~ { + 2.0 / ( + 1.0 / ( ... ) ) : 3 }
```

Expected `OUTPUT`:

```text
+ 2.73333333333334
```

See [Minus and Division](integer-arithmetic/minus-division.md) and [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md) for division with quaternions and symbolic variables.

## Summary

Arithmetic operators require a compute trigger (`~` or `` ` ``) to reduce. The `+` operator is a reduction trigger that combines operands automatically; `*` is not. The `-` operator handles negation, and `/` handles division and reciprocal. Multi-operand chains for `-` and `/` preserve operand details in output, while `+` and `*` collapse to a single computed value.

## Related Pages

- [Addition and Multiplication](integer-arithmetic/addition-multiplication.md)
- [Minus and Division](integer-arithmetic/minus-division.md)
- [Basic Floats](float-arithmetic/basic-floats.md)
- [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md)
- [Meta-Compute Operator](meta-compute-operator.md)
- [Compute Scopes](../../syntax/compute-scopes.md)
- [Supported Reductions](compute-scope/supported-reductions.md)
