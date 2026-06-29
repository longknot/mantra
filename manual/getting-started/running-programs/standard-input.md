# Standard Input

Standard input is the quickest way to run a short Mantra program without
creating a file. Pipe source code to the `bin/mantra` executable and it
executes immediately.

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra
```

Expected output:

```text
[ + 1 + 2 + 3 ]
```

## How Detection Works

Mantra automatically detects redirected stdin — no special flag is required.
When no positional file argument is given, the runtime checks whether the
stdin file descriptor points to a terminal device:

1. If stdin **is** a terminal → prints `--help` and exits.
2. If stdin is **not** a terminal (redirected/piped) → reads from it.

The check uses `fpFStat` on the stdin handle and `FPS_ISCHR` on the
resulting `st_mode` — if the mode indicates a character device, stdin is
treated as an interactive terminal; otherwise it is treated as redirected
input.

In the source (`mantra.lpr`), the `HasRedirectedStdin` function (line 63)
performs this check. The `Bootstrap` procedure (line 471) assigns
`inputPath := '/dev/stdin'` when it detects redirected input.

## Explicit stdin with `-`

Use a positional `-` argument to force stdin input regardless of whether
it is connected to a terminal:

```bash
./bin/mantra -
```

This is useful in scripts where you want to make the stdin dependency
explicit, or when chaining commands where the terminal state is ambiguous.

Only one `-` argument is allowed; a second positional argument raises:

```
Unexpected argument: -
```

## Multi-line Input

For programs that span multiple lines, use a heredoc:

```bash
./bin/mantra <<'EOF'
x = [ 1 2 3 ]
x ? [ y => y + 1 ]
EOF
```

Heredocs are the preferred way to pipe multi-line Mantra programs from the
shell. Use single-quoted delimiters (`<<'EOF'`) to prevent the shell from
expanding variables or interpreting backticks inside the heredoc body.

## Shell Quoting

Mantra uses backticks `` ` `` for compute scope. Most shells use backticks
for command substitution. Always wrap piped programs in **single quotes**:

```bash
# Correct — Mantra receives the backticks
echo '`[ + 1 2 3 ] : 3`' | ./bin/mantra

# Incorrect — shell interprets backticks before Mantra
echo "`[ + 1 2 3 ] : 3`" | ./bin/mantra
```

For detailed guidance, see [Shell Quoting](shell-quoting.md).

## Combining with CLI Flags

Stdin input works with all command-line flags. Common combinations:

### Pre-defined variables (`--set`)

```bash
echo 'x * 2' | ./bin/mantra --set x=21
```

Expected output:

```text
42
```

The `--set` variables are compiled and executed before stdin is read, so the
variables are available when the piped program runs.

### Eval expressions (`--eval=`)

```bash
echo '' | ./bin/mantra --eval='+ 1 2'
```

The `--eval=` expressions run after stdin is processed. They are each wrapped
as `print { EXPR }` and executed in the same runtime context.

### Debug output (`--debug`)

```bash
echo '[ { 1 2 3 : 4 } ]' | ./bin/mantra --debug
```

Prints the output after every statement, useful for tracing multi-statement
piped programs.

### Raw output (`--raw`)

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra --raw
```

Prints unformatted `TreeValue` output instead of the default formatted tree.

## Execution Order with stdin

When stdin is the input source and flags are present, the runtime processes
them in this order:

1. Parse CLI flags (`--set`, `--eval=`, etc.)
2. Initialize `--set` variables (compile and execute)
3. Read and compile stdin
4. Execute compiled statements
5. Run `--eval=` expressions

This means `--set` variables are always available in the stdin program, and
`--eval=` expressions can reference variables defined in the stdin program.

## Limitations

### No Source Locations for Debugger

When Mantra reads from stdin, it sets `DebuggerSourcePath` to an empty
string. This means source-level breakpoints (`--break-source`) cannot
reference stdin input — there is no file path to resolve. The `IsStdinSource`
function in `mathparser.pas` (line 2446) specifically skips debugger source
path resolution for stdin sources.

### No Imports or Includes

Stdin input cannot resolve `import` or `include` directives, because the
runtime has no working directory or file path associated with piped input.
Use file input for programs that depend on external packages or included
files.

### No Interactive Line Editor

When stdin is redirected, Mantra skips the built-in terminal line editor
(history, cursor movement). Input is read as plain sequential lines. For
interactive editing, use `--interactive` with a terminal-connected stdin
instead.

## When to Prefer It

- The example fits on one line or a small heredoc
- The example does not need imports or included files
- You want to quickly reproduce a behavior for a bug report
- You are chaining commands in a shell pipeline
- You are validating output against a test fixture

For programs with multiple statements, rules, or imports, prefer [File
Input](file-input.md).

## See Also

- [Running Programs](../running-programs.md) — Overview of all input methods
- [File Input](file-input.md) — Running from a file
- [Shell Quoting](shell-quoting.md) — Backtick and quote handling
- [Input Files and REPL](../../reference/command-line/common-options/input-files-repl.md) — Full reference
- [CLI Set](../../data/variables-bindings/cli-set.md) — `--set` variable examples
- [Test Fixture Guide](../../reference/test-fixture-guide.md) — `.in` files are stdin-shaped programs
