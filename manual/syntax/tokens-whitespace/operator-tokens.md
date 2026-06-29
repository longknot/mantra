# Operator Tokens

Operator tokens request transformations, computation, assignment, queries, and
structural operations. Every operator produces an AST node that the runtime
dispatches through virtual methods in `nodes.pas`.

Many operators are meaningful only in a particular tree position. Document them
with complete input examples, not as isolated characters.

This page lists every operator token recognized by the parser (configured in
`mathparser.pas` via `AddTransition` calls), grouped by function. For detailed
semantics, follow the linked pages.

---

## Operator Reference

### Repeat and Expansion

| Operator | Token | Node | Description |
|---|---|---|---|
| `:` | `TK_COLON` | `TRepeatNode` | Repeat / tile operator |
| `::` | `TK_ITERATOR` | -- | Staged repeat (iterator) |
| `...` | `TK_TRIPLEDOT` | `TRecurseNode` | Recurse / fixpoint |

The `:` operator repeats or tiles a left-hand tree using a right-hand driver.
An integer on the right clones the left that many times; `...` enables
fixpoint recursion (bounded by `MAX_FIXPOINT_STEPS = 1024`).

```mantra
[ + 1 2 3 ] : 3
```

Output: `[ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ] [ + 1 + 2 + 3 ]`

See also: [Transformations](../transformations/index.md),
[Repeat Operator](../transformations/repeat-operator.md)

---

### Selection and Rewrite

| Operator | Token | Node | Description |
|---|---|---|---|
| `?` | `TK_SELECTION` | `TSelectionNode` | Selection rewrite |
| `$?` | `TK_QUESTIONMARK` + `TK_DOLLAR` | `TSelectionNode` | State-selection (iterative) |
| `??` | `TK_FALLBACK` | -- | Fallback selector |

`?` applies the first matching rule from a rule list to a subject tree.
Lowercase symbols match specific identifiers; uppercase symbols match any node.
`--` matches any tail sequence within a rule.

```mantra
[ 1 2 3 ] ? [ x => x + 1 ]
```

`$?` enables iterative state-selection mode where rules apply repeatedly until
no more matches occur (fixpoint).

`??` is a fallback selector that activates when a preceding `?` finds no match.

See also: [Selection](../transformations/selection.md)

---

### Transform Rules

| Operator | Token | Node | Description |
|---|---|---|---|
| `=>` | `TK_TRANSFORM` | `TTransformNode` | Transform rule |
| `=>>` | `TK_INLINE_TRANSFORM` | -- | Inline transform |
| `==>` | `TK_SYMBOL_SUBST_TRANSFORM` | -- | Symbol-substitution transform |
| `==>>` | `TK_SUBST_TRANSFORM` | -- | Substitution transform (binding-aware) |
| `<=>` | `TK_EQUIVALENCE` | -- | Bidirectional equivalence |
| `<==>` | `TK_SUBST_EQUIVALENCE` | -- | Substitution equivalence (bidirectional) |

`=>` declares a structural rewrite pattern of the form `pattern => replacement`.
Rules are evaluated in order by the `?` selection operator.

`==>>` uses binding-aware template expansion — it goes through normal matcher
bindings and supports template operator carriers. Prefer `==>>` for algebraic
proof rules where operator structure matters.

`==>` skips matcher bindings and treats the substitution as literal symbol map
application. Use `==>` when you intentionally want a more literal symbol-level
rewrite and can tolerate structural drift.

`<=>` is a bidirectional rule that can match in either direction. The first
direction is tried first; if it does not match, the reverse direction is
attempted.

```mantra
[ x y ] <=> [ y x ]
```

Both `[ 1 2 ]` and `[ 2 1 ]` match this equivalence.

