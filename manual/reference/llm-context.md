# LLM_CONTEXT.md

`LLM_CONTEXT.md` at the project root gives language models a self-contained,
accurate mental model of the Mantra programming language, its runtime, and its
repository layout. It is designed so an LLM can navigate the codebase, produce
technical documentation, and assist with implementation without requiring
interactive exploration.

The file is a **living reference** maintained alongside the source code. When
the project structure changes, the file is updated to reflect the new state.

## Location

```
/projects/mantra/LLM_CONTEXT.md
```

The file lives at the project root, alongside `mantra.lpr`, `mantra.cfg`,
`AGENTS.md`, and `README.md`.

## Purpose

The opening of the file states its purpose explicitly:

> **Purpose:** Give an LLM a concise, accurate mental model of the Mantra
> programming language, its runtime, and its repository layout so it can
> produce useful technical documentation and assist with implementation.

It is not a general project README — it is specifically structured for LLM
consumption: dense with facts, tables, and structural references rather than
narrative prose.

## Document Structure

The current `LLM_CONTEXT.md` contains **14 sections** organized for progressive
discovery:

| # | Section | What It Covers |
|---|---|---|
| 1 | What Is Mantra? | Language identity, design philosophy, analogies (term-rewriting, LISP, proof-search) |
| 2 | Repository Layout | Full directory tree with annotations for `src/`, `docs/`, `manual/`, `tests/`, `packages/`, `sandbox/`, `vendor/` |
| 3 | Compilation Pipeline | Tokenizer → Parser → Node Registration → Evaluation → Formatter → Output |
| 4 | Core Data Structures | `TTreeNode` (32-byte packed record), `TCustomTree` (node pool), token system (bit-packed IDs) |
| 5 | Language Constructs | Scope nodes, operators, meta flags, keywords — all in reference tables |
| 6 | Runtime Dispatch Model | VMT-based dispatch, node hierarchy, dispatch lifecycle |
| 7 | Key Language Behaviors | Repeat (`:`), selection (`?`), compute (`` ` ``), inference (`|=`), variables |
| 8 | CLI Interface | Build commands, run modes, debug flags, matcher control, debugger options |
| 9 | Testing | `tests/run.sh`, fixture format (`.in`/`.out`/`.args`), filter and strict modes |
| 10 | Design Philosophy & Key Insights | 8 core principles (code-is-data, compact nodes, no heap allocation, etc.) |
| 11 | Adding a New Node Type | 7-step checklist from `OBJ_*` constant through fixture tests |
| 12 | Common Pitfalls | 6 pitfalls with explanations (wrong PrevIndex, evaluating templates, etc.) |
| 13 | Key Files to Read First | Priority-ordered reading list with rationale |
| 14 | Related Projects | SCORP2 — the predecessor codebase |

## Section Details

### 1. What Is Mantra?

Describes Mantra as an **experimental, tree-first programming language**
implemented in Free Pascal. Source code is parsed into an AST, then rewritten
and evaluated through node-level operations. Key analogies:

- A **term-rewriting system** (like Maude or ELAN)
- A **LISP-like homoiconic language** (code-as-data)
- A **proof-search / inference engine** (bounded rewrite chains)

### 2. Repository Layout

Provides a complete annotated directory tree. Key entries:

| Directory | Content |
|---|---|
| `src/` | 14+ `.pas` units: tokenizer, parser, tree, nodes, context, formatters, matcher, inference, debugger |
| `docs/` | 40+ markdown design notes (ARCHITECTURE.md, NODES.md, REPEAT.md, etc.) |
| `manual/` | User-facing MkDocs documentation (getting-started, language-model, syntax, etc.) |
| `tests/` | Fixture-based test runner with 440+ test cases |
| `packages/` | Mantra package library |
| `sandbox/` | Experimental code |
| `vendor/` | Third-party dependencies |

### 3. Compilation Pipeline

A six-stage pipeline with intermediate representations:

```
Source Text
    ▼
Tokenizer (exp_tokenizer.pas)     → Token stream: (ID, Index) pairs
    ▼
Parser (mathparser.pas)            → AST in TCustomTree
    ▼
Node Registration (nodes.pas)      → VMT_TABLE maps node Id → class VMT
    ▼
Evaluation / Execution (nodes.pas) → DispatchExecute → DispatchEvaluate → DispatchCompute
    ▼
Formatter (formatters.pas)         → Tree → formatted string
    ▼
Output (runtime_output.pas)        → Console output
```

### 4. Core Data Structures

#### TTreeNode

The fundamental AST node — a **packed 32-byte record** using left-child / right-sibling representation:

```pascal
TTreeNode = packed record
  case Integer of
    0: (Data, Ref: Cardinal; Edge: array[0..1] of Integer);
    1: (Id, Extra, Op, Meta: Byte;
        HRef, LRef: Word;
        LHS, RHS: Integer);
end;
```

- **LHS** — first child (left edge)
- **RHS** — next sibling (right edge)
- **EOT** (`MaxInt`) — sentinel for "no link"

#### TCustomTree

Manages a **node pool** with free-list recycling. Methods include `AllocateNode`, `DisposeNode`, `CloneSubtree`, `Delete`, `Expand`, `ExpandInline`, `LinkLHS`, `LinkRHS`.

#### Token System

Token IDs are **bit-packed**: `[31..24] META | [23..16] RESERVED | [15..8] OPERATOR | [7..0] ID`.

### 5. Language Constructs

Reference tables for all syntax elements:

**Scope nodes** — `( ... )` (expression), `[ ... ]` (array), `{ ... }` (evaluation), `` ` ... ` `` (compute), `' ... '` (fixed).

**Operators** — 17 operators documented: `:`, `?`, `:=?`, `=>`, `:=>`, `<=>`, `\|=`, `=`, `:=`, `..`, `...`, `--`, `---`, `&`, `\|`, and their token constants.

**Meta flags** — 5 flags: `~` (compute), `\` (fixed), `$` (state-selection), `^` (full-match), `.` (rule marker), `@` (at-index).

**Keywords** — 12 keywords: `rule`, `define`, `selector`, `package`, `import`, `include`, `print`, `exec`, `callable`, `explode`, `implode`, `alias`.

### 6. Runtime Dispatch Model

#### VMT-Based Dispatch

Nodes are **not heap-allocated objects**. The dispatch model:

1. `RegisterObjects()` populates `VMT_TABLE: array of Pointer`
2. Each entry maps `OBJ_*` constant to a class VMT
3. `GetNode(Index, PrevIndex)` creates a lightweight **stack wrapper** with the correct VMT pointer
4. Trampolines invoke virtual methods through the VMT

#### Node Hierarchy

The complete hierarchy tree is documented — from `TBaseNode` through 20+ concrete node types (`TExpressionNode`, `TEvaluationNode`, `TSelectionNode`, `TInferenceNode`, etc.).

#### Dispatch Lifecycle

```
Execute    — recursive execution over children
  └── Evaluate  — fixed/unfix gating, evaluate descendants, run DoEvaluate, trigger Compute if ~, collapse { }
    └── Compute  — arithmetic reduction in ` ` scope
    └── Expand   — tree expansion (repeat, transform)
    └── Transform — rule-based rewriting
    └── Complete — cleanup (ClearRewrite, ClearEvaluation)
```

### 7. Key Language Behaviors

Covers the five core behaviors with syntax and examples:

| Behavior | Operator | Description |
|---|---|---|
| Repeat | `:` | Clone LHS n times or recurse to fixpoint (bounded at 1024 steps) |
| Selection | `?` | Rewrite LHS using first matching rule from RULES |
| Compute | `` ` `` | Arithmetic reduction in backtick scope |
| Inference | `\|=` | Proof search returning 1 (success) or 0 (failure) |
| Variables | `=`, `:=` | Store and substitute tree snapshots |

### 8. CLI Interface

Documents the complete build command and runtime flags:

- **Build:** `fpc mantra.lpr` with target-specific flags
- **Run:** stdin, file input, REPL (`--interactive`)
- **Variables:** `--set`, `--eval`
- **Debug:** `--debug`, `--raw`, `--show-tokens`
- **Matcher:** `--backtracking`, `--no-guards`, `--no-head-dispatch`
- **Debugger:** `--debugger`, `--debugger-cli`, `--break-callable`, `--break-source`

### 9. Testing

Describes `tests/run.sh` with its options (`--no-build`, `--strict`, `--filter`, `--jobs`) and the fixture format (`.in`/`.out`/`.args`).

### 10. Design Philosophy & Key Insights

Eight numbered principles:

1. **Code is data is trees** — every expression is an AST node
2. **Compact nodes** — 32 bytes per `TTreeNode`
3. **No per-node heap allocation** — stack wrappers with VMT pointers
4. **Left-child / right-sibling** — only two edges, no parent pointers
5. **Evaluation is destructive** — in-place expansion, deletion, replacement
6. **Rules are templates** — RHS must not be evaluated prematurely
7. **Fixpoint is bounded** — `MAX_FIXPOINT_STEPS = 1024`
8. **Free-list recycling** — node pool with allocate/dispose

### 11. Adding a New Node Type

A 7-step checklist for developers:

1. Define `OBJ_*` constant in `nodes.pas`
2. Create packed object type inheriting from `TBaseNode`
3. Override virtual methods (`Execute`, `Evaluate`, `Compute`, etc.)
4. Register in `RegisterObjects`
5. Ensure parser emits this `OBJ_*` (`mathparser.pas`)
6. Add formatting (`formatters.pas`)
7. Add fixture tests (`tests/cases/`)

### 12. Common Pitfalls

Six documented pitfalls:

| Pitfall | Explanation |
|---|---|
| Forgetting `RegisterObjects` | Nodes silently route to wrong behavior |
| Wrong `PrevIndex` | `Expand` vs `ExpandInline` — root nodes need `EOT` |
| Evaluating rule templates | Selection RHS must stay as patterns |
| Assuming parent pointers | `TTreeNode` has no parent |
| Breaking sibling chains | Mutations must preserve `RHS` links |
| Infinite fixpoint | Always respect `MAX_FIXPOINT_STEPS` bounds |

### 13. Key Files to Read First

Priority reading list with rationale — from high-level (`docs/ARCHITECTURE.md`) to implementation details (`exp_trees.pas`, `tokens.pas`, `nodes.pas`, `mathparser.pas`, `matcher_ir.pas`).

### 14. Related Projects

References **SCORP2** (`/projects/scorp2`) — the predecessor codebase that Mantra rewrites with a more compact node model.

## When to Reference It

Load `LLM_CONTEXT.md` before you:

- **Explore the project** — understand the overall layout, pipeline, and conventions
- **Implement a feature** — find where a feature lives and what files to modify
- **Fix a bug** — navigate to the correct source file and understand the dispatch model
- **Write tests** — understand the fixture format, naming conventions, and test runner
- **Write documentation** — check the manual structure and cross-reference existing pages
- **Add a node type** — follow the checklist in section 11
- **Debug a rewrite** — review the dispatch lifecycle and common pitfalls

The file is designed to be **comprehensive but concise** — it summarizes the
project rather than reproducing source code in full.

## How LLMs Should Use It

1. **Load it first** in every new session that involves the Mantra codebase. It
   provides the mental model needed to interpret source files, design docs, and
   test fixtures.

2. **Cross-reference the source.** The file points to specific files and
   sections. When working on a feature, load `LLM_CONTEXT.md` first, then drill
   into the relevant source files listed in section 13.

3. **Check the pitfalls.** Before submitting changes, review section 12 to
   avoid common mistakes (wrong `PrevIndex`, evaluating templates, breaking
   sibling chains).

4. **Follow the checklist.** When adding new functionality, use the "Adding a
   New Node Type" checklist (section 11) as your implementation guide.

## Keeping It Updated

When you make structural changes to the project, update `LLM_CONTEXT.md` to
reflect the new state:

- **Adding a module** — add it to the repository layout (section 2) and update
  the source file descriptions
- **Changing the pipeline** — update the compilation pipeline (section 3)
- **Adding a node type** — update the node hierarchy (section 6) and the
  checklist (section 11) if steps change
- **Adding operators or keywords** — update the language constructs tables
  (section 5)
- **Changing CLI flags** — update the CLI interface section (section 8)
- **Discovering new pitfalls** — add them to section 12

Accurate context ensures future LLM sessions start from reliable information
rather than stale assumptions.

## See Also

- [Project README](../../../README.md) — Public project description
- [AGENTS.md](../../../AGENTS.md) — Agent workflow guidelines
- [Architecture](../../../docs/ARCHITECTURE.md) — High-level pipeline overview
- [Nodes](../../../docs/NODES.md) — Node system design
- [Building the Runtime](../getting-started/building-the-runtime.md) — Build and install guide
- [Command Line](command-line.md) — CLI flags reference
- [Test Fixture Guide](test-fixture-guide.md) — Test conventions and workflows
- [Glossary](glossary.md) — Alphabetical term reference
