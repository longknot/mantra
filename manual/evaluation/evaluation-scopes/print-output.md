# Print and Output

`print` is the explicit mechanism for producing output from a Mantra program. It
takes one or more expressions, evaluates them, formats the result, and writes it
to the output stream.

## Syntax

```
print expression
print { expression }
```

`print` accepts a single expression (its `LHS` child) and zero or more sibling
expressions (linked via `RHS`). Each child is evaluated independently before
formatting.

```mantra
print 42;
print { 1 + 1 };
```

**Output:**
```
42
2
```

## How It Works

The `print` keyword creates a `TOutputNode` (`OBJ_OUTPUT`) in the AST. During
execution, `TOutputNode.Execute` performs these steps:

1. **Evaluate children** — calls `inherited Execute(Context)`, which recursively
   evaluates all child (`LHS`) and sibling (`RHS`) nodes.
2. **Format** — obtains a formatter via `GetFormatter` (default formatter) and
   calls `Formatted(Formatter)` on each evaluated child.
3. **Emit** — calls `EmitRuntimeOutputLine` with the formatted string, which
   writes to stdout (or the configured output sink).

### Raw Mode

With `--raw`, `print` bypasses formatting entirely and uses `TreeValue`
(string representation of the raw tree) instead:

```bash
./bin/mantra --raw <<< 'print { 1 + 1 }'
```

**Output:**
```
+ 1 1
```

In raw mode, the compute result is not collapsed — the tree structure is shown
before reduction.

## Print Variants

Mantra provides three output keywords that differ only in their formatter:

| Keyword | Node | Formatter | Use |
|---|---|---|---|
| `print` | `TOutputNode` (`OBJ_OUTPUT`) | Default | General output |
| `tree` | `TTreeOutputNode` (`OBJ_TREE_OUTPUT`) | `TTreeFormatter` | Structural tree view |
| `ir` | `TIROutputNode` (`OBJ_IR_OUTPUT`) | `TIRFormatter` | Intermediate representation |

### `tree` Output

`tree` uses `TTreeFormatter` which shows the tree structure explicitly:

```mantra
tree { 1 2 3 : 2 };
```

**Output:**
```
[ 1 2 3 1 2 3 ]
```

### `ir` Output

`ir` uses `TIRFormatter` and produces a detailed intermediate representation
dump. Before formatting, it first calls `Expand(Context)` and then resolves
variable references — it checks for `$` dollar references first, then falls
back to normal variable lookup in the context.

The output format is a structured node dump:

```mantra
x = + 1 2;
ir x;
```

**Output:**
```
root=8
node=8 parent=2147483647 depth=0 id=68 id_token="68" op=65536 lhs=2147483647 rhs=9 ref=3 data=0x00010044 ref_token="1"
node=9 parent=2147483647 depth=0 id=68 id_token="68" op=65536 lhs=2147483647 rhs=2147483647 ref=4 data=0x00010044 ref_token="2"
```

Each `node=` line shows the node index, parent pointer, depth, token ID,
operator, edges (`lhs`/`rhs`), and ref/data fields. `parent=2147483647`
(`EOT`) means "no parent." `ir` is primarily useful for debugging and
inspecting the internal tree representation.

## `printf` — Formatted Output

`printf` provides C-style format string output with placeholder substitution.

### Syntax

```mantra
printf "format string" arguments
printf { fmt "format string" arguments }
```

### Format Verbs

| Verb | Type | Example |
|---|---|---|
| `%s` / `%S` | String | `printf "name: %s" [ "Alice" ]` → `name: Alice` |
| `%d` / `%D` | Integer | `printf "count: %d" [ 42 ]` → `count: 42` |
| `%f` / `%F` | Float | `printf "value: %f" [ 3.14 ]` → `value: 3.14` |
| `%t` / `%T` | Tree | `printf "[%t]" [ 1 2 3 ]` → `[1 2 3]` |

### Arguments

`printf` accepts arguments in two forms:

1. **Array** — a single array containing all arguments:
   ```mantra
   printf "%s %d" [ "hello" 42 ];
   ```

2. **Individual** — arguments passed directly:
   ```mantra
   printf "name: %s" [ "world" ];
   ```

The number of format verbs must match the number of arguments. A mismatch raises
a runtime error: `fmt expected N arguments but got M`.

### Tree Format (`%t`)

The `%t`/`%T` verb outputs the tree structure of an argument:

```mantra
r = + ( + m n ) : + 1;
printf "raw=%t" r;
printf "eval=%t" { r };
```

