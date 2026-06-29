# Error Reporting

Mantra surfaces errors at two levels: the **CLI** (interactive sessions and file
execution) and the **programmatic session API** (MCP server, embedded callers).
Errors originate from the parser, runtime nodes, or external system calls. All
user-facing errors follow the `Error: <message>` format on standard output.

## Error Flow

```
Exception raised in nodes / parser / loader
    |
    v
HandleExecutionException (mathparser.pas)
    |
    +-- Emit debugger event (dekExceptionRaised)
    +-- Print "Error: <message>"
    +-- Postmortem report (if --debugger + --postmortem)
    +-- Debugger CLI loop (if --debugger-cli)
```

For the session API (`TMantraSession`), errors are caught and returned
structured:

```pascal
Result.Ok := False;
Result.ErrorCode := 'runtime_error';
Result.ErrorMessage := E.Message;
```

## Error Categories

### Parse Errors

Raised during tokenization and AST construction. These occur before execution
begins.

| Condition | Error Message | Fixture |
|---|---|---|
| Missing assignment target | `Error: Missing assignment target before "="` | `parse_assignment_missing_lhs` |
| Unexpected end of input | `Error: Unexpected end of input. Expected: <token>` | — |
| Token index out of bounds | `Error: Token index %d is out of bounds.` | — |

Parse errors originate in `exp_tokenizer.pas` (tokenizer) and `mathparser.pas`
(parser).

### Runtime Errors

Raised during node evaluation. These are the most common errors users encounter.

#### Assignment Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Invalid assignment target | `Error: Invalid assignment target: <value>` | — |
| Assignment target not a single variable | `Error: Assignment target must be a single variable: <value>` | — |
| Invalid deep-assignment target | `Error: Invalid deep-assignment target: <value>` | — |
| Invalid deep-assignment source | `Error: Invalid deep-assignment source: <value>` | — |
| Invalid deep-assignment mode bits | `Error: Invalid deep-assignment mode bits: 0x%x` | — |
| Deep-assignment failed | `Error: Deep-assignment failed (<source> <- <target>)` | `trie_deep_assignment_fail_mode` |

#### Range Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Non-numeric range step | `Error: range step must be numeric` | — |
| Non-finite range values/step | `Error: range values and step must be finite` | `range_stepped_nonfinite_rejected` |
| Zero range step | `Error: range step cannot be zero` | `range_stepped_zero_rejected` |
| Step direction does not reach end | `Error: range step direction does not reach end` | `range_stepped_direction_rejected` |
| Non-integer range step | `Error: range step must be an integer` | — |
| Character range with explicit step | `Error: explicit character range steps are not supported` | `range_stepped_character_rejected` |
| Missing range step after "by" | `Error: Missing range step after "by"` | `range_stepped_missing_step_rejected` |

#### Index Lookup Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Non-integer index | `Error: index must be an integer, got "<value>"` | `index_lookup_non_integer_rejected` |
| Zero or negative index | `Error: index must be greater than zero, got <n>` | `index_lookup_zero_rejected`, `index_lookup_negative_rejected` |
| Index out of bounds | `Error: index <n> is out of bounds for value with <m> items` | `index_lookup_out_of_bounds` |
| Non-container value | `Error: value is not indexable: <value>` | `index_lookup_non_container_rejected` |
| Stepped range slice | `Error: Stepped index slices are not supported` | `index_lookup_stepped_range_rejected` |
| Missing value in indexed lookup | `Error: indexed lookup is missing a value` | — |
| Missing index in indexed lookup | `Error: indexed lookup is missing an index` | — |

