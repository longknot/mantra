# Syntax

Every Mantra program starts as text. The tokenizer converts source into a stream
of tokens, and the parser converts those tokens into an abstract syntax tree (AST).
The tree is the primary data structure -- rewriting, evaluation, and computation
all operate on tree nodes.

This section describes the language forms the parser recognizes: scope delimiters,
operators, meta flags, keywords, literals, and the rules of the tokenizer itself.

## From Source to Tree

A Mantra program passes through two stages before execution:

```
Source Text
    |
    v
Tokenizer  --  state machine; emits token stream (TTokenInfo records)
    |
    v
Parser     --  consumes tokens; builds AST (TTreeNode pool)
    |
    v
Evaluation  --  walk tree, dispatch node behaviors
```

The tokenizer is a **deterministic state machine** with longest-match backtracking.
Multi-character operators like `<==>` are recognized correctly even when shorter
prefixes (e.g., `<=`) also exist. The tokenizer is case-insensitive by default,
so `x`, `X`, and `MyVar` all match identifier transitions.

Whitespace and comments are filtered by the tokenizer's ignore mask and never
reach the parser.

The parser consumes the token stream sequentially, building a node pool using the
standard **left-child / right-sibling** tree representation. Every node in the
AST is a 32-byte `TTreeNode` record linked by `LHS` (first child) and `RHS`
(next sibling) edges.

## Scope Delimiters at a Glance

Scope delimiters are the primary structural elements in Mantra. They define
boundaries for evaluation, computation, and data containment:

```mantra
[ 1 2 3 ]         -- list container
( + 1 2 )         -- expression grouping
{ x = 42 }        -- evaluation scope
` + 1 2 `         -- compute scope
' + 1 2 '         -- fixed scope (no evaluation)
```

| Delimiter | Node Type | Evaluates | Computes | Transforms |
|---|---|---|---|---|
| `[ ... ]` | `TArrayNode` | Contextual | No | Contextual |
| `( ... )` | `TExpressionNode` | Contextual | No | Contextual |
| `{ ... }` | `TEvaluationNode` | Yes | No | Yes |
| `` ` ... ` `` | `TComputeNode` | Yes | Yes | No |
| `' ... '` | `TFixedNode` | No | No | No |

For the full behavior of each scope type, see the linked sub-pages.

## How Syntax Forms Interact

Syntax elements combine to create expressive programs. A single expression can
use multiple delimiters, operators, and meta flags:

```mantra
[ { ~ + 1 2 3 } ? [ x => x * 2 ] ] : 3
```

This example uses:
- `[ ... ]` -- list container wrapping everything
- `{ ... }` -- evaluation scope for the selection
- `~` -- meta-compute flag reducing `+ 1 2 3` to `+ 6`
- `?` -- selection rewrite applying `[ x => x * 2 ]`
- `: 3` -- repeat operator cloning the result 3 times

For detailed semantics of each form, see the linked chapters:
[Evaluation](../evaluation/index.md), [Transformations](../transformations/index.md),
and [Compute](../compute/index.md).

## Topics

### Tokenization

- [Tokens and Whitespace](tokens-whitespace.md) -- Token data structure, state
  machine tokenizer, whitespace handling, ignore mask, source location tracking,
  and token categories
- [Delimiters and Scope Tokens](tokens-whitespace/delimiters-scope-tokens.md) --
  Token IDs for `()`, `[]`, `{}`, `` ` ``, `'`
- [Operator Tokens](tokens-whitespace/operator-tokens.md) -- Token IDs for
  arithmetic, relational, boolean, and special operators

### Scope Forms

- [List Containers](list-containers.md) -- Square brackets: nesting, indexing
  with `@`, repeat expansion, and list operations
- [Expressions](expressions.md) -- Parentheses: grouping, nesting, selection,
  and distinction from lists
- [Evaluation Scopes](evaluation-scopes.md) -- Curly braces: variable
  substitution, selection, repeat, and scope collapse
- [Compute Scopes](compute-scopes.md) -- Backticks: arithmetic reduction,
  supported operations, and the evaluate-then-compute pipeline
- [Fixed Scopes](fixed-scopes.md) -- Single quotes: literal tree protection,
  pattern templates, and comparison with evaluation scopes

### Meta Flags

- [Meta Flags](meta-flags.md) -- `~` (compute), `\` (fixed), `$` (state-selection),
  `^` (full-match), `.` (matching rule), `@` (at-index): all with examples

### Operators and Special Forms

- [Operators and Special Forms](operators-special-forms.md) -- `:`, `?`, `=>`,
  `:=`, `..`, `...`, `--`, `&`, `|=`, and more: full operator reference with
  AST node types and examples

### Keywords and Declarations

- [Keywords and Declarations](keywords-declarations.md) -- `rule`, `define`,
  `selector`, `callable`, `alias`, `print`, `exec`, `package`, `import`,
  `include`, `explode`, `implode`

### Values and Literals

- [Values and Literals](values-literals.md) -- Integers, floats, strings,
  booleans, complex numbers, and variables: parsing rules and node types
