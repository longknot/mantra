{
    This file is part of the Free Component Library

    MCP Application object with socket transport.
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcp.application.socket;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CustApp, fpjson, mcp.controller, mcp.dispatcher.base, mcp.transport.socket, mcp.dispatcher.serversocket;


type

  { TMCPSocketApplication }

  TMCPSocketApplication = Class(TCustomApplication)
  Private
    FAddress: String;
    FAdress: String;
    FServer : TMCPServerTCPSocketDispatcher;
    FController : TMCPController;
    function GetAdress: String;
    function GetPort: Integer;
    procedure SetAddress(AValue: String);
    procedure SetPort(AValue: Integer);
    procedure SetServer(AValue: TMCPServerTCPSocketDispatcher);
  Protected
    property Server : TMCPServerTCPSocketDispatcher read FServer write SetServer;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Initialize; override;
    procedure DoRun; override;
    property Port : Integer Read GetPort Write SetPort;
    property Address : String Read GetAdress Write SetAddress;
  end;



implementation

uses mcp.stdhandlers, mcp.logging;

constructor TMCPSocketApplication.Create(AOwner: TComponent);

begin
  inherited;
  FServer:=TMCPServerTCPSocketDispatcher.Create(Self);
  FServer.Port:=3030;

  FController:=TMCPController.create(self);
  FServer.Controller:=FController;
end;

procedure TMCPSocketApplication.DoRun;

begin
  Terminate;
  FServer.InitSocket;
  FServer.RunLoop;
end;

function TMCPSocketApplication.GetPort: Integer;
begin
  Result:=Server.Port;
end;

function TMCPSocketApplication.GetAdress: String;
begin
  Result:=Server.Address;
end;

procedure TMCPSocketApplication.SetAddress(AValue: String);
begin
  Server.Address:=aValue;
end;

procedure TMCPSocketApplication.SetPort(AValue: Integer);
begin
  Server.Port:=AValue;
end;

procedure TMCPSocketApplication.SetServer(AValue: TMCPServerTCPSocketDispatcher);
begin
  if FServer=AValue then Exit;
  FServer:=AValue;
end;

procedure TMCPSocketApplication.Initialize;
begin
  inherited Initialize;
  RegisterStandardHandlers;
end;

end.

