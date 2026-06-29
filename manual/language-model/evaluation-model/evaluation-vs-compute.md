# Evaluation vs Compute

Evaluation and compute are related but distinct. Evaluation applies structural
runtime semantics to a subtree — variable substitution, repeat expansion,
selection rewriting, and inference. Compute reduces supported arithmetic,
comparison, and boolean operators into a single numeric result.

The key distinction: **evaluation transforms tree structure; compute folds
values.**

## The Scope Types

Evaluation uses curly braces. Compute uses backticks. Both collapse their
wrapper after processing.

| Syntax | Scope Type | Evaluates children? | Computes arithmetic? |
|---|---|---|---|
| `{ ... }` | Evaluation | Yes | No |
| `` ` ... ` `` | Compute | Yes | Yes |
| `' ... '` | Fixed | No | No |
| `( ... )` | Expression | Contextual | No |

## Evaluation (`{ ... }`)

Curly braces mark a subtree for evaluation. The runtime processes the enclosed
expression and **collapses** the scope — the braces disappear, and the result
takes their place in the parent tree.

```mantra
{ 1 2 3 : 4 }
```

OUTPUT:
```
1 2 3 1 2 3 1 2 3 1 2 3
```

The repeat `1 2 3 : 4` is evaluated inside the scope, then the scope collapses.

### What Evaluation Does

Inside an evaluation scope the runtime:

1. Resolves variables to their bound values.
2. Expands repeat operators (`:`, `::`).
3. Applies selection and transform rules (`?`, `=>`).
4. Runs inference queries (`|=`).
5. Collapses the `{ ... }` wrapper into its result.

### What Evaluation Does Not Do

Evaluation does **not** perform arithmetic reduction by default:

```mantra
{ + 1 2 3 }
```

OUTPUT:
```
+ 1 2 3
```

The `+` operator remains as a structural node. The values `1 2 3` are children
of the operator, but no folding occurs.

### Triggering Compute Inside Evaluation

To compute inside an evaluation scope, use the `~` (tilde) meta-flag:

```mantra
{ ~ + 1 2 3 }
```

OUTPUT:
```
+ 6
```

The `~` marks the `+` node for arithmetic reduction. The evaluation scope then
collapses the result.

### Evaluation Collapses

After evaluation, the `{ ... }` node is replaced by its first child. If the
scope is empty, it is removed entirely:

```mantra
[ { 1 2 3 : 2 } ]
```

OUTPUT:
```
[ 1 2 3 1 2 3 ]
```

The `{ ... }` wrapper disappears; only the expanded repeat result remains
inside the array.

## Compute (`` ` ... ` ``)

Backticks mark a subtree for arithmetic reduction. The runtime first evaluates
its children (resolving variables, processing nested scopes), then applies
compute to reduce supported operators.

```mantra
` + 1 2 3 `
```

OUTPUT:
```
+ 6
```

### What Compute Does

Inside a compute scope the runtime:

1. Evaluates descendants — variables are resolved, nested scopes are processed.
2. Runs compute — walks child nodes and reduces supported operators with their
   operands.
3. Collapses — removes the backtick wrapper, leaving only the result.

The compute pipeline inherits all evaluation behavior and adds arithmetic
reduction on top.

### Supported Reductions

Compute scope can reduce:

- **Integer arithmetic** — `+`, `-`, `*`, `/`
- **Float arithmetic** — same operators on floating-point operands
- **Comparisons** — `<`, `>`, `<=`, `>=`, `=`, `<>`
- **Boolean logic** — `and`, `or`, `xor`
- **Math functions** — `sin`, `cos`, `tan`, `floor`, `ceil`, `round`

### Compute Without Structural Change

Compute only reduces operators it recognizes. Unsupported forms remain symbolic:

```mantra
` + 1 2 unknown `
```

The `+ 1 2` portion may reduce, but `unknown` stops further folding. The
remaining expression is formatted symbolically.

## Compute Is Evaluation Plus Reduction

`TComputeNode` inherits from `TEvaluationNode` in the runtime. This means every
compute scope first performs evaluation, then applies compute:

```mantra
x = [ + 1 2 3 ]
`x`
```

