# Operator Reference

This page catalogues every operator in Mantra by category. Use it as a navigation hub to find the operator you need and understand where it fits in the runtime.

## Quick Reference

| Category | Operators | Sub-page |
|---|---|---|
| Arithmetic | `+`, `-`, `*`, `/` | [Arithmetic Operators](operator-reference/arithmetic-operators.md) |
| Boolean | `and`, `or`, `xor`, `not`, `nand`, `nor`, `nxor` | [Boolean and Comparison](operator-reference/boolean-comparison-operators.md) |
| Comparison | `<`, `<=`, `>`, `>=`, `==`, `!=` | [Boolean and Comparison](operator-reference/boolean-comparison-operators.md) |
| Structural | `&`, `explode`, `implode` | [Structural Operators](operator-reference/structural-operators.md) |
| Rewrite | `?`, `$?`, `:=?`, `=>`, `:=>`, `<=>` | [Structural Operators](operator-reference/structural-operators.md) |
| Transform | `=>`, `:=>`, `<=>` | [Structural Operators](operator-reference/structural-operators.md) |
| Repeat | `:` | — |
| Range / Recurse | `..`, `...` | — |
| Match | `--`, `---` | — |
| Inference | `\|=`, `?|=` | — |
| Assignment | `=`, `:=`, `>:=`, `<:=`, `!:=` | — |
| Meta flags | `~`, `\`, `$`, `^`, `.`, `@` | [Meta-Compute Operator](meta-compute-operator.md) |
| Compute trigger | `` `...` `` | [Compute Scope](compute-scope.md) |

## Operator Categories

### Arithmetic

`+`, `-`, `*`, `/` — reduce numeric operands to computed results inside compute scope or when targeted with `~`. Addition (`+`) and multiplication (`*`) are variadic; `-` and `/` support unary negation and reciprocal.

See [Arithmetic Operators](operator-reference/arithmetic-operators.md).

### Boolean

`and`, `or`, `xor`, `not`, `nand`, `nor`, `nxor` — operate on truthy/falsy values (non-zero is truthy, zero is falsy). `and` and `or` short-circuit; `xor` evaluates all operands. `not` is a modifier bit that negates the result of any boolean or comparison operator.

See [Boolean and Comparison Operators](operator-reference/boolean-comparison-operators.md).

### Comparison

`<`, `<=`, `>`, `>=`, `==`, `!=` — compare two values, returning `1` (true) or `0` (false). Support chaining (`> a b c` evaluates left to right). The `~` meta-compute flag can be combined directly with comparison operators in a single token (`~>`, `~<`, etc.).

See [Boolean and Comparison Operators](operator-reference/boolean-comparison-operators.md).

### Structural

`&` (concatenation), `explode` (string to characters), `implode` (characters to string) — act on tree structure rather than numeric values.

See [Structural Operators](operator-reference/structural-operators.md).

### Rewrite and Transform

`?` (selection), `$?` (state-selection), `:=?` (inline selection), `=>` (transform), `:=>` (inline transform), `<=>` (bidirectional transform) — structural pattern matching and rule-based rewriting. These operate on tree shape, not text.

See [Structural Operators](operator-reference/structural-operators.md).

### Meta Flags

Meta flags modify how the runtime processes a node:

| Flag | Token | Effect |
|---|---|---|
| `~` | `TK_TILDE` | Force compute on targeted node |
| `\` | `TK_FIXED` | Protect node from transformation |
| `$` | `TK_DOLLAR` | State-selection mode |
| `^` | `TK_CARET` | Full-match mode (no subexpression matching) |
| `.` | `TK_DOT` | Matching rule marker |
| `@` | `TK_AT` | At-index / iterator binding |

See [Meta-Compute Operator](meta-compute-operator.md).

## Compute Triggers

All arithmetic, boolean, and comparison operators require a compute trigger to reduce:

- **Meta-compute operator** `~` — targets a specific node for computation
- **Compute scope** `` `...` `` — marks an entire expression as computable

Without a compute trigger, operators remain as symbolic tree structures.

## Related Pages

- [Arithmetic Operators](operator-reference/arithmetic-operators.md)
- [Boolean and Comparison Operators](operator-reference/boolean-comparison-operators.md)
- [Structural Operators](operator-reference/structural-operators.md)
- [Meta-Compute Operator](meta-compute-operator.md)
- [Compute Scope](compute-scope.md)
- [Integer Arithmetic](integer-arithmetic.md)
- [Float Arithmetic](float-arithmetic.md)
- [Boolean and Comparison](boolean-comparison.md)
