unit debugger_cli;

{$I mantra.inc}

interface

uses
  debugger_state, context;

procedure RunDebuggerCommandLoop(const State: TDebuggerState; AContext: TContext);

implementation

uses
  SysUtils, BaseUnix, Classes, debugger_postmortem, debugger_inspect,
  debugger_types, nodes, exp_trees;

const
  DEFAULT_INSPECT_VARIABLE_LIMIT = 64;
  DEFAULT_INSPECT_SETTING_LIMIT = 32;
  DEFAULT_INSPECT_EVENT_LIMIT = 16;
  INSPECT_SETTINGS_ROOT = 'mantra';

type
  TInspectDomain = (
    idUnknown,
    idVars,
    idSettings
  );

function IsInteractiveInput: Boolean;
var
  St: Stat;
begin
  Result := False;
  if fpFStat(TextRec(Input).Handle, St) <> 0 then
    Exit(False);
  Result := FPS_ISCHR(St.st_mode);
end;

function SplitDebuggerCommand(
  const Line: ansistring;
  out CommandName: ansistring;
  out ArgText: ansistring
): Boolean;
var
  P: Integer;
  Trimmed: ansistring;
begin
  Trimmed := Trim(Line);
  if Trimmed = '' then
  begin
    CommandName := '';
    ArgText := '';
    Exit(False);
  end;

  P := Pos(' ', Trimmed);
  if P <= 0 then
  begin
    CommandName := LowerCase(Trimmed);
    ArgText := '';
  end
  else
  begin
    CommandName := LowerCase(Trim(Copy(Trimmed, 1, P - 1)));
    ArgText := Trim(Copy(Trimmed, P + 1, MaxInt));
  end;
  Result := True;
end;

function TryParsePositiveInt(const S: ansistring; out Value: Integer): Boolean;
var
  Code: Integer;
begin
  Val(Trim(S), Value, Code);
  Result := (Code = 0) and (Value >= 0);
end;

function TryGetFrameByTopIndex(
  const State: TDebuggerState;
  TopIndex: Integer;
  out Frame: TDebuggerFrame
): Boolean;
var
  RawIndex: Integer;
begin
  Result := False;
  if (State = nil) or (TopIndex < 0) then
    Exit;
  RawIndex := State.FrameCount - 1 - TopIndex;
  if (RawIndex < 0) or (RawIndex >= State.FrameCount) then
    Exit;
  Frame := State.GetFrame(RawIndex);
  Result := True;
end;

procedure PrintDebuggerBreakpoints(const State: TDebuggerState);
var
  I: Integer;
begin
  WriteLn('Breakpoints:');
  if (State = nil) or (State.BreakpointCount = 0) then
  begin
    WriteLn('  <none>');
    Exit;
  end;
  for I := 0 to State.BreakpointCount - 1 do
    WriteLn('  ' + FormatDebuggerBreakpointLine(State.GetBreakpoint(I), I));
end;

function SanitizeInspectValue(const Value: ansistring): ansistring;
begin
  Result := Value;
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

function InspectDomainName(const Domain: TInspectDomain): ansistring;
begin
  case Domain of
    idVars: Result := 'vars';
    idSettings: Result := 'settings';
  else
    Result := 'unknown';
  end;
end;

function TryParseInspectDomain(
  const Text: ansistring;
  out Domain: TInspectDomain
): Boolean;
var
  Lowered: ansistring;
begin
  Lowered := LowerCase(Trim(Text));
  if Lowered = 'vars' then
    Domain := idVars
  else if Lowered = 'settings' then
    Domain := idSettings
  else
    Domain := idUnknown;
  Result := Domain <> idUnknown;
end;

function BoolText(const Value: Boolean): ansistring;
begin
  if Value then
    Result := '1'
  else
    Result := '0';
end;

function HasPathPrefix(const PathText, Prefix: ansistring): Boolean;
begin
  Result := Copy(PathText, 1, Length(Prefix)) = Prefix;
  if not Result then
    Exit(False);
  if Length(PathText) = Length(Prefix) then
    Exit(True);
  Result := (PathText[Length(Prefix) + 1] = '.') or
            (PathText[Length(Prefix) + 1] = '[');
end;

