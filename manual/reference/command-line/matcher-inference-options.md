# Matcher and Inference Options

Matcher and inference options control how Mantra matches structural patterns,
applies rewrite rules, and searches for proofs. These flags affect the whole
session and are applied at startup.

## Quick Reference

| Flag | What it controls |
|---|---|
| `--backtracking` | Enable backtracking for infix `--` / `---` matching |
| `--no-guards` | Disable rule guards during matching and rewriting |
| `--head-dispatch` | Enable implicit callable dispatch in `{ head ... }` scopes |
| `--no-head-dispatch` | Disable implicit callable dispatch |
| `--event-log[=MODE]` | Emit matcher and inference events to stdout |
| `--beam-width N` | Keep up to `N` candidate proof paths per step |
| `--congruence-budget N` | Allow up to `N` subexpression rewrites per proof step |

## What Each Flag Changes

- `--backtracking` changes how `--` patterns search for a match when multiple
  splits are possible.
- `--no-guards` turns off guard enforcement, so structurally matching rules
  can fire without their guard succeeding.
- `--head-dispatch` and `--no-head-dispatch` control whether `{ head ... }`
  scopes are treated as implicit callable invocations.
- `--event-log` enables diagnostic or trace logging for matcher and inference
  events.
- `--beam-width` and `--congruence-budget` bound `|=` proof search.

## Runtime Settings

Some of the inference settings also have runtime variables:

| Runtime variable | CLI flag | Default |
|---|---|---|
| `mantra.inference.beam` | `--beam-width` | `1` |
| `mantra.inference.budget` | `--congruence-budget` | `-1` (unlimited) |

You can change those variables inside a program with evaluation scopes:

```mantra
{ mantra.inference.beam = 2 }
{ mantra.inference.budget = 5 }
```

## Detail Pages

- [Matcher Controls](matcher-inference-options/matcher-controls.md)
- [Dispatch Flags](matcher-inference-options/dispatch-flags.md)
- [Inference Budget Flags](matcher-inference-options/inference-budget-flags.md)
- [Event Log Flag](matcher-inference-options/event-log-flag.md)
