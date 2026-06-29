# Inference Operator

The inference operator `|=` performs a bounded proof search: it asks whether a
target expression can be reached from a subject expression by applying a set of
rewrite rules. It returns `1` (success) or `0` (failure).

```mantra
print { + x - x => 0 |= [ + m - m <=> 0 ] }
```

Expected `OUTPUT`:

```text
1
```

This query asks: "Can `+ x - x` be rewritten to `0` using the rule `+ m - m <=> 0`?"
The answer is yes -- the rule matches and rewrites the expression in one step.

For witness-oriented inference that records the rewrite trace, see
[witnesses](./witnesses.md). For bounding search depth with the `: n` modifier,
see [bounded search](./bounded-search.md).

## Syntax

```
subject => target |= rules              (directional: implies)
subject <=> target |= rules             (bidirectional: equivalence)
subject => target |= rules : n          (bounded step limit)
```

The left side of `|=` is a **query** expressing the relationship to prove.
The right side is a **ruleset** -- an array of transformation rules.

| Component | Description |
|---|---|
| `subject` | Starting expression (source term) |
| `target` | Expression to reach (goal term) |
| `rules` | Array of rules `[ rule1, rule2, ... ]` |
| `n` | Maximum rewrite steps (via `: n` repeat modifier) |

### Query Operators

The query can use different operators to express the proof relationship:

- `=>` (**directional/implies**) -- only forward rule applications from subject toward target
- `<=>` (**bidirectional/equivalence**) -- proves both directions independently; both must succeed
- `:=>` (**inline transform**) -- inline transformation rules in query
- `==>>` (**substitution transform**) -- substitution-based transformation rules in query

### Root-Only Matching with `^`

Prefix the `|=` with `^` to restrict matching to the root node only (no subexpression
matching). Without `^`, rules can match any subexpression within the subject tree.

```mantra
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }    # 1 -- matches subexpression (1)
print { [ ( 1 ) ] => [ 1 ] ^|= [ ( x ) <=> x ] }   # 0 -- root [ ( 1 ) ] does not match (x)
```

## Evaluation Lifecycle

The inference operator is implemented by `TInferenceNode.Evaluate` (in `nodes.pas`)
which delegates to `RunDirectionalInference` (in `inference.pas`). The evaluation
follows these phases:

1. **Parse query** -- `TryExtractInferenceQuery` decomposes the query into
   `SubjectIndex`, `TargetIndex`, and determines if it is an equivalence query
   (`<=>`) or directional (`=>`). Both `=>` and `<=>` are recognized; inline
   transforms (`:=>`) and substitution transforms (`==>>`) are also supported.

2. **Normalize operands** -- `NormalizeInferenceQueryOperands` normalizes the
   subject and target trees, resolving nested transforms.

3. **Apply configuration** -- `ApplyDefaultInferenceOverrides` reads runtime
   settings (`mantra.inference.*` variables) for beam width, congruence budget,
   cost policy, beam widening delta/max, and profiling flags.

4. **Resolve operands** -- `ResolveInferenceOperands` resolves variable references
   in both the query and ruleset positions.

5. **Execute search** -- `RunDirectionalInference` performs the proof search:
   - If `step_limit = 0`, it checks structural equality (`NodesStrictEqual`).
   - If `step_limit = 1`, it calls `CanRewriteOneStep`.
   - If `step_limit > 1`, it calls `CanRewriteWithinSteps` (beam search).
   - If the query is equivalence (`<=>`), a **second** directional search runs
     from target back to subject.

6. **Replace node** -- The inference node deletes its children, reclassifies
   itself as `OBJ_INTEGER`, and emits `1` or `0`.

The `StepLimit` defaults to `1` (controlled by `InferenceRewriteMaxSteps`).
Use `: n` to increase the bound -- e.g., `|=: 2` allows up to 2 rewrite steps.

## Step Limit Semantics

The step limit controls how many rewrite steps the inference engine is allowed to take.
It is set by the `: n` modifier on the ruleset:

```mantra
subject => target |= rules : n
```

| Step Limit | Behavior |
|---|---|
| `: 0` | Structural equality check -- succeeds only if subject and target are already identical |
| `: 1` (default) | Single-step rewrite -- applies at most one rule application |
| `: n` (n > 1) | Multi-step beam search -- explores up to `n` rewrite steps |

### Zero-Step Equality

When the step limit is 0, no rules are applied. The inference simply checks if the
subject and target are structurally identical:

```mantra
print { 1 => 1 |= [ 1 => 2 ] : 0 }   # 1 -- subject equals target
print { 1 => 2 |= [ 1 => 2 ] : 0 }   # 0 -- subject does not equal target
```

### Single-Step Rewrite

With the default step limit of 1, the inference engine tries to reach the target
by applying exactly one rule:

```mantra
print { + x - x => 0 |= [ + m - m <=> 0 ] }   # 1 -- one rule application succeeds
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] }         # 0 -- requires two steps, not one
```

### Multi-Step Search

