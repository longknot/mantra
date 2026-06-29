# Postmortem Flag

`--debugger-postmortem` automatically prints the debugger stack trace and recent
event log when a Mantra program terminates with an exception.

## Quick Start

```bash
./bin/mantra --debugger-postmortem program.m
```

When the program raises an exception, Mantra prints the standard error message
followed by a full postmortem report to stdout before exiting. No interactive
session is opened — the output goes directly to the terminal.

## When to Use

Postmortem mode is useful when an interactive debugger session is not practical
or desirable:

- **CI/CD pipelines** — capture the failure path in log output without
  requiring a TTY or interactive terminal.
- **Batch test runs** — append structured failure context to each test result
  for later analysis.
- **Remote execution** — diagnose failures on machines where you cannot attach
  a live debugger.
- **Quick diagnosis** — get the execution stack and recent events with a single
  flag instead of rerunning with `--debugger-cli`.
- **Fixture diagnostics** — the output is deterministic and self-contained,
  making it easy to diff against expected results.

## Report Structure

The postmortem report has three sections:

### Pause Reason

```
Debugger Postmortem
Pause reason: exception
```

The pause reason identifies why the debugger stopped. Possible values:

| Reason | Description |
|---|---|
| `exception` | An error occurred during evaluation or execution. |
| `breakpoint` | A breakpoint was hit. |
| `watchpoint` | A watched variable or setting was modified. |
| `step` | Stepping (`step`/`next`/`finish`) reached a stop point. |
| `manual` | Execution was paused manually. |
| `none` | No pause reason recorded. |

For `--debugger-postmortem`, this will almost always be `exception`.

### Debugger Stack

```
Debugger Stack:
  #0 statement | step=1 | state=42
  #1 dispatch f | step=0 | state=15
```

Lists the current call stack from most recent frame (#0) to the oldest.
Each frame line shows:

- **Frame number** — `#0` is the innermost (current) frame.
- **Frame kind** — `statement`, `eval`, `dispatch`, `rewrite-probe`,
  `rewrite-apply`, `inference-state`, `import`, or `unknown`.
- **Name** — the callable name (for `dispatch` frames) or summary text.
- **Step** — the current step count within that frame.
- **State** — the state ID for inference tracking.

### Recent Events

```
Recent Debugger Events:
  - exception Exception raised: undefined variable 'x'
  - statement-exit
  - eval-scope-enter
  - dispatch f
  - statement-enter
```

Shows the last 16 debugger events in chronological order. Event kinds include:

| Event Kind | Meaning |
|---|---|
| `statement-enter` / `statement-exit` | Statement execution boundaries. |
| `eval-scope-enter` / `eval-scope-exit` | Evaluation scope `{ ... }` boundaries. |
| `callable-dispatch-enter` / `callable-dispatch-exit` | Callable invocation boundaries. |
| `import-enter` / `import-exit` | Module import boundaries. |
| `rewrite-probe` | A rewrite rule was probed (matched or not). |
| `rewrite-apply` | A rewrite rule was applied. |
| `inference-state-enter` / `inference-state-exit` | Inference proof-search state transitions. |
| `inference-candidate` | A candidate solution was found during inference. |
| `variable-write` | A variable assignment occurred. |
| `setting-read` / `setting-write` | Runtime setting access. |
| `exception` | An exception was raised. |

Each event line may include the callable name and a message text where
applicable.

## Combining with Other Flags

### With `--debugger-cli`

When both `--debugger-postmortem` and `--debugger-cli` are present, the
postmortem report is printed first, then the interactive debugger command loop
opens. Inside the CLI, you can also run the `postmortem` or `pm` command to
reprint the report at any time.

```bash
./bin/mantra --debugger-postmortem --debugger-cli program.m
```

### With Breakpoints

```bash
./bin/mantra --debugger-postmortem --break-source=program.m:5 program.m
```

If a breakpoint causes execution to pause, the postmortem report will show
`Pause reason: breakpoint` and the event log will include the breakpoint hit.

### With `--debugger`

The postmortem flag requires the debugger event recorder to be enabled. If
`--debugger-postmortem` is used without `--debugger`, the event recorder is
enabled automatically as a dependency.

```bash
./bin/mantra --debugger-postmortem program.m
```

## Example

Given a program that references an undefined variable:

```mantra
print x
```

```bash
$ ./bin/mantra --debugger-postmortem program.m
Error: undefined variable 'x'
Debugger Postmortem
Pause reason: exception

Debugger Stack:
  #0 statement | step=0 | state=1

Recent Debugger Events:
  - exception Exception raised: undefined variable 'x'
  - statement-enter
```

The stack shows the failing statement frame, and the event log captures the
exception event followed by the statement that triggered it.

## Limitations

- Postmortem output is printed to stdout alongside normal program output. Pipe
  or redirect as needed to isolate it.
- The event log retains the last 512 events by default. If the program runs
  for a long time before failing, early events will not appear.
- Postmortem only triggers on exceptions — normal program termination produces
  no postmortem output.
- The report reflects debugger state at the moment of exception. If the
  exception occurs during early startup (before the debugger is initialized),
  the report may show minimal or empty data.
