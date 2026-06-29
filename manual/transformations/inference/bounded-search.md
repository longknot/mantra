# Bounded Search

Bounded search controls how far an inference query may explore rewrite space.
It is the step limit attached to a `|=` or `?|=` query with the repeat suffix
`:` and it is complemented by the session-wide beam and congruence settings.

```mantra
subject => target |= rules : n
```

The `: n` suffix sets the maximum number of rewrite steps for that query.
Without an explicit bound, the default is `: 1`.

## Search Knobs

| Knob | Scope | What it controls |
|---|---|---|
| `: n` | Per query | Maximum number of rewrite steps |
| `--beam-width N` | Session-wide | How many candidate paths survive per step |
| `--congruence-budget N` | Session-wide | How many subexpression rewrites are allowed per step |

The `: n` bound is not the same as beam width. A query can have a large step
bound and still fail if the beam is too narrow or the congruence budget is too
small.

## Step Limit Modes

| Bound | Behavior |
|---|---|
| `: 0` | Structural equality check, no rewrites applied |
| `: 1` (default) | Single-step rewrite, at most one rule application |
| `: n` (`n > 1`) | Multi-step search, up to `n` rewrite steps |

### Zero-Step Equality (`: 0`)

With zero steps, the engine does not apply any rules. It only checks whether
subject and target are already structurally identical:

```mantra
print { 1 => 1 |= [ 1 => 2 ] : 0 }    # 1 -- identical
print { 1 => 2 |= [ 1 => 2 ] : 0 }    # 0 -- not identical
```

The ruleset is ignored in this mode.

### Single-Step Rewrite (`: 1`)

With one step, the engine may fire at most one rule:

```mantra
print { 1 => 2 |= [ 1 => 2 ] }         # 1 -- one rule fires
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] } # 0 -- two steps needed
```

One rewrite can reach `2` from `1`, but not `3`. A chain of two rules needs
`: 2`.

### Multi-Step Search (`: n`, `n > 1`)

When the step bound exceeds `1`, inference keeps exploring rewrite paths until
it either reaches the target or runs out of steps:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }    # 1 -- 1 -> 2 -> 3
```

The query succeeds because the path `1 -> 2 -> 3` fits within the bound.

## Variable Rulesets

The ruleset position accepts variables, so you can reuse the same bounded query
across different rulesets:

```mantra
rules = [ 1 => 2, 2 => 3 ];
print { 1 => 3 |= rules : 2 }    # 1
```

Variables in the subject and target positions are resolved before search
begins.

## Runtime Settings

The CLI flags set the initial search settings for the session:

```bash
./bin/mantra --beam-width 2 --congruence-budget 1 program.m
```

| Flag | Meaning |
|---|---|
| `--beam-width N` | Keep up to `N` candidate paths at each step |
| `--congruence-budget N` | Allow up to `N` subexpression rewrites per step (`-1` means unlimited) |

These flags initialize `mantra.inference.beam` and `mantra.inference.budget`.
You can override them in code with evaluation scopes:

```mantra
{ mantra.inference.beam = 2 }
{ mantra.inference.budget = 5 }
```

Use bounded search when a proof search should be predictable and fixture-friendly.
Without a bound, inference defaults to a single step, which keeps tests fast and
deterministic.
