# Reference and Practice

This section collects lookup-oriented material: command-line flags, executable
examples, debugging workflows, test conventions, and a glossary of Mantra
terms. Use these pages when you need a specific fact, flag, or pattern rather
than a conceptual explanation — those belong in the earlier manual sections.

## Command Line

Reference for all Mantra CLI flags and runtime options.

**Common options** — input, variables, output modes, and help:
- [Input Files and REPL](command-line/common-options/input-files-repl.md) —
  file arguments, stdin, and `--interactive` mode
- [Evaluation and Variables](command-line/common-options/evaluation-variables.md) —
  `--eval`, `--set`, and runtime variable injection
- [Output Inspection](command-line/common-options/output-inspection.md) —
  `--debug`, `--raw`, `--show-tokens`
- [Help Flag](command-line/common-options/help-flag.md) — `--help` and
  auto-help behavior

**Debugger options** — breakpoints, stepping, and postmortem analysis:
- [Debugger Modes](command-line/debugger-options/debugger-modes.md) —
  `--debugger`, `--debugger-cli`, `--debugger-postmortem`
- [Breakpoint Flags](command-line/debugger-options/breakpoint-flags.md) —
  `--break-source`, `--break-callable`, `--break-statement`, `--break-rule`,
  `--break-inference`
- [Postmortem Flag](command-line/debugger-options/postmortem-flag.md) —
  `--postmortem` and exception snapshots

**Matcher and inference options** — rewrite control and proof search:
- [Dispatch Flags](command-line/matcher-inference-options/dispatch-flags.md) —
  `--head-dispatch`, `--no-head-dispatch`
- [Matcher Controls](command-line/matcher-inference-options/matcher-controls.md) —
  `--backtracking`, `--no-guards`
- [Event Log Flag](command-line/matcher-inference-options/event-log-flag.md) —
  `--event-log` for detailed matcher tracing
- [Inference Budget Flags](command-line/matcher-inference-options/inference-budget-flags.md) —
  `--beam`, `--congruence-budget`, `--inference-steps`

See the overview at [Command Line](command-line.md) for the quick-start and
full usage summary.

## Example Gallery

Runnable examples with expected output, sourced from real test fixtures.

- [Compute Examples](examples/compute-examples.md) — arithmetic, meta-compute,
  tilde operator, and nested compute scopes
- [Transform Examples](examples/transform-examples.md) — repeat, selection,
  inline transforms, and equivalence rules
- [Rule Examples](examples/rule-examples.md) — pattern matching, captures,
  guards, named rules, and bidirectional rewrites
- [Data Examples](examples/data-examples.md) — variables, concatenation,
  ranges, explode/implode, and packages

See the overview at [Example Gallery](examples.md) for quick-start examples.

## Test Fixture Guide

How Mantra's fixture-based test system works — format, runner, conventions,
and maintenance workflows.

- [Args Files](test-fixture-guide/args-files.md) — `.args` files for
  per-case CLI flags
- [Filter and Strict Mode](test-fixture-guide/filter-strict.md) —
  `--filter` and `--strict` runner options

See the overview at [Test Fixture Guide](test-fixture-guide.md) for the
fixture format and execution model.

## Debugger Guide

Debugging Mantra programs at runtime — breakpoints, stepping, postmortem
analysis, and interactive commands.

- [Breakpoints](debugger-guide/breakpoints.md) — source, callable, statement,
  rule, and inference breakpoints
- [Stepping](debugger-guide/stepping.md) — step-into, step-over, and
  continue controls
- [Postmortem Debugging](debugger-guide/postmortem.md) — exception snapshots,
  postmortem reports, and CI/CD integration

See the overview at [Debugger Guide](debugger-guide.md) for quick-start
debugging workflows.

## Glossary

Alphabetical reference of Mantra terms: AST nodes, operators, meta flags,
scope types, VMT dispatch, inference concepts, and more.

See [Glossary](glossary.md).

## Language Change Log

Reserved for user-facing language changes: syntax updates, operator behavior
changes, runtime output differences, and migration notes.

See [Language Change Log](language-change-log.md).

## LLM Context

The `LLM_CONTEXT.md` file at the project root gives language models a
self-contained overview of the Mantra project — structure, source files,
conventions, and documentation layout.

See [LLM_CONTEXT.md](llm-context.md).

## Quick Reference: CLI Flags

| Flag | Purpose | See |
|---|---|---|
| `--help` | Show usage and exit | [Help Flag](command-line/common-options/help-flag.md) |
| `--interactive` | Start REPL mode | [Input Files and REPL](command-line/common-options/input-files-repl.md) |
| `--debug` | Print every statement output | [Output Inspection](command-line/common-options/output-inspection.md) |
| `--raw` | Unformatted TreeValue output | [Output Inspection](command-line/common-options/output-inspection.md) |
| `--show-tokens` | Show tokenizer output | [Output Inspection](command-line/common-options/output-inspection.md) |
| `--eval=EXPR` | Append and run expression | [Evaluation and Variables](command-line/common-options/evaluation-variables.md) |
| `--set name=value` | Pre-define a variable | [Evaluation and Variables](command-line/common-options/evaluation-variables.md) |
| `--debugger-cli` | Interactive debugger | [Debugger Modes](command-line/debugger-options/debugger-modes.md) |
| `--postmortem` | Exception snapshot (non-interactive) | [Postmortem Flag](command-line/debugger-options/postmortem-flag.md) |
| `--break-source=FILE:LINE` | Source breakpoint | [Breakpoint Flags](command-line/debugger-options/breakpoint-flags.md) |
| `--break-callable=NAME` | Callable breakpoint | [Breakpoint Flags](command-line/debugger-options/breakpoint-flags.md) |
| `--head-dispatch` | Head dispatch (default) | [Dispatch Flags](command-line/matcher-inference-options/dispatch-flags.md) |
| `--backtracking` | Enable infix `--` backtracking | [Matcher Controls](command-line/matcher-inference-options/matcher-controls.md) |
| `--beam N` | Inference beam width | [Inference Budget Flags](command-line/matcher-inference-options/inference-budget-flags.md) |

## Cross-References

Conceptual background for the topics above lives in these earlier manual
sections:

- [Language Model](../language-model/index.md) — programs as trees, evaluation
  model, rewriting and transformation
- [Syntax](../syntax/index.md) — tokens, scope nodes, operators, and
  declarations
- [Evaluation and Execution](../evaluation/index.md) — evaluation scopes,
  execution order, output formatting
- [Transformations and Repeat](../transformations/index.md) — repeat operator,
  pattern matching, selection, inference
- [Compute and Operators](../compute/index.md) — compute scopes, arithmetic,
  boolean and comparison operators
- [Working With Data](../data/index.md) — lists, variables, packages, and
  structured output
