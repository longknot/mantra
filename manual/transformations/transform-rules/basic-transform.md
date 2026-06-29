# Basic Transform

The basic transform operator is `=>`.

```mantra
pattern => replacement
```

A transform rule defines a structural rewrite: when the *pattern* (left side)
matches a subtree, it is replaced by the *replacement* (right side) with
captured variables substituted.

## How It Works

Transform rules are the building block of selection (`?`) and inference (`|=`).
They are always used indirectly -- the runtime applies them through a selection
or an inference query. A transform rule on its own does nothing; it must be
collected into a ruleset and applied to a subject.

### Lifecycle

1. The parser creates a `TTransformationNode` for `=>`. Both sides are kept
   **unevaluated** -- they are structural templates, not executable code.
2. The rule is assigned to a variable or placed inside a `rule` declaration.
3. Selection (`?`) or inference (`|=`) passes the ruleset to the matcher.
4. The matcher searches the subject for a structural match. On success,
   captured variables are substituted into the replacement and the matched
   subtree is replaced.

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

The `f` callable matches `f` followed by any argument, captures it as `x`, and
the replacement side emits just `x` -- effectively unwrapping one layer.

Rules declared with `rule` are automatically applied via head dispatch: when the
leading symbol of a subject matches the leading symbol of a rule, the rewrite
fires without an explicit `?`.

Rulesets can contain multiple rules separated by commas:

```mantra
rule runlist [
  runlist [ X -- ] => runlist { all X },
  runlist { X, } Y -- => func X runlist [ all Y ],
  runlist { X, } => func X
];

print { runlist [ "a", "b", "c" ] }
```

Expected `OUTPUT`:

```text
func "a" func "b" func "c"
```

Rules are tried in order. The first matching rule wins. Place specific rules
before broad fallback rules to ensure the correct priority.

## Pattern Variables

The pattern side uses lowercase symbols to capture matched nodes:

```mantra
[ x -- ] => [ rhs x ]
```

| Symbol | Matches |
|---|---|
| Lowercase (e.g. `x`) | Single identifier or node |
| Uppercase (e.g. `X`) | Any node, including expressions |
| `--` | Tail sequence (all remaining siblings) |
| `x --` | Captures `x` plus everything after it |

In replacement templates, captured variables are substituted with the matched
subtree. The `--` syntax splices the captured tail back into the output,
equivalent to `all x` for matcher-bound symbols.

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

## Applying Rules with Selection

Rules are applied to a subject through the selection operator `?`:

```mantra
subject ? [ rules ]
```

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ x x -- ] ] }
```

Expected `OUTPUT`:

```text
[ 1 1 2 3 ]
```

The pattern `[ x -- ]` matches the list, capturing `1` as `x` and `2 3` as the
tail. The replacement `[ x x -- ]` produces `[ 1 1 2 3 ]`.

Rules can be stored in variables and referenced by name:

```mantra
ih = << + m : + n >> => << + n : + m >>;

print { + m : + n ? [ ih ] };
```

Expected `OUTPUT`:

```text
+ n : + m
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

A transform can be marked fixed by placing `\` before the operator:

```mantra
ih = << + m : + n >> \ <=> << + n : + m >>;
```

In a fixed transform, the pattern is matched structurally -- variable-shaped
terms do not become fresh matcher bindings. This supports exact hypothesis-style
rewrites where you want the literal symbols preserved:

```mantra
<< + m : + n >>      => << + n : + m >>    |= [ ih ] : 1   // succeeds
<< + 1 : + n >>      => << + n : + 1 >>    |= [ ih ] : 1   // fails
```

A transform-valued binding can also be referenced as fixed:

```mantra
proposition = << + m : + n >> => << + n : + m >>;
ih = \ proposition;
```

## Define Keywords

The `define` keyword registers symbols as match-time keywords, allowing them to
appear in patterns without being treated as variables:

```mantra
define select from where ;

. q = [ [ select x from y where z w ] => [ x ] ] ;

print { [ select "name" from persons where "id" 2 ] ? q : 1 }
```

Expected `OUTPUT`:

```text
[ "name" ]
```

Without `define`, `select`, `from`, and `where` would be treated as lowercase
pattern variables instead of literal symbols.

## Unevaluated Templates

Transform rules keep both sides unevaluated. This is essential -- the pattern
and replacement are structural templates that only materialize when the matcher
applies them. If they were evaluated prematurely, pattern variables would
resolve to context values and the rule would be corrupted before use.

## Subexpression Matching

By default, the matcher searches the entire subject tree -- it matches the root,
then recurses into children and siblings (DFS). A rule can match a subexpression
anywhere inside the subject:

```mantra
{ ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ 1 2 3 ] )
```

The `^` prefix forces full-root matching. Without it, the matcher would search
subexpressions. With it, only the root itself is matched, so the inner list is
not reached and the rule does not fire.

## Rule Ordering and No Match

When no rule matches, the subject is returned unchanged:

```mantra
{ [ 1 , 2 , 3 ] ? [ [ x -- ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
[ 1 , 2 , 3 ]
```

The comma-separated list `[ 1 , 2 , 3 ]` has a different structure than the
flat pattern `[ x -- ]`, so no match occurs and the input is preserved.

## Related Pages

- [Selection Operator](selection/selection-operator.md)
- [Variable Captures](patterns/variable-captures.md)
- [Match-Any Captures](patterns/match-any-captures.md)
- [Inline Transform](inline-transform.md)
- [Substitution Transform](substitution-transform.md)
- [Equivalence Rules](equivalence-rules.md)
- [Guarded Rules](rules-in-practice/guarded-rules.md)
- [Ordered Rule Sets](rules-in-practice/ordered-rule-sets.md)