OUTPUT:
```
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The assignment prints the symbolic form. Then the compute scope `` `x` ``
expands `x` (evaluation step) and reduces the addition (compute step).

## Comparison: Side by Side

The same expression, different scopes:

| Expression | Output | Explanation |
|---|---|---|
| `+ 1 2 3` | `+ 1 2 3` | Raw structural form, no evaluation |
| `{ + 1 2 3 }` | `+ 1 2 3` | Evaluated but not computed |
| `` ` + 1 2 3 ` `` | `+ 6` | Evaluated and computed |
| `{ ~ + 1 2 3 }` | `+ 6` | Evaluation with targeted compute |

## Nested Scopes

Compute can appear inside evaluation scopes, and evaluation can wrap compute:

```mantra
{ ` + 1 2 3 ` }
```

OUTPUT:
```
+ 6
```

The compute scope reduces first (inner), then the evaluation scope collapses
(outer).

### Multiple Compute Scopes

When multiple compute scopes appear at the same level, each is reduced
independently:

```mantra
` + 1 2 ` ` + 3 4 `
```

OUTPUT:
```
+ 3 7
```

### Compute Inside Repeat

Compute scope combines with the repeat operator. The expression inside the
backticks is computed in each repeated copy:

```mantra
`[ + 1 2 3 ] : 3`
```

OUTPUT:
```
[ + 6 ] [ + 6 ] [ + 6 ]
```

The addition `+ 1 2 3` reduces to `+ 6` inside every repeated copy.

## The Tilde Meta-Operator (`~`)

The `~` operator targets compute behavior at a specific node or subtree without
requiring backtick scope:

```mantra
{ ~ * 1.5 2 }
```

OUTPUT:
```
* 3
```

| Feature | Backtick (`` ` ``) | Tilde (`~`) |
|---|---|---|
| Scope | Full expression block | Single targeted node |
| Reduction | All supported ops in scope | Only the marked node/subtree |
| Wrapper removed | Yes, after compute | No wrapper to remove |
| Use case | Compute everything inside | Selective compute on specific nodes |

## Variable Resolution

Both evaluation and compute resolve variables before applying their operations:

```mantra
x = 42
{ ~ + x 1 }
```

OUTPUT:
```
+ 43
```

The variable `x` is first resolved to `42` (evaluation step), then the
arithmetic `+ 42 1` is reduced (compute step).

## When to Use Each

Use **evaluation** (`{ }`) when you want the runtime to:

- Resolve variables to their values.
- Expand repeat operators.
- Apply selection or transform rules.
- Run inference queries.
- Evaluate an expression before it is used in a larger structure.

Use **compute** (`` ` ` ``) when you want to:

- Reduce arithmetic expressions to numeric results.
- Evaluate comparisons and boolean logic.
- Combine repeat expansion with arithmetic folding.

Use **tilde** (`~`) when you want to:

- Compute a specific node without wrapping the entire expression in backticks.
- Apply compute selectively inside an evaluation scope.
- Control exactly which operators are reduced.

## Reading Output

When an example produces surprising output, check the scope delimiters before
changing the expression:

- If the operator remains with its operands (`+ 1 2 3`), it was evaluated but
  not computed — add `` ` ` `` or `~`.
- If you see a reduced result (`+ 6`), compute was applied correctly.
- If the scope wrapper appears in output, it may be nested in a structure that
  prevented collapse.

## Related Pages

- [Compute Scopes](../syntax/compute-scopes.md) — arithmetic reduction with backticks
- [Evaluation Scopes](../syntax/evaluation-scopes.md) — structural evaluation with curly braces
- [Meta-Compute Operator](../compute/meta-compute-operator.md) — targeted compute with tilde
- [Repeat with Compute Scopes](../transformations/repeat-with-compute-scopes.md) — combining repeat and compute
- [Curly Brace Evaluation](../evaluation/evaluation-scopes/curly-brace-evaluation.md) — runtime evaluation semantics
- [Symbolic and Non-Computed Forms](../compute/symbolic-non-computed-forms.md) — when forms stay symbolic
- [Supported Reductions](../compute/compute-scope/supported-reductions.md) — operations compute can fold
