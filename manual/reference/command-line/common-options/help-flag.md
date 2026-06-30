# Help Flag

The `--help` flag prints the complete CLI usage information and terminates
immediately — no source code is parsed or executed.

## Usage

```bash
mantra --help
```

## When Help Appears Automatically

Help is also the **default behavior** when Mantra runs with no input file,
no redirected stdin, and no `--interactive` flag:

```bash
mantra
```

If no file is provided and stdin is not redirected, the `Bootstrap` procedure
calls `ShowHelp` then exits. This means running the bare binary always shows
the usage screen.

## Output Structure

The help output produced by `ShowHelp` has three sections:

1. **ASCII art banner** — gradient-colored "MANTRA" logo using ANSI color
   codes (colors 42 through 186, progressing green-to-red).
2. **Usage line** — `Usage: mantra [options] [file]`
3. **Options list** — all recognized flags with short descriptions, listed
   in the same order they appear in the source.

### Banner

```text
    ___  ___     ___     ___  ___________________     ___
 .:|   \/   |:::/   \:::|   \|   ___    ___      \:::/   \::::.
:::|        |::/  .  \::|       |:::|  |:::|  .  /::/  .  \:::::
:::|  |\/|  |:/   _   \:|  |\   |:::|  |:::|     \:/   _   \::::
:::|__|::|_______/:\/_______|:\__|:::|__|:::|__|\/______/:\\___\:::
```

The banner is rendered with ANSI escape codes (`\x1B[38;5;Nm`) for the
gradient and `\x1B[0m` to reset before the usage text. If the terminal
does not support ANSI colors, the raw escape sequences will appear in
the output.

### Options List

The `ShowHelp` procedure in `mantra.lpr` lists these options verbatim:

| Flag | Description |
|---|---|
| `--raw` | Print unformatted TreeValue output |
| `--interactive`, `-i` | Start REPL mode |
| `--debug`, `-d` | Print every statement output |
| `--debug-ir` | Print parser-friendly IR |
| `--debugger` | Attach debugger event recorder |
| `--debugger-cli` | Enter debugger command loop on exceptions |
| `--break-callable NAME` | Break on callable dispatch |
| `--break-statement TEXT` | Break on statement match |
| `--break-source SPEC` | Break on source location |
| `--break-rule TEXT` | Break on rule probe match |
| `--break-inference TEXT` | Break on inference state |
| `--debugger-postmortem` | Print debugger stack on exceptions |
| `--eval`, `-e` | Evaluate output before printing |
| `--eval=EXPR` | Append and run expression |
| `--head-dispatch` | Enable implicit rule dispatch (default) |
| `--no-head-dispatch` | Disable implicit rule dispatch |
| `--backtracking` | Enable matcher backtracking |
| `--show-input` | Show input lines prefixed with ">" |
| `--show-tokens` | Show tokenizer output |
| `--event-log[=...]` | Emit matcher events to stdout |
| `--congruence-budget N` | Max sub-expression rewrites for `\|=` |
| `--beam-width N` | Beam width for `\|=` proof search |
| `--no-guards` | Disable matcher rule guards |
| `--set NAME=EXPR` | Predefine a variable (repeatable) |
| `--package-root PATH` | Add an external package search root (repeatable) |
| `--help` | Show this help |

For full descriptions of each flag, see the individual pages in the
[common-options](./) reference.

## Behavior

- `--help` **always** prints the help text and exits, regardless of other
  flags. It is checked during argument parsing before any other option takes
  effect.
- The `ShowHelp` procedure is a simple `WriteLn` sequence — it does not read
  any configuration files, environment variables, or external resources.
- After printing, the program calls `Exit` immediately. No `RegisterObjects`,
  no parser initialization, no file I/O occurs.
- Exit code is **0** (success).

## Short Form

There is no short form (`-h`) for `--help`. The `-h` prefix is reserved
for option parsing — any unrecognized `-` prefixed argument raises an
`Unknown option` exception.

## Piping and Redirecting

Since the output is plain text after the ANSI banner, you can pipe or
redirect it for offline reference:

```bash
mantra --help > help.txt
mantra --help | grep --color=never "debug"
```

To strip ANSI color codes from the banner, pipe through `ansi2txt` or
similar tools:

```bash
mantra --help | sed 's/\x1b\[[0-9;]*m//g'
```

## Source

The help implementation lives in `mantra.lpr` as the `ShowHelp` procedure
(lines 10-61). The trigger is checked during CLI argument parsing
(line 445). Help is also the fallback when no input is provided
(line 475).
