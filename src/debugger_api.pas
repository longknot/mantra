unit debugger_api;

{$I mantra.inc}

interface

uses
  debugger_types;

type
  TDebuggerSink = class
  public
    procedure HandleEvent(const Event: TDebuggerEvent); virtual; abstract;
  end;

procedure SetDebuggerSink(ASink: TDebuggerSink);
function GetDebuggerSink: TDebuggerSink;
procedure ClearDebuggerSink;
function DebuggerAttached: Boolean;
procedure EmitDebuggerEvent(const Event: TDebuggerEvent); overload;
procedure EmitDebuggerEvent(
  AKind: TDebuggerEventKind;
  const Frame: TDebuggerFrame;
  const MessageText: ansistring = ''
); overload;

implementation

var
  ActiveDebuggerSink: TDebuggerSink = nil;

procedure SetDebuggerSink(ASink: TDebuggerSink);
begin
  ActiveDebuggerSink := ASink;
end;

function GetDebuggerSink: TDebuggerSink;
begin
  Result := ActiveDebuggerSink;
end;

procedure ClearDebuggerSink;
begin
  ActiveDebuggerSink := nil;
end;

function DebuggerAttached: Boolean;
begin
  Result := Assigned(ActiveDebuggerSink);
end;

procedure EmitDebuggerEvent(const Event: TDebuggerEvent);
begin
  if Assigned(ActiveDebuggerSink) then
    ActiveDebuggerSink.HandleEvent(Event);
end;

procedure EmitDebuggerEvent(
  AKind: TDebuggerEventKind;
  const Frame: TDebuggerFrame;
  const MessageText: ansistring
);
begin
  EmitDebuggerEvent(TDebuggerEvent.Create(AKind, Frame, MessageText));
end;

end.
