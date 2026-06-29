# Evaluation and Variables

These flags control whether output is evaluated before printing and let you
inject expressions or predefine variables from the command line.

## `--eval` / `-e`

```bash
./bin/mantra --eval program.m
./bin/mantra -e program.m
```

Evaluates the output tree before printing. Without `--eval`, Mantra prints the
output tree as-is, which may contain unevaluated expressions.

A program that produces `+ 1 2` will print the arithmetic form literally.
With `--eval`, compute scopes resolve the arithmetic:

```bash
$ echo '+ 1 2' | ./bin/mantra
+ 1 2
$ echo '+ 1 2' | ./bin/mantra --eval
+ 1 2
```

Note: `--eval` only triggers evaluation of scopes that the formatter encounters.
For expressions that need explicit computation, wrap them in a compute scope
(\` \`):

```bash
$ echo '` + 1 2 `' | ./bin/mantra
+ 3
```

Without a compute scope, the tree structure is preserved even with `--eval`.

## `--eval=EXPR`

```bash
./bin/mantra --eval='+ 1 2'
```

Appends `print { EXPR }` to the compiled source and runs it after all source
statements have executed. This lets you experiment with expressions from the
command line without writing a file.

The expression is wrapped in `{ }` (evaluation scope) so that variable
substitution and compute operations resolve before printing.

You can repeat `--eval=` multiple times to run several expressions sequentially.
They execute in left-to-right order, each wrapped in its own `print { ... }`
call:

```bash
./bin/mantra --eval='+ 1 2' --eval='* 3 4'
```

`--eval=EXPR` also has access to variables defined by `--set`:

```bash
./bin/mantra --set n=5 --eval='+ n 1'
```

### Examples

**Expression experiment:**

```bash
$ ./bin/mantra --eval='+ 1 2'
3
```

**Variable reference (from test fixture `cli_eval_expr_append`):**

```bash
$ ./bin/mantra --eval=x
[ + 1 + 2 + 3 ]
```

Input source:

```mantra
x = [ + 1 2 3 ]
```

The `--eval=x` appends `print { x }` after the source runs. The variable `x`
holds the tree `[ + 1 2 3 ]`, which is printed as-is since there is no compute
scope to reduce the arithmetic.

**Calling package functions:**

```bash
$ ./bin/mantra tests/modules/pkg_main_import_utils_cat.m --eval='utils.cat [ 1 2 3 ] [ 4 5 6 ] [ 7 ]'
[ 1 2 3 4 5 6 7 ]
```

(From test fixture `package_import_utils_cat_eval_expr`.)

## `--set NAME=EXPR`

```bash
./bin/mantra --set x=5 program.m
```

Predefines a variable in the runtime context before source execution begins.
The variable is available to all statements in the program.

### Syntax

Two equivalent CLI forms:

```bash
./bin/mantra --set NAME=EXPR program.m      # space-separated
./bin/mantra --set=NAME=EXPR program.m      # compact form
```

- `NAME` — variable identifier (must not be empty)
- `EXPR` — any Mantra expression (parsed as source text, not a literal string)
- The flag is **repeatable** — use `--set` multiple times to define several
  variables

```bash
./bin/mantra --set x=5 --set y=10 --set rules='[ x => x + 1 ]' program.m
```

### Examples

**Integer value (from test fixture `cli_set_integer_lookup`):**

```bash
$ ./bin/mantra --set x=5
print { x }
5
```

Input source:

```mantra
print { x }
```

**Tree structure (from test fixture `cli_set_expression_compute`):**

```bash
$ ./bin/mantra --set x=[+1+2+3]
print `x`
[ + 6 ]
```

Input source:

```mantra
print `x`
```

The expression `[+1+2+3]` is parsed as a tree structure. The variable `x`
holds that tree, and the `` ` `` compute scope reduces it to `[ + 6 ]`.

**Repeat count (from test fixture `cli_set_repeat_count`):**

```bash
$ ./bin/mantra --set n=3
print { [ 7 ] : n }
[ 7 ] [ 7 ] [ 7 ]
```

Input source:

```mantra
print { [ 7 ] : n }
```

The `--set` variable drives the `:` repeat operator.

### Expression Parsing

`--set` values are **parsed as Mantra source**, not stored as literal strings.
This means:

- Numbers are parsed as integer/float nodes: `--set x=5` stores an integer node.
- Tree structures are parsed into AST: `--set x=[+1+2+3]` stores a tree.
- Shell quoting is needed for multi-token expressions:
  `--set rules='[ x => x + 1 ]'`.

The parsed tree is cloned into the variable context. Later variable lookups
substitute by cloning the stored tree.

### Execution Order

`--set` variables are initialized **before** the source file executes. The
runtime processes arguments in this order:

1. Parse each `--set NAME=EXPR` argument from the CLI.
2. For each assignment, compile and execute a synthetic statement that binds
   the variable through `TAssignmentNode`.
3. Compile the source file (or stdin input).
4. Execute the source file statements.
5. Process any `--eval=EXPR` expressions after source execution.

This means `--set` variables are available in the first line of your program.
Later assignments in the source can overwrite them.

### Overwriting Behavior

Multiple `--set` flags are processed left to right. Later definitions of the
same variable name overwrite earlier ones:

```bash
./bin/mantra --set x=1 --set x=2 program.m
```

In this case, `x` resolves to `2` when the program runs.

Source code can also overwrite `--set` variables:

```bash
$ ./bin/mantra --set x=5
x = 10
print { x }
10
```

### Error Handling

**Missing variable name:**

```bash
$ ./bin/mantra --set =5 program.m
Error: Invalid --set argument: =5 (expected NAME=EXPR)
```

**Missing value entirely:**

```bash
$ ./bin/mantra --set program.m
Error: Missing value for --set (expected NAME=EXPR)
```

**Missing expression in `--eval=`:**

```bash
$ ./bin/mantra --eval=
Error: Invalid --eval=EXPR argument: missing expression
```

### Interactive Mode

In `--interactive` mode, `--set` variables are compiled and executed before the
REPL prompt appears. They persist as context variables throughout the session:

```bash
./bin/mantra --set x=42 --interactive
```

The variable `x` is pre-defined when the interactive prompt starts.

### Use Cases

- **Parameterized testing** — run the same program with different inputs via
  `.args` files: `--set n=1`, `--set n=2`, etc.
- **Repeat counts** — drive `:` repeat operators with external values
  (`--set n=5`).
- **Rule injection** — pass selection rules or transform sets from the CLI
  (`--set rules='[ x => x + 1 ]'`).
- **Configuration** — set runtime settings like
  `--set mantra.inference.profile=true` or
  `--set mantra.inference.policy="cost"`.
- **Quick experiments** — combine `--set` with `--eval=` to test expressions
  without writing files:
  `./bin/mantra --set n=10 --eval='+ n 1'`.

## Combining with Other Flags

Evaluation and variable flags work with all output inspection and input flags:

```bash
# Debug output with pre-defined variables
./bin/mantra --debug --set n=10 --eval='+ n 1'

# Raw output with inline expression
./bin/mantra --raw --eval='[ 1 2 3 : 4 ]'

# Evaluate output and inject a variable
./bin/mantra --eval --set x=5 program.m
```

## See Also

- [Assignment](../../data/variables-bindings/assignment.md) — Variable assignment
  in script code
- [CLI Set](../../data/variables-bindings/cli-set.md) — Detailed --set reference
- [Evaluation Scopes](../../evaluation/evaluation-scopes.md) — How `{ }` scopes
  trigger variable substitution
- [Output Inspection](output-inspection.md) — `--debug`, `--raw`, and other
  output flags
- [Test Fixture Args Files](../../reference/test-fixture-guide/args-files.md) —
  Using `.args` with `--set` in tests
