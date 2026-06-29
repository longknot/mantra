# Proof-Oriented Data

Mantra treats proofs as first-class data. Selection, inference, and witness
forms produce structured results stored in the variable trie that can be
inspected, composed, rendered, and passed between expressions.

See the parent page [Selection and Witness Forms](../selection-witness-forms.md)
for the full syntax and semantics.

## Inference Results as Boolean Values

Standard inference (`|=`) returns `1` (proof found) or `0` (not found):

```mantra
print { 1 => 2 |= [ 1 => 2 ] }
# → 1

print { 1 => 3 |= [ 1 => 2 ] }
# → 0
```

This is the simplest proof query — a yes/no answer with no trace.
For observable traces, use witness forms (`?|=`) described below.

## Witness Forms — Structured Proof Traces

Witness inference (`?|=`) extends standard inference by recording every
rewrite step. On completion, it returns the witness name (e.g.,
`"witness.w1"`) and populates the `witness` namespace with full trace data.

### Auto-Naming

Witness entries are numbered sequentially: `witness.w1`, `witness.w2`, etc.
Each `?|=` query increments the counter within the execution context.

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
# → "witness.w1"

print { 1 => 3 ?|= [ 1 => 2, 2 => 3 ] : 2 }
# → "witness.w2"
```

### The Witness Data Structure

Every witness entry exposes these fields under `witness.wN`:

| Field | Type | Description |
|---|---|---|
| `ok` | integer | `1` if proof succeeded, `0` if it failed |
| `count` | integer | Number of rewrite steps taken |
| `steps` | array | Individual rewrite steps (1-based) |
| `policy` | string | Inference policy used (e.g., `"cost"`) |
| `initial_beam` | integer | Starting beam width for search |
| `effective_beam` | integer | Actual beam width reached during search |
| `attempts` | integer | Total inference search attempts |

Each step in `steps[i]` exposes:

| Field | Type | Description |
|---|---|---|
| `rule` | tree | The rule pattern applied |
| `rule_name` | string | Named rule identifier (if rule has a name) |
| `direction` | string | `"forward"` or `"reverse"` |
| `orientation` | string | `"default"` or `"explicit"` |
| `before` | tree | Expression state before the rewrite |
| `after` | tree | Expression state after the rewrite |
| `anchor` | integer | Position index where the match anchored |

### Inspecting Witness Steps

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
print { witness.w1.ok }
print { witness.w1.count }
# → "witness.w1"
# → 1
# → 1
```

### Accessing All Step Fields

Use `steps*` to retrieve all fields for all steps as a single trie:

```mantra
print { witness.w1.steps* }
# → [ "witness.w1.steps[1].after" -> 2
#      "witness.w1.steps[1].anchor" -> 0
#      "witness.w1.steps[1].before" -> 1
#      "witness.w1.steps[1].direction" -> "forward"
#      "witness.w1.steps[1].orientation" -> "default"
#      "witness.w1.steps[1].rule" -> 1 => 2 ]
```

### Named Rules and Rule Names

When rules are assigned to variables, the witness records the variable name:

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;

print { 1 => 3 ?|= [ repeat_seq, ih ] : 2 }
print { witness.w1.steps[1].rule_name }
print { witness.w1.steps[2].rule_name }
# → "witness.w1"
# → [ "witness.w1.steps[1].rule_name" -> "repeat_seq" ]
# → [ "witness.w1.steps[2].rule_name" -> "ih" ]
```

Rules nested inside groups also preserve their individual names:

```mantra
group = [ repeat_seq, ih ];
print { 1 => 3 ?|= [ group ] : 2 }
# Still records steps[1].rule_name = "repeat_seq"
# and steps[2].rule_name = "ih"
```

### Reverse Direction and Equivalence Rules

When a rule is declared as equivalence (`<=>`), the inference engine can
apply it in either direction. The witness records which direction was used:

```mantra
contract = 1 <=> 2;

print { 2 => 1 ?|= [ reverse contract ] }
print { witness.w1.ok }
print { witness.w1.steps[1].rule_name }
print { witness.w1.steps[1].direction }
print { witness.w1.steps[1].orientation }
# → "witness.w1"
# → 1
# → [ "witness.w1.steps[1].rule_name" -> "contract" ]
# → [ "witness.w1.steps[1].direction" -> "reverse" ]
# → [ "witness.w1.steps[1].orientation" -> "explicit" ]
```

The `reverse` keyword forces the engine to use the equivalence rule in the
reverse direction. Without it, the engine tries forward first and reverses
only if needed. The `orientation` field distinguishes automatic direction
choice (`"default"`) from explicit (`"explicit"`).

### Beam Search Witnesses

When beam search is configured, the witness records search metadata:

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 2 }
{ mantra.inference.policy = "cost" }

print { 1 => 3 ?|= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
print { witness.w1.ok }
print { witness.w1.policy }
print { witness.w1.initial_beam }
print { witness.w1.effective_beam }
print { witness.w1.attempts }
# → "witness.w1"
# → 1
# → "cost"
# → 1
# → 2
# → 2
```

The `effective_beam` may exceed `initial_beam` if the engine widened the beam
during backtracking. `attempts` counts the total search attempts made.

