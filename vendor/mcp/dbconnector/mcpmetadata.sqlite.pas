{
    This file is part of the Free Component Library

    SQLite metadata provider
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.sqlite;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, db, sqldb, fpjson, mcp.types,
  SQLite3Conn, mcpmetadata.base;

type

  { TSQLiteMetadataProvider }

  TSQLiteMetadataProvider = class(TDBMetadataProvider)
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; override;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; override;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; override;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; override;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; override;
  end;

implementation

{ TSQLiteMetadataProvider }

function TSQLiteMetadataProvider.GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray;
type
  TIndexEntry = record
    Name: string;
    Unique: Boolean;
  end;
var
  lQry: TSQLQuery;
  lEntries: array of TIndexEntry;
  lLen, lFieldCount, i: Integer;
  lInfo: TIndexInfo;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    // Step 1: Get index names and uniqueness
    lQry.SQL.Text := 'PRAGMA index_list(' + SafeStringLiteral(aTableName) + ')';
    lQry.Open;
    lEntries := nil;
    lLen := 0;
    while not lQry.EOF do
    begin
      SetLength(lEntries, lLen + 1);
      lEntries[lLen].Name := lQry.FieldByName('name').AsString;
      lEntries[lLen].Unique := lQry.FieldByName('unique').AsInteger <> 0;
      Inc(lLen);
      lQry.Next;
    end;
    lQry.Close;

    // Step 2: For each index, get column names
    SetLength(Result, lLen);
    for i := 0 to lLen - 1 do
    begin
      lInfo.Name := lEntries[i].Name;
      lInfo.Unique := lEntries[i].Unique;
      lInfo.Fields := nil;
      lQry.SQL.Text := 'PRAGMA index_info(' + SafeStringLiteral(lEntries[i].Name) + ')';
      lQry.Open;
      lFieldCount := 0;
      while not lQry.EOF do
      begin
        SetLength(lInfo.Fields, lFieldCount + 1);
        lInfo.Fields[lFieldCount] := lQry.FieldByName('name').AsString;
        Inc(lFieldCount);
        lQry.Next;
      end;
      lQry.Close;
      Result[i] := lInfo;
    end;
  finally
    lQry.Free;
  end;
end;

function TSQLiteMetadataProvider.GetViews(aConnection: TSQLConnection): TViewInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''view'' AND name NOT LIKE ''sqlite_%''';
    lQry.Open;
    lLen := 0;
    while not lQry.EOF do
    begin
      SetLength(Result, lLen + 1);
      Result[lLen].Name := lQry.FieldByName('name').AsString;
      Inc(lLen);
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TSQLiteMetadataProvider.GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails;
var
  lQry: TSQLQuery;
begin
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT sql FROM sqlite_master WHERE type = ''view'' AND name = :viewName';
    lQry.Params.ParamByName('viewName').AsString := aViewName;
    lQry.Open;
    if lQry.EOF then
      raise EMCPException.CreateFmt('View not found: %s', [aViewName]);
    Result.SQL := lQry.FieldByName('sql').AsString;
    Result.Updateable := False;
  finally
    lQry.Free;
  end;
end;

function TSQLiteMetadataProvider.GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray;
var
  lQry: TSQLQuery;
  lLen, lCurrentId, lRowId, lIdx: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'PRAGMA foreign_key_list(' + SafeStringLiteral(aTableName) + ')';
    lQry.Open;
    lLen := 0;
    while not lQry.EOF do
    begin
      lRowId := lQry.FieldByName('id').AsInteger;
      // Find existing entry for this FK id, or create new
      lIdx := -1;
      for lCurrentId := 0 to lLen - 1 do
        if Result[lCurrentId].Name = 'fk_' + IntToStr(lRowId) then
        begin
          lIdx := lCurrentId;
          Break;
        end;
      if lIdx = -1 then
      begin
        SetLength(Result, lLen + 1);
        lIdx := lLen;
        Result[lIdx].Name := 'fk_' + IntToStr(lRowId);
        Result[lIdx].ReferencedTable := lQry.FieldByName('table').AsString;
        Result[lIdx].ColumnNames := nil;
        Result[lIdx].ReferencedColumnNames := nil;
        Inc(lLen);
      end;
      SetLength(Result[lIdx].ColumnNames, Length(Result[lIdx].ColumnNames) + 1);
      Result[lIdx].ColumnNames[High(Result[lIdx].ColumnNames)] := lQry.FieldByName('from').AsString;
      SetLength(Result[lIdx].ReferencedColumnNames, Length(Result[lIdx].ReferencedColumnNames) + 1);
      Result[lIdx].ReferencedColumnNames[High(Result[lIdx].ReferencedColumnNames)] := lQry.FieldByName('to').AsString;
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TSQLiteMetadataProvider.GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray;
var
  lQry: TSQLQuery;
begin
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT * FROM ' + SafeIdentifier(aConnection, aTableName) + ' LIMIT ' + IntToStr(aRowCount);
    lQry.Open;
    Result := SQLQueryToJSON(lQry);
  finally
    lQry.Free;
  end;
end;

initialization
  RegisterMetadataProvider(TSQLite3Connection, TSQLiteMetadataProvider);

end.
