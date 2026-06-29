# Programs as Trees

Mantra source is parsed into a tree. Every value, operator, scope delimiter,
and keyword becomes a **node** in that tree. Containers, expressions, scopes,
and operators are not text constructs — they are related nodes connected by
parent-child and sibling edges.

This page explains the tree-first model: how your source code maps to tree
structure, how the runtime operates on trees, and what that means for writing
and reading Mantra programs.

## The Core Idea

In most languages, source code is a linear sequence of statements executed in
order. In Mantra, source code is a **tree** that the runtime traverses,
evaluates, and rewrites. The tree is not an implementation detail hidden from
you — it is the primary mental model for understanding program behavior.

```
Source:  [ + 1 2 3 ]

Tree:
  [ (root)
  ├── + (first child via LHS)
  │   └── 1 (first child of +)
  ├── 2 (sibling of + via RHS)
  ├── 3 (sibling of 2 via RHS)
```

The brackets create a root node. Inside, `+`, `1`, `2`, `3` are siblings linked
through the right edge. The `+` operator itself captures its first operand
through the left edge. Every element you write becomes a node with position and
relationships in this structure.

**Key insight:** operations in Mantra do not work on text or linear statements —
they work on tree nodes and their relationships. Evaluation, repeat, selection,
transform, and compute all operate by traversing and mutating tree structure.

## Why Trees Matter

Tree structure is visible and consequential in Mantra's core operations:

- **Evaluation** acts on scoped subtrees — `{ ... }` evaluates descendants,
  then collapses by replacing itself with its first child.
- **Repeat** expands by cloning subtrees — `[ 1 2 ] : 3` clones the list
  `[ 1 2 ]` three times as sibling nodes.
- **Compute scope** reduces supported subtrees — `` ` + 1 2 3 ` `` replaces
  children with an accumulated result.
- **Selection rewrites** match tree patterns and replace subtrees —
  `[ a b ] ? [ x => x + 1 ]` matches node-by-node, not character-by-character.
- **Formatting** renders the resulting tree structure — the output shape
  reflects the tree, not the original source text.
- **Variable substitution** clones stored trees — `x = [ 1 2 3 ]` stores a
  tree; using `x` clones that tree at the use site.

## Left-Child / Right-Sibling Representation

The tree uses only **two edges** per node:

| Edge | Meaning |
|---|---|
| **LHS** (left edge) | Points to the first child node |
| **RHS** (right edge) | Points to the next sibling node |

There are no parent pointers and no "next child" links. A node with multiple
children links the first child via LHS, and that child chains to its siblings
via RHS. The sentinel `EOT` (End Of Tree) marks "no child" or "no sibling."

This representation has practical consequences:

- **Children are ordered** — the LHS child always comes first, followed by
  siblings through RHS. Tree traversal reads left-to-right.
- **Siblings are peers** — all siblings at the same depth are linked through
  RHS. There is no special "last" or "first" beyond the LHS distinction.
- **No parent navigation** — nodes cannot walk upward. Operations that need
  parent context pass it explicitly through traversal functions.

```
Source:  [ 1 2 3 ]

Tree structure:
  [ ──LHS──> 1 ──RHS──> 2 ──RHS──> 3 ──RHS──> EOT
```

## Source Forms Map to Node Types

Every source form the parser encounters maps to a specific node type. The node
type determines how the runtime processes that element:

**Scope delimiters create container nodes:**

| Form | Node Type | Role |
|---|---|---|
| `( ... )` | `TExpressionNode` | Expression grouping |
| `[ ... ]` | `TArrayNode` | List / array container |
| `{ ... }` | `TEvaluationNode` | Evaluation scope (collapses after) |
| `` ` ... ` `` | `TComputeNode` | Compute scope (arithmetic reduction) |
| `' ... '` | `TFixedNode` | Fixed scope (blocks evaluation) |

**Values become leaf nodes:**

