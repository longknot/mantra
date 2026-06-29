# Dispatch Flags

Head dispatch controls whether the matcher automatically dispatches rule
application when an identifier appears as the first child (the "head") of
a `{ ... }` evaluation scope. When enabled, the runtime treats `{ name ... }`
as an implicit invocation of a callable named `name` against its remaining
children, applying the callable's rules as structural rewrites.

This mechanism lets you write rule calls in a function-call-like syntax
without explicit operators (`?`, `|=`).

## `--head-dispatch` (default)

Enable implicit rule dispatch for `{ head ... }` forms. This is the **default**
behavior.

```bash
./bin/mantra --head-dispatch program.m
```

When head dispatch is enabled, the runtime checks whether the head identifier
is registered as a callable (has associated rules). If it is, the matcher
attempts to rewrite the entire scope using those rules. The original scope
is replaced by the rewritten result.

### Example: Basic head dispatch

```mantra
# tests/cases/head_dispatch_select_query.in
define select from where ;
people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] ] ;
rule select [ select field from table where key val => ( table ? [ [ key val field out -- ] =>> out ] ) ] ;
print { select "name" from people where "id" 2 }
```

Output:
```
( "Jane Smith" )
```

Here, `{ select "name" from people where "id" 2 }` is dispatched automatically:
the `select` callable's rules are applied against the scope contents, producing
the matched result. No explicit `?` operator is needed.

### Example: Prefix matching with tail tolerance

Head dispatch matches the rule pattern against the scope, and extra trailing
elements that don't participate in the match are preserved in the output:

```mantra
# tests/cases/head_dispatch_prefix_tail_tolerant.in
rule mappings [
  mappings "The" => "A"
]

print { mappings "The" "quick" "brown" }
```

Output:
```
"A" "quick" "brown"
```

The rule `mappings "The" => "A"` matches the first two children (`mappings`
and `"The"`), rewriting them to `"A"`. The trailing `"quick" "brown"` are
preserved as siblings in the output.

### Example: Infix `--` (match-any) in head dispatch rules

Rules used for head dispatch can contain `--` to match arbitrary sequences:

```mantra
# tests/cases/head_dispatch_match_any_infix.in
rule json [
  json "{" X -- "}" => [ "OK" ]
]

print { json "{" "\"" "key" "\"" ":" "value" "}" }
```

Output:
```
[ "OK" ]
```

The `--` in the pattern absorbs everything between `X` (bound to `"\""`)
and the closing `"}"`, allowing flexible structural matching.

### Example: Variable dereferencing in head position

When the head argument is a variable, its value is dereferenced before
dispatch:

```mantra
# tests/cases/head_dispatch_subject_variable_deref.in
rule first [
  first [ x -- ] => x
]

print { first [ 1 2 3 ] }
input = [ 1 2 3 ]
print { first input }
```

Output:
```
1
1
```

Both calls produce the same result. In the second call, `input` resolves to
`[ 1 2 3 ]`, which is then dispatched as the subject of the `first` rule.

### Example: Rules defined inside evaluation scope

You can inline rules directly inside the dispatched scope:

```mantra
# tests/cases/head_dispatch_rule_defined_in_eval.in
print { rule foo [ foo x y => ( x y ) ] [ foo 1 2 ] }
```

Output:
```
[ ( 1 2 ) ]
```

The `rule foo [...]` declares the callable inline, and `[ foo 1 2 ]` is
dispatched against it within the same scope.

## `--no-head-dispatch`

Disable implicit rule dispatch. The runtime still evaluates `{ head ... }`
scopes normally, but the head identifier is **not** treated as an implicit
rule invocation.

```bash
./bin/mantra --no-head-dispatch program.m
```

Use this flag when you want explicit control over when and how rules are
applied. Without head dispatch, you must use explicit selection (`?`),
transform (`=>`), or inference (`|=`) to trigger rewrites.

### Example: Explicit selection instead of implicit dispatch

This test case disables head dispatch and manually applies a custom `select`
rule via an explicit `?` selection:

```bash
# tests/cases/head_dispatch_opt_out_explicit_selection.args
--no-head-dispatch
```

```mantra
# tests/cases/head_dispatch_opt_out_explicit_selection.in
define select from where ;
. people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] [ "id" 3 "name" "Alice Johnson" ] ] ;
. select_rule = [ [ select field from TABLE where key val ] => ( TABLE ? [ [ key val field out -- ] =>> out ] ) ] ;
print { [ select "name" from people where "id" 2 ] ? select_rule : 2 }
```

Output:
```
( "Jane Smith" )
```

With `--no-head-dispatch`, the `{ select ... }` form is not automatically
dispatched. Instead, the `? select_rule` explicitly applies the transformation,
giving you full control over which rules fire and when.

### Example: Preventing unintended dispatch

When head dispatch is disabled, identifiers in head position behave as
ordinary variables — they are not matched against callable rules:

```bash
# tests/cases/rule_name_auto_keyword_selection.args
--no-head-dispatch
```

