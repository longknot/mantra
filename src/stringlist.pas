unit stringlist;

{$I mantra.inc}

interface

uses
  Classes, SysUtils, hashtable;

type
  // Q: use cache?
  // Q: jump table? (first symbol)
  // Q: sorted? indices? binary search?
  // Q: hash values?
  // Q: encode FLOAT/INT ...?

  // strings are null-terminated
  TLKStringList = class
  private
    FData: ansistring;
    FBuckets: TIntegerHashTable;
    FNext: TIntegerHashTable;
    procedure DecodeEntry(Index: Integer; out HeaderSize, ValueLength: Integer);
    function EncodeLongLength(ValueLength: Integer): ansistring;
    function FindWithHash(const Value: ansistring; Hash: Integer): Integer;
    function GetValue(Index: Integer): ansistring;
    function HashOf(const Value: ansistring): Integer;
    function ValuesEqualAt(Index: Integer; const Value: ansistring): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Find(const Value: ansistring): Integer;
    function Add(const Value: ansistring): Integer;
    property Value[Index: Integer]: ansistring read GetValue; default;
  end;


implementation




{ TLKStringList }

constructor TLKStringList.Create;
begin
  inherited Create;
  FBuckets.Initialize;
  FNext.Initialize;
end;

destructor TLKStringList.Destroy;
begin
  FBuckets.Destroy;
  FNext.Destroy;
  inherited Destroy;
end;

procedure TLKStringList.DecodeEntry(Index: Integer; out HeaderSize, ValueLength: Integer);
begin
  HeaderSize := 1;
  ValueLength := Ord(FData[Index]);
  if ValueLength = 255 then
  begin
    HeaderSize := 5;
    ValueLength :=
      Ord(FData[Index + 1]) or
      (Ord(FData[Index + 2]) shl 8) or
      (Ord(FData[Index + 3]) shl 16) or
      (Ord(FData[Index + 4]) shl 24);
  end;
end;

function TLKStringList.EncodeLongLength(ValueLength: Integer): ansistring;
begin
  SetLength(Result, 4);
  Result[1] := Chr(ValueLength and $FF);
  Result[2] := Chr((ValueLength shr 8) and $FF);
  Result[3] := Chr((ValueLength shr 16) and $FF);
  Result[4] := Chr((ValueLength shr 24) and $FF);
end;

function TLKStringList.HashOf(const Value: ansistring): Integer;
var
  I: Integer;
  Hash: Cardinal;
begin
  Hash := 2166136261;
  for I := 1 to Length(Value) do
  begin
    Hash := Hash xor Ord(Value[I]);
    Hash := Hash * 16777619;
  end;
  Result := Integer(Hash and $7fffffff);
end;

function TLKStringList.GetValue(Index: Integer): ansistring;
var
  HeaderSize: Integer;
  ValueLength: Integer;
begin
  if (Index < 1) or (Index > Length(FData)) then
    Exit('');
  DecodeEntry(Index, HeaderSize, ValueLength);
  Result := Copy(FData, Index + HeaderSize, ValueLength);
end;

function TLKStringList.ValuesEqualAt(Index: Integer; const Value: ansistring): Boolean;
var
  HeaderSize: Integer;
  ValueLength: Integer;
begin
  Result := False;
  if (Index < 1) or (Index > Length(FData)) then
    Exit;

  DecodeEntry(Index, HeaderSize, ValueLength);
  if ValueLength <> Length(Value) then
    Exit;

  if ValueLength = 0 then
    Exit(True);

  Result := CompareMem(@FData[Index + HeaderSize], @Value[1], ValueLength);
end;

function TLKStringList.FindWithHash(const Value: ansistring; Hash: Integer): Integer;
begin
  Result := FBuckets[Hash];
  while Result >= 0 do
  begin
    if ValuesEqualAt(Result, Value) then
      Exit;
    Result := FNext[Result];
  end;
end;

function TLKStringList.Find(const Value: ansistring): Integer;
begin
  Result := FindWithHash(Value, HashOf(Value));
end;

function TLKStringList.Add(const Value: ansistring): Integer;
var
  Hash: Integer;
  L: Integer;
begin
  Hash := HashOf(Value);
  Result := FindWithHash(Value, Hash);
  if Result < 0 then
  begin
    Result := Length(FData) + 1;
    L := Length(Value);
    if L < 255 then
      FData := FData + Chr(L) + Value
    else
      FData := FData + Chr(255) + EncodeLongLength(L) + Value;

    FNext.Add(Result, FBuckets[Hash]);
    FBuckets.Add(Hash, Result);
  end;
end;




end.
