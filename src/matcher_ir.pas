unit matcher_ir;

{$I mantra.inc}

interface

uses
  exp_trees, tokens, context, selection_strategies;

type
  TInferenceEventKind = (
    iekRewriteApplied,
    iekTargetReached
  );

  TInferenceEvent = record
    Kind: TInferenceEventKind;
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

  TInferenceEventCallback = procedure(
    Tree: TCustomTree;
    const EventData: TInferenceEvent;
    UserData: Pointer
  );

  TInferenceRuleDirectionStats = record
    RuleName: ansistring;
    Direction: Integer;
    CandidatesGenerated: Integer;
    CandidatesAdmitted: Integer;
    CandidatesPrunedBeam: Integer;
    CandidatesPrunedVisited: Integer;
    CandidatesLocalDeduplicated: Integer;
    CandidatesAbandonedSuccess: Integer;
  end;

  TArrayOfInferenceRuleDirectionStats = array of TInferenceRuleDirectionStats;

  TInferenceSearchStats = record
    CandidatesGenerated: Integer;
    CandidatesAdmitted: Integer;
    CandidatesPrunedBeam: Integer;
    CandidatesPrunedVisited: Integer;
    CandidatesLocalDeduplicated: Integer;
    CandidatesAbandonedSuccess: Integer;
    ForwardCandidates: Integer;
    ReverseCandidates: Integer;
    ExpandedStates: Integer;
    MaxCandidateQueue: Integer;
    MaxRetainedFrontier: Integer;
    RuleDirections: TArrayOfInferenceRuleDirectionStats;
  end;
  PInferenceSearchStats = ^TInferenceSearchStats;

  TMatchOp = (
    moCheckObj,
    moCheckTokenId,
    moCheckInteger,
    moMoveLHS,
    moMoveRHS,
    moCheckEOT,
    moBindNode,
    moCheckBindEq,
    moBindTail,
    moSplit,
    moJump,
    moGuard,
    moAccept,
    moFail
  );

  TInstr = packed record
    Op: TMatchOp;
    A: Integer;
    B: Integer;
  end;

  TMatchBindings = record
  public
    NodeRefs: array of Integer;
    TailRefs: array of Integer;

    procedure Init(ABindCount: Integer);
    procedure Clear;
    function Clone: TMatchBindings;
  end;

  TGuardFunc = function(const Bindings: TMatchBindings; Tree: TCustomTree): Boolean;
  TGuardArray = array of TGuardFunc;

  TMatcherProgram = record
  public
    Code: array of TInstr;
    Guards: TGuardArray;
    BindCount: Integer;

    procedure Init(ABindCount: Integer);
    procedure Add(Op: TMatchOp; A: Integer = 0; B: Integer = 0);
    function AddGuard(const Guard: TGuardFunc): Integer;
  end;

function ExecuteMatcher(
  const AProgram: TMatcherProgram;
  Tree: TCustomTree;
  StartNode: Integer;
  out Bindings: TMatchBindings
): Boolean;

function BuildRule_ArrayHeadTail: TMatcherProgram;
function NodesStrictEqual(
  Tree: TCustomTree;
  A, B: Integer
): Boolean;
function CanRewriteOneStep(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  RulesRootIndex: Integer;
  Context: TContext;
  MatchSubexpressions: Boolean = False;
  CongruenceBudget: Integer = -1;
  BeamWidth: Integer = 1;
  UseCostPolicy: Boolean = False;
  OnInferenceEvent: TInferenceEventCallback = nil;
  InferenceEventUserData: Pointer = nil;
  SearchStats: PInferenceSearchStats = nil
): Boolean;
function CanRewriteWithinSteps(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  RulesRootIndex: Integer;
  Context: TContext;
  MaxSteps: Integer;
  MatchSubexpressions: Boolean = False;
  CongruenceBudget: Integer = -1;
  BeamWidth: Integer = 1;
  UseCostPolicy: Boolean = False;
  OnInferenceEvent: TInferenceEventCallback = nil;
  InferenceEventUserData: Pointer = nil;
  SearchStats: PInferenceSearchStats = nil
): Boolean;
function RewriteOneByRules(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  RulesRootIndex: Integer;
  Context: TContext;
  out RewrittenIndex: Integer;
  MatchSubexpressions: Boolean = False;
  AllowRootPrefixTail: Boolean = False;
  CongruenceBudget: PInteger = nil;
  SearchStartIndex: Integer = EOT
): Boolean;

var
  MatcherGuardsEnabled: Boolean = True;
  MatcherBacktrackingEnabled: Boolean = False;
  MatcherSelectionStrategy: TSelectionStrategyKind = sskFirst;
  MatcherExhaustiveSelection: Boolean = False;
  MatcherContext: TContext = nil;
  LastRewriteRuleIndex: Integer = EOT;
  LastRewriteRuleName: ansistring = '';
  // 0 = forward, 1 = reverse
  LastRewriteDirection: Integer = 0;
  LastRewriteAnchorOrdinal: Integer = -1;

procedure LogDiagEvent(Context: TContext; const MessageText: ansistring); inline;
procedure LogTraceEvent(Context: TContext; const MessageText: ansistring); inline;

implementation

uses
  SysUtils, Classes, nodes, helpers, string_utils, runtime_settings, debugger_api,
  debugger_types, debugger_runtime;

var
  MatcherPatternVariablesFixed: Boolean = False;

procedure LogDiagEvent(Context: TContext; const MessageText: ansistring); inline;
begin
  if Assigned(Context) then
    Context.LogDiag(MessageText);
end;

procedure LogTraceEvent(Context: TContext; const MessageText: ansistring); inline;
begin
  if Assigned(Context) then
    Context.LogTrace(MessageText);
end;

function RewriteDirectionName(Direction: Integer): ansistring; inline;
begin
  case Direction of
    1: Result := 'reverse';
  else
    Result := 'forward';
  end;
end;

function RuleTraceText(Tree: TCustomTree; RuleIndex: Integer): ansistring;
begin
  if (not Assigned(Tree)) or (RuleIndex = EOT) then
    Exit('<unknown>');
  Result := nodes.GetNode(RuleIndex).TreeValue;
end;

procedure EmitDebuggerRewriteProbeEvent(
  Tree: TCustomTree;
  RuleIndex: Integer;
  SubjectIndex: Integer;
  Direction: Integer;
  Context: TContext
); inline;
var
  DebugFrame: TDebuggerFrame;
begin
  if not DebuggerAttached then
    Exit;
  DebugFrame := TDebuggerFrame.Create(
    dfkRewriteProbe,
    RuleTraceText(Tree, RuleIndex),
    nodes.GetNode(SubjectIndex).TreeValue,
    SubjectIndex,
    RuleIndex
  );
  EmitDebuggerEvent(
    dekRewriteProbe,
    DebugFrame,
    'direction=' + RewriteDirectionName(Direction)
  );
  HandleDebuggerPause(Context);
end;

procedure EmitDebuggerInferenceStateEvent(
  Tree: TCustomTree;
  RootIndex: Integer;
  Step: Integer;
  StateId: Integer;
  RemainingBudget: Integer;
  Entering: Boolean;
  Context: TContext
); inline;
var
  DebugFrame: TDebuggerFrame;
  MessageText: ansistring;
begin
  if not DebuggerAttached then
    Exit;
  if Entering then
    DebugFrame := TDebuggerFrame.Create(
      dfkInferenceState,
      'state',
      nodes.GetNode(RootIndex).TreeValue,
      RootIndex
    )
  else
    DebugFrame := TDebuggerFrame.Create(
      dfkInferenceState,
      'state',
      '',
      RootIndex
    );
  DebugFrame.Step := Step;
  DebugFrame.StateId := StateId;
  MessageText := 'budget=' + IntToStr(RemainingBudget);
  if Entering then
    EmitDebuggerEvent(dekInferenceStateEnter, DebugFrame, MessageText)
  else
    EmitDebuggerEvent(dekInferenceStateExit, DebugFrame, MessageText);
  HandleDebuggerPause(Context);
end;

procedure EmitDebuggerInferenceCandidateEvent(
  Tree: TCustomTree;
  RootIndex: Integer;
  Step: Integer;
  ParentStateId: Integer;
  RuleIndex: Integer;
  const RuleName: ansistring;
  Direction: Integer;
  Context: TContext
); inline;
var
  DebugFrame: TDebuggerFrame;
  DisplayName: ansistring;
begin
  if not DebuggerAttached then
    Exit;
  if RootIndex = EOT then
    Exit;
  DisplayName := RuleName;
  if DisplayName = '' then
    DisplayName := RuleTraceText(Tree, RuleIndex);
  DebugFrame := TDebuggerFrame.Create(
    dfkInferenceState,
    DisplayName,
    nodes.GetNode(RootIndex).TreeValue,
    RootIndex,
    RuleIndex
  );
  DebugFrame.Step := Step;
  DebugFrame.ParentStateId := ParentStateId;
  EmitDebuggerEvent(
    dekInferenceCandidate,
    DebugFrame,
    'direction=' + RewriteDirectionName(Direction)
  );
end;

procedure EmitInferenceEvent(
  Tree: TCustomTree;
  OnInferenceEvent: TInferenceEventCallback;
  InferenceEventUserData: Pointer;
  Kind: TInferenceEventKind;
  Step: Integer;
  StateId: Integer;
  ParentStateId: Integer;
  RuleIndex: Integer;
  const RuleName: ansistring;
  Direction: Integer;
  OrientationExplicit: Integer;
  SubjectBefore: Integer;
  SubjectAfter: Integer;
  AnchorOrdinal: Integer
); inline;
var
  EventData: TInferenceEvent;
begin
  if not Assigned(OnInferenceEvent) then
    Exit;
  EventData.Kind := Kind;
  EventData.Step := Step;
  EventData.StateId := StateId;
  EventData.ParentStateId := ParentStateId;
  EventData.RuleIndex := RuleIndex;
  EventData.RuleName := RuleName;
  EventData.Direction := Direction;
  EventData.OrientationExplicit := OrientationExplicit;
  EventData.SubjectBefore := SubjectBefore;
  EventData.SubjectAfter := SubjectAfter;
  EventData.AnchorOrdinal := AnchorOrdinal;
  OnInferenceEvent(Tree, EventData, InferenceEventUserData);
end;

const
  SUBSTITUTION_STRICT_SETTING = 'mantra.substitution.strict';
  SUBSTITUTION_STRICT_SETTING_LEGACY = '__substitution_strict';
  INFERENCE_ANCHORS_PER_RULE_SETTING = 'mantra.inference.anchors_per_rule';

const
  MID_OBJ_CATEGORY_MASK = nodes.OBJ_CATEGORY_MASK;
  MID_OBJ_VARIABLE = nodes.OBJ_VARIABLE;
  MID_OBJ_INTEGER = nodes.OBJ_INTEGER;
  MID_OBJ_SCOPE = nodes.OBJ_SCOPE;
  MID_OBJ_EXPRESSION = nodes.OBJ_EXPRESSION;
  MID_OBJ_ARRAY = nodes.OBJ_ARRAY;
  MID_OBJ_EVALUATION = nodes.OBJ_EVALUATION;
  MID_OBJ_SEPARATOR = nodes.OBJ_SEPARATOR;
  MID_OBJ_TRANSFORMATION = nodes.OBJ_TRANSFORMATION;
  MID_OBJ_EQUIVALENCE = nodes.OBJ_EQUIVALENCE;
  MID_OBJ_INLINE_TRANSFORMATION = nodes.OBJ_INLINE_TRANSFORMATION;
  MID_OBJ_SUBST_TRANSFORMATION = nodes.OBJ_SUBST_TRANSFORM;
  MID_OBJ_SYMBOL_SUBST_TRANSFORMATION = nodes.OBJ_SYMBOL_SUBST_TRANSFORM;
  MID_OBJ_SUBST_EQUIVALENCE = nodes.OBJ_SUBST_EQUIVALENCE;
  MID_OBJ_MATCH_ANY = nodes.OBJ_MATCH_ANY;
  MID_OBJ_RANGE = nodes.OBJ_RANGE;
  MID_OBJ_STRING = nodes.OBJ_STRING;
  MID_OBJ_VARIABLE_SUBTREE = nodes.OBJ_VARIABLE_SUBTREE;
  MID_OBJ_RULE_FORWARD = nodes.OBJ_RULE_FORWARD;
  MID_OBJ_RULE_REVERSE = nodes.OBJ_RULE_REVERSE;

type
  TBacktrackState = record
    PC: Integer;
    Cur: Integer;
    Bindings: TMatchBindings;
  end;

  TRewriteDirection = (
    rdForward,
    rdReverse
  );

  TInferenceRuleOrientation = (
    iroDefault,
    iroForwardOnly,
    iroReverseOnly
  );

  TRewriteCandidate = record
    RuleIndex: Integer;
    Direction: TRewriteDirection;
  end;

  TArrayOfRewriteCandidate = array of TRewriteCandidate;
  TArrayOfString = array of ansistring;
  TCollectedRuleRef = record
    RuleIndex: Integer;
    PreparedRuleIndex: Integer;
    RuleName: ansistring;
    ForceFixed: Boolean;
    Orientation: TInferenceRuleOrientation;
  end;
  TArrayOfCollectedRuleRef = array of TCollectedRuleRef;

  TRewriteProbe = record
    RuleIndex: Integer;
    Direction: TRewriteDirection;
    AnchorNode: Integer;
    EffectivePatternIndex: Integer;
    EffectiveReplaceIndex: Integer;
    GuardTemplateIndex: Integer;
    MatchHead: Integer;
    MatchTail: Integer;
    TargetHead: Integer;
    TargetTail: Integer;
    FocusHead: Integer;
    FocusTail: Integer;
    UseFocusTarget: Boolean;
    Symbols: TArrayOfString;
    Bindings: TMatchBindings;
  end;

  TSubstitutionEntry = record
    Symbol: ansistring;
    Replacement: Integer;
  end;

  TArrayOfSubstitutionEntry = array of TSubstitutionEntry;

procedure TMatchBindings.Init(ABindCount: Integer);
var
  I: Integer;
begin
  SetLength(NodeRefs, ABindCount);
  SetLength(TailRefs, ABindCount);
  for I := 0 to ABindCount - 1 do
  begin
    NodeRefs[I] := EOT;
    TailRefs[I] := EOT;
  end;
end;

procedure TMatchBindings.Clear;
begin
  Init(Length(NodeRefs));
end;

function TMatchBindings.Clone: TMatchBindings;
begin
  Result.NodeRefs := Copy(NodeRefs);
  Result.TailRefs := Copy(TailRefs);
end;

procedure TMatcherProgram.Init(ABindCount: Integer);
begin
  Code := nil;
  Guards := nil;
  BindCount := ABindCount;
end;

procedure TMatcherProgram.Add(Op: TMatchOp; A: Integer = 0; B: Integer = 0);
var
  L: Integer;
begin
  L := Length(Code);
  SetLength(Code, L + 1);
  Code[L].Op := Op;
  Code[L].A := A;
  Code[L].B := B;
end;

function TMatcherProgram.AddGuard(const Guard: TGuardFunc): Integer;
var
  L: Integer;
begin
  L := Length(Guards);
  SetLength(Guards, L + 1);
  Guards[L] := Guard;
  Result := L;
end;

function ExecuteMatcher(
  const AProgram: TMatcherProgram;
  Tree: TCustomTree;
  StartNode: Integer;
  out Bindings: TMatchBindings
): Boolean;
var
  PC, Cur: Integer;
  Instr: TInstr;
  Env: TMatchBindings;
  Stack: array of TBacktrackState;
  StackTop: Integer;

  procedure PushState(APC, ACur: Integer; const AEnv: TMatchBindings);
  begin
    Inc(StackTop);
    SetLength(Stack, StackTop + 1);
    Stack[StackTop].PC := APC;
    Stack[StackTop].Cur := ACur;
    Stack[StackTop].Bindings := AEnv.Clone;
  end;

  function PopState(out APC, ACur: Integer; out AEnv: TMatchBindings): Boolean;
  begin
    Result := StackTop >= 0;
    if Result then
    begin
      APC := Stack[StackTop].PC;
      ACur := Stack[StackTop].Cur;
      AEnv := Stack[StackTop].Bindings;
      SetLength(Stack, StackTop);
      Dec(StackTop);
    end;
  end;

  function IsBindIndexValid(Index: Integer): Boolean;
  begin
    Result := (Index >= 0) and (Index < Length(Env.NodeRefs));
  end;

  function FailStep: Boolean;
  begin
    Result := PopState(PC, Cur, Env);
  end;

begin
  Result := False;
  Bindings.Init(0);
  if not Assigned(Tree) then Exit;
  if Length(AProgram.Code) = 0 then Exit;

  Env.Init(AProgram.BindCount);
  Stack := nil;
  StackTop := -1;
  PC := 0;
  Cur := StartNode;

  while True do
  begin
    if (PC < 0) or (PC > High(AProgram.Code)) then
    begin
      if not FailStep then Exit(False);
      Continue;
    end;

    Instr := AProgram.Code[PC];
    case Instr.Op of
      moCheckObj:
        begin
          if (Cur = EOT) or (Tree[Cur]^.Id <> Instr.A) then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moCheckTokenId:
        begin
          if (Cur = EOT) or (Tree.Expression.TokenID(Tree[Cur]^.Ref) <> Instr.A) then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moCheckInteger:
        begin
          if (Cur = EOT) or (Tree[Cur]^.Id <> MID_OBJ_INTEGER) or
             (StrToIntDef(Tree.Expression.TokenValue(Tree[Cur]^.Ref), MaxInt) <> Instr.A) then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moMoveLHS:
        begin
          if Cur = EOT then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Cur := Tree[Cur]^.LHS;
          Inc(PC);
        end;

      moMoveRHS:
        begin
          if Cur = EOT then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Cur := Tree[Cur]^.RHS;
          Inc(PC);
        end;

      moCheckEOT:
        begin
          if ((Instr.A <> 0) and (Cur <> EOT)) or
             ((Instr.A = 0) and (Cur = EOT)) then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moBindNode:
        begin
          if not IsBindIndexValid(Instr.A) then
            raise Exception.CreateFmt('Invalid bind index %d', [Instr.A]);
          if Cur = EOT then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          if Env.NodeRefs[Instr.A] = EOT then
            Env.NodeRefs[Instr.A] := Cur
          else if Env.NodeRefs[Instr.A] <> Cur then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moCheckBindEq:
        begin
          if not IsBindIndexValid(Instr.A) then
            raise Exception.CreateFmt('Invalid bind index %d', [Instr.A]);
          if (Env.NodeRefs[Instr.A] = EOT) or (Cur <> Env.NodeRefs[Instr.A]) then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moBindTail:
        begin
          if not IsBindIndexValid(Instr.A) then
            raise Exception.CreateFmt('Invalid bind index %d', [Instr.A]);
          if Cur = EOT then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Env.TailRefs[Instr.A] := Tree[Cur]^.RHS;
          Inc(PC);
        end;

      moSplit:
        begin
          PushState(Instr.B, Cur, Env);
          PC := Instr.A;
        end;

      moJump:
        PC := Instr.A;

      moGuard:
        begin
          if (Instr.A < 0) or (Instr.A > High(AProgram.Guards)) or
             (not Assigned(AProgram.Guards[Instr.A])) or
             (not AProgram.Guards[Instr.A](Env, Tree)) then
          begin
            if not FailStep then Exit(False);
            Continue;
          end;
          Inc(PC);
        end;

      moAccept:
        begin
          Bindings := Env;
          Exit(True);
        end;

      moFail:
        begin
          if not FailStep then Exit(False);
        end;
    end;
  end;
end;

function BuildRule_ArrayHeadTail: TMatcherProgram;
begin
  Result.Init(1);
  Result.Add(moCheckObj, MID_OBJ_ARRAY);
  Result.Add(moMoveLHS);
  Result.Add(moCheckEOT, 0);
  Result.Add(moBindNode, 0);
  Result.Add(moBindTail, 0);
  Result.Add(moAccept);
end;

type
  TArrayOfInteger = TSelectionIndexArray;

procedure AddStringIfMissing(var Values: TArrayOfString; const Value: ansistring);
var
  I: Integer;
begin
  for I := 0 to High(Values) do
    if Values[I] = Value then
      Exit;
  SetLength(Values, Length(Values) + 1);
  Values[High(Values)] := Value;
end;

function FindString(const Values: TArrayOfString; const Value: ansistring): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Values) do
    if Values[I] = Value then
      Exit(I);
  Result := -1;
end;

procedure AddInteger(var Values: TArrayOfInteger; Value: Integer);
begin
  SetLength(Values, Length(Values) + 1);
  Values[High(Values)] := Value;
end;

procedure AddRewriteCandidate(
  var Candidates: TArrayOfRewriteCandidate;
  RuleIndex: Integer;
  Direction: TRewriteDirection
);
begin
  SetLength(Candidates, Length(Candidates) + 1);
  Candidates[High(Candidates)].RuleIndex := RuleIndex;
  Candidates[High(Candidates)].Direction := Direction;
end;

function IsTransformationNode(NodeId: Integer): Boolean;
begin
  Result := (NodeId = MID_OBJ_TRANSFORMATION) or
            (NodeId = MID_OBJ_EQUIVALENCE) or
            (NodeId = MID_OBJ_INLINE_TRANSFORMATION) or
            (NodeId = MID_OBJ_SUBST_TRANSFORMATION) or
            (NodeId = MID_OBJ_SYMBOL_SUBST_TRANSFORMATION) or
            (NodeId = MID_OBJ_SUBST_EQUIVALENCE);
end;

function IsFixedTransformationRule(Tree: TCustomTree; RuleIndex: Integer): Boolean;
begin
  Result := Assigned(Tree) and (RuleIndex <> EOT) and
            IsTransformationNode(Tree[RuleIndex]^.Id) and
            ((Tree[RuleIndex]^.Data and TK_FIXED) = TK_FIXED);
end;

function IsVariableNode(NodeId: Integer): Boolean;
begin
  Result := NodeId = MID_OBJ_VARIABLE;
end;

function IsMatchAnyNode(NodeId: Integer): Boolean;
begin
  Result := NodeId = MID_OBJ_MATCH_ANY;
end;

function IsIdentifierNode(NodeId: Integer): Boolean;
begin
  Result := ((NodeId and MID_OBJ_CATEGORY_MASK) = TK_IDENTIFIER) or
            (NodeId = MID_OBJ_VARIABLE_SUBTREE);
end;

