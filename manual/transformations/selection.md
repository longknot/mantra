# Selection

Selection applies rule-based structural rewrites to a subject tree. Given a
subject and one or more rules, the matcher searches for the first matching
pattern and replaces it with the corresponding replacement template.

Selection is one of the core transformation operators in Mantra. It sits at
the intersection of pattern matching, tree rewriting, and iterative fixpoint
loops.

```mantra
subject ? rules
```

The right side can be a single rule, a ruleset (list of rules), or a variable
referencing a ruleset. If no rule matches, the subject is returned unchanged.

## Quick Example

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

The rule `[ x -- ] => [ rhs x ]` matches the first element as `x`, captures
the remaining elements with `--`, and replaces the array with everything after
`x`.

Expected output:

```text
[ 2 3 ]
```

Only one rewrite happens per `?`. To apply the rule repeatedly, combine with
repeat (`:`) or use state selection (`$?`).

## Forms

| Syntax | Name | Behavior |
|---|---|---|
| `subject ? rules` | Basic selection | Single rewrite, then collapse |
| `subject :=? rules` | Inline selection | Same as `?` — syntactic variant |
| `subject $? rules` | State selection | Iterative rewrite with state tracking |
| `subject ^? rules` | Root selection | Match only the subject root |
| `selector policy subject ? rules` | Selection policy | Control rule/scope selection strategy |

The `$` and `^` prefixes are meta flags on the selection operator. They change
how the matcher searches and how the runtime handles repeat cycles.

## How It Works

The selection operator follows a deterministic rewrite lifecycle:

1. **Evaluate the subject** — The left side is evaluated in the current context,
   resolving any variables to their bound tree snapshots.
2. **Resolve the ruleset** — If the right side is a variable, it is dereferenced
   (recursively) to obtain the actual ruleset. Rule templates are never evaluated
   themselves; they remain structural patterns.
3. **Search and match** — The matcher walks the subject tree and tries each rule
   in order. The first rule whose pattern matches wins. By default, the search
   covers the root, children, and nested subexpressions (subexpression mode).
4. **Rewrite** — On a match, captured variables are substituted into the
   replacement template and the matched subtree is replaced in-place.
5. **Collapse** — The selection node is removed and replaced by the (possibly
   rewritten) result.

If the ruleset has multiple rules, they are tried in declaration order. Place
specific, narrow rules before broad fallback rules to ensure correct priority.

## Basic Usage

Selection attempts at most one rewrite per evaluation. If no rule matches,
the subject passes through unchanged.

### No Match — Subject Passes Through

```mantra
{ [ 1 2 3 ] ? 0 }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
```

With zero rules (`0`), no rewrite is possible, so the original subject is
returned as-is.

### Single Rewrite on Non-Array Subject

Selection works on any tree structure, not just arrays:

```mantra
{ 1 ? 0 }
```

Expected `OUTPUT`:

```text
1
```

### Removing Elements

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

The rule `[ x -- ] => [ rhs x ]` captures the first element as `x` and
replaces the array with `rhs x` — the remaining siblings after `x`.

## Matching Modes

By default, selection searches for matches at any depth in the subject tree —
the root, its children, and nested subexpressions. This is called
*subexpression mode*.

### Subexpression Mode (Default)

Without any modifier, `?` finds and rewrites the first matching subexpression
anywhere in the subject:

```mantra
{ ( [ 1 2 3 ] ) ? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ ok ] )
```

The rule matches `[ 1 2 3 ]` inside the parentheses and replaces it with
`[ ok ]`, preserving the surrounding structure.

### Root-Only Match (`^`)

Prefix `?` with `^` to restrict matching to the current subject root. The
rule must match the entire subject — no subexpression searching is performed.

```mantra
{ ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ 1 2 3 ] )
```

The pattern `[ 1 2 3 ]` does not match the root `( [ 1 2 3 ] )`, so no
rewrite occurs. See [Root Selection](selection/root-selection.md) for details.

