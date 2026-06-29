# List Containers

Square brackets `[ ... ]` group values and expressions into a list or array
container. Lists are one of the core scope forms in Mantra alongside expressions
`( ... )`, evaluation scopes `{ ... }`, and compute scopes `` ` ... ` ``.

```mantra
[ + 1 2 3 ]
```

The runtime may format this into a more explicit tree-shaped output:

```text
[ + 1 + 2 + 3 ]
```

## Syntax

```mantra
[ expression ]
```

Square brackets create a `TArrayNode` at parse time. The parser accepts the
bracket-delimited content, builds child nodes inside, and links them using the
standard left-child / right-sibling tree representation.

### Empty Lists

An empty list is valid syntax:

```mantra
[ ]
```

### Nested Lists

Lists can contain other lists, creating multi-level structures:

```mantra
[ [ 1 2 ] [ 3 4 ] [ 5 6 ] ]
```

This creates a list of three sub-lists. Nested lists support chained `@` lookups
for matrix-style access.

### Multi-element Lists

Lists hold any number of space-separated elements:

```mantra
[ 1 2 3 ]
[ a b c d e ]
[ "hello" "world" 42 ]
```

Elements can be integers, floats, strings, variables, expressions, or other
containers.

## Square Bracket Forms

Square bracket forms are useful for grouping values and expressions into a
single visible container.

```mantra
[ expression ]
```

Use square brackets when the source should communicate list or sequence
semantics. Use parentheses `( ... )` when the intended grouping is expression
structure rather than a list container.

## Indexing

The `@` operator provides positional access into list containers. Indexing is
1-based: the first element is at position 1.

### Single Element Access

```mantra
print { [ 10 20 30 ] @ 2 }
```

Expected output:

```text
20
```

### Variable Index

The index can be a variable:

```mantra
{ i = 3 };
print { [ 10 20 30 ] @ i }
```

Expected output:

```text
30
```

### Computed Index

The index can be a computed expression:

```mantra
{ i = 1 };
print { [ 10 20 30 ] @ { ~ + i 1 } }
```

Expected output:

```text
20
```

### Parenthesized Expression Indexing

The `@` operator also works on parenthesized expression containers:

```mantra
print { ( 10 20 30 ) @ 2 }
```

Expected output:

```text
20
```

### Range Slicing

The `@ start .. end` form extracts a sub-range from a list. The slice is
returned as a new list container (same bracket type as the source).

```mantra
print { [ a b c d e ] @ 4 .. 2 }
```

Expected output:

```text
[ d c b ]
```

The range traverses backward when `end < start`. A single-position range
returns a one-element list:

```mantra
print { [ a b c ] @ 2 .. 2 }
```

Expected output:

```text
[ b ]
```

Parenthesized sources produce parenthesized slices:

```mantra
print { ( a b c d ) @ 2 .. 3 }
```

Expected output:

```text
( b c )
```

Nested lists slice recursively:

```mantra
print { [ [ 1 2 ] [ 3 4 ] [ 5 6 ] ] @ 3 .. 2 }
```

Expected output:

```text
[ [ 5 6 ] [ 3 4 ] ]
```

Computed range endpoints are supported:

```mantra
print { [ a b c d ] @ { ~ + 1 1 } .. 3 }
print { [ a b c d ] @ 2 .. { ~ + 2 1 } }
```

Expected output:

```text
[ b c ]
[ b c ]
```

### Nested List Indexing

Chained `@` lookups access elements inside nested lists (matrix-style):

```mantra
{ x = [ [ 1 2 3 ] [ 4 5 6 ] [ 7 8 9 ] ] };
print { x @ 2 @ 3 }
```

Expected output:

```text
6
```

### Index Errors

Indexing enforces several bounds checks. All errors are runtime errors:

| Condition | Error |
|---|---|
| Index is 0 or negative | `Error: index must be greater than zero, got N` |
| Index exceeds length | `Error: index N is out of bounds for value with M items` |
| Target is not a container | `Error: value is not indexable: X` |
| Non-integer index | `Error: index must be an integer, got X` |
| Slice start is 0 or negative | `Error: slice start must be greater than zero, got N` |
| Slice end exceeds length | `Error: slice end N is out of bounds for value with M items` |
| Slice start returns multiple values | `Error: slice start must evaluate to one integer, got ...` |
| Non-integer slice endpoint | `Error: slice end must be an integer, got X` |
| Stepped slice (`by`) | `Error: Stepped index slices are not supported` |

### Symbolic (Unbound Variable) Index

When an index or slice endpoint references an unbound variable, the lookup is
not executed — the expression is returned unevaluated:

```mantra
print { [ 10 20 30 ] @ i }
```

Expected output:

```text
[ 10 20 30 ] @ i
```

The same applies to range slices:

```mantra
print { [ a b c ] @ i .. 3 }
```

Expected output:

```text
[ a b c ] @   i .. 3
```

## Lists with Repeat

The `:` repeat operator works inside compute scopes to clone and reduce list
contents:

```mantra
`[ + 1 2 3 ] : 3`
```

Expected output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

## Lists with Staged Repeat (Iteration)

The `::` staged repeat operator iterates over a sequence, binding each element
to a variable:

```mantra
print { [ x ] :: [ 10 20 30 ] @ x }
```

Expected output:

```text
[ 10 ] [ 20 ] [ 30 ]
```

## Lists with Concatenation

The `&` operator concatenates lists:

```mantra
print { [ 1 2 ] & [ 3 4 ] }
```

Expected output:

```text
[ 1 2 3 4 ]
```

Prefix form supports multiple operands:

```mantra
print { & [ 1 2 ] [ 3 4 ] [ 5 6 ] }
```

Expected output:

```text
[ 1 2 3 4 5 6 ]
```

## Related Pages

- [Lists and Sequences](../data/lists-sequences.md) — Comprehensive reference for lists, ranges, concatenation, iteration, and explode/implode
- [Expressions](expressions.md) — Parenthesized expression grouping
- [Evaluation Scopes](evaluation-scopes.md) — Curly brace evaluation
- [Compute Scopes](compute-scopes.md) — Backtick compute reduction
- [Selection](../transformations/selection.md) — `?` pattern matching on lists
- [Repeat](../transformations/repeat.md) — `:` repeat and `::` staged repeat semantics
- [Ranges](../data/lists-sequences/ranges.md) — Detailed range operator reference
- [Concatenation](../data/lists-sequences/concatenation.md) — `&` operator reference
- [Explode and Implode](../data/lists-sequences/explode-implode.md) — String splitting and joining

