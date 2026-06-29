# Operators and Special Forms

Mantra uses operators and special forms to request transformation, evaluation,
or computation. Every operator produces an AST node that the runtime dispatches
through virtual methods in `nodes.pas`.

This page describes the source form and behavior of each operator. Detailed
semantic analysis is covered in the linked sub-pages and the
[Transformations](../transformations/index.md), [Compute](../compute/index.md),
and [Evaluation](../evaluation/index.md) sections.

## Quick Reference

### Scope Delimiters

| Delimiter | Scope | Evaluates | Computes |
|---|---|---|---|
| `[ ... ]` | List container | Contextual | No |
| `( ... )` | Expression grouping | Contextual | No |
| `{ ... }` | Evaluation scope | Yes | No |
| `` ` ... ` `` | Compute scope | Yes | Yes |
| `' ... '` | Fixed scope | No | No |

See also: [List Containers](list-containers.md), [Expressions](expressions.md),
[Evaluation Scopes](evaluation-scopes.md), [Compute Scopes](compute-scopes.md),
[Fixed Scopes](fixed-scopes.md).

### Meta Flags

| Flag | Name | Effect |
|---|---|---|
| `~` | Tilde | Force compute on targeted node |
| `\` | Backslash | Fixed — do not transform |
| `$` | Dollar | State-selection mode |
| `^` | Caret | Full-match (no subexpression matching) |
| `.` | Dot | Matching rule marker |
| `@` | At | At-index / iterator binding |

See also: [Meta Flags](meta-flags.md).

---

## Scope Delimiters

### `[ ... ]` — List Container

Square brackets group values into a flat list container. The runtime creates a
`TArrayNode` at parse time and links children using the standard left-child /
right-sibling tree representation.

```mantra
[ + 1 2 3 ]
```

Output: `[ + 1 + 2 + 3 ]`

Square brackets create the most visible structural boundary. The runtime may
reformat the tree, but elements remain siblings within the container. Lists
support indexing via `@`, range slicing, and nested access.

See also: [List Containers](list-containers.md)

### `( ... )` — Expression Grouping

Parentheses group values as an expression subtree. The parser creates a
`TExpressionNode` node.

```mantra
( + 1 2 )
```

Use parentheses when the intended grouping is expression structure rather than
a flat list. In most contexts, parentheses and square brackets behave similarly;
the difference is semantic intent.

See also: [Expressions](expressions.md)

### `{ ... }` — Evaluation Scope

Curly braces delimit an explicit evaluation boundary. The runtime evaluates all
children inside the braces and replaces the scope node with its result.

```mantra
{ 1 2 3 : 4 }
```

The scope node collapses after evaluation — only the result remains. Evaluation
scopes process variable substitution, repeat expansion, selection rewriting,
and inference queries. They do **not** reduce arithmetic by default.

See also: [Evaluation Scopes](evaluation-scopes.md)

### `` `...` `` — Compute Scope

Backticks request arithmetic reduction of the scoped expression. The runtime
evaluates descendants, runs the compute engine, and removes the backtick wrapper.

```mantra
` + 1 2 3 `
```

Output: `+ 6`

Only supported operations (`+`, `-`, `*`, `/`, comparisons, trig functions,
etc.) are reduced. Non-computable terms pass through unchanged.

When passing backtick forms through a shell, wrap the program in single quotes:

```bash
echo '` + 1 2 3 `' | ./bin/mantra
```

See also: [Compute Scopes](compute-scopes.md)

### `' ... '` — Fixed Scope

Apostrophe markers prevent evaluation of the enclosed subtree. Nodes inside
are never transformed or computed, preserving their literal structure.

```mantra
' 1 2 3
```

The fixed scope acts as an evaluation barrier. The backslash prefix `\` has
the same effect for a single node or subtree.

See also: [Fixed Scopes](fixed-scopes.md)

---

## Assignment

### `=` — Variable Assignment

Stores a tree snapshot under a variable name. The left side is a binding target;
the right side is evaluated and the result is cloned into the context.

```mantra
x = [ + 1 2 3 ]
```

Output: `x = [ + 1 + 2 + 3 ]`

Assignment clones the RHS; it does not store a reference to the original subtree,
preventing unintended aliasing when the source tree is later modified. A variable
can be reassigned any number of times — the new value replaces the previous
binding. Assignments work inside `{ ... }` evaluation scopes and escape the
scope to remain visible afterward.

See also: [Assignment Syntax](operators-special-forms/assignment-syntax.md)

### `:=` — Deep Assignment

Evaluates the right side and performs a deep copy of a trie subtree, merging with
the existing variable. The deep assignment family controls conflict resolution:

| Operator | Node | Behavior |
|---|---|---|
| `:=` | `TDeepAssignNode` | Merge, overwriting on conflict |
| `>:=` | `TDeepAssignNode` | Overwrite mode (explicit) |
| `<:=` | `TDeepAssignNode` | Keep existing keys on conflict |
| `!:=` | `TDeepAssignNode` | Fail on conflict |

```mantra
dict.obj2 := dict.obj1      # merge with overwrite
dict.obj2 <:= dict.obj1     # keep existing keys
dict.obj2 !:= dict.obj1     # error on conflict
```

See also: [Assignment Syntax](operators-special-forms/assignment-syntax.md)

---

## Repeat and Expansion

### `:` — Repeat / Tile

The `:` operator repeats or tiles a left-hand tree using a right-hand driver.
An integer on the right clones the left that many times; `...` enables fixpoint
recursion (bounded by `MAX_FIXPOINT_STEPS = 1024`).

```mantra
[ + 1 2 3 ] : 3
```

Output: `[ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ]`

The left side is the source/template; the right side drives expansion. A variable
on the right is resolved from the runtime context.

### `::` — Staged Repeat (Iterator)

The `::` operator performs staged repeat with an iterator, allowing incremental
expansion steps rather than repeating all at once.

### `...` — Recurse / Fixpoint

The `...` operator enables recursive fixpoint expansion. When used with `:`, it
repeatedly applies the left-hand expression until no further changes occur or
the fixpoint bound is reached.

```mantra
pattern : ...    # recurse until fixpoint
```

See also: [Repeat Operator](../transformations/repeat-operator.md)

---

## Selection and Rewrite

### `?` — Selection Rewrite

Applies the first matching rule from a rule list to a subject tree. Lowercase
symbols match specific identifiers; uppercase symbols match any node. `--` matches
any tail sequence within a rule.

```mantra
[ 1 2 3 ] ? [ x => x + 1 ]
```

### `:=?` — Inline Selection

Creates a selection node that does not require a separate `?` operator. The
inline selection applies a rewrite rule directly to its operand.

### `$?` — State-Selection (Iterative)

Enables iterative state-selection mode where rules apply repeatedly until no
more matches occur (bounded by `MAX_FIXPOINT_STEPS = 1024`).

### `??` — Fallback Selector

Activates when a preceding `?` finds no match, providing an alternative rule
or default value.

See also: [Selection](../transformations/selection.md),
[Selection Rewrite](../transformations/selection-rewrite-model.md)

---

## Transformation Rules

### `=>` — Rewrite Rule

Maps a pattern to a replacement template. The left side is the pattern (input);
the right side is the template (output).

```mantra
x => x + 1       # rename x to x + 1
x => y           # identity — no change
```

A rule creates a `TRuleNode`. In selection, only the first matching rule is
applied per pass. Multiple rules can appear in a single selection context.

### `:=>` — Transform Node

Similar to `=>` but creates a `TTransformNode`. Used for direct structural
transformation operations.

### `<=>` — Bidirectional Rule

Creates a `TDiRuleNode` that matches in both directions — the rule can rewrite
from left to right or right to left depending on what matches.

### Transform Variants

The `=>` family has power variants for different transformation depths:

| Operator | Node | Description |
|---|---|---|
| `=>` | `TRuleNode` | Standard rewrite |
| `=>>` | `TTransformNode` | Power transform |
| `:=>` | `TTransformNode` | Direct structural transform |
| `==>` | `TTransformNode` | Multi-step transform |
| `==>>` | `TTransformNode` | Multi-step power transform |
| `<=>` | `TDiRuleNode` | Bidirectional rule |
| `<==>` | `TDiRuleNode` | Bidirectional power transform |

See also: [Selection Rules](../transformations/selection-rules.md),
[Selection Rewriting](../transformations/selection-rewriting.md)

---

## Inference

### `|=` — Inference Operator

Attempts to match a query tree against a rule list or fact base. Returns `1`
if a valid path exists (inference succeeds) and `0` otherwise.

```mantra
1 => 2 |= [ 1 => 2, 2 => 3 ] : 1
```

Output: `1`

The inference engine searches the rule list for a chain from the query start
to an endpoint. The `:` on the right limits search depth (iteration bound).

### `?|=` — Witness Inference

Performs inference but also returns the witness path taken, allowing
backtracking and solution enumeration.

See also: [Inference](../compute/inference.md),
[Inference Engine](../compute/inference-engine.md)

---

## Arithmetic and Comparison Operators

Mantra supports standard arithmetic and comparison operators, which can be reduced
inside compute scope `` `...` `` or via the `~` meta flag.

| Category | Operators |
|---|---|
| Arithmetic | `+` `-` `*` `/` `mod` |
| Comparison | `=` `<>` `>` `<` `>=` `<=` |
| Boolean | `and` `or` `xor` `not` |
| Math functions | `sin` `cos` `tan` `floor` `ceil` `round` `sqrt` `exp` `ln` `log2` `log10` `abs` `min` `max` |

```mantra
` + 1 2 3 `     # Output: + 6
` * 2 3 `       # Output: * 6
` < 3 5 `       # Output: < 1 (comparison reduced)
```

See also: [Compute Scopes](compute-scopes.md),
[Meta-Compute Operator](../compute/meta-compute-operator.md)

---

## Pattern Matching Operators

### `--` — Match Any

The `--` operator matches any sequence of nodes within a rule. It acts as a
wildcard that absorbs arbitrary content.

```mantra
[ 1 -- 3 ]       # matches any list starting with 1 and ending with 3
```

### `|` — Pattern Separator / Pipe

Serves as a pattern separator and pipe operator in certain contexts.

### Uppercase Variables — Universal Match

In rules and selections, uppercase symbols match any node. This enables
generalized pattern matching:

```mantra
X => X + 1    # X matches any single node
```

---

## Other Operators

### `&` — Concatenation / Append

Appends one node tree to another. Creates a `TAppendNode` that combines
subtrees at runtime.

```mantra
& [ 1 2 ] [ 3 4 ]    # concatenate two lists
```

### `@` — At-Index / Positional Lookup

Accesses elements by position in lists or expressions. Indexing is 1-based.

```mantra
print { [ 10 20 30 ] @ 2 }
```

Output: `20`

The `@` meta flag also marks iterator binding in repeat operations.

### `..` — Range Operator

Defines a range between two values. Used in `@` slicing for sub-range
extraction from lists.

```mantra
print { [ a b c d e ] @ 2 .. 4 }
```

Output: `[ b c d ]`

---

## Output and Control Forms

### `print` — Print

Prints a string or expression result to stdout.

```mantra
print "Hello, World!"
```

### `explode` / `implode` — Tree Expansion and Collapse

`explode` flattens a tree structure; `implode` collapses it back.

### `alias` — Rule Alias

Declares an alias for rules. Supports `|=` inference within aliased rule blocks.

### `#` — Comment

