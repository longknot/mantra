# Ordered Rule Sets

A ruleset is a list of transform rules separated by commas. When multiple rules
can match the same subject, their order determines which one fires. Mantra tries
rules in declaration order -- the first matching rule wins.

```mantra
subject ? [ rule1 , rule2 , rule3 ]
```

## Example

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ 9 ] , [ x -- ] => [ 8 ] ] }
```

Expected `OUTPUT`:

```text
[ 9 ]
```

Both rules match `[ 1 2 3 ]`, but the first rule wins because it is tried first.

## How It Works

When the selection operator `?` evaluates, the matcher collects all rules from
the ruleset and tries them sequentially:

1. **Collect** -- Rules are gathered from left to right in the ruleset. The
   `CollectRuleRefs` function walks the ruleset tree, extracting each
   transformation node (`=>` or `<=>`) in declaration order.
2. **Order** -- By default, the declaration order is preserved (the `first`
   strategy).
3. **Match** -- Each rule is tried in order. The first rule whose pattern
   matches the subject fires immediately.
4. **Rewrite** -- On a match, captured variables are substituted into the
   replacement template and the matched subtree is replaced.
5. **Stop** -- Once a rule fires, remaining rules are not consulted.

If no rule matches, the subject passes through unchanged.

The matcher calls `RewriteOneByRules(...)` which internally builds an array of
collected rule references and iterates over them. The default selection strategy
(`sskFirst`) keeps the declared order untouched.

## Specificity: Specific Before General

The golden rule of ordered rule sets is: **place specific rules before general
fallback rules**. Because the matcher stops at the first match, a broad pattern
early in the ruleset can shadow everything that follows.

### Example: Specific rule first

```mantra
{ [ 1 ] ? [ [ 1 ] => "exact" , [ x ] => "any" ] }
```

Expected `OUTPUT`:

```text
"exact"
```

The specific pattern `[ 1 ]` matches before `[ x ]` gets a chance.

### Example: General rule first (shadowing)

```mantra
{ [ 1 ] ? [ [ x ] => "any" , [ 1 ] => "exact" ] }
```

Expected `OUTPUT`:

```text
"any"
```

The general `[ x ]` pattern matches `[ 1 ]` first, so the specific `[ 1 ] =>
"exact"` rule is never reached. This is a common ordering mistake.

### Example: No match

```mantra
{ [ 1 2 3 ] ? [ [ 4 ] => "notfound" ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
```

No rule matches the subject, so it is returned unchanged. Similarly, an empty
ruleset (e.g., `? 0`) always leaves the subject untouched.

### Example: Multiple specific patterns

```mantra
{ [ 5 ] ? [ [ 5 ] => "five" , [ x ] => "other" ] }
```

Expected `OUTPUT`:

```text
"five"
```

```mantra
{ [ 5 ] ? [ [ x ] => "other" , [ 5 ] => "five" ] }
```

Expected `OUTPUT`:

```text
"other"
```

Rule order is the only priority mechanism -- there is no automatic specificity
ranking. The matcher never "looks ahead" to find a better match.

## Guards and Fallback

When a rule has a guard and the guard fails, the matcher moves to the next
rule. This lets you express conditional behavior with ordered alternatives.

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard `< 3 2` evaluates to false, so the second (fallback)
rule fires and returns `y` (which is `2`).

### Guarded rule with no fallback

When the only matching rule fails its guard and no other rule exists, the
subject passes through unchanged:

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

See [Guarded Rules](guarded-rules.md) for details on guard syntax and
evaluation.

### Multiple guards in a ruleset

Guards and structural specificity work together. The matcher tries rules in
order, evaluating the guard only after a structural match succeeds:

```mantra
{ [ 5 ] [ 3 ] [ 1 ] ? [
  [ x -- ] => x ~( > ~ x 4 ) ,
  [ x -- ] => x ~( < ~ x 2 ) ,
  [ x -- ] [ y -- ] => y
] }
```

Expected `OUTPUT`:

```text
5 [ 3 ]
  [ 1 ]
```

Here, the first rule's guard `> 5 4` is true, so it fires immediately. The
second and third rules are never reached. If the first element were `3`, both
guards would fail and the fallback third rule would fire.

## Selection Strategies

The `selector` keyword wraps a selection expression and changes which rule
fires when multiple rules match. Without a selector, the default strategy is
`first` -- the first matching rule in declaration order wins.

```mantra
selector <strategy> subject ? rules
```

### Available Strategies

| Strategy | Aliases | Behavior |
|---|---|---|
| `first` | `default`, `sequential` | First matching rule in order (default) |
| `random` | `rand` | Randomly pick from matching rules |
| `shrink` | `reduce`, `simplify`, `minnodes` | Prefer the match that produces the smallest result |
| `first-rule` | `firstrule`, `rule-first` | Same as `first` (explicit) |
| `random-rule` | `randomrule`, `rule-random` | Randomly pick a rule from the ruleset, then check for match |

### Example: Explicit first strategy

```mantra
print { selector first [ 1 ] ? [ [ x ] => 10, [ x ] => 20 ] }
```

Expected `OUTPUT`:

```text
10
```

The first rule `[ x ] => 10` matches and fires. This is the same as the
default behavior without a `selector` wrapper.

### Example: Random rule selection

```mantra
print { selector random [ 1 ] ? [ [ 2 ] => 20, [ x ] => 10 ] }
```

Expected `OUTPUT`:

```text
10
```

Only `[ x ] => 10` matches (since `[ 2 ]` does not match `[ 1 ]`), so it
fires regardless of the strategy. When multiple rules match, `random` picks
one randomly.

### When to Use Strategies

- **`first` (default)** -- Use when you want deterministic, predictable behavior.
  Most rulesets rely on this strategy implicitly.
- **`random`** -- Use for nondeterministic testing or exploratory rewrites
  where you want to see different outcomes across runs.
- **`shrink`** -- Use when you have multiple matching rules producing different
  sized results and you want the smallest output.
- **`random-rule`** -- Use when you want to pick a rule at random from the
  ruleset, not just from the matching ones.

Under the hood, the strategy is parsed by `TryParseSelectionStrategy` in
`selection_strategies.pas` and applied via `BuildRuleSelectionOrder`, which
reorders the candidate rules before the matcher iterates over them. The
`sskFirstRule` and `sskRandomRule` strategies select a rule from the ruleset
first (in order or randomly) and then attempt to match the subject, whereas
`sskFirst` and `sskRandom` try each rule in order/random and fire on the first
structural match.

## Design Guidance

- **Place specific rules before general fallback rules.** This is the single
  most important ordering principle. A broad pattern early in the ruleset will
  shadow everything that follows.
- **Use guards for conditions that cannot be expressed structurally.** If two
  rules share the same pattern but should behave differently based on values,
  use guards instead of duplicating patterns. See [Guarded Rules](guarded-rules.md).
- **End with a general fallback.** A catch-all rule like `[ x -- ] => default`
  at the end of a ruleset ensures every subject produces a result rather than
  passing through unchanged.
- **Keep rules focused.** Each rule should handle one case. Complex rules that
  try to do multiple things are harder to order correctly.
- **Test ordering explicitly.** Write test cases that verify the shadowing
  behavior -- both the correct order (specific first) and the wrong order
  (general first) -- to document the expected priority.

## Pitfalls

**A general rule at the top shadows everything.** If `[ x ] => default` appears
first, no other rule in the set will ever fire. Always verify that your
fallback rules are at the end.

**Guards only run after a structural match.** If a rule's pattern does not
match the subject, its guard is never evaluated. The matcher moves to the next
rule. A guard failure does cause the matcher to try the next rule -- this is
the intended fallback path.

**No automatic specificity ranking.** Mantra does not compare patterns to
determine which is "more specific." If two rules match, only declaration order
decides. The second matching rule is silently ignored.

**Rule templates are never evaluated prematurely.** Rules stored in variables
remain structural patterns until the matcher uses them. This means you can
safely pass rulesets around without worrying about early evaluation corrupting
the patterns.

**`--no-guards` disables guard fallback.** When guards are disabled via the
`--no-guards` CLI flag, guarded rules fire based on structural match alone. A
guarded rule that would normally fail its guard will now fire, potentially
blocking the fallback rule behind it.

## Related Pages

- [Selection Operator](../selection/selection-operator.md) -- The `?` operator
  and rule-based structural rewriting
- [Guarded Rules](guarded-rules.md) -- Conditional rules with `~( ... )` guards
- [State Selection](../selection/state-selection.md) -- Iterative rewrites with
  `$?`
- [Bidirectional Rewrites](bidirectional-rewrites.md) -- Equivalence rules
  (`<=>`) that fire in either direction
- [Focus and Match Selectors](../selection/focus-match-selectors.md) -- Rule
  selection with `.` focus markers
