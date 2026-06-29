# Global and Dotted Names

The `global` directive writes assignments into the global variable context. Dotted
names create hierarchical paths in the variable store — each dot-separated segment
forms one level of the hierarchy. Together they provide structured, path-based
variable storage that persists across scopes.

## Quick Reference

| Directive | Purpose |
|---|---|
| `global name = value` | Write to the global variable context |
| `global a.b.c = value` | Write a dotted-path variable globally |
| `get "a.b.c"` | Retrieve a value by dotted path |
| `query_children a.b` | List immediate children under a prefix |
| `assign_path "a.b" value` | Programmatic path assignment |

## Related Pages

- [Path Access](../variables-bindings/path-access.md) — `get`, `path_segment`, `query_children`, indexed patterns
- [Namespaces and Packages](../namespaces-packages.md) — `package`, `import`, `include` directives
- [Assignment](../variables-bindings/assignment.md) — `=` semantics and evaluation lifecycle

---

## The `global` Directive

### Syntax

```mantra
global name = value;
global a.b.c = value;
```

- `global` — the directive keyword (`TK_GLOBAL`)
- `name` — a single identifier or dotted path (e.g., `x`, `dict.obj1.a`)
- `=` — the assignment operator
- `value` — any Mantra expression

The `global` directive pushes a global-writes flag on the runtime context before
executing the assignment, then pops it afterward. This ensures the assignment
targets the global variable store even when nested inside a scoped block.

### How It Works

1. `TGlobalNode.Execute` / `TGlobalNode.Evaluate` calls `Context.PushGlobalWrites`
2. The RHS subtree is executed and evaluated
3. The assignment is stored in the global variable context
4. `Context.PopGlobalWrites` restores the previous scope state
5. The `global` node deletes itself from the AST after execution

### Basic Example

```mantra
global dict.obj1.a = 1;

print { get "dict.obj1.a" };
```

**Output:**

```text
1
```

The dotted name `dict.obj1.a` automatically creates the intermediate hierarchy
(`dict` -> `dict.obj1` -> `dict.obj1.a`) in the variable trie.

### Global Inside Scopes

Without `global`, assignments inside `{ }` scopes are local to that scope.
The `global` directive forces the write to the global variable context:

```mantra
scope { global main.result = 2 };
print { result }
```

**Output:**

```text
2
```

Here, `main.result` is written globally, and `result` resolves via the
`main.` namespace prefix convention. The value persists after the scope ends.

### Local to Global Chain

You can assign a local variable and then export it globally in a single scope:

```mantra
scope { x = 2, y = x, global main.result = y };
print { result }
```

**Output:**

```text
2
```

The local variable `x` is first assigned, then `y` reads it, and finally
`global` writes `y` to the global `main.result` path.

---

## Dotted Names and the Variable Trie

### Path Structure

Dotted names are stored in a trie (prefix tree). Each assignment under a shared
prefix shares the parent nodes:

```mantra
dict.obj1.a = 1;
dict.obj2.b = 2;
```

This creates the structure:

```
dict
├── obj1
│   └── a  (value: 1)
└── obj2
    └── b  (value: 2)
```

### Retrieving with `get`

The `get` directive resolves a dotted path to its stored value. See
[Path Access](../variables-bindings/path-access.md) for the full reference
(literal, variable reference, and computed path forms).

```mantra
dict.obj1.a = 1;
print { get "dict.obj1.a" };
```

**Output:**

```text
1
```

### Querying Children with `query_children`

The `query_children` directive returns all immediate child paths under a given
prefix. It accepts both bare dotted names and quoted strings:

```mantra
dict.obj1.a = 1;
dict.obj2.b = 2;

print { query_children dict };
print { query_children dict.obj1 };
```

**Output:**

```text
"dict.obj1" "dict.obj2"
"dict.obj1.a"
```

Children are returned sorted alphabetically. Each result is the full dotted path
of the child — not just the segment name.

### Indexed Pattern Resolution

Both `get` and `query_children` support indexed patterns (wildcards like `[2]`)
in the path. The runtime resolves these patterns by scanning matching variables:

```mantra
dict.obj1.attr.y = 2;
dict.obj2.attr.inner.y = 9;
dict.obj2.kind = "k";
dict.obj3.z = 3;

print { get dict.obj[2].kind }
print { query_children dict.obj[2].attr }
```

