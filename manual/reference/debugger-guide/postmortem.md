# Postmortem Debugging

Postmortem mode prints a structured debugger report — stack trace and recent
events — whenever a Mantra program raises an exception. It is the non-interactive
alternative to the debugger CLI: no prompt, no commands, just a diagnostic dump
at the moment of failure.

## When to Use Postmortem

Postmortem is the right choice when interactive debugging is not possible or
desirable:

- **CI/CD pipelines** — where there is no TTY for an interactive session
- **Batch test suites** — where hundreds of fixtures run headlessly
- **Automated error reporting** — where you want the stack in the log file
- **Quick diagnosis** — when you just need to know _what_ failed, not explore interactively

Postmortem output goes to stdout alongside the `Error:` message, so it captures
naturally in test harnesses, log collectors, and CI runners.

## Activation

```bash
# Print postmortem report after any exception
./bin/mantra --debugger-postmortem program.m
```

The flag `--debugger-postmortem` enables the event recorder and marks the runtime
to emit a report after every exception. Unlike `--debugger-cli`, it does not open
an interactive prompt — the program terminates after the report prints.

### Combining with Breakpoints

You can combine `--debugger-postmortem` with breakpoints. If execution hits a
breakpoint, it pauses; if it continues and then exceptions, the postmortem report
still prints at the end.

```bash
./bin/mantra --debugger-postmortem --break-source=program.m:5 program.m
```

### Combining with the Debugger CLI

Both flags can coexist. When combined, the postmortem report prints first,
followed by the interactive CLI for deeper inspection:

```bash
./bin/mantra --debugger-postmortem --debugger-cli program.m
```

## Report Structure

The postmortem report has three sections:

```
Debugger Postmortem
Pause reason: exception

Debugger Stack:
  #0 statement | { fail z }
  #1 eval | { fail z }
  #2 dispatch main.fail | fail z

Recent Debugger Events:
  - statement-enter
  - eval-enter
  - dispatch-enter main.fail
  - rewrite-probe fail X => { assign_path } | direction=forward
  - exception main.fail | assign_path path must resolve to scalar path text
```

### Pause Reason

The first line identifies why the debugger paused:

| Reason | Meaning |
|---|---|
| `exception` | A runtime exception was raised (most common in postmortem) |
| `breakpoint` | Execution stopped at a breakpoint |
| `step` | A stepping command triggered a pause |
| `watchpoint` | A watched variable or setting changed |
| `manual` | A manual pause request |
| `none` | No pause reason (unusual; indicates missing state) |

### Debugger Stack

The stack shows the call chain from the outermost frame to the point of failure.
Frames are numbered bottom-to-top — higher numbers are closer to where the
exception occurred.

Each frame line follows this format:

```
#<N> <kind> [<name>] [| <summary>] [| step=<N>] [| state=<N>]
```

| Field | Description |
|---|---|
| `#<N>` | Frame index (0 = bottom/oldest, highest = closest to exception) |
| `kind` | Frame type: `statement`, `eval`, `dispatch`, `rewrite-probe`, `rewrite-apply`, `inference-state`, `import` |
| `name` | Callable name (for `dispatch` frames), rule name (for rewrite frames) |
| `summary` | Human-readable description of the frame content |
| `step=<N>` | Step counter (for inference and rewrite frames) |
| `state=<N>` | State identifier (for inference frames) |

When source location information is available, it appears in the frame detail
(output by the `frame` CLI command):

```
  source: program.m:42:8
```

### Frame Types

| Kind | Description |
|---|---|
| `statement` | A top-level statement in the source |
| `eval` | An evaluation scope `{ ... }` |
| `dispatch` | A callable dispatch (function/callable call) |
| `rewrite-probe` | A pattern rewrite attempt |
| `rewrite-apply` | A rewrite that was applied |
| `inference-state` | An inference/proof-search state |
| `import` | A module import operation |
| `unknown` | An unrecognized frame (internal) |

### Recent Debugger Events

The event log shows the last 16 events leading up to the exception. Each event
identifies what the runtime was doing at that moment.

