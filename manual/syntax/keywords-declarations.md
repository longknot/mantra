# Keywords and Declarations

Mantra provides several keywords for program structure, module management, callable
definitions, and output control. Keywords are recognized by the tokenizer and parsed
into dedicated node types in `nodes.pas`.

## Rule Declarations

The `rule` keyword declares a named transformation rule:

```mantra
rule name [
  pattern => replacement
]
```

Rules define pattern-matching rewrite operations. The left side of `=>` is the
pattern, and the right side is the replacement template.

```mantra
rule increment [
  inc x => x + 1
]
```

Named rules can be referenced by their name in selections and expressions. See
[Rule Declaration Syntax](operators-special-forms/rule-declaration-syntax.md) for
detailed syntax including multiple patterns, guards, and rule composition.

## Define

The `define` keyword registers match-time keywords that the pattern matcher
recognizes during selection and transformation:

```mantra
define keyword
```

Defined keywords become available as symbolic patterns in rules. They allow you
to extend the matcher's vocabulary without modifying the parser.

## Selector

The `selector` keyword wraps a selection policy with an expression:

```mantra
selector policy expression
```

Available policies:

| Policy | Behavior |
|---|---|
| `first` | Apply the first matching rule |
| `random` | Choose a random matching rule |
| `shrink` | Prefer rules that produce smaller results |

```mantra
selector first [ [ x => x + 1 ] [ x => x * 2 ] ]
```

## Print

The `print` keyword explicitly outputs a value to stdout. Without `print`, only
the final expression result is emitted:

```mantra
print [ 1 2 3 ]
```

OUTPUT:
```
[ 1 2 3 ]
```

You can print multiple values by chaining `print` statements:

```mantra
print "step 1"
print ` + 1 2 `
print "step 2"
```

Print creates a `TPrintNode` that formats its argument and writes it during
execution.

## Exec

The `exec` keyword runs a system command from within a Mantra program:

```mantra
exec "ls -la"
```

Exec creates a node that invokes the host shell. Use this for integrating
external tools or debugging.

## Callable and Alias

The `callable` keyword declares a callable entity — a named function that can be
invoked in expressions and matched in patterns:

```mantra
callable func;
```

The `alias` keyword creates an alias for an existing callable or rule:

```mantra
rule f [
  f x => x
];

alias g = f;

print { g 7 };    → 7
```

Callables can be used in rule patterns to drive recursive transformations:

```mantra
callable func;

rule runlist [
  runlist [ X -- ] => runlist { all X },
  runlist { X, } Y -- => func X runlist [ all Y ],
  runlist { X, } => func X
];

print { runlist [ "a", "b", "c" ] }
```

Output: `func "a" func "b" func "c"`

## Package, Import, Include, Global

Module management directives:

```mantra
package name
import package/name
include "file.m"
global variable = value
```

See [Package, Import, Include, and Global Syntax](operators-special-forms/package-import-include-global-syntax.md).
`package` sets the namespace for the current file. `import` makes symbols from
another package available. `include` performs text-level inclusion of another file.
`global` escapes scope boundaries to write to the global context.

## Explode and Implode

The `explode` keyword converts a string to a sequence of character elements:

```mantra
explode "abc"
```

OUTPUT:
```
[ "a" "b" "c" ]
```

The `implode` keyword performs the reverse — converting a sequence back to a string:

```mantra
implode [ "a" "b" "c" ]
```

OUTPUT:
```
"abc"
```

These are useful for character-level processing, string manipulation, and building
strings from computed sequences.

## Keyword Summary

| Keyword | Purpose | Node Type |
|---|---|---|
| `rule` | Named transformation rule | `TRuleNode` |
| `define` | Match-time keyword registration | `TDefineNode` |
| `selector` | Selection policy wrapper | `TSelectorNode` |
| `package` | Package declaration | `TPackageNode` |
| `import` | Import a package | `TImportNode` |
| `include` | Include a file | `TIncludeNode` |
| `global` | Global scope write | `TGlobalNode` |
| `print` | Explicit output | `TPrintNode` |
| `exec` | System command | `TExecNode` |
| `callable` | Callable declaration | `TCallableNode` |
| `explode` | String to characters | — |
| `implode` | Characters to string | — |
| `alias` | Callable alias | — |

## Related Pages

- [Rule Declaration Syntax](operators-special-forms/rule-declaration-syntax.md) — rule details
- [Import and Include Syntax](operators-special-forms/import-include-syntax.md) — module management
- [Operators and Special Forms](operators-special-forms.md) — operator reference
- [Transformations](../transformations/index.md) — rewrite and transform semantics
- [Syntax Index](index.md) — full syntax overview
