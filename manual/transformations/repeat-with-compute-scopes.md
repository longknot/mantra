# Repeat with Compute Scopes

When a repeat expression sits inside a compute scope (backticks), the runtime
first reduces any computable operations within each repeated copy. This
combination lets you both clone a structured template and fold arithmetic in
a single step.

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The addition `+ 1 2 3` reduces to `+ 6` inside every repeated copy.

## How It Works

The interaction between repeat and compute follows a deterministic sequence
defined by `TRepeatNode.Evaluate` and `TComputeNode.Evaluate` in the runtime:

1. **Enter compute scope** -- The backtick scope is recognized. Its descendants
   are evaluated, resolving variables and processing nested scopes.
2. **Evaluate LHS of repeat** -- The left side of `:` is evaluated unless it
   contains selection nodes (`?` / `:=?`), which are preserved as structural
   patterns.
3. **Resolve repeat driver** -- The right side is scanned for the repeat count
   (integer, variable, or recurse `...`).
4. **Expand** -- `TIntegerNode.Expand` (or the recurse equivalent) clones the
   source template the requested number of times. Each clone undergoes
   `Transform` and `Complete` operations.
5. **Evaluate expanded result** -- After expansion, `Node[RHS].Evaluate(Context)`
   runs once over the expanded tree. This is where compute reduces operators
   inside each copy.
6. **Collapse** -- The original repeat node and LHS are deleted. The backtick
   wrapper is then removed by `GlobalTree.Expand`, leaving only the computed
   results.

The key insight: compute reduction happens **after** repetition, not before.
Each cloned copy carries the template expression, and the final evaluation pass
reduces all copies simultaneously.

## Example: Integer Addition with Repeat

The canonical pattern -- repeat a computed addition three times:

```mantra
`[ + 1 2 3 ] : 3`
```

Expected `OUTPUT`:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The compute scope wraps the repeat. Inside the template `[ + 1 2 3 ]`, the
operator `+` and operands `1 2 3` form a reducible expression. After repeating
three times, the evaluate pass reduces each copy independently.

## Example: Multiple Compute Nodes in One Scope

A single compute scope can contain multiple independent reductions:

```mantra
[ ` + 1 2 ` ` + 3 4 ` ]
```

Expected `OUTPUT`:

```text
[ + 3 + 7 ]
```

Each backtick pair (here implicit within the brackets) is reduced separately.

## Nested Repeats with Compute

Compute scopes can contain nested repeats where the inner repeat also produces
computable results:

```mantra
{ [ `+ 1 + 2 + 3` : 2 ] : 3 }
```

Expected `OUTPUT`:

```text
[ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ]
```

Here, the inner repeat `` `+ 1 + 2 + 3` : 2 `` produces two copies of the
computed result `+ 6`. The outer repeat `: 3` then clones that array three
times. The evaluation scope `{ ... }` wraps everything.

## Tilde (`~`) Compute Targeting with Repeat

The `~` meta-operator can target compute at specific nodes inside a repeat
without requiring a full backtick scope. This is called "compute on next
iteration" and lets you apply compute selectively:

### Tilde on a single node

```mantra
[ { [ ~ + 1 2 3 : 2 ] : 3 } ]
```

Expected `OUTPUT`:

```text
[ [ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ] ]
```

The tilde marks `+` for compute in each iteration. The inner repeat `: 2`
produces two copies, and the outer `: 3` produces three copies of that result.

### Tilde on a list

```mantra
[ { ~ [ + 1 2 3 : 2 ] : 3 } ]
```

Expected `OUTPUT`:

```text
[ [ + 12 ] [ + 12 ] [ + 12 ] ]
```

When the tilde targets the entire list, the compute folds more aggressively
across the repeated structure, producing a single accumulated value per copy.

## Variables Inside Compute with Repeat

Variables are resolved before computation. When a variable bound to an
expression appears inside a compute scope with repeat, it first expands to its
stored tree snapshot, then computes:

```mantra
x = [ + 1 2 3 ]
`x`
```

Expected `OUTPUT`:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The assignment prints the symbolic form. The compute scope `` `x` `` expands
`x` and reduces the addition.

You can also use `--set` on the CLI to pre-define variables that drive compute
expressions:

```bash
./bin/mantra --set x='[ + 1 2 3 ]' -e 'print `x`'
```

## Key Differences: Compute Scope vs. Tilde

| Feature | Backtick (`` ` ``) | Tilde (`~`) |
|---|---|---|
| Scope | Full expression block | Single targeted node |
| Reduction | All supported ops in scope | Only the marked node/subtree |
| Wrapper removed | Yes, after compute | No wrapper to remove |
| Use case | Compute everything inside | Selective compute on specific nodes |

## Shell Quoting

Backticks are interpreted by most shells. Always wrap Mantra programs in single
quotes when passing them through a shell:

```bash
echo '`[ + 1 2 3 ] : 3`' | ./bin/mantra
```

Using double quotes will cause the shell to interpret the backticks as command
substitution before Mantra sees the input.

## Related Pages

- [Compute Scopes](../syntax/compute-scopes.md)
- [Compute Scope](../compute/compute-scope.md)
- [Repeat Operator](repeat-operator.md)
- [Nested Repeats](nested-repeats.md)
- [Meta-Compute Operator](../compute/meta-compute-operator.md)
- [Integer Arithmetic](../compute/integer-arithmetic.md)
