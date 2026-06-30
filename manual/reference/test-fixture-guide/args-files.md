# Args Files

An `.args` file supplies CLI arguments to a test fixture. It sits alongside
the `.in` and `.out` files in `tests/cases/` and lets you parameterize a
test without modifying the source input.

## Fixture Files

A complete fixture consists of:

| File | Purpose |
|---|---|
| `<case>.in` | Mantra source code passed to stdin |
| `<case>.out` | Expected raw output |
| `<case>.args` | Optional CLI arguments (one per line) |

When the test runner executes a case, it runs:

```bash
printf '%s\n' "$input_text" | mantra --raw "${case_args[@]}"
```

The `--raw` flag is always added automatically. Any arguments from the
`.args` file are appended after it.

## Format

Each line in an `.args` file is a separate CLI argument. Empty lines are
ignored. The test runner reads the file with `xargs` to handle whitespace
and splitting, so multi-word arguments should be written as single tokens
or quoted appropriately.

```text
--debug
```

```text
--set n=5
```

```text
--beam-width=2
```

## When to Use `.args` Files

Use an `.args` file whenever a fixture needs a runtime flag that changes
mantra's behavior beyond what the source code expresses. Common scenarios:

### Variable Predefinition (`--set`)

Pass variables from the CLI before the program executes:

```text
--set x=5
```

```mantra
print { x }
```

See also: [CLI Set](../../data/variables-bindings/cli-set.md).

### Debug Output (`--debug`)

Enable statement-by-statement output for verifying intermediate results:

```text
--debug
```

Many fixtures use `--debug` to capture the full dispatch output, not just
the final result.

### Debugger Breakpoints (`--debugger-cli`, `--break-*`)

Attach the debugger with specific breakpoints:

```text
--debugger-cli --break-source=*main.m:2 tests/modules/main.m
```

```text
--debugger-cli --break-callable=utils_add tests/modules/main.m
```

Debugger fixtures typically specify the input file path as the last argument.

### Inference Control (`--beam-width`, `--congruence-budget`)

Control the inference engine's search parameters:

```text
--beam-width=2
```

```text
--congruence-budget=10
```

### Event Logging (`--event-log`)

Emit matcher events to stdout:

```text
--event-log
```

```text
--event-log=diag,json
```

### Raw Output (`--raw`)

The `--raw` flag is already added automatically by the test runner. You
can still include it in `.args` if you want the file to be self-documenting,
but it is not required:

```text
--raw
```

### Input File Path

Some fixtures (especially debugger tests) need to specify an input file
instead of using stdin. Place the file path as the last argument:

```text
--debugger-cli --break-source=*debugger_break_source_main_after_import.m:2 tests/modules/debugger_break_source_main_after_import.m
```

## Complete Flags Reference

Any flag accepted by `mantra` can appear in an `.args` file. The full list:

| Flag | Purpose |
|---|---|
| `--raw` | Unformatted TreeValue output (added automatically) |
| `--debug`, `-d` | Print every statement output |
| `--debug-ir` | Print parser-friendly IR |
| `--interactive`, `-i` | REPL mode |
| `--eval`, `-e` | Evaluate output before printing |
| `--eval=EXPR` | Append and run expression |
| `--set NAME=EXPR` | Predefine a variable (repeatable) |
| `--head-dispatch` | Enable implicit rule dispatch (default) |
| `--no-head-dispatch` | Disable implicit rule dispatch |
| `--backtracking` | Enable infix `--` backtracking |
| `--no-guards` | Disable matcher rule guards |
| `--show-input` | Show input lines prefixed with `>` |
| `--show-tokens` | Show tokenizer output |
| `--event-log[=diag\|trace\|json\|text]` | Emit matcher events |
| `--congruence-budget N` | Max sub-expression rewrites in `\|=` |
| `--beam-width N` | Beam width for `\|=` proof search |
| `--debugger` | Attach event recorder |
| `--debugger-cli` | Command loop on exceptions |
| `--debugger-postmortem` | Print stack on exceptions |
| `--break-callable NAME` | Break on callable dispatch |
| `--break-statement TEXT` | Break on statement match |
| `--break-source SPEC` | Break on source location |
| `--break-rule TEXT` | Break on rule match |
| `--break-inference TEXT` | Break on inference state |

## Examples

### Single Flag

```text
--debug
```

### Multiple Flags

```text
--debug
--backtracking
```

### Flag with Value

```text
--set n=3
--set rules='[ x => x + 1 ]'
```

### Debugger with Source File

```text
--debugger-cli --break-source=*main.m:4 tests/modules/test_main.m
```

## Adding a Fixture with `.args`

1. Create `tests/cases/<case>.in` with the Mantra source code.
2. Create `tests/cases/<case>.out` with the expected output.
3. Create `tests/cases/<case>.args` with the CLI flags (one per line).
4. Verify with:

```bash
tests/run.sh --filter <case>
```

## See Also

- [Test Fixture Guide](../test-fixture-guide.md) — Fixture format overview
- [Filter and Strict Mode](filter-strict.md) — Running subsets of tests
- [CLI Set](../../data/variables-bindings/cli-set.md) — `--set` flag details
- [Fixture-Backed Behavior](../../language-model/stability-notes/fixture-backed-behavior.md) — Why fixtures matter
- [Command Line](../../reference/command-line.md) — Complete CLI reference
