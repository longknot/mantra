{
    This file is part of the Free Component Library

    MCP standard I/O transport class
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.transport.stdio;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, mcp.Types, mcp.transport.base;

Type
  PText = ^Text;

  { TLSPTextTransport }
  TJSONRequestHandler = procedure(aRequest : TJSONObject; var aResponse : TJSONObject) of object;

  { TMCPSTDIOTransport }

  TMCPSTDIOTransport = class(TMCPMessageTransport)
  private
    FInput : PText;
    FOutput : PText;
    FError : PText;
    function ReadRequest: TJSONObject;
  Protected
    Procedure DoSendMessage(aMessage: TJSONData); override;
    Procedure DoSendDiagnostic(const aMessage: UTF8String); override;
    Procedure EmitMessage(aMessage: TJSONStringType);
  Public
    constructor Create(aInput,aOutput,aError : PText); reintroduce;
    // specific
    Procedure SetupTextLoop(var aInput,aOutput,aError : Text);
    Procedure RunMessageLoop(aOnRequest : TJSONRequestHandler);
  end;



implementation

uses mcp.logging;

procedure TMCPSTDIOTransport.SetupTextLoop(var aInput, aOutput, aError: Text);

begin
  TJSONData.CompressedJSON := True;
  SetTextLineEnding(aInput, #13#10);
  SetTextLineEnding(aOutput, #13#10);
  SetTextLineEnding(aError, #13#10);
  FInput:=@AInput;
  FOutput:=@AOutput;
  FError:=@aError;
end;

function TMCPSTDIOTransport.ReadRequest: TJSONObject;

Var
  lContent : TJSONStringType;
  lData : TJSONData;

begin
  Result:=Nil;
  MCPLogger.Trace('[%s] Reading request - start',[ClassName]);
  ReadLn(FInput^,lContent);
  MCPLogger.Debug('[%s] Read request: %s',[ClassName,lContent]);
  if lContent<>'' then
    try
      lData:=GetJSON(lContent, True);
      if not (lData is TJSONObject) then
        Raise EJSON.CreateFmt('%s is not a JSON object',[lData.AsJSON]);
      Result:=lData as TJSONObject;
    except
      on E : Exception do
        begin
        MCPLogger.LogException(E,'[%s] Reading request from STDIN',[ClassName]);
        SendDiagnostic('Exception %s while reading request from STDIN: %s',[E.ClassName,E.Message]);
        end;
    end;
  MCPLogger.Trace('[%s] Reading request - end',[ClassName]);
end;


procedure TMCPSTDIOTransport.RunMessageLoop(aOnRequest: TJSONRequestHandler);

var
  lRequest,
  lResponse: TJSONObject;

begin
  MCPLogger.Trace('[%s] RunMessageLoop - start',[ClassName]);
  lResponse:=Nil;
  lRequest:=Nil;
  try
    while not EOF(FInput^) do
      begin
      lRequest:=ReadRequest;
      if Assigned(lRequest) then
        begin
        try
          aOnRequest(lRequest,lResponse);
          MCPLogger.Trace('[%s] after request ',[ClassName]);
        except
          On e : exception do
            begin
            MCPLogger.LogException(E,'[%s] Handling request: "%s"',[ClassName,lRequest.AsJSON]);
            SendDiagnostic('Exception %s (Message: "%s") handling request: %s',[E.ClassName,E.Message,lRequest.AsJSON]);
            end;
        end;
        if Assigned(lResponse) then
          SendMessage(lResponse);
        FreeAndNil(lRequest);
        FreeAndNil(lResponse);
        end;
      end;
  finally
    lResponse.free;
    lRequest.Free;
  end;
  MCPLogger.Trace('[%s] RunMessageLoop - end',[ClassName]);
end;

{ TTextLSPContext }

constructor TMCPStdioTransport.Create(aInput, aOutput, aError: PText);
begin
  FOutput:=aOutput;
  FError:=aError;
  FInput:=aInput;
end;

procedure TMCPStdioTransport.EmitMessage(aMessage: TJSONStringType);
begin
  MCPLogger.Trace('[%s] EmitMessage - start',[ClassName]);
  Try
    WriteLn(Foutput^,aMessage);
    Flush(Foutput^);
  except
    on e : exception do
      MCPLogger.LogException(E,'[%s] EmitMessage',[ClassName]);
  end;
  MCPLogger.Trace('[%s] EmitMessage - end',[ClassName]);
end;

procedure TMCPStdioTransport.DoSendMessage(aMessage: TJSONData);

Var
  Content : TJSONStringType;

begin
  MCPLogger.Trace('[%s] DoSendMessage - start',[ClassName]);
  Content:=aMessage.AsJSON;
  EmitMessage(Content);
  MCPLogger.Trace('[%s] DoSendMessage - end',[ClassName]);
end;

procedure TMCPStdioTransport.DoSendDiagnostic(const aMessage: UTF8String);
begin
  MCPLogger.Trace('[%s] DoSendDiagnostic - start',[ClassName]);
  Try
    WriteLn(FError^,'Diagnostic',aMessage);
    Flush(FError^);
  except
    on e : exception do
      MCPLogger.LogException(E,'[%s] diagnostic output',[ClassName]);
  end;
  MCPLogger.Trace('[%s] DoSendDiagnostic - start',[ClassName]);
end;



end.

