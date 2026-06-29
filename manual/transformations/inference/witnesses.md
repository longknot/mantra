# Witnesses

The witness inference operator `?|=` performs a proof search like `|=`, but with
a critical difference: it **materializes the rewrite trace** as named variables
in the runtime context. Instead of returning `1` or `0`, it returns the witness
handle string that lets you inspect every step of the derivation.

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
```

Expected `OUTPUT`:

```text
"witness.w1"
```

The handle `witness.w1` is a variable prefix. Each witness query gets an
auto-incremented handle (`witness.w1`, `witness.w2`, ...) scoped to the current
context. If the witness is inside a variable assignment, the prefix uses the
assigned variable name instead.

## Syntax

```
subject => target ?|= rules               (directional witness)
subject <=> target ?|= rules              (bidirectional witness)
subject => target ?|= rules : n           (bounded step limit)
```

The syntax mirrors standard inference (`|=`) but uses `?|=` to signal witness
mode. The left side is a **query** (subject and target). The right side is a
**ruleset** -- an array of transformation rules.

| Component | Description |
|---|---|
| `subject` | Starting expression (source term) |
| `target` | Expression to reach (goal term) |
| `rules` | Array of rules `[ rule1, rule2, ... ]` |
| `n` | Maximum rewrite steps (via `: n` repeat modifier) |

## Witness Handle and Prefix

Each `?|=` evaluation allocates a unique prefix via `AllocateWitnessPrefix`. The
handle format is `<base>.<kind><serial>` where:

| Factor | Effect |
|---|---|
| No assignment | Base is `witness`, kind is `w` -- produces `witness.w1`, `witness.w2`, ... |
| Inside `var = ...` | Base is the variable name -- produces `var.w1`, `var.w2`, ... |

The serial counter increments globally per context. Each `?|=` call consumes
exactly one serial number, regardless of whether the search succeeds or fails.

```mantra
# Multiple witnesses get auto-incrementing handles
print { 1 => 2 ?|= [ 1 => 2 ] }   # "witness.w1"
print { 2 => 3 ?|= [ 2 => 3 ] }   # "witness.w2"
```

## Witness Variables

When the witness handle prefix is non-empty, the runtime stores these metadata
variables under the prefix:

| Variable | Type | Description |
|---|---|---|
| `w.ok` | int | `1` if target was reached, `0` otherwise |
| `w.count` | int | Number of rewrite steps in the trace |
| `w.policy` | string | Selection policy used (`"default"` or `"cost"`) |
| `w.initial_beam` | int | Beam width at start of search |
| `w.effective_beam` | int | Beam width actually used (may widen) |
| `w.attempts` | int | Number of search attempts performed |
| `w.steps` | trie | Indexed step records (see below) |

### Step Records

Each rewrite step is stored in `w.steps[n]` as a trie with these properties:

| Property | Type | Description |
|---|---|---|
| `.before` | tree | Expression state before this step |
| `.after` | tree | Expression state after this step |
| `.rule` | tree | The rule applied (directional copy) |
| `.rule_name` | string | Named rule identifier (if applicable) |
| `.direction` | string | `"forward"` or `"reverse"` |
| `.orientation` | string | `"default"` or `"explicit"` |
| `.anchor` | int | Anchor ordinal within the expression |

### Inspecting the Trace

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
print { witness.w1.ok }
print { witness.w1.count }
print { witness.w1.steps* }
```

Expected `OUTPUT`:

```text
"witness.w1"
1
1
[ "witness.w1.steps[1].after" -> 2  "witness.w1.steps[1].anchor" -> 0  "witness.w1.steps[1].before" -> 1  "witness.w1.steps[1].direction" -> "forward"  "witness.w1.steps[1].orientation" -> "default"  "witness.w1.steps[1].rule" -> 1 => 2 ]
```

The `steps*` expansion uses wildcard repetition to enumerate all step records.
Each step is indexed starting from `1`.

## One-Step and Multi-Step Witnesses

The step bound works the same way as standard inference -- `: n` controls the
maximum rewrite depth.

### One-Step Witness

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
```

Returns `witness.w1` with `witness.w1.ok = 1` and `witness.w1.count = 1`.
The single step stores the rule and the before/after states.

### Multi-Step Witness

```mantra
print { 1 => 3 ?|= [ 1 => 2, 2 => 3 ] : 2 }
```

Returns `witness.w1` with `witness.w1.ok = 1` and `witness.w1.count = 2`.
Two steps are recorded: `1 -> 2` followed by `2 -> 3`.

### Failed Witness

When the target cannot be reached, the witness still gets a handle, but
`w.ok = 0` and `w.count = 0` -- no steps are recorded.

```mantra
print { 1 => 3 ?|= [ 1 => 2 ] : 2 }
```

Returns `witness.w1` with `witness.w1.ok = 0` and `witness.w1.count = 0`. The
ruleset contains `1 => 2`, but there is no path to `3` within the step limit.

## Bidirectional Witnesses

When the query uses `<=>` (equivalence), the engine runs two directional searches:
one from subject to target, and one from target back to subject. Both must
succeed for `w.ok = 1`.

```mantra
contract = 1 <=> 2;

