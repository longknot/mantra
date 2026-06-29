# Inference Budget Flags

Inference budget flags control the breadth and depth of `|=` proof search.
They prevent unbounded exploration by limiting how many sub-expression
rewrites occur per step and how many candidate paths the search explores
simultaneously.

The inference operator `|=` attempts to find a sequence of rule applications
that transforms a **subject** into a **target**. It returns `1` (success) when
a valid path is found and `0` (failure) when no path exists within the given
constraints. The `?=|` witness variant does the same but additionally stores
the proof trace in a `witness.wN` variable for inspection.

## `--congruence-budget N`

Set the maximum number of sub-expression rewrites per `|=` inference step.

```bash
./bin/mantra --congruence-budget=1 program.m
```

**Default:** `-1` (unlimited)

The congruence budget limits how deeply the inference engine can rewrite
sub-expressions within a single step. A budget of `0` blocks all sub-expression
rewrites — only exact top-level matches succeed. A budget of `1` allows one
level of nesting; a budget of `2` allows two levels, and so on. A value of
`-1` (the default) removes the limit entirely.

### Example: Budget 0 blocks all sub-expression rewrites

```bash
# tests/cases/inference_congruence_budget_zero.args
--congruence-budget=0
```

```mantra
# tests/cases/inference_congruence_budget_zero.in
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
```

Output:
```
0
```

With budget `0`, the engine cannot rewrite any sub-expression at all. Even
though `( x ) <=> x` could strip the parentheses, the rewrite is blocked
because the subject `[ ( 1 ) ]` is not identical to the target `[ 1 ]` at the
top level.

### Example: Budget of 1 succeeds (one level of nesting)

```bash
# tests/cases/inference_congruence_budget_one.args
--congruence-budget=1
```

```mantra
# tests/cases/inference_congruence_budget_one.in
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
```

Output:
```
1
```

The subject `[ ( 1 ) ]` has one level of nesting. With a congruence budget of
`1`, the rule `( x ) <=> x` can strip the parentheses once, transforming
`( 1 )` to `1`. The target `[ 1 ]` is reached, so the inference succeeds
(returning `1`).

### Example: Budget of 1 fails (two levels of nesting)

```bash
# tests/cases/inference_congruence_budget_exhausted.args
--congruence-budget=1
```

```mantra
# tests/cases/inference_congruence_budget_exhausted.in
print { [ ( ( 1 ) ) ] => [ 1 ] |= [ ( x ) <=> x ] : 2 }
```

Output:
```
0
```

The subject `[ ( ( 1 ) ) ]` has two levels of nesting. With a congruence
budget of `1`, only the outer parentheses can be stripped, producing
`( 1 )`. That is not the target `[ 1 ]`, so the inference fails (returning
`0`), even though two steps of rewriting are requested with `: 2`.

### Example: Budget of 2 succeeds (two levels of nesting)

```bash
# tests/cases/inference_congruence_budget_two.args
--congruence-budget=2
```

```mantra
# tests/cases/inference_congruence_budget_two.in
print { [ ( ( 1 ) ) ] => [ 1 ] |= [ ( x ) <=> x ] : 2 }
```

Output:
```
1
```

With a congruence budget of `2`, both levels of nesting can be stripped.
`( ( 1 ) )` becomes `( 1 )` on the first step, then `1` on the second.
The target `[ 1 ]` is reached, so the inference succeeds.

## `--beam-width N`

Set the beam width for `|=` proof search.

```bash
./bin/mantra --beam-width=2 program.m
```

**Default:** `1`

Beam search explores multiple candidate paths simultaneously at each step. The
beam width controls how many of the best candidates are retained for the next
step. A beam width of `1` means only the single best candidate survives — this
is essentially a greedy search. A beam width of `2` or higher allows the
searcher to explore alternatives and potentially find a path that a greedy
approach would miss.

Values less than `1` raise an error:

```
Invalid --beam-width: <value> (expected >= 1)
```

### Example: Default beam width 1 fails (greedy search dead end)

