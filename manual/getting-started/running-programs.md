# Running Programs

The `bin/mantra` executable accepts source code from standard input, from a file,
or interactively through a built-in REPL. Which method you choose depends on the
size of the program, whether it uses imports, and whether you want to explore
expressions step by step.

## Quick Overview

|| Input Method | Best For |
|---|---|---|
| **Standard Input** | One-liners, shell pipelines, quick tests | `echo '...' \| mantra` |
| **File Input** | Multi-statement programs, imports, debugging | `mantra program.m` |
| **Interactive (REPL)** | Exploring expressions, learning the language | `mantra --interactive` |

## Standard Input

Pipe source code to `bin/mantra` for quick validation without creating a file:

```bash
echo '[ { 1 2 3 : 4 } ]' | mantra
```

Mantra automatically detects redirected stdin — no special flag is required.
When no positional argument is given and stdin is not connected to a terminal,
the runtime reads from it directly.

For heredocs (multi-line input):

```bash
mantra <<'EOF'
x = [ 1 2 3 ]
x ? [ y => y + 1 ]
EOF
```

Always use a **single-quoted delimiter** (`<<'EOF'`) to prevent the shell from
expanding variables or interpreting backticks inside the heredoc body.

For details, see [Standard Input](running-programs/standard-input.md).

## File Input

Pass a file path as a positional argument for larger programs:

```bash
mantra program.m
```

Only one positional file argument is accepted. File input provides full source
location information — parser errors include file path and line number, and
source-level breakpoints (`--break-source`) work correctly.

Save a multi-statement program:

```mantra
x = [ 1 2 3 ]
y = x ? [ a => a * 2 ]
print y
```

Then run it:

```bash
mantra double.m
```

File input is required for programs that use `import` or `include` directives,
because the runtime needs a file path to resolve relative references.

For details, see [File Input](running-programs/file-input.md).

## Interactive Mode (REPL)

Mantra includes a built-in read-eval-print loop for exploring expressions
interactively:

```bash
mantra --interactive
```

At the `mantra> ` prompt, type expressions and press Enter to evaluate them:

```
mantra> ` + 1 2 3 `
+ 6
mantra> x = [ 1 2 3 ]
x = [ 1 2 3 ]
mantra> x ? [ y => y * 2 ]
[ 2 4 6 ]
mantra> :quit
```

Each line is parsed, executed, and printed before accepting the next one.
Multi-line expressions prompt with `...> ` until all delimiters are closed.
Type `:quit` or `:exit` to leave the REPL.

### Load a File, Then Explore

Combine `--interactive` with a file to load definitions and then explore:

```bash
mantra --interactive program.m
```

The file is compiled and its statements execute first. Then the REPL prompt
appears with all variables and definitions from the file available.

### REPL with Pre-defined Variables

```bash
mantra --interactive --set n=10
```

The `--set` variables are available immediately in the REPL session.

## Shell Quoting

Mantra uses backticks (` ` `) for compute scope. Most shells use backticks for
command substitution. If the shell intercepts the backticks before Mantra
receives the source, the program will fail or produce unexpected results.

**Always wrap piped programs containing backticks in single quotes:**

```bash
# Correct — Mantra receives the backticks
echo '`[ + 1 2 3 ] : 3`' | mantra

# Incorrect — shell interprets backticks before Mantra
echo "`[ + 1 2 3 ] : 3`" | mantra
```

Single quotes prevent all shell interpretation — no variable expansion, no
command substitution, no escape sequences. This is the single most common
source of confusion for new users.

For full details, see [Shell Quoting](running-programs/shell-quoting.md).

## Combining with CLI Flags

All input methods work with command-line flags. The most useful combinations:

### Pre-defined Variables (`--set`)

```bash
echo 'x * 2' | mantra --set x=21
```

Output: `42`

The `--set` variables are compiled and executed before the program runs, so they
are available immediately. The flag is repeatable — you can pass multiple
`--set` arguments.

### Eval Expressions (`--eval=`)

```bash
echo 'x = 5' | mantra --eval='x + 10'
```

The `--eval=` expressions run after the program is fully processed. They are
each wrapped as `print { EXPR }` and executed in the same runtime context.

### Debug Output (`--debug`)

```bash
echo '[ { 1 2 3 : 4 } ]' | mantra --debug
```

Prints the output after every statement, useful for tracing multi-statement
programs where you want to see intermediate results.

### Raw Output (`--raw`)

```bash
echo '[ + 1 2 3 ]' | mantra --raw
```

Prints unformatted `TreeValue` output instead of the default formatted tree.
Useful for scripting output parsing where you need a stable representation.

## Execution Order

When flags are present, the runtime processes everything in this order:

1. Parse CLI flags (`--set`, `--eval=`, etc.)
2. Initialize `--set` variables (compile and execute)
3. Read and compile the program (stdin or file)
4. Execute compiled statements
5. Run `--eval=` expressions

This means `--set` variables are always available in your program, and
`--eval=` expressions can reference variables defined in the program.

## Error Handling

### File Not Found

```bash
mantra nonexistent.m
```

```
File handling error occurred. Details: File not found.
```

### Parse Errors

Syntax errors are raised as exceptions during tokenization or parsing. When
using file input, the error message includes the file path and line number.

### Shell Quoting Errors

If the shell interprets backticks before Mantra receives them:

```bash
$ echo "`[ + 1 2 3 ] : 3`" | mantra
bash: [ + 1 2 3 ] : 3: command not found
```

The fix is to use single quotes instead of double quotes.

## When to Use Each Method

### Prefer Standard Input When:

- The example fits on one line or a small heredoc
- You want to quickly reproduce a behavior for a bug report
- You are chaining commands in a shell pipeline
- You are validating output against a test fixture

### Prefer File Input When:

- The program spans multiple statements or definitions
- The program uses `import` or `include` directives
- You want to use source-level breakpoints (`--break-source`)
- The program is part of a larger project with multiple source files
- You are debugging and need file-referenced error messages
- You want to load a program and then explore interactively

### Prefer Interactive Mode When:

- You are learning the language and want to experiment
- You want to test small changes without rewriting files
- You need to inspect intermediate variable states
- You are exploring how operators and transforms behave

## See Also

- [Standard Input](running-programs/standard-input.md) — Piping source via stdin (detailed)
- [File Input](running-programs/file-input.md) — Running from a file (detailed)
- [Shell Quoting](running-programs/shell-quoting.md) — Backtick and quote handling
- [Building the Runtime](building-the-runtime.md) — Compiling from source
- [Reading Runtime Output](reading-runtime-output.md) — Understanding output sections
- [Print Statements](reading-runtime-output/print-statements.md) — Explicit output control
- [Debug Output Modes](reading-runtime-output/debug-output-modes.md) — `--debug`, `--raw`, `--show-tokens`
- [Command Line](../reference/command-line.md) — Full CLI reference
- [Test Fixture Guide](../reference/test-fixture-guide.md) — `.in` files as programs
