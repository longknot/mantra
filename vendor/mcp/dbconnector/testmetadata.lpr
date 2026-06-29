{
    Test tool for MCP database metadata providers.

    Usage:
      testmetadata -l                         List available tools
      testmetadata -d <section> -t <tool> [-n <name>]

    Options:
      -d  INI section name (database config)
      -t  Tool to invoke (list-indexes, list-views, etc.)
      -n  Table or view name (required by most tools)
      -l  List available tools and exit

    The database connection is read from databases.ini using the
    sqldbini unit. Each section must include a Type key matching
    a registered SQLDB connection type (SQLite3, Firebird, etc.).
}
program testmetadata;

{$mode ObjFPC}{$H+}

{$DEFINE USE_SQLITE}

// Uncomment to enable additional database engines:
{$DEFINE USE_FIREBIRD}
{$DEFINE USE_POSTGRESQL}
{$DEFINE USE_MYSQL8}
{$DEFINE USE_MYSQL57}
{$DEFINE USE_ORACLE}
{$DEFINE USE_ODBC}
{$DEFINE USE_MSSQL}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, inifiles, fpjson,
  sqldb, sqldbini,
  {$IFDEF USE_FIREBIRD}
  IBConnection,
  mcpmetadata.firebird,
  {$ENDIF}
  {$IFDEF USE_POSTGRESQL}
  PQConnection,
  mcpmetadata.postgresql,
  {$ENDIF}
  {$IFDEF USE_MYSQL8}
  mysql80conn,
  {$ENDIF}
  {$IFDEF USE_MYSQL57}
  mysql57conn,
  {$ENDIF}
  {$IF DEFINED(USE_MYSQL8) OR DEFINED(USE_MYSQL57)}
  mcpmetadata.mysql,
  {$ENDIF}
  {$IFDEF USE_ODBC}
  odbcconn,
  {$ENDIF}
  {$IFDEF USE_MSSQL}
  MSSQLConn,
  mcpmetadata.mssql,
  {$ENDIF}
  {$IFDEF USE_ORACLE}
  oracleconnection,
  mcpmetadata.oracle,
  {$ENDIF}
  {$IFDEF USE_SQLITE}
  SQLite3Conn,
  mcpmetadata.sqlite,
  {$ENDIF}
  mcpmetadata.base;

const
  IniFileName = 'databases.ini';
  SampleDataCount = 10;

  ToolNames: array[0..4] of string = (
    'list-indexes',
    'list-views',
    'view-details',
    'list-relationships',
    'get-sample-data'
  );

procedure ListTools;
var
  S: string;
begin
  WriteLn('Available tools:');
  for S in ToolNames do
    WriteLn('  ', S);
end;

procedure Usage(const aMsg: string);
begin
  if aMsg <> '' then
    WriteLn(StdErr, 'Error: ', aMsg);
  WriteLn(StdErr, 'Usage: ', ParamStr(0), ' -l');
  WriteLn(StdErr, '       ', ParamStr(0), ' -d <section> -t <tool> [-n <name>]');
  WriteLn(StdErr);
  WriteLn(StdErr, '  -d  INI section (database config from ', IniFileName, ')');
  WriteLn(StdErr, '  -t  Tool: list-indexes, list-views, view-details,');
  WriteLn(StdErr, '            list-relationships, get-sample-data');
  WriteLn(StdErr, '  -n  Table or view name');
  WriteLn(StdErr, '  -l  List available tools');
  Halt(Ord(aMsg <> ''));
end;

function CreateConnection(const aSection: string): TSQLConnection;
var
  lIni: TMemIniFile;
  lType: string;
  lDef: TConnectionDef;
begin
  if not FileExists(IniFileName) then
  begin
    WriteLn(StdErr, 'Error: ', IniFileName, ' not found');
    Halt(1);
  end;
  lIni := TMemIniFile.Create(IniFileName);
  try
    if not lIni.SectionExists(aSection) then
    begin
      WriteLn(StdErr, 'Error: Section [', aSection, '] not found in ', IniFileName);
      Halt(1);
    end;
    lType := lIni.ReadString(aSection, 'Type', '');
    if lType = '' then
    begin
      WriteLn(StdErr, 'Error: No Type key in section [', aSection, ']');
      Halt(1);
    end;
    lDef := GetConnectionDef(lType);
    if lDef = nil then
    begin
      WriteLn(StdErr, 'Error: Unknown connection type: ', lType);
      Halt(1);
    end;
    Result := lDef.ConnectionClass.Create(nil);
    Result.Transaction := TSQLTransaction.Create(Result);
    Result.LoadFromIni(lIni, aSection, [sioSkipMaskPassword]);
  finally
    lIni.Free;
  end;
