# Selection and Witness Forms

Selection, inference, and witness queries form Mantra's proof-oriented
programming layer. They support structural pattern matching, rule-based
rewriting, bounded proof search, and traceable inference pipelines.

## Quick Reference

| Operator | Form | Purpose |
|---|---|---|
| `?` | `subject ? rules` | Single-step selection rewrite |
| `:=?` | `subject :=? rules` | Inline selection (same as `?`) |
| `??` | `lhs ?? fallback` | Fallback: try LHS, use RHS if no progress |
| `\|=` | `query \|=` rules | Inference: check if subject implies target |
| `?|=` | `query ?|=` rules | Witness inference: same as `\|=` plus trace |
| `$` | `$?` | Iterative state-selection mode |
| `^` | `^?` | Full-match mode (no subexpression matching) |

## Related Pages

- [Witness Output](selection-witness-forms/witness-output.md)
- [Proof-Oriented Data](selection-witness-forms/proof-oriented-data.md)
- [Fixpoint Repeat](../transformations/fixpoint-repeat.md)

---

## Selection (`?`)

Selection applies transformation rules to a subject expression, performing a
single structural pattern-match and rewrite.

### Syntax

```mantra
subject ? rules
```

- **subject** — the expression tree to rewrite (LHS)
- **rules** — one or more transformation rules in a container (RHS)

Rules use the transform operator `=>`:

```mantra
[ 1 2 ] ? [ [ x y ] => [ y x ] ]
# → [ 2 1 ]
```

Lowercase symbols (e.g. `x`, `y`) bind to matched nodes and appear in the
replacement. `--` matches any remaining tail sequence.

### Matching Modes

By default, selection searches for the first matching subexpression
(depth-first). Use `^` to require a full-root match:

```mantra
[ 1 [ 2 ] 3 ] ? [ [ x ] => 0 ]      # rewrites inner [ 2 ] → 0
[ 1 [ 2 ] 3 ] ? ^[ [ x ] => 0 ]      # no match (root is not [ x ])
```

Without `^`, the matcher can rewrite inner nodes. With `^`, it requires the
entire current subject to match the pattern at the root level.

### Evaluation Lifecycle

1. Evaluate the LHS (subject) subtree
2. Resolve the RHS if it is a variable (rules can be stored in variables)
3. Call `RewriteOneByRules`: the matcher finds the first applicable rule
4. On success, the selection node is replaced with the rewritten LHS
5. On failure, the selection node collapses to the original LHS
6. The RHS (rules) is deleted after the attempt

### Inline Selection (`:=?`)

`:=?` behaves identically to `?`. The `TInlineSelectionNode` class inherits
directly from `TSelectionNode` with no override. It exists for source-form
distinction but shares the same rewrite logic.

### Iterative State Selection (`$`)

The `$` meta flag enables iterative rewriting within a repeat expansion. When
combined with `: n` or `: ...`, selection repeats until no rule matches or the
step limit is reached:

```mantra
~ { [ 1 2 3 ] $? [ [ x -- ] [ y -- ] =>> all $match ] : 1 }
```

In state mode, expansion uses `ExpandStateSelection`:
- Clone the source once
- Iteratively find selection and call `Transform` until stall
- Finalize with `Complete` + operator propagation
- Clean up selection nodes after the repeat

The `$` mode is useful for progressive transformations where you want to
accumulate changes across multiple steps.

---

## Fallback (`??`)

The fallback operator tries the LHS and switches to the RHS only if the LHS
makes no progress — i.e., no selection, inference, or other rewrite occurred.

```mantra
lhs ?? rhs
```

### How It Works

1. Take a progress snapshot of the runtime context
2. Evaluate the LHS
3. Check if any progress was made since the snapshot
4. If **progress was made**: discard RHS, return LHS
5. If **no progress**: discard LHS, evaluate and return RHS

This is the primary conditional mechanism in Mantra — it provides try/fallback
semantics without explicit boolean predicates.

---

## Rule Templates

Rules are structural patterns, not executable code. Important behaviors:

- **Rule templates are not evaluated prematurely**. The RHS of a selection
  expression stays as a pattern until the matcher uses it
- When a variable holds rules, substitution stores the cloned tree but does
  not recursively evaluate it — this prevents collapsing rules before use
- **Rule order matters**: rules are tried sequentially; the first applicable
  rule wins
- **Guards** can be attached to rules via `~` compute expressions. A guard
  that returns `0` prevents the rule from applying. Use `--no-guards` CLI
  flag to disable guard enforcement

```mantra
{ [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
# Guard checks: is x < y? Only applies if true.
```

---

## Selection Strategies

When multiple rules match, the selection strategy determines which rule to
apply. Available strategies:

| Strategy | Description |
|---|---|
| `first` | Apply the first matching rule (default) |
| `random` | Apply a random matching rule |
| `shrink` | Prefer rules that match smaller subtrees |
| `first-rule` | Always try rules in declaration order |
| `random-rule` | Randomize rule order each step |

Configure via `selector` keyword or CLI flags.

---

## Inference (`|=`)

