# Inference

Inference checks whether a set of rewrite rules can prove or reach a target
relation from a source expression. It is bounded proof search over tree
rewrites -- the runtime explores candidate rewrite paths and returns a boolean
result (or a materialized witness trace).

```mantra
subject => target |= rules
```

Returns `1` (success) or `0` (failure) as an integer.

Use inference when the question is *whether* a source relation follows from
a ruleset, rather than *what* a subject rewrites to under selection or
transform.

## Syntax and Operators

### Boolean Inference (`|=`)

The `|=` operator performs a proof search and returns a boolean-as-integer:

```mantra
print { + x - x => 0 |= [ + m - m <=> 0 ] }
```

Expected `OUTPUT`:

```text
1
```

The query asks: can `+ x - x` be rewritten to `0` using the rule
`+ m - m <=> 0`? The answer is yes.

### Witness Inference (`?|=`)

The `?|=` operator is identical to `|=` but additionally materializes a
witness trace -- a step-by-step record of the rewrite path taken:

```mantra
print { 1 => 2 ?|= [ 1 => 2 ] }
```

Expected `OUTPUT`:

```text
"witness.w1"
```

The witness is stored in the context under a generated prefix (`witness.w1`,
`witness.w2`, etc.) and can be inspected for detailed step information.
See [Witnesses](inference/witnesses.md) for the full witness data model.

### Substitution Inference

Inference supports substitution-pattern rules (`==>` and `<==>`). These rules
operate at the substitution level, matching and replacing symbols directly:

```mantra
print { x => y |= [ x ==> y ] : 1 }
```

Expected `OUTPUT`:

```text
1
```

Substitution rules require an explicit step bound (`: n`) to limit search
depth. Without a bound, they use the default `InferenceRewriteMaxSteps` of
`1`. When strict substitution is disabled (`mantra.substitution.strict = 0`),
substitution rules behave more permissively.

### Query Shapes

The query (left of `|=`) can be directional or bidirectional:

- `subject => target` -- directional: prove subject rewrites to target
- `subject <=> target` -- equivalence: prove both directions

For equivalence queries, the engine runs two directional searches. Both
directions must succeed for the result to be `1`. If only a forward rule
exists, the equivalence fails:

```mantra
print { 1 <=> 2 |= [ 1 => 2 ] }
```

Expected `OUTPUT`:

```text
0
```

The forward direction (`1 => 2`) succeeds, but the reverse (`2 => 1`) has
no matching rule, so the equivalence query returns `0`.

### Oriented Equivalence Rules

Equivalence rules (`<=>`) can be applied with explicit orientation using
`forward` or `reverse` keywords:

```mantra
contract = 1 <=> 2;

print { 1 => 2 |= [ forward contract ] };
print { 2 => 1 |= [ forward contract ] };
print { 1 => 2 |= [ reverse contract ] };
print { 2 => 1 |= [ reverse contract ] };
```

Expected `OUTPUT`:

```text
1
0
0
1
```

without an orientation prefix, an equivalence rule tries both directions
automatically. With `forward` or `reverse`, it is locked to that direction
only. The orientation also appears in witness step records as `"default"` or
`"explicit"`.

## How It Works

The inference engine follows a structured search lifecycle:

1. **Evaluate operands** -- The query (left of `|=`) and ruleset (right of
   `|=`) are evaluated. If either is a variable, it is resolved from the
   current context. Rule templates are never evaluated themselves; they
   remain structural patterns.

2. **Extract query** -- The query must have a transformation shape:
   `subject => target` (directional) or `subject <=> target` (equivalence).
   The subject and target subtrees are extracted and normalized.

