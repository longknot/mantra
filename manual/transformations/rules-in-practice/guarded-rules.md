# Guarded Rules

Guards let a rule match structurally and then check an additional condition
before the rewrite is applied. A guard is a compute expression marked with `~`
(tilde) that appears after the replacement template in a rule.

```mantra
pattern => replacement ~( condition )
```

The structural match happens first. If it succeeds, the guard expression is
evaluated. If the guard is true, the rule fires and the replacement is
applied. If the guard is false, the matcher skips this rule and tries the next
one in the ruleset.

If no rule in the entire ruleset matches (either structurally or because all
matching rules fail their guards), the subject is returned unchanged.

## Syntax

A guard is attached to the replacement side of a rule using the `~` meta flag
followed by a parenthesized expression:

```mantra
[ x -- ] [ y -- ] => x ~( < x y )
```

The `~` marks the guard as a computation node. The expression inside `~( ... )`
is evaluated after variable bindings are resolved, and the result is tested for
truthiness.

### Guard Evaluation

The guard expression is evaluated through the compute pipeline:

1. The guard template is cloned with the current variable bindings substituted.
2. The cloned node undergoes `Compute()` — arithmetic reduction.
3. The result is passed to `GuardToBoolean()`:
   - An integer value of `0` evaluates to **false**.
   - Any non-zero integer evaluates to **true**.
   - If the result is not an integer, it defaults to **true**.
4. The temporary guard node is deleted — it does not appear in the output.

## Worked Examples

### Guard Evaluates to True — Rule Fires

```mantra
{ [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
1
```

The pattern `[ x -- ] [ y -- ]` matches: `x` captures `[ 1 ]` and `y` captures
`[ 2 ]`. The guard `~( < x y )` computes `< 1 2`, which is `1` (true). The rule
fires and the replacement `x` resolves to `1`.

### Guard Evaluates to False — No Fallback

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

The pattern matches (`x` = `[ 3 ]`, `y` = `[ 2 ]`), but the guard `~( < x y )`
computes `< 3 2`, which is `0` (false). The rule is skipped. Since there are no
other rules, the original subject is returned unchanged.

### Guard False — Fallback Rule Fires

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Expected `OUTPUT`:

```text
2
```

The first rule matches structurally but its guard `< 3 2` fails. The matcher
tries the second rule `[ x -- ] [ y -- ] => y`, which has no guard and fires
immediately. The replacement `y` resolves to `2`.

This pattern — guarded rule followed by an unguarded fallback — is the most
common guard idiom. It lets you express "prefer X when condition holds, otherwise
use Y."

### Multiple Guards in a Ruleset

```mantra
{ [ 5 ] [ 3 ] [ 1 ] ? [
  [ x -- ] => x ~( > ~ x 4 ) ,
  [ x -- ] => x ~( < ~ x 2 ) ,
  [ x -- ] [ y -- ] => y
] }
```

In this example, the matcher tries rules in order:
1. First rule: `> 5 4` is true, so the rule fires, returning `5`.
2. The second and third rules are never reached because the first rule already
   succeeded.

If the first element were `3`, the first guard (`> 3 4`) would fail, the second
guard (`< 3 2`) would also fail, and the fallback third rule would fire.

## Why Guards Are Useful

Guards decouple structural matching from semantic constraints. Without guards,
you would need to encode conditions as additional structural patterns, which is
often impossible or awkward. Guards let you:

- **Compare captured values** — use arithmetic operators (`<`, `>`, `=`, `+`,
  `-`, etc.) on matched variables.
- **Express dynamic conditions** — the guard is evaluated at match time with
  the actual bound values, not when the rule is declared.
- **Keep rules readable** — the structural pattern and the condition are on the
  same line, making the intent clear.

Guards are especially important when rules overlap structurally but should only
fire under specific conditions. See [Ordered Rule Sets](ordered-rule-sets.md)
for rule ordering without guards.

## How Guards Fit into the Matcher Lifecycle

When the matcher processes a rule, it follows these steps:

