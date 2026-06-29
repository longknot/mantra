# Working With Data

This section covers how data is represented, stored, queried, and rendered in
Mantra. In Mantra, **code is data is trees** — every value is an AST node.
Variables hold tree snapshots, lists are sequences of nodes, and structured
output transforms trees into user-readable formats.

## Overview

Data in Mantra flows through five interconnected areas:

| Area | What It Covers | Key Operators / Directives |
|---|---|---|
| [Lists and Sequences](lists-sequences.md) | Arrays, ranges, concatenation, string splitting | `[ ]`, `&`, `..`, `explode`, `implode` |
| [Variables and Bindings](variables-bindings.md) | Assignment, dotted paths, CLI pre-definitions | `=`, `:=`, `get`, `assign_path`, `--set` |
| [Local Scopes](local-scopes.md) | Visibility, namespace qualification, query helpers | `global`, `.`-qualified names, `query_children` |
| [Namespaces and Packages](namespaces-packages.md) | Modular code composition and package resolution | `package`, `import`, `include`, `global` |
| [Selection and Witness Forms](selection-witness-forms.md) | Pattern matching, inference, proof traces | `?`, `:=?`, `\|=`, `?\|=`, `$`, `^` |
| [Rendering Structured Output](rendering-structured-output.md) | Format strings, JSON import/export, display | `fmt`, `printf`, `json_load`, `json_save`, `json_encode`, `display` |
| [External API Calls](external-api-calls.md) | Controlled HTTP and JSON service calls | `system http` |

## Data Model

Every value in Mantra is a tree node (`TTreeNode`). The language has no
separate "primitive" types — integers, strings, booleans, and arrays are all
node types that participate uniformly in evaluation, assignment, and
transformation.

### Core Value Types

| Type | Syntax | Node Class |
|---|---|---|
| Integer | `42`, `-7` | `TIntegerNode` |
| Float | `3.14`, `1.0E+2` | `TFloatNode` |
| String | `"hello"`, `'world'` | `TStringNode` |
| Boolean | `true`, `false` | (identifier nodes with fixed values) |
| Null | `null` | (identifier node) |
| Array / List | `[ 1 2 3 ]` | `TArrayNode` |
| Expression | `( + 1 2 )` | `TExpressionNode` |
| Evaluation Scope | `{ x = 1 }` | `TEvaluationNode` |
| Compute Scope | `` ` + 1 2 ` `` | `TComputeNode` |
| Fixed Scope | `' x y '` | `TFixedNode` |

### Variable Storage

Variables store **tree snapshots** — deep clones of the right-hand side
expression at assignment time. The variable trie supports hierarchical (dotted)
paths, so `doc.user.name = "Ada"` creates a three-level path that can be
retrieved with `get "doc.user.name"` or `doc.user.name`.

```mantra
doc.user.name = "Ada";
doc.user.age = 42;
doc.user.active = true;

print { get "doc.user.name" };  # "Ada"
print { query_children doc.user };  # ("name" "age" "active")
```

### Structural Identity

Because values are trees, you can:

- **Inspect** their structure without evaluation using fixed scopes (`' ... '`)
- **Clone** them into variables without referencing the original
- **Transform** them with selection rules (`?`) or repeat (`:`)
- **Encode** them to JSON for interoperability (`json_encode`)
- **Load** external JSON data into the variable trie (`json_load`)
- **Save** compatible trie data to JSON files (`json_save`)

## Data Flow

Data moves through a Mantra program in these stages:

1. **Creation** — Literals, arrays, and ranges create values inline.
   ```mantra
   [ 1 2 3 ]          # array literal
   1 .. 5             # range: 1 2 3 4 5
   explode "abc"      # string to characters: "a" "b" "c"
   ```

2. **Assignment** — Values are stored in the variable trie.
   ```mantra
   x = [ 1 2 3 ];
   config.threshold = 0.8;
   ```

3. **Retrieval** — Values are read back by name or path.
   ```mantra
   print { x };
   print { get "config.threshold" };
   ```

4. **Transformation** — Values are rewritten by rules or expanded by repeat.
   ```mantra
   [ 1 2 3 ] ? [ x => x * 2 ];     # selection
   [ item ] : 3;                    # repeat: [ item ] [ item ] [ item ]
   ```

5. **Rendering** — Values are formatted for output or serialized.
   ```mantra
   fmt "Name: %s, Age: %d" "Ada" 42;       # format string: "Name: Ada, Age: 42"
   json_encode doc;                         # trie to JSON
   display "application/json" chart;        # structured notebook output
   ```

## External Data

Mantra can load structured data from external files:

- **JSON** — `json_load "data.json" root` parses a JSON file and materializes
  it as a trie under the `root` prefix. Nested objects become dotted paths;
  arrays become indexed entries (1-based).
- **HTTP APIs** — `system http response request` sends an explicitly enabled,
  policy-controlled request and materializes status, headers, text, and JSON
  response data.
- **CLI variables** — `--set name=value` predefines variables before program
  execution, enabling parameterized runs and configuration injection.
- **Include files** — `include "helpers.m"` loads source files that define
  variables, callables, and rules.

For details, see [JSON Loading](rendering-structured-output/json-loading.md),
[External API Calls](external-api-calls.md), [CLI Set](variables-bindings/cli-set.md),
and [Include Files](namespaces-packages/include-files.md).

## Related Sections

- [Language Model](../language-model/index.md) — Programs as trees (foundational concept)
- [Evaluation and Execution](../evaluation/index.md) — How `{ }` scopes trigger evaluation
- [Transformations and Repeat](../transformations/index.md) — `:` repeat and `?` selection operators
- [Compute and Operators](../compute/index.md) — `` ` ` `` compute scopes and arithmetic reduction
