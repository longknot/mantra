# Evaluation Scopes

Evaluation scopes, written with curly braces, mark a subtree for evaluation.
When the runtime reaches an evaluation scope, it executes the enclosed
expression and replaces the scope with the result.

```mantra
{ expression }
```

## Syntax

```
{ children... }
```

The opening `{` creates a **TEvaluationNode** in the AST. It inherits from
**TScopeNode** and carries the token `TK_CURLY_BEGIN`. The closing `}`
terminates the scope.

## Evaluation Lifecycle

The complete evaluation process follows these phases:

### 1. Execute — Enter the Scope

When execution reaches `{ ... }`, `TEvaluationNode.Execute` runs. It increments
the `EvaluationExecutionDepth` counter and calls `Evaluate`. This counter
tracks nesting depth so the runtime can distinguish inner evaluations from
outer ones.

### 2. Evaluate — Evaluate Descendants

`TBaseNode.Evaluate` performs three steps:

1. **Fixed/unfix gating** — checks the `TK_FIXED` and `TK_UNFIX` meta flags
   on the node. If the `TK_FIXED` flag is set (via `\`), evaluation is skipped.
2. **Descendant evaluation** — recursively evaluates child (`LHS`) and sibling
   (`RHS`) nodes, but only if they are not marked `TK_FIXED`.
3. **DoEvaluate dispatch** — invokes `TBaseNode.DoEvaluate`, which triggers
   node-specific behavior:
   - `TVariableNode.DoEvaluate` — substitutes variables from context
   - `TIntegerNode.DoEvaluate` — evaluates integer operations (`+`, `-`, `*`, `/`)
   - `TFloatNode.DoEvaluate` — evaluates float operations
   - `TRangeNode.DoEvaluate` — materializes ranges (e.g., `1..5` → `1 2 3 4 5`)
   - `TRecurseNode.DoEvaluate` — triggers recursion (`...`)
   - `TRepeatNode.DoEvaluate` — performs repeat expansion (`:`)
   - Other nodes dispatch their own `DoEvaluate` logic

### 3. Expand — Replace Scope with Result

After evaluation, `TBaseNode.Expand` is invoked. The scope node is replaced
by its children in the parent's context — the curly braces are removed and
their contents become direct children of the parent.

### 4. Complete — Cleanup

`TBaseNode.Complete` calls both `ClearRewrite` and `ClearEvaluation`. The
`ClearEvaluation` method traverses the tree and removes any remaining
`TK_CURLY_BEGIN` nodes, ensuring no evaluation scope artifacts persist.

## Examples

### Basic Evaluation

```mantra
{ 1 2 3 }
```

**Output:** `1 2 3`

The scope evaluates its children and replaces itself with the result.

### Evaluation Inside a Container

```mantra
[ { 1 2 3 : 4 } ]
```

**Output:** `[ 1 2 3 1 2 3 1 2 3 1 2 3 ]`

The evaluation scope first expands `1 2 3 : 4` (repeat `1 2 3`, four times),
then replaces the scope with the expanded result inside the array.

### Nested Evaluation Scopes

```mantra
{ { [ 3 : 3 ] } }
```

**Output:** `[ 3 3 3 ]`

The inner scope `{ [ 3 : 3 ] }` evaluates first, producing `[ 3 3 3 ]`. The
outer scope then evaluates, replacing itself with the result. Each scope
increments and decrements `EvaluationExecutionDepth` independently.

### Evaluation with Compute

```mantra
{ ~ + 1 ( 2 ) }
```

**Output:** `+ 3`

The `~` prefix marks the `+` operator for computation. The expression `( 2 )`
evaluates to `2`. The compute phase then adds `1 + 2 = 3`, producing `+ 3`.
The evaluation scope wraps the compute and replaces itself with the result.

### Evaluation with Variable Substitution

```mantra
x = 5;
{ x }
```

**Output:** `5`

The `TVariableNode.DoEvaluate` replaces `x` with its bound value `5` during
the evaluation phase. The scope then collapses around the substituted value.

### Fixed Content Prevents Evaluation

```mantra
{ \ [ 1 2 : 2 ] }
```

**Output:** `[ 1 2 : 2 ]`

The `\` (backslash) meta flag sets `TK_FIXED` on the enclosed node, preventing
the repeat expansion. The scope still evaluates (calls `Evaluate` on children),
but fixed children are skipped. The scope then replaces itself with the
unexpanded `[ 1 2 : 2 ]`.

### Fixed Scope Prevents Evaluation Entirely

```mantra
' [ 1 2 : 2 ] '
```

**Output:** `( [ 1 2 : 2 ] )`

An apostrophe scope `' ... '` is a fixed scope — it never triggers evaluation
or expansion. The content remains as-is, wrapped in an expression grouping.
This contrasts with `{ ... }` which always evaluates.

## Evaluation Scope vs Other Scopes

| Scope | Syntax | Evaluates | Expands | Computes |
|---|---|---|---|---|
| Expression `( ... )` | parentheses | No | No | Yes (in compute phase) |
| Array `[ ... ]` | brackets | No | No | Yes (in compute phase) |
| Evaluation `{ ... }` | curly braces | Yes | Yes | Yes |
| Compute `` ` ... ` `` | backticks | Yes | Yes | Yes (explicit) |
| Fixed `' ... '` | apostrophes | No | No | No |

### Key Differences

- **`( ... )`** — Expression grouping. Groups nodes but does not trigger
  evaluation. Used for operator precedence and structural grouping.
- **`[ ... ]`** — Array/list container. Preserves structure. Does not evaluate
  its contents.
- **`{ ... }`** — Evaluation scope. Evaluates children, substitutes variables,
  expands repeats, and replaces the scope with the result.
- **`` ` ... ` ``** — Compute scope. Inherits from `TEvaluationNode`. Adds
  explicit arithmetic reduction (`Compute` phase) after evaluation.
- **`' ... '`** — Fixed scope. Prevents all evaluation and expansion. Preserves
  the literal tree structure.

## The Complete Lifecycle in Detail

For a program like `{ 1 2 3 : 4 }`, the runtime follows this sequence:

1. **Parse** — The tokenizer produces `TK_CURLY_BEGIN`, identifiers for `1`,
   `2`, `3`, `TK_COLON`, and `4`. The parser builds an AST with
   `TEvaluationNode` as root, containing children `1`, `2`, `3`, `:`, `4`.

2. **Execute** — `TStatementNode.Execute` dispatches to `TEvaluationNode.Execute`.

3. **Evaluate** — `Evaluate` is called. Fixed flags are checked. Children are
   evaluated recursively. `TRepeatNode.DoEvaluate` encounters `1 2 3 : 4` and
   expands it to `1 2 3 1 2 3 1 2 3 1 2 3`.

4. **Expand** — `TBaseNode.Expand` replaces the `TEvaluationNode` with its
   children in the parent context. The curly braces are removed.

5. **Complete** — `TBaseNode.Complete` cleans up any remaining evaluation
   markers via `ClearEvaluation`, which traverses the tree and deletes nodes
   with `Id = TK_CURLY_BEGIN`.

## Nested Scopes and Depth Tracking

When evaluation scopes nest, the runtime tracks depth with
`EvaluationExecutionDepth`:

```mantra
{ { { 1 } } }
```

Each `{` increments the counter; each completes and decrements it. This ensures
the innermost scope resolves first, and outer scopes see the already-evaluated
result of their inner scopes.

## Interaction with Fixed Meta Flags

The `\` (backslash) meta flag prevents evaluation of the marked node:

```mantra
{ \ 1 2 3 }
```

The `1` node carries `TK_FIXED`, so `Evaluate` skips it. The scope still
collapses, producing `1 2 3` — the fixed flag only prevents transformation of
the marked node, not the scope's own collapse.

## Related Pages

- [Curly Brace Evaluation](evaluation-scopes/curly-brace-evaluation.md)
- [Print and Output](evaluation-scopes/print-output.md)
- [Compute Scopes](compute/compute-scopes.md)
- [Fixed Scopes](syntax/fixed-scopes.md)
- [Repeat Operator](transformations/repeat.md)
