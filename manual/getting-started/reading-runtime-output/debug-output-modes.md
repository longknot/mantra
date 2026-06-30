# Debug Output Modes

Mantra provides several output modes for inspecting what the runtime is doing at
each stage of the pipeline. They let you see the source text, token stream, AST
structure, and statement-by-statement evaluation results.

These flags are independent and can be combined. They are most useful while
writing test fixtures, debugging unexpected parse results, or tracing evaluation
behavior.

## Pipeline Overview

Every Mantra program passes through these stages before producing output:

```
Source Text -> Tokenizer -> Parser (AST) -> Evaluation -> Formatter -> Output
```

The debug flags let you peek at each stage:

| Stage | Flag | What you see |
|---|---|---|
| Source text | `--show-input` | Each input line with `>` prefix |
| Tokenizer | `--show-tokens` | Token stream with positions |
| Parser (AST) | `--debug-ir` | Intermediate representation of the tree |
| Evaluation | `--debug` | Every statement result, not just the last |
| Formatter | `--raw` | Unformatted tree values instead of pretty print |
| Post-format | `--eval` | Additional evaluation pass on output |

## `--show-input` and `--input`

Shows each input line prefixed with `>` before the runtime processes it. Both
`--show-input` and `--input` are accepted as flags.

```bash
mantra --show-input program.m
```

Useful for multi-line programs where you want to correlate each output line with
the specific input that produced it.

### Example

```bash
# tests/cases/boolean_and_compute
mantra --show-input tests/cases/boolean_and_compute.in
```

Input (`boolean_and_compute.in`):

```mantra
{ ~ and 1 2 3 }
```

Output:

```
> { and 1 and 2 and 3 }
```

The `>` prefix line shows the parsed tree value of the statement before
evaluation begins.

## `--show-tokens`

Prints the tokenizer output during compilation. Displays each token with its
text value and source position.

```bash
mantra --show-tokens program.m
```

### Output format

Each token appears as `[ <text> @<line>:<col> ]` separated by spaces:

```
[ print @1:1 ] [ { @1:7 ] [ 1 @1:9 ] [ } @1:11 ]
```

For the source line `print { 1 }`:

- `print` at line 1, column 1
- `{` at line 1, column 7
- `1` at line 1, column 9
- `}` at line 1, column 11

### Example from test fixture

```bash
# tests/cases/show_tokens_line_col
mantra --show-tokens tests/cases/show_tokens_line_col.in
```

Input:

```mantra
print { 1 }
```

Output:

```
[ print @1:1 ] [ { @1:7 ] [ 1 @1:9 ] [ } @1:11 ]
1
```

The token line is emitted first, then the normal program output follows. Use
this to debug tokenizer-level issues like unexpected whitespace handling or
operator grouping.

## `--debug` and `-d`

Prints every statement output, including intermediate results that would
normally be suppressed. This is the primary flag for inspecting the full
execution trace.

```bash
mantra --debug program.m
mantra -d program.m
```

### How it works

By default, Mantra only prints the output of `print` statements and the final
result of the last expression. With `--debug`, the runtime prints the result of
every statement it executes, not just output nodes.

In the execution loop (`parsetree.pas`), after each statement runs:

1. If the statement starts with an output node (e.g., `print`), its output is
   printed normally.
2. If `--debug` is enabled and the statement is NOT an output node, its result
   is printed additionally.

This means `--debug` adds visibility for intermediate computations without
duplicating output from explicit `print` statements.

### Internal flag

In the source, this sets `TRunOptions.DebugOutput := True`.

### Deprecated alias

`--print` and `-p` behave identically but emit a deprecation warning on
stderr. Migrate to `--debug` / `-d`.

## `--debug-ir`

Prints a parser-friendly intermediate representation for each non-output
statement. Shows the AST shape after parsing but before evaluation.

```bash
mantra --debug-ir program.m
```

### Output format

Each node is shown with its properties:

