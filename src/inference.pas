unit inference;

{$I mantra.inc}

interface

uses
  exp_trees, context;

type
  TInferenceConfig = record
    StepLimit: Integer;
    MatchSubexpressions: Boolean;
    CongruenceBudget: Integer;
    BeamWidth: Integer;
    UseCostPolicy: Boolean;
    BeamDelta: Integer;
    BeamMax: Integer;
    ProfileSearch: Boolean;
  end;

  TInferenceRunInfo = record
    Policy: ansistring;
    InitialBeamWidth: Integer;
    EffectiveBeamWidth: Integer;
    Attempts: Integer;
  end;
  PInferenceRunInfo = ^TInferenceRunInfo;

  TInferenceStepCallback = procedure(
    Tree: TCustomTree;
    BeforeRoot: Integer;
    AfterRoot: Integer;
    RuleIndex: Integer;
    const RuleName: ansistring;
    Direction: Integer;
    OrientationExplicit: Integer;
    AnchorOrdinal: Integer;
    UserData: Pointer
  );

  PWitnessBuildState = ^TWitnessBuildState;
  TWitnessBuildState = record
    MatchSubexpressions: Boolean;
    Prefix: ansistring;
    StepsState: TVariableTrieState;
    StepCount: Integer;
    StoreReady: Boolean;
    Context: TContext;
  end;

function TryResolveInferenceInteger(
  Tree: TCustomTree;
  Context: TContext;
  StartIndex: Integer;
  out ResolvedValue: Integer
): Boolean;

function TryReadInferenceOverride(
  Tree: TCustomTree;
  Context: TContext;
  const VariableName: ansistring;
  out OverrideValue: Integer
): Boolean;

procedure ApplyDefaultInferenceOverrides(
  Tree: TCustomTree;
  Context: TContext;
  BaseCongruenceBudget: Integer;
  BaseBeamWidth: Integer;
  out EffectiveCongruenceBudget: Integer;
  out EffectiveBeamWidth: Integer;
  out EffectiveUseCostPolicy: Boolean;
  out EffectiveBeamDelta: Integer;
  out EffectiveBeamMax: Integer;
  out EffectiveProfileSearch: Boolean
);

procedure ResolveInferenceOperands(
  Tree: TCustomTree;
  Context: TContext;
  OwnerIndex: Integer;
  var QueryIndex: Integer;
  var RulesIndex: Integer
);

function TryExtractInferenceQuery(
  Tree: TCustomTree;
  QueryIndex: Integer;
  out SubjectIndex: Integer;
  out TargetIndex: Integer;
  out IsEquivalentQuery: Boolean
): Boolean;

procedure NormalizeInferenceQueryOperands(
  Tree: TCustomTree;
  Context: TContext;
  QueryIndex: Integer;
  var SubjectIndex: Integer;
  var TargetIndex: Integer
);

function RunDirectionalInference(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  RulesIndex: Integer;
  Context: TContext;
  const Config: TInferenceConfig;
  OnStep: TInferenceStepCallback = nil;
  UserData: Pointer = nil;
  RunInfo: PInferenceRunInfo = nil
): Boolean;

procedure InitWitnessBuildState(
  var State: TWitnessBuildState;
  MatchSubexpressions: Boolean;
  AContext: TContext;
  const APrefix: ansistring
);

procedure ClearWitnessBuildState(Tree: TCustomTree; var State: TWitnessBuildState);

procedure InferenceWitnessStepCallback(
  Tree: TCustomTree;
  BeforeRoot: Integer;
  AfterRoot: Integer;
  RuleIndex: Integer;
  const RuleName: ansistring;
  Direction: Integer;
  OrientationExplicit: Integer;
  AnchorOrdinal: Integer;
  UserData: Pointer
);

implementation

uses
  SysUtils, tokens, matcher_ir, helpers, string_utils, runtime_settings;

