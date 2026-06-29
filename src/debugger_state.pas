unit debugger_state;

{$I mantra.inc}

interface

uses
  debugger_types, debugger_api;

type
  TDebuggerStepMode = (
    dsmNone,
    dsmStep,
    dsmNext,
    dsmFinish
  );

  TDebuggerState = class(TDebuggerSink)
  private
    FFrames: array of TDebuggerFrame;
    FBreakpoints: array of TDebuggerBreakpoint;
    FRecentEvents: array of TDebuggerEvent;
    FRecentEventLimit: Integer;
    FPauseReason: TDebuggerPauseReason;
    FPausePending: Boolean;
    FPauseEvent: TDebuggerEvent;
    FPauseMessage: ansistring;
    FStepMode: TDebuggerStepMode;
    FStepFrameDepth: Integer;
    FStepStatementDepth: Integer;
    FStepSourceFile: ansistring;
    function WildcardMatch(const Pattern, Text: ansistring): Boolean;
    function ComposeInferenceBreakpointText(const Event: TDebuggerEvent): ansistring;
    function BreakpointMatches(
      const Breakpoint: TDebuggerBreakpoint;
      const Event: TDebuggerEvent
    ): Boolean;
    function CurrentStatementDepth: Integer;
    function EventMatchesFinishStop(const Event: TDebuggerEvent): Boolean;
    function EventMatchesNextStop(const Event: TDebuggerEvent): Boolean;
    function EventMatchesStepStop(const Event: TDebuggerEvent): Boolean;
    procedure MaybeTriggerBreakpoint(const Event: TDebuggerEvent);
    procedure MaybeTriggerStep(const Event: TDebuggerEvent);
    procedure PushFrame(const Frame: TDebuggerFrame);
    procedure PopFrame(Kind: TDebuggerFrameKind);
    procedure RecordEvent(const Event: TDebuggerEvent);
    procedure SetRecentEventLimit(Value: Integer);
    function EventBeginsFrame(AKind: TDebuggerEventKind): Boolean;
    function EventEndsFrame(AKind: TDebuggerEventKind): Boolean;
    procedure ClearStepPlan;
  public
    constructor Create;
    procedure HandleEvent(const Event: TDebuggerEvent); override;
    procedure Clear;
    procedure AddBreakpoint(const Breakpoint: TDebuggerBreakpoint);
    procedure ClearBreakpoints;
    function FrameCount: Integer;
    function GetFrame(Index: Integer): TDebuggerFrame;
    function TryGetTopFrame(out Frame: TDebuggerFrame): Boolean;
    function BreakpointCount: Integer;
    function GetBreakpoint(Index: Integer): TDebuggerBreakpoint;
    procedure DeleteBreakpoint(Index: Integer);
    function RecentEventCount: Integer;
    function GetRecentEvent(Index: Integer): TDebuggerEvent;
    function PausePending: Boolean;
    procedure ClearPause;
    procedure RequestFinish;
    procedure RequestNext;
    procedure RequestStep;
    function TryGetDisplayLocation(out Location: TDebuggerSourceLocation): Boolean;
    function TryGetPauseEvent(out Event: TDebuggerEvent): Boolean;
    property PauseMessage: ansistring read FPauseMessage;
    property PauseReason: TDebuggerPauseReason read FPauseReason write FPauseReason;
    property RecentEventLimit: Integer read FRecentEventLimit write SetRecentEventLimit;
  end;

implementation

uses
  SysUtils;

constructor TDebuggerState.Create;
begin
  inherited Create;
  FRecentEventLimit := 256;
  FPauseReason := dprNone;
  FPausePending := False;
  FPauseEvent := TDebuggerEvent.Create(dekUnknown, TDebuggerFrame.Create(dfkUnknown));
  FPauseMessage := '';
  ClearStepPlan;
end;

function TDebuggerState.WildcardMatch(const Pattern, Text: ansistring): Boolean;
var
  PatternIndex: Integer;
  TextIndex: Integer;
  StarIndex: Integer;
  MatchIndex: Integer;
begin
  PatternIndex := 1;
  TextIndex := 1;
  StarIndex := 0;
  MatchIndex := 0;

  while TextIndex <= Length(Text) do
  begin
    if (PatternIndex <= Length(Pattern)) and
       ((Pattern[PatternIndex] = '?') or (Pattern[PatternIndex] = Text[TextIndex])) then
    begin
      Inc(PatternIndex);
      Inc(TextIndex);
    end
    else if (PatternIndex <= Length(Pattern)) and (Pattern[PatternIndex] = '*') then
    begin
      StarIndex := PatternIndex;
      MatchIndex := TextIndex;
      Inc(PatternIndex);
    end
    else if StarIndex <> 0 then
    begin
      PatternIndex := StarIndex + 1;
      Inc(MatchIndex);
      TextIndex := MatchIndex;
    end
    else
      Exit(False);
  end;

  while (PatternIndex <= Length(Pattern)) and (Pattern[PatternIndex] = '*') do
    Inc(PatternIndex);
  Result := PatternIndex > Length(Pattern);
