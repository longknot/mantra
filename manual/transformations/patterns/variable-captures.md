# Variable Captures

Pattern variables bind matched subtrees during structural pattern matching.
When a rule matches, each variable symbol in the pattern captures the
corresponding subtree from the subject, and the replacement side references
those captures to build the result.

```mantra
rule f [
  f x => x
];
```

In this rule, `x` captures the argument to `f`. The captured `x` is scoped to
that single rule match and disappears after the rewrite completes.

Mantra provides several capture mechanisms beyond basic variable bindings:

- **Lowercase symbols** — match single identifier nodes (integers, strings,
  variables).
- **Uppercase symbols** — match any node including compound expressions and
  entire subtrees.
- **`$match` / `$focus`** — special dollar captures that reference the entire
  matched region or the focused subregion.
- **Selector modifiers** — `lhs`, `rhs`, `all` extract specific parts of a
  capture (left child, right siblings, or the full span).

## Pattern Variable Types

Mantra distinguishes two kinds of pattern variables by case:

| Pattern Symbol | Match Behavior |
|---|---|
| Lowercase (e.g., `x`, `a`, `name`) | Matches a single identifier node (integer, string, variable, etc.) |
| Uppercase (e.g., `X`, `A`, `HEAD`) | Matches any node, including compound expressions |

Lowercase symbols are the most common capture type. They match a flat
identifier — an integer literal, a string, a variable reference, or any
atomic node. They will not match a nested expression or a compound subtree.

Uppercase symbols match any node regardless of structure — integers, arrays,
expressions, or entire subtrees. Use uppercase when the pattern needs to
capture arbitrary tree shapes.

### Lowercase capture example

```mantra
{ f 1 2 ? [ f x => x ] }
```

Expected `OUTPUT`:

```text
1
```

The lowercase `x` captures `1` (the first argument). The replacement side
uses only `x`, so the result is `1`.

### Uppercase capture example

```mantra
{ f [ 1 2 ] 3 ? [ f X => X ] }
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

The uppercase `X` captures the entire `[ 1 2 ]` array subtree. A lowercase
`x` would not have matched here — it only accepts single identifier nodes.

### Lowercase refusal example

A lowercase symbol will not match a compound expression:

```mantra
{ f [ 1 2 ] 3 ? [ f x => x ] }
```

Expected `OUTPUT`:

```text
f [ 1 2 ] 3
```

The lowercase `x` cannot match `[ 1 2 ]`. The rule fails to fire, so the
subject is returned unchanged.

## How Captures Work

The matcher compiles each rule pattern into a sequence of match instructions
before any matching occurs. This compilation phase identifies all variable
symbols in the pattern and assigns each a unique binding index. When matching
executes, the instructions are a compact bytecode program that walks the
subject tree and binds variables along the way.

### Compilation phase

Before matching, the matcher:

1. Walks the pattern tree and collects all variable symbols.
2. Assigns each unique symbol a binding index (starting from 0).
3. Emits instructions — `moBindNode` for first occurrences of a symbol,
   `moCheckBindEq` for subsequent occurrences (same-symbol checks).
4. Stores the instruction program in a `TMatcherProgram` record.

### Execution phase

When a subject is matched against the compiled program, the matcher:

1. Allocates a `TMatchBindings` record with `NodeRefs` arrays sized to the
   binding count — initially all set to `EOT` (unbound).
2. Steps through the bytecode:
   - **`moBindNode`** — If the binding slot is empty (`EOT`), it stores the
     current subject node index. If already filled, the new node must be the
     same node index or the match fails.
   - **`moCheckBindEq`** — Verifies the current subject node equals the
     previously bound node. If the slot is empty or the nodes differ, the
     match fails.
3. On success, the `TMatchBindings` record holds all captured nodes.
4. The replacement template is then cloned with bound substitutions via
   `CloneTemplateNodeWithBindings`.

### Binding storage

Bindings are stored per-rule in a `TMatchBindings` record with two arrays:
`NodeRefs` (for symbol-to-node mappings) and `TailRefs` (for `--` tail
captures, see [Match-Any Captures](match-any-captures.md)). Bindings are
scoped to the single rule match — they do not leak between rules or persist
after the rewrite completes.

## Symbol Reuse: Same Symbol Must Match the Same Node

When a pattern variable appears multiple times in a rule, all occurrences
must match the same subject node. This is called *binding consistency*.
The matcher enforces this by emitting `moCheckBindEq` instructions for
subsequent occurrences — they verify the current subject node equals the
node index stored in the first binding.

### Symbol reuse succeeds

```mantra
simplify = [
  + a - a => 0
];