### Per-Node Caret Marks

Even when subexpression search is active, you can guide the matcher by
prefixing individual nodes with `^`. The runtime scans for the first `^`-marked
node and starts the search there:

```mantra
{ "a" ^"b" "c" ? [ "a" => "A", "b" => "B" ] }
```

Expected `OUTPUT`:

```text
"a" "B" "c"
```

The `^` on `"b"` directs the matcher to start there. `"b" => "B"` matches
before `"a" => "A"` even though `"a"` appears earlier.

## Rule Guards

Rules can carry guards that conditionally enable or disable a rewrite. A guard
is expressed inside a compute scope `~( ... )` appended to the replacement.
If the guard evaluates to true, the rule fires; otherwise, the matcher tries
the next rule.

```mantra
{ [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
1
```

The guard `< 1 2` is true, so the rule fires and returns `x` (which is `1`).

When the guard fails and no other rule matches, the subject is returned
unchanged:

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

Here `< 3 2` is false, so the rule does not fire. Multiple rules provide
fallback when a guard fails:

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard `< 3 2` fails, so the second rule fires and returns
`y` (which is `2`).

Guards can be disabled globally with the `--no-guards` CLI flag. When disabled,
guards are ignored and rules fire based on structural match alone. See
[Guards and Selectors](patterns/guards-and-selectors.md) for details.

## Inline Selection (`:=?`)

The inline selection operator `:=?` behaves identically to `?` at runtime.
`TInlineSelectionNode` inherits from `TSelectionNode` and shares the same
evaluation and transform logic.

```mantra
subject :=? rules
```

Inline selection is primarily a syntactic variant. Use `:=?` when you want a
visual distinction between inline and top-level selection in source code.

## Ruleset Resolution

The right side of `?` can be:

- **An inline ruleset** — rules passed directly: `[ rule1 , rule2 ]`
- **A variable** — resolved at runtime to whatever ruleset it references
- **A ruleset variable chain** — if the variable points to another variable,
  resolution continues recursively
- **Zero rules (`0`)** — no rewrite is possible; subject passes through

Rule templates stored in variables are never evaluated prematurely. They remain
structural patterns until the matcher uses them during a selection step.

### Ruleset Stored in a Variable

```mantra
flatten = + ( + X ) => + X
subject = + ( + m )
print { subject ? [ flatten ] }
```

Expected `OUTPUT`:

```text
+ m
```

The variable `flatten` holds the rule template. The ruleset `[ flatten ]` is
resolved at runtime, and the rule rewrites `+ ( + m )` to `+ m`.

## Transform Operators in Selection

Selection supports all transform operator types. The operator determines both
the matching behavior and the replacement scope:

| Operator | Name | Replacement Scope | Direction |
|---|---|---|---|
| `=>` | Basic transform | Matched span only | Forward |
| `=>>` | Inline transform | Entire subject | Forward |
| `<=>` | Equivalence | Matched span | Both directions |

### Basic Transform (`=>`)

The basic transform replaces the matched subtree within the subject, preserving
surrounding structure:

```mantra
{ [ 1 2 3 ] ? [ x => y , x =>> z ] }
```

Expected `OUTPUT`:

```text
[ y 2 3 ]
```

The first rule `x => y` matches the first element `1` and replaces only that
subexpression with `y`. The `=>` operator does not replace the entire subject.

### Equivalence Rules (`<=>`)

Selection supports bidirectional equivalence rules `<=>` in addition to
unidirectional transforms `=>`. An equivalence rule fires in either direction:

```mantra
print { [ 1 2 ] ? [ [ x y ] <=> [ y x ] ] }
print { [ 2 1 ] ? [ [ x y ] <=> [ y x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 1 ]
[ 1 2 ]
```

The first subject `[ 1 2 ]` matches the left side `[ x y ]` and is rewritten
to `[ y x ]`. The second subject `[ 2 1 ]` matches the right side and is
rewritten to `[ x y ]`.

