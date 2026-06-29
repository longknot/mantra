# Inline Transform

The inline transform operator is `=>>`.

```mantra
pattern =>> replacement
```

## What It Does

Inline transform is a variant of the basic transform (`=>`) with a
different replacement strategy.

- **Basic transform (`=>`):** Replaces only the matched span *within* the
  subject tree. The surrounding structure of the subject is preserved.
- **Inline transform (`=>>`):** Replaces the *entire* subject tree with
  the replacement. The matched span is removed and the replacement becomes
  the new root of the result.

This makes inline transform ideal for extraction, projection, and cases
where the entire subject should be collapsed into a smaller result.

## Basic Example

A standard transform keeps the surrounding tree:

```mantra
{ [ 1 2 3 ] ? [ x =>> y ] }
```

Expected `OUTPUT`:

```text
y
```

The `x` pattern matches `1` — but instead of replacing just `1` inside
the list, the entire subject `[ 1 2 3 ]` is replaced by `y`.

Compare with a basic transform on the same subject:

```mantra
{ [ 1 2 3 ] ? [ x => y ] }
```

Expected `OUTPUT`:

```text
[ y 2 3 ]
```

Here only the first element `1` is replaced; the list structure remains.

## With State Selection

Inline transforms are commonly paired with `$?` (state selection) and
repeat (`: n`) to extract specific elements or fields from structures.

### Extract a matched element

```mantra
~ { 1 [ 2 ] 3 $? [ [ x ] =>> x ] : 2 }
```

Expected `OUTPUT`:

```text
2
```

The `$?` iteratively rewrites the subject. The rule `[ x ] =>> x` matches
any single-element list and replaces the entire subject with the extracted
element. After two rewrite steps (`: 2`), the `[ 2 ]` element is found
and unwrapped.

### Using $match selectors

```mantra
~ { 1 [ 2 ] 3 $? [ [ x ] =>> $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

Here `$match` refers to the matched subtree itself, so the rule extracts
the matching `[ 2 ]` node as the replacement.

### Using lhs / rhs selectors

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> lhs $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 1 ]
```

The rule matches two consecutive lists. `lhs $match` extracts the left
element of the match, which is `[ 1 ]`.

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> rhs $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

Similarly, `rhs $match` extracts the right element of the match.

### Matching all with $match

```mantra
~ { [ 1 ] [ 2 ] [ 3 ] $? [ [ x -- ] [ y -- ] =>> $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 1 ] [ 2 ]
```

Without `lhs` or `rhs`, `$match` captures the full matched span — both
consecutive lists `[ 1 ] [ 2 ]`.

## Rule-Based Query Pattern

Inline transforms are useful for extracting specific fields from structured
data:

```mantra
define select from where ;
. people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] [ "id" 3 "name" "Alice Johnson" ] ] ;
. select_rule = [ [ select field from TABLE where key val ] => ( TABLE ? [ [ key val field out -- ] =>> out ] ) ] ;
print { [ select "name" from people where "id" 2 ] ? select_rule : 2 }
```

Expected `OUTPUT`:

```text
( "Jane Smith" )
```

The outer `=>` rule desugars a `select` query. The inner `=>>` rule
extracts the target field value from the matched record, replacing the
entire record with just the field value.

## Key Differences Summary

| Feature | `=>` (basic) | `=>>` (inline) |
|---|---|---|
| Scope | Replaces matched span within subject | Replaces entire subject |
| Preserves structure | Yes | No |
| Typical use | Local rewrites | Extraction, projection, collapse |
| With state selection | Modifies subject in place | Subject becomes the replacement |

## Notes

- Inline transform rules are **not bidirectional** — unlike `<=>`
  equivalence rules, `=>>` only rewrites in one direction.
- In the matcher, inline transform sets `InlineReplaceOnly` which bypasses
  the normal span-replacement logic and directly substitutes the subject
  tree with the replacement node.
- Inline transforms are commonly used inside `rule` declarations,
  selection rulesets, and with `$?` state-selection workflows.