#### Slice Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Missing slice start | `Error: slice is missing a start index` | — |
| Missing slice end | `Error: slice is missing an end index` | — |
| Empty slice start result | `Error: slice start evaluated to an empty result` | — |
| Empty slice end result | `Error: slice end evaluated to an empty result` | — |
| Non-integer slice end | `Error: slice end must be an integer, got "<value>"` | `index_lookup_range_non_integer_rejected` |
| Slice start out of bounds | `Error: slice end <n> is out of bounds for value with <m> items` | `index_lookup_range_out_of_bounds` |
| Slice start must be > 0 | `Error: slice start must be greater than zero, got <n>` | `index_lookup_range_zero_rejected` |
| Multiple endpoints in slice start | `Error: slice start must evaluate to one integer, got <values>` | `index_lookup_range_multiple_endpoint_rejected` |

#### Callable and Query Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Callable expects wrong argument count | `Error: <name> expects exactly N argument(s)` | — |
| Missing iterator name | `Error: Missing iterator name` | — |
| Invalid iterator binding name | `Error: Invalid iterator binding name: <name>` | — |
| Unknown callable | `Error: Unknown callable: <name>` | — |

#### Selection Strategy Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Invalid selection strategy expression | `Error: Invalid selection strategy expression: <expr>` | — |
| Unknown selection strategy | `Error: Unknown selection strategy: <name>` | — |
| Invalid selector policy operator | `Error: Invalid selector policy operator: <op>` | — |

#### Render and Display Errors

| Condition | Error Message | Fixture |
|---|---|---|
| Non-JSON MIME type (display) | `Error: display MVP supports JSON MIME types only, got <mime>` | `display_non_json_rejected` |
| json_encode non-finite value | `Error: json_encode requires a finite float, got <value>` | `json_encode_nonfinite_rejected` |
| json_encode path not found | `Error: json_encode path not found: <path>` | `json_encode_missing_path` |
| render profile not found | `Error: render <format> profile not found: <path>` | — |
| render missing column | `Error: render <format> missing <path>.<field>` | — |
| render unsupported format | `Error: render does not support format <name>` | — |
| render empty subject | `Error: render <format> subject cannot be empty` | — |

#### Path and System Command Errors

| Condition | Error Message | Fixture |
|---|---|---|
| assign_path non-scalar path | `Error: assign_path path must resolve to scalar path text; wrap structured values in (...) or {...}` | `assign_path_unboxed_structured_rejected` |
| assign_path empty target | `Error: assign_path target path cannot be empty` | — |
| assign_path missing arguments | `Error: assign_path expected a variable-subtree pair as second argument` | — |
| system command failed | `Error: system <cmd>: <stderr>` | — |
| system command missing args | `Error: system expects at least 2 arguments: system <command> <dest-prefix> [args...]` | — |
| system empty command | `Error: system command name cannot be empty` | — |

#### File Loading Errors

| Condition | Error Message | Source |
|---|---|---|
| json_load parse error | `Error: json_load parse error in "<file>": <detail>` | `nodes.pas` |
| json_save missing directory | `Error: json_save destination directory not found: <path>` | `nodes.pas` |
| json_save replacement failure | `Error: json_save failed to replace "<file>": <detail>` | `nodes.pas` |
| yaml_load parse error | `Error: yaml_load parse error in "<file>": <detail>` | `nodes.pas` |
| Import file not found | `Error: Import file not found: <path>` | `module_loader.pas` |
| Package not found | `Error: Package not found: <path> (expected packages/<path>.m or packages/<path>/package.m)` | `module_loader.pas` |
| File handling error | `File handling error occurred. Details: <msg>` | `mathparser.pas` |
| scope requires tree form | `Error: scope requires the form scope { ... }` | `nodes.pas` |

#### Matcher Errors

| Condition | Error Message | Source |
|---|---|---|
| Invalid bind index | `Error: Invalid bind index <n>` | `matcher_ir.pas` |
| Multiple focus markers | `Error: Rule has multiple focus markers in pattern: <pattern>` | `matcher_ir.pas` |

#### Floating-Point Exceptions

The runtime enables hardware floating-point exceptions (`parsetree.pas`):

```pascal
SetExceptionMask([
  exInvalidOp, exDenormalized, exZeroDivide,
  exOverflow, exUnderflow, exPrecision
]);
```

