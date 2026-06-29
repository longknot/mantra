unit debugger_inspect;

{$I mantra.inc}

interface

uses
  debugger_types, debugger_state, context;

function FormatDebuggerFrameLine(const Frame: TDebuggerFrame): ansistring;
function FormatDebuggerFrameDetail(
  const Frame: TDebuggerFrame;
  FrameIndex: Integer = -1
): ansistring;
function FormatDebuggerEventLine(const Event: TDebuggerEvent): ansistring;
function FormatDebuggerBreakpointLine(
  const Breakpoint: TDebuggerBreakpoint;
  BreakpointIndex: Integer = -1
): ansistring;
function FormatDebuggerContextSummary(AContext: TContext): ansistring;

implementation

uses
  Classes, SysUtils;

function FormatSourceSuffix(const Source: TDebuggerSourceLocation): ansistring;
begin
  Result := '';
  if not Source.IsKnown then
    Exit;

  if Source.FilePath <> '' then
    Result := Source.FilePath;
  if Source.Line > 0 then
    Result := Result + ':' + IntToStr(Source.Line);
  if Source.Col > 0 then
    Result := Result + ':' + IntToStr(Source.Col);
end;

function FormatDebuggerFrameLine(const Frame: TDebuggerFrame): ansistring;
var
  Parts: ansistring;
begin
  Parts := DebuggerFrameKindName(Frame.Kind);
  if Frame.Name <> '' then
    Parts := Parts + ' ' + Frame.Name;
  if Frame.Summary <> '' then
    Parts := Parts + ' | ' + Frame.Summary;
  if Frame.Step >= 0 then
    Parts := Parts + ' | step=' + IntToStr(Frame.Step);
  if Frame.StateId >= 0 then
    Parts := Parts + ' | state=' + IntToStr(Frame.StateId);
  Result := Parts;
end;

function FormatDebuggerFrameDetail(
  const Frame: TDebuggerFrame;
  FrameIndex: Integer
): ansistring;
var
  Lines: TStringList;
  SourceText: ansistring;
begin
  Lines := TStringList.Create;
  try
    if FrameIndex >= 0 then
      Lines.Add('Frame #' + IntToStr(FrameIndex))
    else
      Lines.Add('Frame');
    Lines.Add('  kind: ' + DebuggerFrameKindName(Frame.Kind));
    if Frame.Name <> '' then
      Lines.Add('  name: ' + Frame.Name);
    if Frame.Summary <> '' then
      Lines.Add('  summary: ' + Frame.Summary);
    if Frame.NodeIndex >= 0 then
      Lines.Add('  node-index: ' + IntToStr(Frame.NodeIndex));
    if Frame.AuxIndex >= 0 then
      Lines.Add('  aux-index: ' + IntToStr(Frame.AuxIndex));
    if Frame.Step >= 0 then
      Lines.Add('  step: ' + IntToStr(Frame.Step));
    if Frame.StateId >= 0 then
      Lines.Add('  state-id: ' + IntToStr(Frame.StateId));
    if Frame.ParentStateId >= 0 then
      Lines.Add('  parent-state-id: ' + IntToStr(Frame.ParentStateId));
    SourceText := FormatSourceSuffix(Frame.Source);
    if SourceText <> '' then
      Lines.Add('  source: ' + SourceText);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function FormatDebuggerEventLine(const Event: TDebuggerEvent): ansistring;
begin
  Result := DebuggerEventKindName(Event.Kind);
  if Event.Frame.Name <> '' then
    Result := Result + ' ' + Event.Frame.Name;
  if Event.MessageText <> '' then
    Result := Result + ' | ' + Event.MessageText;
end;

function FormatDebuggerBreakpointLine(
  const Breakpoint: TDebuggerBreakpoint;
  BreakpointIndex: Integer
): ansistring;
begin
  Result := DebuggerBreakpointKindName(Breakpoint.Kind);
  if Breakpoint.Kind = dbkSource then
  begin
    if Breakpoint.Source.Line > 0 then
      Result := Result + ' ' + FormatDebuggerSourceSpec(Breakpoint.Source);
  end
  else if Breakpoint.Pattern <> '' then
    Result := Result + ' ' + Breakpoint.Pattern;
  if BreakpointIndex >= 0 then
    Result := '[' + IntToStr(BreakpointIndex) + '] ' + Result;
  if not Breakpoint.Enabled then
    Result := Result + ' (disabled)';
end;

function FormatDebuggerContextSummary(AContext: TContext): ansistring;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('Debugger Context:');
    if AContext = nil then
    begin
      Lines.Add('  <none>');
      Exit(Lines.Text);
    end;
    Lines.Add('  namespace: ' + AContext.CurrentNamespace);
    Lines.Add('  rewrite-count: ' + IntToStr(AContext.RewriteCount));
    Lines.Add('  dispatch-count: ' + IntToStr(AContext.DispatchCount));
    Lines.Add('  selection-count: ' + IntToStr(AContext.SelectionCount));
    Lines.Add('  inference-count: ' + IntToStr(AContext.InferenceCount));
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
