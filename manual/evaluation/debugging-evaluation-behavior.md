# Debugging Evaluation Behavior

When output is surprising, inspect the tree boundaries first, then use the built-in debugger for deep runtime inspection.

## Checklist

- Check matching delimiters: `[ ]`, `( )`, `{ }`, and backticks.
- Check whether evaluation is explicit with `{ ... }`.
- Check whether compute scope is needed.
- Check whether a repeat form is inside or outside the evaluated subtree.
- Compare the example with a test fixture when possible.

## Debugger Overview

Mantra includes a built-in debugger that lets you pause execution, inspect the call stack, examine variables and settings, and step through evaluation. The debugger activates when a **breakpoint**, **exception**, or **manual pause** is triggered and presents an interactive command prompt (`dbg>`).

### Enabling the Debugger

The debugger is configured at runtime via `ConfigureDebuggerRuntime` with a `TDebuggerState` instance and an option to enable the interactive CLI. When the CLI is enabled and a pause is triggered, `RunDebuggerCommandLoop` presents the `dbg>` prompt.

### Pause Reasons

The debugger pauses execution for the following reasons:

- **breakpoint** — A configured breakpoint matched the current event.
- **watchpoint** — A variable or setting write was intercepted.
- **step** — A step/next/finish command completed and reached the next stop.
- **exception** — An error was raised during evaluation.
- **manual** — Execution was manually interrupted.

When paused, the debugger displays the pause reason and the triggering event or breakpoint message.

## Debugger Commands

The debugger supports these commands at the `dbg>` prompt:

### Breakpoint Management

| Command | Description |
|---------|-------------|
| `break <kind> <pattern>` | Add a breakpoint. Kinds: `callable`, `statement`, `rule`, `inference`, `source` |
| `breakpoints` / `info` | List all breakpoints |
| `delete <n>` | Delete breakpoint at index `n` |
| `clear` | Delete all breakpoints |

**Breakpoint kinds:**

- **`callable <pattern>`** — Breaks when a callable matching the pattern is dispatched. Use wildcard patterns (`*`, `?`). Example: `break callable main.ping`
- **`statement <pattern>`** — Breaks when a statement matching the pattern is entered. Example: `break statement *ping*`
- **`rule <pattern>`** — Breaks when a rewrite rule matching the pattern is probed. Example: `break rule fail`
- **`inference <pattern>`** — Breaks during inference engine events matching the pattern.
- **`source <spec>`** — Breaks at a specific source location. Spec formats: `LINE`, `FILE:LINE`, or `FILE:LINE:COL`. Example: `break source 5` or `break source main.m:42`

### Inspection

| Command | Description |
|---------|-------------|
| `bt` / `where` | Show the debugger stack (call trace) |
| `frame [n]` | Show details for frame `n` (0 = top frame) |
| `events [n]` | Show the `n` most recent debugger events (default: 16) |
| `reason` | Show the current pause reason |
| `context` / `ctx` | Show runtime context summary (namespace, rewrite count, dispatch count, selection count, inference count) |
| `postmortem` / `pm` | Show full postmortem report (reason, stack, recent events) |
| `inspect` | Emit machine-readable inspection snapshot (TSV format) |
| `inspect children <vars|settings> [path]` | List children of a variable or settings path |
| `inspect value <vars|settings> [path]` | Resolve and display a variable or settings value |

### Stepping

| Command | Description |
|---------|-------------|
| `next` / `n` | Resume until the next statement-level stop |
| `step` / `s` | Resume until the next semantic stop (deepest entry) |
| `finish` / `fin` / `out` | Resume until the current frame exits |
| `quit` / `q` / `exit` / `continue` / `c` | Resume execution and exit the debugger prompt |
| `help` / `h` / `?` | Show the command reference |

## Debugger Stack

The `bt` command shows the call stack as a numbered list. Frame indices count from 0 (top/most recent) upward. Each frame shows:

- **Frame kind** — `statement`, `eval`, `dispatch`, `rewrite-probe`, `rewrite-apply`, `inference`, or `import`
- **Name** — The callable or rule name (if applicable)
- **Summary** — A text description of the statement or operation
- **Step / State** — The inference step or state ID (if applicable)

Example output:

```
Debugger Stack:
  #0 dispatch main.ping | ping z
  #1 eval | { ping z }
  #2 statement | { ping z }
```

## Frame Details

The `frame <n>` command shows detailed information about a specific frame:

```
Frame #0
  kind: statement
  summary: { ping a }
  source: debugger_breakpoint_two_statements.m:2:1
  node-index: 8
```

## Machine-Readable Inspection

The `inspect` command emits TSV-formatted data for programmatic consumption. The snapshot includes:

- **Pause information** — reason, message, and source location
- **Frame details** — kind, name, summary, source, node index
- **Context** — namespace, rewrite/dispatch/selection/inference counts
- **Variables** — all variables in scope (up to 64)
- **Settings** — Mantra settings (up to 32)
- **Events** — recent event log entries (up to 16)

The output is wrapped in `@inspect begin` / `@inspect end` markers and uses tab-separated fields.

For deeper inspection, use subcommands:

- `inspect children vars [path]` — List child paths under a variable path
- `inspect children settings [path]` — List child settings under a Mantra settings path
- `inspect value vars [path]` — Resolve and display a specific variable value
- `inspect value settings [path]` — Resolve and display a specific settings value

## Postmortem Reports

The `postmortem` command generates a complete report including:

1. Pause reason
2. Full debugger stack trace
3. Recent debugger events

This is useful when an exception occurs and you need to understand the execution path that led to the error.

## Event Types

The debugger tracks these event kinds:

- `statement-enter` / `statement-exit` — Statement boundary events
- `eval-scope-enter` / `eval-scope-exit` — Evaluation scope boundaries
- `callable-dispatch-enter` / `callable-dispatch-exit` — Callable invocation
- `import-enter` / `import-exit` — Module import operations
- `rewrite-probe` / `rewrite-apply` — Rewrite rule matching and application
- `inference-state-enter` / `inference-state-exit` — Inference engine state changes
- `inference-candidate` — Inference candidate generation
- `variable-write` — Variable assignment
- `setting-read` / `setting-write` — Configuration setting access
- `exception-raised` — Error during evaluation

## Related Pages

- [Event Logs](debugging-evaluation-behavior/event-logs.md)
- [Error Reporting](error-reporting.md)
- [Evaluation Scopes](evaluation-scopes.md)
- [Nested Evaluation](nested-evaluation.md)
