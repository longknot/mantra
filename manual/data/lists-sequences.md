# Lists and Sequences

Lists and sequences are the primary structured data forms in Mantra. Square brackets
`[ ... ]` create arrays, while the `..` range operator generates sequences of
integers, floats, or characters. The `&` operator concatenates values, and the `@`
operator provides indexed access and slicing.

Lists are evaluated by their enclosing scope (e.g., `{ }` or `` ` ``) — elements
are not automatically computed unless the context requests computation.

## Quick Reference

| Form | Description |
|---|---|
| `[ a b c ]` | Array literal |
| `[ 1 , 2 , 3 ]` | Array with structural separators |
| `1 .. 5` | Integer range (1 2 3 4 5) |
| `0 .. 10 by 2` | Stepped range |
| `[ 1 2 3 ] @ 2` | Index lookup (1-based) |
| `[ a b c d e ] @ 4 .. 2` | Range slice (returns `[ d c b ]`) |
| `[ 1 2 ] & [ 3 4 ]` | Concatenation (returns `[ 1 2 3 4 ]`) |
| `explode "abc"` | String to character sequence |
| `implode "a" "b" "c"` | Character sequence to string |
| `[ x ] :: values @ x` | Repeat iteration over values |
| `fmt "..." [ ... ]` | Printf-style formatting with array arguments |

## Array Literals

Square brackets create arrays. Elements are space-separated expressions or values.

```mantra
print { [ 1 2 3 ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
```

Arrays can contain any mix of values, nested arrays, expressions, or scopes:

```mantra
print { [ [ 1 2 ] ( 3 4 ) "text" { + 1 2 } ] }
```

Arrays inside compute scopes evaluate their contents:

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

### Empty Arrays

An empty array is a valid value that contains zero elements:

```mantra
print { [ ] }
```

Expected `OUTPUT`:

```text
[ ]
```

Indexing an empty array produces an out-of-bounds error:

```mantra
print { [ ] @ 1 }
```

Expected `OUTPUT`:

```text
Error: index 1 is out of bounds for value with 0 items
```

## Structural Separators (`,`)

The comma `,` has structural significance in pattern matching. When commas appear
in an array, they act as explicit separators that patterns must match against.
An array with commas only matches patterns that also include commas.

```mantra
{ [ 1 , 2 , 3 ] ? [ [ x , -- ] => [ ok ] ] }
```

Expected `OUTPUT` (with `--debug`):

```text
[ ok ]
```

Without commas in the pattern, no match occurs:

```mantra
{ [ 1 , 2 , 3 ] ? [ [ x -- ] => [ ok ] ] }
```

Expected `OUTPUT` (with `--debug`):

```text
[ 1 , 2 , 3 ]
```

## Index Lookup (`@`)

The `@` operator provides 1-based indexed access into arrays and expressions. The
index must evaluate to a single positive integer.

### Basic Index Lookup

```mantra
print { [ 10 20 30 ] @ 2 }
```

Expected `OUTPUT`:

```text
20
```

The index is 1-based — `@ 1` returns the first element, `@ 2` returns the second.

### Indexing Variables

Arrays stored in variables can be indexed directly:

```mantra
{ x = [ [ 1 2 3 ] [ 4 5 6 ] [ 7 8 9 ] ] };
print { x @ 2 }
```

Expected `OUTPUT`:

```text
[ 4 5 6 ]
```

### Chained Index Lookups (Matrix Access)

Index lookups chain, enabling multi-dimensional access:

```mantra
{ x = [ [ 1 2 3 ] [ 4 5 6 ] [ 7 8 9 ] ] };
print { x @ 2 @ 3 }
```

Expected `OUTPUT`:

```text
6
```

The expression `x @ 2 @ 3` first extracts the second row (`[ 4 5 6 ]`), then
extracts the third element from that row (`6`).

### Variable and Computed Indices

Indices can be variables or computed expressions:

```mantra
{ i = 3 };
print { [ 10 20 30 ] @ i }
```

Expected `OUTPUT`:

```text
30
```

```mantra
{ i = 1 };
print { [ 10 20 30 ] @ { ~ + i 1 } }
```

Expected `OUTPUT`:

```text
20
```

### Indexing Expressions

The `@` operator also works on parenthesized expressions:

```mantra
print { ( 10 20 30 ) @ 2 }
```

Expected `OUTPUT`:

```text
20
```

### Range Slicing (`@ start .. end`)

Index lookup supports range slicing with `@ start .. end`. The result is a new
array containing elements from position `start` through position `end`, inclusive.
When `end < start`, the slice is returned in reverse order.

```mantra
print { [ a b c d e ] @ 4 .. 2 }
```

Expected `OUTPUT`:

```text
[ d c b ]
```

A single-element range returns that element in an array:

```mantra
print { [ a b c ] @ 2 .. 2 }
```

Expected `OUTPUT`:

```text
[ b ]
```

Ranges work on nested arrays:

```mantra
print { [ [ 1 2 ] [ 3 4 ] [ 5 6 ] ] @ 3 .. 2 }
```

Expected `OUTPUT`:

```text
[ [ 5 6 ] [ 3 4 ] ]
```

Ranges also work on parenthesized expressions:

```mantra
print { ( a b c d ) @ 2 .. 3 }
```

Expected `OUTPUT`:

```text
( b c )
```

#### Variable and Computed Endpoints

Range endpoints can be variables or computed expressions:

```mantra
{ i = 2 };
{ j = 4 };
print { [ a b c d e ] @ i .. j }
```

Expected `OUTPUT`:

```text
[ b c d ]
```

Computed expressions using `~` also work as endpoints:

```mantra
print { [ a b c d ] @ { ~ + 1 1 } .. 3 }
print { [ a b c d ] @ 2 .. { ~ + 2 1 } }
```

Expected `OUTPUT`:

```text
[ b c ]
[ b c ]
```

### Index Lookup Errors

- **Zero index**: Index must be greater than zero.
  ```
  print { [ 10 20 30 ] @ 0 }
  Error: index must be greater than zero, got 0
  ```

- **Negative index**: Negative indices are not supported.
  ```
  print { [ 10 20 30 ] @ -1 }
  Error: index must be greater than zero, got -1
  ```

- **Out of bounds**: Index must not exceed the array length.
  ```
  print { [ 10 20 30 ] @ 4 }
  Error: index 4 is out of bounds for value with 3 items
  ```

- **Non-integer index**: Index must be an integer.
  ```
  print { [ 10 20 30 ] @ "x" }
  Error: index must be an integer, got "x"
  ```

- **Non-container value**: Only arrays and expressions are indexable.
  ```
  print { 10 @ 1 }
  Error: value is not indexable: 10
  ```

- **Symbolic index**: Unbound variables in index positions are not resolved.
  ```
  print { [ 10 20 30 ] @ i }
  [ 10 20 30 ] @ i
  ```

### Range Slice Errors

- **Zero start**: Slice start must be greater than zero.
  ```
  print { [ a b c ] @ 0 .. 2 }
  Error: slice start must be greater than zero, got 0
  ```

- **Out of bounds end**: Slice end must not exceed the array length.
  ```
  print { [ a b c ] @ 2 .. 4 }
  Error: slice end 4 is out of bounds for value with 3 items
  ```

- **Multiple values**: Start must evaluate to a single integer.
  ```
  print { [ a b c ] @ { 1 2 } .. 3 }
  Error: slice start must evaluate to one integer, got 1 2
  ```

- **Non-integer endpoint**: End must be an integer.
  ```
  print { [ a b c ] @ 1 .. "x" }
  Error: slice end must be an integer, got "x"
  ```

- **Stepped slices**: Stepped ranges (`by`) are not supported for index lookups.
  ```
  print { [ a b c d ] @ 1 .. 4 by 2 }
  Error: Stepped index slices are not supported
  ```

- **Unbound variables**: Symbolic references in index positions are not resolved.
  ```
  print { [ a b c ] @ i .. 3 }
  [ a b c ] @   i .. 3
  ```

## Concatenation (`&`)

The `&` operator concatenates arrays, expressions, or strings depending on the
input shape. It preserves the type of the operands.

### Array Concatenation

Prefix form:

```mantra
print { & [ 1 2 ] [ 3 4 ] [ 5 6 ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 5 6 ]
```

Infix form:

```mantra
print { [ 1 2 ] & [ 3 4 ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 ]
```

### Expression Concatenation

Concatenation preserves parenthesized expression types:

```mantra
print { & ( 1 2 3 ) ( 4 5 6 ) }
```

Expected `OUTPUT`:

```text
( 1 2 3 4 5 6 )
```

For more examples, see [Concatenation](lists-sequences/concatenation.md).

## Ranges

The `..` operator expands integer, float, and single-character string ranges.

### Integer Range

```mantra
print { 1 .. 3 }
```

Expected `OUTPUT`:

```text
1 2 3
```

### Signed Integer Range

Ranges can span negative and positive values:

```mantra
print { -3 .. 3 }
```

Expected `OUTPUT`:

```text
-3 -2 -1 0 1 2 3
```

### Float Range

Float ranges require an explicit step via `by`:

```mantra
print { 0.0 .. 1.0 by 0.2 }
```

Expected `OUTPUT`:

```text
0 0.2 0.4 0.6 0.8 1
```

Reverse float ranges work with negative steps:

```mantra
print { 1.0 .. 0.0 by -0.2 }
```

Expected `OUTPUT`:

```text
1 0.8 0.6 0.4 0.2 0
```

### Stepped Integer Range

Integer ranges support a `by` clause for custom step sizes:

```mantra
print { 0 .. 10 by 2 }
```

Expected `OUTPUT`:

```text
0 2 4 6 8 10
```

Reverse stepped ranges:

```mantra
print { 10 .. 0 by -2 }
```

Expected `OUTPUT`:

```text
10 8 6 4 2 0
```

Non-uniform steps truncate before exceeding the end:

```mantra
print { 0 .. 10 by 3 }
```

Expected `OUTPUT`:

```text
0 3 6 9
```

### Variable and Computed Endpoints

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

Computed expressions also work:

```mantra
print { { ~ + 0 - 1 } .. { ~ + 1 } by { ~ / ( + 2.0 ) } }
```

Expected `OUTPUT`:

```text
- 1 - 0.5 0 0.5 1
```

### Character Range

Single-character string ranges expand alphabetically:

```mantra
print { "a" .. "c" }
```

Expected `OUTPUT`:

```text
"a" "b" "c"
```

Character ranges do not support stepped expansion (`by`):

```
print { "a" .. "z" by 2 }
Error: explicit character range steps are not supported
```

### Range Errors

- **Direction mismatch**: Step direction must match the range direction.
  ```
  print { 0 .. 3 by -1 }
  Error: range step direction does not reach end
  ```

- **Zero step**: Step cannot be zero.
  ```
  print { 0 .. 3 by 0 }
  Error: range step cannot be zero
  ```

- **Missing step**: `by` requires a value.
  ```
  print { 0 .. 3 by }
  Error: Missing range step after "by"
  ```

- **Non-finite values**: Range endpoints and step must be finite numbers.
  ```
  print { 0 .. 1 by nan }
  Error: range values and step must be finite
  ```

For more examples, see [Ranges](lists-sequences/ranges.md).

## Explode and Implode

`explode` turns a string into a sequence of character values. `implode` turns
character values back into a single string.

### Explode

```mantra
print { explode "abc" }
```

Expected `OUTPUT`:

```text
"a" "b" "c"
```

### Implode

```mantra
print { implode "a" "b" "c" }
```

Expected `OUTPUT`:

```text
"abc"
```

For more examples, see [Explode and Implode](lists-sequences/explode-implode.md).

## Staged Repeat and Iteration

Staged repeat (`::`) iterates over a sequence, binding each element to a variable
via `@`. The pattern `[ template ] :: values @ binding` evaluates the template
once for every element in the driver sequence.

### Basic Iteration

```mantra
print { [ x ] :: [ 10 20 30 ] @ x }
```

Expected `OUTPUT`:

```text
[ 10 ] [ 20 ] [ 30 ]
```

The driver `[ 10 20 30 ]` yields three elements. For each, `x` is bound to the
element and the template `[ x ]` is evaluated.

### Iteration with Variables

```mantra
values = [ 2 3 4 ];
print { [ ~ * x * x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ * 4 ] [ * 9 ] [ * 16 ]
```

### Iteration with Parenthesized Expressions

```mantra
print { [ x ] :: ( a b c ) @ x }
```

Expected `OUTPUT`:

```text
[ a ] [ b ] [ c ]
```

### Iteration with Ranges

```mantra
print { i : -1.0 .. 1.0 by 1.0 @ i }
```

Expected `OUTPUT`:

```text
- 1 0 1
```

### Iteration Without Binding

When no `@ binding` is specified, the template is simply repeated once per
element without variable substitution:

```mantra
print { [ item ] :: [ a b c ] }
```

Expected `OUTPUT`:

```text
[ item ] [ item ] [ item ]
```

### Structured Items

Iteration handles nested structures:

```mantra
print { [ x ] :: [ [ 1 2 ] ( 3 4 ) ] @ x }
```

Expected `OUTPUT`:

```text
[ [ 1 2 ] ] [ ( 3 4 ) ]
```

### Empty Drivers

An empty driver produces no output:

```mantra
print { [ x ] :: [ ] @ x }
```

Expected `OUTPUT` (empty):

```text
```

## Comparison with Conventional Languages

| Aspect | Mantra | Conventional Languages |
|---|---|---|
| Array elements | Any AST node (integers, strings, arrays, expressions, scopes) | Homogeneous types (usually) |
| Indexing | 1-based | 0-based (usually) |
| Ranges | `..` operator with optional `by` step | Language-specific (e.g., `range()`, `..` in Rust) |
| Slicing | `@ start .. end` (inclusive both ends) | Varies (`[start:end]`, `[start:end+1]`) |
| Reverse slice | Automatic when `end < start` | Requires `reversed()` or negative step |
| Concatenation | `&` operator | Language-specific (`+`, `concat`, `..`) |
| Iteration | `[ template ] :: values @ x` (staged repeat) | `for`/`foreach` loops, comprehensions |
| String split/join | `explode`/`implode` | `split`/`join`, `implode`/`explode` (PHP) |

## See Also

- [Ranges](lists-sequences/ranges.md) — Detailed range examples
- [Concatenation](lists-sequences/concatenation.md) — Concatenation reference
- [Explode and Implode](lists-sequences/explode-implode.md) — String splitting and joining
- [Repeat](../../transformations/repeat.md) — `:` repeat and `::` staged repeat semantics
- [Selection](../../transformations/selection.md) — `?` pattern matching on arrays
- [Compute Scopes](../../compute/index.md) — `` ` ` `` arithmetic reduction
- [Format Strings](rendering-structured-output/format-strings.md) — `fmt` with array arguments
