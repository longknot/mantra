# JSON Loading

`json_load` loads a JSON file and materializes its contents as structured Mantra
trie data accessible through dotted path notation:

```mantra
json_load "tests/cases/json_load_basic.json" doc;
print { doc.user.name }
print { doc.user.age }
```

Expected `OUTPUT` excerpt:

```text
"Ada"
42
```

## Syntax

```
json_load "<file-path>" <destination-prefix>
```

| Argument | Type | Description |
|---|---|---|
| `<file-path>` | String | Path to the JSON file, resolved relative to the working directory |
| `<destination-prefix>` | Variable or string | Prefix under which the loaded data is stored in the variable trie |

`json_load` expects exactly 2 arguments. After successful loading, the
`json_load` node deletes itself from the AST.

## JSON to Mantra Mapping

`json_load` recursively traverses the parsed JSON document and creates
corresponding Mantra trie entries. The mapping between JSON types and
Mantra values is:

| JSON Type | Mantra Representation | Access |
|---|---|---|
| Object | Trie path segments (dotted notation) | `prefix.key` |
| Array | Indexed trie path | `prefix[key][index]` (1-based) |
| String | String node | Returns quoted string on output |
| Integer | Integer node | Returns integer literal |
| Float | Float node | Returns scientific notation |
| `true` / `false` | Boolean node | Returns `true` / `false` |
| `null` | Null node | Returns `null` |
| Empty object `{}` | Empty container node | Accessible as trie root |
| Empty array `[]` | Empty container node (indexed) | Accessible as indexed trie root |

## Examples

### Loading and Accessing Values

```json
{
  "user": {
    "name": "Ada",
    "age": 42,
    "active": true,
    "score": 3.5,
    "tags": ["logic", "math"],
    "meta": null
  }
}
```

```mantra
json_load "tests/cases/json_load_basic.json" doc;

print { doc.user.name }
print { doc.user.age }
print { doc.user.active }
print { doc.user.score }
print { query_values doc.user.tags[1] }
print { query_values doc.user.tags[2] }
print { doc.user.meta }
```

Expected `OUTPUT`:

```text
"Ada"
42
true
3.5000000000000000E+000
"logic"
"math"
null
```

Array indexing is 1-based. Use `query_values` to extract the scalar value
from an indexed trie entry.

### Escaped Key Characters

JSON keys may contain characters that conflict with Mantra path syntax.
`json_load` escapes these automatically using the `_xHH_` convention:

| JSON Key Character | Escape Sequence |
|---|---|
| `.` | `_x2E_` |
| `[` | `_x5B_` |
| `]` | `_x5D_` |
| `*` | `_x2A_` |
| `?` | `_x3F_` |
| `%` | `_x25_` |
| `_` | `_x5F_` |

```json
{
  "a.b": {
    "x[y]": 9,
    "q?": 1,
    "m*n": 2
  }
}
```

```mantra
json_load "tests/cases/json_load_escape_keys.json" doc;

print { doc.a_x2E_b.x_x5B_y_x5D_ }
print { doc.a_x2E_b.q_x3F_ }
print { doc.a_x2E_b.m_x2A_n }
```

Expected `OUTPUT`:

```text
9
1
2
```

## Destination Prefix

The destination prefix can be a bare variable name or a quoted string. When
it is a variable reference (`OBJ_VARIABLE`), its token value is used as the
prefix. The prefix is created in the variable trie if it does not already
exist.

```mantra
json_load "data/config.json" config;
json_load "data/config.json" "my_config";
```

Both forms are equivalent when `config` is a simple variable name.

## Error Handling

`json_load` raises runtime errors for common failure conditions:

| Condition | Error Message |
|---|---|
| Missing or wrong argument count | `json_load expects exactly 2 arguments: json_load "<file>" <prefix>` |
| Empty file path | `json_load source path cannot be empty` |
| Empty destination prefix | `json_load destination prefix cannot be empty` |
| File not found | `json_load source file not found: <path>` |
| Invalid JSON syntax | `json_load parse error in "<file>": <detail>` |
| Failed to create trie prefix | `json_load failed to create destination prefix: <prefix>` |
| Failed to materialize data | `json_load failed to materialize payload into prefix: <prefix>` |

All errors follow the standard `Error: <message>` format on standard output.

## Internal Behavior

`json_load` operates in the Execute phase. It:

1. Resolves the file path and destination prefix from its arguments.
2. Reads the entire file into memory.
3. Parses the JSON text using `GetJSON()`.
4. Creates a variable trie state at the destination prefix.
5. Recursively materializes JSON values into the trie — objects become path
   segments, arrays become indexed entries, and scalars become leaf nodes.
6. Deletes itself from the AST.

The recursive materializer (`MaterializeJsonValueAtState`) handles nested
structures of arbitrary depth. Empty containers get special sentinel nodes
rather than being skipped.

## Related

- [JSON Saving](json-saving.md) — `json_save` for atomically writing Mantra data to JSON files
- [JSON Encoding](json-encoding.md) — `json_encode` for converting Mantra values back to JSON
- [Error Reporting](../evaluation/error-reporting.md) — general error handling
