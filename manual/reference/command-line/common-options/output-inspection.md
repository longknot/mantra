# Output Inspection

These flags expose the tokenizer, parser, formatter, and execution pipeline so
you can inspect what Mantra is doing at each stage. They are useful for
debugging unexpected parse results, verifying tree structure, and tracing
statement-by-statement evaluation.

## `--raw`

```bash
mantra --raw program.m
```

Prints unformatted `TreeValue` output instead of the pretty-printed result. Use
this to compare exact tree structure or to script output parsing where you need
a stable, non-formatted representation.

## `--debug` and `-d`

```bash
mantra --debug program.m
mantra -d program.m
```

Prints every statement output, including intermediate results that would
normally be internal. This is the primary flag for inspecting the full
execution trace — every expression that Mantra evaluates will be printed, not
just the final result.

**Deprecated alias:** `--print` and `-p` behave identically but emit a
deprecation warning on stderr. Migrate to `--debug` / `-d`.

## `--debug-ir`

```bash
mantra --debug-ir program.m
```

Prints a parser-friendly intermediate representation for each non-output
statement. Shows the AST shape after parsing but before evaluation, making it
easier to verify the parser produced the expected tree structure.

The IR output shows node types, source positions, and child relationships. Use
this when you need to confirm how Mantra parsed a specific expression before
any evaluation or rewriting occurs.

## `--show-input` and `--input`

```bash
mantra --show-input program.m
mantra --input program.m
```

Shows each input line prefixed with `>` before processing. Both `--show-input`
and `--input` are accepted. Useful for multi-line programs where you want to
correlate output with the specific input line that produced it.

## `--show-tokens`

```bash
mantra --show-tokens program.m
```

Shows the tokenizer output during compilation. Displays each token with its
text value and source position in the format `[ token @line:col ]`. Use this
to debug tokenizer-level issues such as unexpected whitespace handling or
operator grouping.

### Output format

Each token is shown as `[ <text> @<line>:<col> ]` separated by spaces:

```
[ print @1:1 ] [ { @1:7 ] [ 1 @1:9 ] [ } @1:11 ]
```

This corresponds to the source line `print { 1 }`, where:
- `print` is at line 1, column 1
- `{` is at line 1, column 7
- `1` is at line 1, column 9
- `}` is at line 1, column 11

### Example from test fixture

```bash
# tests/cases/show_tokens_line_col.args
--show-tokens
```

```mantra
# tests/cases/show_tokens_line_col.in
print { 1 }
```

Output:
```
[ print @1:1 ] [ { @1:7 ] [ 1 @1:9 ] [ } @1:11 ]
1
```

The token line is emitted first, then the normal program output follows.

## `--eval` and `-e`

```bash
mantra --eval program.m
mantra -e program.m
```

Evaluates output before printing. When enabled, the final result tree is passed
through another evaluation pass, so computed expressions are reduced and
variables are resolved in the displayed output.

## Combining Output Flags

All output inspection flags work independently and can be combined:

```bash
# Show tokens, input, and all statement output
mantra --show-tokens --show-input --debug program.m

# Raw tree output with debug IR
mantra --raw --debug-ir program.m

# Tokenize and evaluate output
mantra --show-tokens --eval program.m

# Raw output with inline expression
mantra --raw --eval='+ 1 2'
```

## When to Use

| Scenario | Recommended flag(s) |
|---|---|
| Why is my expression not parsing as expected? | `--show-tokens` to verify tokenization |
| Why is the tree structure wrong? | `--debug-ir` to inspect the AST before evaluation |
| Why is intermediate output being suppressed? | `--debug` to see every statement |
| Why isn't output evaluated? | `--eval` to force evaluation |
| Multi-line programs — which line produced which output? | `--show-input` to correlate input with output |
| Scripting — need stable, parseable output? | `--raw` for unformatted tree values |
| Full debugging of a failing program | `--debug --debug-ir --show-tokens` |

## Internal Behavior

The output inspection flags set options in `TRunOptions`:

- `Raw` — when `True`, bypasses the formatter and prints raw `TreeValue`
- `DebugOutput` — when `True`, prints every statement's output (not just the last)
- `DebugIR` — when `True`, prints IR for non-output statements after parsing
- `ShowInput` — when `True`, prefixes each input line with `>` before processing
- `ShowTokens` — when `True`, prints token stream after tokenization
- `EvalOutput` — when `True`, runs an additional evaluation pass on output

The tokenizer (`exp_tokenizer.pas`) and parser (`mathparser.pas`) emit their
debug output to standard output. The `--debug` flag controls the execution
loop in `nodes.pas`, where each statement's result is conditionally printed.
