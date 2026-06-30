# Variables and Bindings

Variables are the primary mechanism for storing and retrieving tree snapshots in
Mantra. Every value — integers, strings, arrays, operator trees — is stored
uniformly as a cloned AST subtree in the **variable trie**. Dotted paths like
`doc.user.name` create hierarchical keys that can be queried, merged, and
enumerated programmatically.

Variables participate in every stage of the evaluation lifecycle: they are
captured by assignment, resolved by substitution, scoped by namespace, and
merged by deep-assignment operators.

## Quick Reference

| Form | Description |
|---|---|
| `x = value` | Store a tree snapshot in variable `x` |
| `x := y` | Replace `x` subtree with `y` subtree (deep assignment) |
| `x >:= y` | Merge `y` into `x`; source wins on conflict |
| `x <:= y` | Merge `y` into `x`; existing values preserved |
| `x !:= y` | Merge `y` into `x`; raises error on conflict |
| `doc.name = "Ada"` | Dotted-path assignment (creates hierarchy) |
| `get "doc.name"` | Retrieve value at dotted path |
| `query_children "doc"` | List keys under a prefix |
| `assign_path "p" value` | Programmatic path assignment |
| `--set x=5` | Pre-define variable from CLI |

## What Variables Store

Variables hold **tree snapshots** — deep clones of the right-hand side expression
at the moment of assignment. The stored value is an independent copy; modifying
the original expression or reassigning the variable produces a new snapshot
without affecting earlier captures.

```mantra
x = [ 1 2 3 ];
y = x;
x = [ 4 5 6 ];
print { y };    # [ 1 2 3 ] — y still holds the original snapshot
```

Variables store structural templates, not evaluated results. If the right-hand
side contains operators or unresolved variable references, those are preserved
literally and resolved only when the variable is later used in an evaluation
context.

```mantra
template = ( + a b );
{ a = 3; b = 4 };
`template`;     # + 3 + 4 — operators resolved within compute context
```

For the full assignment lifecycle (Execute vs. Evaluate phases), see
[Assignment](variables-bindings/assignment.md).

## Dotted Paths and Hierarchy

Dotted names automatically create a path hierarchy in the variable trie. Each
dot-separated segment forms one level:

```mantra
doc.user.name = "Ada";
doc.user.age = 30;
doc.active = true;
```

This creates the hierarchy:

```
doc
  user
    name: "Ada"
    age:  30
  active: true
```

You retrieve dotted-path values with `get`:

```mantra
print { get "doc.user.name" };  # "Ada"
```

And enumerate children with `query_children`:

```mantra
print { query_children "doc.user" };  # ("name" "age")
```

For path operations — `get`, `path_segment`, `assign_path`, pattern matching —
see [Path Access](variables-bindings/path-access.md).

## Assignment Phases

Assignment behaves differently depending on whether it runs during the
**Execute** phase (statement-level) or the **Evaluate** phase (inside `{ }`
evaluation scopes):

- **Execute phase** — The RHS is cloned as-is. Operators remain unevaluated.
  The stored value is the raw tree structure.
- **Evaluate phase** — The RHS is evaluated first (variables resolved, computes
  reduced, scopes collapsed), then the result is cloned and stored.

```mantra
x = [ + 1 2 3 ];      # Execute: stores raw tree [ + 1 2 3 ]
print { x };           # [ + 1 2 3 ]

{ y = [ + 1 2 3 ] };  # Evaluate: RHS evaluated, compute reduced
print { y };           # [ + 6 ]
```

This distinction means variables can store either structural templates (for
repeat expansion and pattern matching) or resolved values (for immediate use).

## Deep Assignment

In addition to simple replacement (`=`), Mantra supports operators that merge
subtrees within the variable trie:

| Operator | Mode | Behavior |
|---|---|---|
| `:=` | Replace | Destroys destination subtree, replaces with source |
| `>:=` | Merge overwrite | Merges source; source wins on key conflict |
| `<:=` | Merge keep | Merges source; existing values preserved |
| `!:=` | Fail on conflict | Merges source; errors if any key collides |

