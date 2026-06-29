{
    This file is part of the Free Component Library

    Oracle metadata provider
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.oracle;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, db, sqldb, fpjson, mcp.types,
  oracleconnection, mcpmetadata.base;

type

  { TOracleMetadataProvider }

  TOracleMetadataProvider = class(TDBMetadataProvider)
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; override;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; override;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; override;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; override;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; override;
  end;

implementation

{ TOracleMetadataProvider }

function TOracleMetadataProvider.GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray;
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
      'SELECT aic.index_name, aic.column_name, ai.uniqueness ' +
      'FROM all_ind_columns aic ' +
      'JOIN all_indexes ai ON ai.index_name = aic.index_name ' +
      'AND ai.table_name = aic.table_name AND ai.owner = aic.table_owner ' +
      'WHERE aic.table_owner = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'') ' +
      'AND aic.table_name = :tableName ' +
      'ORDER BY aic.index_name, aic.column_position';
    lQry.Params.ParamByName('tableName').AsString := UpperCase(aTableName);
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
        Result[lIdx].Unique := (lQry.FieldByName('uniqueness').AsString = 'UNIQUE');
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

function TOracleMetadataProvider.GetViews(aConnection: TSQLConnection): TViewInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT view_name FROM all_views WHERE owner = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'')';
    lQry.Open;
    lLen := 0;
    while not lQry.EOF do
    begin
      SetLength(Result, lLen + 1);
      Result[lLen].Name := lQry.FieldByName('view_name').AsString;
      Inc(lLen);
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TOracleMetadataProvider.GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails;
var
  lQry: TSQLQuery;
  lField: TField;
  lHasReadOnly: Boolean;
begin
  lQry := CreateQuery(aConnection);
  try
    lHasReadOnly := True;
    // Try with READ_ONLY column (Oracle 21c+)
    lQry.SQL.Text :=
      'SELECT TEXT, READ_ONLY FROM ALL_VIEWS ' +
      'WHERE VIEW_NAME = :viewName AND OWNER = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'')';
    lQry.Params.ParamByName('viewName').AsString := UpperCase(aViewName);
    try
      lQry.Open;
    except
      on E: EOraDatabaseError do
      begin
        if E.ErrorCode = 904 then // invalid identifier — READ_ONLY not available
        begin
          lHasReadOnly := False;
          lQry.SQL.Text :=
            'SELECT TEXT FROM ALL_VIEWS ' +
            'WHERE VIEW_NAME = :viewName AND OWNER = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'')';
          lQry.Params.ParamByName('viewName').AsString := UpperCase(aViewName);
          lQry.Open;
        end
        else
          raise;
      end;
    end;
    if lQry.EOF then
      raise EMCPException.CreateFmt('View not found: %s', [aViewName]);
    // Handle LONG data type: SQLDB maps it to ftMemo, read with AsString
    lField := lQry.FieldByName('TEXT');
    Result.SQL := lField.AsString;
    if lHasReadOnly then
      Result.Updateable := (lQry.FieldByName('READ_ONLY').AsString = 'N')
    else
      Result.Updateable := True;
  finally
    lQry.Free;
  end;
end;

function TOracleMetadataProvider.GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray;
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
      'a.constraint_name AS foreign_key_name, ' +
      'a.column_name AS column_name, ' +
      'c_pk.table_name AS referenced_table_name, ' +
      'b.column_name AS referenced_column_name ' +
      'FROM all_cons_columns a ' +
      'JOIN all_constraints c ON a.owner = c.owner AND a.constraint_name = c.constraint_name ' +
      'JOIN all_constraints c_pk ON c.r_owner = c_pk.owner AND c.r_constraint_name = c_pk.constraint_name ' +
      'JOIN all_cons_columns b ON c_pk.owner = b.owner AND c_pk.constraint_name = b.constraint_name AND a.position = b.position ' +
      'WHERE c.constraint_type = ''R'' ' +
      'AND a.owner = SYS_CONTEXT(''USERENV'', ''CURRENT_SCHEMA'') ' +
      'AND a.table_name = :tableName ' +
      'ORDER BY a.constraint_name, a.position';
    lQry.Params.ParamByName('tableName').AsString := UpperCase(aTableName);
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

function TOracleMetadataProvider.GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray;
var
  lQry: TSQLQuery;
  lSafeTable: string;
begin
  lSafeTable := SafeIdentifier(aConnection, aTableName);
  lQry := CreateQuery(aConnection);
  try
    // Try Oracle 12c+ syntax first
    lQry.SQL.Text := 'SELECT * FROM ' + lSafeTable + ' FETCH NEXT ' + IntToStr(aRowCount) + ' ROWS ONLY';
    try
      lQry.Open;
    except
      on E: EOraDatabaseError do
      begin
        if (E.ErrorCode = 933) or (E.ErrorCode = 905) then // pre-12c
        begin
          lQry.SQL.Text := 'SELECT * FROM (SELECT * FROM ' + lSafeTable + ') WHERE ROWNUM <= ' + IntToStr(aRowCount);
          lQry.Open;
        end
        else
          raise;
      end;
    end;
    Result := SQLQueryToJSON(lQry);
  finally
    lQry.Free;
  end;
end;

initialization
  RegisterMetadataProvider(TOracleConnection, TOracleMetadataProvider);

end.
