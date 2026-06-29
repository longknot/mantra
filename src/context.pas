unit context;

{$I mantra.inc}

interface

uses
  contnrs, classes, exp_trees, MaskTrieDictionary3;

type
  TEventLogLevel = (
    ellOff,
    ellDiag,
    ellTrace
  );

type
  TEventLogFormat = (
    elfText,
    elfJson
  );

type
  TProgressSnapshot = record
    RewriteCount: QWord;
    DispatchCount: QWord;
    SelectionCount: QWord;
    InferenceCount: QWord;
  end;

type
  TVariableTrie = TTrieDictionary;
  TVariableTrieState = TVariableTrie.TStateHandle;

type
  TCallableBinding = class
  public
    RulesIndex: Integer;
    DispatchHead: ansistring;
    NamespacePath: ansistring;
    constructor Create(
      ARulesIndex: Integer;
      const ADispatchHead: ansistring;
      const ANamespacePath: ansistring
    );
  end;

type
  { TContext }
  TContext = class
  private
    FVariables: TVariableTrie;
    FExactScopeFrames: TObjectList;
    FKeywords: TFPHashList;
    FCallables: TFPHashList;
    FCallableBindings: TStringList;
    FCallableNamespaces: TStringList;
    FNonBindable: TFPHashList;
    FHandleCounters: TFPHashList;
    FSettingNamespaces: TStringList;
    FTree: TCustomTree;
    FData: Pointer;
    FCurrentNamespace: ansistring;
    FGlobalWriteDepth: Integer;
    FEventLines: TStringList;
    FEventLogLevel: TEventLogLevel;
    FEventLogStdout: Boolean;
    FEventLogFormat: TEventLogFormat;
    FRewriteCount: QWord;
    FDispatchCount: QWord;
    FSelectionCount: QWord;
    FInferenceCount: QWord;
    function NormalizeNamespacePath(const Value: ansistring): ansistring;
    function HasDottedPath(const Name: ansistring): Boolean;
    function QualifyLocalName(const Name: ansistring): ansistring;
    function QualifyWriteName(const Name: ansistring): ansistring;
    function TryFindScopedExactVariable(
      const Name: ansistring;
      out Index: Integer
    ): Boolean;
    function DeleteDetachedValue(ValueRef: Integer): Boolean;
    function ShouldFallbackToGlobal(const Name: ansistring): Boolean;
    function DequalifyLocalName(const Name: ansistring): ansistring;
    function FindCallableBindingIndex(const QualifiedName: ansistring): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddVariable(const Name: ansistring; Index: Integer);
    function TryFindVariable(const Name: ansistring; out Index: Integer): Boolean;
    function TryFindVariableResolved(
      const Name: ansistring;
      out ResolvedName: ansistring;
      out Index: Integer
    ): Boolean;
    function TryFindSettingVariable(
      const Name: ansistring;
      out ResolvedName: ansistring;
      out Index: Integer
    ): Boolean;
    function FindVariable(const Name: ansistring): Integer;
    function ResolveIndexedVariablePattern(
      const Pattern: ansistring;
      out ResolvedPattern: ansistring
    ): Boolean;
    function ScanVariables(const Pattern: ansistring; Matches: TStrings): SizeInt;
    function ScanVariableChildren(const Prefix: ansistring; Matches: TStrings): SizeInt;
    function TryLocateVariableState(
      const Prefix: ansistring;
      out ResolvedPrefix: ansistring;
      out State: TVariableTrieState
    ): Boolean;
    function EnsureVariableState(
      const Prefix: ansistring;
      out State: TVariableTrieState
    ): Boolean;
    function EnsureVariableSuffixState(
      const BaseState: TVariableTrieState;
      const Suffix: ansistring;
      out State: TVariableTrieState
    ): Boolean;
    function IsVariableStateIndexed(const State: TVariableTrieState): Boolean;
    function MarkVariableStateIndexed(
      const State: TVariableTrieState;
      const InitialCapacity: SizeInt = 0
    ): Boolean;
    function EnsureIndexedVariableState(
      const Prefix: ansistring;
      out State: TVariableTrieState;
      const InitialCapacity: SizeInt = 0
    ): Boolean;
    function EnsureIndexedVariableChild(
      const ParentState: TVariableTrieState;
      const ZeroBasedIndex: SizeInt;
      out ChildState: TVariableTrieState
    ): Boolean;
    function AddIndexedVariable(
      const State: TVariableTrieState;
      const ZeroBasedIndex: SizeInt;
      const ValueRef: Integer
    ): Boolean;
    function SetVariableAtState(
      const BaseState: TVariableTrieState;
      const Suffix: ansistring;
      ValueRef: Integer
    ): Boolean;
    function AddVariableAtState(
      const State: TVariableTrieState;
      ValueRef: Integer
    ): Boolean;
    function RemoveVariableSubtree(const Prefix: ansistring): Boolean;
    function CopyVariableSubtree(
      const SrcPrefix: ansistring;
      const DstPrefix: ansistring;
      Mode: TVariableTrie.TCopyMode
    ): Boolean;
    function NewHandle(
      const Prefix: ansistring;
      const HandleKind: ansistring = 'h'
    ): ansistring;
    function AllocateWitnessPrefix(const BasePrefix: ansistring = 'witness'): ansistring;
    procedure AddKeyword(const Name: ansistring);
    function IsKeyword(const Name: ansistring): Boolean;
    procedure AddCallable(const Name: ansistring);
    procedure AddCallableBinding(
      const Name: ansistring;
      RulesIndex: Integer;
      const DispatchHead: ansistring;
      const NamespacePath: ansistring = ''
    );
    procedure RemoveCallable(const Name: ansistring);
    function IsCallable(const Name: ansistring): Boolean;
    function TryResolveCallableBinding(
      const Name: ansistring;
      out ResolvedName: ansistring;
      out RulesIndex: Integer;
      out DispatchHead: ansistring;
      out NamespacePath: ansistring
    ): Boolean;
    procedure AddNonBindable(const Name: ansistring);
    function IsNonBindable(const Name: ansistring): Boolean;
    function EventEnabled(Level: TEventLogLevel): Boolean;
    procedure LogEvent(Level: TEventLogLevel; const MessageText: ansistring);
    procedure LogDiag(const MessageText: ansistring);
    procedure LogTrace(const MessageText: ansistring);
    procedure ClearEvents;
    function EventText: ansistring;
    procedure ResetProgressCounters;
    procedure MarkRewriteProgress;
    procedure MarkDispatchProgress;
    procedure MarkSelectionProgress;
    procedure MarkInferenceProgress;
    function GetProgressSnapshot: TProgressSnapshot;
    function HasProgressSince(const Snapshot: TProgressSnapshot): Boolean;
    procedure SetCurrentNamespace(const NamespacePath: ansistring);
    procedure PushExactScope(const LabelText: ansistring = '');
    procedure PopExactScope;
    function ExactScopeActive: Boolean;
    function TryAddScopedExactVariable(const Name: ansistring; Index: Integer): Boolean;
    procedure PushGlobalWrites;
    procedure PopGlobalWrites;
    function GlobalWritesEnabled: Boolean;
    procedure PushCallableNamespace(const NamespacePath: ansistring);
    procedure PopCallableNamespace;
    procedure PushSettingNamespace(const NamespacePath: ansistring);
    procedure PopSettingNamespace;

    // rules
    // procedure AddRule(const Name: ansistring; Index: Integer);
    // function FindRule(const Name: ansistring): PNodeReference;

    // pattern matching
    // procedure AddMapping(Src, Dst: Integer);
    // function FindMapping(Dst: Integer): Integer;

    // Q: context stack?
    // procedure PushContext();
    // procedure PopContext();
    property Tree: TCustomTree read FTree write FTree;
    property Data: Pointer read FData write FData;
    property EventLogLevel: TEventLogLevel read FEventLogLevel write FEventLogLevel;
    property EventLogStdout: Boolean read FEventLogStdout write FEventLogStdout;
    property EventLogFormat: TEventLogFormat read FEventLogFormat write FEventLogFormat;
    property EventLines: TStringList read FEventLines;
    property CurrentNamespace: ansistring read FCurrentNamespace write SetCurrentNamespace;
    property RewriteCount: QWord read FRewriteCount;
    property DispatchCount: QWord read FDispatchCount;
    property SelectionCount: QWord read FSelectionCount;
    property InferenceCount: QWord read FInferenceCount;
  end;

