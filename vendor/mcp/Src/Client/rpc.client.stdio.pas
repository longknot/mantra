{
    This file is part of the Free Component Library

    MCP client side stdIO transport
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit rpc.client.stdio;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Pipes, Process, fpjson, rpc.clienttool, rpc.client.process;

Type
  { TLSPClientStdIOTransport }

  { TBufferedStream }

  TBufferedStream = class
    FBuffer : TBytes;
    FBufferPosition : Integer;
    FBufferRead : Integer;
    FStream : TInputPipeStream;
    FPending : TJSONStringType;
    Constructor Create(aStream : TInputPipeStream; aBufferSize : Cardinal);
    procedure FillBuffer;
    procedure ReadBuffer(P : Pointer; aCount : Integer);
    procedure ReadLine(out aString: TJSONStringType);
    function NumBytesAvailable: Integer;
    Function BufferAvail : Integer;
  end;

  TMCPClientStdIOTransport = class(TMCPClientProcessTransport)
  Private
    FStdOut : TBufferedStream;
    FStdErr : TBufferedStream;
    FBufferSize : Cardinal;
  protected
    function DoCheckDiagnostic(out aMsg: UTF8String): Boolean; override;
    Procedure StartProcess(aProcess : TProcess); override;
    Procedure StopProcess(aProcess : TProcess); override;
    function DoGetMessage(out J: TJSONStringType): Boolean; override;
    procedure DoSendMessage(J: TJSONStringType); override;
    procedure DoCloseSendChannel; override;
  public
    Constructor Create(AOwner: TComponent); override;
  end;


implementation

{ TMCPClientStdIOTransport }

Function TMCPClientStdIOTransport.DoCheckDiagnostic(Out aMsg : UTF8String) : Boolean;

begin
  Result:=(FStdErr.NumBytesAvailable>0) or (FStdErr.BufferAvail>0);
  if Result then
    FStdErr.ReadLine(aMsg);
end;

procedure TMCPClientStdIOTransport.StartProcess(aProcess: TProcess);
begin
  aProcess.Options:=[poUsePipes];
  inherited StartProcess(aProcess);
  FStdOut:=TBufferedStream.Create(aProcess.Output,FBufferSize);
  FStdErr:=TBufferedStream.Create(aProcess.Stderr,FBufferSize);
end;

procedure TMCPClientStdIOTransport.StopProcess(aProcess: TProcess);
begin
  inherited StopProcess(aProcess);
  FreeAndNil(FStdOut);
  FreeAndNil(FStdErr);
end;

{ TMCPClientStdIOTransport }

constructor TBufferedStream.Create(aStream: TInputPipeStream; aBufferSize: Cardinal);
begin
  FStream:=aStream;
  SetLength(FBuffer,aBufferSize);
  FBufferRead := 0;
  FBufferPosition := 0;
  FPending := '';
end;

procedure TBufferedStream.FillBuffer;

var
  Avail, ToRead : Integer;
begin
  FBufferPosition := 0;
  Avail := FStream.NumBytesAvailable;
  if Avail <= 0 then
    begin
    FBufferRead := 0;
    Exit;
    end;
  ToRead := Pred(Length(FBuffer));
  if ToRead > Avail then
    ToRead := Avail;
  FBufferRead := FStream.Read(FBuffer[0], ToRead);
  if FBufferRead > 0 then
    FBuffer[FBufferRead] := 0;
end;

procedure TBufferedStream.ReadBuffer(P: Pointer; aCount: Integer);
begin
  if ACount<=0 then exit;
  Move(FBuffer[FBufferPosition], P^, aCount);
  Inc(FBufferPosition,aCount);
end;

function TBufferedStream.NumBytesAvailable: Integer;

begin
  Result:=FStream.NumBytesAvailable;
end;

function TBufferedStream.BufferAvail: Integer;
begin
  Result:=FBufferRead-FBufferPosition;
end;

procedure TBufferedStream.ReadLine(out aString: TJSONStringType);

var
  VPByte: PByte;
  VPosition, VStrLength, VLength: Integer;

begin
  VPosition := FBufferPosition;
  aString := FPending;
  FPending := '';
  repeat
    VPByte := @FBuffer[FBufferPosition];
    while (FBufferPosition < FBufferRead) and not (VPByte^ in [10, 13]) do
    begin
      Inc(VPByte);
      Inc(FBufferPosition);
    end;
    if FBufferPosition = FBufferRead then
    begin
      VLength := FBufferPosition - VPosition;
      if VLength > 0 then
      begin
        VStrLength := Length(AString);
        SetLength(AString, VStrLength + VLength);
        Move(FBuffer[VPosition], AString[Succ(VStrLength)], VLength);
      end;
      FillBuffer;
      if FBufferRead = 0 then
      begin
        { No more data available yet - save partial and resume next call }
        FPending := aString;
        aString := '';
        Exit;
      end;
      VPByte := @FBuffer[FBufferPosition];
      VPosition := FBufferPosition;
    end;
  until (FBufferPosition = FBufferRead) or (VPByte^ in [10, 13]);
  VLength := FBufferPosition - VPosition;
  if VLength > 0 then
  begin
    VStrLength := Length(AString);
    SetLength(AString, VStrLength + VLength);
    Move(FBuffer[VPosition], AString[Succ(VStrLength)], VLength);
  end;
  if (VPByte^ in [10, 13]) and (FBufferPosition < FBufferRead) then
  begin
    Inc(FBufferPosition);
    if VPByte^ = 13 then
    begin
      if FBufferPosition = FBufferRead then
        FillBuffer;
      if (FBufferPosition < FBufferRead) and (FBuffer[FBufferPosition] = 10) then
        Inc(FBufferPosition);
    end;
  end;
end;


function TMCPClientStdIOTransport.DoGetMessage(out J: TJSONStringType): Boolean;

begin
  CheckDiagnostic;
  J:='';
  Result:=(FStdOut.BufferAvail>0) or (FStdOut.NumBytesAvailable>0);
  if Not Result then
    exit;
  if FStdOut.BufferAvail=0 then
    FStdOut.FillBuffer;
  FStdOut.ReadLine(J);
  { Empty result means the line is still incomplete - try again on next poll }
  Result := J <> '';
end;

procedure TMCPClientStdIOTransport.DoSendMessage(J: TJSONStringType);

Const
  LE : String[2] = #10;

  procedure WriteString(const S : RawByteString; addNewline : Boolean);
  begin
    if (Length(S)>0) then
      Process.Input.WriteBuffer(S[1],Length(S));
    if AddNewLine then
      Process.Input.WriteBuffer(LE[1],Length(LE));
  end;

begin
  WriteString(J,True);
end;

procedure TMCPClientStdIOTransport.DoCloseSendChannel;
begin
  Process.CloseInput;
end;

constructor TMCPClientStdIOTransport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBufferSize:=2048;
end;

end.