const
  INFERENCE_BEAM_VAR = 'mantra.inference.beam';
  INFERENCE_BUDGET_VAR = 'mantra.inference.budget';
  INFERENCE_POLICY_VAR = 'mantra.inference.policy';
  INFERENCE_BEAM_DELTA_VAR = 'mantra.inference.beam_delta';
  INFERENCE_BEAM_MAX_VAR = 'mantra.inference.beam_max';
  INFERENCE_PROFILE_VAR = 'mantra.inference.profile';
  MAX_RESOLVE_DEPTH = 32;

  OBJI_VARIABLE = TK_VARIABLE;
  OBJI_INTEGER = TK_INTEGER;
  OBJI_STRING = TK_STRING;
  OBJI_EXPRESSION = TK_PARENTHESIS_BEGIN;
  OBJI_EVALUATION = TK_CURLY_BEGIN;

  OBJI_TRANSFORMATION = TK_IMPLIES;
  OBJI_INLINE_TRANSFORMATION = TK_INLINE_TRANSFORM;
  OBJI_SUBST_TRANSFORM = TK_SUBST_TRANSFORM;
  OBJI_EQUIVALENCE = TK_EQUIVALENCE;
  OBJI_SUBST_EQUIVALENCE = TK_SUBST_EQUIVALENCE;
  OBJI_SELECTION = TK_QUESTIONMARK;
  OBJI_SEPARATOR = TK_COMMA;
  OBJI_ARRAY = TK_BRACKET_BEGIN;

procedure InitInferenceNode(Tree: TCustomTree; NodeIndex, ObjectId: Integer); inline;
begin
  Tree[NodeIndex]^.Data := ObjectId;
  Tree[NodeIndex]^.Ref := 0;
  Tree[NodeIndex]^.LHS := EOT;
  Tree[NodeIndex]^.RHS := EOT;
end;

function TryResolveInferenceInteger(
  Tree: TCustomTree;
  Context: TContext;
  StartIndex: Integer;
  out ResolvedValue: Integer
): Boolean;
var
  CurIndex: Integer;
  Depth: Integer;
  SymbolName: ansistring;
  TokenText: ansistring;
begin
  Result := False;
  ResolvedValue := 0;
  CurIndex := StartIndex;
  for Depth := 0 to MAX_RESOLVE_DEPTH - 1 do
  begin
    if CurIndex = EOT then
      Exit(False);

    case Tree[CurIndex]^.Id of
      OBJI_INTEGER:
        begin
          TokenText := Tree.Expression.TokenValue(Tree[CurIndex]^.Ref);
          Exit(TryStrToInt(TokenText, ResolvedValue));
        end;
      OBJI_VARIABLE:
        begin
          SymbolName := Tree.Expression.TokenValue(Tree[CurIndex]^.Ref);
          if (SymbolName = '') or
             (not Context.TryFindVariable(SymbolName, CurIndex)) then
            Exit(False);
        end;
      OBJI_EVALUATION, OBJI_EXPRESSION:
        begin
          if (Tree[CurIndex]^.RHS <> EOT) or (Tree[CurIndex]^.LHS = EOT) then
            Exit(False);
          CurIndex := Tree[CurIndex]^.LHS;
        end;
    else
      Exit(False);
    end;
  end;
end;

function TryReadInferenceOverride(
  Tree: TCustomTree;
  Context: TContext;
  const VariableName: ansistring;
  out OverrideValue: Integer
): Boolean;
var
  VariableIndex: Integer;
begin
  Result := False;
  OverrideValue := 0;
  if (not Assigned(Context)) or
     (not Context.TryFindVariable(VariableName, VariableIndex)) then
    Exit(False);
  Result := TryResolveInferenceInteger(Tree, Context, VariableIndex, OverrideValue);
  if (not Result) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected integer literal)', [VariableName])
    );
end;

procedure ApplyDefaultInferenceOverrides(
  Tree: TCustomTree;
  Context: TContext;
  BaseCongruenceBudget: Integer;
  BaseBeamWidth: Integer;
  out EffectiveCongruenceBudget: Integer;
  out EffectiveBeamWidth: Integer;
  out EffectiveUseCostPolicy: Boolean;
  out EffectiveBeamDelta: Integer;
  out EffectiveBeamMax: Integer;
  out EffectiveProfileSearch: Boolean
);
var
  OverrideValue: Integer;
  OverrideSource: ansistring;
  PolicyValue: ansistring;
  ProfileValue: Boolean;
  ReadResult: TSettingReadResult;
  DeltaReadResult: TSettingReadResult;
  MaxReadResult: TSettingReadResult;
