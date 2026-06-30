# Raw, Debug, and Token Output

Mantra provides several diagnostic output modes that expose lower-level
runtime information. These are controlled by CLI flags and the
`TRunOptions` record in `mathparser.pas`.

## CLI Flags

| Flag | `TRunOptions` field | Effect |
|---|---|---|
| `--raw` | `Raw` | Output unformatted `TreeValue` instead of formatted text |
| `--debug` | `DebugOutput` | Print every statement's output, including non-output statements |
| `--debug-ir` | `DebugIR` | Print IR-formatted output for non-output statements |
| `--show-input` | `ShowInput` | Print input lines prefixed with `>` |
| `--show-tokens` | `ShowTokens` | Print tokenizer output to stdout |

These flags are parsed in `mantra.lpr` and stored in the global `RunOptions`
record. They default to `False` and can be combined freely.

## Output Routing

All diagnostic output flows through `runtime_output.pas`. The
`EmitRuntimeOutputLine` procedure either calls the configured sink
(`RuntimeOutputSink`) or falls back to `WriteLn`. This means diagnostic
output respects the same routing as normal program output — whether that's
stdout, a pipe, or a rich output handler.

## `--raw` — Unformatted Tree Output

When `--raw` is set, `TOutputNode.Execute` (in `nodes.pas`) bypasses the
formatter chain (`GetFormatter` → `Formatted`) and outputs
`Node[LHS].TreeValue` — the raw tree value as stored in memory.

The `TreeValue` method (in `TBaseNode`, `nodes.pas`) walks the result tree
using `ElementValue(Config)` with default formatting options, but does NOT
apply:

- Operator prefix decoration (e.g., `+ 1` → `1`)
- Column alignment or dynamic width calculation
- Repeated RHS operator suppression
- Bracket formatting with spacing

This is useful for inspecting the exact values stored in the AST without any
presentation-layer transformations.

### Example

Input (`callable_keyword_exec_tail`):

```mantra
callable func;

rule runlist [
  runlist [ X -- ] => runlist { all X },
  runlist { X, } Y -- => func X runlist [ all Y ],
  runlist { X, } => func X
];

print { runlist [ "a", "b", "c" ] }
```

With `--raw`:

```text
func "a" func "b" func "c"
```

The raw output shows the tree value without operator prefix formatting
that the default formatter would add.

## `--debug` — Statement-Level Debug Output

When `--debug` is set, the execution loop in `parsetree.pas` (`TContext.Execute`)
emits formatted output for **every** statement, not just those with explicit
output nodes (`OBJ_OUTPUT`, `OBJ_TREE_OUTPUT`, `OBJ_IR_OUTPUT`). This includes
intermediate assignments and variable bindings that would otherwise be silent.

Implementation: After `statement.Execute` returns, if `RunOptions.DebugOutput`
is true and the statement object is not an output node (`Object <> OBJ_OUTPUT
and Object <> OBJ_TREE_OUTPUT and Object <> OBJ_IR_OUTPUT`), the tree is
formatted using the configured formatter (`TFormatter`, `TTreeFormatter`, or
`TIRFormatter` depending on `Raw` and `DebugIR` flags) and emitted via
`EmitRuntimeOutputLine`.

### Example

Input (`debug_flag_with_print_no_duplicate`):

```mantra
1 + 2
print { 1 + 2 }
```

Without `--debug`:

```text
1 + 2
```

With `--debug`:

```text
1 + 2
1 + 2
```

Both lines appear: the first from the debug output of the `1 + 2` statement,
the second from the explicit `print` node.

The duplicate-suppression logic in `TOutputNode.Execute` checks
`RunOptions.DebugOutput` and skips emitting the formatted output when the
statement is a debug-output statement (preventing triple output when `--debug`
is combined with an explicit `print`).

## `--debug-ir` — IR Format Debug Output

When `--debug-ir` is set, the execution loop uses `TIRFormatter` instead of
the default `TFormatter` for non-output statements.

The `TIRFormatter` (in `formatters.pas`) produces a parser-friendly intermediate
representation. Its `WriteNode` method recursively formats nodes with depth
indentation, and `EscapeValue` handles value escaping for structural clarity.
This format is designed to be both human-readable and machine-parseable.

This is particularly useful for:

- Verifying parser output matches expected structure
- Debugging node tree construction
- Writing test fixtures with precise structural expectations

## `--show-input` — Echo Input Lines

When `--show-input` is set, the execution loop in `parsetree.pas` prints every
input line prefixed with `>` before executing it. The value comes from the
current token's string content (`Expression.TokenValue(Token)`).

Implementation: In `TContext.Execute`, before `statement.Execute`, if
`RunOptions.ShowInput` is true, `EmitRuntimeOutputLine('> ' + InputValue)`
is called.

### Example

```bash
echo '[ + 1 2 3 ]' | mantra --show-input
```

**Output:**

```text
> [ + 1 2 3 ]
[ + 1 + 2 + 3 ]
```

## `--show-tokens` — Tokenizer Output

When `--show-tokens` is set, the runtime prints token information for each
parsed chunk before evaluation. The output shows each token's value and
source position (line:column).

Implementation (in `mathparser.pas`, `TContext.ParseChunk`): After calling
`Tokenizer.Tokenize` and `P.Tree.Parse`, if `Options.ShowTokens` is true,
the parser iterates over `P.Expression` from `StartToken` to
`P.Expression.Size - 1`, writing each token as
`[ <value> @<line>:<col> ]` separated by spaces. Tokens with `ID = 0` or
`Index < 0` are skipped. Output goes directly to `Write`/`WriteLn` (not
through `EmitRuntimeOutputLine`).

### Example

Input (`show_tokens_line_col`):

```mantra
print { 1 }
```

With `--show-tokens`:

```text
[ print @1:1 ] [ { @1:7 ] [ 1 @1:9 ] [ } @1:11 ]
1
```

Each token is displayed as `[ <token_value> @<line>:<column> ]` with 1-based
line and column positions. The final `1` is the normal program output.

## Combining Flags

These flags can be combined. When multiple diagnostic flags are active, the
output layers stack:

```bash
mantra --debug --raw --show-input program.m
```

This produces:

1. Input lines prefixed with `>` (from `--show-input`)
2. Raw tree values for every statement (from `--debug` + `--raw`)
3. No formatter decoration on any output

## When to Use Diagnostic Output

| Goal | Recommended flag(s) |
|---|---|
| See raw tree structure | `--raw` |
| Debug intermediate values | `--debug` |
| Verify parser output structure | `--debug-ir` |
| Compare input against output | `--show-input` |
| Inspect tokenization | `--show-tokens` |
| Full diagnostic output | `--debug --raw --show-input` |

## Implementation Summary

| Flag | Module | Key Code | Output Path |
|---|---|---|---|
| `--raw` | `nodes.pas` | `TOutputNode.Execute` | `EmitRuntimeOutputLine` |
| `--debug` | `parsetree.pas` | `TContext.Execute` (loop) | `EmitRuntimeOutputLine` |
| `--debug-ir` | `parsetree.pas` | `TContext.Execute` (loop) | `EmitRuntimeOutputLine` |
| `--show-input` | `parsetree.pas` | `TContext.Execute` (loop) | `EmitRuntimeOutputLine` |
| `--show-tokens` | `mathparser.pas` | `TContext.ParseChunk` | `WriteLn` directly |

## Related Pages

- [Output Formatting](../output-formatting.md)
- [Default Output](default-output.md)
