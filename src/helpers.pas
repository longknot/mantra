unit helpers;

{$I mantra.inc}

interface

uses
  exp_trees, context;

type
  TNodeMatchFunc = function(
    Tree: TCustomTree;
    Context: TContext;
    NodeIndex, NodePrev: Integer;
    UserData: Pointer
  ): Boolean;

  TVariableResolveMode = (
    vrmAuto,
    vrmDefault,
    vrmSelectionRulesTemplate,
    vrmAssignmentTarget,
    vrmNormalize
  );

function FindNodeWithPrev(
  Tree: TCustomTree;
  Context: TContext;
  RootIndex, PrevForRoot: Integer;
  Match: TNodeMatchFunc;
  UserData: Pointer;
  out FoundIndex, FoundPrev: Integer
): Boolean;

function FindResolvableVariableWithPrev(
  Tree: TCustomTree;
  Context: TContext;
  RootIndex, PrevForRoot: Integer;
  VariableObjectId: Integer;
  out FoundVariable, FoundPrev: Integer
): Boolean;

function FindSelectionWithPrev(Tree: TCustomTree; RootIndex, PrevForRoot: Integer;
  out FoundSelection, FoundPrev: Integer): Boolean;
function FindSelectionNode(Tree: TCustomTree; RootIndex: Integer): Integer;
function UsesStateSelectionMode(Tree: TCustomTree; RootIndex: Integer): Boolean;
procedure CleanupSelectionNode(Tree: TCustomTree; SelectionNodeIndex, SelectionNodePrev: Integer);
function ExpandStateSelection(
  Tree: TCustomTree;
  Context: TContext;
  Src, DstOp: Integer;
  IterLimit: Int64;
  CleanupAfter: Boolean = True
): Integer;
function GetVariableResolveMode(Tree: TCustomTree; VarIndex, VarPrev: Integer): TVariableResolveMode;
function ResolveVariableNode(
  Tree: TCustomTree;
  Context: TContext;
  VarIndex, VarPrev: Integer;
  Mode: TVariableResolveMode = vrmAuto
): Boolean;
function NormalizeResolvableVariables(
  Tree: TCustomTree;
  Context: TContext;
  RootIndex: Integer;
  RootPrev: Integer = EOT
): Boolean;
procedure NormalizeTransformOperands(
  Tree: TCustomTree;
  Context: TContext;
  TransformIndex: Integer
);
function ResolveDollarVariableChain(
  Tree: TCustomTree;
  Context: TContext;
  StartIndex: Integer;
  out ResolvedIndex: Integer;
  MaxDepth: Integer = 64
): Boolean;
function ResolveDollarVariableChainByName(
  Tree: TCustomTree;
  Context: TContext;
  const StartName: ansistring;
  out ResolvedIndex: Integer;
  MaxDepth: Integer = 64
): Boolean;

implementation

uses
  tokens, nodes;

const
  MAX_VARIABLE_SUBSTITUTION_DEPTH = 64;
  MAX_VARIABLE_NORMALIZATION_STEPS = 4096;

var
  VariableSubstitutionDepth: Integer = 0;

type
  PIntegerRef = ^Integer;

function FindNodeWithPrev(
  Tree: TCustomTree;
  Context: TContext;
  RootIndex, PrevForRoot: Integer;
  Match: TNodeMatchFunc;
  UserData: Pointer;
  out FoundIndex, FoundPrev: Integer
): Boolean;
var
  Child, Sibling: Integer;
begin
  Result := False;
  FoundIndex := EOT;
  FoundPrev := EOT;
  if (not Assigned(Tree)) or (RootIndex = EOT) or (not Assigned(Match)) then
    Exit;

  if Match(Tree, Context, RootIndex, PrevForRoot, UserData) then
  begin
    FoundIndex := RootIndex;
    FoundPrev := PrevForRoot;
    Exit(True);
  end;

  Child := Tree[RootIndex]^.LHS;
  if FindNodeWithPrev(
       Tree, Context, Child, RootIndex, Match, UserData, FoundIndex, FoundPrev
     ) then
    Exit(True);

  Sibling := Tree[RootIndex]^.RHS;
  if FindNodeWithPrev(
       Tree, Context, Sibling, PrevForRoot, Match, UserData, FoundIndex, FoundPrev
     ) then
    Exit(True);
end;

function IsResolvableVariableMatch(
  Tree: TCustomTree;
  Context: TContext;
  NodeIndex, NodePrev: Integer;
  UserData: Pointer
): Boolean;
var
  Name: ansistring;
  DummyRef: Integer;
  VariableObjectId: Integer;
