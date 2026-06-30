# Common Options

Common runtime options cover input, evaluation, output inspection, and help.
They apply to every invocation regardless of whether Mantra is running a file,
reading stdin, or sitting in interactive REPL mode.

## Quick Reference

| Option | Alias | Category |
|---|---|---|
| `--interactive` | `-i` | Input |
| `--raw` | — | Output |
| `--debug` | `-d` | Output |
| `--debug-ir` | — | Output |
| `--show-input` | `--input` | Output |
| `--show-tokens` | — | Output |
| `--eval` | `-e` | Evaluation |
| `--eval=EXPR` | — | Evaluation |
| `--set NAME=EXPR` | — | Evaluation |
| `--help` | — | Help |
| `--package-root` | — | Input |

**Deprecated:** `--print` / `-p` (alias for `--debug` / `-d`)

## Input Modes

Mantra accepts source from three channels:

```bash
# File input
mantra program.m

# Standard input (pipe)
echo '[ + 1 2 3 ]' | mantra

# Explicit stdin
mantra -

# Interactive REPL
mantra --interactive
```

When no file argument and no flags are given, Mantra detects whether stdin is
redirected. If stdin is a terminal (not redirected), it prints `--help` and
exits. If stdin is redirected, it reads from it automatically.

See [Input Files and REPL](common-options/input-files-repl.md) for the full
interactive editor and line-recall behavior.

## Evaluation and Variables

The `--eval` family controls whether output is evaluated and lets you inject
expressions or predefine variables from the command line.

```bash
# Evaluate output before printing
mantra --eval program.m

# Append and run an expression
mantra --eval='+ 1 2'

# Predefine variables (repeatable)
mantra --set x=5 --set y=hello program.m
```

Both `--set` and `--eval=` accept the `--flag=value` syntax with the `=` sign
or a separate argument:

```bash
mantra --set x=5    # compact form
mantra --set x=5    # space-separated form
```

You can repeat `--set` and `--eval=` multiple times on a single invocation.

See [Evaluation and Variables](common-options/evaluation-variables.md) for
examples and variable scoping details.

## Output Inspection

These flags expose the parser, formatter, and execution pipeline for debugging.

```bash
# Unformatted TreeValue output (no pretty-printing)
mantra --raw program.m

# Print every statement output
mantra --debug program.m

# Parser-friendly IR for non-output statements
mantra --debug-ir program.m

# Show input lines prefixed with ">"
mantra --show-input program.m

# Show tokenizer output during compile
mantra --show-tokens program.m
```

`--show-input` is also accepted as `--input`.

**Deprecated:** `--print` and `-p` behave like `--debug` / `-d` but emit a
deprecation warning. Use `--debug` / `-d` instead.

See [Output Inspection](common-options/output-inspection.md) for more detail
on each flag and example output.

## Help

```bash
mantra --help
```

Prints the complete option list from the local binary. This is the quickest way
to verify available flags after pulling changes or switching branches.

See [Help Flag](common-options/help-flag.md).

## Package Search Roots

The `--package-root` flag adds external directories to the package search
path. Use it when your project imports packages that live outside the local
`packages/` directory.

```bash
# Single external root
mantra --package-root /opt/mantra-pkgs program.m

# Multiple roots (searched in order)
mantra --package-root /opt/mantra-pkgs --package-root ~/my-pkgs program.m

# Compact form
mantra --package-root=/opt/mantra-pkgs program.m
```

Project-local `packages/` directories always take precedence. External roots
are searched in the order they appear on the command line.

See [Package Root](common-options/package-root.md) for import resolution
details and examples.

## Combining Flags

Common options can be combined freely with other flag categories. Examples:

```bash
# Debug with variable injection
mantra --debug --set n=10 program.m

# Tokenize and evaluate output
mantra --show-tokens --eval program.m

# Raw output with inline expression
mantra --raw --eval='[ 1 2 3 ]'
```

For debugger-specific flags (`--debugger`, `--break-*`, etc.), see
[Debugger Options](../debugger-options.md).

For matcher and inference flags (`--backtracking`, `--event-log`, etc.), see
[Matcher and Inference Options](../matcher-inference-options.md).
