unit mcp.socketdispatcher;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  Classes, SysUtils, fpjson, ssockets,
  mcp.controller, mcp.handler, mcp.dispatcher, mcp.transport.base, mcp.transport.socket;

Type

  { TMCPSocketDispatcher }


  { TMCPServerSocketConnectionDispatcher }

  TMCPServerSocketConnection = Class
  Private
    FOnDestroy: TNotifyEvent;
    FTerminated : Boolean;
    FContext : TMCPContext;
    FLocalDispatch : TMCPLocalDispatcher;
    FController : TMCPController;
  Protected
    procedure DoMethodResult(Sender: TObject; aResponse: TObject; const aID: String; aResult: TJSONData);
    procedure DoMethodError(Sender: TObject; aResponse: TObject;const aID: String; aError: TJSONData);
  Public
    function ExecuteRequest(aRequest: TJSONData): TJSONData;
    function SocketTransport : TMCPSocketTransport;
    Constructor Create(aController : TMCPController); reintroduce;
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
    Property Path : String Read FPath Write SetPath;
  end;
{$ENDIF}

  { TMCPServerTCPSocketDispatcher }

  TMCPServerTCPSocketDispatcher = Class (TMCPSocketServer)
  private
    FPort: Integer;
    procedure setPort(const aValue: Integer);
  Public
    Procedure InitSocket; override;
    Property Port : Integer Read FPort Write setPort;
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
  Result:=FLocalDispatch.ExecuteRequest(aRequest);
end;

function TMCPServerSocketConnection.SocketTransport: TMCPSocketTransport;
begin
  Result:=FController.Transport as TMCPSocketTransport;
end;

constructor TMCPServerSocketConnection.Create(aController : TMCPController);

begin
  FController:=aController;
  FLocalDispatch:=TMCPLocalDispatcher.Create(FController);
  FLocalDispatch.OnMethodResult:=@DoMethodResult;
  FLocalDispatch.OnMethodError:=@DoMethodError;
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

begin
  Req:=Nil;
  Resp:=Nil;
  try
    While not Terminated do
      begin
      Req:=SocketTransport.ReceiveJSON(lpmtRequest);
      if Assigned(Req) then
        begin
        Resp:=FLocalDispatch.ExecuteRequest(req);
        if not SocketTransport.SendJSON(lpmtResponse,Resp) then
          Terminate;
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
  Result:=TMCPServerSocketConnection.Create(FController);
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
  FController:=aValue;
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

procedure TMCPServerTCPSocketDispatcher.InitSocket;
begin
  SetServer(TInetServer.Create(FPort));
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

