program mcptests;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}
  cwstring,
  ffi.manager,
  {$endif}
  Classes, consoletestrunner, jsonparser,
  mcp.types.test,
  mcp.resources.test,
  mcp.resourceregistry.test,
  mcp.prompts.test,
  mcp.promptregistry.test,
  mcp.tools.test,
  mcp.toolregistry.test,
  mcp.client.rpcerror.test,
  mcp.client.robustness.test,
  mcp.client.initialize.test,
  mcp.client.calls.test,
  mcp.logging,
  mcp.listserialization.test;

type

  { TMyTestRunner }

  TMyTestRunner = class(TTestRunner)
  protected
  end;

var
  Application: TMyTestRunner;

begin
  mcp.logging.MCPLogger.Enabled:=False;
  DefaultRunAllTests:=True;
  DefaultFormat:=fPlain;
  Application := TMyTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'MCP Package tests';
  Application.Run;
  Application.Free;
end.
