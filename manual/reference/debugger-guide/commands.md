# Debugger Commands

When paused in the debugger CLI (`--debugger-cli`), the prompt `dbg> ` accepts
the following commands. All commands are available regardless of the pause
reason — breakpoint, step, or exception.

## Command Reference

| Command | Aliases | Description |
|---|---|---|
| `help` | `h`, `?` | Show this help |
| `breakpoints` | `info` | List all breakpoints |
| `break KIND PATTERN` | `b` | Add a breakpoint |
| `delete N` | `d` | Delete breakpoint by index |
| `clear` | — | Remove all breakpoints |
| `bt` | `where` | Show debugger stack trace |
| `frame [N]` | `f` | Show details for frame N (0 = top) |
| `events [N]` | `ev` | Show last N events (default 16) |
| `reason` | — | Show current pause reason |
| `context` | `ctx` | Show runtime context summary |
| `next` | `n` | Step to next statement |
| `step` | `s` | Step to next semantic event |
| `finish` | `fin`, `out` | Run until current frame exits |
| `inspect` | `ins` | Machine-readable debugger data |
| `inspect children <domain> [path]` | — | List children of a variable or setting |
| `inspect value <domain> [path]` | — | Show value of a variable or setting |
| `postmortem` | `pm` | Print full postmortem report |
| `quit` | `q`, `exit`, `continue`, `c` | Exit debugger, resume execution |

## Inspection Commands

### `bt` — Backtrace

Prints the full debugger stack from the current frame outward:

```
dbg> bt
Debugger Stack:
  #0 dispatch main.ping | ping z
  #1 eval | { ping z }
  #2 statement | { ping z }
```

Frames are numbered with #0 as the current (innermost) frame.

### `frame N` — Frame detail

Shows detailed information about a specific frame:

```
dbg> frame 0
Frame #0
  kind: dispatch
  name: main.ping
  summary: ping z
  source: program.m:3
  node-index: 5
  step: 0
```

Omitting `N` defaults to frame 0 (the top/current frame).

### `events N` — Recent events

Shows the last N debugger events (default 16):

```
dbg> events 3
Recent Debugger Events:
  - dispatch-enter main.ping
  - rewrite-probe ping X => { ... } | direction=forward
  - statement-enter
```

### `reason` — Pause reason

Shows why the debugger is currently paused:

```
dbg> reason
Pause reason: breakpoint
```

### `context` — Runtime context

Shows the current runtime context summary with counters:

```
dbg> context
Debugger Context:
  namespace: main
  rewrite-count: 0
  dispatch-count: 1
  selection-count: 0
  inference-count: 0
```

## Variable and Settings Inspection

### `inspect` — Full snapshot

With no arguments, prints a machine-readable snapshot of all debugger state:

```
dbg> inspect
@inspect	begin
@inspect	pause	reason	breakpoint
@inspect	pause	message	source program.m:2
@inspect	pause	source-path	/projects/mantra/program.m
@inspect	pause	source-line	2
@inspect	frame	present	1
@inspect	frame	kind	statement
@inspect	frame	summary	{ ping a }
@inspect	context	present	1
@inspect	context	namespace	main
@inspect	vars	count	0
@inspect	settings	count	0
@inspect	events	count	3
@inspect	event	statement-enter
@inspect	event	statement-exit
@inspect	event	statement-enter
@inspect	end
```

Output is tab-separated with `begin`/`end` markers for programmatic parsing.

### `inspect children` — List children

Lists the children of a variable or setting path:

```
dbg> inspect children vars
dbg> inspect children vars dict
dbg> inspect children vars dict.obj1
dbg> inspect children settings mantra
dbg> inspect children settings mantra.inference
```

Domains: `vars` for variables, `settings` for runtime settings.

### `inspect value` — Show value

Shows the resolved value at a specific path:

```
dbg> inspect value vars dict.obj1.attr.x
dbg> inspect value settings mantra.inference.beam
```

## Breakpoint Commands

### `break` — Add breakpoint

```
dbg> break callable main.ping
dbg> break statement '* ping *'
dbg> break rule '*transform*'
dbg> break inference '*step=1*'
dbg> break source lib.m:10
dbg> break source 42
```

### `breakpoints` / `info` — List

```
dbg> breakpoints
Breakpoints:
  [0] source program.m:2
  [1] callable main.ping
```

### `delete N` — Remove one

```
dbg> delete 1
Deleted breakpoint 1
```

### `clear` — Remove all

```
dbg> clear
Cleared breakpoints
```

## Postmortem

### `postmortem` / `pm`

Prints the complete postmortem report — pause reason, full stack trace, and
recent events — at any point during an interactive session:

```
dbg> postmortem
Debugger Postmortem
Pause reason: breakpoint

Debugger Stack:
  #0 dispatch main.ping | ping z
  #1 eval | { ping z }
  #2 statement | { ping z }

Recent Debugger Events:
  - statement-enter
  - eval-enter
  - dispatch-enter main.ping
```

This is useful for capturing a structured dump while still in the interactive
session.

## Help

```
dbg> help
Debugger commands:
  help              Show this help
  breakpoints       List breakpoints
  break KIND PATTERN
                    Add breakpoint (KIND = callable|statement|rule|inference|source)
                    source spec: LINE | FILE:LINE | FILE:LINE:COL
  delete N          Delete breakpoint N
  clear             Delete all breakpoints
  bt                Show debugger stack
  frame [N]         Show frame details (0 = top frame)
  events [N]        Show recent debugger events
  reason            Show current pause reason
  context           Show current runtime context summary
  next              Resume until the next statement-level stop
  step              Resume until the next semantic stop
  finish            Resume until the current frame exits
  inspect [MODE]    Emit machine-readable debugger data
                    inspect
                    inspect children <vars|settings> [path]
                    inspect value <vars|settings> [path]
  postmortem        Show full postmortem report
  quit              Exit debugger prompt
```

## See Also

- [Breakpoints](breakpoints.md) — Breakpoint kinds and usage
- [Stepping](stepping.md) — step, next, finish
- [Postmortem Debugging](postmortem.md) — Non-interactive error reports
- [Command Line: Debugger Options](../command-line/debugger-options.md) — CLI flags