end;

function TDebuggerState.ComposeInferenceBreakpointText(
  const Event: TDebuggerEvent
): ansistring;
begin
  Result := '';
  if Event.Frame.Name <> '' then
    Result := Event.Frame.Name;
  if Event.MessageText <> '' then
  begin
    if Result <> '' then
      Result := Result + ' | ';
    Result := Result + Event.MessageText;
  end;
  if Event.Frame.Summary <> '' then
  begin
    if Result <> '' then
      Result := Result + ' | ';
    Result := Result + Event.Frame.Summary;
  end;
  if Event.Frame.Step >= 0 then
  begin
    if Result <> '' then
      Result := Result + ' | ';
    Result := Result + 'step=' + IntToStr(Event.Frame.Step);
  end;
  if Event.Frame.StateId >= 0 then
  begin
    if Result <> '' then
      Result := Result + ' | ';
    Result := Result + 'state=' + IntToStr(Event.Frame.StateId);
  end;
end;

function TDebuggerState.BreakpointMatches(
  const Breakpoint: TDebuggerBreakpoint;
  const Event: TDebuggerEvent
): Boolean;
var
  TargetText: ansistring;
  EventFilePath: ansistring;
  FileMatched: Boolean;
begin
  Result := False;
  if not Breakpoint.Enabled then
    Exit(False);

  case Breakpoint.Kind of
    dbkStatement:
      begin
        if Event.Kind <> dekStatementEnter then
          Exit(False);
        TargetText := Event.Frame.Summary;
      end;
    dbkCallable:
      begin
        if Event.Kind <> dekCallableDispatchEnter then
          Exit(False);
        TargetText := Event.Frame.Name;
      end;
    dbkRule:
      begin
        if Event.Kind <> dekRewriteProbe then
          Exit(False);
        TargetText := Event.Frame.Name;
      end;
    dbkInference:
      begin
        if Event.Kind <> dekInferenceStateEnter then
          Exit(False);
        TargetText := ComposeInferenceBreakpointText(Event);
      end;
    dbkSource:
      begin
        if Event.Kind <> dekStatementEnter then
          Exit(False);
        if Breakpoint.Source.Line <= 0 then
          Exit(False);
        if Event.Frame.Source.Line <> Breakpoint.Source.Line then
          Exit(False);
        if (Breakpoint.Source.Col > 0) and
           (Event.Frame.Source.Col <> Breakpoint.Source.Col) then
          Exit(False);
        if Breakpoint.Source.FilePath <> '' then
        begin
          EventFilePath := Event.Frame.Source.FilePath;
          if EventFilePath = '' then
            Exit(False);
          FileMatched := WildcardMatch(Breakpoint.Source.FilePath, EventFilePath) or
                         WildcardMatch(Breakpoint.Source.FilePath, ExtractFileName(EventFilePath));
          if not FileMatched then
            Exit(False);
        end;
        Exit(True);
      end;
  else
    Exit(False);
  end;

  if Breakpoint.Pattern = '' then
    Exit(False);
  Result := WildcardMatch(Breakpoint.Pattern, TargetText);
end;

procedure TDebuggerState.MaybeTriggerBreakpoint(const Event: TDebuggerEvent);
var
  I: Integer;
begin
  if FPausePending then
    Exit;

  for I := 0 to High(FBreakpoints) do
    if BreakpointMatches(FBreakpoints[I], Event) then
    begin
      ClearStepPlan;
      FPausePending := True;
      FPauseReason := dprBreakpoint;
      FPauseEvent := Event;
      if FBreakpoints[I].Kind = dbkSource then
        FPauseMessage := DebuggerBreakpointKindName(FBreakpoints[I].Kind) +
                         ' ' + FormatDebuggerSourceSpec(FBreakpoints[I].Source)
      else
        FPauseMessage := DebuggerBreakpointKindName(FBreakpoints[I].Kind) +
                         ' ' + FBreakpoints[I].Pattern;
      Exit;
    end;
end;

function TDebuggerState.CurrentStatementDepth: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FFrames) do
    if FFrames[I].Kind = dfkStatement then
      Inc(Result);
end;

function TDebuggerState.EventMatchesFinishStop(const Event: TDebuggerEvent): Boolean;
begin
  if FStepFrameDepth <= 0 then
    Exit(EventMatchesStepStop(Event));
  Result := FrameCount < FStepFrameDepth;
