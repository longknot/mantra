{
    This file is part of the Free Component Library

    MCP socket client class
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.dispatcher.clientsocket;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, ssockets, mcp.dispatcher.base, mcp.transport.base, mcp.transport.socket, mcp.controller;

type

  // Dispatches a request over a socket. It expects the transport to be a socket

  { TMCPClientSocketDispatcher }

  TMCPClientSocketDispatcher = Class(TMCPBaseDispatcher)
  private
    FController : TMCPController;
    FTransport: TMCPSocketTransport;
    function GetMCPTransport: TMCPSocketTransport;
    function GetSocket: TSocketStream;
  Protected
    function GetTransport: TMCPMessageTransport; override;
    function HandleException(aException: Exception; IsReceive : Boolean): Boolean; virtual;
    // Owned by this instance
    Property SocketTransport: TMCPSocketTransport Read GetMCPTransport;
  public
    Constructor Create(aController : TMCPController); reintroduce;
    Destructor Destroy; override;
    function ExecuteRequest(aRequest: TJSONData): TJSONData; override;
    Property Transport : TMCPSocketTransport Read GetMCPTransport Write FTransport;
    Property Socket : TSocketStream Read GetSocket;
  end;


implementation

uses mcp.logging;

{ TSocketDispatcher }

constructor TMCPClientSocketDispatcher.Create(aController: TMCPController);
begin
  FController:=aController;
end;

destructor TMCPClientSocketDispatcher.Destroy;
begin
  inherited Destroy;
end;

function TMCPClientSocketDispatcher.GetSocket: TSocketStream;
begin
  Result:=SocketTransport.Socket;
end;

function TMCPClientSocketDispatcher.GetMCPTransport: TMCPSocketTransport;
begin
  Result:=FTransport as TMCPSocketTransport;
end;

function TMCPClientSocketDispatcher.GetTransport: TMCPMessageTransport;
begin
  Result:=FTransport;
end;

function TMCPClientSocketDispatcher.HandleException(aException : Exception; IsReceive : Boolean) : Boolean;

Const
  Stage : Array[Boolean] of string = ('sending','receiving');

begin
  MCPLogger.Error('Exception %s during %s : %s',[aException.ClassName, Stage[IsReceive], aException.Message]);
  Result:=True;
end;

function TMCPClientSocketDispatcher.ExecuteRequest(aRequest: TJSONData): TJSONData;

begin
  MCPLogger.Debug('Sending message: %s ',[aRequest.AsJSON]);
  Result:=Nil;
  if SocketTransport.SendJSON(mpmtRequest,aRequest) then
    begin
    Result:=SocketTransport.ReceiveJSON(mpmtResponse);
    if Assigned(Result) then
      MCPLogger.Debug('Received message:  %s',[Result.AsJSON])
    else
      MCPLogger.Debug('Received nil message')
    end
  else
    MCPLogger.Warning('Failed to send message %s',[aRequest.AsJSON]);
end;

end.

