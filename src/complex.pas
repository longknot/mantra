unit complex;

{$I mantra.inc}

interface

uses
  sysutils, tokens;

const
  IMAG_BUCKET_REAL = 0;
  IMAG_BUCKET_I = 1;
  IMAG_BUCKET_J = 2;
  IMAG_BUCKET_K = 3;
  IMAG_BUCKET_COUNT = 4;

type
  TBasisProduct = record
    Component: Integer;
    SignOp: Integer;
  end;

  TImaginaryBucket = record
    HasValue: Boolean;
    IsFloat: Boolean;
    IntValue: Int64;
    FloatValue: Double;
    Component: Integer;
  end;

  TImaginaryBuckets = array[0..IMAG_BUCKET_COUNT - 1] of TImaginaryBucket;

function IsKnownImaginaryComponent(Component: Integer): Boolean;
function ImaginaryBucketIndex(Component: Integer): Integer;
function ImaginaryComponentForBucket(BucketIndex: Integer): Integer;
function ImaginaryComponentSuffix(Component: Integer): ansistring;
function StripImaginarySuffix(const Value: ansistring): ansistring;
function NumericTokenId(NumericType, Component: Integer): Integer;
function TryGetImaginaryNumericLiteral(
  const Text: ansistring;
  out LiteralType: Integer;
  out Component: Integer
): Boolean;

procedure InitializeImaginaryBuckets(var Buckets: TImaginaryBuckets);
function IsZeroBucket(const Bucket: TImaginaryBucket): Boolean;
procedure AddIntegerToBucket(var Bucket: TImaginaryBucket; Value: Int64);
procedure AddFloatToBucket(var Bucket: TImaginaryBucket; Value: Double);
function CombineQuaternionBasis(
  LeftComponent,
  RightComponent: Integer;
  out ResultComponent: Integer;
  out BasisSignOp: Integer
): Boolean;
function CombineQuaternionInverseBasis(
  Component: Integer;
  out ResultComponent: Integer;
  out BasisSignOp: Integer
): Boolean;
function CombineQuaternionProductOp(
  LeftOp,
  RightOp,
  BasisSignOp: Integer
): Integer;
procedure MultiplyQuaternionValues(
  const LeftBuckets,
  RightBuckets: TImaginaryBuckets;
  var ResultBuckets: TImaginaryBuckets
);
function TryInvertQuaternionValue(
  const SourceBuckets: TImaginaryBuckets;
  var ResultBuckets: TImaginaryBuckets
): Boolean;

implementation

const
  BASIS_PRODUCT_LUT: array[0..IMAG_BUCKET_COUNT - 1, 0..IMAG_BUCKET_COUNT - 1] of TBasisProduct = (
    (
      (Component: 0;         SignOp: 0),
      (Component: TK_IMAG_I; SignOp: 0),
      (Component: TK_IMAG_J; SignOp: 0),
      (Component: TK_IMAG_K; SignOp: 0)
    ),
    (
      (Component: TK_IMAG_I; SignOp: 0),
      (Component: 0;         SignOp: TK_MINUS),
      (Component: TK_IMAG_K; SignOp: 0),
      (Component: TK_IMAG_J; SignOp: TK_MINUS)
    ),
    (
      (Component: TK_IMAG_J; SignOp: 0),
      (Component: TK_IMAG_K; SignOp: TK_MINUS),
      (Component: 0;         SignOp: TK_MINUS),
      (Component: TK_IMAG_I; SignOp: 0)
    ),
    (
      (Component: TK_IMAG_K; SignOp: 0),
      (Component: TK_IMAG_J; SignOp: 0),
      (Component: TK_IMAG_I; SignOp: TK_MINUS),
      (Component: 0;         SignOp: TK_MINUS)
    )
  );

function IsKnownImaginaryComponent(Component: Integer): Boolean;
begin
  Result := (Component = 0) or
            (Component = TK_IMAG_I) or
            (Component = TK_IMAG_J) or
            (Component = TK_IMAG_K);
end;

function ImaginaryBucketIndex(Component: Integer): Integer;
begin
  case Component of
    0: Result := IMAG_BUCKET_REAL;
    TK_IMAG_I: Result := IMAG_BUCKET_I;
    TK_IMAG_J: Result := IMAG_BUCKET_J;
    TK_IMAG_K: Result := IMAG_BUCKET_K;
  else
    Result := -1;
  end;
end;

function ImaginaryComponentForBucket(BucketIndex: Integer): Integer;
begin
  case BucketIndex of
    IMAG_BUCKET_I: Result := TK_IMAG_I;
    IMAG_BUCKET_J: Result := TK_IMAG_J;
    IMAG_BUCKET_K: Result := TK_IMAG_K;
  else
    Result := 0;
  end;
