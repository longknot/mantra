# Mantra
![image](manual/assets/mantra-frog.png)


**An experimental tree-first programming language for structural rewriting,
symbolic computation, and bounded inference.**

In Mantra, syntax trees are not hidden compiler artifacts. They are the
language's primary values and execution model. Programs construct, match,
rewrite, repeat, evaluate, and search over tree structures using explicit
scopes and transformation rules.

> [!IMPORTANT]
> Mantra is alpha research software. The core runtime is operational and
> extensively fixture-tested, but parts of the language model remain under
> active design. Expect breaking changes.

## A Structural Rewrite

This program matches a two-element tree and rewrites it by exchanging its
children:

```mantra
print { [ 1 2 ] ? [ [ x y ] => [ y x ] ] }
```

```text
[ 2 1 ]
```

`[ 1 2 ]` is the subject, `[ x y ]` is the structural pattern, and `[ y x ]`
is the replacement. The `?` operator selects a matching rule and rewrites the
subject tree.

Rules can also express bidirectional equivalence:

```mantra
print { [ 1 2 ] ? [ [ x y ] <=> [ y x ] ] }
print { [ 2 1 ] ? [ [ x y ] <=> [ y x ] ] }
```

```text
[ 2 1 ]
[ 1 2 ]
```

This behavior is covered by the
[bidirectional selection fixture](tests/cases/equivalence_bidirectional_selection.in).

## Bounded Inference

Mantra can ask whether one tree is reachable from another through a set of
rewrite rules:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

```text
1
```

The query succeeds because `1` can be rewritten to `2`, then to `3`, within
the two-step bound. Inference can return either a Boolean result or a
materialized witness describing the discovered path.

See the [bounded inference fixture](tests/cases/inference_bounded_implies_true.in)
and the [inference manual](manual/transformations/inference.md).

## Why Mantra?

Mantra explores a programming model in which structural transformation is a
language primitive rather than a library technique.

- **Trees are visible values.** Programs and structured data use the same
  runtime representation.
- **Evaluation boundaries are explicit.** Different scope forms determine
  whether a subtree is grouped, evaluated, computed, or preserved.
- **Pattern matching rewrites structure.** Rules operate on nodes and their
  relationships rather than on source text.
- **Iteration is transformational.** Repetition and fixpoint forms repeatedly
  expand or rewrite trees.
- **Inference is built in.** Programs can search bounded transformation spaces
  and inspect proof witnesses.
- **Observable behavior is fixture-backed.** The regression suite acts as the
  current executable specification for implemented semantics.

Mantra draws ideas from term-rewriting systems, symbolic algebra, logic and
proof engines, and homoiconic languages. It is not an implementation of any
one of those traditions; it combines them around an explicit mutable-tree
runtime.

## Core Forms

| Form | Role |
|---|---|
| `( ... )` | Groups an expression |
| `[ ... ]` | Constructs a list or structured container |
| `{ ... }` | Evaluates a subtree |
| `` ` ... ` `` | Evaluates and performs supported computation |
| `' ... '` | Preserves fixed, unevaluated structure |
| `pattern => replacement` | Defines a directional transformation |
| `pattern <=> replacement` | Defines a bidirectional transformation |
| `subject ? rules` | Selects and applies a structural rewrite |
| `subject : n` | Repeats or expands a structure |
| `source => target \|= rules` | Searches for a transformation path |

These forms compose. A subject can be evaluated before selection, a rewrite
can occur inside repetition, and inference can search over named rules imported
from packages.

## Current Capabilities

The alpha runtime currently includes:

- structural patterns, captures, match-any sequences, guards, and selectors;
- directional, substitution, and equivalence transformations;
- named rules, head dispatch, ordered rule sets, and package imports;
- bounded repeat, staged repeat, ranges, and fixpoint rewriting;
- exact-name lexical locals through `scope { ... }`;
- tree-valued variables, namespace paths, and trie-backed data operations;
- integer, floating-point, Boolean, comparison, complex, and quaternion
  computation;
- bounded inference, configurable search policies, and witness materialization;
- JSON and YAML loading, structured rendering, and controlled HTTP operations;
- an interactive REPL, event logging, breakpoints, stepping, tree inspection,
  and postmortem debugging;
- HTTP and MCP server entry points for programmatic integration.

The repository also contains experimental packages for symbolic mathematics,
induction-oriented proofs, sorting, data utilities, and visualization.

## Quick Start

### Requirements

- Free Pascal Compiler
- an `x86_64` POSIX-like environment
- Bash for the test runner
- Python 3 for HTTP-backed fixtures and optional documentation tooling

Free Pascal 3.x is the current target. Other architectures and environments
may work, but are not regularly validated.

### Build

From the repository root:

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Fu"vendor/*" \
  -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

