# Delimiters and Scope Tokens

Delimiter tokens define the visible shape of the source tree. Every delimiter
pair creates a different node type and triggers different runtime behavior.

## Scope Token Reference

| Delimiters | Token | Node Type | Description |
|---|---|---|---|
| `[ ... ]` | `TK_BRACKET_BEGIN` / `TK_BRACKET_END` | `TArrayNode` | Array / list container |
| `( ... )` | `TK_PARENTHESIS_BEGIN` / `TK_PARENTHESIS_END` | `TExpressionNode` | Expression grouping |
| `{ ... }` | `TK_CURLY_BEGIN` / `TK_CURLY_END` | `TEvaluationNode` | Evaluation scope |
| `` ` ... ` `` | `TK_BACKTICK` | `TComputeNode` | Compute scope |
| `' ... '` | `TK_APOSTROPHE` | `TExpressionNode` + `TK_FIXED` | Fixed scope (no evaluation) |
| `<< ... >>` | `TK_GROUP_BEGIN` / `TK_GROUP_END` | (transparent) | Transparent grouping |

## Bracket Scope `[ ... ]`

**Token:** `TK_BRACKET_BEGIN` / `TK_BRACKET_END`
**Node:** `TArrayNode`

Square brackets create an array or list container. The contents are kept as
structural data and are not automatically evaluated.

```mantra
[ + 1 2 3 ]
```

Brackets preserve tree structure. An array with an operator prefix will carry
that operator during computation; arrays without an operator are treated as
pure data containers and are not collapsed during compute.

## Parenthesis Scope `( ... )`

**Token:** `TK_PARENTHESIS_BEGIN` / `TK_PARENTHESIS_END`
**Node:** `TExpressionNode`

Parentheses group values, operators, and subexpressions. They are used when the
intended meaning is expression structure rather than a list container.

```mantra
( + 1 2 )
```

During compute, single-child parenthesis wrappers are collapsed into their
parent operator. Empty parenthesis wrappers with an operator are removed so the
parent operator can continue folding.

## Evaluation Scope `{ ... }`

**Token:** `TK_CURLY_BEGIN` / `TK_CURLY_END`
**Node:** `TEvaluationNode`

Curly braces mark an explicit evaluation boundary. The enclosed subtree is sent
through the runtime evaluation pipeline before being placed back into the
surrounding tree.

```mantra
[ { 1 2 3 : 4 } ]
```

Without the braces, the repeat operator `:` is structural data inside the array.
With the braces, the runtime evaluates the repeat and expands `1 2 3` into
four copies.

## Compute Scope `` ` ... ` ``

**Token:** `TK_BACKTICK`
**Node:** `TComputeNode` (extends `TEvaluationNode`)

Backticks mark a compute scope. The runtime reduces supported arithmetic and
comparison operations inside the scoped expression. Nested compute scopes are
not allowed.

```mantra
`[ + 1 2 3 ] : 3`
```

The content is first evaluated (repeat produces three copies of `[ + 1 2 3 ]`),
then each `+ 1 2 3` is reduced to `+ 6`, yielding `[ + 6 ] [ + 6 ] [ + 6 ]`.

## Fixed Scope `' ... '`

**Token:** `TK_APOSTROPHE`
**Node:** `TExpressionNode` with `TK_FIXED` meta flag

Apostrophes create a fixed scope. The enclosed tree is marked with the `TK_FIXED`
flag, which prevents the runtime from transforming or evaluating its contents.
Nested fixed scopes are not allowed.

```mantra
' [ 1 2 : 2 ] '
```

This outputs `( [ 1 2 : 2 ] )` -- the repeat operator is preserved as structure
rather than being evaluated. Fixed scopes are commonly used in selection patterns
to match literal tree structures without triggering rewrites.

Fixed scopes can be removed with the `\\` (unfix) meta flag inside an evaluation
scope:

```mantra
{ \\ ' [ 1 2 : 2 ] ' }
```

This unfixes the scope and allows the repeat to evaluate, producing
`( [ 1 2 1 2 ] )`.

## Transparent Grouping `<< ... >>`

**Token:** `TK_GROUP_BEGIN` / `TK_GROUP_END`
**Node:** None (parsed then deleted)

Transparent grouping is a parser-level construct. The `<< ... >>` delimiters are
accepted by the parser, the contents are parsed as an expression, and then the
grouping node itself is deleted. Only the inner expression remains in the tree.
This is useful for controlling parse precedence without leaving a scope node in
the AST.

```mantra
ih = << + m : + n >> => << + n : + m >>
```

The grouping ensures `+ m : + n` is parsed as a single unit, but the `<< >>`
delimiters do not appear in the resulting tree. Transparent grouping cannot be
empty and cannot be followed by an implicit sibling if the content is non-atomic.

## Practical Rule

When an example changes behavior after a small edit, check the delimiters before
checking the operator. A delimiter change can move an expression into or out of
an evaluated subtree, switching it between structural data and runtime behavior.

## Related Pages

- [List Containers](../list-containers.md) -- `[ ... ]` in the syntax section
- [Expressions](../expressions.md) -- `( ... )` in the syntax section
- [Evaluation Scopes](../evaluation-scopes.md) -- `{ ... }` in the syntax section
- [Compute Scopes](../compute-scopes.md) -- `` `...` `` in the syntax section
- [Scope Nodes](../../language-model/programs-as-trees/scope-nodes.md) -- node-level overview
