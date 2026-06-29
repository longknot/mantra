{
    This file is part of the Free Component Library

    MCP client component
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit MCP.Client.Base;

{$mode objfpc}
{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, fpjson, mcp.types, rpc.clienttool;

Type

  TMCPClientEventType = (cetTransport,cetWarning,cetError,cetInfo);
  TMCPClientLogEvent = Procedure (Sender : TObject; aType : TMCPClientEventType; Msg : TJSONStringType) of object;

  TMCPCLientOption = (coKeepRequests,coIgnoredMethodNoError,coRoots,coElicitation,coSampling);
  TMCPCLientOptions = set of TMCPCLientOption;

  { TMCPCustomClient }

  TMCPCustomClient = class(TRPCClientTool)
  Private
    FOptions: TMCPClientOptions;
    procedure SetOptions(AValue: TMCPClientOptions);
  Public
    // List available tools
    function ListTools(aOnReply: TListToolsResponseEvent): TMCPCall;virtual; abstract;
    // List available prompts
    function ListPrompts(aOnReply: TPromptListResponseEvent): TMCPCall; virtual; abstract;
    // List available resources
    function ListResources(aOnReply: TResourceListResponseEvent): TMCPCall; virtual; abstract;
    // Get a specific resource by URI
    function GetResource(const aURI: String; aOnReply: TGetResourceResponseEvent): TMCPCall; virtual; abstract;
    // Get completion suggestions
    function CompletePromptArgument(const aPromptName: string;
                                   const aArgumentName: string;
                                   const aPartialValue: string;
                                   aOnReply: TCompletionCompleteEvent;
                                   aContext: TJSONObject = nil): TMCPCall; virtual; abstract;
    function CompleteResourceArgument(const aResourcePattern: string;
                                     const aArgumentName: string;
                                     const aPartialValue: string;
                                     aOnReply: TCompletionCompleteEvent;
                                     aContext: TJSONObject = nil): TMCPCall; virtual; abstract;
    // Set logging level
    function SetLogLevel(const aLevel: string;
                        aOnReply: TSetLogLevelEvent): TMCPCall; virtual; abstract;

    // Convenience methods for setting log levels
    function SetErrorLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
    function SetWarnLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
    function SetInfoLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
    function SetDebugLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;

    // Call a tool
    function CallTool(const aToolName: string; aArguments: TJSONObject;
                     aOnReply: TToolCallEvent): TMCPCall; virtual; abstract;
    function CallTool(const aToolName: string; const aArguments: array of string;
                     aOnReply: TToolCallEvent): TMCPCall; virtual; abstract;
    // Options
    Property Options : TMCPClientOptions Read FOptions Write SetOptions;
  end;


Const
  // Custom error codes.
  SErrJSONUnhandled = -32000;

implementation

resourcestring
  SLogReadHeader = 'Read header %s: %s';
  SErrNoClassForMethod = 'No implementation class found for request %s, method: %s';
  SErrDestreamingRequest = 'Exception %s while destreaming incoming request %s params: %s (%s)';
  SErrHandlingRequest = 'Exception %s while handling incoming request %s: %s (%s)';
  SErrUnhandledMethod = 'Unhandled method %s';
  SWarnUnhandledMethod = 'Unhandled request %s with method %s, params: %s';
  SErrUnknownMethod = 'Unknown method %s';

{ TMCPCustomClient }

procedure TMCPCustomClient.SetOptions(AValue: TMCPClientOptions);
begin
  if FOptions=AValue then Exit;
  FOptions:=AValue;
end;


function TMCPCustomClient.SetErrorLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
begin
  Result := SetLogLevel('error', aOnReply);
end;

function TMCPCustomClient.SetWarnLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
begin
  Result := SetLogLevel('warn', aOnReply);
end;

function TMCPCustomClient.SetInfoLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
begin
  Result := SetLogLevel('info', aOnReply);
end;

function TMCPCustomClient.SetDebugLogLevel(aOnReply: TSetLogLevelEvent): TMCPCall;
begin
  Result := SetLogLevel('debug', aOnReply);
end;


end.
