# Rules in Practice

Rules are the bridge between raw structural matching and practical programming.
A single transform `pattern => replacement` does nothing in isolation — it must
be collected into a ruleset and applied through selection (`?`) or inference
(`|=`). Rules in practice are what happen when you give those transforms names,
organize them into sets, add conditions, and chain them into workflows.

This section covers the patterns you use once you've learned the basics of
selection and transform operators.

## From Anonymous to Named

An anonymous rule lives inline and disappears after use:

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ x * 2 -- ] }
```

Expected `OUTPUT`:

```text
[ 2 2 3 ]
```

A named rule persists. You can call it from multiple places, test it in isolation,
and reference it by name in proof witnesses:

```mantra
double_first = [ x -- ] => [ x * 2 -- ];

print { [ 1 2 3 ] ? [ double_first ] }
```

Expected `OUTPUT`:

```text
[ 2 2 3 ]
```

The same rule template can be stored in a variable, declared with `rule`, aliased
under multiple names, and composed into larger rulesets. Naming is the first step
from ad-hoc rewrites toward reusable behavior.

## What Rules Give You

| Capability | Mechanism |
| --- | --- |
| **Reusable behavior** | `rule <name> [ ... ]` registers a callable ruleset |
| **Multiple entry points** | `alias g = f` gives the same callable additional names |
| **Ordered alternatives** | Rules in a set are tried first-to-last; specific before general |
| **Conditional rewrites** | Guards (`~( ... )`) add value-level checks to structural patterns |
| **Bidirectional reasoning** | `<=>` equivalence rules match in both directions |
| **Selection strategies** | `selector first/random/shrink` control which matching rule wins |
| **Query languages** | Custom keywords + rules build readable DSLs over tree data |
| **Traceable proofs** | Named rules in inference produce witnesses with step names |

## How Rules Are Used

Rules flow through three contexts:

1. **Selection** (`?`) — The most common case. A subject tree is rewritten using
   the first matching rule from a ruleset. One rewrite per evaluation.
2. **Inference** (`|=`) — The engine searches for a rewrite path from source to
   target, applying rules in any order within a bounded step limit. Named rules
   produce witnesses with traceable step names.
3. **Head dispatch** — When a named rule is declared with `rule`, any expression
   starting with that name automatically routes to the ruleset. No explicit `?`
   is needed.

```mantra
// Selection
print { [ 1 2 3 ] ? [ [ x -- ] => [ 0 x -- ] ] }
```

Expected `OUTPUT`:

```text
[ 0 1 2 3 ]
```

```mantra
// Head dispatch (no ? needed)
rule prepend_zero [ [ x -- ] => [ 0 x -- ] ];
print { prepend_zero [ 1 2 3 ] }
```

Expected `OUTPUT`:

```text
[ 0 1 2 3 ]
```

```mantra
// Inference
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

## Rule Lifecycle

When Mantra applies rules, it follows these phases:

1. **Declare** — Rules are written as structural templates. Both sides of
   `=>` (or `<=>`) are kept unevaluated — they are patterns, not code.
2. **Collect** — The matcher gathers rules from the ruleset in declaration order.
   Named rules stored in variables are dereferenced; their templates are never
   evaluated prematurely.
3. **Match** — Each rule's pattern is tried against the subject tree. The matcher
   walks the subject (root, children, nested subexpressions) looking for structural
   matches. Variables bind to matching subtrees.
4. **Guard** — If the rule carries a guard (`~( ... )`), it is evaluated with the
   current variable bindings. Non-zero means true; zero means false. A failed
   guard causes the matcher to try the next rule.
5. **Rewrite** — On success, the replacement template is cloned with variable
   bindings substituted, and the matched subtree is replaced in-place.
6. **Stop** — The first matching rule fires and remaining rules are skipped.
   If no rule matches, the subject passes through unchanged.

## Common Patterns

### Specificity Ordering

The single most important rule-writing practice is: **specific rules first,
general fallbacks last**. The matcher stops at the first match — there is no
automatic specificity ranking.

```mantra
{ [ 1 ] ? [
  [ 1 ] => "exact" ,    // specific — matches first
  [ x ] => "any"         // general fallback
] }
```

Expected `OUTPUT`:

```text
"exact"
```

If the order is reversed, the general rule shadows the specific one:

```mantra
{ [ 1 ] ? [
  [ x ] => "any"         // general — fires first, shadows everything
  [ 1 ] => "exact"        // never reached
] }
```

Expected `OUTPUT`:

```text
"any"
```

### Guarded Fallback

When two rules share the same pattern but should behave differently based on
values, use guards instead of duplicating patterns:

