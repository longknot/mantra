# Expansion Behavior

Expansion is the process by which a repeat expression (`LHS : RHS`) replaces the
repeat node with zero or more copies of its source. The right-hand side drives
how expansion happens — the integer count, a recurse token, a variable, or a
sequence — while the left-hand side provides the template that gets cloned.

```mantra
[ + 1 2 3 ] : 3
```

Expected `OUTPUT`:

```text
[ + 1 2 3 ] [ + 1 2 3 ] [ + 1 2 3 ]
```

The LHS `[ + 1 2 3 ]` is the source template. The RHS `3` says: clone it
three times. The three copies become siblings in place of the original repeat
expression.

## How Expansion Works

The runtime follows a deterministic sequence defined by `TRepeatNode.Evaluate`
in `nodes.pas`:

1. **Evaluate LHS (with guard)** — The left side is evaluated unless it contains
   selection nodes (`?` / `:=?`), which must stay as structural patterns and not
   be executed.
2. **Resolve the repeat driver** — The right side is scanned for the effective
   driver: an integer count, a recurse token (`...`), a resolvable variable,
   or a wrapped form like `[ n ]`. Unresolvable bare variables abort expansion.
3. **Expand** — `Node[RHS].Expand(Context)` performs the actual cloning. The
   driver node type determines which `Expand` method runs.
4. **Evaluate expanded result** — After expansion, one final evaluation pass
   runs over the expanded tree, triggering compute reductions, nested scope
   collapses, and other evaluation-time effects.
5. **Cleanup** — The original LHS and the repeat node itself are deleted. Only
   the expanded copies remain in the tree.

The key insight: the original repeat expression is **consumed**. It disappears
from the AST and is replaced by its expanded results.

## Expansion Drivers

The RHS of `:` determines which expansion strategy applies. The runtime tries
to resolve the driver through `ResolveRepeatDriver`, which handles variable
substitution and unwraps nested forms.

### Integer Count

The most common form. The RHS is an integer (or evaluates to one).

```mantra
print { 1 :: 3 }
```

Expected `OUTPUT`:

```text
1 1 1
```

The template `1` is cloned three times as siblings.

**Zero or negative count** deletes the source entirely — no copies remain.

**Variable-driven count** resolves a variable to an integer at runtime:

```mantra
print { [ 7 ] : n }
```

With `--set n=3`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

### Recurse Token (`...`)

The `...` driver triggers fixpoint-style expansion. When the source contains
no selection nodes, it simply applies `FixRecursion` (ensuring recursion markers)
and produces a single clone:

```mantra
{ [ 1 2 ] : ... }
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

When combined with state-selection (`$?`), it performs iterative rewriting up
to `MAX_FIXPOINT_STEPS` (1024):

```mantra
{ ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : ... }
```

Expected `OUTPUT`:

```text
( [] )
```

Each iteration applies the selection rule until no more matches remain.

### Staged Repeat (Double-Colon `::`)

The double-colon `::` syntax introduces staged repeat, implemented by
`TStagedRepeatNode.Evaluate`. Unlike single-colon `:` which directly clones
the LHS, staged repeat processes each driver value **one at a time**, clones
the LHS, binds the iterator, evaluates that clone, and collects the results.
Each stage is fully evaluated before the next one begins.

```mantra
LHS :: driver @ iterator
```

The `@ iterator` binding is optional. When present, each driver value is
bound to the iterator variable inside the cloned LHS before evaluation.

#### Integer Count with Iterator

When the driver is an integer and an iterator is provided, values `1` through
`n` are generated and bound to the iterator variable:

```mantra
n = 1;
print { scope { [ n ] :: 3 @ n } };
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ] [ 3 ]
```

The outer variable `n = 1` is shadowed inside each clone by the iterator
binding, which takes values `1`, `2`, `3` sequentially.

Without an iterator binding, the LHS is simply cloned `n` times without any
value substitution:

```mantra
print { 1 :: 3 }
```

Expected `OUTPUT`:

```text
1 1 1
```

#### Sequence Drivers

When the driver is an array or expression, each element becomes a separate
stage. The iterator variable is bound to each element value:

```mantra
print { [ x ] :: [ 10 20 30 ] @ x }
```

Expected `OUTPUT`:

```text
[ 10 ] [ 20 ] [ 30 ]
```

With comma-separated sequences:

```mantra
print { [ x ] :: [ a, b, c ] @ x }
```

Expected `OUTPUT`:

```text
[ a ] [ b ] [ c ]
```

The driver can also be a parenthesized expression:

```mantra
values = ( a b c );
print { [ x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ a ] [ b ] [ c ]
```

Structured items (arrays, expressions) are bound as whole nodes:

```mantra
print { [ x ] :: [ [ 1 2 ] ( 3 4 ) ] @ x }
```

Expected `OUTPUT`:

```text
[ [ 1 2 ] ] [ ( 3 4 ) ]
```

An empty sequence produces no output:

```mantra
print { [ x ] :: [ ] @ x }
```

Expected `OUTPUT`:

```text
```

Without binding, each stage still clones and evaluates the LHS:

```mantra
print { [ item ] :: [ a b c ] }
```

Expected `OUTPUT`:

```text
[ item ] [ item ] [ item ]
```

#### Range Drivers

The `..` range operator drives staged repeat, generating values from start
to end (inclusive):

```mantra
print { i :: 1 .. 3 @ i }
```

Expected `OUTPUT`:

```text
1 2 3
```

Float ranges with `by` step:

```mantra
print { [ ~ * x * x ] :: -1.0 .. 1.0 by 0.2 @ x }
```

Expected `OUTPUT`:

```text
[ * 1 ] [ * 0.64 ] [ * 0.36 ] [ * 0.16 ] [ * 0.04 ] [ * 0 ] [ * 0.04 ] [ * 0.16 ] [ * 0.36 ] [ * 0.64 ] [ * 1 ]
```

The range supports both integer and float domains. Character ranges are also
supported (e.g., `a .. z`).

#### Per-Item Evaluation

Each staged repeat clone is evaluated independently within its own context.
Side effects (like `printf`) occur once per stage:

```mantra
mantra.effects.display.evaluate = 1;
{ [ scope { printf "x" } ] :: 3 }
```

Expected `OUTPUT`:

```text
x
x
x
```

#### Nested Repeats Inside Staged Repeat

When the LHS contains an inner repeat, the iterator value is available during
the inner repeat's evaluation:

```mantra
print { [ 1 : m ] :: 2 @ m }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 1 1 ]
```

The first stage binds `m = 1`, so `[ 1 : 1 ]` produces `[ 1 ]`. The second
stage binds `m = 2`, so `[ 1 : 2 ]` produces `[ 1 1 ]`.

With recurse tokens inside staged repeat:

```mantra
print { scope { [ + 1 - ( ... ) : m ] :: 2 @ m } }
```

Expected `OUTPUT`:

```text
[ + 1 - () ] [ + 1 - ( + 1 - () ) ]
```

#### Assigned Variable Drivers

A variable containing an array or expression drives the staged repeat:

```mantra
values = [ 2 3 4 ];
print { [ ~ * x * x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ * 4 ] [ * 9 ] [ * 16 ]
```

## Driver Resolution

`ResolveRepeatDriver` handles the chain of lookups that turns an RHS into
an effective driver:

1. **Variable substitution** — If the RHS contains a variable, it is resolved
   from context and replaced with its bound tree.
2. **Iterator binding extraction** — If the driver is wrapped with `@`, the
   binding is extracted: the driver index points to the actual driver, and
   the iterator token reference is captured.
3. **Direct variable check** — If the result is still an unresolved bare
   variable, expansion aborts (returns `False`).

## Staged Repeat vs Single-Colon Repeat

| Aspect | Single-colon `:` | Staged `::` |
|---|---|---|
| Implementation | `TRepeatNode` / `TIntegerNode.Expand` | `TStagedRepeatNode.Evaluate` |
| Iterator binding | No | Yes (`@ var`) |
| Per-item evaluation | All clones evaluated together | Each clone evaluated separately |
| Range support | Via `TIntegerNode.Expand` | Via `TStagedRepeatNode` |
| Nested repeats | Iterator not available | Iterator value available in inner repeats |
| Sequence driver | Not supported | Array/expression iteration |

## Implementation Details

The staged repeat implementation in `TStagedRepeatNode.Evaluate` follows
this structure:

1. **Resolve driver** — `ResolveRepeatDriver` finds the effective driver and
   any iterator binding.
2. **Clone LHS** — For each stage, `GlobalTree.CloneSubtree(LHS)` creates
   an independent copy.
3. **Bind iterator** — If `@ var` is present, `PushIteratorValueByToken`
   binds the current value to the iterator variable in context.
4. **Evaluate** — The clone is evaluated within a wrapper node.
5. **Cleanup** — `PopRepeatIteratorValue` removes the binding. The wrapper
   is deleted; the result is collected.
6. **Finalize** — All results are linked as siblings. The original staged
   repeat node is replaced inline via `GlobalTree.ExpandInline` or `Expand`.

The range repeat path uses `TryBuildRangeDomain` and `RangeDomainNext` to
iterate over integer or float ranges, supporting both `start .. end` and
`start .. end by step` forms.
