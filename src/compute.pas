unit compute;

{$I mantra.inc}

interface

uses
  tokens, sysutils;

type
  GenericValue = Int64;

  TComputeOp = (coAdd, coSub, coMul, coDiv, coNeg, coInv);

  TUnaryOp = procedure (var X);
  TBinaryOp = procedure (const X, Y; out W);
  TRelationOp = function (const X, Y): Boolean;
  TBoolOp = function (const X): Boolean;

  PArithmeticOps = ^TArithmeticOps;
  TArithmeticOps = record
    Size: Integer;
    Zero: TUnaryOp;
    One: TUnaryOp;
    NaN: TUnaryOp;
    Add: TBinaryOp;
    Sub: TBinaryOp;
    Mul: TBinaryOp;
    Divide: TBinaryOp;
    Neg: TUnaryOp;
    Inv: TUnaryOp;
  end;

  PRelationalOps = ^TRelationalOps;
  TRelationalOps = record
    Size: Integer;
    IsNegative: TBoolOp;
    Equal: TRelationOp;
    NotEqual: TRelationOp;
    Less: TRelationOp;
    LessEqual: TRelationOp;
    Greater: TRelationOp;
    GreaterEqual: TRelationOp;
  end;

// Integer and float operations
procedure FloatZero(var X);
procedure FloatOne(var X);
procedure FloatNaN(var X);
procedure FloatAdd(const X, Y; out W);
procedure FloatSub(const X, Y; out W);
procedure FloatMul(const X, Y; out W);
procedure FloatDiv(const X, Y; out W);
procedure FloatNeg(var X);
procedure FloatInv(var X);

procedure IntZero(var X);
procedure IntOne(var X);
procedure IntAdd(const X, Y; out W);
procedure IntSub(const X, Y; out W);
procedure IntMul(const X, Y; out W);
procedure IntDiv(const X, Y; out W);
procedure IntNeg(var X);
procedure IntInv(var X);

// Relational operations
function IntegerIsNegative(const X): Boolean;
function IntegerEquals(const X, Y): Boolean;
function IntegerNotEquals(const X, Y): Boolean;
function IntegerLess(const X, Y): Boolean;
function IntegerLessEqual(const X, Y): Boolean;
function IntegerGreater(const X, Y): Boolean;
function IntegerGreaterEqual(const X, Y): Boolean;

function DoubleIsNegative(const X): Boolean;
function DoubleEquals(const X, Y): Boolean;
function DoubleNotEquals(const X, Y): Boolean;
function DoubleLess(const X, Y): Boolean;
function DoubleLessEqual(const X, Y): Boolean;
function DoubleGreater(const X, Y): Boolean;
function DoubleGreaterEqual(const X, Y): Boolean;

// folding
function CombineLHS(opX, opY: Integer): Integer;
function GetCombinedOp(X, Y: Integer): Integer;

// operator helpers
function HasArithmeticOp(const Op: Integer): Boolean;
function IsReductionTrigger(const Op: Integer): Boolean;
function IsComparisonOperator(const Op: Integer): Boolean;
function IsBooleanOperator(const Op: Integer): Boolean;
function IsPredicateOperator(const Op: Integer): Boolean;
function IsFoldableArithmeticOperator(const Op: Integer; const IncludeDivide: Boolean = False): Boolean;
function IsSiblingOperand(const NextSiblingOp, CurrentSiblingOp: Integer; const IncludeDivide: Boolean = False): Boolean;

// binary reduction
function TryCombineBinary(
  const opX, opY: Integer;
  const Ops: TArithmeticOps;
  var X, Y;
  out OpW: Integer;
  out W
): Boolean;

procedure CombineBinaryOp(const opX, opY: Integer; const Ops: TArithmeticOps; var X, Y; out W);
procedure ComputeUnary(const Op: Integer; var X; const Ops: TArithmeticOps);

function ComputeRelational(const Op: Integer; const LeftValue, RightValue; const Ops: TRelationalOps): Boolean;
function ComputeBoolean(const Op: Integer; const LeftValue, RightValue: Boolean): Boolean;


