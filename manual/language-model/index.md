# Language Model

In Mantra, **code is data is trees**. Every expression, operator, and literal in
your source becomes a node in an abstract syntax tree. Evaluation, transformation,
and computation operate on those trees rather than on a flat stream of statements.

This section explains the conceptual model you need to read, write, and reason
about Mantra programs. If you are new to Mantra, read this page first — the
subsections below each dive deeper into one part of the model.

## What Is the Language Model?

The language model answers: *how does Mantra represent programs internally, and
how do those representations change during execution?*

Think of Mantra as a hybrid of three ideas:

- A **term-rewriting system** — patterns match, rules rewrite structure
- A **LISP-like homoiconic language** — code and data share the same tree form
- A **bounded inference engine** — rewrite chains run to fixpoint, not forever

Every Mantra program follows this lifecycle:

```
Source Text → Tokens → Parse Tree → Evaluate → Compute → Transform → Output
```

Each phase works on the same tree representation. A Mantra program does not
"compile" to bytecode; it transforms its own AST in place.

## Quick Orientation

Here are the building blocks you will encounter:

**Values** are leaves: integers, floats, strings, and variable references.

```mantra
42                  -- integer
3.14                -- float
"hello"             -- string
x                   -- variable reference
```

**Nodes** are the runtime representation of every source form. Each node has a
type that determines how the runtime treats it.

```mantra
[ 1 2 3 ]           -- array node
( + 1 2 )           -- expression node
{ x = 5 }           -- evaluation scope node
` + 1 2 `           -- compute scope node
' a b '             -- fixed scope node (no evaluation)
```

**Operators** define relationships between nodes and trigger transformations.

```mantra
:                   -- repeat / expansion
?                   -- selection / pattern rewrite
=>                  -- transform rule
|                   -- inference / proof query
&                   -- concatenation
```

See [Values, Nodes, and Expressions](values-nodes-expressions.md) for the full
catalog.

## The Evaluation Lifecycle

Every node goes through a fixed sequence of phases:

```
Parse    → Tokenizer and parser create nodes, wire tree edges
Execute  → Recursive traversal, evaluates children in order
Evaluate → Resolves variables, processes scopes, applies transforms
Compute  → Reduces arithmetic and comparisons (in ` ` scope)
Complete → Cleanup (clear rewrite state, collapse evaluation scopes)
```

During evaluation, nodes can be **expanded** (replaced by their first child),
**deleted**, or **cloned**. These are the primary mutation primitives — the tree
evolves in place.

See [Evaluation Model](evaluation-model.md) and its sub-pages for details on
evaluation vs. compute, statement output, and evaluation boundaries.

## Rewriting and Transformation

Mantra programs evolve by rewriting tree structure. The `?` operator is the
primary mechanism — it applies rules to a subject tree until a match succeeds
or no more rules apply.

```mantra
[ 1 2 3 ] ? [ x => x * 2 ]    -- apply rule: double each element
template : 3                  -- repeat template 3 times
query |= rules : 5            -- bounded inference (max 5 steps)
```

All recursive and iterative rewrites are **bounded** by `MAX_FIXPOINT_STEPS`
(1024) to prevent infinite loops.

See [Rewriting and Transformation Model](rewriting-transformation-model.md) for
selection semantics, repeat nodes, inference, and transform operators.

## Key Design Principles

These principles govern how Mantra works. Understanding them makes every operator
more predictable:

1. **Trees are first-class.** Values, operators, and scope delimiters are all
   tree nodes. You can inspect, clone, and transform any of them.

2. **Left-child / right-sibling.** The tree uses only two edges per node:
   `LHS` (first child) and `RHS` (next sibling). There are no parent pointers.

3. **Evaluation is explicit.** Curly braces `{ }` mark evaluation scope.
   Without them, a form stays structural — it is not automatically computed.

4. **Rewriting is destructive.** Nodes are expanded, deleted, and replaced
   in-place. The tree mutates during execution.

5. **Fixpoint is bounded.** All recursive rewrites have hard caps (1024 steps)
   to prevent infinite loops.

6. **No per-node heap allocation.** Nodes are compact 32-byte records stored in
   a pooled array. Behavior dispatches through a VMT table — cache-friendly and
   allocation-efficient.

## Topics

### Foundational Concepts

Understand how Mantra represents and processes programs:

- [Programs as Trees](programs-as-trees.md) — Tree-first programming model
  - [Scope Nodes](programs-as-trees/scope-nodes.md) — The five scope delimiters and their semantics
  - [User-Visible AST Shape](programs-as-trees/user-visible-ast-shape.md) — How tree structure appears in output
- [Values, Nodes, and Expressions](values-nodes-expressions.md) — Value types, node categories, expression grouping
- [Evaluation Model](evaluation-model.md) — Evaluation scope and explicit evaluation
  - [Evaluation vs. Compute](evaluation-model/evaluation-vs-compute.md) — Structural transform vs. value reduction
  - [Statement Output](evaluation-model/statement-output.md) — What statements produce vs. setup

### Transformation and Rewriting

How programs evolve from one form to another:

- [Rewriting and Transformation Model](rewriting-transformation-model.md) — Evaluate, expand, transform lifecycle
  - [Selection Rewrite Model](rewriting-transformation-model/selection-rewrite-model.md) — Pattern matching and rule application
  - [Transform Operators](rewriting-transformation-model/transform-operators.md) — `=>`, `==>`, `<=>` and variants

### Stability and Evolution

How to distinguish stable behavior from evolving features:

- [Stability Notes](stability-notes.md) — Fixture-backed vs. design-note behavior
  - [Fixture-Backed Behavior](stability-notes/fixture-backed-behavior.md) — Stable behavior backed by regression tests
  - [Design-Note Behavior](stability-notes/design-note-behavior.md) — Working but evolving features

## Related Sections

- [Syntax](../syntax/index.md) — Language forms, tokens, and literal syntax
- [Evaluation and Execution](../evaluation/index.md) — Runtime evaluation exposed to users
- [Transformations and Repeat](../transformations/index.md) — `:` repeat and tree expansion behavior
- [Compute and Operators](../compute/index.md) — `` ` ` `` compute scopes and arithmetic reduction
- [Working With Data](../data/index.md) — Data representation, queries, and rendering