function IsScopeNode(NodeId: Integer): Boolean;
begin
  Result := (NodeId and MID_OBJ_CATEGORY_MASK) = MID_OBJ_SCOPE;
end;

function OperatorsMatchForPattern(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer
): Boolean;
var
  PatternOp: Integer;
  SubjectOp: Integer;
begin
  PatternOp := Tree[PatternIndex]^.Data and TK_OPERATOR_MASK;
  SubjectOp := Tree[SubjectIndex]^.Data and TK_OPERATOR_MASK;

  if PatternOp = SubjectOp then
    Exit(True);

  // Allow plain scope patterns to match operator-decorated scope subjects.
  // This keeps rules such as:
  //   inner_product [ X -- ] [ Y -- ]
  // matching subjects produced by sticky expansion:
  //   + inner_product + [ ... ] + [ ... ].
  if (PatternOp = 0) and IsScopeNode(Tree[PatternIndex]^.Id) then
    Exit(True);

  Result := False;
end;

function ResolveSubjectVariableNode(
  Tree: TCustomTree;
  SubjectIndex: Integer
): Integer;
const
  MAX_SUBJECT_RESOLVE_DEPTH = 32;
var
  Cur: Integer;
  Step: Integer;
  Name: ansistring;
  SourceRef: Integer;
  SelectorBits: Integer;
begin
  Result := SubjectIndex;
  if (SubjectIndex = EOT) or (not Assigned(MatcherContext)) then
    Exit;

  Cur := SubjectIndex;
  for Step := 0 to MAX_SUBJECT_RESOLVE_DEPTH - 1 do
  begin
    if Cur = EOT then
      Exit(EOT);

    if not IsVariableNode(Tree[Cur]^.Id) then
      Exit(Cur);

    Name := Tree.Expression.TokenValue(Tree[Cur]^.Ref);
    if (Name = '') or (not MatcherContext.TryFindVariable(Name, SourceRef)) then
      Exit(Cur);

    SelectorBits := Tree[Cur]^.Data and TK_SELECTOR_MASK;
    case SelectorBits of
      TK_SELECTOR_LHS: Cur := Tree[SourceRef]^.LHS;
      TK_SELECTOR_RHS: Cur := Tree[SourceRef]^.RHS;
    else
      Cur := SourceRef;
    end;
  end;

  Result := Cur;
end;

function CreateDetachedVariableSymbolNode(Tree: TCustomTree; SymbolRef: Integer): Integer;
begin
  Result := Tree.AllocateNode;
  nodes.TVariableNode.InitTreeNode(Result);
  Tree[Result]^.Ref := SymbolRef;
  Tree[Result]^.LHS := EOT;
  Tree[Result]^.RHS := EOT;
end;

function IsGuardNode(Tree: TCustomTree; Index: Integer): Boolean;
begin
  Result := (Index <> EOT) and ((Tree[Index]^.Data and TK_TILDE) = TK_TILDE);
end;

procedure AddCollectedRuleRef(
  var RuleRefs: TArrayOfCollectedRuleRef;
  RuleIndex: Integer;
  const RuleName: ansistring;
  ForceFixed: Boolean;
  Orientation: TInferenceRuleOrientation
);
var
  L: Integer;
begin
  if RuleIndex = EOT then
    Exit;
  L := Length(RuleRefs);
  SetLength(RuleRefs, L + 1);
  RuleRefs[L].RuleIndex := RuleIndex;
  RuleRefs[L].PreparedRuleIndex := EOT;
  RuleRefs[L].RuleName := RuleName;
  RuleRefs[L].ForceFixed := ForceFixed;
  RuleRefs[L].Orientation := Orientation;
end;

procedure CollectRuleRefs(
  Tree: TCustomTree;
  Context: TContext;
  Index: Integer;
  var RuleRefs: TArrayOfCollectedRuleRef;
  const PreferredName: ansistring = '';
  Depth: Integer = 0;
  ForceFixed: Boolean = False;
  Orientation: TInferenceRuleOrientation = iroDefault
);
const
  MAX_RULE_REF_RESOLVE_DEPTH = 64;
var
  NodeId: Integer;
  VariableName: ansistring;
  SourceRef: Integer;
  EffectiveName: ansistring;
  ResolvedNodeId: Integer;
  EffectiveForceFixed: Boolean;
begin
  if (not Assigned(Tree)) or (Index = EOT) then
    Exit;
  if Depth > MAX_RULE_REF_RESOLVE_DEPTH then
    Exit;

  NodeId := Tree[Index]^.Id;
  if IsTransformationNode(NodeId) then
  begin
    AddCollectedRuleRef(RuleRefs, Index, PreferredName, ForceFixed, Orientation);
    Exit;
  end;

  if NodeId = MID_OBJ_RULE_FORWARD then
  begin
    CollectRuleRefs(
      Tree, Context, Tree[Index]^.LHS, RuleRefs, PreferredName, Depth + 1,
      ForceFixed, iroForwardOnly
    );
    Exit;
  end;

  if NodeId = MID_OBJ_RULE_REVERSE then
  begin
    CollectRuleRefs(
      Tree, Context, Tree[Index]^.LHS, RuleRefs, PreferredName, Depth + 1,
      ForceFixed, iroReverseOnly
    );
    Exit;
  end;

  if NodeId = MID_OBJ_VARIABLE then
  begin
    if not Assigned(Context) then
      Exit;
    VariableName := Tree.Expression.TokenValue(Tree[Index]^.Ref);
    if (VariableName = '') or (not Context.TryFindVariable(VariableName, SourceRef)) or
       (SourceRef = EOT) then
      Exit;

    EffectiveName := PreferredName;
    if EffectiveName = '' then
      EffectiveName := VariableName;
    EffectiveForceFixed := ForceFixed or
                           ((Tree[Index]^.Data and TK_FIXED) = TK_FIXED);

    ResolvedNodeId := Tree[SourceRef]^.Id;
    if IsTransformationNode(ResolvedNodeId) or (ResolvedNodeId = MID_OBJ_VARIABLE) then
      CollectRuleRefs(
        Tree, Context, SourceRef, RuleRefs, EffectiveName, Depth + 1,
        EffectiveForceFixed, Orientation
      )
    else
      CollectRuleRefs(
        Tree, Context, SourceRef, RuleRefs, '', Depth + 1,
        EffectiveForceFixed, Orientation
      );
    Exit;
  end;

  if (NodeId = MID_OBJ_ARRAY) or (NodeId = MID_OBJ_EXPRESSION) or
     (NodeId = MID_OBJ_EVALUATION) or (NodeId = MID_OBJ_SEPARATOR) then
  begin
    CollectRuleRefs(
      Tree, Context, Tree[Index]^.LHS, RuleRefs, PreferredName, Depth,
      ForceFixed, Orientation
    );
    CollectRuleRefs(
      Tree, Context, Tree[Index]^.RHS, RuleRefs, PreferredName, Depth,
      ForceFixed, Orientation
    );
    Exit;
  end;

  CollectRuleRefs(
    Tree, Context, Tree[Index]^.LHS, RuleRefs, PreferredName, Depth,
    ForceFixed, Orientation
  );
  CollectRuleRefs(
    Tree, Context, Tree[Index]^.RHS, RuleRefs, PreferredName, Depth,
    ForceFixed, Orientation
  );
end;

procedure PrepareCollectedRuleRefs(
  Tree: TCustomTree;
  Context: TContext;
  var RuleRefs: TArrayOfCollectedRuleRef
);
var
  I: Integer;
begin
  if not Assigned(Tree) then
    Exit;

  for I := 0 to High(RuleRefs) do
  begin
    RuleRefs[I].PreparedRuleIndex := Tree.CloneSubtree(RuleRefs[I].RuleIndex);
    if RuleRefs[I].PreparedRuleIndex <> EOT then
    begin
      if RuleRefs[I].ForceFixed then
        Tree[RuleRefs[I].PreparedRuleIndex]^.Data :=
          Tree[RuleRefs[I].PreparedRuleIndex]^.Data or TK_FIXED;
      if Assigned(Context) then
        NormalizeTransformOperands(Tree, Context, RuleRefs[I].PreparedRuleIndex);
    end;
  end;
end;

procedure ClearPreparedRuleRefs(
  Tree: TCustomTree;
  var RuleRefs: TArrayOfCollectedRuleRef
);
var
  I: Integer;
begin
  if not Assigned(Tree) then
    Exit;

  for I := 0 to High(RuleRefs) do
  begin
    if RuleRefs[I].PreparedRuleIndex <> EOT then
      Tree.DeleteSubtree(EOT, RuleRefs[I].PreparedRuleIndex);
    RuleRefs[I].PreparedRuleIndex := EOT;
  end;
end;

function EffectiveCollectedRuleIndex(const RuleRef: TCollectedRuleRef): Integer; inline;
begin
  if RuleRef.PreparedRuleIndex <> EOT then
    Exit(RuleRef.PreparedRuleIndex);
  Result := RuleRef.RuleIndex;
end;

procedure CollectPatternSymbols(Tree: TCustomTree; Index: Integer; var Symbols: TArrayOfString);
var
  Cur: Integer;
  Name: ansistring;
begin
  Cur := Index;
  while Cur <> EOT do
  begin
    if IsVariableNode(Tree[Cur]^.Id) then
    begin
      Name := Tree.Expression.TokenValue(Tree[Cur]^.Ref);
      if Name <> '' then
        AddStringIfMissing(Symbols, Name);
    end;

    if (Tree[Cur]^.Id = MID_OBJ_VARIABLE_SUBTREE) and
       (Tree[Cur]^.Ref <> EOT) then
    begin
      Name := Tree.Expression.TokenValue(Tree[Cur]^.Ref);
      if (Name <> '') and (Name[1] <> '"') then
        AddStringIfMissing(Symbols, Name);
    end;

    CollectPatternSymbols(Tree, Tree[Cur]^.LHS, Symbols);
    Cur := Tree[Cur]^.RHS;
  end;
end;

function HasSameSymbols(const A, B: TArrayOfString): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  for I := 0 to High(A) do
    if FindString(B, A[I]) = -1 then
      Exit(False);
  Result := True;
end;

function HasStrictSubstitutionShape(
  Tree: TCustomTree;
  PatternIndex: Integer;
  ReplaceIndex: Integer
): Boolean;
var
  LhsSymbols: TArrayOfString;
  RhsSymbols: TArrayOfString;
begin
  LhsSymbols := nil;
  RhsSymbols := nil;
  CollectPatternSymbols(Tree, PatternIndex, LhsSymbols);
  CollectPatternSymbols(Tree, ReplaceIndex, RhsSymbols);
  Result := HasSameSymbols(LhsSymbols, RhsSymbols);
end;

function IsStrictSubstitutionEnabled(
  Tree: TCustomTree;
  Context: TContext
): Boolean;
var
  StrictValue: Boolean;
  SourceName: ansistring;
  ReadResult: TSettingReadResult;
begin
  Result := True;
  ReadResult := ReadBooleanSetting(
    Tree,
    Context,
    [SUBSTITUTION_STRICT_SETTING, SUBSTITUTION_STRICT_SETTING_LEGACY],
    StrictValue,
    SourceName
  );
  case ReadResult of
    srrFound:
      Result := StrictValue;
    srrInvalid:
      begin
        if Assigned(Context) and Context.EventEnabled(ellDiag) then
          Context.LogDiag(
            Format('invalid %s value (expected boolean or 0/1)', [SourceName])
          );
        Result := True;
      end;
  end;
end;

function CountPatternFocusMarkers(Tree: TCustomTree; Index: Integer): Integer;
var
  Cur: Integer;
begin
  Result := 0;
  Cur := Index;
  while Cur <> EOT do
  begin
    if (Tree[Cur]^.Data and TK_DOT) = TK_DOT then
      Inc(Result);
    Inc(Result, CountPatternFocusMarkers(Tree, Tree[Cur]^.LHS));
    Cur := Tree[Cur]^.RHS;
  end;
end;

procedure CollectSequenceNodes(
  Tree: TCustomTree;
  Index: Integer;
  var Nodes: TArrayOfInteger
);
var
  Cur: Integer;
  Next: Integer;
begin
  Cur := Index;
  while Cur <> EOT do
  begin
    AddInteger(Nodes, Cur);
    if Tree[Cur]^.Id = MID_OBJ_RANGE then
    begin
      Next := Tree[Cur]^.RHS;
      if Next <> EOT then
        Cur := Tree[Next]^.RHS
      else
        Cur := EOT;
      Continue;
    end;
    Cur := Tree[Cur]^.RHS;
  end;
end;

function ConsumeFirstCaretInSubtree(Tree: TCustomTree; StartIndex: Integer): Integer;
  function Walk(NodeIndex: Integer): Integer;
  var
    Found: Integer;
  begin
    Result := EOT;
    while NodeIndex <> EOT do
    begin
      if (Tree[NodeIndex]^.Data and TK_CARET) = TK_CARET then
      begin
        Tree[NodeIndex]^.Data := Tree[NodeIndex]^.Data and (not TK_CARET);
        Exit(NodeIndex);
      end;

      Found := Walk(Tree[NodeIndex]^.LHS);
      if Found <> EOT then
        Exit(Found);

      NodeIndex := Tree[NodeIndex]^.RHS;
    end;
  end;
begin
  if (not Assigned(Tree)) or (StartIndex = EOT) then
    Exit(EOT);
  Result := Walk(StartIndex);
end;

function TryParseIntegerNode(Tree: TCustomTree; NodeIndex: Integer; out Value: Int64): Boolean;
begin
  Result := False;
  Value := 0;
  if (NodeIndex = EOT) or (Tree[NodeIndex]^.Id <> MID_OBJ_INTEGER) or (Tree[NodeIndex]^.Ref = EOT) then
    Exit(False);
  Result := TryStrToInt64(Tree.Expression.TokenValue(Tree[NodeIndex]^.Ref), Value);
end;

function TryParseStringCharNode(Tree: TCustomTree; NodeIndex: Integer; out Value: Integer): Boolean;
var
  Raw: ansistring;
begin
  Result := False;
  Value := 0;
  if (NodeIndex = EOT) or (Tree[NodeIndex]^.Id <> MID_OBJ_STRING) or (Tree[NodeIndex]^.Ref = EOT) then
    Exit(False);
  Raw := Tree.Expression.TokenValue(Tree[NodeIndex]^.Ref);
  Result := UnquoteSingleChar(Raw, Value);
end;

function IsWithinInclusiveRange(AValue, AStart, AEnd: Int64): Boolean; inline;
begin
  if AStart <= AEnd then
    Exit((AValue >= AStart) and (AValue <= AEnd));
  Result := (AValue <= AStart) and (AValue >= AEnd);
end;

function MatchRangePredicate(Tree: TCustomTree; PatternIndex, SubjectIndex: Integer): Boolean;
var
  StartIndex, EndIndex: Integer;
  SubjectInt, StartInt, EndInt: Int64;
  SubjectChar, StartChar, EndChar: Integer;
begin
  Result := False;
  if PatternIndex = EOT then
    Exit(False);

  StartIndex := Tree[PatternIndex]^.LHS;
  EndIndex := Tree[PatternIndex]^.RHS;
  if (StartIndex = EOT) or (EndIndex = EOT) then
    Exit(False);

  if TryParseIntegerNode(Tree, SubjectIndex, SubjectInt) and
     TryParseIntegerNode(Tree, StartIndex, StartInt) and
     TryParseIntegerNode(Tree, EndIndex, EndInt) then
    Exit(IsWithinInclusiveRange(SubjectInt, StartInt, EndInt));

  if TryParseStringCharNode(Tree, SubjectIndex, SubjectChar) and
     TryParseStringCharNode(Tree, StartIndex, StartChar) and
     TryParseStringCharNode(Tree, EndIndex, EndChar) then
    Exit(IsWithinInclusiveRange(SubjectChar, StartChar, EndChar));
end;

function NodeEquivalent(Tree: TCustomTree; A, B: Integer; IncludeRHS: Boolean): Boolean;
var
  AToken, BToken: ansistring;
begin
  if (A = EOT) or (B = EOT) then
    Exit(A = B);

  if Tree[A]^.Id <> Tree[B]^.Id then
    Exit(False);

  if not OperatorsMatchForPattern(Tree, A, B) then
    Exit(False);
  if (Tree[A]^.Data and TK_SELECTOR_MASK) <> (Tree[B]^.Data and TK_SELECTOR_MASK) then
    Exit(False);

  if (Tree[A]^.Ref <> EOT) and (Tree[B]^.Ref <> EOT) then
  begin
    AToken := Tree.Expression.TokenValue(Tree[A]^.Ref);
    BToken := Tree.Expression.TokenValue(Tree[B]^.Ref);
    if AToken <> BToken then
      Exit(False);
  end;

  if not NodeEquivalent(Tree, Tree[A]^.LHS, Tree[B]^.LHS, True) then
    Exit(False);

  if IncludeRHS then
    Exit(NodeEquivalent(Tree, Tree[A]^.RHS, Tree[B]^.RHS, True));

  Result := True;
end;

function VariablePatternOperatorMatches(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer
): Boolean;
var
  PatternOp: Integer;
  SubjectOp: Integer;
begin
  PatternOp := Tree[PatternIndex]^.Data and TK_OPERATOR_MASK;
  if PatternOp = 0 then
    Exit(True);

  SubjectOp := Tree[SubjectIndex]^.Data and TK_OPERATOR_MASK;
  Result := PatternOp = SubjectOp;
end;

function NodeEquivalentForBinding(
  Tree: TCustomTree;
  A, B: Integer;
  IncludeRHS: Boolean
): Boolean;
var
  AToken, BToken: ansistring;
begin
  if (A = EOT) or (B = EOT) then
    Exit(A = B);

  if Tree[A]^.Id <> Tree[B]^.Id then
    Exit(False);

  if (Tree[A]^.Data and TK_SELECTOR_MASK) <> (Tree[B]^.Data and TK_SELECTOR_MASK) then
    Exit(False);

  if (Tree[A]^.Ref <> EOT) and (Tree[B]^.Ref <> EOT) then
  begin
    AToken := Tree.Expression.TokenValue(Tree[A]^.Ref);
    BToken := Tree.Expression.TokenValue(Tree[B]^.Ref);
    if AToken <> BToken then
      Exit(False);
  end;

  if not NodeEquivalent(Tree, Tree[A]^.LHS, Tree[B]^.LHS, True) then
    Exit(False);

  if IncludeRHS then
    Exit(NodeEquivalent(Tree, Tree[A]^.RHS, Tree[B]^.RHS, True));

  Result := True;
end;

function StrictNodeEquivalent(
  Tree: TCustomTree;
  A, B: Integer;
  IncludeRHS: Boolean
): Boolean;
var
  AToken, BToken: ansistring;
begin
  if (A = EOT) or (B = EOT) then
    Exit(A = B);

  if Tree[A]^.Id <> Tree[B]^.Id then
    Exit(False);

  if (Tree[A]^.Data and TK_OPERATOR_MASK) <> (Tree[B]^.Data and TK_OPERATOR_MASK) then
    Exit(False);
  if (Tree[A]^.Data and TK_SELECTOR_MASK) <> (Tree[B]^.Data and TK_SELECTOR_MASK) then
    Exit(False);

  if (Tree[A]^.Ref = EOT) xor (Tree[B]^.Ref = EOT) then
    Exit(False);
  if (Tree[A]^.Ref <> EOT) and (Tree[B]^.Ref <> EOT) then
  begin
    AToken := Tree.Expression.TokenValue(Tree[A]^.Ref);
    BToken := Tree.Expression.TokenValue(Tree[B]^.Ref);
    if AToken <> BToken then
      Exit(False);
  end;

  if not StrictNodeEquivalent(Tree, Tree[A]^.LHS, Tree[B]^.LHS, True) then
    Exit(False);

  if IncludeRHS then
    Exit(StrictNodeEquivalent(Tree, Tree[A]^.RHS, Tree[B]^.RHS, True));

  Result := True;
end;

function NodesStrictEqual(
  Tree: TCustomTree;
  A, B: Integer
): Boolean;
begin
  Result := StrictNodeEquivalent(Tree, A, B, True);
end;

function MatchPatternSequence(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer;
  const Symbols: TArrayOfString;
  var Bindings: TMatchBindings;
  HasFocusMarker: Boolean;
  var FocusHead: Integer;
  var FocusTail: Integer
): Boolean; forward;

function MatchPatternSequenceEx(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer;
  const Symbols: TArrayOfString;
  var Bindings: TMatchBindings;
  HasFocusMarker: Boolean;
  var FocusHead: Integer;
  var FocusTail: Integer;
  AllowSubjectTail: Boolean;
  out RemainingSubjectTail: Integer;
  out MatchedSubjectHead: Integer
): Boolean; forward;

function IsSingleChildWrapperNode(Tree: TCustomTree; NodeIndex: Integer): Boolean;
var
  Child: Integer;
begin
  if (not Assigned(Tree)) or (NodeIndex = EOT) then
    Exit(False);
  Child := Tree[NodeIndex]^.LHS;
  Result := (Child <> EOT) and (Tree[Child]^.RHS = EOT);
end;

function IsTransparentEvalPatternWrapper(Tree: TCustomTree; PatternIndex: Integer): Boolean;
begin
  if (PatternIndex = EOT) or (Tree[PatternIndex]^.Id <> MID_OBJ_EVALUATION) then
    Exit(False);
  if not IsSingleChildWrapperNode(Tree, PatternIndex) then
    Exit(False);
  Result := (Tree[PatternIndex]^.Data and
             (TK_OPERATOR_MASK or TK_SELECTOR_MASK or TK_META_MASK)) = 0;
end;

function IsTransparentFixedExprPatternWrapper(Tree: TCustomTree; PatternIndex: Integer): Boolean;
var
  MetaBits: Integer;
begin
  if (PatternIndex = EOT) or (Tree[PatternIndex]^.Id <> MID_OBJ_EXPRESSION) then
    Exit(False);
  if not IsSingleChildWrapperNode(Tree, PatternIndex) then
    Exit(False);
  if (Tree[PatternIndex]^.Data and (TK_OPERATOR_MASK or TK_SELECTOR_MASK)) <> 0 then
    Exit(False);
  MetaBits := Tree[PatternIndex]^.Data and TK_META_MASK;
  Result := MetaBits = TK_FIXED;
end;

function IsTransparentFixedExprPatternSequenceWrapper(
  Tree: TCustomTree;
  PatternIndex: Integer
): Boolean;
var
  MetaBits: Integer;