print { + x - x ? simplify };
```

Expected `OUTPUT`:

```text
0
```

The pattern `+ a - a` captures the first `x` as `a` and verifies that the
second `- x` also matches the same binding — which it does.

### Symbol reuse fails — rule doesn't fire

```mantra
simplify = [
  + a - a => 0
];

print { + x + x ? simplify };
```

Expected `OUTPUT`:

```text
+ x + x
```

The pattern `+ a - a` has a `-` operator on the second term, but the subject
has `+`. The rule doesn't match, so the subject is returned unchanged.

### Operator metadata doesn't affect binding

The matcher compares node indices, not operator metadata. Two references to
the same variable node with different operators still bind to the same symbol:

```mantra
simplify = [
  * x / x => + 1
];

print { * x / x ? simplify };
```

Expected `OUTPUT`:

```text
+ 1
```

Both `x` references point to the same variable node in the subject, so they
bind to the same symbol even though one carries `*` and the other carries
`/` operator bits.

## Using Captures in Replacement Templates

When the matcher resolves captures in the replacement side of a rule, it
clones the template and substitutes bound variables with references to
the actual matched nodes. The replacement template walks through each
node and checks:

1. Is it a `$match` or `$focus` special capture? → Replace with the matched
   or focused region.
2. Is it a bound pattern variable? → Look up the binding slot and replace
   with the matched node.
3. Is it a context variable? → Look up the variable in the current scope
   and substitute its value.
4. Is it a keyword (defined symbol)? → Keep it as a literal invocation,
   not a substituted value. This allows recursive rules to reference
   themselves without expanding to their definition.

### Substitution mechanics

The `CloneTemplateNodeWithBindings` function in `matcher_ir.pas` handles
this substitution. For each variable reference in the replacement template:

1. It looks up the variable name in the binding symbols table.
2. If found, it retrieves the bound node reference from `Bindings.NodeRefs`.
3. It applies any selector bits (`lhs`, `rhs`, `all`) to extract the
   correct part of the bound node.
4. It applies any arithmetic operators (e.g., `+ x` or `- x`) to the
   substituted node.
5. The result replaces the variable reference in the cloned template.

If the variable is not bound by the pattern but exists in the context, the
matcher falls back to the context variable value.

### Selector modifiers on captures

The replacement template can use selector modifiers to extract specific
parts of a capture:

| Selector | Extracts |
|---|---|
| `lhs x` | The left child of `x` |
| `rhs x` | The right siblings of `x` |
| `all x` | The full span from `x` to its tail |

```mantra
{ f [ 1 2 3 ] ? [ f x => lhs x ] }
```

Expected `OUTPUT`:

```text
1
```

Here `x` captures `[ 1 2 3 ]`. The `lhs` selector extracts only the first
child of the captured array.

### Context variable fallback

If a variable name in the replacement template is not bound by the pattern,
the matcher checks the context scope:

```mantra
rule f [
  f => g x
];

x = 5;
print { f ? f };
```

Expected `OUTPUT`:

```text
g 5
```

The pattern doesn't bind `x`, so the replacement template looks up `x`
in the context and finds `5`.

### Keyword preservation

Keywords (defined symbols) in replacement templates are not substituted
with their values — they remain as invocations:

```mantra
rule f [
  f => f
];

