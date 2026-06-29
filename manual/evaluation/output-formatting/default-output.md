# Default Output

The default output formatter (`TFormatter`) is the standard output mode. It
converts evaluated AST trees into human-readable text, applying operator
prefixes, column alignment, and whitespace rules automatically.

## Overview

Every expression that produces a value passes through the output pipeline:

```
Execute → Evaluate → Format → EmitRuntimeOutputLine
```

The formatter traverses the AST, writes each node's representation, and builds
the final string. `TFormatter` is the default — it is selected by
`TBaseNode.GetFormatter` and used by `TOutputNode` (the `OUTPUT` node) whenever
`--raw` is not set.

Three formatters exist:

| Formatter | Class | Output Style |
|---|---|---|
| Default | `TFormatter` | Human-readable with operator prefixes and alignment |
| Tree | `TTreeFormatter` | Indented tree hierarchy (box-drawing characters) |
| IR | `TIRFormatter` | Parser-friendly intermediate representation |

The tree and IR formatters are selected by `TTreeOutputNode` and `TIROutputNode`
respectively. This page covers the default formatter in detail.

## How Default Formatting Works

`TFormatter` extends `TCustomFormatter` and adds column tracking, dynamic width
calculation, and operator prefix handling. When it processes a tree, these
rules apply:

### 1. Operator Prefix

Integer nodes that carry an operator flag (set during the compute phase) are
displayed with that operator as a prefix: `+ 1`, `+ 2`, `- 5`, `* 3`. The
operator is extracted from the node's `TK_OPERATOR_MASK` bits.

A `^` (caret) prefix is also written when the `TK_CARET` bit is set on a node.

### 2. Repeated Operator Suppression

By default, `TFormatter.SuppressRepeatedRHSOperators` is `True`. When consecutive
RHS siblings share the same operator, redundant prefixes are suppressed. This
keeps output clean when multiple nodes carry identical operators.

### 3. Separator

Values are separated by the configured separator (default: single space).
`TFormatter.Write` appends a space after every non-empty value automatically.

### 4. Column Alignment

When column mode is active, `TFormatter` right-aligns values within each column.
It tracks widths per column index (up to 32 columns via `FColumnWidths`),
growing each column dynamically to fit the widest value seen so far. Padding is
applied on the left side of each value.

### 5. Dynamic Column Width

`FDynamicColWidth` defaults to `True`. The formatter performs **two passes**:
the first pass measures column widths without producing output; the second pass
writes the final aligned result. When disabled, a fixed column width of 12 is
used instead.

### 6. Multi-line Arrays

When an array has multiple rows (RHS siblings), `TFormatter` inserts a newline
and preserves the current indentation level. The `FNewLinePos` and
`ScopeStart` tracking ensures proper indentation for nested structures.

### 7. Composite Sibling Spacing

Before a composite sibling (special-category nodes like separators or variable
subtrees), `TFormatter` adds extra spacing to visually separate groups.

## Formatting Scopes

Different scope types are formatted with their delimiters:

| Scope | Syntax | Output |
|---|---|---|
| Expression | `( ... )` | Parenthesized: `( contents )` |
| Array | `[ ... ]` | Bracketed: `[ contents ]` |
| Evaluation | `{ ... }` | Curly-braced: `{ contents }` |
| Compute | `` ` ... ` `` | Backticked: `` ` contents ` `` |

Scopes are written recursively — the formatter processes children before
closing the delimiter.

## Formatting Special Nodes

### Separator (`,`)

Separators break content into multi-line rows. Each separator writes its LHS
column, then appends a comma and newline before continuing with the RHS chain.

### Index Lookup (`@`)

Index lookup nodes write their LHS target followed by `@`.

### Variable Subtree (`->`)

Variable subtree nodes write the variable reference, then `->`, then the bound
value columns. Multiple variable siblings produce multi-line output.

## Two-Pass Formatting

`TFormatter.WriteFormatted` implements a two-pass algorithm:

1. **First pass** — `Write(Index)` traverses the tree, measuring column widths
   and storing them in `FColumnWidths`. No output is retained.
