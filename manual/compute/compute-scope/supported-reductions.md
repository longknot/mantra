# Supported Reductions

Inside a backtick compute scope (`` ` ... ` ``), Mantra performs arithmetic reduction on the AST by traversing sibling chains and combining compatible operands. This page catalogs every reduction the runtime supports.

## Entry Point

The `` ` `` token creates a `TComputeNode` (`nodes.pas`). On evaluation it calls `LHS.Compute(Context)` on the subtree, which dispatches through the node's `Compute` method based on its VMT type. The actual reduction logic lives in `TIntegerNode.Compute` and `TFloatNode.Compute` (both inherit from `TNumericalNode`), with shared helpers in `compute.pas`.

## Arithmetic Operators

| Operator | Token Mask | Description |
|---|---|---|
| `+` | `TK_PLUS` | Addition |
| `-` | `TK_MINUS` | Subtraction / negation |
| `*` | `TK_MULTIPLY` | Multiplication |
| `/` | `TK_DIVIDE` | Division / inversion |

### Binary Reduction

When two adjacent siblings both carry arithmetic operators, `TryCombineBinary` (`compute.pas`) attempts to fold them:

1. Both operands must have arithmetic flags (`TK_PLUS`, `TK_MINUS`, `TK_MULTIPLY`, or `TK_DIVIDE`).
2. At least one must be a *reduction trigger* (`TK_PLUS` or `TK_MULTIPLY`).
3. Unary modifiers (`/` for inversion, `-` for negation) are applied first via `ComputeUnary`.
4. If both operands share `TK_MULTIPLY`, the result is multiplied; otherwise they are added.
5. The combined operator is looked up in the `COMBINE_LHS_LUT` table.

The lookup table encodes 8x8 operator pair combinations (`.` `+` `-` `*` `/` `- *` `- /` `* /` `- * /`) and determines the resulting operator byte for the accumulator node.

### Unary Operations

When a node has a pending unary operator and no right-hand sibling:
- `/` with no RHS -> inversion (`Inv`): `1 / value`
- `-` -> negation (`Neg`): `-value`
- `/` combined with `-` -> negated inversion

For single-term quaternion inverses, `TryStoreSingleTermInverse` handles the special case of inverting expressions like `/ 2i` by computing the quaternion conjugate and magnitude.

## Type Handling

| Node Type | Source | Value Type |
|---|---|---|
| `TIntegerNode` (`OBJ_INTEGER`) | `nodes.pas` | `Int64` |
| `TFloatNode` (`OBJ_FLOAT`) | `nodes.pas` | `Double` |
| `TComplexNode` (`OBJ_COMPLEX`) | `nodes.pas` | `Double` (extends TFloatNode) |

Integer and float operations have separate dispatch tables:
- `OPS_PROCS_INT` (`compute.pas`) — integer arithmetic (Zero, One, Add, Sub, Mul, Div, Neg, Inv)
- `OPS_PROCS_FLOAT` (`compute.pas`) — float arithmetic (same ops, plus `NaN` for division by zero)

Type promotion: when mixing integer and float operands in a chain, the result is promoted to `Double` (`GetCombinedType` in `nodes.pas`).

## Imaginary Components

Numerical nodes can carry an imaginary component in the `TK_EXTRA_MASK` bits (`GetImaginaryComponent` / `SetImaginaryComponent`). Supported components are tracked by `IsKnownImaginaryComponent`.

### Additive Bucket Reduction

When the current operator is `TK_PLUS`, `TryComputeAdditiveBuckets` (`TNumericalNode`) collects all siblings with additive operators (`+` or `-`) into buckets keyed by their imaginary component:

1. Siblings are traversed via `RHS` links.
2. Each sibling's imaginary component is extracted and mapped to a bucket index via `ImaginaryBucketIndex`.
3. Integer and float values are accumulated separately per bucket (`AddIntegerToBucket`, `AddFloatToBucket`).
4. If a non-numeric sibling is encountered, it is evaluated first (`Node[CurrentIndex].Compute(Context)`), and the result is re-checked.
5. Once all additive siblings are consumed, the tree is rewritten via `EmitBucketChain` — emitting one node per non-zero bucket.

### Quaternion Support

The runtime supports quaternion arithmetic through:
- **Quaternion multiplication** — `IsQuaternionMultiplicationPair` detects two numeric nodes both multiplied with non-zero imaginary components whose basis can combine via `CombineQuaternionBasis`.
- **Quaternion inversion** — `TryInvertQuaternionExpressionValue` extracts all components into buckets, computes the conjugate and norm, then re-emits.
- **Quaternion product distribution** — `TryDistributeQuaternionExpressionProduct` distributes multiplication over addition for quaternion expressions.

## Relational (Comparison) Operators

| Operator | Token | Description |
|---|---|---|
| `=` | `TK_RELATIONAL_EQ` | Equal |
| `<>` | `TK_RELATIONAL_NEQ` | Not equal |
| `<` | `TK_RELATIONAL_LT` | Less than |
| `<=` | `TK_RELATIONAL_LE` | Less than or equal |
| `>` | `TK_RELATIONAL_GT` | Greater than |
| `>=` | `TK_RELATIONAL_GE` | Greater than or equal |

Comparison operators trigger chain folding: `TIntegerNode.Compute` and `TFloatNode.Compute` iterate through RHS siblings with matching operators, comparing each pair via `ComputeRelational` (`compute.pas`). The result is `True` only if ALL comparisons hold (folded with implicit AND). The final boolean result is stored as `0` or `1`.

Separate relational op tables exist for integers (`OPS_RELATIONAL_INT`) and floats (`OPS_RELATIONAL_FLOAT`).

## Boolean Operators

| Operator | Token | Description |
|---|---|---|
| `and` | `TK_BOOLEAN_AND` | Logical AND |
| `or` | `TK_BOOLEAN_OR` | Logical OR |
| `xor` | `TK_BOOLEAN_XOR` | Logical XOR |
| `not` | `TK_BOOLEAN_NOT` | Logical NOT (unary modifier) |

Boolean operators also fold sibling chains. `ComputeBoolean` (`compute.pas`) applies the binary operation, then applies NOT as a final post-processing step if the `TK_BOOLEAN_NOT` flag is set.

## Native Functions

The `native_functions.pas` unit provides a registry of callable math functions accessible within compute scopes:

| Function | Arity | Description | Domain |
|---|---|---|---|
| `sin` / `math.sin` | 1 | Sine | All reals |
| `cos` / `math.cos` | 1 | Cosine | All reals |
| `tan` / `math.tan` | 1 | Tangent | All reals (watch discontinuities) |
| `sqrt` / `math.sqrt` | 1 | Square root | Non-negative |
| `exp` / `math.exp` | 1 | Exponential | All reals |
| `ln` / `math.ln` | 1 | Natural logarithm | Positive only |
| `min` / `math.min` | 1+ (variadic) | Minimum of arguments | All numerics |
| `max` / `math.max` | 1+ (variadic) | Maximum of arguments | All numerics |

Domain violations return `ncsDomainError` status. Results that are NaN or infinite are also rejected.

`min` and `max` preserve integer type when all arguments are integers; otherwise they return floats.

## Reduction Flow

The complete reduction flow for a numeric node:

1. **Additive buckets** — if operator is `TK_PLUS`, attempt `TryComputeAdditiveBuckets` first. If successful, recurse on remaining RHS and exit.
2. **Unary-only** — if operator has `TK_DIVIDE` flag and no RHS, apply `ApplyUnaryAndStoreSelf` and exit.
3. **Foldable chain** — if the operator is foldable (arithmetic, relational, or boolean):
   - For relational: fold siblings with matching comparison, store boolean result.
   - For boolean: fold siblings with matching boolean op, store boolean result.
   - For arithmetic: recurse via `TNumericalNode.Recurse`, which iterates siblings, attempting `TryCombineSiblingAndStore` on numeric pairs or evaluating non-numeric siblings first.
4. **Tail recursion** — if RHS remains after folding, compute it.

## Error Handling

- **Division by zero** (integer): raises `Exception.Create('Division by zero')`.
- **Division by zero** (float): returns `NaN` (`0/0`).
- **Native function domain error**: returns `ncsDomainError` status.
- **NaN / infinite from native functions**: returns `ncsDomainError`.
- **Uncombinable binary ops**: `CombineBinaryOp` stores `NaN` as the result.

## Source Files

| File | Role |
|---|---|
| `src/compute.pas` | Arithmetic ops, relational ops, boolean ops, binary reduction, lookup tables |
| `src/nodes.pas` | `TComputeNode`, `TNumericalNode`, `TIntegerNode`, `TFloatNode`, `TComplexNode`, `TScopeNode` |
| `src/native_functions.pas` | Native function registry (`sin`, `cos`, `sqrt`, etc.) |
| `src/tokens.pas` | Token ID constants and masks (`TK_PLUS`, `TK_MINUS`, etc.) |
