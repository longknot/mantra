# Basic Floats

Float literals (decimal-point numbers like `1.5`, `2.0`, `0.25`) are first-class numeric types in Mantra. Inside compute scope, they can be reduced by supported arithmetic, comparison, and boolean operators. Floats use the IEEE 754 double-precision representation internally (`Double` / 64-bit).

## Float Literals

A float literal is any numeric token containing a decimal point:

```mantra
1.5
0.0
3.14
-2.5
```

The parser recognizes these as `TK_FLOAT` tokens and creates `TFloatNode` AST nodes. Unlike integers (`TIntegerNode`), floats are never implicitly converted to integers during computation — the result type follows the widest operand (float promotion).

## When Floats Reduce

Floats do **not** reduce on their own. Like integers, they need a compute trigger:

- **Meta-compute operator** `~` — targets a specific node for computation
- **Compute scope** `` ` ... ` `` — marks an entire expression as computable

### Symbolic vs. Computed

Without compute scope, a float expression remains as a symbolic tree:

```mantra
* 1.5 2
```

Expected `OUTPUT`:

```text
* 1.5 2
```

With compute scope (meta-compute `~`), the same expression reduces to a single numeric result:

```mantra
{ ~ * 1.5 2 }
```

Expected `OUTPUT`:

```text
* 3
```

## Arithmetic Operations

Float arithmetic supports the same prefix-variadic operators as integers. The result format preserves the operator prefix followed by the computed value.

### Addition

The `+` operator sums float operands left to right:

```mantra
{ ~ + 1.5 2.5 }
```

Expected `OUTPUT`:

```text
+ 4
```

### Multiplication

The `*` operator multiplies float operands:

```mantra
{ ~ * 1.5 2.0 3.0 }
```

Expected `OUTPUT`:

```text
* 9
```

### Subtraction

The `-` operator subtracts the second operand from the first (and any subsequent operands from the running total):

```mantra
{ ~ - 5.5 2.2 }
```

Expected `OUTPUT`:

```text
- 5.5 2.2
```

The expression `+ - 1.5 2.5` (negative number as operand of addition) also works:

```mantra
{ ~ + - 1.5 2.5 }
```

Expected `OUTPUT`:

```text
- 4
```

### Division

The `/` operator performs float division. When the operator is the primary node, it reduces its operand:

```mantra
{ ~ / 10.0 3.0 }
```

Expected `OUTPUT`:

```text
/ 10.0 + 0.333333333333333
```

Division can also be unary (reciprocal):

```mantra
{ ~ / 8.0 }
```

Expected `OUTPUT`:

```text
+ 0.125
```

```mantra
{ ~ / 0.25 }
```

Expected `OUTPUT`:

```text
/ 0.25
```

Division inside addition — division sub-expressions compute first due to arithmetic precedence:

```mantra
{ ~ + / 8.0 2 }
```

Expected `OUTPUT`:

```text
+ 0.625
```

**Note:** The runtime uses `FloatToStr(Double, DefaultFormatSettings)` for formatting, so results may include many decimal places (e.g., `0.333333333333333`) rather than symbolic fractions.

## Comparison Operators

Floats support the standard comparison operators: `<`, `<=`, `>`, `>=`. The result is `1` (true) or `0` (false), returned as an integer:

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

Comparison with chained operands (`< a b c`) evaluates left to right and short-circuits on the first `false` result.

## Boolean Operations

Floats participate in boolean logic (`and`, `or`). A non-zero float is truthy; zero is falsy:

```mantra
{ ~ and 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
0
```

Here, `1.5` is truthy, but `0.0` is falsy, so the `and` chain short-circuits to `0`.

```mantra
{ ~ or 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
1
```

The `or` chain finds `1.5` (truthy) first and returns `1`.

## Float and Integer Mixing

When a float and integer appear in the same computation, the integer is **promoted to float** and the result is a float value. The formatting follows the runtime's `FloatToStr` representation:

