# Ranges

The `..` operator expands a range into a sequence of values. Ranges support:

- **Integer ranges** — `1 .. 5` produces `1 2 3 4 5`
- **Float ranges** — `0.0 .. 1.0` produces `0 0.2 0.4 0.6 0.8 1` (with stepped)
- **Character ranges** — `"a" .. "c"` produces `"a" "b" "c"`
- **Signed endpoints** — `-3 .. 3` produces `-3 -2 -1 0 1 2 3`
- **Explicit steps** — `0 .. 10 by 2` produces `0 2 4 6 8 10`

## Syntax

**Basic range** — two endpoints separated by `..`:

```mantra
start .. end
```

**Stepped range** — explicit step via `by` keyword:

```mantra
start .. end by step
```

The `by` keyword is contextual — it only introduces a step immediately after a
completed range. Elsewhere, `by` remains an ordinary identifier.

```mantra
by = 7;
print { by }    // 7
```

## Integer Ranges

Integer endpoints with no explicit step produce unit-step sequences. Direction
is inferred: ascending ranges step by `1`, descending ranges step by `-1`.

### Ascending range

```mantra
print { 1 .. 3 }
```

Expected `OUTPUT`:

```text
1 2 3
```

### Descending range

```mantra
print { 3 .. 1 }
```

Expected `OUTPUT`:

```text
3 2 1
```

### Signed endpoints

Negative integers are valid range endpoints. The range resolves through zero:

```mantra
print { -3 .. 3 }
```

Expected `OUTPUT`:

```text
-3 -2 -1 0 1 2 3
```

### Equal endpoints

When start equals end, the range produces a single value:

```mantra
print { 5 .. 5 }
```

Expected `OUTPUT`:

```text
5
```

## Float Ranges

Float ranges require an explicit step — plain float ranges default to step `1.0`
or `-1.0` depending on direction:

```mantra
print { -1.0 .. 1.0 }
```

Expected `OUTPUT`:

```text
- 1 0 1
```

For finer granularity, use `by` with a float step:

```mantra
print { 0.0 .. 1.0 by 0.2 }
```

Expected `OUTPUT`:

```text
0 0.2 0.4 0.6 0.8 1
```

### Descending float range

```mantra
print { 1.0 .. 0.0 by -0.2 }
```

Expected `OUTPUT`:

```text
1 0.8 0.6 0.4 0.2 0
```

### Endpoint inclusion

Ranges are start-anchored: they always include `start` and include `end` only
when the step reaches it within floating-point tolerance. Values that overshoot
`end` are excluded:

```mantra
print { 0.0 .. 1.0 by 0.3 }
```

Expected `OUTPUT`:

```text
0 0.3 0.6 0.9
```

The value `1.2` would exceed `1.0`, so only `0.9` is included.

## Character Ranges

Character ranges expand single-character strings into a sequence of character
values between the start and end characters (inclusive):

```mantra
print { "a" .. "c" }
```

Expected `OUTPUT`:

```text
"a" "b" "c"
```

Character ranges only support the inferred unit step — explicit steps via `by`
are not supported and raise an error:

```mantra
print { "a" .. "z" by 2 }
```

Expected `OUTPUT`:

```text
Error: explicit character range steps are not supported
```

## Stepped Ranges

The `by` clause adds an explicit step. Stepped ranges support integer and float
domains.

### Integer stepped ranges

```mantra
print { 0 .. 10 by 2 }
```

Expected `OUTPUT`:

```text
0 2 4 6 8 10
```

Descending stepped ranges:

```mantra
print { 10 .. 0 by -2 }
```

Expected `OUTPUT`:

```text
10 8 6 4 2 0
```

Non-dividing steps stop before the endpoint:

```mantra
print { 0 .. 10 by 3 }
```

Expected `OUTPUT`:

```text
0 3 6 9
```

### Mixed integer and float

When integer endpoints are paired with a float step, the result is a float
sequence. When float endpoints are paired with an integer step, the result is
also float:

```mantra
print { { ~ + 0 - 1 } .. { ~ + 1 } by { ~ / ( + 2.0 ) } }
```

Expected `OUTPUT`:

```text
- 1 - 0.5 0 0.5 1
```

### Variable operands

Range endpoints and steps can be variables:

```mantra
start = -1.0;
finish = 1.0;
step = 0.5;
print { start .. finish by step }
```

Expected `OUTPUT`:

```text
- 1 - 0.5 0 0.5 1
```

## Error Cases

Ranges validate their operands and reject invalid configurations:

### Zero step

```mantra
print { 0 .. 3 by 0 }
```

Expected `OUTPUT`:

```text
Error: range step cannot be zero
```

### Direction mismatch

The step direction must reach the end — a positive step with a descending range
(or vice versa) is rejected:

```mantra
print { 0 .. 3 by -1 }
```

Expected `OUTPUT`:

```text
Error: range step direction does not reach end
```

### Non-finite values

NaN and infinite values are not allowed:

```mantra
print { 0 .. 1 by nan }
```

Expected `OUTPUT`:

```text
Error: range values and step must be finite
```

### Missing step value

The `by` keyword requires a following expression:

```mantra
print { 0 .. 3 by }
```

Expected `OUTPUT`:

```text
Error: Missing range step after "by"
```

## Ranges with Repeat

Ranges can drive repeat expansion. Without an iterator binding, the range acts as
a count — each value is discarded and only the repetition count matters:

```mantra
print { 1 : 1 .. 5 }
```

Expected `OUTPUT`:

```text
1 1 1 1 1
```

With an iterator binding (`@`), each range value is bound to a variable:

```mantra
print { i : 1 .. 5 @ i }
```

Expected `OUTPUT`:

```text
1 2 3 4 5
```

Character ranges also support iterator binding:

```mantra
print { i : "b" .. "b" @ i }
```

Expected `OUTPUT`:

```text
"b"
```

## Ranges with Staged Repeat

Staged repeat (`::`) evaluates a fresh copy of the subject for each range value.
Combined with iterator binding, this maps a template over a range:

```mantra
print { i :: 1 .. 3 @ i }
```

Expected `OUTPUT`:

```text
1 2 3
```

Compute-scoped templates with stepped ranges:

```mantra
print { [ ~ * x * x ] :: -1.0 .. 1.0 by 0.2 @ x }
```

Expected `OUTPUT`:

```text
[ * 1 ] [ * 0.64 ] [ * 0.36 ] [ * 0.16 ] [ * 0.04 ] [ * 0 ] [ * 0.04 ] [ * 0.16 ] [ * 0.36 ] [ * 0.64 ] [ * 1 ]
```

## Summary

| Feature | Syntax | Example |
|---|---|---|
| Integer range | `start .. end` | `1 .. 5` |
| Signed range | `-start .. end` | `-3 .. 3` |
| Float range | `start .. end` | `-1.0 .. 1.0` |
| Character range | `"a" .. "z"` | `"a" .. "c"` |
| Stepped integer | `start .. end by step` | `0 .. 10 by 2` |
| Stepped float | `start .. end by step` | `0.0 .. 1.0 by 0.2` |
| Iterator binding | `var : range @ var` | `i : 1 .. 5 @ i` |
| Staged repeat | `expr :: range @ var` | `[~*x*x] :: -1..1 by 0.2 @ x` |