type
  TContextProc = procedure(AContext: TContext) of object;

implementation

uses
  sysutils, runtime_output;

type
  TExactScopeFrame = class
  public
    LabelText: ansistring;
    Values: TStringList;
    constructor Create(const ALabelText: ansistring);
    destructor Destroy; override;
    function TryGetValue(const Name: ansistring; out ValueRef: Integer): Boolean;
    procedure SetValue(const Name: ansistring; ValueRef: Integer);
  end;

type
  TVariableScanCollector = class
  private
    FMatches: TStrings;
  public
    constructor Create(AMatches: TStrings);
    procedure HandleMatch(
      const Key: ansistring;
      const Value: Integer;
      var Continue: Boolean
    );
  end;

type
  TVariablePathCollector = class
  private
    FMatches: TStrings;
  public
    constructor Create(AMatches: TStrings);
    procedure HandlePath(
      const Path: ansistring;
      var Continue: Boolean
    );
  end;

constructor TVariableScanCollector.Create(AMatches: TStrings);
begin
  inherited Create;
  FMatches := AMatches;
end;

constructor TExactScopeFrame.Create(const ALabelText: ansistring);
begin
  inherited Create;
  LabelText := ALabelText;
  Values := TStringList.Create;
  Values.Sorted := True;
  Values.Duplicates := dupIgnore;
  Values.CaseSensitive := True;
end;

destructor TExactScopeFrame.Destroy;
begin
  Values.Free;
  inherited Destroy;
end;

function TExactScopeFrame.TryGetValue(
  const Name: ansistring;
  out ValueRef: Integer
): Boolean;
var
  MatchIndex: Integer;
begin
  ValueRef := EOT;
  MatchIndex := Values.IndexOf(Name);
  Result := MatchIndex >= 0;
  if Result then
    ValueRef := PtrInt(Values.Objects[MatchIndex]);
end;

procedure TExactScopeFrame.SetValue(const Name: ansistring; ValueRef: Integer);
var
  MatchIndex: Integer;
begin
  MatchIndex := Values.IndexOf(Name);
  if MatchIndex >= 0 then
    Values.Objects[MatchIndex] := TObject(PtrInt(ValueRef))
  else
    Values.AddObject(Name, TObject(PtrInt(ValueRef)));
end;

constructor TCallableBinding.Create(
  ARulesIndex: Integer;
  const ADispatchHead: ansistring;
  const ANamespacePath: ansistring
);
begin
  inherited Create;
  RulesIndex := ARulesIndex;
  DispatchHead := ADispatchHead;
  NamespacePath := ANamespacePath;
