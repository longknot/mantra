unit debugger_runtime;

{$I mantra.inc}

interface

uses
  context, debugger_state;

procedure ConfigureDebuggerRuntime(
  AState: TDebuggerState;
  EnableCLI: Boolean
);
procedure ClearDebuggerRuntime;
procedure HandleDebuggerPause(AContext: TContext);

implementation

uses
  debugger_cli;

var
  ActiveDebuggerState: TDebuggerState = nil;
  ActiveDebuggerCLIEnabled: Boolean = False;

procedure ConfigureDebuggerRuntime(
  AState: TDebuggerState;
  EnableCLI: Boolean
);
begin
  ActiveDebuggerState := AState;
  ActiveDebuggerCLIEnabled := EnableCLI;
end;

procedure ClearDebuggerRuntime;
begin
  ActiveDebuggerState := nil;
  ActiveDebuggerCLIEnabled := False;
end;

procedure HandleDebuggerPause(AContext: TContext);
begin
  if (ActiveDebuggerState = nil) or (not ActiveDebuggerCLIEnabled) then
    Exit;
  if not ActiveDebuggerState.PausePending then
    Exit;
  RunDebuggerCommandLoop(ActiveDebuggerState, AContext);
  ActiveDebuggerState.ClearPause;
end;

end.
