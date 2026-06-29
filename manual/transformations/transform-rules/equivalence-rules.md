# Equivalence Rules

The equivalence operator is `<=>`.

```mantra
pattern <=> replacement
```

An equivalence rule defines a **bidirectional** rewrite: the pattern on either
side can match and be replaced by the other. This is the key difference from a
basic transform (`=>`), which only rewrites left to right.

## Bidirectional Behavior

When a selection (`?`) or inference (`|=`) encounters an equivalence rule, the
runtime automatically tries **both directions** — forward (left-to-right) and
reverse (right-to-left) — and accepts the first match.

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

The first call matches `[ 3 4 ]` against the left side of the rule (forward)
and replaces it with `[ 4 3 ]`. The second call matches `[ 4 3 ]` against the
right side (reverse) and replaces it with `[ 3 4 ]`.

## Equivalence vs Basic Transform

A basic transform only matches in one direction:

```mantra
rule forward_only [
  1 => 2
]

print { 1 ? forward_only : 1 }  // matches: 1 -> 2
print { 2 ? forward_only : 1 }  // no match: stays 2
```

With an equivalence rule, both directions work:

```mantra
rule both_ways [
  1 <=> 2
]

print { 1 ? both_ways : 1 }  // matches forward: 1 -> 2
print { 2 ? both_ways : 1 }  // matches reverse: 2 -> 1
```

## Equivalence in Inference

In inference queries, `<=>` in the ruleset means the engine can apply the rule
in either direction to reach the target. A one-step equivalence query requires
an actual equivalence rule (not a unidirectional transform):

```mantra
print { 1 <=> 2 |= [ 1 <=> 2 ] }  // 1 — equivalence rule matches
print { 1 <=> 2 |= [ 1 => 2 ] }   // 0 — unidirectional rule insufficient
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

## Rule Orientation: `forward` and `reverse`

By default, the inference engine tries both directions of an equivalence rule.
You can restrict application to a single direction using the `forward` or
`reverse` keywords:

```mantra
contract = 1 <=> 2;

print { 1 => 2 |= [ forward contract ] };  // 1 — forward direction only
print { 2 => 1 |= [ forward contract ] };  // 0 — forward won't go 2 -> 1
print { 1 => 2 |= [ reverse contract ] };  // 0 — reverse won't go 1 -> 2
print { 2 => 1 |= [ reverse contract ] };  // 1 — reverse direction only
```

The `forward` keyword restricts the rule to match left-to-right (LHS -> RHS).
The `reverse` keyword restricts it to match right-to-left (RHS -> LHS).

When the inference profile is enabled, diagnostic output reports how many
candidates were generated in each direction (`forward=N reverse=N`).

## Fixed Equivalence Transforms

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

## Why Equivalence Rules Are Useful

- **Normalization**: Express algebraic identities once and apply them either
  way (commutativity, associativity, symmetry).
- **Proof search**: Reduce ruleset size — one equivalence rule replaces two
  unidirectional transforms.
- **Named proof steps**: Equivalence rules carry names through inference
  witnesses. Each step records `rule_name`, `direction` (`forward` or
  `reverse`), and `orientation` (`default` or `explicit`).

## Related Pages

- [Basic Transform](basic-transform.md)
- [Substitution Transform](substitution-transform.md)
- [Inference Operator](../inference/inference-operator.md)
- [Bidirectional Rewrites](../rules-in-practice/bidirectional-rewrites.md)
- [Named Rules in Proofs](../rules-in-practice/named-rules-in-proofs.md)