begin
  Result := False;
  if (not Assigned(UserData)) or (not Assigned(Context)) then
    Exit;

  VariableObjectId := PIntegerRef(UserData)^;
  if Tree[NodeIndex]^.Id <> VariableObjectId then
    Exit;

  Name := Tree.Expression.TokenValue(Tree[NodeIndex]^.Ref);
  if Name = '' then
    Exit;

  Result := Context.TryFindVariable(Name, DummyRef);
end;

function FindResolvableVariableWithPrev(
  Tree: TCustomTree;
  Context: TContext;
  RootIndex, PrevForRoot: Integer;
  VariableObjectId: Integer;
  out FoundVariable, FoundPrev: Integer
): Boolean;
begin
  Result := FindNodeWithPrev(
    Tree, Context, RootIndex, PrevForRoot,
    @IsResolvableVariableMatch, @VariableObjectId,
    FoundVariable, FoundPrev
  );
end;

function IsSelectionNodeMatch(
  Tree: TCustomTree;
  Context: TContext;
  NodeIndex, NodePrev: Integer;
  UserData: Pointer
): Boolean;
begin
  Result := (Tree[NodeIndex]^.Id = nodes.OBJ_SELECTION) or
            (Tree[NodeIndex]^.Id = nodes.OBJ_INLINE_SELECTION);
end;

function FindSelectionWithPrev(Tree: TCustomTree; RootIndex, PrevForRoot: Integer;
  out FoundSelection, FoundPrev: Integer): Boolean;
begin
  Result := FindNodeWithPrev(
    Tree, nil, RootIndex, PrevForRoot,
    @IsSelectionNodeMatch, nil,
    FoundSelection, FoundPrev
  );
end;

function FindSelectionNode(Tree: TCustomTree; RootIndex: Integer): Integer;
var
  SelectionPrev: Integer;
begin
  if not FindSelectionWithPrev(Tree, RootIndex, EOT, Result, SelectionPrev) then
    Result := EOT;
end;

function UsesStateSelectionMode(Tree: TCustomTree; RootIndex: Integer): Boolean;
var
  Sel: Integer;
begin
  Sel := FindSelectionNode(Tree, RootIndex);
  Result := (Sel <> EOT) and ((Tree[Sel]^.Data and TK_DOLLAR) = TK_DOLLAR);
end;

procedure CleanupSelectionNode(Tree: TCustomTree; SelectionNodeIndex, SelectionNodePrev: Integer);
var
  LNode, RNode: Integer;
begin
  if SelectionNodeIndex = EOT then
    Exit;
  LNode := Tree[SelectionNodeIndex]^.LHS;
  RNode := Tree[SelectionNodeIndex]^.RHS;

  if RNode <> EOT then
    Tree.DeleteSubtree(SelectionNodeIndex, RNode);
  Tree[SelectionNodeIndex]^.RHS := EOT;

  if SelectionNodePrev = EOT then
    Tree.ExpandInline(SelectionNodePrev, SelectionNodeIndex)
  else if LNode <> EOT then
    Tree.Expand(SelectionNodePrev, SelectionNodeIndex)
  else
    Tree.Delete(SelectionNodePrev, SelectionNodeIndex);
end;

function ExpandStateSelection(
  Tree: TCustomTree;
  Context: TContext;
  Src, DstOp: Integer;
  IterLimit: Int64;
  CleanupAfter: Boolean = True
): Integer;
var
  Iter: Int64;
  SelectionIndex, SelectionPrev: Integer;
begin
  Result := Tree.CloneSubtree(Src);
  nodes.GetNode(Result).AppendOperator(DstOp);

  Iter := IterLimit;
  while Iter > 0 do
  begin
    if not FindSelectionWithPrev(Tree, Result, EOT, SelectionIndex, SelectionPrev) then
      Break;

    nodes.GetNode(SelectionIndex, SelectionPrev).Transform(Context);
    Dec(Iter);
  end;

  if CleanupAfter then
  begin
    if FindSelectionWithPrev(Tree, Result, EOT, SelectionIndex, SelectionPrev) then
      CleanupSelectionNode(Tree, SelectionIndex, SelectionPrev);
  end;

  nodes.GetNode(Result).Complete;
  nodes.GetNode(Result).AppendOperator(DstOp, True);
end;

function GetVariableResolveMode(Tree: TCustomTree; VarIndex, VarPrev: Integer): TVariableResolveMode;
var
  ParentObjectId: Integer;