1. **Split the rule** — `SplitRuleTemplate` separates the pattern, replacement,
   and guard. It scans the rule's children for the first node marked with `~`
   (detected by `IsGuardNode` checking for `TK_TILDE`). The guard is stored
   separately from the replacement template.

2. **Structural match** — The matcher walks the subject tree and tries to match
   the pattern. If it fails, the rule is skipped immediately.

3. **Evaluate the guard** — If the structural match succeeds, the guard template
   is cloned with variable bindings substituted. The cloned guard undergoes
   `Compute()` to reduce the expression, then `GuardToBoolean()` checks the
   result. The temporary guard node is deleted afterward.

4. **Apply the rewrite** — Only if the guard passes (or is absent) is the
   replacement template applied. Captured variables are substituted and the
   matched subtree is replaced in-place.

5. **Move to the next rule** — If the guard fails, the matcher tries the next
   rule in the ruleset without re-matching the pattern from scratch.

Guards are checked **after** structural matching but **before** the rewrite is
committed. This means a failed guard does not modify the subject tree.

## Runtime Control

Guards can be disabled globally with the `--no-guards` CLI flag:

```bash
mantra --no-guards program.m
```

When guards are disabled, the matcher ignores all `~( ... )` expressions and
fires rules based on structural match alone.

### Example: Guard Disabled

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Without `--no-guards`:

```text
[ 3 ] [ 2 ]
```

With `--no-guards`:

```text
3
```

The guard `< 3 2` would normally fail, but with `--no-guards` the rule fires
anyway and returns `x` (which is `3`). The fallback rule, if one existed, would
never be reached.

### When to Use `--no-guards`

Use `--no-guards` only when the behavior under disabled guards is the thing
being verified. Typical scenarios include:

- **Testing** — verifying that a ruleset works correctly without guard
  constraints (e.g., checking that rule ordering alone produces the expected
  result).
- **Exploration** — experimenting with rule patterns before adding guard
  conditions.
- **Guard-light programs** — some deterministic transforms (like sorting
  pipelines using fixpoint iteration) can operate correctly without guards,
  relying instead on state tokens in the subject to control flow.

For more on the trade-offs between guards and fixpoint iteration, see the
design discussion in `docs/SWAT_GUARDS_VS_FIXPOINT.md`.

## Design Guidance

- **Place guarded rules before their unguarded fallbacks.** The matcher tries
  rules in declaration order. A guarded rule that fails should be followed by
  the alternative you want.

- **Keep guard expressions simple.** Guards are evaluated through the compute
  pipeline, so they support arithmetic and comparison operators. Complex guards
  can obscure the rule's intent.

- **Prefer structural specificity over guards when possible.** If you can make
  the pattern itself distinguish cases, the rules are easier to read and
  `--no-guards` remains a viable exploration mode.

- **Use guards for dynamic conditions that cannot be encoded structurally.**
  Value comparisons (`<`, `>`, `=`) and arithmetic predicates are the primary
  use case.

## Pitfalls

**Guard expressions must produce integers for reliable false detection.**
`GuardToBoolean` treats `0` as false and any other integer as true. If the
result is not an integer node, it defaults to true — so an uncomputed or
malformed guard expression will silently allow the rule to fire.

**Guards are evaluated after matching, not before.** The structural match
happens first. If you have overlapping patterns, the first matching rule's guard
will be evaluated; a guard failure does not cause the matcher to try the next
pattern from the beginning of the subject — it simply moves to the next rule.

**`--no-guards` changes semantics.** Programs that rely on guards for
correctness will behave differently when `--no-guards` is passed. This flag
should never be used in production code — it exists for testing and exploration.

**Guard nodes are temporary.** The cloned guard expression is deleted after
evaluation. It does not appear in the output or affect the subject tree.

## Related Pages

- [Selection Operator](../selection/selection-operator.md) — The `?` operator
  and rule-based structural rewriting
- [Ordered Rule Sets](ordered-rule-sets.md) — Rule priority without guards
- [State Selection](../selection/state-selection.md) — Iterative rewrites with
  `$?`
- [Matcher Controls](../../reference/command-line/matcher-inference-options/matcher-controls.md)
  — The `--no-guards` and `--backtracking` CLI flags