begin
  EffectiveCongruenceBudget := BaseCongruenceBudget;
  EffectiveBeamWidth := BaseBeamWidth;
  EffectiveUseCostPolicy := False;
  EffectiveBeamDelta := 0;
  EffectiveBeamMax := BaseBeamWidth;
  EffectiveProfileSearch := False;

  ReadResult := ReadIntegerSetting(
    Tree, Context,
    [INFERENCE_BEAM_VAR],
    OverrideValue, OverrideSource
  );
  if ReadResult = srrFound then
  begin
    if OverrideValue >= 1 then
      EffectiveBeamWidth := OverrideValue
    else if Assigned(Context) and Context.EventEnabled(ellDiag) then
      Context.LogDiag(
        Format('invalid %s value %d (expected >= 1)', [OverrideSource, OverrideValue])
      );
  end;
  if (ReadResult = srrInvalid) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected integer literal)', [OverrideSource])
    );

  ReadResult := ReadIntegerSetting(
    Tree, Context,
    [INFERENCE_BUDGET_VAR],
    OverrideValue, OverrideSource
  );
  if ReadResult = srrFound then
  begin
    if OverrideValue >= -1 then
      EffectiveCongruenceBudget := OverrideValue
    else if Assigned(Context) and Context.EventEnabled(ellDiag) then
      Context.LogDiag(
        Format('invalid %s value %d (expected -1 or >= 0)', [OverrideSource, OverrideValue])
      );
  end;
  if (ReadResult = srrInvalid) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected integer literal)', [OverrideSource])
    );

  ReadResult := ReadStringSetting(
    Tree, Context,
    [INFERENCE_POLICY_VAR],
    PolicyValue, OverrideSource
  );
  if ReadResult = srrFound then
  begin
    PolicyValue := LowerCase(Trim(PolicyValue));
    if PolicyValue = 'cost' then
      EffectiveUseCostPolicy := True
    else if (PolicyValue <> '') and (PolicyValue <> 'default') and
            Assigned(Context) and Context.EventEnabled(ellDiag) then
      Context.LogDiag(
        Format('invalid %s value "%s" (expected "default" or "cost")',
          [OverrideSource, PolicyValue])
      );
  end;
  if (ReadResult = srrInvalid) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected string or identifier)', [OverrideSource])
    );

  EffectiveBeamMax := EffectiveBeamWidth;
  DeltaReadResult := ReadIntegerSetting(
    Tree, Context,
    [INFERENCE_BEAM_DELTA_VAR],
    OverrideValue, OverrideSource
  );
  if DeltaReadResult = srrFound then
  begin
    if OverrideValue > 0 then
    begin
      EffectiveBeamDelta := OverrideValue;
      MaxReadResult := ReadIntegerSetting(
        Tree, Context,
        [INFERENCE_BEAM_MAX_VAR],
        OverrideValue, OverrideSource
      );
      if (MaxReadResult = srrFound) and (OverrideValue >= EffectiveBeamWidth) then
        EffectiveBeamMax := OverrideValue
      else
      begin
        EffectiveBeamDelta := 0;
        if Assigned(Context) and Context.EventEnabled(ellDiag) then
          Context.LogDiag(
            Format('invalid %s value (positive %s requires integer >= initial beam %d)',
              [INFERENCE_BEAM_MAX_VAR, INFERENCE_BEAM_DELTA_VAR, EffectiveBeamWidth])
          );
      end;
    end
    else if (OverrideValue <> 0) and Assigned(Context) and Context.EventEnabled(ellDiag) then
      Context.LogDiag(
        Format('invalid %s value %d (expected >= 0)', [OverrideSource, OverrideValue])
      );
  end;
  if (DeltaReadResult = srrInvalid) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected integer literal)', [INFERENCE_BEAM_DELTA_VAR])
    );

  ReadResult := ReadBooleanSetting(
    Tree, Context,
    [INFERENCE_PROFILE_VAR],
    ProfileValue, OverrideSource
  );
  if ReadResult = srrFound then
    EffectiveProfileSearch := ProfileValue
  else if (ReadResult = srrInvalid) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected boolean literal)', [INFERENCE_PROFILE_VAR])
    );
end;

