# Values, Nodes, and Expressions

Mantra source contains values, operators, and grouped expressions. The parser
turns those forms into nodes that the runtime can evaluate or transform.

This page covers what values exist, how the runtime represents them as nodes,
and how expressions organize values and operators into subtrees.

## Related Pages

- [Programs as Trees](programs-as-trees.md) — Tree-first programming model
- [Evaluation Model](evaluation-model.md) — Execute, evaluate, compute lifecycle
- [Values and Literals](../syntax/values-literals.md) — Literal syntax reference
- [Expressions](../syntax/expressions.md) — Expression grouping with parentheses
- [Tokens and Whitespace](../syntax/tokens-whitespace.md) — Token categories and parsing

---

## Values

A **value** is a leaf element in the source: a number, string, variable reference,
or identifier. The parser assigns each to a specific node type that determines
how the runtime treats it.

### Value Types

| Value | Source Example | Node Type |
|---|---|---|
| Integer | `42`, `-7`, `0` | `TIntegerNode` |
| Float | `3.14`, `-2.5`, `0.0` | `TFloatNode` |
| Complex | `1 + 2i` | `TComplexNode` |
| String | `"hello"` | `TStringNode` |
| Variable | `x`, `first_name` | `TVariableNode` |

### Integers

Whole numbers are parsed as `TIntegerNode`. They participate in arithmetic
reduction when they appear inside compute scope:

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

Without compute scope, integers remain as structural elements:

```mantra
+ 1 2 3
```

Output:

```text
+ 1 + 2 + 3
```

### Floats

Numbers containing a decimal point become `TFloatNode`. Float arithmetic follows
the same compute rules as integers:

```mantra
` * 1.5 2 `
```

Output:

```text
* 3
```

Mixed integer and float computation promotes to float:

```mantra
` + 1 2.5 `
```

Output:

```text
+ 3.5
```

### Complex Numbers

Complex literals (e.g., `1 + 2i`) are parsed as `TComplexNode`. They inherit
float arithmetic behavior and support complex promotion during mixed operations.

### Strings

String literals are enclosed in double quotes and become `TStringNode`. Strings
do not reduce under compute scope — they pass through unchanged:

```mantra
` + "hello" "world" `
```

The compute engine processes what it can and leaves unsupported forms as-is.

### Variables

A bare identifier is parsed as `TVariableNode`. When evaluated, the runtime
looks up the name in the variable trie and clones the stored tree at the use
site:

```mantra
x = [ 1 2 3 ]
x
```

Output:

```text
[ 1 2 3 ]
```

Variables can be predefined on the command line:

```bash
mantra --set x=5 --set rules='[ x => x + 1 ]' program.m
```

Variable resolution order:
1. **Exact scope frames** (innermost to outermost) — local scope bindings
2. **Namespace-qualified** — `CurrentNamespace.Name` in the variable trie
3. **Global fallback** — raw name in the variable trie

---

## Nodes

Every element in a Mantra program — values, operators, scopes, and keywords —
becomes a **node** in the abstract syntax tree. Users interact with nodes
through source forms and output formatting rather than implementation objects.

### Node Categories

The runtime organizes nodes into categories. Each category shares common behavior
and inherits from a base type.

**Scope nodes** group children into containers:

| Source Form | Node Type | Purpose |
|---|---|---|
| `( ... )` | `TExpressionNode` | Expression grouping |
| `[ ... ]` | `TArrayNode` | List / array container |
| `{ ... }` | `TEvaluationNode` | Evaluation scope |
| `` ` ... ` `` | `TComputeNode` | Compute scope |
| `' ... '` | `TFixedNode` | Fixed scope (no evaluation) |

**Value nodes** hold data:

- `TIntegerNode` — integer literals
- `TFloatNode` — floating-point literals
- `TComplexNode` — complex numbers
- `TStringNode` — string literals
- `TVariableNode` — variable references

**Operator nodes** define relationships between values and subtrees:

| Operator | Node Type | Purpose |
|---|---|---|
| `:` | `TRepeatNode` | Repeat / expansion |
| `?` | `TSelectionNode` | Selection rewrite |
| `=>` | `TTransformNode` | Transform rule |
| `..` | `TRangeNode` | Range |
| `...` | `TRecurseNode` | Recurse / fixpoint |
| `&` | `TConcatenateNode` | Concatenation |
| `\|=` | `TInferenceNode` | Inference / proof query |
| `=` | `TAssignmentNode` | Variable assignment |
| `:=` | `TDeepAssignmentNode` | Deep assignment |
| `--` | `TMatchAnyNode` | Match any (pattern) |

