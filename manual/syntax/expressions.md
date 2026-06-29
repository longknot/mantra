# Expressions

Expressions group values, operators, and subexpressions into a single tree node.

```mantra
( + 1 2 )
```

Parentheses create an **expression scope** -- a grouping container that holds its
contents without automatically evaluating or computing them. The exact behavior
of the contents depends on surrounding scope, operators, and explicit evaluation
directives.

## Syntax

```mantra
( contents )
```

Anything that appears inside parentheses becomes a child of the expression node.
An expression may contain zero or more children:

```mantra
( )              -- empty expression
( 1 )            -- single value
( 1 2 3 )        -- multiple values
( a b c )        -- symbols
( + 1 2 3 )      -- operator with operands
( "hello" )      -- string literal
```

## Expressions Are Grouping, Not Evaluation

Parentheses group but do not evaluate. Compare the four scope delimiters:

```mantra
( + 1 2 )       -- expression: no change
{ + 1 2 }       -- evaluation scope: collapses wrapper
` + 1 2 `       -- compute scope: reduces to + 3
[ + 1 2 3 ]     -- list container: preserves structure
```

When the intended grouping is expression structure rather than a list container,
evaluation request, or compute request, use parentheses.

## Nesting

Expressions can be nested inside each other and can contain other scope types:

```mantra
( ( 1 2 ) ( 3 4 ) )         -- nested expressions
( [ 1 2 ] [ 3 4 ] )         -- lists inside expression
( ` + 1 2 ` )               -- compute scope inside expression -> ( + 3 )
( { + 1 2 } )               -- evaluation scope inside expression -> ( + 1 2 )
```

Compute scopes `` `...` `` are reduced even when nested inside an expression.
Evaluation scopes `{...}` collapse their wrapper and the contents remain as
children of the expression.

Conversely, expressions can appear inside any other scope:

```mantra
[ ( 1 2 ) ( 3 4 ) ]         -- expressions inside list
` ( + 1 2 ) `               -- expression inside compute scope
```

## Expressions and Operators

Operators inside parentheses remain as structural elements -- they are not
automatically resolved:

```mantra
( + 1 2 )                   -- output: ( + 1 2 )
( - 10 3 )                  -- output: ( - 10 3 )
( 1 .. 5 )                  -- output: ( 1 .. 5 )
( 1 : 4 )                   -- output: ( 1 : 4 )
( & "a" "b" )              -- output: ( "a" "b" & )
```

To trigger computation, wrap with backticks or the `~` meta-compute flag:

```mantra
` + 1 2 `                   -- output: + 3
( ` + 1 2 ` )               -- output: ( + 3 )
```

## Expressions in Selections

Expressions participate in structural pattern matching through the `?` operator.
Parentheses can match against parentheses:

```mantra
( ( a b ) ( c d ) ) ? ( ( x y ) => ( z x y ) )
-- output: ( ( z a b ) ( c d ) )
```

The pattern `( x y )` matches the first child expression `( a b )`, capturing
`x = a` and `y = b`. The rewrite produces `( z a b )` in its place.

## Expressions with Repeat

Expressions can be repeated using the `:` operator. The entire expression
content is cloned:

```mantra
( a b ) : 3
-- output: ( a b ) ( a b ) ( a b )
```

## Expressions vs Lists

Both parentheses and square brackets group values. The difference is semantic:

- `( ... )` -- expression grouping; communicates expression structure
- `[ ... ]` -- list or list-like container; communicates data structure

```mantra
( 1 2 3 )                   -- expression: ( 1 2 3 )
[ 1 2 3 ]                   -- list: [ 1 2 3 ]
```

They are interchangeable in some contexts but carry different intent. Use
parentheses when the form represents an expression tree node. Use square
brackets when the form represents a collection or data container.

## Expressions with Variables

Expressions can be stored in variables and substituted back:

```mantra
x = ( 1 2 3 )
```

The variable `x` stores a tree snapshot of the expression. Referencing `x`
clones the stored tree structure.

## Multiple Expressions

When multiple expressions appear at the statement level, they are processed as
sibling nodes:

```mantra
( + 1 2 ) ( - 3 4 )
```

## Related Pages

- [List Containers](list-containers.md) -- Square bracket data containers
- [Evaluation Scopes](evaluation-scopes.md) -- Curly brace evaluation
- [Compute Scopes](compute-scopes.md) -- Backtick compute reduction
- [Scope Nodes](../language-model/programs-as-trees/scope-nodes.md) -- All scope forms compared
- [Operators and Special Forms](operators-special-forms.md) -- Operators that work with expressions