function IsSettingQueryPath(const Query: ansistring): Boolean;
var
  Trimmed: ansistring;
begin
  Trimmed := Trim(Query);
  if Trimmed = '' then
    Exit(True);
  Result := HasPathPrefix(Trimmed, INSPECT_SETTINGS_ROOT);
end;

function ExtractImmediateChildSegment(
  const Prefix: ansistring;
  const ChildPath: ansistring
): ansistring;
begin
  Result := ChildPath;
  if Prefix = '' then
    Exit;
  if (Length(ChildPath) <= Length(Prefix)) or
     (Copy(ChildPath, 1, Length(Prefix)) <> Prefix) then
    Exit;
  Result := Copy(ChildPath, Length(Prefix) + 1, MaxInt);
  if (Result <> '') and (Result[1] = '.') then
    Delete(Result, 1, 1);
end;

function RenderInspectPreview(ValueRef: Integer): ansistring;
begin
  Result := '';
  if ValueRef = EOT then
    Exit;
  try
    Result := nodes.GetNode(ValueRef).TreeValue;
  except
    on E: Exception do
      Result := '<error: ' + E.Message + '>';
  end;
end;

procedure WriteInspectProtocolField(
  const Prefix: ansistring;
  const Key: ansistring;
  const Value: ansistring
);
begin
  WriteLn(
    Prefix + #9 +
    Key + #9 +
    SanitizeInspectValue(Value)
  );
end;

procedure WriteInspectProtocolChild(
  const Prefix: ansistring;
  const Segment: ansistring;
  const PathText: ansistring;
  const ResolvedPath: ansistring;
  Ref: Integer;
  HasChildren: Boolean;
  const Preview: ansistring
);
begin
  WriteLn(
    Prefix + #9 +
    'child' + #9 +
    SanitizeInspectValue(Segment) + #9 +
    SanitizeInspectValue(PathText) + #9 +
    SanitizeInspectValue(ResolvedPath) + #9 +
    IntToStr(Ref) + #9 +
    BoolText(HasChildren) + #9 +
    SanitizeInspectValue(Preview)
  );
end;

function TryResolveInspectValueRef(
  const Domain: TInspectDomain;
  const Query: ansistring;
  AContext: TContext;
  out ResolvedName: ansistring;
  out ValueRef: Integer
): Boolean;
var
  TrimmedQuery: ansistring;
begin
  ResolvedName := '';
  ValueRef := EOT;
  if AContext = nil then
    Exit(False);

  TrimmedQuery := Trim(Query);
  if (Domain = idSettings) and (not IsSettingQueryPath(TrimmedQuery)) then
    Exit(False);

  case Domain of
    idVars:
      Result := AContext.TryFindVariableResolved(
        TrimmedQuery,
        ResolvedName,
        ValueRef
      );
    idSettings:
      Result := AContext.TryFindSettingVariable(
        TrimmedQuery,
        ResolvedName,
        ValueRef
      );
  else
    Result := False;
  end;
end;

function CollectInspectChildren(
  const Domain: TInspectDomain;
  const Query: ansistring;
  AContext: TContext;
  Matches: TStrings
): SizeInt;
var
  TrimmedQuery: ansistring;
  ProbeChildren: TStringList;
  ResolvedName: ansistring;
  ValueRef: Integer;
begin
  Result := 0;
  if (AContext = nil) or (Matches = nil) then
    Exit;

  Matches.Clear;
  TrimmedQuery := Trim(Query);

  case Domain of
    idVars:
      Result := AContext.ScanVariableChildren(TrimmedQuery, Matches);
    idSettings:
      begin
        if TrimmedQuery = '' then
        begin
          ProbeChildren := TStringList.Create;
          try
            if TryResolveInspectValueRef(
                 idSettings,
                 INSPECT_SETTINGS_ROOT,
                 AContext,
                 ResolvedName,
                 ValueRef
               ) or
               (AContext.ScanVariableChildren(INSPECT_SETTINGS_ROOT, ProbeChildren) > 0) then
            begin
              Matches.Add(INSPECT_SETTINGS_ROOT);
              Result := 1;
            end;
          finally
            ProbeChildren.Free;
          end;
        end
        else if IsSettingQueryPath(TrimmedQuery) then
          Result := AContext.ScanVariableChildren(TrimmedQuery, Matches);
      end;
  end;
