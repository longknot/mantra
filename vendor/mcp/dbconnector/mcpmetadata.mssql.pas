{
    This file is part of the Free Component Library

    MS SQL Server metadata provider
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.mssql;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, db, sqldb, fpjson, mcp.types,
  MSSQLConn, mcpmetadata.base;

type

  { TMSSQLMetadataProvider }

  TMSSQLMetadataProvider = class(TDBMetadataProvider)
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; override;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; override;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; override;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; override;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; override;
  end;

implementation

{ TMSSQLMetadataProvider }

function TMSSQLMetadataProvider.GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
  lCurrentName, lIdxName: string;
  lIdx: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text :=
      'SELECT ' +
      'i.name AS index_name, ' +
      'c.name AS column_name, ' +
      'i.is_unique ' +
      'FROM sys.indexes i ' +
      'JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id ' +
      'JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id ' +
      'JOIN sys.tables t ON i.object_id = t.object_id ' +
      'JOIN sys.schemas s ON t.schema_id = s.schema_id ' +
      'WHERE t.name = :tableName ' +
      'AND s.name = SCHEMA_NAME() ' +
      'AND i.name IS NOT NULL ' +
      'ORDER BY i.name, ic.key_ordinal';
    lQry.Params.ParamByName('tableName').AsString := aTableName;
    lQry.Open;
    lLen := 0;
    lCurrentName := '';
    lIdx := -1;
    while not lQry.EOF do
    begin
      lIdxName := lQry.FieldByName('index_name').AsString;
      if lIdxName <> lCurrentName then
      begin
        SetLength(Result, lLen + 1);
        lIdx := lLen;
        Result[lIdx].Name := lIdxName;
        Result[lIdx].Unique := lQry.FieldByName('is_unique').AsBoolean;
        Result[lIdx].Fields := nil;
        lCurrentName := lIdxName;
        Inc(lLen);
      end;
      SetLength(Result[lIdx].Fields, Length(Result[lIdx].Fields) + 1);
      Result[lIdx].Fields[High(Result[lIdx].Fields)] := lQry.FieldByName('column_name').AsString;
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TMSSQLMetadataProvider.GetViews(aConnection: TSQLConnection): TViewInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text :=
      'SELECT v.name FROM sys.views v ' +
      'JOIN sys.schemas s ON v.schema_id = s.schema_id ' +
      'WHERE s.name = SCHEMA_NAME()';
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

function TMSSQLMetadataProvider.GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails;
var
  lQry: TSQLQuery;
  lField: TField;
begin
  lQry := CreateQuery(aConnection);
  try
    // Step 1: Get view definition
    lQry.SQL.Text := 'SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(:viewName)';
    lQry.Params.ParamByName('viewName').AsString := aViewName;
    lQry.Open;
    if lQry.EOF then
      raise EMCPException.CreateFmt('View not found: %s', [aViewName]);
    Result.SQL := lQry.FieldByName('definition').AsString;
    lQry.Close;

    // Step 2: Get updatability
    lQry.SQL.Text := 'SELECT OBJECTPROPERTY(OBJECT_ID(:viewName), ''IsUpdatable'') AS is_updatable';
    lQry.Params.ParamByName('viewName').AsString := aViewName;
    lQry.Open;
    lField := lQry.FieldByName('is_updatable');
    if lField.IsNull then
      Result.Updateable := False
    else
      Result.Updateable := (lField.AsInteger = 1);
  finally
    lQry.Free;
  end;
end;

function TMSSQLMetadataProvider.GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray;
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
      'SELECT ' +
      'fk.name AS foreign_key_name, ' +
      'c1.name AS column_name, ' +
      't2.name AS referenced_table_name, ' +
      'c2.name AS referenced_column_name ' +
      'FROM sys.foreign_keys fk ' +
      'JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id ' +
      'JOIN sys.tables t1 ON fkc.parent_object_id = t1.object_id ' +
      'JOIN sys.schemas s ON t1.schema_id = s.schema_id ' +
      'JOIN sys.columns c1 ON fkc.parent_object_id = c1.object_id AND fkc.parent_column_id = c1.column_id ' +
      'JOIN sys.tables t2 ON fkc.referenced_object_id = t2.object_id ' +
      'JOIN sys.columns c2 ON fkc.referenced_object_id = c2.object_id AND fkc.referenced_column_id = c2.column_id ' +
      'WHERE t1.name = :tableName ' +
      'AND s.name = SCHEMA_NAME() ' +
      'ORDER BY fk.name, fkc.constraint_column_id';
    lQry.Params.ParamByName('tableName').AsString := aTableName;
    lQry.Open;
    lLen := 0;
    lCurrentName := '';
    lIdx := -1;
    while not lQry.EOF do
    begin
      lFKName := lQry.FieldByName('foreign_key_name').AsString;
      if lFKName <> lCurrentName then
      begin
        SetLength(Result, lLen + 1);
        lIdx := lLen;
        Result[lIdx].Name := lFKName;
        Result[lIdx].ReferencedTable := lQry.FieldByName('referenced_table_name').AsString;
        Result[lIdx].ColumnNames := nil;
        Result[lIdx].ReferencedColumnNames := nil;
        lCurrentName := lFKName;
        Inc(lLen);
      end;
      SetLength(Result[lIdx].ColumnNames, Length(Result[lIdx].ColumnNames) + 1);
      Result[lIdx].ColumnNames[High(Result[lIdx].ColumnNames)] := lQry.FieldByName('column_name').AsString;
      SetLength(Result[lIdx].ReferencedColumnNames, Length(Result[lIdx].ReferencedColumnNames) + 1);
      Result[lIdx].ReferencedColumnNames[High(Result[lIdx].ReferencedColumnNames)] := lQry.FieldByName('referenced_column_name').AsString;
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TMSSQLMetadataProvider.GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray;
var
  lQry: TSQLQuery;
begin
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT TOP ' + IntToStr(aRowCount) + ' * FROM ' + SafeIdentifier(aConnection, aTableName);
    lQry.Open;
    Result := SQLQueryToJSON(lQry);
  finally
    lQry.Free;
  end;
end;

initialization
  RegisterMetadataProvider(TMSSQLConnection, TMSSQLMetadataProvider);

end.
