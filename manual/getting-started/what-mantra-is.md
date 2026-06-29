# What Mantra Is

Mantra is an experimental, **tree-first programming language**. Every Mantra program
starts as source text, but that text is immediately parsed into a tree structure.
The runtime then traverses, evaluates, and rewrites that tree — the tree is not an
internal implementation detail; it is the primary model for understanding how the
language works.

## The Core Idea

In most languages, programs are a linear sequence of statements executed in order.
In Mantra, programs are **trees** that the runtime operates on. You write nested
expressions that look similar to Lisp s-expressions, but the emphasis is on
**structural transformations** rather than sequential computation.

```
Source:  [ + 1 2 3 ]

Tree:    [ (root)
         ├── + (first child)
         ├── 1 (sibling of +)
         ├── 2 (sibling of 1)
         └── 3 (sibling of 2)
```

Every element you type — operators, values, scope delimiters — becomes a node in
this tree. Operations like evaluation, repetition, pattern matching, and arithmetic
reduction all work by traversing and mutating tree structure.

## Source Forms

Mantra programs use familiar structural delimiters, each with a distinct semantic
role:

| Delimiter | Scope Type | Behavior |
|---|---|---|
| `( ... )` | Expression | Groups elements without evaluating them |
| `[ ... ]` | Array / List | Container for data and structures |
| `{ ... }` | Evaluation | Evaluates descendants, then collapses into its contents |
| `` ` ... ` `` | Compute | Evaluates and performs arithmetic reduction |
| `' ... '` | Fixed | Blocks all evaluation — preserves literal structure |

Choosing the right delimiter matters. Swapping one for another changes whether
content is evaluated, computed, or preserved unchanged.

## What Mantra Can Do

### Repeat and Expansion

The `:` (repeat) operator clones and expands tree structures:

```mantra
[ { 1 2 3 : 4 } ]
```

This repeats `1 2 3` four times inside an evaluation scope. The evaluation scope
then collapses, leaving:

```text
[ 1 2 3 1 2 3 1 2 3 1 2 3 ]
```

### Arithmetic Computation

Backtick scopes trigger arithmetic reduction. When combined with repeat, you get
computed and replicated structures:

```mantra
`[ + 1 2 3 ] : 3`
```

The compute scope first reduces `+ 1 2 3` to `6`, then the repeat clones the
result three times:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

### Structural Pattern Matching

Mantra supports tree-based pattern matching with the `?` (selection) operator.
Rules match tree structures — not text — and rewrite matched subtrees:

```mantra
[ a b c ] ? [ x => x + 1 ]
```

Rules capture nodes using lowercase symbols (matching specific identifiers) and
uppercase symbols (matching any node). The `--` operator matches any remaining
sequence of nodes.

### Transform Rules

Named rules let you define reusable transformations:

```mantra
rule double [ x => x x ]
[ 1 2 ] ? double
```

Rules can be composed, guarded, and applied iteratively through selection and
transform operators.

### Inference and Proof Queries

The `|=` operator supports proof-oriented queries — can you transform one tree
into another using a given set of rules? It returns `1` (success) or `0` (failure)
and can search multiple steps using bounded repetition.

```mantra
[ a ] => [ b ] |= [ a => b ]
```

This asks: starting from `[ a ]`, can the rules reach `[ b ]`? The answer is `1`.

### Variables and Tree Substitution

Variables in Mantra store entire tree structures, not scalar values. When you
reference a variable, the runtime clones its stored tree at that location:

```mantra
x = [ 1 2 3 ]
x
```

This binds `x` to the tree `[ 1 2 3 ]` and then substitutes that tree on the next
line. Variables can also be pre-defined from the command line using `--set`.

### Sequence and Structural Utilities

Mantra provides operators for concatenating sequences (`&`), expanding ranges
(`..`), and converting between strings and character sequences (`explode` /
`implode`).

## What Makes Mantra Different

Mantra draws from several traditions but carves its own path:

- **Term-rewriting systems** like Maude and ELAN — Mantra rewrites tree structures
  using rules, but with a more compact syntax and integrated evaluation model.
- **Lisp and homoiconic languages** — Mantra's code-as-data model shares DNA with
  Lisp, but the focus is on tree transformations rather than macro systems or
  sequential evaluation.
- **Proof search and inference engines** — The `|=` operator and rule-based
  transforms support bounded search through transformation spaces, making Mantra
  applicable to verification and synthesis tasks.

Key design choices that set Mantra apart:

1. **Compact node representation** — Every tree node is 32 bytes using only two
   edges (left-child, right-sibling), making the runtime memory-efficient and
   traversal fast.
2. **Evaluation is explicit** — You mark exactly which parts of the tree should
   evaluate using scope delimiters. Unmarked content stays literal.
3. **Destructive tree mutation** — Evaluation expands, deletes, and replaces nodes
   in place. The tree is not copied conservatively; mutation is the primary
   mechanism.
4. **Bounded fixpoint iteration** — Recursive and iterative rewrites always have
   hard step limits, so programs cannot loop infinitely.

## Current Status

Mantra is under active development. The runtime supports:

- Full tokenization and parsing pipeline
- Five scope types with distinct evaluation semantics
- Repeat, selection, transform, and inference operators
- Pattern matching with variable bindings, match-any captures, and guards
- Arithmetic compute with integer, float, and boolean operations
- Range expansion, string manipulation, and sequence utilities
- Named rules, packages, and imports
- CLI-driven debugging with breakpoints, event logs, and tree inspection
- A test suite with 370+ fixtures validating behavior

Some areas are still evolving and may change in future releases. The manual
documents behavior that is observable in the current runtime and links to deeper
design notes where behavior is still being refined.

## How to Learn More

This manual is organized to take you from basics to advanced workflows:

| Topic | Where to Go |
|---|---|
| Build and run your first program | [Getting Started](../getting-started.md) |
| Programs as tree structures | [Language Model](../language-model/index.md) |
| Language syntax reference | [Syntax](../syntax/index.md) |
| Evaluation and execution lifecycle | [Evaluation and Execution](../evaluation/index.md) |
| Repeat, patterns, and transforms | [Transformations and Repeat](../transformations/index.md) |
| Arithmetic and compute operations | [Compute and Operators](../compute/index.md) |
| Data, variables, and packages | [Working With Data](../data/index.md) |
| Runnable examples with expected output | [Examples](../reference/examples.md) |
| Command-line reference | [Command Line](../reference/command-line.md) |

The [Test Fixture Guide](../reference/test-fixture-guide.md) is also a practical
learning resource — every fixture is a runnable example with verified input and
output.

## Related Projects

Mantra is a rewrite of [SCORP2](https://github.com/longknot/scorp2) with a more
compact node model and cleaner separation of concerns between the tokenizer,
parser, tree operations, and runtime dispatch.
