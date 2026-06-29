# Fixed Scopes

Single quotes mark a fixed scope — the subtree inside is not evaluated, rewritten,
or transformed by the runtime.

```mantra
' expression '
```

The fixed scope creates an expression node marked with the `TK_FIXED` flag at parse
time. Everything inside single quotes retains its original tree structure throughout
the entire evaluation, selection, and computation pipeline.

## How It Works

When the parser encounters `' ... '`, it:

1. Sets the `FixedScope` parser flag to prevent nested fixed scopes.
2. Allocates an expression node and applies the `TK_FIXED` meta flag to its `Data` field.
3. Parses the enclosed content as a normal expression (inheriting the `TK_FIXED` scope ID).
4. Consumes the closing `'` and clears the `FixedScope` flag.

The `TK_FIXED` flag in the node's `Data` field is what the runtime checks during
evaluation, matching, and rewriting — when it sees the flag, it skips the node
entirely.

## Basic Examples

```mantra
' + 1 2 3 '
```

OUTPUT:
```
( + 1 2 3 )
```

The expression is preserved as structure — the `+` operator is not evaluated.
The output wraps in parentheses because the formatter renders the expression node,
not the apostrophe delimiters.

```mantra
' x = 42 '
```

OUTPUT:
```
( x 42 )
```

The assignment inside a fixed scope is not executed — it remains as literal
tree structure.

```mantra
' [ 1 2 : 2 ] '
```

OUTPUT:
```
( [ 1 2 :     2 ] )
```

The repeat operator `:` is preserved as structure rather than being expanded.
Without the fixed scope, `{ [ 1 2 : 2 ] }` would evaluate to `[ 1 2 1 2 ]`.

## Comparison with Other Scope Types

| Delimiter | Scope Type | Evaluates | Computes | Transforms |
|---|---|---|---|---|
| `{ ... }` | Evaluation scope | Yes | No | Yes |
| `` ` ... ` `` | Compute scope | Yes | Yes | No |
| `' ... '` | Fixed scope | No | No | No |
| `[ ... ]` | List container | Contextual | No | Contextual |
| `( ... )` | Expression | Contextual | No | Contextual |

Side-by-side comparison:

```mantra
{ + 1 2 3 }       → + 1 2 3         (evaluated; scope collapses)
' + 1 2 3 '       → ( + 1 2 3 )     (fixed; structure preserved)
` + 1 2 3 `       → + 6             (computed; reduced to result)
```

## What Is Prevented

Fixed scopes block all of the following runtime behaviors:

### Variable Substitution

Variables inside a fixed scope are not resolved:

```mantra
x = 42
' x '
```

OUTPUT:
```
( x )
```

The variable name `x` appears literally, not the value `42`.

### Repeat Expansion

Repeat operators are not expanded:

```mantra
' 1 : 3 '
```

OUTPUT:
```
( 1 : 3 )
```

The `: 3` repeat is preserved as structural data.

### Evaluation Scope Collapse

Nested evaluation scopes inside fixed quotes do not evaluate:

```mantra
' { + 1 2 } '
```

OUTPUT:
```
( + 1 2 )
```

The inner `{ ... }` is preserved — note the evaluation scope itself is still
parsed, but the `TK_FIXED` flag on the parent prevents the evaluation pipeline
from processing it. The formatter renders the evaluation scope's content
(`+ 1 2`) since the scope node remains in the tree.

### Compute Reduction

Arithmetic is not reduced:

```mantra
' + 1 2 3 '
```

OUTPUT:
```
( + 1 2 3 )
```

Without the fixed scope, `` ` + 1 2 3 ` `` would reduce to `+ 6`.

## Fixed Scopes in Arrays

Fixed scopes inside arrays preserve their contents while siblings evaluate normally:

```mantra
[ ' + 1 2 ' 3 ]
```

OUTPUT:
```
[ ( + 1 2 )         3 ]
```

The first element is protected; the second element (`3`) is a regular value.

## Fixed Scopes and Selection Rules

### Fixed Subject