## Multiple Rewrites with Repeat

A single `?` performs at most one rewrite. To apply a rule repeatedly, combine
selection with the repeat operator `:`:

```mantra
{ ( [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ 2 3 ] )
```

Each repeat iteration evaluates the selection again, applying one rewrite per
step. With `: 2`, the subject would be rewritten twice.

For iterative state-selection workflows that track focus and match state
across repeats, use `$?` instead. See [State Selection](selection/state-selection.md).

## Selection Policies

The `selector` keyword wraps a selection with a specific policy that controls
which rule or match scope is chosen when multiple candidates exist:

```mantra
selector policy subject ? rules
```

| Policy | Behavior |
|---|---|
| `first` / `firstrule` | Try rules in declaration order; pick the first match |
| `random` / `"random"` | Pick a random matching rule |
| `shrink` | Pick the rule producing the smallest result |

### First Rule

```mantra
print { selector first [ 1 ] ? [ [ x ] => 10, [ x ] => 20 ] }
```

Expected `OUTPUT`:

```text
10
```

The `first` policy ensures rules are tried in order and the first match wins.

### Shrink Policy

```mantra
print { selector shrink 1 2 3 ? [ x y z => x y, x y z => x ] }
```

Expected `OUTPUT`:

```text
1
```

The `shrink` policy picks the rewrite that produces the smallest result. Here
`x y z => x` produces a single element, while `x y z => x y` produces two — so
the smaller result (`1`) wins.

## Chained Selection for Extraction

Selection chains are useful for drilling into nested structures. Each `?` step
narrows the result, passing it to the next selection:

```mantra
. persons = [
  [ "name" "John Doe",
    "address" [
      "street" "123 Main St",
      "city" "Anytown",
      "country" "USA"
    ]
  ],
  [ "name" "Jane Smith",
    "address" [
      "street" "456 Elm St",
      "city" "Othertown",
      "country" "USA"
    ]
  ]
]

. extract_person = [
  [ "name" "Jane Smith", -- ] =>> $match
]

. extract_address = [
  "address" =>> rhs $match
]

. extract_street = [
  "street" =>> rhs $match
]

print { persons ? extract_person ? extract_address ? extract_street }
```

Expected `OUTPUT`:

```text
"456 Elm St"
```

Each step narrows the result: `extract_person` finds the matching record,
`extract_address` gets the nested address, and `extract_street` extracts the
street value. The `=>>` inline transform replaces the entire subject with the
replacement at each step, enabling progressive narrowing.

## Operator and Selector in Replacements

The `op` keyword in a replacement template reconstructs the operator of a
captured variable, useful for structural transformations:

```mantra
print { + m ? [ x => op x ( x ) ] }
```

Expected `OUTPUT`:

```text
+ ( + m )
```

The `op x` returns the operator of `x` (which is `+`), and the replacement
constructs `+ ( + m )`.

Similarly, `lhs`, `rhs`, and `all` selectors extract parts of captured
subtrees. See [Variable Captures](patterns/variable-captures.md) for details
on capture variables and [Match-Any Captures](patterns/match-any-captures.md)
for `--` and `---` patterns.

## Related Pages

- [Selection Operator](selection/selection-operator.md) — Full reference for `?`
- [State Selection](selection/state-selection.md) — Iterative rewrites with `$?`
- [Root Selection](selection/root-selection.md) — Full-match mode with `^`
- [Focus and Match Selectors](selection/focus-match-selectors.md) — `$focus` and `$match`
- [Transform Rules](transform-rules.md) — Rule operators (`=>`, `=>>`, `<=>`)
- [Variable Captures](patterns/variable-captures.md) — Pattern variables
- [Match-Any Captures](patterns/match-any-captures.md) — `--` and `---` patterns
- [Guards and Selectors](patterns/guards-and-selectors.md) — Rule guards
- [Rules in Practice](rules-in-practice.md) — Applied rule workflows
- [Inference](inference.md) — Bounded proof search with `|=`
