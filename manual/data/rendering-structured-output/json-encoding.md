# JSON Encoding

`json_encode` converts a Mantra variable or trie subtree into a JSON string.
It traverses the variable trie at the given path, recursively converting object
entries, indexed arrays, and scalar leaf values into their JSON equivalents.

```mantra
json_load "data/chart.json" chart;
print { json_encode chart }
```

Use [`json_save`](json-saving.md) when the JSON should be written directly to a
file rather than returned as a string.

## Syntax

```
json_encode <path>
```

| Argument | Type | Description |
|---|---|---|
| `<path>` | Variable or string | Trie path (dotted notation) to encode. Resolved from the variable context. |

`json_encode` expects exactly 1 argument. It evaluates in the Evaluate phase:
it resolves the path, builds a JSON data structure, and replaces the node with
the resulting JSON string.

## Mantra to JSON Mapping

`json_encode` recursively traverses trie state and produces JSON according to
these rules:

| Mantra Trie State | JSON Output |
|---|---|
| Scalar string node | `"text"` |
| Scalar integer node | `42` |
| Scalar float node (finite) | `3.14` |
| `true` / `false` | `true` / `false` |
| `null` | `null` |
| Trie with dot-path children (object-like) | `{"key": value, ...}` |
| Trie with `[n]` indexed children (array-like) | `[value, ...]` |
| Empty object marker (`TK_JSON_EMPTY_OBJECT`) | `{}` |
| Empty array marker (`TK_JSON_EMPTY_ARRAY`) | `[]` |

Object fields are emitted in deterministic trie order. Object field order is not
semantically significant in JSON.

### Building Trie Data with `assign_path`

The most common way to build structured data for `json_encode` is
[`assign_path`](../variables-bindings/assignment.md). Each call creates or
updates a single trie entry:

```mantra
{ assign_path "chart.mark" "line" };
{ assign_path "chart.encoding.x.field" "x" };
{ assign_path "chart.encoding.x.type" "quantitative" };

print { json_encode chart }
```

Output:
```
"{ "encoding" : { "x" : { "field" : "x", "type" : "quantitative" } }, "mark" : "line" }"
```

Array entries use 1-based bracket indexing:

```mantra
{ assign_path "items[1].name" "Ada" };
{ assign_path "items[1].active" true };
{ assign_path "items[2].name" "Bob" };
{ assign_path "items[2].active" false };

print { json_encode items }
```

Output:
```
"{ "items" : [{ "active" : true, "name" : "Ada" }, { "active" : false, "name" : "Bob" }] }"
```

### Escaped Key Characters

JSON keys containing `.`, `[`, `]`, `*`, `?`, `%`, or `_` are automatically
escaped by `json_load` using the `_xHH_` convention. When `json_encode`
encounters these escaped keys in the trie, it decodes them back to the original
characters:

| Escaped Key | Decoded JSON Key |
|---|---|
| `_x2E_` | `.` |
| `_x5B_` | `[` |
| `_x5D_` | `]` |
| `_x2A_` | `*` |
| `_x3F_` | `?` |
| `_x25_` | `%` |
| `_x5F_` | `_` |

## Round Trip

`json_encode` and `json_load` are inverse operations for supported values. A
document loaded from a file can be re-encoded to produce equivalent JSON:

```mantra
json_load "data/doc.json" doc;
print { json_encode doc }
```

```json
{
  "active": true,
  "disabled": false,
  "nothing": null,
  "count": 3,
  "ratio": 1.25,
  "name": "Ada\nLovelace",
  "empty_object": {},
  "empty_array": [],
  "items": [
    { "x": 1, "labels": [] },
    { "x": 2, "meta": {} }
  ]
}
```

For supported values, `json_encode doc` produces JSON with the same structure
as the original file (key order follows deterministic trie traversal).

## Scalar Values

`json_encode` also accepts simple variables bound to scalar values:

```mantra
x = 42;
print { json_encode x }
```