procedure ResolveInferenceOperands(
  Tree: TCustomTree;
  Context: TContext;
  OwnerIndex: Integer;
  var QueryIndex: Integer;
  var RulesIndex: Integer
);
begin
  while (QueryIndex <> EOT) and (Tree[QueryIndex]^.Id = OBJI_VARIABLE) do
    if not ResolveVariableNode(Tree, Context, QueryIndex, OwnerIndex, vrmAuto) then
      Break;

  while (RulesIndex <> EOT) and (Tree[RulesIndex]^.Id = OBJI_VARIABLE) do
    if not ResolveVariableNode(Tree, Context, RulesIndex, OwnerIndex, vrmSelectionRulesTemplate) then
      Break;
end;

function TryExtractInferenceQuery(
  Tree: TCustomTree;
  QueryIndex: Integer;
  out SubjectIndex: Integer;
  out TargetIndex: Integer;
  out IsEquivalentQuery: Boolean
): Boolean;
var
  QueryObjectId: Integer;
begin
  SubjectIndex := EOT;
  TargetIndex := EOT;
  IsEquivalentQuery := False;
  Result := False;

  if QueryIndex = EOT then
    Exit(False);

  QueryObjectId := Tree[QueryIndex]^.Id;
  IsEquivalentQuery := (QueryObjectId = OBJI_EQUIVALENCE) or
                       (QueryObjectId = OBJI_SUBST_EQUIVALENCE);
  if not (IsEquivalentQuery or
          (QueryObjectId = OBJI_TRANSFORMATION) or
          (QueryObjectId = OBJI_SUBST_TRANSFORM) or
          (QueryObjectId = OBJI_INLINE_TRANSFORMATION)) then
    Exit(False);

  SubjectIndex := Tree[QueryIndex]^.LHS;
  TargetIndex := Tree[QueryIndex]^.RHS;
  Result := (SubjectIndex <> EOT) and (TargetIndex <> EOT);
end;

procedure NormalizeInferenceQueryOperands(
  Tree: TCustomTree;
  Context: TContext;
  QueryIndex: Integer;
  var SubjectIndex: Integer;
  var TargetIndex: Integer
);
begin
  if (not Assigned(Tree)) or (not Assigned(Context)) then
    Exit;
  if QueryIndex = EOT then
    Exit;

  NormalizeTransformOperands(Tree, Context, QueryIndex);
  SubjectIndex := Tree[QueryIndex]^.LHS;
  TargetIndex := Tree[QueryIndex]^.RHS;
end;

type
  TInferenceTraceStep = record
    Step: Integer;
    StateId: Integer;
    ParentStateId: Integer;
    RuleIndex: Integer;
    RuleName: ansistring;
    Direction: Integer;
    OrientationExplicit: Integer;
    SubjectBefore: Integer;
    SubjectAfter: Integer;
    AnchorOrdinal: Integer;
  end;

  TInferenceTraceState = record
    Steps: array of TInferenceTraceStep;
    WinnerStateId: Integer;
  end;

procedure ClearInferenceTrace(Tree: TCustomTree; var TraceState: TInferenceTraceState);
var
  I: Integer;
begin
  if Assigned(Tree) then
    for I := 0 to High(TraceState.Steps) do
    begin
      if TraceState.Steps[I].SubjectBefore <> EOT then
        Tree.DeleteSubtree(EOT, TraceState.Steps[I].SubjectBefore);
      if TraceState.Steps[I].SubjectAfter <> EOT then
        Tree.DeleteSubtree(EOT, TraceState.Steps[I].SubjectAfter);
      if TraceState.Steps[I].RuleIndex <> EOT then
        Tree.DeleteSubtree(EOT, TraceState.Steps[I].RuleIndex);
    end;
  TraceState.Steps := nil;
  TraceState.WinnerStateId := 0;
end;

function FindInferenceStepByStateId(
  const TraceState: TInferenceTraceState;
  StateId: Integer
): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(TraceState.Steps) do
    if TraceState.Steps[I].StateId = StateId then
      Exit(I);
end;

procedure CollectInferenceTraceEvent(
  Tree: TCustomTree;
  const EventData: TInferenceEvent;
  UserData: Pointer
);
var
  TraceState: ^TInferenceTraceState;
  L: Integer;
