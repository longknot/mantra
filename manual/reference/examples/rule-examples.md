# Rule Examples

This page collects compact, runnable examples that demonstrate how rules work
in Mantra — pattern matching, structural rewriting, named dispatch, guards,
bidirectional transforms, and inference. All examples correspond to real test
fixtures in `tests/cases/` unless otherwise noted.

---

## Pattern Matching Basics

### Lowercase Symbols Match Identifiers

Lowercase symbols in a rule match a single node (identifier, integer, etc.).

**Input:**

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => x ] }
```

**Output:**

```text
1
```

The rule `[ x -- ]` captures the head (`x = 1`) and discards the tail.
The replacement `x` emits only the captured head.
(Test fixture: `matcher_rule_capture_head`)

### Tail Capture with `--`

The `--` suffix captures all remaining siblings after the preceding symbol.

**Input:**

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

**Output:**

```text
[ 2 3 ]
```

`rhs x` extracts the tail portion matched by `--`.
(Test fixture: `matcher_rule_capture_rhs_tail`)

### Full Tail Splice

In replacement position, `x --` splices both the head and captured tail back
into the output — equivalent to `all x`.

**Input:**

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => [ x -- ] ] }
```

**Output:**

```text
[ 1 2 3 ]
```

(Test fixture: `matcher_rhs_tail_splice_forward`)

### Any-Node Match with Uppercase Symbols

Uppercase symbols match any node, including compound expressions.

**Input:**

```mantra
print { [ [ 1 ] [ 1 ] ] ? [ [ X X ] => X ] }
```

**Output:**

```text
[ 1 ]
```

Both uppercase `X` symbols bind to `[ 1 ]`, and the replacement keeps one.
(Test fixture: `matcher_rule_uppercase_any_match`)

---

## Symbol Constraints

### Repeated Symbol — Must Match Same Value

When a lowercase symbol appears multiple times in a pattern, every occurrence
must match the same node.

**Match (identical symbols):**

```mantra
print { [ 1 1 ] ? [ [ x x ] => x ] }
```

**Output:**

```text
1
```

(Test fixture: `matcher_rule_repeated_symbol_match`)

**No Match (different values):**

```mantra
print { [ 1 2 ] ? [ [ x x ] => x ] }
```

**Output:**

```text
[ 1 2 ]
```

The rule does not fire because the two positions hold different values.
The original expression is returned unchanged.
(Test fixture: `matcher_rule_repeated_symbol_no_match`)

### Infix Match Any

`--` can appear in the middle of a pattern to match an arbitrary sequence
between fixed anchors.

**Input:**

```mantra
print { [ 1 2 3 4 ] ? [ [ 1 -- 4 ] => [ ok ] }
```

**Output:**

```text
[ ok ]
```

The `--` absorbs `2 3` between the literal anchors `1` and `4`.
(Test fixture: `matcher_match_any_infix_basic`)

---

## Rule Ordering

When multiple rules are present, the **first** applicable rule wins. Later
rules are never tried once an earlier one matches.