print { 2 => 1 ?|= [ reverse contract ] };
print { witness.w1.ok };
print { witness.w1.steps[1].direction };
print { witness.w1.steps[1].orientation };
```

The reverse direction is recorded as `"reverse"` in the step's `.direction`
field. When the orientation is explicitly specified via `reverse`, the
`.orientation` field is `"explicit"`.

## Named Rules

When rules have identifiers, the `.rule_name` property captures the name. Named
rules are useful for identifying which specific transformation fired at each step
in complex rulesets.

```mantra
contract = 1 <=> 2;

print { 2 => 1 ?|= [ reverse contract ] };
print { witness.w1.steps[1].rule_name };
```

Expected `OUTPUT` for `rule_name`:

```text
[ "witness.w1.steps[1].rule_name" -> "contract" ]
```

## Inference Configuration

Witness inference respects the same configuration overrides as standard inference.
Set these via evaluation scopes before the query:

| Variable | Type | Description |
|---|---|---|
| `mantra.inference.beam` | int >= 1 | Beam width for search |
| `mantra.inference.budget` | int >= -1 | Congruence budget (-1 = unlimited) |
| `mantra.inference.policy` | string | `"default"` or `"cost"` |
| `mantra.inference.beam_delta` | int >= 0 | Beam widening increment |
| `mantra.inference.beam_max` | int >= beam | Maximum beam width cap |
| `mantra.inference.profile` | bool | Enable search profiling |

### Beam Widening with Witnesses

When `mantra.inference.beam_delta > 0`, the engine retries the search with
increasing beam width until the target is found or the maximum beam is reached.
The `.effective_beam` and `.attempts` metadata variables record the final values.

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
"cost"
1
2
2
```

The search first tried with beam width 1 (failed), then widened to beam width 2
(succeeded). Two total attempts were made, and the effective beam width was 2.

### Single-Path Limitation

Witness inference currently uses a single-path rewrite trace. When `mantra.inference.beam > 1`, a diagnostic
note is logged but the witness records only the winning path, not the full
beam frontier.

## Variable Assignment Prefix

When a witness query appears as the right-hand side of a variable assignment,
the witness variables use the assigned variable name as their prefix instead of
`witness`:

```mantra
x = 1 => 2 ?|= [ 1 => 2 ];
print { x.ok };     # 1
print { x.count };  # 1
```

This makes the trace self-documenting -- the variable name becomes the witness
identifier.

## Witness Data Structure

Under the hood, the witness system works through these phases:

1. **Build state init** -- `InitWitnessBuildState` creates a `TWitnessBuildState`
   with a prefix and prepares the steps trie in the context.
2. **Directional search** -- `RunDirectionalInference` runs the proof search with
   `InferenceWitnessStepCallback` as the step handler.
3. **Step recording** -- `AppendWitnessStep` stores each step's `.before`, `.after`,
   `.rule`, `.rule_name`, `.direction`, `.orientation`, and `.anchor` properties.
4. **Bidirectional check** -- for `<=>` queries, a second search runs from target
   back to subject. Both directions must succeed.
5. **Metadata store** -- `.ok`, `.count`, `.policy`, `.initial_beam`,
   `.effective_beam`, and `.attempts` are stored as variables under the prefix.
6. **Handle return** -- the node is replaced with a string containing the witness
   prefix handle.

### Rule Cloning

For equivalence rules, the engine creates a directional copy oriented to the
search direction via `CloneDirectionalRuleForWitness`. This ensures the
`.rule` property in each step reflects the actual direction the rule was
applied, even if the original rule was bidirectional.

## Comparison with Standard Inference

| Feature | `|=` (standard) | `?|=` (witness) |
|---|---|---|
| Return value | `1` or `0` | Witness handle string |
| Trace recorded | No | Yes, in context variables |
| Inspectable steps | No | Yes, via `w.steps[n]` |
| Assignment prefix | N/A | Uses variable name |
| Beam search | Full beam | Single-path trace |

Use `|=` when you only need a yes/no answer. Use `?|=` when you need to
inspect, validate, or report the derivation path.

## See Also

- [Inference operator](./inference-operator.md) -- the `|=` operator reference
- [Bounded search](./bounded-search.md) -- step limits and beam configuration
