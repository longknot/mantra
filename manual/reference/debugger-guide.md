# Debugger Guide

The Mantra debugger inspects program execution at runtime. It records every
semantic event — statement entry and exit, callable dispatch, rule probes,
inference states, evaluation scopes, and imports — and lets you pause execution
to inspect the call stack, variables, and settings.

## Quick Start

Attach the debugger and break on the first statement of a program:

```bash
mantra --debugger-cli program.m
```

This enters the interactive debugger prompt. Type `help` for available commands.

Break on a specific source line before running:

```bash
mantra --debugger-cli --break-source=42 program.m
```

Or stop on an exception without an interactive prompt:

```bash
mantra --debugger-postmortem program.m
```

## Debugger Modes

Three modes control how the debugger interacts with your program:

- **`--debugger`** — silently records events. Does not pause execution.
  Useful when you want event history without interaction.
- **`--debugger-cli`** — pauses execution at breakpoints, steps, and exceptions,
  and enters the interactive debugger command loop.
- **`--debugger-postmortem`** — prints the debugger stack and recent events
  when an exception occurs. No interactive prompt.

## Breakpoints

Breakpoints stop execution when a matching runtime event occurs. Set them from
the command line or add them interactively at the debugger prompt.

### Command-line breakpoints

| Flag | Stops when |
|---|---|
| `--break-source SPEC` | Execution reaches a source location (`LINE`, `FILE:LINE`, or `FILE:LINE:COL`; line and col must be > 0) |
| `--break-callable NAME` | A callable matching `NAME` is about to dispatch (`*`, `?` wildcards; matches the callable's `name` field) |
| `--break-statement TEXT` | A statement matching `TEXT` is about to execute (`*`, `?` wildcards; matches the frame `summary` field) |
| `--break-rule TEXT` | A rule matching `TEXT` probes successfully (`*`, `?` wildcards; matches the frame `name` field) |
| `--break-inference TEXT` | An inference state matching `TEXT` is entered (`*`, `?` wildcards; matches a pipe-separated composite — see below) |

Example — break when `main.ping` dispatches:

```bash
mantra --debugger-cli --break-callable=main.ping program.m
```

Example — break on line 3 of the main file:

```bash
mantra --debugger-cli --break-source=3 program.m
```

Example — break on a specific file and line:

```bash
mantra --debugger-cli --break-source=program.m:42 program.m
```

Source breakpoints support wildcard file names for included or imported files:

```bash
mantra --debugger-cli --break-source='*sub.m:3' main.m
```

Source breakpoint file names are matched against both the full file path and the
basename, so `*sub.m:3` will match `sub.m`, `/lib/sub.m`, `packages/core/sub.m`, etc.

### Wildcard pattern syntax

Breakpoint patterns for `callable`, `statement`, `rule`, and `inference` kinds
support two wildcard characters:

| Wildcard | Matches |
|---|---|
| `*` | Any sequence of characters (including empty) |
| `?` | Exactly one character |

Matching is **case-sensitive**.

```bash
mantra --debugger-cli --break-callable='main.pi?' program.m
# matches main.ping but not main.pingpong
```

### Inference breakpoint matching

Inference breakpoints match against a composite description built from the
inference state. The description concatenates (pipe-separated):

1. the callable **name**
2. the event **message** (if present)
3. the frame **summary** (if present)
4. `step=<N>` (if the step counter is set)
5. `state=<N>` (if the state ID is set)

A pattern like `*step=1*` will match any inference state where the step counter
is `1`, regardless of the callable name. A pattern like `main.solve*` matches
any inference state entered during `main.solve`.

### Breakpoints at the debugger prompt

Add, list, and delete breakpoints while paused:

```
dbg> break callable main.ping
Added breakpoint: [1] callable main.ping

dbg> breakpoints
Breakpoints:
  [0] source program.m:2
  [1] callable main.ping

dbg> delete 0
Deleted breakpoint 0

dbg> clear
Cleared breakpoints
```

## Stepping

When paused, control execution with stepping commands:

| Command | Effect |
|---|---|
| `next` (`n`) | Resume until the next statement-enter at the same or shallower nesting depth in the same source file |
| `step` (`s`) | Resume until the next stop event: statement-enter, eval-scope-enter, callable-dispatch-enter, import-enter, rewrite-probe, or inference-state-enter |
| `finish` (`fin`, `out`) | Resume until the current frame exits (frame count drops below the current depth). Falls back to `step` behavior when already at frame depth 0 |

Example session:

```
dbg> step
Debugger paused: step
Debugger Stack:
  #0 eval | { ping a }
  #1 statement | { ping a }

dbg> next
Debugger paused: step
Debugger Stack:
  #0 statement | { ping b }
```

## Inspecting State

### Stack trace

```
dbg> bt
Debugger Stack:
  #0 dispatch main.ping | ping z
  #1 eval | { ping z }
  #2 statement | { ping z }
```

Use `frame N` to inspect a specific frame (0 = top):

```
dbg> frame 1
Frame #1
  kind: eval
  summary: { ping z }
  source: program.m:5
```

### Recent events

```
dbg> events
Recent Debugger Events:
  - statement-enter
  - eval-enter
  - dispatch-enter main.ping
```

### Pause reason and context

```
dbg> reason
Pause reason: breakpoint

dbg> context
Debugger Context:
  namespace: main
  rewrite-count: 0
  dispatch-count: 1
  selection-count: 0
  inference-count: 0
```

## Postmortem Mode

When `--debugger-postmortem` is set, the debugger prints the stack and recent
events automatically after an exception:

```
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
  - exception main.fail | assign_path path must resolve to scalar path text; ...
```

## Scripted Debugging

The debugger prompt reads from standard input, so you can pipe commands to it
for scripted or automated debugging sessions. When stdin is not connected to a
terminal, the prompt hides the `dbg> ` prompt text automatically:

```bash
printf '%s\n' 'reason' 'bt' 'events 8' 'quit' | \
  mantra --debugger-cli --break-rule='*foo*' program.m
```

This is useful in CI/CD pipelines, test scripts, or when you want a repeatable
debugging workflow without manual interaction.

## Event Buffer

The debugger records events in a circular buffer with a default capacity of 256
events. The `events` command shows the last 16 by default, but you can request
more:

```
dbg> events 256
```

If the program performs many operations, only the most recent events are
available. Increasing the buffer limit requires changing `RecentEventLimit` in
`TDebuggerState` (default: 256).

## Machine-readable Inspect Protocol

The `inspect` command emits tab-separated machine-readable data. Use it for
tooling integration or programmatic access to debugger state.

### Snapshot

`inspect` with no arguments produces a full snapshot of pause state, current
frame, context, variables, settings, and recent events:

```
@inspect	begin
@inspect	pause	reason	breakpoint
@inspect	pause	message	source program.m:2
@inspect	pause	source-path	/projects/mantra/program.m
@inspect	pause	source-line	2
@inspect	pause	source-col	0
@inspect	frame	present	1
@inspect	frame	kind	statement
@inspect	frame	summary	{ ping a }
@inspect	frame	name	
@inspect	frame	source-path	program.m
@inspect	frame	source-line	2
@inspect	frame	source-col	0
@inspect	frame	node-index	-1
@inspect	frame	aux-index	-1
@inspect	frame	step	-1
@inspect	frame	state-id	-1
@inspect	frame	parent-state-id	-1
@inspect	context	present	1
@inspect	context	namespace	main
...
@inspect	end
```

The frame fields `node-index`, `aux-index`, `step`, `state-id`, and `parent-state-id`
are set to `-1` when not applicable. They are populated for specific frame kinds:
`rewrite-probe` and `rewrite-apply` frames include `node-index` and `aux-index`;
`inference-state` frames include `step`, `state-id`, and `parent-state-id`.

### Variable and setting traversal

Inspect the variable tree with `inspect children` and `inspect value`:

```
dbg> inspect children vars
dbg> inspect children vars dict
dbg> inspect value vars dict.obj1.attr.x
```

Each subcommand emits a structured protocol block with `begin`/`end` markers,
field names, and values separated by tabs.

### Settings inspection

Settings live under the `mantra` root:

```
dbg> inspect children settings mantra
dbg> inspect value settings mantra.inference.beam
```

## Debugger Commands Reference

| Command | Aliases | Description |
|---|---|---|
| `help` | `h`, `?` | Show help |
| `breakpoints` | `info` | List breakpoints |
| `break KIND PATTERN` | `b` | Add breakpoint |
| `delete N` | `d` | Delete breakpoint by index |
| `clear` | — | Delete all breakpoints |
| `bt` | `where` | Show debugger stack |
| `frame [N]` | `f` | Show frame details (0 = top) |
| `events [N]` | `ev` | Show recent events (default 16) |
| `reason` | — | Show pause reason |
| `context` | `ctx` | Show runtime context summary |
| `next` | `n` | Step to next statement-enter at same/shallower depth in same file |
| `step` | `s` | Step to next stop event (statement, eval, dispatch, import, rewrite-probe, inference) |
| `finish` | `fin`, `out` | Run until current frame exits (falls back to step at depth 0) |
| `inspect [MODE]` | `ins` | Machine-readable data |
| `postmortem` | `pm` | Full postmortem report |
| `quit` | `q`, `exit`, `continue`, `c` | Exit debugger prompt |

## Frame Kinds

The debugger recognizes the following frame kinds, displayed in stack traces and frame details:

| Frame Kind | Description |
|---|---|
| `statement` | A statement block being executed |
| `eval` | An evaluation scope (expression evaluation) |
| `dispatch` | A callable dispatch |
| `rewrite-probe` | A rewrite rule probe (with `node-index`, `aux-index`) |
| `rewrite-apply` | A rewrite rule application (with `node-index`, `aux-index`) |
| `inference-state` | An inference state frame (with `step`, `state-id`, `parent-state-id`) |
| `import` | An import operation |

## Event Kinds

The `events` command shows the following event kinds:

| Event Kind | Description |
|---|---|
| `statement-enter` | Entered a statement block |
| `statement-exit` | Exited a statement block |
| `eval-enter` | Entered an evaluation scope |
| `eval-exit` | Exited an evaluation scope |
| `dispatch-enter` | Entered a callable dispatch |
| `dispatch-exit` | Exited a callable dispatch |
| `import-enter` | Entered an import operation |
| `import-exit` | Exited an import operation |
| `rewrite-probe` | A rewrite rule was probed |
| `rewrite-apply` | A rewrite rule was applied |
| `inference-state-enter` | Entered an inference state |
| `inference-state-exit` | Exited an inference state |
| `inference-candidate` | An inference candidate was found |
| `variable-write` | A variable was written |
| `setting-read` | A setting was read |
| `setting-write` | A setting was written |
| `exception` | An exception was raised |

Note: `step` only pauses on the "enter" events (`statement-enter`, `eval-enter`, `dispatch-enter`, `import-enter`, `rewrite-probe`, `inference-state-enter`), not on exit or data-change events.

## Current Limits

The debugger does not yet include:

- conditional breakpoint expressions
- enable/disable breakpoint toggles from the CLI (breakpoints have an `enabled` flag but no CLI command to toggle it)
- `variable-write` and `setting` breakpoints (types exist but are not exposed in the CLI)
- watchpoints for variable writes or settings changes in the CLI
- a full debugger UI for lazy variable trie expansion (available via `inspect` protocol only)

It is currently strongest for:

- tracing dispatch, rewrite, and inference paths
- source and statement breakpointing
- postmortem debugging after runtime exceptions

## Related Pages

- [Breakpoints](debugger-guide/breakpoints.md)
- [Stepping](debugger-guide/stepping.md)
- [Postmortem Debugging](debugger-guide/postmortem.md)
- [Debugger Commands](debugger-guide/commands.md)
- [Command Line: Debugger Options](command-line/debugger-options.md)
