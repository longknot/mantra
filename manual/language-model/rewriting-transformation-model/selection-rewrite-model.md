# Selection Rewrite Model

Selection applies structural rewrite rules to a subject tree. It is the core mechanism for pattern-matching and tree transformation in Mantra.

## Syntax

```mantra
LHS ? RULES
LHS :=? RULES
```

- **`LHS`** — the subject tree to rewrite.
- **`?`** — the selection operator.
- **`:=?`** — the inline selection operator (currently shares the same runtime behavior as `?`; `TInlineSelectionNode` inherits from `TSelectionNode`).
- **`RULES`** — a rule, a ruleset, or a variable referencing one.

A repeat count can follow to bound how many rewrite steps are attempted:

```mantra
LHS ? RULES : n    — try up to n rewrite steps
LHS ? RULES : ...  — iterate to fixpoint (bounded by MAX_FIXPOINT_STEPS = 1024)
```

## How It Works

Selection delegates rewriting to `matcher_ir.RewriteOneByRules(...)`. The engine:

1. Evaluates the **LHS** (subject) to its current tree state.
2. Resolves the **RHS** (rules) — if it is a variable, it is repeatedly dereferenced until a concrete ruleset is reached.
3. Collects rules from the ruleset in source order.
4. Attempts to match and apply the **first applicable rule**.
5. If a rewrite succeeds, the selection node is replaced by the resulting tree.
6. The RHS (rules) is consumed and deleted after the attempt.

### Single-Step vs. Iterative

Selection has two evaluation paths depending on context:

- **`Evaluate`** (single-step): Attempts one rewrite, then always collapses the selection node — replacing it with the rewritten LHS (or the original LHS if no rule matched). The rules are deleted regardless.

- **`Transform`** (iterative): Called during repeat expansion. Attempts one rewrite but **keeps the selection node alive** if the step succeeds, so the next repeat iteration can apply another rewrite. When no rule matches and `CLEANUP_SELECTION_ON_STALL` is enabled, the selection collapses to plain LHS (rules are discarded).

## Matching Modes

### Subexpression Matching (Default)

Without any modifier, the matcher searches the subject tree breadth-first: it tries the root first, then descends into children and siblings. The **first** matching subexpression is rewritten.

```mantra
[ 1 [ 2 3 ] 4 ] ? [ [ 2 x ] => [ matched x ] ]
→ [ 1 [ matched 3 ] 4 ]
```

### Full-Root Matching (`^`)

Prefix the selection with `^` to force the matcher to require a full match of the current subject root — no subexpression matching:

```mantra
[ 1 2 3 ] ^? [ [ 1 x y ] => [ matched x y ] ]
→ [ matched 2 3 ]

[ 1 [ 2 3 ] ] ^? [ [ 2 x ] => [ matched x ] ]
→ [ 1 [ 2 3 ] ]   ← no change; the root is [ 1 [ 2 3 ] ], not [ 2 3 ]
```

In the source code, this is controlled by the `TK_CARET` flag on the node's `Data` field: `MatchSubexpressions := (TreeNode^.Data and TK_CARET) <> TK_CARET`.

## State Selection Mode (`$`)

The `$` meta flag enables **iterative state-selection mode**. When selection appears inside a repeat expansion with `$`, the engine uses `ExpandStateSelection` instead of the standard expansion path:

1. The source tree is cloned once.
2. The engine iteratively finds the selection node and calls `Transform` until the repeat limit is reached or no rule matches (stall).
3. After the loop, cleanup occurs (`CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT`).
4. The final tree is finalized with `Complete` + operator propagation.

This is the pattern for multi-pass rewrites where you want selection rules applied repeatedly in a single expression:

```mantra
{ 1 2 3 $? [ x => x + 1 ] : 2 }
→ attempts two rewrite steps on [ 1 2 3 ]
```

The `UsesStateSelectionMode(...)` helper checks whether a source tree contains selection with the `TK_DOLLAR` flag.

## Rules and Rule Resolution

### Rule Order

Rules are collected in source order. The first rule that matches the subject is applied. Subsequent rules are not tried. Rule ordering is your primary control flow mechanism.

### Equivalence Rules

Rules defined with `<=>` (bidirectional equivalence) generate **two candidates** — one forward and one reverse — doubling the effective rule count for matching purposes.

### Named Rulesets

Rules can be stored in variables and referenced by name:

```mantra
. my_rules = [
  [ "name" -- ] =>> $match
  [ "address" -- ] =>> lhs $match
]

persons ? my_rules
```

When the RHS of a selection is a variable node, `TSelectionNode.Evaluate` repeatedly resolves it (`while ObjectId = OBJ_VARIABLE`) until a concrete ruleset is reached.

### Rule Templates Are Not Evaluated

