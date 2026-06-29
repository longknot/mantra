{
    This file is part of the Free Component Library

    MCP Application object with standard I/O transport.
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcp.application.stdio;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CustApp, fpjson, mcp.dispatcher.base, mcp.transport.stdio;


type

  { TMCPStdIOApplication }

  TMCPStdIOApplication = Class(TCustomApplication)
  Private
    FTransport : TMCPSTDIOTransport;
    FDispatcher : TMCPBaseDispatcher;
    FFileData : Text;
    procedure HandleRequest(aRequest: TJSONObject; var aResponse: TJSONObject); virtual;
  Protected
    Procedure doRun; override;
  public
    procedure Initialize; override;
  end;


implementation

uses mcp.stdhandlers, mcp.controller, mcp.logging;

procedure TMCPStdIOApplication.doRun;


begin
  Terminate;
  FTransport.RunMessageLoop(@HandleRequest);
end;

procedure TMCPStdIOApplication.Initialize;
begin
  inherited Initialize;
  RegisterStandardHandlers;
  if FileExists('input.txt') then
    begin
    AssignFile(FFileData,'input.txt');
    Reset(FFileData);
    FTransport:=TMCPSTDIOTransport.Create(@FFileData,@Output,@StdErr);
    end
  else
    FTransport:=TMCPSTDIOTransport.Create(@Input,@Output,@StdErr);
  TMCPController.instance.RegisterTransport(FTransport);
  FDispatcher:=TMCPLocalDispatcher.Create(TMCPController.Instance);
end;

procedure TMCPStdIOApplication.HandleRequest(aRequest: TJSONObject; var aResponse: TJSONObject);
var
  lResp,lID : TJSONData;
  lHaveID : Boolean;
begin
  MCPLogger.Trace('[%s] Handlerequest - start',[ClassName]);
  aResponse:=Nil;
  lHaveID:=aRequest.IndexOfName('id')<>-1;
  lResp:=FDispatcher.ExecuteRequest(aRequest);
  if lResp is TJSONObject then
    begin
    aResponse:=lResp as TJSONObject;
    lID:=aResponse.Find('id');
    if Assigned(lID) then
      begin
      // Request cancellation: do not return response when cancelled.
      if TMCPController.Instance.IsCancelled(lID.AsString) then
        begin
        FreeAndNil(aResponse);
        lResp:=Nil;
        end;
      TMCPController.Instance.RequestDone(lID.AsString);
      end;
    end
  else
    begin
    if lHaveID and (lResp<>Nil) then
      MCPLogger.Error('Invalid JSON response: %s',[lResp.AsJSON]);
    lResp.Free;
    end;
  MCPLogger.Trace('[%s] Handlerequest - end',[ClassName]);
end;

end.

