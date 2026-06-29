# Print Statements

`print` emits user-facing output from a statement. Without it, a program still
produces its default statement output, but `print` gives you explicit control
over what appears and when.

```mantra
print { & [ 1 2 ] [ 3 4 ] [ 5 6 ] };
```

Output:

```text
[ 1 2 3 4 5 6 ]
```

## Why Use Print

By default, Mantra evaluates and displays every top-level statement. Use `print`
when a program contains setup statements whose results should not clutter the
output:

```mantra
rules = [ x => x + 1 ];       # stored silently
data = [ 1 2 3 ];             # stored silently
print { data ? rules };       # only this appears
```

Output:

```text
[ 2 3 4 ]
```

## What Print Displays

`print` takes a single expression as its argument. It runs the full formatting
pipeline on the evaluated result — identical to the default statement output
you see without `print`. The expression is first evaluated (inside `{ }` or
bare), then the resulting tree is formatted and emitted as a single output
line.

### Print with Different Data Types

```mantra
print "hello";
print { ` + 1 2 ` };
print { & [ 1 2 ] [ 3 4 ] };
```

Output:

```text
"hello"
+ 3
[ 1 2 3 4 ]
```

### Multiple Print Statements

Each `print` produces one output line. Lines appear in statement order:

```mantra
print "first";
print { ` + 5 3 ` };
print { & "a" "b" };
```

Output:

```text
"first"
+ 8
"ab"
```

### Print and Scope Evaluation

`print` evaluates its argument before formatting. Curly-brace scopes `{ }`
trigger evaluation of their contents:

```mantra
print { explode "abc" };
print { implode "x" "y" "z" };
```

Output:

```text
"a" "b" "c"
"xyz"
```

## Print vs. Printf

`print` uses the standard tree formatter. `printf` supports C-style format
strings with positional bindings:

| Feature | `print` | `printf` |
|---|---|---|
| Format string | No | Yes (`%s`, `%d`, `%f`, `%q`, `%t`, `%%`) |
| Formatting | Automatic tree-to-string | Manual format spec |
| Effect control | No | Yes (`mantra.effects.display.*`) |
| Use case | General output | Structured / templated output |

### Printf Format Specifiers

```mantra
print { fmt "alpha %s beta %d gamma %q delta %f %% omega" [ "x" 7 "z" 7.5 ] };
```

Output:

```text
"alpha x beta 7 gamma \"z\" delta 7.5 % omega"
```

Format specifier summary:

| Specifier | Meaning | Example Input | Output |
|---|---|---|---|
| `%s` | String / identifier | `"hello"` | `hello` |
| `%d` | Integer | `42` | `42` |
| `%f` | Floating point | `3.14` | `3.14` |
| `%q` | Quoted string | `"val"` | `"val"` |
| `%t` | Tree (full structure) | `( + 1 2 )` | `( + 1 + 2 )` |
| `%%` | Literal percent sign | — | `%` |

### Printf Effect Control

`printf` respects runtime effect flags. By default, effects are off inside
evaluation and compute scopes:

```mantra
{ printf "eval %d" [ 7 ] }              # silenced (default)
{ ~ printf "compute %d" [ 8 ] }         # silenced (default)
print "done"
```

Output:

```text
"done"
```

Enable effects per scope type:

```mantra
mantra.effects.display.evaluate = 1
{ printf "eval %d" [ 7 ] }
print "done"
```

Output:

```text
eval 7
"done"
```

```mantra
mantra.effects.display.compute = 1
{ ~ printf "compute %d" [ 7 ] }
print "done"
```

Output:

```text
compute 7
"done"
```

`print` does not have effect-gating — it always emits. This makes `print`
reliable for unconditional output, while `printf` is the choice when you want
context-sensitive behavior (silent during evaluation unless explicitly enabled).

## Print and the --debug Flag

When running with `--debug`, Mantra outputs every statement result automatically.
`print` statements do **not** duplicate this debug output — they appear only
once:

```bash
echo '1 + 2
print { 1 + 2 }' | mantra --debug
```

Output:

```text
1 + 2
1 + 2
```

The first line is the default statement output (debug mode). The second line
is the `print` statement. No duplicate is produced.

## Print and Pattern Matching

`print` can capture and display the result of selection and transform
operations:

```mantra
print { { "a" ^"b" "c" ? [ "a" => "A", "b" => "B" ] } };
```

Output:

```text
"a" "B" "c"
```

## Summary

| Keyword | Formatter | Effect-gated | Always emits |
|---|---|---|---|
| `print` | Standard tree formatter | No | Yes |
| `printf` | C-style format string | Yes | Only when effect enabled |
| `tree` | Tree formatter (raw structure) | No | Yes |
| `ir` | IR formatter | No | Yes |

Use `print` for general-purpose output that always appears. Use `printf` when
you need format-string control or effect-gated behavior inside evaluation and
compute scopes.