Inference checks whether a subject can be transformed into a target using
a given set of rules. It returns `1` (success) or `0` (failure).

### Syntax

```mantra
subject => target |= rules           # implies (one direction)
subject <=> target |= rules          # equivalence (both directions)
subject => target |= rules : n       # bounded: allow up to n rewrite steps
```

### How It Works

1. Parse the query to extract subject, target, and direction
2. Apply rules to transform the subject toward the target
3. For equivalence (`<=>`), verify both forward and reverse directions
4. Return `1` if the target is reached, `0` otherwise

```mantra
print { [ ( 1 ) ] => [ 1 ] |= [ ( x ) <=> x ] }
# → 1  (parentheses can be removed by the rule)

print { 1 <=> 2 |= [ 1 => 2 ] }
# → 0  (only forward rule; reverse direction fails)

print { 1 <=> 3 |= [ 1 => 2, 2 => 3, 3 => 4, 4 => 1 ] : 2 }
# → 1  (bounded to 2 steps; chain 1→2→3 works)
```

### Bounded Search

Use `: n` after the rules to limit the number of rewrite steps:

```mantra
print { 1 => 1 |= [ 1 => 2 ] : 0 }
# → 1  (zero steps: subject already equals target)
```

With `: 0`, the system checks if subject equals target without applying any
rules. Larger bounds allow longer proof chains.

### Congruence Budget

The congruence budget controls how deeply the inference engine explores
structurally similar (congruent) subexpressions. Configure via:

- `{ mantra.inference.congruence = n }` in source
- CLI flags for per-run overrides

A budget of `0` disables congruence checking; `-1` (default) uses the
internal default. Exceeding the budget returns `0`.

### Beam Search

Beam search allows the inference engine to explore multiple proof paths
simultaneously. Configure via:

- `mantra.inference.beam` — initial beam width (default: 1)
- `mantra.inference.beam_delta` — how much to widen on backtracking
- `mantra.inference.beam_max` — maximum beam width

```mantra
{ mantra.inference.beam = 1 }
{ mantra.inference.beam_delta = 1 }
{ mantra.inference.beam_max = 2 }

print { 1 => 3 |= [ 1 => 2, 1 => 4, 4 => 3 ] }
```

When beam width is 1, the engine uses single-path search. Wider beams allow
exploring parallel candidates before pruning.

### Cost Policy

Enable cost-based rule selection with `{ mantra.inference.policy = "cost" }`.
Cost policy tracks rule application costs and prefers lower-cost paths.

---

## Witness Forms (`?|=`)

Witness forms extend inference with observable traces. They behave like
`\|=` but additionally populate the `witness` namespace with step-by-step
evidence of how the proof was constructed.

### Syntax

```mantra
subject => target ?|= rules        # witness inference (one direction)
subject <=> target ?|= rules       # witness equivalence (both directions)
```

### How It Works

1. Parse the query (identical to `\|=`)
2. Run `RunDirectionalInference` with an active inference context
3. Each rewrite step is recorded: rule applied, LHS, result
4. Results are stored under `witness.wN` (where N = query counter)
5. Return `1` (success) or `0` (failure) — same as `\|=`

```mantra
ih = << + m : + n >> => << + n : + m >>;

print { << + m : + n >> => << + n : + m >> ?|= [ ih ] : 1 };
print { witness.w1.steps[1].rule };
# → "witness.w1"
# → [ "witness.w1.steps[1].rule" -> + m : + n => + n : + m ]
```

The witness name `w1` is auto-assigned. Subsequent witness queries increment
the counter (`w2`, `w3`, ...). Use `?|=` with an explicit name to control
labeling:

```mantra
{ 1 => 2 ?|= [ 1 => 2 ] }
# Creates witness.w1

{ 3 => 4 ?|= [ 3 => 4 ] }
# Creates witness.w2
```

### Witness Data Structure

Each witness entry contains:
- `steps` — array of individual rewrite steps
- `steps[i].rule` — the rule applied at step i
- `ok` — `1` if proof succeeded, `0` if it failed
- `policy` — inference policy used (e.g., `"cost"`)
- `initial_beam` — starting beam width
- `effective_beam` — actual beam width reached during search

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
# → "witness.w1"
# → 1
# → "cost"
# → 1
# → 2
```

### Grouping with Witnesses

When the subject or target involves grouping operators (like `:`, `=>`),
the inference engine must distinguish them from query operators. Prefix
with `+` to force node creation:

```mantra
ih = << + m : + n >> => << + n : + m >>;
print { << + m : + n >> => << + n : + m >> ?|= [ ih ] : 1 };
```

Without the `+` prefix, the parser might misinterpret `:` or `=>` inside
the container as selection/inference operators rather than data.

### Transparent Inference Witnesses

When a witness succeeds, you can inspect intermediate steps. The engine
stores the full rewrite trace including which rule matched and the
intermediate expression state:

```mantra
print { witness.w1.steps[1].rule };
# → [ "witness.w1.steps[1].rule" -> + m : + n => + n : + m ]
```

This supports debugging and verification of proof paths.