```mantra
# tests/cases/inference_beam_width_default.in
print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

Output:
```
0
```

From `1`, there are two possible rewrites: `1 => 2` and `1 => 4`. The greedy
search (beam width 1, the default) picks the first candidate `1 => 2`, but `2`
is a dead end with no rule leading to `3`. The search fails.

### Example: Beam width 2 finds a path that greedy search misses

```bash
# tests/cases/inference_beam_width_two.args
--beam-width=2
```

```mantra
# tests/cases/inference_beam_width_two.in
print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

Output:
```
1
```

With beam width 2, both candidates (`2` and `4`) are retained after the first
step. The second step finds `4 => 3`, so the path `1 => 4 => 3` succeeds.

## Step Limit

The `: N` suffix on an inference query sets the maximum number of rewrite
steps the search can take. The default is `1` step.

```mantra
# Single-step search (default)
print { 1 => 2 |= [ 1 => 2 ] }

# Multi-step search (up to 2 steps)
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

The step limit acts as a depth bound — the search explores paths of at most
`N` rewrite applications. Increasing the step limit lets the search reach
targets further away but also increases the exploration space exponentially.

## Runtime Option Variables

The CLI flags set initial values. You can also control these from within
Mantra programs using runtime variables:

| Variable | CLI flag | Default | Description |
|---|---|---|---|
| `mantra.inference.beam` | `--beam-width` | `1` | Current beam width |
| `mantra.inference.budget` | `--congruence-budget` | `-1` (unlimited) | Current congruence budget |

### Example: Reading runtime options

```bash
# tests/cases/runtime_option_sets_mantra_inference_beam.args
--beam-width=2
```

```mantra
# tests/cases/runtime_option_sets_mantra_inference_beam.in
print { mantra.inference.beam }
```

This prints `2`, confirming that the `--beam-width` flag sets the runtime
variable.

### Example: Setting budget at runtime

```mantra
# tests/cases/inference_inline_budget_override.in
mantra.inference.budget = 0
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
```

Output:
```
0
```

Setting `mantra.inference.budget = 0` at runtime has the same effect as
`--congruence-budget=0` — all sub-expression rewrites are blocked.

### Example: Setting beam width at runtime

```mantra
# tests/cases/inference_trie_beam_override.in
mantra.inference.beam = 2
print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

Output:
```
1
```

Setting `mantra.inference.beam = 2` at runtime lets the inference succeed where
the default beam width of `1` would fail.

### Advanced: Beam widening

The inference engine supports automatic beam widening across failed attempts.
When the initial search fails, the engine increases the beam width by
`mantra.inference.beam_delta` and retries, repeating until it either succeeds
or reaches `mantra.inference.beam_max`.

| Variable | Default | Description |
|---|---|---|
| `mantra.inference.beam_delta` | `0` | Amount to increase beam width after each failed attempt |
| `mantra.inference.beam_max` | (same as initial beam) | Maximum beam width before widening stops |

When `beam_delta` is set to a positive value, `beam_max` must also be set to a
value greater than or equal to the initial beam width. If `beam_max` is missing
or too small, widening is disabled and a diagnostic message is emitted:

```
EVENT[diag] invalid mantra.inference.beam_max value (positive mantra.inference.beam_delta requires integer >= initial beam 1)
```

#### Example: Beam widening succeeds

```mantra
# tests/cases/inference_beam_widening.in
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 2 }

print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

Output:
```
1
```

The first attempt with beam width 1 fails (greedy dead end at `2`). The engine
widens to beam width 2 and retries. With beam width 2, both candidates are
retained, and the path `1 => 4 => 3` succeeds.

#### Example: Invalid beam widening configuration

```mantra
# tests/cases/inference_beam_widening_invalid.in
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }

print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

Output:
```
0
```

Because `beam_max` was not set, the widening configuration is invalid. The
engine falls back to the initial beam width of 1, which fails.

#### Example: Witness with beam widening and cost policy

