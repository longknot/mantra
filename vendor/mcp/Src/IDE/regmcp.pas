{
    This file is part of the Free Component Library

    MCP class registration
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit regmcp;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  ProjectIntf,
  system.uitypes,
  frmmcpserveropts,
  frmmcptoolopts,
  mcp.dispatcher.base;

Type
  { TMCPToolDef }

  TMCPToolDef = class(TFileDescPascalUnit)
  private
    FToolName : String;
    FToolDescr : String;
    FToolClassName : string;
    FToolRegister : boolean;
    FToolResult : TToolReturn;
    function GetResultParam: String;
  public
    function Init(var {%H-}NewFilename: string; {%H-}NewOwner: TObject;
                  var {%H-}NewSource: string; {%H-}Quiet: boolean): TModalResult; override;
    function ShowOptionDialog : TModalResult;
    function GetInterfaceUsesSection: string; override;
    function GetInterfaceSource(const {%H-}aFilename, {%H-}aSourceName,
                                {%H-}aResourceName: string): string; override;
    function GetImplementationSource(const {%H-}aFilename, {%H-}aSourceName,
                                     {%H-}aResourceName: string): string; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
  end;

  { TProjectMCPServer }

  TProjectMCPServer = class(TProjectDescriptor)
  private
    FTransportType : TTransportType;
    FCreateTool : boolean;
    FConfigureLogging : boolean;
    procedure AddApplicationConstructor(aLines: TStrings);
    procedure AddApplicationDef(aLines: TStrings);
    procedure AddApplicationDestructor(aLines: TStrings);
    procedure AddApplicationImpl(aLines: TStrings);
    procedure AddDefines(aLines: TStrings);
    procedure AddMCPUses(aLines: TStrings);
    procedure AddProgramBlock(aLines: TStrings);
  protected
    function CreateSource: string; virtual;
    function DoInitDescriptor: TModalResult; override;
    function ShowOptions : TModalResult;
    property TransportType : TTransportType read FTransportType;
  public
    constructor Create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function InitProject(AProject: TLazProject): TModalResult; override;
    function CreateStartFiles(AProject: TLazProject): TModalResult; override;
  end;


procedure Register;

implementation

uses
  sysutils,
  forms,
  NewItemIntf,
  LazIDEIntf,
  mcpstrings,
  mcp.handler,
  mcp.dispatcher.serversocket,
  mcp.dispatcher.clientsocket,
  mcp.controller,
  mcp.transport.http,
  mcp.transport.stdio;

{$R mcp_icons.res}

var
  MCPToolDef : TMCPToolDef;
  MCPServer : TProjectMCPServer;
  MCPCat : TNewIDEItemCategory;
procedure Register;

begin
  RegisterComponents(rsAITab,[TMCPSocketServer,TMCPClientSocketDispatcher,TMCPSTDIOTransport,TMCPHTTPTransport,TMCPController]);
  MCPToolDef:=TMCPToolDef.Create;
  MCPToolDef.Name:=cMCPToolName;
  MCPCat:=TNewIDEItemCategory.Create(rsMCPCategory);
  RegisterNewItemCategory(MCPCat);
  RegisterProjectFileDescriptor(MCPToolDef,rsMCPCategory);
  MCPServer:=TProjectMCPServer.Create;
  RegisterProjectDescriptor(MCPServer,rsMCPCategory);
end;

{ TMCPToolDef }

function TMCPToolDef.Init(var NewFilename: string; NewOwner: TObject;
  var NewSource: string; Quiet: boolean): TModalResult;
begin
  if not Quiet then
    Result:=ShowOptionDialog
  else
    begin
    FToolName:=rsDefaultToolName;
    FToolClassName:=cDefaultToolClassName;
    FToolDescr:=rsDefaultToolDescription;
    FToolRegister:=True;
    end;
end;

function TMCPToolDef.ShowOptionDialog: TModalResult;
var
  Frm : TMCPToolOptionsForm;
begin
  frm:=TMCPToolOptionsForm.Create(Application);
  try
    Result:=frm.ShowModal;
    if Result=mrOK then
      begin
      FToolName:=frm.ToolName;
      FToolClassName:=frm.ToolClassName;
      FToolDescr:=frm.ToolDescription;
      FToolRegister:=frm.ToolRegister;
      FToolResult:=frm.ToolReturn;
      end;
  finally
    frm.Free;
  end;
end;

function TMCPToolDef.GetInterfaceUsesSection: string;
begin
  Result:=inherited GetInterfaceUsesSection;
  Result:=Result+', fpjson, mcp.tools, mcp.types';
end;

function TMCPToolDef.GetInterfaceSource(const aFilename, aSourceName,
  aResourceName: string): string;
var
  l : TStrings;
begin
  l:=TStringList.Create;
  try
    with l do
      begin
      Add('');
      Add('type');
      Add('');
      Add('  %s = class(TMCPTool)',[FToolClassName]);
      Add('  protected');
      Add('    Procedure DoExecute(aInput : TJSONObject; %s); override;',[GetResultParam]);
      Add('  public');
      Add('    constructor create; reintroduce;');
      Add('  end;');
      Add('');
      end;
    Result:=l.Text;
  finally
    L.free;
  end;

end;

function TMCPToolDef.GetResultParam : String;
begin
  case FToolResult of
    trSingle : Result:='out aResult : TMCPToolResult';
    trMultiple : Result:='var aResult : TMCPToolResultArray';
    trRaw : Result:='aResult : TJSONObject';
  end;
end;

function TMCPToolDef.GetImplementationSource(const aFilename, aSourceName,
  aResourceName: string): string;

  function MakeConst(aString : string) : string;
  begin
    Result:=StringReplace(aString,'''','''''',[rfReplaceAll]);
  end;
var
  l : TStrings;
begin
  l:=TStringList.Create;
  try
    with l do
      begin
      Add('');
      Add('const');
      Add('  cToolName = ''%s'';',[MakeConst(FToolName)]);
      Add('  cToolDescr = ''%s'';',[MakeConst(FToolDescr)]);
      Add('');
      if FToolRegister then
        begin
        Add('var');
        Add('  Tool : %s;',[FToolClassName]);
        Add('');
        end;
      Add('constructor %s.create;',[FToolClassName]);
      Add('');
      Add('begin');
      Add('  inherited create(cToolName,cToolDescr);');
      Add('end;');
      Add('');
      Add('Procedure %s.DoExecute(aInput : TJSONObject; %s);',[FToolClassName,GetResultParam]);
      Add('');
      Add('begin');
      Case FToolResult of
        trSingle :   Add('  aResult:=Default(TMCPToolResult);');
        trMultiple : Add('  SetLength(aResult,1);');
        trRaw :      Add('  // add key,data to aResult...');
      end;
      Add('end;');
      Add('');
      if FToolRegister then
        begin
        Add('initialization');
        Add('  Tool:=%s.Create;',[FToolClassName]);
        Add('  Tool.Register;');
        end;
      end;
    Result:=l.Text;
  finally
    l.Free;
  end;

end;

function TMCPToolDef.GetLocalizedName: string;
begin
  Result:=rsMCPToolName;
end;

function TMCPToolDef.GetLocalizedDescription: string;
begin
  Result:=rsMcpToolDescription;
end;

{ TProjectMCPServer }

function TProjectMCPServer.DoInitDescriptor: TModalResult;
begin
  Result:=ShowOptions;
end;

function TProjectMCPServer.ShowOptions: TModalResult;
var
  Frm : TMCPServerOptionsForm;
begin
  frm:=TMCPServerOptionsForm.Create(Application);
  try
    Result:=frm.ShowModal;
    if Result=mrOK then
      begin
      FTransportType:=frm.TransportType;
      FCreateTool:=frm.AddTool;
      FConfigureLogging:=frm.ConfigureLogging;
      end;
  finally
    frm.Free;
  end;
end;

constructor TProjectMCPServer.Create;
begin
  inherited Create;
  Name:=cMCPServer
end;

function TProjectMCPServer.GetLocalizedName: string;
begin
  Result:=rsMCPServerApplicationName;
end;

function TProjectMCPServer.GetLocalizedDescription: string;
begin
  Result:=rsMCPServerApplicationDescr;
end;

procedure TProjectMCPServer.AddDefines(aLines : TStrings);

begin
  with aLines do
    begin
    Add('// Define one of these to use the socket or http protocol.');
    Add('{ $DEFINE USE_SOCKET}');
    Add('{ $DEFINE USE_HTTP}');
    Add('');
    Add('{$IF DEFINED(USE_SOCKET) AND DEFINED(USE_HTTP)}');
    Add('{$Error ''Cannot use HTTP and socket transport at the same time''}');
    Add('{$ENDIF}');
    Add('');
    Add('{$IF DEFINED(USE_HTTP) or DEFINED(USE_SOCKET)}');
    Add('{$DEFINE HAVE_PORT}');
    Add('{$ENDIF}');
    Add('');
    end;
end;

procedure TProjectMCPServer.AddMCPUses(aLines : TStrings);

begin
  with aLines do
    begin
    case FTransportType of
      ttStdIO  : Add('  mcp.application.stdio,');
      ttHTTP   : Add('  mcp.application.http,');
      ttSocket : Add('  mcp.application.socket,');
      ttDefine :
        begin
        Add('  {$IFDEF USE_SOCKET}');
        Add('  mcp.application.socket,');
        Add('  {$ELSE USE_SOCKET}');
        Add('  {$IFDEF USE_HTTP}');
        Add('  mcp.application.http,');
        Add('  {$ELSE USE_HTTP}');
        Add('  mcp.application.stdio,');
        Add('  {$ENDIF USE_HTTP}');
        Add('  {$ENDIF USE_SOCKET}');
        end;
    end;
    add('  mcp.types, mcp.logging, mcp.controller,');
    add('  mcp.tools, mcp.resources, mcp.prompts;');
    end;
end;

procedure TProjectMCPServer.AddApplicationDef(aLines : TStrings);

begin
  with aLines do
    begin
    Add('  { TApplication }');
    Add('');
    case FTransportType of
      ttStdIO  : Add('  TApplication = class(TMCPStdioApplication)');
      ttHTTP   : Add('  TApplication = class(TMCPHTTPServerApplication)');
      ttSocket : Add('  TApplication = class(TMCPSocketApplication)');
      ttDefine :
        begin
        Add('  {$IFDEF USE_SOCKET}');
        Add('  TApplication = class(TMCPSocketApplication)');
        Add('  {$ELSE USE_SOCKET}');
        Add('  {$IFDEF USE_HTTP}');
        Add('  TApplication = class(TMCPHTTPServerApplication)');
        Add('  {$ELSE USE_HTTP}');
        Add('  TApplication = class(TMCPStdioApplication)');
        Add('  {$ENDIF USE_HTTP}');
        Add('  {$ENDIF USE_SOCKET}');
        end;
    end;
    Add('  protected');
    if FConfigureLogging then
      Add('    procedure DoMCPLog(aType: TMCPLogType; const aMessage: string);');
    Add('    procedure DoRun; override;');
    Add('  public');
    if FConfigureLogging then
      begin
      Add('    constructor Create(aOwner : TComponent); override;');
      Add('    destructor Destroy; override;');
      end;
    Add('  end;');
    end;
end;

procedure TProjectMCPServer.AddApplicationConstructor(aLines : TStrings);
begin
  with aLines do
    begin
    Add('constructor TApplication.Create(aOwner: TComponent);');
    Add('begin');
    Add('  inherited Create(aOwner);');
    Add('  MCPLogger.LogLevels:=[mltError,mltInfo,mltWarning];');
    Add('  MCPLogger.AddLogHandler(@DoMCPLog); ');
    Add('  MCPLogger.Enabled:=True;');
    Add('  MCPLogger.LogToConsole:=False;');
    Add('end;');
    Add('');
    end;
end;

procedure TProjectMCPServer.AddApplicationDestructor(aLines : TStrings);
begin
  with aLines do
    begin
    Add('destructor TApplication.Destroy;');
    Add('begin');
    Add('  MCPLogger.RemoveLogHandler(@DoMCPLog);');
    Add('  inherited destroy;');
    Add('end;');
    Add('');
    end;
end;


procedure TProjectMCPServer.AddApplicationImpl(aLines : TStrings);
begin
  with aLines do
    begin
    if FConfigureLogging then
      begin
      Add('procedure TApplication.DoMCPLog(aType: TMCPLogType; const aMessage: string);');
      Add('');
      Add('const');
      Add('  sLogs : array [TMCPLogType] of string = (''Error'',''Warning'',''Info'',''Trace'',''Debug'');');
      Add('');
      Add('begin');
      Add('  Writeln(StdErr,DateToISO8601(Now),'' ['',sLogs[aType]:7,''] '',aMessage);');
      Add('end;');
      end;
    Add('procedure TApplication.DoRun;');
    Add('begin');
    Add('  Terminate;');
    Add('  // Parse Options and adjust the properties below (if any)');
    case FTransportType of
      ttHTTP   :
        begin
        Add('  Port:=3030;');
        Add('  RequireSessionID:=False;');
        Add('  AllowSSE:=True;');
        end;
      ttSocket :
        Add('  Port:=3030;');
      ttDefine :
        begin
        Add('  {$IFDEF HAVE_PORT}');
        Add('  Port:=3030;');
        Add('  {$ENDIF HAVE_PORT}');
        Add('  {$IFDEF USE_HTTP}');
        Add('  RequireSessionID:=False;');
        Add('  AllowSSE:=True;');
        Add('  {$ENDIF USE_HTTP}');
        end;
    end;
    Add('  inherited dorun;');
    Add('end;');
    end;
end;

procedure TProjectMCPServer.AddProgramBlock(aLines : TStrings);

begin
  with aLines do
    begin
    Add('');
    Add('var');
    Add('  Application : TApplication;');
    Add('');
    Add('begin');
    Add('  Application:=TApplication.Create(nil);');
    Add('  Application.Initialize;');
    Add('  Application.Run;');
    Add('  Application.Free;');
    Add('end.');
    end;
end;

function TProjectMCPServer.CreateSource : string;
var
  l: TStrings;
begin
  l:=TStringList.Create;
  try
    With l do
      begin
      Add('program mcpserver1;');
      Add('');
      Add('{$mode objfpc}{$h+}');
      if FTransportType=ttDefine then
        AddDefines(l);
      Add('');
      Add('uses SysUtils, Classes, jsonparser, fpjson, dateutils, ');
      AddMCPUses(l);
      Add('');
      Add('type');
      AddApplicationDef(l);
      Add('');
      if FConfigureLogging then
        begin
        AddApplicationConstructor(l);
        AddApplicationDestructor(l);
        end;
      AddApplicationImpl(l);
      AddProgramBlock(l);
      end;
    Result:=l.Text;
  finally
    l.Free;
  end;
end;

function TProjectMCPServer.InitProject(AProject: TLazProject): TModalResult;

var
  NewSource: string;
  MainFile: TLazProjectFile;

begin
  MainFile:=AProject.CreateProjectFile('mcpserver1.lpr');
  MainFile.IsPartOfProject:=true;
  AProject.AddFile(MainFile,false);
  AProject.MainFileID:=0;

  // create program source
  NewSource:=CreateSource;

  AProject.MainFile.SetSourceText(NewSource);
  // add FCL dependency
  AProject.AddPackageDependency('mcpbase');
  result:=mrOK;
end;

function TProjectMCPServer.CreateStartFiles(AProject: TLazProject
  ): TModalResult;
begin
  Result:=inherited CreateStartFiles(AProject);
  if FCreateTool then
    LazarusIDE.DoNewEditorFile(MCPToolDef,'','',
                              [nfIsPartOfProject,nfOpenInEditor,nfCreateDefaultSrc]);
end;

initialization

end.

