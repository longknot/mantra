# Selection Operator

The selection operator `?` applies rule-based structural rewrites to a subject
tree. It is one of the core transformation operators in Mantra, used to
pattern-match a tree and replace the matched subtree according to user-defined
rules.

```mantra
subject ? rules
```

The right side can be a single rule, a ruleset (list of rules separated by
commas), or a variable referencing a ruleset.

## Basic Usage

Selection attempts to rewrite the subject using the first matching rule from
the provided ruleset. If no rule matches, the subject is returned unchanged.

```mantra
{ [ 1 2 3 ] ? 0 }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
```

With zero rules (`0`), no rewrite is possible, so the original subject `[ 1 2
3 ]` is returned as-is.

## How It Works

The selection operator follows a deterministic rewrite lifecycle:

1. **Evaluate the subject** -- The left side is evaluated in the current
   context, resolving any variables to their bound tree snapshots.
2. **Resolve the ruleset** -- If the right side is a variable, it is
   dereferenced (recursively) to obtain the actual ruleset. Rule templates are
   never evaluated themselves; they remain structural patterns.
3. **Search and match** -- The matcher walks the subject tree and tries each
   rule in order. The first rule whose pattern matches wins.
4. **Rewrite** -- On a match, captured variables are substituted into the
   replacement template and the matched subtree is replaced in-place.
5. **Collapse** -- The selection node is removed and replaced by the (possibly
   rewritten) result.

If the ruleset has multiple rules, they are tried in declaration order.
Place specific, narrow rules before broad fallback rules to ensure correct
priority.

## Example: Removing Elements

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

The rule `[ x -- ] => [ rhs x ]` captures the first element as `x` and
replaces the array with `rhs x` -- the remaining siblings after `x`. The
result is `[ 2 3 ]`.

## Multiple Rewrite Steps with Repeat

A single `?` performs at most one rewrite. To apply a rule repeatedly, combine
selection with the repeat operator `:`:

```mantra
{ ( [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] ) : 1 }
```

Expected `OUTPUT`:

```text
( [ 2 3 ] )
```

Each repeat iteration evaluates the selection again, applying one rewrite per
step. With `: 2`, the subject would be rewritten twice, producing `( [ 3 ] )`.

For iterative state-selection workflows that track focus and match state
across repeats, use `$?` instead. See [State Selection](state-selection.md).

## Inline Selection

The inline selection operator `:=?` behaves identically to `?` at runtime.
`TInlineSelectionNode` inherits from `TSelectionNode` and shares the same
evaluation and transform logic.

```mantra
subject :=? rules
```

Inline selection is primarily a syntactic variant. Use `:=?` when you want a
visual distinction between inline and top-level selection in source code.

## Matching Modes

By default, selection searches for matches at any depth in the subject tree --
the root, its children, and nested subexpressions. This is called
*subexpression mode*.

### Subexpression Mode (Default)

Without any modifier, `?` will find and rewrite the first matching
subexpression anywhere in the subject:

```mantra
{ ( [ 1 2 3 ] ) ? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ ok ] )
```

The rule matches `[ 1 2 3 ]` inside the parentheses and replaces it with
`[ ok ]`, preserving the surrounding structure.

### Root-Only Match (`^`)

Prefix `?` with `^` to restrict matching to the current subject root. The
rule must match the entire subject -- no subexpression searching is performed.

```mantra
{ ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ 1 2 3 ] )
```

The pattern `[ 1 2 3 ]` does not match the root `( [ 1 2 3 ] )`, so no
rewrite occurs. See [Root Selection](root-selection.md) for details.

## Rule Guards

Rules can carry guards that conditionally enable or disable a rewrite. A guard
is expressed inside a compute scope `~( ... )` appended to the replacement.
If the guard evaluates to true, the rule fires; otherwise, the matcher tries
the next rule.

```mantra
{ [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
1
```

The guard `< 1 2` is true, so the rule fires and returns `x` (which is `1`).

When the guard fails and no other rule matches, the subject is returned
unchanged:

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

Here `< 3 2` is false, so the rule does not fire and the original subject is
returned.

Multiple rules provide fallback when a guard fails:

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard `< 3 2` fails, so the second rule `[ x -- ] [ y -- ]
=> y` fires and returns `y` (which is `2`).

Guards can be disabled globally with the `--no-guards` CLI flag. When
disabled, guards are ignored and rules fire based on structural match alone:

```bash
mantra --no-guards program.m
```

With `--no-guards`, the first rule fires even though `< 3 2` is false,
returning `3` instead of trying the fallback.

## Ruleset Resolution

The right side of `?` can be:

- **An inline ruleset** -- rules passed directly: `[ rule1 , rule2 ]`
- **A variable** -- resolved at runtime to whatever ruleset it references
- **A ruleset variable chain** -- if the variable points to another variable,
  resolution continues recursively
- **Zero rules (`0`)** -- no rewrite is possible; subject passes through

Rule templates stored in variables are never evaluated prematurely. They remain
structural patterns until the matcher uses them during a selection or inference
step.

## Equivalence Rules

Selection supports bidirectional equivalence rules `<=>` in addition to
unidirectional transforms `=>`. An equivalence rule fires in either direction:

```mantra
print { [ 1 2 ] ? [ [ x y ] <=> [ y x ] ] }
print { [ 2 1 ] ? [ [ x y ] <=> [ y x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 1 ]
[ 1 2 ]
```

The first subject `[ 1 2 ]` matches the left side `[ x y ]` and is rewritten
to `[ y x ]`. The second subject `[ 2 1 ]` matches the right side (which
is `[ y x ]` from the equivalence) and is rewritten to `[ x y ]`.

## Related Pages

- [Basic Transform](transform-rules/basic-transform.md)
- [Equivalence Rules](transform-rules/equivalence-rules.md)
- [Root Selection](root-selection.md)
- [State Selection](state-selection.md)
- [Focus and Match Selectors](focus-match-selectors.md)
