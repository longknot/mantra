# Rule Declaration Syntax

The `rule` keyword declares a named transformation rule. A rule binds a name
to a pattern-based rewrite that can be invoked through selection, callable
dispatch, or head-dispatch.

```mantra
rule name [
  pattern => replacement
]
```

When executed, the rule registers the name as a keyword and callable in the
runtime context, then stores a clone of the rule body. The rule node deletes
itself from the AST after registration.

## Syntax

```mantra
rule <name> <body>;
```

- `<name>` — identifier (variable or string) that names the rule
- `<body>` — a scope `[ ... ]`, `{ ... }`, expression, or any subtree containing
  one or more transform rules (`=>` or `<=>`)
- The trailing semicolon is optional

The name must be a variable identifier. The parser rejects non-variable names
with `Invalid rule name`. The body must be present — the parser raises
`Missing rule definition for "name"` when the body is absent.

The rule body can use square brackets `[ ... ]`, curly braces `{ ... }`,
parentheses `( ... )`, or backticks `` ` ... ` `` as delimiters. When the body
is a scope node, the runtime clones its left-hand child (the scope contents).
For other body types, it clones the entire subtree.

### Name Case Sensitivity

When the rule name is entirely uppercase, the runtime marks it with the
`TK_ALLCAPS` flag. This affects matching behavior — uppercase names are treated
as pattern wildcards during structural matching, similar to how uppercase
variables in patterns match any node.

## Examples

### Basic Named Rule

```mantra
rule replace x => y ;
print { a ? replace }
```

Output: `y`

The rule `replace` is a simple transform that rewrites any `x` to `y`.
Selection (`?`) applies the rule to the subject `a`.

### Rule with Multiple Transform Rules

```mantra
rule sum [ sum X -- => + all X ];
rule mul [ mul X -- => * all X ];
print ~ { sum ( mul 1 9 ) }
```

Output: `+ 9`

Each rule takes the form `head pattern => replacement`. The `--` wildcard
matches the remaining tail of a sequence, and `all X` refers to the full
subtree bound by `X`. The `~` tilde forces compute on the result.

### Bidirectional (Equivalence) Rule

```mantra
rule swap [
  [ x y ] <=> [ y x ]
]
print { [ 3 4 ] ? swap : 1 }
print { [ 4 3 ] ? swap : 1 }
```

Output:
```
[ 4 3 ]
[ 3 4 ]
```

Equivalence rules (`<=>`) match in either direction. The runtime tries the
forward direction first, then falls back to the reverse if the forward match
fails. Both `[ 3 4 ]` and `[ 4 3 ]` rewrite to the opposite order.

### Recursive Rule

```mantra
rule recurse {
  recurse x -- => [ x , recurse rhs x ]
}
print { recurse 1 2 3 }
```

Output: `[ 1 , [ 2 , [ 3 , recurse ] ] ]`

Rules can reference themselves by name. Here, `recurse` matches the head
element `x` and recurses over the tail (`rhs x`). The recursion eventually
stops when the remaining pattern no longer matches the forward rule, leaving
the unmatched `recurse` symbol as a base-case marker. The fixpoint bound
(`MAX_FIXPOINT_STEPS = 1024`) prevents infinite recursion.

### Rule with Alias

```mantra
rule f [
  f x => x
];
alias g = f;
print { g 7 };
```

Output: `7`

Rules can be aliased with the `alias` keyword. The alias `g` dispatches to
the same callable binding as `f`, providing a secondary name for the same
rewrite behavior.

## How Rules Work

At runtime, `TRuleNode.Execute` performs these steps:

1. **Validate name** — confirms the name is a variable identifier (raises
   `Invalid rule name` otherwise).
2. **Locate body** — the body is the sibling to the right of the rule node.
   If absent, the parser already raised `Missing rule definition`.
3. **Clone body** — if the body is a scope node (`[ ]`, `{ }`, `` ` ` ``, etc.),
   only the scope contents (LHS child) are cloned; otherwise the full subtree
   is cloned.
4. **Register** — the name is added as a keyword, a variable (pointing to the
   cloned body), a callable, and a callable binding. The binding links the name
   to its rule body within the current namespace.
5. **Delete self** — the `rule` node removes itself from the AST.

The `Evaluate` method adds tail-processing: when the body is a scope with
sibling content after it, those siblings are evaluated after registration.

## How Rules Are Invoked

Rules can be invoked in three ways:

### Selection (`?`)

The selection operator applies a rule to a subject by structural matching:

```mantra
[ 3 4 ] ? swap : 1
```

The runtime iterates through the rules in `swap`, tries to match the subject
against each pattern, and applies the first match. The `: 1` bounds the search
to a single step.

### Callable Dispatch

Rules are registered as callables. When a variable appears as the head of an
expression inside an evaluation scope, the runtime dispatches it:

```mantra
rule f [ f x => x ];
print { f 7 };
```

The expression `f 7` is matched against the rule body `f x => x`. The variable
`x` binds to `7`, and the replacement `x` evaluates to `7`.

### Head Dispatch

The runtime can automatically dispatch rule calls without explicit selection
when head dispatch is enabled. The rule name as the head of an expression
triggers pattern matching against the rule's body.

## Error Messages

| Error | Cause |
|---|---|
| `Invalid rule name: ...` | The name position is not a variable identifier |
| `Missing rule definition for "name"` | No body follows the rule name |
| `Missing rule name after "rule"` | No identifier follows the `rule` keyword |

## Related

- [Keywords and Declarations](../keywords-declarations.md) — overview of `rule`, `define`, `callable`, `alias`
- [Rules in Practice](../../transformations/rules-in-practice.md) — reusable rules, queries, proofs
- [Selection](../../transformations/selection.md) — the `?` operator that applies rules
- [Transform Rules](../../transformations/transform-rules.md) — `=>` and `<=>` operators
