# Scope Nodes

Scope nodes are the structural containers in Mantra. Each delimiter creates a
different node type with distinct evaluation semantics. The five scope forms
are **not interchangeable** -- swapping one delimiter for another changes how
the runtime processes the contained subtree.

## Overview

| Syntax | Node Type | Token | Behavior |
|---|---|---|---|
| `( ... )` | `TExpressionNode` | `TK_PARENTHESIS` | Expression grouping -- preserves contents as-is |
| `[ ... ]` | `TArrayNode` | `TK_BRACKET` | Array/list container -- structural data grouping |
| `{ ... }` | `TEvaluationNode` | `TK_CURLY` | Evaluation scope -- triggers descendant evaluation |
| `` ` ... ` `` | `TComputeNode` | `TK_BACKTICK` | Compute scope -- arithmetic reduction |
| `' ... '` | `TFixedNode` | `TK_APOSTROPHE` | Fixed scope -- prevents evaluation and transforms |

## Class Hierarchy

```
TBaseNode
  └── TScopeNode                    -- base for all scope containers
        ├── TExpressionNode          -- ( ... )
        ├── TArrayNode               -- [ ... ]
        └── TEvaluationNode          -- { ... }
              └── TComputeNode       -- ` ... `

TIdentifierNode                     -- (separate branch)
  └── TFixedNode                    -- ' ... '
```

`TComputeNode` inherits from `TEvaluationNode`, so compute scopes also trigger
evaluation before performing arithmetic reduction. `TFixedNode` lives on a
separate branch from `TIdentifierNode` -- it is not technically a scope container
in the same inheritance sense, but it functions as a quoting mechanism that
prevents evaluation.

## Expression Scope `( ... )`

**Node class:** `TExpressionNode`

Parentheses create a grouping container that preserves its contents without
automatic evaluation or computation. Expression nodes inherit the default
`TScopeNode` behavior -- they execute children but do not trigger special
processing.

```mantra
( + 1 2 )        -- preserved as + 1 2 (no evaluation)
( a b c )        -- grouping of symbols
( )              -- empty expression
```

Expressions are the neutral container. Use them when you need structural grouping
without triggering evaluation, computation, or data container semantics.

### Key Properties

- Does **not** automatically evaluate descendants.
- Does **not** collapse or expand during evaluation.
- Children are processed in the normal execution flow (Execute -> Evaluate).
- Can nest inside any other scope type.

## Array Scope `[ ... ]`

**Node class:** `TArrayNode`

Brackets create array/list containers. Unlike expression scopes, arrays have
their own `Execute` behavior and serve as structural data containers.

```mantra
[ 1 2 3 ]        -- list of values
[ + 1 2 3 ]      -- operator with operands in a container
[ ]              -- empty array
```

### Key Properties

- Has custom `Execute` logic (distinct from the default `TScopeNode` behavior).
- Preserves the tree structure of its contents.
- Drives repeat operations when used as repeat targets.
- The canonical data container in Mantra.

## Evaluation Scope `{ ... }`

**Node class:** `TEvaluationNode`

Curly braces create evaluation scopes. When executed, they increment the
evaluation depth counter, evaluate all descendants, and then collapse by
replacing themselves with their first child (via `Expand`).

```mantra
{ + 1 2 }        -- evaluates contents, collapses wrapper
{ ~ + 1 2 }      -- with ~ flag: triggers compute on + node
{ [ 1 2 3 ] }    -- evaluates array contents, collapses braces
```

### Execution Flow

1. Increments `EvaluationExecutionDepth` (tracks nested evaluation).
2. Calls `Evaluate(Context)` -- processes descendants and runs `DoEvaluate`.
3. After evaluation completes, the scope node **collapses** -- it is replaced
   by its LHS child in the parent's link structure.
4. Decrements `EvaluationExecutionDepth` in the cleanup phase.

### Collapse Behavior

The `Expand` operation replaces the evaluation scope node with its first child.
This means `{ expr }` produces the same result as `expr` -- the braces exist
only to trigger the evaluation phase. The collapse is destructive: the scope
node itself is removed from the tree.

### Evaluation Depth

The `EvaluationExecutionDepth` counter tracks how deeply evaluation scopes are
nested. Other parts of the runtime (e.g., selection rules, inference engines)
check this counter to determine whether they should trigger additional
processing.