begin
  Result := vrmDefault;
  if (not Assigned(Tree)) or (VarPrev = EOT) then
    Exit;

  ParentObjectId := Tree[VarPrev]^.Id;
  case ParentObjectId of
    nodes.OBJ_SELECTION, nodes.OBJ_INLINE_SELECTION, nodes.OBJ_INFERENCE:
      if Tree[VarPrev]^.RHS = VarIndex then
        Result := vrmSelectionRulesTemplate;
    nodes.OBJ_ASSIGNMENT:
      if Tree[VarPrev]^.LHS = VarIndex then
        Result := vrmAssignmentTarget;
  end;
end;

function ResolveVariableNode(
  Tree: TCustomTree;
  Context: TContext;
  VarIndex, VarPrev: Integer;
  Mode: TVariableResolveMode = vrmAuto
): Boolean;
var
  EffectiveMode: TVariableResolveMode;
  VariableNode: TBaseNode;
  Name: ansistring;
  ParentObjectId: Integer;
  SourceRef: Integer;
  SourceNode: TBaseNode;
  Dst: Integer;
  ResolvedNode: TBaseNode;
  SelectorBits: Integer;
  PreserveFixed: Boolean;
  PreserveCompute: Boolean;
begin
  Result := False;
  if (not Assigned(Tree)) or (not Assigned(Context)) or (VarIndex = EOT) then
    Exit;

  VariableNode := nodes.GetNode(VarIndex, VarPrev);
  if VariableNode.ObjectId <> nodes.OBJ_VARIABLE then
    Exit;

  if Mode = vrmAuto then
    EffectiveMode := GetVariableResolveMode(Tree, VarIndex, VarPrev)
  else
    EffectiveMode := Mode;
  if EffectiveMode = vrmAssignmentTarget then
    Exit(False);
  PreserveFixed := (Tree[VarIndex]^.Data and TK_FIXED) = TK_FIXED;
  PreserveCompute := (Tree[VarIndex]^.Data and TK_TILDE) = TK_TILDE;

  if VarPrev <> EOT then
    ParentObjectId := Tree[VarPrev]^.Id
  else
    ParentObjectId := EOT;

  Name := VariableNode.TokenValue;
  if (Name <> '') and Context.IsKeyword(Name) and
     (VariableNode.LHS = EOT) and
     (VariableNode.RHS = EOT) and
     ((Tree[VarIndex]^.Data and TK_SELECTOR_MASK) = 0) and
     (Tree[VarIndex]^.Op = 0) and
     (EffectiveMode <> vrmSelectionRulesTemplate) and
     (ParentObjectId <> nodes.OBJ_SELECTION) and
     (ParentObjectId <> nodes.OBJ_INLINE_SELECTION) then
    Exit;

  if not Context.TryFindVariable(Name, SourceRef) then
    Exit;

  if VariableSubstitutionDepth >= MAX_VARIABLE_SUBSTITUTION_DEPTH then
    Exit;

  SourceNode := nodes.GetNode(SourceRef);
  if (SourceNode.ObjectId = nodes.OBJ_VARIABLE) and
     (SourceNode.TokenValue = Name) and
     (SourceNode.LHS = EOT) and
     (SourceNode.RHS = EOT) then
    Exit;

  SelectorBits := Tree[VarIndex]^.Data and TK_SELECTOR_MASK;
  case SelectorBits of
    TK_SELECTOR_LHS:
      if Tree[SourceRef]^.LHS <> EOT then
        Dst := Tree.CloneSubtree(Tree[SourceRef]^.LHS)
      else
        Dst := EOT;
    TK_SELECTOR_RHS:
      if Tree[SourceRef]^.RHS <> EOT then
        Dst := Tree.CloneSubtree(Tree[SourceRef]^.RHS)
      else
        Dst := EOT;
  else
    Dst := Tree.CloneSubtree(SourceRef);
  end;

  if Dst = EOT then
    Exit;

  if Tree[VarIndex]^.Op <> 0 then
  begin
    if (SelectorBits = TK_SELECTOR_LHS) or
       (SelectorBits = TK_SELECTOR_RHS) or
       (SelectorBits = TK_SELECTOR_ALL) then
      nodes.GetNode(Dst).AppendOperator(Tree[VarIndex]^.Op, True)
    else
      nodes.GetNode(Dst).AppendOperator(Tree[VarIndex]^.Op);
  end;

  if PreserveFixed then
    Tree[Dst]^.Data := Tree[Dst]^.Data or TK_FIXED;
  if PreserveCompute then
    Tree[Dst]^.Data := Tree[Dst]^.Data or TK_TILDE;

  Tree[VarIndex]^.LHS := Dst;
  Tree.ExpandInline(VarPrev, VarIndex);
  Result := True;

  if EffectiveMode = vrmSelectionRulesTemplate then
    Exit;
  if (EffectiveMode = vrmNormalize) and (not PreserveCompute) then
    Exit;
  if PreserveFixed then
    Exit;

  Inc(VariableSubstitutionDepth);
  try
    ResolvedNode := nodes.GetNode(VarIndex, VarPrev);
    ResolvedNode.Evaluate(Context);
  finally
    Dec(VariableSubstitutionDepth);
  end;
