# Comparison Operators

Comparison (relational) operators evaluate the relationship between two numeric
values and return `1` (true) or `0` (false). Mantra supports six relational
operators, all available in compute contexts for both integer and float types.

## Operators

| Operator | Syntax | Token | Description |
|---|---|---|---|
| Equal | `==` | `TK_RELATIONAL_EQ` (`$00600000`) | Left equals right |
| Not equal | `<>` | `TK_RELATIONAL_NEQ` (`$00E00000`) | Left not equal to right |
| Less than | `<` | `TK_RELATIONAL_LT` (`$00A00000`) | Left less than right |
| Less or equal | `<=` | `TK_RELATIONAL_LE` (`$00400000`) | Left less than or equal to right |
| Greater than | `>` | `TK_RELATIONAL_GT` (`$00C00000`) | Left greater than right |
| Greater or equal | `>=` | `TK_RELATIONAL_GE` (`$00200000`) | Left greater than or equal to right |

## Equality

```mantra
{ ~== 2 2 }
```

Expected `OUTPUT`:

```text
== 1
```

```mantra
{ ~<> 2 3 }
```

Expected `OUTPUT`:

```text
<> 1
```

## Less Than

```mantra
{ ~< 2 3 }
```

Expected `OUTPUT`:

```text
< 1
```

```mantra
{ ~< 3 2 }
```

Expected `OUTPUT`:

```text
< 0
```

## Greater Than

```mantra
{ ~> 3 2 }
```

Expected `OUTPUT`:

```text
> 1
```

## Less Than or Equal

```mantra
{ ~<= 2 2 }
```

Expected `OUTPUT`:

```text
<= 1
```

## Greater Than or Equal

```mantra
{ ~>= 2 3 }
```

Expected `OUTPUT`:

```text
>= 0
```

## Float Comparisons

All six comparison operators work with float operands. The runtime dispatches
to `OPS_RELATIONAL_FLOAT` when the node type is `TFloatNode`:

```mantra
{ ~ < 1.5 2.0 }
```

Expected `OUTPUT`:

```text
< 1
```

## Variadic Comparison Chains

Comparison operators fold across multiple operands. The compute engine evaluates
each adjacent pair left to right, and the chain returns `1` only if **all**
pairs are true:

```mantra
{ ~ <= 1 2 3 }
```

The engine evaluates `1 <= 2` (true), then `2 <= 3` (true). All pairs are true,
so the result is `1`.

When any pair fails, the chain short-circuits:

```mantra
{ ~ <= 1 3 2 }
```

The engine evaluates `1 <= 3` (true), then `3 <= 2` (false). Result is `0`.

## Implementation

The `ComputeRelational` function in `compute.pas` dispatches the operator token
to the appropriate function in the `TRelationalOps` record:

```pascal
function ComputeRelational(const Op: Integer; const LeftValue, RightValue;
  const Ops: TRelationalOps): Boolean;
begin
  case Op and TK_RELATIONAL_MASK of
    TK_RELATIONAL_EQ:  Result := Ops.Equal(LeftValue, RightValue);
    TK_RELATIONAL_GT:  Result := Ops.Greater(LeftValue, RightValue);
    TK_RELATIONAL_GE:  Result := Ops.GreaterEqual(LeftValue, RightValue);
    TK_RELATIONAL_LT:  Result := Ops.Less(LeftValue, RightValue);
    TK_RELATIONAL_LE:  Result := Ops.LessEqual(LeftValue, RightValue);
    TK_RELATIONAL_NEQ: Result := Ops.NotEqual(LeftValue, RightValue);
  else
      Result := False;
  end;
end;
```

Integer comparisons use `Int64` operations (`OPS_RELATIONAL_INT`), while float
comparisons use `Double` operations (`OPS_RELATIONAL_FLOAT`). Both records are
defined in `compute.pas` and implement the `TRelationalOps` interface.

## Detection

The `IsComparisonOperator` function in `compute.pas` identifies relational
operators via a case statement:

```pascal
function IsComparisonOperator(const Op: Integer): Boolean;
begin
  case Op of
    TK_RELATIONAL_EQ, TK_RELATIONAL_GT, TK_RELATIONAL_GE,
    TK_RELATIONAL_LT, TK_RELATIONAL_LE, TK_RELATIONAL_NEQ:
      Result := True;
  else
      Result := False;
  end;
end;
```

## Token Bit Layout

The relational operators share the `TK_RELATIONAL_MASK` (`$00F00000`) bit range.
Each operator encodes a unique 3-bit pattern within that mask:

| Bit pattern | Operator | Bit 2 | Bit 1 | Bit 0 |
|---|---|---|---|---|
| `0 0 1` | `>=` | GE | — | — |
| `0 1 0` | `<=` | — | LE | — |
| `0 1 1` | `==` | — | LE | GE (overlap) |
| `1 0 1` | `<` | — | — | not >= |
| `1 1 0` | `>` | — | not <= | — |
| `1 1 1` | `<>` | — | not <= | not == |

The encoding allows bitwise relationships between operators. For example,
`==` (`$00600000`) is the bitwise combination of `<=` and `>=`, reflecting
that equality implies both less-or-equal and greater-or-equal simultaneously.

## See Also

- [Boolean and Comparison](../boolean-comparison.md) — Parent overview
- [Boolean Logic](boolean-logic.md) — Boolean operators (`and`, `or`, `xor`)
- [Meta-Compute Operator](../meta-compute-operator.md) — The `~` compute trigger
