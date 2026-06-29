# Transform Examples

This page collects compact examples that demonstrate transforms and selection
rewrites in Mantra.

## Basic Selection

A selection rewrites its left-hand subject using the first matching rule from
the right-hand list.

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => x ] }
```

Expected `OUTPUT`:

```text
1
```

The lowercase symbol `x` binds to the first element; `--` captures the
remaining tail. The replacement keeps only `x`.

## Subexpression Matching (Default)

By default, the matcher searches subexpressions and rewrites the first match.

```mantra
print { ( [ 1 2 3 ] ) ? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ ok ] )
```

## Full-Root Matching (^)

The `^` meta flag restricts matching to the subject root only — inner
subexpressions are not considered.

```mantra
print { ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
( [ 1 2 3 ] )
```

The outer parentheses are the root; `[ 1 2 3 ]` is a subexpression, so the
rule does not fire.

## Prefix Preservation

When a rule matches a suffix of a flat sequence, unmatched prefix siblings
are preserved.

```mantra
print { 12 [ 15 20 ] [ 49 ] ? [ [ x -- ] [ y -- ] => [ all x ] [ all y ] 1 ] }
```

Expected `OUTPUT`:

```text
12 [ 15 20 ] [ 49 ] 1
```

The `12` before the matched arrays remains as a sibling in the result.

## Iterative Selection ($)

The `$` meta flag enables iterative state-selection mode. Combined with
repeat (`: n`), the rule fires `n` times, each time rewriting the result
of the previous step.

### Step-by-step removal of first element

```mantra
print { ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 1 }
print { ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 2 }
print { ( [ 1 2 3 ] $? [ [ x -- ] => [ rhs x ] ] ) : 3 }
```

Expected `OUTPUT`:

```text
( [ 2 3 ] )
( [ 3 ] )
( [] )
```

Each repeat step applies `[ x -- ] => [ rhs x ]`, which removes the first
element. After three steps the list is empty.

## Match Any (--)

The `--` token matches any number of sibling nodes (zero or more).

### Infix match any

```mantra
print { [ 1 2 3 4 ] ? [ [ 1 -- 4 ] => [ ok ] ] }
```

Expected `OUTPUT`:

```text
[ ok ]
```

The pattern `[ 1 -- 4 ]` matches any sequence starting with `1` and ending
with `4`.

### Suffix match any (-- prefix)

```mantra
rule last [
  last [ -- x ] => x
]

print { last [ 1 2 3 ] }
input = [ 4 5 6 ]
print { last input }
```

Expected `OUTPUT`:

```text
3
6
```

`[ -- x ]` matches any sequence and binds `x` to the last element.

### Long match any (---)

`---` matches zero or more nodes greedily, including nodes that contain the
target value. It is useful when `--` stops too early.

```mantra
print { [ 1 2 0 2 3 ] ? [ [ 1 -- 2 3 ] => [ short ] ] }
print { [ 1 2 0 2 3 ] ? [ [ 1 --- 2 3 ] => [ long ] ] }
```

Expected `OUTPUT`:

```text
[ 1 2 0 2 3 ]
[ long ]
```

`--` cannot bridge past the first `2` because it is greedy and stops at the
earliest match. `---` spans the entire range and finds `2 3` at the end.

## Uppercase Any Match

Uppercase symbols match any node regardless of type or value.

```mantra
print { [ [ 1 ] [ 1 ] ] ? [ [ X X ] => X ] }
```

Expected `OUTPUT`:

```text
[ 1 ]
```

`X` is an uppercase binder — it matches any structure. Because it appears
twice in the pattern, both positions must be structurally equal for the rule
to fire.

## Repeated Symbol Matching

The same lowercase symbol must bind to identical values.

```mantra
print { [ 1 1 ] ? [ [ x x ] => x ] }
print { [ 1 2 ] ? [ [ x x ] => x ] }
```

Expected `OUTPUT`:

```text
1
[ 1 2 ]
```

The second input has mismatched values (`1` vs `2`), so the rule does not
fire and the subject is returned unchanged.

## Rule Order

Rules are tried in order; the first matching rule wins.

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => [ 9 ] , [ x -- ] => [ 8 ] ] }
```

Expected `OUTPUT`:

```text
[ 9 ]
```

Both rules match, but only the first fires.

## lhs / rhs / all Selectors

Rules can access the bound symbol's subtree using `lhs`, `rhs`, and `all`:

| Selector | Meaning |
|---|---|
| `x` | The node matched by `x` |
| `lhs x` | The left child of `x` |
| `rhs x` | The right sibling of `x` |
| `all x` | `x` plus all its right siblings |

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => x ] }
print { [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
print { [ 1 2 3 ] ? [ [ x -- ] => [ all x ] ] }
```

Expected `OUTPUT`:

```text
1
[ 2 3 ]
[ 1 2 3 ]
```

## Tail Splice (x --) in Replacement

Using `x --` in the replacement position splices the matched node and its
captured tail back into the output — equivalent to `all x`.

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => [ x -- ] ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
```

This is especially useful with bidirectional equivalence rules:

```mantra
print { [ [ 1 2 3 ] ] ? [ [ [ x -- ] ] <=> [ x -- ] ] }
print { [ 1 2 3 ] ? [ [ [ x -- ] ] <=> [ x -- ] ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
[ [ 1 2 3 ] ]
```

## Equivalence (<=>)

Equivalence rules are bidirectional — they match in both directions.

```mantra
print { [ 1 2 ] ? [ [ x y ] <=> [ y x ] ] }
print { [ 2 1 ] ? [ [ x y ] <=> [ y x ] ] }
```

Expected `OUTPUT`:

```text
[ 2 1 ]
[ 1 2 ]
```

## Named Rules and Rule Dispatch

Rules can be named and invoked via variable lookup.

```mantra
rule f [
  f x => x
];

alias g = f;

print { g 7 }
```

Expected `OUTPUT`:

```text
7
```

### Named rule with variable binding

```mantra
rule cat [
  cat X Y => [ lhs X lhs Y ]
]

var_x = [ 1 2 3 ];
var_y = [ 4 5 6 ];

print { cat var_x var_y }
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 5 6 ]
```

The `X` and `Y` uppercase binders match the variable nodes. The rule
constructs a result using `lhs` to extract the variable's first subtree.

## Transparent Grouping (<< >>)

Transparent grouping `<< ... >>` provides parse-level grouping without
leaving a scope node in the AST. This is useful when a transform operand
needs grouping but the grouping wrapper should not survive.

```mantra
ih = << + m : + n >> => << + n : + m >>;

print { ih }
print { + m : + n ? [ ih ] }
```

Expected `OUTPUT`:

```text
+ m : + n => + n : + m
+ n : + m
```

## Fixed Transforms

A fixed transform (`\` before the operator) prevents variable-shaped terms
from becoming fresh matcher bindings — the pattern must match structurally
and completely.

```mantra
x = 1;
fixed = x \ => 2;
schema = x => 2;

print { 1 ? [ fixed ] }
print { 3 ? [ fixed ] }

x = 3;

print { 1 ? [ fixed ] }
print { 3 ? [ fixed ] }
```

Expected `OUTPUT`:

```text
2
3
1
2
```

The fixed rule uses the resolved value of `x` at the time of each
application, not a fresh binding. After `x = 3`, the fixed rule now matches
`3` instead of `1`.

## Substitution Transforms (==>)

The `==>` operator performs symbol-level substitution across an entire
expression, replacing all occurrences of the left symbol with the right
side.

```mantra
print { x ==> y }
print { x ? [ x ==> - x ] }
print { + x ( - x ) x ? [ x ==> - x ] }
```

Expected `OUTPUT`:

```text
x ==> y
- x
- x + ( + x ) - x
```

All occurrences of `x` in the subject are replaced with `- x`.

### Strict substitution

By default, substitution applies to all occurrences. The `?` + `[ ... ==> ... ]`
form ensures the substitution only fires inside a selection context.

```mantra
print { + x ( - x ) x ? [ x ==> - x ] }
```

Expected `OUTPUT`:

```text
- x + ( + x ) - x
```

The subject `+ x ( - x ) x` contains three occurrences of `x`. All three
are replaced with `- x`, including the `- x` which becomes `+ x` when the
unary `-` is applied.

## Inline Transform (:>)

The `:>` (inline transform) replaces matched nodes in place. Combined with
`~` compute and `$` iterative selection, it can rewrite subtrees:

```mantra
~ { 1 [ 2 ] 3 $? [ [ x ] =>> x ] : 2 }
```

Expected `OUTPUT`:

```text
2
```

## Transform Dot (.)

The `.` prefix on a pattern focuses on specific matched positions. The
`.=>` operator replaces the focused position with the replacement.

```mantra
~ { [ [ 2 ] ] $? [ [ .[ x ] ] .=> x ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

The pattern `.[ x ]` focuses on an array containing `x`; the `.=>` replaces
the focused position with `x`, unwrapping one level.

### Delete focused position

With no replacement after `.=>`, the focused node is deleted:

```mantra
~ { [ [ 2 ] [ 3 ] ] $? [ [ .[ x ] -- ] .=> ] : 1 }
```

Expected `OUTPUT`:

```text
[ [ 3 ] ]
```

The first `[ x ]` position is matched and removed, leaving `[ 3 ]`.

## Guards

Guards are expressions prefixed with `~` that must evaluate to true (non-zero)
for a rule to fire.

### Guard passes

```mantra
print { [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
1
```

The guard `~( < x y )` checks that `x < y` (i.e., `1 < 2`), which is true,
so the rule fires.

### Guard fails with fallback

```mantra
print { [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) , [ x -- ] [ y -- ] => y ] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard `~( < x y )` fails because `3 < 2` is false. The
second rule fires instead, returning `y`.

### Guard fails with no fallback

```mantra
print { [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

No rule succeeds, so the original subject is returned unchanged.

### Disabling guards (--no-guards)

The `--no-guards` CLI flag makes rules ignore guard conditions entirely:

```bash
mantra --no-guards program.m
```

With `--no-guards`, the example above would return `3` because the first
rule fires without evaluating its guard.

## Selection Policies

The `selector` keyword controls which match to pick when multiple rules or
positions match.

```mantra
print { selector shrink 1 2 3 ? [ x y z => x y, x y z => x ] }
```

Expected `OUTPUT`:

```text
1
```

The `shrink` policy picks the rewrite that produces the smallest result
(fewest nodes). Between `x y` (2 nodes) and `x` (1 node), the second rule
wins.

## Variable-Valued Rules

Rules can be stored in variables and referenced by name in selections.

```mantra
flatten = + ( + X ) => + X;
subject = + ( + m );
print { subject ? [ flatten ] }
```

Expected `OUTPUT`:

```text
+ m
```

## Transparent Grouping with Repeat

When a rule replacement contains a repeat expression, parentheses are needed
to keep the repeat bound to the replacement:

```mantra
r = target => ( + n : + m 1 );

print { target ? [ r ] }
```

Expected `OUTPUT`:

```text
( + n : + m + 1 )
```

## Selection with transform RHS tokens

Rules in a selection RHS can use different transform operators:

```mantra
print { [ 1 2 3 ] ? [ x => y , x =>> y ] }
```

Expected `OUTPUT`:

```text
[ y 2 3 ]
```

The first rule uses `=>` (single replacement). The `=>>` variant also
performs replacement but with slightly different scoping semantics.

## Structural Query Example

Transforms combined with `define` keywords enable SQL-like structural queries:

```mantra
define select from where ;
people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] ] ;
rule select [ select field from table where key val => ( table ? [ [ key val field out -- ] =>> out ] ) ] ;
print { select "name" from people where "id" 2 }
```

Expected `OUTPUT`:

```text
( "Jane Smith" )
```

The rule matches the structured pattern and extracts the `"name"` field
from the record where `"id"` equals `2`.

## Merge Example

A practical multi-rule transform that merges and sorts two sorted lists:

```mantra
merge = [
  [ x -- ] [ y -- ] 1 => x [ rhs x ] [ all y ],
  [ x -- ] [ y -- ] 0 => y [ all x ] [ rhs y ],
  [ x -- ] [] => all x,
  [] [ y -- ] => all y
];
```

The `merge` variable holds rules that compare heads of two lists and
recursively merge the smaller element first. Used with selection:

```mantra
[ 1 2 3 ] [ 4 5 6 ] ? merge
```