```
root=0
node=0 parent=2147483647 depth=0 id=2 id_token="..." op=0 lhs=2 rhs=2147483647 ref=0 data=0x00000002 ref_token="{"
node=2 parent=0 depth=1 id=68 id_token="68" op=0 lhs=2147483647 rhs=2147483647 ref=8 data=0x00000044 ref_token="1"
```

Key fields:

| Field | Description |
|---|---|
| `node` | Node index in the tree |
| `parent` | Parent node index (2147483647 = `MaxInt` = `EOT` = no parent) |
| `depth` | Nesting depth from root |
| `id` | Node type identifier (maps to `OBJ_*` constants) |
| `id_token` | Token name for the node type |
| `op` | Operator byte field |
| `lhs` | Left child index (or `EOT` for leaf) |
| `rhs` | Right sibling index (or `EOT` for last sibling) |
| `ref` | Index into expression token storage |
| `ref_token` | The actual token text from source |

The value `2147483647` (i.e., `MaxInt` / `EOT`) is the sentinel for "no link" —
it appears where a node has no parent, left child, or right sibling.

### When to use

Use `--debug-ir` when you need to confirm how Mantra parsed a specific
expression before any evaluation or rewriting occurs. It reveals the exact
tree structure the parser produced, which helps diagnose cases where the AST
shape differs from expectations.

## `--raw`

Prints unformatted `TreeValue` output instead of the pretty-printed result.

```bash
mantra --raw program.m
```

### When to use

- Comparing exact tree structure across runs
- Scripting output parsing where you need a stable, non-formatted representation
- When the formatter adds visual noise that obscures the actual data

### Combining with `--debug`

When `--raw` and `--debug` are both enabled, the debug output for non-output
statements also uses the raw `TreeValue` format instead of the formatted version.

## `--eval` and `-e`

Evaluates the output tree before printing. When enabled, the final result is
passed through another evaluation pass, so computed expressions are reduced and
variables are resolved in the displayed output.

```bash
mantra --eval program.m
mantra -e program.m
```

### Example

```bash
# With --eval, computed expressions in output are reduced
mantra --eval --eval='+ 1 2'
```

The `--eval=EXPR` form (without the `-e` flag) appends and runs an expression
after loading the program.

## Combining Output Flags

All output inspection flags work independently and can be combined:

```bash
# Show tokens, input, and all statement output
mantra --show-tokens --show-input --debug program.m

# Raw tree output with debug IR
mantra --raw --debug-ir program.m

# Tokenize and evaluate output
mantra --show-tokens --eval program.m

# Full debugging of a failing program
mantra --debug --debug-ir --show-tokens program.m
```

## When to Use Each Flag

| Scenario | Recommended flag(s) |
|---|---|
| Tokenizer producing unexpected results | `--show-tokens` |
| Tree structure differs from expectations | `--debug-ir` |
| Intermediate results being suppressed | `--debug` |
| Output not fully evaluated | `--eval` |
| Multi-line program — which line produced what? | `--show-input` |
| Scripting — need parseable, stable output | `--raw` |
| Writing test fixtures | `--debug` or `--raw` |
| Full investigation of a failing program | `--debug --debug-ir --show-tokens` |

## Internal Implementation

The flags correspond to boolean fields in `TRunOptions` (defined in
`mathparser.pas`):

| Flag | `TRunOptions` field | Default |
|---|---|---|
| `--raw` | `Raw` | `False` |
| `--debug` / `-d` | `DebugOutput` | `False` |
| `--debug-ir` | `DebugIR` | `False` |
| `--show-input` / `--input` | `ShowInput` | `False` |
| `--show-tokens` | `ShowTokens` | `False` |
| `--eval` / `-e` | `EvalOutput` | `False` |

The execution loop in `parsetree.pas` processes each statement and checks these
flags to decide what to emit. The `--debug` and `--debug-ir` modes specifically
skip output nodes (like `print`) to avoid duplicating their output.
