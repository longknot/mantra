# Reusable Rule Dispatch

Rules let you name a structural rewrite and invoke it later by calling the name
as if it were a function. The `rule` keyword declares a callable, and `alias`
gives the same callable additional names. Together they support clean
separation between public API spelling and internal implementation.

```mantra
rule f [
  f x => x
];

alias g = f;

print { g 7 };
```

Expected `OUTPUT`:

```text
7
```

The rule `f` strips one argument and returns it. The alias `g` routes
transparently to the same ruleset -- `g 7` dispatches to `f`, which matches
and produces `7`.

## Syntax

### Rule Declaration

```mantra
rule name [
  pattern1 => replacement1 ,
  pattern2 => replacement2
];
```

The `rule` keyword registers a named ruleset with four side effects:

1. **Keyword** -- `name` is added to the context's keyword table so the parser
   recognizes it during pattern matching.
2. **Variable** -- `name` is bound to a clone of the ruleset.
3. **Callable** -- `name` is marked as callable, enabling head dispatch: any
   expression `name <args>` tries to match `<args>` against the ruleset.
4. **Callable binding** -- The dispatch head (`name`) is linked to the ruleset
   index, so the runtime knows which pattern to apply.

### Alias

```mantra
alias g = f;
```

The `alias` keyword creates an additional name for an existing callable. When
`g` is invoked, the runtime resolves the binding, discovers the dispatch head
is `f`, clones the invocation, replaces the head token with `f`, and applies
the ruleset. The alias is completely transparent to the matcher.

### Callable Declaration

```mantra
callable func;
```

The `callable` keyword pre-registers a name as callable without yet binding a
ruleset. This lets you forward-declare a dispatch point before the rules are
defined, or leave a binding that another part of the program fills in later.

## How It Works

When Mantra encounters a variable at the head of an expression (`f` in
`f 7`), it checks for a callable binding before performing standard variable
substitution. This mechanism is called *head dispatch*.

The `TryHeadDispatch` function in `TVariableNode.Evaluate` performs these
checks in sequence:

1. Is head dispatch enabled (`HeadInvocationDispatchEnabled`)?
2. Has the recursive depth exceeded `MAX_HEAD_DISPATCH_STEPS` (128)?
3. Does the head name have a ruleset (non-EOT `RulesIndex`)?
4. Is the head name registered as callable (`Context.IsCallable`)?
5. Does a callable binding exist (`Context.TryResolveCallableBinding`)?
6. If the invocation name differs from the dispatch head (alias case), clone
   the invocation tree and replace the head token with the dispatch head.
7. Call `RewriteOneByRules` to apply the first matching rule.
8. If a rewrite was applied, evaluate the result and replace the original node.

For a full reference on the dispatch pipeline — second-chance dispatch, prefix-tail
tolerance, recursion guards — see [Head Dispatch](../../evaluation/execution-order/head-dispatch.md).

---

## Callable Declaration in Detail

### Internal Symbols

When the callable name starts with `__` (double underscore), the runtime also
adds it to the **non-bindable** table. Non-bindable names cannot be captured by
lowercase pattern variables during structural matching — they behave like
keywords that survive matching rather than being absorbed.

```mantra
callable __h;
print { __h ? [ x ==> ( - x ) ] : 1 };
print { __h ? [ __h => "ok" ] : 1 };
```

Expected `OUTPUT`:

```text
__h
"ok"
```

The first selection fails to bind `x` because `__h` is non-bindable. The second
selection matches `__h` literally against itself and produces `"ok"`.

### Callable Without Ruleset

`callable` marks the name but does not create a binding. Invoking an unbound
callable name with arguments falls through to ordinary variable evaluation:

```mantra
callable f;
```

A `callable` declaration without a corresponding `rule` does not yet have a
ruleset index. If you later define `rule f [ ... ]`, the callable status is
already present and head dispatch activates automatically.

---

## Alias Dispatch

When you create an alias, the runtime copies the callable binding from the
target to the alias but preserves the original dispatch head. This means the
matcher sees the original rule name, not the alias:

```mantra
rule f [
  f x => x
];

alias g = f;

print { g 7 };
```

Expected `OUTPUT`:

```text
7
```

Invocation `g 7` is cloned, the head token `g` is replaced with `f`, and the
rule `f x => x` fires against `f 7`. The alias is invisible to the matcher.

### Alias Validation

The alias target must be a callable binding. The runtime rejects:

- Non-callable targets: `Alias target is not a callable binding: <name>`
- Non-variable alias names: `Invalid alias definition: <expression>`
- Non-variable targets: `Alias target must be a callable name: <expression>`

---

## Fallback Operator (`??`)

The `??` operator provides a default value when head dispatch or selection
fails to produce a rewrite:

```mantra
print { unknown 1 ?? 2 }
callable f;
rule f [ f x => x ];
print { f 7 ?? 0 }
print { 1 ? [ 1 => 2 ] ?? 9 }
print { 5 ? [ 1 => 2 ] ?? 9 }
```

Expected `OUTPUT`:

```text
2
7
2
9
```

Behavior by case:

| Expression | Result | Reason |
|---|---|---|
| `unknown 1 ?? 2` | `2` | `unknown` is not callable; fallback to `2` |
| `f 7 ?? 0` | `7` | `f 7` dispatches successfully; fallback unused |
| `1 ? [ 1 => 2 ] ?? 9` | `2` | Selection matches; fallback unused |
| `5 ? [ 1 => 2 ] ?? 9` | `9` | Selection fails; fallback to `9` |

---

## Rules Defined Inline

Rules can be declared and invoked in the same evaluation scope. The rule
declaration executes before the body evaluates, so the callable is registered
when the invocation fires:

```mantra
print { rule foo [ foo x y => ( x y ) ] [ foo 1 2 ] }
```

Expected `OUTPUT`:

```text
[ ( 1 2 ) ]
```

---

## Removing Callable Status

A deep assignment to a callable name removes its callable mark and binding.
Subsequent invocations no longer dispatch:

```mantra
rule bar [ bar x => x * 2 ];
print { bar 5 }     → 10

. bar = [ 1 2 3 ];  # assignment removes callable mark
print { bar 5 }     → bar 5  (no dispatch)
```

See [Head Dispatch](../../evaluation/execution-order/head-dispatch.md#callable-registration)
for the full state table.

---

## Callable and Alias in Selection Contexts

Named rules and aliases work with the selection operator just like anonymous
rules. You can pass them by name without quoting:

```mantra
rule double [ [ x -- ] => [ x * 2 -- ] ];
print { [ 1 2 3 ] ? double : 1 }
```

Expected `OUTPUT`:

```text
[ 2 2 3 ]
```

---

## Summary

| Keyword | Registers | Enables |
|---|---|---|
| `rule name [ ... ]` | keyword + variable + callable + binding | head dispatch, selection by name |
| `alias g = f` | keyword + variable + callable + binding (copy) | additional dispatch entry point |
| `callable name` | keyword + callable flag only | callable status without ruleset |

**Key behaviors:**

- `rule` does the full registration — keyword, variable, callable, binding.
- `alias` copies the binding from one callable to another but keeps the
  original dispatch head for pattern matching.
- `callable` marks a name without a ruleset — useful for forward declarations.
- `__`-prefixed callables are also non-bindable (survive pattern matching).
- A deep assignment removes callable status and its binding.
- `??` provides a fallback when dispatch or selection fails.
- Rules can be declared and invoked in the same evaluation scope.

---

## Related Pages

- [Head Dispatch](../../evaluation/execution-order/head-dispatch.md) — dispatch
  pipeline, second-chance dispatch, prefix-tail tolerance, recursion guards,
  namespace-aware dispatch
- [Rule Declaration Syntax](../../syntax/operators-special-forms/rule-declaration-syntax.md) —
  `rule` keyword syntax and body parsing
- [Selection](../selection.md) — the `?` operator and structural rewriting
- [Rules in Practice](../rules-in-practice.md) — parent overview of rule patterns
