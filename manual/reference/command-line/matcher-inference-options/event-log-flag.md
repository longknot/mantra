# Event Log Flag

The `--event-log` flag emits diagnostic events from the structural pattern
matcher and inference engine to standard output. Each event records a specific
operation — a rule match, a rewrite application, a guard evaluation, a
substitution failure, a beam search decision — with a level (`diag` or `trace`)
and a human-readable message.

Use event logs when a transform, selection, or inference reaches an unexpected
result and normal output does not reveal which rule or state caused the change.

## Usage

```bash
# Default mode (diag level, text format)
mantra --event-log program.m

# Explicit modes
mantra --event-log=diag program.m
mantra --event-log=trace program.m
mantra --event-log=json program.m
mantra --event-log=text program.m

# Combined modes (level + format)
mantra --event-log=trace,json program.m
mantra --event-log=diag,text program.m
```

## CLI Argument Parsing

The flag supports two syntaxes:

- **Bare flag** (`--event-log`) — enables logging with defaults (`diag` level, `text` format).
  Parsed at `mantra.lpr` line 367 as a standalone argument matching `arg = '--event-log'`.

- **Spec argument** (`--event-log=<modes>`) — parsed by `ParseEventLogSpec` which
  accepts a comma-separated list of tokens. The spec is case-insensitive (converted to
  lowercase before parsing). Valid tokens are `diag`, `trace`, `json`, `text`.

At least one level token (`diag` or `trace`) and one format token (`json` or `text`)
must be implied: if neither is specified explicitly, both default to `diag` and `text`.
An unrecognizable token causes immediate failure with:

```
Invalid --event-log mode: <spec> (expected diag|trace|json|text and comma combos)
```

## Modes

The `--event-log` flag accepts a comma-separated specification with two
categories: **level** and **format**.

### Levels

| Level | Description | Events Captured |
|---|---|---|
| `diag` | Diagnostic — significant decisions, failures, and warnings | Rule rejections, guard failures, substitution errors, no-op rewrites, inference profile summaries |
| `trace` | Trace — everything in `diag` plus granular operations | All `diag` events, plus successful matches, rewrite applications, match attempts, variable bindings, beam widening |

**Level hierarchy:** `trace` &sub; `diag`. Setting `trace` enables all `diag`-level
event emission points in addition to `trace`-specific ones. At the implementation
level (`TContext.EventEnabled` in `context.pas`):

```
EventEnabled(Diag)  → true when level is ellDiag or ellTrace
EventEnabled(Trace) → true when level is ellTrace
```

### Formats

| Format | Description | Output Line |
|---|---|---|
| `text` | Human-readable prefixed lines | `EVENT[<level>] <message>` |
| `json` | Machine-parseable JSON objects | `{"level":"<level>","event":"<message>"}` |

JSON output escapes special characters in messages (quotes, backslashes,
control characters).

### Mode Combinations

| Spec | Level | Format |
|---|---|---|
| (bare `--event-log`) | `diag` | `text` |
| `diag` | `diag` | `text` |
| `trace` | `trace` | `text` |
| `json` | `diag` | `json` |
| `trace,json` | `trace` | `json` |
| `diag,json` | `diag` | `json` |
| `text` | `diag` | `text` |

An invalid mode string raises an error:

```
Invalid --event-log mode: <spec> (expected diag|trace|json|text and comma combos)
```

## Examples

### Default diagnostic output (text format)

```bash
# tests/cases/event_log_default_diag.args
--event-log
```

```mantra
# tests/cases/event_log_default_diag.in
print { x ? [ x ==>> ] }
```

Output:
```
EVENT[diag] substitution strictness failed: vars(LHS) must equal vars(RHS)
x
```

The event explains why the substitution rule was rejected (LHS variable set
`{x}` does not equal the RHS variable set); `x` is the final program output
(the subject passed through unchanged).

### Trace-level output — successful rewrite

```bash
# tests/cases/event_log_trace_rewrite.args
--event-log=trace
```

```mantra
# tests/cases/event_log_trace_rewrite.in
print { [ 1 ] ? [ [ x ] => x ] }
```

Output:
```
EVENT[trace] rewrite applied
1
```

The event confirms the rule matched and applied; `1` is the extracted element
after rewriting `[ 1 ]` with `[ x ] => x`.

### JSON output — diagnostic level

```bash
# tests/cases/event_log_json_diag.args
--event-log=json
```

```mantra
# tests/cases/event_log_json_diag.in
print { x ? [ x ==>> ] }
```

Output:
```
{"level":"diag","event":"substitution strictness failed: vars(LHS) must equal vars(RHS)"}
x
```

### Combined trace + JSON

```bash
# tests/cases/event_log_json_trace.args
--event-log=trace,json
```

```mantra
# tests/cases/event_log_json_trace.in
print { [ 1 ] ? [ [ x ] => x ] }
```

Output:
```
{"level":"trace","event":"rewrite applied"}
1
```

This produces the most detailed output in machine-readable format. Useful for
deep debugging of inference profiles, beam search behavior, and cost policy
decisions.

## Event Catalog

Events originate from three source files: `matcher_ir.pas` (pattern matcher),
`inference.pas` (proof search), and `nodes.pas` (node dispatch).

### Diag-level events