```mantra
config.host = "localhost";
config.port = 8080;

override.port = 9090;
override.debug = true;

config >:= override;
print { get "config.host" };  # "localhost" (preserved)
print { get "config.port" };  # 9090 (overwritten)
print { get "config.debug" }; # true (newly added)
```

Deep assignment operates on the trie structure — both sides must resolve to
single variable identifiers. For details, see [Assignment](variables-bindings/assignment.md).

## Variable Resolution

When a variable is referenced in an expression, the runtime resolves it through
a lookup chain:

1. **Exact scope frame** — If an evaluation scope is active, checks the local
   scope first via `TryFindScopedExactVariable`.
2. **Namespace-qualified lookup** — Applies the current namespace prefix
   (`FCurrentNamespace`) via `QualifyLocalName`.
3. **Global fallback** — If namespace lookup fails, falls back to an unqualified
   global lookup.

```mantra
x = "global";
{ x = "local"; print { x } };  # "local" — exact scope takes priority
print { x };                    # "global" — falls back to global after scope exits
```

## Variable Substitution

When a variable is resolved, its stored tree is **cloned** and substituted at
the reference point. This means every use of a variable produces an independent
copy — the original stored value is never modified in place.

Variables with unresolved references inside them support **late binding**: the
unresolved references are preserved in the stored tree and resolved only when
the variable is later evaluated in a context where those references exist.

```mantra
s = ( + x : + p );   # p is not yet defined — stored literally
{ p = 3 };
print { s };          # + x + x + x — p resolved to 3 at use time
```

## CLI Pre-Definition

The `--set` flag predefines variables before any source code executes. Variables
defined this way are available in the first statement of the program and persist
throughout execution.

```bash
mantra --set n=3 --set name="world" program.m
```

Multiple `--set` flags are processed left to right; later definitions of the
same name overwrite earlier ones. The expression is parsed as Mantra source, not
as a literal string, so you can pass structured values:

```bash
mantra --set rules='[ x => x + 1 ]' program.m
```

For details, see [CLI Set](variables-bindings/cli-set.md).

## Callable Override

Assignment automatically removes any callable binding with the same name. If
`foo` was previously defined as a callable, `foo = 42` replaces it with a
variable binding. The namespace stays consistent — a variable assignment always
supersedes a callable definition.

```mantra
callable greet ( x ) = [ hello x ];
print { greet "Ada" };     # [ hello "Ada" ]

greet = "static";
print { greet };            # "static" — callable replaced by variable
```

## Variable Trie Internals

The variable store is implemented as a trie (`TVariableTrie` /
`TTrieDictionary`) inside `TContext`. Key characteristics:

- **Hierarchical storage** — Dotted paths map to trie nodes. `a.b.c` creates
  three levels: `a` → `b` → `c`.
- **Indexed variables** — The trie supports indexed children (e.g., from
  `json_load` arrays or witness steps), accessed via `EnsureIndexedVariableChild`
  and `AddIndexedVariable`.
- **Namespace qualification** — A `FCurrentNamespace` prefix is applied to all
  writes and reads, so `package foo; x = 1` stores `foo.x`.
- **Exact scope frames** — Evaluation scopes push/pop frames that intercept
  variable lookups before the global trie is consulted.

## Related Pages

- [Assignment](variables-bindings/assignment.md) — `=`, `:=`, `>:=`, `<:=`, `!:=`, Execute vs. Evaluate phases, path assignment, error handling
- [Path Access](variables-bindings/path-access.md) — `get`, `path_segment`, `assign_path`, pattern matching, `query_children`
- [CLI Set](variables-bindings/cli-set.md) — `--set` flag, pre-definition, interactive mode, execution order
- [Local Scopes](local-scopes.md) — Visibility, namespace qualification, query helpers
- [Evaluation Scopes](../evaluation/evaluation-scopes.md) — How `{ }` scopes trigger variable resolution
- [Namespaces and Packages](namespaces-packages.md) — Modular code composition

## Related Sections

- [Language Model](../language-model/index.md) — Programs as trees (foundational concept)
- [Data](index.md) — Data model overview (values, lists, structured output)
- [Transformations](../transformations/index.md) — How variables interact with `:` repeat and `?` selection
