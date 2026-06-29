# Symbolic and Non-Computed Forms

Not every source form is reduced to a numeric result. Some forms remain
**symbolic** — they are formatted as tree structure rather than computed.

Mantra distinguishes between **structural data** (the tree as written) and
**computed values** (arithmetic reduction). By default, operators like `+`, `-`,
`*`, `/` stay symbolic unless they appear inside a compute scope (`` ` ` ``)
or are targeted with the `~` (tilde) meta-flag.

## What Makes a Form Symbolic?

A form stays symbolic when the runtime does not apply arithmetic reduction:

1. **No compute scope** — the expression is outside backticks or tilde.
2. **Unsupported operator** — the operator has no numeric reduction rule.
3. **Non-numeric operand** — one or more operands cannot resolve to a number.
4. **Fixed scope** — the expression is protected by single quotes or `\`.

Each case is explained below.

---

## No Compute Scope

Without backticks or tilde, operators and operands are formatted but not
reduced. The formatter traverses the tree structure, prefixing each operand
with its parent operator.

### Operators Outside Compute Scope

```mantra
[ + 1 2 3 ]
```

OUTPUT:

```text
[ + 1 + 2 + 3 ]
```

The `+` operator appears before each operand — `1`, `2`, `3` — reflecting
the tree structure. This is how the formatter represents a node with operator
`+` and three children. The expression is **not** reduced to `6`.

Compare with the same expression inside a compute scope:

```mantra
`[ + 1 2 3 ]`
```

OUTPUT:

```text
[ + 6 ]
```

The backtick scope triggers arithmetic reduction, folding all operands into
a single result.

### Assignment Stores Symbolic Forms

Variables store the symbolic tree snapshot. The stored form is not computed:

```mantra
x = [ + 1 2 3 ]
```

OUTPUT:

```text
x = [ + 1 + 2 + 3 ]
```

The assignment prints the formatted tree. When the variable is later used
inside a compute scope, it is reduced:

```mantra
x = [ + 1 2 3 ]
`x`
```

OUTPUT:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The first line shows the stored symbolic form. The second line shows the
computed result after `` `x` `` expands the variable and applies arithmetic
reduction.

### Evaluation Scope Does Not Compute

Curly braces evaluate (resolve variables, expand repeats) but do not compute
arithmetic by default:

```mantra
{ + 1 2 3 }
```

OUTPUT:

```text
+ 1 2 3
```

The scope collapses, but the `+` operator remains structural. To compute
inside an evaluation scope, use the `~` meta-flag:

```mantra
{ ~ + 1 2 3 }
```

OUTPUT:

```text
+ 6
```

### Parentheses Are Structural

Parentheses group expressions but do not trigger computation:

```mantra
( + 1 2 )
```

OUTPUT:

```text
( + 1 + 2 )
```

Parentheses preserve the tree structure. During compute evaluation, single-
child parenthesis wrappers are collapsed into their parent operator, but
without compute scope, they remain as-is.

---

## Non-Numeric Operands

Even inside a compute scope, if an operand is not numeric, the operator
cannot reduce and the form stays symbolic.

### Variables That Don't Resolve to Numbers

```mantra
print { ~ + x 1 }
```

If `x` is not bound or bound to a non-numeric value, the `+` node cannot
complete the reduction. The remaining expression is formatted symbolically.

### Mixed Numeric and Symbolic Operands

When some operands are numeric and others are not, the runtime reduces what
it can and preserves the rest:

```mantra
print ~ { + 1i x 1j 1i }
```

OUTPUT:

```text
+ 1i + x + 1i 1j
```

The imaginary values `1i` and `1j` are recognized but cannot fold with a
symbolic variable `x`. The expression remains partially symbolic.

### Mathematical Functions Without Compute

Native function names like `sin`, `sqrt`, `exp` are treated as identifiers.
Without the `~` marker, they stay symbolic:

```mantra
print { sin 0 }
```

OUTPUT:

```text
sin 0
```

With `~`, the function is dispatched if implemented:

```mantra
print { ~ sin 0 }
```

If the function is supported, it returns a numeric result. If the argument
is out of domain, the form remains symbolic:

```mantra
print { ~ sqrt -1 }
```

OUTPUT:

```text
sqrt - 1
```

The negative domain has no real-valued result, so `sqrt -1` stays symbolic
rather than silently producing `NaN`.

---

## Unsupported Operators

Not all operators have numeric reduction rules. When the compute pipeline
encounters an unrecognized operator, it leaves the form unchanged.

### Index Lookup with Symbolic Expressions

The `@` index lookup operator cannot reduce when the index is symbolic:

```mantra
print { [ 10 20 30 ] @ i }
```

OUTPUT:

```text
[ 10 20 30 ] @ i
```

The variable `i` is not bound to a numeric index, so the lookup remains
symbolic. The same form with parentheses around the index behaves identically:

```mantra
print { [ 10 20 30 ] @ ( i ) }
```

OUTPUT:

```text
[ 10 20 30 ] @ ( i )
```

### Repeat with Symbolic RHS

When the right side of a repeat operator is symbolic (not a resolved number),
the repeat stays structural:

```mantra
print { + x : + p }
```

OUTPUT:

```text
+ x : + p
```

Neither `x` nor `p` is bound, so the repeat cannot execute. The form is
preserved as a template that can be instantiated later:

```mantra
s1 = + x : + p;
print { s1 }
```

OUTPUT:

```text
+ x : + p
```

When the RHS variable is assigned, the repeat becomes active:

```mantra
s2 = + x : + 2 p 2;
{ p = 3 };
print { s2 }
```

OUTPUT:

```text
+ x + x + x + x + x + x + x
```

The `+ 2 p 2` resolves to `+ 2 3 2` = `+ 6 2` which evaluates to `7`,
repeating `+ x` seven times.

---

## Fixed Scopes

Single quotes and the `\` (backslash) meta-flag protect expressions from
evaluation and transformation. Fixed forms are always symbolic.

### Apostrophe Fixed Scope

Single quotes mark a fixed scope. The enclosed tree is never evaluated,
rewritten, or computed:

```mantra
' [ 1 2 : 2 ] '
```

OUTPUT:

```text
( [ 1 2 : 2 ] )
```

The repeat operator `: 2` is preserved as structure rather than being
evaluated. The scope wrapper collapses to parentheses in the output.

Fixed scopes are commonly used in selection patterns to match literal tree
structures:

```mantra
print { test "hello world" ? [ test ' x ' => x ] }
```

OUTPUT:

```text
"hello world"
```

The `' x '` pattern matches any node regardless of its type — the fixed
scope preserves the literal structure of the pattern variable `x` so it
captures the matched value without triggering evaluation.

### Backslash Meta-Flag

The `\` prefix on a node has the same fixed effect as single quotes — it
marks a single node or subtree as immune to transformation:

```mantra
\ [ + 1 2 ]
```

The `[ + 1 2 ]` subtree will not be evaluated or computed even if it appears
inside an evaluation or compute scope.

### Unfixing Fixed Scopes

Fixed scopes can be removed with the `\\` (double backslash) unfix meta-flag
inside an evaluation scope:

```mantra
{ \\\\ ' [ 1 2 : 2 ] ' }
```

OUTPUT:

```text
( [ 1 2 1 2 ] )
```

The unfix removes the protection, allowing the repeat `: 2` to evaluate
and produce two copies of `1 2`.

---

## Summary: When Forms Stay Symbolic

| Condition | Example | Result |
|---|---|---|
| No compute scope | `[ + 1 2 3 ]` | `[ + 1 + 2 + 3 ]` |
| Evaluation only | `{ + 1 2 3 }` | `+ 1 2 3` |
| Non-numeric operand | `+ x 1` (x unbound) | `+ x + 1` |
| Out-of-domain | `{ ~ sqrt -1 }` | `sqrt - 1` |
| Fixed scope | `' [ 1 2 : 2 ] '` | `( [ 1 2 : 2 ] )` |
| Backslash prefix | `\ [ + 1 2 ]` | `\ [ + 1 + 2 ]` |
| Unsupported operator | `[ 10 20 30 ] @ i` | `[ 10 20 30 ] @ i` |
| Symbolic repeat RHS | `+ x : + p` | `+ x : + p` |

---

## Making Symbolic Forms Computable

To reduce a symbolic form to a numeric result:

1. **Wrap in compute scope** — add backticks around the expression:
   `` ` + 1 2 3 ` `` → `+ 6`
2. **Use the tilde meta-flag** — target a specific node:
   `{ ~ + 1 2 3 }` → `+ 6`
3. **Bind symbolic variables** — assign numeric values before computing:
   `x = 5` then `` `+ x 1` `` → `+ 6`
4. **Unfix protected scopes** — use `\\` to remove fixed protection:
   `{ \\\\ ' [ 1 2 : 2 ] ' }` → `( [ 1 2 1 2 ] )`

---

## Related Pages

- [Evaluation vs Compute](../language-model/evaluation-model/evaluation-vs-compute.md) — the distinction between structural evaluation and arithmetic reduction
- [Compute Scopes](../syntax/compute-scopes.md) — arithmetic reduction with backticks
- [Fixed Scopes](../syntax/fixed-scopes.md) — protective single-quote scopes
- [Meta-Compute Operator](meta-compute-operator.md) — targeted compute with tilde
- [Supported Reductions](compute-scope/supported-reductions.md) — operations compute can fold
- [Delimiters and Scope Tokens](../syntax/tokens-whitespace/delimiters-scope-tokens.md) — all scope delimiters