end;

function HasInspectChildren(
  const Domain: TInspectDomain;
  const Query: ansistring;
  AContext: TContext
): Boolean;
var
  Matches: TStringList;
begin
  Matches := TStringList.Create;
  try
    Result := CollectInspectChildren(Domain, Query, AContext, Matches) > 0;
  finally
    Matches.Free;
  end;
end;

procedure WriteInspectField(
  const GroupName: ansistring;
  const Key: ansistring;
  const Value: ansistring
);
begin
  WriteLn(
    '@inspect' + #9 +
    GroupName + #9 +
    Key + #9 +
    SanitizeInspectValue(Value)
  );
end;

procedure WriteInspectItem(
  const GroupName: ansistring;
  const NameText: ansistring;
  Ref: Integer
);
begin
  WriteLn(
    '@inspect' + #9 +
    GroupName + #9 +
    SanitizeInspectValue(NameText) + #9 +
    IntToStr(Ref)
  );
end;

procedure WriteInspectFrame(const State: TDebuggerState);
var
  Frame: TDebuggerFrame;
begin
  if (State = nil) or (not TryGetFrameByTopIndex(State, 0, Frame)) then
  begin
    WriteInspectField('frame', 'present', '0');
    Exit;
  end;

  WriteInspectField('frame', 'present', '1');
  WriteInspectField('frame', 'kind', DebuggerFrameKindName(Frame.Kind));
  if Frame.Name <> '' then
    WriteInspectField('frame', 'name', Frame.Name);
  if Frame.Summary <> '' then
    WriteInspectField('frame', 'summary', Frame.Summary);
  if Frame.Source.FilePath <> '' then
    WriteInspectField('frame', 'source-file', ExtractFileName(Frame.Source.FilePath));
  if Frame.Source.Line > 0 then
    WriteInspectField('frame', 'source-line', IntToStr(Frame.Source.Line));
  if Frame.Source.Col > 0 then
    WriteInspectField('frame', 'source-col', IntToStr(Frame.Source.Col));
  if Frame.NodeIndex >= 0 then
    WriteInspectField('frame', 'node-index', IntToStr(Frame.NodeIndex));
  if Frame.AuxIndex >= 0 then
    WriteInspectField('frame', 'aux-index', IntToStr(Frame.AuxIndex));
  if Frame.Step >= 0 then
    WriteInspectField('frame', 'step', IntToStr(Frame.Step));
  if Frame.StateId >= 0 then
    WriteInspectField('frame', 'state-id', IntToStr(Frame.StateId));
  if Frame.ParentStateId >= 0 then
    WriteInspectField('frame', 'parent-state-id', IntToStr(Frame.ParentStateId));
end;

procedure WriteInspectContext(AContext: TContext);
begin
  if AContext = nil then
  begin
    WriteInspectField('context', 'present', '0');
    Exit;
  end;

  WriteInspectField('context', 'present', '1');
  WriteInspectField('context', 'namespace', AContext.CurrentNamespace);
  WriteInspectField('context', 'rewrite-count', IntToStr(AContext.RewriteCount));
  WriteInspectField('context', 'dispatch-count', IntToStr(AContext.DispatchCount));
  WriteInspectField('context', 'selection-count', IntToStr(AContext.SelectionCount));
  WriteInspectField('context', 'inference-count', IntToStr(AContext.InferenceCount));
end;

procedure WriteInspectVariableMatches(
  const CountGroup: ansistring;
  const ItemGroup: ansistring;
  const Pattern: ansistring;
  AContext: TContext;
  Limit: Integer
);
var
  Matches: TStringList;
  I: Integer;
  EmitCount: Integer;
  Ref: Integer;
begin
  if Limit < 0 then
    Limit := 0;

  Matches := TStringList.Create;
  try
    if (AContext <> nil) and (Trim(Pattern) <> '') then
      AContext.ScanVariables(Pattern, Matches);
    WriteInspectField(CountGroup, 'count', IntToStr(Matches.Count));

    EmitCount := Matches.Count;
    if EmitCount > Limit then
      EmitCount := Limit;
    for I := 0 to EmitCount - 1 do
    begin
      Ref := PtrInt(Matches.Objects[I]);
      WriteInspectItem(ItemGroup, Matches[I], Ref);
    end;
    if Matches.Count > EmitCount then
      WriteInspectField(
        CountGroup,
        'truncated',
        IntToStr(Matches.Count - EmitCount)
      );
  finally
    Matches.Free;
  end;