end;

procedure TVariableScanCollector.HandleMatch(
  const Key: ansistring;
  const Value: Integer;
  var Continue: Boolean
);
begin
  Continue := True;
  if not Assigned(FMatches) then
    Exit;
  FMatches.AddObject(Key, TObject(PtrInt(Value)));
end;

constructor TVariablePathCollector.Create(AMatches: TStrings);
begin
  inherited Create;
  FMatches := AMatches;
end;

procedure TVariablePathCollector.HandlePath(
  const Path: ansistring;
  var Continue: Boolean
);
begin
  Continue := True;
  if not Assigned(FMatches) then
    Exit;
  FMatches.Add(Path);
end;

constructor TContext.Create;
begin
  inherited Create;
  FVariables := TVariableTrie.Create;
  FExactScopeFrames := TObjectList.Create(True);
  FKeywords := TFPHashList.Create;
  FCallables := TFPHashList.Create;
  FCallableBindings := TStringList.Create;
  FCallableNamespaces := TStringList.Create;
  FNonBindable := TFPHashList.Create;
  FHandleCounters := TFPHashList.Create;
  FSettingNamespaces := TStringList.Create;
  FEventLines := TStringList.Create;
  FEventLogLevel := ellOff;
  FEventLogStdout := False;
  FEventLogFormat := elfText;
  FCurrentNamespace := '';
  FGlobalWriteDepth := 0;
  FCallableBindings.Sorted := True;
  FCallableBindings.Duplicates := dupIgnore;
  FCallableBindings.CaseSensitive := True;
  AddKeyword('null');
  FCurrentNamespace := 'main';
  ResetProgressCounters;
end;

destructor TContext.Destroy;
var
  I: Integer;
begin
  FEventLines.Free;
  FSettingNamespaces.Free;
  FHandleCounters.Free;
  FNonBindable.Free;
  FCallableNamespaces.Free;
  while FExactScopeFrames.Count > 0 do
    PopExactScope;
  FExactScopeFrames.Free;
  for I := 0 to FCallableBindings.Count - 1 do
    FCallableBindings.Objects[I].Free;
  FCallableBindings.Free;
  FCallables.Free;
  FKeywords.Free;
  FVariables.Free;
  inherited Destroy;
end;

procedure TContext.AddVariable(const Name: ansistring; Index: Integer);
begin
  FVariables.Add(QualifyWriteName(Name), Index);
end;

function TContext.TryFindVariableResolved(
  const Name: ansistring;
  out ResolvedName: ansistring;
  out Index: Integer
): Boolean;
var
  TrimmedName: ansistring;
  LocalName: ansistring;
  GlobalName: ansistring;
begin
  ResolvedName := '';
  TrimmedName := Trim(Name);
  if TryFindScopedExactVariable(TrimmedName, Index) then
  begin
    ResolvedName := TrimmedName;
    Exit(True);
  end;
  LocalName := QualifyLocalName(Name);
  Result := (LocalName <> '') and FVariables.TryGetValue(LocalName, Index);
  if Result then
  begin
    ResolvedName := LocalName;
    Exit(True);
  end;
  if (not Result) and ShouldFallbackToGlobal(Name) then
  begin
    GlobalName := Trim(Name);
    if (GlobalName <> '') and (GlobalName <> LocalName) then
      Result := FVariables.TryGetValue(GlobalName, Index);
    if Result then
      ResolvedName := GlobalName;
  end;
  if not Result then
    Index := EOT;
end;

function TContext.TryFindVariable(const Name: ansistring; out Index: Integer): Boolean;
var
  ResolvedName: ansistring;
begin
  Result := TryFindVariableResolved(Name, ResolvedName, Index);
end;

function TContext.FindCallableBindingIndex(const QualifiedName: ansistring): Integer;
begin
  if QualifiedName = '' then
    Exit(-1);
  Result := FCallableBindings.IndexOf(QualifiedName);
end;

function TContext.TryFindSettingVariable(
  const Name: ansistring;
  out ResolvedName: ansistring;
  out Index: Integer
): Boolean;
var
  Candidate: ansistring;
  I: Integer;
begin
  ResolvedName := '';
  Index := EOT;

  Candidate := Trim(Name);
  if Candidate = '' then
    Exit(False);

  for I := FSettingNamespaces.Count - 1 downto 0 do
  begin
    if FSettingNamespaces[I] = '' then
      Continue;
    Candidate := FSettingNamespaces[I] + '.' + Trim(Name);
    if FVariables.TryGetValue(Candidate, Index) then
    begin
      ResolvedName := Candidate;
      Exit(True);
    end;
  end;

  Result := TryFindVariableResolved(Name, ResolvedName, Index);
end;

function TContext.FindVariable(const Name: ansistring): Integer;
begin
  Assert(TryFindVariable(Name, Result), Format('Variable %s is undefined', [Name]));
end;

function TContext.ResolveIndexedVariablePattern(
  const Pattern: ansistring;
  out ResolvedPattern: ansistring
): Boolean;
var
  LocalPattern: ansistring;
  GlobalPattern: ansistring;
begin
  LocalPattern := QualifyLocalName(Pattern);
  Result := (LocalPattern <> '') and FVariables.ResolveIndexedPattern(LocalPattern, ResolvedPattern);
  if Result then
    ResolvedPattern := DequalifyLocalName(ResolvedPattern);
  if (not Result) and ShouldFallbackToGlobal(Pattern) then
  begin
    GlobalPattern := Trim(Pattern);
    if (GlobalPattern <> '') and (GlobalPattern <> LocalPattern) then
      Result := FVariables.ResolveIndexedPattern(GlobalPattern, ResolvedPattern);
  end;