The resulting executable is `bin/mantra`.

To build the runtime and both server entry points:

```bash
mkdir -p bin build
./build.sh --all
```

### Run

From standard input:

```bash
echo 'print { [ 1 2 ] ? [ [ x y ] => [ y x ] ] }' | ./bin/mantra --raw
```

From a source file:

```bash
./bin/mantra program.m
```

Start the interactive REPL:

```bash
./bin/mantra --interactive
```

Mantra uses backticks for compute scopes. When running code through a shell,
wrap the complete program in single quotes so the shell does not interpret the
backticks.

## Another Example: Symbolic Rules

The bundled mathematics package contains differentiation rules:

```mantra
import math;

define ddx exp x;
target = * ( exp x ) ( 1 );

print { ddx ( exp x ) ? [ math.ddx_exp ] ? [ math.ddx_self ] }
print { ddx ( exp x ) => target |= [ math.ddx_exp, math.ddx_self ] : 2 }
```

```text
* ( exp x ) * ( 1 )
1
```

The first result is produced by direct structural rewriting. The second asks
the inference engine to verify that the same target is reachable within two
steps. See the [calculus fixture](tests/cases/calculus_ddx_exp.in).

## Testing and Stability

Run the complete fixture suite:

```bash
tests/run.sh
```

Useful variants:

```bash
tests/run.sh --no-build
tests/run.sh --strict
tests/run.sh --filter inference
```

The current alpha tree contains more than 450 fixture cases covering parsing,
evaluation, computation, matching, rewriting, inference, packages, data
operations, and debugging. Server integrations have separate smoke tests:

```bash
tests/server_smoke.sh --no-build
tests/mcp_smoke.sh --no-build
```

Fixture-backed behavior is the closest thing Mantra currently has to an
executable language specification. Features without equivalent regression
coverage should be treated as less stable.

## Project Status

Mantra is suitable for:

- experimenting with term rewriting and structural computation;
- symbolic mathematics and small proof-search problems;
- exploring rules, normalization strategies, and transformation pipelines;
- studying a language where tree mutation is part of the user-visible model;
- controlled local integrations through the CLI, HTTP server, or MCP server.

Mantra is not currently:

- a production-ready general-purpose language;
- a complete or soundness-certified theorem prover;
- a hardened sandbox for untrusted programs;
- source-, package-, protocol-, or binary-compatible across alpha revisions;
- optimized or benchmarked for large-scale proof search and rewrite workloads.

Important current limitations include incomplete inference search, evolving
package metadata and visibility, exact-name-only frame locals, incomplete
debugger provenance, and semantic edge cases around complex rewrites. Read
[KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) before depending on Mantra for a
larger experiment.

## Documentation

The [user manual](manual/index.md) covers:

- [getting started](manual/getting-started.md);
- the [tree-first language model](manual/language-model/index.md);
- [syntax and source forms](manual/syntax/index.md);
- [evaluation and execution](manual/evaluation/index.md);
- [patterns, rules, repeat, and inference](manual/transformations/index.md);
- [computation and operators](manual/compute/index.md);
- [variables, scopes, packages, and structured data](manual/data/index.md);
- the [command-line and debugger reference](manual/reference/index.md).

The manual is built with MkDocs:

```bash
mkdocs serve
```

## Implementation

The runtime is implemented in Free Pascal. Source is tokenized and parsed into
a compact tree whose nodes use a left-child/right-sibling representation.
Runtime node behavior is dispatched through objects mapped from node IDs, while
the underlying tree nodes remain compact 128-bit records.

The implementation is intentionally direct: evaluation expands, replaces,
clones, and deletes nodes in the active tree. This keeps the runtime model close
to the language model, but it also means mutation and structural ownership are
central concerns in the engine.

## Repository Layout

| Path | Contents |
|---|---|
| `src/` | Parser, tree runtime, matcher, inference engine, debugger, and services |
| `tests/cases/` | Fixture inputs and expected outputs |
| `packages/` | Experimental standard and example packages |
| `manual/` | User-facing language documentation |
| `vendor/` | Vendored source dependencies and their licenses |

## Contributing

Bug reports, regression fixtures, documentation corrections, and focused
language or runtime changes are welcome. Semantic proposals should explain the
intended tree behavior and interactions with evaluation, rewriting, scopes,
namespaces, and inference.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the build, test, and submission
workflow.

## Security

Mantra is not a security boundary. Do not execute untrusted Mantra programs or
expose the alpha servers directly to untrusted networks.

Report security-sensitive problems according to [SECURITY.md](SECURITY.md).

## License

Mantra source files are available under the
[Mozilla Public License 2.0](LICENSE), unless a file or directory states
otherwise.

Vendored dependencies remain under their own licenses. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
