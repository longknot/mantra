# Examples

This page collects compact, runnable examples that introduce Mantra's core
concepts — expressions, scopes, operators, pattern matching, and computation.
All examples correspond to real test fixtures in `tests/cases/` unless otherwise
noted.

For deeper coverage, see the dedicated example pages:

- **[Compute Examples](examples/compute-examples.md)** — arithmetic, boolean,
  unary ops, repeat with compute, variable lookup
- **[Transform Examples](examples/transform-examples.md)** — selection rewrites,
  match-any, guards, equivalence, inline transforms
- **[Rule Examples](examples/rule-examples.md)** — pattern matching, named rules,
  iterative selection, bidirectional transforms, inference
- **[Data Examples](examples/data-examples.md)** — JSON/YAML loading, path access,
  query helpers, display output

---

## Expressions and Values

### Raw Expression (Non-Compute)

Without a compute scope, Mantra preserves the tree structure without reducing
operators.

**Input:**

```mantra
[ + 1 2 3 ]
```

**Output:**

```text
[ + 1 + 2 + 3 ]
```

The operator `+` is retained as a node in the tree. Operands `1`, `2`, `3` are
stored as sibling children. No arithmetic reduction occurs.
(Test fixture: `backtick_no_compute`)

### Multiple Values

A list can contain any number of elements as siblings.

**Input:**

```mantra
[ 1 2 3 4 5 ]
```

**Output:**

```text
[ 1 2 3 4 5 ]
```

---

## Compute Scopes

### Basic Compute with Backticks

Backtick scopes `` ` ... ` `` trigger arithmetic reduction. The operator is
preserved while operands are folded.

**Input:**

```mantra
` + 1 2 3 `
```

**Output (`--debug`):**

```text
+ 6
```

Siblings `1`, `2`, `3` are summed to `6`. The `+` operator remains in the
output tree.
(Test fixture: `backtick_integer_add`)

### Compute with Repeat

Combine compute and repeat (`:`) to clone and reduce expressions.

**Input:**

```mantra
`[ + 1 2 3 ] : 3`
```

**Output:**

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The list `[ + 1 2 3 ]` is repeated 3 times; each clone is independently
computed to `+ 6`.
(Test fixture: `backtick_repeat_list_compute`)

### Multiple Compute Scopes

Each backtick scope reduces independently.

**Input:**

```mantra
[ ` + 1 2 ` ` + 3 4 ` ]
```

**Output:**

```text
[ + 3 + 7 ]
```

The first scope reduces `+ 1 2` to `+ 3`; the second reduces `+ 3 4` to `+ 7`.
(Test fixture: `multi_compute_nodes`)

See [Compute Examples](examples/compute-examples.md) for more arithmetic,
boolean, float, unary, and variable examples.

---

## Tilde Meta-Compute

The `~` (tilde) meta flag marks a node or subtree for targeted compute
evaluation. It can be combined with `{ }` evaluation scope.

### Tilde on Full Expression

**Input:**

```mantra
[ { ~ [ + 1 2 3 : 2 ] : 3 } ]
```

**Output:**

```text
[ [ + 12 ] [ + 12 ] [ + 12 ] ]
```

The tilde targets the entire repeated block. The inner `+ 1 2 3` repeats twice
to produce `+ 1 2 3 1 2 3` (sum 12), which is then repeated 3 times.
(Test fixture: `backtick_tilde_full_expr`)

### Tilde on Operator Only

**Input:**

```mantra
[ { [ ~ + 1 2 3 : 2 ] : 3 } ]
```

**Output:**

```text
[ [ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ] ]
```

Here the tilde targets only the `+` operator, not the list wrapper. The `+ 1 2 3`
reduces to `+ 6` inside the repeat, producing `[ + 6 + 6 ]`, which repeats 3
times.
(Test fixture: `backtick_tilde_operator_only`)

---

## Scopes

Mantra has five scope delimiters, each controlling evaluation behavior:

| Syntax | Token | Meaning |
|---|---|---|
| `( ... )` | `TK_PARENTHESIS` | Expression grouping |
| `[ ... ]` | `TK_BRACKET` | Array / list |
| `{ ... }` | `TK_CURLY` | Evaluation scope |
| `` ` ... ` `` | `TK_BACKTICK` | Compute scope |
| `' ... '` | `TK_APOSTROPHE` | Fixed scope (no evaluation) |

### Grouping with Parentheses

Parentheses group expressions without triggering computation.

**Input:**

```mantra
( + 1 2 3 )
```

**Output:**

```text
( + 1 + 2 + 3 )
```

### Evaluation Scope

Curly braces `{ }` create an evaluation context where nested operations execute.

**Input:**

```mantra
{ ` + 1 2 ` }
```

**Output:**

```text
+ 3
```

### Fixed Scope

Single quotes `' ' ` prevent any transformation or evaluation inside.

**Input:**

```mantra
' + 1 2 '
```

**Output:**

```text
+ 1 2
```

The contents are preserved as-is without reduction.

---

## Variables and Assignment

### Variable Assignment

Use `=` to bind a tree snapshot to a variable name.

**Input:**

```mantra
x = [ 1 2 3 ]
print { x }
```

**Output:**

```text
[ 1 2 3 ]
```

(Test fixture: `assignment_basic`)

### Variable Lookup in Compute

Variables are resolved from context before arithmetic reduction.

**Input:**

```mantra
x = [ + 1 2 3 ]
`x`
```