Rules on the RHS of `?` are **structural templates**, not executable code. They are preserved unevaluated until the matcher uses them. This is enforced by `TVariableNode.Evaluate`, which stops recursive evaluation when a variable occurs in rule position (parent is selection and parent.RHS = variable node).

## Selection with Repeat

Selection integrates with the repeat operator (`:`) for iterative rewriting:

```mantra
[ 1 2 3 4 5 ] ? [ x => x + 10 ] : 3
→ applies the rule up to 3 times
```

When `LHS` contains selection, `TRepeatNode.Evaluate` skips pre-evaluating LHS to preserve the rewrite structure. The repeat count is resolved from the RHS before expansion begins.

### Implicit Recurse Injection

By default, `TBaseNode.FixRecursion` appends an implicit `...` when no recurse is present. However, when selection exists in the source (`SKIP_IMPLICIT_RECURSE_FOR_SELECTION = True`), implicit recurse is **not** injected — this prevents accidental extra iteration on selection-driven rewrites.

## Pattern Matching Basics

Selection rules use Mantra's structural pattern matcher:

- **Lowercase symbols** (`x`, `y`) match and bind single identifiers.
- **Uppercase symbols** (`X`, `Y`) match any node without binding.
- **`--`** matches any tail sequence (zero or more siblings).
- **`---`** is the long form of match-any.
- **`$match`** references the full matched subtree in replacements.
- **`lhs` / `rhs`** extract the left or right child of a matched node.

```mantra
. persons = [
  [ "name" "Alice" "age" 30 ],
  [ "name" "Bob" "age" 25 ]
]

. find_alice = [ [ "name" "Alice" -- ] =>> $match ]

print { persons ? find_alice }
→ [ "name" "Alice" "age" 30 ]
```

## Rule Composition and Chaining

Selections can be chained — the output of one selection becomes the input to the next:

```mantra
. extract_person = [ [ "name" "Jane Smith", -- ] =>> $match ]
. extract_address = [ "address" =>> rhs $match ]
. extract_street  = [ "street" =>> rhs $match ]

print { persons ? extract_person ? extract_address ? extract_street }
→ "456 Elm St"
```

Each `?` consumes its rules and collapses to its result, which becomes the LHS for the next selection.

## Selection Strategies

The matcher supports configurable selection strategies controlled by `MatcherSelectionStrategy`:

| Strategy | Description |
|---|---|
| `first` (default) | Apply the first matching rule in source order |
| `random` | Randomly select among matching candidates |
| `shrink` | Prefer rules that produce smaller results |
| `first-rule` | Always try rules in fixed source order |
| `random-rule` | Randomize rule trial order |

These can be set via the `selector` keyword or CLI flags.

## Guards

Rules can include guards — conditions that must be true for a rule to apply. Guards are evaluated via `EvaluateGuardTemplate(...)` in the matcher IR. The CLI flag `--no-guards` disables guard enforcement entirely.

## Inline Selection (`:=?`)

The `:=?` operator creates a `TInlineSelectionNode` which inherits all behavior from `TSelectionNode`. Currently, the runtime behavior is identical to `?`. The distinction exists for future differentiation between inline and standard selection semantics.

## Tree Replacement

Selection uses two tree mutation primitives to replace itself:

- **`ExpandInline`** — used when `PrevIndex = EOT` (root-level selection). Rewrites the node in-place, preserving root connectivity.
- **`Expand`** — used for non-root selection nodes. Replaces the node with its LHS in the parent context.

## Common Patterns

### Extract

Use selection to extract specific data from a structure:

```mantra
[ key value ] ? [ key =>> rhs $match ]
→ value
```

### Filter

Use selection to remove or replace items:

```mantra
[ 1 2 3 4 ] ? [ 2 =>> -- ]
→ [ 1 3 4 ]
```

### Transform

Use selection with repeat for multi-pass transformation:

```mantra
[ a b c ] $? [ x =>> ( transformed x ) ] : ...
→ [ ( transformed a ) ( transformed b ) ( transformed c ) ]
```

## Key Implementation Notes

- Selection nodes are `OBJ_SELECTION` / `OBJ_INLINE_SELECTION` in the node hierarchy.
- Meta operators (`$`, `^`) are accumulated during parsing and stored in the node's `Data` field.
- `RewriteOneByRules` collects rules once, builds candidates, applies selection strategy, and returns the rewritten tree index.
- Fixpoint iterations are bounded by `MAX_FIXPOINT_STEPS` (1024) to prevent infinite loops.
- The context tracks selection progress via `MarkSelectionProgress` / `HasProgressSince` — used by fallback (`??`) to detect whether a rewrite actually occurred.

## Related

- [Transform Operators](./transform-operators.md) — the `=>`, `=>>`, `<=>` operators used in rules
- [Evaluation Model](../evaluation-model.md) — how trees are evaluated and computed
- [Values, Nodes, Expressions](../values-nodes-expressions.md) — the tree data model selection operates on
