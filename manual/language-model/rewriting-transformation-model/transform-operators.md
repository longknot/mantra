# Transform Operators

A transform operator creates a **rewrite rule**: a pattern (LHS) paired with a replacement template (RHS).

```mantra
print { [ 1 2 3 ] ? [ x ] => [ x + 1 ] }
```

Both sides of a transform stay **unevaluated** at construction time — they are structural templates consumed by the inference engine, not computed values.

## Operators

| Operator | Node class | Direction | Substitution |
|---|---|---|---|
| `=>` | `TTransformationNode` | Forward | No |
| `<=>` | `TEquivalenceNode` | Both | No |
| `:=` | `TInlineTransformationNode` | Forward | No |
| `==> ` | `TSymbolSubstitutionNode` | Forward | Yes (always strict) |
| `==>>` | `TSubstitutionNode` | Forward | Conditional |
| `<==>` | `TEquivalenceSubstitutionNode` | Both | Conditional |

## Standard Transforms

`=>` defines a forward rewrite rule. The left side is the pattern; the right side is the replacement.

```mantra
print { [ 1 2 3 ] ? [ x ] => [ x * 2 ] }
```

The pattern `[ x ]` matches each single-element subsequence. The replacement `[ x * 2 ]` doubles the matched value.

Transform nodes override `Evaluate` to return their children **unevaluated**. This keeps the pattern and replacement as structural templates for the inference engine rather than computing them immediately.

The `\` prefix marks a transform as **fixed**: both sides are structural templates instead of pattern templates. A fixed transform requires an exact structural match — no pattern variables are extracted.

## Equivalence Transforms

`<=>` defines a bidirectional rule. The inference engine tries both directions during matching:

```mantra
x + 0 <=> x
```

This rewrites `x + 0` to `x` in the forward direction and `x` to `x + 0` in the reverse direction. The `TEquivalenceNode` class inherits from `TTransformationNode` and is handled specially by the matcher, which swaps LHS/RHS when probing the reverse direction.

## Inline Transforms

`:=` defines an inline transform. It behaves like `=>` but is marked with inline semantics. The `TInlineTransformationNode` class inherits the same no-op `Evaluate` behavior from `TTransformationNode`. Inline transforms are used where the transformation should be applied directly at the parse level rather than through the selection mechanism.

## Substitution Transforms

Substitution transforms require that the **pattern symbols** and **replacement symbols** are identical. The matcher collects all identifiers and pattern variables from both sides and rejects the rule if the sets differ.

### Symbol Substitution (`==> `)

`==> ` always enforces strict symbol identity. Both sides must use exactly the same symbols.

```mantra
x + y ==> y + x
```

This is accepted because both sides reference `x` and `y`. A rule like `x + y ==> z + w` would be rejected because the symbols differ.

The `TSymbolSubstitutionNode` class signals the matcher that strict substitution is mandatory regardless of configuration.

### Conditional Substitution (`==>>`)

`==>>` enforces strict symbol identity when the `substitution.strict` setting is enabled. When the setting is disabled, it falls back to standard transform behavior. This allows the same syntax to be either strict or flexible depending on the context.

The `TSubstitutionNode` class delegates the strictness decision to the `IsStrictSubstitutionEnabled` runtime check.

### Bidirectional Substitution (`<==>` )

`<===>` combines bidirectional matching with conditional substitution semantics. It tries both directions like `<=>` and enforces symbol identity when `substitution.strict` is enabled, like `==>>`.

The `TEquivalenceSubstitutionNode` class inherits from `TSubstitutionNode` and adds the bidirectional probing behavior from `TEquivalenceNode`.

## Transparent Grouping

`<< >>` groups expressions transparently at the parse level. Unlike `()`, which creates a wrapper node in the AST, `<< >>` returns the inner expression directly without adding a grouping node. This is useful for controlling operator precedence without changing the tree structure.

## Fixed Transforms

Prefixing a transform with `\` marks it as fixed. Fixed transforms use structural matching instead of pattern matching — both sides are treated as literal templates with no variable extraction.

## Interaction with Selection

Transforms are consumed by the selection operator (`?`). The selection applies the transform's pattern to the subject tree, collects bindings, then evaluates the replacement template using those bindings.

The matcher groups all transform variants via `IsTransformationNode()`, which returns true for all six operator types. It distinguishes substitution rules via `IsSubstitutionRule()` to apply the symbol identity check where required.

## Source Files

- `src/tokens.pas` — Token constants (`TK_TRANSFORM`, `TK_EQUIVALENCE`, `TK_INLINE_TRANSFORM`, `TK_SUBST_TRANSFORM`, `TK_SYMBOL_SUBST_TRANSFORM`, `TK_SUBST_EQUIVALENCE`)
- `src/nodes.pas` — Node class definitions and registration
- `src/mathparser.pas` — Parser transitions and node allocation
- `src/matcher_ir.pas` — Matcher IR generation, symbol collection, strict substitution checks
