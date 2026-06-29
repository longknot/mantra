# Named Rules in Proofs

Named rules are useful when a proof should record which rule was applied at each
step. When rules are given names, witness output preserves those names, turning
anonymous rewrites into explained proof steps.

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;
rules = [ repeat_seq, ih ];

print { 1 => 3 ?|= rules : 2 };
print { witness.w1.ok };
print { witness.w1.count };
print { witness.w1.steps[1].rule_name };
print { witness.w1.steps[2].rule_name };
```

Expected `OUTPUT`:

```text
"witness.w1"
1
2
[ "witness.w1.steps[1].rule_name" -> "repeat_seq" ]
[ "witness.w1.steps[2].rule_name" -> "ih" ]
```

## Why This Is Useful

Without names, the inference engine can still find a path from source to target,
but the witness only shows the raw rewrite steps. Named rules make rule names
part of the explanation surface. Each step in the witness carries the rule name
that produced it, so you can reconstruct the proof logic by reading the step
sequence.

Use named rules in proofs when you need:

- **Traceable rewrites** -- Each step records which rule fired, making it easy
  to verify the proof path matches the intended logic.
- **Readable proof reports** -- Named steps (`repeat_seq`, `ih`, `base_case`)
  are more meaningful than raw tree transformations in documentation and
  debugging.
- **Debugging failed proofs** -- When a proof fails, the witness shows which
  rules were attempted and in what order, helping identify where the search
  diverged from expectations.

## How Named Rules Work

A rule becomes named when it is stored in a variable. The variable name is
captured by the inference engine and recorded in the witness:

1. **Define named rules** -- Assign rules to variables using `=` or `:=`. The
   variable name becomes the rule name.
2. **Collect in a ruleset** -- Place named rules in a list `[ rule1, rule2 ]`
   or reference them via a variable.
3. **Run inference query** -- Use `?|=` to materialize a witness. The engine
   records `rule_name` for each step.
4. **Read the witness** -- Access `witness.wN.steps[i].rule_name` to inspect
   which rule each step used.

### Key Differences: Named vs. Anonymous Rules

| Behavior | Named Rule | Anonymous Rule |
|---|---|---|
| Definition | `r = 1 => 2` | Inline: `[ 1 => 2 ]` |
| Witness `rule_name` | Variable name (`"r"`) | Raw tree representation |
| Readability | Human-meaningful | Machine-readable structure |
| Reuse | Reference by variable | Must be repeated inline |

## Examples

### Multi-Step Chain Proof

Two named rules chain to prove `1 => 3` within two steps:

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;
rules = [ repeat_seq, ih ];

print { 1 => 3 ?|= rules : 2 };
print { witness.w1.ok };
print { witness.w1.count };
print { witness.w1.steps[1].rule_name };
print { witness.w1.steps[2].rule_name };
```

Expected `OUTPUT`:

```text
"witness.w1"
1
2
[ "witness.w1.steps[1].rule_name" -> "repeat_seq" ]
[ "witness.w1.steps[2].rule_name" -> "ih" ]
```

The witness confirms `ok` is `1` (proof succeeded) and `count` is `2`
(two steps). Step 1 applied `repeat_seq` (rewriting `1` to `2`), and step 2
applied `ih` (rewriting `2` to `3`).

### Named Rules Inside Groups

Rules can be nested inside a group variable and still preserve their names:

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;
group = [ repeat_seq, ih ];
rules = [ group ];

