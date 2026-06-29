# Assignment Syntax

Assignment stores a tree snapshot under a variable name. The assignment operator
produces an AST node that validates the target, evaluates the right-hand side,
clones the result, and registers it in the runtime context.

```mantra
x = [ + 1 2 3 ]
```

Output:

```text
x = [ + 1 + 2 + 3 ]
```

The left side of a plain assignment is a binding target. It is not treated as an
ordinary variable reference during assignment.

## Forms

Mantra supports two assignment families: ordinary assignment (`=`) and deep
assignment (`:=` and variants). They differ in what they accept on each side
and how they mutate the context.

| Operator | Node | Target | Source | Behavior |
|---|---|---|---|---|
| `=` | `TAssignmentNode` | single variable | any expression | Clone evaluated RHS into context |
| `:=` | `TDeepAssignmentNode` | single variable | single variable | Replace entire variable subtree |
| `>:=` | `TDeepAssignmentNode` | single variable | single variable | Merge, source wins on conflict |
| `<:=` | `TDeepAssignmentNode` | single variable | single variable | Merge, existing wins on conflict |
| `!:=` | `TDeepAssignmentNode` | single variable | single variable | Merge, fail on conflict |

In addition, the `assign_path` callable provides path-based assignment to
arbitrary locations in the variable trie.

## Ordinary Assignment (`=`)

### Syntax

```mantra
<variable> = <expression>
```

- `<variable>` — a bare identifier (the binding target)
- `<expression>` — any subtree: literals, lists, scopes, operators, or other
  variables

The target must be a single variable with no siblings. Expressions like
`[ x y ] = 1` or `x y = 1` are rejected.

### Behavior

The runtime performs these steps:

1. **Validate target** — confirms the LHS is a single `OBJ_VARIABLE` node.
2. **Evaluate RHS** — sends the right side through `Evaluate`, resolving
   variables, processing scopes, and running nested operations.
3. **Clone result** — deep-copies the evaluated RHS subtree into the context.
4. **Register** — calls `TryAddScopedExactVariable` first (for local scope
   frames); if that fails, writes to the global context via `AddVariable`.
5. **Remove callable** — clears any callable binding for the same name so
   the variable shadows the callable.

### Clone Isolation

Assignment clones the RHS; it does not store a reference to the original
subtree. This prevents unintended aliasing when the source tree is later
modified by subsequent operations.

```mantra
x = [ 1 2 ]
y = x
x = [ 3 4 ]
print { y }
```

Output: `[ 1 2 ]`

Changing `x` after assigning `y = x` does not affect `y` — each assignment
independently clones its source.

### Rebinding

A variable can be reassigned any number of times. The new value replaces the
previous binding.

```mantra
x = 5
x = 10
print { x }
```

Output: `10`

### Assignment in Evaluation Scopes

Assignment works inside `{ ... }` evaluation scopes. The binding is visible to
subsequent statements in the same scope and in outer scopes (assignments escape
the evaluation scope).

```mantra
{ a = "x" }
print { a }
```

Output: `"x"`

### Rebinding Inside Rule Evaluation

The assignment-target guard ensures that `x` on the left side of `=` is never
resolved as a variable reference, even when the assignment appears inside an
evaluated rule body. This allows rules to rebind existing variables:

```mantra
{ a = "x" }
rule r [ r => { a = "y" } ];
{ r }
print { a }
```

Output: `"y"`

Without this guard, the `a` on the left would expand to its current value
`"x"`, which is not a valid assignment target.

## Deep Assignment (`:=` and Variants)

Deep assignment operates on the variable trie — the hierarchical structure of
variables organized by dot-separated paths. Both the target and source must be
single variable identifiers; deep assignment does not accept arbitrary
expressions.

The runtime implements deep assignment through `CopyVariableSubtree`, which
copies all keys sharing a given prefix from the source trie to the destination.
Each deep-assignment operator corresponds to a `TCopyMode`:

### Replace (`:=`)

Replaces the destination subtree entirely, removing any existing keys under the
destination prefix before copying source keys.

```mantra
a.x = 1
a.y = 2
b.x = 10
b.z = 20
a := b
print { query_children a }
print { query_children b }
```

The `a` subtree is replaced with the contents of `b`. Keys `a.x` and `a.y` are
replaced by `a.x` (10) and `a.z` (20).

### Merge Overwrite (`>:=`)

Merges source keys into the destination. When a key exists in both, the source
value overwrites the destination value.

```mantra
dict.obj1.a = 1
dict.obj1.b = 2
dict.obj2.a = 3
dict.obj2 >:= dict.obj1
print { query_values dict.obj2.* }
```

The key `dict.obj2.a` is overwritten by the source value (1), and `dict.obj2.b`
is added with value 2. Keys unique to the source (like `dict.obj1.b`) are
copied; keys unique to the destination are preserved.

### Merge Keep (`<:=`)

Merges source keys into the destination. When a key exists in both, the
existing destination value is kept — the source does not overwrite it.

```mantra
dict.obj1.a = 1
dict.obj1.b = 2
dict.obj2.a = 3
dict.obj2 <:= dict.obj1
```

The key `dict.obj2.a` retains its existing value (3) rather than being
overwritten by the source. New keys from the source (`dict.obj2.b = 2`) are
still added.

### Fail on Conflict (`!:=`)

Merges source keys into the destination, but raises an error if any key exists
in both. This is useful for validating that two subtrees are disjoint before
combining them.

```mantra
dict.obj1.a = 1
dict.obj2.a = 9
dict.obj2 !:= dict.obj1
```