const
  OPS_PROCS_INT: TArithmeticOps = (
    Size: SizeOf(TArithmeticOps);
    Zero: @IntZero;
    One: @IntOne;
    NaN: @IntZero; // N: No NaN for integers, but we can use zero as a placeholder.
    Add: @IntAdd;
    Sub: @IntSub;
    Mul: @IntMul;
    Divide: @IntDiv;
    Neg: @IntNeg;
    Inv: @IntInv;
  );

  OPS_PROCS_FLOAT: TArithmeticOps = (
    Size: SizeOf(TArithmeticOps);
    Zero: @FloatZero;
    One: @FloatOne;
    NaN: @FloatNaN;
    Add: @FloatAdd;
    Sub: @FloatSub;
    Mul: @FloatMul;
    Divide: @FloatDiv;
    Neg: @FloatNeg;
    Inv: @FloatInv;
  );

  OPS_RELATIONAL_INT: TRelationalOps = (
    Size: SizeOf(TRelationalOps);
    IsNegative: @IntegerIsNegative;
    Equal: @IntegerEquals;
    NotEqual: @IntegerNotEquals;
    Less: @IntegerLess;
    LessEqual: @IntegerLessEqual;
    Greater: @IntegerGreater;
    GreaterEqual: @IntegerGreaterEqual;
  );

  OPS_RELATIONAL_FLOAT: TRelationalOps = (
    Size: SizeOf(TRelationalOps);
    IsNegative: @DoubleIsNegative;
    Equal: @DoubleEquals;
    NotEqual: @DoubleNotEquals;
    Less: @DoubleLess;
    LessEqual: @DoubleLessEqual;
    Greater: @DoubleGreater;
    GreaterEqual: @DoubleGreaterEqual;
  );

implementation

const
  TK_ARITHMETIC_MASK = TK_PLUS or TK_MINUS or TK_MULTIPLY or TK_DIVIDE;
  TK_REDUCTION_TRIGGER_MASK = TK_PLUS or TK_MULTIPLY;

(*
| y (x) | .     | +     | -     | *     | /     | - *   | - /   | * /   | - * / |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| .     | .     | +     | -     | *     | /     | -     | - /   | /     | - /   |
| +     | +     | +     | -     | +     | /     | -     | - /   | /     | - /   |
| -     | -     | -     | +     | -     | - /   | +     | /     | - /   | /     |
| *     | *     | *     | - *   | *     | * /   | - *   | - * / | * /   | - * / |
| /     | /     | /     | - /   | /     | +     | - /   | -     | +     | -     |
| - *   | - *   | - *   | *     | - *   | - * / | *     | * /   | - * / | * /   |
| - /   | - /   | - /   | /     | - /   | -     | /     | +     | -     | +     |
| * /   | * /   | * /   | - * / | * /   | *     | - * / | - *   | *     | - *   |
| - * / | - * / | - * / | * /   | - * / | - *   | * /   | *     | - *   | *     |

(OP shr 16) and $0F :
.     = $0
+     = $1
-     = $2
*     = $4
/     = $8
- *   = $6
- /   = $A
* /   = $C
- * / = $E

*)
  COMBINE_LHS_LUT: array [0..7] of array [0..7] of Byte = (
    ( 0,  1,  0,  1,  4,  5,  4,  5), // +
    ( 1,  0,  1,  0,  5,  4,  5,  4), // -
    ( 2,  3,  2,  3,  6,  7,  6,  7), // *
    ( 3,  2,  3,  2,  7,  6,  7,  6), // -*
    ( 4,  5,  4,  5,  0,  1,  0,  1), // /
    ( 5,  4,  5,  4,  1,  0,  1,  0), // -/
    ( 6,  7,  6,  7,  2,  3,  2,  3), // */
    ( 7,  6,  7,  6,  3,  2,  3,  2)  // -*/
  );


function CombineLHS(opX, opY: Integer): Integer;
begin
  if ((opX or opY) and $000F0000 = 0) then
    Result := 0
  else
    Result := COMBINE_LHS_LUT[(opY shr 17) and $07][(opX shr 17) and $07] shl 17 or $00010000;
end;

