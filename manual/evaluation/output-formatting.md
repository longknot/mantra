# Output Formatting

Mantra produces output through its runtime output system, which converts evaluated
AST trees into human-readable text. Every statement that results in a visible
value triggers the output pipeline: execution → evaluation → formatting →
`EmitRuntimeOutputLine`.

## How Output Works

The output pipeline follows these stages:

### 1. Execution

`TStatementNode.Execute` runs the statement. The last evaluated expression
automatically becomes the output — no explicit `return` or `print` statement
is needed.

### 2. Formatting

After execution, the result tree is passed to a **formatter**. The formatter
traverses the AST and converts it to a string using configurable formatting
rules. Three formatters are available:

| Formatter | Class | Purpose |
|---|---|---|
| Default | `TFormatter` | Human-readable output with column alignment |
| Tree | `TTreeFormatter` | Indented tree structure showing node hierarchy |
| IR | `TIRFormatter` | Parser-friendly intermediate representation |

### 3. Emission

`EmitRuntimeOutputLine()` sends the formatted string to stdout. The runtime
output system (`runtime_output.pas`) supports both standard output and
redirected sinks for use by the MCP server and test harness.

## Output Nodes

The runtime recognizes three output node types:

### TOutputNode (`OUTPUT`)

The default output node. Executes its child (`LHS`) and emits the formatted
result. When `--raw` is set, outputs `TreeValue` (unformatted tree text)
instead of the formatted string.

```mantra
[ + 1 + 2 + 3 ]
```

**Output:** `[ + 1 + 2 + 3 ]`

### TTreeOutputNode (`TREE_OUTPUT`)

Same behavior as `TOutputNode`, but always uses `TTreeFormatter` to produce
an indented tree view. Useful for inspecting the AST structure.

### TIROutputNode (`IR_OUTPUT`)

Same behavior as `TOutputNode`, but uses `TIRFormatter` to produce parser-
friendly intermediate representation. The IR formatter escapes values and
shows node indices, parent relationships, and depth information.

## Print and Printf

Mantra provides two explicit output keywords:

### `print`

Prints the value of its argument and removes the print node from the tree
after execution. Unlike implicit output (which is the last expression),
`print` can be used mid-computation to debug intermediate values.

```mantra
x = 5;
print x;
x + 1
```

**Output:**
```
5
6
```

### `printf`

`TPrintfNode` — renders formatted output with a format string. The `RenderFmtInvocation`
function processes format specifiers and substitutes values from context.

## Output Formatting in Detail

### Default Formatter (`TFormatter`)

The default formatter applies these transformations:

- **Integer formatting** — integers with operators are shown with the operator
  prefix (e.g., `+ 1`, `+ 2`, `+ 3`).
- **Column alignment** — when `BeginColumn`/`EndColumn` is active, values
  are right-aligned to the widest value in each column.
- **Repeated operator suppression** — when consecutive nodes share the same
  RHS operator, the formatter suppresses redundant operator output.
- **Dynamic column width** — column widths adjust based on actual content
  rather than fixed widths.

```mantra
[ + 1 2 3 ]
```

**Output:** `[ + 1 + 2 + 3 ]`

### Tree Formatter (`TTreeFormatter`)

Produces an indented view showing node hierarchy with parent/child
relationships. Each level adds indentation to reveal tree depth.

### IR Formatter (`TIRFormatter`)

Produces machine-readable output suitable for parser testing and debugging.
Escapes special characters and annotates node indices.

## CLI Output Options

The runtime supports several CLI flags that control output behavior:

| Flag | `TRunOptions` | Effect |
|---|---|---|
| `--raw` | `Raw` | Output unformatted `TreeValue` instead of formatted text |
| `--debug` | `DebugOutput` | Print every statement's output, including non-output statements |
| `--debug-ir` | `DebugIR` | Print IR-formatted output for non-output statements |
| `--show-input` | `ShowInput` | Print input lines prefixed with `>` |
| `--show-tokens` | `ShowTokens` | Print tokenizer output |
| `--eval` | `EvalOutput` | Evaluate output before printing |
| `--eval=EXPR` | `EvalExpressions` | Append and run additional expression(s) |

### `--raw`

When `--raw` is set, `TOutputNode.Execute` skips formatting and outputs
`Node[LHS].TreeValue` directly. This shows the raw tree value as stored
in memory, without operator decoration or column alignment.

### `--debug` / `--debug-ir`

In `parsetree.pas`, after `Node.Execute` completes, the execution loop
checks these flags. If the statement does **not** start with an output node,
the runtime emits additional output:

- `--debug` — formats the statement using the default formatter (or
  `TreeValue` if `--raw` is also set).
- `--debug-ir` — formats the statement using `TIRFormatter`.

Both are silently skipped for statements that already produce output,
avoiding duplicate output lines.

### `--show-input`

Prints every input line prefixed with `>`. Useful for comparing input
against output.

```bash
echo '[ + 1 2 3 ]' | mantra --show-input
```

**Output:**
```
> [ + 1 2 3 ]
[ + 1 + 2 + 3 ]
```

## Format Configuration

The `TFormatConfig` record controls formatter behavior:

```pascal
TFormatConfig = record
  Offset: Integer;       // Starting offset in output
  ColumnWidth: Integer;  // Default column width (6)
  Separator: ansistring; // Value separator (' ')
  NewLine: Boolean;      // Append newline after output
  Options: TFormatOptions; // Formatting options
end;
```

The default configuration:
- `Offset: 0`
- `ColumnWidth: 6`
- `Separator: ' '`
- `NewLine: False`
- `Options: []`

## Test Fixture Output

Test fixtures in `tests/cases/` use `.out` files that contain only the
expected `OUTPUT:` line — the final formatted result of the program.
The test runner (`tests/run.sh`) normalizes whitespace by default,
comparing the actual output against the expected output character by
character after collapsing whitespace.

```
# test case: backtick_repeat_list_compute
# .in:   `[ + 1 2 3 ] : 3`
# .out:  `[ + 6 ] [ + 6 ] [ + 6 ]`
```

In strict mode (`--strict`), the test runner compares output exactly
without whitespace normalization.

## Rich Output

The runtime output system supports structured output through
`TRuntimeRichOutput` and `TRichOutputSink`. This is used by the MCP
server to deliver typed responses with MIME types and JSON data:

```pascal
TRuntimeRichOutput = class
  MimeType: ansistring;
  Encoding: ansistring;
  Data: TJSONData;
  Metadata: TJSONObject;
end;
```

When no rich output sink is registered, JSON data falls back to
`WriteLn(Output.Data.AsJSON)` on stdout.

## Related Pages

- [Default Output](output-formatting/default-output.md)
- [Raw, Debug, and Token Output](output-formatting/raw-debug-token-output.md)
- [Evaluation Scopes](evaluation-scopes.md)
- [Compute Scopes](compute/compute-scopes.md)
