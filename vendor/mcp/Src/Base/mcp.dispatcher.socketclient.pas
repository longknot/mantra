unit mcp.dispatcher.socketclient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, ssockets, mcp.dispatcher.base, mcp.transport.base, mcp.transport.socket, mcp.controller;

type

  // Dispatches a request over a socket. It expects the transport to be a socket
  TMCPClientSocketDispatcher = Class(TMCPBaseDispatcher)
  private
    FController : TMCPController;
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
    Property Socket : TSocketStream Read GetSocket;
  end;


implementation

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
  Result:=FController.Transport as TMCPSocketTransport;
end;

function TMCPClientSocketDispatcher.GetTransport: TMCPMessageTransport;
begin
  Result:=FController.Transport;
end;


function TMCPClientSocketDispatcher.HandleException(aException : Exception; IsReceive : Boolean) : Boolean;

Const
  Stage : Array[Boolean] of string = ('sending','receiving');

begin
  Writeln('Exception ',aException.ClassName,' during ',Stage[IsReceive],' : ',aException.Message);
  Result:=True;
end;

function TMCPClientSocketDispatcher.ExecuteRequest(aRequest: TJSONData): TJSONData;


begin
  Result:=Nil;
  if SocketTransport.SendJSON(lpmtRequest,aRequest) then
    Result:=SocketTransport.ReceiveJSON(lpmtResponse);
end;

end.

