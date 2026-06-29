{
    This file is part of the Free Component Library

    PostgreSQL metadata provider
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.postgresql;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, db, sqldb, fpjson, mcp.types,
  PQConnection, mcpmetadata.base;

type

  { TPostgreSQLMetadataProvider }

  TPostgreSQLMetadataProvider = class(TDBMetadataProvider)
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; override;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; override;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; override;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; override;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; override;
  end;

implementation

{ TPostgreSQLMetadataProvider }

function TPostgreSQLMetadataProvider.GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray;
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
      'ic.relname AS index_name, ' +
      'a.attname AS column_name, ' +
      'ix.indisunique AS is_unique ' +
      'FROM pg_index ix ' +
      'JOIN pg_class t ON t.oid = ix.indrelid ' +
      'JOIN pg_class ic ON ic.oid = ix.indexrelid ' +
      'JOIN pg_namespace n ON n.oid = t.relnamespace ' +
      'JOIN LATERAL unnest(ix.indkey) WITH ORDINALITY AS k(attnum, ord) ON TRUE ' +
      'JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum ' +
      'WHERE t.relname = :tableName ' +
      'AND n.nspname = current_schema() ' +
      'AND k.attnum > 0 ' +
      'ORDER BY ic.relname, k.ord';
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

function TPostgreSQLMetadataProvider.GetViews(aConnection: TSQLConnection): TViewInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT table_name FROM information_schema.views WHERE table_schema = current_schema()';
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

function TPostgreSQLMetadataProvider.GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails;
var
  lQry: TSQLQuery;
begin
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text :=
      'SELECT view_definition, is_updatable FROM information_schema.views ' +
      'WHERE table_name = :viewName AND table_schema = current_schema()';
    lQry.Params.ParamByName('viewName').AsString := aViewName;
    lQry.Open;
    if lQry.EOF then
      raise EMCPException.CreateFmt('View not found: %s', [aViewName]);
    Result.SQL := lQry.FieldByName('view_definition').AsString;
    Result.Updateable := (lQry.FieldByName('is_updatable').AsString = 'YES');
  finally
    lQry.Free;
  end;
end;

function TPostgreSQLMetadataProvider.GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray;
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
      'c.conname AS foreign_key_name, ' +
      'a1.attname AS column_name, ' +
      't2.relname AS referenced_table_name, ' +
      'a2.attname AS referenced_column_name ' +
      'FROM pg_constraint c ' +
      'JOIN pg_class t1 ON t1.oid = c.conrelid ' +
      'JOIN pg_namespace n1 ON n1.oid = t1.relnamespace ' +
      'JOIN pg_class t2 ON t2.oid = c.confrelid ' +
      'JOIN LATERAL unnest(c.conkey, c.confkey) WITH ORDINALITY AS k(col_attnum, ref_attnum, ord) ON TRUE ' +
      'JOIN pg_attribute a1 ON a1.attrelid = t1.oid AND a1.attnum = k.col_attnum ' +
      'JOIN pg_attribute a2 ON a2.attrelid = t2.oid AND a2.attnum = k.ref_attnum ' +
      'WHERE c.contype = ''f'' ' +
      'AND t1.relname = :tableName ' +
      'AND n1.nspname = current_schema() ' +
      'ORDER BY c.conname, k.ord';
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

function TPostgreSQLMetadataProvider.GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray;
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
  RegisterMetadataProvider(TPQConnection, TPostgreSQLMetadataProvider);

end.