print { f ? f };
```

Expected `OUTPUT`:

```text
f
```

The `f` in the replacement stays as a rule reference, not its definition.
This enables recursive rules to call themselves.

## Dollar Captures: `$match` and `$focus`

Beyond named variables, Mantra provides two special dollar captures that
reference entire matched regions:

| Capture | References |
|---|---|
| `$match` | The entire matched region (from `MatchHead` to `MatchTail`) |
| `$focus` | The focused subregion within the match (from `FocusHead` to `FocusTail`) |

These are implemented in `CloneTemplateNodeWithBindings` as
`dckMatch` and `dckFocus` cases. When the matcher encounters `$match` or
`$focus` in a replacement template, it clones the corresponding matched
span using `CloneMatchVariableWithSelector`.

### `$match` — the entire matched region

```mantra
{ [ 1 2 3 ] ? [ [ $match ] => $match ] }
```

Expected `OUTPUT`:

```text
[ 1 2 3 ]
```

`$match` refers to the entire region that the pattern matched.

### `$focus` — the focused subregion

When a pattern has a focus point, `$focus` captures only the focused
subregion rather than the entire match.

## Variable Shadowing and Context Resolution

When a replacement template references a variable name, the matcher
resolves it through this priority chain:

1. **Bound pattern variable** — If the name was bound by the current
   pattern match, use the bound node.
2. **Context variable** — If the name exists in the current scope
   (via `Context.TryFindVariable`), use its value.
3. **Keyword** — If the name is a defined keyword, keep it as a literal
   invocation (not substituted).
4. **Unresolved** — If none of the above, the variable remains as-is.

This means pattern bindings shadow context variables of the same name.

```mantra
rule f [
  f x => x
];

x = 5;
print { f 10 ? f };
```

Expected `OUTPUT`:

```text
10
```

The pattern binds `x` to `10`, which shadows the context variable `x = 5`.
The replacement returns the bound value `10`.

## Variable Subtree References

When a pattern variable captures a node that itself references a subtree
(via `OBJ_VARIABLE_SUBTREE`), the replacement template can resolve that
subtree reference by looking up the variable's bound node and extracting
its `Ref` field. This allows capturing references to complex subtrees
and reconstructing them in the replacement.

The `CloneTemplateNodeWithBindings` function handles this by checking
for `MID_OBJ_VARIABLE_SUBTREE` nodes and resolving their references
through the binding symbols table and context.

## Match-Any Captures and Variable Combination

Variable captures work alongside `--` match-any wildcards. When a variable
appears before or after `--`, the `TailRefs` binding tracks where the
wildcard's captured span begins and ends. This enables selectors like
`rhs x` (tail after `x`) and `all x` (full span including tail) to
work correctly.

See [Match-Any Captures](match-any-captures.md) for details on `--` and
`---` wildcards.

## Common Pitfalls

### Lowercase variables don't match compound expressions

```mantra
# This won't match because x is lowercase and [ 1 2 ] is a compound node
{ f [ 1 2 ] ? [ f x => x ] }
```

Use uppercase `X` to match compound nodes.

### Pattern bindings shadow context variables

```mantra
rule f [
  f x => x
];

x = 5;
print { f 10 ? f };
```

Returns `10`, not `5`, because the pattern binding takes priority.

### Keyword identifiers are not substituted in replacements

```mantra
rule f [
  f => f
];
```

The `f` in the replacement is a keyword reference, not a value. This is
intentional — it allows recursive rules to work without infinite expansion.

## Summary

Variable captures are the primary mechanism for transferring matched
structure into replacement templates. Key points:

- **Lowercase symbols** match single identifier nodes.
- **Uppercase symbols** match any node including compound expressions.
- **`$match` / `$focus`** capture entire matched regions.
- **Selector modifiers** (`lhs`, `rhs`, `all`) extract parts of captures.
- **Pattern bindings** shadow context variables of the same name.
- **Keywords** in replacements stay as invocations, not substituted values.
- **Binding consistency** requires the same symbol to match the same node
  across all occurrences in a pattern.