```mantra
# tests/cases/rule_name_auto_keyword_selection.in
rule only [ only x => x ]
print { [ foo 1 ] ? only : 1 }
```

Output:
```
[ foo 1 ]
```

The `only` rule is available, but since head dispatch is disabled, `{ foo 1 }`
is not automatically dispatched. The explicit `? only` applies the rule to
the bracketed expression instead.

## Head Dispatch Depth Limit

Head dispatch has a hard depth limit of **128 levels** (`MAX_HEAD_DISPATCH_STEPS`).
When the limit is reached, further dispatch attempts fail — the scope is
evaluated normally without rule rewriting.

This prevents runaway recursion from self-referential callables:

```mantra
# tests/cases/head_dispatch_depth_limit_no_fallback.in
rule id [
  id X => id X
]

print { id 1 }
```

Output:
```
id 1
```

The `id` rule rewrites its subject to `id X`, which would normally trigger
another dispatch — creating infinite recursion. The depth limit stops this
after 128 levels. When the limit is hit, the node is left as-is (output:
`id 1`), and the program continues without error.

### Example: Depth limit with explicit fallback

You can combine `--no-head-dispatch` with explicit selection to avoid the
depth limit entirely when needed:

```bash
# tests/cases/head_dispatch_depth_limit_no_fallback.args
--no-head-dispatch
```

```mantra
# tests/cases/head_dispatch_depth_limit_no_fallback.in
rule only [ only x => x ]
print { [ foo 1 ] ? only : 1 }
```

Output:
```
[ foo 1 ]
```

With head dispatch off, recursion through implicit dispatch is impossible —
the `?` operator applies rules only once per invocation, independent of the
head dispatch depth counter.

## When to Use Each Flag

| Scenario | Flag |
|---|---|
| Normal interactive use | `--head-dispatch` (default) |
| Explicit rule control in tests/fixtures | `--no-head-dispatch` |
| Debugging unexpected dispatch behavior | `--no-head-dispatch` to isolate |
| SQL-style DSLs with reserved keywords | `--no-head-dispatch` + explicit `?` |
| Preventing accidental recursive dispatch | `--no-head-dispatch` when callables self-reference |

## Internal Behavior

### Dispatch Flow

When `HeadInvocationDispatchEnabled` is `True` (default), here is what happens
during evaluation of `{ head ... }`:

1. The runtime evaluates the scope and checks if the first child is an
   identifier that resolves to a callable with registered rules.
2. If found, `TryHeadDispatch` clones the scope (or uses it directly), applies
   `RewriteOneByRules` using the callable's rules, and replaces the original
   scope with the rewritten result.
3. If a rewrite is applied, the result is re-evaluated. If the tree revision
   changed during evaluation, dispatch is tried again.
4. If no rule matches or the depth limit is reached, normal scope evaluation
   proceeds without dispatch.

### Namespace and Head Override

Head dispatch supports two advanced features:

- **Namespace dispatch** (`DispatchNamespace`): When a callable specifies a
  namespace, the dispatch pushes that namespace onto the context stack before
  applying rules, ensuring rules resolve symbols in the correct scope.
- **Head override** (`DispatchHeadName`): A callable can specify a different
  name for the head identifier in the dispatched subject. The runtime clones
  the scope, replaces the head token with the override name, and dispatches
  the modified copy.

### Global Variables

| Variable | Type | Default | Set by |
|---|---|---|---|
| `HeadInvocationDispatchEnabled` | `Boolean` | `False` (set to `True` by default `--head-dispatch`) | `--head-dispatch` / `--no-head-dispatch` |
| `HeadDispatchDepth` | `Integer` | `0` | Incremented/decremented during dispatch |
| `MAX_HEAD_DISPATCH_STEPS` | `const Integer` | `128` | Compile-time constant |

The `options.HeadDispatch` flag in `mantra.lpr` defaults to `True`. It is
applied to `nodes.HeadInvocationDispatchEnabled` at session startup via
`mantra_session.pas`. The flag affects all evaluation for the entire session
— it cannot be toggled mid-execution.

### Debugger Integration

Head dispatch emits debugger events when a debugger is attached:
- `dekCallableDispatchEnter` when dispatch begins
- `dekCallableDispatchExit` when dispatch completes

These events create a `dfkCallableDispatch` frame, allowing breakpoints on
callable invocations via `--break-callable`.

## Comparison with Explicit Selection

| Feature | Head Dispatch (`--head-dispatch`) | Explicit Selection (`?`) |
|---|---|---|
| Syntax | `{ name args }` | `{ subject ? rules }` |
| Rule source | Callable registered by name | Inline or variable rules |
| Depth limit | 128 levels | No depth limit |
| Tail tolerance | Automatic | Automatic |
| Recursion risk | Bounded by depth limit | Controlled by `:` repeat |
| Debuggable | Yes (callable dispatch events) | Yes (selection events) |
| Use `--no-head-dispatch` | N/A (disabled) | Works regardless |
