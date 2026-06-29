unit native_functions;

{$I mantra.inc}

interface

type
  TNativeNumericKind = (
    nnInteger,
    nnFloat
  );

  TNativeNumericValue = record
    Kind: TNativeNumericKind;
    IntValue: Int64;
    FloatValue: Double;
  end;

  TNativeNumericValues = array of TNativeNumericValue;
  TNativeFunctionNames = array of ansistring;

  TNativeCallStatus = (
    ncsSuccess,
    ncsUnsupported,
    ncsDomainError
  );

  TNativeFunctionCallback = function(
    const Args: TNativeNumericValues;
    out Value: TNativeNumericValue
  ): TNativeCallStatus;

  TNativeFunctionContract = record
    CanonicalName: ansistring;
    Aliases: TNativeFunctionNames;
    MinArity: Integer;
    MaxArity: Integer;
  end;

  TNativeFunctionImplementation = record
    ContractName: ansistring;
    ProviderName: ansistring;
    Callback: TNativeFunctionCallback;
  end;

procedure RegisterNativeFunctionContract(
  const CanonicalName: ansistring;
  const Aliases: array of ansistring;
  MinArity: Integer;
  MaxArity: Integer
);

procedure RegisterNativeFunctionImplementation(
  const ContractName: ansistring;
  const ProviderName: ansistring;
  Callback: TNativeFunctionCallback
);

function TryResolveNativeFunction(
  const Name: ansistring;
  out Contract: TNativeFunctionContract
): Boolean;