When `n > 1`, the inference engine performs a beam search, exploring multiple
rewrite paths up to `n` steps deep:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }   # 1 -- 1 -> 2 -> 3 in two steps
```

## Query Types

### Directional (Implies)

A directional query `A => B |= rules` asks: "Can `A` be rewritten to `B` using
the given rules?" Only forward rule applications are considered.

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

This succeeds in two steps: `1` -> `2` -> `3`.

### Equivalence

An equivalence query `A <=> B |= rules` asks: "Can `A` and `B` reach each other
via the given rules?" The system proves **both directions** independently.
Both must succeed for the result to be `1`.

```mantra
print { 1 <=> 2 |= [ 1 => 2 ] }
```

Expected `OUTPUT`:

```text
0
```

This fails because while `1` can reach `2` (forward direction succeeds), `2`
cannot reach `1` (reverse direction fails) -- the rule `1 => 2` is directional,
not bidirectional.

For equivalence to succeed, rules must support both directions. Either use
bidirectional rules (`<=>`) in the ruleset, or ensure directional rules can
reach both ways:

```mantra
print { 1 <=> 3 |= [ 1 => 2, 2 => 3, 3 => 4, 4 => 1 ] : 2 }
```

Expected `OUTPUT`:

```text
1
```

Here, `1` reaches `3` via `1 -> 2 -> 3`, and `3` reaches `1` via `3 -> 4 -> 1`.

### Equivalence Rules

Rules declared with `<=>` are bidirectional and can fire in either direction:

```mantra
print { + x - x => 0 |= [ + m - m <=> 0 ] }
```

Expected `OUTPUT`:

```text
1
```

The rule `+ m - m <=> 0` can match `+ x - x` and rewrite it to `0` in one step.

## Variable Resolution

Both the query and the ruleset support variable references. Variables are resolved
before the search begins.

### Ruleset as Variable

The ruleset can be stored in a variable:

```mantra
rules = [ 1 => 2, 2 => 3 ];
print { 1 => 3 |= rules : 2 }    # 1
```

### Named Rules

Rules can be stored in named variables and referenced by name in a ruleset array:

```mantra
repeat_seq = 1 => 2;
ih = 2 => 3;
rules = [ repeat_seq, ih ];

print { 1 => 3 |= rules : 2 }    # 1
```

When used with witness inference (`?|=`), the rule names are preserved in the
witness trace, making it easier to identify which rule was applied at each step.

### Query Operand Variables

Variables in the query subject and target positions are resolved before the search:

```mantra
ih_lhs = 1;
ih_rhs = 2;
ih = ih_lhs => ih_rhs;

print { 1 => 2 |= [ ih ] : 1 }    # 1
```

## Configuration

The inference engine supports runtime configuration through `mantra.inference.*`
variables. These can be set inline in the program or via CLI flags.

### Beam Width

`mantra.inference.beam` controls how many candidate states the beam search
explores at each step. The default is `1` (greedy search).

```mantra
mantra.inference.beam = 2
print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] : 2 }    # 1 -- wider beam finds the path
```

With beam width 1, the search might follow `1 -> 2` and miss `1 -> 4 -> 3`.
With beam width 2, both candidates are explored.

### Congruence Budget

`mantra.inference.budget` controls the congruence closure budget. A value of
`-1` (default) means unlimited. Setting it to `0` disables subexpression matching,
effectively requiring root-only matches:

```mantra
mantra.inference.budget = 0
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }    # 0 -- subexpression match blocked
```

### Cost Policy

`mantra.inference.policy = "cost"` enables cost-based selection instead of the
default selection strategy. With cost policy, candidates are prioritized by
rewrite cost rather than insertion order.

```mantra
mantra.inference.policy = "cost"
print { ... |= [ ... ] : n }
```

### Beam Widening

When inference fails, you can configure automatic beam widening by setting:

- `mantra.inference.beam` -- initial beam width
- `mantra.inference.beam_delta` -- amount to increase beam width after each failed attempt
- `mantra.inference.beam_max` -- maximum beam width before giving up

```mantra
mantra.inference.beam = 1
mantra.inference.beam_delta = 1
mantra.inference.beam_max = 2
print { ... |= [ ... ] : n }    # retries with beam=2 if beam=1 fails
```

If the initial beam width fails, the engine retries with `beam + delta`, up to `beam_max`.

### Profile Search

`mantra.inference.profile = true` enables detailed search profiling. When enabled,
the engine logs diagnostic events with statistics about candidates generated,
admitted, pruned, and expanded:

```
EVENT[diag] inference profile attempt=1 policy=default beam=1 result=failure generated=1 admitted=1 pruned_beam=0 pruned_visited=0 deduped=0 abandoned_success=0 forward=1 reverse=0 expanded=1 max_queue=1 max_frontier=1
```

## Substitution Transforms

The inference operator supports substitution transforms (`==>>`) in the query:

```mantra
mantra.inference.beam = 2
print { ( + x - x <=> 0 ) => ( + x + ( + - x ) - ( + - x ) <=> + x + 0 ) |= [ x ==>> ( -x ), { U -- <=> V -- } => { + x all U <=> + x all V } ] : 2 }
```

Substitution transforms (`==>>` and `<==>`) perform syntactic substitution rather
than structural matching. They are useful when you need to replace a specific
subterm with another expression.

## Return Value

The inference operator always replaces itself with an integer node:
- `1` when the proof succeeds (target is reachable from subject)
- `0` when the proof fails (target is not reachable within the step limit)

The node deletes its children (query and ruleset) before reclassifying, so the
inference expression cannot be inspected after evaluation -- only the truth value
remains.

## See Also

- [Witnesses](./witnesses.md) -- Witness-oriented inference with `?|=` that records the rewrite trace
- [Bounded Search](./bounded-search.md) -- Controlling search depth with `: n` and CLI flags
