# Rendering Structured Output

Mantra provides multiple ways to convert AST node values into human-readable or machine-readable text. This section documents the full output pipeline: from how values are formatted internally, to how they reach standard output, to CLI flags that control rendering behavior.

## Output Pipeline

When Mantra executes a program, values flow through this chain:

1. **AST nodes** hold evaluated values (strings, integers, floats, booleans, trees).
2. **Formatters** convert node values to strings using different strategies.
3. **Output nodes** (`print`, `tree_out`, `ir_out`, `printf`) invoke formatters and emit text.
4. **`EmitRuntimeOutputLine`** writes the final string to stdout.
5. **CLI flags** (`--raw`, `--eval`, `--debug`, `--show-tokens`) modify behavior at different stages.

### The Formatter Hierarchy

All formatters inherit from `TCustomFormatter`, which accumulates text in an `Output` property:

| Formatter | Description |
|---|---|
| `TCustomFormatter` | Base class. Writes raw `TreeValue` of each node. |
| `TFormatter` | Default formatter. Columnar output with separator handling, width tracking, and newline support. Used by `print`. |
| `TTreeFormatter` | Renders the full AST tree structure with indentation. Used by `tree_out`. |
| `TIRFormatter` | Renders intermediate representation with escaped values and node depth. Used by `ir_out`. |

Each formatter implements `WriteFormatted(Index)` which is called recursively to traverse the AST subtree rooted at `Index` and produce formatted text.

### Output Nodes

| Keyword | Node Type | Formatter | Description |
|---|---|---|---|
| `print` | `TOutputNode` | `TFormatter` (or raw with `--raw`) | Prints values using the default columnar formatter. |
| `tree_out` | `TTreeOutputNode` | `TTreeFormatter` | Prints the full AST tree structure with indentation. |
| `ir_out` | `TIROutputNode` | `TIRFormatter` | Prints intermediate representation with node details and escaped values. |
| `printf` | `TPrintfNode` | Format string rendering | Direct output using format-string placeholders (`%s`, `%d`, `%f`, `%t`, `%q`). |

#### `print`

The default output statement. Evaluates its argument and formats it with `TFormatter`:

```mantra
print { + 1 2 }
```

With `--raw`, `print` skips the formatter and outputs the node's raw `TreeValue` directly:

```mantra
print "hello"
```
- Normal output: `"hello" `
- With `--raw`: `hello`

The `--raw` flag only affects `print` (`OBJ_OUTPUT`). `tree_out` and `ir_out` always use their respective formatters regardless of `--raw`.

#### `tree_out`

Renders the complete AST tree structure of a value with indentation showing the hierarchy:

```mantra
tree_out { + * 2 3 4 }
```

This uses `TTreeFormatter.Write` which recursively traverses the tree, writing each node with its depth level.

#### `ir_out`

Prints the intermediate representation with escaped values and parent-child relationships:

```mantra
ir_out { + * 2 3 4 }
```

This uses `TIRFormatter.WriteNode` which writes each node with its token, parent index, and depth. Supports variable resolution via `$` references.

#### `printf`

Direct output using format-string specifiers. See [Format Strings](rendering-structured-output/format-strings.md) for the full syntax. Unlike `print`, `printf` does not add outer quotes or column separators — it writes the formatted string directly:

```mantra
printf "Value: %s, Count: %d" "items" 42
```

Output:
```
Value: items, Count: 42
```

## CLI Output Flags

### `--raw`

Prints unformatted `TreeValue` output for `print` statements. Skips the formatter entirely and writes the raw string value of each node. Only affects `OBJ_OUTPUT` nodes — `tree_out` and `ir_out` always use their formatters.

```bash
mantra --raw script.m
```

### `--eval`

Enables evaluation output mode. When set, evaluation results are printed to stdout during execution.

```bash
mantra --eval script.m
```

### `--debug` / `-d`

Enables debug output mode. Additional diagnostic information is printed during execution.

```bash
mantra --debug script.m
```

### `--show-tokens`

Prints tokenization results before compilation, showing each token with its line and column position:

```bash
mantra --show-tokens script.m
```

Output example:
```
[ print @1:1 ] [ "hello" @1:7 ]
```

### `--show-input` / `--input`

Echoes the input source before execution. Useful for verifying piped or stdin content.

```bash
mantra --show-input script.m
```

## Value Formatting

Each AST node type has formatting methods (`TreeValue`, `ElementValue`, `TokenValue`) that produce different representations:

- **`TreeValue`** — The raw string value of a node. Used by `--raw` mode and `TCustomFormatter`.
- **`Formatted(Formatter)`** — The formatted string produced by a specific formatter. Used by `print`, `tree_out`, and `ir_out`.
- **`TokenValue`** — The original token text from the source. Used by `TStatementNode`.

### String Values

Strings are quoted in default output:

```mantra
print "hello"
```
Output: `"hello" `

### Numeric Values

Integers and floats are rendered as literals:

```mantra
print 42
print 3.14
```
Output: `42 `, `3.1400000000000000E+000 `

### Boolean and Null

```mantra
print true
print false
print null
```

### Collections

Arrays and objects use the formatter's columnar layout:

```mantra
print [ 1 2 3 ]
print { name "Ada" age 42 }
```

## JSON Data

See [JSON Loading](rendering-structured-output/json-loading.md) for
`json_load`, [JSON Saving](rendering-structured-output/json-saving.md) for
`json_save`, and [JSON Encoding](rendering-structured-output/json-encoding.md)
for `json_encode`.

## Format Strings

See [Format Strings](rendering-structured-output/format-strings.md) for `fmt` and `printf` format-string syntax with `%s`, `%d`, `%f`, `%t`, `%q` placeholders.

## Interactive Mode

In interactive mode (`--interactive` / `-i`), Mantra enters a REPL loop. The last expression in each input is automatically evaluated and its result is displayed. Multi-line inputs are tracked with a continuation prompt (`...> `) until all brackets and parentheses are balanced.

## Error Output

Errors are printed to stdout with the prefix `Error: ` followed by the message:

```mantra
print { / 1 0 }
```
Output: `Error: Division by zero`

When the debugger is active (`--debugger`), unhandled exceptions also trigger a post-mortem report and an interactive debugger command loop.

## Related Pages

- [Format Strings](rendering-structured-output/format-strings.md) — `fmt` and `printf` format-string syntax
- [JSON Loading](rendering-structured-output/json-loading.md) — `json_load` for reading JSON files
- [JSON Saving](rendering-structured-output/json-saving.md) — `json_save` for atomically writing JSON files
- [JSON Encoding](rendering-structured-output/json-encoding.md) — `json_encode` for producing JSON output
- [Witness Output](selection-witness-forms/witness-output.md) — structured witness formatting
- [Error Reporting](../evaluation/error-reporting.md) — error handling and diagnostics