**Keyword nodes** declare language constructs:

- `TPackageNode`, `TImportNode`, `TIncludeNode` — module system
- `TCallableNode` — callable dispatch
- `TSelectionPolicyNode` — selection policy wrapper (`selector`)
- `TGlobalNode` — global scope access
- `TScopeFrameNode` — local scope (`scope`)
- `TAliasNode` — callable alias

### Tree Structure

Nodes form a tree using **left-child / right-sibling** representation:

- **LHS** (left edge) — points to the first child node
- **RHS** (right edge) — points to the next sibling node

This means every node has only two links. A node with multiple children links
the first child via LHS, and that child chains to its siblings via RHS.

```
    Statement
    /
  [     →    +     →     1     →     2     →     3
  /
 +     →     1
```

The source `[ + 1 2 3 ]` becomes a tree where `[` is the root, `+`, `1`, `2`,
`3` are siblings linked through RHS, and `+` itself may have children (its
operands) linked through LHS.

### Runtime Representation

Nodes are **not heap-allocated objects**. The implementation keeps a compact
32-byte record per node (`TTreeNode`) in a pooled array. Behavior is dispatched
through a VMT table keyed by node ID — `GetNode(index, prevIndex)` creates a
lightweight stack wrapper with the correct virtual method table pointer.

This design means:
- Nodes are cache-friendly and allocation-efficient
- The tree uses a free-list for recycling (`AllocateNode` / `DisposeNode`)
- No per-node heap allocation overhead during parsing or evaluation

### Node Lifecycle

Every node goes through these phases:

1. **Parse** — tokenizer produces tokens, parser creates nodes and wires edges
2. **Execute** — recursive traversal evaluates children in order
3. **Evaluate** — resolves variables, processes scopes, applies transforms
4. **Compute** — reduces arithmetic/comparison operations (when triggered)
5. **Complete** — cleanup (clear rewrite state, collapse evaluation scopes)

During evaluation, nodes can be **expanded** (replaced by their LHS child in the
parent context), **deleted**, or **cloned**. These are the primary mutation
primitives.

### EOT Sentinel

The constant `EOT` (End Of Tree, value `MaxInt`) marks "no link." When a node's
LHS or RHS is `EOT`, it has no child or no sibling respectively.

---

## Expressions

An **expression** groups values and operators into a single subtree. Parentheses
create expression scope:

```mantra
( + 1 2 )
```

Expressions do not automatically evaluate their contents. They are structural
containers. Compare the four scope delimiters:

```mantra
( + 1 2 )       -- expression: no change
{ + 1 2 }       -- evaluation scope: collapses wrapper
` + 1 2 `       -- compute scope: reduces to + 3
[ + 1 2 ]       -- list container: preserves structure
```

See [Expressions](../syntax/expressions.md) for full expression syntax.

### Expression Nesting

Expressions can nest inside each other and inside other scope types:

```mantra
( ( 1 2 ) ( 3 4 ) )         -- nested expressions
( [ 1 2 ] [ 3 4 ] )         -- lists inside expression
( ` + 1 2 ` )               -- compute scope inside expression
```

Compute scopes reduce even when nested inside expressions. Evaluation scopes
collapse their wrapper, leaving contents as children of the expression.

### Expressions vs Lists

Both parentheses and square brackets group values. The difference is semantic:

- `( ... )` — expression grouping; communicates expression structure
- `[ ... ]` — list container; communicates data structure

They are interchangeable in some contexts but carry different intent. See
[List Containers](../syntax/list-containers.md) for details.

### Expressions in Patterns

Expressions participate in structural pattern matching through the `?` operator:

```mantra
( ( a b ) ( c d ) ) ? ( ( x y ) => ( z x y ) )
```

Output:

```text
( ( z a b ) ( c d ) )
```

The pattern `( x y )` matches the first child expression `( a b )`, capturing
`x = a` and `y = b`. The rewrite produces `( z a b )` in its place.

### Expressions and Repeat

Expressions can be repeated using the `:` operator. The entire expression content
is cloned:

```mantra
( a b ) : 3
```

Output:

```text
( a b ) ( a b ) ( a b )
```

---

## Summary

- **Values** are the leaves: integers, floats, strings, variables, identifiers
- **Nodes** are the runtime representation: every source form becomes a node with
  a type, value, and tree edges
- **Expressions** group values and operators into subtrees using parentheses
- The tree uses **left-child / right-sibling** edges (LHS/RHS)
- Nodes are **compact pooled records**, not heap objects — dispatch uses a VMT
  table for virtual behavior
