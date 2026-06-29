# Bidirectional Rewrites

Equivalence rules use the `<=>` operator to define a rewrite that works in
both directions. Unlike a basic transform `=>` (which only rewrites left to
right), an equivalence rule lets the runtime match and replace from either
side.

```mantra
LHS <=> RHS
```

## How It Works

When the matcher encounters an equivalence rule, it automatically generates
two rewrite candidates:

1. **Forward** (LHS → RHS) — match the left side, replace with the right
2. **Reverse** (RHS → LHS) — match the right side, replace with the left

The matcher tries both candidates. The first one that matches fires.

### Example: Swapping

```mantra
rule swap [
  [ x y ] <=> [ y x ]
]

print { [ 3 4 ] ? swap : 1 }
print { [ 4 3 ] ? swap : 1 }
```

Expected `OUTPUT`:

```text
[ 4 3 ]
[ 3 4 ]
```

The first call matches `[ 3 4 ]` against the forward direction `[ x y ]` and
produces `[ 4 3 ]`. The second call matches `[ 4 3 ]` against the reverse
direction `[ y x ]` (which has the same structure) and produces `[ 3 4 ]`.

## Equivalence vs Basic Transform

A basic transform only matches in one direction:

```mantra
rule forward_only [
  1 => 2
]

print { 1 ? forward_only : 1 }  // matches: 1 -> 2
print { 2 ? forward_only : 1 }  // no match: stays 2
```

Expected `OUTPUT`:

```text
2
2
```

With an equivalence rule, both directions work:

```mantra
rule both_ways [
  1 <=> 2
]

print { 1 ? both_ways : 1 }  // matches forward: 1 -> 2
print { 2 ? both_ways : 1 }  // matches reverse: 2 -> 1
```

Expected `OUTPUT`:

```text
2
1
```

## Equivalence in Inference

In inference queries, `<=>` in the ruleset means the engine can apply the rule
in either direction to reach the target. A one-step equivalence query requires
an actual equivalence rule (not a unidirectional transform):

```mantra
print { 1 <=> 2 |= [ 1 <=> 2 ] }  // 1 — equivalence rule matches
print { 1 <=> 2 |= [ 1 => 2 ] }   // 0 — unidirectional rule insufficient
```

Expected `OUTPUT`:

```text
1
0
```

For multi-step proofs, equivalence rules can chain with other rules:

```mantra
print { 1 <=> 3 |= [ 1 => 2, 2 => 3, 3 => 4, 4 => 1 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

The inference engine finds a path from `1` to `3` within two steps using the
available rules.

## Direction Control: `forward` and `reverse`

By default, an equivalence rule can fire in either direction. You can restrict
application to a single direction using the `forward` or `reverse` keywords:

```mantra
contract = 1 <=> 2;

print { 1 => 2 |= [ forward contract ] };  // 1 — forward direction only
print { 2 => 1 |= [ forward contract ] };  // 0 — forward won't go 2 -> 1
print { 1 => 2 |= [ reverse contract ] };  // 0 — reverse won't go 1 -> 2
print { 2 => 1 |= [ reverse contract ] };  // 1 — reverse direction only
```

Expected `OUTPUT`:

```text
1
0
0
1
```

The `forward` keyword restricts the rule to match left-to-right (LHS → RHS).
The `reverse` keyword restricts it to match right-to-left (RHS → LHS).

Under the hood, `forward` creates a `TForwardRuleNode` (OBJ_RULE_FORWARD) and
`reverse` creates a `TReverseRuleNode` (OBJ_RULE_REVERSE) wrapping the rule
reference. The matcher respects these wrappers when building candidates — only
the allowed direction is added to the candidate list.

### Witness Direction Tracking

When inference produces a witness, each step records which direction was used.
The `direction` field is `"forward"` or `"reverse"`, and the `orientation`
field is `"default"` (no explicit direction keyword) or `"explicit"` (when
`forward`/`reverse` was used):

```mantra
contract = 1 <=> 2;

print { 2 => 1 ?|= [ reverse contract ] };
print { witness.w1.ok };
print { witness.w1.steps[1].rule_name };
print { witness.w1.steps[1].direction };
print { witness.w1.steps[1].orientation };
```

Expected `OUTPUT`:

```text
"witness.w1"
1
[ "witness.w1.steps[1].rule_name" -> "contract" ]
[ "witness.w1.steps[1].direction" -> "reverse" ]
[ "witness.w1.steps[1].orientation" -> "explicit" ]
```

### Inference Profile Diagnostics

When the inference profile is enabled, diagnostic output reports how many
candidates were generated in each direction:

```mantra
{ mantra.inference.profile = true }

step = 1 <=> 2;

print { 1 => 3 |= [ step ] : 1 };
print { 2 => 3 |= [ step ] : 1 };
```

The diagnostic log shows `forward=1 reverse=0` for the first query (only the
forward direction generated candidates) and `forward=0 reverse=1` for the
second (only the reverse direction generated candidates).

## Fixed Equivalence

An equivalence rule can be marked **fixed** with `\` (backslash) before the
operator. A fixed equivalence matches structurally — variable-shaped terms do
not become fresh matcher bindings:

```mantra
ih = << + m : + n >> \ <=> << + n : + m >>;

<< + m : + n >>    => << + n : + m >>    |= [ ih ] : 1   // succeeds
<< + 1 : + n >>    => << + n : + 1 >>    |= [ ih ] : 1   // fails
```

A transform-valued binding can also be referenced as fixed:

```mantra
proposition = << + m : + n >> => << + n : + m >>;
ih = \ proposition;
```

## Tail Splicing with `--`

The `--` tail-splice pattern works symmetrically in equivalence rules, making
them convenient for structural normalization:

```mantra
print { [ [ 1 2 3 ] ] ? [ [ [ x -- ] ] <=> [ x -- ] ] }
print { [ 1 2 3 ] ? [ [ [ x -- ] ] <=> [ x -- ] ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
[ [ 1 2 3 ] ]
```

The first call unwraps nested brackets (forward direction); the second rewraps
them (reverse direction).

## Substitution Equivalence `<==>`

The `<==>` operator is the substitution variant of `<=>`. It behaves like a
bidirectional equivalence but with substitution semantics — variable-shaped
terms follow substitution rules rather than creating fresh matcher bindings.
`TEquivalenceSubstitutionNode` extends `TTransformationNode` and is compiled
as `OBJ_SUBST_EQUIVALENCE`.

## Why Bidirectional Rewrites Are Useful

- **Normalization**: Express algebraic identities once and apply them either
  way (commutativity, associativity, symmetry).
- **Proof search**: Reduce ruleset size — one equivalence rule replaces two
  unidirectional transforms.
- **Named proof steps**: Equivalence rules carry names through inference
  witnesses. Each step records `rule_name`, `direction` (`forward` or
  `reverse`), and `orientation` (`default` or `explicit`).

## Related Pages

- [Equivalence Rules](../transform-rules/equivalence-rules.md)
- [Basic Transform](../transform-rules/basic-transform.md)
- [Substitution Transform](../transform-rules/substitution-transform.md)
- [Inference Operator](../inference/inference-operator.md)
- [Named Rules in Proofs](named-rules-in-proofs.md)