| Form | Node Type |
|---|---|
| `42`, `-7` | `TIntegerNode` |
| `3.14`, `-2.5` | `TFloatNode` |
| `1 + 2i` | `TComplexNode` |
| `"hello"` | `TStringNode` |
| `x`, `name` | `TVariableNode` |

**Operators become relationship nodes:**

| Form | Node Type | Captures |
|---|---|---|
| `:` | `TRepeatNode` | LHS = source, RHS = count/pattern |
| `?` | `TSelectionNode` | LHS = subject, RHS = rules |
| `=>` | `TTransformNode` | LHS = pattern, RHS = replacement |
| `..` | `TRangeNode` | LHS = start, RHS = end |
| `...` | `TRecurseNode` | Recursion / fixpoint trigger |
| `&` | `TConcatenateNode` | LHS + RHS = concatenated result |
| `=` | `TAssignmentNode` | LHS = name, RHS = value |

See [Values, Nodes, and Expressions](values-nodes-expressions.md) for the
complete node catalog and [Scope Nodes](programs-as-trees/scope-nodes.md)
for detailed scope behavior.

## Tree Mutation

Evaluation is destructive. Nodes are expanded, deleted, and replaced in-place
during execution. The primary mutation operations are:

### Expand

Replaces a node with its LHS child in the parent context. Used by evaluation
scopes (`{ ... }`) and compute scopes (`` ` ... ` ``) to "collapse" — the
scope node disappears and its contents take its place in the tree.

```mantra
{ [ 1 2 ] }
```

The `{ }` evaluates, then expands: the evaluation scope node is replaced by its
first child (`[ 1 2 ]`). Output:

```text
[ 1 2 ]
```

### Clone

Creates a deep copy of a subtree. Used by repeat (`` : ``) and variable
substitution.

```mantra
[ 1 2 ] : 3
```

The repeat clones `[ 1 2 ]` three times, linking clones as siblings. Output:

```text
[ 1 2 ] [ 1 2 ] [ 1 2 ]
```

### Delete

Removes nodes from the tree. Used during compute reduction (consumed siblings
are deleted) and cleanup.

```mantra
` + 1 2 3 `
```

The compute engine replaces `1`, `2`, `3` with the result `6`, deleting the
consumed siblings. Output:

```text
+ 6
```

## Operator Placement in the Tree

Operators are not free-floating tokens — they attach to specific nodes. The
parser builds the tree left-to-right, and each operator node captures its
operands through LHS (first child) and RHS (sibling chain) links.

```mantra
+ 1 2 3
```

Without compute scope, the tree has `+` as a node with siblings `1`, `2`, `3`.
The formatter walks this tree and produces:

```text
+ 1 + 2 + 3
```

The operator appears before each RHS sibling because the formatter outputs the
operator as it encounters each sibling in the chain. This is the default
behavior — the operator "belongs to" its children structurally.

With compute scope, the tree is reduced before output:

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

The compute engine replaces the children with a single accumulated value. The
output tree now has `+` with one child: `6`.

## Nested Structure and Output Shape

Nested forms are not just grouping syntax — they determine where evaluation or
transformation applies. The output shape changes based on nesting:

```mantra
[ { 1 2 3 : 4 } ]
```

Brackets hold one evaluation scope. Inside, `1 2 3 : 4` repeats `1 2 3` four
times. The evaluation scope collapses. Output:

```text
[ 1 2 3 1 2 3 1 2 3 1 2 3 ]
```

Compare with compute scope wrapping the repeat:

```mantra
`[ + 1 2 3 ] : 3`
```

Output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The compute scope first reduces `[ + 1 2 3 ]` to `[ + 6 ]`, then the repeat
clones it three times. The outer compute scope collapses.

With evaluation scope instead:

```mantra
{ [ + 1 2 3 ] : 3 }
```

Output:

```text
[ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ]
```

The evaluation scope clones the list three times but does not compute — the
list contents remain as `+ 1 + 2 + 3` rather than being reduced to `+ 6`.

## Variable Substitution Preserves Tree Shape

