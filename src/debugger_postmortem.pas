unit debugger_postmortem;

{$I mantra.inc}

interface

uses
  debugger_state;

function FormatDebuggerStackTrace(const State: TDebuggerState): ansistring;
function FormatDebuggerRecentEvents(
  const State: TDebuggerState;
  MaxEvents: Integer = 16
): ansistring;
function BuildDebuggerPostmortemReport(const State: TDebuggerState): ansistring;

implementation

uses
  Classes, SysUtils, debugger_types, debugger_inspect;

function FormatDebuggerStackTrace(const State: TDebuggerState): ansistring;
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('Debugger Stack:');
    if (State = nil) or (State.FrameCount = 0) then
      Lines.Add('  <empty>')
    else
      for I := State.FrameCount - 1 downto 0 do
        Lines.Add(Format('  #%d %s', [State.FrameCount - 1 - I, FormatDebuggerFrameLine(State.GetFrame(I))]));
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function FormatDebuggerRecentEvents(
  const State: TDebuggerState;
  MaxEvents: Integer
): ansistring;
var
  Lines: TStringList;
  StartIndex: Integer;
  I: Integer;
  Event: TDebuggerEvent;
  LineText: ansistring;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('Recent Debugger Events:');
    if (State = nil) or (State.RecentEventCount = 0) then
      Lines.Add('  <none>')
    else
    begin
      if MaxEvents < 0 then
        MaxEvents := 0;
      StartIndex := State.RecentEventCount - MaxEvents;
      if StartIndex < 0 then
        StartIndex := 0;
      for I := StartIndex to State.RecentEventCount - 1 do
      begin
        Event := State.GetRecentEvent(I);
        LineText := '  - ' + FormatDebuggerEventLine(Event);
        Lines.Add(LineText);
      end;
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function BuildDebuggerPostmortemReport(const State: TDebuggerState): ansistring;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('Debugger Postmortem');
    if State <> nil then
      Lines.Add('Pause reason: ' + DebuggerPauseReasonName(State.PauseReason))
    else
      Lines.Add('Pause reason: none');
    Lines.Add('');
    Lines.Text := Lines.Text + FormatDebuggerStackTrace(State);
    Lines.Add('');
    Lines.Text := Lines.Text + FormatDebuggerRecentEvents(State);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