begin
  if (PatternIndex = EOT) or (Tree[PatternIndex]^.Id <> MID_OBJ_EXPRESSION) then
    Exit(False);
  if Tree[PatternIndex]^.LHS = EOT then
    Exit(False);
  if (Tree[PatternIndex]^.Data and (TK_OPERATOR_MASK or TK_SELECTOR_MASK)) <> 0 then
    Exit(False);
  MetaBits := Tree[PatternIndex]^.Data and TK_META_MASK;
  Result := MetaBits = TK_FIXED;
end;

function PromoteLeadingFixedPatternSequence(
  Tree: TCustomTree;
  PatternIndex: Integer;
  Context: TContext
): Integer;
var
  NextPatternNode: Integer;
  PromotedIndex: Integer;
  TailSeparator: Integer;
  Name: ansistring;
begin
  Result := PatternIndex;
  if PatternIndex = EOT then
    Exit(EOT);

  PromotedIndex := Result;
  if IsTransparentFixedExprPatternSequenceWrapper(Tree, PromotedIndex) then
    PromotedIndex := Tree[PromotedIndex]^.LHS
  else if IsVariableNode(Tree[PromotedIndex]^.Id) then
  begin
    NextPatternNode := Tree[PromotedIndex]^.RHS;
    if (NextPatternNode <> EOT) and (Tree[NextPatternNode]^.RHS = EOT) and
       IsTransparentFixedExprPatternSequenceWrapper(Tree, NextPatternNode) then
    begin
      if Assigned(Context) then
      begin
        Name := Tree.Expression.TokenValue(Tree[PromotedIndex]^.Ref);
        if Context.IsKeyword(Name) then
          PromotedIndex := Tree[NextPatternNode]^.LHS;
      end;
    end;
  end;

  // Comma lists inside fixed wrappers follow rule-list assembly semantics:
  // the effective transform LHS is the tail column (last separator's LHS).
  if (PromotedIndex <> EOT) and (Tree[PromotedIndex]^.Id = MID_OBJ_SEPARATOR) then
  begin
    TailSeparator := Tree.LastSibling[PromotedIndex];
    if (TailSeparator <> EOT) and
       (Tree[TailSeparator]^.Id = MID_OBJ_SEPARATOR) and
       (Tree[TailSeparator]^.LHS <> EOT) then
      PromotedIndex := Tree[TailSeparator]^.LHS;
  end;

  Result := PromotedIndex;
end;

function MatchPatternNode(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer;
  const Symbols: TArrayOfString;
  var Bindings: TMatchBindings;
  HasFocusMarker: Boolean;
  var FocusHead: Integer;
  var FocusTail: Integer
): Boolean;
var
  Slot: Integer;
  Name: ansistring;
  SubjectName: ansistring;
  IsAny: Boolean;
  BoundNode: Integer;
begin
  Result := False;
  if (PatternIndex = EOT) or (SubjectIndex = EOT) then
    Exit;

  if IsVariableNode(Tree[PatternIndex]^.Id) then
  begin
    if MatcherPatternVariablesFixed then
    begin
      SubjectIndex := ResolveSubjectVariableNode(Tree, SubjectIndex);
      if (SubjectIndex = EOT) or (not IsVariableNode(Tree[SubjectIndex]^.Id)) then
        Exit(False);
      Exit(StrictNodeEquivalent(Tree, PatternIndex, SubjectIndex, False));
    end;

    Name := Tree.Expression.TokenValue(Tree[PatternIndex]^.Ref);
    if Assigned(MatcherContext) and MatcherContext.IsKeyword(Name) then
    begin
      if not IsIdentifierNode(Tree[SubjectIndex]^.Id) then
        Exit(False);
      SubjectName := Tree.Expression.TokenValue(Tree[SubjectIndex]^.Ref);
      if SubjectName <> Name then
        Exit(False);

      if HasFocusMarker and
         ((Tree[PatternIndex]^.Data and TK_DOT) = TK_DOT) and
         (FocusHead = EOT) then
      begin
        FocusHead := SubjectIndex;
        FocusTail := Tree[SubjectIndex]^.RHS;
      end;
      Exit(True);
    end;

    Slot := FindString(Symbols, Name);
    if Slot < 0 then
      Exit(False);

    IsAny := (Tree[PatternIndex]^.Data and TK_ALLCAPS) = TK_ALLCAPS;
    if (not IsAny) and (not IsIdentifierNode(Tree[SubjectIndex]^.Id)) then
      Exit(False);

    if Assigned(MatcherContext) and IsVariableNode(Tree[SubjectIndex]^.Id) then
    begin
      SubjectName := Tree.Expression.TokenValue(Tree[SubjectIndex]^.Ref);
      if MatcherContext.IsNonBindable(SubjectName) then
        Exit(False);
    end;

    if not VariablePatternOperatorMatches(Tree, PatternIndex, SubjectIndex) then
      Exit(False);

    if Bindings.NodeRefs[Slot] = EOT then
      Bindings.NodeRefs[Slot] := SubjectIndex
    else if not NodeEquivalentForBinding(Tree, Bindings.NodeRefs[Slot], SubjectIndex, False) then
      Exit(False);

    if HasFocusMarker and
       ((Tree[PatternIndex]^.Data and TK_DOT) = TK_DOT) and
       (FocusHead = EOT) then
    begin
      FocusHead := SubjectIndex;
      FocusTail := Tree[SubjectIndex]^.RHS;
    end;

    Exit(True);
  end;

  SubjectIndex := ResolveSubjectVariableNode(Tree, SubjectIndex);
  if SubjectIndex = EOT then
    Exit(False);

  if IsMatchAnyNode(Tree[PatternIndex]^.Id) then
    Exit(True);

  if Tree[PatternIndex]^.Id = MID_OBJ_RANGE then
  begin
    if not MatchRangePredicate(Tree, PatternIndex, SubjectIndex) then
      Exit(False);

    if HasFocusMarker and
       ((Tree[PatternIndex]^.Data and TK_DOT) = TK_DOT) and
       (FocusHead = EOT) then
    begin
      FocusHead := SubjectIndex;
      FocusTail := Tree[SubjectIndex]^.RHS;
    end;
    Exit(True);
  end;

  if Tree[PatternIndex]^.Id <> Tree[SubjectIndex]^.Id then
  begin
    if IsTransparentEvalPatternWrapper(Tree, PatternIndex) or
       IsTransparentFixedExprPatternWrapper(Tree, PatternIndex) then
      Exit(
        MatchPatternNode(
          Tree,
          Tree[PatternIndex]^.LHS,
          SubjectIndex,
          Symbols,
          Bindings,
          HasFocusMarker,
          FocusHead,
          FocusTail
        )
      );
    Exit(False);
  end;

  if not OperatorsMatchForPattern(Tree, PatternIndex, SubjectIndex) then
    Exit(False);
  if (Tree[PatternIndex]^.Data and TK_SELECTOR_MASK) <>
     (Tree[SubjectIndex]^.Data and TK_SELECTOR_MASK) then
    Exit(False);

  if Tree[PatternIndex]^.Id = MID_OBJ_VARIABLE_SUBTREE then
  begin
    if (Tree[PatternIndex]^.Ref = EOT) xor (Tree[SubjectIndex]^.Ref = EOT) then
      Exit(False);
    if (Tree[PatternIndex]^.Ref <> EOT) and (Tree[SubjectIndex]^.Ref <> EOT) then
    begin
      Name := Tree.Expression.TokenValue(Tree[PatternIndex]^.Ref);
      SubjectName := Tree.Expression.TokenValue(Tree[SubjectIndex]^.Ref);
      if (Name <> '') and (Name[1] <> '"') then
      begin
        if Assigned(MatcherContext) and MatcherContext.IsKeyword(Name) then
        begin
          if Name <> SubjectName then
            Exit(False);
        end
        else
        begin
          if Assigned(MatcherContext) and MatcherContext.IsNonBindable(SubjectName) then
            Exit(False);

          Slot := FindString(Symbols, Name);
          if Slot < 0 then
            Exit(False);

          if Bindings.NodeRefs[Slot] = EOT then
            Bindings.NodeRefs[Slot] := CreateDetachedVariableSymbolNode(Tree, Tree[SubjectIndex]^.Ref)
          else
          begin
            BoundNode := Bindings.NodeRefs[Slot];
            if (BoundNode = EOT) or (Tree[BoundNode]^.Ref = EOT) then
              Exit(False);
            if Tree.Expression.TokenValue(Tree[BoundNode]^.Ref) <> SubjectName then
              Exit(False);
          end;
        end;
      end
      else if Name <> SubjectName then
        Exit(False);
    end;
  end
  else if IsIdentifierNode(Tree[PatternIndex]^.Id) and
     (Tree[PatternIndex]^.Ref <> EOT) and (Tree[SubjectIndex]^.Ref <> EOT) then
    if Tree.Expression.TokenValue(Tree[PatternIndex]^.Ref) <>
       Tree.Expression.TokenValue(Tree[SubjectIndex]^.Ref) then
      Exit(False);

  if HasFocusMarker and
     ((Tree[PatternIndex]^.Data and TK_DOT) = TK_DOT) and
     (FocusHead = EOT) then
  begin
    FocusHead := SubjectIndex;
    FocusTail := Tree[SubjectIndex]^.RHS;
  end;

  Result := MatchPatternSequence(
    Tree,
    Tree[PatternIndex]^.LHS,
    Tree[SubjectIndex]^.LHS,
    Symbols,
    Bindings,
    HasFocusMarker,
    FocusHead,
    FocusTail
  );
end;

function MatchPatternSequenceEx(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer;
  const Symbols: TArrayOfString;
  var Bindings: TMatchBindings;
  HasFocusMarker: Boolean;
  var FocusHead: Integer;
  var FocusTail: Integer;
  AllowSubjectTail: Boolean;
  out RemainingSubjectTail: Integer;
  out MatchedSubjectHead: Integer
): Boolean;
var
  PNode, SNode: Integer;
  NextPatternNode: Integer;
  Name: ansistring;
  Slot: Integer;
  PatternNodes: TArrayOfInteger;
  SubjectNodes: TArrayOfInteger;
  PatternPos: Integer;
  SubjectPos: Integer;
  CandidatePos: Integer;

  function FindNextPatternMatch(StartSubjectPos: Integer; NextNode: Integer;
    PreferLongest: Boolean;
    out MatchPos: Integer): Boolean;
  var
    K: Integer;
    CandidateBindings: TMatchBindings;
    CandidateFocusHead: Integer;
    CandidateFocusTail: Integer;
  begin
    Result := False;
    MatchPos := -1;
    if PreferLongest then
    begin
      for K := High(SubjectNodes) downto StartSubjectPos do
      begin
        CandidateBindings := Bindings.Clone;
        CandidateFocusHead := FocusHead;
        CandidateFocusTail := FocusTail;
        if MatchPatternNode(
             Tree,
             NextNode,
             SubjectNodes[K],
             Symbols,
             CandidateBindings,
             HasFocusMarker,
             CandidateFocusHead,
             CandidateFocusTail
           ) then
        begin
          Bindings := CandidateBindings;
          FocusHead := CandidateFocusHead;
          FocusTail := CandidateFocusTail;
          MatchPos := K;
          Exit(True);
        end;
      end;
      Exit(False);
    end;

    for K := StartSubjectPos to High(SubjectNodes) do
    begin
      CandidateBindings := Bindings.Clone;
      CandidateFocusHead := FocusHead;
      CandidateFocusTail := FocusTail;
      if MatchPatternNode(
           Tree,
           NextNode,
           SubjectNodes[K],
           Symbols,
           CandidateBindings,
           HasFocusMarker,
           CandidateFocusHead,
           CandidateFocusTail
         ) then
      begin
        Bindings := CandidateBindings;
        FocusHead := CandidateFocusHead;
        FocusTail := CandidateFocusTail;
        MatchPos := K;
        Exit(True);
      end;
    end;
  end;

  function TryMatchWildcardRemainderWithBacktracking(
    WildcardNode: Integer;
    StartSubjectPos: Integer;
    NextNode: Integer;
    PreferLongest: Boolean;
    out MatchPos: Integer
  ): Boolean;
  var
    K: Integer;
    CandidateBindings: TMatchBindings;
    CandidateFocusHead: Integer;
    CandidateFocusTail: Integer;
    CandidateRemainingTail: Integer;
    CandidateMatchedHead: Integer;
  begin
    Result := False;
    MatchPos := -1;
    if PreferLongest then
    begin
      for K := High(SubjectNodes) downto StartSubjectPos do
      begin
        CandidateBindings := Bindings.Clone;
        CandidateFocusHead := FocusHead;
        CandidateFocusTail := FocusTail;
        CandidateRemainingTail := EOT;
        CandidateMatchedHead := EOT;

        if MatchPatternSequenceEx(
             Tree,
             NextNode,
             SubjectNodes[K],
             Symbols,
             CandidateBindings,
             HasFocusMarker,
             CandidateFocusHead,
             CandidateFocusTail,
             AllowSubjectTail,
             CandidateRemainingTail,
             CandidateMatchedHead
           ) then
        begin
          if HasFocusMarker and
             ((Tree[WildcardNode]^.Data and TK_DOT) = TK_DOT) and
             (CandidateFocusHead = EOT) then
          begin
            if StartSubjectPos < Length(SubjectNodes) then
              CandidateFocusHead := SubjectNodes[StartSubjectPos]
            else
              CandidateFocusHead := EOT;
            if K < Length(SubjectNodes) then
              CandidateFocusTail := SubjectNodes[K]
            else
              CandidateFocusTail := EOT;
          end;

          Bindings := CandidateBindings;
          FocusHead := CandidateFocusHead;
          FocusTail := CandidateFocusTail;
          RemainingSubjectTail := CandidateRemainingTail;
          if MatchedSubjectHead = EOT then
          begin
            if StartSubjectPos < Length(SubjectNodes) then
              MatchedSubjectHead := SubjectNodes[StartSubjectPos]
            else
              MatchedSubjectHead := CandidateMatchedHead;
          end;
          MatchPos := K;
          Exit(True);
        end;
      end;
      Exit(False);
    end;

    for K := StartSubjectPos to High(SubjectNodes) do
    begin
      CandidateBindings := Bindings.Clone;
      CandidateFocusHead := FocusHead;
      CandidateFocusTail := FocusTail;
      CandidateRemainingTail := EOT;
      CandidateMatchedHead := EOT;

      if MatchPatternSequenceEx(
           Tree,
           NextNode,
           SubjectNodes[K],
           Symbols,
           CandidateBindings,
           HasFocusMarker,
           CandidateFocusHead,
           CandidateFocusTail,
           AllowSubjectTail,
           CandidateRemainingTail,
           CandidateMatchedHead
         ) then
      begin
        if HasFocusMarker and
           ((Tree[WildcardNode]^.Data and TK_DOT) = TK_DOT) and
           (CandidateFocusHead = EOT) then
        begin
          if StartSubjectPos < Length(SubjectNodes) then
            CandidateFocusHead := SubjectNodes[StartSubjectPos]
          else
            CandidateFocusHead := EOT;
          if K < Length(SubjectNodes) then
            CandidateFocusTail := SubjectNodes[K]
          else
            CandidateFocusTail := EOT;
        end;

        Bindings := CandidateBindings;
        FocusHead := CandidateFocusHead;
        FocusTail := CandidateFocusTail;
        RemainingSubjectTail := CandidateRemainingTail;
        if MatchedSubjectHead = EOT then
        begin
          if StartSubjectPos < Length(SubjectNodes) then
            MatchedSubjectHead := SubjectNodes[StartSubjectPos]
          else
            MatchedSubjectHead := CandidateMatchedHead;
        end;
        MatchPos := K;
        Exit(True);
      end;
    end;
  end;

  function IsLongWildcardNode(NodeIndex: Integer): Boolean;
  begin
    if (NodeIndex = EOT) or (Tree[NodeIndex]^.Ref = EOT) then
      Exit(False);
    Result := (Tree[NodeIndex]^.RefData and TK_SPECIAL_MASK) = TK_MATCH_ANY_LONG;
  end;

  procedure BindTailBoundaryForPrevVariable(BoundaryNode: Integer);
  var
    PrevPatternNode: Integer;
  begin
    if PatternPos <= 0 then
      Exit;
    PrevPatternNode := PatternNodes[PatternPos - 1];
    if (PrevPatternNode = EOT) or (not IsVariableNode(Tree[PrevPatternNode]^.Id)) then
      Exit;

    Name := Tree.Expression.TokenValue(Tree[PrevPatternNode]^.Ref);
    if Assigned(MatcherContext) and MatcherContext.IsKeyword(Name) then
      Exit;

    Slot := FindString(Symbols, Name);
    if Slot >= 0 then
      Bindings.TailRefs[Slot] := BoundaryNode;
  end;
begin
  RemainingSubjectTail := EOT;
  MatchedSubjectHead := EOT;
  PatternNodes := nil;
  SubjectNodes := nil;
  CollectSequenceNodes(Tree, PatternIndex, PatternNodes);
  CollectSequenceNodes(Tree, SubjectIndex, SubjectNodes);
  PatternPos := 0;
  SubjectPos := 0;

  while PatternPos < Length(PatternNodes) do
  begin
    PNode := PatternNodes[PatternPos];
    if SubjectPos < Length(SubjectNodes) then
      SNode := SubjectNodes[SubjectPos]
    else
      SNode := EOT;
    if PatternPos < High(PatternNodes) then
      NextPatternNode := PatternNodes[PatternPos + 1]
    else
      NextPatternNode := EOT;

    if (PNode <> EOT) and IsMatchAnyNode(Tree[PNode]^.Id) then
    begin
      if (PatternPos = 0) and (NextPatternNode <> EOT) then
      begin
        if Length(SubjectNodes) < (Length(PatternNodes) - 1) then
          Exit(False);

        if HasFocusMarker and
           ((Tree[PNode]^.Data and TK_DOT) = TK_DOT) and
           (FocusHead = EOT) then
        begin
          if Length(SubjectNodes) > 0 then
            FocusHead := SubjectNodes[0]
          else
            FocusHead := EOT;
          if Length(SubjectNodes) > (Length(PatternNodes) - 1) then
            FocusTail := SubjectNodes[Length(SubjectNodes) - (Length(PatternNodes) - 1)]
          else
            FocusTail := EOT;
        end;

        SubjectPos := Length(SubjectNodes) - (Length(PatternNodes) - 1);
        Inc(PatternPos);
        Continue;
      end;

      if NextPatternNode = EOT then
      begin
        if MatchedSubjectHead = EOT then
          MatchedSubjectHead := SNode;
        if HasFocusMarker and
           ((Tree[PNode]^.Data and TK_DOT) = TK_DOT) and
           (FocusHead = EOT) then
        begin
          FocusHead := SNode;
          FocusTail := EOT;
        end;
        BindTailBoundaryForPrevVariable(EOT);
        RemainingSubjectTail := EOT;
        Exit(True);
      end;

      if MatcherBacktrackingEnabled then
      begin
        if TryMatchWildcardRemainderWithBacktracking(
             PNode, SubjectPos, NextPatternNode, IsLongWildcardNode(PNode), CandidatePos
           ) then
        begin
          if CandidatePos < Length(SubjectNodes) then
            BindTailBoundaryForPrevVariable(SubjectNodes[CandidatePos])
          else
            BindTailBoundaryForPrevVariable(EOT);
          Exit(True);
        end
        else
          Exit(False);
      end;

      if not FindNextPatternMatch(
               SubjectPos, NextPatternNode, IsLongWildcardNode(PNode), CandidatePos
             ) then
        Exit(False);

      if HasFocusMarker and
         ((Tree[PNode]^.Data and TK_DOT) = TK_DOT) and
         (FocusHead = EOT) then
      begin
        if SubjectPos < Length(SubjectNodes) then
          FocusHead := SubjectNodes[SubjectPos]
        else
          FocusHead := EOT;
        if CandidatePos < Length(SubjectNodes) then
          FocusTail := SubjectNodes[CandidatePos]
        else
          FocusTail := EOT;
      end;

      if CandidatePos < Length(SubjectNodes) then
        BindTailBoundaryForPrevVariable(SubjectNodes[CandidatePos])
      else
        BindTailBoundaryForPrevVariable(EOT);
      SubjectPos := CandidatePos;
      Inc(PatternPos);
      Continue;
    end;

    if (PNode = EOT) or (SNode = EOT) then
      Exit(False);

    if MatchedSubjectHead = EOT then
      MatchedSubjectHead := SNode;

    if not MatchPatternNode(
             Tree, PNode, SNode, Symbols, Bindings, HasFocusMarker, FocusHead, FocusTail
           ) then
      Exit(False);

    Inc(PatternPos);
    Inc(SubjectPos);
  end;

  if MatchedSubjectHead = EOT then
  begin
    if Length(SubjectNodes) > 0 then
      MatchedSubjectHead := SubjectNodes[0]
    else
      MatchedSubjectHead := EOT;
  end;

  if SubjectPos < Length(SubjectNodes) then
    RemainingSubjectTail := SubjectNodes[SubjectPos]
  else
    RemainingSubjectTail := EOT;
  if AllowSubjectTail then
    Result := True
  else
    Result := RemainingSubjectTail = EOT;
end;

function MatchPatternSequence(
  Tree: TCustomTree;
  PatternIndex: Integer;
  SubjectIndex: Integer;
  const Symbols: TArrayOfString;
  var Bindings: TMatchBindings;
  HasFocusMarker: Boolean;
  var FocusHead: Integer;
  var FocusTail: Integer
): Boolean;
var
  RemainingTail: Integer;
  MatchedHead: Integer;
begin
  Result := MatchPatternSequenceEx(
    Tree, PatternIndex, SubjectIndex, Symbols, Bindings,
    HasFocusMarker, FocusHead, FocusTail,
    False, RemainingTail, MatchedHead
  );
end;

function CloneTemplateSequenceWithBindings(
  Tree: TCustomTree;
  TemplateIndex: Integer;
  Context: TContext;
  const Symbols: TArrayOfString;
  const Bindings: TMatchBindings;
  MatchHead: Integer;
  MatchTail: Integer;
  FocusHead: Integer;
  FocusTail: Integer;
  StopBefore: Integer = EOT;
  AllowContextVariableSubstitution: Boolean = True
): Integer; forward;

type
  TDollarCaptureKind = (
    dckNone,
    dckMatch,
    dckFocus
  );

function GetDollarCaptureKind(Tree: TCustomTree; TemplateIndex: Integer): TDollarCaptureKind;
var
  Name: ansistring;