begin
  if UserData = nil then
  begin
    if (EventData.Kind = iekRewriteApplied) and
       (EventData.SubjectBefore <> EOT) and Assigned(Tree) then
      Tree.DeleteSubtree(EOT, EventData.SubjectBefore);
    if (EventData.Kind = iekRewriteApplied) and
       (EventData.SubjectAfter <> EOT) and Assigned(Tree) then
      Tree.DeleteSubtree(EOT, EventData.SubjectAfter);
    Exit;
  end;

  TraceState := UserData;
  case EventData.Kind of
    iekRewriteApplied:
      begin
        L := Length(TraceState^.Steps);
        SetLength(TraceState^.Steps, L + 1);
        TraceState^.Steps[L].Step := EventData.Step;
        TraceState^.Steps[L].StateId := EventData.StateId;
        TraceState^.Steps[L].ParentStateId := EventData.ParentStateId;
        if Assigned(Tree) and (EventData.RuleIndex <> EOT) then
          TraceState^.Steps[L].RuleIndex := Tree.CloneSubtree(EventData.RuleIndex)
        else
          TraceState^.Steps[L].RuleIndex := EOT;
        TraceState^.Steps[L].RuleName := EventData.RuleName;
        TraceState^.Steps[L].Direction := EventData.Direction;
        TraceState^.Steps[L].OrientationExplicit := EventData.OrientationExplicit;
        TraceState^.Steps[L].SubjectBefore := EventData.SubjectBefore;
        TraceState^.Steps[L].SubjectAfter := EventData.SubjectAfter;
        TraceState^.Steps[L].AnchorOrdinal := EventData.AnchorOrdinal;
      end;
    iekTargetReached:
      TraceState^.WinnerStateId := EventData.StateId;
  end;
end;

function ReplayInferenceTrace(
  Tree: TCustomTree;
  var TraceState: TInferenceTraceState;
  OnStep: TInferenceStepCallback;
  UserData: Pointer
): Boolean;
var
  StateId: Integer;
  StepIndex: Integer;
  Path: array of Integer;
  PathLen: Integer;
  I: Integer;
begin
  Result := False;
  if not Assigned(OnStep) then
    Exit(True);
  if TraceState.WinnerStateId <= 0 then
    Exit(False);

  StateId := TraceState.WinnerStateId;
  Path := nil;
  while StateId > 0 do
  begin
    StepIndex := FindInferenceStepByStateId(TraceState, StateId);
    if StepIndex < 0 then
      Exit(False);
    PathLen := Length(Path);
    SetLength(Path, PathLen + 1);
    Path[PathLen] := StepIndex;
    StateId := TraceState.Steps[StepIndex].ParentStateId;
  end;

  for I := High(Path) downto 0 do
  begin
    StepIndex := Path[I];
    OnStep(
      Tree,
      TraceState.Steps[StepIndex].SubjectBefore,
      TraceState.Steps[StepIndex].SubjectAfter,
      TraceState.Steps[StepIndex].RuleIndex,
      TraceState.Steps[StepIndex].RuleName,
      TraceState.Steps[StepIndex].Direction,
      TraceState.Steps[StepIndex].OrientationExplicit,
      TraceState.Steps[StepIndex].AnchorOrdinal,
      UserData
    );
    TraceState.Steps[StepIndex].SubjectBefore := EOT;
    TraceState.Steps[StepIndex].SubjectAfter := EOT;
  end;

  Result := True;
end;