**Input:**

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => [ 9 ] , [ x -- ] => [ 8 ] ] }
```

**Output:**

```text
[ 9 ]
```

The first rule `[ x -- ] => [ 9 ]` matches everything, so `[ 8 ]` is never
reached.
(Test fixture: `matcher_rule_order_first`)

---

## Guards

Guards are boolean expressions that gate rule application. A rule fires only
if its guard evaluates to true (non-zero).

### Guard True — Rule Fires

When a guard evaluates to true, the rule applies.

**Input:**

```mantra
print { [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

**Output:**

```text
1
```

The guard `~( < x y )` checks that `1 < 2`, which is true, so the rule
fires and returns `x` (which is `[ 1 ]` unwrapped to `1`).
(Test fixture: `matcher_guard_true`)

### Guard False — Rule Skipped

When a guard evaluates to false, the rule is skipped entirely.

**Input:**

```mantra
print { [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

**Output:**

```text
[ 3 ] [ 2 ]
```

The guard `~( < x y )` checks `3 < 2`, which is false. The rule does not
fire, and the original expression is returned unchanged.
(Test fixture: `matcher_guard_false_no_fallback`)

### Guard with Fallback Rule

When a guarded rule fails, subsequent rules in the list are tried.

**Input:**

```mantra
print { [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

**Output:**

```text
2
```

The first rule fails its guard (`3 < 2` is false). The fallback rule
`[ x -- ] [ y -- ] => y` matches and returns `y` (which is `2`).
(Test fixture: `matcher_guard_fallback_rule`)

### Disabling Guards

Pass `--no-guards` to the CLI to disable guard enforcement. With guards
disabled, a rule with a false guard still fires.

**Input (with `--no-guards`):**

```mantra
print { [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

**Output:**

```text
3
```

(Test fixture: `matcher_no_guards_false_guard_applies`)

---

## Subexpression Matching

By default, the matcher searches the entire expression tree for a match —
it can rewrite nested subexpressions, not just the root.

### Default: Subexpression Match

**Input:**

```mantra
print { ( [ 1 2 3 ] ) ? [ [ 1 2 3 ] => [ ok ] ] }
```

**Output:**

```text
( [ ok ] )
```

The rule matched the inner `[ 1 2 3 ]` subexpression, not the outer
parentheses.
(Test fixture: `matcher_selection_subexpr_default`)

### Full-Match Mode with `^`

Prefix the selection with `^` to require a full-root match. The rule will
only fire if it matches the entire subject expression.

**Input:**

```mantra
print { ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```

**Output:**

```text
( [ 1 2 3 ] )
```

The subject is `( [ 1 2 3 ] )`, which does not fully match `[ 1 2 3 ]`.
The rule does not fire.
(Test fixture: `matcher_selection_subexpr_caret_full`)

### Prefix Preservation

When a rule matches a subexpression, preceding siblings are preserved.

**Input:**

```mantra
print { 12 [ 15 20 ] [ 49 ] ? [ [ x -- ] [ y -- ] => [ all x ] [ all y ] 1 ] }
```

**Output:**

```text
12 [ 15 20 ] [ 49 ] 1
```

The prefix `12` is preserved; the rule matches `[ 15 20 ] [ 49 ]` and
appends `1`.
(Test fixture: `matcher_selection_subexpr_preserve_prefix`)

---

## Named Rules

### Declaring Named Rules with `rule`

Use `rule` to create a named, reusable transformation.

**Input:**

```mantra
rule replace [ x => y ]
print { a ? replace }
```

**Output:**

```text
y
```

(Test fixture: `rule_keyword_basic`)

### Named Dispatch via Callable

Named rules can be dispatched through the callable mechanism using
`alias` to create an alternate entry point.

**Input:**

```mantra
rule f [
  f x => x
];

alias g = f;

print { g 7 }
```

**Output:**

```text
7
```

The rule `f` matches the pattern `f x` and returns `x`. The alias `g`
routes through `f`, so `g 7` dispatches to the rule and extracts `7`.

### Auto-Keyword Selection

A named rule can be invoked as a keyword in selection context, matching
its own name.

**Input (with `--no-head-dispatch`):**

```mantra
rule only [ only x => x ]
print { [ foo 1 ] ? only : 1 }
```

**Output:**

```text
[ foo 1 ]
```

The `only` rule matches the `only` keyword followed by a symbol.
Since the subject `[ foo 1 ]` does not start with `only`, the rule
does not fire.
(Test fixture: `rule_name_auto_keyword_selection`)

---

## Iterative Selection with `$`

The `$` meta flag enables state-selection mode — rules are applied
iteratively across repeat steps.

### Iterative Head Removal

**Input:**

```mantra
print { ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 1 }
```

**Output:**

```text
( [ 2 3 ] )
```

One step: removes the head, leaving `[ 2 3 ]`.
(Test fixture: `matcher_selection_dollar_iter_1`)

**Two steps:**

```mantra
print { ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 2 }
```

**Output:**

```text
( [ 3 ] )
```

(Test fixture: `matcher_selection_dollar_iter_2`)

**Three steps — empty:**

```mantra
print { ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 3 }
```

**Output:**

```text
( [] )
```

After three iterations, the list is exhausted.
(Test fixture: `matcher_selection_dollar_iter_3`)

### Dollar Focus — Extract Matched Node

The `$` focus operator extracts the node matched by `.` (the matched
anchor) during rule application.

**Input:**

```mantra
~ { 1 [ 2 ] 3 $? [ [ .x ] =>> $focus ] : 1 }
```

**Output:**

```text
2
```

The rule matches `[ 2 ]` (the `.` pattern), and `$focus` returns the
matched node value.
(Test fixture: `matcher_dollar_focus_basic`)

---

## Bidirectional Transforms

Equivalence rules (`<=>`) can rewrite in both directions.

### Swap Example

**Input:**

```mantra
print { [ 1 2 ] ? [ [ x y ] <=> [ y x ] ] }
print { [ 2 1 ] ? [ [ x y ] <=> [ y x ] ] }
```

**Output:**

```text
[ 2 1 ]
[ 1 2 ]
```

The first call matches `[ x y ]` against `[ 1 2 ]` and produces `[ 2 1 ]`.
The second call matches in the reverse direction — `[ y x ]` against
`[ 2 1 ]` — producing `[ 1 2 ]`.
(Test fixture: `equivalence_bidirectional_selection`)

### Equivalence with Tail Splice

When using `--` in equivalence rules, the tail splice (`x --`) preserves
the matched sequence in both directions.

**Input:**

```mantra
print { [ [ 1 2 ] ] ? [ [ [ x -- ] ] <=> [ x -- ] ] }
```

**Output:**

```text
[ 1 2 ]
```

The rule unwraps the outer container. In reverse, `[ x -- ]` would
re-wrap it.
(Test fixture: `matcher_rhs_tail_splice_equivalence`)

---

## Fixed Transforms

Fixed transforms (`\`) treat their operands as structural patterns rather
than as matcher binders. Variables are resolved from context at
preparation time, not fresh-bound at match time.

### Fixed vs. Schema

**Input:**

```mantra
x = 1
fixed = x \ => 2
schema = x => 2

print { 1 ? [ fixed ] }
print { 3 ? [ fixed ] }
print { 1 ? [ schema ] }
print { 3 ? [ schema ] }
```

**Output:**

```text
2
3
2
2
```

The `fixed` rule resolves `x` to `1` from context, so it only matches `1`.
The `schema` rule treats `x` as a fresh matcher binder, so it matches
any value.
(Test fixture: `matcher_fixed_transform_context_resolution`)

### Context Resolution Timing

Fixed transforms resolve variables from the **current** context when
they are prepared for application — not when they are defined.

**Input:**

```mantra
x = 1
fixed = x \ => 2

print { 1 ? [ fixed ] }  // x = 1, so matches

x = 3

print { 1 ? [ fixed ] }  // x = 3, no longer matches 1
print { 3 ? [ fixed ] }  // matches 3
```

**Output:**

```text
2
1
2
```

After reassigning `x = 3`, the fixed rule now matches `3` instead of `1`.
(Test fixture: `matcher_fixed_transform_context_resolution`)

---

## Inference / Proof Search

The `|=` operator searches for a rewrite chain from a subject to a target
using a set of rules.

### Basic Inference — Success

**Input:**

```mantra
print { 1 => 3 |= [ 1 => [ 4, 5 ], 1 => 2, 2 => 3 ] : 2 }
```

**Output:**

```text
1
```

The inference engine finds the path `1 => 2 => 3` within 2 steps.
The result `1` means success.

### Cost Policy — Choosing Shorter Paths

By default, inference admits the first successful path. With the cost
policy, it prefers the path with the smallest structural growth,
pruning branches that expand the tree unnecessarily.

**Input (default policy — no cost):**

```mantra
{ mantra.inference.beam = 1 }

print { 1 => 3 |= [ 1 => [ 4, 5 ], 1 => 2, 2 => 3 ] : 2 }
```

**Output:**

```text
0
```

The first rule `1 => [ 4, 5 ]` is tried, grows the tree, and fails to
reach the target within 2 steps. Result: `0` (failure).

**Input (cost policy):**

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.policy = "cost" }

print { 1 => 3 |= [ 1 => [ 4, 5 ], 1 => 2, 2 => 3 ] : 2 }
```

**Output:**

```text
1
```

The cost policy evaluates all candidates at each step, selects the one
with the smallest growth (`1 => 2` has 0 growth vs. `1 => [ 4, 5 ]`
with growth 4), and reaches the target in 2 steps. Result: `1` (success).
(Test fixture: `inference_cost_policy_growth`)

### Inference with Event Tracing

Enable `--event-log=trace` to see the step-by-step inference decisions.

**Input (with `--event-log=trace`):**

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.policy = "cost" }

print { 1 => 3 |= [ 1 => [ 4, 5 ], 1 => 2, 2 => 3 ] : 2 }
```

**Output (excerpt):**

```text
EVENT[trace] inference step=1 state=0 candidate score=4 growth=4 nodes=5 policy=cost
EVENT[trace] inference step=1 state=0 candidate score=0 growth=0 nodes=1 policy=cost
EVENT[trace] inference step=1 state=0 candidate pruned reason=beam score=4 policy=cost
EVENT[trace] inference step=2 state=1 candidate score=0 growth=0 nodes=1 policy=cost
EVENT[trace] inference target reached at step=2 via state=1
1
```

The trace shows the candidate `1 => [ 4, 5 ]` (score=4) being pruned
in favor of `1 => 2` (score=0).
(Test fixture: `inference_cost_policy_trace`)

### Inference Direction with Equivalence Rules

Equivalence rules (`<=>`) can be applied in forward or reverse direction
during inference.

**Input:**

```mantra
step = 1 <=> 2

print { 1 => 3 |= [ step ] : 1 }
print { 2 => 3 |= [ step ] : 1 }
```

The first call can use `step` forward (`1 => 2`). The second call can
use `step` in reverse (`2 => 1`).

### Inference Budget

Control the search depth with `mantra.inference.budget`.

**Input:**

```mantra
{ mantra.inference.budget = 4 }

add = + x => + y;

print { + a => + b |= [ add ] : 1 }
```

**Output:**

```text
1
```

The rule rewrites `+ a` to `+ b` within the budget.
(Test fixture: `inference_cost_policy_trace`)

---

## Structural Matching

### Structural Comma as Separator

In structural patterns, commas separate elements that must match
adjacent nodes.

**Input (with comma pattern matching):**

```mantra
print { [ a b c ] ? [ [ a, b, c ] => [ ok ] ] }
```

A comma-separated pattern matches when all named variables resolve
to their corresponding values.
(Test fixture: `matcher_separator_structural_comma_pattern_match`)

### Pair Value and Key Binding

**Input:**

```mantra
print { [ [ 1 2 ] [ 3 4 ] ] ? [ [ key val ] => val ] }
```

**Output:**

```text
[ 3 4 ]
```

The pattern `[ key val ]` binds `key` to `[ 1 2 ]` and `val` to `[ 3 4 ]`,
returning the value.
(Test fixture: `matcher_pair_value_key_bindable`)

---

## Induction and Rulesets

### Ruleset Append and Nesting

Rulesets can be appended, creating nested rule collections.

**Input:**

```mantra
ruleset1 = [ r1: x => 1 ]
ruleset2 = [ r2: x => 2 ]
combined = ruleset1 + ruleset2

print { foo ? combined }
```

The first rule in the combined ruleset fires.
(Test fixture: `induction_ruleset_append_nests_rules`)

---

## How It Works

- **`?`** — Applies rules to a subject expression and returns the result.
  The matcher searches the full expression tree for matches.
- **`^?`** — Full-match mode: only fires if the rule matches the entire
  subject expression at root level.
- **`$?`** — Iterative selection mode: applies rules across repeat steps,
  transforming the subject iteratively.
- **`=>`** — Forward rewrite rule: matches left, produces right.
- **`<=>`** — Equivalence rule: can rewrite in both directions.
- **`\`** — Fixed transform: resolves variables from context instead of
  binding fresh matchers.
- **`~( expr )`** — Guard: a boolean expression that must be true for the
  rule to fire.
- **`--`** — Tail pattern: captures all remaining siblings.
- **`|=`** — Inference operator: searches for a rewrite chain from
  subject to target using a rule set.
- **Uppercase symbols** — Match any node (including compound expressions).
- **Lowercase symbols** — Bind to a single node; repeated occurrences
  must match the same value.
- **First rule wins** — When multiple rules match, the first one in the
  list is applied; later rules are never tried.
- **`--no-guards`** — CLI flag to disable guard enforcement.
- **`mantra.inference.policy`** — Set to `"cost"` to prefer paths with
  minimal structural growth during inference.
- **`mantra.inference.beam`** — Controls the beam width during inference
  search (default 1 = greedy).

### Reduction Order

When multiple operators appear in a rule, the left-hand side (LHS)
pattern is matched against the subject structure. The right-hand side
(RHS) reconstructs the output using captured variables. `--` extracts
remaining siblings; `x --` splices them back.

### Variable Scoping

- Schema rules (`=>`) bind fresh variables at match time.
- Fixed transforms (`\`) resolve variables from the current context.
- Guard expressions (`~(...)`) share the variable bindings from their
  rule's LHS.

---

## Reference

- Test fixtures: `tests/cases/*matcher*`, `tests/cases/*rule*`,
  `tests/cases/*equivalence*`, `tests/cases/*inference*`
- Source: `src/matcher.pas` (pattern matching and rule application)
- Source: `src/inference.pas` (proof search engine)
- Source: `src/transform.pas` (rewrite transformations)
- Manual: [Selection Operator Reference](../../selection/reference.md)
- Manual: [Transform Operator Reference](../../transform/reference.md)