Division by zero, NaN propagation, and overflow will raise runtime exceptions
that surface as `Error:` messages through the same handler.

## Error Handling with the Debugger

When `--debugger` is enabled, every exception triggers additional diagnostics:

1. **Debugger event** — `dekExceptionRaised` is emitted with the error message.
2. **Postmortem report** — if `--debugger` is set, `BuildDebuggerPostmortemReport`
   prints the debugger stack and recent events after the error message.
3. **Interactive CLI** — if `--debugger-cli` is set, the debugger command loop
   opens after the error, allowing inspection before exit.

Example with `--debugger`:
```
$ mantra --debugger --debugger-cli program.m
Error: index 4 is out of bounds for value with 3 items
Debugger paused: exception
Debugger commands:
  help              Show this help
  breakpoints       List breakpoints
  bt                Show debugger stack
  reason            Show current pause reason
  ...
```

The `debugger_postmortem_dispatch_error` and `debugger_cli_postmortem` fixtures
validate this behavior.

## Session API Error Response

When Mantra is used programmatically (MCP server, embedded sessions), errors
are returned as structured JSON rather than printed to stdout:

```json
{
  "ok": false,
  "error_code": "runtime_error",
  "error_message": "index 4 is out of bounds for value with 3 items",
  "text": ""
}
```

The `TMantraSession.Exec` method catches all exceptions and populates:

| Field | Value |
|---|---|
| `Ok` | `False` |
| `ErrorCode` | `"runtime_error"` |
| `ErrorMessage` | The exception message text |
| `Text` | Any output captured before the error |

For variable lookups (`GetValue`), missing paths return:

```json
{
  "ok": false,
  "error_code": "not_found",
  "error_message": "path not found: <path>",
  "kind": "missing"
}
```

## Fixture-Based Error Testing

The test suite validates error behavior using the same fixture system as
positive tests. Each error case has a `.in` (input) and `.out` (expected
error output) pair. The `.out` file contains the `Error:` line(s) the runtime
should produce.

Current error fixtures (32 total):

| Category | Fixtures |
|---|---|
| Index lookup | `index_lookup_negative_rejected`, `index_lookup_non_container_rejected`, `index_lookup_non_integer_rejected`, `index_lookup_out_of_bounds`, `index_lookup_stepped_range_rejected`, `index_lookup_zero_rejected` |
| Index lookup ranges | `index_lookup_range_multiple_endpoint_rejected`, `index_lookup_range_non_integer_rejected`, `index_lookup_range_out_of_bounds`, `index_lookup_range_zero_rejected` |
| Range steps | `range_stepped_character_rejected`, `range_stepped_direction_rejected`, `range_stepped_missing_step_rejected`, `range_stepped_nonfinite_rejected`, `range_stepped_zero_rejected` |
| Assign path | `assign_path_unboxed_structured_rejected` |
| JSON encoding | `json_encode_nonfinite_rejected`, `json_encode_missing_path` |
| Display | `display_non_json_rejected` |
| Parse | `parse_assignment_missing_lhs` |
| Deep assignment | `trie_deep_assignment_fail_mode` |
| Debugger | `debugger_postmortem_dispatch_error`, `debugger_cli_postmortem` |

## Adding New Error Cases

When a node or parser raises a new `Exception.CreateFmt`, follow these steps:

1. **Raise the exception** in the relevant source file with a descriptive
   message. Use `Exception.CreateFmt` when the message includes dynamic values
   (e.g., the offending value, index, or path).

2. **Add a fixture** in `tests/cases/` with `<name>_<description>_rejected.in`
   and `<name>_<description>_rejected.out`. The `.out` file should contain the
   exact `Error:` line(s) produced.

3. **Verify** with `tests/run.sh --filter <name>`.

## Related Pages

- [Debugging Evaluation Behavior](debugging-evaluation-behavior.md)
- [Event Logs](debugging-evaluation-behavior/event-logs.md)
- [Statement Execution](execution-order/statement-execution.md)
