# Execution Order

Execution order in Mantra is determined by three layers working together: statement
sequencing at the top, tree traversal order within each statement, and the dispatch
lifecycle phases that process every node. Together they produce a deterministic,
predictable flow from source to result.

```
Statements (sequential, top to bottom)
  └── Execute phase (LHS-first depth-first traversal)
        └── Evaluate phase (fixed/unfix gating, descendant dispatch, DoEvaluate)
        └── Compute phase (~-triggered arithmetic reduction)
        └── Expand phase (scope collapse: { } becomes its children)
        └── Transform phase (rule-based rewriting)
        └── Complete phase (cleanup: clear rewrite and evaluation markers)
```

## Statement Sequencing

Statements are the outermost unit of execution. A program consists of one or more
statements separated by semicolons, executed sequentially from first to last. All
statements share a single `TContext` — variables, rules, callables, and namespaces
assigned in earlier statements are visible to all later ones.

```mantra
x = 10;
y = 20;
print { [ + x y ] };    ! sees x = 10 and y = 20
```

The runtime builds an execution queue from the parsed statements and processes them
in order. If a statement dynamically adds new statements (e.g., `include` or
`import`), those are spliced into the queue immediately after the current position.

See [Statement Execution](execution-order/statement-execution.md) for the full
statement loop, dynamic insertion, and shared context details.

---

## Tree Traversal: Left-Child / Right-Sibling

Every expression is a tree of nodes connected by two edges:

- **LHS** — first child (left edge)
- **RHS** — next sibling (right edge)

The runtime traverses this structure **depth-first, LHS-first**. For any node, it
processes the left child (LHS) before moving to the right sibling (RHS). This means
execution proceeds through children before siblings:

```
Node A (RHS → B)
  └── LHS → Node C (RHS → D)
          └── LHS → Node E
```

Traversal order: `A → C → E → D → B`

This ordering is implemented in `TBaseNode.Dispatch`, which visits LHS before RHS:

```pascal
procedure TBaseNode.Dispatch(Proc: Pointer; Context: TContext);
begin
  nodes.Dispatch(LHS, Index, Proc, Context);
  nodes.Dispatch(RHS, Index, Proc, Context);
end;
```

### What This Means in Practice

```mantra
{ [ 1 2 ] [ 3 4 ] }
```

The runtime evaluates `[ 1 2 ]` (LHS of the scope) before `[ 3 4 ]` (RHS sibling).
Within each array, elements are siblings processed left to right. The evaluation scope
collapses after all children are evaluated, producing `1 2 3 4`.

---

## The Dispatch Lifecycle

Every node participates in a phased dispatch. The phases execute in a fixed order,
and each node type implements its own behavior for each phase:

### Phase 1: Execute

The outermost phase. `TBaseNode.Execute` dispatches recursively to all children
(LHS then RHS). It handles control-flow operations:

- **Assignments** (`=`) — `TAssignmentNode` stores values in context
- **Definitions** (`define`, `rule`) — register keywords and callables
- **Output** (`print`, `output`, `tree`, `ir`) — format and emit results
- **Callables** — declared via `rule`, invoked via head dispatch

The Execute phase walks the tree structure but does not evaluate expressions or
collapse scopes — that happens in the Evaluate phase.

### Phase 2: Evaluate

The core phase. `TBaseNode.Evaluate` performs:

1. **Fixed/unfix gating** — checks `TK_FIXED` (via `\`) and `TK_UNFIX` meta flags.
   Fixed nodes skip evaluation of their subtree entirely.
2. **Descendant dispatch** — recursively calls `Evaluate` on LHS then RHS children.
3. **DoEvaluate** — invokes node-specific evaluation logic:
   - `TVariableNode` — substitutes variables from context
   - `TIntegerNode` / `TFloatNode` — evaluates arithmetic operations
   - `TRangeNode` — materializes ranges (`1..5` → `1 2 3 4 5`)
   - `TRepeatNode` — performs repeat expansion (`:`)
   - `TRecurseNode` — triggers fixpoint recursion (`...`)
   - Other nodes dispatch their own `DoEvaluate` behavior
4. **Compute trigger** — if the `~` (tilde) flag is set, runs `Compute` on this
   node, then clears the flag.
5. **Scope collapse** — for `TEvaluationNode` (`{ }`), calls `Expand` to replace
   the scope with its children in the parent context.

### Phase 3: Compute

Arithmetic reduction triggered by the `~` meta flag or explicit compute scopes
(`\` ... \``). `TBaseNode.Compute` checks fixed flags, then dispatches to children.
Specialized nodes like `TIntegerNode` and `TFloatNode` perform actual arithmetic
during this phase.

Compute does **not** run automatically on every node — it requires either the `~`
flag on a specific operator or an enclosing compute scope.

### Phase 4: Expand

Tree expansion phase. Handles:
- Evaluation scope collapse (`{ }` → its children)
- Repeat expansion (`:` → clones)
- Transform expansion (`=>` → rewritten forms)

After expansion, the original scope node is replaced by its contents in the parent's
child chain.

### Phase 5: Transform

Rule-based rewriting phase. `TBaseNode.Transform` checks fixed flags, then dispatches
to children. This phase applies selection rules (`?`) and inline transforms (`:=>`).

### Phase 6: Complete

Cleanup phase. `TBaseNode.Complete` calls:
- `ClearRewrite` — removes forward and triple-dot markers
- `ClearEvaluation` — removes remaining `TK_CURLY_BEGIN` nodes

This ensures no evaluation artifacts persist after processing.

---

## Scope Evaluation Order: Innermost First

When scopes nest, the innermost scope always evaluates first. This is guaranteed by
the depth-first traversal order combined with the `EvaluationExecutionDepth` counter.

```mantra
{ { [ 1 2 : 2 ] } : 3 }
```

Step by step:

1. **Execute** enters the outer `{ }`. Increments `EvaluationExecutionDepth` to 1.
2. **Evaluate** dispatches to children. Finds inner `{ }`.
3. **Execute** enters the inner `{ }`. Increments `EvaluationExecutionDepth` to 2.
4. **Evaluate** the inner scope. `[ 1 2 : 2 ]` expands to `1 2 1 2`.
5. **Expand** collapses the inner scope. `EvaluationExecutionDepth` decrements to 1.
   The outer scope now sees `1 2 1 2 : 3`.
6. **Evaluate** continues. `1 2 1 2 : 3` expands to `1 2 1 2 1 2 1 2 1 2 1 2`.
7. **Expand** collapses the outer scope. Produces `1 2 1 2 1 2 1 2 1 2 1 2`.

See [Nested Evaluation](nested-evaluation.md) for depth tracking and scope
interaction rules.

---

## Head Dispatch and Execution Order

Head dispatch occurs during the Evaluate phase when a variable node is encountered
in the head position of an expression. If the variable is registered as callable,
its rules are applied automatically against the invocation.

```mantra
rule double [ double x => ( x x ) ];
print { double 7 }
```

When `{ double 7 }` evaluates:

1. `TVariableNode.Evaluate` resolves `double`.
2. `Context.IsCallable("double")` returns true.
3. `TryHeadDispatch` applies the rule: `( 7 7 )`.
4. The rewritten form is evaluated immediately.

Head dispatch fires during evaluation, not during execute. This means it can only
trigger once the surrounding scope has entered the Evaluate phase. See
[Head Dispatch](execution-order/head-dispatch.md) for recursion safety,
second-chance dispatch, and namespace resolution.

---

## Fixed and Unfix Flags

The `\` (backslash) and `'` (apostrophe) controls affect execution order by
preventing evaluation of marked nodes:

- **`\` (backslash)** on a node — sets `TK_FIXED`. The node and its subtree are
  skipped during Evaluate and Transform phases.
- **`' ... '` (apostrophe scope)** — wraps content in `TFixedNode`. No evaluation,
  no expansion, no compute occurs inside.

```mantra
{ \[ 1 2 : 2 ] [ 3 4 : 2 ] }
```

**Output:** `1 2 : 2 3 4 3 4`

The fixed `\` prevents `[ 1 2 : 2 ]` from expanding. The sibling `[ 3 4 : 2 ]`
expands normally to `3 4 3 4`. The scope then collapses, producing the mixed result.

---

## Dynamic Statement Insertion

Some statements add new statements during execution. The runtime detects this and
splices new statements into the queue immediately after the current position:

```mantra
x = 1;
include "extra.m";     ! new statements from extra.m run here
print { x };            ! runs after included statements
```

If `extra.m` contains `x = 42;`, the output is `42` — not `1`. The included
statements execute between the include and the print.

---

## Practical Reading Order

When analyzing a Mantra program, follow this order:

1. **Statements top to bottom.** Identify each semicolon-delimited statement.
2. **Locate innermost scopes.** The deepest `{ }` and `` ` ` `` evaluate first.
3. **Check fixed/unfix flags.** `\` and `'` prevent evaluation of subtrees.
4. **Identify ~-marked operators.** These trigger the Compute phase.
5. **Find repeat and transform operators.** `:`, `?`, `=>` expand during Evaluate.
6. **Check for callable invocations.** Head dispatch fires for registered callables.
7. **Read outward.** See where each result is inserted as scopes collapse.

### Example: Complex Expression

```mantra
rule inc [ inc x => ( x + 1 ) ];

result = [ { inc 5 } { \ + 2 3 } ];
print { result };
```

Execution:

1. **Statement 1:** `rule inc [...]` — registers `inc` as callable.
2. **Statement 2:** Assignment. Evaluates `[ { inc 5 } { \ + 2 3 } ]`.
   - Array `[ ... ]` does not trigger evaluation — but `{ ... }` inside does.
   - Inner `{ inc 5 }`: `inc` is callable, head dispatch fires.
     Rule `inc 5 => ( 5 + 1 )` rewrites to `( 5 + 1 )`. Scope collapses.
   - Inner `{ \ + 2 3 }`: `\` fixes `+`, so no expansion. Scope collapses to `+ 2 3`.
   - Result: `[ ( 5 + 1 ) + 2 3 ]`.
3. **Statement 3:** `print { result }` — substitutes `result`, evaluates scope.

---

## Execution Order Summary

| Layer | Order | Key Mechanism |
|---|---|---|
| Statements | Sequential, top to bottom | `TExecutable.Execute` loop |
| Tree traversal | LHS-first, depth-first | `TBaseNode.Dispatch` |
| Phases | Execute → Evaluate → Compute → Expand → Transform → Complete | VMT dispatch lifecycle |
| Nested scopes | Innermost first | `EvaluationExecutionDepth` + depth-first traversal |
| Head dispatch | During Evaluate phase | `TVariableNode.Evaluate` + `TryHeadDispatch` |
| Dynamic insertion | After current statement | Queue splice in `TExecutable.Execute` |
| Fixed nodes | Skipped in Evaluate/Transform | `TK_FIXED` flag check |

---

## Related Pages

- [Statement Execution](execution-order/statement-execution.md) — the statement loop, parsing, dynamic insertion, and shared context
- [Head Dispatch](execution-order/head-dispatch.md) — automatic callable rule dispatch, recursion safety, and namespace resolution
- [Evaluation Scopes](../evaluation-scopes.md) — curly brace, backtick, and fixed scopes
- [Nested Evaluation](nested-evaluation.md) — nested scope interaction and depth tracking
- [Compute Scopes](../compute/compute-scopes.md) — arithmetic reduction in backtick scopes