function GetCombinedOp(X, Y: Integer): Integer;
begin
  if X = 0 then
    Exit(Y);
  if Y = 0 then
    Exit(X);

  // Accept either full token IDs (e.g. $00810000) or raw op-bytes (e.g. $81).
  if (X <> 0) and ((X and TK_OPERATOR_MASK) = 0) then
    X := X shl 16;
  if (Y <> 0) and ((Y and TK_OPERATOR_MASK) = 0) then
    Y := Y shl 16;

  Result := CombineLHS(X, Y);
end;

function HasArithmeticOp(const Op: Integer): Boolean;
begin
  Result := (Op and TK_ARITHMETIC_MASK) <> 0;
end;

function IsReductionTrigger(const Op: Integer): Boolean;
begin
  Result := (Op and TK_REDUCTION_TRIGGER_MASK) <> 0;
end;

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

function IsBooleanOperator(const Op: Integer): Boolean;
begin
  Result := Op and TK_BOOLEAN_OP <> 0;
end;

function IsPredicateOperator(const Op: Integer): Boolean;
begin
  Result := IsComparisonOperator(Op) or IsBooleanOperator(Op);
end;

function IsFoldableArithmeticOperator(const Op: Integer; const IncludeDivide: Boolean = False): Boolean;
var
  FoldMask: Integer;
begin
  FoldMask := TK_PLUS or TK_MINUS or TK_MULTIPLY;
  if IncludeDivide then
    FoldMask := FoldMask or TK_DIVIDE;
  Result := (Op and FoldMask) <> 0;
end;

function IsSiblingOperand(const NextSiblingOp, CurrentSiblingOp: Integer; const IncludeDivide: Boolean = False): Boolean;
begin
  Result := NextSiblingOp = CurrentSiblingOp;
  if not Result then
    Result := (NextSiblingOp = 0) and IsFoldableArithmeticOperator(CurrentSiblingOp, IncludeDivide);
end;

procedure ComputeUnary(const Op: Integer; var X; const Ops: TArithmeticOps);
begin
  if Op and TK_DIVIDE <> 0 then Ops.Inv(X);
  if Op and TK_MINUS  <> 0 then Ops.Neg(X);
end;

function TryCombineBinary(
  const opX, opY: Integer;
  const Ops: TArithmeticOps;
  var X, Y;
  out OpW: Integer;
  out W
): Boolean;
begin
  Result := False;
  OpW := 0;

  if (not HasArithmeticOp(opX)) or (not HasArithmeticOp(opY)) then
    Exit;

  if (not IsReductionTrigger(opX)) and (not IsReductionTrigger(opY)) then
    Exit;

  ComputeUnary(opX, X, Ops);
  ComputeUnary(opY, Y, Ops);

  if opX and opY and TK_MULTIPLY <> 0 then
    Ops.Mul(X, Y, W)
  else
    Ops.Add(X, Y, W);

  OpW := CombineLHS(opY, opX);
  Result := True;
end;

// Combine binary operations, returning the combined result.
procedure CombineBinaryOp(const opX, opY: Integer; const Ops: TArithmeticOps; var X, Y; out W);
var
  OpW: Integer;
begin
  if not TryCombineBinary(opX, opY, Ops, X, Y, OpW, W) then
  begin
    // N: Keep compatibility with existing callers.
    Ops.NaN(W);
  end
end;

function ComputeRelational(const Op: Integer; const LeftValue, RightValue; const Ops: TRelationalOps): Boolean;
begin
  case Op and TK_RELATIONAL_MASK of
    TK_RELATIONAL_EQ: Result := Ops.Equal(LeftValue, RightValue);
    TK_RELATIONAL_GT: Result := Ops.Greater(LeftValue, RightValue);
    TK_RELATIONAL_GE: Result := Ops.GreaterEqual(LeftValue, RightValue);
    TK_RELATIONAL_LT: Result := Ops.Less(LeftValue, RightValue);
    TK_RELATIONAL_LE: Result := Ops.LessEqual(LeftValue, RightValue);
    TK_RELATIONAL_NEQ: Result := Ops.NotEqual(LeftValue, RightValue);
  else
      Result := False;
  end;
end;

