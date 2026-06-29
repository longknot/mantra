# Nested Evaluation

Nested evaluation is what happens when evaluation scopes (`{ }`), compute scopes
(` `` ` `` `), fixed scopes (`' ... '`), or containers (`( )`, `[ ]`) appear inside
one another. Each scope type participates in the evaluation lifecycle differently,
and the runtime tracks nesting depth to ensure correct order of resolution.

## Core Concept

When an evaluation scope is entered, the runtime increments a depth counter,
evaluates the contents, collapses the scope, and decrements the counter. If
evaluation scopes nest, each one maintains its own depth level:

```mantra
{ { 1 2 3 } }
```

The inner scope evaluates first (at depth 2), producing `1 2 3`. The outer scope
then evaluates (at depth 1), collapsing to the same result. The depth counter
ensures the innermost scope always resolves before outer scopes see its result.

## Depth Tracking

The global counter `EvaluationExecutionDepth` in `nodes.pas` tracks how many
evaluation scopes are currently active. It is incremented by `TEvaluationNode.Execute`
before evaluation and decremented in a `finally` block afterward:

```
Depth before: 0
Enter outer { ... }:    depth → 1
  Enter inner { ... }:  depth → 2
  Inner scope evaluates, collapses
  Exit inner scope:     depth → 1
Outer scope evaluates, collapses
Exit outer scope:       depth → 0
```

The depth counter is used internally for:
- **Guarding `TDefineNode`** — definitions created during evaluation are scoped
- **Debugger integration** — `dekEvalScopeEnter`/`dekEvalScopeExit` events carry
  the current depth level
- **Preventing recursive loops** — the counter helps detect runaway evaluations

## Nested Evaluation Scopes

Multiple `{ }` scopes can nest. Each independently evaluates and collapses:

```mantra
{ { 1 2 : 2 } : 3 }
```

Expected output: `1 2 1 2 1 2 1 2 1 2 1 2`

The inner scope `{ 1 2 : 2 }` evaluates first, expanding `1 2` twice to `1 2 1 2`.
The outer scope then repeats that result three times.

### Deeply Nested Scopes

```mantra
{ { { { [ 5 : 2 ] } } } }
```

Expected output: `[ 5 5 ]`

Each scope layer evaluates in turn. The innermost produces `[ 5 5 ]`; each outer
scope simply collapses around it without changing the result.

## Nested Compute Scopes

Compute scopes inherit from `TEvaluationNode` — they first evaluate children, then
apply arithmetic reduction via the `Compute` phase, then collapse. When compute
scopes nest, each independently evaluates and reduces:

```mantra
{ `` + 1 2 `` }
```

Expected output: `+ 3`

The compute scope evaluates `+ 1 2`, then reduces `1 + 2 = 3`. The outer evaluation
scope then collapses.

### Multiple Compute Levels

```mantra
{ `` + `` + 1 2 `` 3 `` }
```

Expected output: `+ 6`

The innermost compute scope `` ` + 1 2 ` `` evaluates first, producing `+ 3`.
The outer compute scope then evaluates `+ 3 3`, reducing to `+ 6`.

### Compute with Tilde in Nested Evaluation

```mantra
{ ~ + 1 { ~ + 2 3 } }
```

Expected output: `+ 6`

The `~` tilde marks operators for compute during evaluation. The inner scope
produces `+ 5`. The outer scope then computes `1 + 5 = 6`.

## Mixed Scope Nesting

Different scope types interact when nested. The key principle: evaluation scopes
(`{ }`) and compute scopes (` `` ` `` `) both collapse, while containers
(`( )`, `[ ]`) persist:

### Evaluation Inside List

```mantra
[ { 1 2 : 2 } ]
```

Expected output: `[ 1 2 1 2 ]`

The list persists. The evaluation scope inside it expands and collapses,
splicing its children into the list.

### Compute Inside Evaluation

```mantra
{ [ `` + 1 2 `` ] }
```

Expected output: `[ + 3 ]`

The compute scope evaluates and reduces, producing `[ + 3 ]`. The evaluation
scope then collapses around the already-computed result.

### Evaluation Inside Compute

```mantra
`` + { 1 2 } 3 ``
```

Expected output: `+ 6`

The evaluation scope `{ 1 2 }` evaluates first, producing `1 2`. The compute
scope then reduces `1 + 2 + 3 = 6`.

### Fixed Scope Prevents Inner Evaluation

```mantra
{ ' { 1 2 : 2 } ' }
```

Expected output: `( { 1 2 : 2 } )`

The fixed scope `' ... '` prevents all evaluation. The inner `{ 1 2 : 2 }`
is never evaluated. The outer scope collapses around the fixed content.

## Interaction with Repeat

When repeat (`:`) and nested scopes interact, the timing of evaluation matters:

### Repeat of Nested Scopes

```mantra
{ { 1 2 : 2 } : 3 }
```

Expected output: `1 2 1 2 1 2 1 2 1 2 1 2`

Inner scope evaluates first (`1 2 1 2`), then outer scope repeats it three times.

### Nested Repeats with Compute