Everything after `#` on a line is treated as a comment and ignored by the parser.

---

## Meta Flags

Meta flags are unary prefixes that modify the behavior of the following node.

| Flag | Name | Node Type | Effect |
|---|---|---|---|
| `~` | Tilde | `TComputeNode` | Force compute on targeted node |
| `\` | Backslash | `TFixedNode` | Fixed — do not transform |
| `$` | Dollar | `TAtNode` / `TSelectionNode` | State-selection mode |
| `^` | Caret | `TDiRuleNode` | Full-match (no subexpression matching) |
| `.` | Dot | `TTransformNode` / `TRuleNode` | Matching rule marker |
| `@` | At | `TAtNode` | At-index / iterator binding |

### `~` — Meta-Compute

The tilde flag forces computation on the following subtree. Unlike compute scope
`` `...` ``, which wraps an entire expression, `~` targets specific nodes:

```mantra
{ ~ * 1.5 2 }      # Output: * 3
```

See also: [Meta-Compute Operator](../compute/meta-compute-operator.md),
[Meta Flags](meta-flags.md)

### `\` — Fixed Prefix

Marks a node or subtree as immune to transformation. Equivalent to a fixed scope
but scoped to a single node:

```mantra
\ [ + 1 2 ]       # prevents transformation of the enclosed tree
```

---

## Import and Include

### `import` — Import from Library

Loads definitions from an external file into the current context.

```mantra
import math
```

### `include` — Include File

Reads and evaluates an external file inline. Supports the `.` extension as a
convention (e.g., `.mantra`).

See also: [Import/Include Syntax](operators-special-forms/import-include-syntax.md)

---

## Operator Precedence and Evaluation Order

Operators are evaluated left-to-right. The runtime does not use traditional
precedence tables; instead, it follows a structural evaluation model:

1. **Parse** — The parser tokenizes input, creates AST nodes with types defined
   in `tokens.pas` (integer, float, operator, delimiter, etc.), and builds the
   tree.
2. **Evaluate** — The `TContext` evaluates nodes from the root downward. Each
   node type implements its own evaluation behavior.
3. **Format** — The formatter produces output via `FormatTree` or `FormatLine`.

Evaluation order is generally left-to-right, inside-out. Scope delimiters
control when evaluation happens relative to the surrounding context.

---

## Related Pages

- [Assignment Syntax](operators-special-forms/assignment-syntax.md)
- [Rule Declaration Syntax](operators-special-forms/rule-declaration-syntax.md)
- [Import/Include Syntax](operators-special-forms/import-include-syntax.md) — legacy overview
- [Package, Import, Include, and Global Syntax](operators-special-forms/package-import-include-global-syntax.md)
- [Meta Flags](meta-flags.md)
- [Operator Tokens](tokens-whitespace/operator-tokens.md)
- [Delimiter Tokens](tokens-whitespace/delimiters-scope-tokens.md)
- [Evaluation Scopes](evaluation-scopes.md)
- [Compute Scopes](compute-scopes.md)
- [Fixed Scopes](fixed-scopes.md)
- [List Containers](list-containers.md)
- [Expressions](expressions.md)
- [Repeat Operator](../transformations/repeat-operator.md)
- [Selection](../transformations/selection.md)
- [Selection Rules](../transformations/selection-rules.md)
- [Selection Rewriting](../transformations/selection-rewriting.md)
- [Meta-Compute Operator](../compute/meta-compute-operator.md)
- [Compute Scope](../compute/compute-scope.md)
- [Inference](../compute/inference.md)
