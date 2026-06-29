# Assignment

Assignment stores a tree snapshot in the variable context. The right-hand side
is cloned into the context's variable trie, and the variable name is bound to
that clone.

## Syntax

```
Variable = Expression
```

- `Variable` — a single identifier (the target name)
- `=` — the assignment operator (`TK_ASSIGNMENT`)
- `Expression` — any Mantra expression (evaluated or structural, depending
  on context)

```mantra
x = [ + 1 2 3 ]
```

Expected `OUTPUT`:

```text
x = [ + 1 + 2 + 3 ]
```

## Evaluation Lifecycle

Assignment participates in two phases of the evaluation lifecycle:

### Execute Phase

In `TAssignmentNode.Execute`, the RHS subtree is **cloned** and stored without
evaluating it first. The RHS retains its original structure.

```mantra
x = [ + 1 2 3 ]
print { x }
```

Expected `OUTPUT`:

```text
x = [ + 1 2 3 ]
[ + 1 2 3 ]
```

The stored value is the raw tree — operators have not been reduced.

### Evaluate Phase

In `TAssignmentNode.Evaluate`, the RHS is **evaluated first**, then the result
is cloned and stored. This means arithmetic operations, variable lookups, and
computes inside `{ }` scopes are resolved before the value is saved.

```mantra
x = [ + 1 2 3 ]
`x`
```

Expected `OUTPUT`:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The `Evaluate` phase evaluates the RHS (`[ + 1 2 3 ]` becomes `[ + 6 ]` after
compute reduction), then clones that result for storage.

## Structural Cloning

Assignment always **clones** the RHS subtree — it does not reference it in
place. Each variable holds an independent copy:

```mantra
x = [ 1 2 3 ];
y = x;
```

`x` and `y` now point to separate tree clones. Modifying one does not affect
the other.

### Immutability After Capture

The tree snapshot captured by assignment is a point-in-time copy. Later
re-evaluation of the original expression produces fresh values, but the stored
variable retains what it captured:

```mantra
x = [ 1 ];
print { { y = x } };
x = [ 2 ];
print { y };
```

Expected `OUTPUT`:

```text
y = [ 1 ]
[ 1 ]
```

Even though `x` was reassigned to `[ 2 ]`, `y` still holds `[ 1 ]` — the
snapshot taken when `y = x` was executed.

## Variable Lookup and Substitution

When a variable is used later in an expression, it is resolved through the
context's variable trie. The variable node looks up the stored tree index and
substitutes a clone of it at the use site.

```mantra
x = [ + 1 2 3 ]
`x`
```

Expected `OUTPUT`:

```text
x = [ + 1 + 2 + 3 ]
[ + 6 ]
```

The variable `x` in the backtick scope is resolved to its stored tree
(`[ + 1 + 2 + 3 ]`), which is then evaluated within the compute context
to produce `[ + 6 ]`.

### Late Binding in Structural Templates

Assignment captures the literal tree structure. If the RHS contains unresolved
variable references, those references are preserved and resolved at use time:

```mantra
s1 = + x : + p;
s2 = + x : + 2 p 2;

print { s1 };
print { s2 };

{ p = 3 };
print { s2 };
```

Expected `OUTPUT`:

```text
+ x : + p
+ x + x ( + x : + p ) + x + x
+ x + x + x + x + x + x + x
```

When `s2` is first printed, `p` is stored literally (not yet defined). After
`p = 3` is executed inside an evaluation scope, the repeat operator resolves
`p` to `3` and expands `+ x` three times.

## Scope and Namespace

### Local vs. Global Writes

Assignment respects the current namespace. In namespace-aware contexts (e.g.,
packages or function scopes), writes are qualified with the local namespace
prefix unless global writes are explicitly enabled.

### Scoped Variables in Evaluation Scopes

Inside `{ }` evaluation scopes, variables can be scoped to that block.
`TryAddScopedExactVariable` attempts to store the variable in an exact-scope
frame first. If no exact scope is active, or if global writes are enabled,
the variable falls through to the global variable trie:

```mantra
x = [ 1 ];
print { { y = x } };  // y is scoped to this evaluation scope
x = [ 2 ];
print { y };          // y is still accessible (scope leaked for output)
```

Expected `OUTPUT`:

```text
y = [ 1 ]
[ 1 ]
```

### Namespace Qualification

The context maintains a `FCurrentNamespace`. When writing, names are prefixed
with the namespace via `QualifyWriteName`. When reading, `QualifyLocalName`
applies the same prefix. This ensures that variables defined in one package
don't collide with variables in another.

## Callable Override

Assignment automatically removes any callable binding with the same name. If
`foo` was previously a callable, `foo = 42` replaces it with a variable:

```mantra
callable foo ( x ) = x + 1;
print { foo 5 };

foo = 42;
print { foo };
```

The `RemoveCallable` call in both `Execute` and `Evaluate` ensures the name
space stays consistent — a variable assignment supersedes a callable definition.

## Deep Assignment

In addition to the basic `=` operator, Mantra supports deep assignment
operators that operate on the variable trie structure rather than replacing
single variables:

### Deep Assignment Operators

| Operator | Mode | Behavior |
|---|---|---|
| `:=` | Replace | Replaces the entire destination subtree with the source subtree |
| `>:=` | Merge Overwrite | Merges source into destination; source values overwrite on conflict |
| `<:=` | Merge Keep | Merges source into destination; existing values are kept on conflict |
| `!:=` | Fail on Conflict | Merges source into destination; raises an error on conflict |

### Deep Assignment Syntax

```
DestinationVariable Operator SourceVariable
```

Both sides must be single variable identifiers — not expressions.

```mantra
dict.obj1.a = 1;
dict.obj2.a = 9;
dict.obj2 !:= dict.obj1;
```

Expected `OUTPUT`:

```text
Error: Deep-assignment failed (dict.obj2 <- dict.obj1)
```

The `!:=` operator fails because `dict.obj2.a` already exists and conflicts
with the incoming `dict.obj1.a` value.

### Deep Assignment Modes

#### Replace (`:=`)

Completely replaces the destination subtree:

```mantra
x = [ 1 2 3 ];
y = [ a b ];
x := y;
print { x };
```

`x` now contains what `y` contained, and any children previously under `x`
are removed.

#### Merge Overwrite (`>:=`)

Merges source into destination. On conflict, the source value wins:

```mantra
a.x = 1;
a.y = 2;
b.x = 10;
a >:= b;
print { a.x };  // 10 (overwritten by b.x)
print { a.y };  // 2 (preserved, no conflict)
```

#### Merge Keep (`<:=`)

Merges source into destination. On conflict, the existing value is preserved:

```mantra
a.x = 1;
a.y = 2;
b.x = 10;
a <:= b;
print { a.x };  // 1 (kept, not overwritten)
print { a.y };  // 2
```

#### Fail on Conflict (`!:=`)

Merges source into destination but raises an error if any key already exists:

```mantra
dict.obj1.a = 1;
dict.obj2.a = 9;
dict.obj2 !:= dict.obj1;  // Error: conflict on dict.obj2.a
```

## Path Assignment

For dotted-path targets that aren't simple variable names, use `assign_path`:

```mantra
assign_path "root.expr1" ( + m n );
print { get "root.expr1" };
```

Expected `OUTPUT`:

```text
+ m + n
```

`assign_path` accepts 2 or 3 arguments:
- `assign_path <path> <value>` — assigns to the dotted path
- `assign_path <root> <path> <value>` — assigns relative to a root variable

The path argument must resolve to a scalar string. Wrap structured values
in `( ... )` or `{ ... }` to prevent parsing errors:

```mantra
assign_path "root.expr" + m n;
```

Expected `OUTPUT`:

```text
Error: assign_path path must resolve to scalar path text; wrap structured values in (...) or {...}
```

## Error Handling

### Missing LHS

Assignment requires a target on the left side:

```mantra
{ = 1 }
```

Expected `OUTPUT`:

```text
Error: Missing assignment target before "="
```

### Invalid Target

The LHS must be a single variable identifier:

```mantra
raise Exception.CreateFmt('Invalid assignment target: %s', [Node[LHS].TreeValue]);
```

Composite expressions, paths, or operator results on the left side produce an
error.

### Deep Assignment Target/Source Validation

Both sides of a deep assignment must be single variable identifiers:

```
Deep-assignment target must be a single variable: ...
Deep-assignment source must be a single variable: ...
```

## Assignment in Different Contexts

### In Evaluation Scopes

Inside `{ }`, assignment uses the `Evaluate` path — the RHS is evaluated
before being stored:

```mantra
{ x = + 1 2 };
print { x };
```

### In Compute Scopes

Variables can be referenced inside backtick compute scopes:

```mantra
x = [ 1 ];
`x`
```

Expected `OUTPUT`:

```text
x = [ 1 ]
[ 1 ]
```

### With Repeat

Variables store structural templates that participate in repeat expansion:

```mantra
values = ( a b c );
print { [ x ] :: values @ x }
```

Expected `OUTPUT`:

```text
[ a ] [ b ] [ c ]
```

The `values` variable stores `( a b c )` as a structural template. The staged
repeat `::` iterates over it, binding each element to `x` via `@`.

## Comparison with Other Languages

| Aspect | Mantra | Conventional Languages |
|---|---|---|
| Stored value | Tree snapshot (AST clone) | Memory reference or value copy |
| Mutability | Reassignment replaces the clone | In-place mutation possible |
| Type system | None (trees are homogeneous) | Static or dynamic types |
| Scoping | Namespace-qualified + exact scope frames | Block/function/module scope |
| Deep operations | `:=`, `>:=`, `<:=`, `!:=` on variable trie | Manual merge/replace needed |

## See Also

- [Path Access](path-access.md) — Dotted-path variable queries
- [CLI Set](cli-set.md) — Pre-defining variables via `--set`
- [Evaluation Scopes](../../syntax/evaluation-scopes.md) — `{ }` scope semantics
- [Selection](../../transformations/selection.md) — `?` rewrite operator