### Failed Witnesses

When a proof fails, `ok` is `0` and `count` reflects the steps attempted
before failure:

```mantra
print { 1 => 3 ?|= [ 1 => 2 ] : 2 }
print { witness.w1.ok }
# → "witness.w1"
# → 0  (cannot reach 3 from 1 with only [ 1 => 2 ])
```

Failed witnesses still record the steps that were attempted, which is useful
for diagnosing why a proof did not complete.

### Grouping and Transparent Syntax

When subject or target expressions contain operators that could be confused
with query syntax (`:`, `=>`), prefix elements with `+` to force node
creation:

```mantra
ih = << + m : + n >> => << + n : + m >>;

print { << + m : + n >> => << + n : + m >> ?|= [ ih ] : 1 }
print { witness.w1.steps[1].rule }
# → "witness.w1"
# → [ "witness.w1.steps[1].rule" -> + m : + n => + n : + m ]
```

Without the `+` prefix, the parser may interpret `:` or `=>` inside containers
as selection or inference operators rather than data.

## Failed Witnesses and Fallback

Combine witness inference with the fallback operator `??` to provide
alternative results when a proof cannot be found:

```mantra
{ subject => target ?|= [ rules ] ?? "proof failed" }
```

If the witness inference succeeds, the result is the witness name
(e.g., `"witness.w1"`). If it fails, the fallback value is returned instead.

## Rule Variables

Rules can be stored in variables and referenced in queries. The inference
engine resolves the variable and uses the stored pattern for matching.

```mantra
ih = << + m : + n >> => << + n : + m >>;

print { << + m : + n >> => << + n : + m >> ?|= [ ih ] : 1 }
# → "witness.w1"
```

Rule operands themselves can be materialized from variables:

```mantra
ih_lhs = 1;
ih_rhs = 2;
ih = ih_lhs => ih_rhs;

print { 1 => 2 ?|= [ ih ] : 1 }
print { witness.w1.steps[1].rule_name }
# → "witness.w1"
# → [ "witness.w1.steps[1].rule_name" -> "ih" ]
```

## Proof Chains

For multi-step proofs, use bounded search to limit depth with `: n`:

```mantra
print { 1 => 3 ?|= [ 1 => 2, 2 => 3, 3 => 4, 4 => 1 ] : 2 }
print { witness.w1.ok }
print { witness.w1.count }
# → "witness.w1"
# → 1  (chain 1→2→3 found within 2 steps)
# → 2
```

The bound `: 2` limits the search to 2 rewrite steps. Without a bound,
the engine searches until it finds a proof or exhausts the rule space.
Use `: 0` to check if subject already equals target without applying rules.

## Equivalence Checking

Use `<=>` in the query to verify bidirectional equivalence:

```mantra
print { [ 1 2 ] <=> [ 2 1 ] |= [ [ x y ] <=> [ y x ] ] }
# → 1  (both directions: [1 2]↔[2 1] works)
```

Equivalence requires the rules to transform subject→target AND target→subject.
Witness forms (`?|=`) with equivalence record the direction used for each step.

## Witness Step Printing

The `utils.witness_print_steps` helper formats witness traces as readable
output:

```mantra
import utils;

commute = + M N <=> + N M;
rules = [ commute ];
{ W = [ + 1 2 ] => [ + 2 1 ] ?|= rules : 1 }
mantra.effects.display.evaluate = 1;
{ utils.witness_print_steps W }
# → step 1 | rule=commute | dir=forward | anchor=1 | [ + 1 + 2 ] => [ + 2 + 1 ]
```

This is useful for debugging and verifying proof paths interactively.

## Rendering Witnesses as Tables

Witness data can be rendered as formatted tables using built-in profiles:

### Columns Format

```mantra
import utils;

w = witness.w1 -> {
  steps -> [
    { rule_name -> "repeat_seq", direction -> "forward", anchor -> 1, before -> "s0", after -> "s1" },
    { rule_name -> "ih", direction -> "reverse", anchor -> 2, before -> "s1", after -> "s2" }
  ]
};

{ utils.make_trie w };
print [ render columns profiles.witness_steps "witness.w1" ]
# → STEP  RULE        DIR      ANCHOR
# → 1     repeat_seq  forward  1
# → 2     ih          reverse  2
```

The `profiles.witness_steps_wide` profile adds `BEFORE` and `AFTER` columns.

### CSV Format

```mantra
print [ render csv profiles.witness_steps "witness.w1" ]
# → STEP,RULE,DIR,ANCHOR
# → 1,repeat_seq,forward,1
# → 2,ih,reverse,2
```

Custom profiles support additional options (headers, delimiters, column
selection). See [Rendering Structured Output](../rendering-structured-output.md)
for details on profile configuration.

## Related Pages

- [Selection and Witness Forms](../selection-witness-forms.md) — Full syntax and semantics
- [Witness Output](witness-output.md) — Detailed witness field reference
- [Rendering Structured Output](../rendering-structured-output.md) — Profile-based rendering
- [Fixpoint Repeat](../transformations/fixpoint-repeat.md) — Bounded iterative rewrites
