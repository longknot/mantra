# Reading Runtime Output

Every Mantra program produces output as it executes. Understanding what the
runtime prints — and how to control it — is essential for writing programs,
debugging, and creating test fixtures.

This page explains the output pipeline, the sections you may see, how the
runtime decides what to emit, and how to read and control the results.

## The Output Pipeline

A Mantra program passes through these stages before producing visible output:

```
Source Text -> Tokenizer -> Parser (AST) -> Execution -> Formatter -> Output
```

Each stage can emit diagnostic information. By default, only the final
formatted result reaches stdout. Debug flags let you inspect intermediate
stages.

The output pipeline is implemented in `parsetree.pas` (execution loop),
`formatters.pas` (tree-to-string conversion), and `runtime_output.pas`
(emission to stdout or redirected sinks).

## What You See by Default

Without any flags, Mantra prints the formatted result of output statements.
An output statement is one whose first node is a `print`, `tree`, or `ir`
keyword — or the final expression in the program.

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra
```

Output:

```
[ + 1 + 2 + 3 ]
```

The formatter converts the internal tree `[ + 1 2 3 ]` into the human-readable
`[ + 1 + 2 + 3 ]`, repeating the operator for each element.

## Output Sections in Diagnostic Mode

When you enable diagnostic flags, the runtime prefixes or annotates output.
The sections you may encounter:

### `> ` — Input Echo (`--show-input`)

Each statement's source text appears prefixed with `> ` before evaluation:

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra --show-input
```

Output:

```
> [ + 1 2 3 ]
[ + 1 + 2 + 3 ]
```

The `>` line shows the parsed tree value of the statement before evaluation
begins. This helps you correlate input lines with their output, especially
in multi-statement programs.

### Token Lines (`--show-tokens`)

The tokenizer output appears before program execution:

```bash
echo 'print { 1 }' | ./bin/mantra --show-tokens
```

Output:

```
[ print @1:1 ] [ { @1:7 ] [ 1 @1:9 ] [ } @1:11 ]
1
```

Each token shows its text, line number, and column position. See
[Debug Output Modes](reading-runtime-output/debug-output-modes.md) for the
full format reference.

### Debug Statement Output (`--debug`)

Every statement's result is printed, not just output nodes:

```bash
echo 'x = 5
x + 1' | ./bin/mantra --debug
```

Output:

```
x = 5
+ x 1
```

Without `--debug`, only `print` statements and the last expression produce
output. With `--debug`, you see intermediate computations too.

### IR Output (`--debug-ir`)

The intermediate representation shows the AST structure after parsing:

```
root=0
node=0 parent=2147483647 depth=0 id=2 ...
```

Each node displays its index, parent, depth, type ID, edges (LHS/RHS),
and token reference. The value `2147483647` (`MaxInt` / `EOT`) means
"no link" — the node has no parent, child, or sibling in that direction.

### Raw Output (`--raw`)

Unformatted `TreeValue` output instead of the pretty-printed result:

```bash
echo '[ + 1 2 3 ]' | ./bin/mantra --raw
```

This shows the tree as stored in memory, without operator decoration or
column alignment. Useful for scripting and exact comparison.

## How the Runtime Decides What to Print

The execution loop in `parsetree.pas` processes each statement and applies
these rules:

1. **Check if it starts with an output node** (`print`, `tree`, `ir`).
   If yes, the node's own `Execute` method handles formatting and emission.
   Debug output (`--debug`, `--debug-ir`) is **skipped** to avoid duplicates.

2. **If it is NOT an output node** and `--debug` is enabled, format the
   result (using the default formatter or `TreeValue` if `--raw` is set)
   and emit it.

3. **If it is NOT an output node** and `--debug-ir` is enabled, format the
   result using `TIRFormatter` and emit it.

4. **If `--show-input`** is enabled, emit the input line before evaluation.

This means explicit `print` statements always produce exactly one output
line. The `--debug` and `--debug-ir` flags add visibility only for
statements that would otherwise be silent.

## The Three Output Node Types

| Keyword | Node Type | Formatter | Purpose |
|---|---|---|---|
| `print` | `TOutputNode` | Default (`TFormatter`) | Human-readable output |
| `tree` | `TTreeOutputNode` | Tree (`TTreeFormatter`) | Indented tree structure |
| `ir` | `TIROutputNode` | IR (`TIRFormatter`) | Parser-friendly representation |