end;

function TContext.ScanVariables(const Pattern: ansistring; Matches: TStrings): SizeInt;
var
  Collector: TVariableScanCollector;
  RawMatches: TStringList;
  ExactLocalIndex: Integer;
  TrimmedPattern: ansistring;
  LocalPattern: ansistring;
  GlobalPattern: ansistring;
  I: Integer;
  UsedLocal: Boolean;
begin
  Result := 0;
  if (Pattern = '') or (not Assigned(Matches)) then
    Exit;

  RawMatches := TStringList.Create;
  Collector := TVariableScanCollector.Create(RawMatches);
  Matches.BeginUpdate;
  try
    Matches.Clear;
    TrimmedPattern := Trim(Pattern);
    if TryFindScopedExactVariable(TrimmedPattern, ExactLocalIndex) then
    begin
      Matches.AddObject(TrimmedPattern, TObject(PtrInt(ExactLocalIndex)));
      Exit(Matches.Count);
    end;
    LocalPattern := QualifyLocalName(Pattern);
    Result := 0;
    UsedLocal := False;
    if LocalPattern <> '' then
      Result := FVariables.ScanPattern(LocalPattern, @Collector.HandleMatch);
    UsedLocal := Result > 0;
    if (Result = 0) and ShouldFallbackToGlobal(Pattern) then
    begin
      GlobalPattern := Trim(Pattern);
      if (GlobalPattern <> '') and (GlobalPattern <> LocalPattern) then
        Result := FVariables.ScanPattern(GlobalPattern, @Collector.HandleMatch);
    end;

    for I := 0 to RawMatches.Count - 1 do
    begin
      if UsedLocal then
        Matches.AddObject(DequalifyLocalName(RawMatches[I]), RawMatches.Objects[I])
      else
        Matches.AddObject(RawMatches[I], RawMatches.Objects[I]);
    end;
  finally
    Matches.EndUpdate;
    Collector.Free;
    RawMatches.Free;
  end;
end;

function TContext.ScanVariableChildren(const Prefix: ansistring; Matches: TStrings): SizeInt;
var
  FrameIndex: Integer;
  FrameMatchIndex: Integer;
  Frame: TExactScopeFrame;
  Collector: TVariablePathCollector;
  RawMatches: TStringList;
  ExactLocalIndex: Integer;
  LocalPrefix: ansistring;
  GlobalPrefix: ansistring;
  TrimmedPrefix: ansistring;
  I: Integer;
  UsedLocal: Boolean;
begin
  Result := 0;
  if not Assigned(Matches) then
    Exit;

  RawMatches := TStringList.Create;
  Collector := TVariablePathCollector.Create(RawMatches);
  Matches.BeginUpdate;
  try
    Matches.Clear;
    TrimmedPrefix := Trim(Prefix);
    if (TrimmedPrefix <> '') and TryFindScopedExactVariable(TrimmedPrefix, ExactLocalIndex) then
      Exit(0);
    if TrimmedPrefix = '' then
      for FrameIndex := FExactScopeFrames.Count - 1 downto 0 do
      begin
        Frame := TExactScopeFrame(FExactScopeFrames[FrameIndex]);
        if not Assigned(Frame) then
          Continue;
        for FrameMatchIndex := 0 to Frame.Values.Count - 1 do
          if Matches.IndexOf(Frame.Values[FrameMatchIndex]) < 0 then
            Matches.Add(Frame.Values[FrameMatchIndex]);
      end;
    if TrimmedPrefix = '' then
    begin
      if FCurrentNamespace <> '' then
        LocalPrefix := FCurrentNamespace
      else
        LocalPrefix := '';
    end
    else
      LocalPrefix := QualifyLocalName(TrimmedPrefix);
    Result := 0;
    UsedLocal := False;
    if (TrimmedPrefix = '') or (LocalPrefix <> '') then
      Result := FVariables.ScanImmediateChildren(LocalPrefix, @Collector.HandlePath);
    UsedLocal := Result > 0;
    if (Result = 0) and ShouldFallbackToGlobal(TrimmedPrefix) then
    begin
      GlobalPrefix := TrimmedPrefix;
      if (GlobalPrefix <> '') and (GlobalPrefix <> LocalPrefix) then
        Result := FVariables.ScanImmediateChildren(GlobalPrefix, @Collector.HandlePath);
    end;

    for I := 0 to RawMatches.Count - 1 do
    begin
      if UsedLocal then
      begin
        if Matches.IndexOf(DequalifyLocalName(RawMatches[I])) < 0 then
          Matches.Add(DequalifyLocalName(RawMatches[I]));
      end
      else
      begin
        if Matches.IndexOf(RawMatches[I]) < 0 then
          Matches.Add(RawMatches[I]);
      end;
    end;
    Result := Matches.Count;
  finally
    Matches.EndUpdate;
    Collector.Free;
    RawMatches.Free;
  end;
end;

function TContext.TryLocateVariableState(
  const Prefix: ansistring;
  out ResolvedPrefix: ansistring;
  out State: TVariableTrieState
): Boolean;
var
  LocalPrefix: ansistring;
  GlobalPrefix: ansistring;
