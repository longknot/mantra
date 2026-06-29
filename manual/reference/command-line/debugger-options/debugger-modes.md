# Debugger Modes

Mantra provides three debugger activation modes that control how the debugger interacts with your program — from silent event recording to full interactive debugging. All three modes share the same underlying event recorder, which tracks semantic events across the evaluation lifecycle.

## `--debugger` — Silent Event Recording

The `--debugger` flag enables the debugger event recorder without pausing execution or opening any interactive prompt. The recorder silently captures all semantic events — statement boundaries, callable dispatches, rewrite probes, inference states, variable writes, setting access, and exceptions — into a rolling buffer (256 events by default).

```bash
./bin/mantra --debugger program.m
```

This mode does not pause execution. The event recorder runs in the background, maintaining an internal stack frame and event log. If no other debugger feature (CLI, postmortem, or breakpoints) is configured, the recorded data is not printed to stdout.

**When to use:**
- Programmatic tooling that hooks into the debugger event sink API
- As a dependency for `--debugger-postmortem` (enabled automatically if omitted)
- Performance profiling where you want the event recorder active but with zero UI overhead

**Architecture:**
Under the hood, `--debugger` creates a `TDebuggerState` instance (which extends `TDebuggerSink`) and registers it as the active debugger sink via `SetDebuggerSink`. Every semantic event emitted by `EmitDebuggerEvent` is routed to this state object, which maintains:
- A **frame stack** — pushed on enter events (`statement-enter`, `eval-enter`, `dispatch-enter`, etc.) and popped on corresponding exit events
- A **rolling event log** — the most recent N events (default 256, configurable via `RecentEventLimit`)
- **Breakpoint matching** — even without `--debugger-cli`, breakpoints are checked on every event

## `--debugger-cli` — Interactive Debugging

The `--debugger-cli` flag enables the full interactive debugger. When execution pauses — at breakpoints, stepping commands, or runtime exceptions — the `dbg> ` command loop opens where you can inspect the stack, variables, settings, and recent events.

```bash
./bin/mantra --debugger-cli program.m
```

The debugger CLI opens whenever one of these conditions is met:
- **Breakpoints** set via `--break-*` flags or the `break` command at the prompt
- **Stepping commands** (`step`, `next`, `finish`) issued from the prompt
- **Runtime exceptions** — automatic pause on error

**Pause reasons:**
The debugger tracks why it paused. Possible values:

| Reason | Description |
|---|---|
| `exception` | An error occurred during evaluation or execution |
| `breakpoint` | A breakpoint pattern or source location matched |
| `step` | A stepping command (`step`/`next`/`finish`) reached its stop point |
| `watchpoint` | A watched variable or setting was modified |
| `manual` | Execution was paused manually |

**Command loop:**
When paused, the debugger prompt accepts these commands (with aliases):

| Command | Aliases | Description |
|---|---|---|
| `help` | `h`, `?` | Show available commands |
| `breakpoints` | `info` | List all active breakpoints |
| `break KIND PATTERN` | `b` | Add a breakpoint (`callable`, `statement`, `rule`, `inference`, `source`) |
| `delete N` | `d` | Delete breakpoint by index |
| `clear` | | Remove all breakpoints |
| `bt` | `where` | Show the debugger stack trace |
| `frame [N]` | `f` | Show details for frame N (0 = top/innermost) |
| `events [N]` | `ev` | Show N most recent debugger events (default 16) |
| `reason` | | Show the current pause reason and message |
| `context` | `ctx` | Show runtime context: namespace and rewrite/dispatch/selection/inference counters |
| `next` | `n` | Resume until the next statement-level stop in the current source file |
| `step` | `s` | Resume until the next semantic stop (statement, eval, dispatch, import, rewrite, inference) |
| `finish` | `fin`, `out` | Resume until the current frame exits |
| `inspect` | `ins` | Emit a machine-readable snapshot for debugger adapters |
| `inspect children <vars\|settings> [path]` | | Lazy trie expansion of variables or settings |
| `inspect value <vars\|settings> [path]` | | Exact node lookup with preview |
| `postmortem` | `pm` | Print the full postmortem report (stack + events) |
| `quit` | `q`, `exit`, `continue`, `c` | Resume execution or exit |

**Stepping modes:**
The three stepping commands differ in granularity:

- **`step`** (`s`) — pauses at every semantic boundary: statement entry, eval scope entry, callable dispatch, import entry, rewrite probe, or inference state entry. Most fine-grained.
- **`next`** (`n`) — pauses at the next statement-level stop within the current source file. Skips into callee bodies.
- **`finish`** (`fin`) — resumes until the current frame pops, then pauses. Equivalent of "step out."

