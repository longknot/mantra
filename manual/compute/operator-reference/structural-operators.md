# Structural Operators

Structural operators act on tree shape, strings, or rewrite state rather than
on numeric values. They are the operators to reach for when you want to
reshape data or apply structural rewrites.

## Quick Reference

| Operator | Meaning |
|---|---|
| `&` | Concatenate sibling sequences |
| `explode` | Split a string into character values |
| `implode` | Join character values into a string |
| `?` | Apply a selection rewrite |
| `:=?` | Inline selection, same runtime behavior as `?` |
| `$?` | State selection, the iterative selection form |

Selection and state-selection are structural rewrites. The full rule syntax is
documented in the transformations section; this page focuses on how the
operators behave on tree data.

## Concatenation (`&`)

The `&` operator concatenates arrays, expressions, or strings into a single
sequence:

```mantra
[ & [ 1 2 ] [ 3 4 ] ]
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 ]
```

## Explode

The `explode` operator decomposes a string into its character components:

```mantra
explode "abc"
```

Expected `OUTPUT`:

```text
[ "a" "b" "c" ]
```

For the full explode/implode behavior, including multi-argument forms, see
[Explode and Implode](../../data/lists-sequences/explode-implode.md).

## Implode

The `implode` operator performs the inverse of `explode` - it combines
character values into a string:

```mantra
implode [ "a" "b" "c" ]
```

Expected `OUTPUT`:

```text
"abc"
```

## Selection Operator (`?`)

The `?` operator applies selection rules to a tree. It matches against a
subject and rewrites the first matching subtree:

```mantra
{ [ 1 2 3 ] ? [ 2 => "replaced" ] }
```

Expected `OUTPUT`:

```text
[ 1 "replaced" 3 ]
```

Selection rules use the `=>` transformation operator to define the mapping
from pattern to replacement. For the full rewrite semantics, see
[Selection](../../transformations/selection.md).

### Inline Selection (`:=?`)

`:=?` is the inline form of selection. It uses the same runtime behavior as
`?`, but keeps the syntax distinct for forms that want an explicit inline
selection node.

```mantra
{ [ 1 2 3 ] :=? [ 2 => "replaced" ] }
```

Expected `OUTPUT`:

```text
[ 1 "replaced" 3 ]
```

## State Selection (`$?`)

The `$?` form applies state-based selection rules. It is the iterative form of
selection and is most useful when a rewrite needs to keep applying across
repeat iterations:

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ 2 3 ] )
```

State selection is useful when the transformation depends on variables or
context established during evaluation. For the full iteration model, see
[State Selection](../../transformations/selection/state-selection.md).

## Common Patterns

### Chaining Structural Operations

Structural operators can chain:

```mantra
[ & explode "ab" explode "cd" ]
```

Expected `OUTPUT`:

```text
[ "a" "b" "c" "d" ]
```

### Structural Operators in Compute Scope

Some structural results can participate in compute contexts when they become
numeric. Use the meta-compute operator to trigger computation on a structural
subtree if needed.

## Related Pages

- [Meta-Compute Operator](../meta-compute-operator.md)
- [Compute Scope](../compute-scope.md)
- [Selection](../../transformations/selection.md)
- [State Selection](../../transformations/selection/state-selection.md)
- [Repeat Operator](../../transformations/repeat-operator.md)
- [Explode and Implode](../../data/lists-sequences/explode-implode.md)