begin
  ResolvedPrefix := '';
  State := 0;
  LocalPrefix := QualifyLocalName(Prefix);
  Result := (LocalPrefix <> '') and FVariables.TryLocateState(LocalPrefix, State);
  if Result then
  begin
    ResolvedPrefix := DequalifyLocalName(LocalPrefix);
    Exit(True);
  end;

  if ShouldFallbackToGlobal(Prefix) then
  begin
    GlobalPrefix := Trim(Prefix);
    if (GlobalPrefix <> '') and (GlobalPrefix <> LocalPrefix) then
      Result := FVariables.TryLocateState(GlobalPrefix, State);
    if Result then
      ResolvedPrefix := GlobalPrefix;
  end;
end;

function TContext.EnsureVariableState(
  const Prefix: ansistring;
  out State: TVariableTrieState
): Boolean;
begin
  Result := FVariables.EnsureState(QualifyWriteName(Prefix), State);
end;

function TContext.EnsureVariableSuffixState(
  const BaseState: TVariableTrieState;
  const Suffix: ansistring;
  out State: TVariableTrieState
): Boolean;
begin
  Result := FVariables.EnsureSuffixState(BaseState, Suffix, State);
end;

function TContext.IsVariableStateIndexed(const State: TVariableTrieState): Boolean;
begin
  Result := FVariables.IsIndexedState(State);
end;

function TContext.MarkVariableStateIndexed(
  const State: TVariableTrieState;
  const InitialCapacity: SizeInt
): Boolean;
begin
  Result := FVariables.MarkStateIndexed(State, InitialCapacity);
end;

function TContext.EnsureIndexedVariableState(
  const Prefix: ansistring;
  out State: TVariableTrieState;
  const InitialCapacity: SizeInt
): Boolean;
begin
  Result := FVariables.EnsureState(QualifyWriteName(Prefix), State);
  if not Result then
    Exit(False);
  if FVariables.IsIndexedState(State) then
    Exit(True);
  Result := FVariables.MarkStateIndexed(State, InitialCapacity);
end;

function TContext.EnsureIndexedVariableChild(
  const ParentState: TVariableTrieState;
  const ZeroBasedIndex: SizeInt;
  out ChildState: TVariableTrieState
): Boolean;
begin
  Result := FVariables.EnsureIndexedState(ParentState, ZeroBasedIndex, ChildState);
end;

function TContext.AddIndexedVariable(
  const State: TVariableTrieState;
  const ZeroBasedIndex: SizeInt;
  const ValueRef: Integer
): Boolean;
begin
  Result := FVariables.AddIndexed(State, ZeroBasedIndex, ValueRef);
end;

function TContext.SetVariableAtState(
  const BaseState: TVariableTrieState;
  const Suffix: ansistring;
  ValueRef: Integer
): Boolean;
var
  TargetState: TVariableTrieState;
begin
  Result := FVariables.EnsureSuffixState(BaseState, Suffix, TargetState);
  if not Result then
    Exit(False);
  Result := FVariables.AddAtState(TargetState, ValueRef);
end;

function TContext.AddVariableAtState(
  const State: TVariableTrieState;
  ValueRef: Integer
): Boolean;
begin
  Result := FVariables.AddAtState(State, ValueRef);
end;

function TContext.RemoveVariableSubtree(const Prefix: ansistring): Boolean;
begin
  Result := FVariables.RemoveSubtree(QualifyWriteName(Prefix));
end;

function TContext.CopyVariableSubtree(
  const SrcPrefix: ansistring;
  const DstPrefix: ansistring;
  Mode: TVariableTrie.TCopyMode
): Boolean;
var
  ResolvedSrc: ansistring;
begin
  ResolvedSrc := QualifyLocalName(SrcPrefix);
  Result := (ResolvedSrc <> '') and FVariables.CopySubtree(ResolvedSrc, QualifyWriteName(DstPrefix), Mode);
  if (not Result) and ShouldFallbackToGlobal(SrcPrefix) then
  begin
    ResolvedSrc := Trim(SrcPrefix);
    if ResolvedSrc <> '' then
      Result := FVariables.CopySubtree(ResolvedSrc, QualifyWriteName(DstPrefix), Mode);
  end;
end;

function TContext.NewHandle(
  const Prefix: ansistring;
  const HandleKind: ansistring
): ansistring;
var
  BasePrefix: ansistring;
  Kind: ansistring;
  CounterIndex: Integer;
  SerialValue: PtrUInt;
begin
  BasePrefix := Trim(Prefix);
  if BasePrefix = '' then
    BasePrefix := 'handle';

  Kind := LowerCase(Trim(HandleKind));
  if Kind = '' then
    Kind := 'h';

  CounterIndex := FHandleCounters.FindIndexOf(Kind);
  if CounterIndex < 0 then
  begin
    SerialValue := 1;
    FHandleCounters.Add(Kind, Pointer(SerialValue));
  end
  else
  begin
    SerialValue := PtrUInt(FHandleCounters.Items[CounterIndex]) + 1;
    FHandleCounters.Items[CounterIndex] := Pointer(SerialValue);
  end;

  Result := BasePrefix + '.' + Kind + IntToStr(SerialValue);
end;

function TContext.AllocateWitnessPrefix(const BasePrefix: ansistring): ansistring;
var
  PrefixBase: ansistring;
begin
  PrefixBase := BasePrefix;
  if PrefixBase = '' then
    PrefixBase := 'witness';
  Result := NewHandle(PrefixBase, 'w');
end;

procedure TContext.AddKeyword(const Name: ansistring);
var
  QualifiedName: ansistring;
begin
  if Name = '' then
    Exit;
  QualifiedName := QualifyWriteName(Name);
  if FKeywords.Find(QualifiedName) = nil then
    FKeywords.Add(QualifiedName, Pointer(PtrInt(1)));
