# Witness Output

Witness inference (`?|=`) extends standard inference (`|=`) with observable,
step-by-step proof traces. Every witness query creates a named entry in the
`witness` namespace containing the full rewrite path, metadata, and intermediate
expression states.

See the parent page [Selection and Witness Forms](../selection-witness-forms.md)
for the full syntax and semantics.

## Quick Reference

| Field | Description |
|---|---|
| `ok` | `1` if proof succeeded, `0` if it failed |
| `count` | Total rewrite steps recorded |
| `steps[i].rule` | The rule applied at step i |
| `steps[i].rule_name` | Named rule identifier (if available) |
| `steps[i].before` | Expression before the rewrite |
| `steps[i].after` | Expression after the rewrite |
| `steps[i].direction` | `"forward"` or `"reverse"` |
| `steps[i].orientation` | `"explicit"` or `"default"` |
| `steps[i].anchor` | Anchor ordinal (position in tree) |
| `policy` | Inference policy (e.g., `"cost"`, `"default"`) |
| `initial_beam` | Starting beam width |
| `effective_beam` | Actual beam width reached |
| `attempts` | Total inference attempts |

---

## How It Works

A witness query runs the same inference engine as `|=` but with an active trace
callback. Each rewrite step fires `InferenceWitnessStepCallback`, which stores
cloned subtrees for the expression before and after the transformation, the
rule applied, direction, orientation, and anchor position.

1. Parse the query (subject, target, rules) — identical to `|=`
2. Initialize `TWitnessBuildState` with the witness prefix and context
3. Run `RunDirectionalInference` with the witness callback
4. For equivalence (`<=>`), run a second pass in the reverse direction
5. Store scalar fields (`ok`, `count`, `policy`, beam data, `attempts`)
6. Replace the witness node with the witness name string

### Node Implementation

The `TInferenceWitnessNode` (`?|=`) class in `nodes.pas` handles witness
evaluation. It calls `TInferenceWitnessNode.Evaluate` which:
- Resolves inference configuration (beam, budget, policy) from runtime settings
- Creates the witness build state and run info records
- Delegates to `RunDirectionalInference` in `inference.pas`
- Handles equivalence queries by running two directional passes
- Stores results as indexed variables under the witness prefix

---

## Auto-Naming

Witness entries are numbered sequentially: `witness.w1`, `witness.w2`, etc.
The counter increments with each `?|=` query in the same execution context.

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
# → "witness.w1"

print { 3 => 4 ?|= [ 3 => 4 ] }
# → "witness.w2"
```

### Assignment-Based Naming

When a witness query is the RHS of a variable assignment, the witness inherits
the variable name as its prefix instead of the auto-incremented `witness.wN`:

```mantra
{ W = [ + 1 2 ] => [ + 2 1 ] ?|= [ + M N <=> + N M ] : 1 }
# Creates witness entry "W" (not "witness.w1")
# Access via W.ok, W.steps[1].rule, etc.
```

The `InferAssignmentPrefixBase` function detects this pattern:
1. The witness node's parent is an `OBJ_ASSIGNMENT`
2. The assignment's LHS is a simple variable (no siblings)
3. The witness node is the assignment's RHS

If the conditions are met, the variable name becomes the witness prefix.
Otherwise, `Context.AllocateWitnessPrefix` generates the default
`witness.wN` naming.

### Custom Prefixes

You can supply a custom prefix base by passing it to
`Context.AllocateWitnessPrefix`. This is useful for batched inference
where you want grouped naming (e.g., `test.w1`, `test.w2`).

---

## Witness Data Structure

### Scalar Fields

Each witness entry stores these scalar values:

| Field | Type | Description |
|---|---|---|
| `ok` | Integer | `1` if proof succeeded, `0` if it failed |
| `count` | Integer | Total number of rewrite steps recorded |
| `policy` | String | Inference policy — `"cost"` or `"default"` |
| `initial_beam` | Integer | Starting beam width from config |
| `effective_beam` | Integer | Maximum beam width actually reached during search |
| `attempts` | Integer | Total inference attempts across all directional passes |

### Step Fields

Each step in `steps[i]` stores:

| Field | Type | Description |
|---|---|---|
| `rule` | Tree | The directional rule applied (cloned subtree) |
| `rule_name` | String | Named rule identifier (empty string if unnamed) |
| `before` | Tree | Expression before the rewrite (cloned subtree) |
| `after` | Tree | Expression after the rewrite (cloned subtree) |
| `direction` | String | `"forward"` (direction=0) or `"reverse"` (direction=1) |
| `orientation` | String | `"explicit"` if orientation was explicitly set, `"default"` otherwise |
| `anchor` | Integer | Anchor ordinal — position index in the tree traversal |

---

## Inspecting Witness Data

After a witness query completes, access trace data using dot notation and
array indexing. Steps are 1-indexed.

### Basic Success

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
# → "witness.w1"

print { witness.w1.ok }
# → 1

print { witness.w1.count }
# → 1
```

### Single Step With Full Details

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
print { witness.w1.steps* }
# → "witness.w1"
# → [ "witness.w1.steps[1].after" -> 2
#      "witness.w1.steps[1].anchor" -> 0
#      "witness.w1.steps[1].before" -> 1
#      "witness.w1.steps[1].direction" -> "forward"
#      "witness.w1.steps[1].orientation" -> "default"
#      "witness.w1.steps[1].rule" -> 1 => 2 ]
```

The `steps*` expansion prints all fields of all steps as a key-value list.

### Rule Name Inspection

Named rules appear in the `rule_name` field. Rules stored via the `reverse`
keyword or explicit equivalence orientation also record their direction and
orientation:

```mantra
contract = 1 <=> 2;

