# Local Scopes

Local scopes let you create variables that are visible only within a `scope { ... }`
block and are destroyed when the block exits. They are implemented via **exact scope
frames** — isolated name-to-value maps pushed onto a stack and popped when the scope
ends.

## Quick Reference

| Construct | Purpose |
|---|---|
| `scope { ... }` | Create a local scope with isolated variables |
| `scope { ... } "label"` | Named scope (label for debugging/inspection) |
| `global name = value` | Export a value from scope to global store |
| Nested `scope` | Inner scope shadows outer; outer resumes after inner exits |
| Last expression | Scope body's last expression is returned as the scope result |

## Related Pages

- [Global and Dotted Names](local-scopes/global-dotted-names.md) — `global` directive and dotted-path storage
- [Query Helpers](local-scopes/query-helpers.md) — `get`, `query_children`, path access
- [Variables and Bindings](variables-bindings.md) — Variable storage, assignment, and namespace resolution
- [Evaluation Scopes](evaluation/evaluation-scopes.md) — `{ ... }` evaluation scopes
- [Compute Scope](compute/compute-scope.md) — `` ` ... ` `` compute scopes

---

## Syntax

```mantra
scope { statements... }
scope { statements... } "label"
```

The `scope` keyword must be followed by a `{ ... }` body. The body contains
comma-separated statements. An optional string or identifier label can follow
the closing brace for debugging and inspection purposes.

```mantra
scope { x = 5, print { x } }
```

Variables assigned inside the scope are stored in the scope frame, not in the
global variable trie. Dotted names are rejected — scope frames only accept
flat identifiers.

## How Scope Frames Work

When the runtime evaluates a `scope` statement, it:

1. **Pushes** a new exact scope frame (`TExactScopeFrame`)
2. **Evaluates** the body statements inside the scope
3. **Pops** the scope frame, destroying all local bindings

Each frame is a `TStringList` with sorted, case-insensitive entries. The
`TContext` maintains a stack of frames (`FExactScopeFrames`) — lookup walks
from innermost to outermost, so nested scopes shadow outer bindings.

## Variable Resolution Order

When resolving a variable name, the runtime checks in this order:

1. **Exact scope frames** (innermost to outermost) — flat identifiers only
   (no dots). The `TryFindScopedExactVariable` method walks the frame stack
   in reverse (newest first) and returns immediately on a match.
2. **Namespace-qualified** — `CurrentNamespace.Name` in the variable trie
3. **Global fallback** — raw name in the variable trie (only if the name
   contains a dot, making it ineligible for namespace qualification)

This means a local scope variable shadows a global variable with the same name.
Dotted names always bypass scope frames — they are never stored locally.

## Scope Lifecycle

### Push

When `TScopeFrameNode.Execute` or `TScopeFrameNode.Evaluate` runs, it calls
`Context.PushExactScope(LabelText)` to create a new `TExactScopeFrame`. The
frame starts empty and accepts `SetValue` calls for any flat identifier.

### Execute vs Evaluate

The scope node distinguishes between two execution modes:

- **`Execute`** — All body statements are evaluated (not executed). This is the
  default mode when scope appears at the top level of a statement.
- **`Evaluate`** — All statements except the last are evaluated; the last
  statement is evaluated instead of executed, so it returns a value that
  becomes the scope's result.

This distinction matters for `print` and other output nodes: `print` calls
`Execute` to produce output, while evaluated expressions return values.

### Pop

When the scope exits (via the `finally` block in `RunScopedBody`),
`Context.PopExactScope` is called. This:

1. Iterates all values in the frame
2. Deletes each value's subtree from the tree (`DeleteDetachedValue`)
3. Removes the frame from the stack

This ensures no orphaned references remain. Local variables are completely
gone after the scope exits.

## Examples

### Local Variable

```mantra
scope { x = 2, print { x } }
```

**Output:**

```
2
```

The variable `x` is local to the scope and is destroyed when the scope ends.

### Variable Leakage Prevention

```mantra
scope { x = 2, global main.result = x };
print { result }
```

**Output:**

```
2
```

The local `x` is exported to `main.result` via `global`. After the scope
exits, `result` still has value `2`, but `x` is no longer defined.

### Expression Tail

```mantra
print { scope { x = 2, x } }
```

**Output:**

```
x 2 , 
2
```

The scope body's last expression (`x`) is evaluated and returned as the
scope's result. The output shows the assignment and the final value.

### Nested Scope

```mantra
scope { x = 1, scope { x = 2, print { x } }, print { x } }
```

**Output:**

```
1
```

The inner scope shadows `x` with value `2`. The inner `print { x }` evaluates
`x` inside the inner scope (value `2`), but this output is captured during
evaluation. The outer `print { x }` then evaluates the scope body's final
expression, which returns `1` (the outer scope's `x`). After the inner scope
exits, the outer scope's `x = 1` is visible again.

### Variable Chaining

```mantra
scope { x = 2, y = x, global main.result = y };
print { result }
```

**Output:**

```
2
```

Local variables can reference other local variables within the same scope.

### Scope with Label

```mantra
scope { x = 5, print { x } } "test_scope"
```

The optional label is stored in `TExactScopeFrame.LabelText` for debugging
and inspection. It does not affect execution — it's metadata for the scope
frame itself.

### Local Variable Not Accessible Outside

```mantra
scope { x = 2, global main.result = x };
print { result };
print { x }
```

**Output:**

```
2
x
```

After the scope exits, `x` is no longer defined. `print { x }` outputs the
literal `x` (the undefined variable name).

## Global Export

The `global` keyword inside a scope exports a value to the global variable
store. It pushes a global-writes flag (`PushGlobalWrites`) before the
assignment and pops it (`PopGlobalWrites`) afterward, ensuring the assignment
targets the global variable store even when nested inside a scoped block.

```mantra
scope {
  x = 5;
  y = x + 1;
  global main.value = y;
};
print { value };
```

See [Global and Dotted Names](local-scopes/global-dotted-names.md) for details
on the `global` directive and dotted-path storage.

## Scope Frame Details

| Property | Description |
|---|---|
| **Type** | `TExactScopeFrame` (in `context.pas`) |
| **Storage** | `TStringList` with sorted, case-insensitive entries |
| **Stack** | `FExactScopeFrames` in `TContext` |
| **Push** | `PushExactScope` / `PushLocalScope` |
| **Pop** | `PopExactScope` / `PopLocalScope` |
| **Lookup** | `TryFindScopedExactVariable` — only flat identifiers (no dots) |
| **Assignment** | `TryAddScopedExactVariable` — rejects dotted names |
| **Cleanup** | `DeleteDetachedValue` — deletes subtree on pop |

## Related Pages

- [Global and Dotted Names](local-scopes/global-dotted-names.md)
- [Query Helpers](local-scopes/query-helpers.md)
- [Variables and Bindings](variables-bindings.md)
- [Evaluation Scopes](evaluation/evaluation-scopes.md)
- [Compute Scope](compute/compute-scope.md)
