{
    This file is part of the Free Component Library

    Firebird metadata provider
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadata.firebird;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, db, sqldb, fpjson, mcp.types,
  IBConnection, mcpmetadata.base;

type

  { TFirebirdMetadataProvider }

  TFirebirdMetadataProvider = class(TDBMetadataProvider)
  public
    function GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray; override;
    function GetViews(aConnection: TSQLConnection): TViewInfoArray; override;
    function GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails; override;
    function GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray; override;
    function GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray; override;
  end;

implementation

{ TFirebirdMetadataProvider }

function TFirebirdMetadataProvider.GetIndexes(aConnection: TSQLConnection; const aTableName: string): TIndexInfoArray;
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
      'SELECT TRIM(ix.RDB$INDEX_NAME) AS index_name, ' +
      'TRIM(sg.RDB$FIELD_NAME) AS field_name, ' +
      'ix.RDB$UNIQUE_FLAG AS is_unique ' +
      'FROM RDB$INDICES ix ' +
      'JOIN RDB$INDEX_SEGMENTS sg ON ix.RDB$INDEX_NAME = sg.RDB$INDEX_NAME ' +
      'WHERE ix.RDB$RELATION_NAME = :tableName ' +
      'AND (ix.RDB$SYSTEM_FLAG IS NULL OR ix.RDB$SYSTEM_FLAG = 0) ' +
      'ORDER BY ix.RDB$INDEX_NAME, sg.RDB$FIELD_POSITION';
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
        Result[lIdx].Unique := lQry.FieldByName('is_unique').AsInteger <> 0;
        Result[lIdx].Fields := nil;
        lCurrentName := lIdxName;
        Inc(lLen);
      end;
      SetLength(Result[lIdx].Fields, Length(Result[lIdx].Fields) + 1);
      Result[lIdx].Fields[High(Result[lIdx].Fields)] := lQry.FieldByName('field_name').AsString;
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TFirebirdMetadataProvider.GetViews(aConnection: TSQLConnection): TViewInfoArray;
var
  lQry: TSQLQuery;
  lLen: Integer;
begin
  Result := nil;
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text :=
      'SELECT TRIM(RDB$RELATION_NAME) AS view_name FROM RDB$RELATIONS ' +
      'WHERE RDB$VIEW_SOURCE IS NOT NULL ' +
      'AND (RDB$SYSTEM_FLAG IS NULL OR RDB$SYSTEM_FLAG = 0)';
    lQry.Open;
    lLen := 0;
    while not lQry.EOF do
    begin
      SetLength(Result, lLen + 1);
      Result[lLen].Name := Trim(lQry.FieldByName('view_name').AsString);
      Inc(lLen);
      lQry.Next;
    end;
  finally
    lQry.Free;
  end;
end;

function TFirebirdMetadataProvider.GetViewDetails(aConnection: TSQLConnection; const aViewName: string): TViewDetails;
var
  lQry: TSQLQuery;
  lCount: Integer;
begin
  lQry := CreateQuery(aConnection);
  try
    // Step 1: Get view source
    lQry.SQL.Text := 'SELECT RDB$VIEW_SOURCE FROM RDB$RELATIONS WHERE RDB$RELATION_NAME = :viewName';
    lQry.Params.ParamByName('viewName').AsString := UpperCase(aViewName);
    lQry.Open;
    if lQry.EOF then
      raise EMCPException.CreateFmt('View not found: %s', [aViewName]);
    Result.SQL := Trim(lQry.FieldByName('RDB$VIEW_SOURCE').AsString);
    lQry.Close;

    // Step 2: Check for BEFORE triggers (updatability)
    lQry.SQL.Text :=
      'SELECT COUNT(*) FROM RDB$TRIGGERS ' +
      'WHERE RDB$RELATION_NAME = :viewName ' +
      'AND BIN_AND(RDB$TRIGGER_TYPE, 1) = 1';
    lQry.Params.ParamByName('viewName').AsString := UpperCase(aViewName);
    lQry.Open;
    lCount := lQry.Fields[0].AsInteger;
    Result.Updateable := (lCount > 0);
  finally
    lQry.Free;
  end;
end;

function TFirebirdMetadataProvider.GetRelationships(aConnection: TSQLConnection; const aTableName: string): TRelationshipInfoArray;
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
      'TRIM(rc.RDB$CONSTRAINT_NAME) AS foreign_key_name, ' +
      'TRIM(seg1.RDB$FIELD_NAME) AS column_name, ' +
      'TRIM(rc2.RDB$RELATION_NAME) AS referenced_table_name, ' +
      'TRIM(seg2.RDB$FIELD_NAME) AS referenced_column_name ' +
      'FROM RDB$RELATION_CONSTRAINTS rc ' +
      'JOIN RDB$REF_CONSTRAINTS refc ON rc.RDB$CONSTRAINT_NAME = refc.RDB$CONSTRAINT_NAME ' +
      'JOIN RDB$INDEX_SEGMENTS seg1 ON rc.RDB$INDEX_NAME = seg1.RDB$INDEX_NAME ' +
      'JOIN RDB$RELATION_CONSTRAINTS rc2 ON refc.RDB$CONST_NAME_UQ = rc2.RDB$CONSTRAINT_NAME ' +
      'JOIN RDB$INDEX_SEGMENTS seg2 ON rc2.RDB$INDEX_NAME = seg2.RDB$INDEX_NAME ' +
      'AND seg1.RDB$FIELD_POSITION = seg2.RDB$FIELD_POSITION ' +
      'WHERE rc.RDB$CONSTRAINT_TYPE = ''FOREIGN KEY'' ' +
      'AND rc.RDB$RELATION_NAME = :tableName ' +
      'ORDER BY rc.RDB$CONSTRAINT_NAME, seg1.RDB$FIELD_POSITION';
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

function TFirebirdMetadataProvider.GetSampleData(aConnection: TSQLConnection; const aTableName: string; aRowCount: Integer): TJSONArray;
var
  lQry: TSQLQuery;
begin
  lQry := CreateQuery(aConnection);
  try
    lQry.SQL.Text := 'SELECT * FROM ' + SafeIdentifier(aConnection, aTableName) + ' ROWS ' + IntToStr(aRowCount);
    lQry.Open;
    Result := SQLQueryToJSON(lQry);
  finally
    lQry.Free;
  end;
end;

initialization
  RegisterMetadataProvider(TIBConnection, TFirebirdMetadataProvider);

end.
