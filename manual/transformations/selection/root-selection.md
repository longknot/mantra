# Root Selection

By default, selection searches the entire tree for matching subexpressions.
Root selection restricts the match to the subject's root node only.

The `^` (caret) marker controls root selection in two ways:

1. **On the selection operator** (`^?`) — forces full-root match.
2. **On individual nodes** in the subject — marks them as preferred match targets.

## Full-Root Match (`^?`)

Prefixing the `?` operator with `^` requires the rule to match the entire
subject root — no subexpression search occurs.

```mantra
[ + 1 2 ] ^? [ + x y => + y x ]
```

The rule pattern is compared against `[ + 1 2 ]` as a whole. If it doesn't
match the root, the selection produces no rewrite.

Without `^`, the matcher would descend into children and siblings looking for
any subexpression that matches.

The same behavior applies to the inference operator `^|=`. Prefixing inference
with `^` restricts proof search to root-level matches only:

```mantra
print { [ ( 1 ) ] => [ 1 ] ^=|=[ ( x ) <=> x ] }
```

```text
OUTPUT: 0
```

Without `^`, inference finds the subexpression `( 1 )` inside the array and
proves the rewrite succeeds (`1`). With `^`, it must match the root
`[ ( 1 ) ]` directly, which fails (`0`).

## Subexpression vs Full-Root: Examples

Default (no `^`): the matcher searches recursively through the subject tree
and rewrites the first matching subexpression:

```mantra
{ ( [ 1 2 3 ] ) ? [ [ 1 2 3 ] => [ ok ] ] }
```
```text
OUTPUT: ( [ ok ] )
```

With `^?`: the rule must match the entire root `( [ 1 2 3 ] )` — it doesn't,
so no rewrite occurs:

```mantra
{ ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```
```text
OUTPUT: ( [ 1 2 3 ] )
```

## Per-Node Caret Marks

Even when subexpression search is active (no `^?`), you can guide the matcher
by prefixing individual nodes with `^`. The runtime scans for the first
`^`-marked node and starts the search there.

```mantra
{ "a" ^"b" "c" ? [ "a" => "A", "b" => "B" ] }
```
```text
OUTPUT: "a" "B" "c"
```

The `^` on `"b"` directs the matcher to start there. `"b" => "B"` matches
before `"a" => "A"` even though `"a"` appears earlier in the tree.

Nested per-node caret:

```mantra
{ "x" ( ^"y" ) ? [ "x" => "X", "y" => "Y" ] }
```
```text
OUTPUT: "x" ( "Y" )
```

## Caret Interaction with `^?`

Per-node caret marks only have an effect in subexpression mode. When `^?` is
used, the matcher never descends into children, so `^` on individual nodes
within the subject is ignored — only the root-level match attempt occurs.

## Caret Marks Are Consumed

The `^` flag on per-node marks is cleared (consumed) when the matcher finds
and uses it. This means:

- A single selection step cannot reuse the same caret mark twice.
- In repeat-driven selection loops (`: 1`, `: ...`), a caret mark placed on
  the source will only guide the first iteration. Subsequent iterations
  resume normal subexpression search from the root.

## Match-Any Prefix Preservation

When using `--` (match any) in a rule pattern, the matcher can preserve
unmatched prefix elements at the root level:

```mantra
{ 12 [ 15 20 ] [ 49 ] ? [ [ x -- ] [ y -- ] => [ all x ] [ all y ] 1 ] }
```
```text
OUTPUT: 12 [ 15 20 ] [ 49 ] 1
```

The prefix `12` is not consumed by the rule and remains in the output.

## Implementation Details

- The `MatchSubexpressions` flag is derived from `(Data and TK_CARET) <> TK_CARET`
  on the selection node.
- When `MatchSubexpressions` is true and a `^`-marked node exists,
  `ConsumeFirstCaretInSubtree` finds it (DFS walk, clears the caret) and
  the search starts at that node.
- When `MatchSubexpressions` is false (`^?`), the search starts only at the
  root; if the root doesn't match, the selection is a no-op.
- Per-node `^` marks are consumed (cleared) during matching, so they cannot
  be reused by subsequent rewrite steps in the same selection.
- The same `TK_CARET` check applies to inference (`|=` and `<=> |=`), which
  also derive their `MatchSubexpressions` flag from the selection node data.

## Related Pages

- [Selection Operator](selection-operator.md)
- [Focus and Match Selectors](focus-match-selectors.md)
- [State Selection](state-selection.md)
- [Meta Flags](../syntax/meta-flags.md)
