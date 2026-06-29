# Evaluation

Evaluation is the runtime phase where Mantra processes expression trees to produce
results. Every Mantra program executes by walking its parsed expression trees
through a dispatch lifecycle that evaluates variables, applies transformations,
and computes values.

This section explains how Mantra evaluates expressions, from the top-level
statement loop down to individual node behavior.

---

## Core Concepts

### Expression Trees

When Mantra parses source code, it builds expression trees — linked structures of
nodes connected by LHS (left-hand side) and RHS (right-hand side) pointers. Each
node represents a language construct: variables, operators, literals, control-flow
forms, and more.

Evaluation walks these trees recursively. The tree structure determines execution
order, scope boundaries, and data flow.

### Dispatch Lifecycle

Every node participates in a five-phase dispatch lifecycle. The phases execute
in a fixed order, and each node type implements its own behavior for each phase:

```
Execute    — control flow (assignments, definitions, output)
  └── Evaluate  — scope gating, child dispatch, value resolution
    └── DoEvaluate  — node-specific evaluation logic
    └── Compute  — arithmetic reduction in backtick scopes
    └── Expand  — tree expansion (repeat, transform)
    └── Transform  — rule-based rewriting
    └── Complete  — cleanup (clear rewrite and evaluation flags)
```

The `Execute` phase handles top-level operations like assignments and definitions.
The `Evaluate` phase is the core: it dispatches to children, resolves variables,
handles scope boundaries, and coordinates the remaining phases.

### Context

All evaluation happens within a `TContext` — a shared runtime environment that
carries variables, rules, callables, namespaces, and configuration state.
Statements share a single context, so values assigned in one statement are
visible to all subsequent statements.

---

## Topics

### How Programs Execute

- **[Execution Order](execution-order.md)** — Statement sequencing and the
  dispatch lifecycle that processes each statement
- **[Statement Execution](execution-order/statement-execution.md)** — The
  statement loop, parsing, dynamic statement insertion, and shared context
- **[Head Dispatch](execution-order/head-dispatch.md)** — Automatic callable
  rule dispatch, pattern matching, recursion safety, and namespace resolution

### Evaluation Scopes

- **[Evaluation Scopes](evaluation-scopes.md)** — How curly braces `{ }`,
  backticks `` ` ``, and `fix` control evaluation boundaries
- **[Nested Evaluation](nested-evaluation.md)** — Nested evaluation scopes,
  deferred evaluation, and scope interaction rules

### Output

- **[Output Formatting](output-formatting.md)** — How Mantra formats evaluated
  results, value types, and display options
- **[Default Output](output-formatting/default-output.md)** — Standard output
  formatting for each value type

### Errors and Debugging

- **[Error Reporting](error-reporting.md)** — Runtime errors, error locations,
  and diagnostic information
- **[Debugging Evaluation Behavior](debugging-evaluation-behavior.md)** — Debug
  flags, event logs, and step-through execution

---

## Quick Reference

### Evaluation Entry Points

| Form | Entry Point | Description |
|---|---|---|
| Statement | `TExecutable.Execute` | Top-level statement loop |
| `{ expression }` | `TEvaluationNode` | Curly-brace evaluation scope |
| `` ` expression ` `` | `TComputeNode` | Arithmetic computation scope |
| `fix expression` | `TFixedNode` | Fixed (no-evaluate) scope |
| `name args` | `TVariableNode.Evaluate` (head dispatch) | Callable invocation |
| `subject ? rules` | `TSelectionNode` | Explicit rule selection |

### Phase Summary

| Phase | Responsibility |
|---|---|
| `Execute` | Control flow: assignments, definitions, output emission |
| `Evaluate` | Core dispatch: scope gating, variable resolution, child traversal |
| `DoEvaluate` | Node-specific logic (overridden by subclasses) |
| `Compute` | Numeric reduction within backtick scopes |
| `Expand` | Tree expansion for repeat and transform operators |
| `Transform` | Rule-based rewriting via selection or head dispatch |
| `Complete` | Cleanup: clear temporary flags and rewrite markers |

### Scope Types

| Syntax | Node Type | Behavior |
|---|---|---|
| `{ expr }` | `TEvaluationNode` | Evaluate contents, collapse to single value |
| `` ` expr ` `` | `TComputeNode` | Arithmetic-only evaluation |
| `fix expr` | `TFixedNode` | Block all evaluation (literal tree) |
| `[ ... ]` | `TListNode` | Container — evaluated unless in fixed scope |
| `( ... )` | `TParensNode` | Grouping — evaluated like evaluation scope |

---

## Related Sections

- [Syntax](../syntax/index.md) — Language constructs and their tree representations
- [Transformations](../transformations/index.md) — Rule-based rewriting, selection, and inference
- [Data Types](../data/index.md) — Variables, containers, and value types
