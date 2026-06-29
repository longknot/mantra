# Match-Any Captures

The match-any token `--` captures zero or more trailing siblings in a pattern.
It is the primary wildcard mechanism for working with variable-length sequences
in Mantra rules.

```mantra
[ x -- ] => [ rhs x ]
```

Here, `x` matches the first element and `--` absorbs everything that follows.
In the replacement, `rhs x` emits only the siblings that came after `x` --
effectively dropping the head and keeping the tail.

Mantra provides two match-any tokens:

| Token | Constant | Greedy behavior |
|---|---|---|
| `--` | `TK_MATCH_ANY` | Shortest match (left-to-right) |
| `---` | `TK_MATCH_ANY_LONG` | Longest match (right-to-left) |

## When to Use

Use `--` when you need to:

- **Peel elements** from the front or back of a sequence.
- **Match variable-length tails** after a fixed prefix pattern.
- **Implement recursive descent** rules that process one element per match
  and recurse on the remainder.
- **Build merge, sort, and filter** operations on flat sequences.

For single-element wildcards (match any one node), use uppercase symbols
instead. For matching exactly one identifier, use lowercase symbols.

## How It Works

The matcher processes patterns left-to-right through a sequence matching
algorithm (`MatchPatternSequenceEx` in `matcher_ir.pas`). When it encounters
`--`, three cases apply depending on position:

### 1. `--` at the end (tail position)

```mantra
[ x -- ] => [ rhs x ]
```

The matcher binds `x` to the first subject node, then `--` consumes all
remaining siblings. This is the most common form.

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

`x` captures `1`. `rhs x` returns the siblings after `x`, which are `2 3`.
The result replaces the matched array.

### 2. `--` at the beginning (prefix position)

```mantra
[ -- x ] => [ rhs x ]
```

When `--` appears first and another pattern follows, the matcher skips ahead
in the subject so the remaining pattern(s) fit at the end. It computes the
skip position as `subject_length - remaining_pattern_count`.

For example with `[ -- y ]`, `--` absorbs everything except the last element,
which binds to `y`.

### 3. `--` in the middle (infix wildcard)

```mantra
[ x -- y ] => ...
```

The matcher must find where `--` stops and where `y` begins. Without
backtracking (`--backtracking` CLI flag), it searches forward from `x` for
the first position where `y` matches. With backtracking, it tries all
positions and uses the longest-match or shortest-match strategy depending on
the token (`---` vs `--`).

```mantra
{ [ 1 2 3 4 5 ] ? [ [ x -- y ] => [ x y ] ] }
```

Expected `OUTPUT` (without backtracking):

```text
[ 1 2 ]
```

`x` binds to `1`. The matcher scans forward and finds `y` matching at `2`
(first match). `--` captures nothing (empty span between `x` and `y`).

## Tail Capture and Replacement

The matcher tracks what `--` captures in a `TailRefs` binding. When the
variable preceding `--` is used with a selector in the replacement template,
the tail reference determines what gets emitted.

### `rhs x` -- Tail after x

Returns the siblings that follow `x`. When `x` was followed by `--` in the
pattern, `rhs x` returns exactly what `--` captured.

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

### `all x` -- x plus its tail

Returns `x` followed by all captured siblings (the tail). In replacement
position, `x --` is equivalent to `all x` for matcher-bound symbols -- it
splices the matched node and the captured tail back into the output.

```mantra
{ [ [ 1 2 3 ] ] ? [ [ [ x -- ] ] <=> [ x -- ] ] }
```

Expected `OUTPUT`:

```text
[ [ 1 2 3 ] ]
```

### `lhs x` -- The node x itself

Returns only the node bound to `x`, without any siblings.

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => x ] }
```

Expected `OUTPUT`:

```text
1
```

This is confirmed by the `matcher_rule_capture_head` test fixture.

## `--` vs `---`: Shortest vs Longest Match

The key difference between `--` and `---` is the direction the matcher
searches when resolving the wildcard:

| Token | Search direction | Behavior |
|---|---|---|
| `--` | Left-to-right | Stops at the **first** match for the next pattern |
| `---` | Right-to-left | Finds the **last** match for the next pattern (longest wildcard span) |

This only matters when `--`/`---` appears before another pattern element
(prefix or infix position). In tail position (end of pattern), both tokens
behave identically since they both capture everything remaining.

The `IsLongWildcardNode` helper in `matcher_ir.pas` checks whether the
match-any token is `TK_MATCH_ANY_LONG` (`---`) to select the correct search
direction in `FindNextPatternMatch` and
`TryMatchWildcardRemainderWithBacktracking`.

### Backtracking

When the `--backtracking` CLI flag is enabled, infix wildcards get enhanced
behavior. Instead of a single-pass scan, the matcher tries all possible split
positions and uses backtracking to find a valid match. This is useful when
the next pattern after `--` can match at multiple positions and you need the
best fit.

Without backtracking, the first/last position wins depending on `--` vs
`---`. With backtracking, the matcher explores alternatives and backtracks
when a chosen position fails later in the pattern.