When a fixed scope is the subject of a selection rewrite, the fixed flag
is checked on the wrapper node. The selection still processes the inner
contents:

```mantra
' [ 1 2 3 ] ' ? [ x => x + 1 ]
```

OUTPUT:
```
( [ 1 + 1 2 3 ] )
```

The selection rewrite applies to the contents inside the fixed scope, but
the result remains wrapped in the fixed expression.

### Fixed Pattern in Rules

Fixed scopes in transform rule patterns and replacements preserve literal
structure. This is the primary use case for fixed scopes in selection rules:

```mantra
[ 1 2 3 ] ? [ x => ' + x 1 ' ]
```

OUTPUT:
```
[ ( + 1 1 )         2         3 ]
```

The first element matches `x` and is replaced by the fixed scope `' + x 1 '`,
which becomes `( + 1 1 )` in output — the `x` inside is still substituted
with the matched value, but the `+` operator is not computed.

### Fixed Pattern Templates

Fixed scopes are the natural way to embed transform patterns that should not
be evaluated when constructed:

```mantra
' x => x + 1 '
```

OUTPUT:
```
( x => x + 1 )
```

The pattern is preserved as literal structure for later use.

## Fixed Scopes and Variables

When assigned to a variable, a fixed scope preserves its literal structure:

```mantra
x = ' + 1 2 '
x
```

OUTPUT:
```
x ( + 1 2 ) 
x
```

The variable `x` stores the fixed expression node. When referenced, it outputs
as `( + 1 2 )` — the structure is preserved.

## Output Format

Fixed scopes do not render with their apostrophe delimiters in the output.
The formatter treats them as expression nodes and wraps the contents in
parentheses:

```mantra
print ' hello world '
```

OUTPUT:
```
( hello world )
```

```mantra
' a ' ' b ' ' c '
```

OUTPUT:
```
( a ) ( b ) ( c )
```

Each fixed scope becomes a parenthesized expression in the formatted output.

## Nested Fixed Scopes

Nested fixed scopes are **not** allowed. The parser uses a `FixedScope` boolean
flag to track whether a fixed scope is currently being parsed. If another
apostrophe is encountered while the flag is set, the parser skips it:

```mantra
' ' x ' '
```

OUTPUT:
```
( ) x ( )
```

The inner `' x '` is not parsed as a nested fixed scope — it is treated as
separate tokens outside the first fixed scope.

## Backslash — Single-Node Fixed Protection

The `\` (backslash) meta flag provides the same fixed protection but targets
a single node instead of wrapping a scope:

```mantra
\ [ + 1 2 ]
```

OUTPUT:
```
[ + 1 2 ]
```

| Feature | `' ... '` | `\` |
|---|---|---|
| Scope | Full subtree | Single node |
| Nesting | Not allowed | N/A |
| Output | Parentheses | No wrapper |

Use backslash when you need to protect one element inside a larger expression
without quoting the entire scope. See [Meta Flags](meta-flags.md) for details.

## When to Use Fixed Scopes

Use `' ... '` when you want to:

- **Embed literal tree structure** — preserve operators, variables, and patterns
  as data rather than executable code.
- **Construct pattern templates** — create selection rules or transform patterns
  that are applied later, not immediately.
- **Protect subtrees from evaluation** — prevent specific parts of an expression
  from being evaluated, computed, or rewritten.
- **Store unevaluated expressions** — assign tree structures to variables for
  deferred processing.

Do not use `' ... '` when you want to:

- Evaluate an expression — use `{ ... }` instead.
- Compute arithmetic — use `` ` ... ` `` instead.
- Group structurally without protection — use `( ... )` or `[ ... ]`.

## Related Pages

- [Meta Flags](meta-flags.md) — `\` prefix for single-node protection
- [Evaluation Scopes](evaluation-scopes.md) — `{ ... }` for evaluation
- [Compute Scopes](compute-scopes.md) — `` ` ... ` `` for arithmetic reduction
- [Delimiters and Scope Tokens](tokens-whitespace/delimiters-scope-tokens.md) — all scope tokens
- [Syntax Index](index.md) — full syntax overview