All three follow the same emission path: execute their child (`LHS`),
format the result, and emit via `EmitRuntimeOutputLine()`.

For details on `print` and `printf`, see [Print Statements](reading-runtime-output/print-statements.md).

## Formatters

The formatter converts an AST tree into a string. Three formatters are available:

### Default Formatter (`TFormatter`)

The standard formatter. Applies column alignment, operator repetition, and
dynamic width calculation. This is what you see without any flags.

```
[ + 1 + 2 + 3 ]
```

### Tree Formatter (`TTreeFormatter`)

Produces an indented view showing node hierarchy with parent-child
relationships. Each level adds indentation to reveal tree depth. Activated
by the `tree` keyword.

### IR Formatter (`TIRFormatter`)

Produces machine-readable output with node indices, types, and edges.
Useful for verifying parser behavior. Activated by the `ir` keyword or
the `--debug-ir` flag.

## Emission: Where Output Goes

All output flows through `EmitRuntimeOutputLine()` in `runtime_output.pas`.
By default, it calls `WriteLn` to print to stdout. But the runtime supports
redirected sinks:

- **`SetRuntimeOutputSink`** — redirects text output to a custom handler.
  Used by the MCP server and test harness.
- **`EmitRuntimeJsonOutput`** — sends structured JSON output with MIME
  types. Used by `render`, `json_encode`, and similar keywords.
- **`SetRuntimeRichOutputSink`** — redirects rich (typed) output. Falls
  back to `WriteLn(Output.Data.AsJSON)` when no sink is registered.

This architecture means output can be captured programmatically without
modifying the formatting logic.

## Test Fixtures and Output

Test fixtures in `tests/cases/` use `.out` files that contain the expected
output lines. The test runner feeds the `.in` content to the runtime and
compares the actual output against `.out`.

Key points:

- The `.out` file contains the **direct runtime output** — no `OUTPUT:`
  prefix is added by the fixture comparison itself.
- By default, the test runner **normalizes whitespace** before comparing.
- In `--strict` mode, comparison is character-exact with no normalization.
- When a fixture has a `.args` file, those CLI flags are passed to the
  runtime (e.g., `--debug`, `--raw`).

For writing fixtures, run the program with the same flags you intend to
use and capture the output:

```bash
echo '[ + 1 2 3 ] : 3' | ./bin/mantra > tests/cases/my_test.out
```

See [Test Fixture Guide](../reference/test-fixture-guide.md) for full
details.

## Common Patterns

### See Everything

```bash
./bin/mantra --show-tokens --show-input --debug program.m
```

Shows tokens, input echo, and every statement's result.

### Debug Tree Structure

```bash
./bin/mantra --debug-ir program.m
```

Shows the AST shape for each statement before evaluation.

### Stable Output for Scripting

```bash
./bin/mantra --raw program.m
```

Produces machine-parseable output without formatting variations.

### Print Only What You Want

```mantra
rules = [ x => x + 1 ];     # silent assignment
data  = [ 1 2 3 ];          # silent assignment
print { data ? rules };     # explicit output
```

See [Print Statements](reading-runtime-output/print-statements.md) for
details.

## Summary

| What you want | How to get it |
|---|---|
| Default formatted output | Run without flags |
| See every statement's result | `--debug` |
| See AST structure | `--debug-ir` |
| See input alongside output | `--show-input` |
| See tokenizer output | `--show-tokens` |
| Raw tree values | `--raw` |
| Evaluate output before printing | `--eval` |
| Indented tree view | Use `tree` keyword |
| Explicit program output | Use `print` keyword |

## Related Pages

- [Print Statements](reading-runtime-output/print-statements.md) — `print` and `printf` in detail
- [Debug Output Modes](reading-runtime-output/debug-output-modes.md) — All CLI debug flags
- [Output Formatting](../evaluation/output-formatting.md) — Formatter implementation details
- [Test Fixture Guide](../reference/test-fixture-guide.md) — Writing and running test fixtures
- [Command Line](../reference/command-line.md) — Complete CLI flag reference