begin
  Result := dckNone;
  if (TemplateIndex = EOT) or
     (not IsVariableNode(Tree[TemplateIndex]^.Id)) or
     ((Tree[TemplateIndex]^.Data and TK_DOLLAR) <> TK_DOLLAR) then
    Exit;

  Name := Tree.Expression.TokenValue(Tree[TemplateIndex]^.Ref);
  if Name = 'match' then
    Exit(dckMatch);
  if Name = 'focus' then
    Exit(dckFocus);
end;

function FindLastBeforeTail(Tree: TCustomTree; StartNode, TailNode: Integer): Integer;
begin
  if StartNode = EOT then
    Exit(EOT);

  if TailNode = EOT then
    Exit(Tree.LastSibling[StartNode]);

  Result := StartNode;
  while Result <> EOT do
  begin
    if Tree[Result]^.RHS = TailNode then
      Exit(Result);
    Result := Tree[Result]^.RHS;
  end;
end;

function CloneSpan(Tree: TCustomTree; StartNode, TailBoundary: Integer): Integer;
var
  LastNode: Integer;
begin
  if StartNode = EOT then
    Exit(EOT);

  if TailBoundary = EOT then
    Exit(Tree.CloneSubtree(StartNode));

  LastNode := FindLastBeforeTail(Tree, StartNode, TailBoundary);
  if LastNode = EOT then
    Exit(Tree.CloneSubtree(StartNode));

  Result := Tree.Copy(StartNode, LastNode);
end;

function CloneMatchVariableWithSelector(
  Tree: TCustomTree;
  MatchHead, MatchTail, SelectorBits: Integer
): Integer;
var
  MatchRHS: Integer;
begin
  case SelectorBits of
    TK_SELECTOR_LHS:
      begin
        if (MatchHead <> EOT) and (Tree[MatchHead]^.LHS <> EOT) then
          Exit(Tree.CloneSubtree(Tree[MatchHead]^.LHS))
        else
          Exit(EOT);
      end;
    TK_SELECTOR_RHS:
      begin
        if MatchHead = EOT then
          Exit(EOT);
        MatchRHS := Tree[MatchHead]^.RHS;
        Exit(CloneSpan(Tree, MatchRHS, MatchTail));
      end;
    TK_SELECTOR_ALL, 0:
      Exit(CloneSpan(Tree, MatchHead, MatchTail));
  else
    begin
      Result := CloneSpan(Tree, MatchHead, MatchTail);
      if (Result <> EOT) and (SelectorBits <> 0) then
        Tree[Result]^.Data := Tree[Result]^.Data or SelectorBits;
    end;
  end;
end;

function IsSelectorBits(SelectorBits: Integer): Boolean;
begin
  case SelectorBits and TK_SELECTOR_MASK of
    TK_SELECTOR_LHS, TK_SELECTOR_RHS, TK_SELECTOR_ALL:
      Result := True;
  else
    Result := False;
  end;
end;

function RemoveSelectorOperatorBits(Data: Integer): Integer;
var
  SelectorBits: Integer;
begin
  SelectorBits := Data and TK_SELECTOR_MASK;
  if IsSelectorBits(SelectorBits) then
    Result := Data and (not TK_SELECTOR_MASK)
  else
    Result := Data;
  Result := Result and (not TK_SELECTOR_OP);
end;

function IsTemplateOperatorCarrierNode(Tree: TCustomTree; TemplateIndex: Integer): Boolean;
begin
  Result := (TemplateIndex <> EOT) and
            IsVariableNode(Tree[TemplateIndex]^.Id) and
            ((Tree[TemplateIndex]^.Data and TK_SELECTOR_OP) = TK_SELECTOR_OP);
end;

function CloneTemplateNodeWithBindings(
  Tree: TCustomTree;
  TemplateIndex: Integer;
  Context: TContext;
  const Symbols: TArrayOfString;
  const Bindings: TMatchBindings;
  MatchHead: Integer;
  MatchTail: Integer;
  FocusHead: Integer;
  FocusTail: Integer;
  AllowContextVariableSubstitution: Boolean = True;
  ForceAllSelector: Boolean = False
): Integer;
var
  Slot: Integer;
  Name: ansistring;
  SelectorBits: Integer;
  ArithmeticOp: Integer;
  Bound, Tail, Replaced, SourceRef: Integer;
  DollarCaptureKind: TDollarCaptureKind;
  ResolvedVariableSubtreeRef: Integer;
begin
  Result := EOT;
  if TemplateIndex = EOT then
    Exit;

  DollarCaptureKind := GetDollarCaptureKind(Tree, TemplateIndex);
  if DollarCaptureKind <> dckNone then
  begin
    SelectorBits := Tree[TemplateIndex]^.Data and TK_SELECTOR_MASK;
    case DollarCaptureKind of
      dckMatch:
        Exit(CloneMatchVariableWithSelector(Tree, MatchHead, MatchTail, SelectorBits));
      dckFocus:
        begin
          if FocusHead = EOT then
            Exit(EOT);
          Exit(CloneMatchVariableWithSelector(Tree, FocusHead, FocusTail, SelectorBits));
        end;
    end;
  end;

  if (Tree[TemplateIndex]^.Id = MID_OBJ_VARIABLE_SUBTREE) and
     (Tree[TemplateIndex]^.Ref <> EOT) then
  begin
    Name := Tree.Expression.TokenValue(Tree[TemplateIndex]^.Ref);
    ResolvedVariableSubtreeRef := EOT;
    if (Name <> '') and (Name[1] <> '"') then
    begin
      Slot := FindString(Symbols, Name);
      if Slot >= 0 then
      begin
        Bound := Bindings.NodeRefs[Slot];
        if (Bound <> EOT) and (Tree[Bound]^.Ref <> EOT) then
          ResolvedVariableSubtreeRef := Tree[Bound]^.Ref;
      end;
    end;

    if ResolvedVariableSubtreeRef <> EOT then
    begin
      Result := Tree.AllocateNode;
      Tree[Result]^ := Tree[TemplateIndex]^;
      Tree[Result]^.Data := RemoveSelectorOperatorBits(Tree[Result]^.Data);
      Tree[Result]^.Ref := ResolvedVariableSubtreeRef;
      Tree[Result]^.LHS := EOT;
      Tree[Result]^.RHS := EOT;
      if Tree[TemplateIndex]^.LHS <> EOT then
        Tree[Result]^.LHS := CloneTemplateSequenceWithBindings(
          Tree,
          Tree[TemplateIndex]^.LHS,
          Context,
          Symbols,
          Bindings,
          MatchHead,
          MatchTail,
          FocusHead,
          FocusTail,
          EOT,
          AllowContextVariableSubstitution
        );
      Exit(Result);
    end;
  end;

  if IsVariableNode(Tree[TemplateIndex]^.Id) then
  begin
    Name := Tree.Expression.TokenValue(Tree[TemplateIndex]^.Ref);
    Slot := FindString(Symbols, Name);
    if Slot >= 0 then
    begin
      Bound := Bindings.NodeRefs[Slot];
      if Bound <> EOT then
      begin
        SelectorBits := Tree[TemplateIndex]^.Data and TK_SELECTOR_MASK;
        if ForceAllSelector then
          SelectorBits := TK_SELECTOR_ALL;
        ArithmeticOp := Tree[TemplateIndex]^.Data and TK_OPERATOR_MASK;
        case SelectorBits of
          TK_SELECTOR_LHS:
            begin
              if Tree[Bound]^.LHS <> EOT then
                Replaced := Tree.CloneSubtree(Tree[Bound]^.LHS)
              else
                Replaced := EOT;

              if (Replaced = EOT) and Assigned(Context) and IsVariableNode(Tree[Bound]^.Id) then
              begin
                Name := Tree.Expression.TokenValue(Tree[Bound]^.Ref);
                if (Name <> '') and Context.TryFindVariable(Name, SourceRef) then
                begin
                  if Tree[SourceRef]^.LHS <> EOT then
                    Replaced := Tree.CloneSubtree(Tree[SourceRef]^.LHS)
                  else
                    Replaced := EOT;
                end;
              end;
            end;
          TK_SELECTOR_RHS:
            begin
              Tail := Bindings.TailRefs[Slot];
              if Tail = EOT then
                Tail := Tree[Bound]^.RHS;
              if Tail <> EOT then
                Replaced := Tree.CloneSubtree(Tail)
              else
                Replaced := EOT;
            end;
          TK_SELECTOR_ALL:
            begin
              Tail := Bindings.TailRefs[Slot];
              if Tail <> EOT then
                Replaced := CloneSpan(Tree, Bound, Tail)
              else
                Replaced := Tree.CloneSubtree(Bound);
              if Replaced = EOT then
                Exit(EOT);
            end;
        else
          Replaced := Tree.CloneLHS(Bound);
        end;

        if (Replaced <> EOT) and (ArithmeticOp <> 0) then
        begin
          if (SelectorBits = TK_SELECTOR_LHS) or
             (SelectorBits = TK_SELECTOR_RHS) or
             (SelectorBits = TK_SELECTOR_ALL) then
            nodes.GetNode(Replaced).AppendOperator(ArithmeticOp, True)
          else
            nodes.GetNode(Replaced).AppendOperator(ArithmeticOp);
        end;
        Exit(Replaced);
      end;
    end;

    if Assigned(Context) and Context.IsKeyword(Name) then
    begin
      // Keep keyword identifiers as literal symbols in RHS templates.
      // This allows recursive rule heads (e.g. `cat ... => cat ...`) to
      // remain invocations instead of being substituted with the rule value.
    end
    else if AllowContextVariableSubstitution and
            Assigned(Context) and Context.TryFindVariable(Name, SourceRef) then
    begin
      SelectorBits := Tree[TemplateIndex]^.Data and TK_SELECTOR_MASK;
      if ForceAllSelector then
        SelectorBits := TK_SELECTOR_ALL;
      ArithmeticOp := Tree[TemplateIndex]^.Data and TK_OPERATOR_MASK;
      case SelectorBits of
        TK_SELECTOR_LHS:
          begin
            if Tree[SourceRef]^.LHS <> EOT then
              Replaced := Tree.CloneSubtree(Tree[SourceRef]^.LHS)
            else
              Replaced := EOT;
          end;
        TK_SELECTOR_RHS:
          begin
            Tail := Tree[SourceRef]^.RHS;
            if Tail <> EOT then
              Replaced := Tree.CloneSubtree(Tail)
            else
              Replaced := EOT;
          end;
        TK_SELECTOR_ALL, 0:
          Replaced := Tree.CloneSubtree(SourceRef);
      else
        Replaced := Tree.CloneSubtree(SourceRef);
      end;
      if (Replaced <> EOT) and (ArithmeticOp <> 0) then
      begin
        if (SelectorBits = TK_SELECTOR_LHS) or
           (SelectorBits = TK_SELECTOR_RHS) or
           (SelectorBits = TK_SELECTOR_ALL) then
          nodes.GetNode(Replaced).AppendOperator(ArithmeticOp, True)
        else
          nodes.GetNode(Replaced).AppendOperator(ArithmeticOp);
      end;
      Exit(Replaced);
    end;
  end;

  Result := Tree.AllocateNode;
  Tree[Result]^ := Tree[TemplateIndex]^;
  if IsVariableNode(Tree[TemplateIndex]^.Id) then
    Tree[Result]^.Data := Tree[TemplateIndex]^.Data
  else
    Tree[Result]^.Data := RemoveSelectorOperatorBits(Tree[Result]^.Data);
  Tree[Result]^.LHS := EOT;
  Tree[Result]^.RHS := EOT;
  if Tree[TemplateIndex]^.LHS <> EOT then
    Tree[Result]^.LHS := CloneTemplateSequenceWithBindings(
      Tree,
      Tree[TemplateIndex]^.LHS,
      Context,
      Symbols,
      Bindings,
      MatchHead,
      MatchTail,
      FocusHead,
      FocusTail,
      EOT,
      (Tree[TemplateIndex]^.Id <> nodes.OBJ_ASSIGNMENT) and
      AllowContextVariableSubstitution
    );
end;

function CloneTemplateSequenceWithBindings(
  Tree: TCustomTree;
  TemplateIndex: Integer;
  Context: TContext;
  const Symbols: TArrayOfString;
  const Bindings: TMatchBindings;
  MatchHead: Integer;
  MatchTail: Integer;
  FocusHead: Integer;
  FocusTail: Integer;
  StopBefore: Integer = EOT;
  AllowContextVariableSubstitution: Boolean = True
): Integer;
var
  Cur, Piece, Head, Tail, Last: Integer;
  Slot: Integer;
  Name: ansistring;
  IsTailSplice: Boolean;
  PendingOperatorBits: Integer;
begin
  Head := EOT;
  Tail := EOT;
  Cur := TemplateIndex;
  PendingOperatorBits := 0;

  while (Cur <> EOT) and (Cur <> StopBefore) do
  begin
    IsTailSplice := False;
    if IsVariableNode(Tree[Cur]^.Id) and
       (Tree[Cur]^.RHS <> EOT) and
       IsMatchAnyNode(Tree[Tree[Cur]^.RHS]^.Id) and
       ((Tree[Cur]^.Data and TK_SELECTOR_MASK) = 0) then
    begin
      Name := Tree.Expression.TokenValue(Tree[Cur]^.Ref);
      Slot := FindString(Symbols, Name);
      IsTailSplice := (Slot >= 0) and (Bindings.NodeRefs[Slot] <> EOT);
    end;

    if IsTemplateOperatorCarrierNode(Tree, Cur) then
    begin
      Piece := CloneTemplateNodeWithBindings(
        Tree, Cur, Context, Symbols, Bindings,
        MatchHead, MatchTail, FocusHead, FocusTail,
        AllowContextVariableSubstitution
      );
      if Piece <> EOT then
      begin
        PendingOperatorBits := PendingOperatorBits or
                               (Tree[Piece]^.Data and TK_OPERATOR_MASK);
        Tree.DeleteSubtree(EOT, Piece);
      end;
      Cur := Tree[Cur]^.RHS;
      Continue;
    end;

    Piece := CloneTemplateNodeWithBindings(
      Tree, Cur, Context, Symbols, Bindings,
      MatchHead, MatchTail, FocusHead, FocusTail,
      AllowContextVariableSubstitution,
      IsTailSplice
    );
    if Piece <> EOT then
    begin
      if PendingOperatorBits <> 0 then
      begin
        nodes.GetNode(Piece).AppendOperator(PendingOperatorBits);
        PendingOperatorBits := 0;
      end;
      if Head = EOT then
        Head := Piece
      else
        Tree[Tail]^.RHS := Piece;
      Last := Tree.LastSibling[Piece];
      Tail := Last;
    end;
    if IsTailSplice then
      Cur := Tree[Tree[Cur]^.RHS]^.RHS
    else
      Cur := Tree[Cur]^.RHS;
  end;

  Result := Head;
end;

function FindSubstitutionEntry(
  const Entries: TArrayOfSubstitutionEntry;
  const SymbolName: ansistring
): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Entries) do
    if Entries[I].Symbol = SymbolName then
      Exit(I);
  Result := -1;
end;

procedure CleanupSubstitutionEntries(
  Tree: TCustomTree;
  var Entries: TArrayOfSubstitutionEntry
);
var
  I: Integer;
begin
  for I := 0 to High(Entries) do
    if Entries[I].Replacement <> EOT then
      Tree.DeleteSubtree(EOT, Entries[I].Replacement);
  Entries := nil;
end;

function BuildSubstitutionEntries(
  Tree: TCustomTree;
  PatternIndex: Integer;
  ReplaceIndex: Integer;
  GuardIndex: Integer;
  ResolveWithBindings: Boolean;
  Context: TContext;
  const Symbols: TArrayOfString;
  const Bindings: TMatchBindings;
  MatchHead: Integer;
  MatchTail: Integer;
  FocusHead: Integer;
  FocusTail: Integer;
  out Entries: TArrayOfSubstitutionEntry;
  out FailureReason: ansistring
): Boolean;
var
  LCur: Integer;
  RCur: Integer;
  NextR: Integer;
  SingleVariableLHS: Boolean;
  SymbolName: ansistring;
  Replacement: Integer;
  EntryIndex: Integer;
begin
  Result := False;
  FailureReason := '';
  Entries := nil;
  LCur := PatternIndex;
  RCur := ReplaceIndex;
  SingleVariableLHS := (LCur <> EOT) and (Tree[LCur]^.RHS = EOT);

  while (LCur <> EOT) and (RCur <> EOT) and (RCur <> GuardIndex) do
  begin
    if not IsVariableNode(Tree[LCur]^.Id) then
    begin
      FailureReason := 'substitution LHS must be a top-level variable sequence';
      Exit(False);
    end;
    if Tree[LCur]^.Ref = EOT then
    begin
      FailureReason := 'substitution LHS variable has no symbol reference';
      Exit(False);
    end;

    SymbolName := Tree.Expression.TokenValue(Tree[LCur]^.Ref);
    if SymbolName = '' then
    begin
      FailureReason := 'substitution LHS variable symbol is empty';
      Exit(False);
    end;
    if FindSubstitutionEntry(Entries, SymbolName) <> -1 then
    begin
      FailureReason := 'substitution LHS contains duplicate symbols';
      Exit(False);
    end;

    if SingleVariableLHS then
      NextR := GuardIndex
    else
      NextR := Tree[RCur]^.RHS;
    if ResolveWithBindings then
      Replacement := CloneTemplateSequenceWithBindings(
        Tree, RCur, Context, Symbols, Bindings,
        MatchHead, MatchTail, FocusHead, FocusTail, NextR
      )
    else
      Replacement := CloneSpan(Tree, RCur, NextR);

    EntryIndex := Length(Entries);
    SetLength(Entries, EntryIndex + 1);
    Entries[EntryIndex].Symbol := SymbolName;
    Entries[EntryIndex].Replacement := Replacement;

    LCur := Tree[LCur]^.RHS;
    RCur := NextR;
  end;

  if (LCur <> EOT) or ((RCur <> EOT) and (RCur <> GuardIndex)) then
  begin
    FailureReason := 'substitution LHS/RHS mapping arity mismatch';
    Exit(False);
  end;
  if Length(Entries) = 0 then
  begin
    FailureReason := 'substitution mapping is empty';
    Exit(False);
  end;

  Result := True;
end;

function CloneSequenceWithSubstitution(
  Tree: TCustomTree;
  SourceIndex: Integer;
  StopBefore: Integer;
  const Entries: TArrayOfSubstitutionEntry;
  out SubstitutionCount: Integer
): Integer; forward;

function CloneNodeWithSubstitution(
  Tree: TCustomTree;
  SourceNode: Integer;
  const Entries: TArrayOfSubstitutionEntry;
  out SubstitutionCount: Integer
): Integer;
var
  SourceSymbol: ansistring;
  SourceOp: Integer;
  ReplacedNode: Integer;
  ChildCount: Integer;
  EntryIndex: Integer;
begin
  Result := EOT;
  SubstitutionCount := 0;
  if SourceNode = EOT then
    Exit(EOT);

  if IsVariableNode(Tree[SourceNode]^.Id) and (Tree[SourceNode]^.Ref <> EOT) then
  begin
    SourceSymbol := Tree.Expression.TokenValue(Tree[SourceNode]^.Ref);
    EntryIndex := FindSubstitutionEntry(Entries, SourceSymbol);
    if EntryIndex <> -1 then
    begin
      ReplacedNode := Tree.CloneSubtree(Entries[EntryIndex].Replacement);
      SourceOp := Tree[SourceNode]^.Data and TK_OPERATOR_MASK;
      if (ReplacedNode <> EOT) and (SourceOp <> 0) then
        nodes.GetNode(ReplacedNode).AppendOperator(SourceOp);
      SubstitutionCount := 1;
      Exit(ReplacedNode);
    end;
  end;

  Result := Tree.AllocateNode;
  Tree[Result]^ := Tree[SourceNode]^;
  Tree[Result]^.LHS := EOT;
  Tree[Result]^.RHS := EOT;

  if Tree[SourceNode]^.LHS <> EOT then
  begin
    Tree[Result]^.LHS := CloneSequenceWithSubstitution(
      Tree,
      Tree[SourceNode]^.LHS,
      EOT,
      Entries,
      ChildCount
    );
    Inc(SubstitutionCount, ChildCount);
  end;
end;

function CloneSequenceWithSubstitution(
  Tree: TCustomTree;
  SourceIndex: Integer;
  StopBefore: Integer;
  const Entries: TArrayOfSubstitutionEntry;
  out SubstitutionCount: Integer
): Integer;
var
  Cur: Integer;
  Piece: Integer;
  PieceCount: Integer;
  Head: Integer;
  Tail: Integer;
  Last: Integer;
begin
  Head := EOT;
  Tail := EOT;
  Cur := SourceIndex;
  SubstitutionCount := 0;

  while (Cur <> EOT) and (Cur <> StopBefore) do
  begin
    Piece := CloneNodeWithSubstitution(
      Tree, Cur, Entries, PieceCount
    );
    Inc(SubstitutionCount, PieceCount);

    if Piece <> EOT then
    begin
      if Head = EOT then
        Head := Piece
      else
        Tree[Tail]^.RHS := Piece;
      Last := Tree.LastSibling[Piece];
      Tail := Last;
    end;
    Cur := Tree[Cur]^.RHS;
  end;

  Result := Head;
end;

procedure SplitRuleTemplate(
  Tree: TCustomTree;
  RuleIndex: Integer;
  out ReplaceIndex: Integer;
  out GuardIndex: Integer
);
var
  Cur: Integer;
begin
  ReplaceIndex := Tree[RuleIndex]^.RHS;
  GuardIndex := EOT;
  Cur := ReplaceIndex;
  while Cur <> EOT do
  begin
    if IsGuardNode(Tree, Cur) then
    begin
      GuardIndex := Cur;
      Exit;
    end;
    Cur := Tree[Cur]^.RHS;
  end;
end;

function UnwrapRuleEvalWrapper(Tree: TCustomTree; Index: Integer): Integer;
var
  Cur: Integer;
  Child: Integer;
begin
  Cur := Index;
  while Cur <> EOT do
  begin
    if Tree[Cur]^.Id <> MID_OBJ_EVALUATION then
      Break;
    if Tree[Cur]^.RHS <> EOT then
      Break;
    if (Tree[Cur]^.Data and (TK_OPERATOR_MASK or TK_SELECTOR_MASK or TK_META_MASK)) <> 0 then
      Break;
    Child := Tree[Cur]^.LHS;
    if Child = EOT then
      Break;
    Cur := Child;
  end;
  Result := Cur;