end;

function TDebuggerState.EventMatchesNextStop(const Event: TDebuggerEvent): Boolean;
begin
  if Event.Kind <> dekStatementEnter then
    Exit(False);
  if (FStepSourceFile <> '') and
     (Event.Frame.Source.FilePath <> '') and
     (Event.Frame.Source.FilePath <> FStepSourceFile) then
    Exit(False);
  Result := CurrentStatementDepth <= FStepStatementDepth;
end;

function TDebuggerState.EventMatchesStepStop(const Event: TDebuggerEvent): Boolean;
begin
  case Event.Kind of
    dekStatementEnter,
    dekEvalScopeEnter,
    dekCallableDispatchEnter,
    dekImportEnter,
    dekRewriteProbe,
    dekInferenceStateEnter:
      Result := True;
  else
    Result := False;
  end;
end;

procedure TDebuggerState.MaybeTriggerStep(const Event: TDebuggerEvent);
var
  Matched: Boolean;
begin
  if FPausePending or (FStepMode = dsmNone) then
    Exit;

  case FStepMode of
    dsmStep:
      Matched := EventMatchesStepStop(Event);
    dsmNext:
      Matched := EventMatchesNextStop(Event);
    dsmFinish:
      Matched := EventMatchesFinishStop(Event);
  else
    Matched := False;
  end;

  if not Matched then
    Exit;

  ClearStepPlan;
  FPausePending := True;
  FPauseReason := dprStep;
  FPauseEvent := Event;
  FPauseMessage := DebuggerEventKindName(Event.Kind);
end;

procedure TDebuggerState.PushFrame(const Frame: TDebuggerFrame);
var
  L: Integer;
begin
  L := Length(FFrames);
  SetLength(FFrames, L + 1);
  FFrames[L] := Frame;
end;

procedure TDebuggerState.PopFrame(Kind: TDebuggerFrameKind);
var
  I: Integer;
begin
  for I := High(FFrames) downto 0 do
    if FFrames[I].Kind = Kind then
    begin
      SetLength(FFrames, I);
      Exit;
    end;
end;

procedure TDebuggerState.RecordEvent(const Event: TDebuggerEvent);
var
  L: Integer;
  I: Integer;
begin
  if FRecentEventLimit <= 0 then
    Exit;

  L := Length(FRecentEvents);
  if L >= FRecentEventLimit then
  begin
    for I := 1 to L - 1 do
      FRecentEvents[I - 1] := FRecentEvents[I];
    Dec(L);
    SetLength(FRecentEvents, L);
  end;

  SetLength(FRecentEvents, L + 1);
  FRecentEvents[L] := Event;
end;

procedure TDebuggerState.SetRecentEventLimit(Value: Integer);
var
  RemoveCount: Integer;
  I: Integer;
begin
  if Value < 0 then
    Value := 0;
  FRecentEventLimit := Value;
  if Length(FRecentEvents) <= FRecentEventLimit then
    Exit;
  RemoveCount := Length(FRecentEvents) - FRecentEventLimit;
  for I := RemoveCount to High(FRecentEvents) do
    FRecentEvents[I - RemoveCount] := FRecentEvents[I];
  SetLength(FRecentEvents, FRecentEventLimit);
end;

function TDebuggerState.EventBeginsFrame(AKind: TDebuggerEventKind): Boolean;
begin
  case AKind of
    dekStatementEnter,
    dekEvalScopeEnter,
    dekCallableDispatchEnter,
    dekImportEnter,
    dekInferenceStateEnter:
      Result := True;
  else
    Result := False;
  end;
end;

function TDebuggerState.EventEndsFrame(AKind: TDebuggerEventKind): Boolean;
begin
  case AKind of
    dekStatementExit,
    dekEvalScopeExit,
    dekCallableDispatchExit,
    dekImportExit,
    dekInferenceStateExit:
      Result := True;
  else
    Result := False;
  end;
end;

procedure TDebuggerState.HandleEvent(const Event: TDebuggerEvent);
begin
  if EventBeginsFrame(Event.Kind) then
    PushFrame(Event.Frame)
  else if EventEndsFrame(Event.Kind) then
    PopFrame(Event.Frame.Kind);

  RecordEvent(Event);
  if Event.Kind = dekExceptionRaised then
  begin
    ClearStepPlan;
    FPauseReason := dprException;
    FPauseEvent := Event;
    FPauseMessage := Event.MessageText;
  end
  else
  begin
    MaybeTriggerBreakpoint(Event);
    MaybeTriggerStep(Event);
  end;
end;

