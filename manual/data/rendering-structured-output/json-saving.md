# JSON Saving

`json_save` writes a JSON-compatible Mantra value or trie subtree to a file:

```mantra
doc.name = "Ada";
doc.active = true;

json_save doc "data/user.json";
```

This produces a file `data/user.json` with the contents:

```json
{"active":true,"name":"Ada"}
```

## Syntax

```
json_save <source-prefix> "<file-path>"
```

| Argument | Type | Description |
|---|---|---|
| `<source-prefix>` | Variable or string | Trie path prefix whose data is serialized to JSON |
| `<file-path>` | String | Destination file path, resolved relative to the working directory |

`json_save` expects exactly 2 arguments. After successful execution, the
`json_save` node deletes itself from the AST.

The directive is the inverse of [`json_load`](json-loading.md):

```
json_save <source-prefix> "<file-path>"    ; Mantra data → JSON file
json_load "<file-path>" <dest-prefix>      ; JSON file → Mantra data
```

## Source Prefix

The source prefix can be a bare variable name or a quoted path string. When
it is a variable reference, its token value is used as the prefix to look
up in the variable trie.

```mantra
json_save doc "data/doc.json";           ; bare variable name
json_save "my.path" "data/doc.json";     ; quoted path string
```

## Supported Values

`json_save` uses the same conversion as [`json_encode`](json-encoding.md). It
supports:

- strings
- integers
- finite floating-point numbers
- `true`, `false`, and `null`
- object-like trie paths (dotted children become JSON object keys)
- contiguous indexed trie paths (become JSON arrays)
- empty objects and arrays loaded by `json_load` or `yaml_load`

Unsupported values, sparse arrays, and trie nodes that contain both a scalar
value and children are rejected before the destination file is changed.

## Mantra to JSON Mapping

`json_save` recursively traverses the trie and builds a JSON document. The
mapping between Mantra trie structures and JSON types is:

| Mantra Structure | JSON Type | Example |
|---|---|---|
| Scalar leaf (string, integer, float, boolean, null) | JSON scalar | `"Ada"`, `42`, `3.5`, `true`, `null` |
| Dotted children (`doc.name`, `doc.active`) | Object with string keys | `{"name":"Ada","active":true}` |
| Contiguous indexed children (`doc.items[1]`, `doc.items[2]`) | Array | `["a","b"]` |
| Empty object marker | Empty object `{}` | `{}` |
| Empty array marker | Empty array `[]` | `[]` |

### Objects

Trie paths with dotted children are serialized as JSON objects. Each child
becomes a key-value pair:

```mantra
doc.name = "Ada";
doc.active = true;
doc.age = 42;

json_save doc "data/user.json";
```

Output file:

```json
{"active":true,"age":42,"name":"Ada"}
```

### Arrays

Contiguous 1-based indexed children are serialized as JSON arrays:

```mantra
{ assign_path "doc.values[1]" "a" };
{ assign_path "doc.values[2]" "b" };
{ assign_path "doc.values[3]" "c" };

json_save doc "data/list.json";
```

Output file:

```json
{"values":["a","b","c"]}
```

### Mixed Objects and Arrays

Objects and arrays can be nested within each other:

```mantra
doc.name = "Ada";
{ assign_path "doc.tags[1]" "logic" };
{ assign_path "doc.tags[2]" "math" };

json_save doc "data/user_tags.json";
```

Output file:

```json
{"name":"Ada","tags":["logic","math"]}
```

## Output Format

The output is compact JSON — no extra whitespace or indentation. Each object's
keys are emitted in deterministic trie-traversal order, so the output is
stable across runs for the same data.

The file is encoded as UTF-8 and terminated with the platform line ending
(`\n` on Unix, `\r\n` on Windows).

## Atomic Replacement

`json_save` never leaves a partially written file. It operates in three steps:

1. **Encode** the Mantra trie data to a JSON string.
2. **Write** the JSON text to a temporary file in the destination directory
   (named `<filename>.tmp.<pid>.<ticks>`).
3. **Rename** the temporary file to the destination path atomically.

If any step fails, the existing destination file is left unchanged and the
temporary file is cleaned up. This means:

- encoding failures (unsupported values, sparse arrays) leave the existing
  file unchanged
- write failures (disk full, permission denied) leave the existing file
  unchanged
- an existing destination file is silently overwritten
- temporary files are never left behind after failures

The destination directory must already exist. `json_save` does not create
intermediate directories.

## Round Trip

For supported values, saving and then loading data produces an equivalent
structure:

```mantra
doc.name = "Ada";
{ assign_path "doc.values[1]" 2 };
{ assign_path "doc.values[2]" 3 };

json_save doc "data/doc.json";
json_load "data/doc.json" copy;

print { copy.name }
print { get "copy.values[1]" }
print { get "copy.values[2]" }
```

Expected `OUTPUT`:

```text
"Ada"
2
3
```

The `copy` trie has the same JSON structure as the original `doc` data.

## Overwriting Files

`json_save` replaces the destination file entirely on each invocation.
Subsequent saves overwrite previous content:

```mantra
doc.version = 1;
json_save doc "data/version.json";

doc.version = 2;
doc.current = true;
json_save doc "data/version.json";

json_load "data/version.json" copy;
print { copy.version }
print { copy.current }
```

Expected `OUTPUT`:

```text
2
true
```

The first save (`{"version":1}`) is completely replaced by the second
save (`{"current":true,"version":2}`). The atomic rename ensures readers
never see a corrupted intermediate file.

## Error Handling

`json_save` raises runtime errors for common failure conditions:

| Condition | Error Message |
|---|---|
| Wrong argument count | `json_save expects exactly 2 arguments: json_save <source-prefix> "<file>"` |
| Empty source prefix | `json_save source prefix cannot be empty` |
| Empty destination path | `json_save destination path cannot be empty` |
| Missing source path | `json_encode path not found: <path>` |
| Non-contiguous array | `json_encode requires contiguous arrays at <path>` |
| Mixed scalar and children | `json_encode object path also contains a scalar value: <path>` |
| Non-finite float | `json_encode requires a finite float, got <value>` |
| Missing destination directory | `json_save destination directory not found: <path>` |
| Atomic rename failure | `json_save failed to replace "<file>": <detail>` |

All errors follow the standard `Error: <message>` format on standard output.

## Internal Behavior

`json_save` operates in the Execute phase. It:

1. Resolves the source prefix and destination file path from its arguments.
2. Calls `BuildJsonDataFromPath` to recursively convert the trie subtree at
   the source prefix into a `TJSONData` tree (same encoder as `json_encode`).
3. Serializes the `TJSONData` tree to a compact JSON string via `AsJSON`.
4. Writes the JSON text atomically to the destination file (write to temp,
   rename).
5. Deletes itself from the AST.

Because the encoding happens entirely in step 2, any validation error
(unsupported values, sparse arrays, etc.) is raised before the file system
is touched. The atomic write in step 4 ensures that partial encodings never
appear on disk.

## Related

- [JSON Loading](json-loading.md) — `json_load` for loading JSON files into Mantra trie data
- [JSON Encoding](json-encoding.md) — `json_encode` for converting Mantra values to JSON strings