end;

function GuardToBoolean(Tree: TCustomTree; Index: Integer): Boolean;
var
  ValueIndex: Integer;
  TokenValue: ansistring;
  NumberValue: Int64;
begin
  ValueIndex := Index;
  if ValueIndex = EOT then
    Exit(False);

  if (Tree[ValueIndex]^.Id = MID_OBJ_EXPRESSION) or
     (Tree[ValueIndex]^.Id = MID_OBJ_ARRAY) or
     (Tree[ValueIndex]^.Id = MID_OBJ_EVALUATION) then
    ValueIndex := Tree[ValueIndex]^.LHS;

  if ValueIndex = EOT then
    Exit(False);

  if Tree[ValueIndex]^.Id = MID_OBJ_INTEGER then
  begin
    TokenValue := Tree.Expression.TokenValue(Tree[ValueIndex]^.Ref);
    NumberValue := StrToIntDef(TokenValue, 0);
    Exit(NumberValue <> 0);
  end;

  Result := True;
end;

function EvaluateGuardTemplate(
  Tree: TCustomTree;
  GuardTemplateIndex: Integer;
  const Symbols: TArrayOfString;
  const Bindings: TMatchBindings;
  Context: TContext;
  MatchHead: Integer;
  MatchTail: Integer;
  FocusHead: Integer;
  FocusTail: Integer
): Boolean;
var
  GuardIndex: Integer;
  GuardNode: TBaseNode;
begin
  if GuardTemplateIndex = EOT then
    Exit(True);

  GuardIndex := CloneTemplateNodeWithBindings(
    Tree, GuardTemplateIndex, Context, Symbols, Bindings,
    MatchHead, MatchTail, FocusHead, FocusTail
  );
  if GuardIndex = EOT then
    Exit(False);

  GuardNode := nodes.GetNode(GuardIndex);
  GuardNode.Compute(Context);
  Result := GuardToBoolean(Tree, GuardIndex);

  Tree.DeleteSubtree(EOT, GuardIndex);
end;

function TryProbeRuleMatch(
  Tree: TCustomTree;
  RuleIndex: Integer;
  SubjectIndex: Integer;
  Context: TContext;
  AllowSubjectTail: Boolean;
  Direction: TRewriteDirection;
  out Probe: TRewriteProbe
): Boolean;
var
  PatternIndex, ReplaceIndex, GuardIndex: Integer;
  function TryProbeDirectional(
    APatternIndex: Integer;
    AReplaceIndex: Integer;
    AGuardIndex: Integer
  ): Boolean;
  var
    EffectivePatternIndex: Integer;
    EffectiveMatchPatternIndex: Integer;
    Symbols: TArrayOfString;
    Bindings: TMatchBindings;
    MatchHead, MatchTail, FocusHead, FocusTail: Integer;
    FocusCount: Integer;
    UseFocusTarget: Boolean;
    IsSubstitutionRule: Boolean;
    IsSymbolSubstitutionRule: Boolean;
    StrictSubstitutionEnabled: Boolean;
    TargetHead: Integer;
    TargetTail: Integer;
    FixedRulePattern: Boolean;
    PreviousFixedPattern: Boolean;
  begin
    Result := False;
    MatchHead := EOT;
    FocusHead := EOT;
    FocusTail := EOT;

    if APatternIndex = EOT then
      Exit(False);

    EffectivePatternIndex := UnwrapRuleEvalWrapper(Tree, APatternIndex);
    Probe.EffectiveReplaceIndex := UnwrapRuleEvalWrapper(Tree, AReplaceIndex);
    IsSubstitutionRule := (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_TRANSFORMATION) or
                          (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) or
                          (Tree[RuleIndex]^.Id = MID_OBJ_SYMBOL_SUBST_TRANSFORMATION);
    IsSymbolSubstitutionRule := Tree[RuleIndex]^.Id = MID_OBJ_SYMBOL_SUBST_TRANSFORMATION;
    FixedRulePattern := IsFixedTransformationRule(Tree, RuleIndex) and
                        (not IsSubstitutionRule);
    StrictSubstitutionEnabled := True;
    if IsSubstitutionRule and (not IsSymbolSubstitutionRule) then
      StrictSubstitutionEnabled := IsStrictSubstitutionEnabled(Tree, Context);

    if IsSubstitutionRule and (not IsSymbolSubstitutionRule) and StrictSubstitutionEnabled then
      if not HasStrictSubstitutionShape(
               Tree,
               EffectivePatternIndex,
               Probe.EffectiveReplaceIndex
             ) then
      begin
        LogDiagEvent(Context, 'substitution strictness failed: vars(LHS) must equal vars(RHS)');
        Exit(False);
      end;

    if IsSubstitutionRule and (not IsSymbolSubstitutionRule) then
      EffectiveMatchPatternIndex := EffectivePatternIndex
    else
      EffectiveMatchPatternIndex := PromoteLeadingFixedPatternSequence(
                                      Tree,
                                      EffectivePatternIndex,
                                      Context
                                    );

    Symbols := nil;
    if IsSymbolSubstitutionRule then
    begin
      Bindings.Init(0);
      MatchHead := SubjectIndex;
      MatchTail := EOT;
      FocusHead := EOT;
      FocusTail := EOT;
      FocusCount := 0;
    end
    else
    begin
      FocusCount := CountPatternFocusMarkers(Tree, EffectiveMatchPatternIndex);
      if FocusCount > 1 then
        raise Exception.CreateFmt('Rule has multiple focus markers in pattern: %s',
          [nodes.GetNode(RuleIndex).TreeValue]);

      if not FixedRulePattern then
        CollectPatternSymbols(Tree, EffectiveMatchPatternIndex, Symbols);
      Bindings.Init(Length(Symbols));

      PreviousFixedPattern := MatcherPatternVariablesFixed;
      MatcherPatternVariablesFixed := FixedRulePattern;
      MatcherContext := Context;
      try
        if not MatchPatternSequenceEx(
                 Tree, EffectiveMatchPatternIndex, SubjectIndex, Symbols, Bindings,
                 FocusCount = 1, FocusHead, FocusTail,
                 AllowSubjectTail and (not FixedRulePattern), MatchTail, MatchHead
               ) then
        begin
          LogTraceEvent(Context, 'rule did not match subject');
          Exit(False);
        end;
      finally
        MatcherContext := nil;
        MatcherPatternVariablesFixed := PreviousFixedPattern;
      end;

      if MatchHead = EOT then
        MatchHead := SubjectIndex;
    end;

    if MatcherGuardsEnabled and
       (not EvaluateGuardTemplate(
              Tree, AGuardIndex, Symbols, Bindings, Context,
              MatchHead, MatchTail, FocusHead, FocusTail
            )) then
    begin
      LogDiagEvent(Context, 'rule guard evaluated to false');
      Exit(False);
    end;

    UseFocusTarget := (not IsSymbolSubstitutionRule) and
                      ((Tree[RuleIndex]^.Data and TK_DOT) = TK_DOT);
    if UseFocusTarget and (FocusHead <> EOT) then
    begin
      TargetHead := FocusHead;
      TargetTail := FocusTail;
    end
    else
    begin
      TargetHead := MatchHead;
      TargetTail := MatchTail;
    end;

    // Substitution rewrites operate over the full probed subject unless the
    // rule explicitly targets a focused subspan. Keep the probe span aligned
    // with the actual replacement span so later apply/score logic stays
    // consistent with the built replacement tree.
    if IsSubstitutionRule and (not UseFocusTarget) then
    begin
      TargetHead := SubjectIndex;
      TargetTail := EOT;
    end;

    Probe.RuleIndex := RuleIndex;
    Probe.Direction := Direction;
    Probe.AnchorNode := SubjectIndex;
    Probe.EffectivePatternIndex := EffectivePatternIndex;
    Probe.GuardTemplateIndex := AGuardIndex;
    Probe.MatchHead := MatchHead;
    Probe.MatchTail := MatchTail;
    Probe.TargetHead := TargetHead;
    Probe.TargetTail := TargetTail;
    Probe.FocusHead := FocusHead;
    Probe.FocusTail := FocusTail;
    Probe.UseFocusTarget := UseFocusTarget;
    Probe.Symbols := Symbols;
    Probe.Bindings := Bindings;
    EmitDebuggerRewriteProbeEvent(
      Tree,
      RuleIndex,
      SubjectIndex,
      Ord(Direction),
      Context
    );
    Result := True;
  end;
begin
  Result := False;
  Probe.RuleIndex := EOT;
  Probe.Direction := Direction;
  Probe.AnchorNode := SubjectIndex;
  Probe.EffectivePatternIndex := EOT;
  Probe.EffectiveReplaceIndex := EOT;
  Probe.GuardTemplateIndex := EOT;
  Probe.MatchHead := EOT;
  Probe.MatchTail := EOT;
  Probe.TargetHead := EOT;
  Probe.TargetTail := EOT;
  Probe.FocusHead := EOT;
  Probe.FocusTail := EOT;
  Probe.UseFocusTarget := False;
  Probe.Symbols := nil;
  Probe.Bindings.Init(0);

  if (Tree[RuleIndex]^.Id = MID_OBJ_EQUIVALENCE) or
     (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) then
  begin
    if Direction = rdReverse then
      Exit(TryProbeDirectional(Tree[RuleIndex]^.RHS, Tree[RuleIndex]^.LHS, EOT))
    else
      Exit(TryProbeDirectional(Tree[RuleIndex]^.LHS, Tree[RuleIndex]^.RHS, EOT));
  end;

  PatternIndex := Tree[RuleIndex]^.LHS;
  SplitRuleTemplate(Tree, RuleIndex, ReplaceIndex, GuardIndex);
  if PatternIndex = EOT then
    Exit(False);

  Result := TryProbeDirectional(PatternIndex, ReplaceIndex, GuardIndex);
end;

function BuildRewriteFromProbe(
  Tree: TCustomTree;
  const Probe: TRewriteProbe;
  Context: TContext;
  out RewrittenIndex: Integer
): Boolean;
var
  RuleIndex: Integer;
  IsSubstitutionRule: Boolean;
  IsSymbolSubstitutionRule: Boolean;
  SubstitutionHead: Integer;
  SubstitutionTail: Integer;
  SubstitutionCount: Integer;
  SubstitutionEntries: TArrayOfSubstitutionEntry;
  SubstitutionFailureReason: ansistring;
begin
  Result := False;
  RewrittenIndex := EOT;
  RuleIndex := Probe.RuleIndex;
  if RuleIndex = EOT then
    Exit(False);

  IsSubstitutionRule := (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_TRANSFORMATION) or
                        (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) or
                        (Tree[RuleIndex]^.Id = MID_OBJ_SYMBOL_SUBST_TRANSFORMATION);
  IsSymbolSubstitutionRule := Tree[RuleIndex]^.Id = MID_OBJ_SYMBOL_SUBST_TRANSFORMATION;

  if IsSubstitutionRule then
  begin
    if BuildSubstitutionEntries(
         Tree,
         Probe.EffectivePatternIndex,
         Probe.EffectiveReplaceIndex,
         Probe.GuardTemplateIndex,
         not IsSymbolSubstitutionRule,
         Context,
         Probe.Symbols,
         Probe.Bindings,
         Probe.MatchHead,
         Probe.MatchTail,
         Probe.FocusHead,
         Probe.FocusTail,
         SubstitutionEntries,
         SubstitutionFailureReason
       ) then
    begin
      try
        SubstitutionHead := Probe.TargetHead;
        SubstitutionTail := Probe.TargetTail;

        if SubstitutionHead = EOT then
          Exit(False);

        RewrittenIndex := CloneSequenceWithSubstitution(
          Tree,
          SubstitutionHead,
          SubstitutionTail,
          SubstitutionEntries,
          SubstitutionCount
        );
        Result := SubstitutionCount > 0;
        if (not Result) and (RewrittenIndex <> EOT) then
        begin
          Tree.DeleteSubtree(EOT, RewrittenIndex);
          RewrittenIndex := EOT;
        end;
        if Result then
          LogTraceEvent(Context, 'substitution rewrite applied')
        else
          LogDiagEvent(Context, 'substitution rewrite made no changes');
        Exit(Result);
      finally
        CleanupSubstitutionEntries(Tree, SubstitutionEntries);
      end;
    end
    else
    begin
      LogDiagEvent(Context, 'invalid substitution mapping: ' + SubstitutionFailureReason);
      Exit(False);
    end;
  end;

  // MVP hygiene: normal rule replacements should not implicitly capture
  // plain program variables from the ambient context at template-clone time.
  RewrittenIndex := CloneTemplateSequenceWithBindings(
    Tree,
    Probe.EffectiveReplaceIndex,
    Context,
    Probe.Symbols,
    Probe.Bindings,
    Probe.MatchHead,
    Probe.MatchTail,
    Probe.FocusHead,
    Probe.FocusTail,
    Probe.GuardTemplateIndex,
    False
  );
  if Probe.EffectiveReplaceIndex = EOT then
    Result := True
  else
    Result := RewrittenIndex <> EOT;
  if Result then
    LogTraceEvent(Context, 'rewrite applied');
end;

function TryRewriteRule(
  Tree: TCustomTree;
  RuleIndex: Integer;
  SubjectIndex: Integer;
  Context: TContext;
  out RewrittenIndex: Integer;
  AllowSubjectTail: Boolean;
  out MatchTail: Integer;
  out TargetHead: Integer;
  out TargetTail: Integer;
  Direction: TRewriteDirection
): Boolean;
var
  Probe: TRewriteProbe;
begin
  Result := False;
  RewrittenIndex := EOT;
  MatchTail := EOT;
  TargetHead := EOT;
  TargetTail := EOT;

  if not TryProbeRuleMatch(
           Tree,
           RuleIndex,
           SubjectIndex,
           Context,
           AllowSubjectTail,
           Direction,
           Probe
         ) then
    Exit(False);

  MatchTail := Probe.MatchTail;
  TargetHead := Probe.TargetHead;
  TargetTail := Probe.TargetTail;
  Result := BuildRewriteFromProbe(Tree, Probe, Context, RewrittenIndex);
end;

function RuleDirectionCount(Tree: TCustomTree; RuleIndex: Integer): Integer; inline;
begin
  Result := 1;
  if (Tree[RuleIndex]^.Id = MID_OBJ_EQUIVALENCE) or
     (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) then
    Result := 2;
end;

function AllowsRuleDirection(
  const RuleRef: TCollectedRuleRef;
  Direction: TRewriteDirection
): Boolean; inline;
begin
  case RuleRef.Orientation of
    iroForwardOnly: Result := Direction = rdForward;
    iroReverseOnly: Result := Direction = rdReverse;
  else
    Result := True;
  end;
end;

function FindPreorderOrdinalInTree(
  Tree: TCustomTree;
  NodeIndex: Integer;
  TargetIndex: Integer;
  var Counter: Integer;
  out Ordinal: Integer
): Boolean;
begin
  Result := False;
  while NodeIndex <> EOT do
  begin
    if NodeIndex = TargetIndex then
    begin
      Ordinal := Counter;
      Exit(True);
    end;
    Inc(Counter);
    if FindPreorderOrdinalInTree(Tree, Tree[NodeIndex]^.LHS, TargetIndex, Counter, Ordinal) then
      Exit(True);
    NodeIndex := Tree[NodeIndex]^.RHS;
  end;
end;

function ComputeAnchorOrdinalInTree(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer
): Integer;
var
  Counter: Integer;
  Ordinal: Integer;
begin
  Result := -1;
  if (SubjectIndex = EOT) or (TargetIndex = EOT) then
    Exit;
  Counter := 0;
  Ordinal := -1;
  if FindPreorderOrdinalInTree(Tree, SubjectIndex, TargetIndex, Counter, Ordinal) then
    Result := Ordinal;
end;

function FindNodeByPreorderOrdinalInTree(
  Tree: TCustomTree;
  NodeIndex: Integer;
  PrevIndex: Integer;
  DesiredOrdinal: Integer;
  var Counter: Integer;
  out FoundNode: Integer;
  out FoundPrev: Integer
): Boolean;
var
  Cur: Integer;
begin
  Result := False;
  Cur := NodeIndex;
  while Cur <> EOT do
  begin
    if Counter = DesiredOrdinal then
    begin
      FoundNode := Cur;
      FoundPrev := PrevIndex;
      Exit(True);
    end;
    Inc(Counter);
    if FindNodeByPreorderOrdinalInTree(
         Tree,
         Tree[Cur]^.LHS,
         Cur,
         DesiredOrdinal,
         Counter,
         FoundNode,
         FoundPrev
       ) then
      Exit(True);
    PrevIndex := Cur;
    Cur := Tree[Cur]^.RHS;
  end;
end;

function FindRewriteStartInTree(
  Tree: TCustomTree;
  NodeIndex: Integer;
  PrevIndex: Integer;
  TargetIndex: Integer;
  out FoundPrev: Integer
): Boolean;
var
  Cur: Integer;
begin
  Result := False;
  Cur := NodeIndex;
  while Cur <> EOT do
  begin
    if Cur = TargetIndex then
    begin
      FoundPrev := PrevIndex;
      Exit(True);
    end;
    if FindRewriteStartInTree(Tree, Tree[Cur]^.LHS, Cur, TargetIndex, FoundPrev) then
      Exit(True);
    PrevIndex := Cur;
    Cur := Tree[Cur]^.RHS;
  end;
end;

function FindSpanPrevInMatchInTree(
  Tree: TCustomTree;
  StartNode: Integer;
  StopTail: Integer;
  PrevForStart: Integer;
  TargetNode: Integer;
  out FoundPrev: Integer
): Boolean;
var
  Cur: Integer;
  PrevInChain: Integer;
begin
  Result := False;
  Cur := StartNode;
  PrevInChain := PrevForStart;
  while (Cur <> EOT) and (Cur <> StopTail) do
  begin
    if Cur = TargetNode then
    begin
      FoundPrev := PrevInChain;
      Exit(True);
    end;
    if FindSpanPrevInMatchInTree(Tree, Tree[Cur]^.LHS, EOT, Cur, TargetNode, FoundPrev) then
      Exit(True);
    PrevInChain := Cur;
    Cur := Tree[Cur]^.RHS;
  end;
end;

function ReplaceSpanInTree(
  Tree: TCustomTree;
  SpanHead: Integer;
  SpanTail: Integer;
  SpanPrev: Integer;
  SpanRoot: Integer;
  Replacement: Integer;
  out NewRoot: Integer
): Boolean;
var
  SpanLastLocal: Integer;
  RewrittenLastLocal: Integer;
begin
  Result := False;
  NewRoot := SpanRoot;
  if SpanHead = EOT then
    Exit(False);

  if SpanTail <> EOT then
  begin
    SpanLastLocal := SpanHead;
    while (SpanLastLocal <> EOT) and (Tree[SpanLastLocal]^.RHS <> SpanTail) do
      SpanLastLocal := Tree[SpanLastLocal]^.RHS;
    if SpanLastLocal = EOT then
      Exit(False);
    Tree[SpanLastLocal]^.RHS := EOT;
  end;

  if Replacement = EOT then
    Replacement := SpanTail
  else if SpanTail <> EOT then
  begin
    RewrittenLastLocal := Tree.LastSibling[Replacement];
    Tree[RewrittenLastLocal]^.RHS := SpanTail;
  end;

  if SpanPrev = EOT then
    NewRoot := Replacement
  else if Tree[SpanPrev]^.LHS = SpanHead then
    Tree[SpanPrev]^.LHS := Replacement
  else if Tree[SpanPrev]^.RHS = SpanHead then
    Tree[SpanPrev]^.RHS := Replacement
  else
    Exit(False);

  Tree.DeleteSubtree(EOT, SpanHead);
  Result := True;
end;

function ApplyRewriteProbeAtNodeInTree(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  NodeIndex: Integer;
  PrevIndex: Integer;
  const Probe: TRewriteProbe;
  Context: TContext;
  CongruenceBudget: PInteger;
  out RootIndex: Integer
): Boolean;
var
  SpanPrev: Integer;
  ReplacementNode: Integer;
  InlineReplaceOnly: Boolean;
  AnchorOrdinal: Integer;
begin
  Result := False;
  RootIndex := SubjectIndex;
  if not BuildRewriteFromProbe(Tree, Probe, Context, ReplacementNode) then
    Exit(False);

  InlineReplaceOnly := Tree[Probe.RuleIndex]^.Id = MID_OBJ_INLINE_TRANSFORMATION;
  AnchorOrdinal := ComputeAnchorOrdinalInTree(Tree, SubjectIndex, Probe.TargetHead);
  if not FindSpanPrevInMatchInTree(
           Tree,
           NodeIndex,
           Probe.MatchTail,
           PrevIndex,
           Probe.TargetHead,
           SpanPrev
         ) then
    SpanPrev := PrevIndex;

  if InlineReplaceOnly then
  begin
    RootIndex := ReplacementNode;
    if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) then
      Dec(CongruenceBudget^);
    LastRewriteRuleIndex := Probe.RuleIndex;
    LastRewriteDirection := Ord(Probe.Direction);
    LastRewriteAnchorOrdinal := AnchorOrdinal;
    Tree.DeleteSubtree(EOT, SubjectIndex);
    Exit(True);
  end;

  if ReplaceSpanInTree(
       Tree,
       Probe.TargetHead,
       Probe.TargetTail,
       SpanPrev,
       SubjectIndex,
       ReplacementNode,
       RootIndex
     ) then
  begin
    if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) then
      Dec(CongruenceBudget^);
    LastRewriteRuleIndex := Probe.RuleIndex;
    LastRewriteDirection := Ord(Probe.Direction);
    LastRewriteAnchorOrdinal := AnchorOrdinal;
    Exit(True);
  end;

  if ReplacementNode <> EOT then
    Tree.DeleteSubtree(EOT, ReplacementNode);
end;

function CanRewriteOneStep(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  RulesRootIndex: Integer;
  Context: TContext;
  MatchSubexpressions: Boolean = False;
  CongruenceBudget: Integer = -1;
  BeamWidth: Integer = 1;
  UseCostPolicy: Boolean = False;
  OnInferenceEvent: TInferenceEventCallback = nil;
  InferenceEventUserData: Pointer = nil;
  SearchStats: PInferenceSearchStats = nil
): Boolean;
begin
  Result := CanRewriteWithinSteps(
    Tree, SubjectIndex, TargetIndex, RulesRootIndex, Context, 1,
    MatchSubexpressions, CongruenceBudget, BeamWidth, UseCostPolicy,
    OnInferenceEvent, InferenceEventUserData, SearchStats
  );