print { 1 => 3 ?|= rules : 2 };
print { witness.w1.ok };
print { witness.w1.count };
print { witness.w1.steps[1].rule_name };
print { witness.w1.steps[2].rule_name };
```

Expected `OUTPUT`:

```text
"witness.w1"
1
2
[ "witness.w1.steps[1].rule_name" -> "repeat_seq" ]
[ "witness.w1.steps[2].rule_name" -> "ih" ]
```

Even though the rules are wrapped in a `group` variable, the witness records
the individual rule names (`repeat_seq`, `ih`) rather than the group name.
This allows organizing rules in modules or categories without losing step-level
traceability.

### Equivalence Rules with Direction Tracking

When equivalence rules `<=>` are used in proofs, the witness records both the
rule name and the direction it was applied (forward or reverse):

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

The witness records `direction` as `"reverse"` and `orientation` as
`"explicit"` — the `reverse` keyword explicitly tells the engine to apply
the rule backward. Without `reverse`, the engine would try both directions
automatically and record whichever direction succeeded.

### Witness Structure Reference

A witness object exposes several fields accessible via `witness.wN`:

| Field | Type | Description |
|---|---|---|
| `.ok` | `1` / `0` | Whether the proof succeeded |
| `.count` | integer | Number of steps in the proof path |
| `.steps[i].rule_name` | string | Name of the rule applied at step `i` |
| `.steps[i].direction` | string | `"forward"` or `"reverse"` |
| `.steps[i].orientation` | string | `"explicit"` or `"auto"` |
| `.steps[i].anchor` | value | The state anchor at this step |
| `.steps[i].before` | string | State label before the rewrite |
| `.steps[i].after` | string | State label after the rewrite |

Step indices start at `1`. When the proof fails, `.ok` is `0` and the steps
array reflects the search attempts that were made before giving up.

## Inference Configuration

Named rules interact with inference budget flags that control proof search. The
key runtime settings are:

| Setting | Description |
|---|---|
| `mantra.inference.beam` | Beam width for search (default: 1) |
| `mantra.inference.beam_delta` | Increment for beam widening |
| `mantra.inference.beam_max` | Maximum beam width |
| `mantra.inference.budget` | Subexpression rewrite budget |
| `mantra.inference.policy` | Selection policy (`"default"`, `"cost"`) |
| `mantra.inference.profile` | When `true`, emit diagnostic events |
| `mantra.inference.anchors_per_rule` | Anchors tried per rule |

When the profile is enabled, diagnostic events report rule-level statistics
including which named rules were tried, their direction, and counts for
generated, admitted, and pruned candidates.

### Witness Policy Metadata

The witness also records metadata about which policy and beam settings were
active during the search:

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 2 }
{ mantra.inference.policy = "cost" }

print { 1 => 3 ?|= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 };
print { witness.w1.ok };
print { witness.w1.policy };
print { witness.w1.initial_beam };
print { witness.w1.effective_beam };
print { witness.w1.attempts };
```

Expected `OUTPUT`:

```text
"witness.w1"
1
[ "witness.w1.policy" -> "cost" ]
[ "witness.w1.initial_beam" -> 1 ]
[ "witness.w1.effective_beam" -> 2 ]
[ "witness.w1.attempts" -> 2 ]
```

The witness records that the `"cost"` policy was active, the beam widened from
`1` to `2`, and the search took `2` attempts.

## Design Guidance

- **Name rules for proof readability** -- Use descriptive names (`base_case`,
  `inductive_step`, `commute`) that convey the logical role of each rewrite.
- **Keep rules focused** -- Each named rule should perform one logical operation.
  A single rule that does multiple things makes the witness harder to read.
- **Organize with groups** -- Use group variables to categorize rules
  (`arithmetic`, `structural`, `logical`) without losing individual names in
  the witness.
- **Test with witnesses** -- Write tests that assert on `witness.wN.ok` and
  `witness.wN.steps[i].rule_name` to verify both correctness and proof path.
- **Use profile mode for debugging** -- Enable `mantra.inference.profile = true`
  to see which rules the engine tried, in what order, and how many candidates
  were pruned.

## Reading the Proof

Return to the first example:

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;
rules = [ repeat_seq, ih ];

print { 1 => 3 ?|= rules : 2 };
```

The proof reads as: "Starting from `1`, apply up to 2 rules from the set.
Step 1 uses `repeat_seq` to reach `2`. Step 2 uses `ih` to reach `3`. The
target `3` is reached, so the proof succeeds."

Each step is a named, verifiable transformation. The witness makes the proof
path explicit rather than implicit.

## Related Pages

- [Inference Operator](../inference/inference-operator.md)
- [Witnesses](../inference/witnesses.md)
- [Bounded Search](../inference/bounded-search.md)
- [Equivalence Rules](../transform-rules/equivalence-rules.md)
- [Basic Transform](../transform-rules/basic-transform.md)
- [Rules in Practice](../rules-in-practice.md)
