unit debugger_types;

{$I mantra.inc}

interface

type
  TDebuggerEventKind = (
    dekUnknown,
    dekStatementEnter,
    dekStatementExit,
    dekEvalScopeEnter,
    dekEvalScopeExit,
    dekCallableDispatchEnter,
    dekCallableDispatchExit,
    dekImportEnter,
    dekImportExit,
    dekRewriteProbe,
    dekRewriteApply,
    dekInferenceStateEnter,
    dekInferenceStateExit,
    dekInferenceCandidate,
    dekVariableWrite,
    dekSettingRead,
    dekSettingWrite,
    dekExceptionRaised
  );

  TDebuggerFrameKind = (
    dfkUnknown,
    dfkStatement,
    dfkEvalScope,
    dfkCallableDispatch,
    dfkRewriteProbe,
    dfkRewriteApply,
    dfkInferenceState,
    dfkImport
  );

  TDebuggerBreakpointKind = (
    dbkUnknown,
    dbkSource,
    dbkStatement,
    dbkCallable,
    dbkRule,
    dbkInference,
    dbkVariableWrite,
    dbkSetting
  );

  TDebuggerPauseReason = (
    dprNone,
    dprBreakpoint,
    dprWatchpoint,
    dprStep,
    dprException,
    dprManual
  );

  TDebuggerSourceLocation = record
    FilePath: ansistring;
    Line: Integer;
    Col: Integer;
    class function Create(
      const AFilePath: ansistring;
      ALine: Integer;
      ACol: Integer
    ): TDebuggerSourceLocation; static;
    function IsKnown: Boolean;
  end;

  TDebuggerFrame = record
    Kind: TDebuggerFrameKind;
    Name: ansistring;
    Summary: ansistring;
    Source: TDebuggerSourceLocation;
    NodeIndex: Integer;
    AuxIndex: Integer;
    Step: Integer;
    StateId: Integer;
    ParentStateId: Integer;
    class function Create(
      AKind: TDebuggerFrameKind;
      const AName: ansistring = '';
      const ASummary: ansistring = '';
      ANodeIndex: Integer = -1;
      AAuxIndex: Integer = -1
    ): TDebuggerFrame; static;
  end;

  TDebuggerEvent = record
    Kind: TDebuggerEventKind;
    Frame: TDebuggerFrame;
    MessageText: ansistring;
    class function Create(
      AKind: TDebuggerEventKind;
      const AFrame: TDebuggerFrame;
      const AMessageText: ansistring = ''
    ): TDebuggerEvent; static;
  end;

  TDebuggerBreakpoint = record
    Kind: TDebuggerBreakpointKind;
    Pattern: ansistring;
    Source: TDebuggerSourceLocation;
    Enabled: Boolean;
    class function Create(
      AKind: TDebuggerBreakpointKind;
      const APattern: ansistring = ''
    ): TDebuggerBreakpoint; static;
  end;

function DebuggerEventKindName(AKind: TDebuggerEventKind): ansistring;
function DebuggerFrameKindName(AKind: TDebuggerFrameKind): ansistring;
function DebuggerBreakpointKindName(AKind: TDebuggerBreakpointKind): ansistring;
function DebuggerPauseReasonName(AReason: TDebuggerPauseReason): ansistring;
function TryParseDebuggerSourceSpec(
  const Spec: ansistring;
  out Location: TDebuggerSourceLocation
): Boolean;
function FormatDebuggerSourceSpec(const Location: TDebuggerSourceLocation): ansistring;

implementation

uses
  SysUtils;

function TryParseNonNegativeInteger(const ValueText: ansistring; out Value: Integer): Boolean;
var
  Code: Integer;
begin
  Val(Trim(ValueText), Value, Code);
  Result := (Code = 0) and (Value >= 0);
end;

function TrySplitLastColon(
  const S: ansistring;
  out LeftPart: ansistring;
  out RightPart: ansistring
): Boolean;
var
  P: Integer;
begin
  P := Length(S);
  while (P > 0) and (S[P] <> ':') do
    Dec(P);
  if P <= 0 then
    Exit(False);
  LeftPart := Trim(Copy(S, 1, P - 1));
  RightPart := Trim(Copy(S, P + 1, MaxInt));
  Result := True;
end;

class function TDebuggerSourceLocation.Create(
  const AFilePath: ansistring;
  ALine: Integer;
  ACol: Integer
): TDebuggerSourceLocation;
begin
  Result.FilePath := AFilePath;
  Result.Line := ALine;
  Result.Col := ACol;
end;

function TDebuggerSourceLocation.IsKnown: Boolean;
begin
  Result := (FilePath <> '') or (Line > 0) or (Col > 0);
end;

class function TDebuggerFrame.Create(
  AKind: TDebuggerFrameKind;
  const AName: ansistring;
  const ASummary: ansistring;
  ANodeIndex: Integer;
  AAuxIndex: Integer
): TDebuggerFrame;
begin
  Result.Kind := AKind;
  Result.Name := AName;
  Result.Summary := ASummary;
  Result.Source := TDebuggerSourceLocation.Create('', 0, 0);
  Result.NodeIndex := ANodeIndex;
  Result.AuxIndex := AAuxIndex;
  Result.Step := -1;
  Result.StateId := -1;
  Result.ParentStateId := -1;
end;