| Event | Source | When |
|---|---|---|
| `substitution strictness failed: vars(LHS) must equal vars(RHS)` | `matcher_ir.pas` | Substitution rule LHS/RHS variable sets mismatch |
| `rule guard evaluated to false` | `matcher_ir.pas` | Guard condition on a rule failed |
| `substitution rewrite made no changes` | `matcher_ir.pas` | Substitution attempted but produced identical output |
| `invalid substitution mapping: <reason>` | `matcher_ir.pas` | Variable binding produced an invalid substitution result |
| `invalid <setting> value (expected boolean or 0/1)` | `matcher_ir.pas` | Boolean matcher setting has invalid value |
| `invalid <setting> value (expected integer literal)` | `matcher_ir.pas`, `inference.pas` | Integer setting (beam, budget, etc.) cannot be parsed |
| `invalid <setting> value <val> (expected >= 1)` | `matcher_ir.pas`, `inference.pas` | Positive integer setting is too small |
| `invalid <setting> value <val> (expected -1 or >= 0)` | `inference.pas` | Congruence budget is out of range |
| `invalid <setting> value "<val>" (expected "default" or "cost")` | `inference.pas` | Inference policy has unrecognized value |
| `invalid <setting> value (expected string or identifier)` | `inference.pas` | String setting cannot be parsed |
| `witness inference currently uses a single-path rewrite trace` | `nodes.pas` | Witness inference mode uses single-path tracing |
| `inference profile attempt=<n> policy=<p> beam=<b> result=<r> ...` | `inference.pas` | Profile summary after each proof-search attempt (see below) |
| `inference profile rule attempt=<n> policy=<p> beam=<b> name="<name>" direction=<d> ...` | `inference.pas` | Per-rule direction breakdown within profile summary |

### Trace-level events

| Event | Source | When |
|---|---|---|
| `rewrite applied` | `matcher_ir.pas` | Rule successfully rewrote the subject expression |
| `substitution rewrite applied` | `matcher_ir.pas` | Substitution-based rewrite succeeded |
| `rule did not match subject` | `matcher_ir.pas` | Pattern match attempt failed |
| `inference attempt=<n> beam=<b>` | `inference.pas` | Beam widening: new attempt with increased beam width |

## Inference Profile Events

When inference profiling is enabled (`mantra.inference.profile = true`), the
event log emits structured summaries after each proof-search attempt.

### Attempt summary (diag level)

```
inference profile attempt=<N> policy=<policy> beam=<W> result=<result> \
  generated=<G> admitted=<A> pruned_beam=<PB> pruned_visited=<PV> \
  deduped=<D> abandoned_success=<AS> forward=<F> reverse=<R> \
  expanded=<E> max_queue=<MQ> max_frontier=<MF>
```

Fields:

| Field | Description |
|---|---|
| `attempt` | Attempt number (increments on retry) |
| `policy` | Selection policy (`default` or `cost`) |
| `beam` | Beam width for this attempt |
| `result` | `success` or `failure` |
| `generated` | Total candidate states generated |
| `admitted` | Candidates admitted to the beam |
| `pruned_beam` | Candidates pruned by beam capacity |
| `pruned_visited` | Candidates pruned by visited-state deduplication |
| `deduped` | Candidates locally deduplicated |
| `abandoned_success` | Candidates abandoned after proof succeeded |
| `forward` | Candidates from forward rule application |
| `reverse` | Candidates from reverse rule application |
| `expanded` | States fully expanded |
| `max_queue` | Maximum candidate queue size during search |
| `max_frontier` | Maximum retained frontier size |

### Per-rule direction breakdown (diag level)

One line per rule used during the attempt:

```
inference profile rule attempt=<N> policy=<policy> beam=<W> \
  name="<rule_name>" direction=<forward|reverse> \
  generated=<G> admitted=<A> pruned_beam=<PB> pruned_visited=<PV> \
  deduped=<D> abandoned_success=<AS>
```

## Internal Behavior

The `--event-log` flag configures three fields in `TContext` (`src/context.pas`):

- `EventLogLevel` — `ellOff`, `ellDiag`, or `ellTrace` (defaults: `ellOff`)
- `EventLogFormat` — `elfText` or `elfJson` (defaults: `elfText`)
- `EventLogStdout` — whether events are emitted immediately to stdout

Events are buffered in `FEventLines: TStringList`. Each call to `TContext.LogEvent`
first checks `EventEnabled(Level)` to determine if the event should be recorded,
then formats the line according to the active format, adds it to the buffer,
and emits it to stdout if `EventLogStdout` is true.

The event log writes to standard output alongside normal program output. To
separate them, redirect stdout and filter lines starting with `EVENT[` (text
format) or parse JSON objects with a `level` field (JSON format).

## When to Use

| Scenario | Recommended mode |
|---|---|
| Quick debugging of which rules fired | `--event-log` (default diag) |
| Detailed step-by-step matcher trace | `--event-log=trace` |
| Guard failures or rule rejections | `--event-log=diag` |
| Programmatic analysis of matcher behavior | `--event-log=json` or `--event-log=trace,json` |
| Inference profile analysis | `--event-log=diag` with profiling enabled |
| CI/test fixtures with deterministic logging | `--event-log` with explicit mode |

## Related

- [Event Logs](../evaluation/debugging-evaluation-behavior/event-logs.md) — Conceptual guide to event log usage
- [Matcher and Inference Options](../matcher-inference-options.md) — All matcher CLI flags
