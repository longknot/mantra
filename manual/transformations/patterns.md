# Patterns

Patterns are structural templates that describe tree shapes. They appear on the
left side of transform rules and control which subject trees match and what
subtrees are captured for replacement.

```mantra
pattern => replacement
```

A pattern is not executable code — it is a structural blueprint. Both the pattern
and replacement sides of a transform rule are kept unevaluated until the matcher
applies them during a selection (`?`) or inference (`|=`) step.

Patterns are the foundation of structural pattern matching in Mantra. Every
rewrite operation — selection, transform, inference, head dispatch — relies on
patterns to find and capture matching subtrees.

## Pattern Components

A pattern is built from these elements:

| Element | Example | Matches |
|---|---|---|
| Literal nodes | `+`, `1`, `"text"` | Exact node values |
| Lowercase variables | `x`, `a`, `name` | Single identifier node |
| Uppercase variables | `X`, `A`, `HEAD` | Any node (including compound expressions) |
| Match-any (short) | `--` | Zero or more trailing siblings (left-to-right) |
| Match-any (long) | `---` | Zero or more trailing siblings (right-to-left) |
| Scope wrappers | `[ ]`, `( )`, `{ }` | Structural groupings |
| Fixed transform | `\` before `=>` | Literal pattern (no matcher bindings) |
| Focus marker | `.x` | Marks `x` as the focused subtree |

Patterns can be combined freely to describe complex tree structures.

## Pattern Matching Lifecycle

When a selection (`?`) or inference (`|=`) step applies rules to a subject, the
matcher follows this process:

1. **Compile the pattern** — The pattern tree is converted into a sequence of
   match instructions (`TMatchOp`: `moCheckObj`, `moCheckTokenId`, `moBindNode`,
   `moCheckBindEq`, `moBindTail`, `moGuard`, `moAccept`, `moFail`, etc.).
2. **Walk the subject** — The matcher traverses the subject tree (root first,
   then DFS into children and siblings). Subexpression mode is default; `^?`
   restricts to root-only matching.
3. **Execute instructions** — Each instruction checks a node property or binds
   a variable. If any check fails, the matcher backtracks and tries the next
   rule.
4. **Apply guards** — If the pattern has a guard (`~`), the cloned guard
   expression is evaluated via `Compute`. Non-zero is true; zero or absent is
   false. If the guard fails, the rule is rejected.
5. **Accept the match** — On success, captured bindings are available in the
   replacement template. The matched subtree is replaced and the selection node
   collapses to the result.

See [Selection Operator](selection/selection-operator.md) for the full rewrite
lifecycle and [Basic Transform](transform-rules/basic-transform.md) for rule
structure.

## Examples

### Basic literal pattern

```mantra
{ [ 1 2 3 ] ? [ [ 1 2 3 ] => [ replaced ] }
```

Expected `OUTPUT`:

```text
[ replaced ]
```

The pattern `[ 1 2 3 ]` matches the subject exactly by structure and value.
The replacement `[ replaced ]` is emitted.

### Lowercase variable capture

```mantra
{ [ x 2 3 ] ? [ [ x 2 3 ] => [ head x ] }
```

Expected `OUTPUT`:

```text
[ head 1 ]
```

The lowercase `x` captures `1`. The literal `2` and `3` must match exactly.

### Uppercase variable capture — any node

```mantra
{ f [ 1 2 ] ? [ f X => X ] }
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

The uppercase `X` captures the entire `[ 1 2 ]` subtree — a compound expression
that a lowercase `x` would refuse to match.

### Match-any tail capture

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ head x tail rhs x ] }
```

Expected `OUTPUT`:

```text
[ head 1 tail 2 3 ]
```

The `x` captures `1` and `--` absorbs `2 3` as the tail. `rhs x` returns the
siblings after `x` (i.e., `2 3`).

### Lowercase vs. uppercase — refusal

A lowercase variable refuses to match a compound expression:

```mantra
{ f [ 1 2 ] ? [ f x => x ] }
```

Expected `OUTPUT`:

```text
f [ 1 2 ]
```

The lowercase `x` cannot match `[ 1 2 ]`. The rule doesn't fire; the subject
is returned unchanged. Use uppercase `X` to capture arbitrary tree shapes.

### Symbol reuse — same symbol must match same node

```mantra
simplify = [ + a - a => 0 ];

print { + x - x ? simplify };
```

Expected `OUTPUT`:

```text
0
```

The pattern `+ a - a` binds the first `x` as `a` and verifies the second
occurrence references the same node. If the nodes differ, the rule fails.

### No match — subject returned unchanged

```mantra
{ [ 1 , 2 , 3 ] ? [ [ x -- ] => [ ok ] }
```

Expected `OUTPUT`:

```text
[ 1 , 2 , 3 ]
```

The comma-separated list `[ 1 , 2 , 3 ]` has a different structure than the
flat pattern `[ x -- ]`, so no match occurs.

### Root-only matching with `^?`

```mantra
{ ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] }
```

Expected `OUTPUT`:

```text
( [ 1 2 3 ] )
```

The `^` prefix restricts matching to the root node only. The root is
`( [ 1 2 3 ] )`, which doesn't match `[ 1 2 3 ]`. Without `^`, the matcher
would search subexpressions and find the inner list.

## Variable Captures

Pattern variables bind matched subtrees during structural pattern matching.
When a rule matches, each variable symbol in the pattern captures the
corresponding subtree from the subject, and the replacement side references
those captures to build the result.

### Capture resolution in replacements

When the matcher resolves captures in the replacement template, it follows
this priority chain:

1. **Bound pattern variable** — If the name was bound by the current match,
   use the bound node.
2. **Context variable** — If the name exists in the current scope, use its
   value.
3. **Keyword** — If the name is a defined symbol, keep it as a literal
   invocation (not substituted).
4. **Unresolved** — If none of the above, the variable remains as-is.

Pattern bindings shadow context variables of the same name:

```mantra
rule f [ f x => x ];

