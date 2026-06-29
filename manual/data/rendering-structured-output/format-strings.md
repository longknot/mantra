# Format Strings

`fmt` takes a format string with placeholder specifiers and replaces them with
values from arguments, producing a single formatted string.

## Syntax

```
fmt <format_string> <arg1> <arg2> ...
fmt <format_string> [ <arg1> <arg2> ... ]
```

`fmt` is an identifier node — it works like a function call. The first argument
is always the **format string** (a string literal). The remaining arguments
supply the values that fill the `%` placeholders.

Two calling styles are supported:

- **Positional (multiple arguments)** — each value is a separate argument:
  ```mantra
  fmt "name: %s count: %d" "Alice" 42
  ```

- **Array (two arguments)** — the format string and an array of values:
  ```mantra
  fmt "name: %s count: %d" [ "Alice" 42 ]
  ```

When exactly two arguments are given and the second is an array, `fmt` unpacks
the array elements as individual values. For the `%t` / `%T` verb (tree
representation), the array is **not** unpacked — it is treated as a single
tree argument.

## Placeholders

| Verb | Type | Description |
|---|---|---|
| `%s` / `%S` | String | Converts the argument to its string representation. |
| `%d` / `%D` | Integer | Converts the argument to an integer. Raises an error if the value cannot be parsed as an integer. |
| `%f` / `%F` | Float | Converts the argument to a floating-point number. Raises an error if the value cannot be parsed as a number. |
| `%t` / `%T` | Tree | Renders the argument as its raw tree structure (AST representation). Does **not** evaluate the argument unless it is wrapped in an evaluation or compute scope. |
| `%q` / `%Q` | Quoted | Converts the argument to a string and wraps it in double quotes with internal quotes escaped. |
| `%%` | Literal percent | Produces a literal `%` in the output. Takes no argument. |

Case-insensitive: both `%s` and `%S` are equivalent for all verbs.

## Examples

### Basic formatting with positional arguments

```mantra
print { fmt "%s has %d items" "warehouse" 150 }
```

Output:

```
"warehouse has 150 items"
```

### Array arguments

```mantra
print { fmt "alpha %s beta %d gamma %q delta %f %% omega" [ "x" 7 "z" 7.5 ] }
```

Output:

```
"alpha x beta 7 gamma "z" delta 7.5 % omega"
```

The array `[ "x" 7 "z" 7.5 ]` is unpacked into four values that fill `%s`, `%d`,
`%q`, and `%f` respectively. `%%` produces a literal `%`.

### Tree representation (`%t`)

```mantra
print { fmt "sum=%t label=%s" ( + 1 2 ) "ok" }
```

Output:

```
"sum=( + 1 + 2 ) label=ok"
```

`%t` renders the tree structure of `( + 1 2 )` as-is — it shows the AST without
full evaluation. If you want the evaluated result, wrap the argument in a compute
scope:

```mantra
print { fmt "sum=%t" `{ + 1 2 }`}
```

### Quoted strings (`%q`)

```mantra
print { fmt "Value: %q" "hello world" }
```

Output:

```
"Value: ""hello world"""
```

`%q` is useful when you need a value that can be safely parsed back as a Mantra
string literal — internal double quotes are escaped.

### Integer and float conversions

```mantra
print { fmt "Integer: %d, Float: %f" 42 3.14 }
```

Output:

```
"Integer: 42, Float: 3.14"
```

Both verbs also accept arguments that produce numeric strings:

```mantra
print { fmt "Answer: %d" { + 1 2 39 } }
```

Output:

```
"Answer: 42"
```

### Variables as format arguments

```mantra
name = "Mantra"
version = 2
print { fmt "Language: %s, Version: %d" name version }
```

Output:

```
"Language: Mantra, Version: 2"
```

Variables are resolved and substituted before formatting.

### Literal percent sign

```mantra
print { fmt "100%% complete" }
```

Output:

```
"100% complete"
```

`%%` consumes no argument from the argument list.

## Evaluation

`fmt` evaluates its arguments before formatting, with one exception:

- **`%t` / `%T`** — the argument is **not** evaluated unless it is wrapped in an
  evaluation scope `{ ... }` or compute scope `` ` ... ` ``. This preserves the
  raw tree structure for inspection.

For all other verbs (`%s`, `%d`, `%f`, `%q`), the argument is evaluated before
extraction. This means expressions like `{ + 1 2 }` or `` ` * 3 4 ` `` will
reduce before formatting.

## Errors

| Error | Cause |
|---|---|
| `fmt expects a format string` | No arguments provided to `fmt`. |
| `fmt failed to clone the format string` | Internal error creating a copy of the format string. |
| `fmt expected N arguments but got M` | The number of `%` placeholders does not match the number of arguments. |
| `fmt %d expects an integer, got ...` | The `%d` verb received a value that cannot be parsed as an integer. |
| `fmt %f expects a number, got ...` | The `%f` verb received a value that cannot be parsed as a floating-point number. |
| `fmt does not support %X` | An unrecognized placeholder verb `%X` was used in the format string. |

## `printf` — Direct Output

`printf` is a variant of `fmt` that prints the result directly to the output
stream instead of returning it as a string value. It shares the same placeholder
syntax and semantics.

```mantra
printf { fmt "alpha %s beta %d" [ "x" 7 ] }
```

Output (without outer string quotes):

```
alpha x beta 7
```

`printf` also accepts a bare format string and array without an explicit `fmt`:

```mantra
printf "raw %s" [ "text" ]
```

Output:

```
raw text
```

Use `printf` when you want immediate console output. Use `fmt` when you need the
formatted string as a value for further processing.

## Comparison with `render`

`render` is a more advanced formatting function that takes three arguments:
`render <format> <profile> <subject>`. Unlike `fmt`, which produces a simple
formatted string, `render` applies a named format profile to a subject and can
produce structured output (e.g., columnar layouts).

Use `fmt` for simple string interpolation. Use `render` when you need profiled,
structured output formatting.
