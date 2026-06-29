{
    This file is part of the Free Component Library

    MCP socket server class, socket loop
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.dispatcher.serversocket;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  Classes, SysUtils, fpjson, ssockets,
  mcp.controller, mcp.handler, mcp.dispatcher.base, mcp.transport.base, mcp.transport.socket;

Const
  DefaultMCPServerPort = 9876;

Type
  { TMCPServerSocketConnectionDispatcher }

  TMCPServerSocketConnection = Class (TComponent)
  Private
    FOnDestroy: TNotifyEvent;
    FTerminated : Boolean;
    FContext : TMCPContext;
    FLocalDispatch : TMCPLocalDispatcher;
    FController : TMCPController;
    FTransport : TMCPSocketTransport;
    procedure SetController(const aValue: TMCPController);
    procedure SetTransport(const aValue: TMCPSocketTransport);
  Protected
    procedure DoMethodResult(Sender: TObject; aResponse: TObject; const aID: String; aResult: TJSONData);
    procedure DoMethodError(Sender: TObject; aResponse: TObject;const aID: String; aError: TJSONData);
  Public
    constructor create(aOwner : TComponent); override;
    function ExecuteRequest(aRequest: TJSONData): TJSONData;
    property SocketTransport : TMCPSocketTransport read FTransport Write SetTransport;
    property Controller : TMCPController Read FController Write SetController;
    Destructor Destroy; override;
    Procedure RunLoop; virtual;
    Procedure Terminate; virtual;
    Property Terminated : Boolean Read FTerminated;
    Property OnDestroy: TNotifyEvent Read FOnDestroy Write FOnDestroy;
  end;

  { TMCPSocketServer }

  TThreadMode = (tmNone,tmThreadPerConnection);
  TMCPSocketServer = Class(TComponent)
  Private
    FController: TMCPController;
    FSingleConnect: Boolean;
    FSocket: TSocketServer;
    FThreadMode: TThreadMode;
    FConns : TFPList;
    procedure SetController(const aValue: TMCPController);
  Protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure TerminateConnections; virtual;
    procedure RemoveConn(Sender: TObject); virtual;
    procedure AddConnection(aConn : TMCPServerSocketConnection); virtual;
    procedure HandleConnection(Sender: TObject; Data: TSocketStream); virtual;
    function CreateConnection(Data: TSocketStream): TMCPServerSocketConnection; virtual;
    Procedure SetServer(aSocket : TSocketServer);
    Property Connections : TFPList Read FConns;
  Public
    Constructor Create(aOwner : TComponent); override;
    Destructor Destroy; override;
    Procedure InitSocket; virtual; abstract;
    Procedure RunLoop;
    Procedure Terminate;
    Property Socket : TSocketServer Read FSocket;
    Property Controller : TMCPController Read FController Write SetController;
  Published
    Property ThreadMode : TThreadMode Read FThreadMode Write FThreadMode;
    Property SingleConnect : Boolean Read FSingleConnect Write FSingleConnect;
  end;

{$IFDEF UNIX}
  { TMCPServerUnixSocketDispatcher }

  TMCPServerUnixSocketDispatcher = Class (TMCPSocketServer)
  private
    FPath: String;
    procedure SetPath(const aValue: String);
  Public
    Procedure InitSocket; override;
  Published
    Property Path : String Read FPath Write SetPath;
  end;
{$ENDIF}

  { TMCPServerTCPSocketDispatcher }

  TMCPServerTCPSocketDispatcher = Class (TMCPSocketServer)
  private
    FAddress: String;
    FPort: Integer;
    procedure SetAddress(AValue: String);
    procedure setPort(const aValue: Integer);
  Public
    Constructor Create(aOwner : TComponent); override;
    Procedure InitSocket; override;
  Published
    Property Port : Integer Read FPort Write SetPort;
    Property Address: String Read FAddress Write SetAddress;
  end;

  { TMCPThread }

  TMCPThread = Class(TThread)
  Private
    FConnection : TMCPServerSocketConnection;
  Protected
    Procedure DoTerminate; override;
  Public
    Constructor Create(aConnection : TMCPServerSocketConnection);
    Procedure Execute; override;
    Property Connection : TMCPServerSocketConnection Read FConnection;
  end;

implementation

uses mcp.logging, typinfo, sockets;



{ TMCPServerSocketConnectionDispatcher }

procedure TMCPServerSocketConnection.SetController(const aValue: TMCPController);
begin
  if FController=aValue then Exit;
  if Assigned(FController) then
    begin
    FController.RemoveFreeNotification(Self);
    if assigned(FTransport) then
      FController.UnRegisterTransport(FTransport);
    end;
  FController:=aValue;
  if assigned(FController) then
    begin
    FreeAndNil(FLocalDispatch);
    FLocalDispatch:=TMCPLocalDispatcher.Create(FController);
    FLocalDispatch.OnMethodResult:=@DoMethodResult;
    FLocalDispatch.OnMethodError:=@DoMethodError;
    if Assigned(FTransport) then
      FController.RegisterTransport(FTransport);
    end;
end;

procedure TMCPServerSocketConnection.SetTransport(const aValue: TMCPSocketTransport);
begin
  if FTransport=aValue then Exit;

  FTransport:=aValue;
end;

procedure TMCPServerSocketConnection.DoMethodResult(Sender: TObject;
  aResponse: TObject; const aID: String; aResult: TJSONData);
begin
  MCPLogger.Debug('Result of request "%s" : %s',[aID,aResult.AsJSON]);
end;

procedure TMCPServerSocketConnection.DoMethodError(Sender: TObject;
  aResponse: TObject; const aID: String; aError: TJSONData);
begin
  MCPLogger.Debug('Client reported error for request "%s" : %s',[aID,aError.AsJSON]);
end;

function TMCPServerSocketConnection.ExecuteRequest(aRequest: TJSONData
  ): TJSONData;
begin
  MCPLogger.Trace('%s ExecuteRequest - start',[ClassName]);
  if not assigned(FLocalDispatch) then
    exit;
  Result:=FLocalDispatch.ExecuteRequest(aRequest);
  MCPLogger.Trace('%s ExecuteRequest - end',[ClassName]);
end;

constructor TMCPServerSocketConnection.create(aOwner: TComponent);

begin
  MCPLogger.Trace('%s Creating connection',[ClassName]);
  Inherited ;
end;

destructor TMCPServerSocketConnection.Destroy;
begin
  If Assigned(FOnDestroy) then
    FOnDestroy(Self);
  FreeAndNil(FContext);
  inherited Destroy;
end;

procedure TMCPServerSocketConnection.RunLoop;

Var
  Req,Resp : TJSONData;
  lRes : String;
begin
  MCPLogger.Trace('%s RunLoop - start',[ClassName]);
  if not assigned(FLocalDispatch) then
    begin
    MCPLogger.Error('%s RunLoop - start but no local dispatcher',[ClassName]);
    Raise EMCPSocket.Create('No local dispatcher available yet');
    end;
  Req:=Nil;
  Resp:=Nil;
  try
    While not Terminated do
      begin
      Req:=SocketTransport.ReceiveJSON(mpmtRequest);
      if Assigned(Req) then
        begin
        MCPLogger.Trace('%s RunLoop - receive JSON: %s',[ClassName,Req.AsJSON]);
        Resp:=FLocalDispatch.ExecuteRequest(req);
        if Assigned(Resp) then
          lRes:=Resp.AsJSON
        else
          lRes:='<NIL>';
        MCPLogger.Trace('%s RunLoop - sending result: %s',[ClassName,lRes]);
        if not SocketTransport.SendJSON(mpmtResponse,Resp) then
          begin
          MCPLogger.Debug('%s RunLoop - ending, response sent: %s',[ClassName,lRes]);
          Terminate;
          end;
        end;
      FreeAndNil(Resp);
      FreeAndNil(Req);
      if SocketTransport.SocketClosed then
        Terminate;
      end;
  finally
    Req.Free;
    Resp.Free;
  end;
  MCPLogger.Trace('%s RunLoop - end',[ClassName]);
end;

procedure TMCPServerSocketConnection.Terminate;
begin
  FTerminated:=True;
end;


{ TMCPSocketServer }

function TMCPSocketServer.CreateConnection(Data: TSocketStream): TMCPServerSocketConnection;

Var
  Trans : TMCPSocketTransport;

begin
  Trans:=TMCPSocketTransport.Create(Data);
  Result:=TMCPServerSocketConnection.Create(Self);
  Result.SocketTransport:=Trans;
  Result.Controller:=FController;
end;

procedure TMCPSocketServer.HandleConnection(Sender: TObject;
  Data: TSocketStream);

var
  Conn : TMCPServerSocketConnection;

begin
  Conn:=CreateConnection(Data);
  try
    AddConnection(Conn);
    Case ThreadMode of
      tmNone:
        Conn.RunLoop;
      tmThreadPerConnection :
        begin
        TMCPThread.Create(Conn);
        Conn:=Nil;
        end;
    end;
  finally
    Conn.Free;
  end;
  if FSingleConnect then
    Terminate;
end;

procedure TMCPSocketServer.SetServer(aSocket: TSocketServer);
begin
  FSocket:=aSocket;
  FSocket.OnConnect:=@HandleConnection;
end;

constructor TMCPSocketServer.Create(aOwner: TComponent);
begin
  Inherited create(aOwner);
  FConns:=TFPList.Create;
end;

destructor TMCPSocketServer.Destroy;
begin
  FreeAndNil(FSocket);
  FreeAndNil(FConns);
  inherited Destroy;
end;

procedure TMCPSocketServer.SetController(const aValue: TMCPController);
begin
  if FController=aValue then Exit;
  if Assigned(FController) then
    FController.RemoveFreeNotification(Self);
  FController:=aValue;
  if Assigned(FController) then
    FController.FreeNotification(Self);
end;

procedure TMCPSocketServer.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then
    begin
    if aComponent=FController then
      FController:=Nil;
    end;
end;

procedure TMCPSocketServer.TerminateConnections;

Var
  I : Integer;

begin
  For I:=FConns.Count-1 downto 0 do
    TMCPServerSocketConnection(FConns[i]).Terminate;
end;

procedure TMCPSocketServer.RemoveConn(Sender: TObject);
begin
  FConns.Remove(Sender);
end;

procedure TMCPSocketServer.AddConnection(aConn: TMCPServerSocketConnection);
begin
  aConn.OnDestroy:=@RemoveConn;
  FConns.Add(aConn);
end;

procedure TMCPSocketServer.RunLoop;

begin
  if not assigned(FSocket) then
    Raise EMCPSocket.Create('Cannot run loop: Socket not assigned');
  FSocket.StartAccepting;
end;

procedure TMCPSocketServer.Terminate;
begin
  if not assigned(FSocket) then
    Exit;
  TerminateConnections;
  FSocket.StopAccepting(True);
end;

{$IFDEF UNIX}
{ TMCPServerUnixSocketDispatcher }


procedure TMCPServerUnixSocketDispatcher.SetPath(const aValue: String);
begin
  if FPath=aValue then Exit;
  if Assigned(Socket) then
    Raise EMCPSocket.Create('Socket already initialized');
  FPath:=aValue;
end;

procedure TMCPServerUnixSocketDispatcher.InitSocket;
begin
  SetServer(TUnixServer.Create(FPath));
  Socket.ReuseAddress:=True;
end;
{$ENDIF}

{ TMCPServerTCPSocketDispatcher }

procedure TMCPServerTCPSocketDispatcher.setPort(const aValue: Integer);
begin
  if FPort=aValue then Exit;
  if Assigned(Socket) then
    Raise EMCPSocket.Create('Socket already initialized');
  FPort:=aValue;
end;

procedure TMCPServerTCPSocketDispatcher.SetAddress(AValue: String);
begin
  if FAddress=AValue then Exit;
  if Assigned(Socket) then
    Raise EMCPSocket.Create('Socket already initialized');
  FAddress:=AValue;
end;

constructor TMCPServerTCPSocketDispatcher.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FPort:=DefaultMCPServerPort;
end;

procedure TMCPServerTCPSocketDispatcher.InitSocket;
begin
  SetServer(TInetServer.Create(FAddress,FPort));
  Socket.ReuseAddress:=True;
end;

{ TMCPThread }

procedure TMCPThread.DoTerminate;
begin
  inherited DoTerminate;
  FConnection.Terminate;
end;

constructor TMCPThread.Create(aConnection: TMCPServerSocketConnection);
begin
  FConnection:=aConnection;
  FreeOnTerminate:=True;
  Inherited Create(False);
end;

procedure TMCPThread.Execute;
begin
  try
    FConnection.RunLoop;
  finally
    FreeAndNil(FConnection)
  end;
end;

end.

