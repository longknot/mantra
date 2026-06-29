# Addition and Multiplication

Integer addition (`+`) and multiplication (`*`) are the primary arithmetic operators in Mantra. Both operate in **prefix (prefix-variadic) form** and reduce to a numeric result inside compute scope. Without compute scope, they remain as symbolic tree structures.

## When Reduction Happens

Addition and multiplication do **not** reduce on their own. They need one of two triggers:

- **Meta-compute operator** `~` — targets a specific node for computation
- **Compute scope** `` ` ... ` `` — marks an entire expression as computable

### Symbolic vs. Computed

Without compute scope, the output preserves the tree structure with each operand as a sibling:

```mantra
[ + 1 2 3 ]
```

Expected `OUTPUT`:

```text
[ + 1 + 2 + 3 ]
```

With compute scope (meta-compute `~`), the same expression reduces:

```mantra
{ ~ + 1 2 3 }
```

Expected `OUTPUT`:

```text
+ 6
```

## Addition

The `+` operator is **variadic** — it accepts any number of integer operands and sums them left to right. The result is formatted as `+ <sum>`.

### Basic Addition

```mantra
{ ~ + 1 2 3 }
```

Expected `OUTPUT`:

```text
+ 6
```

### Addition with Nested Expressions

Parenthesized sub-expressions are evaluated before addition:

```mantra
{ ~ + 1 ( 2 ) }
```

Expected `OUTPUT`:

```text
+ 3
```

### Addition with Mixed Add and Subtract

The `+` and `-` operators can appear in the same expression. The `-` children are subtracted from the running sum:

```mantra
{ ~ + 1 2 3 - 1 2 3 }
```

Expected `OUTPUT`:

```text
+ 0
```

### Addition in Backtick Compute Scope

Backtick scope triggers compute on its contents. The `+` operator reduces inside the scope, and the result participates in any outer operations like repeat:

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
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

### Addition with Variables

When a variable holds an arithmetic tree, wrapping it in a backtick scope triggers reduction:

```mantra
x = [ + 1 2 3 ]
`x`
```

Expected `OUTPUT`:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

### Large Integer Addition

Addition supports Int64 values — operands and results can exceed the 32-bit signed range:

```mantra
print { ~ + 2147483647 1 }
```

Expected `OUTPUT`:

```text
+ 2147483648
```

### Addition with Repeat

When addition is inside a repeated structure, the compute scope reduces each copy independently:

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Expected `OUTPUT`:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

## Multiplication

The `*` operator multiplies its integer operands and produces a result formatted as `* <product>`. Like addition, it needs compute scope to reduce.

### Basic Multiplication

```mantra
print { ~ * 2 3 }
```

Expected `OUTPUT`:

```text
* 6
```

### Large Integer Multiplication

Multiplication also supports Int64 arithmetic:

```mantra
print { ~ * 3037000499 2 }
```

Expected `OUTPUT`:

```text
* 6074000998
```

### Multiplication with Variables

Variables can be bound and used inside multiplicative expressions with meta-compute:

```mantra
print { [ ~ * x * x ] :: values @ x }
```

This repeats the expression `[ ~ * x * x ]` for each value in `values`, binding `x` each iteration.

### Float Multiplication

Multiplication also works with float operands, with the result promoted to float when needed:

```mantra
{ ~ * 1.5 2 }
```

Expected `OUTPUT`:

```text
* 3
```

See [Mixed Numeric Forms](../float-arithmetic/mixed-numeric-forms.md) for how integers and floats interact during computation.

## How Addition and Multiplication Interact

Addition and multiplication follow standard arithmetic precedence during compute — multiplication is evaluated before addition:

```mantra
{ ~ + / 8.0 2 }
```

Expected `OUTPUT`:

```text
+ 0.625
```

Here, division is computed first as a sub-expression, then the result participates in addition.

## Summary Table

| Context | Input | Output |
|---|---|---|
| No compute scope | `[ + 1 2 3 ]` | `[ + 1 + 2 + 3 ]` |
| Meta-compute | `{ ~ + 1 2 3 }` | `+ 6` |
| Backtick scope | `` ` + 1 2 ` `` | `+ 3` |
| Repeat + backtick | `` `[ + 1 2 3 ] : 3` `` | `[ + 6 ] [ + 6 ] [ + 6 ]` |
| Mixed +/- | `{ ~ + 1 2 3 - 1 2 3 }` | `+ 0` |
| Int64 addition | `{ ~ + 2147483647 1 }` | `+ 2147483648` |
| Multiplication | `{ ~ * 2 3 }` | `* 6` |
| Int64 multiply | `{ ~ * 3037000499 2 }` | `* 6074000998` |

## Related Pages

- [Minus and Division](minus-division.md)
- [Basic Floats](../float-arithmetic/basic-floats.md)
- [Mixed Numeric Forms](../float-arithmetic/mixed-numeric-forms.md)
- [Meta-Compute Operator](../meta-compute-operator.md)
- [Supported Reductions](../compute-scope/supported-reductions.md)
