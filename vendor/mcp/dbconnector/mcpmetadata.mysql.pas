{
    This file is part of the Free Component Library

    MySQL metadata provider
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.mysql;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, db, sqldb, fpjson, mcp.types,
  mysql80conn, mysql57conn, mcpmetadata.base;

type

  { TMySQLMetadataProvider }

  TMySQLMetadataProvider = class(TDBMetadataProvider)
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; override;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; override;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; override;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; override;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; override;
  end;

implementation

{ TMySQLMetadataProvider }

function TMySQLMetadataProvider.GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
  lCurrentName, lKeyName: string;
  lIdx: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SHOW INDEX FROM ' + SafeIdentifier(aConnection, aTableName);
    lQry.Open;
    lLen := 0;
    lCurrentName := '';
    lIdx := -1;
    while not lQry.EOF do
    begin
      lKeyName := lQry.FieldByName('Key_name').AsString;
      if lKeyName <> lCurrentName then
      begin
        SetLength(Result, lLen + 1);
        lIdx := lLen;
        Result[lIdx].Name := lKeyName;
        Result[lIdx].Unique := (lQry.FieldByName('Non_unique').AsInteger = 0);
        Result[lIdx].Fields := nil;
        lCurrentName := lKeyName;
        Inc(lLen);
      end;
      SetLength(Result[lIdx].Fields, Length(Result[lIdx].Fields) + 1);
      Result[lIdx].Fields[High(Result[lIdx].Fields)] := lQry.FieldByName('Column_name').AsString;
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TMySQLMetadataProvider.GetViews(aConnection: TSQLConnection): TViewInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT table_name FROM information_schema.views WHERE TABLE_SCHEMA = DATABASE()';
    lQry.Open;
    lLen := 0;
    while not lQry.EOF do
    begin
      SetLength(Result, lLen + 1);
      Result[lLen].Name := lQry.FieldByName('table_name').AsString;
      Inc(lLen);
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TMySQLMetadataProvider.GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails;
var
  lQry: TSQLQuery;
begin
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text :=
      'SELECT VIEW_DEFINITION, IS_UPDATABLE FROM information_schema.VIEWS ' +
      'WHERE TABLE_NAME = :viewName AND TABLE_SCHEMA = DATABASE()';
    lQry.Params.ParamByName('viewName').AsString := aViewName;
    lQry.Open;
    if lQry.EOF then
      raise EMCPException.CreateFmt('View not found: %s', [aViewName]);
    Result.SQL := lQry.FieldByName('VIEW_DEFINITION').AsString;
    Result.Updateable := (lQry.FieldByName('IS_UPDATABLE').AsString = 'YES');
  finally
    lQry.Free;
  end;
end;

function TMySQLMetadataProvider.GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
  lCurrentName, lFKName: string;
  lIdx: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text :=
      'SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME ' +
      'FROM information_schema.KEY_COLUMN_USAGE ' +
      'WHERE REFERENCED_TABLE_SCHEMA IS NOT NULL ' +
      'AND TABLE_NAME = :tableName ' +
      'AND TABLE_SCHEMA = DATABASE() ' +
      'ORDER BY CONSTRAINT_NAME, ORDINAL_POSITION';
    lQry.Params.ParamByName('tableName').AsString := aTableName;
    lQry.Open;
    lLen := 0;
    lCurrentName := '';
    lIdx := -1;
    while not lQry.EOF do
    begin
      lFKName := lQry.FieldByName('CONSTRAINT_NAME').AsString;
      if lFKName <> lCurrentName then
      begin
        SetLength(Result, lLen + 1);
        lIdx := lLen;
        Result[lIdx].Name := lFKName;
        Result[lIdx].ReferencedTable := lQry.FieldByName('REFERENCED_TABLE_NAME').AsString;
        Result[lIdx].ColumnNames := nil;
        Result[lIdx].ReferencedColumnNames := nil;
        lCurrentName := lFKName;
        Inc(lLen);
      end;
      SetLength(Result[lIdx].ColumnNames, Length(Result[lIdx].ColumnNames) + 1);
      Result[lIdx].ColumnNames[High(Result[lIdx].ColumnNames)] := lQry.FieldByName('COLUMN_NAME').AsString;
      SetLength(Result[lIdx].ReferencedColumnNames, Length(Result[lIdx].ReferencedColumnNames) + 1);
      Result[lIdx].ReferencedColumnNames[High(Result[lIdx].ReferencedColumnNames)] := lQry.FieldByName('REFERENCED_COLUMN_NAME').AsString;
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TMySQLMetadataProvider.GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray;
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
  RegisterMetadataProvider(TMySQL80Connection, TMySQLMetadataProvider);
  RegisterMetadataProvider(TMySQL57Connection, TMySQLMetadataProvider);

end.
