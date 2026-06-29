# Statement Output

Mantra executes source as statements. Every statement follows the same execution
lifecycle, but statements differ in whether and how they produce visible output.

---

## Statement Types

A statement is one of:

| Type | Example | Output? |
|---|---|---|
| **Setup** | `x = [ + 1 2 3 ]` | No (stores value) |
| **Output** | `print { x }` | Yes (explicit) |
| **Implicit** | `[ + 1 2 3 ]` | Only with `--debug` / `--raw` |

---

## Setup Statements

A setup statement stores a value, declares a rule, or configures the runtime
without producing user-facing output.

```mantra
x = [ + 1 2 3 ]
```

The runtime executes the statement, stores the result, and moves on. In the
default mode, no text is emitted to stdout.

### Setup With `--debug`

When the `--debug` flag is set, the runtime prints the result of **every**
statement — including setup statements — after execution. The output loop in
`parsetree.pas` checks whether the first node of a statement is an output node;
if it is not, and `--debug` is enabled, it formats and emits the result.

```bash
echo 'x = [ + 1 2 3 ]' | ./bin/mantra --debug
```

**Output:**
```
x [ + 1 2 3 ]
```

Without `--debug`, the same program produces no output at all.

---

## Output Statements

Output statements use explicit keywords that create output nodes in the AST:

| Keyword | Node | Formatter |
|---|---|---|
| `print` | `TOutputNode` (`OBJ_OUTPUT`) | Default (`TFormatter`) |
| `tree` | `TTreeOutputNode` (`OBJ_TREE_OUTPUT`) | `TTreeFormatter` |
| `ir` | `TIROutputNode` (`OBJ_IR_OUTPUT`) | `TIRFormatter` |

### Print

The most common output form. Evaluates its argument, formats it with the default
formatter, and writes the result.

```mantra
print 42
```

**Output:**
```
42
```

With an evaluation scope:

```mantra
x = [ + 1 2 3 ]
print { x }
```

**Output:**
```
[ + 1 2 3 ]
```

### Tree

Same behavior as `print`, but uses `TTreeFormatter` which shows the structural
tree view with indentation:

```mantra
tree { [ + 1 2 3 : 2 ] }
```

### IR

Uses `TIROutputNode` which produces a detailed intermediate representation dump.
Before formatting, it calls `Expand(Context)` and resolves variable references —
checking for `$` dollar references first, then falling back to normal variable
lookup in the context.

```mantra
x = + 1 2
ir x
```

Each `node=` line shows node index, parent pointer, depth, token ID, operator,
edges (`lhs`/`rhs`), and ref/data fields. `ir` is primarily useful for debugging
and inspecting the internal tree representation.

---

## How Output Works

### Execution

`TOutputNode.Execute` follows these steps:

1. **Evaluate children** — calls `inherited Execute(Context)`, which recursively
   evaluates all child (`LHS`) and sibling (`RHS`) nodes.
2. **Format** — obtains a formatter via `GetFormatter` (each output node type
   provides its own) and calls `Formatted(Formatter)` on the evaluated child.
3. **Emit** — calls `EmitRuntimeOutputLine` with the formatted string.

The three output node types differ only in their formatter:
- `TOutputNode` (print) uses the default `TFormatter`
- `TTreeOutputNode` (tree) uses `TTreeFormatter`
- `TIROutputNode` (ir) uses `TIRFormatter`

### No Duplicate Output

The execution loop detects whether a statement starts with an output node. If it
does, the runtime does **not** emit additional debug output for it — this avoids
duplicate lines when `--debug` is also enabled.

### Raw Mode

With `--raw`, `print` bypasses formatting entirely and uses `TreeValue` (the
unformatted string representation of the raw tree) instead:

```bash
echo 'print { 1 + 1 }' | ./bin/mantra --raw
```

**Output:**
```
+ 1 1
```

In raw mode, the tree structure is shown before any formatter decoration.

---

## Printf

`printf` provides C-style format string output with placeholder substitution. It
is implemented as `TPrintfNode` which extends `TOutputNode`.

### Format Verbs

| Verb | Type | Example |
|---|---|---|
| `%s` / `%S` | String | `printf "%s" [ "hello" ]` |
| `%d` / `%D` | Integer | `printf "%d" [ 42 ]` |
| `%f` / `%F` | Float | `printf "%f" [ 3.14 ]` |
| `%t` / `%T` | Tree | `printf "[%t]" [ 1 2 3 ]` |

The `%t` verb does not evaluate its argument by default — the raw tree is
printed. Wrapping the argument in `{ }` forces evaluation first.

### Printf Effects

`printf` can fire during different evaluation phases. Two runtime settings
control this:

| Setting | Default | Effect |
|---|---|---|
| `mantra.effects.display.evaluate` | `0` | Run printf during Evaluate phase |
| `mantra.effects.display.compute` | `0` | Run printf during Compute phase |

By default, `printf` only executes during the `Execute` phase. When effects are
enabled, printf nodes inside evaluation scopes or compute scopes fire during
those phases and delete themselves after output.

---

## Output Flow

### Statement Execution Loop

The runtime iterates over statements sequentially:

1. Get the statement node from the execution queue.
2. Check if the first node is an output node (`IsOutputNode`).
3. Execute the statement via `Node.Execute(Context)`.
4. If `--debug` / `--debug-ir` is set **and** the statement does not start with
   an output node, emit additional debug output.
5. Move to the next statement (or newly added statements if the queue grew).

### Output Sinks

Output goes through `EmitRuntimeOutputLine`, which checks for a configured
`RuntimeOutputSink`. If none is set, it falls back to `WriteLn`. This allows
the MCP server and other integrations to capture output programmatically.

---

## Print vs Implicit Output

| | `print` | Implicit (last expression) |
|---|---|---|
| Always fires | Yes | No (only with `--debug`) |
| Controlled | Selective | All statements |
| Use case | End-user programs | Interactive exploration |

`print` is intentional output that always fires regardless of debug flags. It is
the recommended way to produce output in programs designed for end users.

Implicit output (printing the last expression) only appears with `--debug` or
`--raw`. Without these flags, a bare expression like `[ + 1 2 3 ]` produces no
visible output.

---

## Examples

### Basic print

```mantra
print 42
```

**Output:** `42`

### Print with evaluation scope

```mantra
name = "Alice"
print { name }
```

**Output:** `Alice`

### Multiple print statements

```mantra
print 1
print 2
print 3
```

**Output:**
```
1
2
3
```

### Print inside a container

```mantra
print [ 1 2 3 : 2 ]
```

**Output:** `[ 1 2 3 1 2 3 ]`

The repeat `1 2 3 : 2` is evaluated before formatting.

### Printf with multiple formats

```mantra
printf "%s is %d years old" [ "Bob" 25 ]
```

**Output:** `Bob is 25 years old`

---

## Related Pages

- [Print and Output](../../evaluation/evaluation-scopes/print-output.md)
- [Output Formatting](../../evaluation/output-formatting.md)
- [Evaluation vs Compute](evaluation-vs-compute.md)
- [Reading Runtime Output](../../getting-started/reading-runtime-output.md)
