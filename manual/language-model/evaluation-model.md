# Evaluation Model

Evaluation is explicit in Mantra. A form is not automatically evaluated just
because it appears in source text. Evaluation requires a deliberate scope
delimiter or operator that tells the runtime to process a subtree.

This page explains the evaluation lifecycle, how scopes control evaluation
boundaries, and how evaluation interacts with compute, expansion, and cleanup.

---

## The Dispatch Lifecycle

Every node in the AST participates in a five-phase dispatch lifecycle. The
phases execute in a fixed order during the `Evaluate` pass:

```
Execute    — recursive traversal, top-level control flow
  └── Evaluate  — scope gating, child dispatch, variable resolution
    └── DoEvaluate  — node-specific evaluation (overridden per type)
    └── Compute  — arithmetic reduction (when ~ or backtick scope triggers it)
    └── Expand  — tree expansion (repeat, transform, scope collapse)
    └── Transform — rule-based rewriting
    └── Complete  — cleanup (ClearRewrite, ClearEvaluation)
```

`TEvaluationNode.Execute` wraps the `Evaluate` call in a try/finally block that
increments `EvaluationExecutionDepth` before and decrements it after. This
counter tracks nesting depth across all evaluation scopes.

---

## Explicit Evaluation

Curly braces mark evaluation scope:

```mantra
{ 1 2 3 : 4 }
```

The runtime evaluates the scoped form and places the result into the surrounding
tree. The braces are **destructive** — they disappear after evaluation, and their
children are spliced directly into the parent tree via `GlobalTree.Expand`.

### How It Works

1. **Enter scope** — `TEvaluationNode.Execute` increments `EvaluationExecutionDepth`
2. **Evaluate** — children are recursively evaluated; variables are substituted;
   operators like `:` (repeat) and `?` (selection) expand
3. **Collapse** — `GlobalTree.Expand(PrevIndex, Index)` replaces the scope node
   with its children in the parent tree
4. **Exit scope** — `EvaluationExecutionDepth` is decremented

The key operation is the **collapse** (step 3). The braces are removed and
their contents become direct children of the parent node.

### Examples

**Simple evaluation and collapse:**

```mantra
[ { 1 2 3 : 4 } ]
```

The `{ 1 2 3 : 4 }` scope evaluates the repeat (clones `1 2 3` four times),
then collapses. Result:

```
[ 1 2 3 1 2 3 1 2 3 1 2 3 ]
```

**Empty evaluation scope:**

An empty `{ }` evaluates to nothing and disappears from the tree.

---

## Evaluation Boundaries

Only the expression inside the curly braces belongs to that evaluation scope.
Surrounding forms may still affect how the evaluated result is placed or
formatted.

When an example produces surprising output, inspect where the curly braces begin
and end before changing the expression itself.

### Nested Evaluation

Multiple `{ }` scopes can nest. Each has its own `EvaluationExecutionDepth` level,
and the innermost scope resolves first:

```mantra
{ { [ 3 : 3 ] } }
```

The inner scope evaluates first, producing `[ 3 3 3 ]`. The outer scope then
collapses around the already-evaluated result.

### Fixed Content Prevents Evaluation

The `\` (backslash) meta flag sets `TK_FIXED` on a node, preventing it from
being evaluated or transformed:

```mantra
{ \ [ 1 2 : 2 ] }
```

**Output:** `[ 1 2 : 2 ]`

The `[ 1 2 : 2 ]` node is fixed, so the repeat expansion is skipped. The
evaluation scope still collapses, but its children were not expanded.

Compare with `' ... '` (apostrophe scope), which is a `TFixedNode` that
prevents all evaluation entirely:

```mantra
' [ 1 2 : 2 ] '
```

**Output:** `( [ 1 2 : 2 ] )`

---

## Evaluation vs Compute

Evaluation and compute are related but distinct phases:

| Aspect | Evaluation (`{ }`) | Compute (`` ` ``) |
|---|---|---|
| Node type | `TEvaluationNode` | `TComputeNode` |
| Inheritance | `TScopeNode` | `TEvaluationNode` |
| Primary action | Evaluate children, collapse scope | Evaluate children, reduce arithmetic |
| Arithmetic reduction | Only with `~` modifier | Automatic on children |
| Scope collapse | Yes | Yes |

Compute inherits from `TEvaluationNode` — it first evaluates children, then
calls `Compute` on the first child, then collapses. The `~` tilde modifier
can trigger compute inside any evaluation scope without requiring backtick
delimiters.

### Compute with Tilde

```mantra
{ ~ + 1 ( 2 ) }
```

**Output:** `+ 3`

The `~` triggers compute on `+ 1 ( 2 )`, reducing it to `+ 3`. The evaluation
scope then collapses around the result.

---

## Evaluation in Different Contexts

### Inside Selection Rules

Curly braces in selection patterns protect expressions from premature
evaluation, keeping rule templates structural:

```mantra
print { test "hello world" ? [ test { x y } => x ] }
```

**Output:** `test "hello world"`

The `{ x y }` pattern expects exactly two children. Since the pattern stays
structural (not evaluated), the multi-child `"hello world"` does not match
the two-slot pattern.

### Inside Repeat Operations

Curly braces inside repeat operations evaluate each clone individually during
staged repeats (`::`):

```mantra
{ [ scope { printf "x" } ] :: 3 }
```

**Output:** `x x x` (on separate lines)

Each iteration evaluates `{ printf "x" }`, firing the printf call.

### With Inference

Curly braces wrap inference queries and rule sets:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

**Output:** `1`

The inference query evaluates to `1` (true) and collapses back into print.

---

## Scope Comparison

| Scope | Syntax | Evaluates | Collapses | Computes |
|---|---|---|---|---|
| Expression | `( ... )` | No | No | In compute phase |
| Array | `[ ... ]` | No | No | In compute phase |
| Evaluation | `{ ... }` | Yes | **Yes** | With `~` |
| Compute | `` ` ... ` `` | Yes | Yes | Automatic |
| Fixed | `' ... '` | No | No | No |

---

## Key Behaviors

- **Destructive collapse** — `{ }` is always removed; children are spliced into
  the parent tree via `GlobalTree.Expand(PrevIndex, Index)`
- **Nested evaluation** — Multiple scopes nest; each tracks its own depth level
- **Fixed marker respect** — `\` (backslash) on a child prevents its evaluation
- **Tilde compute** — `~` triggers arithmetic reduction before collapse
- **Rule template protection** — In selection rules, `{ }` keeps patterns
  structural and prevents premature evaluation
- **Debugger integration** — `dekEvalScopeEnter` and `dekEvalScopeExit` events
  are emitted when a debugger is attached
- **Empty scope** — `{ }` collapses to nothing; the parent sees no children

---

## Related Pages

- [Curly Brace Evaluation](evaluation-scopes/curly-brace-evaluation.md) — Detailed reference for `{ }` behavior
- [Evaluation vs Compute](evaluation-model/evaluation-vs-compute.md) — Differences between the two phases
- [Statement Output](evaluation-model/statement-output.md) — Setup vs output statements
- [Nested Evaluation](../evaluation/nested-evaluation.md) — Nested scope interaction rules
- [Evaluation Scopes](../evaluation/evaluation-scopes.md) — Full evaluation scope lifecycle
- [Backtick Compute Scopes](../syntax/compute-scopes.md) — Arithmetic reduction syntax
- [Fixed Scopes](../syntax/fixed-scopes.md) — Preventing evaluation with `' ... '`

