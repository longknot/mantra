# Imaginary and Quaternion Forms

Mantra supports imaginary and quaternion arithmetic inside compute contexts.
Numeric literals suffixed with `i`, `j`, or `k` represent values along the
quaternion basis axes. These values participate in addition, multiplication,
and inversion using the same bucket-based reduction system that handles
integers and floats.

## Syntax

Append `i`, `j`, or `k` to any integer or float literal to create an imaginary
value:

```mantra
1i      {#} integer along the i-axis {#/}
2.5j    {#} float along the j-axis {#/}
3k      {#} integer along the k-axis {#/}
```

Without a suffix, a plain number lives in the real (scalar) bucket. Together,
all four buckets -- real, `i`, `j`, `k` -- form a quaternion.

## Imaginary Addition

Values in compute scope are grouped by their component (real, `i`, `j`, `k`)
into separate **buckets**. When adding, only values sharing the same component
combine into a single result.

### Same Component

Imaginary values with matching suffixes add together:

```mantra
print ~ { + 1i 2i }
```

Output:

```text
+ 3i
```

### Unlike Components

When operands have different components, each stays in its own bucket. They
do not collapse into a single value but remain as a multi-component expression:

```mantra
print ~ { + 1 2i }
```

Output:

```text
+ 1 2i
```

### Multiple Components

A single addition can span all four buckets. The result carries each non-zero
bucket in canonical order (real, `i`, `j`, `k`):

```mantra
print ~ { + 1k 1i 1j 1 1k 1 }
```

Output:

```text
+ 2 1i 1j 2k
```

### Zero Buckets

When two opposite imaginary values cancel out, the bucket reduces to zero:

```mantra
print ~ { + 1i -1i }
```

Output:

```text
+ 0
```

### Symbolic Islands

If a non-numeric symbol appears among imaginary terms, computation stops at
that point and the remaining expression is formatted symbolically:

```mantra
print ~ { + 1i x 1j 1i }
```

Output:

```text
+ 1i + x + 1i 1j
```

The `1i` and `1j` are still processed, but the `x` variable prevents further
bucket aggregation across it.

### Float Promotion

Adding a float to an integer imaginary value promotes the entire bucket to
float arithmetic:

```mantra
print ~ { + 1 2.5 3i 4i }
print ~ { + 1.5i 2i }
```

Output:

```text
+ 3.5 7i
+ 3.5i
```

### Int64 Range

Imaginary addition respects 64-bit integer range. Values exceeding the 32-bit
signed integer limit still combine correctly:

```mantra
print { ~ + 2147483647i 1i }
```

Output:

```text
+ 2147483648i
```

## Imaginary Multiplication

When two imaginary values multiply, the result follows quaternion basis
multiplication rules. The runtime uses a lookup table to determine the result
component and sign.

### Basis Multiplication Rules

| Left x Right | Real    | i       | j       | k       |
|-------------|---------|---------|---------|---------|
| Real        | Real    | i       | j       | k       |
| i           | i       | -Real   | k       | -j      |
| j           | j       | -k      | -Real   | i       |
| k           | k       | j       | -i      | -Real   |

The key properties:
- `i * i = -1` (and similarly `j * j = -1`, `k * k = -1`)
- `i * j = k`, but `j * i = -k` (order matters)
- `j * k = i`, `k * j = -i`
- `k * i = j`, `i * k = -j`

### Basic Products

```mantra
print ~ { * 2i 3j }
print ~ { * 2j 3i }
```

Output:

```text
* 6k
- * 6k
```

Reversing the order flips the sign.

### All Basis Pairs

```mantra
print ~ { * 2i 3j }
print ~ { * 2j 3i }
print ~ { * 2j 3k }
print ~ { * 2k 3j }
print ~ { * 2k 3i }
print ~ { * 2i 3k }
```

Output:

```text
* 6k
- * 6k
* 6i
- * 6i
* 6j
- * 6j
```

### Same-Component Products

Multiplying two values on the same axis produces a real (negative) result:

```mantra
print ~ { * 2i 3i }
```

Output:

```text
- * 6
```

### Chain Multiplication

Multiple imaginary factors chain together:

```mantra
print ~ { * 2i 3j 4k }
```

Output:

```text
- * 24
```

The computation proceeds left to right: `(2i * 3j) = 6k`, then `6k * 4k = -24`.