2. **Reset** — `FOutput` is cleared, positions are reset.
3. **Second pass** — `Write(Index)` runs again, this time producing the final
   aligned output using the measured column widths.

This ensures that all values in a column are right-aligned to the widest entry
without knowing the width in advance.

## Format Configuration

`TFormatter` respects the `TFormatConfig` record defined in `formatters.pas`:

| Setting | Default | Purpose |
|---|---|---|
| `Offset` | `0` | Starting position in output buffer |
| `ColumnWidth` | `6` | Base column width for alignment |
| `Separator` | `' '` | Character between values |
| `NewLine` | `False` | Whether to append a newline after output |
| `Options` | `[]` | Additional formatting flags (e.g., `foFormatArrays`) |

The `DefaultFormat` constant provides these defaults. The `TFormatOption`
enumeration currently defines `foFormatArrays` for array-specific formatting.

## When Default Output Is Used

`TFormatter` is active when:

- No `--raw` flag is set (raw mode uses `TreeValue` directly)
- The output node is `TOutputNode` (not `TTreeOutputNode` or `TIROutputNode`)
- `TBaseNode.GetFormatter` is called without override

`TOutputNode.Execute` checks `GlobalExecutable.RunOptions.Raw` — if raw mode
is active and the node is `OBJ_OUTPUT`, it bypasses the formatter and outputs
the unformatted `TreeValue`. For all other cases, it creates a formatter,
calls `Formatted(Formatter)`, and emits the result.

## Examples

### Simple Array

Input:

```mantra
[ + 1 2 3 ]
```

Output:

```text
[ + 1 + 2 + 3 ]
```

Each integer node carries the `+` operator from the compute phase. The formatter
writes each operator prefix followed by the value.

### Compute Result

Input:

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

The backtick scope triggers compute, which reduces `1 + 2 + 3 = 6`. The result
node carries the `+` operator, so it is displayed as `+ 6`.

### Repeat Expansion

Input:

```mantra
`[ + 1 2 3 ] : 3`
```

Output:

```text
[ + 6 ] [ + 6 ] [ + 6 ]
```

The repeat operator clones the compute scope three times. Each clone independently
computes `1 + 2 + 3 = 6`, producing three identical array results.

### Variable Assignment

Input:

```mantra
x = [ + 1 + 2 + 3 ];
[ + 1 + 2 + 3 ]
```

Output:

```text
[ + 1 + 2 + 3 ]
```

The assignment statement stores the tree snapshot but produces no visible output.
Only the final expression generates output.

### Nested Expressions

Input:

```mantra
{ { [ 3 : 3 ] } }
```

Output:

```text
[ 3 3 3 ]
```

Evaluation scopes collapse inward. The inner `{ ... }` processes the repeat
`[ 3 : 3 ]` to produce `[ 3 3 3 ]`. The outer scope then collapses, leaving
the array as the final result.

### Operator Prefix on Integer Nodes

Input:

```mantra
` + 1 2 3 `
```

Output:

```text
+ 6
```

The computed integer node carries the operator `+` in its `TK_OPERATOR_MASK`
bits. The formatter extracts this and writes it as a prefix before the value.

### Mixed Operators

When a tree contains different operators, each node displays its own prefix:

```mantra
` + 1 * 2 3 `
```

The formatter walks each node independently, so operators are written per-node
rather than globally.

## Formatter Hierarchy

```
TCustomFormatter        — base class; writes raw strings and delegates WriteFormatted
├── TFormatter          — default: operator prefixes, columns, two-pass alignment
├── TTreeFormatter      — indented tree view with box-drawing characters
└── TIRFormatter        — debug IR with node indices, parent links, and depths
```

`TCustomFormatter` maintains an `FOutput` string buffer. Subclasses override
`Write` and `WriteFormatted` to customize behavior. The `TBaseNode.Formatted`
method creates a formatter, calls `WriteFormatted(Index)`, and returns the
result string.

## Related Pages

- [Output Formatting](../output-formatting.md)
- [Raw, Debug, and Token Output](raw-debug-token-output.md)
- [Compute Scope](../../compute/compute-scope.md)
