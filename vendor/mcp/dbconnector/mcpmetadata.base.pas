{
    This file is part of the Free Component Library

    Database metadata provider base classes and factory
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.base;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, Types, dateutils, db, sqldb, fpjson,
  mcp.types, mcp.logging, mcp.utils;

type

  { TIndexInfo }

  TIndexInfo = record
    Name: string;
    Fields: TStringDynArray;
    Unique: Boolean;
    function ToJSON: TJSONObject;
  end;
  TIndexInfoArray = array of TIndexInfo;

  { TViewInfo }

  TViewInfo = record
    Name: string;
    function ToJSON: TJSONObject;
  end;
  TViewInfoArray = array of TViewInfo;

  { TViewDetails }

  TViewDetails = record
    SQL: string;
    Updateable: Boolean;
    function ToJSON: TJSONObject;
  end;

  { TRelationshipInfo }

  TRelationshipInfo = record
    Name: string;
    ColumnNames: TStringDynArray;
    ReferencedTable: string;
    ReferencedColumnNames: TStringDynArray;
    function ToJSON: TJSONObject;
  end;
  TRelationshipInfoArray = array of TRelationshipInfo;

  { TDBMetadataProvider }

  TDBMetadataProvider = class(TObject)
  protected
    function CreateQuery(aConnection: TSQLConnection): TSQLQuery;
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; virtual; abstract;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; virtual; abstract;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; virtual; abstract;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; virtual; abstract;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; virtual; abstract;
  end;
  TDBMetadataProviderClass = class of TDBMetadataProvider;

{ Standalone JSON conversion functions }
procedure SQLRecordToJSON(aRow: TJSONObject; aQuery: TSQLQuery);
function SQLQueryToJSON(aQuery: TSQLQuery): TJSONArray;

{ Identifier safety helpers }
function SafeIdentifier(aConnection: TSQLConnection; const aName: string): string;
function SafeStringLiteral(const aName: string): string;

{ Provider factory }
procedure RegisterMetadataProvider(aConnectionClass: TSQLConnectionClass; aProviderClass: TDBMetadataProviderClass);
function GetMetadataProvider(aConnection: TSQLConnection): TDBMetadataProvider;

implementation

{ TIndexInfo }

function TIndexInfo.ToJSON: TJSONObject;
var
  lArr: TJSONArray;
  i: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('name', Name);
    lArr := TJSONArray.Create;
    for i := 0 to Length(Fields) - 1 do
      lArr.Add(Fields[i]);
    Result.Add('fields', lArr);
    Result.Add('unique', Unique);
  except
    Result.Free;
    raise;
  end;
end;

{ TViewInfo }

function TViewInfo.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('name', Name);
  except
    Result.Free;
    raise;
  end;
end;

{ TViewDetails }

function TViewDetails.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('sql', SQL);
    Result.Add('updateable', Updateable);
  except
    Result.Free;
    raise;
  end;
end;

{ TRelationshipInfo }

function TRelationshipInfo.ToJSON: TJSONObject;
var
  lArr: TJSONArray;
  i: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('name', Name);
    lArr := TJSONArray.Create;
    for i := 0 to Length(ColumnNames) - 1 do
      lArr.Add(ColumnNames[i]);
    Result.Add('column_names', lArr);
    Result.Add('referenced_table', ReferencedTable);
    lArr := TJSONArray.Create;
    for i := 0 to Length(ReferencedColumnNames) - 1 do
      lArr.Add(ReferencedColumnNames[i]);
    Result.Add('referenced_column_names', lArr);
  except
    Result.Free;
    raise;
  end;
end;

{ TDBMetadataProvider }

function TDBMetadataProvider.CreateQuery(aConnection: TSQLConnection): TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.Database := aConnection;
  Result.Transaction := aConnection.Transaction;
end;

{ SQLRecordToJSON }

procedure SQLRecordToJSON(aRow: TJSONObject; aQuery: TSQLQuery);
var
  F: TField;
  S: String;
begin
  for F in aQuery.Fields do
  begin
    if F.IsNull then
      aRow.Add(F.FieldName)
    else
      case F.DataType of
        ftInteger: aRow.Add(F.FieldName, F.AsInteger);
        ftLargeInt: aRow.Add(F.FieldName, F.AsLargeInt);
        ftBoolean: aRow.Add(F.FieldName, F.AsBoolean);
        ftFloat,
        ftCurrency: aRow.Add(F.FieldName, F.AsString);
        ftDate,
        ftDateTime,
        ftTime,
        ftTimeStamp: aRow.Add(F.FieldName, DateToISO8601(F.AsDateTime));
        ftGuid,
        ftString,
        ftFixedChar,
        ftMemo: aRow.Add(F.FieldName, F.AsString);
        ftWideString,
        ftFixedWideChar,
        ftWideMemo: aRow.Add(F.FieldName, UTF8Encode(F.AsUnicodeString));
      else
        if MCPLogger.Enabled then
        begin
          WriteStr(S, F.DataType);
          MCPLogger.Log(mltWarning, 'Field type %s not supported in SQL: %s', [S, CapString(aQuery.SQL.Text)]);
        end;
      end;
  end;
end;

{ SQLQueryToJSON }

function SQLQueryToJSON(aQuery: TSQLQuery): TJSONArray;
var
  lRow: TJSONObject;
begin
  Result := TJSONArray.Create;
  try
    while not aQuery.EOF do
    begin
      lRow := TJSONObject.Create;
      try
        SQLRecordToJSON(lRow, aQuery);
      except
        lRow.Free;
        raise;
      end;
      Result.Add(lRow);
      aQuery.Next;
    end;
  except
    Result.Free;
    raise;
  end;
end;

{ SafeIdentifier }

function SafeIdentifier(aConnection: TSQLConnection; const aName: string): string;
var
  lOpen, lClose: string;
begin
  lOpen := aConnection.FieldNameQuoteChars[0];
  lClose := aConnection.FieldNameQuoteChars[1];
  Result := lOpen + StringReplace(aName, lClose, lClose + lClose, [rfReplaceAll]) + lClose;
end;

{ SafeStringLiteral }

function SafeStringLiteral(const aName: string): string;
begin
  Result := '''' + StringReplace(aName, '''', '''''', [rfReplaceAll]) + '''';
end;

{ Provider Registry and Cache }

type
  TProviderRegistration = record
    ConnectionClass: TSQLConnectionClass;
    ProviderClass: TDBMetadataProviderClass;
  end;

var
  ProviderRegistry: array of TProviderRegistration;
  ProviderCache: TThreadSafeObjectHash;

procedure RegisterMetadataProvider(aConnectionClass: TSQLConnectionClass; aProviderClass: TDBMetadataProviderClass);
var
  lLen: Integer;
begin
  lLen := Length(ProviderRegistry);
  SetLength(ProviderRegistry, lLen + 1);
  ProviderRegistry[lLen].ConnectionClass := aConnectionClass;
  ProviderRegistry[lLen].ProviderClass := aProviderClass;
end;

function GetMetadataProvider(aConnection: TSQLConnection): TDBMetadataProvider;
var
  i: Integer;
  lProviderClass: TDBMetadataProviderClass;
  lKey: string;
begin
  lProviderClass := nil;
  for i := 0 to Length(ProviderRegistry) - 1 do
    if aConnection.ClassType = ProviderRegistry[i].ConnectionClass then
    begin
      lProviderClass := ProviderRegistry[i].ProviderClass;
      Break;
    end;
  if lProviderClass = nil then
    raise EMCPException.CreateFmt('No metadata provider registered for connection type: %s', [aConnection.ClassName]);
  lKey := lProviderClass.ClassName;
  ProviderCache.Lock;
  try
    Result := TDBMetadataProvider(ProviderCache.Get(lKey));
    if Result = nil then
    begin
      Result := lProviderClass.Create;
      ProviderCache.Add(lKey, Result);
    end;
  finally
    ProviderCache.Unlock;
  end;
end;

initialization
  ProviderCache := TThreadSafeObjectHash.Create(True);

end.
