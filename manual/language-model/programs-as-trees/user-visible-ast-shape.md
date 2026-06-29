# User-Visible AST Shape

The abstract syntax tree (AST) is an internal data structure, but users see its
shape through every output format Mantra produces. This page documents how the
tree structure manifests in runtime output and what that means for writing and
reading programs.

## What Is "User-Visible"?

Mantra never prints raw internal AST node addresses or memory offsets. Instead,
three formatters present the tree in different levels of detail:

| Formatter | Invocation | Shows |
|---|---|---|
| Default (`TFormatter`) | implicit output, `print` | Structured source-like text — what the tree evaluates to |
| Tree (`TTreeFormatter`) | `tree_out` | Full tree hierarchy with indentation and branch/sibling connectors |
| IR (`TIRFormatter`) | `ir_out` | Low-level node details: index, parent, depth, token, edges, flags |

Users interact with the default formatter most often. The tree and IR formatters
exist for debugging and introspection — they make the AST structure explicit.

## Source Structure Maps to Output Structure

The fundamental rule: **every source form becomes a node in the tree, and every
node becomes something in the output.**

```mantra
[ + 1 2 3 ]
```

Output:

```text
[ + 1 + 2 + 3 ]
```

The brackets delimit a list container (one node). The `+` operators and integers
are its children (siblings linked through RHS). Each element appears in the
output because each element is a node in the tree.

Nested structures produce nested output:

```mantra
{ [ 1 2 ] : 3 }
```

Output:

```text
[ 1 2 ] [ 1 2 ] [ 1 2 ]
```

The evaluation scope `{ ... }` wraps the repeat expression. The repeat (`: 3`)
clones the list `[ 1 2 ]` three times. The evaluation scope then collapses
(removes its wrapper), leaving the three cloned lists as output.

## Operator Placement in the Tree

Operators attach to specific nodes in the tree — not to arbitrary text ranges.
The parser builds the tree left-to-right, and each operator node captures its
operands through LHS (first child) and RHS (sibling chain) links.

```mantra
+ 1 2 3
```

Without compute scope, this produces:

```text
+ 1 + 2 + 3
```

The formatter walks the tree: `+` node with siblings `1`, `2`, `3`. The
formatter outputs the operator before each RHS sibling. This is the default
behavior — the operator "belongs to" its children and appears before them.

With compute scope, the tree is reduced before output:

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

The compute engine traverses the subtree, performs arithmetic, and replaces the
children with the result. The output tree now has `+` with a single child `6`.

## Scope Delimiters and Their Output

Each scope delimiter creates a different node type with different formatting
behavior:

| Delimiter | Node Type | Output Behavior |
|---|---|---|
| `( ... )` | `TExpressionNode` | Parentheses appear in output; contents pass through unchanged |
| `[ ... ]` | `TArrayNode` | Brackets appear in output; children are space-separated |
| `{ ... }` | `TEvaluationNode` | Braces collapse after evaluation; contents replace the scope |
| `` `...` `` | `TComputeNode` | Backticks collapse after compute; contents replace the scope |
| `' ... '` | `TFixedNode` | Apostrophes suppress evaluation; contents preserved literally |

**Evaluation scope** is unique — it removes itself from the output:

```mantra
{ + 1 2 }
```

Output:

```text
+ 1 + 2
```

The `{ }` wrapper evaluated its contents, then collapsed. The resulting nodes
are placed where the scope was in the parent tree.

**Expression scope** preserves its wrapper:

```mantra
( + 1 2 )
```

Output:

```text
( + 1 + 2 )
```

The parentheses remain because expressions are structural containers, not
evaluation triggers.

## Nested Scope Interaction

The output shape changes dramatically depending on nesting:

```mantra
[ { 1 2 3 : 4 } ]
```

The brackets hold one evaluation scope. Inside, `1 2 3 : 4` repeats `1 2 3`
four times. The evaluation scope collapses. Output:

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
clones it three times. The outer compute scope collapses, leaving three cloned
lists.