end;

function TContext.IsKeyword(const Name: ansistring): Boolean;
var
  QualifiedName: ansistring;
  GlobalName: ansistring;
begin
  if Name = '' then
    Exit(False);
  if (Name = 'null') or (Name = 'true') or (Name = 'false') then
    Exit(True);
  QualifiedName := QualifyLocalName(Name);
  Result := (QualifiedName <> '') and (FKeywords.Find(QualifiedName) <> nil);
  if (not Result) and ShouldFallbackToGlobal(Name) then
  begin
    GlobalName := Trim(Name);
    if (GlobalName <> '') and (GlobalName <> QualifiedName) then
      Result := FKeywords.Find(GlobalName) <> nil;
  end;
end;

procedure TContext.AddCallable(const Name: ansistring);
var
  QualifiedName: ansistring;
begin
  if Name = '' then
    Exit;
  QualifiedName := QualifyWriteName(Name);
  if FCallables.Find(QualifiedName) = nil then
    FCallables.Add(QualifiedName, Pointer(PtrInt(1)));
end;

procedure TContext.AddCallableBinding(
  const Name: ansistring;
  RulesIndex: Integer;
  const DispatchHead: ansistring;
  const NamespacePath: ansistring
);
var
  QualifiedName: ansistring;
  Binding: TCallableBinding;
  ExistingIndex: Integer;
begin
  if Name = '' then
    Exit;

  QualifiedName := QualifyWriteName(Name);
  if QualifiedName = '' then
    Exit;

  Binding := TCallableBinding.Create(
    RulesIndex,
    DispatchHead,
    NormalizeNamespacePath(NamespacePath)
  );

  ExistingIndex := FindCallableBindingIndex(QualifiedName);
  if ExistingIndex >= 0 then
  begin
    FCallableBindings.Objects[ExistingIndex].Free;
    FCallableBindings.Objects[ExistingIndex] := Binding;
  end
  else
    FCallableBindings.AddObject(QualifiedName, Binding);
end;

procedure TContext.RemoveCallable(const Name: ansistring);
var
  I: Integer;
  QualifiedName: ansistring;
begin
  if Name = '' then
    Exit;
  QualifiedName := QualifyWriteName(Name);
  I := FCallables.FindIndexOf(QualifiedName);
  if I >= 0 then
    FCallables.Delete(I);
  I := FindCallableBindingIndex(QualifiedName);
  if I >= 0 then
  begin
    FCallableBindings.Objects[I].Free;
    FCallableBindings.Delete(I);
  end;
end;

function TContext.IsCallable(const Name: ansistring): Boolean;
var
  QualifiedName: ansistring;
  GlobalName: ansistring;
  CandidateName: ansistring;
  I: Integer;
begin
  if Name = '' then
    Exit(False);
  QualifiedName := QualifyLocalName(Name);
  Result := (QualifiedName <> '') and (FCallables.Find(QualifiedName) <> nil);
  if (not Result) and ShouldFallbackToGlobal(Name) then
  begin
    GlobalName := Trim(Name);
    if (GlobalName <> '') and (GlobalName <> QualifiedName) then
      Result := FCallables.Find(GlobalName) <> nil;
  end;
  if Result or HasDottedPath(Name) then
    Exit;
  GlobalName := Trim(Name);
  if GlobalName = '' then
    Exit(False);
  for I := FCallableNamespaces.Count - 1 downto 0 do
  begin
    CandidateName := NormalizeNamespacePath(FCallableNamespaces[I]);
    if CandidateName = '' then
      Continue;
    CandidateName := CandidateName + '.' + GlobalName;
    if FCallables.Find(CandidateName) <> nil then
      Exit(True);
  end;
end;

function TContext.TryResolveCallableBinding(
  const Name: ansistring;
  out ResolvedName: ansistring;
  out RulesIndex: Integer;
  out DispatchHead: ansistring;
  out NamespacePath: ansistring
): Boolean;
var
  QualifiedName: ansistring;
  GlobalName: ansistring;
  CandidateName: ansistring;
  I: Integer;
  BindingIndex: Integer;
  Binding: TCallableBinding;
begin
  ResolvedName := '';
  RulesIndex := EOT;
  DispatchHead := '';
  NamespacePath := '';

  QualifiedName := QualifyLocalName(Name);
  I := FindCallableBindingIndex(QualifiedName);
  if I >= 0 then
  begin
    Binding := TCallableBinding(FCallableBindings.Objects[I]);
    if Assigned(Binding) and (Binding.RulesIndex <> EOT) then
    begin
      ResolvedName := QualifiedName;
      RulesIndex := Binding.RulesIndex;
      DispatchHead := Binding.DispatchHead;
      NamespacePath := Binding.NamespacePath;
      Exit(True);
    end;
  end;

  if ShouldFallbackToGlobal(Name) then
  begin
    GlobalName := Trim(Name);
    if (GlobalName <> '') and (GlobalName <> QualifiedName) then
    begin
      I := FindCallableBindingIndex(GlobalName);
      if I >= 0 then
      begin
        Binding := TCallableBinding(FCallableBindings.Objects[I]);
        if Assigned(Binding) and (Binding.RulesIndex <> EOT) then
        begin
          ResolvedName := GlobalName;
          RulesIndex := Binding.RulesIndex;
          DispatchHead := Binding.DispatchHead;
          NamespacePath := Binding.NamespacePath;
          Exit(True);
        end;
      end;
    end;
  end;

  if not HasDottedPath(Name) then
  begin
    GlobalName := Trim(Name);
    if GlobalName <> '' then
      for I := FCallableNamespaces.Count - 1 downto 0 do
      begin
        CandidateName := NormalizeNamespacePath(FCallableNamespaces[I]);
        if CandidateName = '' then
          Continue;
        CandidateName := CandidateName + '.' + GlobalName;
        BindingIndex := FindCallableBindingIndex(CandidateName);
        if BindingIndex >= 0 then
        begin
          Binding := TCallableBinding(FCallableBindings.Objects[BindingIndex]);
          if Assigned(Binding) and (Binding.RulesIndex <> EOT) then
          begin
            ResolvedName := CandidateName;
            RulesIndex := Binding.RulesIndex;
            DispatchHead := Binding.DispatchHead;
            NamespacePath := Binding.NamespacePath;
            Exit(True);
          end;
        end;
      end;
  end;

  Result := False;