function InvokeNativeFunction(
  const Contract: TNativeFunctionContract;
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;

procedure RegisterBuiltinNativeFunctions;

implementation

uses
  Contnrs, Math, SysUtils;

var
  Contracts: array of TNativeFunctionContract;
  Implementations: array of TNativeFunctionImplementation;
  ContractNameIndex: TFPHashList = nil;
  ImplementationIndex: TFPHashList = nil;
  BuiltinsRegistered: Boolean = False;

procedure EnsureIndexes;
begin
  if not Assigned(ContractNameIndex) then
    ContractNameIndex := TFPHashList.Create;
  if not Assigned(ImplementationIndex) then
    ImplementationIndex := TFPHashList.Create;
end;

function EncodedIndex(Index: Integer): Pointer;
begin
  Result := Pointer(PtrInt(Index + 1));
end;

function DecodedIndex(Value: Pointer): Integer;
begin
  Result := PtrInt(Value) - 1;
end;

function ImplementationKey(
  const ProviderName: ansistring;
  const ContractName: ansistring
): ansistring;
begin
  Result := ProviderName + #1 + ContractName;
end;

procedure RegisterNativeFunctionContract(
  const CanonicalName: ansistring;
  const Aliases: array of ansistring;
  MinArity: Integer;
  MaxArity: Integer
);
var
  I, J: Integer;
begin
  EnsureIndexes;
  if CanonicalName = '' then
    raise Exception.Create('Native function contract requires a canonical name');
  if MinArity < 0 then
    raise Exception.CreateFmt(
      'Native function "%s" has invalid minimum arity',
      [CanonicalName]
    );
  if (MaxArity >= 0) and (MaxArity < MinArity) then
    raise Exception.CreateFmt(
      'Native function "%s" has invalid maximum arity',
      [CanonicalName]
    );

  if ContractNameIndex.Find(CanonicalName) <> nil then
    raise Exception.CreateFmt(
      'Native function name already registered: %s',
      [CanonicalName]
    );
  for I := 0 to High(Aliases) do
  begin
    if (Aliases[I] = '') or (Aliases[I] = CanonicalName) then
      raise Exception.CreateFmt(
        'Native function "%s" has invalid alias',
        [CanonicalName]
      );
    if ContractNameIndex.Find(Aliases[I]) <> nil then
      raise Exception.CreateFmt(
        'Native function name already registered: %s',
        [Aliases[I]]
      );
    for J := 0 to I - 1 do
      if Aliases[I] = Aliases[J] then
        raise Exception.CreateFmt(
          'Native function alias is duplicated: %s',
          [Aliases[I]]
        );
  end;

  I := Length(Contracts);
  SetLength(Contracts, I + 1);
  Contracts[I].CanonicalName := CanonicalName;
  SetLength(Contracts[I].Aliases, Length(Aliases));
  for J := 0 to High(Aliases) do
    Contracts[I].Aliases[J] := Aliases[J];
  Contracts[I].MinArity := MinArity;
  Contracts[I].MaxArity := MaxArity;

  ContractNameIndex.Add(CanonicalName, EncodedIndex(I));
  for J := 0 to High(Aliases) do
    ContractNameIndex.Add(Aliases[J], EncodedIndex(I));
end;

procedure RegisterNativeFunctionImplementation(
  const ContractName: ansistring;
  const ProviderName: ansistring;
  Callback: TNativeFunctionCallback
);
var
  I: Integer;
  Key: ansistring;
  ContractEntry: Pointer;
begin
  EnsureIndexes;
  if (ContractName = '') or (ProviderName = '') or (not Assigned(Callback)) then
    raise Exception.Create('Invalid native function implementation');

  ContractEntry := ContractNameIndex.Find(ContractName);
  if (ContractEntry = nil) or
     (Contracts[DecodedIndex(ContractEntry)].CanonicalName <> ContractName) then
    raise Exception.CreateFmt(
      'Native function contract is not registered: %s',
      [ContractName]
    );

  Key := ImplementationKey(ProviderName, ContractName);
  if ImplementationIndex.Find(Key) <> nil then
    raise Exception.CreateFmt(
      'Native function implementation already registered: %s/%s',
      [ProviderName, ContractName]
    );

  I := Length(Implementations);
  SetLength(Implementations, I + 1);
  Implementations[I].ContractName := ContractName;
  Implementations[I].ProviderName := ProviderName;
  Implementations[I].Callback := Callback;
  ImplementationIndex.Add(Key, EncodedIndex(I));
end;

function TryResolveNativeFunction(
  const Name: ansistring;
  out Contract: TNativeFunctionContract
): Boolean;
var
  I: Integer;
  Entry: Pointer;
begin
  EnsureIndexes;
  Entry := ContractNameIndex.Find(Name);
  Result := Entry <> nil;
  if not Result then
    Exit;
  I := DecodedIndex(Entry);
  Contract := Contracts[I];
end;

function InvokeNativeFunction(
  const Contract: TNativeFunctionContract;
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
var
  I: Integer;
  Entry: Pointer;
begin
  EnsureIndexes;
  Entry := ImplementationIndex.Find(
    ImplementationKey('builtin.float64', Contract.CanonicalName)
  );
  if Entry = nil then
    Exit(ncsUnsupported);
  I := DecodedIndex(Entry);
  Result := Implementations[I].Callback(Args, Value);
end;

function FloatResult(
  const Number: Double;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  if IsNan(Number) or IsInfinite(Number) then
    Exit(ncsDomainError);
  Value.Kind := nnFloat;
  Value.IntValue := 0;
  Value.FloatValue := Number;
  Result := ncsSuccess;
end;

function BuiltinSin(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  Result := FloatResult(Sin(Args[0].FloatValue), Value);
end;

function BuiltinCos(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  Result := FloatResult(Cos(Args[0].FloatValue), Value);
end;

function BuiltinTan(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  Result := FloatResult(Tan(Args[0].FloatValue), Value);
end;

function BuiltinSqrt(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  if Args[0].FloatValue < 0.0 then
    Exit(ncsDomainError);
  Result := FloatResult(Sqrt(Args[0].FloatValue), Value);
end;

function BuiltinExp(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  Result := FloatResult(Exp(Args[0].FloatValue), Value);
end;

function BuiltinLn(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
begin
  if Args[0].FloatValue <= 0.0 then
    Exit(ncsDomainError);
  Result := FloatResult(Ln(Args[0].FloatValue), Value);
end;

function BuiltinMin(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
var
  I: Integer;
  AllIntegers: Boolean;
  ResultFloat: Double;
  ResultInteger: Int64;
begin
  AllIntegers := True;
  ResultFloat := Args[0].FloatValue;
  ResultInteger := Args[0].IntValue;
  for I := 0 to High(Args) do
  begin
    AllIntegers := AllIntegers and (Args[I].Kind = nnInteger);
    if Args[I].FloatValue < ResultFloat then
      ResultFloat := Args[I].FloatValue;
    if (Args[I].Kind = nnInteger) and (Args[I].IntValue < ResultInteger) then
      ResultInteger := Args[I].IntValue;
  end;

  if AllIntegers then
  begin
    Value.Kind := nnInteger;
    Value.IntValue := ResultInteger;
    Value.FloatValue := ResultInteger;
    Exit(ncsSuccess);
  end;
  Result := FloatResult(ResultFloat, Value);
end;

function BuiltinMax(
  const Args: TNativeNumericValues;
  out Value: TNativeNumericValue
): TNativeCallStatus;
var
  I: Integer;
  AllIntegers: Boolean;
  ResultFloat: Double;
  ResultInteger: Int64;
begin
  AllIntegers := True;
  ResultFloat := Args[0].FloatValue;
  ResultInteger := Args[0].IntValue;
  for I := 0 to High(Args) do
  begin
    AllIntegers := AllIntegers and (Args[I].Kind = nnInteger);
    if Args[I].FloatValue > ResultFloat then
      ResultFloat := Args[I].FloatValue;
    if (Args[I].Kind = nnInteger) and (Args[I].IntValue > ResultInteger) then
      ResultInteger := Args[I].IntValue;
  end;

  if AllIntegers then
  begin
    Value.Kind := nnInteger;
    Value.IntValue := ResultInteger;
    Value.FloatValue := ResultInteger;
    Exit(ncsSuccess);
  end;
  Result := FloatResult(ResultFloat, Value);
end;

procedure RegisterBuiltinNativeFunctions;

  procedure RegisterUnary(
    const Name: ansistring;
    Callback: TNativeFunctionCallback
  );
  begin
    RegisterNativeFunctionContract('math.' + Name, [Name], 1, 1);
    RegisterNativeFunctionImplementation(
      'math.' + Name,
      'builtin.float64',
      Callback
    );
  end;

  procedure RegisterVariadic(
    const Name: ansistring;
    Callback: TNativeFunctionCallback
  );
  begin
    RegisterNativeFunctionContract('math.' + Name, [Name], 1, -1);
    RegisterNativeFunctionImplementation(
      'math.' + Name,
      'builtin.float64',
      Callback
    );
  end;

begin
  if BuiltinsRegistered then
    Exit;
  BuiltinsRegistered := True;

  RegisterUnary('sin', @BuiltinSin);
  RegisterUnary('cos', @BuiltinCos);
  RegisterUnary('tan', @BuiltinTan);
  RegisterUnary('sqrt', @BuiltinSqrt);
  RegisterUnary('exp', @BuiltinExp);
  RegisterUnary('ln', @BuiltinLn);
  RegisterVariadic('min', @BuiltinMin);
  RegisterVariadic('max', @BuiltinMax);
end;

finalization
  ImplementationIndex.Free;
  ContractNameIndex.Free;

end.