With evaluation scope instead:

```mantra
{ [ + 1 2 3 ] : 3 }
```

Output:

```text
[ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ]
```

The evaluation scope clones the list three times but does not compute. The list
contents remain unevaluated — `+ 1 + 2 + 3` instead of `+ 6`.

## Variable Substitution Preserves Tree Shape

When a variable is used, the runtime clones its stored tree at the use site.
The cloned tree participates in evaluation normally:

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
replaced by the cloned tree inside compute scope, which then reduces to `[ + 6 ]`.

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

## Tree Output: Seeing the Full Structure

The `tree_out` command renders the complete AST hierarchy with branch and
sibling connectors:

```mantra
tree_out [ 1 2 3 ]
```

Output (structure):

```
├── [
│   ├── 1
│   ├── 2
│   └── 3
```

This formatter traverses the tree recursively: LHS (first child) descends one
level, RHS (next sibling) stays at the same level. The connectors (`├──`,
`└──`) show which nodes are children versus siblings.

## IR Output: Low-Level Node Details

The `ir_out` command shows each node with its internal fields:

```mantra
ir_out [ 1 2 ]
```

Output includes node index, parent index, depth, node ID, token text, operator
flags, edge pointers (LHS/RHS), and the expression token reference. This
formatter is useful for debugging tree construction — it maps the abstract tree
back to the actual node pool.

## Raw Output: Node Values Without Formatting

With the `--raw` flag, `print` bypasses the formatter entirely and outputs
each node's raw `TreeValue` string. This strips the columnar formatting,
spacing, and delimiters the default formatter adds:

```mantra
print "hello"
```

- Normal output: `"hello" `
- With `--raw`: `hello`

The `--raw` flag only affects `print` (`OBJ_OUTPUT`). `tree_out` and `ir_out`
always use their formatters regardless of `--raw`.

## Formatting Affects Perceived Structure

The default formatter makes some design choices that influence how users
perceive tree structure:

- **Column spacing** — the formatter adds spaces between elements and may
  right-align columns for multi-column output.
- **Operator placement** — operators appear before each RHS sibling in the
  chain, not once per group.
- **Scope collapsing** — evaluation and compute scopes remove their delimiters
  from output, which can make it unclear where a scope boundary was.
- **Newline handling** — arrays with many elements may wrap to newlines,
  preserving the container delimiter across lines.

These formatting choices are conventions, not language semantics. The underlying
tree structure is the same regardless of formatting.

## Practical Guidelines

### When Documenting Behavior

Show enough source structure for readers to see which subtree an operator acts
on. If you write `x ? [ a => b ]`, the reader should be able to trace which
node is the subject (`x`) and which is the rule set (`[ a => b ]`).

### When Debugging Unexpected Output

If the output shape surprises you:

1. **Check scope boundaries** — `{ }` and `` ` ` ` collapse; `( )` and
   `[ ]` do not. The wrong delimiter can remove or preserve structure.
2. **Use `tree_out`** — render the full tree to verify parent-child
   relationships.
3. **Use `ir_out`** — inspect node IDs, edges, and flags when the tree
   structure itself seems wrong.
4. **Use `--raw`** — strip formatting to see raw node values.

### When Writing Examples

Nested forms are not just grouping syntax — they determine where evaluation or
transformation applies. Prefer examples where the nesting is intentional and
observable in the output.

## Related Pages

- [Programs as Trees](programs-as-trees.md) — Tree-first programming model
- [Values, Nodes, and Expressions](../values-nodes-expressions.md) — Node
  types and the tree structure
- [Scope Nodes](scope-nodes.md) — Delimiter types and their semantics
- [Evaluation Model](../evaluation-model.md) — How evaluation transforms trees
- [Rendering Structured Output](../../data/rendering-structured-output.md) —
  Formatters, `print`, `tree_out`, `ir_out`, and CLI output flags
