# Input Files and REPL

Mantra can read source from a file, from standard input, or incrementally in
interactive REPL mode. The runtime decides which channel to use based on
command-line arguments and the state of the stdin file descriptor.

## Input Modes

### File Input

```bash
./bin/mantra program.m
```

Passes a file path as a positional argument. Mantra opens the file and reads
all lines, compiling each statement chunk as it encounters statement boundaries.

Use file input for multi-statement programs, packages, imports, debugger
breakpoints, and examples that should be committed as test fixtures.

When the file cannot be opened, the runtime reports a file handling error:

```
File handling error occurred. Details: <message>
```

Only one positional file argument is accepted. A second positional argument
raises:

```
Unexpected argument: <value>
```

### Standard Input (Pipe / Redirect)

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra
```

Use standard input for small one-line examples and pipeline-driven workflows.

Mantra automatically detects redirected stdin. When no file argument is given
and stdin is not a terminal device, it reads from stdin without requiring any
flags. Internally the runtime checks whether the stdin file descriptor points
to a character device (`isatty`); if not, it treats it as redirected.

### Explicit stdin with `-`

```bash
./bin/mantra -
```

The positional `-` argument tells Mantra to read from stdin regardless of
whether it is a terminal. Use this when you want to make the stdin dependency
explicit in scripts or when chaining commands.

Only one `-` argument is allowed; a second positional argument raises:

```
Unexpected argument: -
```

## `--interactive` and `-i` (REPL Mode)

```bash
./bin/mantra --interactive
./bin/mantra -i
```

Interactive mode processes input incrementally: each statement is compiled and
executed as soon as the runtime detects a complete statement boundary.

Use REPL mode for exploration, debugging, and interactive experimentation. For
documented, reproducible behavior, use test fixtures instead.

### REPL Prompts

```
mantra>    — statement is complete; enter a new expression
...>       — waiting for more input (unbalanced delimiters)
```

The prompt changes when the runtime detects unbalanced parentheses `()`,
brackets `[]`, or braces `{}`. It also tracks strings `"..."`, backtick scopes
`` `...` ``, apostrophe scopes `'...'`, and block comments `(* ... *)`.

### Terminal Line Editor

When attached to a terminal, the REPL activates a built-in line editor:

| Key | Action |
|---|---|
| Up arrow | Recall older input from history |
| Down arrow | Move forward toward newer input or blank draft |
| Left arrow | Move cursor left within current line |
| Right arrow | Move cursor right within current line |
| Backspace / Delete | Remove character at cursor |
| Ctrl-D | Exit REPL when line is empty; otherwise no effect |
| Ctrl-C | Cancel current line and return to prompt |

### Non-Terminal Input

When stdin is redirected or piped, Mantra skips the terminal line editor and
uses plain line-based input instead. This means no history recall or cursor
movement — each line is read sequentially.

### REPL Commands

| Command | Action |
|---|---|
| `:quit` / `.quit` | Exit the REPL |
| `:exit` / `.exit` | Exit the REPL (alias) |
| `:help` / `.help` | Print available REPL commands |

These commands are recognized only when the input is at a statement boundary
(the line is not inside unbalanced delimiters).

### File Input with `--interactive`

When a file argument is given together with `--interactive`, Mantra first
compiles and executes the file, then enters the interactive loop. This lets
you load a program and continue working in the same runtime context:

```bash
./bin/mantra --interactive program.m
```

### Pre-defined Variables in REPL

`--set` variables are compiled and executed before the REPL prompt appears.
They persist as context variables throughout the session:

```bash
./bin/mantra --interactive --set x=42
```

The variable `x` is available immediately when the interactive prompt starts.

### Eval Expressions in REPL

`--eval=` expressions run after `--set` variables but are executed within the
interactive loop so each expression's errors are caught individually:

```bash
./bin/mantra --interactive --set n=5 --eval='+ n 1'
```

## Execution Order

When multiple input sources and flags are present, the runtime processes them
in this order:

1. Parse all CLI flags (`--set`, `--eval=`, etc.)
2. Initialize `--set` variables (compile and execute before anything else)
3. Read source file (if given as positional argument)
4. Read stdin (if `-`, `/dev/stdin`, or auto-detected redirect)
5. Run `--eval=` expressions (each wrapped as `print { EXPR }`)
6. Enter REPL loop (if `--interactive`)

In non-interactive mode, steps 2-5 compile all source first, then execute
everything in one pass. In interactive mode, each step compiles and executes
immediately.

## Default Behavior Summary

| Condition | Result |
|---|---|
| File argument given | Reads from file |
| No arguments, stdin redirected | Reads from stdin |
| No arguments, stdin is terminal | Prints help and exits |
| `-` argument | Reads from stdin explicitly |
| `--interactive` | Enters REPL mode (loads file first if given) |

## Statement Boundaries

The runtime groups lines into chunks based on delimiter balance. A chunk is
compiled when all of these are true:

- All parentheses `()` are balanced
- All brackets `[]` are balanced
- All braces `{}` are balanced
- Not inside a string literal `"..."`
- Not inside a backtick scope `` `...` ``
- Not inside an apostrophe scope `'...'`
- Not inside a block comment `(* ... *)`

Lines containing `//` start a line comment; the rest of the line is ignored
for balancing purposes.

## Error Handling

### Unknown Options

```
Unknown option: --foo
```

Any flag starting with `-` that the runtime does not recognize raises an error.

### Missing File Arguments

If `--set`, `--eval=`, `--congruence-budget`, `--beam-width`, or any
`--break-*` flag expects a value but none follows, the runtime raises a
specific missing-value error.

## Internal Behavior

The input handling code lives in these files:

- `mantra.lpr` — CLI argument parsing (`Bootstrap` procedure)
- `src/mathparser.pas` — Input routing, statement boundary detection, REPL loop
  (`Execute` procedure with `TRunOptions`)
- `src/parsetree.pas` — Statement compilation and execution loop
  (`TExecutable`)
- `src/repl_input.pas` — Terminal line editor, history, raw mode toggling
  (`ReadInteractiveLine`)
- `src/exp_tokenizer.pas` — Tokenizer (called per-chunk)
- `src/context.pas` — Runtime variable context (stores `--set` bindings)

The `TRunOptions` record carries all flags through the pipeline:

- `Interactive` — enables REPL mode
- `Raw` — unformatted output
- `DebugOutput` — print every statement
- `DebugIR` — print IR for non-output statements
- `ShowInput` — prefix input lines with `>`
- `ShowTokens` — show tokenizer output
- `EvalOutput` — evaluate output before printing
- `SetAssignments` — array of `--set` specifications
- `EvalExpressions` — array of `--eval=` expressions

## See Also

- [Common Options](common-options.md) — Overview of all runtime flags
- [Output Inspection](common-options/output-inspection.md) — `--raw`, `--debug`,
  `--show-input`, `--show-tokens`, `--eval`
- [Evaluation and Variables](common-options/evaluation-variables.md) — `--set`
  and `--eval=` in detail
- [CLI Set](../../data/variables-bindings/cli-set.md) — `--set` with examples
- [Help Flag](common-options/help-flag.md) — `--help` output
- [Test Fixture Args Files](../../reference/test-fixture-guide/args-files.md) —
  Using `.args` files to pass flags to test cases
