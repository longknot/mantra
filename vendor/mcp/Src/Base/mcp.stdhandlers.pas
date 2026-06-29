{
    This file is part of the Free Component Library

    MCP protocol default JSON-RPC command handlers
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.stdhandlers;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
interface

uses
  Classes, SysUtils, fpjson, mcp.logging, mcp.types, mcp.handler, mcp.tools, mcp.prompts, mcp.resources;

Type

  TMCPStdHandler = class(TMCPBaseHandler)
  end;

  { TMCPListToolsHandler }

  TMCPListToolsHandler = class(TMCPStdHandler)
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
    class function MCPMethodName: string; override;
  end;

  { TMCPCallToolHandler }

  TMCPCallToolHandler = class(TMCPStdHandler)
    class function MCPMethodName: string; override;
    function GetTool(aName : String) : TMCPTool;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;


  { TMCPListResourcesHandler }

  TMCPListResourcesHandler = class(TMCPStdHandler)
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;

  { TMCPReadResourcesHandler }

  TMCPReadResourcesHandler = class(TMCPStdHandler)
  Protected
    function GetResource(const aURI: String) : TMCPResource; virtual;
  Public
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;


  { TMCPListPromptsHandler }

  TMCPListPromptsHandler = class(TMCPStdHandler)
  Public
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;

  { TMCPGetPromptHandler }

  TMCPGetPromptHandler = class(TMCPStdHandler)
  Protected
    function GetPrompt(const aName: String) : TMCPPrompt; virtual;
  Public
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;

  { TMCPCancellationHandler }

  TMCPCancellationHandler = class(TMCPStdHandler)
  Public
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;


  { TMCPPingHandler }

  TMCPPingHandler = class(TMCPStdHandler)
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;

  { TMCPInitializeHandler }

  TMCPInitializeHandler = class(TMCPStdHandler)
  Public
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;

  { TMCPInitializedNotificationHandler }

  TMCPInitializedNotificationHandler = class(TMCPStdHandler)
    class function MCPMethodName: string; override;
    procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); override;
  end;

procedure RegisterStandardHandlers;

implementation

uses mcp.strings;

procedure RegisterStandardHandlers;
begin

  TMCPListToolsHandler.Register;
  TMCPCallToolHandler.Register;

  TMCPListResourcesHandler.Register;
  TMCPReadResourcesHandler.Register;

  TMCPListPromptsHandler.Register;
  TMCPGetPromptHandler.Register;

  TMCPCancellationHandler.Register;

  TMCPPingHandler.Register;

  TMCPInitializeHandler.Register;

  TMCPInitializedNotificationHandler.Register;

end;

{ TMCPListToolsHandler }

procedure TMCPListToolsHandler.MCPExecute(const Params: TJSONObject; aResult: TJSONObject);
var
  Arr: TJSONArray;
  lToolArr : TMCPToolArray;
  lTool : TMCPTool;
begin
  Arr:=TJSONArray.Create;
  aResult.Add('tools',Arr);
  MCPController.Tools.LockList(lToolArr);
  try
    for lTool in lToolArr do
      Arr.Add(lTool.ToJSON());
    lToolArr:=Nil;
  finally
    MCPController.tools.UnLockList;
  end;
end;

class function TMCPListToolsHandler.MCPMethodName: string;
begin
  result:='tools/list'
end;

{ TMCPCallToolHandler }

class function TMCPCallToolHandler.MCPMethodName: string;
begin
  result:='tools/call'
end;

function TMCPCallToolHandler.GetTool(aName: String): TMCPTool;
begin
  Result:=MCPController.Tools.Get(aName);
end;

procedure TMCPCallToolHandler.MCPExecute(const Params: TJSONObject;
  aResult: TJSONObject);
var
  lName : string;
  lTool : TMCPTool;
  lArgs : TJSONObject;
begin
  lName:=Params.Get('name','');
  lArgs:=Params.Get('arguments',TJSONObject(Nil));
  LTool:=MCPController.Tools.Get(lName);
  if lTool=Nil then
    Raise EMCPException.CreateFmt(SErrUnknownTool,[lName]);
  lTool.Execute(lArgs,aResult);
end;

{ TMCPListResourcesHandler }

class function TMCPListResourcesHandler.MCPMethodName: string;
begin
  result:='resources/list'
end;

procedure TMCPListResourcesHandler.MCPExecute(const Params: TJSONObject; aResult: TJSONObject);
Var
  Arr : TJSONArray;
  lResArr : TMCPResourceArray;
  lRes : TMCPResource;

begin
  lResArr:=[];
  Arr:=TJSONArray.Create;
  aResult.Add('resources',Arr);
  MCPController.Resources.LockList(lResArr);
  try
    for lRes in lResArr do
      Arr.Add(lRes.ToJSON(false));
    lResArr:=Nil;
  finally
    MCPController.Resources.UnLockList;
  end;
end;

{ TMCPReadResourcesHandler }

function TMCPReadResourcesHandler.GetResource(const aURI: String): TMCPResource;
begin
  Result:=MCPController.Resources.Find(aURI);
end;

class function TMCPReadResourcesHandler.MCPMethodName: string;
begin
  result:='resources/read';
end;

procedure TMCPReadResourcesHandler.MCPExecute(const Params: TJSONObject;
  aResult: TJSONObject);
var
  lURI : String;
  lRes : TMCPResource;
  lContents : TJSONArray;