function RunDirectionalInference(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  RulesIndex: Integer;
  Context: TContext;
  const Config: TInferenceConfig;
  OnStep: TInferenceStepCallback = nil;
  UserData: Pointer = nil;
  RunInfo: PInferenceRunInfo = nil
): Boolean;
var
  CongruenceBudget: Integer;
  BeamWidth: Integer;
  AttemptBeamWidth: Integer;
  AttemptCount: Integer;
  StepLimit: Integer;
  TraceState: TInferenceTraceState;
  EventCallback: TInferenceEventCallback;
  EventUserData: Pointer;
  AttemptStats: TInferenceSearchStats;
  StatsPtr: PInferenceSearchStats;
  SearchSucceeded: Boolean;

  procedure LogAttemptProfile(AttemptSucceeded: Boolean);
  var
    I: Integer;
    PolicyName: ansistring;
    ResultName: ansistring;
    DirectionName: ansistring;
  begin
    if not Config.ProfileSearch or (not Assigned(Context)) then
      Exit;
    if Config.UseCostPolicy then
      PolicyName := 'cost'
    else
      PolicyName := 'default';
    if AttemptSucceeded then
      ResultName := 'success'
    else
      ResultName := 'failure';
    Context.LogDiag(
      Format(
        'inference profile attempt=%d policy=%s beam=%d result=%s generated=%d admitted=%d pruned_beam=%d pruned_visited=%d deduped=%d abandoned_success=%d forward=%d reverse=%d expanded=%d max_queue=%d max_frontier=%d',
        [AttemptCount, PolicyName, AttemptBeamWidth, ResultName,
         AttemptStats.CandidatesGenerated, AttemptStats.CandidatesAdmitted,
         AttemptStats.CandidatesPrunedBeam, AttemptStats.CandidatesPrunedVisited,
         AttemptStats.CandidatesLocalDeduplicated, AttemptStats.CandidatesAbandonedSuccess,
         AttemptStats.ForwardCandidates, AttemptStats.ReverseCandidates, AttemptStats.ExpandedStates,
         AttemptStats.MaxCandidateQueue, AttemptStats.MaxRetainedFrontier]
      )
    );
    for I := 0 to High(AttemptStats.RuleDirections) do
    begin
      if AttemptStats.RuleDirections[I].Direction = 1 then
        DirectionName := 'reverse'
      else
        DirectionName := 'forward';
      Context.LogDiag(
        Format(
          'inference profile rule attempt=%d policy=%s beam=%d name="%s" direction=%s generated=%d admitted=%d pruned_beam=%d pruned_visited=%d deduped=%d abandoned_success=%d',
          [AttemptCount, PolicyName, AttemptBeamWidth,
           AttemptStats.RuleDirections[I].RuleName, DirectionName,
           AttemptStats.RuleDirections[I].CandidatesGenerated,
           AttemptStats.RuleDirections[I].CandidatesAdmitted,
           AttemptStats.RuleDirections[I].CandidatesPrunedBeam,
           AttemptStats.RuleDirections[I].CandidatesPrunedVisited,
           AttemptStats.RuleDirections[I].CandidatesLocalDeduplicated,
           AttemptStats.RuleDirections[I].CandidatesAbandonedSuccess]
        )
      );
    end;
  end;
begin
  Result := False;
  if (not Assigned(Tree)) or (SubjectIndex = EOT) or (TargetIndex = EOT) or
     (RulesIndex = EOT) then
    Exit(False);

  StepLimit := Config.StepLimit;
  if StepLimit < 0 then
    StepLimit := 0;
  BeamWidth := Config.BeamWidth;
  if BeamWidth < 1 then
    BeamWidth := 1;
  AttemptBeamWidth := BeamWidth;
  AttemptCount := 0;
  if Assigned(RunInfo) then
  begin
    if Config.UseCostPolicy then
      RunInfo^.Policy := 'cost'
    else
      RunInfo^.Policy := 'default';
    RunInfo^.InitialBeamWidth := BeamWidth;
    RunInfo^.EffectiveBeamWidth := BeamWidth;
    RunInfo^.Attempts := 0;
  end;
  if Config.MatchSubexpressions then
    CongruenceBudget := Config.CongruenceBudget
  else
    CongruenceBudget := -1;

  if Assigned(OnStep) then
  begin
    EventCallback := @CollectInferenceTraceEvent;
    EventUserData := @TraceState;
  end
  else
  begin
    EventCallback := nil;
    EventUserData := nil;
  end;

  if StepLimit = 0 then
  begin
    Result := NodesStrictEqual(Tree, SubjectIndex, TargetIndex);
    if Assigned(RunInfo) then
      RunInfo^.Attempts := 1;
    Exit;
  end;

  repeat
    Inc(AttemptCount);
    if Config.ProfileSearch then
      StatsPtr := @AttemptStats
    else
      StatsPtr := nil;
    if Config.BeamDelta > 0 then
      LogTraceEvent(
        Context,
        Format('inference attempt=%d beam=%d', [AttemptCount, AttemptBeamWidth])
      );
    TraceState.Steps := nil;
    TraceState.WinnerStateId := 0;
    try
      if StepLimit = 1 then
        Result := CanRewriteOneStep(
          Tree, SubjectIndex, TargetIndex, RulesIndex, Context,
          Config.MatchSubexpressions, CongruenceBudget, AttemptBeamWidth, Config.UseCostPolicy,
          EventCallback, EventUserData, StatsPtr
        )
      else
        Result := CanRewriteWithinSteps(
          Tree, SubjectIndex, TargetIndex, RulesIndex, Context, StepLimit,
          Config.MatchSubexpressions, CongruenceBudget, AttemptBeamWidth, Config.UseCostPolicy,
          EventCallback, EventUserData, StatsPtr
        );

      SearchSucceeded := Result;
      if Result and Assigned(OnStep) then
        Result := ReplayInferenceTrace(Tree, TraceState, OnStep, UserData);
      LogAttemptProfile(SearchSucceeded);
    finally
      ClearInferenceTrace(Tree, TraceState);
    end;

    if Result or (Config.BeamDelta <= 0) or
       (AttemptBeamWidth >= Config.BeamMax) then
      Break;
    AttemptBeamWidth := AttemptBeamWidth + Config.BeamDelta;
    if AttemptBeamWidth > Config.BeamMax then
      AttemptBeamWidth := Config.BeamMax;
  until False;

  if Assigned(RunInfo) then
  begin
    RunInfo^.EffectiveBeamWidth := AttemptBeamWidth;
    RunInfo^.Attempts := AttemptCount;
  end;
