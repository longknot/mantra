# Substitution Transform

Substitution transforms use `==>` and `==>>` to perform simultaneous symbol-level
replacements across a subject tree. Unlike basic transforms (`=>`) that match
structural patterns and replace a single matched span, substitution transforms
build a symbol-to-replacement mapping and apply it to every matching occurrence
in the subject in one pass.

```mantra
pattern ==> replacement    {substitution transform (strict mode)}
pattern ==>> replacement   {symbol-substitution transform (no strict mode)}
```

The bidirectional form `<==>` works like `==>` but matches in both directions,
analogous to how `<=>` relates to `=>`.

## Forms

Substitution transforms support three operator forms:

| Operator | Node Type | Behavior |
|---|---|---|
| `==>` | `TSymbolSubstitutionNode` | Symbol-substitution (literal, no strict check) |
| `==>>` | `TSubstitutionNode` | Substitution (binding-aware, strict check) |
| `<==>` | `TEquivalenceSubstitutionNode` | Bidirectional substitution (strict check) |

Despite the similar names, `==>` and `==>>` behave quite differently internally.
The three-character form `==>` skips matcher bindings entirely and performs
literal symbol replacement, while the four-character form `==>>` goes through
normal matcher bindings with template expansion.

## How It Works

Substitution transforms follow a two-phase process:

1. **Build the substitution mapping** — The LHS of the rule is parsed as a
   sequence of top-level variables (e.g., `x y z`). The RHS provides the
   corresponding replacement expressions. Each LHS variable is paired with
   an RHS replacement to form a substitution entry.

2. **Apply simultaneously** — The matcher traverses the subject tree and
   replaces every occurrence of each mapped symbol with its corresponding
   replacement. The substitution happens in a single pass, so all symbols
   are replaced simultaneously — this prevents swap and capture anomalies
   that would occur with sequential replacement.

### Single-symbol substitution

```mantra
print { x ==> y }
```

Expected `OUTPUT`:
```text
x ==> y
```

The rule itself is just a structural template — nothing happens until it is
applied through selection (`?`) or inference (`|=`).

### Applying with selection

```mantra
print { x ? [ x ==> - x ] }
```

Expected `OUTPUT`:
```text
- x
```

Here the rule `x ==> - x` maps symbol `x` to replacement `- x`. The subject
`x` is matched and replaced, producing `- x`.

### All occurrences replaced

Substitution transforms replace **every occurrence** of the mapped symbol in
the subject, not just the first match:

```mantra
print { + x ( - x ) x ? [ x ==> - x ] }
```

Expected `OUTPUT`:
```text
- x + ( + x ) - x
```

Every `x` in the subject is replaced. Note that the operator attached to each
`x` (e.g., unary `-`) is preserved on the replacement — the original `- x`
occurrence keeps its negation operator, and the top-level `+` operator
is preserved as well.

### Multi-symbol simultaneous substitution

Substitution transforms can map multiple symbols at once. The LHS is a
sequence of variables; the RHS provides the same number of replacement
expressions. Each variable maps positionally:

```mantra
print { x y x ? [ x y ==> y x ] }
```

Expected `OUTPUT`:
```text
y x y
```

The rule `x y ==> y x` creates two substitution entries: `x -> y` and
`y -> x`. Because the replacement is simultaneous, the first `x` becomes
`y`, `y` becomes `x`, and the second `x` becomes `y`. If replacements were
sequential, the intermediate result would corrupt the second substitution.

With a single-symbol LHS, the entire RHS is treated as one replacement unit:

```mantra
print { p ? [ p ==> + p 1 ] }
```

Expected `OUTPUT`:
```text
+ p + 1
```

Here `p` maps to the entire `+ p 1` expression. Both `==>>` and `==>` behave
the same for this simple case.

## `==>` vs `==>>`: Key Differences

Although `==>` and `==>>` look similar, they use fundamentally different code
paths inside the matcher:

| Aspect | `==>` (TSymbolSubstitutionNode) | `==>>` (TSubstitutionNode) |
|---|---|---|
| Matcher bindings | Skipped (`Bindings.Init(0)`) | Normal binding collection |
| Replacement | Literal `CloneSpan` of RHS fragments | `CloneTemplateSequenceWithBindings` |
| Strict shape check | Never applied | Applied when `mantra.substitution.strict = 1` (default) |
| Operator forwarding | Source operator only (`AppendOperator(SourceOp)`) | Template operator carriers, selector-aware spans |
| Best for | Literal symbol-level rewrites | Algebraic proof rules with operator structure |

### Matching and binding

- `==>` bypasses the matcher's symbol collection and binding system entirely.
  It treats the rule as a pure symbol-to-replacement map and walks the subject
  tree looking for variable nodes whose name matches a mapping key.

- `==>>` goes through normal pattern matching: it collects symbols, builds
  bindings, and uses template expansion logic. This means it supports operator
  propagation, selector operators (`lhs`, `rhs`, `all`), and focus markers.

### Replacement construction

- `==>` uses `CloneSpan` — it literally clones the RHS fragments from the
  rule tree. The result is a direct structural copy with only the source
  variable's operator reapplied.

- `==>>` uses `CloneTemplateSequenceWithBindings` — it processes template
  nodes, resolves bindings, and handles selector-aware spans. This preserves
  operator structure through unfold/fold normalization passes.

### Practical difference: operator propagation

The two forms can produce structurally different results when the subject
contains grouped expressions that later get unfolded:

```mantra
print { ( + x - x <=> 0 ) ? [ x ==>> ( -x ) ] }
{ s1 = ( + x - x <=> 0 ) ? [ x ==>> ( -x ) ] }
print { s1 }
print { s1 ? [ { U -- <=> V -- } => { + x all U <=> + x all V } ] }
```

Expected `OUTPUT`:
```text
( + ( - x ) - ( - x ) <=> 0 )
( + ( - x ) - ( - x ) <=> 0 )
( + x + ( - x ) - ( - x ) <=> + x + 0 )
```

The `==>` path produces cleaner operator structure that interacts better with
subsequent unfold/fold rules. Prefer `==>` for algebraic proof workflows where
operator structure matters.

## Strict Mode

`==>>` (and `<==>` with the same strictness rules) enforces a **strictness
check** by default: the set of symbols on the LHS must exactly match the set of
symbols on the RHS. No fresh symbols may be introduced, and no symbols may be
dropped.

The check is controlled by the runtime setting `mantra.substitution.strict`
(default `1`):

```mantra
mantra.substitution.strict = 1   { enforce strict check (default) }
mantra.substitution.strict = 0   { allow arbitrary symbol mappings }
```

Note: `==>` never applies the strict check — it is exempt by design.

### Valid and invalid rules (strict mode)

```mantra
print { x ? [ x ==> - x ] }      { valid: vars(LHS) = {x}, vars(RHS) = {x} }
print { x y x ? [ x y ==> y x ] } { valid: vars(LHS) = {x,y}, vars(RHS) = {x,y} }
```

Expected `OUTPUT`:
```text
- x
y x y
```

A rule introducing a fresh symbol on the RHS is rejected:

```mantra
print { x ? [ x ==>> - y ] }     { invalid: y not in LHS }
```

Expected `OUTPUT`:
```text
x
```

The subject is unchanged because the rule fails the strictness check. With
diagnostics enabled, the matcher emits:
`substitution strictness failed: vars(LHS) must equal vars(RHS)`.

### Disabling strictness

```mantra
print { x ? [ x ==>> y ] }
mantra.substitution.strict = 0
print { x ? [ x ==>> y ] }
```

Expected `OUTPUT`:
```text
x
y
```

The first application fails (strict check rejects fresh `y`). After disabling
strict mode, the same rule succeeds.

### LHS shape requirements

For substitution transforms, the LHS must be a **top-level variable sequence**.
Each LHS element must be a single variable node — nested expressions, integers,
or compound patterns on the LHS will cause the rule to fail. The LHS also
cannot contain duplicate symbols.

Failure reasons the matcher reports:
- `substitution LHS must be a top-level variable sequence`
- `substitution LHS variable has no symbol reference`
- `substitution LHS contains duplicate symbols`
- `substitution LHS/RHS mapping arity mismatch`
- `substitution mapping is empty`

## Bidirectional Substitution Equivalence

The `<==>` operator creates a bidirectional substitution rule. Like `<=>` vs
`=>`, the matcher tries both forward (LHS to RHS) and reverse (RHS to LHS)
directions:

```mantra
print { x y ? [ x y <==> y x ] }
```

Expected `OUTPUT`:
```text
y x
```

The subject `x y` matches the LHS of the rule in the forward direction and is
replaced with `y x`. The reverse direction would also work if the subject were
`y x`, replacing it with `x y`.

The `<==>` form inherits the same strictness checks as `==>>` — the LHS and RHS
must contain the same symbol set.

## Substitution in Inference

Substitution transforms work naturally with the inference operator `|=`. They
are commonly used to prove that one expression can be rewritten into another
using only symbol substitutions:

```mantra
print { x => y |= [ x ==> y ] : 1 }
```

Expected `OUTPUT`:
```text
1
```

The query asks whether `x` can become `y` in one step using the substitution
rule `x ==> y`. The answer is `1` (success).

Strictness still applies in inference contexts:

```mantra
mantra.substitution.strict = 0
print { x => y |= [ x ==> y ] : 1 }
```

Expected `OUTPUT`:
```text
1
```

Here strict mode is explicitly disabled so the fresh symbol `y` on the RHS is
accepted.

## Substitution Span and Focus

When a substitution rule is applied, it operates on the **matched span** of the
subject — the subtree that the matcher has selected. Without an explicit focus
marker, substitution applies to the full matched candidate. With a dot/focus
marker (`.`), substitution targets only the focused span.

Substitution rules applied through ordinary selection (`?`) on a literal subject
replace symbols throughout that entire subject:

```mantra
print { * 1 m <=> + m ? [ m ==> ( + m 1 ) ] }
```

Expected `OUTPUT`:
```text
* 1 * ( + m + 1 ) <=> + ( + m + 1 )
```

Every occurrence of `m` in the subject is replaced with `( + m 1 )`.

## Comparison with Basic Transforms

| Feature | `=>` (basic) | `==>` / `==>>` (substitution) |
|---|---|---|
| Matching | Structural pattern match | Symbol name lookup |
| Replacement scope | Single matched span | All occurrences of mapped symbols |
| Variables on LHS | Pattern variables with `--` tails | Top-level variable sequence |
| Simultaneous replacement | No (one match at a time) | Yes (all symbols at once) |
| Strictness check | No | Yes for `==>>` (default on) |

Use basic transforms when you want to match structural patterns and replace
a specific matched region. Use substitution transforms when you need to
replace every occurrence of certain symbols throughout a subject tree.

## Related Pages

- [Basic Transform](basic-transform.md)
- [Equivalence Rules](equivalence-rules.md)
- [Inline Transform](inline-transform.md)
- [Inference Operator](../inference/inference-operator.md)
