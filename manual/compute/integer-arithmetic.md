# Integer Arithmetic

Integer arithmetic in Mantra supports addition, multiplication, subtraction, and division (reciprocal) operations. Integers use 64-bit signed arithmetic internally (`Int64`), so values range from -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807.

## Related Pages

- [Addition and Multiplication](integer-arithmetic/addition-multiplication.md) — Addition (`+`) and multiplication (`*`) with full variadic support, operator combining, and test-backed examples.
- [Subtraction and Division](integer-arithmetic/minus-division.md) — Subtraction (`-`) and division (`/`) with operator combining rules and test-backed examples.

## Integer Literals

Integer literals are numeric tokens without a decimal point:

```mantra
42
0
-7
2147483648
```\

## When Integers Reduce

Integer expressions do **not** reduce on their own. They need a compute trigger:

- **Meta-compute operator** `~` — targets a specific node for computation
- **Compute scope** `` ` ... ` `` — marks an entire expression as computable

Without compute scope, an integer expression stays as a symbolic tree:

```mantra
[ + 1 2 3 ]
```

Expected `OUTPUT`:

```text
[ + 1 + 2 + 3 ]
```

With compute scope, it reduces to a single numeric result:

```mantra
{ ~ + 1 ( 2 ) }
```

Expected `OUTPUT`:

```text
+ 3
```

## Supported Operations

The `OPS_PROCS_INT` record in `compute.pas` defines the integer arithmetic operations:

| Operation | Token | Behavior |
| --- | --- | --- |
| Addition | `TK_PLUS` (`+`) | Variadic sum, left to right |
| Subtraction | `TK_MINUS` (`-`) | Unary negation or variadic subtraction |
| Multiplication | `TK_MULTIPLY` (`*`) | Variadic product, left to right |
| Division | `TK_DIVIDE` (`/`) | Reciprocal (unary) or integer division |
| Negation | `TK_MINUS` (unary) | Sign inversion |
| Inverse | `TK_DIVIDE` (unary) | Reciprocal of a single value |

All operations are implemented in `compute.pas` via the `TArithmeticOps` record with `IntAdd`, `IntSub`, `IntMul`, `IntDiv`, `IntNeg`, and `IntInv` function pointers.

## Operator Precedence

Operators combine based on a lookup table (`COMBINE_LHS_LUT`) rather than traditional left-to-right precedence. The table encodes how pairs of operators interact:

| y \ x | `.` | `+` | `-` | `*` | `/` | `- *` | `- /` | `* /` | `- * /` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `.` | `.` | `+` | `-` | `*` | `/` | `- *` | `- /` | `* /` | `- * /` |
| `+` | `+` | `+` | `-` | `+` | `/` | `-` | `- /` | `/` | `- /` |
| `-` | `-` | `-` | `+` | `-` | `- /` | `+` | `/` | `- /` | `/` |
| `*` | `*` | `*` | `- *` | `*` | `* /` | `- *` | `- * /` | `* /` | `- * /` |
| `/` | `/` | `/` | `- /` | `/` | `+` | `- /` | `-` | `+` | `-` |
| `- *` | `- *` | `- *` | `*` | `- *` | `- * /` | `*` | `* /` | `- * /` | `* /` |
| `- /` | `- /` | `- /` | `/` | `- /` | `-` | `/` | `+` | `-` | `+` |
| `* /` | `* /` | `* /` | `- * /` | `* /` | `*` | `- * /` | `- *` | `*` | `- *` |
| `- * /` | `- * /` | `- * /` | `* /` | `- * /` | `- *` | `* /` | `*` | `- *` | `*` |

Row is the right-hand operator, column is the left-hand. The result is the combined operator. For example, `+` combined with `-` yields `-`, and `*` combined with `/` yields `* /`.

## Unary Operations

When an integer has no right-hand sibling, certain operators apply as unary operations:

- **Unary minus** negates the value:
  ```mantra
  { ~ - ( - 3 ) }
  ```
  Expected `OUTPUT`:
  ```text
  + 3
  ```

- **Unary divide** computes the reciprocal:
  ```mantra
  { ~ / 8.0 }
  ```
  Expected `OUTPUT`:
  ```text
  + 0.125
  ```

## Integer vs. Float Mixing

When an integer expression includes float operands, the result promotes to the widest type. See [Float Arithmetic](../float-arithmetic.md) for details on mixed-type behavior.

## Comparison and Boolean Operations

Integers also support comparison operators (`==`, `<>`, `<`, `<=`, `>`, `>=`) and boolean operators (`and`, `or`, `xor`). Truth values are represented as `1` (true) and `0` (false). See [Boolean and Comparison](../boolean-comparison.md) for details.

## Imaginary and Quaternion Extensions

Integers can carry imaginary suffixes (`i`, `j`, `k`) for quaternion arithmetic. See [Imaginary and Quaternion Forms](../imaginary-quaternion.md) for the full specification.

## Integer Overflow

Integer arithmetic uses `Int64`. Values exceeding the 64-bit signed range will overflow. There is currently no explicit overflow checking in the arithmetic operations.