3. **Apply search configuration** -- The engine reads inference settings from
   the context (beam width, congruence budget, policy, etc.) and applies
   CLI-level defaults. See [Configuration](#configuration) below.

4. **Run directional search** -- The engine calls `RunDirectionalInference`
   to search for a rewrite path from subject to target. The search explores
   a frontier of candidate rewrites rather than committing to the first
   match. Each candidate represents a valid local rewrite at a specific
   anchor point in the subject tree.

5. **Check equivalence (if needed)** -- If the query uses `<=>`, the engine
   also runs the reverse search (target → subject). Both directions must
   succeed for an equivalence query to return `1`.

6. **Collapse and return** -- The inference node is replaced by an integer
   literal: `1` for success, `0` for failure. Query and ruleset subtrees
   are deleted as part of evaluation.

### Beam Search

The inference engine uses beam search to manage the explosion of candidate
rewrites. At each step, multiple rules may match the subject tree, producing
many possible next states. The beam width limits how many candidates are
retained at each step:

- **Default beam width** is `1` (keep only the best candidate at each step)
- With `mantra.inference.beam`, you can widen the beam to explore more paths

```mantra
print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

With the default beam width of `1`, this returns `0` -- the engine keeps only
the first candidate (`1 => 2`) and misses the path through `4`. With beam
width `2`, it retains both candidates and finds the path:

```mantra
mantra.inference.beam = 2
print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

### Congruence Budget

When matching subexpressions (the default), inference applies rules at
multiple anchor points within the subject tree. The congruence budget limits
how many subexpression rewrites are considered per step:

- Budget `0`: no subexpression rewrites allowed
- Budget `1`: one subexpression rewrite per step
- Budget `-1`: unlimited (default)

```mantra
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
```

Expected `OUTPUT`:

```text
1
```

The rule `( x ) <=> x` matches the inner subexpression `( 1 )` and rewrites
it to `1`. With congruence budget `0`, this fails:

```mantra
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
```

With `mantra.inference.budget = 0`:

Expected `OUTPUT`:

```text
0
```

A budget of `-1` (the default) means unlimited subexpression rewrites. With
budget `0`, only the root expression is matched.

### Root-Only Matching with `^`

The `^` meta flag disables subexpression matching, restricting all matches
to the full root expression only:

```mantra
print { [ ( 1 ) ] => [ 1 ] ^|= [ ( x ) <=> x ] }
```

Expected `OUTPUT`:

```text
0
```

The `^` flag prevents the engine from descending into subexpressions, so the
rule `( x ) <=> x` cannot match `( 1 )` inside `[ ( 1 ) ]` -- it only tries
to match the root `[ ( 1 ) ]` which doesn't fit the pattern.

### Anchors Per Rule

By default, the engine tries one anchor position per rule. The
`mantra.inference.anchors_per_rule` setting lets you try multiple anchor
positions, which can help find rewrite paths in complex structures:

```mantra
{ mantra.inference.budget = 10 }
{ mantra.inference.anchors_per_rule = 3 }

print { [ + 1 2 3 4 ] => [ + 1 2 4 3 ] |= [ + M N <=> + N M ] : 1 }
```

Expected `OUTPUT`:

```text
1
```

With `anchors_per_rule = 3`, the commute rule is tried at multiple positions
within the `+` expression, allowing it to swap just the tail elements `3` and
`4` while leaving the prefix `+ 1 2` intact.

## Bounded Search

Inference accepts an optional step bound via the repeat operator `:`:

```mantra
subject => target |= rules : n
```

The bound `n` sets `InferenceRewriteMaxSteps` temporarily for that query. The
default is `1` -- a single rewrite step. Without an explicit bound, inference
uses whatever value `InferenceRewriteMaxSteps` currently holds.

### One-Step Inference (default)

With no explicit bound, inference defaults to `InferenceRewriteMaxSteps = 1`,
meaning at most one rewrite step is allowed:

```mantra
print { 1 => 2 |= [ 1 => 2 ] }
```

Expected `OUTPUT`:

```text
1
```

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 1 }
```

Expected `OUTPUT`:

```text
0
```

One step can reach `2` from `1`, but not `3` from `1`. Two steps are needed.

### Multi-Step Inference

Increasing the step bound lets inference chain multiple rewrites:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

The engine first rewrites `1` to `2`, then `2` to `3`, proving the path
exists within the step limit.

### Zero-Step Structural Equality

With zero steps (`: 0`), inference performs a strict structural equality check
between subject and target -- no rewrites are attempted:

```mantra
print { 1 => 1 |= [ 1 => 2 ] : 0 }
```

Expected `OUTPUT`:

```text
1
```

```mantra
print { 1 => 2 |= [ 1 => 2 ] : 0 }
```

Expected `OUTPUT`:

```text
0
```

Zero steps means "are the subject and target already structurally identical?"
The ruleset is irrelevant in this mode.

### Variable Rulesets

The ruleset side of `|=` can be a variable referencing a ruleset:

```mantra
rules = [ 1 => 2, 2 => 3 ];
print { 1 => 3 |= rules : 2 }
```

Expected `OUTPUT`:

```text
1
```

Variables in the query position (left of `|=`) are also resolved from the
context before the search begins.

## Configuration

The inference engine accepts several configuration variables that control
search behavior. These can be set in source code using evaluation scopes or
passed via CLI flags.

### Source Code Settings

Set these inside `{ ... }` evaluation scopes:

```mantra
{ mantra.inference.beam = 2 }
{ mantra.inference.budget = 5 }
{ mantra.inference.policy = "cost" }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 4 }
{ mantra.inference.profile = true }
{ mantra.inference.anchors_per_rule = 2 }
```

### CLI Flags

The same settings can be passed on the command line:

```bash
mantra --beam-width 2 --congruence-budget 5 program.m
```

### Settings Reference

| Setting | Type | Default | Description |
|---|---|---|---|
| `mantra.inference.beam` | int >= 1 | 1 | Beam width: how many candidates to keep per step |
| `mantra.inference.budget` | int >= -1 | -1 | Congruence budget: subexpression rewrites per step (-1 = unlimited) |
| `mantra.inference.policy` | string | "default" | Candidate policy: "default" or "cost" |
| `mantra.inference.beam_delta` | int >= 0 | 0 | Auto-widening increment (requires `beam_max`) |
| `mantra.inference.beam_max` | int >= beam | beam | Upper bound for auto-widening |
| `mantra.inference.profile` | boolean | false | Emit diagnostic search statistics |
| `mantra.inference.anchors_per_rule` | int >= 1 | 1 | Anchor positions tried per rule per state |

### Cost Policy

The default policy keeps the first `beam` candidates admitted. The `"cost"`
policy scores each candidate by the size of the rewrite result (tree node
count) and prefers smaller rewrites -- those with less growth. This helps
avoid paths that expand the expression unnecessarily:

```mantra
{ mantra.inference.beam = 1 }

