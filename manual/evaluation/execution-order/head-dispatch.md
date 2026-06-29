# Head Dispatch

Head dispatch automatically applies callable rule definitions when you write an
invocation-like form `name arg1 arg2 ...` inside an evaluation scope. Instead
of requiring an explicit selection operator `?`, the runtime detects that
`name` is a registered callable and dispatches its stored rules against the
invocation.

```mantra
rule double [ double x => ( x x ) ];
print { double 7 }
→ 7 7
```

The `{ double 7 }` form dispatches to the `double` rule automatically. Without
head dispatch, you would need to write `{ [ double 7 ] ? double : 2 }`
manually.

---

## How It Works

### Entry Point

Head dispatch lives inside `TVariableNode.Evaluate`. When the runtime evaluates
a variable node, it checks a series of conditions before attempting dispatch:

1. The node is **not** in selection-rules-template mode (`vrmSelectionRulesTemplate`).
2. The variable `Name` is non-empty.
3. `Context.IsCallable(Name)` returns true — the name is registered as callable.
4. `Context.TryResolveCallableBinding(Name, ...)` succeeds — rules exist for this name.
5. The node has RHS arguments **or** the name is a keyword
   (`(RHS <> EOT) or Context.IsKeyword(Name)`).

If all conditions pass, `TryHeadDispatch` is called.

### What Happens Inside Dispatch

`TryHeadDispatch` performs a root-oriented rewrite:

```
RewriteOneByRules(GlobalTree, Index, RulesIndex, Context,
                  RewrittenIndex, False, True)
```

Key parameters:
- **`MatchSubexpressions = False`** — dispatch targets the invocation root, not
  arbitrary subexpressions.
- **`AllowRootPrefixTail = True`** — the matcher tolerates prefix-tail patterns,
  so unmatched arguments survive the rewrite as a tail.

On success, the rewritten tree replaces the original node in its parent context
and is immediately evaluated. On failure, the runtime falls through to the
normal variable resolution path.

### Second-Chance Dispatch

If the first dispatch attempt does not complete, the runtime evaluates the node
through the inherited path (`inherited Evaluate(Context)`) and then attempts
dispatch again if:

- The tree revision changed (something was rewritten).
- The node is still alive.
- The node still has RHS arguments.

This supports flows where arguments need one evaluation pass before rules can
match — for example, when a variable reference in the argument position must be
dereferenced first.

---

## Callable Registration

Callable status is explicit context state, not inferred from tree structure.

### Declaring Callables

```mantra
rule foo [ foo x => x + 1 ];
```

The `rule` keyword does three things:
1. Registers `foo` as a keyword.
2. Stores the rule definition under the variable `foo`.
3. Marks `foo` as callable via `AddCallable`.

### Removing Callable Status

A deep assignment removes the callable mark:

```mantra
rule bar [ bar x => x * 2 ];
print { bar 5 }     → 10

. bar = [ 1 2 3 ];  # assignment removes callable mark
print { bar 5 }     → bar 5  (no dispatch, ordinary variable + tail)
```

### Callable vs. Non-Callable Variables

| State | Behavior |
|---|---|
| `rule name [...]` | `name` is callable — head dispatch activates |
| `. name = ...` | `name` loses callable mark — no dispatch |
| Ordinary variable | Never callable unless declared with `rule` |

---

## Namespace-Aware Dispatch

When a callable is resolved with an explicit namespace (via
`TryResolveCallableBinding`), dispatch pushes that namespace onto the context's
callable and setting namespace stacks before rewriting, and pops them afterward.

```mantra
# Rules with qualified names can dispatch with namespace isolation.
```

---

## Prefix-Tail Tolerance

Head dispatch allows rules to match only the prefix of an invocation.
Unmatched arguments are preserved as a tail after the rewrite.

```mantra
rule mappings [
  mappings "The" => "A"
]

print { mappings "The" "quick" "brown" }
→ "A" "quick" "brown"
```

The rule `mappings "The" => "A"` matches the head `"The"`. The remaining
arguments `"quick" "brown"` are preserved as the tail.

This behavior is controlled by `AllowRootPrefixTail = True` in the rewrite
call. It means a rule does not need to consume all arguments — it can rewrite
the prefix and leave the rest.

**Caution:** Prefix-tail tolerance can produce surprising results if your rule
shape is imprecise. Always test with extra arguments to verify tail handling.

---

## Recursion Safety

Head dispatch has two layers of protection against infinite loops.

### Hard Depth Limit

`MAX_HEAD_DISPATCH_STEPS` is set to **128**. Each dispatch increments
`HeadDispatchDepth`; once the limit is reached, dispatch stops and the
invocation falls through to ordinary evaluation.

```mantra
rule id [
  id X => id X    # Self-referencing rule that never shrinks
]

print { id 1 }
→ id 1    # Halted — recursion guard stopped the loop
```

When halted, the runtime emits a diagnostic event and returns the unrewritten
form.

### Non-Shrinking Guard

Even before reaching the hard depth limit, the runtime detects non-productive
recursion. After a rewrite, it checks whether the same callable appears again
in the result. Recursion is allowed only if:

- The tail width shrinks (fewer arguments than before), **or**
- The nested invocation has a different structural signature from the previous one.

