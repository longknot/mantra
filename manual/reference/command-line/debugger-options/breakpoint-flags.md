# Breakpoint Flags

Breakpoint flags let you pause execution when specific runtime events occur.
They are designed to be used together with `--debugger-cli` for interactive
debugging or `--debugger-postmortem` for non-interactive diagnostics.

## Flags

| Flag | Argument | Pauses when |
|---|---|---|
| `--break-callable NAME` | Callable name (wildcards ok) | A callable matching `NAME` is about to dispatch |
| `--break-statement TEXT` | Statement text (wildcards ok) | A statement matching `TEXT` is about to execute |
| `--break-source SPEC` | Source location spec | Execution reaches the source location |
| `--break-rule TEXT` | Rule name (wildcards ok) | A rewrite rule matching `TEXT` probes successfully |
| `--break-inference TEXT` | Inference description (wildcards ok) | An inference state matching `TEXT` is entered |

## `--break-callable`

Breaks when a callable (function) matching the given name is about to dispatch.
The name is the fully-qualified callable name including the namespace prefix.

```bash
# Break when main.ping dispatches
mantra --debugger-cli --break-callable=main.ping program.m

# Break on any callable in the lib namespace
mantra --debugger-cli --break-callable='lib/*' program.m

# Break on callables starting with main.p
mantra --debugger-cli --break-callable='main.p*' program.m
```

The breakpoint fires before the callable body executes. The debugger stack will
show a `dispatch` frame at position #0.

## `--break-statement`

Breaks when a statement matching the text pattern is about to execute. The
pattern matches against the textual representation of the statement.

```bash
# Break on any statement containing "ping"
mantra --debugger-cli --break-statement='* ping *' program.m

# Break on statements with assign
mantra --debugger-cli --break-statement='*assign*' program.m
```

## `--break-source`

Breaks when execution reaches a specific source location. The spec accepts
three formats:

```bash
# Break on line 42 of the main input file
mantra --debugger-cli --break-source=42 program.m

# Break on line 42 of program.m
mantra --debugger-cli --break-source=program.m:42 program.m

# Break on line 10, column 5 of lib.m
mantra --debugger-cli --break-source=lib.m:10:5 program.m
```

File names support wildcards for imported or included files:

```bash
# Break on line 3 of any file ending in sub.m
mantra --debugger-cli --break-source='*sub.m:3' main.m
```

## `--break-rule`

Breaks when a rewrite rule matching the name probes successfully. The pattern
matches against the rule name.

```bash
# Break when any rule matching *transform* fires
mantra --debugger-cli --break-rule='*transform*' program.m

# Break when main.fail rule probes
mantra --debugger-cli --break-rule=main.fail program.m
```

The breakpoint fires only on a successful probe — if the rule does not match,
the breakpoint does not trigger.

## `--break-inference`

Breaks when an inference state matching the description is entered. Useful for
debugging proof search and beam search behavior.

```bash
# Break when an inference state containing "step=1" is entered
mantra --debugger-cli --break-inference='*step=1*' program.m

# Break on inference states with beam=3
mantra --debugger-cli --break-inference='*beam=3*' program.m
```

## Multiple Breakpoints

You can combine multiple `--break-*` flags to set several breakpoints:

```bash
mantra --debugger-cli \
  --break-callable=main.ping \
  --break-callable=main.fail \
  --break-source=program.m:5 \
  program.m
```

Each flag adds a new breakpoint. They are all active during the same run.

## Wildcards

All breakpoint kinds except `source` use `*` as the wildcard character. The
wildcard matches any substring:

- `main.*` matches `main.ping`, `main.pong`, etc.
- `*fail*` matches `main.fail`, `lib.failure_handler`, etc.
- `*step=1*` matches inference states containing `step=1` anywhere in their description.

For source breakpoints, wildcards work in the file name portion only:

- `*sub.m:3` matches `lib_sub.m:3`, `test_sub.m:3`, etc.
- `*/lib/*.m:10` matches any `.m` file under a `lib` directory on line 10

## See Also

- [Debugger Modes](debugger-modes.md) — `--debugger`, `--debugger-cli`, `--debugger-postmortem`
- [Postmortem Flag](postmortem-flag.md) — `--debugger-postmortem` flag reference
- [Breakpoints](../debugger-guide/breakpoints.md) — Full breakpoint guide
- [Debugger Commands](../debugger-guide/commands.md) — Interactive breakpoint management
