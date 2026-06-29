# Meta Flags

Meta flags prefix a node to modify how the runtime treats it during evaluation,
matching, or rewriting. They are written directly before the target node or
subtree with no operator symbol — the flag character itself carries the meaning.

## Flag Reference

| Flag | Name | Effect |
|---|---|---|
| `~` | Tilde (meta-compute) | Forces arithmetic reduction on the targeted node or subtree |
| `\` | Backslash (fixed) | Protects the node from transformation — same effect as `' ... '` |
| `$` | Dollar (state-selection) | Enables iterative state-selection mode for rewrite rules |
| `^` | Caret (full-match) | Forces full-root match; no subexpression matching |
| `.` | Dot (matching rule) | Marks a rule as a matching-only pattern |
| `@` | At (at-index) | Binds an iterator index or position to the node |

## Tilde — Meta-Compute

The tilde flag tells the runtime to compute the targeted expression even outside
a backtick scope. This is the primary way to trigger arithmetic reduction on a
specific node without wrapping the entire expression in compute scope.

```mantra
[ { ~ + 1 2 3 } ]
```

OUTPUT:
```
[ + 6 ]
```

Without the tilde, the expression inside `{ ... }` would remain unevaluated:

```mantra
[ { + 1 2 3 } ]    → [ + 1 2 3 ]
[ { ~ + 1 2 3 } ]  → [ + 6 ]
```

You can also apply tilde to specific subexpressions within a larger scope:

```mantra
{ ~ + 1 2 ~ * 3 4 }
```

OUTPUT:
```
+ 3 * 12
```

See [Compute Scopes](compute-scopes.md) for the full compute model and
[Compute](../compute/index.md) for supported operators.

## Caret — Full-Match Mode

By default, selection rules can match subexpressions anywhere inside a tree.
Prefixing the rule with `^` requires the pattern to match the entire root node:

```mantra
[ + 1 2 3 ] ? [ + x y => + y x ]       → matches subexpression + 1 2
[ + 1 2 3 ] ? ^ [ + x y => + y x ]     → matches full root
```

Without `^`, the matcher searches all descendant nodes and applies the first
match found. With `^`, only the root node itself is tested.

You can combine `^` with `$` for full-match iterative selection:

```mantra
[ 1 2 3 ] ? $ ^ [ x -- => ... ]
```

See [Selection Rewrite](../transformations/index.md) for selection semantics.

## Dollar — State-Selection Mode

The `$` prefix enables iterative state-selection mode, where rules are applied
repeatedly until no more matches occur. The iteration is bounded by
`MAX_FIXPOINT_STEPS = 1024` to prevent infinite loops.

```mantra
[ 1 2 3 4 5 ] ? $ [ n => n * 2 ]
```

In state-selection mode, each pass of the rewrite updates the subject, and the
next pass operates on the modified result. This continues until a pass produces
no changes or the fixpoint limit is reached.

## Backslash — Fixed Protection

The backslash protects a single node from being transformed. It is the single-
node equivalent of `' ... '` fixed scope:

```mantra
\ [ + 1 2 ]
```

This marks the enclosed node as immune to rewriting during evaluation. The
backslash flag modifies the `Meta` byte of the token ID at the `TK_META`
bit position (`$01000000`).

Use backslash when you need to protect individual elements inside a larger
expression without quoting the entire scope:

```mantra
{ \ [ + 1 2 ] ? [ 1 => 10 ] }   → \ [ + 1 2 ]  (protected from rewrite)
{ [ + 1 2 ] ? [ 1 => 10 ] }     → [ + 10 2 ]   (rewritten normally)
```

See [Fixed Scopes](fixed-scopes.md) for the quote-based alternative.

## At — At-Index and Iterator Binding

The `@` flag binds an iterator index or position to a node. It is commonly used
with repeat operations and list traversals to access element positions:

```mantra
[ 10 20 30 ] : @
```

In this context, `@` provides the current iteration index, allowing rules to
reference positions dynamically.

When used with selection patterns, `@` captures the position of a matched
element within its parent scope:

```mantra
[ a b c d ] ? [ @ x => x _@ ]
```

See [List Containers](list-containers.md) for at-index access patterns and
[Repeat Operator](../transformations/index.md) for iteration contexts.

## Dot — Matching Rule Marker

The `.` prefix marks a rule as a matching-only pattern. Matching rules participate
in pattern comparison but do not produce rewrites themselves — they are used to
guard or qualify other rules.

```mantra
. [ pattern ]    → matching rule (no rewrite)
```

Dot-marked rules are useful for:

- **Guard conditions** — test whether a pattern exists without transforming it
- **Rule composition** — combine multiple matching criteria before applying a rewrite
- **Pattern validation** — verify structure before proceeding with transformations

## Meta Flags in Tokens

Meta flags are encoded in the token ID's high byte. The token layout is:

```
[31..24] META  |  [23..16] RESERVED  |  [15..8] OPERATOR  |  [7..0] ID
```

The `META` byte (`TK_META = $01000000`) stores flag information. When the parser
encounters a meta flag character, it sets the corresponding bit in the token
rather than creating a separate operator node.

See [Tokens and Whitespace](tokens-whitespace.md) for the full token structure.

## Related Pages

- [Fixed Scopes](fixed-scopes.md) — `' ... '` scope-level protection
- [Compute Scopes](compute-scopes.md) — `~` tilde and compute
- [Tokens and Whitespace](tokens-whitespace.md) — token structure and META byte
- [Syntax Index](index.md) — full syntax overview
