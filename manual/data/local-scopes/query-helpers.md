# Query Helpers

Query helpers read structured data from the variable trie by path, key, or
relationship. They are the primary way to inspect, enumerate, and extract
stored values without manual path construction.

## Quick Reference

| Helper | Purpose |
|---|---|
| `get <path>` | Retrieve a single value by dotted path |
| `query_children <prefix>` | List child paths under a prefix |
| `query_keys <pattern>` | Extract keys from a key-value sequence |
| `query_values <pattern>` | Extract values from a key-value sequence |
| `path_segment <path> <index>` | Extract one segment from a dotted path |
| `make_pair <key> <value>` | Build a `key -> value` pair node |

## Related Pages

- [Path Access](../variables-bindings/path-access.md) — `get`, `path_segment`, `assign_path`, indexed patterns
- [Global and Dotted Names](global-dotted-names.md) — global scope and dotted-path storage
- [JSON Loading](../rendering-structured-output/json-loading.md) — loading JSON into the variable trie

---

## `get` — Retrieve a Value by Path

The `get` helper resolves a path string to the variable value stored at that
location in the variable trie. It expects exactly one argument.

### Syntax

```mantra
get <path>
```

### Argument Forms

**Literal path string** — pass a quoted string with the full dotted path:

```mantra
doc.first_name = "John";

print { get "doc.first_name" }
```

**Output:**

```text
"John"
```

**Bare variable path** — pass a bare variable that holds a path string:

```mantra
doc.first_name = "John";
P = "doc.first_name";

print { get $P }
```

**Output:**

```text
"John"
```

**Computed path expression** — any expression that resolves to a scalar path
string works:

```mantra
x = 1;
print { get { fmt "%s" [ "x" ] } }
```

**Output:**

```text
1
```

### Resolution Order

`get` tries lookups in this order:

1. **Exact match** via `TryFindVariable` — direct path lookup in the trie.
2. **Pattern scan** via `ScanVariables` — if no exact match, scans all
   variables whose paths contain the query string.
3. **Indexed pattern resolution** — if the path contains indexed wildcards
   (e.g., `{n}`), `ResolveIndexedVariablePattern` substitutes current repeat/
   selection indices before retrying the lookup.

### Return Value

`get` replaces itself with the cloned value node. If the path resolves to
nothing, the result is empty (no children).

---

## `query_children` — List Child Paths Under a Prefix

`query_children` enumerates all immediate child paths under a given prefix
in the variable trie. It returns the full qualified paths (including the
prefix), not just the child names.

### Syntax

```mantra
query_children <prefix>
```

### Argument Forms

**Bare variable prefix** — the most common form:

```mantra
doc.first_name = "John";
doc.last_name = "Doe";
doc.age = 30;

print { query_children doc }
```

**Output:**

```text
"doc.age" "doc.first_name" "doc.last_name"
```

**String prefix** — pass a quoted string:

```mantra
print { query_children "doc" }
```

**Variable dereference** — use `$` to dereference a variable holding the prefix:

```mantra
P = "doc";
print { query_children $P }
```

**Output:**

```text
"doc.first_name" "doc.last_name" "doc.age"
```

**Computed expression** — any expression that resolves to a scalar string:

```mantra
x.a = 1;
x.b = 2;

print { [ query_children { fmt "%s" [ "x" ] } ] }
```

**Output:**

```text
[ "x.a" "x.b" ]
```

### Behavior Details

- `query_children` calls `ScanVariableChildren` on the resolved prefix.
- Results are **sorted alphabetically**.
- Returns **full qualified paths** (e.g., `"dict.obj2.attr"`, not just `"attr"`).
- Works with indexed paths: `query_children dict.list` returns entries like
  `"dict.list[1]"`, `"dict.list[2]"`.
- Returns child paths that are themselves prefixes (have their own children)
  as well as leaf paths.

### Nested Example

```mantra
dict.obj1.attr.y = 2;
dict.obj2.attr.inner.y = 9;
dict.obj2.kind = "k";
dict.obj3.z = 3;

print { query_children dict }
print { query_children dict.obj2 }
```

**Output:**

```text
"dict.obj1" "dict.obj2" "dict.obj3"
"dict.obj2.attr" "dict.obj2.kind"
```

---

## `query_keys` and `query_values` — Project Keys or Values

`query_keys` and `query_values` operate on a sequence of key-value pairs
(variable-subtree nodes like `"key" -> value`) and extract either the keys
or the values respectively.

### Syntax

```mantra
query_keys <source>
query_values <source>
```

The `<source>` is typically a variable-subtree sequence, often produced by
`query_children` results or loaded JSON array entries.

### How They Work

Both helpers evaluate the source argument, then iterate over its entries:

- **`query_keys`** — for each `TVariableSubtreeNode`, extracts the key
  (the token/identifier part) and emits it.