**Output:**
```
raw=+ ( + m + n ) : + 1
eval=+ ( + m + n )
```

Note: `%t` does not evaluate its argument by default — the raw tree is printed.
Wrapping the argument in `{ }` forces evaluation first.

### printf Effects

`printf` can fire during different evaluation phases. By default, it only
executes during the `Execute` phase. Two runtime settings control behavior:

| Setting | Default | Effect |
|---|---|---|
| `mantra.effects.display.evaluate` | `0` | Run printf during Evaluate phase |
| `mantra.effects.display.compute` | `0` | Run printf during Compute phase |

```mantra
mantra.effects.display.evaluate = 1;
{ printf "eval %d" [ 7 ] };
```

**Output:**
```
mantra.effects.display.evaluate = 1
{ printf "eval %d" [ 7 ] }
eval 7
```

When `mantra.effects.display.evaluate = 1`, printf nodes inside evaluation
scopes execute during the `Evaluate` phase and delete themselves after output.
When `mantra.effects.display.compute = 1`, printf inside compute scopes
(`~`) executes during the `Compute` phase.

Without these settings enabled, printf inside scopes is skipped:

```mantra
{ printf "eval %d" [ 7 ] };
{ ~ printf "compute %d" [ 8 ] };
print "done";
```

**Output:**
```
{ printf "eval %d" [ 7 ] }
{ ~ printf "compute %d" [ 8 ] }
print "done"
done
```

## Output Flow

### Statement Execution

The runtime iterates over statements. For each statement:

1. If it starts with `print`, `tree`, or `ir`, the node's own `Execute` method
   handles output. The runtime does **not** emit additional debug output for it.
2. For other statements, debug output (`--debug`, `--raw`) prints the result
   automatically.

This means `print` is primarily useful when you want controlled, selective output
rather than printing every statement's result.

### Output Sinks

Output goes through `EmitRuntimeOutputLine`, which checks for a configured
`RuntimeOutputSink`. If none is set, it falls back to `WriteLn`. This allows
the MCP server and other integrations to capture output programmatically.

### Rich Output

Structured output (JSON, CSV) uses `EmitRuntimeJsonOutput` with MIME types:

```pascal
EmitRuntimeJsonOutput('application/json', jsonData);
```

This path is used by `render`, `json_encode`, and similar output keywords that
produce structured data rather than plain text.

## Examples

### Basic Print

```mantra
print 42;
```

**Output:**
```
42
```

### Print with Evaluation

```mantra
print { 1 + 2 * 3 };
```

**Output:**
```
+ 1 * 2 3
```

### Print with Variables

```mantra
name = "Alice";
print { name };
```

**Output:**
```
Alice
```

### Print with Rules

```mantra
rule f [
  f x => x
];

print { f 7 };
```

**Output:**
```
7
```

### Multiple Print Statements

```mantra
print "First";
print { 1 + 1 };
print "Last";
```

**Output:**
```
print "First"
print { 1 + 1 }
print "Last"
First
2
Last
```

Note: Each statement is echoed as `INPUT:` before its output. This is the
default runtime behavior — the source line appears, followed by the result.

### Print Inside a Container

```mantra
print [ 1 2 3 : 2 ];
```

**Output:**
```
[ 1 2 3 1 2 3 ]
```

The repeat `1 2 3 : 2` is evaluated before formatting.

### Printf with Multiple Formats

```mantra
printf "%s is %d years old" [ "Bob" 25 ];
```

**Output:**
```
Bob is 25 years old
```

### Printf with Tree Output

```mantra
printf "[%t]" { + x ? y : 2 };
```

**Output:**
```
[]
```

The evaluation scope resolves to empty (unbound variables), so `%t` renders
an empty tree.

## Print vs Implicit Output

Without `print`, Mantra still produces output through debug modes:

- **`--debug`** — prints every statement's result after execution
- **`--raw`** — prints unformatted `TreeValue` instead of `Formatted`
- **`--show-input`** — prefixes each statement with `> source`

`print` is intentional output that always fires regardless of debug flags. It
is the recommended way to produce output in programs designed for end users.

## Related Pages

- [Evaluation Scopes](../evaluation/evaluation-scopes.md)
- [Compute Scopes](../compute/compute-scope.md)
- [Rendering Structured Output](../data/rendering-structured-output.md)
- [Reading Runtime Output](../getting-started/reading-runtime-output.md)
- [Debugging Evaluation Behavior](debugging-evaluation-behavior.md)
