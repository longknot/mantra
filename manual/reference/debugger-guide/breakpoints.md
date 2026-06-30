# Breakpoints

Breakpoints stop program execution when a matching runtime event occurs. Once
paused, the debugger enters its interactive command loop where you can inspect
the call stack, variables, settings, and recent events before resuming.

## Breakpoint Types

Mantra supports five breakpoint kinds, each matching a different class of
runtime event:

| Kind | Triggers when | Example |
|---|---|---|
| `callable` | A callable (function) matching the name is about to dispatch | `main.ping`, `lib/*` |
| `statement` | A statement matching the text is about to execute | `* ping *`, `{ assign * }` |
| `rule` | A rewrite rule matching the name probes successfully | `*transform*`, `main.fail` |
| `inference` | An inference state matching the description is entered | `*step=1*`, `*beam=3*` |
| `source` | Execution reaches a specific source location | `42`, `program.m:42`, `lib.m:10:5` |

All kinds except `source` support wildcard patterns using `*` as the
wildcard character.

## Setting Breakpoints from the Command Line

Use the `--break-*` flags together with `--debugger-cli` to pause automatically
at the start of execution:

```bash
# Break when main.ping dispatches
mantra --debugger-cli --break-callable=main.ping program.m

# Break when any callable matching lib/* dispatches
mantra --debugger-cli --break-callable='lib/*' program.m

# Break on line 42 of the main file
mantra --debugger-cli --break-source=42 program.m

# Break on a specific file and line
mantra --debugger-cli --break-source=program.m:42 program.m

# Break on file, line, and column
mantra --debugger-cli --break-source=lib.m:10:5 program.m

# Break when a rule matching *transform* fires
mantra --debugger-cli --break-rule='*transform*' program.m

# Break when a statement containing "assign" executes
mantra --debugger-cli --break-statement='*assign*' program.m

# Break when an inference state containing "step=1" is entered
mantra --debugger-cli --break-inference='*step=1*' program.m
```

You can specify multiple `--break-*` flags to set several breakpoints at once:

```bash
mantra --debugger-cli \
  --break-callable=main.ping \
  --break-callable=main.fail \
  --break-source=program.m:5 \
  program.m
```

## Setting Breakpoints Interactively

When paused at the debugger prompt, use the `break` command to add new
breakpoints:

```
dbg> break callable main.ping
Added breakpoint: [1] callable main.ping

dbg> break statement '* ping *'
Added breakpoint: [2] statement * ping *

dbg> break source lib.m:10
Added breakpoint: [3] source lib.m:10
```

## Listing and Deleting Breakpoints

View all active breakpoints:

```
dbg> breakpoints
Breakpoints:
  [0] source program.m:2
  [1] callable main.ping
  [2] statement * ping *
```

The `info` command is an alias for `breakpoints`.

Delete a specific breakpoint by its index:

```
dbg> delete 1
Deleted breakpoint 1
```

Remove all breakpoints at once:

```
dbg> clear
Cleared breakpoints
```

## Source Breakpoint Specification

The `--break-source` flag and `break source` command accept three formats:

| Format | Example | Matches |
|---|---|---|
| `LINE` | `42` | Line 42 in the main input file |
| `FILE:LINE` | `program.m:42` | Line 42 in file `program.m` |
| `FILE:LINE:COL` | `lib.m:10:5` | Column 5 on line 10 in file `lib.m` |

File names in source breakpoints support wildcards. Use this to break in
imported or included files:

```bash
mantra --debugger-cli --break-source='*sub.m:3' main.m
```

This breaks on line 3 of any file ending in `sub.m` that gets loaded during
execution.

## Callable Breakpoints

Callable breakpoints match against the fully-qualified name of a callable
(function) at dispatch time. The name includes the namespace prefix:

```
dbg> break callable main.ping
dbg> break callable 'lib/*'       # matches any callable in lib namespace
dbg> break callable 'main.p*'     # matches main.ping, main.pong, etc.
```

The breakpoint fires when the callable is about to dispatch — before the body
executes. The debugger stack will show the `dispatch` frame at position #0.

## Statement Breakpoints

Statement breakpoints match against the textual representation of a statement
just before it executes. Use wildcards for flexible matching:

```
dbg> break statement '* ping *'    # matches any statement containing "ping"
dbg> break statement '{ assign * }'
```

## Rule Breakpoints

Rule breakpoints fire when a rewrite rule probes successfully (matches). The
pattern matches against the rule name:

```
dbg> break rule main.fail
dbg> break rule '*transform*'
dbg> break rule 'lib/*'
```

Note: the breakpoint fires on a successful probe, not on the initial attempt
to match. If a rule does not match the input, the breakpoint does not trigger.

## Inference Breakpoints

Inference breakpoints match against the textual description of an inference
state when it is entered. This is useful for debugging proof search and beam
search:

```
dbg> break inference '*step=1*'
dbg> break inference '*beam=3*'
```

## Breakpoint Behavior

When a breakpoint is hit:

1. Execution pauses immediately.
2. The debugger prints the pause reason and breakpoint message:
   ```
   Debugger paused: breakpoint
   Breakpoint hit: callable main.ping
   ```
3. If `--debugger-cli` is enabled, the interactive command loop opens.
4. The current call stack, variables, and context are available for inspection.

A single breakpoint can be hit multiple times during execution. Each hit
pauses execution independently. Use `delete` or `clear` to remove breakpoints
you no longer need.

## Breakpoints with Postmortem

You can combine breakpoints with `--debugger-postmortem` for non-interactive
diagnostics:

```bash
mantra --debugger-postmortem --break-source=program.m:5 program.m
```

If execution hits the breakpoint and continues to an exception, the postmortem
report includes the breakpoint in its event log.

## See Also

- [Stepping](stepping.md) — Controlling execution one step at a time
- [Postmortem Debugging](postmortem.md) — Non-interactive error diagnosis
- [Debugger Commands](commands.md) — Complete command reference
- [Command Line: Breakpoint Flags](../command-line/debugger-options/breakpoint-flags.md) — CLI flag reference