end;

procedure TContext.PushCallableNamespace(const NamespacePath: ansistring);
var
  Normalized: ansistring;
begin
  Normalized := NormalizeNamespacePath(NamespacePath);
  if Normalized = '' then
    Exit;
  FCallableNamespaces.Add(Normalized);
end;

procedure TContext.PopCallableNamespace;
begin
  if FCallableNamespaces.Count > 0 then
    FCallableNamespaces.Delete(FCallableNamespaces.Count - 1);
end;

procedure TContext.AddNonBindable(const Name: ansistring);
var
  QualifiedName: ansistring;
begin
  if Name = '' then
    Exit;
  QualifiedName := QualifyWriteName(Name);
  if FNonBindable.Find(QualifiedName) = nil then
    FNonBindable.Add(QualifiedName, Pointer(PtrInt(1)));
end;

function TContext.IsNonBindable(const Name: ansistring): Boolean;
var
  QualifiedName: ansistring;
  GlobalName: ansistring;
begin
  if Name = '' then
    Exit(False);
  QualifiedName := QualifyLocalName(Name);
  Result := (QualifiedName <> '') and (FNonBindable.Find(QualifiedName) <> nil);
  if (not Result) and ShouldFallbackToGlobal(Name) then
  begin
    GlobalName := Trim(Name);
    if (GlobalName <> '') and (GlobalName <> QualifiedName) then
      Result := FNonBindable.Find(GlobalName) <> nil;
  end;
end;

function TContext.NormalizeNamespacePath(const Value: ansistring): ansistring;
begin
  Result := Trim(Value);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, '\', '.', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '.', [rfReplaceAll]);
  while (Result <> '') and (Result[1] = '.') do
    Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] = '.') do
    Delete(Result, Length(Result), 1);
  while Pos('..', Result) > 0 do
    Result := StringReplace(Result, '..', '.', [rfReplaceAll]);
end;

function TContext.HasDottedPath(const Name: ansistring): Boolean;
begin
  Result := Pos('.', Name) > 0;
end;

function TContext.QualifyLocalName(const Name: ansistring): ansistring;
begin
  Result := Trim(Name);
  if Result = '' then
    Exit('');
  if FCurrentNamespace = '' then
    Exit(Result);
  Result := FCurrentNamespace + '.' + Result;
end;

function TContext.QualifyWriteName(const Name: ansistring): ansistring;
begin
  Result := Trim(Name);
  if Result = '' then
    Exit('');
  if GlobalWritesEnabled then
    Exit(Result);
  Result := QualifyLocalName(Result);
end;

function TContext.TryFindScopedExactVariable(
  const Name: ansistring;
  out Index: Integer
): Boolean;
var
  TrimmedName: ansistring;
  FrameIndex: Integer;
  Frame: TExactScopeFrame;
begin
  Index := EOT;
  TrimmedName := Trim(Name);
  if (TrimmedName = '') or HasDottedPath(TrimmedName) then
    Exit(False);
  for FrameIndex := FExactScopeFrames.Count - 1 downto 0 do
  begin
    Frame := TExactScopeFrame(FExactScopeFrames[FrameIndex]);
    if Assigned(Frame) and Frame.TryGetValue(TrimmedName, Index) then
      Exit(True);
  end;
  Result := False;
end;

function TContext.DeleteDetachedValue(ValueRef: Integer): Boolean;
begin
  Result := (ValueRef <> EOT) and Assigned(FTree);
  if Result then
    FTree.DeleteSubtree(EOT, ValueRef);
end;

function TContext.ShouldFallbackToGlobal(const Name: ansistring): Boolean;
begin
  Result := HasDottedPath(Trim(Name));
end;

function TContext.DequalifyLocalName(const Name: ansistring): ansistring;
var
  Prefix: ansistring;
begin
  Result := Name;
  if FCurrentNamespace = '' then
    Exit;
  Prefix := FCurrentNamespace + '.';
  if Copy(Result, 1, Length(Prefix)) = Prefix then
    Delete(Result, 1, Length(Prefix));
end;

procedure TContext.SetCurrentNamespace(const NamespacePath: ansistring);
begin
  FCurrentNamespace := NormalizeNamespacePath(NamespacePath);
end;

procedure TContext.PushExactScope(const LabelText: ansistring);
begin
  FExactScopeFrames.Add(TExactScopeFrame.Create(LabelText));
end;

procedure TContext.PopExactScope;
var
  Frame: TExactScopeFrame;
  I: Integer;
  ValueRef: Integer;