```mantra
{ [ `` + 1 + 2 + 3 `` : 2 ] : 3 }
```

Expected output: `[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]`

The inner repeat produces two copies of the computed result `+ 6` inside a
list. The outer repeat clones that list three times.

### Compute on Next Iteration

```mantra
[ { [ ~ + 1 2 3 : 2 ] : 3 } ]
```

Expected output: `[ [ + 6 6 ] [ + 6 6 ] [ + 6 6 ] ]`

The tilde marks `+` for compute in each iteration. The inner repeat `: 2`
produces two copies with compute folding the operands, and the outer `: 3`
produces three copies of that result.

## Interaction with Transformations

Transform rules (`=>`) interact with nested evaluation scopes. The evaluation
scope protects structural patterns from premature evaluation:

### Selection with Nested Evaluation

```mantra
{ test "hello world" ? [ test { x y } => x ] }
```

Expected output: `test "hello world"`

The `{ x y }` pattern expects exactly two children. Since the pattern stays
structural (not evaluated), the multi-child `"hello world"` does not match
the two-slot pattern.

### Staged Repeat with Nested Evaluation

```mantra
{ [ scope { printf "x" } ] :: 3 }
```

Expected output: `x x x` (on separate lines)

Each iteration evaluates `{ printf "x" }`, firing the printf call.

## Interaction with Inference

Inference queries use curly braces for both rule wrapping and query evaluation:

```mantra
{ 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

Expected output: `1`

The inference query evaluates to `1` (true) and collapses back into the scope.

## Lifecycle Trace

For `{ `` + { 1 2 } 3 `` }`, the runtime follows this sequence:

1. **Parse** — `TComputeNode` wraps children. Inside, `TIntegerNode` (1),
   `TIntegerNode` (2), `TEvaluationNode` (the `{ }`), `TIntegerNode` (3),
   and `TK_PLUS` operators.

2. **Enter compute scope** — `TEvaluationNode.Execute` increments depth to 1.

3. **Evaluate children** — `TBaseNode.Evaluate` recursively evaluates children.

4. **Enter nested evaluation** — `TEvaluationNode.Execute` for `{ 1 2 }`
   increments depth to 2.

5. **Inner scope evaluates** — Children `1` and `2` evaluate. No operators
   to reduce. The scope collapses via `GlobalTree.Expand`.

6. **Exit inner scope** — Depth decrements to 1. The tree now has
   `` ` + 1 2 3 ` ``.

7. **Compute phase** — `TComputeNode.Evaluate` calls `Compute` on the first
   child. The `+ 1 2 3` expression reduces to `+ 6`.

8. **Compute scope collapses** — `GlobalTree.Expand` replaces the compute
   scope with `+ 6`.

9. **Exit compute scope** — Depth decrements to 0.

## Edge Cases

### Empty Nested Scopes

```mantra
{ { } }
```

Expected output: *(nothing)*

Both scopes evaluate to nothing and disappear.

### Fixed Content in Deep Nesting

```mantra
{ { \\ 1 2 : 2 } }
```

Expected output: `[ 1 2 : 2 ]`

The `\\` sets `TK_FIXED` on `[ 1 2 : 2 ]`, preventing repeat expansion even
though two evaluation scopes surround it.

### Deep Nesting with Mixed Scope Types

```mantra
{ [ ( { `` + 1 2 `` } ) ] }
```

Expected output: `[ ( + 3 ) ]`

The compute scope evaluates to `+ 3`. The parentheses persist as grouping.
The list persists as container. The evaluation scope collapses.

## Pitfalls

| Pitfall | Explanation |
|---|---|
| Expecting outer scope to re-evaluate inner result | Once an inner scope collapses, outer scopes see the already-evaluated tree — they don't re-parse |
| Assuming fixed content unfixes at outer depth | `TK_FIXED` persists across all scope levels; it must be explicitly unset with `TK_UNFIX` |
| Nested repeat count evaluated in wrong scope | A variable in the repeat driver resolves from the runtime context — the scope level doesn't change resolution order |
| Fixed scope inside compute scope | `' ... '` prevents evaluation of its contents regardless of surrounding compute scopes |
| Deep nesting without operators | `{ { { 1 } } }` produces `1` — extra scope layers collapse but don't add value when no operators are present |

## Related Pages

- [Evaluation Scopes](evaluation-scopes.md) — Full lifecycle for `{ }`
- [Evaluation Model](language-model/evaluation-model.md) — Dispatch lifecycle and scope types
- [Compute Scopes](compute/compute-scopes.md) — Arithmetic reduction with `` ` ``
- [Curly Brace Evaluation](evaluation-scopes/curly-brace-evaluation.md) — Detailed reference
- [Repeat Operator](transformations/repeat-operator.md) — Repeat expansion (`:`)
- [Nested Repeats](transformations/nested-repeats.md) — Multi-level repeat interactions
- [Fixed Scopes](syntax/fixed-scopes.md) — Preventing evaluation with `' ... '`
- [Meta-Compute Operator](compute/meta-compute-operator.md) — Tilde (`~`) for compute marking