| Event | Description |
|---|---|
| `statement-enter` | Entering a statement |
| `statement-exit` | Leaving a statement |
| `eval-enter` | Entering an evaluation scope `{ ... }` |
| `eval-exit` | Leaving an evaluation scope |
| `dispatch-enter` | Calling a callable |
| `dispatch-exit` | Returning from a callable |
| `import-enter` | Loading an imported module |
| `import-exit` | Module import complete |
| `rewrite-probe` | Attempting a pattern rewrite |
| `rewrite-apply` | Applying a rewrite rule |
| `inference-state-enter` | Entering an inference proof state |
| `inference-state-exit` | Leaving an inference state |
| `inference-candidate` | An inference candidate was explored |
| `variable-write` | A variable was assigned |
| `setting-read` | A setting was read |
| `setting-write` | A setting was modified |
| `exception` | An exception was raised (always the last event in postmortem) |

Events with additional context show pipe-separated details:

```
rewrite-probe fail X => { assign_path } | direction=forward
exception main.fail | assign_path path must resolve to scalar path text
```

## Complete Example

Given a program `fail.m`:

```mantra
rule fail [ fail X => { assign_path "root.expr" + m n } ]
{ fail z }
```

Run with postmortem:

```bash
./bin/mantra --debugger-postmortem fail.m
```

Output:

```
Error: assign_path path must resolve to scalar path text; wrap structured values in (...) or {...}
Debugger Postmortem
Pause reason: exception

Debugger Stack:
  #0 dispatch main.fail | fail z
  #1 eval | { fail z }
  #2 statement | { fail z }

Recent Debugger Events:
  - statement-enter
  - statement-exit
  - statement-enter
  - eval-enter
  - dispatch-enter main.fail
  - rewrite-probe fail X => { assign_path } | direction=forward
  - exception main.fail | assign_path path must resolve to scalar path text
```

Reading this report:

1. The **error message** tells us what failed — `assign_path` received a non-scalar
   path argument.
2. The **stack** shows the call chain: a `statement` containing an `eval` scope
   dispatched the callable `main.fail` (frame #0, closest to the exception).
3. The **events** show the sequence: statement entered, eval entered, callable
   dispatched, a rewrite was probed, then the exception was raised inside the
   callable `main.fail`.

## Postmortem in the Interactive CLI

When using `--debugger-cli`, you can also request the full postmortem report
manually using the `postmortem` command:

```
dbg> postmortem
Debugger Postmortem
Pause reason: exception
...
```

This is useful when you want the structured dump alongside interactive exploration
or when you want to capture the report at a specific point during a debugging session.

## Event Buffer

The debugger records events in a circular buffer. The default buffer size is 256
events, though the postmortem report shows only the last 16. This means:

- If the program performs many operations before the exception, only the final 16
  events appear in the report.
- The actual buffer holds 256 events, so deeper history is available through the
  interactive CLI (`events 256` to see the full buffer).

## Limitations

- **Postmortem only prints on exceptions.** If a program completes without raising
  an error, no report is generated.
- **No variable inspection.** The postmortem report shows the call stack and events
  but does not include variable values or the runtime context summary. Use
  `--debugger-cli` for variable inspection.
- **Source locations may be absent.** When Mantra parses from stdin or inline
  expressions, frames may lack file:line:col source references.

## Comparison: Postmortem vs. CLI

| Feature | `--debugger-postmortem` | `--debugger-cli` |
|---|---|---|
| Interactive prompt | No | Yes |
| Postmortem report | Yes (automatic) | Manual (`postmortem` command) |
| Variable inspection | No | Yes (`inspect`, `context`) |
| Stepping commands | No | Yes (`step`, `next`, `finish`) |
| Breakpoint management | No | Yes (`break`, `delete`) |
| Suitable for CI/CD | Yes | No (needs TTY) |
| Continues after pause | No (exits after report) | Yes (after `continue`) |

## See Also

- [Stepping](stepping.md) — Interactive stepping commands for fine-grained debugging
- [Breakpoints](breakpoints.md) — Setting and managing breakpoints
- [Error Reporting](../../evaluation/error-reporting.md) — How Mantra reports and handles errors
