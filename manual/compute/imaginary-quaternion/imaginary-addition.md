# Imaginary Addition

Imaginary addition in Mantra uses a **bucket accumulation** mechanism. When the
compute engine encounters a `+` expression containing imaginary values, it scans
the sibling chain left to right, grouping each numeric term into one of four
buckets based on its basis component: real, `i`, `j`, or `k`. After scanning,
each bucket is independently reduced to a single value and emitted in the
canonical order: real first, then `i`, `j`, `k`.

The algorithm is implemented in `TryComputeAdditiveBuckets` and `EmitBucketChain`
(nodes.pas). It consumes consecutive numeric siblings that carry valid imaginary
components and additive operators (`+`, `-`, or implicit positive). If a
non-numeric term or an incompatible operator appears, scanning stops and the
remaining terms are left untouched as a tail chain.

## How Buckets Work

The four buckets map directly to quaternion components:

| Bucket | Component | Suffix | Description |
|--------|-----------|--------|-------------|
| 0      | 0         | (none) | Real part   |
| 1      | i         | `i`    | First imaginary axis |
| 2      | j         | `j`    | Second imaginary axis |
| 3      | k         | `k`    | Third imaginary axis |

During addition, terms are placed in their respective buckets and summed
independently. After reduction, zero buckets are omitted from the output — only
non-zero components appear. If all buckets cancel to zero, the result is `+ 0`.

## Same Component

When all operands share the same basis, they combine into a single term:

```mantra
print ~ { + 1i 2i }
```

Output:

```text
+ 3i
```

The same applies to any component:

```mantra
print ~ { + 3j 5j }
print ~ { + 4k 1k }
```

Output:

```text
+ 8j
+ 5k
```

## Unlike Components

When operands carry different basis components, each stays in its own bucket.
The output follows the canonical ordering: real, `i`, `j`, `k`:

```mantra
print ~ { + 1 2i }
```

Output:

```text
+ 1 2i
```

The real term (`1`) goes to the real bucket; `2i` goes to the `i` bucket.
Neither absorbs the other.

## Canonical Ordering

The runtime always emits results in the fixed component order: real, `i`, `j`,
`k` — regardless of the order in the input expression. This makes output
deterministic and readable:

```mantra
print ~ { + 1k 1i 1j 1 1k 1 }
```

Output:

```text
+ 2 1i 1j 2k
```

The input has components in the order `k, i, j, real, k, real`. The buckets
accumulate independently — real becomes `1 + 1 = 2`, `i` stays `1`, `j` stays
`1`, and `k` becomes `1 + 1 = 2` — then the result is emitted in canonical
order: `+ 2 1i 1j 2k`.

## Mixed Real and Imaginary

Real numbers and imaginary values coexist naturally in the same expression:

```mantra
print ~ { + 1 2.5 3i 4i }
```

Output:

```text
+ 3.5 7i
```

The real bucket sums `1 + 2.5 = 3.5` (promoted to float); the `i` bucket sums
`3i + 4i = 7i` (stays integer). Both buckets are emitted together.

## Partial Zero Cancellation

When only some buckets cancel, the remaining non-zero buckets survive:

```mantra
print ~ { + 1i -1i 3j }
```

Output:

```text
+ 3j
```

The `i` bucket cancels to zero and disappears; only `3j` remains.

## Zero Cancellation

When all terms in a bucket cancel to zero, the bucket is omitted from the
output. Negated terms carry a sign bit that subtracts from their bucket during
accumulation:

```mantra
print ~ { + 1i -1i }
```

Output:

```text
+ 0
```

Here `1i` adds to the `i` bucket and `-1i` subtracts from it. The `i` bucket
reaches zero and is omitted. With no non-zero buckets remaining, the runtime
emits `+ 0` as the default.

## Float Promotion

When a float term enters a bucket, the entire bucket promotes to float
arithmetic. Integer-only buckets stay as integers:

```mantra
print ~ { + 1.5i 2i }
```

Output:

```text
+ 3.5i
```

Mixed integer and float reals promote the real bucket:

```mantra
print ~ { + 1 2.5 3i 4i }
```

Output:

```text
+ 3.5 7i
```

The real bucket (`1 + 2.5`) becomes float (`3.5`), while the `i` bucket
(`3i + 4i`) stays integer (`7i`). Each bucket tracks its type independently.

## Int64 Range

Imaginary addition uses Int64 arithmetic for integer buckets, so values that
exceed the 32-bit integer range are handled correctly:

```mantra
print { ~ + 2147483647i 1i }
```

Output:

```text
+ 2147483648i
```

The sum `2147483647 + 1 = 2147483648` exceeds the 32-bit signed maximum but
fits within Int64, so the result is exact.

## Symbolic Islands

When a non-numeric term (e.g., a variable or callable) appears in the sibling
chain, bucket scanning stops. Terms before the non-numeric boundary are
reduced; the remainder forms an untouched tail:

```mantra
print ~ { + 1i x 1j 1i }
```

Output:

```text
+ 1i + x + 1i 1j
```

The runtime consumes `1i` into the `i` bucket. When it encounters the variable
`x`, scanning halts. The bucket chain is emitted, then the remaining siblings
(`x`, `1j`, `1i`) are linked as a tail. This means symbolic terms act as
barriers that split the expression into a computed prefix and a literal suffix.

## Inert Forms

Bucket addition only triggers when the root operator is `+` (TK_PLUS). Expressions
with other root operators are not affected:

```mantra
print ~ { * 1i 2i }
```

This is multiplication, not addition — it follows quaternion product rules
(see [Quaternion Products](quaternion-products.md)), not additive bucketing.

## Related Pages

- [Imaginary and Quaternion Forms](../imaginary-quaternion.md) — syntax,
  distribution, and inverse
- [Quaternion Products](quaternion-products.md) — basis multiplication rules
- [Supported Reductions](../compute-scope/supported-reductions.md) — all
  compute operations