x = 5;
print { f 10 ? f };
```

Expected `OUTPUT`:

```text
10
```

The pattern binds `x` to `10`, which shadows the context variable `x = 5`.

For full details on variable captures, binding compilation, and substitution
mechanics, see [Variable Captures](patterns/variable-captures.md).

## Match-Any Captures

The `--` token captures zero or more trailing siblings. It is the primary
wildcard for variable-length sequences:

| Token | Behavior |
|---|---|
| `--` | Shortest match (left-to-right) |
| `---` | Longest match (right-to-left) |

### Tail position

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

`x` captures `1`; `--` absorbs `2 3`. `rhs x` returns the tail.

### Prefix position

```mantra
{ [ 1 2 3 ] ? [ [ -- x ] => x ] }
```

`--` skips ahead so the remaining pattern fits at the end. `x` captures `3`.

### Infix position

```mantra
{ [ 1 2 3 4 5 ] ? [ [ x -- y ] => [ x y ] }
```

Expected `OUTPUT` (without backtracking):

```text
[ 1 2 ]
```

`x` binds to `1`; the matcher scans forward and finds `y` at `2` (first match).
`--` captures nothing between them.

For full details on `--`, `---`, tail refs, and backtracking, see
[Match-Any Captures](patterns/match-any-captures.md).

## Selectors

Selectors extract specific structural parts of matched or bound variables
within replacement templates:

| Selector | Extracts |
|---|---|
| `lhs` | Left child (first subtree) of the target |
| `rhs` | Right siblings (all following siblings) |
| `all` | Full node plus all siblings (complete span) |

```mantra
{ [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] }
```

Expected `OUTPUT`:

```text
[ 2 3 ]
```

`rhs x` extracts the siblings after `x`, which are exactly what `--` captured.

For full details on selectors and selection policies, see
[Guards and Selectors](patterns/guards-and-selectors.md).

## Guards

Guards attach a boolean or arithmetic condition to a rule. The pattern must
still match structurally, but the guard can reject a match:

```mantra
pattern => replacement ~( condition )
```

```mantra
{ [ 1 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
1
```

The guard `~( < 1 2 )` evaluates to true, so the rule fires.

```mantra
{ [ 3 ] [ 2 ] ? [ [ x -- ] [ y -- ] => x ~( < x y ) ] }
```

Expected `OUTPUT`:

```text
[ 3 ] [ 2 ]
```

The guard `~( < 3 2 )` evaluates to false. The rule is skipped and the
subject is returned unchanged.

### Guard with fallback

```mantra
{ [ 3 ] [ 2 ] ? [
  [ x -- ] [ y -- ] => x ~( < x y ) ,
  [ x -- ] [ y -- ] => y
] }
```

Expected `OUTPUT`:

```text
2
```

The first rule's guard fails; the second (unguarded) rule fires.

Guards can be disabled globally with `--no-guards`. For full details, see
[Guards and Selectors](patterns/guards-and-selectors.md) and
[Guarded Rules](rules-in-practice/guarded-rules.md).

## Focus and Match Selectors

In state-selection (`$?`) rules, `$focus` and `$match` reference specific parts
of what the matcher found:

| Selector | Requires dot marker? | Captures |
|---|---|---|
| `$match` | No | Full matched span |
| `$focus` | Yes | Dot-marked subtree only |

```mantra
~ { 1 [ 2 ] 3 $? [ [ x ] =>> $match ] : 1 }
```

Expected `OUTPUT`:

```text
[ 2 ]
```

`$match` returns the full matched node. For full details, see
[Focus and Match Selectors](selection/focus-match-selectors.md).

## Fixed Transforms

A `\` prefix on the transform operator forces literal matching — variable
symbols are not treated as matcher bindings:

```mantra
ih = << + m : + n >> \ <=> << + n : + m >>;
```

Without `\`, `m` and `n` would become matcher variables. With `\`, they are
treated as literal symbols. For full details, see
[Basic Transform](transform-rules/basic-transform.md).

## Define Keywords

The `define` keyword registers symbols as match-time literals so they don't
appear as variables:

```mantra
define select from where ;

q = [ [ select x from y where z w ] => [ x ] ] ;

print { [ select "name" from persons where "id" 2 ] ? q : 1 }
```

Expected `OUTPUT`:

```text
[ "name" ]
```

Without `define`, `select`, `from`, and `where` would be treated as lowercase
pattern variables.

## Related Pages

- [Variable Captures](patterns/variable-captures.md) — Lowercase vs. uppercase, binding compilation, substitution, shadowing
- [Match-Any Captures](patterns/match-any-captures.md) — `--` and `---` wildcards, tail refs, infix matching
- [Guards and Selectors](patterns/guards-and-selectors.md) — `~( ... )` guards, `lhs`/`rhs`/`all` selectors, selection policies
- [Focus and Match Selectors](selection/focus-match-selectors.md) — `$focus` and `$match` in state-selection rules
- [Basic Transform](transform-rules/basic-transform.md) — `=>` operator, rule declarations, fixed transforms
- [Selection Operator](selection/selection-operator.md) — The `?` operator and rule-based rewriting
- [Guarded Rules](rules-in-practice/guarded-rules.md) — Deep dive into guard semantics
- [Ordered Rule Sets](rules-in-practice/ordered-rule-sets.md) — Rule priority without guards
- [Inline Transform](transform-rules/inline-transform.md) — `=>>` state-selection transforms
