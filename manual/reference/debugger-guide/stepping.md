# Stepping

Stepping commands let you advance program execution one step at a time. They
give you fine-grained control over what happens next — whether you want to skip
into callables, stay in the current scope, or fast-forward until a frame exits.

## Stepping Commands

Three commands control how far execution advances:

| Command | Aliases | Effect |
|---|---|---|
| `step` | `s` | Resume until the next semantic event (enters callables and evaluations) |
| `next` | `n` | Resume until the next statement in the current source scope |
| `finish` | `fin`, `out` | Resume until the current frame exits |

## `step` — Enter deeper

The `step` command resumes execution and pauses at the next semantic event. It
will enter callables, evaluation scopes, rewrite probes, and inference states.

```
dbg> step
Debugger paused: step
Debugger Stack:
  #0 eval | { ping a }
  #1 statement | { ping a }
```

After stepping into the statement `{ ping a }`, the top of the stack is now
an `eval` frame — the debugger stepped inside the evaluation scope. Step again:

```
dbg> step
Debugger paused: step
Debugger Stack:
  #0 dispatch main.ping | ping a
  #1 eval | { ping a }
  #2 statement | { ping a }
```

Now the top frame is a `dispatch` — the debugger stepped into the callable
`main.ping`.

## `next` — Stay at the same level

The `next` command resumes execution until the next statement in the current
source scope. It does not enter callables or sub-scopes — it treats them as
black boxes.

```
dbg> next
Debugger paused: step
Debugger Stack:
  #0 statement | { ping b }
```

After `next`, execution moved to the next statement `{ ping b }` without
stopping inside the callable that `ping a` invoked.

## `finish` — Run until current frame exits

The `finish` command (also `fin` or `out`) resumes execution until the current
frame completes and returns to its caller.

```
dbg> finish
Debugger paused: step
Debugger Stack:
  #0 statement | { ping c }
```

This is useful when you have stepped into a callable and want to run it to
completion without setting a breakpoint at the exit point.

## Stepping Example

Given a program with three statements:

```mantra
{ ping a }
{ ping b }
{ ping c }
```

A mixed stepping session might look like:

```
./bin/mantra --debugger-cli --break-source=1 program.m

Debugger paused: breakpoint
Breakpoint hit: source program.m:1

dbg> step
Debugger paused: step
Debugger Stack:
  #0 eval | { ping a }
  #1 statement | { ping a }

dbg> step
Debugger paused: step
Debugger Stack:
  #0 dispatch main.ping | ping a
  #1 eval | { ping a }
  #2 statement | { ping a }

dbg> finish
Debugger paused: step
Debugger Stack:
  #0 statement | { ping b }

dbg> next
Debugger paused: step
Debugger Stack:
  #0 statement | { ping c }

dbg> next
Debugger paused: step
Debugger Stack:
  #0 statement | { print "done" }
```

## Frame Kinds and Stepping

As you step through a program, different frame kinds appear on the stack:

| Frame Kind | Description | Appears when... |
|---|---|---|
| `statement` | A top-level statement | Stepping into a statement |
| `eval` | An evaluation scope `{ ... }` | Stepping into an eval block |
| `dispatch` | A callable dispatch | Stepping into a function call |
| `rewrite-probe` | A rewrite rule attempt | Stepping through a rule match |
| `rewrite-apply` | A rewrite rule application | Stepping through an applied rule |
| `inference-state` | An inference proof state | Stepping through inference search |
| `import` | A module import | Stepping through module loading |

Use `bt` (backtrace) to see the full stack at any point:

```
dbg> bt
Debugger Stack:
  #0 dispatch main.ping | ping a
  #1 eval | { ping a }
  #2 statement | { ping a }
```

The `frame N` command shows details for a specific frame:

```
dbg> frame 0
Frame #0
  kind: dispatch
  name: main.ping
  summary: ping a
  source: program.m:3
```

## Combining with Breakpoints

You can use stepping alongside breakpoints for efficient navigation:

1. Set a breakpoint near the area of interest.
2. Let the program run to the breakpoint.
3. Use `step`, `next`, or `finish` to navigate through the interesting code.
4. Use `break` to set additional breakpoints further ahead.
5. Use `quit` or `continue` to run to the next breakpoint.

```
dbg> break callable main.ping
Added breakpoint: [1] callable main.ping

dbg> next
Debugger paused: step

dbg> continue
Debugger paused: breakpoint
Breakpoint hit: callable main.ping
```

## Exiting the Debugger

After stepping, you can exit the debugger prompt in several ways:

| Command | Effect |
|---|---|
| `quit` / `q` / `exit` | Exit debugger, continue program execution |
| `continue` / `c` | Same as `quit` — resume execution |

If you are at the last statement and resume, the program completes normally.
If an exception occurs during execution, the debugger will pause again at the
exception point (if `--debugger-cli` is enabled) or print a postmortem report
(if `--debugger-postmortem` is enabled).

## See Also

- [Breakpoints](breakpoints.md) — Setting and managing breakpoints
- [Postmortem Debugging](postmortem.md) — Non-interactive error diagnosis
- [Debugger Commands](commands.md) — Complete command reference
- [Command Line: Debugger Options](../command-line/debugger-options.md) — CLI flags
