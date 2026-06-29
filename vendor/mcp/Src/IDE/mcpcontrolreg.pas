{
    This file is part of the Free Component Library

    MCP Lazarus tool & resource registrations
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcpcontrolreg;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Controls, Classes, LazIDEIntf, ProjectIntf, CompOptsIntf, fpjson, mcp.types,
  mcp.tools, mcp.dispatcher.serversocket, mcp.stdhandlers, mcp.controller, mcp.logging;

type

  { TMCPToolController }

  TMCPToolController = class(TComponent)
  private
    FLog : TFileStream;
    FServer: TMCPServerTCPSocketDispatcher;
    procedure DoMCPLog(aType: TMCPLogLevel; const Msg: string);
  protected
    function CreateJSONResult(const aContent: Array of const): TMCPToolResultArray;
    function JSONToResult(aJSON: TJSONObject): TMCPToolResultArray;
    procedure MCPAddExistingUnit(aInput: TJSONData; var aOutput: TMCPToolResultArray);
    procedure MCPAddNewUnit(aInput: TJSONData; var aOutput: TMCPToolResultArray);
    procedure MCPCompileProject(aInput: TJSONData; var aOutput: TMCPToolResultArray);
    procedure MCPOpenProject(aInput: TJSONData; var aOutput: TMCPToolResultArray);
    procedure MCPNewProject(aInput: TJSONData; var aOutput: TMCPToolResultArray);
  Public
    constructor create(aOwner: TComponent); override;
    Destructor destroy; override;
    Procedure StartController;
    Procedure RegisterTools;
    Procedure Terminate;
  end;

procedure register;

implementation

var
  _ToolController : TMCPToolController;

procedure CreateMCPController;

begin
  _ToolController:=TMCPToolController.Create(Nil);
  _ToolController.RegisterTools;
  _ToolController.StartController;
end;

procedure register;
begin
  CreateMCPController;
end;

type
   TLazCmd = class(TObject)
     ExecuteResult : boolean;
   end;
   { TAddUnit }

   TAddUnitCmd = Class(TLazCmd)
     FFileName: string;
     IsNew : Boolean;
     Constructor Create(aFileName : string; aisNew : Boolean);
     Procedure Execute;
   end;

   { TOpenProjectCmd }

   TOpenProjectCmd = Class(TLazCmd)
     FFileName: string;
     Constructor Create(aFileName : string);
     Procedure Execute;
   end;

   { TCompileProject }

   TCompileProjectCmd = Class(TLazCmd)
     Reason : TCompileReason;
     constructor Create(aReason : TCompileReason);
     procedure execute;
   end;

{ TOpenProjectCmd }

constructor TOpenProjectCmd.Create(aFileName: string);
begin
  FFileName:=aFileName;
end;

procedure TOpenProjectCmd.Execute;
var
  ldesc : TProjectDescriptor;
begin
  if FFileName='' then
    begin
    ldesc:=ProjectDescriptors.FindByName(ProjDescNameSimpleProgram);
    ExecuteResult:=Assigned(ldesc) and (mrOK=LazarusIDE.DoNewProject(lDesc));
    end
  else
    ExecuteResult:=mrOK=LazarusIDE.DoOpenProjectFile(FFileName,[ofOnlyIfExists,ofAddToRecent]);
end;

{ TCompileProject }

constructor TCompileProjectCmd.Create(aReason : TCompileReason);
begin
  Reason:=aReason;
end;

procedure TCompileProjectCmd.execute;
begin
  ExecuteResult:=LazarusIDE.DoBuildProject(Reason,[],True)=mrOK;
end;

{ TAddUnit }

constructor TAddUnitCmd.Create(aFileName: string; aisNew : Boolean);
begin
  FFileName:=aFileName;
  IsNew:=aIsNew;
end;

procedure TAddUnitCmd.Execute;
begin
  if IsNew then
    begin
    ExecuteResult:=mrOK=LazarusIDE.DoNewEditorFile(FileDescriptorUnit,'','',
      [nfQuiet,nfAddToRecent,nfIsPartOfProject]);
    end
  else
    begin
    ExecuteResult:=mrOK=LazarusIDE.DoOpenEditorFile(FFileName,0,0,
      [ofQuiet,ofAddToProject,ofAddToRecent,ofOnlyIfExists]);
    end
end;

{ TMCPToolController }

procedure TMCPToolController.DoMCPLog(aType: TMCPLogLevel; const Msg: string);
var
  S : String;
begin
  WriteStr(S,aType);
  S:='['+S+'] '+Msg+sLineBreak;
  FLog.WriteBuffer(S[1],Length(S));
end;

function TMCPToolController.CreateJSONResult(const aContent: array of const): TMCPToolResultArray;
var
  lObj : TJSONObject;
begin
  lObj:=TJSONObject.Create(aContent);
  try
    Result:=JSONToResult(lObj);
  finally
    lObj.Free;
  end;
end;

function TMCPToolController.JSONToResult(aJSON: TJSONObject): TMCPToolResultArray;
begin
  Result:=[];
  SetLength(Result,1);
  Result[0]:=TMCPToolResult.CreateText(aJSON);
end;

procedure TMCPToolController.MCPAddExistingUnit(aInput: TJSONData; var aOutput: TMCPToolResultArray);
var
  OK: Boolean;
  lFilename : string;
  lRes : TJSONObject;
begin
  lFileName:=(aInput as TJSONObject).Get('filename','');
  if lFileName='' then
    Raise EMCPException.Create('Need a filename');
  With TAddUnitCmd.Create(lFileName,False) do
    begin
    TThread.Synchronize(TThread.CurrentThread,@Execute);
    OK:=ExecuteResult;
    Free;
    end;
  lRes:=TJSONObject.Create(['Success',OK]);
  aOutput:=JSONToResult(lRes)
end;

procedure TMCPToolController.MCPAddNewUnit(aInput: TJSONData; var aOutput: TMCPToolResultArray);
var
  OK: Boolean;
begin
  With TAddUnitCmd.Create('',True) do
    begin
    TThread.Synchronize(TThread.CurrentThread,@Execute);
    OK:=ExecuteResult;
    Free;
    end;
  aOutput:=CreateJSONResult(['Success',OK]);
end;

procedure TMCPToolController.MCPCompileProject(aInput: TJSONData; var aOutput: TMCPToolResultArray);
var
  lReason : TCompileReason;
  Ok : Boolean;
begin
  if (aInput as TJSONObject).Get('build',False) then
    lReason:=TCompileReason.crCompile
  else
    lReason:=TCompileReason.crBuild;
  With TCompileProjectCmd.Create(lReason) do
    begin
    TThread.Synchronize(TThread.CurrentThread,@Execute);
    OK:=ExecuteResult;
    Free;
    end;
  aOutput:=CreateJSONResult(['Success',OK]);
end;

procedure TMCPToolController.MCPOpenProject(aInput: TJSONData; var aOutput: TMCPToolResultArray);
var
  lFileName : string;
  OK : Boolean;

begin
  lFileName:=(aInput as TJSONObject).Get('filename','');
  if lFileName='' then
    Raise EMCPException.Create('Need a filename');
  With TOpenProjectCmd.Create(lFileName) do
    begin
    TThread.Synchronize(TThread.CurrentThread,@Execute);
    OK:=ExecuteResult;
    Free;
    end;
  aOutput:=CreateJSONResult(['Success',OK]);
end;

procedure TMCPToolController.MCPNewProject(aInput: TJSONData; var aOutput: TMCPToolResultArray);
var
  OK : Boolean;
begin
  With TOpenProjectCmd.Create('') do
    begin
    TThread.Synchronize(TThread.CurrentThread,@Execute);
    OK:=ExecuteResult;
    Free;
    end;
  aOutput:=CreateJSONResult(['Success',OK]);
end;

constructor TMCPToolController.create(aOwner: TComponent);
begin
  inherited create(aOwner);
  FLog:=TFileStream.Create(GetTempDir(False)+'lazmcplog.log',fmCreate or fmShareDenyNone);
  FServer:=TMCPServerTCPSocketDispatcher.Create(Self);
  FServer.Controller:=TMCPController.Instance;
end;

destructor TMCPToolController.destroy;
begin
  DoMCPLog(mltTrace,'Shutting down');
  FreeAndNil(FLog);
  inherited destroy;
end;

procedure DoRunLoop;
begin
  _ToolController.FServer.RunLoop;
end;

procedure TMCPToolController.StartController;
begin
  MCPLogger.LogToConsole:=False;
  MCPLogger.LogLevels:=[Low(TMCPLogLevel)..High(TMCPLogLevel)];
  MCPLogger.AddLogHandler(@DoMCPLog);
  MCPLogger.Enabled:=True;
  RegisterStandardHandlers;
  FServer.Port:=10987;
  FServer.InitSocket;
  TThread.CreateAnonymousThread(@DoRunLoop).Start;
end;

procedure TMCPToolController.RegisterTools;
begin
  With TMCPEventTool.create('openproject','Open a lazarus project',@MCPOpenProject) do
    begin
    InputSchema.AddArgument('projectfile',TJSONObject.Create(['type','string']),True);
    Register;
    end;
  With TMCPEventTool.create('newproject','Create a new lazarus project',@MCPNewProject) do
    begin
    Register;
    end;
  With TMCPEventTool.create('newnunit','Add a new unit to the project',@MCPAddNewUnit) do
    begin
    InputSchema.AddArgument('filename',TJSONObject.Create(['type','string']),True);
    Register;
    end;
  With TMCPEventTool.create('addnunit','Add an existing unit to the project',@MCPAddExistingUnit) do
    begin
    InputSchema.AddArgument('filename',TJSONObject.Create(['type','string']),True);
    Register;
    end;
  With TMCPEventTool.create('compile','compile project',@MCPCompileProject) do
    begin
    InputSchema.AddArgument('build',TJSONObject.Create(['type','boolean']),True);
    Register;
    end;
end;

procedure TMCPToolController.Terminate;
begin
  FServer.Terminate;
end;

finalization
  if assigned(_ToolController) then
    _ToolController.Terminate;
  FreeAndNil(_ToolController);
end.

