# Concatenation

The `&` operator concatenates multiple operands of the same type into a single
value. It supports **arrays** (`[ ]`), **expressions** (`( )`), and **strings**
(`" "`). The operator preserves the type of its operands — the result always has
the same shape as the inputs.

The `&` operator supports both **prefix** and **infix** forms and can chain
arbitrary operands.

## Syntax

**Prefix form** — `&` appears before all operands:

```mantra
& operand1 operand2 operand3 ...
```

**Infix form** — `&` appears between two operands:

```mantra
operand1 & operand2
```

The prefix form is more flexible — it can concatenate three or more operands in
a single expression. The infix form is convenient for chaining two operands.

## Array Concatenation

Arrays are concatenated by cloning their elements and linking them into a new
flat array. The original arrays are not modified.

### Prefix form with multiple operands:

```mantra
print { & [ 1 2 ] [ 3 4 ] [ 5 6 ] };
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 5 6 ]
```

### Infix form:

```mantra
print { [ 1 2 ] & [ 3 4 ] };
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 ]
```

### Empty arrays

Empty arrays act as identity elements — concatenating with an empty array
returns the other operand unchanged:

```mantra
print { & [ 1 2 ] [] [ 3 4 ] };
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 ]
```

Two empty arrays produce an empty array:

```mantra
print { & [] [] };
```

Expected `OUTPUT`:

```text
[ ]
```

### Structural cloning

Concatenation **clones** the elements from source arrays — it does not create
references. Modifying the result does not affect the originals:

```mantra
print { & [ [ 1 2 ] ] [ [ 3 4 ] ] };
```

Expected `OUTPUT`:

```text
[ [ 1 2 ] [ 3 4 ] ]
```

## Expression Concatenation

Parenthesized expressions are concatenated by merging their child nodes while
preserving the expression type:

```mantra
print { & ( 1 2 3 ) ( 4 5 6 ) };
```

Expected `OUTPUT`:

```text
( 1 2 3 4 5 6 )
```

Symbolic expressions concatenate the same way:

```mantra
print { & ( a b ) ( c d ) };
```

Expected `OUTPUT`:

```text
( a b c d )
```

Empty expressions are identity elements:

```mantra
print { & ( ) ( 1 2 ) };
```

Expected `OUTPUT`:

```text
( 1 2 )
```

## String Concatenation

String literals are concatenated by joining their text content. The quotes are
stripped from each operand, the text is joined, and the result is re-quoted:

```mantra
print { & "hello" " " "world" };
```

Expected `OUTPUT`:

```text
"hello world"
```

Two strings:

```mantra
print { & "a" "b" };
```

Expected `OUTPUT`:

```text
"ab"
```

## Type Uniformity

All operands must share the same type. Mixing arrays, expressions, and strings
in a single `&` expression does **not** produce a combined result — instead,
the operator processes the operands sequentially and stops when it encounters a
type mismatch:

```mantra
print { & [ 1 2 ] "a" };
```

Expected `OUTPUT` (type mismatch — no valid concatenation):

```text
[ 1 2 ] "a" &
```

The output above shows the partial state when the operator cannot complete the
concatenation. To combine different types, concatenate within each type first:

```mantra
print { & [ 1 2 ] [ 3 4 ] };  # [ 1 2 3 4 ]
print { & "a" "b" };          # "ab"
```

## Single Operand

When only one operand is provided, it is returned unchanged:

```mantra
print { & [ 1 2 ] };
```

Expected `OUTPUT`:

```text
[ 1 2 ]
```

## No Operands

When `&` receives no operands, it evaluates to itself:

```mantra
print { & };
```

Expected `OUTPUT`:

```text
&
```

## Relationship with Other Operators

### With Ranges

Concatenation works naturally with range expressions. Ranges expand to individual
values (not arrays), so wrap them in arrays first:

```mantra
print { & [ 1 .. 3 ] [ 4 .. 6 ] };
```

Expected `OUTPUT`:

```text
[ 1 2 3 4 5 6 ]
```

### With Explode/Implode

The `explode` and `implode` keywords are complementary to `&` for string
operations. While `&` joins string literals, `implode` joins character values
back into a string:

```mantra
print { implode "a" "b" "c" };  # "abc"
print { & "a" "b" "c" };        # "abc"
```

Both produce the same result for character values, but `implode` is the
dedicated keyword for the character-to-string conversion.

## Summary

| Form | Syntax | Result |
|---|---|---|
| Array (prefix) | `& [ 1 2 ] [ 3 4 ]` | `[ 1 2 3 4 ]` |
| Array (infix) | `[ 1 2 ] & [ 3 4 ]` | `[ 1 2 3 4 ]` |
| Expression | `& ( a b ) ( c d )` | `( a b c d )` |
| String | `& "a" "b" "c"` | `"abc"` |
| Empty identity | `& [] [ 1 ]` | `[ 1 ]` |
| Mixed types | `& [ 1 ] "a"` | No valid result |