print { 2 => 1 ?|= [ reverse contract ] };
print { witness.w1.ok };
# → 1

print { witness.w1.steps[1].rule_name };
# → "contract"

print { witness.w1.steps[1].direction };
# → "reverse"

print { witness.w1.steps[1].orientation };
# → "explicit"
```

The `reverse` keyword flips an equivalence rule to apply in the reverse
direction. The `direction` field records `"reverse"` and `orientation` records
`"explicit"` because the user explicitly chose the direction.

---

## Beam Search Witnesses

When beam search is active, the witness records the initial and effective beam
widths. The `effective_beam` field reflects the maximum beam width actually
reached during search, which may exceed the initial value if beam widening
occurs.

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 2 }
{ mantra.inference.policy = "cost" }

print { 1 => 3 ?|= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 };
# → "witness.w1"

print { witness.w1.ok };
# → 1

print { witness.w1.policy };
# → "cost"

print { witness.w1.initial_beam };
# → 1

print { witness.w1.effective_beam };
# → 2

print { witness.w1.attempts };
# → 2
```

Note: witness inference currently records a single-path rewrite trace. Even with
a wider beam, the step trace follows the winning path. The engine logs a
diagnostic when beam width exceeds 1: `"witness inference currently uses a
single-path rewrite trace"`.

---

## Equivalence Witnesses

For equivalence queries (`<=>`), the inference engine runs two directional
passes: forward (subject → target) and reverse (target → subject). Steps from
both passes are recorded sequentially in the same `steps` array.

```mantra
commute = + M N <=> + N M;
rules = [ commute ];

{ W = [ + 1 2 ] => [ + 2 1 ] ?|= rules : 1 }

print { W.ok };
# → 1

print { W.count };
# → 2  (forward + reverse steps)
```

The `attempts` field counts inference attempts across both directional passes.
The `effective_beam` takes the maximum beam width from either pass.

---

## Failed Witnesses

When a proof fails, `ok` is `0`. The `steps` array still contains the steps
attempted before failure, which helps diagnose why a proof did not complete.

```mantra
print { 1 => 3 ?|= [ 1 => 2 ] : 2 }
# → "witness.w1"

print { witness.w1.ok }
# → 0

print { witness.w1.count }
# → 1  (one step attempted: 1 → 2, but never reached target 3)
```

A failed witness still increments the global witness counter. Access its fields
normally — `ok` will be `0` and `steps` will show what was attempted.

---

## Grouping Witnesses with Assignment

When a witness is assigned to a variable, use the variable name to access the
witness data instead of the auto-generated `witness.wN`:

```mantra
ih = << + m : + n >> => << + n : + m >>;

{ W = << + m : + n >> => << + n : + m >> ?|= [ ih ] : 1 }

print { W.ok };
# → 1

print { W.steps[1].rule };
# → [ "W.steps[1].rule" -> + m : + n => + n : + m ]
```

The `+` prefix forces node creation for operators that might otherwise be
misinterpreted by the parser (`:`, `=>`, etc.).

---

## Witness Printing Utilities

The `utils.witness` package provides helper rules for formatting and printing
witness steps.

### Print Steps

`witness_print_steps` walks all steps and prints each as a formatted line:

```mantra
import utils;

commute = + M N <=> + N M;
rules = [ commute ];

{ W = [ + 1 2 ] => [ + 2 1 ] ?|= rules : 1 }

mantra.effects.display.evaluate = 1;
{ utils.witness_print_steps W }
# → step 1 | rule=commute | dir=forward | anchor=1
#    | [ + 1 + 2 ] => [ + 2 + 1 ]
```

### Tabular Render

`witness_render_steps` produces a columns table string:

```mantra
print { render columns profiles.witness_steps W }
```

This uses the `witness_steps` render profile which maps columns for STEP,
RULE, DIR, and ANCHOR fields.

### Wide Render

`witness_render_steps_wide` adds BEFORE and AFTER columns:

```mantra
print { render columns profiles.witness_steps_wide W }
```

### CSV Render

`witness_render_steps_csv` and `witness_render_steps_wide_csv` produce CSV
output for the same profiles.

---

## Runtime Configuration

Witness inference respects the same runtime settings as standard inference:

| Setting | Purpose |
|---|---|
| `mantra.inference.beam` | Initial beam width (default: 1) |
| `mantra.inference.beam_delta` | Beam widening increment |
| `mantra.inference.beam_max` | Maximum beam width |
| `mantra.inference.budget` | Congruence budget (default: -1) |
| `mantra.inference.policy` | Policy — `"cost"` or `"default"` |
| `mantra.inference.profile` | Enable search profiling |

---

## Internal Implementation

### Witness Build State

The `TWitnessBuildState` record in `inference.pas` tracks witness construction:

- `Prefix` — the witness name prefix (e.g., `"witness.w1"` or custom name)
- `StepsState` — indexed variable trie state for storing steps
- `StepCount` — current step counter
- `StoreReady` — whether the steps container was successfully initialized
- `Context` — reference to the runtime context

### Step Storage

Steps are stored as indexed variables under `{prefix}.steps[i]`. The
`AppendWitnessStep` function:
1. Ensures the next child slot exists via `EnsureIndexedVariableChild`
2. Clones the directional rule (handles equivalence rules specially)
3. Stores each field (`.rule`, `.rule_name`, `.before`, `.after`,
   `.direction`, `.orientation`, `.anchor`) as a property of the step node

For equivalence rules, `CloneDirectionalRuleForWitness` creates a new
transformation node oriented in the correct direction before storing it.

### Witness Return Value

The `?|=` node collapses to a `TStringNode` containing the witness prefix
string. This is why `print { ... ?|= ... }` outputs the witness name.
