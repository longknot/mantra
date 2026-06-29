{
    This file is part of the Free Component Library

    MCP metadata tools
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpmetadatatools;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpjson, sqldb, mcp.types, mcpsqldbtools, mcpmetadata.base;

type

  { TListIndexesTool }

  TListIndexesTool = class(TSQLDBTool)
    constructor create(const aName: string; const aDescription: string); override;
    procedure ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject); override;
  end;

  { TListViewsTool }

  TListViewsTool = class(TSQLDBTool)
    procedure ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject); override;
  end;

  { TViewDetailsTool }

  TViewDetailsTool = class(TSQLDBTool)
    constructor create(const aName: string; const aDescription: string); override;
    procedure ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject); override;
  end;

  { TListRelationshipsTool }

  TListRelationshipsTool = class(TSQLDBTool)
    constructor create(const aName: string; const aDescription: string); override;
    procedure ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject); override;
  end;

  { TGetSampleDataTool }

  TGetSampleDataTool = class(TSQLDBTool)
    constructor create(const aName: string; const aDescription: string); override;
    procedure ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject); override;
  end;

implementation

{ TListIndexesTool }

constructor TListIndexesTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('tableName', TJSONObject.Create(['type', 'string']), True);
end;

procedure TListIndexesTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lProvider: TDBMetadataProvider;
  lIndexes: TIndexInfoArray;
  lArray: TJSONArray;
  lTableName: string;
  i: Integer;
begin
  lTableName := aInput.Get('tableName', '');
  if lTableName = '' then
    raise EMCPException.Create('Missing table name argument');
  lProvider := GetMetadataProvider(aConnection);
  lIndexes := lProvider.GetIndexes(aConnection, lTableName);
  lArray := TJSONArray.Create;
  try
    for i := 0 to Length(lIndexes) - 1 do
      lArray.Add(lIndexes[i].ToJSON);
    aResult.Add('indexes', lArray);
  except
    lArray.Free;
    raise;
  end;
end;

{ TListViewsTool }

procedure TListViewsTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lProvider: TDBMetadataProvider;
  lViews: TViewInfoArray;
  lArray: TJSONArray;
  i: Integer;
begin
  lProvider := GetMetadataProvider(aConnection);
  lViews := lProvider.GetViews(aConnection);
  lArray := TJSONArray.Create;
  try
    for i := 0 to Length(lViews) - 1 do
      lArray.Add(lViews[i].ToJSON);
    aResult.Add('views', lArray);
  except
    lArray.Free;
    raise;
  end;
end;

{ TViewDetailsTool }

constructor TViewDetailsTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('viewName', TJSONObject.Create(['type', 'string']), True);
end;

procedure TViewDetailsTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lProvider: TDBMetadataProvider;
  lDetails: TViewDetails;
  lViewName: string;
begin
  lViewName := aInput.Get('viewName', '');
  if lViewName = '' then
    raise EMCPException.Create('Missing view name argument');
  lProvider := GetMetadataProvider(aConnection);
  lDetails := lProvider.GetViewDetails(aConnection, lViewName);
  aResult.Add('sql', lDetails.SQL);
  aResult.Add('updateable', lDetails.Updateable);
end;

{ TListRelationshipsTool }

constructor TListRelationshipsTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('tableName', TJSONObject.Create(['type', 'string']), True);
end;

procedure TListRelationshipsTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lProvider: TDBMetadataProvider;
  lRels: TRelationshipInfoArray;
  lArray: TJSONArray;
  lTableName: string;
  i: Integer;
begin
  lTableName := aInput.Get('tableName', '');
  if lTableName = '' then
    raise EMCPException.Create('Missing table name argument');
  lProvider := GetMetadataProvider(aConnection);
  lRels := lProvider.GetRelationships(aConnection, lTableName);
  lArray := TJSONArray.Create;
  try
    for i := 0 to Length(lRels) - 1 do
      lArray.Add(lRels[i].ToJSON);
    aResult.Add('relationships', lArray);
  except
    lArray.Free;
    raise;
  end;
end;

{ TGetSampleDataTool }

constructor TGetSampleDataTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('tableName', TJSONObject.Create(['type', 'string']), True);
  InputSchema.AddArgument('rowCount', TJSONObject.Create(['type', 'integer']), True);
end;

procedure TGetSampleDataTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lProvider: TDBMetadataProvider;
  lRowCount64: Int64;
  lRowCount: Integer;
  lTableName: string;
  lData: TJSONArray;
begin
  lTableName := aInput.Get('tableName', '');
  if lTableName = '' then
    raise EMCPException.Create('Missing table name argument');
  lRowCount64 := aInput.Get('rowCount', Int64(0));
  if lRowCount64 < 1 then
    lRowCount64 := 1;
  if lRowCount64 > 10 then
    lRowCount64 := 10;
  lRowCount := Integer(lRowCount64);
  lProvider := GetMetadataProvider(aConnection);
  lData := lProvider.GetSampleData(aConnection, lTableName, lRowCount);
  try
    aResult.Add('rows', lData);
  except
    lData.Free;
    raise;
  end;
end;

end.