**Output:**

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The variable `x` is assigned (printing the assignment), then the compute scope
resolves it and reduces the expression.
(Test fixture: `assignment_lookup_compute`)

### CLI-Set Variables

Pre-define variables via `--set` before execution.

**Args:** `--set x=5`

**Input:**

```mantra
print { x }
```

**Output:**

```text
5
```

(Test fixture: `cli_set_basic`)

---

## Repeat Operator

The repeat operator (`:`) clones its left-hand side a specified number of times.

### Basic Repeat

**Input:**

```mantra
[ 1 2 3 ] : 4
```

**Output:**

```text
[ 1 2 3 ] [ 1 2 3 ] [ 1 2 3 ] [ 1 2 3 ]
```

The list is cloned 4 times as siblings.
(Test fixture: `repeat_basic`)

### Repeat with Expression

The RHS can be a variable or expression that resolves to an integer.

**Input:**

```mantra
n = 3
[ hello ] : n
```

**Output:**

```text
[ hello ] [ hello ] [ hello ]
```

(Test fixture: `repeat_variable_count`)

### Recurse / Fixpoint

Use `...` for recursive repeat until fixpoint (bounded by 1024 steps).

**Input:**

```mantra
[ 1 2 ] : ...
```

**Output:**

```text
[ 1 2 ] [ 1 2 ] [ 1 2 ] ...
```

See [Repeat Operator Reference](../transformations/repeat-operator.md) for
fixpoint semantics and bounds.

---

## Pattern Matching Basics

### Selection with `?`

The selection operator rewrites its left subject using rules on the right.

**Input:**

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => x ] }
```

**Output:**

```text
1
```

The rule `[ x -- ] => x` captures the head (`x = 1`) and discards the tail.
Lowercase `x` binds to a single node; `--` captures remaining siblings.
(Test fixture: `matcher_rule_capture_head`)

### Tail Capture

**Input:**

```mantra
print { [ 1 2 3 ] ? [ [ x -- ] => [ rhs x ] ] }
```

**Output:**

```text
[ 2 3 ]
```

`rhs x` extracts the tail portion matched by `--`.
(Test fixture: `matcher_rule_capture_rhs_tail`)

### Match Any with `--`

`--` matches zero or more siblings between anchors.

**Input:**

```mantra
print { [ 1 2 3 4 ] ? [ [ 1 -- 4 ] => [ ok ] ] }
```

**Output:**

```text
[ ok ]
```

The `--` absorbs `2 3` between the literal anchors `1` and `4`.
(Test fixture: `matcher_match_any_infix_basic`)

### Full-Match Mode with `^`

Prefix `^` restricts matching to the subject root only.

**Input:**

```mantra
print { ( [ 1 2 3 ] ) ^? [ [ 1 2 3 ] => [ ok ] ] }
```

**Output:**

```text
( [ 1 2 3 ] )
```

The subject root is `( [ 1 2 3 ] )` — the rule pattern `[ 1 2 3 ]` does not
match the outer parentheses, so no rewrite occurs.
(Test fixture: `matcher_selection_subexpr_caret_full`)

See [Rule Examples](examples/rule-examples.md) and [Transform
Examples](examples/transform-examples.md) for complete pattern matching coverage.

---

## Named Rules

### Declare and Invoke

Use `rule` to create a reusable transformation.

**Input:**

```mantra
rule replace [ x => y ]
print { a ? replace }
```

**Output:**

```text
y
```

(Test fixture: `rule_keyword_basic`)

### Callable Dispatch

Named rules can be dispatched through callables with aliases.

**Input:**

```mantra
rule f [
  f x => x
];

alias g = f;

print { g 7 }
```

**Output:**

```text
7
```

The rule `f` matches `f x` and returns `x`. The alias `g` routes to `f`.
(Test fixture: `rule_callable_alias`)

---

## How It Works

- **Code is data is trees.** Every Mantra expression is an AST node. Operations
  transform tree structure, not text.
- **Backtick scope** triggers arithmetic reduction. The operator is preserved
  in the output (`+ 6` not `6`).
- **`~` (tilde)** marks targeted nodes for compute evaluation.
- **`?` (selection)** rewrites subjects using the first matching rule.
- **`--` (match any)** captures zero or more sibling nodes in patterns.
- **`:` (repeat)** clones the LHS a specified number of times.
- **`=` (assignment)** binds a tree snapshot to a variable name.
- **Lowercase symbols** match single nodes; **uppercase** match any structure.
- **Repeated symbols** (e.g., `[ x x ]`) require identical values at both positions.

### Running Examples from the Shell

```bash
# From stdin
echo '[ + 1 2 3 ]' | mantra

# From file
mantra program.m

# With debug output
mantra --debug program.m

# Pre-define variables
mantra --set n=5 --eval program.m
```

---

## Reference

- Source: `src/nodes.pas` (node hierarchy and dispatch)
- Source: `src/compute.pas` (arithmetic reduction)
- Source: `src/matcher_ir.pas` (pattern matcher and rewrite engine)
- Test fixtures: `tests/cases/` (370+ test cases)
- Manual: [Language Model](../language-model/index.md) — programs as trees
- Manual: [Evaluation](../evaluation/index.md) — runtime evaluation
- Manual: [Transformations](../transformations/index.md) — repeat and rewrites
- Manual: [Compute](../compute/index.md) — compute scopes and reductions
