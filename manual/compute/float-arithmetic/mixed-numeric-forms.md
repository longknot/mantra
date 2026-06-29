# Mixed Numeric Forms

When integer and float operands appear together in a compute expression, the
runtime promotes the integer to `Double` and performs floating-point arithmetic.
The result is always formatted as a float (or as an integer when the result is
a whole number and the runtime chooses the compact form).

## Promotion Rule

The `TFloatNode.IsNumericNodeForCompute` method accepts both `OBJ_FLOAT` and
`OBJ_INTEGER` as valid numeric siblings. When the head operator node is a
`TFloatNode`, all integer siblings are promoted to `Double` during
accumulation. When the head is a `TIntegerNode` but a float sibling is
encountered, the accumulator switches to floating-point mode.

In short: **the presence of any float operand in a compute expression promotes
the entire operation to floating-point arithmetic**.

## Addition with Mixed Types

Adding a float and an integer produces a float result:

```mantra
{ ~ + 1.5 2 }
```

Expected `OUTPUT`:

```text
+ 3.5
```

The integer `2` is promoted to `2.0` before addition. The fixture
`float_add_int_mixed_compute` verifies this behavior.

When both operands are integers, the result stays integer:

```mantra
{ ~ + 1 2 }
```

Expected `OUTPUT`:

```text
+ 3
```

When the sum of mixed operands happens to be a whole number, the runtime may
format it compactly:

```mantra
{ ~ + 1.5 2.5 }
```

Expected `OUTPUT`:

```text
+ 4
```

The fixture `float_add_compute` confirms that `1.5 + 2.5` displays as `+ 4`
rather than `+ 4.0`.

## Subtraction with Mixed Types

Subtraction follows the same promotion rule. The `float_minus_compute` fixture
demonstrates:

```mantra
{ ~ + - 1.5 2.5 }
```

Expected `OUTPUT`:

```text
- 4
```

Here, the expression represents `- (1.5 + 2.5)` — the minus operator applies
unary negation to the accumulated sum, producing a negative result formatted
as `- 4`.

## Multiplication with Mixed Types

Multiplication promotes to float when any operand is a float:

```mantra
{ ~ * 1.5 2 }
```

Expected `OUTPUT`:

```text
* 3
```

The integer `2` is promoted to `2.0`. The product `3.0` is formatted as `* 3`
(compact whole-number form). The fixture `float_multiply_compute` verifies this.

## Division with Mixed Types

Division always produces a float result, since the inverse of an integer is
generally non-integer.

### Single Operand

A single float operand with division computes its reciprocal:

```mantra
{ ~ / 8.0 }
```

Expected `OUTPUT`:

```text
+ 0.125
```

The fixture `float_divide_single_compute` demonstrates this.

### Wrapped Operand

Parenthesized expressions are evaluated before division:

```mantra
{ ~ / ( 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

The fixture `float_divide_wrapped_compute` confirms this behavior.

### Division with Addition

Division has higher precedence than addition during compute. The division
sub-expression reduces first, then participates in the additive accumulator:

```mantra
{ ~ + / 8.0 2 }
```

Expected `OUTPUT`:

```text
+ 0.625
```

The fixture `float_divide_compute` shows that `/ 8.0 2` evaluates to `4.0`,
which is then added (with the `+` prefix operator) to produce `0.625` —
specifically, the `/ 8.0 2` produces `4.0`, but the output `+ 0.625` indicates
the expression structure where division result feeds into the addition operator.

### Division with Wrapped Addition

When addition is wrapped inside division:

```mantra
{ ~ / ( + 2.0 ) }
```

Expected `OUTPUT`:

```text
+ 0.5
```

The fixture `float_divide_wrapped_plus_compute` demonstrates that `( + 2.0 )`
evaluates to `2.0`, and its reciprocal is `0.5`.

### Recursive Division

Division participates in recursive fixpoint expansion. Nested scopes with
division reduce correctly, and empty scopes are cleaned up:

```mantra
~ { + 2.0 / ( + 1.0 / ( ... ) ) : 3 }
```

Expected `OUTPUT`:

```text
+ 2.73333333333334
```

The fixture `float_divide_recursive_empty_scope_cleanup` verifies that recursive
division with repeat expansion produces numerically stable results and cleans
up empty scopes.

## Comparison Operators with Mixed Types

Relational comparisons between integers and floats promote to floating-point
comparison. The result is always an integer `1` (true) or `0` (false):

```mantra
{ ~ < 1.5 2.0 }
```

Expected `OUTPUT`:

```text
1
```

The fixture `float_compare_less_true` confirms that `1.5 < 2.0` evaluates to
`1` (true). The comparison operator consumes both operands and stores the
boolean result as an integer.

## Boolean Operators with Float Operands

Boolean operators (`and`, `or`, `xor`) treat non-zero floats as truthy and
zero floats as falsy:

```mantra
{ ~ and 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
0
```

The fixture `boolean_and_float_compute` shows that `and 1.5 0.0 2.5` evaluates
to `0` — the `and` operator short-circuits when it encounters `0.0` (falsy),
regardless of the other truthy operands.

## Float Promotion in Complex Numbers

Float promotion also applies to imaginary and quaternion arithmetic. When a
float appears alongside an imaginary value, the imaginary bucket promotes to
floating-point arithmetic:

```mantra
print ~ { + 1 2.5 3i 4i }
```

Expected `OUTPUT`:

```text
+ 3.5 7i
```

The fixture `imag_add_float_promotion_compute` demonstrates that the real bucket
(`1 + 2.5 = 3.5`) and the imaginary bucket (`3i + 4i = 7i`) both reduce
correctly with float promotion.

```mantra
print ~ { + 1.5i 2i }
```

Expected `OUTPUT`:

```text
+ 3.5i
```

The integer imaginary `2i` is promoted to `2.0i` for the addition with `1.5i`.

Quaternion distribution with floats also promotes correctly:

```mantra
print ~ { * ( + 1.5 2i ) ( + 3 4.5j ) }
```

Expected `OUTPUT`:

```text
+ 4.5 6i 6.75j 9k
```

The fixture `quaternion_distribution_float_zero_compute` verifies mixed float/
integer quaternion multiplication.

## Float Ranges

Float values work in range expressions with stepped expansion:

```mantra
print { 0.0 .. 1.0 by 0.2 }
print { 1.0 .. 0.0 by -0.2 }
print { 0.0 .. 1.0 by 0.3 }
```

Expected `OUTPUT`:

```text
0 0.2 0.4 0.6 0.8 1
1 0.8 0.6 0.4 0.2 0
0 0.3 0.6 0.9
```

The fixture `range_stepped_float_expand` shows that float ranges use the same
`..` and `by` syntax as integer ranges, supporting both positive and negative
steps. Note that `0.0 .. 1.0 by 0.3` stops at `0.9` because `1.2` would exceed
the upper bound.

## Float Repeat Sequences

Float values participate in repeat sequences with variable binding:

```mantra
values = [ -1.0 -0.8 -0.6 ]
print { [ ~ * x * x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ * 1 ] [ * 0.64 ] [ * 0.36 ]
```

The fixture `staged_repeat_sequence_float_square` demonstrates squaring each
float value in a sequence. The results are formatted compactly: `* 1` for
`(-1.0)^2 = 1.0`, `* 0.64` for `(-0.8)^2 = 0.64`, etc.

## Output Formatting Notes

- Whole-number float results may display without a decimal point (`+ 4` instead
  of `+ 4.0`).
- Division results display full precision (`+ 0.625`, `+ 0.125`).
- Recursive computations may show extended precision
  (`+ 2.73333333333334`).
- Comparison and boolean results always display as integers (`0` or `1`).
- Do not normalize float formatting by hand in documentation — use the exact
  output from the fixture suite.

## Summary Table

| Context | Input | Output |
|---|---|---|
| Float + int | `{ ~ + 1.5 2 }` | `+ 3.5` |
| Float + float (whole) | `{ ~ + 1.5 2.5 }` | `+ 4` |
| Float - float | `{ ~ + - 1.5 2.5 }` | `- 4` |
| Float * int | `{ ~ * 1.5 2 }` | `* 3` |
| Float reciprocal | `{ ~ / 8.0 }` | `+ 0.125` |
| Float / wrapped | `{ ~ / ( 2.0 ) }` | `+ 0.5` |
| Div in addition | `{ ~ + / 8.0 2 }` | `+ 0.625` |
| Float comparison | `{ ~ < 1.5 2.0 }` | `1` |
| Boolean and (float) | `{ ~ and 1.5 0.0 2.5 }` | `0` |
| Float range | `{ 0.0 .. 1.0 by 0.2 }` | `0 0.2 0.4 0.6 0.8 1` |
| Float squaring | `[ ~ * x * x ]` | `[ * 1 ]` etc. |
| Imag float promotion | `~ { + 1.5i 2i }` | `+ 3.5i` |

## Related Pages

- [Basic Floats](basic-floats.md)
- [Addition and Multiplication](../integer-arithmetic/addition-multiplication.md)
- [Minus and Division](../integer-arithmetic/minus-division.md)
- [Meta-Compute Operator](../meta-compute-operator.md)
- [Imaginary and Quaternion Forms](../imaginary-quaternion.md)
- [Boolean Comparison](../boolean-comparison.md)