print { 1 => 3 |= [ 1 => [ 4, 5 ], 1 => 2, 2 => 3 ] : 2 };

{ mantra.inference.policy = "cost" }

print { 1 => 3 |= [ 1 => [ 4, 5 ], 1 => 2, 2 => 3 ] : 2 };
```

Expected `OUTPUT`:

```text
0
1
```

With the default policy and beam `1`, the engine admits the first matching
candidate (`1 => [ 4, 5 ]`) and misses the shorter path through `2`. The
cost policy scores candidates and admits the smaller rewrite (`1 => 2` with
score `0` growth over `1 => [ 4, 5 ]` with score `4` growth), finding the
solution.

### Beam Widening

When `beam_delta` is positive and `beam_max` is set to a value >= the initial
beam, the engine will automatically widen the beam after a failed attempt,
repeating until success or until the beam reaches `beam_max`:

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 2 }

print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 };
```

Expected `OUTPUT`:

```text
1
```

First attempt with beam `1` fails (keeps only `1 => 2`). Second attempt with
beam `2` succeeds by keeping both candidates and finding the path through `4`.

If `beam_delta` is positive but `beam_max` is not set (or is below the
initial beam), a diagnostic warning is emitted and widening is disabled.

### Profile Search

Setting `mantra.inference.profile = true` enables detailed diagnostic output
showing candidate generation, admission, pruning, and per-rule statistics.
This is useful for tuning inference configuration:

```mantra
{ mantra.inference.profile = true }
{ mantra.inference.beam = 1 }

expand = 1 => [ 4, 5 ];
toward = 1 => 2;
finish = 2 => 3;

print { 1 => 3 |= [ expand, toward, finish ] : 2 };
```

Expected `OUTPUT` includes diagnostic lines like:

```text
EVENT[diag] inference profile attempt=1 policy=default beam=1 result=failure generated=2 admitted=1 pruned_beam=1 pruned_visited=0 deduped=0 abandoned_success=0 forward=2 reverse=0 expanded=2 max_queue=2 max_frontier=1
EVENT[diag] inference profile rule attempt=1 policy=default beam=1 name="expand" direction=forward generated=1 admitted=1 pruned_beam=0 pruned_visited=0 deduped=0 abandoned_success=0
```

The profile output shows per-attempt statistics (candidates generated,
admitted, pruned by beam vs visited set, deduplication counts) and per-rule
breakdowns. This helps identify which rules are being explored and why the
search succeeds or fails.

## Named Rules and Witness Traces

When rules are declared as named variables, inference preserves their names
in the trace and witness output:

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

Rules nested inside grouped rulesets also retain their individual names
rather than being labeled as the group name.

## Witness Data Model

The witness inference operator (`?|=`) stores a structured trace in the
context. The returned string is the witness prefix (e.g., `witness.w1`).
The witness contains:

- `witness.wN.ok` -- `1` if proof succeeded, `0` otherwise
- `witness.wN.count` -- number of rewrite steps in the trace
- `witness.wN.policy` -- policy used (`"default"` or `"cost"`)
- `witness.wN.initial_beam` -- starting beam width
- `witness.wN.effective_beam` -- beam width that found the solution
- `witness.wN.attempts` -- number of search attempts (with widening)
- `witness.wN.steps[N]` -- individual step records

Each step record contains:

- `.before` -- tree state before the rewrite
- `.after` -- tree state after the rewrite
- `.rule` -- the directional rule applied
- `.rule_name` -- name of the rule (if named)
- `.direction` -- `"forward"` or `"reverse"`
- `.orientation` -- `"default"` (auto) or `"explicit"` (manual `forward`/`reverse`)
- `.anchor` -- ordinal position where the rule matched

When inference fails, the witness prefix is still returned, but `ok` is `0`
and `count` is `0` -- no step records are materialized.

For more details on inspecting witnesses, see [Witnesses](inference/witnesses.md).

## Practical Examples

### Proving Algebraic Properties

Inference is designed for structural proof search. Here's a simple
cancellation proof:

```mantra
print { + x - x => 0 |= [ + m - m <=> 0 ] }
```

The rule `+ m - m <=> 0` matches the structure `+ x - x` and rewrites it
to `0`, proving the cancellation property holds for this instance.

### Multi-Rule Chaining

Proving that `1` rewrites to `3` using two chained rules:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

Two steps are needed: first `1 => 2`, then `2 => 3`. With only one step
(`: 1`), the proof fails.

### Equivalence Requires Both Directions

An equivalence query requires rules supporting both directions:

```mantra
print { 1 <=> 3 |= [ 1 => 2, 2 => 3, 3 => 4, 4 => 1 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

The forward direction (`1 => 3`) uses rules `1 => 2` and `2 => 3`. The
reverse direction (`3 => 1`) uses rules `3 => 4` and `4 => 1`. Both
succeed within the step limit, so the equivalence holds.
