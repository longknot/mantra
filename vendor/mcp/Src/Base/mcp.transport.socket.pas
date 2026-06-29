{
    This file is part of the Free Component Library

    MCP Socket transport class
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.transport.socket;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  Classes, SysUtils, fpjson, mcp.transport.base, ssockets;

{
  The Protocol is simple message exchange in binary format:
  Client sends message of certain type (see below)
  Server answsers with message, with same ID.
}

Const
  MCPProtocolVersion = 1;

Type
  TMCPProtocolMessageType = (mpmtRequest, mpmtResponse, mpmtMessage, mpmtDiagnostic);

  { TMCPProtocolMessageTypeHelper }

  TMCPProtocolMessageTypeHelper = Type Helper for TMCPProtocolMessageType
  private
    function GetAsString: String;
  Public
    Property AsString : String Read GetAsString;
  end;

  { TMCPFrame }

  TMCPFrame = Packed Record
  private
    function GetMessageType: TMCPProtocolMessageType;
    function GetPayloadString: UTF8String;
    procedure SetMessageType(AValue: TMCPProtocolMessageType);
  public
    Version : Byte;
    MsgType : Byte; // Sent as byte
    ID : cardinal; // In network order;
    PayloadLen : cardinal; // In network order
    PayLoad : TBytes;
    Property MessageType : TMCPProtocolMessageType Read GetMessageType Write SetMessageType;
    Property PayloadString : UTF8String Read GetPayloadString;
  end;

  EMCPSocket = Class(Exception);

  { TSocketDispatcher }

  { TMCPSocketDispatcher }

  { TMCPSocketTransport }

  THandleFrameEvent = Procedure(Sender : TObject; const aFrame : TMCPFrame) of object;
  TMCPSocketTransport = class(TMCPMessageTransport)
  private
    FOnHandleFrame: THandleFrameEvent;
    FSocket: TSocketStream;
    FSocketClosed: Boolean;
    FID : Integer;
  Protected
    Procedure DoHandleFrame(const aFrame : TMCPFrame); virtual;
  Public
    Constructor Create(aSocket: TSocketStream);
    Destructor Destroy; override;
    function NextID : Cardinal;
    // TMessageTRansport methods
    Procedure DoSendMessage(aMessage: TJSONData); override;
    Procedure DoSendDiagnostic(const aMessage : UTF8String); override;
    function ReadFrame(Out Msg: TMCPFrame) : Boolean;
    function SendFrame(const Msg: TMCPFrame) : Boolean;
    // Read frames till a frame with type aType is read.
    function ReceiveJSON(aType: TMCPProtocolMessageType): TJSONData;
    function SendJSON(aType: TMCPProtocolMessageType; aJSON : TJSONData) : Boolean;
    // Socket is owned by this transport instance.
    Property Socket : TSocketStream Read FSocket;
    // True when last read indicated socket is closed.
    Property SocketClosed : Boolean Read FSocketClosed;
    // Handle unexpected frames
    Property OnHandleFrame : THandleFrameEvent Read FOnHandleFrame Write FOnHandleFrame;
  end;


implementation

uses typinfo, sockets;

{ TMCPProtocolMessageTypeHelper }

function TMCPProtocolMessageTypeHelper.GetAsString: String;
begin
  Result:=GetEnumName(TypeInfo(TMCPProtocolMessageType),Ord(Self));
end;

{ TMCPFrame }

function TMCPFrame.GetMessageType: TMCPProtocolMessageType;
begin
  Result:=TMCPProtocolMessageType(MsgType);
end;

function TMCPFrame.GetPayloadString: UTF8String;
begin
  Result:=TEncoding.UTF8.GetAnsiString(Payload);
end;

procedure TMCPFrame.SetMessageType(AValue: TMCPProtocolMessageType);
begin
  MsgType:=Ord(aValue);
end;

{ TMCPSocketTransport }

procedure TMCPSocketTransport.DoHandleFrame(const aFrame: TMCPFrame);
begin
  if Assigned(FOnHandleFrame) then
    FOnHandleFrame(Self,aFrame);
end;

constructor TMCPSocketTransport.Create(aSocket: TSocketStream);
begin
  FSocket:=aSocket;
end;

destructor TMCPSocketTransport.Destroy;
begin
  FreeAndNil(FSocket);
  inherited Destroy;
end;

procedure TMCPSocketTransport.DoSendMessage(aMessage: TJSONData);
begin
  SendJSON(mpmtMessage,aMessage);
end;

procedure TMCPSocketTransport.DoSendDiagnostic(const aMessage: UTF8String);
Var
  Msg : TMCPFrame;

begin
  Msg.Version:=MCPProtocolVersion;
  Msg.MsgType:=Ord(mpmtDiagnostic);
  Msg.ID:=NextID;
  Msg.PayLoad:=TEncoding.UTF8.GetAnsiBytes(aMessage);
  Msg.PayloadLen:=Length(Msg.PayLoad);
  SendFrame(Msg);
end;

function TMCPSocketTransport.NextID: Cardinal;
begin
  Result:=InterlockedIncrement(FID);
end;

function TMCPSocketTransport.SendFrame(const Msg : TMCPFrame) : Boolean;

Var
  N : Cardinal;

begin
  Result:=False;
  N:=0;
  if Socket.Write(Msg.Version,SizeOf(Byte))=0 then
    begin
    FSocketClosed:=True;
    exit;
    end;
  try
    Socket.WriteBuffer(Msg.MsgType,SizeOf(Byte));
    N:=htonl(Msg.ID);
    Socket.WriteBuffer(N,SizeOf(cardinal));
    N:=htonl(Msg.PayloadLen);
    Socket.WriteBuffer(N,SizeOf(cardinal));
    Socket.WriteBuffer(Msg.Payload[0],Msg.PayloadLen);
  except
    // Rather crude
    FSocketClosed:=True;
  end;
end;

function TMCPSocketTransport.ReadFrame(out Msg: TMCPFrame): Boolean;

Var
  N : Cardinal;

begin
  Result:=False;
  N:=0;
  Msg:=Default(TMCPFrame);
  if Socket.Read(Msg.Version,SizeOf(Byte))=0 then
    begin
    FSocketClosed:=True;
    exit;
    end;
  Socket.ReadBuffer(Msg.MsgType,SizeOf(Byte));
  Socket.ReadBuffer(N,SizeOf(cardinal));
  Msg.ID:=ntohl(N);
  Socket.ReadBuffer(N,SizeOf(cardinal));
  Msg.PayloadLen:=ntohl(N);
  SetLength(Msg.Payload,Msg.PayloadLen);
  if Msg.PayloadLen>0 then
    Socket.ReadBuffer(Msg.Payload[0],Msg.PayloadLen);
  Result:=(Msg.Version=MCPProtocolVersion);
end;


function TMCPSocketTransport.SendJSON(aType: TMCPProtocolMessageType;
  aJSON: TJSONData): Boolean;

Var
  Msg : TMCPFrame;
  JS : TJSONStringType; // Tmp var for debugging purposes.

begin
  Msg.Version:=MCPProtocolVersion;
  Msg.MsgType:=Ord(aType);
  Msg.ID:=NextID;
  if Assigned(aJSON) then
    JS:=aJSON.AsJSON
  else
    JS:='';
  Msg.PayLoad:=TEncoding.UTF8.GetAnsiBytes(JS);
  Msg.PayloadLen:=Length(Msg.PayLoad);
  SendFrame(Msg);
  Result:=True;
end;

function TMCPSocketTransport.ReceiveJSON(aType: TMCPProtocolMessageType): TJSONData;

Var
  Msg : TMCPFrame;
  JSON : TJSONStringType;

begin
  Result:=nil;
  Repeat
    if Not ReadFrame(Msg) then
      Exit;
    if (Ord(aType)<>Msg.MsgType) then
      DoHandleFrame(Msg)
    else
      begin
      if (Msg.PayloadLen<>0) then
        begin
        JSON:=TEncoding.UTF8.GetAnsiString(Msg.Payload);
        Result:=GetJSON(JSON,True);
        end;
      end;
  Until (Ord(aType)=Msg.MsgType) or SocketClosed;
end;

end.

