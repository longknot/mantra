# Path Access

Dotted paths are the primary way to organize and navigate variables in Mantra. A
dotted path such as `doc.first_name` stores a value under a hierarchical key that
can be retrieved, assigned, and manipulated programmatically.

## Storing Dotted-Path Variables

Dotted names automatically create a path in the variable store. Each dot-separated
segment forms one level of the hierarchy.

```mantra
doc.first_name = "John";
doc.last_name = "Doe";
doc.age = 30;
```

Path segments are joined with a literal dot. The `assign_path` directive provides
the explicit API for programmatic path writes. See **Assigning with `assign_path`**
below.

## Retrieving with `get`

The `get` directive resolves a path string to the variable value stored at that
location. It accepts three forms:

### Literal path

Pass a quoted string containing the full dotted path:

```mantra
doc.first_name = "John";

print { get "doc.first_name" }
```

**Output:**

```text
"John"
```

### Variable reference

Pass a bare variable that evaluates to a path string:

```mantra
doc.first_name = "John";
P = "doc.first_name";

print { get $P }
```

**Output:**

```text
"John"
```

### Computed path expression

Any expression that resolves to a scalar path string works:

```mantra
x = 1;
print { get { fmt "%s" [ "x" ] } }
```

**Output:**

```text
1
```

The `get` directive first tries an exact lookup via `TryFindVariable`. If no exact
match is found, it falls back to a pattern scan via `ScanVariables`, so indexed
patterns (e.g., containing `{n}` wildcards) will also resolve if they produce a
single exact match.

## Path Segments with `path_segment`

The `path_segment` function extracts an individual segment from a dotted path by
1-based index. Negative indices count from the end.

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

### Square bracket segments

Segments inside square brackets (e.g., `[1]` in `steps[1]`) are parsed as
separate segments. When `path_segment` returns a bracket segment, it is emitted
as an integer node rather than a string:

```mantra
print { path_segment $P 4 }   # bracket segment [1] -> integer 1
print { path_segment $P 5 }   # beyond end -> empty string
```

**Output:**

```text
1
""
```

### Out of range

If the index is out of range, `path_segment` returns an empty string:

```mantra
print { path_segment "a.b.c" 5 }
```

**Output:**

```text
""
```

### Errors

`path_segment` requires exactly two arguments and the index must be parseable as
an integer. Otherwise it raises an exception:

```mantra
print { path_segment "a.b.c" }         # error: expects 2 arguments
print { path_segment "a.b.c" "abc" }   # error: index must be an integer
```

## Assigning with `assign_path`

`assign_path` writes a value to an arbitrary dotted path at runtime. It accepts
two argument forms:

### Two-argument form: `assign_path <path> <value>`

```mantra
assign_path "root.key1" "hello";
print { get "root.key1" };
```

**Output:**

```text
"hello"
```

### Three-argument form: `assign_path <root> <path> <value>`

The `root` prefix is prepended to the `path` segment:

```mantra
assign_path "root" "key2" "world";
print { get "root.key2" };
```

**Output:**

```text
"world"
```

### Pair form: `assign_path <root> <path -> value>`

A variable-subtree pair binds a key to a value:

```mantra
assign_path "root" { key3 -> "value3" };
print { get "root.key3" };
```

**Output:**

```text
"value3"
```

### Structured expressions

When the value is a structured expression (operator tree), wrap it in parentheses
or braces. Bare unboxed structures are rejected:

```mantra
assign_path "root.expr1" ( + m n );   # OK - wrapped in parens
print { get "root.expr1" };
```

**Output:**

```text
+ m + n
```

The unboxed variant fails:

```mantra
assign_path "root.expr" + m n;        # Error: wrap in (...) or {...}
```

### Computed paths

Both the `root` and `path` arguments are evaluated and must resolve to scalar
text. If they resolve to a structured value instead, an error is raised:

```
Error: assign_path path must resolve to scalar path text;
       wrap structured values in (...) or {...}
```

### Path joining

When a root and path are combined, `JoinTriePath` normalizes the result:
trailing and leading dots are stripped, and double dots collapse to single dots.

## Pattern Matching in Path Resolution

When `get` does not find an exact variable match, it falls back to
`ResolveIndexedVariablePattern` and `ScanVariables`. This means indexed patterns
(e.g., paths containing `{n}` placeholders that correspond to repeat or selection
indices) will be resolved if they produce an exact match.

Similarly, `query_children` uses `ScanVariableChildren` to enumerate all variables
under a given prefix, which is useful for discovering nested keys:

```mantra
doc.first_name = "John";
doc.last_name = "Doe";
doc.age = 30;

print { query_children "doc" };
```

**Output:**

```text
("first_name" "last_name" "age")
```

## Path Access with JSON

When data is loaded from JSON, the keys are stored as dotted-path variables.
`get` retrieves them using the same path syntax:

```mantra
json_load "data.json";
print { get "user.name" };
print { get "user.address.city" };
```

## Cross-References

- **Global dotted names** -- how dotted names are parsed and resolved in variable
  lookup. See `global-dotted-names.md`.
- **Query helpers** -- `query_children`, `query_keys`, `query_values` for
  enumerating paths. See `query-helpers.md`.
- **Assignment** -- how `:=`, `>:=`, `<:=` operators interact with dotted paths.
  See `assignment.md`.
- **Evaluation scopes** -- how namespace scoping affects path resolution. See
  `evaluation-scopes.md`.
