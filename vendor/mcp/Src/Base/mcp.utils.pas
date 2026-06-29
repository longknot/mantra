{
    This file is part of the Free Component Library

    MCP utility routines and classes
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.utils;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, base64, syncobjs, contnrs;

type

  { TThreadSafeObjectHash }

  TThreadSafeObjectHash = record
  Private
    FLock : TCriticalSection;
    FList :  TFPObjectHashTable;
  Public
    class function create(aOwnsObjects : Boolean) : TThreadSafeObjectHash;  static;
    procedure Destroy;
    Procedure GetObjectList(aList : TFPList);
    procedure Add(const aKey : String; aObject: TObject);
    function Get(const aKey : string) : TObject;
    procedure Remove(const aKey : string);
    procedure Lock;
    procedure Unlock;
    function Count : Integer;
  end;

  { TGFPObjectList }
  // Included here to be able to compile with 3.2.X
  generic TGFPObjectList<T : TObject> = class (TFPObjectList)
  private
    Type
       { TObjectEnum }
       TObjectEnum = Class
         FList : TFPObjectList;
         FIdx : Integer;
         constructor create(aList : TFPObjectList);
         function GetCurrent : T;
         function MoveNext: Boolean;
         property Current : T read GetCurrent;
       end;
    function GetElement(aIndex: Integer): T;
    procedure SetElement(aIndex: Integer; AValue: T);
  Public
    function getenumerator : TObjectEnum;
    function add(aElement : T) : integer;
    function Extract(aIndex : Integer) : T;
    property Elements[aIndex: Integer] : T read GetElement Write SetElement; default;
  end;


function EncodeBytes(data : TBytes) : string;
function DecodeBytes(data : String) : TBytes;
function CapString(const aString : String; aCap : Integer = 100) : string;

implementation

function EncodeBytes(data : TBytes) : string;

var
  lRes : TStringStream;
  lEnc : TBase64EncodingStream;

begin
  lEnc:=Nil;
  lRes:=TStringStream.Create('');
  try
    lEnc:=TBase64EncodingStream.Create(lRes);
    Lenc.WriteBuffer(Data[0],Length(Data));
    lEnc.Flush;
    Result:=lRes.DataString;
  finally
    lEnc.Free;
    lRes.Free;
  end;
end;

function DecodeBytes(data: String): TBytes;
var
  lRes : TMemoryStream;
  lDec : TBase64DecodingStream;
  lOut : TBytesStream;

begin
  Result:=Nil;
  if Data='' then
    exit;
  lDec:=Nil;
  lRes:=TStringStream.Create(data);
  try
    lDec:=TBase64DecodingStream.Create(lRes);
    lOut:=TBytesStream.Create(nil);
    lOut.CopyFrom(lDec,lDec.Size);
    Result:=Copy(lOut.Bytes,0,lOut.Size);
  finally
    lOut.Free;
    lDec.Free;
    lRes.Free;
  end;
end;

function CapString(const aString: String; aCap: Integer): string;
begin
  Result:=aString;
  if aCap<3 then
    aCap:=3;
  if Length(Result)>aCap-3 then
    begin
    SetLength(Result,aCap-3);
    Result:=Result+'...';
    end;
end;

{ TThreadSafeObjectHash }

class function TThreadSafeObjectHash.create(aOwnsObjects : Boolean): TThreadSafeObjectHash;
begin
  Result.FList:=TFPObjectHashTable.Create(aOwnsObjects);
  Result.FLock:=TCriticalSection.Create;
end;

procedure TThreadSafeObjectHash.Destroy;
begin
  FreeAndNil(FList);
  FreeAndNil(Flock);
end;

{ TResourceLister }
Type

  { TObjectLister }

  TObjectLister = class(TObject)
    FList : TFPList;
    constructor Create(aList : TFPList) ;
    procedure ListObject(Item: TObject; const Key: string; var Continue: Boolean);
  end;

{ TObjectLister }

constructor TObjectLister.Create(aList: TFPList);
begin
  FList:=aList;
end;

procedure TObjectLister.ListObject(Item: TObject; const Key: string;
  var Continue: Boolean);
begin
  Flist.Add(Item);
  Continue:=True;
end;


procedure TThreadSafeObjectHash.GetObjectList(aList: TFPList);
begin
  Lock;
  if assigned(aList) then
    With TObjectLister.Create(aList) do
      try
        Self.FList.Iterate(@ListObject);
      finally
        free;
      end;
  // do not unlock!
end;

procedure TThreadSafeObjectHash.Add(const aKey: String; aObject: TObject);
begin
  Lock;
  try
    FList.Add(aKey,aObject);
  finally
    Unlock;
  end;
end;

function TThreadSafeObjectHash.Get(const aKey: string): TObject;
begin
  Lock;
  try
    Result:=FList.Items[aKey];
  finally
    Unlock;
  end;
end;

procedure TThreadSafeObjectHash.Remove(const aKey: string);
begin
  Lock;
  try
    FList.Delete(aKey);
  finally
    Unlock;
  end;
end;

procedure TThreadSafeObjectHash.Lock;
begin
  FLock.Acquire;
end;

procedure TThreadSafeObjectHash.Unlock;
begin
  FLock.Release;
end;

function TThreadSafeObjectHash.Count: Integer;
begin
  Result:=FList.Count;
end;

{ TGFPObjectList }

function TGFPObjectList.GetElement(aIndex: Integer): T;

begin
  Result:=T(Items[aIndex]);
end;

procedure TGFPObjectList.SetElement(aIndex: Integer; AValue: T);

begin
  Items[aIndex]:=aValue;
end;

function TGFPObjectList.getenumerator: TObjectEnum;

begin
  Result:=TObjectEnum.Create(Self);
end;

function TGFPObjectList.add(aElement: T): integer;
begin
  Result:=Inherited add(aElement);
end;

function TGFPObjectList.Extract(aIndex: Integer): T;
var
  OO : Boolean;
begin
  OO:=OwnsObjects;
  try
    OwnsObjects:=False;
    Result:=GetElement(aIndex);
    Delete(aIndex);
  finally
    OwnsObjects:=OO;
  end;
end;

{ TGFPObjectList.TObjectEnum }

constructor TGFPObjectList.TObjectEnum.create(aList: TFPObjectList);
begin
  FList:=aList;
  FIdx:=-1;
end;

function TGFPObjectList.TObjectEnum.GetCurrent: T;
begin
  If FIdx<0 then
    Result:=Nil
  else
    Result:=T(FList[FIdx]);
end;

function TGFPObjectList.TObjectEnum.MoveNext: Boolean;
begin
  Inc(FIdx);
  Result:=FIdx<FList.Count;
end;

end.