begin
  if FExactScopeFrames.Count = 0 then
    Exit;
  Frame := TExactScopeFrame(FExactScopeFrames[FExactScopeFrames.Count - 1]);
  if Assigned(Frame) then
    for I := 0 to Frame.Values.Count - 1 do
    begin
      ValueRef := PtrInt(Frame.Values.Objects[I]);
      DeleteDetachedValue(ValueRef);
    end;
  FExactScopeFrames.Delete(FExactScopeFrames.Count - 1);
end;

function TContext.ExactScopeActive: Boolean;
begin
  Result := FExactScopeFrames.Count > 0;
end;

function TContext.TryAddScopedExactVariable(const Name: ansistring; Index: Integer): Boolean;
var
  Frame: TExactScopeFrame;
  TrimmedName: ansistring;
  ExistingRef: Integer;
begin
  Result := False;
  if not ExactScopeActive or GlobalWritesEnabled then
    Exit(False);

  TrimmedName := Trim(Name);
  if (TrimmedName = '') or HasDottedPath(TrimmedName) then
    Exit(False);

  Frame := TExactScopeFrame(FExactScopeFrames[FExactScopeFrames.Count - 1]);
  if not Assigned(Frame) then
    Exit(False);

  if Frame.TryGetValue(TrimmedName, ExistingRef) and (ExistingRef <> Index) then
    DeleteDetachedValue(ExistingRef);
  Frame.SetValue(TrimmedName, Index);
  Result := True;
end;

procedure TContext.PushGlobalWrites;
begin
  Inc(FGlobalWriteDepth);
end;

procedure TContext.PopGlobalWrites;
begin
  if FGlobalWriteDepth > 0 then
    Dec(FGlobalWriteDepth);
end;

function TContext.GlobalWritesEnabled: Boolean;
begin
  Result := FGlobalWriteDepth > 0;
end;

procedure TContext.PushSettingNamespace(const NamespacePath: ansistring);
var
  Normalized: ansistring;
begin
  Normalized := NormalizeNamespacePath(NamespacePath);
  if Normalized = '' then
    Exit;
  FSettingNamespaces.Add(Normalized);
end;

procedure TContext.PopSettingNamespace;
begin
  if FSettingNamespaces.Count > 0 then
    FSettingNamespaces.Delete(FSettingNamespaces.Count - 1);
end;

function TContext.EventEnabled(Level: TEventLogLevel): Boolean;
begin
  case Level of
    ellDiag:
      Result := FEventLogLevel in [ellDiag, ellTrace];
    ellTrace:
      Result := FEventLogLevel = ellTrace;
  else
    Result := False;
  end;
end;

procedure TContext.LogEvent(Level: TEventLogLevel; const MessageText: ansistring);
var
  Prefix: ansistring;
  LineText: ansistring;
  function JsonEscape(const S: ansistring): ansistring;
  var
    I: Integer;
    C: Char;
  begin
    Result := '';
    for I := 1 to Length(S) do
    begin
      C := S[I];
      case C of
        '"': Result := Result + '\"';
        '\': Result := Result + '\\';
        #8: Result := Result + '\b';
        #9: Result := Result + '\t';
        #10: Result := Result + '\n';
        #12: Result := Result + '\f';
        #13: Result := Result + '\r';
      else
        if Ord(C) < 32 then
          Result := Result + Format('\u%.4x', [Ord(C)])
        else
          Result := Result + C;
      end;
    end;
  end;
begin
  if not EventEnabled(Level) then
    Exit;
  case Level of
    ellDiag: Prefix := 'diag';
    ellTrace: Prefix := 'trace';
  else
    Prefix := 'event';
  end;
  if FEventLogFormat = elfJson then
    LineText := Format('{"level":"%s","event":"%s"}', [Prefix, JsonEscape(MessageText)])
  else
    LineText := Format('EVENT[%s] %s', [Prefix, MessageText]);
  FEventLines.Add(LineText);
  if FEventLogStdout then
    EmitRuntimeOutputLine(LineText);
end;

procedure TContext.LogDiag(const MessageText: ansistring);
begin
  LogEvent(ellDiag, MessageText);
end;

procedure TContext.LogTrace(const MessageText: ansistring);
begin
  LogEvent(ellTrace, MessageText);
end;

procedure TContext.ClearEvents;
begin
  FEventLines.Clear;
end;

function TContext.EventText: ansistring;
begin
  Result := FEventLines.Text;
end;

procedure TContext.ResetProgressCounters;
begin
  FRewriteCount := 0;
  FDispatchCount := 0;
  FSelectionCount := 0;
  FInferenceCount := 0;
end;

procedure TContext.MarkRewriteProgress;
begin
  Inc(FRewriteCount);
end;

procedure TContext.MarkDispatchProgress;
begin
  Inc(FDispatchCount);
end;

procedure TContext.MarkSelectionProgress;
begin
  Inc(FSelectionCount);
end;

procedure TContext.MarkInferenceProgress;
begin
  Inc(FInferenceCount);
end;

function TContext.GetProgressSnapshot: TProgressSnapshot;
begin
  Result.RewriteCount := FRewriteCount;
  Result.DispatchCount := FDispatchCount;
  Result.SelectionCount := FSelectionCount;
  Result.InferenceCount := FInferenceCount;
end;

function TContext.HasProgressSince(const Snapshot: TProgressSnapshot): Boolean;
begin
  Result :=
    (FRewriteCount <> Snapshot.RewriteCount) or
    (FDispatchCount <> Snapshot.DispatchCount) or
    (FSelectionCount <> Snapshot.SelectionCount) or
    (FInferenceCount <> Snapshot.InferenceCount);
end;

end.