end;

function ImaginaryComponentSuffix(Component: Integer): ansistring;
begin
  case Component of
    TK_IMAG_I: Result := 'i';
    TK_IMAG_J: Result := 'j';
    TK_IMAG_K: Result := 'k';
  else
    Result := '';
  end;
end;

function StripImaginarySuffix(const Value: ansistring): ansistring;
begin
  Result := Value;
  if (Length(Result) > 0) and (Result[Length(Result)] in ['i', 'j', 'k']) then
    Delete(Result, Length(Result), 1);
end;

function NumericTokenId(NumericType, Component: Integer): Integer;
begin
  Result := NumericType or (Component and TK_EXTRA_MASK);
end;

function TryGetImaginaryNumericLiteral(
  const Text: ansistring;
  out LiteralType: Integer;
  out Component: Integer
): Boolean;
var
  Magnitude: ansistring;
  IntValue: Int64;
  FloatValue: Double;
begin
  Result := False;
  LiteralType := 0;
  Component := 0;
  if Length(Text) < 2 then
    Exit;

  case Text[Length(Text)] of
    'i': Component := TK_IMAG_I;
    'j': Component := TK_IMAG_J;
    'k': Component := TK_IMAG_K;
  else
    Exit;
  end;

  Magnitude := System.Copy(Text, 1, Length(Text) - 1);
  if Magnitude = '' then
    Exit;

  if TryStrToInt64(Magnitude, IntValue) then
  begin
    LiteralType := TK_INTEGER;
    Exit(True);
  end;

  if TryStrToFloat(Magnitude, FloatValue, DefaultFormatSettings) then
  begin
    LiteralType := TK_FLOAT;
    Exit(True);
  end;
end;

procedure InitializeImaginaryBuckets(var Buckets: TImaginaryBuckets);
var
  I: Integer;
begin
  for I := 0 to High(Buckets) do
  begin
    Buckets[I].HasValue := False;
    Buckets[I].IsFloat := False;
    Buckets[I].IntValue := 0;
    Buckets[I].FloatValue := 0.0;
    Buckets[I].Component := ImaginaryComponentForBucket(I);
  end;
end;

function IsZeroBucket(const Bucket: TImaginaryBucket): Boolean;
begin
  if Bucket.IsFloat then
    Result := Bucket.FloatValue = 0.0
  else
    Result := Bucket.IntValue = 0;
end;

procedure AddIntegerToBucket(var Bucket: TImaginaryBucket; Value: Int64);
begin
  if not Bucket.HasValue then
  begin
    Bucket.HasValue := True;
    Bucket.IntValue := Value;
    Exit;
  end;

  if Bucket.IsFloat then
    Bucket.FloatValue := Bucket.FloatValue + Value
  else
    Bucket.IntValue := Bucket.IntValue + Value;
end;

procedure AddFloatToBucket(var Bucket: TImaginaryBucket; Value: Double);
begin
  if not Bucket.HasValue then
  begin
    Bucket.HasValue := True;
    Bucket.IsFloat := True;
    Bucket.FloatValue := Value;
    Exit;
  end;

  if not Bucket.IsFloat then
  begin
    Bucket.IsFloat := True;
    Bucket.FloatValue := Bucket.IntValue;
  end;
  Bucket.FloatValue := Bucket.FloatValue + Value;
end;

function BucketFloatValue(const Bucket: TImaginaryBucket): Double;
begin
  if not Bucket.HasValue then
    Result := 0.0
  else if Bucket.IsFloat then
    Result := Bucket.FloatValue
  else
    Result := Bucket.IntValue;
end;

function CombineQuaternionBasis(
  LeftComponent,
  RightComponent: Integer;
  out ResultComponent: Integer;
  out BasisSignOp: Integer
): Boolean;
var
  LeftBucket: Integer;
  RightBucket: Integer;
  Product: TBasisProduct;
begin
  Result := False;
  ResultComponent := 0;
  BasisSignOp := 0;

  LeftBucket := ImaginaryBucketIndex(LeftComponent);
  RightBucket := ImaginaryBucketIndex(RightComponent);
  if (LeftBucket < 0) or (RightBucket < 0) then
    Exit;

  Product := BASIS_PRODUCT_LUT[LeftBucket, RightBucket];
  ResultComponent := Product.Component;
  BasisSignOp := Product.SignOp;
  Result := True;
end;

function CombineQuaternionInverseBasis(
  Component: Integer;
  out ResultComponent: Integer;
  out BasisSignOp: Integer
): Boolean;
begin
  Result := IsKnownImaginaryComponent(Component);
  ResultComponent := Component;
  BasisSignOp := 0;
  if not Result then
    Exit;

  if Component <> 0 then
    BasisSignOp := TK_MINUS;
