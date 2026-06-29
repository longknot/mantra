# Staged Repeat (`::`)

Staged repeat uses the `::` operator to independently evaluate a subject
expression for each element of a driver sequence. It is the variant of the
repeat operation that produces **separate, isolated evaluations** rather than
the single evolving result of ordinary repeat (`:`).

```
subject :: driver
```

Every driver value triggers a fresh clone of the subject, which is evaluated
independently. The results are collected as sibling outputs.

---

## Two Repeat Modes

Mantra supports two repeat operators with distinct semantics:

| Operator | Mode | Behavior |
|---|---|---|
| `:` | Ordinary (evolving) repeat | One subject clone is transformed repeatedly. Each iteration sees the result of the previous one. |
| `::` | Staged repeat | A fresh subject clone is evaluated independently for each driver value. Iterations do not share state. |

Choose `:` when you want to iteratively transform a single result. Choose
`::` when you want to map a subject over a collection of independent values.

---

## Iterator Binding

When `@ variable` follows the driver, each driver value is bound to the
named variable for the duration of that one evaluation:

```
[ x * 2 ] :: [ 1 2 3 ] @ x
```

Output:

```
[ 2 * 2 ] [ 2 * 2 ] [ 2 * 2 ]
```

After evaluation:

```
2 4 6
```

The iterator variable exists only within a **temporary exact-local scope**
created for each iteration. It does not pollute the package or global state
and is automatically cleaned up after each step.

---

## Supported Driver Types

Staged repeat accepts several driver forms:

### Count Driver

An integer produces that many evaluations:

```
[ i * 2 ] :: 3 @ i
```

Output:

```
2 4 6
```

The iterator takes values `1, 2, ..., n` (one-based).

### Range Driver

A range produces evaluations for each value in the sequence:

```
[ i * 2 ] :: 1 .. 3 @ i
```

Output:

```
2 4 6
```

### Stepped Range Driver

Ranges with explicit step:

```
[ i ] :: 0 .. 10 step 3 @ i
```

Output:

```
0 3 6 9
```

### Array Driver

Literal arrays drive one evaluation per element:

```
[ x * 2 ] :: [ 10 20 30 ] @ x
```

Output:

```
20 40 60
```

### Expression Driver

Parenthesized expressions with multiple items act as sequences:

```
[ x * 2 ] :: ( 10 20 30 ) @ x
```

Output:

```
20 40 60
```

Comma-separated items are also supported:

```
[ x * 2 ] :: [ a, b, c ] @ x
```

### Variable Resolving To A Container

A variable whose value is an array or expression container:

```
values = [ 2 3 4 ];
[ x * x ] :: values @ x
```

Output:

```
4 9 16
```

---

## Without Iterator Binding

When no `@ variable` is present, the driver still controls how many
independent evaluations occur, but the driver values are not bound:

```
[ item ] :: [ a b c ]
```

Output:

```
[ item ] [ item ] [ item ]
```

Use this when you need the repetition count but not the individual values.

---

## Empty Drivers

An empty driver produces zero evaluations and no output:

```
[ x ] :: [ ] @ x
```

Output: (nothing)

---

## Structured Items

Nested containers remain single structured values and are not flattened:

```
[ x ] :: [ a b [ c d ] ] @ x
```

Each element is treated as one item. The nested `[ c d ]` is a single
structured value passed to one evaluation.

---

## Compute Scopes With Staged Repeat

Compute expressions inside a staged repeat are evaluated within each
independent clone:

```
[ ~ * x * x ] :: [ 2 3 4 ] @ x
```

Each iteration evaluates a fresh compute scope with the iterator value bound.

---

## Comparison With Ordinary Repeat

| | Ordinary `:` | Staged `::` |
|---|---|---|
| Clones | One clone, transformed repeatedly | Fresh clone per iteration |
| State | Iterations share and accumulate | Iterations are independent |
| Use case | Iterative computation, fixpoints | Mapping, collection transformation |
| Count behavior | `n` means `n-1` transforms on one subject | `n` means `n` independent evaluations |

Example showing the difference:

```
[ + 1 ] : 3       // Ordinary: evolves one subject
```

This clones once and transforms twice, accumulating across iterations.

```
[ i ] :: 3 @ i    // Staged: three independent evaluations
```

This evaluates `[ i ]` three separate times with `i` = 1, 2, 3.

---

## Grouping Compatibility

Parentheses around single scalar drivers retain their meaning as grouping:

```
[ i ] :: ( 3 ) @ i
```

A parenthesized multi-item form is a sequence:

```
[ x ] :: ( a b c ) @ x
```

---

## Item Boundaries

Whitespace-separated children of an array are individual items:

```
[ a b [ c d ] ]
```

yields three items: `a`, `b`, and `[ c d ]`.

Comma-separated containers similarly use each comma entry as one item:

```
[ a, b, [ c d ] ]
```

---

## Precedence

Repeat operators have the lowest precedence in the expression grammar:

1. Prefixed values or scope
2. Range `..`
3. Indexed lookup `@` (also used for iterator binding)
4. Repeat `:` / `::`

The `@` symbol serves a dual role: indexed lookup in general expressions,
and iterator binding when it follows a repeat driver. The parser distinguishes
by position:

```
i : 5 @ i       // @ is iterator binding (after repeat driver)
x @ i           // @ is indexed lookup (not in repeat context)
```

---

## Current Limitations

The current implementation does not yet:

- Allow sequence drivers on ordinary evolving repeat (`:`)
- Treat arbitrary flat sibling chains as implicit sequences
- Support filtering or destructuring of driver values
- Support multiple simultaneous iterators
- Support strings as character sequences

The restriction of sequence drivers to `::` is intentional. Sequence mapping
naturally matches staged repeat's contract of one independent evaluation per
driver value. Ordinary `:` evolves a single subject and would require a
separate semantic decision to support sequence values.
