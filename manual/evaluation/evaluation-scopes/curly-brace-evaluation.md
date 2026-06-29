# Curly Brace Evaluation

Curly braces mark a subtree for **evaluation and collapse**. The runtime evaluates
the enclosed expression and replaces the `{ ... }` wrapper with the result in the
surrounding tree.

```mantra
{ expression }
```

Unlike parentheses `( ... )` which group expressions without removing the wrapper,
curly braces are **destructive** — the braces disappear and their contents take
their place in the parent tree.

---

## Syntax

```mantra
{ expression }
```

| Component | Meaning |
|---|---|
| `{` | Opens an evaluation scope |
| `expression` | One or more child nodes to evaluate |
| `}` | Closes the evaluation scope |

---

## Evaluation Lifecycle

When the runtime encounters `{ ... }`, it follows these steps:

1. **Enter scope** — increments `EvaluationExecutionDepth` (tracks nesting level)
2. **Evaluate children** — recursively evaluates all child nodes (unfixes `~`
   markers, respects fixed `\` markers, dispatches node-specific evaluation)
3. **Compute (if `~` present)** — if the tilde modifier `~` is set, triggers
   arithmetic reduction on the children before collapsing
4. **Collapse** — replaces the `{ ... }` node with its children in the parent tree
   via `GlobalTree.Expand(PrevIndex, Index)`
5. **Exit scope** — decrements `EvaluationExecutionDepth`

The key operation is the **collapse** (step 4). The braces are removed and their
children are spliced directly into the parent's child chain.

---

## Basic Examples

### Simple evaluation and collapse

```mantra
[ { 1 2 3 : 4 } ]
```

The `{ 1 2 3 : 4 }` scope evaluates the repeat `1 2 3 : 4` (clones `1 2 3`
four times), then collapses — the braces are removed and the result takes their
place inside the array:

```
[ 1 2 3 1 2 3 1 2 3 1 2 3 ]
```

### Empty evaluation scope

An empty `{ }` evaluates to nothing and disappears:

```mantra
printf "[%t]" { + x ? y : 2 }
```

**Output:** `[]`

The `{ + x ? y : 2 }` scope evaluates the selection (which produces no matching
result for an empty subject), collapses to nothing, and the printf receives an
empty tree.

---

## Compute with Tilde Modifier

The `~` modifier inside curly braces triggers arithmetic reduction on the enclosed
expression before the scope collapses.

### Compute list elements

```mantra
[ { ~ [ + 1 2 3 : 2 ] : 3 } ]
```

**Output:** `[ [ + 12 ] [ + 12 ] [ + 12 ] ]`

The inner repeat `: 2` first clones `+ 1 2 3` twice, producing
`+ 1 2 3 + 1 2 3` inside the list. Then `~` triggers compute on the
entire list, reducing `+ 1 2 3 + 1 2 3` to `+ 12`. Finally, the outer
repeat `: 3` clones `[ + 12 ]` three times.

### Compute individual operator

```mantra
[ { [ ~ + 1 2 3 : 2 ] : 3 } ]
```

**Output:** `[ [ + 6 + 6 ] [ + 6 + 6 ] [ + 6 + 6 ] ]`

The `~` here is directly on the `+ 1 2 3` operator inside the repeat body. Each
iteration of `: 2` first computes `+ 1 2 3` to `+ 6`, producing `+ 6 + 6`. The
outer `: 3` then clones `[ + 6 + 6 ]` three times. Note the difference from the previous example: `~` placement determines
what gets computed and when.

### Boolean compute

```mantra
{ ~ and 1.5 0.0 2.5 }
```

**Output:** `0`

The `~` triggers compute on the `and` expression. Float values `1.5` and `0.0`
and `2.5` are evaluated as boolean — `0.0` is falsy, so the result is `0`.

### Comparison compute

```mantra
{ ~ < 1.5 2.0 }
```

**Output:** `1`

The `~` triggers compute on `< 1.5 2.0`, which evaluates to `1` (true).

---

## Curly Braces in Repeat Context

Curly braces inside repeat operations evaluate each clone individually:

```mantra
{ [ scope { printf "x" } ] :: 3 }
```

**Output:** `x` `x` `x` (on separate lines)

The `::` staged repeat creates 3 clones, and each `{ printf "x" }` evaluation
scope fires the printf call during iteration.

---

## Curly Braces in Selection Rules

Curly braces in selection rule patterns protect expressions from premature
evaluation. They act as structural wrappers that keep rule templates intact
during pattern matching.

### Eval wrapper in selection rule

```mantra
addinv = + x - x <=> 0
print { addinv ? [ { U -- <=> V -- } => { + x all U <=> + x all V } ] }
```

**Output:** `+ x + x - x <=> + x + 0`

The `{ U -- <=> V -- }` pattern wrapper prevents the rule RHS template from
being evaluated prematurely. The `{ + x all U <=> + x all V }` replacement
wrapper similarly stays structural until the rewrite is applied.

### Multi-child eval wrapper stays strict

```mantra
print { test "hello world" ? [ test { x y } => x ] }
```

**Output:** `test "hello world"`

The `{ x y }` in the pattern expects exactly two children — the evaluation scope
keeps the pattern structural and strict. The multi-child `"hello world"` does not
match the two-slot pattern, so no rewrite occurs.

---

## Curly Braces with Inference

Curly braces can wrap inference queries and rule sets:

```mantra
print { 1 => 3 |= [ 1 => 2, 2 => 3 ] : 2 }
```

**Output:** `1`

The evaluation scope contains an inference query asking whether `1` can reach
`3` using the given rules with 2 steps. The result `1` (true) collapses back
into the print statement.

### Inline rules in inference

```mantra
print { ( + x - x <=> 0 ) <=> ( ... ) |= [ x ==>> ( -x ), { U -- <=> V -- } => { + x all U <=> + x all V } ] : 2 }
```

**Output:** `1`

The `{ U -- <=> V -- }` and `{ + x all U <=> + x all V }` evaluation scopes
within the inference ruleset keep the pattern and replacement structural.

---

## Curly Braces with Callable Rules

Curly braces in callable rules trigger evaluation of intermediate results
during recursive rewriting:

```mantra
callable func;

rule runlist [
  runlist [ X -- ] => runlist { all X },
  runlist { X, } Y -- => func X runlist [ all Y ],
  runlist { X, } => func X
];

print { runlist [ "a", "b", "c" ] }
```

**Output:** `func "a" func "b" func "c"`

The `{ all X }` in the first rule evaluates `all X` before continuing the
rewrite chain. The `{ X, }` patterns in the other rules match comma-separated
elements structurally.

---

## Comparison Table

| Scope | Behavior | Braces removed? |
|---|---|---|
| `( ... )` — Parentheses | Groups expression | No |
| `{ ... }` — Curly braces | Evaluates and collapses | **Yes** |
| `` ` ... ` `` — Backticks | Computes and collapses | Yes (via `TComputeNode`) |
| `' ... '` — Apostrophe | Fixed — no evaluation | No |

---

## Key Behaviors

- **Destructive collapse** — The `{ }` wrapper is always removed; children are
  spliced into the parent tree.
- **Nested evaluation** — Multiple `{ }` scopes nest; each has its own
  `EvaluationExecutionDepth` level.
- **Fixed marker respect** — The `\` (backslash) marker prevents evaluation of
  enclosed children; only siblings continue.
- **Tilde compute** — The `~` modifier triggers arithmetic reduction before
  collapse.
- **Rule template protection** — In selection rules, `{ }` keeps patterns
  structural and prevents premature evaluation.
- **Debugger events** — `dekEvalScopeEnter` and `dekEvalScopeExit` events are
  emitted when a debugger is attached.
- **Empty scope** — An empty `{ }` collapses to nothing; the parent sees no
  children from that position.

---

## Common Patterns

**Evaluate expression inside array:**
```mantra
[ { expression } ]
```

**Compute inside evaluation:**
```mantra
{ ~ expression }
```

**Protect rule template:**
```mantra
[ { U -- => V } => replacement ]
```

**Evaluate per-iteration in repeat:**
```mantra
{ [ scope { action } ] :: n }
```

---

## Related Pages

- [Print and Output](print-output.md)
- [Nested Evaluation](../nested-evaluation.md)
- [Backtick Compute Scopes](../../syntax/compute-scopes.md)
- [Fixed Scopes](../../syntax/fixed-scopes.md)
- [Selection Operator](../../syntax/selection-operator.md)