Variables store trees, not values. When a variable is used, the runtime clones
its stored tree at the use site:

```mantra
x = [ + 1 2 3 ]
`x`
```

Output:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The assignment stores the tree `[ + 1 2 3 ]`. On the second line, `x` is
replaced by the cloned tree inside compute scope, which then reduces to
`[ + 6 ]`.

With evaluation scope instead:

```mantra
x = [ + 1 2 3 ]
{ x }
```

Output:

```text
x = [ + 1 + 2 + 3 ]
[ + 1 + 2 + 3 ]
```

The variable expands to the tree, but evaluation scope alone does not compute.

## Tree Traversal During Evaluation

The runtime traverses trees in a fixed order during the dispatch lifecycle:

1. **Execute** — recursive traversal evaluates children in order
2. **Evaluate** — resolves variables, processes scopes, applies transforms
3. **Compute** — reduces arithmetic operations (when triggered by `` ` `` or `~`)
4. **Expand** — collapses evaluation scopes, applies tree expansions
5. **Complete** — cleanup (clear rewrite state, finalize evaluation)

Each phase may mutate the tree. The left-child / right-sibling structure means
traversal descends via LHS and moves across siblings via RHS. There is no
random access — operations follow the tree's linked structure.

## Seeing the Tree: Formatters

Mantra provides three ways to visualize tree structure:

| Formatter | Invocation | Shows |
|---|---|---|
| Default | implicit output, `print` | Structured source-like text |
| Tree | `tree_out` | Full hierarchy with indentation |
| IR | `ir_out` | Node IDs, edges, flags, depth |

The default formatter is what users see most often. The tree and IR formatters
make the AST explicit and are useful for debugging unexpected behavior.

```mantra
tree_out [ 1 2 3 ]
```

This renders the complete AST hierarchy with branch and sibling connectors,
showing which nodes are children (via LHS) versus siblings (via RHS).

See [User-Visible AST Shape](programs-as-trees/user-visible-ast-shape.md) for
detailed formatter behavior and debugging techniques.

## Practical Guidelines

### Think in Trees, Not Text

When writing Mantra, ask "what tree structure does this source produce?" rather
than "what text does this output?" The tree structure determines evaluation
order, scope boundaries, and which operations apply to which subtrees.

### Scope Delimiters Are Not Interchangeable

Swapping one delimiter for another changes behavior:

- `( ... )` groups without evaluating
- `[ ... ]` creates a data container
- `{ ... }` evaluates and collapses
- `` ` ... ` `` evaluates, computes, and collapses
- `' ... '` blocks all processing

Choosing the wrong delimiter is the most common source of unexpected behavior.

### Nesting Controls Scope

Nested forms determine where evaluation or transformation applies. Prefer
examples and code where nesting is intentional and observable in the output.

### Debug with Tree Tools

When output surprises you:

1. **Check scope boundaries** — `{ }` and `` ` ` ` collapse; `( )` and
   `[ ]` do not. The wrong delimiter can remove or preserve structure.
2. **Use `tree_out`** — render the full tree to verify parent-child
   relationships.
3. **Use `ir_out`** — inspect node IDs, edges, and flags when the tree
   structure itself seems wrong.
4. **Use `--raw`** — strip formatting to see raw node values.

## Related Pages

- [Values, Nodes, and Expressions](values-nodes-expressions.md) — Node types,
  tree structure, and the runtime dispatch model
- [Scope Nodes](programs-as-trees/scope-nodes.md) — Scope delimiters, class
  hierarchy, and evaluation semantics for each scope type
- [User-Visible AST Shape](programs-as-trees/user-visible-ast-shape.md) — How
  tree structure manifests in output: formatters, `tree_out`, `ir_out`,
  operator placement, and debugging
- [Evaluation Model](evaluation-model.md) — Execute, evaluate, compute
  lifecycle and how evaluation transforms trees
- [Rewriting and Transformation Model](rewriting-transformation-model.md) —
  Selection, transform, and inference operators as tree rewrites
