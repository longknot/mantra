{
    This file is part of the Free Component Library

    Database handling MCP Server
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

program mcpdbconnector;

{ $define usesocket}
{ $define usehttp}

{$IFDEF USESOCKET}
{$DEFINE HAVEPORT}
{$IFDEF USEHTTP}
{$Error 'Cannot use HTTP and socket transport at the same time'}
{$ENDIF}
{$ENDIF}

{$IFDEF USEHTTP}
{$DEFINE HAVEPORT}
{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  jsonparser,
  fpjson,
  sysutils,
  classes,
  inifiles,
  strutils,
  dateutils,
  sqldb,
  {$ifdef usesocket}
  mcp.application.socket,
  {$else}
  {$ifdef usehttp}
  mcp.application.http,
  {$ELSE}
  mcp.application.stdio,
  {$endif}
  {$ENDIF}
  mcp.types,
  mcp.logging,
  mcp.tools,
  mcp.resources,
  mcp.prompts, mcpsqldbtools, mcpmetadatatools, mcpsqldbsupport;

const
  sDatabase = 'Database';
  KeyHost = 'host';
  KeyDatabase = 'database';
  KeyUser = 'user';
  keyPort = 'port';
  keyPassword = 'password';
  keyOption = 'option';
  keyParams = 'params';
  keyConfig = 'config';
  keyWrite = 'write';
  keyHelp = 'help';
  keyType = 'type';
  keyQuiet = 'quiet';
  keyVerbose = 'verbose';
  SServer = 'Server';
  keyListen = 'listen';
  keyAll = 'all';

  DefaultListenPort = 3030;

  LongOptions : array of string = (
      keyConfig+':', KeyHost+':', KeyDatabase+':', KeyUser+':',
      keyPassword+':', keyPort+':', keyOption+':', keyWrite,
      keyHelp, keyType+':', keyQuiet, keyVerbose, keyListen+':', keyAll);


Type

  { TApplication }
{$IFDEF usesocket}
  TApplication = class (TMCPSocketApplication)
{$ELSE usesocket}
{$IFDEF usehttp}
  TApplication = class (TMCPHTTPServerApplication)
{$ELSE usehttp}
  TApplication = class (TMCPStdioApplication)
{$ENDIF usehttp}
{$endif usesocket}
  private
    FListen : integer;
    function DefaultDBtype: String;
    procedure DoMCPLog(aType: TMCPLogType; const aMessage: string);
    procedure ReadDBConfig(aInfo: TMCPDBConnectionInfo; aConfigFile: string);
    procedure RegisterTools;
  protected
    procedure DoRun; override;
  public
    constructor Create(aOwner : TComponent); override;
    destructor Destroy; override;
    procedure ParseOptions;
    procedure Usage(aMsg : string);
  end;

{ TApplication }

procedure TApplication.DoRun;
var
  S : String;
begin
  S:=CheckOptions('c:H:d:u:p:P:o:whvqal:',LongOptions);
  if (s<>'') or HasOption('h',keyHelp) then
    begin
    Usage(S);
    Terminate;
    exit;
    end;
  ParseOptions;
  RegisterTools;
  inherited DoRun;
end;

procedure TApplication.RegisterTools;
var
  T : TMCPTool;
begin
  T:=TListTablesTool.Create('list-tables','lists the tables in the database');
  T.Register;
  T:=TExecuteSQLTool.Create('execute-query','Executes a query in the database.');
  T.Register;
  T:=TGetTableInfoTool.Create('describe-table','Gets the detailed schema (columns, types) of a specific table.');
  T.Register;
  T:=TListIndexesTool.Create('list-indexes','Lists all indexes of a specific table.');
  T.Register;
  T:=TListViewsTool.Create('list-views','Lists all views in the database.');
  T.Register;
  T:=TViewDetailsTool.Create('view-details','Gets the SQL definition and updatability of a specific view.');
  T.Register;
  T:=TListRelationshipsTool.Create('list-relationships','Lists all foreign key relationships of a specific table.');
  T.Register;
  T:=TGetSampleDataTool.Create('get-sample-data','Returns sample rows from a specific table (max 10).');
  T.Register;
end;

constructor TApplication.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  MCPLogger.LogLevels:=[mltError,mltInfo,mltWarning];
  MCPLogger.AddLogHandler(@DoMCPLog);
  MCPLogger.Enabled:=True;
  MCPLogger.LogToConsole:=False;
end;

destructor TApplication.Destroy;
begin
  MCPLogger.RemoveLogHandler(@DoMCPLog);
  inherited destroy;
end;

function TApplication.DefaultDBtype: String;
begin
  Result:=TMCPToolConnectionManager.DefaultDBType;
end;

procedure TApplication.DoMCPLog(aType: TMCPLogType; const aMessage: string);

const
  sLogs : array [TMCPLogType] of string = ('Error','Warning','Info','Trace','Debug');

begin
  Writeln(StdErr,DateToISO8601(Now),' [',sLogs[aType]:7,'] ',aMessage);
end;

procedure TApplication.ReadDBConfig(aInfo : TMCPDBConnectionInfo; aConfigFile : string);

var
  lIni : TCustomIniFile;
  S : String;

begin
  lIni:=TMemIniFile.Create(aConfigFile);
  try
    With lIni do
      begin
      aInfo.DBType:=ReadString(sDatabase,KeyHost,'');
      aInfo.HostName:=ReadString(sDatabase,KeyHost,'localhost');
      aInfo.DatabaseName:=ReadString(sDatabase,KeyDatabase,'');
      aInfo.Port:=ReadInteger(sDatabase,KeyPort,0);
      aInfo.UserName:=ReadString(sDatabase,KeyUser,'');
      aInfo.Password:=ReadString(sDatabase,keyPassword,'');
      S:=ReadString(sDatabase,keyParams,'');
      if S<>'' then
        aInfo.Params:=SplitString(S,',');
      FListen:=ReadInteger(SServer,keyListen,DefaultListenPort);
      {$IFDEF HAVEPORT}
      if ReadBool(SServer,KeyAll,False) then
        Address:='';
      {$ENDIF}
      end;
  finally
    lIni.Free
  end;
end;

procedure TApplication.ParseOptions;
var
  lInfo : TMCPDBConnectionInfo;
begin
  lInfo:=TMCPDBConnectionInfo.Create;
  if HasOption('c',keyConfig) then
    ReadDBConfig(lInfo,GetOptionValue('c',keyConfig))
  else
    begin
    lInfo.DBType:=GetOptionValue('t',KeyType);
    lInfo.HostName:=GetOptionValue('H',Keyhost);
    lInfo.DatabaseName:=GetOptionValue('d',KeyDatabase);
    lInfo.Port:=StrToIntDef(GetOptionValue('P',keyPort),0);
    lInfo.UserName:=GetOptionValue('u',keyUser);
    lInfo.Password:=GetOptionValue('p',keyPassword);
    lInfo.Params:=GetOptionValues('o',keyOption);
    end;
  if HasOption('v','verbose') then
    MCPLogger.LogLevels:=[Low(TMCPLogType)..High(TMCPLogType)];
  if HasOption('q','quiet') then
    MCPLogger.LogLevels:=[mltError];
  if HasOption('l','listen') then
    FListen:=StrToIntDef(GetOptionValue('l','listen'),DefaultListenPort)
  else
    FListen:=DefaultListenPort;
  {$IFDEF HAVEPORT}
  Port:=FListen;
  if HasOption('a','all') then
    Address:='';
  {$ENDIF}
  TMCPToolConnectionManager.Instance.SetDefaultConnection(lInfo);
  TMCPToolConnectionManager.Instance.AllowModify:=HasOption('w',keyWrite);
end;

procedure TApplication.Usage(aMsg: string);
var
  l : TStrings;
  S : string;
begin
  if (aMsg<>'') then
    Writeln('Error: ',aMsg);
  Writeln(stdErr,'Usage: ',Paramstr(0),' [options]');
  Writeln(stdErr,'Where options is one or more of:');
  Writeln(stdErr,'-h --help             this help.');
  {$IFDEF HAVEPORT}
  Writeln(stdErr,'-a --all              listen on all local interfaces. Default is to listen on 127.0.0.1');
  {$ENDIF}
  Writeln(stdErr,'-c --config=File      config file for database connection.');
  Writeln(stdErr,'-d --database=DBName  set connection database name.');
  Writeln(stdErr,'-H --host=HOST        set connection host.');
  Writeln(stdErr,'-p --password=PASSWD  set connection password.');
  Writeln(stdErr,'-P --port=NNN         set connection port ');
  {$IFDEF HAVEPORT}
  Writeln(stdErr,'-l --listen=NNN       listen on port NNN for MCP requests');
  {$ENDIF}
  Writeln(stdErr,'-q --quiet            Write less log messages.');
  Writeln(stdErr,'-t --type=DBTYPE      type connection. Allowed types:');
  l:=TStringList.Create;
  try
    GetConnectionList(l);
    if L.Count=0 then
      Writeln(stdErr,'                      No types defined. Recompile this tool with DB support! ');
    for S in L do
      Writeln(stdErr,'                      - ',S);
  finally
    l.Free;
  end;
  Writeln(stdErr,'-u --user=USER        set connection username.');
  Writeln(stdErr,'-v --verbose          Write more log messages.');
  Writeln(stdErr,'-w --write            allow SQL statements that modify the database.');
  ExitCode:=Ord(aMsg<>'');
end;

var
  Application : TApplication;

begin
  Application:=TApplication.Create(Nil);
  Application.Initialize;
  Application.Run;
  Application.Free;
end.

end.