Otherwise, recursion is halted immediately with a diagnostic:

```
head dispatch halted for "id": rewritten callable tail did not shrink
```

This heuristic catches pure self-reinsertion loops while still permitting valid
recursive reductions like `matrix_inner_product` where the tail genuinely
shrinks each step.

---

## Variable Dereference in Arguments

Head dispatch supports arguments that are variable references. The second-chance
dispatch mechanism ensures variables are dereferenced before rules are applied.

```mantra
rule first [
  first [ x -- ] => x
]

# Direct argument — dispatch works immediately.
print { first [ 1 2 3 ] }
→ 1

# Variable reference — first pass dereferences, second pass dispatches.
input = [ 1 2 3 ]
print { first input }
→ 1
```

In the second case, `input` is a variable reference, not an array literal. The
first evaluation pass resolves `input` to `[ 1 2 3 ]`. The tree revision
changes, triggering a second dispatch attempt where the rule now matches the
concrete array.

---

## Rules Defined Inline

Rules can be declared and invoked in the same evaluation scope:

```mantra
print { rule foo [ foo x y => ( x y ) ] [ foo 1 2 ] }
→ [ ( 1 2 ) ]
```

The `rule foo [...]` registers the callable before the inner `[ foo 1 2 ]`
evaluates. The dispatch then fires against the freshly-registered rule.

---

## Pattern Matching in Dispatch

Head dispatch rules use the full matcher syntax — lowercase captures, uppercase
any-match, and `--` for tail sequences.

### Infix Match-Any with `--`

```mantra
rule json [
  json "{" X -- "}" => [ "OK" ]
]

print { json "{" "\"" "key" "\"" ":" "value" "}" }
→ [ "OK" ]
```

The `--` wildcard captures everything between `"{"` and `"}"`, allowing the
rule to match variable-length argument sequences.

### Structured Query Dispatch

```mantra
define select from where ;

people = [ [ "id" 1 "name" "John Doe" ]
           [ "id" 2 "name" "Jane Smith" ] ] ;

rule select [
  select field from table where key val
    => ( table ? [ [ key val field out -- ] =>> out ] )
]

print { select "name" from people where "id" 2 }
→ ( "Jane Smith" )
```

The `define` keyword makes `select`, `from`, `where` keywords so they participate
in pattern matching without being consumed as arguments. The `select` rule
receives the full invocation and rewrites it into a selection query.

---

## Disabling Head Dispatch

Head dispatch is enabled by default. Use `--no-head-dispatch` to disable it:

```bash
./bin/mantra --no-head-dispatch program.m
```

With head dispatch disabled, invocation-like forms do not trigger implicit rule
application. They evaluate as ordinary variable + argument sequences unless you
apply rules explicitly with `?`.

```mantra
# With --no-head-dispatch, use explicit selection:
define select from where ;
. people = [ [ "id" 1 "name" "John Doe" ]
             [ "id" 2 "name" "Jane Smith" ]
             [ "id" 3 "name" "Alice Johnson" ] ] ;
. select_rule = [ [ select field from TABLE where key val ]
                   => ( TABLE ? [ [ key val field out -- ] =>> out ] ) ] ;
print { [ select "name" from people where "id" 2 ] ? select_rule : 2 }
→ ( "Jane Smith" )
```

---

## Debugger Integration

Head dispatch events are exposed to the debugger:

- **`dekCallableDispatchEnter`** — emitted when dispatch begins.
- **`dekCallableDispatchExit`** — emitted when dispatch completes.

The debugger frame includes the callable name, tree value, node index, and
rules index. Use `--break-callable NAME` to pause execution when a specific
callable dispatches.

---

## Head Dispatch vs. Explicit Selection

| Aspect | Head Dispatch | Explicit Selection (`?`) |
|---|---|---|
| Syntax | `name args` | `subject ? rules` |
| Callable check | Required — name must be callable | Not required — any rules work |
| Namespace | Pushes callable namespace | No namespace push |
| Second-chance | Yes — retries after evaluation | No — single pass |
| Recursion guard | 128-step limit + non-shrinking check | Fixpoint bounds only |
| When to use | Default for named callables | Ad-hoc rules, non-callable subjects |

---

## Summary

Head dispatch bridges the gap between declarative rule definitions and invocation
syntax. When you declare a `rule`, you can call it like a function — the runtime
handles the rewrite automatically. Key behaviors to remember:

- Callable status is explicit context state (`rule` adds it, assignment removes it).
- Dispatch targets the invocation root, not subexpressions.
- Prefix-tail tolerance preserves unmatched arguments.
- Two safety layers prevent infinite loops: a hard 128-step limit and a
  non-shrinking heuristic.
- Second-chance dispatch handles variable dereference in argument positions.
- Disable with `--no-head-dispatch` when you need explicit control.

---

## Related Pages

- [Dispatch Flags](../reference/command-line/matcher-inference-options/dispatch-flags.md) — CLI controls
- [Rule Declaration Syntax](../syntax/operators-special-forms/rule-declaration-syntax.md) — `rule` keyword
- [Selection Operator](../transformations/selection-operator.md) — explicit `?` rewrites
- [Statement Execution](./statement-execution.md) — statement ordering