class function TDebuggerEvent.Create(
  AKind: TDebuggerEventKind;
  const AFrame: TDebuggerFrame;
  const AMessageText: ansistring
): TDebuggerEvent;
begin
  Result.Kind := AKind;
  Result.Frame := AFrame;
  Result.MessageText := AMessageText;
end;

class function TDebuggerBreakpoint.Create(
  AKind: TDebuggerBreakpointKind;
  const APattern: ansistring
): TDebuggerBreakpoint;
begin
  Result.Kind := AKind;
  Result.Pattern := APattern;
  Result.Source := TDebuggerSourceLocation.Create('', 0, 0);
  Result.Enabled := True;
end;

function DebuggerEventKindName(AKind: TDebuggerEventKind): ansistring;
begin
  case AKind of
    dekStatementEnter: Result := 'statement-enter';
    dekStatementExit: Result := 'statement-exit';
    dekEvalScopeEnter: Result := 'eval-enter';
    dekEvalScopeExit: Result := 'eval-exit';
    dekCallableDispatchEnter: Result := 'dispatch-enter';
    dekCallableDispatchExit: Result := 'dispatch-exit';
    dekImportEnter: Result := 'import-enter';
    dekImportExit: Result := 'import-exit';
    dekRewriteProbe: Result := 'rewrite-probe';
    dekRewriteApply: Result := 'rewrite-apply';
    dekInferenceStateEnter: Result := 'inference-state-enter';
    dekInferenceStateExit: Result := 'inference-state-exit';
    dekInferenceCandidate: Result := 'inference-candidate';
    dekVariableWrite: Result := 'variable-write';
    dekSettingRead: Result := 'setting-read';
    dekSettingWrite: Result := 'setting-write';
    dekExceptionRaised: Result := 'exception';
  else
    Result := 'unknown';
  end;
end;

function DebuggerFrameKindName(AKind: TDebuggerFrameKind): ansistring;
begin
  case AKind of
    dfkStatement: Result := 'statement';
    dfkEvalScope: Result := 'eval';
    dfkCallableDispatch: Result := 'dispatch';
    dfkRewriteProbe: Result := 'rewrite-probe';
    dfkRewriteApply: Result := 'rewrite-apply';
    dfkInferenceState: Result := 'inference-state';
    dfkImport: Result := 'import';
  else
    Result := 'unknown';
  end;
end;

function DebuggerBreakpointKindName(AKind: TDebuggerBreakpointKind): ansistring;
begin
  case AKind of
    dbkSource: Result := 'source';
    dbkStatement: Result := 'statement';
    dbkCallable: Result := 'callable';
    dbkRule: Result := 'rule';
    dbkInference: Result := 'inference';
    dbkVariableWrite: Result := 'variable-write';
    dbkSetting: Result := 'setting';
  else
    Result := 'unknown';
  end;
end;

function DebuggerPauseReasonName(AReason: TDebuggerPauseReason): ansistring;
begin
  case AReason of
    dprBreakpoint: Result := 'breakpoint';
    dprWatchpoint: Result := 'watchpoint';
    dprStep: Result := 'step';
    dprException: Result := 'exception';
    dprManual: Result := 'manual';
  else
    Result := 'none';
  end;
end;

function TryParseDebuggerSourceSpec(
  const Spec: ansistring;
  out Location: TDebuggerSourceLocation
): Boolean;
var
  Trimmed: ansistring;
  LeftPart, RightPart: ansistring;
  FilePart: ansistring;
  NestedLeftPart, NestedRightPart: ansistring;
  LineValue, ColValue: Integer;
begin
  Location := TDebuggerSourceLocation.Create('', 0, 0);
  Trimmed := Trim(Spec);
  if Trimmed = '' then
    Exit(False);

  if TryParseNonNegativeInteger(Trimmed, LineValue) then
  begin
    if LineValue <= 0 then
      Exit(False);
    Location.Line := LineValue;
    Exit(True);
  end;

  if not TrySplitLastColon(Trimmed, LeftPart, RightPart) then
    Exit(False);
  if not TryParseNonNegativeInteger(RightPart, LineValue) then
    Exit(False);
  if LineValue <= 0 then
    Exit(False);

  FilePart := LeftPart;
  ColValue := 0;

  if TrySplitLastColon(LeftPart, NestedLeftPart, NestedRightPart) and
     TryParseNonNegativeInteger(NestedRightPart, LineValue) then
  begin
    FilePart := NestedLeftPart;
    if LineValue <= 0 then
      Exit(False);
    if not TryParseNonNegativeInteger(RightPart, ColValue) then
      Exit(False);
    if ColValue <= 0 then
      Exit(False);
  end
  else
  begin
    if not TryParseNonNegativeInteger(RightPart, LineValue) then
      Exit(False);
    if LineValue <= 0 then
      Exit(False);
  end;

  FilePart := Trim(FilePart);
  if FilePart = '' then
    Exit(False);

  Location.FilePath := FilePart;
  Location.Line := LineValue;
  Location.Col := ColValue;
  Result := True;
end;

function FormatDebuggerSourceSpec(const Location: TDebuggerSourceLocation): ansistring;
begin
  Result := '';
  if Location.FilePath <> '' then
    Result := Location.FilePath;
  if Location.Line > 0 then
    Result := Result + ':' + IntToStr(Location.Line);
  if Location.Col > 0 then
    Result := Result + ':' + IntToStr(Location.Col);
  if (Location.FilePath = '') and (Location.Line > 0) then
    Result := IntToStr(Location.Line);
end;

end.