end;

function CanRewriteWithinSteps(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  RulesRootIndex: Integer;
  Context: TContext;
  MaxSteps: Integer;
  MatchSubexpressions: Boolean = False;
  CongruenceBudget: Integer = -1;
  BeamWidth: Integer = 1;
  UseCostPolicy: Boolean = False;
  OnInferenceEvent: TInferenceEventCallback = nil;
  InferenceEventUserData: Pointer = nil;
  SearchStats: PInferenceSearchStats = nil
): Boolean;
type
  TSearchState = record
    Root: Integer;
    RemainingBudget: Integer;
    StateId: Integer;
    NodeCount: Integer;
    PathCost: Integer;
  end;
  TQueuedCandidate = record
    Root: Integer;
    RemainingBudget: Integer;
    ParentStateId: Integer;
    RuleSourceIndex: Integer;
    RuleIndex: Integer;
    RuleName: ansistring;
    Direction: Integer;
    OrientationExplicit: Integer;
    BeforeSnapshot: Integer;
    AnchorOrdinal: Integer;
    Step: Integer;
    NodeCount: Integer;
    PathCost: Integer;
  end;
var
  Step: Integer;
  RewrittenRoot: Integer;
  RemainingBudget: Integer;
  CurrentStates: array of TSearchState;
  NextStates: array of TSearchState;
  QueuedCandidates: array of TQueuedCandidate;
  RuleRefs: TArrayOfCollectedRuleRef;
  Visited: TStringList;
  I: Integer;
  J: Integer;
  Key: ansistring;
  ExistingIndex: Integer;
  ExistingBudget: Integer;
  NextStateId: Integer;
  CandidateStateId: Integer;
  BeforeSnapshot: Integer;
  AnchorsPerRule: Integer;
  SettingValue: Integer;
  SettingSource: ansistring;
  SettingReadResult: TSettingReadResult;
  LocalKeys: TStringList;
  MatchOrdinal: Integer;
  DirectionCount: Integer;
  DirectionIndex: Integer;
  Direction: TRewriteDirection;
  CandidateNodeCount: Integer;
  CandidateGrowth: Integer;
  CandidatePathCost: Integer;

  procedure ResetSearchStats;
  begin
    if not Assigned(SearchStats) then
      Exit;
    SearchStats^.CandidatesGenerated := 0;
    SearchStats^.CandidatesAdmitted := 0;
    SearchStats^.CandidatesPrunedBeam := 0;
    SearchStats^.CandidatesPrunedVisited := 0;
    SearchStats^.CandidatesLocalDeduplicated := 0;
    SearchStats^.CandidatesAbandonedSuccess := 0;
    SearchStats^.ForwardCandidates := 0;
    SearchStats^.ReverseCandidates := 0;
    SearchStats^.ExpandedStates := 0;
    SearchStats^.MaxCandidateQueue := 0;
    SearchStats^.MaxRetainedFrontier := 0;
    SearchStats^.RuleDirections := nil;
  end;

  function RuleStatsIndex(const RuleName: ansistring; DirectionValue: Integer): Integer;
  var
    K: Integer;
    EffectiveRuleName: ansistring;
  begin
    Result := -1;
    if not Assigned(SearchStats) then
      Exit;
    EffectiveRuleName := RuleName;
    if EffectiveRuleName = '' then
      EffectiveRuleName := '<unnamed>';
    for K := 0 to High(SearchStats^.RuleDirections) do
      if (SearchStats^.RuleDirections[K].RuleName = EffectiveRuleName) and
         (SearchStats^.RuleDirections[K].Direction = DirectionValue) then
        Exit(K);
    Result := Length(SearchStats^.RuleDirections);
    SetLength(SearchStats^.RuleDirections, Result + 1);
    SearchStats^.RuleDirections[Result].RuleName := EffectiveRuleName;
    SearchStats^.RuleDirections[Result].Direction := DirectionValue;
  end;

  procedure RecordCandidateGenerated(const RuleName: ansistring; DirectionValue: Integer);
  var
    StatsIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    Inc(SearchStats^.CandidatesGenerated);
    if DirectionValue = Ord(rdReverse) then
      Inc(SearchStats^.ReverseCandidates)
    else
      Inc(SearchStats^.ForwardCandidates);
    StatsIndex := RuleStatsIndex(RuleName, DirectionValue);
    Inc(SearchStats^.RuleDirections[StatsIndex].CandidatesGenerated);
  end;

  procedure RecordCandidateAdmitted(const RuleName: ansistring; DirectionValue: Integer);
  var
    StatsIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    Inc(SearchStats^.CandidatesAdmitted);
    StatsIndex := RuleStatsIndex(RuleName, DirectionValue);
    Inc(SearchStats^.RuleDirections[StatsIndex].CandidatesAdmitted);
  end;

  procedure RecordCandidateBeamPruned(const RuleName: ansistring; DirectionValue: Integer);
  var
    StatsIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    Inc(SearchStats^.CandidatesPrunedBeam);
    StatsIndex := RuleStatsIndex(RuleName, DirectionValue);
    Inc(SearchStats^.RuleDirections[StatsIndex].CandidatesPrunedBeam);
  end;

  procedure RecordCandidateVisitedPruned(const RuleName: ansistring; DirectionValue: Integer);
  var
    StatsIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    Inc(SearchStats^.CandidatesPrunedVisited);
    StatsIndex := RuleStatsIndex(RuleName, DirectionValue);
    Inc(SearchStats^.RuleDirections[StatsIndex].CandidatesPrunedVisited);
  end;

  procedure RecordCandidateLocalDeduplicated(const RuleName: ansistring; DirectionValue: Integer);
  var
    StatsIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    Inc(SearchStats^.CandidatesLocalDeduplicated);
    StatsIndex := RuleStatsIndex(RuleName, DirectionValue);
    Inc(SearchStats^.RuleDirections[StatsIndex].CandidatesLocalDeduplicated);
  end;

  procedure RecordCandidateAbandonedSuccess(const RuleName: ansistring; DirectionValue: Integer);
  var
    StatsIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    Inc(SearchStats^.CandidatesAbandonedSuccess);
    StatsIndex := RuleStatsIndex(RuleName, DirectionValue);
    Inc(SearchStats^.RuleDirections[StatsIndex].CandidatesAbandonedSuccess);
  end;

  procedure FreeStateRoots(var States: array of TSearchState);
  var
    K: Integer;
  begin
    for K := 0 to High(States) do
      if States[K].Root <> EOT then
      begin
        Tree.DeleteSubtree(EOT, States[K].Root);
        States[K].Root := EOT;
      end;
  end;

  function BudgetStronger(NewBudget, OldBudget: Integer): Boolean;
  begin
    if NewBudget = OldBudget then
      Exit(False);
    if NewBudget = -1 then
      Exit(True);
    if OldBudget = -1 then
      Exit(False);
    Result := NewBudget > OldBudget;
  end;

  function StateKey(Root: Integer): ansistring;
  begin
    if Root = EOT then
      Exit('<eot>');
    Result := nodes.GetNode(Root).TreeValue;
  end;

  procedure UpdateQueueMaximum;
  begin
    if Assigned(SearchStats) and
       (Length(QueuedCandidates) > SearchStats^.MaxCandidateQueue) then
      SearchStats^.MaxCandidateQueue := Length(QueuedCandidates);
  end;

  function CountTreeNodes(Root: Integer): Integer;
  var
    Cur: Integer;
  begin
    Result := 0;
    Cur := Root;
    while Cur <> EOT do
    begin
      Inc(Result);
      Inc(Result, CountTreeNodes(Tree[Cur]^.LHS));
      Cur := Tree[Cur]^.RHS;
    end;
  end;

  function AcceptByVisited(const CandidateKey: ansistring; CandidateBudget: Integer): Boolean;
  begin
    ExistingIndex := Visited.IndexOf(CandidateKey);
    if ExistingIndex < 0 then
    begin
      Visited.AddObject(CandidateKey, TObject(PtrInt(CandidateBudget)));
      Exit(True);
    end;

    ExistingBudget := PtrInt(Visited.Objects[ExistingIndex]);
    if BudgetStronger(CandidateBudget, ExistingBudget) then
    begin
      Visited.Objects[ExistingIndex] := TObject(PtrInt(CandidateBudget));
      Exit(True);
    end;
    Result := False;
  end;

  procedure CleanupQueuedCandidate(var Candidate: TQueuedCandidate);
  begin
    if Candidate.Root <> EOT then
    begin
      Tree.DeleteSubtree(EOT, Candidate.Root);
      Candidate.Root := EOT;
    end;
    if Candidate.BeforeSnapshot <> EOT then
    begin
      Tree.DeleteSubtree(EOT, Candidate.BeforeSnapshot);
      Candidate.BeforeSnapshot := EOT;
    end;
  end;

  procedure FreeQueuedCandidates(var Candidates: array of TQueuedCandidate);
  var
    K: Integer;
  begin
    for K := 0 to High(Candidates) do
      CleanupQueuedCandidate(Candidates[K]);
  end;

  procedure QueueCandidate(
    CandidateRoot: Integer;
    CandidateBudget: Integer;
    CandidateParentStateId: Integer;
    CandidateRuleSourceIndex: Integer;
    CandidateRuleIndex: Integer;
    const CandidateRuleName: ansistring;
    CandidateDirection: Integer;
    CandidateOrientationExplicit: Integer;
    CandidateBeforeSnapshot: Integer;
    CandidateAnchorOrdinal: Integer;
    CandidateStep: Integer;
    CandidateNodeCount: Integer;
    CandidatePathCost: Integer
  );
  var
    L: Integer;
  begin
    if CandidateRoot = EOT then
    begin
      if CandidateBeforeSnapshot <> EOT then
        Tree.DeleteSubtree(EOT, CandidateBeforeSnapshot);
      Exit;
    end;
    L := Length(QueuedCandidates);
    SetLength(QueuedCandidates, L + 1);
    QueuedCandidates[L].Root := CandidateRoot;
    QueuedCandidates[L].RemainingBudget := CandidateBudget;
    QueuedCandidates[L].ParentStateId := CandidateParentStateId;
    QueuedCandidates[L].RuleSourceIndex := CandidateRuleSourceIndex;
    QueuedCandidates[L].RuleIndex := CandidateRuleIndex;
    QueuedCandidates[L].RuleName := CandidateRuleName;
    QueuedCandidates[L].Direction := CandidateDirection;
    QueuedCandidates[L].OrientationExplicit := CandidateOrientationExplicit;
    QueuedCandidates[L].BeforeSnapshot := CandidateBeforeSnapshot;
    QueuedCandidates[L].AnchorOrdinal := CandidateAnchorOrdinal;
    QueuedCandidates[L].Step := CandidateStep;
    QueuedCandidates[L].NodeCount := CandidateNodeCount;
    QueuedCandidates[L].PathCost := CandidatePathCost;
  end;

  procedure QueueCandidateWithLocalDedup(
    var LocalKeys: TStringList;
    CandidateRoot: Integer;
    CandidateBudget: Integer;
    CandidateParentStateId: Integer;
    CandidateRuleSourceIndex: Integer;
    CandidateRuleIndex: Integer;
    const CandidateRuleName: ansistring;
    CandidateDirection: Integer;
    CandidateOrientationExplicit: Integer;
    CandidateBeforeSnapshot: Integer;
    CandidateAnchorOrdinal: Integer;
    CandidateStep: Integer;
    CandidateNodeCount: Integer;
    CandidatePathCost: Integer
  );
  var
    CandidateKey: ansistring;
    LocalIndex: Integer;
    QueueIndex: Integer;
    L: Integer;
  begin
    if CandidateRoot = EOT then
    begin
      if CandidateBeforeSnapshot <> EOT then
        Tree.DeleteSubtree(EOT, CandidateBeforeSnapshot);
      Exit;
    end;

    CandidateKey := StateKey(CandidateRoot);
    LocalIndex := LocalKeys.IndexOf(CandidateKey);
    if LocalIndex >= 0 then
    begin
      RecordCandidateLocalDeduplicated(CandidateRuleName, CandidateDirection);
      QueueIndex := PtrInt(LocalKeys.Objects[LocalIndex]);
      if (QueueIndex >= 0) and (QueueIndex <= High(QueuedCandidates)) and
         BudgetStronger(CandidateBudget, QueuedCandidates[QueueIndex].RemainingBudget) then
      begin
        CleanupQueuedCandidate(QueuedCandidates[QueueIndex]);
        QueuedCandidates[QueueIndex].Root := CandidateRoot;
        QueuedCandidates[QueueIndex].RemainingBudget := CandidateBudget;
        QueuedCandidates[QueueIndex].ParentStateId := CandidateParentStateId;
        QueuedCandidates[QueueIndex].RuleSourceIndex := CandidateRuleSourceIndex;
        QueuedCandidates[QueueIndex].RuleIndex := CandidateRuleIndex;
        QueuedCandidates[QueueIndex].RuleName := CandidateRuleName;
        QueuedCandidates[QueueIndex].Direction := CandidateDirection;
        QueuedCandidates[QueueIndex].OrientationExplicit := CandidateOrientationExplicit;
        QueuedCandidates[QueueIndex].BeforeSnapshot := CandidateBeforeSnapshot;
        QueuedCandidates[QueueIndex].AnchorOrdinal := CandidateAnchorOrdinal;
        QueuedCandidates[QueueIndex].Step := CandidateStep;
        QueuedCandidates[QueueIndex].NodeCount := CandidateNodeCount;
        QueuedCandidates[QueueIndex].PathCost := CandidatePathCost;
      end
      else
      begin
        Tree.DeleteSubtree(EOT, CandidateRoot);
        if CandidateBeforeSnapshot <> EOT then
          Tree.DeleteSubtree(EOT, CandidateBeforeSnapshot);
      end;
      Exit;
    end;

    QueueCandidate(
      CandidateRoot,
      CandidateBudget,
      CandidateParentStateId,
      CandidateRuleSourceIndex,
      CandidateRuleIndex,
      CandidateRuleName,
      CandidateDirection,
      CandidateOrientationExplicit,
      CandidateBeforeSnapshot,
      CandidateAnchorOrdinal,
      CandidateStep,
      CandidateNodeCount,
      CandidatePathCost
    );
    L := High(QueuedCandidates);
    LocalKeys.AddObject(CandidateKey, TObject(PtrInt(L)));
    UpdateQueueMaximum;
  end;

  function TryRewriteNthMatchForRuleDirection(
    BaseRoot: Integer;
    BaseBudget: Integer;
    RuleIndex: Integer;
    MatchDirection: TRewriteDirection;
    DesiredMatchOrdinal: Integer;
    out NewRoot: Integer;
    out NewBudget: Integer
  ): Boolean;
  var
    WorkingRoot: Integer;
    WorkingBudget: Integer;
    BudgetPtrLocal: PInteger;
    MatchCounter: Integer;
    SearchStart: Integer;
    SearchPrev: Integer;

    function VisitNthMatch(
      NodeIndex: Integer;
      PrevIndex: Integer;
      out AppliedRoot: Integer
    ): Boolean;
    var
      Probe: TRewriteProbe;
      Child: Integer;
      Sibling: Integer;
    begin
      Result := False;
      AppliedRoot := WorkingRoot;
      if NodeIndex = EOT then
        Exit(False);
      if (NodeIndex <> WorkingRoot) and Assigned(BudgetPtrLocal) and
         (BudgetPtrLocal^ <= 0) then
        Exit(False);

      if TryProbeRuleMatch(
           Tree,
           RuleIndex,
           NodeIndex,
           Context,
           MatchSubexpressions,
           MatchDirection,
           Probe
         ) then
      begin
        Inc(MatchCounter);
        if MatchCounter = DesiredMatchOrdinal then
          Exit(
            ApplyRewriteProbeAtNodeInTree(
              Tree,
              WorkingRoot,
              NodeIndex,
              PrevIndex,
              Probe,
              Context,
              BudgetPtrLocal,
              AppliedRoot
            )
          );
      end;

      if not MatchSubexpressions then
        Exit(False);

      Child := Tree[NodeIndex]^.LHS;
      if VisitNthMatch(Child, NodeIndex, AppliedRoot) then
        Exit(True);

      Sibling := Tree[NodeIndex]^.RHS;
      if VisitNthMatch(Sibling, NodeIndex, AppliedRoot) then
        Exit(True);
    end;
  begin
    Result := False;
    NewRoot := EOT;
    NewBudget := BaseBudget;
    WorkingRoot := Tree.CloneSubtree(BaseRoot);
    if WorkingRoot = EOT then
      Exit(False);

    WorkingBudget := BaseBudget;
    if MatchSubexpressions and (WorkingBudget >= 0) then
      BudgetPtrLocal := @WorkingBudget
    else
      BudgetPtrLocal := nil;
    MatchCounter := 0;

    if MatchSubexpressions then
    begin
      SearchStart := ConsumeFirstCaretInSubtree(Tree, WorkingRoot);
      SearchPrev := EOT;
      if (SearchStart <> EOT) and (SearchStart <> WorkingRoot) then
      begin
        if not FindRewriteStartInTree(Tree, WorkingRoot, EOT, SearchStart, SearchPrev) then
          SearchStart := WorkingRoot;
      end
      else
        SearchStart := WorkingRoot;
    end
    else
    begin
      SearchStart := WorkingRoot;
      SearchPrev := EOT;
    end;

    if VisitNthMatch(SearchStart, SearchPrev, NewRoot) then
    begin
      NewBudget := WorkingBudget;
      Exit(True);
    end;

    Tree.DeleteSubtree(EOT, WorkingRoot);
    NewRoot := EOT;
  end;

  procedure SelectNextStatesFromQueuedCandidates;
  var
    StateId: Integer;
    L: Integer;
    CandidateIndex: Integer;
    AfterSnapshot: Integer;
    RoundApplied: Integer;
    CandidateUsed: array of Boolean;
    RoundBucketParents: array of Integer;
    RoundBucketRuleSources: array of Integer;
    RoundBucketDirections: array of Integer;
    RoundBucketCount: Integer;
    BucketIndex: Integer;

    function SeenRoundBucket(
      ParentStateId: Integer;
      RuleSourceIndex: Integer;
      Direction: Integer
    ): Boolean;
    var
      K: Integer;
    begin
      for K := 0 to RoundBucketCount - 1 do
        if (RoundBucketParents[K] = ParentStateId) and
           (RoundBucketRuleSources[K] = RuleSourceIndex) and
           (RoundBucketDirections[K] = Direction) then
          Exit(True);
      Result := False;
    end;

    procedure MarkRoundBucket(
      ParentStateId: Integer;
      RuleSourceIndex: Integer;
      Direction: Integer
    );
    begin
      BucketIndex := RoundBucketCount;
      Inc(RoundBucketCount);
      SetLength(RoundBucketParents, RoundBucketCount);
      SetLength(RoundBucketRuleSources, RoundBucketCount);
      SetLength(RoundBucketDirections, RoundBucketCount);
      RoundBucketParents[BucketIndex] := ParentStateId;
      RoundBucketRuleSources[BucketIndex] := RuleSourceIndex;
      RoundBucketDirections[BucketIndex] := Direction;
    end;
  begin
    SetLength(CandidateUsed, Length(QueuedCandidates));
    while Length(NextStates) < BeamWidth do
    begin
      RoundApplied := 0;
      RoundBucketCount := 0;
      SetLength(RoundBucketParents, 0);
      SetLength(RoundBucketRuleSources, 0);
      SetLength(RoundBucketDirections, 0);

      for CandidateIndex := 0 to High(QueuedCandidates) do
      begin
        if CandidateUsed[CandidateIndex] then
          Continue;
        if QueuedCandidates[CandidateIndex].Root = EOT then
        begin
          CandidateUsed[CandidateIndex] := True;
          Continue;
        end;
        if SeenRoundBucket(
             QueuedCandidates[CandidateIndex].ParentStateId,
             QueuedCandidates[CandidateIndex].RuleSourceIndex,
             QueuedCandidates[CandidateIndex].Direction
           ) then
          Continue;

        MarkRoundBucket(
          QueuedCandidates[CandidateIndex].ParentStateId,
          QueuedCandidates[CandidateIndex].RuleSourceIndex,
          QueuedCandidates[CandidateIndex].Direction
        );
        CandidateUsed[CandidateIndex] := True;
        Inc(RoundApplied);

        Key := StateKey(QueuedCandidates[CandidateIndex].Root);
        if not AcceptByVisited(
                 Key,
                 QueuedCandidates[CandidateIndex].RemainingBudget
               ) then
        begin
          RecordCandidateVisitedPruned(
            QueuedCandidates[CandidateIndex].RuleName,
            QueuedCandidates[CandidateIndex].Direction
          );
          CleanupQueuedCandidate(QueuedCandidates[CandidateIndex]);
          Continue;
        end;

        RecordCandidateAdmitted(
          QueuedCandidates[CandidateIndex].RuleName,
          QueuedCandidates[CandidateIndex].Direction
        );
        StateId := NextStateId;
        Inc(NextStateId);
        L := Length(NextStates);
        SetLength(NextStates, L + 1);
        NextStates[L].Root := QueuedCandidates[CandidateIndex].Root;
        NextStates[L].RemainingBudget := QueuedCandidates[CandidateIndex].RemainingBudget;
        NextStates[L].StateId := StateId;
        NextStates[L].NodeCount := QueuedCandidates[CandidateIndex].NodeCount;
        NextStates[L].PathCost := QueuedCandidates[CandidateIndex].PathCost;

        AfterSnapshot := EOT;
        if Assigned(OnInferenceEvent) then
          AfterSnapshot := Tree.CloneSubtree(QueuedCandidates[CandidateIndex].Root);
        EmitInferenceEvent(
          Tree, OnInferenceEvent, InferenceEventUserData,
          iekRewriteApplied, QueuedCandidates[CandidateIndex].Step, StateId,
          QueuedCandidates[CandidateIndex].ParentStateId,
          QueuedCandidates[CandidateIndex].RuleIndex,
          QueuedCandidates[CandidateIndex].RuleName,
          QueuedCandidates[CandidateIndex].Direction,
          QueuedCandidates[CandidateIndex].OrientationExplicit,
          QueuedCandidates[CandidateIndex].BeforeSnapshot,
          AfterSnapshot,
          QueuedCandidates[CandidateIndex].AnchorOrdinal
        );
        if (not Assigned(OnInferenceEvent)) and
           (QueuedCandidates[CandidateIndex].BeforeSnapshot <> EOT) then
          Tree.DeleteSubtree(EOT, QueuedCandidates[CandidateIndex].BeforeSnapshot);

        QueuedCandidates[CandidateIndex].Root := EOT;
        QueuedCandidates[CandidateIndex].BeforeSnapshot := EOT;

        if Length(NextStates) >= BeamWidth then
          Break;
      end;

      if RoundApplied = 0 then
        Break;
      if Length(NextStates) >= BeamWidth then
        Break;
    end;
  end;

  procedure SelectNextStatesByCost;
  var
    CandidateUsed: array of Boolean;
    IsRepresentative: array of Boolean;
    CandidateIndex: Integer;
    OtherIndex: Integer;
    BestIndex: Integer;
    StateId: Integer;
    L: Integer;
    AfterSnapshot: Integer;

    function SameBucket(A, B: Integer): Boolean;
    begin
      Result :=
        (QueuedCandidates[A].ParentStateId = QueuedCandidates[B].ParentStateId) and
        (QueuedCandidates[A].RuleSourceIndex = QueuedCandidates[B].RuleSourceIndex) and
        (QueuedCandidates[A].Direction = QueuedCandidates[B].Direction);
    end;

    function CandidateBetter(A, B: Integer): Boolean;
    begin
      if B < 0 then
        Exit(True);
      if QueuedCandidates[A].PathCost <> QueuedCandidates[B].PathCost then
        Exit(QueuedCandidates[A].PathCost < QueuedCandidates[B].PathCost);
      Result := A < B;
    end;

    procedure AdmitCandidate(QueueIndex: Integer);
    begin
      Key := StateKey(QueuedCandidates[QueueIndex].Root);
      if not AcceptByVisited(Key, QueuedCandidates[QueueIndex].RemainingBudget) then
      begin
        RecordCandidateVisitedPruned(
          QueuedCandidates[QueueIndex].RuleName,
          QueuedCandidates[QueueIndex].Direction
        );
        LogTraceEvent(
          Context,
          Format(
            'inference step=%d state=%d candidate pruned reason=visited score=%d policy=cost',
            [QueuedCandidates[QueueIndex].Step,
             QueuedCandidates[QueueIndex].ParentStateId,
             QueuedCandidates[QueueIndex].PathCost]
          )
        );
        CleanupQueuedCandidate(QueuedCandidates[QueueIndex]);
        Exit;
      end;

      RecordCandidateAdmitted(
        QueuedCandidates[QueueIndex].RuleName,
        QueuedCandidates[QueueIndex].Direction
      );
      StateId := NextStateId;
      Inc(NextStateId);
      L := Length(NextStates);
      SetLength(NextStates, L + 1);
      NextStates[L].Root := QueuedCandidates[QueueIndex].Root;
      NextStates[L].RemainingBudget := QueuedCandidates[QueueIndex].RemainingBudget;
      NextStates[L].StateId := StateId;
      NextStates[L].NodeCount := QueuedCandidates[QueueIndex].NodeCount;
      NextStates[L].PathCost := QueuedCandidates[QueueIndex].PathCost;
      LogTraceEvent(
        Context,
        Format(
          'inference step=%d state=%d candidate admitted score=%d policy=cost',
          [QueuedCandidates[QueueIndex].Step,
           QueuedCandidates[QueueIndex].ParentStateId,
           QueuedCandidates[QueueIndex].PathCost]
        )
      );

      AfterSnapshot := EOT;
      if Assigned(OnInferenceEvent) then
        AfterSnapshot := Tree.CloneSubtree(QueuedCandidates[QueueIndex].Root);
      EmitInferenceEvent(
        Tree, OnInferenceEvent, InferenceEventUserData,
        iekRewriteApplied, QueuedCandidates[QueueIndex].Step, StateId,
        QueuedCandidates[QueueIndex].ParentStateId,
        QueuedCandidates[QueueIndex].RuleIndex,
        QueuedCandidates[QueueIndex].RuleName,
        QueuedCandidates[QueueIndex].Direction,
        QueuedCandidates[QueueIndex].OrientationExplicit,
        QueuedCandidates[QueueIndex].BeforeSnapshot,
        AfterSnapshot,
        QueuedCandidates[QueueIndex].AnchorOrdinal
      );
      if (not Assigned(OnInferenceEvent)) and
         (QueuedCandidates[QueueIndex].BeforeSnapshot <> EOT) then
        Tree.DeleteSubtree(EOT, QueuedCandidates[QueueIndex].BeforeSnapshot);
      QueuedCandidates[QueueIndex].Root := EOT;
      QueuedCandidates[QueueIndex].BeforeSnapshot := EOT;
    end;

    function SelectBestUnused(RepresentativesOnly: Boolean): Integer;
    var
      K: Integer;
    begin
      Result := -1;
      for K := 0 to High(QueuedCandidates) do
      begin
        if CandidateUsed[K] or (QueuedCandidates[K].Root = EOT) then
          Continue;
        if RepresentativesOnly and (not IsRepresentative[K]) then
          Continue;
        if CandidateBetter(K, Result) then
          Result := K;
      end;
    end;
  begin
    SetLength(CandidateUsed, Length(QueuedCandidates));
    SetLength(IsRepresentative, Length(QueuedCandidates));
    for CandidateIndex := 0 to High(QueuedCandidates) do
    begin
      if QueuedCandidates[CandidateIndex].Root = EOT then
        Continue;
      IsRepresentative[CandidateIndex] := True;
      for OtherIndex := 0 to High(QueuedCandidates) do
        if (OtherIndex <> CandidateIndex) and
           (QueuedCandidates[OtherIndex].Root <> EOT) and
           SameBucket(CandidateIndex, OtherIndex) and
           CandidateBetter(OtherIndex, CandidateIndex) then
        begin
          IsRepresentative[CandidateIndex] := False;
          Break;
        end;
    end;

    while Length(NextStates) < BeamWidth do
    begin
      BestIndex := SelectBestUnused(True);
      if BestIndex < 0 then
        Break;
      CandidateUsed[BestIndex] := True;
      AdmitCandidate(BestIndex);
    end;

    while Length(NextStates) < BeamWidth do
    begin
      BestIndex := SelectBestUnused(False);
      if BestIndex < 0 then
        Break;
      CandidateUsed[BestIndex] := True;
      AdmitCandidate(BestIndex);
    end;

  end;

  procedure RecordBeamPrunedCandidates;
  var
    CandidateIndex: Integer;
  begin
    for CandidateIndex := 0 to High(QueuedCandidates) do
      if QueuedCandidates[CandidateIndex].Root <> EOT then
      begin
        RecordCandidateBeamPruned(
          QueuedCandidates[CandidateIndex].RuleName,
          QueuedCandidates[CandidateIndex].Direction
        );
        if UseCostPolicy then
          LogTraceEvent(
            Context,
            Format(
              'inference step=%d state=%d candidate pruned reason=beam score=%d policy=cost',
              [QueuedCandidates[CandidateIndex].Step,
               QueuedCandidates[CandidateIndex].ParentStateId,
               QueuedCandidates[CandidateIndex].PathCost]
            )
          );
      end;
  end;

  procedure RecordCandidatesAbandonedBySuccess;
  var
    CandidateIndex: Integer;
  begin
    if not Assigned(SearchStats) then
      Exit;
    for CandidateIndex := 0 to High(QueuedCandidates) do
      if QueuedCandidates[CandidateIndex].Root <> EOT then
        RecordCandidateAbandonedSuccess(
          QueuedCandidates[CandidateIndex].RuleName,
          QueuedCandidates[CandidateIndex].Direction
        );
  end;