## Compute Scope `` ` ... ` ``

**Node class:** `TComputeNode` (inherits from `TEvaluationNode`)

Backtick scopes trigger arithmetic reduction. They first inherit the evaluation
behavior from `TEvaluationNode`, then explicitly invoke `Compute` on their
children, and finally collapse via `Expand`.

```mantra
` + 1 2 `          -- reduces to + 3
` + 1 2 3 `        -- reduces to + 6
`[ + 1 2 3 ] : 3`  -- compute inside repeat: [ + 6 ] [ + 6 ] [ + 6 ]
```

### Execution Flow

1. Calls `inherited Evaluate(Context)` -- runs the parent `TEvaluationNode`
   evaluation logic.
2. Invokes `Node[LHS].Compute(Context)` on the first child -- this triggers
   arithmetic reduction across the child subtree.
3. Calls `GlobalTree.Expand(PrevIndex, Index)` -- collapses the backtick scope
   just like `{ ... }`.

### What Compute Does

The `Compute` phase traverses siblings and reduces foldable operators
(arithmetic `+ - * /`, comparisons, boolean operations) into single accumulated
values. It processes left-to-right, deleting consumed siblings from the tree.

```mantra
{ ~ + 1 ( 2 ) }    -- output: + 3
```

Here, the `~` flag on `+` triggers compute. The `+` node absorbs `1` and
`( 2 )`, reducing them to `+ 3`.

### Compute with Repeat

Compute scopes interact with repeat operations. When a compute scope wraps a
repeat expression, each repetition is computed independently:

```mantra
`[ + 1 2 3 ] : 3`
-- output: [ + 6 ] [ + 6 ] [ + 6 ]
```

## Fixed Scope `' ... '`

**Node class:** `TFixedNode` (inherits from `TIdentifierNode`)

Apostrophe-quoted scopes prevent evaluation and transformation. They quote their
contents, protecting them from the normal evaluation and rewrite pipeline.

```mantra
' [ 1 2 : 2 ] '    -- output: ( [ 1 2 : 2 ] )
```

The `: 2` repeat inside the fixed scope does **not** execute -- the contents
are preserved as literal tree structure.

### Key Properties

- Inherits from `TIdentifierNode`, not from `TScopeNode`.
- Sets the fixed flag on contained nodes, preventing transformation rules from
  matching them.
- Blocks both evaluation and structural rewrites.
- The contents are output as-is, wrapped in expression parentheses by the
  formatter.

### Fixed vs. Other Scopes

| Scope | Evaluates? | Computes? | Transforms? |
|---|---|---|---|
| `( ... )` | No | No | Yes |
| `[ ... ]` | No | No | Yes |
| `{ ... }` | Yes | No | Yes |
| `` ` ... ` `` | Yes | Yes | Yes (before compute) |
| `' ... '` | No | No | No |

Only the fixed scope completely blocks all processing. Parentheses and brackets
preserve structure but still allow transforms. Evaluation and compute scopes
actively process their contents.

## Scope Comparison

This table summarizes the behavior differences:

| Aspect | `( )` | `[ ]` | `{ }` | `` ` ` `` | `' '` |
|---|---|---|---|---|---|
| Collapses after eval | No | No | Yes | Yes | N/A |
| Triggers Evaluate | No | No | Yes | Yes | No |
| Triggers Compute | No | No | No | Yes | No |
| Blocks transforms | No | No | No | No | Yes |
| Inherits from | TScopeNode | TScopeNode | TScopeNode | TEvaluationNode | TIdentifierNode |

## Nesting Rules

Scopes can be nested in any combination. The innermost scope's behavior
determines how its immediate children are processed:

```mantra
{ ( + 1 2 ) }      -- evaluates, but + 1 2 is in () so no compute without ~
{ ` + 1 2 ` }      -- outer {} evaluates; inner ` ` computes to + 3
' { + 1 2 } '      -- fixed scope blocks everything; { } never evaluates
[ ` + 1 2 ` ]      -- array contains computed result
```

## Scope Frame Node

There is also a `TScopeFrameNode` (`scope_frame` keyword) used internally for
local scope management. It creates labeled scope frames that manage variable
lifetimes and cleanup. See the [Local Scopes](local-scopes.md) documentation
for details.
