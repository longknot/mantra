# Compute Scopes

Backticks introduce a compute scope. They tell the runtime to reduce supported
operations inside the enclosed expression before the wrapper disappears.

```mantra
` expression `
```

Compute scope is the syntax-level trigger for arithmetic reduction in Mantra.
It works on a subtree, not on plain text.

## What Compute Scope Does

When the runtime encounters a backtick scope, it performs three steps:

1. Evaluate descendants so variables and nested scopes resolve first.
2. Run the compute pipeline over the enclosed tree.
3. Remove the backtick wrapper and replace it with the computed result.

The result is still a tree. The difference is that supported operators inside
the scope have already been reduced.

## Basic Example

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

Without compute scope, the same expression remains symbolic:

```mantra
+ 1 2 3
```

Output:

```text
+ 1 + 2 + 3
```

## Supported Reductions

Compute scope reduces the operator families documented in
[Compute and Operators](../compute/index.md):

- Integer arithmetic: `+`, `-`, `*`, `/`
- Float arithmetic: the same operators on floating-point values
- Comparisons: `<`, `>`, `<=`, `>=`, `==`, `!=`
- Boolean logic: `and`, `or`, `xor`
- Math functions: `sin`, `cos`, `tan`, `floor`, `ceil`, `round`

If an expression is not supported, compute leaves it symbolic.

## Compute Scope With Other Forms

### Variables

Variables are resolved before compute runs:

```mantra
x = [ + 1 2 3 ]
`x`
```

Output:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

### Repeat

Compute scope combines with repeat. The repeated copies are computed after the
repeat expands:

```mantra
`[ + 1 2 3 ] : 3`
```

Output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

For more detail, see [Repeat with Compute Scopes](../transformations/repeat-with-compute-scopes.md).

### Evaluation Scopes

Compute scope can appear inside evaluation scopes. Evaluation handles structure
first, then compute reduces any supported subtrees:

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Output:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

### Nested Compute Scopes

Nested backticks are processed inside-out. The inner scope computes first, then
the outer scope sees the reduced tree.

```mantra
` + ` 1 2 ` 3 `
```

Output:

```text
+ 6
```

## Meta-Compute Operator

The `~` meta-compute operator targets a specific node or subtree without
requiring a full backtick scope. See [Meta-Compute Operator](../compute/meta-compute-operator.md).

```mantra
{ ~ * 1.5 2 }
```

Output:

```text
* 3
```

## Shell Quoting

When you pass backticks through a shell, wrap the full program in single quotes
so the shell does not treat them as command substitution:

```bash
echo '` + 1 2 3 `' | ./bin/mantra
```

## When Computation Does Not Reduce

Not every form inside compute scope reduces to a single number. Unsupported
operators, partial expressions, and non-numeric trees remain symbolic after the
compute pass.

For the full operator catalog, see [Compute and Operators](../compute/index.md).