end;

function NormalizeResolvableVariables(
  Tree: TCustomTree;
  Context: TContext;
  RootIndex: Integer;
  RootPrev: Integer = EOT
): Boolean;
var
  VariableIndex, VariablePrev: Integer;
  StepCount: Integer;
begin
  Result := False;
  if (not Assigned(Tree)) or (not Assigned(Context)) or (RootIndex = EOT) then
    Exit;

  StepCount := 0;
  while StepCount < MAX_VARIABLE_NORMALIZATION_STEPS do
  begin
    if not FindResolvableVariableWithPrev(
             Tree, Context, RootIndex, RootPrev,
             nodes.OBJ_VARIABLE, VariableIndex, VariablePrev
           ) then
      Break;

    if not ResolveVariableNode(Tree, Context, VariableIndex, VariablePrev, vrmNormalize) then
      Break;

    Result := True;
    Inc(StepCount);
  end;
end;

procedure NormalizeTransformOperands(
  Tree: TCustomTree;
  Context: TContext;
  TransformIndex: Integer
);
var
  SubjectIndex: Integer;
  TargetIndex: Integer;
begin
  if (not Assigned(Tree)) or (not Assigned(Context)) or
     (TransformIndex = EOT) then
    Exit;

  SubjectIndex := Tree[TransformIndex]^.LHS;
  TargetIndex := Tree[TransformIndex]^.RHS;
  if SubjectIndex <> EOT then
    NormalizeResolvableVariables(Tree, Context, SubjectIndex, TransformIndex);
  if TargetIndex <> EOT then
    NormalizeResolvableVariables(Tree, Context, TargetIndex, TransformIndex);
end;

function ResolveDollarVariableChainByName(
  Tree: TCustomTree;
  Context: TContext;
  const StartName: ansistring;
  out ResolvedIndex: Integer;
  MaxDepth: Integer = 64
): Boolean;
var
  CurrentName: ansistring;
  NextName: ansistring;
  CurrentIndex: Integer;
  Depth: Integer;
begin
  ResolvedIndex := EOT;
  Result := False;
  if (not Assigned(Tree)) or (not Assigned(Context)) then
    Exit;

  CurrentName := StartName;
  if CurrentName = '' then
    Exit;

  if MaxDepth < 1 then
    MaxDepth := 1;

  Depth := 0;
  while Depth < MaxDepth do
  begin
    if not Context.TryFindVariable(CurrentName, CurrentIndex) then
      Break;
    if CurrentIndex = EOT then
      Break;

    ResolvedIndex := CurrentIndex;
    Result := True;

    if Tree[CurrentIndex]^.Id <> nodes.OBJ_VARIABLE then
      Break;

    NextName := Tree.Expression.TokenValue(Tree[CurrentIndex]^.Ref);
    if (NextName = '') or (NextName = CurrentName) then
      Break;

    CurrentName := NextName;
    Inc(Depth);
  end;
end;

function ResolveDollarVariableChain(
  Tree: TCustomTree;
  Context: TContext;
  StartIndex: Integer;
  out ResolvedIndex: Integer;
  MaxDepth: Integer = 64
): Boolean;
var
  StartName: ansistring;
begin
  ResolvedIndex := StartIndex;
  Result := False;
  if (not Assigned(Tree)) or (not Assigned(Context)) or (StartIndex = EOT) then
    Exit;
  if Tree[StartIndex]^.Id <> nodes.OBJ_VARIABLE then
    Exit;
  if (Tree[StartIndex]^.Data and TK_DOLLAR) <> TK_DOLLAR then
    Exit;

  StartName := Tree.Expression.TokenValue(Tree[StartIndex]^.Ref);
  if StartName = '' then
    Exit;

  Result := ResolveDollarVariableChainByName(
    Tree, Context, StartName, ResolvedIndex, MaxDepth
  );
end;

end.
