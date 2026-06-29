# Command Line

The Mantra command-line interface controls how source is loaded, evaluated,
inspected, and debugged. You can run Mantra from a file, from standard input,
or interactively in REPL mode.

```bash
Usage: mantra [options] [file]
```

## Quick Start

**From a file** — the standard way to run a Mantra program:

```bash
./bin/mantra program.m
```

**From standard input** — useful for one-line experiments:

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra
```

**Interactive REPL** — for incremental exploration:

```bash
./bin/mantra --interactive
```

**Evaluate an expression** — without writing a file:

```bash
./bin/mantra --eval='+ 1 2 3'
```

## Flag Reference

The complete set of CLI flags, grouped by purpose:

### Running Source

| Flag | Description |
|---|---|
| `--interactive`, `-i` | Start REPL mode (process input incrementally) |
| `--set NAME=EXPR` | Predefine a variable before execution (repeatable) |
| `--package-root PATH` | Add an external package search root (repeatable) |
| `--help` | Show help and exit |

`--package-root` accepts either `--package-root PATH` or
`--package-root=PATH`. The path directly contains logical package paths. For
example, `import acme/http` checks `PATH/acme/http.m` and
`PATH/acme/http/package.m`. Project-local `packages/` directories take
precedence; external roots are searched in command-line order.

### Evaluation Setup

| Flag | Description |
|---|---|
| `--eval`, `-e` | Evaluate output before printing |
| `--eval=EXPR` | Append and run `print { EXPR }` |

### Output Inspection

| Flag | Description |
|---|---|
| `--raw` | Print unformatted `TreeValue` output |
| `--debug`, `-d` | Print every statement output (debug mode) |
| `--debug-ir` | Print parser-friendly IR for each non-output statement |
| `--show-input` | Show input lines prefixed with `>` |
| `--show-tokens` | Show tokenizer output during compile |

### Debugger Support

| Flag | Description |
|---|---|
| `--debugger` | Attach debugger event recorder (experimental) |
| `--debugger-cli` | Enter debugger command loop on exceptions |
| `--debugger-postmortem` | Print debugger stack/events on exceptions |
| `--break-callable NAME` | Break when callable `NAME` is about to dispatch |
| `--break-statement TEXT` | Break when a statement matching `TEXT` is about to execute |
| `--break-source SPEC` | Break on source location (`LINE` \| `FILE:LINE` \| `FILE:LINE:COL`) |
| `--break-rule TEXT` | Break when a rule matching `TEXT` probes successfully |
| `--break-inference TEXT` | Break when an inference state matching `TEXT` is entered |

### Rewrite and Proof Controls

| Flag | Description |
|---|---|
| `--head-dispatch` | Enable implicit rule dispatch for `{ head ... }` forms (default) |
| `--no-head-dispatch` | Disable implicit rule dispatch |
| `--backtracking` | Enable matcher backtracking for infix `--` patterns |
| `--no-guards` | Disable matcher rule guards (experimental) |
| `--event-log[=modes]` | Emit matcher events to stdout (modes: `diag`, `trace`, `json`, `text`; comma-separated combinations) |
| `--beam-width N` | Beam width for `\|=` proof search (default: 1) |
| `--congruence-budget N` | Max sub-expression rewrites in `\|=` (default: unlimited) |

## Combining Flags

Flags can be combined freely. Common patterns:

```bash
# Debug with full token and IR visibility
./bin/mantra --debug --show-tokens --debug-ir program.m

# Predefine variables and evaluate
./bin/mantra --set n=5 --set rules='[ x => x + 1 ]' --eval program.m

# Inference with controlled search
./bin/mantra --beam-width 3 --congruence-budget 2 program.m

# Matcher event tracing in JSON
./bin/mantra --event-log=trace,json program.m
```

## Detailed Pages

Each flag group has a dedicated page with examples and edge cases:

- **[Common Options](command-line/common-options.md)** — Input files, REPL,
  evaluation flags, output inspection, and help.
  - [Input Files and REPL](command-line/common-options/input-files-repl.md)
  - [Evaluation and Variables](command-line/common-options/evaluation-variables.md)
  - [Package Root](command-line/common-options/package-root.md)
  - [Output Inspection](command-line/common-options/output-inspection.md)
  - [Help Flag](command-line/common-options/help-flag.md)

- **[Debugger Options](command-line/debugger-options.md)** — Debugger modes,
  breakpoints, and postmortem analysis.
  - [Debugger Modes](command-line/debugger-options/debugger-modes.md)
  - [Breakpoint Flags](command-line/debugger-options/breakpoint-flags.md)
  - [Postmortem Flag](command-line/debugger-options/postmortem-flag.md)

- **[Matcher and Inference Options](command-line/matcher-inference-options.md)**
  — Dispatch flags, matcher controls, event logs, and inference budgets.
  - [Dispatch Flags](command-line/matcher-inference-options/dispatch-flags.md)
  - [Matcher Controls](command-line/matcher-inference-options/matcher-controls.md)
  - [Event Log Flag](command-line/matcher-inference-options/event-log-flag.md)
  - [Inference Budget Flags](command-line/matcher-inference-options/inference-budget-flags.md)

## Building Mantra

To build from source:

```bash
mkdir -p bin build
fpc mantra.lpr -FEbin -FUbuild -Fusrc -Px86_64 -Mobjfpc -S2cahi -O1 -gw3 -v0
```

See [Getting Started](../getting-started/index.md) for a full build and run guide.

## Test Runner

To run the fixture-based test suite:

```bash
tests/run.sh
```

Useful options:

```bash
tests/run.sh --no-build     # Run without rebuilding
tests/run.sh --strict       # Exact output match mode
tests/run.sh --filter <name> # Filter tests by name
```
