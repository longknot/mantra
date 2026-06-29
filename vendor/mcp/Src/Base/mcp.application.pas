unit mcp.application;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CustApp, fpjson, mcp.dispatcher.base, mcp.transport.stdio;


type

  { TMCPApplication }

  TMCPApplication = Class(TCustomApplication)
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

uses mcp.stdhandlers, mcp.controller,mcp.logging;

procedure TMCPApplication.doRun;


begin
  Terminate;
  FTransport.RunMessageLoop(@HandleRequest);
end;

procedure TMCPApplication.Initialize;
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
  TMCPController.instance.Transport:=FTransport;
  FDispatcher:=TMCPLocalDispatcher.Create(TMCPController.Instance);
end;

procedure TMCPApplication.HandleRequest(aRequest: TJSONObject; var aResponse: TJSONObject);
var
  lResp,lID : TJSONData;
begin
  aResponse:=Nil;
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
    MCPLogger.Error('Invalid JSON response: %s',[lResp.AsJSON]);
    lResp.Free;
    end;
end;

end.

