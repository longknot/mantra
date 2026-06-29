# Eval Option

The `--eval=EXPR` CLI flag appends an expression to the program and runs it
after all source code is processed. The boolean `--eval` (or `-e`) flag
re-evaluates output before printing — a separate but related feature.

## Quick Start

```bash
# Append and run an expression
./bin/mantra --eval='+ 1 2'
```

This wraps the expression as `print { EXPR }` and runs it after all source
code, producing the evaluated result.

## `--eval=EXPR` — Append and Run

### What It Does

For each `--eval=EXPR` argument, the runtime appends:

```mantra
print { EXPR }
```

These statements are compiled after all source code (file or stdin) and after
all `--set` assignments, then executed together. This means `--eval=EXPR` can
reference variables defined in the program.

### Basic Example

```bash
echo 'x = [ + 1 2 3 ]' | ./bin/mantra --eval='x'
```

Output:

```text
[ + 1 + 2 + 3 ]
```

The expression `x` resolves to the stored tree snapshot and prints it. The
output is `[ + 1 + 2 + 3 ]` (not computed) because `{ }` is an evaluation
scope, not a compute scope.

### With Compute Scope

To trigger arithmetic reduction, wrap the expression in backticks:

```bash
echo 'x = [ + 1 2 3 ]' | ./bin/mantra --eval='`x`'
```

Output:

```text
[ + 6 ]
```

### Multiple Eval Expressions

You can use `--eval=EXPR` multiple times. Each expression is wrapped
independently in `print { ... }` and they run sequentially:

```bash
echo '' | ./bin/mantra --eval='+ 1 2' --eval='* 3 4'
```

Output:

```text
+ 1 2
* 3 4
```

### Variables from Source and --set

`--eval=EXPR` runs after all source code and `--set` assignments. It can
access any variable defined before it:

```bash
echo 'y = 20' | ./bin/mantra --set 'x=10' --eval='`x + y`'
```

Output:

```text
10 + 20
```

Execution order is:

1. Parse CLI flags (`--set`, `--eval=`, etc.)
2. Apply `--set` assignments (each wrapped as `. NAME=EXPR`)
3. Compile and execute source (file or stdin)
4. Run `--eval=` expressions (each wrapped as `print { EXPR }`)

## `--eval` / `-e` — Evaluate Output Before Printing

The boolean `--eval` flag (short form `-e`) sets `EvalOutput`. It tells the
runtime to run an additional evaluation pass on output before it is printed.
This is distinct from `--eval=EXPR` — the flag takes no argument.

```bash
# Evaluate output before printing (no expression appended)
./bin/mantra --eval program.m

# Combined with --eval=EXPR
./bin/mantra --eval --eval='+ 1 2'
```

The `--eval` flag is useful when output contains evaluation scopes that should
be resolved further before display. See
[Debug Output Modes](../getting-started/reading-runtime-output/debug-output-modes.md)
for details on `--eval`/`-e`.

## How the Wrapping Works

The source code implementation in `mantra.lpr` and `mathparser.pas` makes this
explicit:

- `IsEvalExprArg(arg)` checks if an argument starts with `--eval=`
- `AddEvalExpression` extracts everything after `--eval=` and stores it
- During `Execute`, each stored expression is wrapped as
  `print { <expr> }` and compiled

This means:

- The expression is always printed (the `print` keyword is added)
- The expression is evaluated in `{ }` scope (variable resolution, nested scope
  processing) but NOT computed — use `` ` ` `` for arithmetic reduction
- Each `--eval=EXPR` gets its own `print { }` wrapper

## Error Handling

```bash
# Empty expression — rejected
./bin/mantra --eval=''
```

Output:

```text
Error: Invalid --eval=EXPR argument: missing expression
```

```bash
# No input source — shows help
./bin/mantra --eval='+ 1 2'
```

Output:

```text
Usage: mantra [options] [file]
...
```

`--eval=EXPR` requires an input source (file, stdin, or `-` for stdin). When
no input is provided and no file is specified, the runtime shows help.

## Common Patterns

### Quick Arithmetic

```bash
echo '' | ./bin/mantra --eval='` + 10 20 30 `'
```

Output:

```text
+ 60
```

### Inspecting Variables

```bash
echo 'x = [ 1 2 3 ]' | ./bin/mantra --eval='x'
```

Output:

```text
[ 1 2 3 ]
```

### Combining with --set

```bash
echo '' | ./bin/mantra --set 'n=5' --set 'm=3' --eval='`n * m`'
```

Output:

```text
15
```

### Pipeline Experiments

Use `--eval=EXPR` to test expressions against a program's variable state:

```bash
./bin/mantra program.m --eval='result'
./bin/mantra program.m --eval='`result + 1`'
./bin/mantra program.m --eval='`result * 2`'
```

## When to Use --eval vs. Other Approaches

| Scenario | Approach |
|---|---|
| Quick expression test | `--eval=EXPR` |
| Multi-line program with setup | File input or stdin |
| Pre-define variables | `--set NAME=EXPR` |
| Debug intermediate state | `--debug` or `--debugger` |
| Additional evaluation pass | `--eval` / `-e` (boolean flag) |

Use `--eval=EXPR` for small command-line experiments. Use file input or
fixture input when the expression needs setup statements.

## See Also

- [Compute Scope](compute-scope.md) — Backtick-delimited blocks for arithmetic
  reduction
- [Supported Reductions](compute-scope/supported-reductions.md) — Full list of
  reduction families
- [Running Programs](../getting-started/running-programs.md) — File input,
  stdin, and CLI flags
- [Debug Output Modes](../getting-started/reading-runtime-output/debug-output-modes.md) —
  `--eval`/`-e` flag for output re-evaluation
- [CLI --set](../data/variables-bindings/cli-set.md) — Predefining variables
  before execution