**When stdin is not a TTY**, the debugger still accepts piped input, enabling scripted debugging sessions:
```bash
printf '%s\n' 'reason' 'bt' 'events 3' 'quit' | \
  ./bin/mantra --debugger-cli --break-rule='*foo*' program.m
```

**When to use:**
- Step-by-step debugging of program logic
- Inspecting variable values, settings, and call stacks at runtime
- Adding breakpoints interactively during a session
- Exploring rewrite and inference behavior

**`inspect` protocol:**
The `inspect` command emits machine-readable output prefixed with `@inspect<TAB>` designed for debugger adapters (IDEs, VS Code extensions). A bare `inspect` produces a snapshot containing:
- **Pause** — reason, message, and source location
- **Frame** — kind, name, summary, source, node index, step, state ID
- **Context** — namespace, rewrite/dispatch/selection/inference counters
- **Variables** — up to 64 variable matches (name + node ref)
- **Settings** — up to 32 runtime setting matches under the `mantra.*` root
- **Events** — up to 16 recent debugger events

The `inspect children` and `inspect value` variants support lazy trie expansion for large variable namespaces, emitting child-presence metadata and preview text.

## `--debugger-postmortem` — Exception Reports

The `--debugger-postmortem` flag prints a structured debugger report — stack trace and recent events — whenever a program raises an exception. No interactive prompt opens; the program prints the report and exits immediately after.

```bash
./bin/mantra --debugger-postmortem program.m
```

The report structure always contains three sections:

1. **Pause reason** — always `exception` for postmortem-triggered reports
2. **Debugger Stack** — numbered frame stack from innermost (#0) to outermost, showing frame kind, name/summary, step count, and state ID
3. **Recent Debugger Events** — the last 16 events in chronological order, showing event kind with associated frame details

**When to use:**
- CI/CD pipelines where no TTY is available
- Batch test runs producing log output
- Quick error diagnosis without interactive debugging
- Automated error reporting and log collection
- Fixture diagnostics — the output is deterministic and self-contained

**Postmortem only triggers on exceptions.** Normal program termination produces no postmortem output. The event log retains the last 256 events; for long-running programs, early events will not appear in the report.

**See also:** [Postmortem Flag](postmortem-flag.md) for the full report format specification, event kinds, and frame kinds.

## Mode Comparison

| Feature | `--debugger` | `--debugger-cli` | `--debugger-postmortem` |
|---|---|---|---|
| Event recording | Yes | Yes | Yes |
| Interactive prompt | No | Yes | No |
| Pauses on breakpoints | No | Yes | No |
| Stepping commands (`step`/`next`/`finish`) | No | Yes | No |
| Variable/setting inspection | No | Yes (`inspect`) | No |
| Exception report | No | Manual (`postmortem` cmd) | Automatic |
| Pauses on exceptions | No | Yes | No (exits with report) |
| Suitable for CI/CD | Yes (for tooling) | No | Yes |

## Combining Modes

### `--debugger-cli` with `--debugger-postmortem`

Both flags can coexist. When combined, the postmortem report prints first when an exception occurs, followed by the interactive CLI for deeper inspection:

```bash
./bin/mantra --debugger-postmortem --debugger-cli program.m
```

This is useful when you want both the printed report (for logs) and the interactive prompt (for follow-up investigation). Inside the CLI, you can re-run `postmortem` or `pm` at any time to reprint the report.

### `--debugger` with `--debugger-postmortem`

The `--debugger-postmortem` flag automatically enables the event recorder, so `--debugger` is redundant:

```bash
# These are equivalent:
./bin/mantra --debugger --debugger-postmortem program.m
./bin/mantra --debugger-postmortem program.m
```

### With Breakpoints

All three modes work with `--break-*` flags. Note that any `--break-*` flag automatically enables both `--debugger` and `--debugger-cli` as dependencies:

```bash
# Interactive debugging with breakpoints
./bin/mantra --debugger-cli --break-callable=main.ping --break-source=program.m:5 program.m

# Postmortem with a source breakpoint
./bin/mantra --debugger-postmortem --break-source=program.m:5 program.m

# Silent recording with breakpoints (breakpoints still checked but no pause UI)
./bin/mantra --debugger --break-callable=main.ping program.m
```

## See Also

- [Breakpoint Flags](breakpoint-flags.md) — `--break-*` flag reference
- [Postmortem Flag](postmortem-flag.md) — `--debugger-postmortem` report format details
- [Breakpoints](../debugger-guide/breakpoints.md) — Setting and managing breakpoints
- [Stepping](../debugger-guide/stepping.md) — `step`, `next`, `finish` commands
- [Postmortem Debugging](../debugger-guide/postmortem.md) — Non-interactive error diagnosis
