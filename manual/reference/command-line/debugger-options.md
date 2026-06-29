# Debugger Options

Debugger flags control event recording, interactive pauses, and postmortem
reports. The debugger is still experimental, so these options are easiest to
validate with fixture-backed tests.

## Quick Reference

| Flag | What it does |
|---|---|
| `--debugger` | Record debugger events without pausing |
| `--debugger-cli` | Pause on breakpoints and open the interactive debugger |
| `--debugger-postmortem` | Print a debugger report when execution raises an exception |
| `--break-callable NAME` | Pause when a callable matching `NAME` is about to dispatch |
| `--break-statement TEXT` | Pause when a statement matching `TEXT` is about to execute |
| `--break-source SPEC` | Pause when execution reaches the specified source location |
| `--break-rule TEXT` | Pause when a matching rule probe succeeds |
| `--break-inference TEXT` | Pause when a matching inference state is entered |

`--break-source` accepts these formats:

```text
LINE
FILE:LINE
FILE:LINE:COL
```

## When to Use Each Mode

- Use `--debugger` when you want event history but do not need to stop the
  program.
- Use `--debugger-cli` when you want to inspect live execution and manage
  breakpoints interactively.
- Use `--debugger-postmortem` when you want a structured report after an
  exception, especially in CI or other non-interactive environments.

## Breakpoint Flags

The `--break-*` flags are usually paired with `--debugger-cli` or
`--debugger-postmortem`. They support wildcard matching on names and text, and
source breakpoints also support `FILE:LINE[:COL]` matching.

For the full breakpoint syntax and examples, see
[Breakpoint Flags](debugger-options/breakpoint-flags.md).

## Detail Pages

- [Debugger Modes](debugger-options/debugger-modes.md)
- [Breakpoint Flags](debugger-options/breakpoint-flags.md)
- [Postmortem Flag](debugger-options/postmortem-flag.md)