function ComputeBoolean(const Op: Integer; const LeftValue, RightValue: Boolean): Boolean;
begin
  case Op and TK_BOOLEAN_XOR of
    TK_BOOLEAN_AND: Result := LeftValue and RightValue;
    TK_BOOLEAN_OR: Result := LeftValue or RightValue;
    TK_BOOLEAN_XOR: Result := LeftValue xor RightValue;
  else
    Result := False;
  end;
  if Op and TK_BOOLEAN_NOT <> 0 then
    Result := not Result;
end;

{ Integer operations }
procedure IntZero(var X);
begin
  Int64(X) := 0;
end;

procedure IntOne(var X);
begin
  Int64(X) := 1;
end;

procedure IntAdd(const X, Y; out W);
begin
  Int64(W) := Int64(X) + Int64(Y);
end;

procedure IntSub(const X, Y; out W);
begin
  Int64(W) := Int64(X) - Int64(Y);
end;

procedure IntMul(const X, Y; out W);
begin
  Int64(W) := Int64(X) * Int64(Y);
end;

procedure IntDiv(const X, Y; out W);
begin
  Int64(W) := Int64(X) div Int64(Y);
end;

procedure IntNeg(var X);
begin
  Int64(X) := -Int64(X);
end;

procedure IntInv(var X);
begin
  if Int64(X) = 0 then
    raise Exception.Create('Division by zero');
  Int64(X) := 1 div Int64(X);
end;

{ Float operations }
procedure FloatZero(var X);
begin
  Double(X) := 0.0;
end;

procedure FloatOne(var X);
begin
  Double(X) := 1.0;
end;

procedure FloatNaN(var X);
begin
  Double(X) := 0/0;
end;

procedure FloatAdd(const X, Y; out W);
begin
  Double(W) := Double(X) + Double(Y);
end;

procedure FloatSub(const X, Y; out W);
begin
  Double(W) := Double(X) - Double(Y);
end;

procedure FloatMul(const X, Y; out W);
begin
  Double(W) := Double(X) * Double(Y);
end;

procedure FloatDiv(const X, Y; out W);
begin
  if Double(Y) = 0.0 then
    Double(W) := 0/0 // N: Return NaN for division by zero.
  else
    Double(W) := Double(X) / Double(Y);
end;

procedure FloatNeg(var X);
begin
  Double(X) := -Double(X);
end;

procedure FloatInv(var X);
begin
  if Double(X) = 0.0 then
    Double(X) := 0/0 // N: Return NaN for division by zero.
  else
    Double(X) := 1.0 / Double(X);
end;

{ Relational operations }
function IntegerIsNegative(const X): Boolean;
begin
  Result := Int64(X) < 0;
end;

function IntegerEquals(const X, Y): Boolean;
begin
  Result := Int64(X) = Int64(Y);
end;

function IntegerNotEquals(const X, Y): Boolean;
begin
  Result := Int64(X) <> Int64(Y);
end;

function IntegerLess(const X, Y): Boolean;
begin
  Result := Int64(X) < Int64(Y);
end;

function IntegerLessEqual(const X, Y): Boolean;
begin
  Result := Int64(X) <= Int64(Y);
end;

function IntegerGreater(const X, Y): Boolean;
begin
  Result := Int64(X) > Int64(Y);
end;

function IntegerGreaterEqual(const X, Y): Boolean;
begin
  Result := Int64(X) >= Int64(Y);
end;

function DoubleIsNegative(const X): Boolean;
begin
  Result := Double(X) < 0.0;
end;

function DoubleEquals(const X, Y): Boolean;
begin
  Result := Double(X) = Double(Y);
end;

function DoubleNotEquals(const X, Y): Boolean;
begin
  Result := Double(X) <> Double(Y);
end;

function DoubleLess(const X, Y): Boolean;
begin
  Result := Double(X) < Double(Y);
end;

function DoubleLessEqual(const X, Y): Boolean;
begin
  Result := Double(X) <= Double(Y);
end;

function DoubleGreater(const X, Y): Boolean;
begin
  Result := Double(X) > Double(Y);
end;

function DoubleGreaterEqual(const X, Y): Boolean;
begin
  Result := Double(X) >= Double(Y);
end;

end.