```mantra
{ ~ + 1.5 2 }
```

Expected `OUTPUT`:

```text
+ 3.5
```

```mantra
{ ~ * 1.5 2 }
```

Expected `OUTPUT`:

```text
* 3
```

When the product is a whole number (e.g., `1.5 * 2 = 3`), the runtime may format it as `3` (without a decimal point) since `FloatToStr` of a whole-number double can drop the fractional part. See [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md) for a deeper treatment.

## Floats in Parenthesized Expressions

Parenthesized sub-expressions are resolved before float computation proceeds:

```mantra
{ ~ / ( 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

```mantra
{ ~ / ( + 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

## Floats in Recursive Compute

Floats participate in recursive fixpoint computations. When a float expression is repeated via `: n`, each iteration reduces independently:

```mantra
~ { + 2.0 / ( + 1.0 / ( ... ) ) : 3 }
```

Expected `OUTPUT`:

```text
+ 2.73333333333334
```

The recursive expansion (`: 3`) creates three levels of nested expressions, which then reduce from the inside out.

## Negative Float Results

When float arithmetic produces a negative result, the sign is stored in the operator bits (`TK_MINUS`), and the magnitude is formatted as a positive float:

```mantra
{ ~ - 0.5 }
```

Expected `OUTPUT`:

```text
- 0.5
```

## Floats in Ranges

Float ranges using `..` with `by` step expand to float sequences. The output formatting may drop trailing zeros for whole-number floats:

```mantra
print { 0.0 .. 1.0 by 0.2 }
```

Expected `OUTPUT`:

```text
0 0.2 0.4 0.6 0.8 1
```

Descending float ranges also work:

```mantra
print { 1.0 .. 0.0 by -0.2 }
```

Expected `OUTPUT`:

```text
1 0.8 0.6 0.4 0.2 0
```

## Floats with Variables

Variables bound to float values participate in computation via selector expressions:

```mantra
values = [ -1.0 -0.8 -0.6 ];
print { [ ~ * x * x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ * 1 ] [ * 0.64 ] [ * 0.36 ]
```

Here, each float value is bound to `x`, squared (`x * x`), and computed within the selector scope.

## Float Output Formatting

Float output follows the Pascal `FloatToStr` representation using `DefaultFormatSettings`. This means:

- **Whole-number results** may appear without a decimal point (`3` instead of `3.0`)
- **Non-terminating fractions** use fixed-point notation with significant digits (`0.333333333333333`)
- **Negative values** are formatted as a negative operator prefix plus positive magnitude (`- 0.5`)
- **Very large or very small numbers** may use scientific notation depending on the value

## Summary Table

| Context | Input | Output |
|---|---|---|
| No compute scope | `* 1.5 2` | `* 1.5 2` |
| Meta-compute multiply | `{ ~ * 1.5 2 }` | `* 3` |
| Float addition | `{ ~ + 1.5 2.5 }` | `+ 4` |
| Mixed float + int | `{ ~ + 1.5 2 }` | `+ 3.5` |
| Division | `{ ~ / 10.0 3.0 }` | `/ 10.0 + 0.333333333333333` |
| Unary reciprocal | `{ ~ / 8.0 }` | `+ 0.125` |
| Comparison | `{ ~ < 1.5 2.0 }` | `1` |
| Boolean and | `{ ~ and 1.5 0.0 }` | `0` |
| Boolean or | `{ ~ or 1.5 0.0 }` | `1` |
| Negative result | `{ ~ - 0.5 }` | `- 0.5` |

## Related Pages

- [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md)
- [Float Arithmetic](../float-arithmetic.md)
- [Minus and Division](../integer-arithmetic/minus-division.md)
- [Meta-Compute Operator](../meta-compute-operator.md)
- [Supported Reductions](../compute-scope/supported-reductions.md)
- [Comparison Operators](../boolean-comparison/comparison-operators.md)
- [Boolean Logic](../boolean-comparison/boolean-logic.md)