Output:
```
"42"
```

## Rejected Values

`json_encode` raises a runtime error for unsupported input:

| Condition | Error Message |
|---|---|
| Non-finite float (NaN, infinity) | `json_encode requires a finite float, got <value>` |
| Missing trie path | `json_encode path not found: <path>` |
| Scalar value with children at same path | `json_encode object path also contains a scalar value: <path>` |
| Array path with scalar value | `json_encode array path also contains a scalar value: <path>` |
| Sparse array (non-contiguous indices) | `json_encode requires contiguous arrays at <path>` |
| Non-index child in array | `json_encode array has a non-index child: <path>` |
| Duplicate array index | `json_encode array has duplicate index <n> at <path>` |
| Missing array index | `json_encode array is missing index <n> at <path>` |
| Invalid immediate child path | `json_encode encountered an invalid immediate child: <path>` |
| Invalid encoded key | `json_encode encountered an invalid encoded key: <key>` |
| Unsupported AST node type | `json_encode does not support node type <n>` |

All errors follow the standard `Error: <message>` format.

## Rich Notebook Output

`display` emits structured JSON with an associated MIME type. It operates in
the Execute phase and deletes itself from the AST after emitting output.

```mantra
display "application/vnd.vegalite.v6+json" chart;
```

### Syntax

```
display <mime-type> <path>
```

| Argument | Type | Description |
|---|---|---|
| `<mime-type>` | String | MIME type — must be `application/json` or end with `+json` |
| `<path>` | Variable or string | Trie path to encode |

### MIME Type Support

The MVP accepts:

- `application/json` — encodes the path with standard `json_encode` rules
- `<type>/<subtype>+json` — vendor-specific JSON types (e.g. `application/vnd.vegalite.v6+json`)
- `application/vnd.vegalite.*+json` — uses the Vega-Lite encoder which tolerates inline data values with invalid fields (falls back to `null`)

Non-JSON MIME types are rejected:

```mantra
display "image/svg+xml" chart;
```

Output:
```
Error: display MVP supports JSON MIME types only, got image/svg+xml
```

### Output Behavior

- In an interactive session (`--interactive`), `display` sends the MIME-typed
  JSON to the session output channel where a frontend renderer can use it.
- In the CLI, the fallback is the plain JSON representation printed to stdout.
- After emitting, the `display` node deletes itself from the AST.

## Vega-Lite Helper

The `viz` package provides chart-building helpers that produce Vega-Lite
specifications as trie data:

```mantra
import viz;

{ viz.line_xy "chart" "x" "y" };
{ assign_path "chart.data.values[1].x" -1 };
{ assign_path "chart.data.values[1].y" 1 };
{ assign_path "chart.data.values[2].x" 0 };
{ assign_path "chart.data.values[2].y" 0 };
{ assign_path "chart.data.values[3].x" 1 };
{ assign_path "chart.data.values[3].y" 1 };

{ viz.show "chart" }
```

`viz.line_xy` authors the `$schema`, `mark`, and quantitative field encodings.
Callers populate `chart.data.values[n]` with row objects. `viz.show` calls
`display` with the `application/vnd.vegalite.v6+json` MIME type.

For a computed function plot, the package can own both the schema and row
materialization:

```mantra
import viz;

k = 2.0;
step = 0.2;

{ viz.line_range "chart" ( -k .. k by step ) ( * x x ) };
{ viz.show "chart" }
```

The grouped range and expression are passed as structural arguments.
`viz.line_range` binds each driver value to `x`, evaluates the expression, and
creates one `{x, y}` row per value. `viz.square_range` is shorthand for the
same call with `( * x x )`.

## Related

- [JSON Loading](json-loading.md) — `json_load` for reading JSON files
- [JSON Saving](json-saving.md) — `json_save` for atomically writing JSON files
- [Path Access](../variables-bindings/path-access.md) — trie path syntax and `assign_path`
- [Error Reporting](../../evaluation/error-reporting.md) — general error handling