- **`query_values`** — for each `TVariableSubtreeNode`, extracts the LHS
  (the value subtree) and emits a deep clone.

The result replaces the helper node inline.

### Example with Indexed Patterns

```mantra
import utils;

dict.obj1.attr.y = 2;
dict.obj2.attr.inner.y = 9;
dict.obj2.kind = "k";
dict.obj3.z = 3;

print { get dict.obj[2].kind }
print { query_keys dict.obj[2].attr.* }
print { query_values dict.obj[2].attr.* }
```

**Output:**

```text
"k"
"dict.obj2.attr.inner" "dict.obj2.attr.inner.y"
9
```

### Example with JSON Arrays

When loading JSON, array elements are stored as indexed trie entries.
`query_values` extracts the scalar value from an indexed entry:

```mantra
json_load "data.json" doc;

print { query_values doc.user.tags[1] }
print { query_values doc.user.tags[2] }
```

**Output:**

```text
"logic"
"math"
```

### `utils/trie` Wrappers

The `utils/trie` package provides rule-based wrappers around the built-in
helpers:

```mantra
import utils;

utils.dict_keys   X.*   # wraps query_keys
utils.dict_values X.*   # wraps query_values
utils.dict_children X    # wraps query_children
```

These wrappers use selection rules to delegate to the native helpers.

---

## `path_segment` — Extract a Segment from a Dotted Path

`path_segment` splits a dotted path into individual segments and returns the
one at the given 1-based index. Negative indices count from the end. It
expects exactly two arguments: the path and the index.

### Syntax

```mantra
path_segment <path> <index>
```

### Argument Forms

The path argument can be a literal string, a variable dereference (`$`), or
any expression that resolves to a scalar string. The index must be an
integer.

```mantra
P = "dict.obj1.steps[1].after";

print { path_segment $P 1 }
print { path_segment $P 2 }
print { path_segment $P 3 }
print { path_segment $P -1 }
print { path_segment $P -2 }
```

**Output:**

```text
"dict"
"obj1"
"steps"
"after"
"steps"
```

### Square Bracket Segments

Segments inside square brackets (e.g., `[1]` in `steps[1]`) are parsed as
separate segments. When `path_segment` returns a bracket segment, it is
emitted as an integer node rather than a string:

```mantra
P = "dict.obj1.steps[1].after";

print { path_segment $P 4 }   # bracket segment [1] -> integer 1
print { path_segment $P 5 }   # beyond end -> empty string
```

**Output:**

```text
1
""
```

### Index Rules

| Index | Behavior |
|---|---|
| `1` | First segment |
| `N > 0` | Nth segment (1-based) |
| `-1` | Last segment |
| `-N` | Nth segment from the end |
| `0` | Returns empty string |
| Out of range | Returns empty string `""` |

### Literal String Paths

The path can be a literal string:

```mantra
print { path_segment "a.b.c" 2 }
print { path_segment "a.b.c" 5 }
```

**Output:**

```text
"b"
""
```

### Variable Dereference

When the path is stored in a variable, use `$` to dereference it:

```mantra
P = "a.b.c";
Q = P;
print { path_segment $Q 2 }
```

**Output:**

```text
"b"
```

### Errors

`path_segment` raises an exception if:

- The argument count is not exactly 2:
  `path_segment expects exactly 2 arguments: path_segment <path> <index>`
- The index cannot be parsed as an integer:
  `path_segment index must be an integer`

---

## `make_pair` — Build a Key-Value Pair Node

`make_pair` constructs a `key -> value` pair (variable-subtree node) from
two arguments. It expects exactly two arguments: the key and the value.

### Syntax

```mantra
make_pair <key> <value>
```

### Example

```mantra
K = "doc.user.name";
print { make_pair K 1 }
print { make_pair ( path_segment "doc.user.name" -1 ) 2 }
```

**Output:**

```text
"doc.user.name" -> 1
"name" -> 2
```

### Use Cases

`make_pair` is useful when constructing entries for `query_keys`/`query_values`
or building flat key-value lists for `assign_path`:

```mantra
assign_path "root" { make_pair "key1" "value1" };
```

---

## Common Patterns

### Iterating over trie children

List children, then retrieve each by path:

```mantra
doc.name = "Ada";
doc.age = 42;

{ query_children doc }
# ("doc.age" "doc.name")
```

### Extracting array values from JSON

```mantra
json_load "data.json" doc;

print { query_values doc.user.tags[1] }   # "logic"
print { query_values doc.user.tags[2] }   # "math"
```

### Building trie paths from segments

```mantra
P = "config.server.host";
print { path_segment $P 1 }  # "config"
print { path_segment $P 3 }  # "host"
```

### Converting trie to AST structure

The `utils/trie` package uses `query_children`, `path_segment`, and `make_pair`
to convert trie state into nested AST-like structures:

```mantra
import utils;

utils.trie.trie_to_ast [ all { query_children root } ]
```
