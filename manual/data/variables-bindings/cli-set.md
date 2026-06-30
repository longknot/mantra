# CLI Set

`--set NAME=EXPR` predefines a variable before any source code executes. The
variable is available immediately in the first statement of the program.

## Syntax

Two equivalent CLI forms:

```bash
mantra --set NAME=EXPR program.m
mantra --set=NAME=EXPR program.m
```

- `NAME` — variable identifier (must not be empty)
- `EXPR` — any Mantra expression (parsed as source text)
- The flag is **repeatable** — use `--set` multiple times to define several
  variables

```bash
mantra --set x=5 --set y=10 program.m
```

The short form `--set=` and the long form `--set` (space-separated) accept the
same `NAME=EXPR` argument and are interchangeable.

## Examples

### Integer Value

```.args
--set x=5
```

```mantra
print { x }
```

Expected `OUTPUT`:

```text
5
```

### Tree Structure

```.args
--set x=[+1+2+3]
```

```mantra
print `x`
```

Expected `OUTPUT`:

```text
[ + 6 ]
```

The expression `[+1+2+3]` is parsed as a tree structure. The variable `x` holds
that tree, and the `` ` `` compute scope reduces it to `[ + 6 ]`.

### Repeat Count

```.args
--set n=3
```

```mantra
print { [ 7 ] : n }
```

Expected `OUTPUT`:

```text
[ 7 ] [ 7 ] [ 7 ]
```

The `--set` variable can drive repeat operators, selection rules, inference
parameters, and any other context that resolves variables.

### String and Complex Expressions

```bash
mantra --set rules='[ x => x + 1 ]' program.m
```

Quoted shell expressions let you pass multi-token Mantra structures. The value
is parsed as Mantra source, not as a literal string.

## Execution Order

`--set` variables are initialized **before** the source file executes. The
runtime processes them in this order:

1. Parse each `--set NAME=EXPR` argument from the CLI.
2. For each assignment, compile and execute a synthetic statement `. NAME=EXPR`
   that binds the variable.
3. Compile the source file (or stdin input).
4. Execute the source file statements.
5. Process any `--eval=EXPR` expressions after source execution.

This means `--set` variables are available in the first line of your program.
Later assignments in the source can overwrite them.

## Assignment Path

`--set` uses the same assignment mechanism as `x = EXPR` in script code. Each
`--set NAME=EXPR` is compiled as a synthetic statement that goes through
`TAssignmentNode` — the RHS subtree is cloned into the variable context. This
means `--set` inherits the same behaviors:

- The expression is **parsed** as Mantra source (not evaluated immediately).
- The parsed tree is **cloned** into the variable context.
- Variable lookup later **substitutes** by cloning the stored tree.

For details on assignment behavior, see [Assignment](assignment.md).

## Repeatable Flag

Multiple `--set` flags are processed left to right. Later definitions of the
same variable name overwrite earlier ones:

```bash
mantra --set x=1 --set x=2 program.m
```

In this case, `x` resolves to `2` when the program runs.

## Error Handling

```.args
--set =5
```

If the variable name is missing (empty string before `=`), the runtime raises:

```
Invalid --set argument: =5 (expected NAME=EXPR)
```

```.args
--set
```

If `--set` has no value at all (missing `NAME=EXPR`), the runtime raises:

```
Missing value for --set (expected NAME=EXPR)
```

## Interactive Mode

In `--interactive` mode, `--set` variables are compiled and executed before the
REPL prompt appears. They persist as context variables throughout the session.

```.args
--set x=42
--interactive
```

The variable `x` is pre-defined when the interactive prompt starts.

## Use Cases

- **Parameterized testing** — run the same program with different inputs via
  `.args` files: `.args` with `--set n=1`, `--set n=2`, etc.
- **Repeat counts** — drive `:` repeat operators with external values
  (`--set n=5`).
- **Rule injection** — pass selection rules or transform sets from the CLI
  (`--set rules='[ x => x + 1 ]'`).
- **Configuration** — set runtime settings like
  `--set mantra.inference.profile=true` or
  `--set mantra.inference.policy="cost"`.

## See Also

- [Assignment](assignment.md) — Variable assignment in script code
- [Variable Substitution](variable-substitution.md) — How variables resolve at
  runtime
- [Evaluation Scopes](../../evaluation/evaluation-scopes.md) — How `{ }` scopes
  trigger variable substitution
- [Test Fixture Args Files](../../reference/test-fixture-guide/args-files.md) —
  Using `.args` with `--set` in tests