Transparent grouping `<< ... >>` can be used inside transform operands to
provide parse-level grouping without creating a surviving AST wrapper. A transform
can be marked fixed with `\` to prevent matcher variable bindings.

See also: [Transform Rules](../transformations/transform-rules.md),
[Transforms](../../docs/TRANSFORMS.md)

---

### Assignment

| Operator | Token | Node | Description |
|---|---|---|---|
| `=` | `TK_ASSIGNMENT` | `TAssignmentNode` | Variable assignment |
| `:=` | `TK_DEEP_ASSIGN` | `TDeepAssignNode` | Deep assignment (trie copy) |
| `>:=` | `TK_DEEP_ASSIGN_OVERWRITE` | `TDeepAssignNode` | Deep assignment (overwrite mode) |
| `<:=` | `TK_DEEP_ASSIGN_KEEP` | `TDeepAssignNode` | Deep assignment (keep mode) |
| `!:=` | `TK_DEEP_ASSIGN_FAIL` | `TDeepAssignNode` | Deep assignment (fail on conflict) |

`= ` stores a tree snapshot under a variable name. The left side is a binding
target; the right side is evaluated and cloned into the context.

```mantra
x = [ + 1 2 3 ]
```

`:=` performs a deep copy of a trie subtree, merging with overwrite behavior by
default. The variants `>:=`, `<:=`, and `!:=` control conflict resolution:
overwrite existing keys, keep existing keys, or fail if any key conflicts.

```mantra
dict.obj2 := dict.obj1;       // merge with overwrite
dict.obj2 >:= dict.obj1;      // overwrite mode (explicit)
dict.obj2 <:= dict.obj1;      // keep existing keys
dict.obj2 !:= dict.obj1;      // error on conflict
```

See also: [Assignment Syntax](../operators-special-forms/assignment-syntax.md)

---

### Inference and Proof Search

| Operator | Token | Node | Description |
|---|---|---|---|
| `\|=` | `TK_INFERENCE` | `TInferenceNode` | Inference / proof query |
| `?\|=` | `TK_INFERENCE_WITNESS` | `TInferenceNode` | Witness-producing inference |

`\|=` checks whether a set of rules can prove that a subject can be rewritten to
reach a target. The runtime returns `1` (success) or `0` (failure).

```mantra
subject => target |= rules
subject <=> target |= rules : n    (bounded multi-step)
```

`?\|=` is a witness-producing variant that can materialize the actual proof path
or intermediate tree state, not just the boolean result.

See also: [Inference](../transformations/inference.md)

---

### Compute

| Operator | Token | Node | Description |
|---|---|---|---|
| `~` | `TK_TILDE` | (meta flag) | Meta-compute (targeted compute) |

The `~` (tilde) operator forces arithmetic reduction on a targeted node or
subtree even outside a backtick compute scope. It sets the `TK_TILDE` meta flag
on the next node in the tree.

```mantra
[ { ~ + 1 2 3 } ]
```

See also: [Meta-Compute Operator](../compute/meta-compute-operator.md),
[Compute Scopes](../compute-scopes.md)

---

### Structural Operators

| Operator | Token | Node | Description |
|---|---|---|---|
| `&` | `TK_AMPERSAND` | `TConcatenateNode` | Concatenation (arrays, strings, expressions) |

`&` concatenates arrays, expressions, or strings. It joins two tree structures
by making the children of the right operand siblings of the left.

```mantra
[ 1 2 ] & [ 3 4 ]
```

Output: `[ 1 2 3 4 ]`

See also: [Structural Operators](../compute/operator-reference/structural-operators.md)

---

### Arithmetic Operators

| Operator | Token | Description |
|---|---|---|
| `+` | `TK_PLUS` | Addition |
| `-` | `TK_MINUS` | Subtraction / negation |
| `*` | `TK_ASTERISK` | Multiplication |
| `/` | `TK_SLASH` | Division |

Arithmetic operators appear as expression prefixes or operands. They reduce to
a numeric result only inside compute scope `` ` ... ` `` or when targeted with
the `~` meta-compute flag. Outside compute scope, they are formatted symbolically.

```mantra
` + 1 2 3 `      // → + 6 (reduced)
[ + 1 2 3 ]      // → + 1 + 2 + 3 (symbolic)
```

See also: [Arithmetic Operators](../compute/operator-reference/arithmetic-operators.md),
[Compute](../compute/index.md)

---

### Comparison Operators

| Operator | Token | Description |
|---|---|---|
| `<` | `TK_RELATIONAL_LT` | Less than |
| `>` | `TK_RELATIONAL_GT` | Greater than |
| `<=` | `TK_RELATIONAL_LE` | Less than or equal |
| `>=` | `TK_RELATIONAL_GE` | Greater than or equal |
| `==` | `TK_RELATIONAL_EQ` | Equality |
| `!=` | `TK_RELATIONAL_NEQ` | Not equal |

Comparison operators reduce to `1` (true) or `0` (false) in compute scope.

```mantra
` < 1 3 `    // → 1
` > 1 3 `    // → 0
```

See also: [Boolean and Comparison Operators](../compute/operator-reference/boolean-comparison-operators.md)

---

### Pattern Matching

| Operator | Token | Description |
|---|---|---|
| `--` | `TK_MATCH_ANY` | Match any (tail sequence) |
| `---` | `TK_MATCH_ANY_LONG` | Long match any |
| `\|` | `TK_PIPE` | Pattern separator |

`--` is used inside selection rules to match any remaining tail sequence. It
captures zero or more nodes into a variable.

```mantra
[ 1 x -- ] ? [ 1 y -- => y ]
```

`---` is a longer variant of the same pattern matching construct.

`\|` serves as a pattern separator within rule definitions.

---

### Range and Other

| Operator | Token | Description |
|---|---|---|
| `..` | `TK_DOUBLEDOT` | Range operator |
| `#` | `TK_HASH` | Hash / comment marker |

`..` creates a range from one value to another, typically producing a sequence
of integers.

```mantra
1 .. 5
```

`#` marks a hash symbol, used in various contexts.

---

## Related Pages

- [Operators and Special Forms](../operators-special-forms.md) -- comprehensive syntax overview
- [Meta Flags](../meta-flags.md) -- `~`, `\`, `$`, `^`, `.`, `@` prefixes
- [Delimiters and Scope Tokens](delimiters-scope-tokens.md) -- `[ ]`, `( )`, `{ }`, `` ` ``, `' '`
- [Tokens and Whitespace](../tokens-whitespace.md) -- parent overview
- [Compute and Operators](../compute/index.md) -- compute scope and supported reductions
- [Transformations](../transformations/index.md) -- repeat, selection, inference
- [Assignment Syntax](../operators-special-forms/assignment-syntax.md) -- `=`, `:=` variants
