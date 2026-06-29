# Quaternion Products

Quaternion multiplication in Mantra is non-commutative and follows the standard
Hamilton rules. The runtime uses a 4x4 lookup table to determine the result
component and sign for every basis pair, then distributes across multi-component
quaternions by expanding all bucket pairs and accumulating the results.

## Basis Multiplication

The fundamental quaternion basis rules are:

| Left x Right | i     | j     | k     |
|--------------|-------|-------|-------|
| i            | -1    | k     | -j    |
| j            | -k    | -1    | i     |
| k            | j     | -i    | -1    |

The key takeaway: **order matters**. Reversing two basis elements flips the sign.

## Single-Component Products

When both operands carry the same basis suffix, they follow the standard rule
`i * i = -1` (and similarly for `j` and `k`):

```mantra
print ~ { * 2i 3i }
print ~ { * 2j 3j }
print ~ { * 2k 3k }
```

Output:

```text
- * 6
- * 6
- * 6
```

All three axes produce a negative real result.

## Mixed Basis Products

Each basis pair resolves to a single result component with the sign determined
by the lookup table:

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

The pattern is consistent: the cyclic order `i -> j -> k -> i` produces a
positive result, while the reverse direction produces a negative one.

## Negative Coefficients

Negated imaginary values propagate their sign through the same lookup-table
mechanism. The sign bits from both operands and the basis product combine via
XOR:

```mantra
print ~ { * -2i 3j }
print ~ { * 2i -3j }
print ~ { * -2i -3j }
print ~ { * -3i -4j }
```

Output:

```text
* 6k
- * 6k
* 6k
* 12k
```

Two negatives cancel; an odd number of negatives yields a negative result.

## Chain Multiplication

Multiple operands chain left to right. Each step reduces the current accumulator
with the next operand:

```mantra
print ~ { * 2i 3j 4k }
```

Output:

```text
- * 24
```

The computation: `2i * 3j = 6k`, then `6k * 4k = -24`.

Four or more factors chain the same way:

```mantra
print ~ { * 2i 3j 4k 5i }
```

Output:

```text
- * 120i
```

The computation: `2i * 3j = 6k`, `6k * 4k = -24`, `-24 * 5i = -120i`.

## Float Promotion

When at least one operand is a float, the result promotes to float arithmetic:

```mantra
print ~ { * 2i 3.5j }
print ~ { * 0.5i 2j }
```

Output:

```text
* 7k
* 1k
```

Integer-by-integer products stay as integers; any float input promotes the result.

## Quaternion Distribution

When two multi-component quaternions multiply, the runtime distributes across
all bucket pairs (4x4 = 16 combinations) and accumulates results into the output
buckets. See [Imaginary and Quaternion Forms](../imaginary-quaternion.md#quaternion-distribution) for the full treatment.

```mantra
print ~ { * ( + 1 2i ) ( + 3 4j ) }
```

Output:

```text
+ 3 6i 4j 8k
```

Expanding: `1*3 = 3`, `1*4j = 4j`, `2i*3 = 6i`, `2i*4j = 8k`.

## Inert Behavior

Distribution requires all components to be numeric. If a symbolic variable
appears in either operand, the expression stays inert and is not reduced:

```mantra
print ~ { * ( + x 2i ) ( + 3 4j ) }
print ~ { * ( + 1 2i ) x }
```

Output:

```text
* ( + x 2i ) ( + 3 4j )
* ( + 1 2i ) x
```

Three or more factors also prevent distribution — the runtime only distributes
two-term quaternion products:

```mantra
print ~ { * ( + 1 2i ) ( + 3 4j ) ( + 5 6k ) }
```

Output:

```text
* ( + 1 2i ) ( + 3 4j ) ( + 5 6k )
```

## Zero-Cancelled Products

When a quaternion evaluates to zero, the product collapses to zero:

```mantra
print ~ { * ( + 1i -1i ) ( + 3 4j ) }
```

Output:

```text
+ 0
```

The left side `1i + (-1i)` reduces to zero before multiplication; anything
times zero is zero.

## Related Pages

- [Imaginary and Quaternion Forms](../imaginary-quaternion.md) — syntax,
  distribution, and inverse
- [Imaginary Addition](imaginary-addition.md) — component-based bucket addition
- [Supported Reductions](../compute-scope/supported-reductions.md) — all
  compute operations
