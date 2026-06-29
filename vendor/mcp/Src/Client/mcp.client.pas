unit mcp.client;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, mcp.types, rpc.clienttool, mcp.client.base, fpjson;

Type

  { TMCPClient }

  TMCPClient = Class (TMCPCustomClient)
  Public
    procedure Initialize(aOnReply: TOnInitializeEvent);
    // List available tools
    function ListTools(aOnReply: TListToolsResponseEvent): TMCPCall; override;
    // List available prompts
    function ListPrompts(aOnReply: TPromptListResponseEvent): TMCPCall; override;
    // List available resources
    function ListResources(aOnReply: TResourceListResponseEvent): TMCPCall; override;
    // Get a specific resource by URI
    function GetResource(const aURI: String; aOnReply: TGetResourceResponseEvent): TMCPCall; override;
    // Get completion suggestions
    function CompletePromptArgument(const aPromptName: string;
                                   const aArgumentName: string;
                                   const aPartialValue: string;
                                   aOnReply: TCompletionCompleteEvent;
                                   aContext: TJSONObject = nil): TMCPCall; override;
    function CompleteResourceArgument(const aResourcePattern: string;
                                     const aArgumentName: string;
                                     const aPartialValue: string;
                                     aOnReply: TCompletionCompleteEvent;
                                     aContext: TJSONObject = nil): TMCPCall; override;
    // Set logging level
    function SetLogLevel(const aLevel: string;
                        aOnReply: TSetLogLevelEvent): TMCPCall; override;

    // Call a tool
    function CallTool(const aToolName: string; aArguments: TJSONObject;
                     aOnReply: TToolCallEvent): TMCPCall;
    function CallTool(const aToolName: string; const aArguments: array of string;
                     aOnReply: TToolCallEvent): TMCPCall;

  Published
    Property Transport;
    Property OnServerNotification;
    property ClientVersion;
    property ClientName;
    Property Options;
    property Protocolversion;
  end;

  { TMCPClientProcessTransport }


implementation

uses mcp.client.calls;

procedure TMCPClient.Initialize(aOnReply : TOnInitializeEvent);
var
  lCall:TMCPInitialize;
begin
  lCall:=TMCPInitialize.create(Self);
  lCall.OnReply:=aOnReply;
  lCall.Call;
end;

function TMCPClient.ListTools(aOnReply: TListToolsResponseEvent): TMCPCall;
var
  ListToolsCall: TMCPListTools;
begin
  ListToolsCall := TMCPListTools.Create(Self);
  ListToolsCall.OnReply := aOnReply;
  ListToolsCall.Call();
  Result := ListToolsCall;
end;

function TMCPClient.ListPrompts(aOnReply: TPromptListResponseEvent): TMCPCall;
var
  ListPromptsCall: TMCPReadPromptList;
begin
  ListPromptsCall := TMCPReadPromptList.Create(Self);
  ListPromptsCall.OnReply := aOnReply;
  ListPromptsCall.Call();
  Result := ListPromptsCall;
end;

function TMCPClient.ListResources(aOnReply: TResourceListResponseEvent): TMCPCall;
var
  ListResourcesCall: TMCPReadResourceList;
begin
  ListResourcesCall := TMCPReadResourceList.Create(Self);
  ListResourcesCall.OnReply := aOnReply;
  ListResourcesCall.Call();
  Result := ListResourcesCall;
end;

function TMCPClient.GetResource(const aURI: String; aOnReply: TGetResourceResponseEvent): TMCPCall;
var
  GetResourceCall: TMCPGetResource;
begin
  GetResourceCall := TMCPGetResource.Create(Self);
  GetResourceCall.OnReply := aOnReply;
  GetResourceCall.Call(aURI);
  Result := GetResourceCall;
end;

function TMCPClient.CompletePromptArgument(const aPromptName: string;
                                               const aArgumentName: string;
                                               const aPartialValue: string;
                                               aOnReply: TCompletionCompleteEvent;
                                               aContext: TJSONObject): TMCPCall;
begin
  // For now, return a basic TMCPCall until proper callback integration is implemented
  Result := TMCPCall.Create(Self);
  // TODO: Implement proper completion call with callback support
end;

function TMCPClient.CompleteResourceArgument(const aResourcePattern: string;
                                                  const aArgumentName: string;
                                                  const aPartialValue: string;
                                                  aOnReply: TCompletionCompleteEvent;
                                                  aContext: TJSONObject): TMCPCall;
begin
  // For now, return a basic TMCPCall until proper callback integration is implemented
  Result := TMCPCall.Create(Self);
  // TODO: Implement proper completion call with callback support
end;

function TMCPClient.SetLogLevel(const aLevel: string;
                                     aOnReply: TSetLogLevelEvent): TMCPCall;
var
  SetLogLevelCall: TMCPSetLogLevel;
  LogLevel: TMCPProtocolLogLevel;
begin
  SetLogLevelCall := TMCPSetLogLevel.Create(Self);

  // Convert string to enum
  LogLevel := TMCPProtocolLogLevel.FromString(aLevel);

  // For now, simple implementation without callback until proper integration is added
  SetLogLevelCall.Call(LogLevel);
  Result := SetLogLevelCall;
end;


function TMCPClient.CallTool(const aToolName: string; aArguments: TJSONObject;
                                  aOnReply: TToolCallEvent): TMCPCall;
var
  ToolCall: TMCPToolCall;
begin
  ToolCall := TMCPToolCall.Create(Self);
  // For now, simple implementation without direct callback integration
  ToolCall.Call(aToolName, aArguments);
  Result := ToolCall;
end;

function TMCPClient.CallTool(const aToolName: string; const aArguments: array of string;
                                  aOnReply: TToolCallEvent): TMCPCall;
var
  ToolCall: TMCPToolCall;
begin
  ToolCall := TMCPToolCall.Create(Self);
  // For now, simple implementation without direct callback integration
  ToolCall.Call(aToolName, aArguments);
  Result := ToolCall;
end;


end.