end;

procedure RunTool(const aTool, aName: string; aConnection: TSQLConnection);
var
  lProvider: TDBMetadataProvider;
  lIndexes: TIndexInfoArray;
  lViews: TViewInfoArray;
  lDetails: TViewDetails;
  lRels: TRelationshipInfoArray;
  lData: TJSONArray;
  lArr: TJSONArray;
  lObj: TJSONObject;
  i: Integer;
begin
  aConnection.Connected := True;
  aConnection.Transaction.Active := True;
  lProvider := GetMetadataProvider(aConnection);

  if (aTool = 'list-indexes') then
  begin
    if aName = '' then
    begin
      WriteLn(StdErr, 'Error: -n <tableName> required for list-indexes');
      Halt(1);
    end;
    lIndexes := lProvider.GetIndexes(aConnection, aName);
    lArr := TJSONArray.Create;
    try
      for i := 0 to Length(lIndexes) - 1 do
        lArr.Add(lIndexes[i].ToJSON);
      WriteLn(lArr.FormatJSON);
    finally
      lArr.Free;
    end;
  end
  else if (aTool = 'list-views') then
  begin
    lViews := lProvider.GetViews(aConnection);
    lArr := TJSONArray.Create;
    try
      for i := 0 to Length(lViews) - 1 do
        lArr.Add(lViews[i].ToJSON);
      WriteLn(lArr.FormatJSON);
    finally
      lArr.Free;
    end;
  end
  else if (aTool = 'view-details') then
  begin
    if aName = '' then
    begin
      WriteLn(StdErr, 'Error: -n <viewName> required for view-details');
      Halt(1);
    end;
    lDetails := lProvider.GetViewDetails(aConnection, aName);
    lObj := lDetails.ToJSON;
    try
      WriteLn(lObj.FormatJSON);
    finally
      lObj.Free;
    end;
  end
  else if (aTool = 'list-relationships') then
  begin
    if aName = '' then
    begin
      WriteLn(StdErr, 'Error: -n <tableName> required for list-relationships');
      Halt(1);
    end;
    lRels := lProvider.GetRelationships(aConnection, aName);
    lArr := TJSONArray.Create;
    try
      for i := 0 to Length(lRels) - 1 do
        lArr.Add(lRels[i].ToJSON);
      WriteLn(lArr.FormatJSON);
    finally
      lArr.Free;
    end;
  end
  else if (aTool = 'get-sample-data') then
  begin
    if aName = '' then
    begin
      WriteLn(StdErr, 'Error: -n <tableName> required for get-sample-data');
      Halt(1);
    end;
    lData := lProvider.GetSampleData(aConnection, aName, SampleDataCount);
    try
      WriteLn(lData.FormatJSON);
    finally
      lData.Free;
    end;
  end
  else
  begin
    WriteLn(StdErr, 'Error: Unknown tool: ', aTool);
    WriteLn(StdErr);
    ListTools;
    Halt(1);
  end;
end;

var
  lSection, lTool, lName: string;
  lConnection: TSQLConnection;
  i: Integer;
  lHasD, lHasT, lHasL: Boolean;

begin
  lSection := '';
  lTool := '';
  lName := '';
  lHasD := False;
  lHasT := False;
  lHasL := False;

  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '-l' then
      lHasL := True
    else if ParamStr(i) = '-d' then
    begin
      lHasD := True;
      Inc(i);
      if i > ParamCount then
        Usage('Missing argument for -d');
      lSection := ParamStr(i);
    end
    else if ParamStr(i) = '-t' then
    begin
      lHasT := True;
      Inc(i);
      if i > ParamCount then
        Usage('Missing argument for -t');
      lTool := ParamStr(i);
    end
    else if ParamStr(i) = '-n' then
    begin
      Inc(i);
      if i > ParamCount then
        Usage('Missing argument for -n');
      lName := ParamStr(i);
    end
    else
      Usage('Unknown option: ' + ParamStr(i));
    Inc(i);
  end;

  if lHasL then
  begin
    ListTools;
    Halt(0);
  end;

  if not lHasD then
    Usage('Missing -d <section>');
  if not lHasT then
    Usage('Missing -t <tool>');

  lConnection := CreateConnection(lSection);
  try
    try
      RunTool(lTool, lName, lConnection);
    except
      on E: Exception do
      begin
        WriteLn(StdErr, E.ClassName, ': ', E.Message);
        Halt(1);
      end;
    end;
  finally
    lConnection.Free;
  end;
end.
