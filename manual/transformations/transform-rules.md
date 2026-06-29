# Transform Rules

Transform rules define structural rewrites. They are the core building block of
pattern matching and tree rewriting in Mantra. A transform rule says: *when this
pattern matches, replace it with this template*.

```mantra
pattern => replacement
```

Transform rules are always used **indirectly** — they do nothing in isolation.
They must be collected into a ruleset and applied through selection (`?`) or
inference (`|=`).

## Syntax

A transform rule has two sides separated by a transform operator:

```mantra
lhs => rhs
```

- **Pattern (LHS):** Structural template to match against the subject tree.
- **Replacement (RHS):** Template to substitute the matched portion with.

Both sides are kept **unevaluated** — they are structural templates, not executable
code. Pattern variables only materialize when the matcher applies them.

### Pattern Variables

| Symbol | Matches |
|---|---|
| Lowercase (e.g. `x`) | Single identifier or node |
| Uppercase (e.g. `X`) | Any node, including expressions |
| `--` | Tail sequence (all remaining siblings) |
| `x --` | Captures `x` plus everything after it |

In replacement templates, `x --` splices the matched node and captured tail back
into the output, equivalent to `all x` for matcher-bound symbols.

### Selectors

Replacement templates can use `lhs`, `rhs`, and `all` to extract parts of a
matched binding:

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

Here `x` captures `1`, and `rhs x` extracts the right siblings (`2 3`).

## Operators

Mantra provides six transform operators that differ in direction, replacement
scope, and matching strategy:

| Operator | Node Type | Name | Direction | Replacement |
|---|---|---|---|---|
| `=>` | `TTransformationNode` | Basic transform | Forward | Matched span |
| `=>>` | `TInlineTransformationNode` | Inline transform | Forward | Entire subject |
| `==>` | `TSymbolSubstitutionNode` | Symbol substitution | Forward | All symbol occurrences |
| `==>>` | `TSubstitutionNode` | Binding substitution | Forward | All symbol occurrences |
| `<=>` | `TEquivalenceNode` | Equivalence | Both | Matched span |
| `<==>` | `TEquivalenceSubstitutionNode` | Substitution equivalence | Both | All symbol occurrences |

## Rule Declarations

The `rule` keyword declares a named, reusable ruleset:

```mantra
rule f [
  f x => x
];

print { f 7 };
```

Expected `OUTPUT`:

```text
7
```

Rules declared with `rule` are automatically applied via head dispatch: when the
leading symbol of a subject matches the leading symbol of a rule, the rewrite
fires without an explicit `?`.

Rulesets can contain multiple rules separated by commas. Rules are tried in order;
the first matching rule wins. Place specific rules before broad fallback rules to
ensure correct priority.

Rules can also be stored in variables and referenced by name:

```mantra
swap = [ x y ] <=> [ y x ];

print { [ 1 2 ] ? swap : 1 };
```

Expected `OUTPUT`:

```text
[ 2 1 ]
```

## Transparent Grouping

Transparent grouping `<< ... >>` provides parse-level grouping without creating a
surviving scope node. This is useful when a transform operand needs grouping:

```mantra
ih = << + m : + n >> => << + n : + m >>;
```

This keeps each repeat expression on the intended side of `=>`, but the grouping
itself is not rendered in the resulting rule or witness output.

Because `<< ... >>` does not create an AST wrapper, non-atomic grouped forms
cannot be followed by an implicit sibling term. Use ordinary parentheses when a
compound expression must remain an atom inside a larger sequence.

## Fixed Transforms

A transform or equivalence can be marked **fixed** by placing `\` immediately
before the transform operator:

```mantra
ih = << + m : + n >> \ <=> << + n : + m >>;
```

In a fixed transform, the pattern is matched structurally — variable-shaped terms
do not become fresh matcher bindings. This supports exact hypothesis-style
rewrites where literal symbols must be preserved:

```mantra
<< + m : + n >>      => << + n : + m >>    |= [ ih ] : 1   // succeeds
<< + 1 : + n >>      => << + n : 1 >>      |= [ ih ] : 1   // fails
```

A transform-valued binding can also be referenced as fixed:

```mantra
proposition = << + m : + n >> => << + n : + m >>;
ih = \ proposition;
```

When `ih` is collected as a rule, this is equivalent to using the fixed transform
form of `proposition`. The `proposition` binding itself remains an ordinary
instantiable schema; only the rule reference through `ih` is strict.

## How It Works

Transform rules follow a two-phase lifecycle:

1. **Parse** — The parser creates the appropriate node type. Both sides are kept
   **unevaluated** — they are structural templates, not executable code.
2. **Apply** — Selection (`?`) or inference (`|=`) passes the ruleset to the
   matcher. The matcher searches for structural matches and applies the rewrite.

By default, the matcher searches the entire subject tree — it matches the root,
then recurses into children and siblings (DFS). A rule can match a subexpression
anywhere inside the subject. The `^` prefix forces full-root matching, restricting
the matcher to the root only.

When no rule matches, the subject is returned unchanged.

## Basic Transform (`=>`)

The basic transform replaces a matched subtree within the subject tree, preserving
the surrounding structure. See [Basic Transform](transform-rules/basic-transform.md)
for detailed examples and lifecycle.

## Inline Transform (`=>>`)

Inline transform replaces the **entire subject** with the replacement, collapsing
the surrounding structure. Ideal for extraction and projection. See
[Inline Transform](transform-rules/inline-transform.md) for details.

## Substitution Transforms (`==>`, `==>>`, `<==>`)

Substitution transforms replace **every occurrence** of mapped symbols throughout
the subject in a single pass. The `==>` form uses literal symbol replacement,
while `==>>` uses binding-aware template expansion with strictness checks. See
[Substitution Transform](transform-rules/substitution-transform.md).

## Equivalence (`<=>`)

Equivalence rules are bidirectional — they match in both directions. See
[Equivalence Rules](transform-rules/equivalence-rules.md) for details.

## Related Pages

- [Basic Transform](transform-rules/basic-transform.md)
- [Inline Transform](transform-rules/inline-transform.md)
- [Substitution Transform](transform-rules/substitution-transform.md)
- [Equivalence Rules](transform-rules/equivalence-rules.md)
- [Selection Operator](selection/selection-operator.md)
- [Variable Captures](patterns/variable-captures.md)
- [Match-Any Captures](patterns/match-any-captures.md)
