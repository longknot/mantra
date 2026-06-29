# Evaluation Scopes

Curly braces mark an evaluation scope. The runtime evaluates the enclosed expression
and replaces the scope with the result in the surrounding tree.

```mantra
{ expression }
```

## How It Works

When the runtime encounters `{ ... }`, it:

1. Evaluates all children inside the braces.
2. Replaces the entire `{ ... }` node with its first child (the evaluated result).

This means the scope node itself disappears — only the result remains.

```mantra
print { [ 1 2 3 ] ? [ 1 => 10 ] }
```

OUTPUT:
```
[ 10  2  3 ]
```

The selection `?` rewrites the list inside the scope, and the scope collapses to reveal the result.

## Evaluation Without Computation

Evaluation scopes apply runtime semantics (variable substitution, rule matching,
repeat expansion, etc.) but do **not** perform arithmetic reduction by default.

```mantra
print { + 1 2 3 }
```

OUTPUT:
```
+ 1 2 3
```

The `+` operator is evaluated as a structural node but not computed. To trigger
arithmetic reduction, use a [compute scope](compute-scopes.md) with backticks or
the `~` meta flag.

```mantra
print { ~ { + 1 2 3 } }
```

OUTPUT:
```
+ 6
```

## Common Patterns

### Variable Substitution

Variables inside evaluation scopes are resolved to their bound values.

```mantra
x = 42
print { { x } }
```

OUTPUT:
```
42
```

### Repeat Expansion

Repeat operations are expanded within evaluation scopes.

```mantra
print { { 1 2 3 : 4 } }
```

OUTPUT:
```
1 2 3 1 2 3 1 2 3 1 2 3
```

### Selection and Rewriting

Evaluation scopes are the natural place for structural pattern matching.

```mantra
print { { [ "a" "b" "c" ] ? [ "a" => "A" ] } }
```

OUTPUT:
```
[ "A"  "b"  "c" ]
```

### Inference Queries

Inference operators evaluate within scopes, returning `1` (success) or `0` (failure).

```mantra
print { { 1 => 2 |= [ 1 => 2 ] : 1 } }
```

OUTPUT:
```
1
```

### Assignment Inside Scopes

Assignments can be made inside evaluation scopes to set up state before evaluating
an expression.

```mantra
print { { max_steps = 2; 1 => 3 |= [ 1 => 2, 2 => 3 ] : max_steps } }
```

OUTPUT:
```
1
```

The `max_steps` variable is defined inside the scope and used by the inference query
in the same scope.

## Nested Evaluation Scopes

Evaluation scopes can be nested. Each scope evaluates independently from the
inside out.

```mantra
print { { { 1 2 3 : 2 } } }
```

OUTPUT:
```
1 2 3 1 2 3
```

## Comparison with Other Scope Types

| Syntax | Scope Type | Evaluates | Computes Arithmetic |
|---|---|---|---|
| `{ ... }` | Evaluation scope | Yes | No |
| `` ` ... ` `` | Compute scope | Yes | Yes |
| `' ... '` | Fixed scope | No | No |
| `( ... )` | Expression | Contextual | No |
| `[ ... ]` | List container | Contextual | No |

- **Evaluation scope** (`{ }`) — evaluates children, collapses to result.
- **Compute scope** (`` ` ` ``) — inherits evaluation scope behavior, then
  reduces arithmetic expressions.
- **Fixed scope** (`' '`) — prevents evaluation and transformation entirely.
- **Expression** `( )` — structural grouping; no automatic evaluation.
- **List** `[ ]` — structural grouping; no automatic evaluation.

## Scope Collapse

After evaluation, the `{ ... }` node is replaced by its first child. If the scope
is empty, it is removed entirely. This "collapse" behavior is what distinguishes
evaluation scopes from pure grouping forms like parentheses or brackets.

```mantra
[ { 1 2 3 : 2 } ]
```

OUTPUT:
```
[ 1 2 3 1 2 3 ]
```

The `{ ... }` wrapper disappears; only the expanded repeat result remains inside
the list.

## When to Use Evaluation Scopes

Use `{ ... }` when you want the runtime to:

- Resolve variables to their values.
- Expand repeat operators.
- Apply selection or transform rules.
- Run inference queries.
- Evaluate an expression before it is used in a larger structure.

Do not use `{ ... }` when you want to:

- Prevent evaluation — use `' ... '` (fixed scope) instead.
- Perform arithmetic — use `` ` ... ` `` (compute scope) instead.
- Group structurally without evaluation — use `( ... )` or `[ ... ]`.

## Related Pages

- [Compute Scopes](compute-scopes.md) — arithmetic reduction with backticks
- [Print and Output](../evaluation/evaluation-scopes/print-output.md) — intentional output
- [Curly Brace Evaluation](../evaluation/evaluation-scopes/curly-brace-evaluation.md) — runtime semantics
- [Delimiters and Scope Tokens](tokens-whitespace/delimiters-scope-tokens.md) — all scope tokens
- [Nested Evaluation](../evaluation/nested-evaluation.md) — evaluation within evaluation
