{
    This file is part of the Free Component Library

    MCP context and RPC handler classes
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.handler;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, fpjsonrpc, mcp.transport.base, mcp.controller;

Type

  { TMCPContext }

  TMCPContext = class(TJSONRPCCallContext)
  private
    FController : TMCPController;
    FSessionID: String;
    function GetServiceInstructions: String;
    function GetServiceName : String;
    function GetServiceVersion : String;
    function GetProtocolVersion : string;
  public
    constructor Create(aController : TMCPController);
    function NextMessageID : Integer;
    Property Controller : TMCPController Read FController;
    Property ServiceName : string Read GetServiceName;
    Property ServiceVersion : string Read GetServiceVersion;
    Property ProtocolVersion : string Read GetProtocolVersion;
    property ServiceInstructions : String Read GetServiceInstructions;
    property SessionID : String Read FSessionID Write FSessionID;
 end;

  { TMCPBaseHandler }

  TMCPBaseHandler = class(TCustomJSONRPCHandler)
  private
    FContext: TMCPContext;
    FMeta: TJSONObject;
    FTransport: TMCPMessageTransport;
    function GetController: TMCPController;
  public
    Procedure MCPExecute(const Params: TJSONObject; aResult: TJSONObject); virtual; abstract;
  Public
    Class Function MCPMethodName : string; virtual; abstract;
    Class procedure Register;
    function DoExecute(const Params: TJSONData; AContext: TJSONRPCCallContext): TJSONData; override;
    Property MCPContext : TMCPContext Read FContext;
    property MCPController : TMCPController read GetController;
    Property Transport : TMCPMessageTransport Read FTransport Write FTRansport;
    Property _Meta : TJSONObject Read FMeta;
  end;

implementation

uses mcp.logging;

{ TMCPContext }

function TMCPContext.GetServiceInstructions: String;
begin
  Result:=FController.ServiceInstructions.Text;
end;

function TMCPContext.NextMessageID: Integer;
begin
  Result:=FController.NextMessageID;
end;

function TMCPContext.GetServiceName: String;
begin
  Result:=FController.ServiceName;
end;

function TMCPContext.GetServiceVersion: String;
begin
  Result:=FController.ServiceVersion;
end;

function TMCPContext.GetProtocolVersion: string;
begin
  Result:=FController.ProtocolVersion;
end;

constructor TMCPContext.Create(aController: TMCPController);
begin
  FController:=aController;
end;

{ TMCPBaseHandler }

function TMCPBaseHandler.GetController: TMCPController;
begin
  Result:=MCPContext.Controller;
end;

class procedure TMCPBaseHandler.Register;
begin
  JSONRPCHandlerManager.RegisterHandler('',MCPMethodName,Self);
end;

function TMCPBaseHandler.DoExecute(const Params: TJSONData;
  AContext: TJSONRPCCallContext): TJSONData;
var
  lObj : TJSONObject absolute Params;
  lResult: TJSONObject;
begin
  MCPLogger.Trace('[%s] DoExecute - start',[ClassName]);
  Result:=Nil;
  if (Params<>Nil) and not (Params is TJSONObject) then
    begin
    MCPLogger.Error('[%s] Request with invalid parameters: %s',[ClassName,Params.AsJSON]);
    Exit;
    end;
  if aContext is TMCPContext then
    FContext:=TMCPContext(aContext);
  if Assigned(lObj) then
    FMeta:=lObj.Get('_meta',TJSONObject(Nil));
  lResult:=TJSONObject.Create;
  try
    MCPExecute(lObj,lResult);
    Result:=lResult;
  except
    On E : exception do
      begin
      MCPLogger.LogException(E,'[%s] DoExecute exception %s : %s',[ClassName,E.ClassName,E.Message]);
      lResult.Free;
      Raise;
      end;
  end;
  MCPLogger.Trace('[%s] DoExecute - end',[ClassName]);
end;


end.

