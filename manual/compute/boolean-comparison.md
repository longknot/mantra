# Boolean and Comparison Operations

Mantra supports **comparison (relational) operators** and **boolean operators**
in compute contexts. Both groups return integer results: `1` for true, `0` for
false. Together they form the **predicate** operator family, which the runtime
handles specially — predicate results are always stored as integers, never as
floats, even when the computation originates from float nodes.

## Related Pages

- [Comparison Operators](boolean-comparison/comparison-operators.md) — Six relational operators (`==`, `<>`, `<`, `<=`, `>`, `>=`) with variadic chaining, type dispatch, and test-backed examples.
- [Boolean Logic](boolean-comparison/boolean-logic.md) — Boolean operators (`and`, `or`, `xor`, `not`) with truth-table semantics, variadic folding, and type coercion rules.

## Truth Values

Mantra represents booleans as integers. The value `1` means true and `0` means
false. Any nonzero integer coerces to true in a boolean context (`value <> 0`
for integers, `value <> 0.0` for floats).

## Compute Trigger Required

Like all arithmetic, boolean and comparison operations need a compute trigger:

- **Meta-compute operator** `~` — targets a specific node
- **Compute scope** `` ` ... ` `` — marks an entire expression as computable

Without a trigger, the expression remains symbolic:

```mantra
[ < 2 3 ]
```

Expected `OUTPUT`:

```text
[ < 2 3 ]
```

With compute:

```mantra
{ ~ < 2 3 }
```

Expected `OUTPUT`:

```text
0
```

## How It Works

The compute engine handles both operator groups through a **fold loop** inside
`TIntegerNode.Compute` and `TFloatNode.Compute` (`nodes.pas`).

When the engine encounters a predicate operator with numeric siblings, it walks
the right-sibling chain left to right:

1. The current node's value is captured as `PrevValue`.
2. For each numeric sibling, the operator is applied between `PrevValue` (for
   comparisons) or the accumulated boolean result (for boolean ops) and the
   sibling's value.
3. Siblings are deleted from the tree in-place after folding.
4. The final result (`1` or `0`) is stored via `StoreAccumulator`.

If a non-numeric sibling is encountered during folding, the chain breaks and the
remaining siblings are computed recursively.

### Comparison Fold

The comparison fold evaluates each adjacent pair and requires **all pairs** to
be true. The first false pair sets `RelationalResult` to false — though all
remaining siblings are still consumed (not short-circuited in the tree
traversal, just logically):

```pascal
RelationalResult := True;
while NextIndex <> EOT do
begin
  if not ComputeRelational(CurrentOp, PrevValue, Value, Ops) then
    RelationalResult := False;
  PrevValue := Value;
  GlobalTree.Delete(Index, NextIndex);
  NextIndex := RHS;
end;
Acc := Ord(RelationalResult);
StoreAccumulator(OriginalOp, Acc);
```

### Boolean Fold

The boolean fold accumulates through `ComputeBoolean` for each pair:

```pascal
BooleanResult := PrevValue <> 0;
while NextIndex <> EOT do
begin
  BooleanResult := ComputeBoolean(CurrentOp, BooleanResult, Value <> 0);
  GlobalTree.Delete(Index, NextIndex);
  NextIndex := RHS;
end;
Acc := Ord(BooleanResult);
StoreAccumulator(OriginalOp, Acc);
```

## Operator Classification

| Group | Detection Function | Operators |
|---|---|---|
| Comparison | `IsComparisonOperator` | `==`, `<>`, `<`, `<=`, `>`, `>=` |
| Boolean | `IsBooleanOperator` | `and`, `or`, `xor`, `not`, `nand`, `nor`, `nxor` |
| Predicate | `IsPredicateOperator` | Both groups combined |

The `IsPredicateOperator` function simply returns
`IsComparisonOperator(Op) or IsBooleanOperator(Op)`.

## Predicate Storage

Predicate operators are treated specially by `StoreAccumulator` — the operator
bit is cleared and the result is always stored as an integer value:

```pascal
if IsPredicateOperator(Op) then
begin
  TreeNode^.Ref := AppendValueToExpression(AValue);
  FinalOp := 0;
  TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or (FinalOp and TK_OPERATOR_MASK);
  Exit;
end;
```

This means a comparison or boolean operation on float nodes still produces an
integer result, not a float. The operator name does not appear in the output —
only the numeric result (`1` or `0`) is emitted.

## Type Dispatch

| Node Type | Comparison Ops | Boolean Coercion |
|---|---|---|
| `TIntegerNode` | `OPS_RELATIONAL_INT` (`Int64`) | `value <> 0` |
| `TFloatNode` | `OPS_RELATIONAL_FLOAT` (`Double`) | `value <> 0.0` |

Both integer and float nodes use the shared `ComputeBoolean` function for
boolean logic, with type-specific truth coercion applied before the call.

## Variadic Chaining

Both comparison and boolean operators fold across multiple operands.

### Comparison Chain

```mantra
{ ~ <= 1 2 3 }
```

The engine evaluates `1 <= 2` (true), then `2 <= 3` (true). All pairs are
true, so the result is `1`.

```mantra
{ ~ <= 1 3 2 }
```

The engine evaluates `1 <= 3` (true), then `3 <= 2` (false). Result is `0`.

See [Comparison Operators](boolean-comparison/comparison-operators.md) for
detailed variadic chain examples.

### Boolean Fold

```mantra
{ ~ and 1 2 3 }
```

All three operands are nonzero (truthy), so the result is `1`.

```mantra
{ ~ or 0 0 3 }
```

The third operand `3` is truthy, so the result is `1`.

```mantra
{ ~ xor 1 0 1 }
```

Folds left to right: `1 xor 0` is `1`, then `1 xor 1` is `0`.

See [Boolean Logic](boolean-comparison/boolean-logic.md) for detailed variadic
fold examples.

## Mixed-Type Examples

Boolean operators accept both integer and float operands within the same
expression, as long as the node type is consistent:

```mantra
{ ~ and 1.5 0.0 2.5 }
```

Expected `OUTPUT`:

```text
0
```

The second operand `0.0` is falsy, so the result is `0`.

## See Also

- [Meta-Compute Operator](meta-compute-operator.md) — The `~` compute trigger
- [Compute Scope](compute-scope.md) — Backtick compute scope
- [Integer Arithmetic](integer-arithmetic.md) — Integer operations
- [Float Arithmetic](float-arithmetic.md) — Float operations
- [Operator Reference](operator-reference.md) — All supported operators