begin
  lURI:=Params.Get('uri','');
  if lURI='' then
    Raise EMCPException.Create(SErrInvalidResource);
  LRes:=GetResource(lURI);
  // get data if needed
  if Assigned(LRes.OnData) then
    lRes.OnData(lRes);
  lContents:=TJSONArray.Create;
  aResult.Add('contents',lContents);
  lContents.Add(lRes.ToJSON(True));
end;

{ TMCPListPromptsHandler }

class function TMCPListPromptsHandler.MCPMethodName: string;
begin
  Result:='prompts/list';
end;

procedure TMCPListPromptsHandler.MCPExecute(const Params: TJSONObject;
  aResult: TJSONObject);
Var
  Arr : TJSONArray;
  lPromptArr : TMCPPromptArray;
  lPrompt : TMCPPrompt;

begin
  lPromptArr:=[];
  Arr:=TJSONArray.Create;
  aResult.Add('prompts',Arr);
  MCPController.Prompts.LockList(lPromptArr);
  try
    for lPrompt in lPromptArr do
      Arr.Add(lPrompt.ToJSON);
    lPromptArr:=Nil;
  finally
    MCPController.Prompts.UnLockList;
  end;
end;

{ TMCPGetPromptHandler }

function TMCPGetPromptHandler.GetPrompt(const aName: String): TMCPPrompt;
begin
  Result:=MCPController.Prompts.Get(aName);
end;

class function TMCPGetPromptHandler.MCPMethodName: string;
begin
  Result:='prompts/get'
end;

procedure TMCPGetPromptHandler.MCPExecute(const Params: TJSONObject;
  aResult: TJSONObject);

var
  lArgsJSON : TJSONObject;
  lEnum : TJSONEnum;
  lPrompt : TMCPPrompt;
  lName : string;
  lArgs : TStrings;
  lMessages : TMCPPromptMessageArray;

begin
  lName:=Params.Get('name','');
  if lName='' then
    Raise EMCPException.Create(SErrMissingName);
  lPrompt:=GetPrompt(lName);
  lArgs:=TStringList.Create;
  try
    lArgsJSON:=Params.get('arguments',TJSONObject(nil));
    if assigned(lArgsJSON) then
      for lEnum in lArgsJSON do
        lArgs.Values[lEnum.Key]:=lEnum.Value.AsString;
    lMessages:=lPrompt.GetPrompt(lArgs);
  finally
    lArgs.Free;
  end;
  aResult.Add('messages',lMessages.ToJSON(MCPController.Resources));
end;

{ TMCPCancellationHandler }

class function TMCPCancellationHandler.MCPMethodName: string;
begin
  Result:='notifications/cancelled';
end;

procedure TMCPCancellationHandler.MCPExecute(const Params: TJSONObject;
  aResult: TJSONObject);
var
  lID : TJSONData;
begin
  lID:=Params.Find('id');
  MCPController.CancelRequest(lID.AsString)
end;

{ TMCPPingHandler }

class function TMCPPingHandler.MCPMethodName: string;
begin
  result:='ping';
end;

procedure TMCPPingHandler.MCPExecute(const Params: TJSONObject;
  aResult: TJSONObject);
begin
  // nothing needs to be done. We return an empty result.
end;

{ TMCPInitializeHandler }

class function TMCPInitializeHandler.MCPMethodName: string;
begin
  result:='initialize';
end;

procedure TMCPInitializeHandler.MCPExecute(const Params: TJSONObject; aResult: TJSONObject);

var
  Tmp, Tmp2: TJSONObject;
  S : String;
begin
  MCPController.ClientInitialized(Params);
  // Add server info
  Tmp := TJSONObject.Create;
  Tmp.Add('name', MCPContext.ServiceName);
  Tmp.Add('version', MCPContext.ServiceVersion);
  aResult.Add('serverInfo', Tmp);

  // Add protocol version
  S:=Params.Get('protocolVersion','');
  if S='' then
    S:=MCPContext.ProtocolVersion;
  aResult.Add('protocolVersion', S);

  // Add capabilities
  Tmp := TJSONObject.Create;
  aResult.Add('capabilities', Tmp);
  // Tools
  Tmp2 := TJSONObject.Create;
  Tmp.Add('tools', Tmp2);
  Tmp2.Add('listChanged', TJSONBoolean.Create(True));

  // Add resources capability
  Tmp2 := TJSONObject.Create;
  Tmp.Add('resources', Tmp2);
  Tmp2.Add('listChanged', TJSONBoolean.Create(True));
  Tmp2.Add('subscribe', TJSONBoolean.Create(False));

  // Add prompts capability
  Tmp2 := TJSONObject.Create;
  Tmp.Add('prompts', Tmp2);
  Tmp2.Add('listChanged', TJSONBoolean.Create(True));


  Tmp2 := TJSONObject.Create;
  Tmp.Add('completions', Tmp2);

  // Add instructions
  aResult.Add('instructions', MCPContext.ServiceInstructions);
end;

class function TMCPInitializedNotificationHandler.MCPMethodName: string;
begin
  result:='notifications/initialized';
end;

procedure TMCPInitializedNotificationHandler.MCPExecute(const Params: TJSONObject; aResult: TJSONObject);
begin
  MCPLogger.Info('Executing '+MCPMethodName);
  // Nothing to do
end;

end.