```mantra
# tests/cases/inference_beam_widening_witness.in
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

Output:
```
"witness.w1"
1
"cost"
1
2
2
```

The `?=|` witness operator stores proof metadata. After widening succeeded,
`witness.w1` records that 2 attempts were made: the first with beam 1 (failed)
and the second with beam 2 (succeeded).

### `?=|` Witness Operator

The `?=|` operator is the witness variant of inference. It performs the same
proof search as `|=` but additionally stores the proof trace in a variable
named `witness.wN` (where `N` is a sequential counter starting at 1).

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
```

Output:
```
"witness.w1"
```

The witness variable provides access to the proof metadata:

| Property | Description |
|---|---|
| `witness.wN.ok` | `1` if the proof succeeded, `0` if it failed |
| `witness.wN.policy` | The policy used (`"compare"` or `"cost"`) |
| `witness.wN.initial_beam` | The starting beam width |
| `witness.wN.effective_beam` | The final beam width (after any widening) |
| `witness.wN.attempts` | Total number of search attempts |

#### Example: Nested target variable with witness

```mantra
# tests/cases/inference_witness_nested_target_variable.in
import math;
{ mantra.inference.beam = 64 }
{ mantra.inference.budget = 4 }
{ max_steps = 6 }
{ addinv_x = math.addinv ? [ M ==> x ] }
{ addinvinv_x = math.addinvinv ? [ m ==> x ] }
{ rules = [ math.negate, math.unfold, math.addzero, math.addinv, math.addlr ] }
print { addinv_x => addinvinv_x ?|= rules : max_steps }
print { $witness.w1.ok }
```

Output:
```
"witness.w1"
1
```

The `witness.w1.ok` property returns `1`, confirming the proof succeeded.

### Inline and Trie Overrides

Besides inline assignments (`mantra.inference.beam = 2`), you can also override
inference settings within rule lists (tries):

```mantra
# tests/cases/inference_trie_budget_override.in
{ mantra.inference.budget = 0 }
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
```

Output:
```
0
```

The budget override within the same scope blocks all sub-expression rewrites
for that inference query.

## Inference Policies

The inference engine uses a policy to rank and prune candidates at each step.
Set it via `mantra.inference.policy`.

| Variable | Default | Description |
|---|---|---|
| `mantra.inference.policy` | `compare` | Candidate ranking policy (`compare` or `cost`) |

### Compare Policy (default)

The `compare` policy ranks candidates by structural similarity to the target.
Candidates that more closely match the target's structure are preferred.

```mantra
# tests/cases/inference_cost_policy_compare.in
import math;
{ mantra.inference.beam = 2 }
{ mantra.inference.budget = 4 }
{ mantra.inference.policy = "compare" }

{ rules = [ math.negate, math.unfold, math.addzero, math.addlr ] }
print { math.negate => math.addinvinv ?|= rules : 5 }
print { witness.w1.ok }
```

Output:
```
"witness.w1"
0
```

With the compare policy, the search prioritizes structural similarity. If no
directly similar path exists, the proof may fail.

### Cost Policy (growth-based scoring)

The `cost` policy uses growth-based scoring to rank candidates. It scores
each candidate by how much it reduces the structural distance between the
current expression and the target. Candidates that bring the expression closer
to the target receive lower cost scores.

When the cost policy is active with profiling enabled, the event log emits
detailed statistics about candidate generation, admission, and pruning:

```
EVENT[diag] inference profile attempt=1 policy=cost beam=1 result=success generated=3 admitted=2 pruned_beam=1 pruned_visited=0 deduped=0 abandoned_success=0 forward=3 reverse=0 expanded=2 max_queue=3 max_frontier=2
```

The cost policy is useful when structural similarity alone is insufficient to
find the optimal path, as it considers the semantic growth or reduction of
expressions during rewriting.

## Profile Search

Enable profiling to emit detailed inference search statistics to the event log.

| Variable | Default | Description |
|---|---|---|
| `mantra.inference.profile` | `false` | Emit inference profile events |

When profiling is enabled, the event log emits structured summaries of each
proof-search attempt, including:

- **Attempt count** and **policy** in use
- **Beam width** at the time of the attempt
- **Result** (`success` or `failure`)
- **Candidate statistics**: generated, admitted, pruned by beam, pruned by
  visited-state dedup, local dedup, abandoned on success
- **Direction breakdown**: forward vs reverse candidates per rule
- **Queue and frontier** maximum sizes

### Profile Event Format

```
EVENT[diag] inference profile attempt=1 policy=default beam=1 result=failure generated=1 admitted=1 pruned_beam=0 pruned_visited=0 deduped=0 abandoned_success=0 forward=1 reverse=0 expanded=1 max_queue=1 max_frontier=1
EVENT[diag] inference profile rule attempt=1 policy=default beam=1 name="step" direction=forward generated=1 admitted=1 pruned_beam=0 pruned_visited=0 deduped=0 abandoned_success=0
```

Each profile event includes:
- `attempt` — which attempt number this is (with beam widening, multiple attempts occur)
- `policy` — the active policy (`default`, `compare`, or `cost`)
- `beam` — the current beam width for this attempt
- `result` — `success` or `failure`
- `generated` — total candidates generated
- `admitted` — candidates admitted to the beam
- `pruned_beam` — candidates pruned due to beam width limit
- `pruned_visited` — candidates pruned as already-visited states
- `deduped` — candidates removed by local deduplication
- `abandoned_success` — candidates abandoned because a success was found
- `forward` / `reverse` — direction breakdown (forward rules vs reverse/bidirectional)
- `expanded` — candidates actually expanded in the search
- `max_queue` — maximum queue size during the search
- `max_frontier` — maximum frontier size during the search

#### Example: Bidirectional rule direction

```bash
# tests/cases/inference_profile_rule_direction.args
--event-log
```

```mantra
# tests/cases/inference_profile_rule_direction.in
print { + 0 0 1 2 3 5 8 13 21 34 55 89 144 => 217 |= [ step ] : 50 }
print { + 0 0 1 2 3 5 8 13 21 34 55 89 144 <= 217 |= [ step ] : 50 }
```

The profile events show `direction=forward` for the forward rule and
`direction=reverse` for the reverse rule, allowing you to verify which
direction each candidate is explored in.

### Additional Inference Variables

| Variable | Default | Description |
|---|---|---|
| `mantra.inference.anchors_per_rule` | `1` | Number of anchor points per rule for matching |
| `mantra.inference.beam` | `1` | Beam width |
| `mantra.inference.beam_delta` | `0` | Beam widening increment |
| `mantra.inference.beam_max` | (same as beam) | Maximum beam width for widening |
| `mantra.inference.budget` | `-1` (unlimited) | Congruence budget |
| `mantra.inference.policy` | `compare` | Ranking policy |
| `mantra.inference.profile` | `false` | Enable profiling |

`mantra.inference.anchors_per_rule` controls how many anchor points are used
per rule during matching. Higher values allow more parallel matching but
increase memory usage.

## When to Use

| Scenario | Recommended setting |
|---|---|
| Quick single-step rewrite | Default settings (beam 1, unlimited budget) |
| Multi-step proof search | Increase step limit with `: N` |
| Search has alternatives | Set beam width ≥ 2 |
| Deeply nested rewrites needed | Set congruence budget ≥ nesting depth |
| Greedy search fails | Enable beam widening (`beam_delta` + `beam_max`) |
| Inspect proof metadata | Use `?=|` witness operator |
| Debug search behavior | Enable `mantra.inference.profile` + `--event-log` |
| Memory-constrained | Lower beam width and congruence budget |

## Internal Behavior

| Runtime option | Default | CLI flag |
|---|---|---|
| `InferenceRewriteMaxSteps` | `1` | — |
| `InferenceCongruenceBudget` | `-1` | `--congruence-budget` |
| `InferenceBeamWidth` | `1` | `--beam-width` |

The CLI flags set initial values for the global runtime options. Setting
`mantra.inference.budget` or `mantra.inference.beam` at runtime overrides
the CLI defaults for subsequent inference queries in the same session.
