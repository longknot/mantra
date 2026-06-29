# Guards and Selectors

Guards and selectors are two complementary mechanisms that control which rewrite
rule applies and what it produces. Guards add conditional logic on top of
structural pattern matching. Selectors extract specific parts of matched trees
within replacement templates.

## Guards

A guard attaches an arithmetic or boolean condition to a rule. The pattern must
still match structurally, but the guard can reject a match when its expression
evaluates to false.

### Syntax

A guard appears in the replacement section of a rule, prefixed with `~` (tilde):

```mantra
pattern => replacement ~ guard_expression
```

The guard expression is evaluated inside a compute scope after the pattern
matches and variable bindings are resolved. Captured variables from the pattern
are available inside the guard.

### How Guards Work

The matcher evaluates guards through this lifecycle:

1. **Structural match** -- The pattern matches the subject tree and binds
   variables.
2. **Guard cloning** -- The guard template is cloned with bound variable
   substitutions (via `CloneTemplateNodeWithBindings`).
3. **Compute evaluation** -- The cloned guard is evaluated via `Compute`,
   reducing arithmetic expressions to a value.
4. **Boolean check** -- `GuardToBoolean` extracts the result: a non-zero
   integer is true; zero or absent is false.

If the guard evaluates to true, the rule fires and the replacement template is
applied. If false, the matcher moves to the next rule in the ruleset.

### Guard Syntax Details

The `~` (tilde) meta flag marks a node as a guard. In the source, `~` is the
same token used for compute scopes. When the matcher's `SplitRuleTemplate`
walks the replacement side of a rule, it calls `IsGuardNode` which checks for
the `TK_TILDE` bit in the node's `Data` field. Everything from the `~` onward
is treated as the guard; the preceding siblings form the replacement template.

```mantra
[ x -- ] [ y -- ] => x ~( < x y )
```

Here `x` is the replacement and `~( < x y )` is the guard. The `<` comparison
is computed with `x` and `y` substituted from the match.

## Guard Examples

### Guard passes — rule fires

```mantra
{ [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
1
```

The pattern captures `[ 1 ]` as `x` and `[ 2 ]` as `y`. The guard
`~( < 1 2 )` evaluates to true, so the rule fires and returns `x` (which is
`1`).

### Guard fails — no match

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

The pattern matches structurally, binding `x` to `[ 3 ]` and `y` to `[ 2 ]`.
However, the guard `~( < 3 2 )` evaluates to false. No other rule is available,
so the subject passes through unchanged.

### Guard fails with fallback rule

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard `~( < 3 2 )` fails. The matcher then tries the second
rule, which has no guard and fires immediately, returning `y` (which is `2`).

This is the standard guard + fallback pattern: place guarded rules before
unguarded fallbacks to handle conditional rewrites gracefully.

## Guard Evaluation Details

The guard expression is reduced by the compute pipeline. This means any
arithmetic, comparison, or boolean operator supported by compute scopes works
inside guards:

- Comparisons: `<`, `>`, `<=`, `>=`, `=`
- Arithmetic: `+`, `-`, `*`, `/`
- Boolean: `and`, `or`, `not`
- Functions: `floor`, `ceil`, `round`, `abs`, etc.

The `GuardToBoolean` function extracts the final value. It unwraps expression,
array, and evaluation nodes to reach the integer result. A non-zero integer is
treated as true; zero or a missing node is treated as false.

### Guards and `--no-guards`

Guards can be disabled globally via CLI flag:

```bash
./bin/mantra --no-guards program.m
```

When disabled, `MatcherGuardsEnabled` is set to false. Rules with guards fire
based on structural match alone — the guard expression is never evaluated.
With `--no-guards`, the example above would return `3` (the first rule fires
even though `< 3 2` is false):

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT` with `--no-guards`:

```text
3
```

Use `--no-guards` only for debugging or when verifying behavior without guards.

## Selectors

Selectors extract specific structural parts of matched or bound variables within
replacement templates. The keywords `lhs`, `rhs`, and `all` are recognized by
the parser and carry selector bits (`TK_SELECTOR_LHS`, `TK_SELECTOR_RHS`,
`TK_SELECTOR_ALL`) that the matcher interprets during template cloning.

### Selector Keywords

| Keyword | Bit flag | Extracts |
|---|---|---|
| `lhs` | `TK_SELECTOR_LHS` | Left child (first subtree) of the target node |
| `rhs` | `TK_SELECTOR_RHS` | Right siblings (all following siblings) of the target node |
| `all` | `TK_SELECTOR_ALL` | The node plus all its siblings (full span) |

These selectors prefix a variable reference in a replacement template. They
operate on the tree structure (left-child / right-sibling representation), not
on list contents:

```mantra
[ x -- ] => [ rhs x ]
```

Here `rhs x` returns all siblings after `x` — the tail captured by `--`. The
result is the remaining elements of the original list minus the first element.

### How Selectors Work in Templates

During `CloneTemplateNodeWithBindings`, when the matcher encounters a variable
node with a selector bit set, it applies `CloneMatchVariableWithSelector`. The
selector bits determine which part of the bound value is cloned:

- **`lhs`** — clones `Tree[MatchHead]^.LHS` (the first child subtree)
- **`rhs`** — clones the span from `Tree[MatchHead]^.RHS` to the tail boundary
- **`all`** — clones the entire span from `MatchHead` to `MatchTail`

When combined with `$match` or `$focus`, selectors operate on the full matched
span rather than a single bound variable. See [Focus and Match
Selectors](../selection/focus-match-selectors.md) for details.

## Selection Policies

Selection policies control which rule from a ruleset the matcher tries first.
They are set via the `selector` keyword and affect the global
`MatcherSelectionStrategy` variable.

### Policy Keyword

```mantra
selector strategy payload
```

The `selector` keyword creates a `TSelectionPolicyNode` that:

1. Parses the strategy name from its left child (LHS)
2. Sets `MatcherSelectionStrategy` to the parsed value
3. Evaluates its right child (RHS) as the payload
4. Restores the previous strategy after evaluation
5. Collapses itself into the payload result

### Supported Strategies

| Strategy | Aliases | Behavior |
|---|---|---|
| `first` | `default`, `sequential` | Try rules in declaration order (default) |
| `random` | `rand` | Shuffle rules with Fisher-Yates before trying |
| `shrink` | `reduce`, `simplify`, `minnodes` | Prefer matches producing smaller results |
| `first-rule` | `firstrule`, `rule-first`, `rulefirst` | Rule-ordered search: find all matching positions, pick first rule |
| `random-rule` | `randomrule`, `rule-random`, `rulerandom` | Rule-ordered search: shuffle rules, then find matches |

### Exhaustive Selection Override

The `selector` keyword supports `+` and `-` operators to override the exhaustive
selection flag:

```mantra
selector + strategy payload   // enable exhaustive selection
selector - strategy payload   // disable exhaustive selection
```

The `+` sets `MatcherExhaustiveSelection` to true, while `-` sets it to false.
Without the operator, the existing exhaustive selection setting is preserved.

### Example: Random Selection

```mantra
selector random { [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] }
```

With the `random` strategy, if the ruleset has multiple rules, they are shuffled
before the matcher tries them. This is useful when rule priority should be
non-deterministic.

## Related Pages

- [Selection Operator](../selection/selection-operator.md)
- [Focus and Match Selectors](../selection/focus-match-selectors.md)
- [Basic Transform](../transform-rules/basic-transform.md)
- [Guarded Rules](../rules-in-practice/guarded-rules.md)
- [Inline Transform](../transform-rules/inline-transform.md)
