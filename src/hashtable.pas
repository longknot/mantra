unit hashtable;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TKeyValuePair = record
    Key, Value: Integer;
    // Next: Integer;  // Q: maintain order of insertion (???)
  end;
  TKeyValueArray = array of TKeyValuePair;

const
  EMPTY_VALUE = -1;
  EMPTY_KEY_VALUE: TKeyValuePair = (Key: -1; Value: -1);

type
  { TIntegerHashTable }
  TIntegerHashTable = object
  private
    FItems: TKeyValueArray;
    FItemCount: Integer;
    function GetIndex(Key: Integer): Integer;
    function GetValue(Key: Integer): Integer;
    procedure SetValue(Key, Value: Integer);
    procedure Expand;
    function GetItem(I: Integer): TKeyValuePair;
    function GetCapacity: Integer;
    //function GetCurrent: Integer;
  public
    constructor Initialize;
    destructor Destroy;

    procedure Add(Key, Value: Integer);
    function FindKey(Value: Integer): Integer;
    procedure Delete(Key: Integer);
    property Value[Key: Integer]: Integer read GetValue write SetValue; default;
    property Index[Key: Integer]: Integer read GetIndex;
    property Items[I: Integer]: TKeyValuePair read GetItem;
    property Capacity: Integer read GetCapacity;
    property Count: Integer read FItemCount;

    // for in loop
    //function MoveNext: Boolean;
    //property Current: Integer read GetCurrent;
  end;

  { TXYIntegerHashTable }
  TXYIntegerHashTable = object
  private
    FKeys: TIntegerHashTable;
    FItems: TIntegerHashTable;
    FNextKey: Integer;
    function GetValue(X, Y: Integer): Integer;
    procedure SetValue(X, Y, Value: Integer);
    function GetNextKey: Integer;
  public
    constructor Initialize;
    destructor Destroy;
    property Value[X, Y: Integer]: Integer read GetValue write SetValue; default;
  end;

  { TCacheTable }
  TCacheTable = object(TIntegerHashTable)
  end;


const
  XY_SHIFT_BITS = 20; // 11.20 precision   [ 2048 , 1048576 ]

implementation

{ TIntegerHashTable }

function TIntegerHashTable.GetIndex(Key: Integer): Integer;
var
  I, H: Integer;
begin
  Result := EMPTY_VALUE;
  if Key >= 0 then
  begin
    H := High(FItems);  // 2^n - 1
    I := Key and H;
    while FItems[I].Key >= 0 do
    begin
      if FItems[I].Key = Key then Exit(I);
      I := (I + 1) and H;
    end;
    Result := I;
  end;
end;

function TIntegerHashTable.GetValue(Key: Integer): Integer;
var
  I: Integer;
begin
  I := GetIndex(Key);
  if I >= 0 then
    Result := FItems[I].Value;
end;

procedure TIntegerHashTable.SetValue(Key, Value: Integer);
begin
  Add(Key, Value);
end;

procedure TIntegerHashTable.Expand;
var
  OldItems: TKeyValueArray;
  I, L: Integer;
begin
  OldItems := Copy(FItems);
  L := Length(FItems) * 2;
  SetLength(FItems, L);

  for I := 0 to L - 1 do
    FItems[I] := EMPTY_KEY_VALUE;

  FItemCount := 0;
  for I := 0 to High(OldItems) do
    Add(OldItems[I].Key, OldItems[I].Value);
end;

function TIntegerHashTable.GetItem(I: Integer): TKeyValuePair;
begin
  Result := FItems[I];
end;

function TIntegerHashTable.GetCapacity: Integer;
begin
  Result := Length(FItems);
end;

constructor TIntegerHashTable.Initialize;
begin
  SetLength(FItems, 1);
  FItems[0] := EMPTY_KEY_VALUE;
  FItemCount := 0;
end;

destructor TIntegerHashTable.Destroy;
begin
  FItems := nil;
end;

procedure TIntegerHashTable.Add(Key, Value: Integer);
var
  I: Integer;
begin
  if Key >= 0 then
  begin
    I := GetIndex(Key);
    if FItems[I].Key < 0 then
    begin
      if (FItemCount + 1) * 2 > Length(FItems) then
      begin
        Expand;
        I := GetIndex(Key);
      end;
      Inc(FItemCount);
    end;
    FItems[I].Key := Key;
    FItems[I].Value := Value;   // N: replaces old value
  end;
end;

function TIntegerHashTable.FindKey(Value: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FItems) do
    if FItems[I].Value = Value then
      Exit(FItems[I].Key);
end;

procedure TIntegerHashTable.Delete(Key: Integer);
var
  I: Integer;
begin
  I := GetIndex(Key);
  if I >= 0 then
    FItems[I] := EMPTY_KEY_VALUE;
end;


{ TXYIntegerHashTable }

function TXYIntegerHashTable.GetValue(X, Y: Integer): Integer;
var
  Key: Integer;
begin
  Key := FKeys[X];
  Result := FItems[Key or (Y shl XY_SHIFT_BITS)];
end;

procedure TXYIntegerHashTable.SetValue(X, Y, Value: Integer);
var
  Key: Integer;
begin
  Key := FKeys[X];
  if Key = -1 then
  begin
    Key := GetNextKey;
    FKeys.Add(X, Key);
  end;
  FItems[Key or (Y shl XY_SHIFT_BITS)] := Value;
end;

function TXYIntegerHashTable.GetNextKey: Integer;
begin
  Result := FNextKey;
  Inc(FNextKey);
end;

constructor TXYIntegerHashTable.Initialize;
begin
  FKeys.Initialize;
  FItems.Initialize;
end;

destructor TXYIntegerHashTable.Destroy;
begin
  FKeys.Destroy;
  FItems.Destroy;
end;

(*
var
  A: TXYIntegerHashTable;

initialization
  A.Initialize;
  A[00,00] := 111;
  A[01,10] := 222;
  A[20,01] := 333;
  A[30,31] := 444;
  A[31,00] := 555;
  A[121231,$0212] := 666;
  A[2121231,$0213] := 777;
  A[12121231,$0212] := 888;

  WriteLn(A.FKeys.Capacity);
  WriteLn(A.FItems.Capacity);
  WriteLn(A.FKeys.Count);
  WriteLn(A.FItems.Count);
  WriteLn(A[00,00]);
  WriteLn(A[01,10]);
  WriteLn(A[20,01]);
  WriteLn(A[30,31]);
  WriteLn(A[31,00]);
  WriteLn(A[121231,$0212]);
  WriteLn(A[2121231,$0213]);
  WriteLn(A[12121231,$0212]);

  WriteLn(A[01,00]);
  WriteLn(A[00,01]);
  WriteLn(A[01,11]);
  WriteLn(A[02,10]);
  WriteLn(A[20,00]);
  WriteLn(A[21,01]);
  WriteLn(A[31,31]);
  WriteLn(A[31,30]);
  WriteLn(A[31,01]);
*)

end.