end;

procedure InitWitnessBuildState(
  var State: TWitnessBuildState;
  MatchSubexpressions: Boolean;
  AContext: TContext;
  const APrefix: ansistring
);
var
  StepsKey: ansistring;
begin
  State.MatchSubexpressions := MatchSubexpressions;
  State.Prefix := APrefix;
  State.StepsState := 0;
  State.StepCount := 0;
  State.StoreReady := False;
  State.Context := AContext;
  if Assigned(AContext) and (APrefix <> '') then
  begin
    StepsKey := APrefix + '.steps';
    State.StoreReady := AContext.EnsureIndexedVariableState(StepsKey, State.StepsState, 0);
  end;
end;

procedure ClearWitnessBuildState(Tree: TCustomTree; var State: TWitnessBuildState);
begin
  State.Prefix := '';
  State.StepsState := 0;
  State.StepCount := 0;
  State.StoreReady := False;
  State.Context := nil;
end;

function CloneDirectionalRuleForWitness(
  Tree: TCustomTree;
  RuleIndex: Integer;
  Direction: Integer
): Integer;
var
  RuleObjectId: Integer;
  NewRule: Integer;
  NewLHS: Integer;
  NewRHS: Integer;
  SourceLHS: Integer;
  SourceRHS: Integer;
begin
  Result := EOT;
  if RuleIndex = EOT then
    Exit(EOT);

  RuleObjectId := Tree[RuleIndex]^.Id;
  if (RuleObjectId = OBJI_EQUIVALENCE) or
     (RuleObjectId = OBJI_SUBST_EQUIVALENCE) then
  begin
    NewRule := Tree.AllocateNode;
    if RuleObjectId = OBJI_SUBST_EQUIVALENCE then
      InitInferenceNode(Tree, NewRule, OBJI_SUBST_TRANSFORM)
    else
      InitInferenceNode(Tree, NewRule, OBJI_TRANSFORMATION);

    if Direction = 1 then
    begin
      SourceLHS := Tree[RuleIndex]^.RHS;
      SourceRHS := Tree[RuleIndex]^.LHS;
    end
    else
    begin
      SourceLHS := Tree[RuleIndex]^.LHS;
      SourceRHS := Tree[RuleIndex]^.RHS;
    end;

    NewLHS := Tree.CloneSubtree(SourceLHS);
    NewRHS := Tree.CloneSubtree(SourceRHS);
    if NewLHS <> EOT then
      Tree.LinkLHS(NewRule, NewLHS);
    if NewRHS <> EOT then
      Tree.LinkRHS(NewRule, NewRHS);
    Exit(NewRule);
  end;

  Result := Tree.CloneSubtree(RuleIndex);
end;

function CreateWitnessIntegerNode(Tree: TCustomTree; Value: Integer): Integer;
begin
  Result := Tree.AllocateNode;
  InitInferenceNode(Tree, Result, OBJI_INTEGER);
  Tree[Result]^.Ref := Tree.Expression.Append(TK_INTEGER, IntToStr(Value));