**Output:**

```text
"k"
"dict.obj2.attr.inner"
```

The pattern `dict.obj[2]` resolves to `dict.obj2` by matching the indexed
wildcard against the trie.

### Dollar-sign Variable Deref

Use the `$` prefix to deref a variable containing a path string:

```mantra
dict.obj2.b = 2;
dict.obj1.a = 1;
P = "dict";

print { query_children $P }
```

**Output:**

```text
"dict.obj1" "dict.obj2"
```

The `$P` syntax tells the runtime to first resolve `P` to its value
(`"dict"`), then use that string as the query prefix.

### Computed Path Expressions

Any expression inside `{ }` that evaluates to a path string works as an argument:

```mantra
{ x.a = 1 }
{ x.b = 2 }
print { [ query_children { fmt "%s" [ "x" ] } ] }
```

**Output:**

```text
[ "x.a" "x.b" ]
```

---

## Programmatic Path Assignment with `assign_path`

The `assign_path` directive assigns a value to a path specified as a string.
It supports bracket-indexed segments for array-like structures:

```mantra
assign_path "root.expr1" ( + m n );
print { get "root.expr1" };
```

**Output:**

```text
+ m + n
```

Array-indexed paths:

```mantra
{ assign_path "dict.list[1].name" "a" };
{ assign_path "dict.list[2].name" "b" };

print { query_children dict.list }
print { get "dict.list[1].name" }
```

**Output:**

```text
"dict.list[1]" "dict.list[2]"
"a"
```

The `assign_path` directive is the programmatic counterpart to dotted-name
assignment — it takes the path as a string argument rather than a syntactic
dotted identifier, so it can be constructed dynamically at runtime.

---

## Comparison: Local vs Global Assignments

| Aspect | Local (`x = 1`) | Global (`global x = 1`) |
|---|---|---|
| Scope | Current `{ }` block or scope frame | Global variable context |
| Survives scope exit | No | Yes |
| Dotted paths | Creates local hierarchy | Creates global hierarchy |
| Access from other scopes | No (unless re-assigned) | Yes |
| AST after execution | Assignment node deleted | Global wrapper node deleted |

### When to Use Global

- **Sharing state between scopes** — export local computation results to a global
  variable accessible by other parts of the program.
- **Structured configuration** — use dotted names under a common prefix
  (e.g., `config.db.host`) for namespaced settings.
- **Accumulating results** — build a result trie across multiple scope blocks,
  then query it once at the end.

### When to Use Local

- **Temporary intermediates** — values that only matter within a single
  computation block.
- **Isolated experiments** — avoid polluting the global namespace during
  development.

---

## Complete Example

```mantra
global config.db.host = "localhost";
global config.db.port = 5432;
global config.app.name = "myapp";

print { get "config.db.host" };
print { get "config.app.name" };
print { query_children config };
print { query_children config.db };
```

**Output:**

```text
"localhost"
"myapp"
"config.app" "config.db"
"config.db.host" "config.db.port"
```

---

## Implementation Details

### Node Types

| Node | Token | Description |
|---|---|---|
| `TGlobalNode` | `TK_GLOBAL` | Wraps an assignment with global scope |
| `TGetNode` | `TK_GET` | Resolves a path string to a variable value |
| `TQueryChildrenNode` | `TK_QUERY_CHILDREN` | Lists children under a path prefix |

### Runtime Flow

1. `TGlobalNode.Execute` calls `Context.PushGlobalWrites` to set the global
   write flag on the context
2. The LHS assignment subtree is executed (storing the value in the global trie)
3. `Context.PopGlobalWrites` clears the flag
4. The `global` node deletes itself from the AST

### Pattern Resolution

Both `get` and `query_children` call `ResolveQueryArgumentText` to extract
their path argument, then use `Context.ResolveIndexedVariablePattern` to handle
indexed wildcards (e.g., `[n]`). If the pattern resolves to a concrete path,
that path is used for the lookup instead of the original pattern text.

### Variable Trie

The runtime stores variables in a trie (prefix tree) keyed by dotted path
segments. `ScanVariables` and `ScanVariableChildren` walk this trie to find
matches. The trie supports both dotted segments (`a.b.c`) and bracket-indexed
segments (`list[1]`).