```mantra
{ [ 3 ] [ 2 ] ? [
  [ x -- ] [ y -- ] => x ~( < x y ) ,  // if x < y, return x
  [ x -- ] [ y -- ] => y                // otherwise, return y
] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard `< 3 2` evaluates to false, so the matcher falls through
to the unguarded second rule, which returns `y` (which is `2`).

### Named Rules for Proofs

In inference, rule names survive into witness output. Descriptive names make
proofs readable and debuggable:

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;

print { 1 => 3 ?|= [ repeat_seq, ih ] : 2 };
print { witness.w1.ok };
print { witness.w1.steps[1].rule_name };
print { witness.w1.steps[2].rule_name };
```

Expected `OUTPUT`:

```text
"witness.w1"
1
[ "witness.w1.steps[1].rule_name" -> "repeat_seq" ]
[ "witness.w1.steps[2].rule_name" -> "ih" ]
```

Each step in the witness carries the rule name that produced it, so you can
reconstruct the proof logic by reading the step sequence.

### Query DSLs

Rules can hide lower-level selection expressions behind readable query syntax.
The `define` keyword registers custom keywords, and a named rule rewrites the
query form into a selection expression:

```mantra
define select from where;

people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] ];

rule select [
  select field from table where key val
  => ( table ? [ [ key val field out -- ] =>> out ] )
];

print { select "name" from people where "id" 2 }
```

Expected `OUTPUT`:

```text
( "Jane Smith" )
```

The `define` call is essential — without it, `select`, `from`, and `where` are
treated as ordinary identifiers and won't match literally in the pattern.

### Selection Strategies

When multiple rules can match, the `selector` keyword controls which one fires:

```mantra
// Default: first matching rule wins (declaration order)
print { selector first [ 1 ] ? [ [ x ] => 10, [ x ] => 20 ] }
```

Expected `OUTPUT`:

```text
10
```

```mantra
// Shrink: pick the rule producing the smallest result
print { selector shrink 1 2 3 ? [ x y z => x y, x y z => x ] }
```

Expected `OUTPUT`:

```text
1
```

Available strategies: `first` (default), `random`, `shrink`, `first-rule`,
`random-rule`. See [Ordered Rule Sets](rules-in-practice/ordered-rule-sets.md)
for details.

### Bidirectional Rewrites with `<=>`

Equivalence rules match in both directions, useful for algebraic identities
and proof search:

```mantra
rule swap [ [ x y ] <=> [ y x ] ];

print { [ 3 4 ] ? swap : 1 }
print { [ 4 3 ] ? swap : 1 }
```

Expected `OUTPUT`:

```text
[ 4 3 ]
[ 3 4 ]
```

You can restrict an equivalence rule to one direction using `forward` or
`reverse` keywords. See [Bidirectional Rewrites](rules-in-practice/bidirectional-rewrites.md).

## Topics

### Declaration and Dispatch

- [Reusable Rule Dispatch](rules-in-practice/reusable-rule-dispatch.md) — The
  `rule` keyword, `alias`, `callable` declarations, head dispatch, and how named
  rules become callable entry points

### Rule Organization

- [Ordered Rule Sets](rules-in-practice/ordered-rule-sets.md) — How rule order
  determines priority, specificity patterns, selection strategies (`first`,
  `random`, `shrink`), and guard-based fallback

- [Guarded Rules](rules-in-practice/guarded-rules.md) — Conditional rules with
  `~( ... )` guards: syntax, evaluation lifecycle, guard failure and fallback,
  and the `--no-guards` CLI flag

### Advanced Rewrites

- [Bidirectional Rewrites](rules-in-practice/bidirectional-rewrites.md) —
  Equivalence rules (`<=>`) that match in both directions: `forward`/`reverse`
  control, fixed equivalence, tail splicing with `--`, and substitution
  equivalence (`<===>`)

### Practical Workflows

- [Querying Structures with Rules](rules-in-practice/querying-structures.md) —
  Building query languages with `define` + `rule`: the `select/from/where`
  pattern, named vs. variable rules, and nested queries

- [Named Rules in Proofs](rules-in-practice/named-rules-in-proofs.md) — How rule
  names survive into inference witnesses, direction tracking for equivalence
  rules, witness structure reference, and inference configuration

## Related Pages

- [Selection](selection.md) — The `?` operator and structural rewriting
- [Transform Rules](transform-rules.md) — Rule operators (`=>`, `=>>`, `<=>`,
  substitution variants)
- [Patterns](patterns.md) — Structural templates, match-any captures, and
  pattern matching lifecycle
- [Inference](inference.md) — Bounded proof search with `|=`