### Float Promotion

Float and integer imaginary values mix seamlessly in multiplication:

```mantra
print ~ { * 2i 3.5j }
```

Output:

```text
* 7k
```

## Quaternion Distribution

When two multi-component quaternions multiply, the runtime distributes across
all bucket pairs and accumulates results into the output buckets.

### Two-Term Quaternions

```mantra
print ~ { * ( + 1 2i ) ( + 3 4j ) }
```

Output:

```text
+ 3 6i 4j 8k
```

Expanding manually: `1*3 = 3`, `1*4j = 4j`, `2i*3 = 6i`, `2i*4j = 8k`.

### Same-Component Terms

```mantra
print ~ { * ( + 1 2i ) ( + 3 4i ) }
```

Output:

```text
- 5 10i
```

Expanding: `1*3 = 3`, `1*4i = 4i`, `2i*3 = 6i`, `2i*4i = -8`. Combined:
`-8 + 3 = -5`, `4i + 6i = 10i`.

### Full Four-Term Product

```mantra
print ~ { * ( + 1 2i 3j 4k ) ( + 5 6i 7j 8k ) }
```

Output:

```text
- 60 12i 30j 24k
```

### Float Zero Distribution

When one quaternion evaluates to zero, the entire product collapses:

```mantra
print ~ { * ( + 1i -1i ) ( + 3 4j ) }
```

Output:

```text
+ 0
```

### Float Coefficients

Float coefficients are preserved through full distribution:

```mantra
print ~ { * ( + 1.5 2i ) ( + 3 4.5j ) }
```

Output:

```text
+ 4.5 6i 6.75j 9k
```

### Inert Behavior

Distribution is only performed when all components are numeric. If a symbolic
variable appears, the expression stays inert:

```mantra
print ~ { * ( + x 2i ) ( + 3 4j ) }
```

Output:

```text
* ( + x + 2i ) * ( + 3 4j )
```

The same applies when the right operand contains symbols or when three or more
factors are present:

```mantra
print ~ { * ( + 1 2i ) ( + 3 4j ) ( + 5 6k ) }
```

Output:

```text
* ( + 1 + 2i ) * ( + 3 + 4j ) * ( + 5 + 6k )
```

## Quaternion Inverse

The unary `/` operator inverts (reciprocates) a single value or quaternion.
For a single-term value, it returns `1 / value` with the appropriate sign and
component. For multi-component quaternions, it computes the conjugate divided
by the squared norm.

### Single-Element Inverse

```mantra
print ~ { / 2 }
print ~ { / 2i }
print ~ { / 2j }
print ~ { / 2k }
```

Output:

```text
+ 0.5
- 0.5i
- 0.5j
- 0.5k
```

Note: `1/i = -i`, `1/j = -j`, `1/k = -k` -- the imaginary basis elements
invert to their negation.

### Multi-Component Quaternion Inverse

```mantra
print ~ { / ( + 1 2i ) }
```

Output:

```text
+ 0.2 - 0.4i
```

The conjugate of `1 + 2i` is `1 - 2i`; the squared norm is `1 + 4 = 5`.
So the inverse is `(1 - 2i) / 5 = 0.2 - 0.4i`.

### Full Quaternion Inverse

```mantra
print ~ { / ( + 1 2i 3j 4k ) }
```

Output:

```text
+ 0.0333333333333333 - 0.0666666666666667i - 0.1j - 0.133333333333333k
```

Squared norm: `1 + 4 + 9 + 16 = 30`. Conjugate: `1 - 2i - 3j - 4k`.
Divided by 30.

### Inert and Zero Cases

Inverting a quaternion with symbolic components or zero norm does not
produce a numeric result:

```mantra
print ~ { / ( + x 2i ) }
print ~ { / ( + 0 ) }
print ~ { / 0i }
```

Output:

```text
/ ( + x + 2i )
+ Nan
+ Nani
```

The symbolic case stays inert. Division by zero (real or imaginary) produces
`Nan`.

## Related Pages

- [Imaginary Addition](imaginary-quaternion/imaginary-addition.md)
- [Quaternion Products](imaginary-quaternion/quaternion-products.md)
- [Supported Reductions](compute-scope/supported-reductions.md)
- [Compute Scopes](../../syntax/compute-scopes.md)