begin
  Result := False;
  ResetSearchStats;
  if (not Assigned(Tree)) or (RulesRootIndex = EOT) or (SubjectIndex = EOT) then
    Exit(False);
  if MaxSteps < 0 then
    Exit(False);
  if BeamWidth < 1 then
    BeamWidth := 1;
  AnchorsPerRule := 1;
  SettingReadResult := ReadIntegerSetting(
    Tree,
    Context,
    [INFERENCE_ANCHORS_PER_RULE_SETTING],
    SettingValue,
    SettingSource
  );
  if SettingReadResult = srrFound then
  begin
    if SettingValue >= 1 then
      AnchorsPerRule := SettingValue
    else if Assigned(Context) and Context.EventEnabled(ellDiag) then
      Context.LogDiag(
        Format('invalid %s value %d (expected >= 1)', [SettingSource, SettingValue])
      );
  end;
  if (SettingReadResult = srrInvalid) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag(
      Format('invalid %s value (expected integer literal)', [INFERENCE_ANCHORS_PER_RULE_SETTING])
    );

  RuleRefs := nil;
  CollectRuleRefs(Tree, Context, RulesRootIndex, RuleRefs);
  if Length(RuleRefs) = 0 then
    Exit(False);
  PrepareCollectedRuleRefs(Tree, Context, RuleRefs);

  Visited := TStringList.Create;
  try
    Visited.Sorted := True;
    Visited.Duplicates := dupIgnore;

    SetLength(CurrentStates, 1);
    CurrentStates[0].Root := Tree.CloneSubtree(SubjectIndex);
    if MatchSubexpressions then
      CurrentStates[0].RemainingBudget := CongruenceBudget
    else
      CurrentStates[0].RemainingBudget := -1;
    CurrentStates[0].StateId := 0;
    CurrentStates[0].NodeCount := CountTreeNodes(CurrentStates[0].Root);
    CurrentStates[0].PathCost := 0;
    if Assigned(SearchStats) then
      SearchStats^.MaxRetainedFrontier := 1;
    NextStateId := 1;

    if CurrentStates[0].Root = EOT then
      Exit(False);
    if NodesStrictEqual(Tree, CurrentStates[0].Root, TargetIndex) then
      Exit(True);

    Key := StateKey(CurrentStates[0].Root);
    Visited.AddObject(Key, TObject(PtrInt(CurrentStates[0].RemainingBudget)));

    for Step := 1 to MaxSteps do
    begin
      SetLength(NextStates, 0);
      SetLength(QueuedCandidates, 0);
      for I := 0 to High(CurrentStates) do
      begin
        if Assigned(SearchStats) then
          Inc(SearchStats^.ExpandedStates);
        EmitDebuggerInferenceStateEvent(
          Tree,
          CurrentStates[I].Root,
          Step,
          CurrentStates[I].StateId,
          CurrentStates[I].RemainingBudget,
          True,
          Context
        );
        try
          LocalKeys := TStringList.Create;
          try
            for J := 0 to High(RuleRefs) do
            begin
              DirectionCount := RuleDirectionCount(
                Tree, EffectiveCollectedRuleIndex(RuleRefs[J])
              );
              for DirectionIndex := 0 to DirectionCount - 1 do
              begin
                Direction := rdForward;
                if DirectionIndex = 1 then
                  Direction := rdReverse;
                if not AllowsRuleDirection(RuleRefs[J], Direction) then
                  Continue;

                for MatchOrdinal := 1 to AnchorsPerRule do
                begin
                  RewrittenRoot := EOT;
                  RemainingBudget := CurrentStates[I].RemainingBudget;
                  LastRewriteRuleName := '';
                  if not TryRewriteNthMatchForRuleDirection(
                           CurrentStates[I].Root,
                           RemainingBudget,
                           EffectiveCollectedRuleIndex(RuleRefs[J]),
                           Direction,
                           MatchOrdinal,
                           RewrittenRoot,
                           RemainingBudget
                         ) then
                    Break;

                  LastRewriteRuleName := RuleRefs[J].RuleName;
                  CandidateNodeCount := CountTreeNodes(RewrittenRoot);
                  CandidateGrowth := CandidateNodeCount - CurrentStates[I].NodeCount;
                  if CandidateGrowth < 0 then
                    CandidateGrowth := 0;
                  CandidatePathCost := CurrentStates[I].PathCost + CandidateGrowth;
                  RecordCandidateGenerated(LastRewriteRuleName, LastRewriteDirection);

                  if LastRewriteRuleIndex <> EOT then
                    LogTraceEvent(
                      Context,
                      Format(
                        'inference step=%d state=%d candidate applied rule="%s" direction=%s',
                        [Step, CurrentStates[I].StateId, RuleTraceText(Tree, LastRewriteRuleIndex), RewriteDirectionName(LastRewriteDirection)]
                      )
                    );
                  if UseCostPolicy then
                    LogTraceEvent(
                      Context,
                      Format(
                        'inference step=%d state=%d candidate score=%d growth=%d nodes=%d policy=cost',
                        [Step, CurrentStates[I].StateId, CandidatePathCost,
                         CandidateGrowth, CandidateNodeCount]
                      )
                    );

                  EmitDebuggerInferenceCandidateEvent(
                    Tree,
                    RewrittenRoot,
                    Step,
                    CurrentStates[I].StateId,
                    LastRewriteRuleIndex,
                    LastRewriteRuleName,
                    LastRewriteDirection,
                    Context
                  );

                  BeforeSnapshot := EOT;
                  if Assigned(OnInferenceEvent) then
                    BeforeSnapshot := Tree.CloneSubtree(CurrentStates[I].Root);

                  if (RewrittenRoot <> EOT) and NodesStrictEqual(Tree, RewrittenRoot, TargetIndex) then
                  begin
                    UpdateQueueMaximum;
                    RecordCandidateAdmitted(LastRewriteRuleName, LastRewriteDirection);
                    CandidateStateId := NextStateId;
                    Inc(NextStateId);
                    EmitInferenceEvent(
                      Tree, OnInferenceEvent, InferenceEventUserData,
                      iekRewriteApplied, Step, CandidateStateId, CurrentStates[I].StateId,
                      LastRewriteRuleIndex, LastRewriteRuleName, LastRewriteDirection,
                      Ord(RuleRefs[J].Orientation <> iroDefault), BeforeSnapshot,
                      RewrittenRoot,
                      LastRewriteAnchorOrdinal
                    );
                    BeforeSnapshot := EOT;
                    if Assigned(OnInferenceEvent) then
                      RewrittenRoot := EOT
                    else
                      Tree.DeleteSubtree(EOT, RewrittenRoot);
                    LogTraceEvent(
                      Context,
                      Format(
                        'inference target reached at step=%d via state=%d',
                        [Step, CurrentStates[I].StateId]
                      )
                    );
                    EmitInferenceEvent(
                      Tree, OnInferenceEvent, InferenceEventUserData,
                      iekTargetReached, Step, CandidateStateId, CurrentStates[I].StateId,
                      LastRewriteRuleIndex, LastRewriteRuleName, LastRewriteDirection,
                      Ord(RuleRefs[J].Orientation <> iroDefault), EOT, EOT, -1
                    );
                    RecordCandidatesAbandonedBySuccess;
                    FreeStateRoots(CurrentStates);
                    FreeStateRoots(NextStates);
                    FreeQueuedCandidates(QueuedCandidates);
                    Exit(True);
                  end;

                  QueueCandidateWithLocalDedup(
                    LocalKeys,
                    RewrittenRoot,
                    RemainingBudget,
                    CurrentStates[I].StateId,
                    J,
                    LastRewriteRuleIndex,
                    LastRewriteRuleName,
                    LastRewriteDirection,
                    Ord(RuleRefs[J].Orientation <> iroDefault),
                    BeforeSnapshot,
                    LastRewriteAnchorOrdinal,
                    Step,
                    CandidateNodeCount,
                    CandidatePathCost
                  );
                  BeforeSnapshot := EOT;
                end;
              end;
            end;
          finally
            LocalKeys.Free;
          end;
        finally
          EmitDebuggerInferenceStateEvent(
            Tree,
            CurrentStates[I].Root,
            Step,
            CurrentStates[I].StateId,
            CurrentStates[I].RemainingBudget,
            False,
            Context
          );
        end;
      end;

      if UseCostPolicy then
        SelectNextStatesByCost
      else
        SelectNextStatesFromQueuedCandidates;
      RecordBeamPrunedCandidates;
      if Assigned(SearchStats) and
         (Length(NextStates) > SearchStats^.MaxRetainedFrontier) then
        SearchStats^.MaxRetainedFrontier := Length(NextStates);
      FreeQueuedCandidates(QueuedCandidates);
      SetLength(QueuedCandidates, 0);

      FreeStateRoots(CurrentStates);
      CurrentStates := nil;
      if Length(NextStates) = 0 then
      begin
        FreeStateRoots(NextStates);
        Exit(False);
      end;

      CurrentStates := Copy(NextStates);
      SetLength(NextStates, 0);
    end;
  finally
    FreeStateRoots(CurrentStates);
    FreeStateRoots(NextStates);
    FreeQueuedCandidates(QueuedCandidates);
    Visited.Free;
    ClearPreparedRuleRefs(Tree, RuleRefs);
  end;
end;