procedure TDebuggerState.Clear;
begin
  SetLength(FFrames, 0);
  SetLength(FRecentEvents, 0);
  FPauseReason := dprNone;
  FPausePending := False;
  FPauseEvent := TDebuggerEvent.Create(dekUnknown, TDebuggerFrame.Create(dfkUnknown));
  FPauseMessage := '';
  ClearStepPlan;
end;

procedure TDebuggerState.AddBreakpoint(const Breakpoint: TDebuggerBreakpoint);
var
  L: Integer;
begin
  L := Length(FBreakpoints);
  SetLength(FBreakpoints, L + 1);
  FBreakpoints[L] := Breakpoint;
end;

procedure TDebuggerState.ClearBreakpoints;
begin
  SetLength(FBreakpoints, 0);
end;

function TDebuggerState.FrameCount: Integer;
begin
  Result := Length(FFrames);
end;

function TDebuggerState.GetFrame(Index: Integer): TDebuggerFrame;
begin
  Result := FFrames[Index];
end;

function TDebuggerState.TryGetTopFrame(out Frame: TDebuggerFrame): Boolean;
begin
  Result := Length(FFrames) > 0;
  if Result then
    Frame := FFrames[High(FFrames)]
  else
    Frame := TDebuggerFrame.Create(dfkUnknown);
end;

function TDebuggerState.BreakpointCount: Integer;
begin
  Result := Length(FBreakpoints);
end;

function TDebuggerState.GetBreakpoint(Index: Integer): TDebuggerBreakpoint;
begin
  Result := FBreakpoints[Index];
end;

procedure TDebuggerState.DeleteBreakpoint(Index: Integer);
var
  I: Integer;
begin
  if (Index < 0) or (Index >= Length(FBreakpoints)) then
    Exit;
  for I := Index + 1 to High(FBreakpoints) do
    FBreakpoints[I - 1] := FBreakpoints[I];
  SetLength(FBreakpoints, Length(FBreakpoints) - 1);
end;

function TDebuggerState.RecentEventCount: Integer;
begin
  Result := Length(FRecentEvents);
end;

function TDebuggerState.GetRecentEvent(Index: Integer): TDebuggerEvent;
begin
  Result := FRecentEvents[Index];
end;

function TDebuggerState.PausePending: Boolean;
begin
  Result := FPausePending;
end;

procedure TDebuggerState.ClearPause;
begin
  FPausePending := False;
  if FPauseReason <> dprException then
  begin
    FPauseReason := dprNone;
    FPauseMessage := '';
    FPauseEvent := TDebuggerEvent.Create(dekUnknown, TDebuggerFrame.Create(dfkUnknown));
  end;
end;

procedure TDebuggerState.ClearStepPlan;
begin
  FStepMode := dsmNone;
  FStepFrameDepth := 0;
  FStepStatementDepth := 0;
  FStepSourceFile := '';
end;

procedure TDebuggerState.RequestFinish;
var
  PauseEvent: TDebuggerEvent;
begin
  FStepMode := dsmFinish;
  FStepFrameDepth := FrameCount;
  FStepStatementDepth := CurrentStatementDepth;
  FStepSourceFile := '';
  if TryGetPauseEvent(PauseEvent) then
    FStepSourceFile := PauseEvent.Frame.Source.FilePath;
end;

procedure TDebuggerState.RequestNext;
var
  PauseEvent: TDebuggerEvent;
begin
  FStepMode := dsmNext;
  FStepFrameDepth := FrameCount;
  FStepStatementDepth := CurrentStatementDepth;
  FStepSourceFile := '';
  if TryGetPauseEvent(PauseEvent) then
    FStepSourceFile := PauseEvent.Frame.Source.FilePath;
end;

procedure TDebuggerState.RequestStep;
begin
  FStepMode := dsmStep;
  FStepFrameDepth := FrameCount;
  FStepStatementDepth := CurrentStatementDepth;
  FStepSourceFile := '';
end;

function TDebuggerState.TryGetDisplayLocation(
  out Location: TDebuggerSourceLocation
): Boolean;
var
  I: Integer;
begin
  for I := High(FFrames) downto 0 do
    if FFrames[I].Source.IsKnown then
    begin
      Location := FFrames[I].Source;
      Exit(True);
    end;

  if FPauseEvent.Frame.Source.IsKnown then
  begin
    Location := FPauseEvent.Frame.Source;
    Exit(True);
  end;

  Location := TDebuggerSourceLocation.Create('', 0, 0);
  Result := False;
end;

function TDebuggerState.TryGetPauseEvent(out Event: TDebuggerEvent): Boolean;
begin
  Result := FPauseEvent.Kind <> dekUnknown;
  if Result then
    Event := FPauseEvent
  else
    Event := TDebuggerEvent.Create(dekUnknown, TDebuggerFrame.Create(dfkUnknown));
end;

end.
