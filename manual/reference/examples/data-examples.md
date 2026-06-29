# Data Examples

## CLI Variable

Args:

```text
--set x=5
```

Input:

```mantra
print { x }
```

Expected `OUTPUT`:

```text
5
```

## JSON Loading

Input:

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

## YAML Loading

Input:

```mantra
yaml_load "tests/cases/yaml_load_basic.yaml" doc;
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
"null"
```

## JSON Key Escaping

Input:

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

## JSON Encoding

Input:

```mantra
x = 42;
print { json_encode x }
```

Expected `OUTPUT`:

```text
"42"
```

## JSON Roundtrip

Input:

```mantra
json_load "tests/cases/json_encode_roundtrip.json" doc;
print { json_encode doc }
```

Expected `OUTPUT`:

```text
"{ \"\.\" : \"dot\", \"_x2E_\" : \"literal escape text\", \"active\" : true, \"count\" : 3, \"disabled\" : false, \"empty_array\" : [], \"empty_object\" : {}, \"items\" : [{ \"labels\" : [], \"x\" : 1 }, { \"meta\" : {}, \"x\" : 2 }], \"name\" : \"Ada\nLovelace\", \"nothing\" : null, \"ratio\" : 1.2500000000000000E+000 }"
```

## JSON Encoding — Missing Path

Input:

```mantra
print { json_encode missing }
```

Expected `OUTPUT`:

```text
Error: json_encode path not found: missing
```

## JSON Encoding — Non-Finite Rejected

Input:

```mantra
x = nan;
print { json_encode x }
```

Expected `OUTPUT`:

```text
Error: json_encode requires a finite float, got nan
```

## assign_path — Build Trie Programmatically

Input:

```mantra
{ assign_path "chart.mark" "line" };
{ assign_path "chart.encoding.x.field" "x" };
{ assign_path "chart.encoding.x.type" "quantitative" };
{ assign_path "chart.encoding.y.field" "y" };
{ assign_path "chart.encoding.y.type" "quantitative" };
{ assign_path "chart.options.tooltip" true };
{ assign_path "chart.data.values[1].x" -1 };
{ assign_path "chart.data.values[1].y" 1 };
{ assign_path "chart.data.values[2].x" 0 };
{ assign_path "chart.data.values[2].y" 0 };
{ assign_path "chart.data.values[3].x" 1 };
{ assign_path "chart.data.values[3].y" 1 };
print { json_encode chart }
```

Expected `OUTPUT`:

```text
"{ \"data\" : { \"values\" : [{ \"x\" : -1, \"y\" : 1 }, { \"x\" : 0, \"y\" : 0 }, { \"x\" : 1, \"y\" : 1 }] }, \"encoding\" : { \"x\" : { \"field\" : \"x\", \"type\" : \"quantitative\" }, \"y\" : { \"field\" : \"y\", \"type\" : \"quantitative\" } }, \"mark\" : \"line\", \"options\" : { \"tooltip\" : true } }"
```

## Display — Structured Notebook Output

Input:

```mantra
{ assign_path "chart.mark" "line" };
{ assign_path "chart.options.tooltip" true };
display "application/vnd.vegalite.v6+json" chart;
```

Expected `OUTPUT`:

```text
{ "mark" : "line", "options" : { "tooltip" : true } }
```

## get — Retrieve by Path

Input:

```mantra
doc.first_name = "John";
doc.last_name = "Doe";
doc.age = 30;

print { get "doc.first_name" }
print { get "doc.age" }
```

Expected `OUTPUT`:

```text
"John"
30
```

## query_children — List Children Under a Prefix

Input:

```mantra
doc.first_name = "John";
doc.last_name = "Doe";
doc.age = 30;

print { query_children doc }
```

Expected `OUTPUT`:

```text
"doc.age" "doc.first_name" "doc.last_name"
```

## query_values — Extract Values from Indexed Array

Input:

```mantra
json_load "tests/cases/json_load_basic.json" doc;
print { query_values doc.user.tags[1] }
print { query_values doc.user.tags[2] }
```

Expected `OUTPUT`:

```text
"logic"
"math"
```

## path_segment — Split a Dotted Path

Input:

```mantra
P = "dict.obj1.steps[1].after";

print { path_segment $P 1 }
print { path_segment $P 2 }
print { path_segment $P 4 }
print { path_segment $P -1 }
```

Expected `OUTPUT`:

```text
"dict"
"obj1"
1
"after"
```

## make_pair — Build Key-Value Pair

Input:

```mantra
K = "doc.user.name";
print { make_pair K 1 }
print { make_pair ( path_segment "doc.user.name" -1 ) 2 }
```

Expected `OUTPUT`:

```text
"doc.user.name" -> 1
"name" -> 2
```

## Related Pages

- [JSON Loading](../rendering-structured-output/json-loading.md) — loading JSON into the variable trie
- [JSON Encoding](../rendering-structured-output/json-encoding.md) — converting Mantra values back to JSON
- [Path Access](../variables-bindings/path-access.md) — `get`, `path_segment`, `assign_path`
- [Query Helpers](../local-scopes/query-helpers.md) — `query_children`, `query_keys`, `query_values`
- [Data Index](../data/index.md) — overview of data model and types
