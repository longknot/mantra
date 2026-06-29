# Boolean Logic

Boolean operators combine truth values. Mantra currently supports `and`, `or`,
`xor`, and `not`. Additional operators (`nand`, `nor`, `nxor`) have token
definitions but are not yet exposed in the parser.

## Truth Values

Mantra represents booleans as integers: `1` for true, `0` for false. Any
nonzero integer coerces to true in a boolean context.

## Operators

| Operator | Syntax | Token | Description |
|---|---|---|---|
| `and` | `and` | `TK_BOOLEAN_AND` (`$00300000`) | Logical AND |
| `or` | `or` | `TK_BOOLEAN_OR` (`$00500000`) | Logical OR |
| `xor` | `xor` | `TK_BOOLEAN_XOR` (`$00700000`) | Logical XOR |
| `not` | `not` | `TK_BOOLEAN_NOT` (`$00800000`) | Logical NOT |

Additional tokens defined but not yet active in the parser:

| Operator | Token | Bit pattern | Description |
|---|---|---|---|
| `nand` | `TK_BOOLEAN_NAND` (`$00B00000`) | `1 0 1` | AND with negation |
| `nor` | `TK_BOOLEAN_NOR` (`$00D00000`) | `1 1 0` | OR with negation |
| `nxor` | `TK_BOOLEAN_NXOR` (`$00F00000`) | `1 1 1` | XOR with negation |

The `TK_BOOLEAN_NOT` bit can be combined with `and`, `or`, and `xor` in the
`ComputeBoolean` function to produce the negated variants — this is how `nand`,
`nor`, and `nxor` are implemented at the compute level.

## AND

```mantra
{ ~ and 1 2 3 }
```

Expected `OUTPUT`:

```text
and 1
```

All three operands are nonzero (truthy), so the result is `1`.

When any operand is zero (false), the chain short-circuits:

```mantra
{ ~ and 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
and 0
```

The second operand `0.0` is falsy, so the result is `0`.

## OR

```mantra
{ ~ or 0 0 3 }
```

Expected `OUTPUT`:

```text
or 1
```

The third operand `3` is truthy, so the result is `1`.

## XOR

```mantra
{ ~ xor 1 0 1 }
```

Expected `OUTPUT`:

```text
xor 0
```

The engine folds left to right: `1 xor 0` is `1`, then `1 xor 1` is `0`.

## Variadic Folding

Boolean operators fold across all numeric siblings. The compute engine captures
the first operand as `BooleanResult` and chains through remaining siblings:

1. Each sibling is converted to a boolean (`<> 0` for integers, `<> 0.0` for
   floats).
2. The operator is applied between `BooleanResult` and the new value.
3. The sibling is deleted from the tree after folding.
4. If a non-numeric sibling is encountered, the chain breaks.

This means `and 1 2 3 4` evaluates as `true and true and true and true` = `1`.

## Implementation

The `ComputeBoolean` function in `compute.pas` handles all boolean operators:

```pascal
function ComputeBoolean(const Op: Integer; const LeftValue, RightValue: Boolean): Boolean;
begin
  case Op and TK_BOOLEAN_XOR of
    TK_BOOLEAN_AND: Result := LeftValue and RightValue;
    TK_BOOLEAN_OR:  Result := LeftValue or RightValue;
    TK_BOOLEAN_XOR: Result := LeftValue xor RightValue;
  else
    Result := False;
  end;
  if Op and TK_BOOLEAN_NOT <> 0 then
    Result := not Result;
end;
```

The `TK_BOOLEAN_NOT` bit is checked after the primary operation. This means
`nand` (which has the `and` bit plus the `not` bit) is implemented as
`and` followed by negation, not as a separate code path.

## Operator Detection

The `IsBooleanOperator` function checks the `TK_BOOLEAN_OP` bit:

```pascal
function IsBooleanOperator(const Op: Integer): Boolean;
begin
  Result := Op and TK_BOOLEAN_OP <> 0;
end;
```

Together with comparison operators, boolean operators form the **predicate**
group (`IsPredicateOperator`), which the store accumulator handles specially —
predicate results are stored as integers rather than floating point values.

## Token Bit Layout

Boolean operators share the `TK_BOOLEAN_MASK` (`$00F00000`) range. The 3-bit
patterns encode both the primary operation and the negation flag:

| Bit pattern | Operator | Primary | Not |
|---|---|---|---|
| `0 0 1` | `and` | AND | No |
| `0 1 0` | `or` | OR | No |
| `0 1 1` | `xor` | XOR | No |
| `1 0 0` | `not` | — | Yes (unary) |
| `1 0 1` | `nand` | AND | Yes |
| `1 1 0` | `nor` | OR | Yes |
| `1 1 1` | `nxor` | XOR | Yes |

## Type Coercion

Boolean operators accept both integer and float operands. The runtime coerces
values to booleans based on the node type:

| Node Type | Coercion |
|---|---|
| `TIntegerNode` | `value <> 0` |
| `TFloatNode` | `value <> 0.0` |

This means `and 1.5 0.0 2.5` treats `1.5` as true and `0.0` as false.

## See Also

- [Boolean and Comparison](../boolean-comparison.md) — Parent overview
- [Comparison Operators](comparison-operators.md) — Relational operators
- [Meta-Compute Operator](../meta-compute-operator.md) — The `~` compute trigger
