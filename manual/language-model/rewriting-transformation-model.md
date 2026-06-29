---
title: Rewriting and Transformation Model
parent: Language Model
---

# Rewriting and Transformation Model

The rewriting and transformation model defines how Mantra programs evolve from one form to another. At its core, a Mantra program is a **tree of expressions** that the evaluator transforms step by step through evaluation, expansion, and rewriting.

The three operations — **Evaluate**, **Expand**, and **Transform** — form the lifecycle of every node. Together, they implement a term-rewriting system where patterns match, variables bind, and rules rewrite structure until a fixed point is reached.

## The Three Operations

### Evaluate

The `Evaluate` operation computes the value of an expression. It resolves variables, applies arithmetic, performs pattern matching, and reduces composite nodes to their results. When `Evaluate` is called on a node, the node attempts to produce a concrete value by processing its children and applying its own logic.

For example, evaluating `2 + 3` produces `5`. Evaluating a variable `$x` resolves it to whatever tree the runtime context bound to `x`.

### Expand

The `Expand` operation decomposes or iterates over a structure. It is the mechanism behind repetition, recursion, and collection traversal. When a node expands, it generates new sibling or child nodes representing individual elements or iterations.

For instance, `range(1, 5)` expands to `1 2 3 4` — four sibling integer nodes. A recursive node `...` expands by cloning its pattern and descending into child trees.

### Transform

The `Transform` operation applies structural changes to a tree. It is used by selection nodes (`?`) to rewrite matched patterns according to transformation rules (`=>`). Unlike evaluation, which produces values, transformation produces **structural rewrites** — replacing one tree shape with another while preserving bindings and context.

## Selection Nodes: Pattern Matching and Rewriting

Selection nodes (`?`) are the primary rewriting mechanism in Mantra. They implement a **pattern-matching loop**: they evaluate their left-hand side (the pattern), search the right-hand side (the rules), and rewrite matches until no rule applies.

A selection node has two children:
- **LHS** — the pattern or expression to be rewritten
- **RHS** — the transformation rules to apply

During evaluation (`TSelectionNode.Evaluate`):

1. The LHS is evaluated
2. Variables in the LHS are normalized (resolved from the context)
3. Variables in the RHS are resolved
4. `RewriteOneByRules` searches for matches and applies the first rule that succeeds
5. If a match is found, the LHS is replaced with the rewritten result
6. If no match is found, the LHS is expanded in place (passed through unchanged)

The `MatchSubexpressions` flag (controlled by the `^` modifier) determines whether the matcher looks for subexpression matches within the pattern or only top-level matches.

### Transform Mode

Selection nodes also implement `Transform`, which differs from `Evaluate` in one key way: if **no rewrite step occurs**, the selection node cleans up its children and expands the LHS in place. This behavior — controlled by `CLEANUP_SELECTION_ON_STALL` — ensures that selections which cannot rewrite their input still produce a result rather than hanging.

### Inline Selections

Inline selection nodes (`:=?`) inherit the selection behavior but are evaluated inline within their parent expression rather than as standalone statements.

## Repeat Nodes: Iteration and Repetition

Repeat nodes (`:`) drive iterative expansion. They have two children:
- **LHS** — the template or replacement pattern
- **RHS** — the subject to expand (typically an integer or collection)

During evaluation (`TRepeatNode.Evaluate`):

1. The LHS is evaluated (unless it contains a selection, in which case it is preserved)
2. The RHS is resolved — variables are substituted from the context
3. The RHS is expanded:
   - If the RHS is an **integer**, it repeats the LHS N times, calling `Transform` between iterations to update state
   - If the RHS contains a **selection**, it uses state-based expansion via `ExpandStateSelection`, which loops until the selection reaches a fixed point (stall) or the iteration limit is reached
   - If the RHS is a **collection**, it iterates over each element
4. The LHS is deleted, and the expanded RHS replaces the repeat node

### State Selection Expansion

When the LHS contains a selection node, the repeat uses `ExpandStateSelection` from `helpers.pas`. This function:
1. Clones the source pattern
2. Loops through iterations, calling `Transform` on any selection nodes found in the tree
3. Stops when no selection can make progress (stall) or the iteration limit is reached
4. Cleans up any remaining selection nodes

