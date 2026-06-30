# Mantra User Manual

Mantra is an experimental, **tree-first programming language**. Every Mantra
program starts as source text, which the runtime immediately parses into an
abstract syntax tree. The runtime then traverses, evaluates, and rewrites that
tree using structural pattern matching, rule-based transformations, and
iterative fixpoint rewrites.

This manual is the user-facing guide for writing, running, and reasoning about
Mantra programs. It is built with [MkDocs](https://www.mkdocs.org/) and
configured at the repository root in `mkdocs.yml`.

## Quick Start

If you have Mantra built and want to run something immediately:

```bash
# Arithmetic in a compute scope
echo '` + 1 2 3`' | mantra

# Repeat and expand
echo '[ { 1 2 3 : 4 } ]' | mantra

# Interactive REPL
mantra --interactive
```

For a full walkthrough — from building the runtime to running the 370+ fixture
test suite — see [Getting Started](getting-started.md).

## Manual Sections

The manual is organized into eight sections, each covering a broad area of the
language:

### [Getting Started](getting-started.md)

Build the runtime from source, run your first program, understand the input/
output cycle, and validate with the test suite. Covers prerequisites, building,
running from stdin or files, shell quoting, debug output modes, and interactive
REPL.

- [What Mantra Is](getting-started/what-mantra-is.md) — tree-first language,
  delimiters, and core capabilities
- [Installation and Prerequisites](getting-started/installation-and-prerequisites.md)
  — Free Pascal, shell, MkDocs
- [Building the Runtime](getting-started/building-the-runtime.md) — compile
  command, directory layout, verification
- [Running Programs](getting-started/running-programs.md) — stdin, files, shell
  quoting
- [Reading Runtime Output](getting-started/reading-runtime-output.md) — INPUT/
  OUTPUT/FORMATTED sections, print statements, debug modes

### [Language Model](language-model/index.md)

Programs as tree structures: how Mantra represents code internally, the five
scope types, values and expressions, the evaluation model, and rewriting and
transformation theory. This section explains the mental model behind the
language.

- [Programs as Trees](language-model/programs-as-trees.md) — AST shape, scope
  nodes, user-visible tree structure
- [Values, Nodes, and Expressions](language-model/values-nodes-expressions.md)
- [Evaluation Model](language-model/evaluation-model.md) — evaluation vs.
  compute, statement output
- [Rewriting and Transformation Model](language-model/rewriting-transformation-model.md)
  — transform operators, selection rewrite model
- [Stability Notes](language-model/stability-notes.md) — fixture-backed vs.
  design-note behavior

### [Syntax](syntax/index.md)

Reference for all language forms: tokens, whitespace, delimiters, scope types,
operators, keywords, and declarations. Use this as a quick lookup when you need
to know how something is written.

- [Tokens and Whitespace](syntax/tokens-whitespace.md) — identifiers, operators,
  delimiters
- [List Containers](syntax/list-containers.md) — `[ ... ]` arrays
- [Expressions](syntax/expressions.md) — `( ... )` grouping
- [Evaluation Scopes](syntax/evaluation-scopes.md) — `{ ... }` evaluation
- [Compute Scopes](syntax/compute-scopes.md) — `` ` ... ` `` arithmetic
- [Operators and Special Forms](syntax/operators-special-forms.md) — assignment,
  rules, imports, includes

### [Evaluation and Execution](evaluation/index.md)

How the runtime evaluates programs: execution order, head dispatch, nested
evaluation, output formatting, error reporting, and debugging with event logs.

- [Evaluation Scopes](evaluation/evaluation-scopes.md) — curly-brace
  evaluation, print and output
- [Execution Order](evaluation/execution-order.md) — statement execution, head
  dispatch
- [Nested Evaluation](evaluation/nested-evaluation.md)
- [Output Formatting](evaluation/output-formatting.md) — default, raw, debug,
  token output
- [Error Reporting](evaluation/error-reporting.md)
- [Debugging Evaluation Behavior](evaluation/debugging-evaluation-behavior.md)
  — event logs

### [Transformations and Repeat](transformations/index.md)

The core of Mantra: the `:` repeat operator, pattern matching, selection
rewrites, transform rules, and inference queries. Covers bounded and fixpoint
repeat, variable captures, match-any, guards, selectors, equivalence rules, and
witness output.

- [Repeat Operator](transformations/repeat-operator.md) — bounded and fixpoint
  repeat
- [Expansion Behavior](transformations/expansion-behavior.md)
- [Patterns](transformations/patterns.md) — variable captures, match-any,
  guards and selectors
- [Transform Rules](transformations/transform-rules.md) — basic, inline,
  substitution, equivalence
- [Rules in Practice](transformations/rules-in-practice.md) — reusable dispatch,
  queries, bidirectional rewrites, ordered sets, guards, named rules
- [Selection](transformations/selection.md) — selection operator, focus/match,
  state selection, root selection
- [Inference](transformations/inference.md) — inference operator, bounded
  search, witnesses

### [Compute and Operators](compute/index.md)

Arithmetic and reduction operations inside backtick scopes. Covers integer and
float arithmetic, boolean comparison, meta-compute, imaginary and quaternion
forms, symbolic (non-computed) forms, and a complete operator reference.

- [Compute Scope](compute/compute-scope.md) — supported reductions, eval option
- [Integer Arithmetic](compute/integer-arithmetic.md)
- [Float Arithmetic](compute/float-arithmetic.md)
- [Boolean and Comparison](compute/boolean-comparison.md)
- [Meta-Compute Operator](compute/meta-compute-operator.md) — `~` tilde
- [Imaginary and Quaternion Forms](compute/imaginary-quaternion.md)
- [Symbolic and Non-Computed Forms](compute/symbolic-non-computed-forms.md)
- [Operator Reference](compute/operator-reference.md) — arithmetic, boolean/
  comparison, structural operators

### [Working With Data](data/index.md)

Data-oriented features: lists and sequences, variables and bindings, local
scopes, namespaces and packages, selection witnesses, and rendering structured
output (format strings, JSON).

- [Lists and Sequences](data/lists-sequences.md) — concatenation, ranges,
  explode/implode
- [Variables and Bindings](data/variables-bindings.md) — assignment, CLI set,
  path access
- [Local Scopes](data/local-scopes.md) — global and dotted names, query helpers
- [Namespaces and Packages](data/namespaces-packages.md) — packages and imports,
  include files
- [Selection and Witness Forms](data/selection-witness-forms.md) — witness
  output, proof-oriented data
- [Rendering Structured Output](data/rendering-structured-output.md) — format
  strings, JSON encoding and loading

### [Reference](reference/index.md)

Look-up material: command-line reference, example gallery, test fixture guide,
debugger guide, glossary, and language change log.

- [Command Line](reference/command-line.md) — common options, debugger options,
  matcher and inference options
- [Example Gallery](reference/examples.md) — compute, transform, rule, and data
  examples
- [Test Fixture Guide](reference/test-fixture-guide.md) — args files, filter and
  strict mode
- [Debugger Guide](reference/debugger-guide.md) — breakpoints, stepping,
  postmortem
- [Glossary](reference/glossary.md)
- [Language Change Log](reference/language-change-log.md)

## Current Status

Mantra is under active development. The runtime is validated by a test suite of
370+ fixtures. Some language behavior is stable and well-tested; other areas are
still evolving. This manual documents observable, fixture-backed behavior where
possible and notes when behavior is still subject to change.

For deeper design discussion beyond what the user manual covers, the
`docs/` directory contains 40+ markdown files with architectural notes, node
system design, and operator semantics.

## Building the Manual

This manual is written in Markdown and built with MkDocs. From the repository
root:

```bash
python -m pip install -r requirements-docs.txt
mkdocs serve
```

This starts a live preview server. Open the URL it prints in your browser.

To build static HTML instead:

```bash
mkdocs build
```
