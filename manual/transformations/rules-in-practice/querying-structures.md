# Querying Structures with Rules

Rules can turn a structured pattern into a small query language. By defining
a rule that matches a query syntax and rewrites it to a selection expression,
you get readable, composable queries over nested tree data.

```mantra
define select from where ;
people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] ] ;
rule select [ select field from table where key val => ( table ? [ [ key val field out -- ] =>> out ] ) ] ;
print { select "name" from people where "id" 2 }
```

Expected `OUTPUT`:

```text
( "Jane Smith" )
```

## Why This Is Useful

The rule hides the lower-level selection expression behind a readable query
form. Instead of writing:

```mantra
people ? [ [ "id" 2 "name" out -- ] =>> out ]
```

Users write:

```mantra
select "name" from people where "id" 2
```

This pattern scales: you can build query vocabularies (JOIN, GROUP, FILTER)
as additional rules, layering higher-level abstractions over the structural
matcher.

## How It Works

The query pattern is a two-step process:

1. **Define keywords** — `define select from where ;` registers the words
   `select`, `from`, and `where` as match-time keywords. Without this, the
   parser treats them as ordinary identifiers and they won't match the rule
   pattern literally.
2. **Rule expansion** — When the parser encounters `select "name" from people
   where "id" 2`, the named rule `select` matches the structure and rewrites
   it to the underlying selection expression.

### Lifecycle

```
select "name" from people where "id" 2
    │
    ▼  (rule select matches and expands)
people ? [ [ "id" 2 "name" out -- ] =>> out ]
    │
    ▼  (selection rewrites the subject)
"Jane Smith"
```

The named rule performs the first rewrite. The selection operator performs the
second. The result is the value captured by the `out` variable in the inner
rule.

## Reading the Rule

```mantra
define select from where ;
rule select [ select field from table where key val => ( table ? [ [ key val field out -- ] =>> out ] ) ] ;
```

Break it down:

- **`define select from where ;`** — Registers query words. The matcher
  recognizes these as literal tokens during pattern matching. Uppercase symbols
  in patterns (`TABLE`, `KEY`, `VAL`) are bound to any value; the defined
  lowercase keywords match themselves literally.
- **`rule select [ ... ]`** — Declares a named rule. When the parser sees an
  expression starting with `select`, it dispatches to this rule.
- **Pattern: `select field from table where key val`** — Matches the query
  shape. Lowercase variables (`field`, `table`, `key`, `val`) capture
  subexpressions from the query.
- **Replacement: `( table ? [ [ key val field out -- ] =>> out ] )`** —
  Constructs a selection expression using the captured values. The inner rule
  searches `table` for a record containing `key val`, captures `field`'s value
  as `out`, and returns it.
- **`=>>`** — The inline transform shorthand. Equivalent to `=>` but without
  wrapping parentheses, useful inside selection rules.
- **`--`** — Match-any pattern. Captures the remaining siblings after `out`,
  ensuring the rule matches records regardless of how many fields follow.

## The Selection Pattern Explained

The core search is `[ key val field out -- ] =>> out`. Inside the selection
operator, this pattern walks the table looking for a child record that
contains, in order:

1. A matching key-value pair (`key val`)
2. The target field key (`field`)
3. Its value (captured as `out`)
4. Any remaining fields (`--`)

The match-any (`--`) is essential — without it, the pattern would only match
records where the target field is the last one.

## Worked Examples

### Example: Query with three records

```mantra
define select from where ;
. people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] [ "id" 3 "name" "Alice Johnson" ] ] ;
. select_rule = [ [ select field from TABLE where key val ] => ( TABLE ? [ [ key val field out -- ] =>> out ] ) ] ;
print { [ select "name" from people where "id" 2 ] ? select_rule : 2 }
```

Expected `OUTPUT`:

```text
( "Jane Smith" )
```

Here the rule is stored in a variable (`select_rule`) rather than declared
with `rule select`. The query expression `[ select "name" ... ]` is explicitly
passed through the selection operator with `: 2` (two repeat steps) to allow
the rule to expand and the selection to complete.

### Example: Simple keyword matching (field extraction)

```mantra
define select from where ;
. q = [ [ select x from y where z w ] => [ x ] ] ;
print { [ select "name" from persons where "id" 2 ] ? q : 1 }
```

Expected `OUTPUT`:

```text
[ "name" ]
```

This rule only extracts the field name — it doesn't actually search the table.
The pattern captures `x` as `"name"` and returns `[ x ]`.

### Example: Keyword mismatch (no match)

```mantra
define select from where ;
. q = [ [ select x from y where z w ] => [ x ] ] ;
print { [ choose "name" from persons where "id" 2 ] ? q : 1 }
```

Expected `OUTPUT`:

```text
[ choose "name" from persons where "id" 2 ]
```

The expression uses `choose` instead of `select`. Since only `select` was
defined as a keyword, the pattern doesn't match and the original expression
is returned unchanged.

### Example: Named rule with head dispatch

```mantra
define select from where ;
people = [ [ "id" 1 "name" "John Doe" ] [ "id" 2 "name" "Jane Smith" ] ] ;
rule select [ select field from table where key val => ( table ? [ [ key val field out -- ] =>> out ] ) ] ;
print { select "name" from people where "id" 2 }
```

Expected `OUTPUT`:

```text
( "Jane Smith" )
```

When declared with `rule select`, the runtime uses head dispatch: expressions
starting with `select` automatically route to the rule. No explicit `?` is
needed.

## Named Rule vs Variable Rule

There are two ways to attach the query logic:

| Approach | Declaration | Usage | Dispatch |
|---|---|---|---|
| Named rule | `rule select [ pattern => replacement ]` | `select "name" from people where "id" 2` | Automatic (head dispatch) |
| Variable rule | `. select_rule = [ pattern => replacement ]` | `[ select "name" ... ] ? select_rule : 2` | Explicit selection with repeat |

The named rule is cleaner — it rewrites on first encounter. The variable
approach gives more control: you can chain multiple rules, change the repeat
count, or combine rulesets.

## Nested Queries

You can nest queries to filter further:

```mantra
define select from where ;
people = [ [ "id" 1 "name" "John Doe" "city" "NYC" ] [ "id" 2 "name" "Jane Smith" "city" "LA" ] ] ;
rule select [ select field from table where key val => ( table ? [ [ key val field out -- ] =>> out ] ) ] ;
print { select "city" from people where "id" 1 }
```

Expected `OUTPUT`:

```text
( "NYC" )
```

The same rule works for any field — `"name"`, `"city"`, or any other key-value
pair in the record. The pattern is generic.

## Pitfalls

**Forgetting `define`** — Without `define select from where ;`, the matcher
treats `select`, `from`, `where` as ordinary identifiers. They won't match
literally in the pattern, so the rule never fires.

**Wrong field order** — The inner pattern `[ key val field out -- ]` expects
the target field to follow the key-value pair. If your records store fields in
a different order, adjust the pattern accordingly.

**Missing `--` match-any** — Without `--` at the end, the pattern only matches
records where the target field is the last entry. Adding `--` absorbs
remaining siblings.

**No match returns original** — If the selection finds no matching record, the
table is returned unchanged. There is no implicit "null" or "not found"
indicator — you need to check the result shape yourself.

## See Also

- [Selection Operator](../selection/selection-operator.md) — Details on `?`
  rewrite semantics
- [Ordered Rule Sets](ordered-rule-sets.md) — How rule ordering affects matches
- [Guarded Rules](guarded-rules.md) — Adding conditions to rules

