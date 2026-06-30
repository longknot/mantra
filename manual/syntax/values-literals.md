# Values and Literals

Mantra recognizes several literal value types that the parser converts directly
into tree nodes. Each literal type maps to a specific node class in `nodes.pas`:

| Literal | Node Type | Example |
|---|---|---|
| Integer | `TIntegerNode` | `42`, `-7`, `0` |
| Float | `TFloatNode` | `3.14`, `-2.5` |
| String | `TStringNode` | `"hello"` |
| Boolean | — | `true`, `false` |
| Complex | `TComplexNode` | `1+2i` |
| Variable | `TVariableNode` | `x`, `myVar` |

## Integer Literals

Whole numbers (positive, negative, or zero) are parsed as integer nodes:

```mantra
42
-7
0
```

Integers participate in arithmetic when inside a compute scope:

```mantra
` + 1 2 3 `    → + 6
` * 10 5 `     → * 50
` - 100 7 `    → - 93
```

Without compute scope, integers remain as symbolic values:

```mantra
+ 1 2 3        → + 1 + 2 + 3    (formatted, not computed)
```

### Integer in Compute

Compute scope supports standard arithmetic operators on integers:

| Operator | Meaning |
|---|---|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `mod` | Modulo |

See [Compute](../compute/index.md) for the full list of supported operations.

## Float Literals

Numbers containing a decimal point are parsed as floating-point nodes:

```mantra
3.14
-2.5
0.0
1e10
```

Floats and integers can mix in arithmetic expressions:

```mantra
` + 3.14 2 `    → + 5.14
` * 2.5 4 `     → * 10
```

Float literals support the same operators as integers. See [Compute](../compute/index.md)
for trigonometric functions (`sin`, `cos`, `tan`), `floor`, `ceil`, `round`, and
other math operations that operate on floating-point values.

## String Literals

String literals are enclosed in double quotes:

```mantra
"hello"
"hello world"
""
```

Strings can be empty. The tokenizer handles escape sequences within quoted strings.

### String and Lists

Strings inside lists are preserved as literal values:

```mantra
[ "a" "b" "c" ]
```

OUTPUT:
```
[ "a" "b" "c" ]
```

### String Concatenation

Use the `&` operator for string concatenation:

```mantra
` & "hello" " " "world" `
```

### Explode and Implode

The `explode` keyword converts a string to a sequence of characters:

```mantra
explode "abc"    → [ "a" "b" "c" ]
```

The `implode` keyword does the reverse:

```mantra
implode [ "a" "b" "c" ]    → "abc"
```

See [Keywords and Declarations](keywords-declarations.md) for `explode` and `implode`.

## Boolean Literals

Mantra recognizes `true` and `false` as boolean values:

```mantra
true
false
```

Booleans participate in comparison and logical operations within compute scope:

```mantra
` > 5 3 `     → true
` = 1 2 `     → false
```

See [Compute](../compute/index.md) for supported comparison and boolean operators.

## Complex Numbers

Mantra supports complex number literals using the `i` suffix:

```mantra
1+2i
3-4i
```

Complex numbers are parsed as `TComplexNode` values and support arithmetic
operations that respect complex number algebra.

## Variable References

A bare identifier (not preceded by an operator and not matching a keyword) is
treated as a variable lookup. If the variable is bound in the current context,
its stored tree is cloned and substituted at the use site:

```mantra
x = [ 1 2 3 ]
x               → [ 1 2 3 ]
```

Variable names are case-insensitive — `x`, `X`, `MyVar`, and `MYVAR` all refer
to the same identifier.

### Variable Extraction

You can extract parts of a variable's stored tree:

```mantra
lhs x            → left child subtree of x
rhs x            → right sibling subtree of x
all x            → x plus all siblings
```

See [Evaluation](../evaluation/index.md) for variable context management.

### Predefined Variables

Variables can be set on the command line before execution:

```bash
mantra --set x=5 --set rules='[ x => x + 1 ]' program.m
```

See [Getting Started](../getting-started/index.md) for CLI usage.

### Assignment

Variables are assigned using `=` (shallow) or `:=` (deep):

```mantra
x = [ 1 2 3 ]      — shallow assignment (stores reference)
y := [ 1 2 3 ]     — deep assignment (stores clone)
```

See [Assignment Syntax](operators-special-forms/assignment-syntax.md).

## Related Pages

- [Assignment Syntax](operators-special-forms/assignment-syntax.md) — `=` and `:=`
- [Keywords and Declarations](keywords-declarations.md) — `explode`, `implode`
- [Compute](../compute/index.md) — arithmetic and comparison operators
- [Tokens and Whitespace](tokens-whitespace.md) — tokenizer and identifier handling
- [Syntax Index](index.md) — full syntax overview