end;

function CreateWitnessStringNode(Tree: TCustomTree; const Value: ansistring): Integer;
begin
  Result := Tree.AllocateNode;
  InitInferenceNode(Tree, Result, OBJI_STRING);
  Tree[Result]^.Ref := Tree.Expression.Append(TK_STRING, QuoteStringLiteral(Value));
end;

function AppendWitnessStep(
  Tree: TCustomTree;
  var State: TWitnessBuildState;
  BeforeRoot: Integer;
  AfterRoot: Integer;
  RuleIndex: Integer;
  const RuleName: ansistring;
  Direction: Integer;
  OrientationExplicit: Integer;
  AnchorOrdinal: Integer
): Boolean;
var
  StepState: TVariableTrieState;
  RuleNode: Integer;
  RuleNameNode: Integer;
  DirectionNode: Integer;
  OrientationNode: Integer;
  AnchorNode: Integer;

  function StoreProp(const Suffix: ansistring; NodeIndex: Integer): Boolean;
  begin
    Result := False;
    if NodeIndex = EOT then
      Exit(False);
    Result := State.Context.SetVariableAtState(StepState, Suffix, NodeIndex);
    if not Result then
      Tree.DeleteSubtree(EOT, NodeIndex);
  end;
begin
  Result := False;
  if (BeforeRoot = EOT) or (AfterRoot = EOT) then
    Exit;
  if (not State.StoreReady) or (not Assigned(State.Context)) then
    Exit;
  if not State.Context.EnsureIndexedVariableChild(State.StepsState, State.StepCount, StepState) then
    Exit(False);

  RuleNode := CloneDirectionalRuleForWitness(Tree, RuleIndex, Direction);
  RuleNameNode := EOT;
  if RuleName <> '' then
    RuleNameNode := CreateWitnessStringNode(Tree, RuleName);
  if Direction = 1 then
    DirectionNode := CreateWitnessStringNode(Tree, 'reverse')
  else
    DirectionNode := CreateWitnessStringNode(Tree, 'forward');
  if OrientationExplicit <> 0 then
    OrientationNode := CreateWitnessStringNode(Tree, 'explicit')
  else
    OrientationNode := CreateWitnessStringNode(Tree, 'default');
  AnchorNode := CreateWitnessIntegerNode(Tree, AnchorOrdinal);

  if not StoreProp('.before', BeforeRoot) then
    Exit(False);
  if not StoreProp('.rule', RuleNode) then
    Exit(False);
  if (RuleNameNode <> EOT) and (not StoreProp('.rule_name', RuleNameNode)) then
    Exit(False);
  if not StoreProp('.after', AfterRoot) then
    Exit(False);
  if not StoreProp('.direction', DirectionNode) then
    Exit(False);
  if not StoreProp('.orientation', OrientationNode) then
    Exit(False);
  if not StoreProp('.anchor', AnchorNode) then
    Exit(False);

  Inc(State.StepCount);
  Result := True;
end;

procedure InferenceWitnessStepCallback(
  Tree: TCustomTree;
  BeforeRoot: Integer;
  AfterRoot: Integer;
  RuleIndex: Integer;
  const RuleName: ansistring;
  Direction: Integer;
  OrientationExplicit: Integer;
  AnchorOrdinal: Integer;
  UserData: Pointer
);
var
  State: PWitnessBuildState;
begin
  if not Assigned(Tree) then
    Exit;

  if UserData = nil then
  begin
    if BeforeRoot <> EOT then
      Tree.DeleteSubtree(EOT, BeforeRoot);
    if AfterRoot <> EOT then
      Tree.DeleteSubtree(EOT, AfterRoot);
    Exit;
  end;

  State := PWitnessBuildState(UserData);
  if not AppendWitnessStep(
           Tree, State^, BeforeRoot, AfterRoot, RuleIndex, RuleName, Direction,
           OrientationExplicit, AnchorOrdinal
         ) then
  begin
    if BeforeRoot <> EOT then
      Tree.DeleteSubtree(EOT, BeforeRoot);
    if AfterRoot <> EOT then
      Tree.DeleteSubtree(EOT, AfterRoot);
  end;
end;

end.