function RewriteOneByRules(
  Tree: TCustomTree;
  SubjectIndex: Integer;
  RulesRootIndex: Integer;
  Context: TContext;
  out RewrittenIndex: Integer;
  MatchSubexpressions: Boolean = False;
  AllowRootPrefixTail: Boolean = False;
  CongruenceBudget: PInteger = nil;
  SearchStartIndex: Integer = EOT
): Boolean;
var
  RuleNodes: TArrayOfInteger;
  RuleRefs: TArrayOfCollectedRuleRef;
  Candidates: TArrayOfRewriteCandidate;
  CandidateOrder: TArrayOfInteger;
  OrderedRuleNodes: TArrayOfInteger;
  TailPrev: Integer;
  RewrittenLast: Integer;

  function UsesRuleOrderedSearch: Boolean;
  begin
    Result := (MatcherSelectionStrategy = sskFirstRule) or
              (MatcherSelectionStrategy = sskRandomRule);
  end;

  procedure EnsureRuleNodes;
  var
    J: Integer;
  begin
    if Length(RuleNodes) > 0 then
      Exit;
    RuleRefs := nil;
    RuleNodes := nil;
    CollectRuleRefs(Tree, Context, RulesRootIndex, RuleRefs);
    SetLength(RuleNodes, Length(RuleRefs));
    for J := 0 to High(RuleRefs) do
    begin
      if IsFixedTransformationRule(Tree, RuleRefs[J].RuleIndex) or
         RuleRefs[J].ForceFixed then
      begin
        RuleRefs[J].PreparedRuleIndex := Tree.CloneSubtree(RuleRefs[J].RuleIndex);
        if RuleRefs[J].PreparedRuleIndex <> EOT then
        begin
          if RuleRefs[J].ForceFixed then
            Tree[RuleRefs[J].PreparedRuleIndex]^.Data :=
              Tree[RuleRefs[J].PreparedRuleIndex]^.Data or TK_FIXED;
          if Assigned(Context) then
            NormalizeTransformOperands(Tree, Context, RuleRefs[J].PreparedRuleIndex);
        end;
      end;
      RuleNodes[J] := EffectiveCollectedRuleIndex(RuleRefs[J]);
    end;
  end;

  procedure BuildCandidates;
  var
    J: Integer;
    RuleIndex: Integer;
  begin
    Candidates := nil;
    EnsureRuleNodes;
    for J := 0 to High(RuleNodes) do
    begin
      RuleIndex := RuleNodes[J];
      if (Tree[RuleIndex]^.Id = MID_OBJ_EQUIVALENCE) or
         (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) then
      begin
        AddRewriteCandidate(Candidates, RuleIndex, rdForward);
        AddRewriteCandidate(Candidates, RuleIndex, rdReverse);
      end
      else
        AddRewriteCandidate(Candidates, RuleIndex, rdForward);
    end;
  end;

  procedure BuildOrderedRuleNodes;
  var
    OrderStrategy: TSelectionStrategyKind;
  begin
    EnsureRuleNodes;
    OrderStrategy := sskFirst;
    if MatcherSelectionStrategy = sskRandomRule then
      OrderStrategy := sskRandom;
    BuildRuleSelectionOrder(RuleNodes, OrderStrategy, OrderedRuleNodes);
  end;

  procedure RefreshCandidateOrder;
  var
    J: Integer;
    BaseOrder: TArrayOfInteger;
  begin
    SetLength(BaseOrder, Length(Candidates));
    for J := 0 to High(BaseOrder) do
      BaseOrder[J] := J;
    BuildRuleSelectionOrder(BaseOrder, MatcherSelectionStrategy, CandidateOrder);
  end;

  function CountSequenceNodes(StartNode, StopTail: Integer): Integer; forward;

  function CountDetachedNode(NodeIndex: Integer): Integer;
  begin
    if NodeIndex = EOT then
      Exit(0);
    Result := 1 + CountSequenceNodes(Tree[NodeIndex]^.LHS, EOT);
  end;

  function CountSequenceNodes(StartNode, StopTail: Integer): Integer;
  var
    Cur: Integer;
  begin
    Result := 0;
    Cur := StartNode;
    while (Cur <> EOT) and (Cur <> StopTail) do
    begin
      Inc(Result, CountDetachedNode(Cur));
      Cur := Tree[Cur]^.RHS;
    end;
  end;

  function FindPreorderOrdinal(
    NodeIndex: Integer;
    TargetIndex: Integer;
    var Counter: Integer;
    out Ordinal: Integer
  ): Boolean;
  begin
    Result := False;
    while NodeIndex <> EOT do
    begin
      if NodeIndex = TargetIndex then
      begin
        Ordinal := Counter;
        Exit(True);
      end;
      Inc(Counter);
      if FindPreorderOrdinal(Tree[NodeIndex]^.LHS, TargetIndex, Counter, Ordinal) then
        Exit(True);
      NodeIndex := Tree[NodeIndex]^.RHS;
    end;
  end;

  function ComputeAnchorOrdinal(TargetIndex: Integer): Integer;
  var
    Counter: Integer;
    Ordinal: Integer;
  begin
    Result := -1;
    if (SubjectIndex = EOT) or (TargetIndex = EOT) then
      Exit;
    Counter := 0;
    Ordinal := -1;
    if FindPreorderOrdinal(SubjectIndex, TargetIndex, Counter, Ordinal) then
      Result := Ordinal;
  end;

  function FindSpanPrevInMatch(
    StartNode, StopTail, PrevForStart, TargetNode: Integer;
    out FoundPrev: Integer
  ): Boolean;
  var
    Cur: Integer;
    PrevInChain: Integer;
  begin
    Result := False;
    Cur := StartNode;
    PrevInChain := PrevForStart;
    while (Cur <> EOT) and (Cur <> StopTail) do
    begin
      if Cur = TargetNode then
      begin
        FoundPrev := PrevInChain;
        Exit(True);
      end;
      if FindSpanPrevInMatch(Tree[Cur]^.LHS, EOT, Cur, TargetNode, FoundPrev) then
        Exit(True);
      PrevInChain := Cur;
      Cur := Tree[Cur]^.RHS;
    end;
  end;

  function ReplaceSpan(
    SpanHead, SpanTail, SpanPrev, SpanRoot, Replacement: Integer;
    out NewRoot: Integer
  ): Boolean;
  var
    SpanLastLocal: Integer;
    RewrittenLastLocal: Integer;
  begin
    Result := False;
    NewRoot := SpanRoot;
    if SpanHead = EOT then
      Exit(False);

    if SpanTail <> EOT then
    begin
      SpanLastLocal := SpanHead;
      while (SpanLastLocal <> EOT) and (Tree[SpanLastLocal]^.RHS <> SpanTail) do
        SpanLastLocal := Tree[SpanLastLocal]^.RHS;
      if SpanLastLocal = EOT then
        Exit(False);
      Tree[SpanLastLocal]^.RHS := EOT;
    end;

    if Replacement = EOT then
      Replacement := SpanTail
    else if SpanTail <> EOT then
    begin
      RewrittenLastLocal := Tree.LastSibling[Replacement];
      Tree[RewrittenLastLocal]^.RHS := SpanTail;
    end;

    if SpanPrev = EOT then
      NewRoot := Replacement
    else if Tree[SpanPrev]^.LHS = SpanHead then
      Tree[SpanPrev]^.LHS := Replacement
    else if Tree[SpanPrev]^.RHS = SpanHead then
      Tree[SpanPrev]^.RHS := Replacement
    else
      Exit(False);

    Tree.DeleteSubtree(EOT, SpanHead);
    Result := True;
  end;

  function ApplyInPlaceRewriteAtNode(
    NodeIndex: Integer;
    PrevIndex: Integer;
    const Probe: TRewriteProbe;
    out RootIndex: Integer
  ): Boolean;
  var
    SpanPrev: Integer;
    ReplacementNode: Integer;
    AnchorOrdinal: Integer;
    InlineReplaceOnly: Boolean;
  begin
    Result := False;
    RootIndex := SubjectIndex;
    if not BuildRewriteFromProbe(Tree, Probe, Context, ReplacementNode) then
      Exit(False);

    InlineReplaceOnly := Tree[Probe.RuleIndex]^.Id = MID_OBJ_INLINE_TRANSFORMATION;
    AnchorOrdinal := ComputeAnchorOrdinal(Probe.TargetHead);
    if not FindSpanPrevInMatch(NodeIndex, Probe.MatchTail, PrevIndex, Probe.TargetHead, SpanPrev) then
      SpanPrev := PrevIndex;

    if InlineReplaceOnly then
    begin
      RootIndex := ReplacementNode;
      if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) then
        Dec(CongruenceBudget^);
      LastRewriteRuleIndex := Probe.RuleIndex;
      LastRewriteDirection := Ord(Probe.Direction);
      LastRewriteAnchorOrdinal := AnchorOrdinal;
      Tree.DeleteSubtree(EOT, SubjectIndex);
      Exit(True);
    end;

    if ReplaceSpan(
         Probe.TargetHead,
         Probe.TargetTail,
         SpanPrev,
         SubjectIndex,
         ReplacementNode,
         RootIndex
       ) then
    begin
      if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) then
        Dec(CongruenceBudget^);
      LastRewriteRuleIndex := Probe.RuleIndex;
      LastRewriteDirection := Ord(Probe.Direction);
      LastRewriteAnchorOrdinal := AnchorOrdinal;
      Exit(True);
    end;

    if ReplacementNode <> EOT then
      Tree.DeleteSubtree(EOT, ReplacementNode);
  end;

  function ApplyInPlaceDetachedRewriteAtNode(
    NodeIndex: Integer;
    PrevIndex: Integer;
    RewrittenNode: Integer;
    MatchTail: Integer;
    TargetHead: Integer;
    TargetTail: Integer;
    InlineReplaceOnly: Boolean;
    out RootIndex: Integer
  ): Boolean;
  var
    SpanPrev: Integer;
    ReplacementNode: Integer;
    AnchorOrdinal: Integer;
  begin
    Result := False;
    RootIndex := SubjectIndex;
    ReplacementNode := RewrittenNode;
    AnchorOrdinal := ComputeAnchorOrdinal(TargetHead);
    if not FindSpanPrevInMatch(NodeIndex, MatchTail, PrevIndex, TargetHead, SpanPrev) then
      SpanPrev := PrevIndex;

    if InlineReplaceOnly then
    begin
      RootIndex := ReplacementNode;
      if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) then
        Dec(CongruenceBudget^);
      LastRewriteAnchorOrdinal := AnchorOrdinal;
      Tree.DeleteSubtree(EOT, SubjectIndex);
      Exit(True);
    end;

    if ReplaceSpan(TargetHead, TargetTail, SpanPrev, SubjectIndex, ReplacementNode, RootIndex) then
    begin
      if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) then
        Dec(CongruenceBudget^);
      LastRewriteAnchorOrdinal := AnchorOrdinal;
      Exit(True);
    end;
  end;

  function SelectRuleOrderedCandidateAtRoot(
    AllowSubjectTail: Boolean;
    out SelectedCandidate: TRewriteCandidate;
    out SelectedRewritten: Integer;
    out SelectedMatchTail: Integer;
    out SelectedTargetHead: Integer;
    out SelectedTargetTail: Integer;
    out SelectedInlineReplaceOnly: Boolean
  ): Boolean;
  var
    RuleOrderIndex: Integer;
    DirectionIndex: Integer;
    DirectionCount: Integer;
    RuleIndex: Integer;
    Direction: TRewriteDirection;
  begin
    Result := False;
    SelectedCandidate.RuleIndex := EOT;
    SelectedCandidate.Direction := rdForward;
    SelectedRewritten := EOT;
    SelectedMatchTail := EOT;
    SelectedTargetHead := EOT;
    SelectedTargetTail := EOT;
    SelectedInlineReplaceOnly := False;

    BuildOrderedRuleNodes;
    for RuleOrderIndex := 0 to High(OrderedRuleNodes) do
    begin
      RuleIndex := OrderedRuleNodes[RuleOrderIndex];
      DirectionCount := 1;
      if (Tree[RuleIndex]^.Id = MID_OBJ_EQUIVALENCE) or
         (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) then
        DirectionCount := 2;

      for DirectionIndex := 0 to DirectionCount - 1 do
      begin
        Direction := rdForward;
        if DirectionIndex = 1 then
          Direction := rdReverse;

        if TryRewriteRule(
             Tree, RuleIndex, SubjectIndex, Context, SelectedRewritten,
             AllowSubjectTail, SelectedMatchTail, SelectedTargetHead,
             SelectedTargetTail, Direction
           ) then
        begin
          SelectedInlineReplaceOnly :=
            Tree[RuleIndex]^.Id = MID_OBJ_INLINE_TRANSFORMATION;
          SelectedCandidate.RuleIndex := RuleIndex;
          SelectedCandidate.Direction := Direction;
          LastRewriteRuleIndex := RuleIndex;
          LastRewriteDirection := Ord(Direction);
          Exit(True);
        end;
      end;
    end;
  end;

  function TryRewriteAtSingleRule(
    NodeIndex: Integer;
    PrevIndex: Integer;
    RuleIndex: Integer;
    out RootIndex: Integer
  ): Boolean;
  var
    Probe: TRewriteProbe;
    DirectionCount: Integer;
    DirectionIndex: Integer;
    Direction: TRewriteDirection;
    Child: Integer;
    Sibling: Integer;
  begin
    Result := False;
    RootIndex := SubjectIndex;
    if NodeIndex = EOT then
      Exit(False);
    if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) and
       (CongruenceBudget^ <= 0) then
      Exit(False);

    DirectionCount := 1;
    if (Tree[RuleIndex]^.Id = MID_OBJ_EQUIVALENCE) or
       (Tree[RuleIndex]^.Id = MID_OBJ_SUBST_EQUIVALENCE) then
      DirectionCount := 2;
    for DirectionIndex := 0 to DirectionCount - 1 do
    begin
      Direction := rdForward;
      if DirectionIndex = 1 then
        Direction := rdReverse;

      if TryProbeRuleMatch(
           Tree, RuleIndex, NodeIndex, Context, True, Direction, Probe
         ) then
      begin
        Exit(
          ApplyInPlaceRewriteAtNode(
            NodeIndex,
            PrevIndex,
            Probe,
            RootIndex
          )
        );
      end;
    end;

    Child := Tree[NodeIndex]^.LHS;
    if TryRewriteAtSingleRule(Child, NodeIndex, RuleIndex, RootIndex) then
      Exit(True);

    Sibling := Tree[NodeIndex]^.RHS;
    if TryRewriteAtSingleRule(Sibling, NodeIndex, RuleIndex, RootIndex) then
      Exit(True);
  end;

  function TryRewriteByRuleOrder(
    RewriteStart: Integer;
    RewritePrev: Integer;
    out NewRoot: Integer
  ): Boolean;
  var
    RuleOrderIndex: Integer;
  begin
    Result := False;
    NewRoot := SubjectIndex;
    BuildOrderedRuleNodes;
    for RuleOrderIndex := 0 to High(OrderedRuleNodes) do
      if TryRewriteAtSingleRule(
           RewriteStart, RewritePrev, OrderedRuleNodes[RuleOrderIndex], NewRoot
         ) then
        Exit(True);
  end;

  function SelectCandidate(
    NodeIndex: Integer;
    AllowSubjectTail: Boolean;
    out SelectedCandidate: TRewriteCandidate;
    out SelectedRewritten: Integer;
    out SelectedMatchTail: Integer;
    out SelectedTargetHead: Integer;
    out SelectedTargetTail: Integer;
    out SelectedInlineReplaceOnly: Boolean
  ): Boolean;
  var
    J: Integer;
    Candidate: TRewriteCandidate;
    RewrittenNode: Integer;
    MatchTail: Integer;
    TargetHead: Integer;
    TargetTail: Integer;
    InlineReplaceOnly: Boolean;
    UseExhaustive: Boolean;
    MatchCount: Integer;
    RemovedNodes: Integer;
    AddedNodes: Integer;
    Score: Integer;
    BestScore: Integer;
    BestFound: Boolean;
    procedure SetSelected(
      const ACandidate: TRewriteCandidate;
      ARewritten: Integer;
      AMatchTail: Integer;
      ATargetHead: Integer;
      ATargetTail: Integer;
      AInlineReplaceOnly: Boolean;
      DeletePrevious: Boolean
    );
    begin
      if DeletePrevious and (SelectedRewritten <> EOT) then
        Tree.DeleteSubtree(EOT, SelectedRewritten);

      SelectedCandidate := ACandidate;
      SelectedRewritten := ARewritten;
      SelectedMatchTail := AMatchTail;
      SelectedTargetHead := ATargetHead;
      SelectedTargetTail := ATargetTail;
      SelectedInlineReplaceOnly := AInlineReplaceOnly;
    end;
  begin
    Result := False;
    SelectedRewritten := EOT;
    SelectedMatchTail := EOT;
    SelectedTargetHead := EOT;
    SelectedTargetTail := EOT;
    SelectedInlineReplaceOnly := False;
    SelectedCandidate.RuleIndex := EOT;
    SelectedCandidate.Direction := rdForward;

    RefreshCandidateOrder;
    if MatcherSelectionStrategy <> sskShrink then
    begin
      UseExhaustive := MatcherExhaustiveSelection;
      MatchCount := 0;
      for J := 0 to High(CandidateOrder) do
      begin
        Candidate := Candidates[CandidateOrder[J]];
        if TryRewriteRule(
             Tree, Candidate.RuleIndex, NodeIndex, Context, RewrittenNode,
             AllowSubjectTail, MatchTail, TargetHead, TargetTail, Candidate.Direction
           ) then
        begin
          InlineReplaceOnly :=
            Tree[Candidate.RuleIndex]^.Id = MID_OBJ_INLINE_TRANSFORMATION;

          Inc(MatchCount);
          if MatchCount = 1 then
          begin
            SetSelected(
              Candidate,
              RewrittenNode,
              MatchTail,
              TargetHead,
              TargetTail,
              InlineReplaceOnly,
              False
            );
            if not UseExhaustive then
              Break;
            Continue;
          end;

          if MatcherSelectionStrategy = sskRandom then
          begin
            // Reservoir sampling: pick uniformly among all successful rewrites.
            if Random(MatchCount) = 0 then
              SetSelected(
                Candidate,
                RewrittenNode,
                MatchTail,
                TargetHead,
                TargetTail,
                InlineReplaceOnly,
                True
              )
            else if RewrittenNode <> EOT then
              Tree.DeleteSubtree(EOT, RewrittenNode);
          end
          else if RewrittenNode <> EOT then
            Tree.DeleteSubtree(EOT, RewrittenNode);
        end;
      end;

      if MatchCount = 0 then
        Exit(False);

      Result := True;
      LastRewriteRuleIndex := SelectedCandidate.RuleIndex;
      LastRewriteDirection := Ord(SelectedCandidate.Direction);
      Exit(True);
    end;

    BestFound := False;
    BestScore := Low(Integer);
    for J := 0 to High(CandidateOrder) do
    begin
      Candidate := Candidates[CandidateOrder[J]];
      if not TryRewriteRule(
               Tree, Candidate.RuleIndex, NodeIndex, Context, RewrittenNode,
               AllowSubjectTail, MatchTail, TargetHead, TargetTail, Candidate.Direction
             ) then
        Continue;

      InlineReplaceOnly := Tree[Candidate.RuleIndex]^.Id = MID_OBJ_INLINE_TRANSFORMATION;
      if InlineReplaceOnly then
        RemovedNodes := CountSequenceNodes(SubjectIndex, EOT)
      else
        RemovedNodes := CountSequenceNodes(TargetHead, TargetTail);

      if RewrittenNode = EOT then
        AddedNodes := 0
      else
        AddedNodes := CountSequenceNodes(RewrittenNode, EOT);

      Score := RemovedNodes - AddedNodes;
      if (not BestFound) or (Score > BestScore) then
      begin
        if BestFound and (SelectedRewritten <> EOT) then
          Tree.DeleteSubtree(EOT, SelectedRewritten);

        SelectedCandidate := Candidate;
        SelectedRewritten := RewrittenNode;
        SelectedMatchTail := MatchTail;
        SelectedTargetHead := TargetHead;
        SelectedTargetTail := TargetTail;
        SelectedInlineReplaceOnly := InlineReplaceOnly;
        BestScore := Score;
        BestFound := True;
      end
      else if RewrittenNode <> EOT then
        Tree.DeleteSubtree(EOT, RewrittenNode);
    end;

    if (not BestFound) or (BestScore <= 0) then
    begin
      if SelectedRewritten <> EOT then
        Tree.DeleteSubtree(EOT, SelectedRewritten);
      SelectedRewritten := EOT;
      SelectedMatchTail := EOT;
      SelectedTargetHead := EOT;
      SelectedTargetTail := EOT;
      SelectedInlineReplaceOnly := False;
      SelectedCandidate.RuleIndex := EOT;
      Exit(False);
    end;

    Result := True;
    LastRewriteRuleIndex := SelectedCandidate.RuleIndex;
    LastRewriteDirection := Ord(SelectedCandidate.Direction);
  end;

  function TryRewriteAt(NodeIndex, PrevIndex: Integer; out RootIndex: Integer): Boolean;
  var
    RewrittenNode: Integer;
    MatchTail, TargetHead, TargetTail: Integer;
    Child, Sibling: Integer;
    InlineReplaceOnly: Boolean;
    Candidate: TRewriteCandidate;
  begin
    Result := False;
    RootIndex := SubjectIndex;
    if NodeIndex = EOT then
      Exit(False);
    if (NodeIndex <> SubjectIndex) and Assigned(CongruenceBudget) and
       (CongruenceBudget^ <= 0) then
      Exit(False);

    if SelectCandidate(
         NodeIndex, True, Candidate, RewrittenNode, MatchTail,
         TargetHead, TargetTail, InlineReplaceOnly
       ) then
      Exit(
        ApplyInPlaceDetachedRewriteAtNode(
          NodeIndex,
          PrevIndex,
          RewrittenNode,
          MatchTail,
          TargetHead,
          TargetTail,
          InlineReplaceOnly,
          RootIndex
        )
      );

    Child := Tree[NodeIndex]^.LHS;
    if TryRewriteAt(Child, NodeIndex, RootIndex) then
      Exit(True);

    Sibling := Tree[NodeIndex]^.RHS;
    if TryRewriteAt(Sibling, NodeIndex, RootIndex) then
      Exit(True);
  end;

  function FindRewriteStart(
    NodeIndex, PrevIndex, TargetIndex: Integer;
    out FoundPrev: Integer
  ): Boolean;
  var
    Cur: Integer;
  begin
    Result := False;
    Cur := NodeIndex;
    while Cur <> EOT do
    begin
      if Cur = TargetIndex then
      begin
        FoundPrev := PrevIndex;
        Exit(True);
      end;
      if FindRewriteStart(Tree[Cur]^.LHS, Cur, TargetIndex, FoundPrev) then
        Exit(True);
      PrevIndex := Cur;
      Cur := Tree[Cur]^.RHS;
    end;
  end;

var
  NewRoot: Integer;
  Candidate: TRewriteCandidate;
  InlineReplaceOnly: Boolean;
  MatchTail, TargetHead, TargetTail: Integer;
  RewriteStart: Integer;
  RewritePrev: Integer;
  Cur: Integer;

  procedure MarkRewriteProgress;
  begin
    if Assigned(Context) then
      Context.MarkRewriteProgress;
  end;
begin
  Result := False;
  RewrittenIndex := EOT;
  LastRewriteRuleIndex := EOT;
  LastRewriteRuleName := '';
  LastRewriteDirection := 0;
  LastRewriteAnchorOrdinal := -1;
  if (not Assigned(Tree)) or (SubjectIndex = EOT) or (RulesRootIndex = EOT) then
    Exit;
  if MatchSubexpressions and (SearchStartIndex = EOT) then
    SearchStartIndex := ConsumeFirstCaretInSubtree(Tree, SubjectIndex);

  RuleNodes := nil;
  RuleRefs := nil;
  Candidates := nil;
  CandidateOrder := nil;
  OrderedRuleNodes := nil;

  try
    if UsesRuleOrderedSearch then
    begin
      EnsureRuleNodes;
      if Length(RuleNodes) = 0 then
        Exit(False);

      if MatchSubexpressions then
      begin
        RewriteStart := SubjectIndex;
        RewritePrev := EOT;
        if (SearchStartIndex <> EOT) and (SearchStartIndex <> SubjectIndex) then
        begin
          if FindRewriteStart(SubjectIndex, EOT, SearchStartIndex, RewritePrev) then
            RewriteStart := SearchStartIndex;
        end;

        if TryRewriteByRuleOrder(RewriteStart, RewritePrev, NewRoot) then
        begin
          RewrittenIndex := NewRoot;
          MarkRewriteProgress;
          Exit(True);
        end;
        Exit(False);
      end;

      if SelectRuleOrderedCandidateAtRoot(
           False, Candidate, RewrittenIndex, MatchTail,
           TargetHead, TargetTail, InlineReplaceOnly
         ) then
      begin
        LastRewriteAnchorOrdinal := ComputeAnchorOrdinal(TargetHead);
        MarkRewriteProgress;
        Exit(True);
      end;

      if not AllowRootPrefixTail then
        Exit(False);

      if not SelectRuleOrderedCandidateAtRoot(
               True, Candidate, RewrittenIndex, MatchTail,
               TargetHead, TargetTail, InlineReplaceOnly
             ) then
        Exit(False);

      LastRewriteAnchorOrdinal := ComputeAnchorOrdinal(TargetHead);

      if MatchTail <> EOT then
      begin
        TailPrev := SubjectIndex;
        while (TailPrev <> EOT) and (Tree[TailPrev]^.RHS <> MatchTail) do
          TailPrev := Tree[TailPrev]^.RHS;
        if TailPrev <> EOT then
          Tree[TailPrev]^.RHS := EOT;

        if RewrittenIndex = EOT then
          RewrittenIndex := MatchTail
        else
        begin
          RewrittenLast := Tree.LastSibling[RewrittenIndex];
          Tree[RewrittenLast]^.RHS := MatchTail;
        end;
      end;
      MarkRewriteProgress;
      Exit(True);
    end;

    BuildCandidates;
    if MatchSubexpressions then
    begin
      RewriteStart := SubjectIndex;
      RewritePrev := EOT;
      if (SearchStartIndex <> EOT) and (SearchStartIndex <> SubjectIndex) then
      begin
        if FindRewriteStart(SubjectIndex, EOT, SearchStartIndex, RewritePrev) then
          RewriteStart := SearchStartIndex;
      end;

      if TryRewriteAt(RewriteStart, RewritePrev, NewRoot) then
      begin
        RewrittenIndex := NewRoot;
        MarkRewriteProgress;
        Exit(True);
      end;
      Exit(False);
    end;

    if SelectCandidate(
         SubjectIndex, False, Candidate, RewrittenIndex, MatchTail,
         TargetHead, TargetTail, InlineReplaceOnly
       ) then
    begin
      LastRewriteAnchorOrdinal := ComputeAnchorOrdinal(TargetHead);
      MarkRewriteProgress;
      Exit(True);
    end;

    if not AllowRootPrefixTail then
      Exit(False);

    if not SelectCandidate(
             SubjectIndex, True, Candidate, RewrittenIndex, MatchTail,
             TargetHead, TargetTail, InlineReplaceOnly
           ) then
      Exit(False);

    LastRewriteAnchorOrdinal := ComputeAnchorOrdinal(TargetHead);

    if MatchTail <> EOT then
    begin
      TailPrev := SubjectIndex;
      while (TailPrev <> EOT) and (Tree[TailPrev]^.RHS <> MatchTail) do
        TailPrev := Tree[TailPrev]^.RHS;
      if TailPrev <> EOT then
        Tree[TailPrev]^.RHS := EOT;

      if RewrittenIndex = EOT then
        RewrittenIndex := MatchTail
      else
      begin
        RewrittenLast := Tree.LastSibling[RewrittenIndex];
        Tree[RewrittenLast]^.RHS := MatchTail;
      end;
    end;
    MarkRewriteProgress;
    Exit(True);
  finally
    ClearPreparedRuleRefs(Tree, RuleRefs);
  end;
end;

end.
