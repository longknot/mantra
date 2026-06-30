# File Input

File input is the primary way to run Mantra programs. Pass a file path as a
positional argument and the runtime reads, parses, and executes the source.

```bash
mantra mantra.m
```

Only one positional file argument is accepted; a second raises:

```
Unexpected argument: <file>
```

## How It Works

The runtime reads the file line by line, tracking brace/bracket/paren balance
and string/comment state. When a statement boundary is reached — all delimiters
are closed and no string, backtick, apostrophe, or block comment is open — the
accumulated chunk is compiled and staged. After the entire file is processed,
all staged statements execute together in order.

Key behaviors in `CompileSourceFile` (`mathparser.pas`, line 2514):

- The file path is resolved with `ExpandFileName` and stored as
  `ActiveSourcePath`.
- `DebuggerSourcePath` is set to the absolute path, enabling source-level
  breakpoints.
- Line numbers are tracked (`CurrentSourceLine`) and passed to the tokenizer
  (`BaseLine`), so parser errors and debugger events reference the correct
  source location.
- Chunks are compiled incrementally at statement boundaries, not all at once.
  This means errors are reported at the first failing statement, not the last
  line of the file.

## Multi-Statement Files

File input is the natural home for programs with multiple statements, variable
declarations, rules, and imports:

```mantra
x = [ 1 2 3 ]
y = x ? [ a => a * 2 ]
print y
```

Save this as `double.m` and run:

```bash
mantra double.m
```

Statements are compiled top to bottom and executed in the same runtime context.
Variables defined earlier are available to later statements.

## Source Locations and Debugger Support

Unlike stdin input, file input provides full source location information:

- **Parser errors** include file path and line number.
- **`--break-source`** breakpoints work by matching `FILE:LINE:COL` against
  the resolved source path.
- **Debugger events** (`--debugger`) record file paths, enabling post-mortem
  inspection and source navigation.

The `DebuggerSourcePath` is set to the expanded absolute path of the input
file. This is checked by `IsStdinSource` (`mathparser.pas`, line 2446) — it
returns `false` for any path that is not `''`, `'-'`, or `'/dev/stdin'`.

## Comments and Blank Lines

Mantra supports two comment styles in files:

```mantra
// This is a single-line comment

/* This is a
   block comment */
```

Comments are stripped during tokenization. Single-line comments (`//`) extend
to the end of the line. Block comments (`/* ... */`) can span multiple lines.

The `UpdateBalance` function tracks block comment state across lines — a
statement boundary is not recognized while inside a block comment.

Blank lines are ignored — they do not affect statement boundaries.

## Imports and Includes

File input is required for programs that use `import` or `include` directives,
because the runtime needs a file path to resolve relative references.

### Import

The `import` keyword loads a package from the package library:

```mantra
import math;

print { math.kron [ 1 2 ] [ a b ] };
```

See [package_import_math_kron](../../reference/test-fixture-guide.md) for a
working test fixture example.

### Include

The `include` keyword embeds another source file at the current location:

```mantra
include helpers.m;

print { helper_fn x };
```

Include paths are resolved relative to the directory of the including file.

Both `import` and `include` emit debugger events (`dekImportEnter`) when the
debugger is attached, creating frames with `dfkImport` type for tracing.

## Combining with CLI Flags

File input works with all command-line flags. Common combinations:

### Pre-defined variables (`--set`)

```bash
mantra program.m --set n=10
```

The `--set` variables are compiled and executed before the file is read, so
they are available when the file runs.

### Eval expressions (`--eval=`)

```bash
mantra program.m --eval='x + 1'
```

The `--eval=` expressions run after the file is fully processed. They are each
wrapped as `print { EXPR }` and executed in the same runtime context.

### Debug output (`--debug`)

```bash
mantra program.m --debug
```

Prints the output after every statement, useful for tracing multi-statement
programs.

### Raw output (`--raw`)

```bash
mantra program.m --raw
```

Prints unformatted `TreeValue` output instead of the default formatted tree.

### Debugger (`--debugger`)

```bash
mantra program.m --debugger
```

Attaches the event recorder. Combined with `--break-source`, this enables
source-level debugging:

```bash
mantra program.m --debugger --break-source program.m:5:1
```

## Execution Order with File Input

When a file is the input source and flags are present, the runtime processes
them in this order:

1. Parse CLI flags (`--set`, `--eval=`, etc.)
2. Initialize `--set` variables (compile and execute)
3. Read, parse, and compile the source file
4. Execute compiled statements
5. Run `--eval=` expressions

This means `--set` variables are always available in the file program, and
`--eval=` expressions can reference variables defined in the file.

## Interactive Mode with File Input

Use `--interactive` to load a file and then enter interactive mode:

```bash
mantra --interactive program.m
```

The file is compiled and its statements execute first. Then the REPL prompt
appears, with all variables and definitions from the file available:

```
mantra> 
```

In interactive mode, the REPL reads lines with balance tracking — multi-line
expressions prompt with `...> ` until all delimiters are closed. Type `:quit`
or `:exit` to exit.

## Error Handling

When file input encounters errors, the behavior depends on the error type:

### File Not Found

```bash
mantra nonexistent.m
```

```
File handling error occurred. Details: File not found.
```

The `CompileSourceFile` procedure catches `EInOutError` exceptions and prints
a descriptive message.

### Parse Errors

Syntax errors are raised as exceptions during tokenization or parsing. The
error message includes the file path and line number from the tokenizer state.

### Runtime Errors

Execution errors (e.g., type mismatches, unbound variables) are caught by
`HandleExecutionException`, which prints the error and optionally invokes
the debugger CLI if `--debugger-cli` is set.

## When to Prefer It

- The program spans multiple statements or definitions
- The program uses `import` or `include` directives
- You want to use source-level breakpoints (`--break-source`)
- The program is part of a larger project with multiple source files
- You are debugging and need file-referenced error messages
- You want to load a program and then explore interactively (`--interactive`)

For quick one-liners or shell pipelines, prefer [Standard Input](standard-input.md).

## See Also

- [Running Programs](../running-programs.md) — Overview of all input methods
- [Standard Input](standard-input.md) — Piping source via stdin
- [Shell Quoting](shell-quoting.md) — Backtick and quote handling
- [Building the Runtime](../building-the-runtime.md) — Compiling from source
- [Test Fixture Guide](../../reference/test-fixture-guide.md) — `.in` files as programs
- [Debugger Guide](../../reference/debugger-guide.md) — Source breakpoints
