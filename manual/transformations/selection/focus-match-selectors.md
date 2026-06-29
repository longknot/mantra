# Focus and Match Selectors

In state-selection (`$?`) rules, replacement templates can use `$focus` and
`$match` to reference specific parts of what the matcher found. These are
special capture variables that carry runtime context -- the focused subtree and
the full matched span.

## What They Capture

| Selector | Captures |
|---|---|
| `$focus` | The subtree marked with `.` (dot) in the pattern |
| `$match` | The entire span matched by the rule pattern |

Both selectors work only inside `$?` state-selection workflows. They cannot
appear in ordinary `?` selection rules.

## $match -- Full Matched Span

`$match` replaces the node with the complete matched subtree. It is the
equivalent of `all` for the entire match, not just a single captured variable.

```mantra
~ { 1 [ 2 ] 3 $? [ [ x ] =>> $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

The pattern `[ x ]` matches `[ 2 ]`. `$match` returns the full matched node --
the list `[ 2 ]` itself -- not just the inner value.

### $match with multi-node patterns

When a pattern matches multiple siblings, `$match` captures the entire matched
span:

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ]
```

The rule matches two consecutive lists. `$match` captures both -- `[ 1 ]` and
`[ 2 ]` -- as the full matched span.

### $match with lhs / rhs / all selectors

`$match` can be combined with structural selectors (`lhs`, `rhs`, `all`) to
extract parts of the matched span:

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> lhs $match ] : 1 }
```

Expected `OUTPUT`:

```text
1
```

`lhs $match` extracts the left (first child) of the first matched node, which
is `1`.

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> rhs $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

`rhs $match` extracts the right sibling of the first matched node, which is
`[ 2 ]`.

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> all $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ]
```

`all $match` returns the matched node plus all siblings up to the match tail,
which here is the same as the default `$match` behavior.

## $focus -- Dot-Marked Focus

`$focus` captures only the subtree marked with a `.` (dot) prefix in the
pattern. The dot marks a specific node as the "focus" -- the matcher tracks
its position and passes it to the replacement template.

```mantra
~ { 1 [ 2 ] 3 $? [ [ .x ] =>> $focus ] : 1 }
```

Expected `OUTPUT`:

```text
2
```

The pattern `[ .x ]` matches `[ 2 ]`, and the `.` on `x` marks that node as
the focus. `$focus` extracts only the focused content -- the inner `2` --
replacing the entire subject with it.

### $focus vs. $match

The key difference: `$match` returns the full matched span, while `$focus`
returns only what the dot marker designates:

```mantra
~ { 1 [ 2 ] 3 $? [ [ .x ] =>> [ $match $focus ] ] : 1 }
```

Expected `OUTPUT`:

```text
[ [ 2 ] 2 ]
```

`$match` gives `[ 2 ]` (the full matched node), while `$focus` gives `2` (the
focused inner content). Both appear in the replacement.

### $focus with no dot marker

When there is no `.` in the pattern, `$focus` has nothing to capture:

```mantra
print ~ { 1 [ 2 ] 3 $? [ [ x ] =>> $focus ] : 1 }
```

Expected `OUTPUT`:

```text
1 [ 2 ] 3
```

Without a focus marker, `$focus` resolves to nothing. The rule matches but the
replacement is empty, so the rewrite does not advance and the subject remains
unchanged.

### $focus with selector modifiers

Like `$match`, `$focus` accepts `lhs`, `rhs`, and `all`:

```mantra
~ { 1 [ 2 3 ] 4 $? [ [ .x ] =>> lhs $focus ] : 1 }
```

Expected `OUTPUT`:

```text
2
```

`$focus` captures `2 3` (the focused content), and `lhs` extracts its first
child: `2`.

## Focus Marker in Patterns

The `.` (dot) prefix in a pattern designates which node is the focus. Only one
focus marker is allowed per pattern -- the matcher raises an error if multiple
are found.

```
[ .x ]     -- focus is x
[ x .y ]   -- focus is y
```

The focus marker does not change what the pattern matches -- it only labels a
captured node for later reference via `$focus` in the replacement template.

The dot marker is the same `.` meta flag (`TK_DOT`) used for dot-focus
transforms. In the matcher, `CountPatternFocusMarkers` walks the pattern tree
and counts nodes with the dot flag set.

## Focus Target Rewrites

When a rule has the `.` meta flag on the transform operator itself (`. =>` or
`. =>>`), the rewrite targets the focused span instead of the full matched
span. This is the "focus target" behavior: the matched region is replaced at
the position of the focus marker rather than at the match root.

Example -- a recursive `cat` callable uses `. =>> ... $focus` to rewrite at
the focused position:

```mantra
rule cat [
  cat [ X -- ] . -- =>> [ all X ] $focus
]
```

Here the `.` on the pattern marks the focus, and the rewrite replaces only the
focused subspan, not the entire matched prefix.

## Chained Selections with $match

`$match` is useful for chaining extractions across multiple rules stored in
variables:

```mantra
. persons = [
  [ "name" "John Doe",
    "address" [
      "street" "123 Main St",
      "city" "Anytown",
      "country" "USA"
    ]
  ],
  [ "name" "Jane Smith",
    "address" [
      "street" "456 Elm St",
      "city" "Othertown",
      "country" "USA"
    ]
  ]
]

. extract_person = [
  [ "name" "Jane Smith", -- ] =>> $match
]

. extract_address = [
  "address" =>> rhs $match
]

. extract_street = [
  "street" =>> rhs $match
]

print { persons ? extract_person ? extract_address ? extract_street }
```

Expected `OUTPUT`:

```text
"456 Elm St"
```

Each step narrows the result: `extract_person` finds the matching record,
`extract_address` gets the nested address, and `extract_street` extracts the
street value. `$match` preserves the full matched structure for the next step
to operate on.

## Summary

| Selector | Requires dot marker? | Captures |
|---|---|---|
| `$match` | No | Full matched span |
| `$focus` | Yes | Dot-marked subtree only |
| `lhs $match` | No | Left child of match root |
| `rhs $match` | No | Right siblings of match root |
| `all $match` | No | Match node + siblings to tail |
| `lhs $focus` | Yes | Left child of focused node |
| `rhs $focus` | Yes | Right siblings of focused node |

Both `$match` and `$focus` are context-sensitive -- they only work inside
`$?` state-selection rules (`=>>` inline transforms).

## Related Pages

- [State Selection](state-selection.md)
- [Inline Transform](../transform-rules/inline-transform.md)
- [Selection Operator](selection-operator.md)
- [Root Selection](root-selection.md)
