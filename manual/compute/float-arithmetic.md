# Float Arithmetic

Float arithmetic in Mantra supports addition, multiplication, subtraction, and division (reciprocal) operations on floating-point values. Floats use IEEE 754 double-precision representation internally (`Double` / 64-bit), giving approximately 15-16 decimal digits of precision. The full range spans from approximately ±5×10⁻³²⁴ (denormals) to ±1.8×10³⁰⁸.

## Related Pages

- [Basic Floats](float-arithmetic/basic-floats.md) — Float literals, compute triggers, and test-backed examples for all arithmetic, comparison, and boolean operators with floats.
- [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md) — Integer-to-float promotion rules, mixed-type arithmetic, float ranges, recursive division, and output formatting details.

## Float Literals

Float literals are numeric tokens containing a decimal point:

```mantra
1.5
0.0
3.14
-2.5
```

The parser recognizes these as `TK_FLOAT` tokens and creates `TFloatNode` AST nodes. Unlike integers (`TIntegerNode`), floats use `Double` precision internally and are never implicitly truncated to integers during computation.

## When Floats Reduce

Float expressions do **not** reduce on their own. They need a compute trigger:

- **Meta-compute operator** `~` — targets a specific node for computation
- **Compute scope** `` ` ... ` `` — marks an entire expression as computable

Without compute scope, a float expression stays as a symbolic tree:

```mantra
[ * 1.5 2 ]
```

Expected `OUTPUT`:

```text
[ * 1.5 2 ]
```

With compute scope, it reduces to a single numeric result:

```mantra
{ ~ * 1.5 2 }
```

Expected `OUTPUT`:

```text
* 3
```

## Supported Operations

The `OPS_PROCS_FLOAT` record in `compute.pas` defines the float arithmetic operations available through `TFloatNode`:

| Operation | Token | Behavior |
| --- | --- | --- |
| Addition | `TK_PLUS` (`+`) | Variadic sum, left to right |
| Subtraction | `TK_MINUS` (`-`) | Unary negation or variadic subtraction |
| Multiplication | `TK_MULTIPLY` (`*`) | Variadic product, left to right |
| Division | `TK_DIVIDE` (`/`) | Reciprocal (unary) or float division |
| Negation | `TK_MINUS` (unary) | Sign inversion |
| Inverse | `TK_DIVIDE` (unary) | Reciprocal of a single value |
| Comparisons | `<`, `<=`, `>`, `>=`, `==`, `<>` | Relational (returns `1` or `0`) |
| Boolean | `and`, `or`, `xor` | Logical (non-zero = truthy) |

All arithmetic operations are implemented in `compute.pas` via the `TArithmeticOps` record with `FloatAdd`, `FloatSub`, `FloatMul`, `FloatDiv`, `FloatNeg`, and `FloatInv` function pointers. Comparisons use `OPS_RELATIONAL_FLOAT` with `DoubleEquals`, `DoubleLess`, `DoubleGreater`, etc.

## Operator Combining

Float operators combine using the same `COMBINE_LHS_LUT` lookup table as integers. When adjacent operators of the same precedence appear, they fold into a combined operator token. The table encodes how pairs of operators interact — for example, `+` combined with `-` yields `-`, and `*` combined with `/` yields `* /`.

## Additive Bucket Computing

Float compute implements bucket-based accumulation via `TryComputeAdditiveBuckets`. Before attempting direct binary folding, the runtime scans for additive chains (`+`/`-` operators) and accumulates them separately. This handles complex expressions like `+ 1.5 - 2.0 + 3.5` in a single pass, correctly combining mixed `+`/`-` operators.

## Unary Operations

When a float has no right-hand sibling, certain operators apply as unary operations:

- **Unary minus** negates the value:
  ```mantra
  { ~ - 0.5 }
  ```
  Expected `OUTPUT`:
  ```text
  - 0.5
  ```

- **Unary divide** computes the reciprocal:
  ```mantra
  { ~ / 8.0 }
  ```
  Expected `OUTPUT`:
  ```text
  + 0.125
  ```

- **Division by zero** returns `NaN` (Not a Number) rather than raising an exception — this is the key safety difference from integer division:
  ```mantra
  { ~ / 0.0 }
  ```
  Expected `OUTPUT`:
  ```text
  NaN
  ```

## Float Precision and Output Formatting

Float output follows the Pascal `FloatToStr` representation using `DefaultFormatSettings`. This means:

- **Whole-number results** may appear without a decimal point (`3` instead of `3.0`)
- **Non-terminating fractions** use fixed-point notation with significant digits (`0.333333333333333`)
- **Negative values** are formatted as a negative operator prefix plus positive magnitude (`- 0.5`)
- **Very large or very small numbers** may use scientific notation (`1.5000000000000000E+000`)
- **NaN** is produced by division by zero and propagates through subsequent operations

## Float vs. Integer Promotion

When a float and integer appear in the same computation, the integer is **promoted to float** and the result type follows the widest operand. The `TFloatNode.IsNumericNodeForCompute` method accepts both `OBJ_FLOAT` and `OBJ_INTEGER` as valid numeric siblings:

```mantra
{ ~ + 1.5 2 }
```

Expected `OUTPUT`:

```text
+ 3.5
```

The integer `2` is promoted to `2.0` before addition. See [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md) for the complete promotion specification.

## Floats in Ranges and Sequences

Float values work in range expressions with stepped expansion:

```mantra
print { 0.0 .. 1.0 by 0.2 }
```

Expected `OUTPUT`:

```text
0 0.2 0.4 0.6 0.8 1
```

Floats also participate in repeat sequences with variable binding:

```mantra
values = [ -1.0 -0.8 -0.6 ];
print { [ ~ * x * x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ * 1 ] [ * 0.64 ] [ * 0.36 ]
```

## Floats with Imaginary and Quaternion Types

Float promotion extends to imaginary and quaternion arithmetic. When a float appears alongside imaginary values, the imaginary bucket promotes to floating-point arithmetic:

```mantra
print ~ { + 1 2.5 3i 4i }
```

Expected `OUTPUT`:

```text
+ 3.5 7i
```

See [Imaginary and Quaternion Forms](../imaginary-quaternion.md) for the full specification.

## Comparison and Boolean Operations

Floats support comparison operators (`<`, `<=`, `>`, `>=`, `==`, `<>`) and boolean operators (`and`, `or`, `xor`). Truth values are `1` (true) and `0` (false). Non-zero floats are truthy; `0.0` is falsy:

```mantra
{ ~ < 1.5 2.0 }
```

Expected `OUTPUT`:

```text
1
```

```mantra
{ ~ and 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
0
```

See [Boolean and Comparison](../boolean-comparison.md) for details.

## Recursive Fixpoint with Floats

Floats participate in recursive fixpoint computations bounded by `MAX_FIXPOINT_STEPS = 1024`. Nested scopes with division reduce correctly:

```mantra
~ { + 2.0 / ( + 1.0 / ( ... ) ) : 3 }
```

Expected `OUTPUT`:

```text
+ 2.73333333333334
```

## Summary

| Context | Input | Output |
| --- | --- | --- |
| No compute scope | `* 1.5 2` | `* 1.5 2` |
| Meta-compute multiply | `{ ~ * 1.5 2 }` | `* 3` |
| Float addition | `{ ~ + 1.5 2.5 }` | `+ 4` |
| Mixed float + int | `{ ~ + 1.5 2 }` | `+ 3.5` |
| Unary reciprocal | `{ ~ / 8.0 }` | `+ 0.125` |
| Division by zero | `{ ~ / 0.0 }` | `NaN` |
| Comparison | `{ ~ < 1.5 2.0 }` | `1` |
| Boolean and | `{ ~ and 1.5 0.0 2.5 }` | `0` |
| Float range | `{ 0.0 .. 1.0 by 0.2 }` | `0 0.2 0.4 0.6 0.8 1` |
| Negative result | `{ ~ - 0.5 }` | `- 0.5` |

## Related Pages

- [Basic Floats](float-arithmetic/basic-floats.md) — Float literals, compute triggers, and test-backed examples for all arithmetic, comparison, and boolean operators.
- [Mixed Numeric Forms](float-arithmetic/mixed-numeric-forms.md) — Integer-to-float promotion, mixed-type arithmetic, float ranges, recursive division, and formatting.
- [Integer Arithmetic](integer-arithmetic.md) — The integer counterpart with `Int64` arithmetic.
- [Meta-Compute Operator](meta-compute-operator.md) — The `~` operator that targets nodes for computation.
- [Compute Scope](compute-scope.md) — The `` ` ... ` `` scope that marks expressions as computable.
- [Boolean and Comparison](boolean-comparison.md) — Comparison and boolean operators shared across numeric types.
- [Imaginary and Quaternion Forms](imaginary-quaternion.md) — Imaginary suffixes (`i`, `j`, `k`) with float promotion.
- [Supported Reductions](compute-scope/supported-reductions.md) — Complete list of reducible operations in compute scope.
- [Symbolic Non-Computed Forms](symbolic-non-computed-forms.md) — When expressions remain symbolic without compute triggers.
