# Event Logs

Event logs expose the internal activity of the structural pattern matcher and the
inference engine. Each log line records a specific event — a rule match, a
rewrite application, a guard evaluation, a substitution failure, etc. — with a
level (`diag` or `trace`) and a human-readable message.

Use event logs when a transform, selection, or inference reaches an unexpected
result and normal output does not reveal which rule or state caused the change.

## Syntax

```bash
mantra --event-log program.m          # default: diag + text mode
mantra --event-log=diag program.m     # diag level, text output
mantra --event-log=trace program.m    # trace level (more detail), text output
mantra --event-log=json program.m     # diag level, JSON output
mantra --event-log=trace,json program.m  # trace level, JSON output
mantra --event-log=text program.m     # explicit text output
```

## Event Levels

| Level | Description | Events Included |
|---|---|---|
| `diag` | Diagnostic — significant decisions and failures | Rule rejections, guard failures, substitution errors, no-op rewrites |
| `trace` | Trace — diagnostic + granular operations | Everything in `diag`, plus successful matches, rewrite applications, match attempts, variable bindings |

The level hierarchy is: `trace` ⊃ `diag`. Setting `trace` enables all `diag`
events plus additional fine-grained ones.

When the flag is provided without an explicit level (`--event-log`), the default
level is `diag`.

## Output Formats

| Format | Description | Example |
|---|---|---|
| `text` | Human-readable prefixed lines | `EVENT[diag] rule guard evaluated to false` |
| `json` | Machine-parseable JSON objects | `{"level":"diag","event":"rule guard evaluated to false"}` |

When the flag is provided without an explicit format, the default is `text`.

Multiple flags can be combined with commas: `--event-log=trace,json` emits trace
events in JSON format.

## Default Behavior

```bash
mantra --event-log program.m
```

Equivalent to `--event-log=diag,text`. Events are written to the internal event
buffer and emitted to standard output.

## What Gets Logged

Event sources live in the matcher (`matcher_ir.pas`), the inference engine
(`inference.pas`), and node dispatch (`nodes.pas`). Common events include:

### Diag-level events

| Event | When |
|---|---|
| `substitution strictness failed: vars(LHS) must equal vars(RHS)` | A rule's LHS and RHS variable sets do not match |
| `rule guard evaluated to false` | A rule guard condition failed |
| `substitution rewrite made no changes` | A substitution was attempted but produced identical output |
| `invalid substitution mapping` | A variable binding produced an invalid result |
| `witness inference currently uses a single-path rewrite trace` | Inference witness mode is single-path |

### Trace-level events

| Event | When |
|---|---|
| `rewrite applied` | A rule successfully rewrote the subject |
| `substitution rewrite applied` | A substitution-based rewrite succeeded |
| `rule did not match subject` | A rule was attempted but the pattern did not match |
| Variable binding events | Individual variable bindings during matching |
| Match attempt events | Entry/exit of matching operations |

## Examples

### Diag mode — rule rejection

When a rule's LHS/RHS variable sets mismatch, `diag` level catches it:

```bash
echo 'print { x ? [ x ==>> ] }' | mantra --event-log=diag
```

Output:

```
EVENT[diag] substitution strictness failed: vars(LHS) must equal vars(RHS)
x
```

The event explains why the rule was rejected; `x` is the final program output
(the subject passed through unchanged).

### Trace mode — successful rewrite

When a rule matches and rewrites, `trace` level confirms the operation:

```bash
echo 'print { [ 1 ] ? [ [ x ] => x ] }' | mantra --event-log=trace
```

Output:

```
EVENT[trace] rewrite applied
1
```

The event confirms the rule matched and applied; `1` is the extracted element
after rewriting `[ 1 ]` with `[ x ] => x`.

### JSON output

For machine consumption, combine any level with `json`:

```bash
echo 'print { [ 1 ] ? [ [ x ] => x ] }' | mantra --event-log=trace,json
```

Output:

```
{"level":"trace","event":"rewrite applied"}
1
```

```bash
echo 'print { x ? [ x ==>> ] }' | mantra --event-log=json
```

Output:

```
{"level":"diag","event":"substitution strictness failed: vars(LHS) must equal vars(RHS)"}
x
```

### Combined levels and formats

```bash
mantra --event-log=trace,json program.m   # trace events as JSON
mantra --event-log=diag,text program.m    # diag events as text (explicit)
mantra --event-log program.m              # diag + text (default)
```

## When to Use Event Logs

Event logs are the primary debugging tool for rewrite and inference behavior:

1. **Selection produces wrong result.** Use `--event-log=diag` to see which
   rules were rejected and why. Use `--event-log=trace` to see the full
   matching path including successful bindings.

2. **Inference fails unexpectedly.** Use `--event-log=trace` to trace the
   proof search path, rule directions, and beam decisions.

3. **Guard behavior unclear.** Use `--event-log=diag` — guard failures always
   appear at `diag` level.

4. **Scripted analysis or CI.** Use `--event-log=json` to parse events
   programmatically with `jq` or similar tools.

## Implementation Details

### Internals

The event log system lives in `TContext` (`src/context.pas`). Three fields
control behavior:

- `EventLogLevel` — `ellOff`, `ellDiag`, or `ellTrace`
- `EventLogFormat` — `elfText` or `elfJson`
- `EventLogStdout` — whether events are emitted immediately to stdout

Events are stored in an internal buffer (`FEventLines: TStringList`). Each call
to `LogEvent` first checks `EventEnabled(Level)`, then formats the line, adds
it to the buffer, and optionally emits it to stdout.

### Level filtering

```
EventEnabled(Diag)  → true when level is Diag or Trace
EventEnabled(Trace) → true when level is Trace
```

This means `trace` captures everything `diag` captures, plus additional
fine-grained events.

### Event emission points

| Source file | What it logs |
|---|---|
| `matcher_ir.pas` | Rule matches, guards, substitutions, rewrite applications |
| `inference.pas` | Proof search steps, beam decisions, rule directions |
| `nodes.pas` | Witness inference mode notices |

### Output format

Text mode prefixes: `EVENT[<level>] <message>`

JSON mode: `{"level":"<level>","event":"<message>"}`

Both formats apply proper escaping for the message content (JSON escapes
quotes, backslashes, control characters).

## Related

- [Event Log Flag](../reference/command-line/matcher-inference-options/event-log-flag.md) — CLI flag reference
- [Matcher and Inference Options](../reference/command-line/matcher-inference-options.md) — all matcher flags
- [Debugging Evaluation Behavior](../debugging-evaluation-behavior.md) — general debugging checklist