Error: `Deep-assignment failed (dict.obj2 <- dict.obj1)`

The conflict on key `a` causes the operation to abort. No keys are modified.

### Deep Assignment Validation

Deep assignment enforces strict type checking on both sides:

- The **target** must be a single `OBJ_VARIABLE` node with no siblings.
  Expressions like `x y := z` or `[ x ] := z` are rejected with
  `Deep-assignment target must be a single variable`.
- The **source** must also be a single `OBJ_VARIABLE` node with no siblings.
  Expressions like `x := [ 1 2 ]` or `x := y z` are rejected with
  `Deep-assignment source must be a single variable`.

### Callable Shadowing

Like ordinary assignment, deep assignment clears any callable binding for the
destination prefix. If a callable shares the name of the destination, it is
removed and subsequent dispatch to that name resolves as a variable lookup
instead.

## Path-Based Assignment (`assign_path`)

The `assign_path` callable provides programmatic assignment to arbitrary paths
in the variable trie. Unlike `=` and `:=` which require literal identifiers,
`assign_path` accepts computed paths — strings, variables, or evaluated
expressions that resolve to path text.

### Syntax

```mantra
assign_path <path> <value>
assign_path <root> <path> <value>
assign_path <root> <key -> value>
```

- **Two-argument form** — `<path>` is the full dotted path; `<value>` is the
  subtree to store.
- **Three-argument form** — `<root>` is the base prefix; `<path>` is the
  suffix; the target is the concatenation of both.
- **Pair form** — `<root>` is the base prefix; `<key -> value>` is a
  variable-subtree pair (`->` syntax) where the key becomes the path suffix
  and the value is the stored subtree.

### Behavior

1. **Resolve path** — the path argument(s) must resolve to scalar text
   (string, variable, integer, etc.). If a structured value is passed,
   wrap it in `( ... )` or `{ ... }`.
2. **Clone value** — the value is deep-cloned into the context, same as
   ordinary assignment.
3. **Register** — the path is written via `AddVariable` into the trie.
4. **Remove callable** — any callable at the target path is cleared.
5. **Delete self** — the `assign_path` node removes itself from the AST.

### Examples

```mantra
assign_path "root.expr" ( + m n );
print { get "root.expr" };
```

Output: `+ m + n`

The path argument is evaluated to scalar text, and the value is cloned and
stored under that path.

With a root prefix:

```mantra
assign_path "root" "key" 42;
print { get "root.key" };
```

Output: `42`

The root and path are concatenated with a dot separator.

Pair form with variable-subtree syntax:

```mantra
import utils;
{ utils.trie_assign_indexed "cols" 1 ( a -> 1 ) };
{ utils.trie_assign_indexed "cols" 2 ( b -> 2 ) };
print { query_children "cols" };
```

Output: `"cols[1]" "cols[2]" "cols[3]"` (after three indexed assignments)

### assign_path in Evaluation Scopes

When called inside `{ ... }`, the path and value arguments are evaluated before
resolution:

```mantra
y = + 3 4;
{ assign_path "root.expr" ( y ) };
print { get "root.expr" };
```

Output: `+ 3 + 4`

The variable `y` is resolved during evaluation, and the result is cloned under
the target path.

### Error Messages

| Error | Cause |
|---|---|
| `assign_path expects 2 or 3 arguments: ...` | Fewer than 2 arguments provided |
| `assign_path path must resolve to scalar path text; wrap structured values in (...) or {...}` | The path argument evaluates to a structured value (list, scope) instead of scalar text |
| `assign_path does not accept unboxed structural values; wrap the value in (...) or {...}` | Unboxed structural expression passed as value (e.g. `assign_path "x" + m n` without wrapping) |
| `assign_path target path cannot be empty` | Both root and path arguments resolved to empty strings |
| `assign_path expected a variable-subtree pair as second argument` | The pair form received a non-pair value |
| `assign_path pair key is missing` | The pair form has no key identifier |
| `assign_path pair value is missing` | The pair form has no value after the key |

## Error Messages

### Ordinary Assignment

| Error | Cause |
|---|---|
| `Invalid assignment target: ...` | The LHS is not a single `OBJ_VARIABLE` node (e.g., a literal or operator) |
| `Assignment target must be a single variable: ...` | The LHS has siblings — e.g., `x y = 1` |
| `Missing assignment target before "="` | The parser sees `=` with no preceding expression |
| `Missing assignment value after "="` | The parser sees `=` with no following expression |

### Deep Assignment

| Error | Cause |
|---|---|
| `Invalid deep-assignment target: ...` | The LHS is not a single `OBJ_VARIABLE` node |
| `Deep-assignment target must be a single variable: ...` | The LHS has siblings |
| `Invalid deep-assignment source: ...` | The RHS is not a single `OBJ_VARIABLE` node |
| `Deep-assignment source must be a single variable: ...` | The RHS has siblings |
| `Deep-assignment failed (...)` | `!:=` mode encountered a key conflict, or the copy operation returned false |
| `Invalid deep-assignment mode bits: 0x...` | The operator has unexpected relational modifier bits |

## Related

- [Variables and Substitution](../variables.md) — how variables are resolved and substituted
- [Evaluation Scope](../../evaluation/evaluation-scope.md) — `{ ... }` scope semantics
- [Compute Scope](../../compute/compute-scope.md) — `` ` ... ` `` arithmetic scopes
- [Selection](../../transformations/selection.md) — the `?` operator with rules
- [Rule Declaration Syntax](./rule-declaration-syntax.md) — `rule` keyword and callable bindings
