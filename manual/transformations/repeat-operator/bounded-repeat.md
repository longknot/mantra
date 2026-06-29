# Bounded Repeat

A bounded repeat uses a numeric value as the repeat driver. The runtime clones
the left-hand source a specific number of times, applying `Transform` and
`Complete` operations to each copy.

```mantra
subject ? rules : n
```

In selection and inference workflows, this is commonly used to limit how many
rewrite or search steps are attempted.

## Syntax

```
LHS : n
```

- **LHS** — the source/template to be expanded
- **n** — an integer (positive, zero, or negative) that drives expansion

The integer can appear directly as a literal, be stored in a variable, or be
passed via the CLI with `--set`.

## How It Works

The evaluation flow is orchestrated by `TRepeatNode.Evaluate` in `nodes.pas`:

1. **Evaluate LHS** — The left side is evaluated unless it contains selection
   nodes (`?` / `:=?`), which are preserved as structural patterns.
2. **Resolve repeat driver** — `ResolveRepeatDriver` scans the RHS for the
   effective driver node (integer, variable, or iterator binding). Unresolved
   variables cause the repeat to exit without expanding.
3. **Set source pointer** — `Context.Data` is set to point to the LHS source
   node, so the expansion callback knows what to clone.
4. **Expand** — `TIntegerNode.Expand` handles the numeric driver:
   - If `n <= 0`, the target is deleted.
   - If `n > 0` in normal mode, the source is cloned `n` times with
     `Transform` and `Complete` applied to each copy.
   - If `n > 0` with `$` state-selection mode, delegates to
     `ExpandStateSelection` for stepwise rewrites (up to `n` steps).
5. **Evaluate expanded result** — `Node[RHS].Evaluate(Context)` runs once over
   the expanded tree, enabling compute reduction on the repeated copies.
6. **Clean up** — The original LHS and the repeat node are deleted; only the
   expanded RHS remains.

## Example: Basic Repetition

The simplest bounded repeat clones a template multiple times:

```mantra
print { [ 7 ] : 3 }
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

Each copy is an independent clone of the source `[ 7 ]`.

## Example: Selection with Bounded Repeat

The most common pattern — applying a selection rewrite a fixed number of times:

```mantra
rule swap [
  [ x y ] <=> [ y x ]
]

print { [ 3 4 ] ? swap : 1 }
```

Expected `OUTPUT`:

```text
[ 4 3 ]
```

The selection `[ 3 4 ] ? swap` matches once, swapping the pair. The `: 1`
driver ensures only one rewrite step is attempted.

## Example: Variable-Driven Repeat

The repeat count can be stored in a variable and passed via CLI:

```mantra
print { [ 7 ] : n }
```

Run with `--set n=3`:

```bash
./bin/mantra --set n=3 -e 'print { [ 7 ] : n }'
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

The runtime resolves `n` from context before expansion. Unresolved variables
cause the repeat to exit without expanding.

## Example: Zero and Negative Values

When the integer value is `<= 0`, the repeat deletes the target entirely:

```mantra
print { [ 7 ] : 0 }
```

With a negative value, the same deletion occurs:

```mantra
print { [ 7 ] : -1 }
```

Both produce no output. This behavior is defined in `TIntegerNode.Expand`:
`if Value <= 0 then Delete`. It provides a conditional expansion pattern where
a count of zero or negative suppresses the output.

## Example: Multiple Rewrites

A bounded repeat can drive multiple sequential selection steps. Each step
processes one selection match before the counter decrements:

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ < 1 < 2 ] )
```

With two steps:

```mantra
{ ( [ 9 ] ? [ [ 1 ] => [ done ] , [ x -- ] => [ ~< 1 2 ] ] ) : 2 }
```

Expected `OUTPUT`:

```text
( [ done ] )
```

The first step replaces `[ 9 ]` with the tilde-marked `[ ~< 1 2 ]`. The second
step evaluates the tilde compute and matches `[ 1 ]` to produce `[ done ]`.

## State Selection with Bounded Repeat

When the source contains a `$` state-selection marker, the bounded repeat
delegates to `ExpandStateSelection` for up to `n` rewrite steps. This is the
primary mechanism for iterative tree transformations:

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 5 }
```

Each iteration applies one selection rewrite. The process stops when either `n`
steps are exhausted or no more rules match.

## Iterator Binding

Bounded repeat supports iterator bindings via `@` which expose the current
iteration index to the LHS template:

```mantra
print { i : 5 @ i }
```

Expected `OUTPUT`:

```text
1 2 3 4 5
```

The iterator `i` takes values 1 through `n` during expansion. This is useful
for generating sequences where each position depends on its index.

## Bounded Inference

When the LHS contains an inference node (`|=`), the repeat operator switches
to bounded inference mode. The integer on the RHS limits the maximum proof
search depth instead of controlling cloning:

```mantra
<query> |= <rules> : <n>
```

Here `<n>` sets `InferenceRewriteMaxSteps` temporarily while the inference
query runs, then restores the previous value. This is the same mechanism used
in `TRepeatNode.Evaluate` — it detects `OBJ_INFERENCE` in the LHS and routes
to specialized inference handling rather than the cloning path.

## Key Behaviors

| Behavior | Detail |
|---|---|
| Driver `n <= 0` | Target is deleted; no output produced |
| Driver `n > 0` (normal) | Source cloned `n` times with Transform/Complete |
| Driver `n > 0` (state `$`) | Up to `n` iterative rewrites via ExpandStateSelection |
| Unresolved variable | Repeat exits without expanding |
| LHS with `?` / `:=?` | Not pre-evaluated; selection templates preserved |
| LHS with `\|=` | Switches to bounded inference; `n` = max search depth |
| After expansion | Final `Evaluate` pass enables compute on repeated copies |

## Bounded Repeat vs. Fixpoint Repeat

| Feature | Bounded (`: n`) | Fixpoint (`: ...`) |
|---|---|---|
| Driver | Integer literal or variable | `...` recurse token |
| Steps | Exactly `n` (or fewer if stalled) | Up to `MAX_FIXPOINT_STEPS` (1024) |
| Control | Explicit count from user | Implicit fixpoint convergence |
| Use case | Known iteration count | Unknown iteration count |

## Related Pages

- [Fixpoint Repeat](fixpoint-repeat.md)
- [Repeat with Compute Scopes](../repeat-with-compute-scopes.md)
- [State Selection](../state-selection.md)
- [Compute Scopes](../syntax/compute-scopes.md)
- [Selection Operator](../selection-operator.md)