end;

function NormalizeOperatorBits(Op: Integer): Integer;
begin
  if (Op <> 0) and ((Op and TK_OPERATOR_MASK) = 0) then
    Op := Op shl 16;
  Result := Op and TK_OPERATOR_MASK;
end;

function CombineQuaternionProductOp(
  LeftOp,
  RightOp,
  BasisSignOp: Integer
): Integer;
var
  Negative: Boolean;
begin
  LeftOp := NormalizeOperatorBits(LeftOp);
  RightOp := NormalizeOperatorBits(RightOp);
  BasisSignOp := NormalizeOperatorBits(BasisSignOp);

  if ((LeftOp and RightOp and TK_MULTIPLY) = 0) or
     (((LeftOp or RightOp) and TK_DIVIDE) <> 0) then
    Exit(TK_ERROR);

  Negative := ((LeftOp and TK_MINUS) <> 0) xor
              ((RightOp and TK_MINUS) <> 0) xor
              ((BasisSignOp and TK_MINUS) <> 0);

  Result := TK_MULTIPLY;
  if Negative then
    Result := Result or TK_MINUS;
end;

procedure AddQuaternionBucketProduct(
  const LeftBucket,
  RightBucket: TImaginaryBucket;
  var ResultBuckets: TImaginaryBuckets
);
var
  ResultComponent: Integer;
  BasisSignOp: Integer;
  ResultBucketIndex: Integer;
  ProductInt: Int64;
  ProductFloat: Double;
begin
  if (not LeftBucket.HasValue) or IsZeroBucket(LeftBucket) or
     (not RightBucket.HasValue) or IsZeroBucket(RightBucket) then
    Exit;

  if not CombineQuaternionBasis(
    LeftBucket.Component, RightBucket.Component, ResultComponent, BasisSignOp
  ) then
    Exit;

  ResultBucketIndex := ImaginaryBucketIndex(ResultComponent);
  if ResultBucketIndex < 0 then
    Exit;

  if LeftBucket.IsFloat or RightBucket.IsFloat then
  begin
    if LeftBucket.IsFloat then
      ProductFloat := LeftBucket.FloatValue
    else
      ProductFloat := LeftBucket.IntValue;

    if RightBucket.IsFloat then
      ProductFloat := ProductFloat * RightBucket.FloatValue
    else
      ProductFloat := ProductFloat * RightBucket.IntValue;

    if (BasisSignOp and TK_MINUS) <> 0 then
      ProductFloat := -ProductFloat;

    AddFloatToBucket(ResultBuckets[ResultBucketIndex], ProductFloat);
  end
  else
  begin
    ProductInt := LeftBucket.IntValue * RightBucket.IntValue;
    if (BasisSignOp and TK_MINUS) <> 0 then
      ProductInt := -ProductInt;

    AddIntegerToBucket(ResultBuckets[ResultBucketIndex], ProductInt);
  end;
end;

procedure MultiplyQuaternionValues(
  const LeftBuckets,
  RightBuckets: TImaginaryBuckets;
  var ResultBuckets: TImaginaryBuckets
);
var
  I: Integer;
  J: Integer;
begin
  InitializeImaginaryBuckets(ResultBuckets);
  for I := 0 to High(LeftBuckets) do
    for J := 0 to High(RightBuckets) do
      AddQuaternionBucketProduct(LeftBuckets[I], RightBuckets[J], ResultBuckets);
end;

function TryInvertQuaternionValue(
  const SourceBuckets: TImaginaryBuckets;
  var ResultBuckets: TImaginaryBuckets
): Boolean;
var
  I: Integer;
  Value: Double;
  NormSquared: Double;
begin
  Result := True;
  InitializeImaginaryBuckets(ResultBuckets);

  NormSquared := 0.0;
  for I := 0 to High(SourceBuckets) do
  begin
    Value := BucketFloatValue(SourceBuckets[I]);
    NormSquared := NormSquared + (Value * Value);
  end;

  if NormSquared = 0.0 then
  begin
    AddFloatToBucket(ResultBuckets[IMAG_BUCKET_REAL], 0.0 / 0.0);
    Exit;
  end;

  for I := 0 to High(SourceBuckets) do
  begin
    Value := BucketFloatValue(SourceBuckets[I]);
    if Value = 0.0 then
      Continue;

    if SourceBuckets[I].Component <> 0 then
      Value := -Value;

    AddFloatToBucket(ResultBuckets[I], Value / NormSquared);
  end;
end;

end.
