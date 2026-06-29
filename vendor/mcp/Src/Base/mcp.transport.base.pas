{
    This file is part of the Free Component Library

    MCP transport definition
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.transport.base;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, classes, fpJSON, mcp.types;

Type

  { TMCPMessageTransport }

  {
    Abstracts away the transport, allows to send diagnostic messages to the client
  }
  TMCPMessageTransport = class(TComponent)
  Protected
    procedure DoLog(aLevel : TMCPLogType; const aMessage : string);
    procedure DoLog(aLevel : TMCPLogType; const aFmt : string; const aArgs : Array of const);
    Procedure DoSendMessage(aMessage : TJSONData); virtual; abstract;
    Procedure DoSendDiagnostic(const aMessage : UTF8String); virtual; abstract;
  Public
    class function IsResponseValid(aResponse: TJSONData): boolean;
    Procedure SendMessage(aMessage : TJSONData);
    Procedure SendDiagnostic(const aMessage : UTF8String);
    Procedure SendDiagnostic(const aFmt : String; const aArgs : Array of const); overload;
  end;

implementation

uses mcp.logging;

{ TMCPMessageTransport }

procedure TMCPMessageTransport.DoLog(aLevel: TMCPLogType; const aMessage: string);
begin
  MCPLogger.Log(aLevel,'['+ClassName+'] '+aMessage);
end;

procedure TMCPMessageTransport.DoLog(aLevel: TMCPLogType; const aFmt: string; const aArgs: array of const);
begin
  DoLog(aLevel,Format(aFmt,aArgs));
end;

class function TMCPMessageTransport.IsResponseValid(aResponse: TJSONData): boolean;
var
  lObj : TJSONObject absolute aResponse;
begin
  result := true;
  // invalid responses without id's or null id's must not be sent to client, i.e:
  // {"jsonrpc":"2.0","error":{"code":-32603,"message":"Access violation"},"id":null}
  if (aResponse is TJSONObject) and
     ((lObj.Find('id') = nil) or lObj.Nulls['id']) then
    result := false;
end;

procedure TMCPMessageTransport.SendMessage(aMessage: TJSONData);
begin
  if IsResponseValid(aMessage) then
    DoSendMessage(aMessage)
  else
    begin
    MCPLogger.Error('[%s] Not a valid JSON-RPC message: %s',[ClassName,aMessage.AsJSON]);
    SendDiagnostic('invalid response message -> '+aMessage.AsJSON);
    end;
end;

procedure TMCPMessageTransport.SendDiagnostic(const aMessage: UTF8String);
begin
  DoSendDiagnostic(aMessage);
end;

procedure TMCPMessageTransport.SendDiagnostic(const aFmt: String; const aArgs: array of const);
begin
  DoSendDiagnostic(Format(aFmt,aArgs));
end;

end.

