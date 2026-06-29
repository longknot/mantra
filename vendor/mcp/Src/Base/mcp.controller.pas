{
    This file is part of the Free Component Library

    MCP controller class - acts as a repository
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.controller;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, contnrs, mcp.transport.base, mcp.types, mcp.resources, mcp.tools, mcp.prompts;

type
  TMCPController = class;
  TMCPControllerClass = class of TMCPController;

  { TMCPController }

  TMCPController = class(TComponent)
  private
    FNextID: integer;
    FProtocolVersion: string;
    FServiceName: string;
    FServiceVersion: string;
    FServiceInstructions: TStrings;
    FTransports: TFPObjectList;
    FCancelled: TFPStringHashTable;
  class var _instance: TMCPController;
    class function GetController: TMCPController; static;
    procedure SendChange(Sender: TObject);
    procedure SetServiceInstructions(AValue: TStrings);
  protected
    function GetPrompts: TMCPPromptRegistry; virtual;
    function GetResources: TMCPResourceRegistry; virtual;
    function GetTools: TMCPToolRegistry; virtual;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClientInitialized(aParams: TJSONObject);
    function NextMessageID: integer;
    // Request cancellation
    procedure CancelRequest(const aID: string);
    function IsCancelled(const aID: string): boolean;
    procedure RegisterTransport(aTransport: TMCPMessageTransport);
    procedure UnRegisterTransport(aTransport: TMCPMessageTransport);
    procedure RequestDone(const aID: string);
    procedure SendNotification(aTransport: TMCPMessageTransport; const aMethod: string);

    property Resources: TMCPResourceRegistry read GetResources;
    property Prompts: TMCPPromptRegistry read GetPrompts;
    property Tools: TMCPToolRegistry read GetTools;
    property ProtocolVersion: string read FProtocolVersion write FProtocolVersion;
    property ServiceName: string read FServiceName write FServiceName;
    property ServiceVersion: string read FServiceVersion write FServiceVersion;
    property ServiceInstructions: TStrings read FServiceInstructions write SetServiceInstructions;

    class procedure Init(aClass: TMCPControllerClass);
    class property Instance: TMCPController read GetController;
  end;



implementation

uses mcp.logging, mcp.strings;

  { TMCPController }

class function TMCPController.GetController: TMCPController; static;
begin
  if _Instance = nil then
    _instance := TMCPController.Create(nil);
  Result := _Instance;
end;

procedure TMCPController.SendNotification(aTransport: TMCPMessageTransport; const aMethod: string);

var
  lMsg: TJSONObject;
begin
  lMsg := TJSONObject.Create(['jsonrpc', '2.0', 'method', aMethod]);
  try
    aTransport.SendMessage(lMsg);
  finally
    lMsg.Free;
  end;
end;

procedure TMCPController.SendChange(Sender: TObject);
var
  lChange: string;
  I: integer;
  lTransport: TMCPMessageTransport;

begin
  if Sender is TMCPResourceRegistry then
    lChange := 'resources'
  else if Sender is TMCPPromptRegistry then
      lChange := 'prompts'
    else if Sender is TMCPToolRegistry then
        lChange := 'tools'
      else
        lChange := '';
  if lChange<>'' then
  begin
    for I := 0 to FTransports.Count-1 do
    begin
      lTransport := TMCPMessageTransport(FTransports[i]);
      SendNotification(lTransport, Format('notifications/%s/list_changed', [lChange]));
    end;
  end
  else
  begin
    if Assigned(Sender) then
      lChange := Sender.ToString
    else
      lChange := '<Nil>';
    MCPLogger.Error('Received change notification of unknown sender: %s', [lChange]);
  end;
end;

function TMCPController.GetPrompts: TMCPPromptRegistry;
begin
  Result := TMCPPromptRegistry.Instance;
end;

function TMCPController.GetResources: TMCPResourceRegistry;
begin
  Result := TMCPResourceRegistry.Instance;
end;

function TMCPController.GetTools: TMCPToolRegistry;
begin
  Result := TMCPToolRegistry.Instance;
end;

procedure TMCPController.SetServiceInstructions(AValue: TStrings);
begin
  FServiceInstructions.Assign(aValue);
end;

constructor TMCPController.Create(aOwner: TComponent);
begin
  ProtocolVersion := '1';
  FServiceInstructions := TStringList.Create;
  FCancelled := TFPStringHashTable.Create;
  FTransports := TFPObjectList.Create(False);
end;

destructor TMCPController.Destroy;
begin
  FreeAndNil(FTransports);
  FreeAndNil(FServiceInstructions);
  FreeAndNil(FCancelled);
  inherited Destroy;
end;

procedure TMCPController.ClientInitialized(aParams: TJSONObject);
begin
  Resources.OnChange := @SendChange;
  Prompts.OnChange := @SendChange;
  Tools.OnChange := @SendChange;
end;

function TMCPController.NextMessageID: integer;
begin
  Result := InterlockedIncrement(FNextID);
end;

procedure TMCPController.CancelRequest(const aID: string);
begin
  FCancelled.Add(aID, aID);
end;

function TMCPController.IsCancelled(const aID: string): boolean;
begin
  Result := FCancelled.Items[aID] = aID;
end;

procedure TMCPController.RegisterTransport(aTransport: TMCPMessageTransport);
begin
  FTransports.Add(aTransport);
end;

procedure TMCPController.UnRegisterTransport(aTransport: TMCPMessageTransport);
begin
  FTransports.Remove(aTransport);
end;

procedure TMCPController.RequestDone(const aID: string);
begin
  FCancelled.Delete(aID);
end;

class procedure TMCPController.Init(aClass: TMCPControllerClass);
begin
  if Assigned(_Instance) then
    raise EMCPException.Create(SErrControllerInitialized);
  if not Assigned(aClass) then
    raise EMCPException.Create(SErrControllerClassEmpty);
  _Instance := aClass.Create(nil);
end;

end.