end;

procedure WriteInspectEvents(const State: TDebuggerState; Limit: Integer);
var
  StartIndex: Integer;
  I: Integer;
  Event: TDebuggerEvent;
begin
  if Limit < 0 then
    Limit := 0;

  if State = nil then
  begin
    WriteInspectField('events', 'count', '0');
    Exit;
  end;

  WriteInspectField('events', 'count', IntToStr(State.RecentEventCount));
  StartIndex := State.RecentEventCount - Limit;
  if StartIndex < 0 then
    StartIndex := 0;
  if StartIndex > 0 then
    WriteInspectField('events', 'truncated', IntToStr(StartIndex));
  for I := StartIndex to State.RecentEventCount - 1 do
  begin
    Event := State.GetRecentEvent(I);
    WriteLn(
      '@inspect' + #9 + 'event' + #9 +
      SanitizeInspectValue(FormatDebuggerEventLine(Event))
    );
  end;
end;

procedure PrintDebuggerInspectSnapshot(const State: TDebuggerState; AContext: TContext);
var
  PauseLocation: TDebuggerSourceLocation;
begin
  WriteLn('@inspect' + #9 + 'begin');
  if State = nil then
  begin
    WriteInspectField('pause', 'reason', 'none');
    WriteInspectField('pause', 'message', '');
  end
  else
  begin
    WriteInspectField('pause', 'reason', DebuggerPauseReasonName(State.PauseReason));
    WriteInspectField('pause', 'message', State.PauseMessage);
    if State.TryGetDisplayLocation(PauseLocation) then
    begin
      if PauseLocation.FilePath <> '' then
        WriteInspectField('pause', 'source-path', PauseLocation.FilePath);
      if PauseLocation.Line > 0 then
        WriteInspectField('pause', 'source-line', IntToStr(PauseLocation.Line));
      if PauseLocation.Col > 0 then
        WriteInspectField('pause', 'source-col', IntToStr(PauseLocation.Col));
    end;
  end;
  WriteInspectFrame(State);
  WriteInspectContext(AContext);
  WriteInspectVariableMatches(
    'vars',
    'var',
    '*',
    AContext,
    DEFAULT_INSPECT_VARIABLE_LIMIT
  );
  WriteInspectVariableMatches(
    'settings',
    'setting',
    'mantra.*',
    AContext,
    DEFAULT_INSPECT_SETTING_LIMIT
  );
  WriteInspectEvents(State, DEFAULT_INSPECT_EVENT_LIMIT);
  WriteLn('@inspect' + #9 + 'end');
end;

procedure PrintDebuggerInspectChildren(
  const Domain: TInspectDomain;
  const Query: ansistring;
  AContext: TContext
);
var
  ChildPaths: TStringList;
  TrimmedQuery: ansistring;
  ResolvedName: ansistring;
  Preview: ansistring;
  ChildResolvedName: ansistring;
  ChildPreview: ansistring;
  ValueRef: Integer;
  ChildRef: Integer;
  Present: Boolean;
  HasChildren: Boolean;
  ChildPresent: Boolean;
  ChildHasChildren: Boolean;
  I: Integer;
begin
  ChildPaths := TStringList.Create;
  try
    TrimmedQuery := Trim(Query);
    Present := TryResolveInspectValueRef(
      Domain,
      TrimmedQuery,
      AContext,
      ResolvedName,
      ValueRef
    );
    if Present then
      Preview := RenderInspectPreview(ValueRef)
    else
    begin
      ValueRef := -1;
      Preview := '';
    end;

    CollectInspectChildren(Domain, TrimmedQuery, AContext, ChildPaths);
    HasChildren := ChildPaths.Count > 0;

    WriteLn('@inspect-children' + #9 + 'begin');
    WriteInspectProtocolField('@inspect-children', 'domain', InspectDomainName(Domain));
    WriteInspectProtocolField('@inspect-children', 'query', TrimmedQuery);
    WriteInspectProtocolField('@inspect-children', 'resolved', ResolvedName);
    WriteInspectProtocolField('@inspect-children', 'present', BoolText(Present));
    WriteInspectProtocolField('@inspect-children', 'ref', IntToStr(ValueRef));
    WriteInspectProtocolField('@inspect-children', 'has-children', BoolText(HasChildren));
    WriteInspectProtocolField('@inspect-children', 'preview', Preview);
    WriteInspectProtocolField('@inspect-children', 'count', IntToStr(ChildPaths.Count));

    for I := 0 to ChildPaths.Count - 1 do
    begin
      ChildPresent := TryResolveInspectValueRef(
        Domain,
        ChildPaths[I],
        AContext,
        ChildResolvedName,
        ChildRef
      );
      if ChildPresent then
        ChildPreview := RenderInspectPreview(ChildRef)
      else
      begin
        ChildRef := -1;
        ChildPreview := '';
      end;
      ChildHasChildren := HasInspectChildren(Domain, ChildPaths[I], AContext);
      WriteInspectProtocolChild(
        '@inspect-children',
        ExtractImmediateChildSegment(TrimmedQuery, ChildPaths[I]),
        ChildPaths[I],
        ChildResolvedName,
        ChildRef,
        ChildHasChildren,
        ChildPreview
      );
    end;

    WriteLn('@inspect-children' + #9 + 'end');
  finally
    ChildPaths.Free;
  end;
end;

procedure PrintDebuggerInspectValue(
  const Domain: TInspectDomain;
  const Query: ansistring;
  AContext: TContext
);
var
  TrimmedQuery: ansistring;
  ResolvedName: ansistring;
  Preview: ansistring;
  ValueRef: Integer;
  Present: Boolean;
  HasChildren: Boolean;
begin
  TrimmedQuery := Trim(Query);
  Present := TryResolveInspectValueRef(
    Domain,
    TrimmedQuery,
    AContext,
    ResolvedName,
    ValueRef
  );
  if Present then
    Preview := RenderInspectPreview(ValueRef)
  else
  begin
    ValueRef := -1;
    Preview := '';
  end;
  HasChildren := HasInspectChildren(Domain, TrimmedQuery, AContext);

  WriteLn('@inspect-value' + #9 + 'begin');
  WriteInspectProtocolField('@inspect-value', 'domain', InspectDomainName(Domain));
  WriteInspectProtocolField('@inspect-value', 'query', TrimmedQuery);
  WriteInspectProtocolField('@inspect-value', 'resolved', ResolvedName);
  WriteInspectProtocolField('@inspect-value', 'present', BoolText(Present));
  WriteInspectProtocolField('@inspect-value', 'ref', IntToStr(ValueRef));
  WriteInspectProtocolField('@inspect-value', 'has-children', BoolText(HasChildren));
  WriteInspectProtocolField('@inspect-value', 'preview', Preview);
  WriteLn('@inspect-value' + #9 + 'end');
end;

function HandleInspectCommand(
  const ArgText: ansistring;
  const State: TDebuggerState;
  AContext: TContext
): Boolean;
var
  Subcommand: ansistring;
  SubArgs: ansistring;
  DomainText: ansistring;
  PathText: ansistring;
  Domain: TInspectDomain;
begin
  if Trim(ArgText) = '' then
  begin
    PrintDebuggerInspectSnapshot(State, AContext);
    Exit(True);
  end;

  if not SplitDebuggerCommand(ArgText, Subcommand, SubArgs) then
    Exit(False);

  if (Subcommand = 'children') or (Subcommand = 'child') then
  begin
    if not SplitDebuggerCommand(SubArgs, DomainText, PathText) then
      Exit(False);
    if not TryParseInspectDomain(DomainText, Domain) then
      Exit(False);
    PrintDebuggerInspectChildren(Domain, PathText, AContext);
    Exit(True);
  end;

  if (Subcommand = 'value') or (Subcommand = 'val') then
  begin
    if not SplitDebuggerCommand(SubArgs, DomainText, PathText) then
      Exit(False);
    if not TryParseInspectDomain(DomainText, Domain) then
      Exit(False);
    PrintDebuggerInspectValue(Domain, PathText, AContext);
    Exit(True);
  end;

  Result := False;
end;

function TryParseBreakpointCommand(
  const ArgText: ansistring;
  out Breakpoint: TDebuggerBreakpoint
): Boolean;
var
  P: Integer;
  KindText: ansistring;
  Pattern: ansistring;
begin
  Result := False;
  Breakpoint := TDebuggerBreakpoint.Create(dbkUnknown, '');

  P := Pos(' ', Trim(ArgText));
  if P <= 0 then
    Exit(False);

  KindText := LowerCase(Trim(Copy(Trim(ArgText), 1, P - 1)));
  Pattern := Trim(Copy(Trim(ArgText), P + 1, MaxInt));
  if Pattern = '' then
    Exit(False);

  if KindText = 'callable' then
    Breakpoint := TDebuggerBreakpoint.Create(dbkCallable, Pattern)
  else if KindText = 'statement' then
    Breakpoint := TDebuggerBreakpoint.Create(dbkStatement, Pattern)
  else if KindText = 'rule' then
    Breakpoint := TDebuggerBreakpoint.Create(dbkRule, Pattern)
  else if KindText = 'inference' then
    Breakpoint := TDebuggerBreakpoint.Create(dbkInference, Pattern)
  else if KindText = 'source' then
  begin
    Breakpoint := TDebuggerBreakpoint.Create(dbkSource, '');
    if not TryParseDebuggerSourceSpec(Pattern, Breakpoint.Source) then
      Exit(False);
  end
  else
    Exit(False);

  Result := True;
end;

procedure PrintDebuggerHelp;
begin
  WriteLn('Debugger commands:');
  WriteLn('  help              Show this help');
  WriteLn('  breakpoints       List breakpoints');
  WriteLn('  break KIND PATTERN');
  WriteLn('                    Add breakpoint (KIND = callable|statement|rule|inference|source)');
  WriteLn('                    source spec: LINE | FILE:LINE | FILE:LINE:COL');
  WriteLn('  delete N          Delete breakpoint N');
  WriteLn('  clear             Delete all breakpoints');
  WriteLn('  bt                Show debugger stack');
  WriteLn('  frame [N]         Show frame details (0 = top frame)');
  WriteLn('  events [N]        Show recent debugger events');
  WriteLn('  reason            Show current pause reason');
  WriteLn('  context           Show current runtime context summary');
  WriteLn('  next              Resume until the next statement-level stop');
  WriteLn('  step              Resume until the next semantic stop');
  WriteLn('  finish            Resume until the current frame exits');
  WriteLn('  inspect [MODE]    Emit machine-readable debugger data');
  WriteLn('                    inspect');
  WriteLn('                    inspect children <vars|settings> [path]');
  WriteLn('                    inspect value <vars|settings> [path]');
  WriteLn('  postmortem        Show full postmortem report');
  WriteLn('  quit              Exit debugger prompt');
end;

procedure RunDebuggerCommandLoop(const State: TDebuggerState; AContext: TContext);
var
  Line: ansistring;
  CommandName: ansistring;
  ArgText: ansistring;
  Limit: Integer;
  FrameIndex: Integer;
  Frame: TDebuggerFrame;
  InteractiveInput: Boolean;
  PauseEvent: TDebuggerEvent;
  Breakpoint: TDebuggerBreakpoint;
begin
  if State = nil then
    Exit;

  InteractiveInput := IsInteractiveInput;
  WriteLn('Debugger paused: ' + DebuggerPauseReasonName(State.PauseReason));
  if (State.PauseReason = dprBreakpoint) and State.TryGetPauseEvent(PauseEvent) then
  begin
    if State.PauseMessage <> '' then
      WriteLn('Breakpoint hit: ' + State.PauseMessage)
    else
      WriteLn('Breakpoint hit: ' + FormatDebuggerEventLine(PauseEvent));
  end;
  if InteractiveInput then
    WriteLn('Type "help" for commands, "quit" to exit.');

  while not EOF(Input) do
  begin
    if InteractiveInput then
      Write('dbg> ');
    ReadLn(Input, Line);
    if not SplitDebuggerCommand(Line, CommandName, ArgText) then
      Continue;

    if (CommandName = 'quit') or (CommandName = 'q') or
       (CommandName = 'exit') or (CommandName = 'continue') or
       (CommandName = 'c') then
      Exit;

    if (CommandName = 'next') or (CommandName = 'n') then
    begin
      State.RequestNext;
      Exit;
    end;

    if (CommandName = 'step') or (CommandName = 's') then
    begin
      State.RequestStep;
      Exit;
    end;

    if (CommandName = 'finish') or (CommandName = 'fin') or
       (CommandName = 'out') then
    begin
      State.RequestFinish;
      Exit;
    end;

    if (CommandName = 'help') or (CommandName = 'h') or (CommandName = '?') then
    begin
      PrintDebuggerHelp;
      Continue;
    end;

    if (CommandName = 'breakpoints') or (CommandName = 'info') then
    begin
      PrintDebuggerBreakpoints(State);
      Continue;
    end;

    if (CommandName = 'break') or (CommandName = 'b') then
    begin
      if not TryParseBreakpointCommand(ArgText, Breakpoint) then
      begin
        WriteLn('Usage: break callable <pattern> | break statement <pattern> | break rule <pattern> | break inference <pattern> | break source <line|file:line|file:line:col>');
        Continue;
      end;
      State.AddBreakpoint(Breakpoint);
      WriteLn('Added breakpoint: ' +
        FormatDebuggerBreakpointLine(
          State.GetBreakpoint(State.BreakpointCount - 1),
          State.BreakpointCount - 1
        )
      );
      Continue;
    end;

    if (CommandName = 'delete') or (CommandName = 'd') then
    begin
      if not TryParsePositiveInt(ArgText, FrameIndex) then
      begin
        WriteLn('Invalid breakpoint index: ' + ArgText);
        Continue;
      end;
      if (FrameIndex < 0) or (FrameIndex >= State.BreakpointCount) then
      begin
        WriteLn('Breakpoint index out of range: ' + IntToStr(FrameIndex));
        Continue;
      end;
      State.DeleteBreakpoint(FrameIndex);
      WriteLn('Deleted breakpoint ' + IntToStr(FrameIndex));
      Continue;
    end;

    if CommandName = 'clear' then
    begin
      State.ClearBreakpoints;
      WriteLn('Cleared breakpoints');
      Continue;
    end;

    if (CommandName = 'bt') or (CommandName = 'where') then
    begin
      Write(FormatDebuggerStackTrace(State));
      Continue;
    end;

    if (CommandName = 'reason') then
    begin
      WriteLn('Pause reason: ' + DebuggerPauseReasonName(State.PauseReason));
      Continue;
    end;

    if (CommandName = 'context') or (CommandName = 'ctx') then
    begin
      Write(FormatDebuggerContextSummary(AContext));
      Continue;
    end;

    if (CommandName = 'inspect') or (CommandName = 'ins') then
    begin
      if not HandleInspectCommand(ArgText, State, AContext) then
      begin
        WriteLn('Usage: inspect | inspect children <vars|settings> [path] | inspect value <vars|settings> [path]');
        Continue;
      end;
      Continue;
    end;

    if (CommandName = 'postmortem') or (CommandName = 'pm') then
    begin
      Write(BuildDebuggerPostmortemReport(State));
      Continue;
    end;

    if (CommandName = 'events') or (CommandName = 'ev') then
    begin
      Limit := 16;
      if (ArgText <> '') and (not TryParsePositiveInt(ArgText, Limit)) then
      begin
        WriteLn('Invalid events limit: ' + ArgText);
        Continue;
      end;
      Write(FormatDebuggerRecentEvents(State, Limit));
      Continue;
    end;

    if (CommandName = 'frame') or (CommandName = 'f') then
    begin
      FrameIndex := 0;
      if (ArgText <> '') and (not TryParsePositiveInt(ArgText, FrameIndex)) then
      begin
        WriteLn('Invalid frame index: ' + ArgText);
        Continue;
      end;
      if not TryGetFrameByTopIndex(State, FrameIndex, Frame) then
      begin
        WriteLn('Frame index out of range: ' + IntToStr(FrameIndex));
        Continue;
      end;
      Write(FormatDebuggerFrameDetail(Frame, FrameIndex));
      Continue;
    end;

    WriteLn('Unknown debugger command: ' + CommandName);
  end;
end;

end.