This mechanism implements **fixpoint iteration** — repeatedly applying rewrite rules until the tree stabilizes.

### Staged Repeat Nodes

Staged repeat nodes (`::`) provide controlled, multi-stage expansion. They evaluate detached stages one at a time, allowing intermediate results between iterations. Each stage clones the LHS template, binds the iterator value, and evaluates it independently.

### Recurse Nodes

Recurse nodes (`...`) implement recursive descent. During expansion:
1. If part of a repeat context, the recurse node clones the source pattern and normalizes iterator bindings
2. It applies the operator (e.g., `>>`, `<<`) to control direction
3. The cloned pattern replaces the recurse node and continues expanding

Recurse nodes also support state selection mode for recursive rewriting scenarios.

## Fallback Nodes

Fallback nodes (`??`) provide conditional evaluation with a default path:

1. Evaluate the LHS
2. Check if the LHS made any progress (via `Context.HasProgressSince`)
3. If no progress was made, evaluate the RHS instead and discard the LHS
4. If progress was made, discard the RHS and keep the LHS

This implements a **try-catch** pattern for expression evaluation: attempt the primary path, fall back to the alternative if nothing happens.

## Inference Nodes

Inference nodes (`|=`) check whether one expression can be transformed into another using a set of rules:

1. The LHS is the **query** (subject -> target)
2. The RHS is the **ruleset** to apply
3. The inference engine attempts to rewrite the subject toward the target using the provided rules
4. Returns `1` (true) if the target is reachable, `0` (false) otherwise

For equivalence queries (`<=>`), the engine checks both directions: subject to target AND target to subject.

Inference respects configuration options:
- **Step limit** — maximum rewrite steps before giving up
- **Congruence budget** — maximum tree size during rewriting
- **Beam width** — number of parallel rewrite paths to explore

### Inference Witness Nodes

Inference witness nodes (`?|=`) return structured diagnostic information about the inference attempt rather than a simple boolean. They report:
- Whether the inference succeeded
- The number of steps taken
- The beam configuration used
- Policy and cost information from the inference engine

## Transform Pipeline

The overall transformation pipeline for a Mantra program follows this sequence:

1. **Parse** — The parser builds a tree of nodes from the source text
2. **Evaluate** — Nodes reduce to values, resolve variables, and match patterns
3. **Expand** — Repeat and recurse nodes iterate over structures, generating new nodes
4. **Transform** — Selection and inference nodes rewrite tree structure
5. **Repeat** — Steps 2-4 continue until the tree reaches a fixed point

Each node type implements the lifecycle methods it needs:
- **Leaf nodes** (integers, strings) only need `Evaluate`
- **Composite nodes** (arithmetic, functions) implement `Evaluate` and `Expand`
- **Control nodes** (selection, repeat, recurse) implement all three: `Evaluate`, `Expand`, and `Transform`

## Key Constants

| Constant | Value | Description |
|---|---|---|
| `MAX_FIXPOINT_STEPS` | 1024 | Maximum iterations for state selection expansion |
| `MAX_HEAD_DISPATCH_STEPS` | 128 | Maximum head dispatch iterations |
| `MAX_VARIABLE_SUBSTITUTION_DEPTH` | 64 | Maximum nested variable resolutions |
| `MAX_VARIABLE_NORMALIZATION_STEPS` | 4096 | Maximum variable normalization iterations |
| `CLEANUP_SELECTION_ON_STALL` | True | Clean up selection nodes when no rewrite occurs |
| `CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT` | True | Clean up selections after dollar-repeat expansion |

## Example: Selection Rewrite

```
pattern ? rewrite_rule
```

This creates a selection node where `pattern` is the LHS and `rewrite_rule` is the RHS. If the pattern matches the rule, the tree is rewritten. If not, the pattern passes through unchanged.

## Example: Repeat with Fixpoint

```
template : 3
```

This repeats `template` three times, applying transformations between iterations. If `template` contains a selection, each iteration applies the rewrite rules before producing the next copy.

## Example: Bounded Inference

```
query |= rules : 5
```

This checks if `query` can be proven using `rules`, but limits the inference to 5 rewrite steps. The repeat node detects the inference in its LHS and sets `InferenceRewriteMaxSteps` accordingly.
