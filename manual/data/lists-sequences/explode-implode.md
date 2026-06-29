# Explode and Implode

The `explode` and `implode` keywords are inverse operations that convert between
strings and sequences of individual character strings. They operate on the sibling
chain of nodes — every string in the chain is processed, and non-string nodes pass
through unchanged.

## Explode

`explode` takes one or more string arguments and expands each into a sequence of
single-character strings.

**Syntax:**

```mantra
explode string_expression
explode string1 string2 ...
```

Each string argument is replaced by its individual characters, each as a separate
single-character string. The characters are linked as siblings in left-to-right
order, preserving the original argument order.

### Basic usage

```mantra
print { explode "abc" }
```

Expected `OUTPUT`:

```text
"a" "b" "c"
```

### Multiple string arguments

When `explode` receives multiple string arguments, each one is expanded
independently — the result is the concatenation of all the per-string character
sequences:

```mantra
print { explode "ab" "cd" }
```

Expected `OUTPUT`:

```text
"a" "b" "c" "d"
```

### Strings with spaces and special characters

Every character in the string — including spaces — produces a separate single-
character result:

```mantra
print { explode "a b c" }
```

Expected `OUTPUT`:

```text
"a" " " "b" " " "c"
```

### Empty strings

An empty string argument produces no characters and is simply removed from the
sibling chain:

```mantra
print { explode "" }
```

Expected `OUTPUT`:

```text
(empty)
```

```mantra
print { explode "" "ab" "" }
```

Expected `OUTPUT`:

```text
"a" "b"
```

### No arguments

With no arguments, `explode` produces an empty result:

```mantra
print { explode }
```

Expected `OUTPUT`:

```text
(empty)
```

### Non-string siblings

If non-string nodes appear among the arguments, they are left untouched and pass
through the sibling chain unchanged:

```mantra
print { explode "x" 1 "y" }
```

Expected `OUTPUT`:

```text
"x" 1 "y"
```

## Implode

`implode` concatenates consecutive string arguments into a single string. It
operates left to right, merging runs of adjacent string nodes. Non-string nodes
act as separators — they break the chain and are not included in the
concatenation.

**Syntax:**

```mantra
implode string_expression
implode string1 string2 ...
```

### Basic usage

```mantra
print { implode "a" "b" "c" }
```

Expected `OUTPUT`:

```text
"abc"
```

### Multiple-argument concatenation

Multiple string arguments — whether single characters or longer strings — are all
concatenated in order:

```mantra
print { implode "ab" "cd" }
```

Expected `OUTPUT`:

```text
"abcd"
```

### Empty string handling

Empty strings are absorbed during concatenation and do not affect the result:

```mantra
print { implode "" "a" "" }
```

Expected `OUTPUT`:

```text
"a"
```

### Non-string siblings as separators

Non-string nodes in the argument chain are left in place and act as boundaries
between separate string groups. Only the consecutive strings on either side of a
non-string node are merged:

```mantra
print { implode 1 "a" "b" 2 "c" }
```

Expected `OUTPUT`:

```text
1 "ab" 2 "c"
```

In this example, `"a"` and `"b"` are merged into `"ab"` (the integers `1` and `2`
block further merging). The lone `"c"` has no adjacent string neighbor on the
right, so it remains as-is.

### No arguments

With no arguments, `implode` produces an empty result:

```mantra
print { implode }
```

Expected `OUTPUT`:

```text
(empty)
```

## Explode and Implode as inverses

`explode` and `implode` are designed as complementary operations. Exploding a
string and then imploding the result recovers the original:

```mantra
print { implode { explode "hello" } }
```

Expected `OUTPUT`:

```text
"hello"
```

## Implementation details

Both `explode` and `implode` evaluate their children first, then transform the
sibling chain in place:

- **`explode`** replaces each string node with a sequence of single-character
  string nodes. The first character reuses the original node; additional
  characters are allocated as new sibling nodes. Non-string nodes and empty
  strings are skipped or removed.

- **`implode`** walks the sibling chain, merging each consecutive run of string
  nodes into one combined string. The first node in each run is updated with the
  combined value, and the subsequent nodes in the run are deleted. Non-string
  nodes break the chain and are preserved.

After transformation, the `explode` / `implode` keyword node itself is expanded
away, leaving only the result chain.
