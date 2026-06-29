unit nodes;

{$I mantra.inc}

interface

uses
  exp_trees, context, tokens, sysutils, formatters, compute, native_functions;

const
  OBJ_CATEGORY_MASK = $C0;
  OBJ_CUSTOM_NODE = 0;
  OBJ_BASE_NODE   = 1;
  OBJ_STATEMENT   = 2;

  // IDENTIFIER : $20
  OBJ_IDENTIFIER = TK_IDENTIFIER;
  OBJ_VARIABLE   = OBJ_IDENTIFIER + 1;
  OBJ_STRING     = OBJ_IDENTIFIER + 3;
  OBJ_INTEGER    = OBJ_IDENTIFIER + 4;
  OBJ_FLOAT      = OBJ_IDENTIFIER + 6;
  OBJ_COMPLEX    = OBJ_IDENTIFIER + 7;
  OBJ_SELECTION_POLICY = OBJ_IDENTIFIER + 12;
  OBJ_EXEC       = OBJ_IDENTIFIER + 13;
  OBJ_DEFINE     = OBJ_IDENTIFIER + 14;
  OBJ_PACKAGE    = OBJ_IDENTIFIER + 16;
  OBJ_IMPORT     = OBJ_IDENTIFIER + 17;
  OBJ_INCLUDE    = OBJ_IDENTIFIER + 18;
  OBJ_OUTPUT     = OBJ_IDENTIFIER + 19;
  OBJ_EXPLODE    = OBJ_IDENTIFIER + 20;
  OBJ_IMPLODE    = OBJ_IDENTIFIER + 21;
  OBJ_TREE_OUTPUT = OBJ_IDENTIFIER + 22;
  OBJ_CALLABLE   = OBJ_IDENTIFIER + 23;
  OBJ_IR_OUTPUT  = OBJ_IDENTIFIER + 24;
  OBJ_PATTERN    = OBJ_IDENTIFIER + 25;
  OBJ_QUERY_KEYS = OBJ_IDENTIFIER + 27;
  OBJ_QUERY_VALUES = OBJ_IDENTIFIER + 28;
  OBJ_NULL       = OBJ_IDENTIFIER + 29;
  OBJ_JSON_LOAD  = OBJ_IDENTIFIER + 30;
  OBJ_SYSTEM     = OBJ_IDENTIFIER + 31;
  OBJ_ASSIGN_PATH = OBJ_IDENTIFIER + 32;
  OBJ_QUERY_CHILDREN = OBJ_IDENTIFIER + 33;
  OBJ_GET        = OBJ_IDENTIFIER + 34;
  OBJ_YAML_LOAD  = OBJ_IDENTIFIER + 35;
  OBJ_PATH_SEGMENT = OBJ_IDENTIFIER + 36;
  OBJ_MAKE_PAIR  = OBJ_IDENTIFIER + 37;
  OBJ_FMT        = OBJ_IDENTIFIER + 38;
  OBJ_PRINTF     = OBJ_IDENTIFIER + 39;
  OBJ_RENDER     = OBJ_IDENTIFIER + 40;
  OBJ_GLOBAL     = OBJ_IDENTIFIER + 41;
  OBJ_ALIAS      = OBJ_IDENTIFIER + 42;
  OBJ_RULE_FORWARD = OBJ_IDENTIFIER + 44;
  OBJ_RULE_REVERSE = OBJ_IDENTIFIER + 45;
  OBJ_JSON_ENCODE = OBJ_IDENTIFIER + 46;
  OBJ_DISPLAY = OBJ_IDENTIFIER + 50;
  OBJ_JSON_SAVE = OBJ_IDENTIFIER + 51;

  // SPECIAL : $40
  OBJ_SPECIAL    = TK_SPECIAL;
  OBJ_RANGE      = OBJ_SPECIAL + 1;  // TK_DOUBLEDOT (..)
  OBJ_RECURSE    = OBJ_SPECIAL + 2;  // TK_TRIPLEDOT (...)
  OBJ_REPEAT     = OBJ_SPECIAL + 3;  // TK_COLON (:)
  OBJ_SEPARATOR  = OBJ_SPECIAL + 4;  // TK_COMMA (,)
  OBJ_ASSIGNMENT = OBJ_SPECIAL + 28;  // TK_ASSIGNMENT (:=)
  OBJ_DEEP_ASSIGNMENT = OBJ_SPECIAL + 30; // TK_DEEP_ASSIGN (:=, >:=, <:=, !:=)
  OBJ_SELECTION  = OBJ_SPECIAL + 8;  // TK_QUESTION = TK_SELECTION (?)
  OBJ_INLINE_SELECTION = OBJ_SPECIAL + 9; // TK_INLINE_SELECTION (:=?)
  OBJ_TRANSFORMATION = OBJ_SPECIAL + 12; // TK_IMPLIES = TK_TRANSFORM (=>)
  OBJ_INLINE_TRANSFORMATION = OBJ_SPECIAL + 13; // TK_INLINE_TRANSFORM (=>>)
  OBJ_SUBST_TRANSFORM = OBJ_SPECIAL + 14; // TK_SUBST_TRANSFORM (==>)
  OBJ_SYMBOL_SUBST_TRANSFORM = OBJ_SPECIAL + 15; // TK_SYMBOL_SUBST_TRANSFORM (==>>)
  OBJ_EQUIVALENCE = OBJ_SPECIAL + 16; // TK_EQUIVALENCE (<=>)
  OBJ_SUBST_EQUIVALENCE = OBJ_SPECIAL + 17; // TK_SUBST_EQUIVALENCE (<==>)
  OBJ_FALLBACK = OBJ_SPECIAL + 11; // TK_FALLBACK (??)

  // @todo -- map to tokens
  OBJ_PIPE        = OBJ_SPECIAL + 5;
  OBJ_RULE        = OBJ_SPECIAL + 25;
  OBJ_MATCH_ANY   = OBJ_SPECIAL + 21; // TK_MATCH_ANY (--)
  OBJ_CONCATENATE = OBJ_SPECIAL + 23; // TK_AMPERSAND (&)
  OBJ_STAGED_REPEAT = OBJ_SPECIAL + 24; // TK_ITERATOR (::)
  OBJ_INFERENCE   = OBJ_SPECIAL + 27; // TK_INFERENCE (|=)
  OBJ_INFERENCE_WITNESS = OBJ_SPECIAL + 29; // TK_INFERENCE_WITNESS (?|=)
  OBJ_ITERATOR_BIND = OBJ_SPECIAL + 31; // repeat-driver iterator binder (@)
  OBJ_VARIABLE_SUBTREE = OBJ_SPECIAL + 34; // TK_VARIABLE_SUBTREE_ARROW (->)
  OBJ_INDEX_LOOKUP = OBJ_SPECIAL + 35; // positional lookup (@)
  OBJ_STEPPED_RANGE = OBJ_SPECIAL + 36; // contextual: start .. end by step

  // SCOPE : $80
  OBJ_SCOPE      = TK_SCOPE;
  OBJ_EXPRESSION = TK_PARENTHESIS_BEGIN;
  OBJ_ARRAY      = TK_BRACKET_BEGIN;
  OBJ_EVALUATION = TK_CURLY_BEGIN;
  OBJ_COMPUTE    = TK_SCOPE_BEGIN_END;
  OBJ_SCOPE_FRAME = TK_SCOPE_FRAME;

type
  TValueRef = Integer;

type
  PAbstractNode = ^TAbstractNode;
  TAbstractNode = packed object
    function GetVMT: Pointer;
    procedure SetVMT(Value: Pointer);
    property VMT: Pointer read GetVMT write SetVMT;
    constructor Initialize;
  end;

  { TCustomNode }
  PCustomNode = ^TCustomNode;
  TCustomNode = packed object(TAbstractNode)
    Index: Integer; // index in tree
    PrevIndex: Integer;
    Extra: Integer;

    function ObjectId: Integer; static;
    function GetTreeNode: PTreeNode;
    property TreeNode: PTreeNode read GetTreeNode;

    constructor Initialize(Flags: Integer);

    // VMT manipulation.
    function RealVMT: Pointer; static;

    // Helper to get global tree instance.
    function GetTree: TCustomTree;

    // From tree node (note: parent = prev, child = lhs, next = rhs):
    function LHS: Integer;
    function RHS: Integer;
    //function Parent: Integer;
    // function Prev: Integer;

    // N: token = child for value nodes.
    function GetToken: Integer;
    function GetTokenId: Integer;
    function GetTokenKey: Integer;

    procedure SetToken(Value: Integer);
    procedure SetTokenId(Value: Integer);

    property TokenId: Integer read GetTokenId write SetTokenId;
    property Token: Integer read GetToken write SetToken;
    property TokenKey: Integer read GetTokenKey;
  end;

  // PCustomNodeRec = ^TCustomNodeRec;
  // TCustomNodeRec = packed record
  //   VMT: Pointer;
  //   Index: Integer;
  //   Extra: Integer;
  // end;

  { TBaseNode }
  PBaseNode = ^TBaseNode;
  TBaseNode = packed object(TCustomNode)
    // function GetTreeNode: PTreeNode; virtual;
    // property TreeNode: PTreeNode read GetTreeNode;
    procedure InitTreeNode(AIndex: Integer; AToken: Integer = 0); static;

    function Child: TBaseNode;
    function Prev: TBaseNode;
    function Next: TBaseNode;

    function GetNode(AIndex: Integer): TBaseNode;

    // non-virtual trampolines:
    procedure DispatchExecute(Context: TContext);
    procedure DispatchEvaluate(Context: TContext);
    procedure DispatchCompute(Context: TContext);
    procedure DispatchExpand(Context: TContext);
    procedure DispatchTransform(Context: TContext);

    // virtual methods
    procedure Dispatch(Proc: Pointer; Context: TContext); virtual;
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
    procedure DoEvaluate(Context: TContext); virtual;
    procedure Compute(Context: TContext); virtual;
    procedure Expand(Context: TContext); virtual;

    // tree manipulation
    procedure AppendOperator(DstOp: Integer; IncludeNext: Boolean = False);
    // N: adds recurse node to the tail of the current node
    procedure FixRecursion;
    procedure Transform(Context: TContext); virtual;

    function TransformPartial(Depth: Integer): Integer;

    procedure ClearRewrite; virtual;
    procedure ClearEvaluation; virtual;
    procedure ClearEmptyScopes; virtual;
    procedure Clear(AToken, Mask: Integer); virtual;
    procedure Complete; virtual;

    // auxiliary methods
    procedure Delete;
    function WrapNode: Integer;

    // Debugging
    function AsString: ansistring; virtual; overload;
    function AsString(var Config: TFormatConfig): ansistring; virtual; overload;

    function GetFormatter: TCustomFormatter; virtual;

    function Formatted: ansistring; virtual; overload;
    //function TreeFormatted: ansistring; virtual;
    function Formatted(Formatter: TCustomFormatter): ansistring; virtual; overload;

    function TokenValue: ansistring; virtual; overload;
    function TokenValue(var Config: TFormatConfig): ansistring; virtual; overload;
    function ElementValue: ansistring; virtual; overload;
    function ElementValue(var Config: TFormatConfig): ansistring; virtual; overload;
    function GetOperator: ansistring;
    procedure IncludeOperator(var Value: ansistring);
    function TreeValue: ansistring; virtual; overload;
    function TreeValue(var Config: TFormatConfig): ansistring; virtual; overload;

    function FindObject(Id: Integer): Integer;

    // Helper function to get custom node from tree.
    property Node[AIndex: Integer]: TBaseNode read GetNode;
  end;

  { TEndOfTreeNode }
  TEndOfTreeNode = packed object(TBaseNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
    //function Compute: TValueRef; virtual;
    procedure Compute(Context: TContext); virtual;
  end;


  { SCOPES }

  { TScopeNode }
  TScopeNode = packed object(TBaseNode)
    procedure Compute(Context: TContext); virtual;
    function TokenValue(var Config: TFormatConfig): ansistring; virtual; overload;
  end;

  { TExpressionNode : () }
  TExpressionNode = packed object(TScopeNode)
  end;

  { TArrayNode : [] }
  TArrayNode = packed object(TScopeNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TEvaluationNode }
  TEvaluationNode = packed object(TScopeNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TComputeNode : `` }
  TComputeNode = packed object(TEvaluationNode)
    //procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;


  { IDENTIFIERS }

  { TIdentifierNode }
  TIdentifierNode = packed object(TBaseNode)
  end;

  { TValueNode }
  TValueNode = packed object(TIdentifierNode)
    procedure GetValue(out Value); virtual; abstract;
  end;

  { TFixedNode }
  TFixedNode = packed object(TIdentifierNode)  // Q: use only META_FIXED flag?
  end;

  { TNumericalNode }
  TNumericalNode = packed object(TValueNode)
    function GetArithmeticOps: PArithmeticOps; virtual; abstract;
    function GetRelationalOps: PRelationalOps; virtual; abstract;
    function AppendValueToExpression(const Value): Integer; virtual; abstract;

    procedure Recurse(Context: TContext; NextIndex: Integer); virtual;
    function IsNumericNodeForCompute(NodeIndex: Integer): Boolean; virtual; abstract;
    procedure ApplyUnaryAndStoreSelf; virtual; abstract;
    function TryCombineSiblingAndStore(SiblingIndex: Integer): Boolean; virtual;
    function TryComputeAdditiveBuckets(Context: TContext): Boolean;
    procedure StoreAccumulator(const Op: Integer; var AValue);
  end;

  { TIntegerNode }
  TIntegerNode = packed object(TNumericalNode)
    function GetArithmeticOps: PArithmeticOps; virtual;
    function GetRelationalOps: PRelationalOps; virtual;
    function AppendValueToExpression(const Value): Integer; virtual;

    procedure GetValue(out Value); virtual;
    function NodeNumericValue(NodeIndex: Integer): Int64;
    function IsNumericNodeForCompute(NodeIndex: Integer): Boolean; virtual;
    procedure ApplyUnaryAndStoreSelf; virtual;
    //function TryCombineSiblingAndStore(SiblingIndex: Integer): Boolean; virtual;
    procedure Compute(Context: TContext); virtual;
    procedure Expand(Context: TContext); virtual;
  end;

  { TFloatNode }
  TFloatNode = packed object(TNumericalNode)
    function GetArithmeticOps: PArithmeticOps; virtual;
    function GetRelationalOps: PRelationalOps; virtual;
    function AppendValueToExpression(const Value): Integer; virtual;

    procedure GetValue(out Value); virtual;
    function NodeNumericValue(NodeIndex: Integer): Double;
    function IsNumericNodeForCompute(NodeIndex: Integer): Boolean; virtual;
    procedure StoreAccumulator(const Op: Integer; const AValue: Double);
    procedure ApplyUnaryAndStoreSelf; virtual;
    //function TryCombineSiblingAndStore(SiblingIndex: Integer): Boolean; virtual;
    procedure Compute(Context: TContext); virtual;
  end;

  { TComplexNode }
  TComplexNode = packed object(TFloatNode)
  end;

  { TStringNode }
  TStringNode = packed object(TIdentifierNode)
  end;

  { TVariableNode }
  TVariableNode = packed object(TIdentifierNode)
    function TryResolveDollarReference(Context: TContext; out ResolvedIndex: Integer): Boolean;
    procedure Expand(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
    procedure Compute(Context: TContext); virtual;
  end;

  { TSelectionPolicyNode [ selector ] }
  TSelectionPolicyNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TForwardRuleNode [ forward ] }
  TForwardRuleNode = packed object(TIdentifierNode)
  end;

  { TReverseRuleNode [ reverse ] }
  TReverseRuleNode = packed object(TIdentifierNode)
  end;

  { TPackageNode [ package ] }
  TPackageNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TImportNode [ import ] }
  TImportNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TIncludeNode [ include ] }
  TIncludeNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TGlobalNode [ global ] }
  TGlobalNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TScopeFrameNode [ scope ] }
  TScopeFrameNode = packed object(TIdentifierNode)
    function TryResolveBodyAndLabel(
      out BodyIndex: Integer;
      out LabelText: ansistring
    ): Boolean;
    procedure RunScopedBody(Context: TContext; EvaluateLast: Boolean);
    procedure CleanupLabelNode;
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TAliasNode [ alias ] }
  TAliasNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TPatternNode }
  TPatternNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TQueryKeysNode [ query_keys ] }
  TQueryKeysNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TQueryValuesNode [ query_values ] }
  TQueryValuesNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TQueryChildrenNode [ query_children ] }
  TQueryChildrenNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TGetNode [ get ] }
  TGetNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TPathSegmentNode [ path_segment ] }
  TPathSegmentNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TMakePairNode [ make_pair ] }
  TMakePairNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TFmtNode [ fmt ] }
  TFmtNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TRenderNode [ render ] }
  TRenderNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TJsonLoadNode [ json_load ] }
  TJsonLoadNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TJsonEncodeNode [ json_encode ] }
  TJsonEncodeNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TJsonSaveNode [ json_save ] }
  TJsonSaveNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TDisplayNode [ display ] }
  TDisplayNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TYamlLoadNode [ yaml_load ] }
  TYamlLoadNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TSystemNode [ system ] }
  TSystemNode = packed object(TIdentifierNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TAssignPathNode [ assign_path ] }
  TAssignPathNode = packed object(TIdentifierNode)
    procedure ApplyAssignPath(Context: TContext; EvaluateInputs: Boolean);
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TExecNode [ exec ] }
  TExecNode = packed object(TIdentifierNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { SPECIAL OPERATORS }

  { TSpecialNode }
  TSpecialNode = packed object(TBaseNode)
    function TokenValue(var Config: TFormatConfig): ansistring; virtual;
    function TreeValue(var Config: TFormatConfig): ansistring; virtual;
  end;

  { TOutputNode }
  TOutputNode = packed object(TBaseNode)
    procedure Execute(Context: TContext); virtual;
  end;

  { TPrintfNode [ printf ] }
  TPrintfNode = packed object(TOutputNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
    procedure Compute(Context: TContext); virtual;
  end;

  { TTreeOutputNode }
  TTreeOutputNode = packed object(TOutputNode)
    function GetFormatter: TCustomFormatter; virtual;
  end;

  { TIROutputNode }
  TIROutputNode = packed object(TOutputNode)
    procedure Execute(Context: TContext); virtual;
    function GetFormatter: TCustomFormatter; virtual;
  end;

  { TExplodeNode [ explode ] }
  TExplodeNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TImplodeNode [ implode ] }
  TImplodeNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TAssignmentNode [ := ] }
  TAssignmentNode = packed object(TSpecialNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TDeepAssignmentNode [ :=, >:=, <:=, !:= ] }
  TDeepAssignmentNode = packed object(TSpecialNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TRepeatNode [ : ] }
  // Q: TExpansionNode ?
  TRepeatNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
    procedure Transform(Context: TContext); virtual;
  end;

  { TStagedRepeatNode [ :: ] }
  TStagedRepeatNode = packed object(TRepeatNode)
    procedure Evaluate(Context: TContext); virtual;
    procedure Transform(Context: TContext); virtual;
  end;

  { TRecurseNode [ ... ] }
  TRecurseNode = packed object(TBaseNode)
    procedure Expand(Context: TContext); virtual;
    procedure Transform(Context: TContext); virtual;
  end;

  { TIteratorBindingNode [ @ ] }
  TIteratorBindingNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
    procedure Expand(Context: TContext); virtual;
  end;

  { TIndexLookupNode [ @ ] }
  TIndexLookupNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TSelectionNode [ ? ] }
  TSelectionNode = packed object(TSpecialNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
    procedure Transform(Context: TContext); virtual;
  end;

  { TInlineSelectionNode [ :=? ] }
  TInlineSelectionNode = packed object(TSelectionNode)
  end;

  { TFallbackNode [ ?? ] }
  TFallbackNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TTransformationNode [ => ] }
  TTransformationNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TEquivalenceNode [ <=> ] }
  TEquivalenceNode = packed object(TTransformationNode)
  end;

  { TInlineTransformationNode [ :=> ] }
  TInlineTransformationNode = packed object(TTransformationNode)
  end;

  { TSubstitutionNode [ ==>> ] }
  TSubstitutionNode = packed object(TTransformationNode)
  end;

  { TSymbolSubstitutionNode [ ==> ] }
  TSymbolSubstitutionNode = packed object(TTransformationNode)
  end;

  { TEquivalenceSubstitutionNode [ <==> ] }
  TEquivalenceSubstitutionNode = packed object(TTransformationNode)
  end;

  { TPipeNode [ | ] }
  TPipeNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TDefineNode [ define ] }
  TDefineNode = packed object(TSpecialNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TCallableNode [ callable ] }
  TCallableNode = packed object(TSpecialNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TRuleNode [ rule ] }
  TRuleNode = packed object(TSpecialNode)
    procedure Execute(Context: TContext); virtual;
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TPermuteDimensionNode [ # ] }
  TPermuteDimensionsNode = packed object(TSpecialNode)
  end;

  { TSeparatorNode [ , ] }
  TSeparatorNode = packed object(TSpecialNode)
  end;

  { TVariableSubtreeNode [ -> ] }
  TVariableSubtreeNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
    function TokenValue(var Config: TFormatConfig): ansistring; virtual; overload;
    function TreeValue(var Config: TFormatConfig): ansistring; virtual; overload;
  end;

  { TRangeNode [ .. ] }
  TRangeNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
    procedure Expand(Context: TContext); virtual;
  end;

  { TSteppedRangeNode [ range by step ] }
  TSteppedRangeNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
    procedure Expand(Context: TContext); virtual;
  end;

  { TConcatenateNode [ & ] }
  TConcatenateNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TMatchAnyNode [ -- ] }
  TMatchAnyNode = packed object(TSpecialNode)
  end;

  { TInferenceNode [ |= ] }
  TInferenceNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;

  { TInferenceWitnessNode [ ?|= ] }
  TInferenceWitnessNode = packed object(TSpecialNode)
    procedure Evaluate(Context: TContext); virtual;
  end;


  { STATEMENTS }

  { TStatementNode [ ; ] }
  TStatementNode = packed object(TBaseNode)
   procedure Execute(Context: TContext); virtual;
   function TokenValue(var Config: TFormatConfig): ansistring; virtual; overload;
  end;

var
  VMT_TABLE: array [Byte] of Pointer;
  HeadInvocationDispatchEnabled: Boolean = False;
  EvaluationExecutionDepth: Integer = 0;
  HeadDispatchDepth: Integer = 0;
  InferenceRewriteMaxSteps: Integer = 1;
  InferenceCongruenceBudget: Integer = -1;
  InferenceBeamWidth: Integer = 1;

// Nodes
function GetNode(Index: Integer; PrevIndex: Integer = EOT): TBaseNode;
//function GetRefValue(Ref: Integer): TRefValue;

procedure RegisterObjects;

implementation

uses
  classes, math, baseunix, fpjson, jsonparser,
  fpyaml.data, fpyaml.parser, fpyaml.json,
  parsetree, mathparser, matcher_ir,
  selection_strategies, helpers, module_loader, string_utils, inference,
  runtime_settings, system_commands, value_node_helpers, json_value_codec,
  complex, debugger_api,
  debugger_types, debugger_runtime, runtime_output;

const
  SKIP_IMPLICIT_RECURSE_FOR_SELECTION = True;
  CLEANUP_SELECTION_ON_STALL = True;
  CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT = True;
  MAX_FIXPOINT_STEPS = 1024;
  MAX_HEAD_DISPATCH_STEPS = 128;

function JoinTriePath(const Prefix, Suffix: ansistring): ansistring; forward;

function TokenValue(Ref: Integer): ansistring;
begin
  Result := GlobalTree.Expression.TokenValue(Ref);
end;

function ReplaceNodeInParent(ParentIndex, OldNodeIndex, NewNodeIndex: Integer): Boolean; forward;

type
  PRepeatExpandContext = ^TRepeatExpandContext;
  TRepeatExpandContext = record
    SourceIndex: Integer;
    IteratorTokenRef: Integer;
  end;

function TryGetRepeatExpandContext(
  Context: TContext;
  out RepeatExpandContext: PRepeatExpandContext
): Boolean; forward;
function TryGetRepeatExpandSource(Context: TContext; out SourceIndex: Integer): Boolean; forward;
function TryGetRepeatIteratorToken(Context: TContext; out IteratorTokenRef: Integer): Boolean; forward;


// function GetRefValue(Ref: Integer): TRefValue;
// begin
// end;

function GetNode(Index: Integer; PrevIndex: Integer = EOT): TBaseNode;
var
  Ref, id: Integer;
begin
  if Index = EOT then
  begin
    PPointer(@Result)^ := TypeOf(TEndOfTreeNode);
  end
  else
  begin
    id := GlobalTree[Index]^.Id;
    PPointer(@Result)^ := VMT_TABLE[id];
  end;
  Result.Index := Index;
  Result.PrevIndex := PrevIndex;
end;

function TryGetRepeatExpandContext(
  Context: TContext;
  out RepeatExpandContext: PRepeatExpandContext
): Boolean;
begin
  RepeatExpandContext := nil;
  Result := Assigned(Context) and Assigned(Context.Data);
  if not Result then
    Exit;

  RepeatExpandContext := PRepeatExpandContext(Context.Data);
  Result := Assigned(RepeatExpandContext) and
            (RepeatExpandContext^.SourceIndex <> EOT);
  if not Result then
    RepeatExpandContext := nil;
end;

function TryGetRepeatExpandSource(Context: TContext; out SourceIndex: Integer): Boolean;
var
  RepeatExpandContext: PRepeatExpandContext;
begin
  Result := TryGetRepeatExpandContext(Context, RepeatExpandContext);
  if Result then
    SourceIndex := RepeatExpandContext^.SourceIndex
  else
    SourceIndex := EOT;
end;

function TryGetRepeatIteratorToken(Context: TContext; out IteratorTokenRef: Integer): Boolean;
var
  RepeatExpandContext: PRepeatExpandContext;
begin
  Result := TryGetRepeatExpandContext(Context, RepeatExpandContext) and
            (RepeatExpandContext^.IteratorTokenRef <> EOT);
  if Result then
    IteratorTokenRef := RepeatExpandContext^.IteratorTokenRef
  else
    IteratorTokenRef := EOT;
end;

function IsDirectVariableNode(NodeIndex: Integer): Boolean;
begin
  Result := (NodeIndex <> EOT) and
            (GlobalTree[NodeIndex]^.Id = OBJ_VARIABLE) and
            (GlobalTree[NodeIndex]^.RHS = EOT);
end;

function UnwrapIteratorDriver(DriverIndex: Integer): Integer;
var
  CandidateIndex: Integer;
  CandidateIsStandaloneDriver: Boolean;
begin
  Result := DriverIndex;
  while (Result <> EOT) and
        (GlobalTree[Result]^.Id = OBJ_EXPRESSION) and
        (GlobalTree[Result]^.RHS = EOT) do
  begin
    CandidateIndex := GlobalTree[Result]^.LHS;
    if CandidateIndex = EOT then
      Break;

    CandidateIsStandaloneDriver := False;
    case GlobalTree[CandidateIndex]^.Id of
      OBJ_INTEGER, OBJ_VARIABLE:
        CandidateIsStandaloneDriver := GlobalTree[CandidateIndex]^.RHS = EOT;
      OBJ_RANGE, OBJ_STEPPED_RANGE, OBJ_ITERATOR_BIND:
        CandidateIsStandaloneDriver := True;
      OBJ_ARRAY, OBJ_EXPRESSION:
        CandidateIsStandaloneDriver := GlobalTree[CandidateIndex]^.RHS = EOT;
    end;

    if not CandidateIsStandaloneDriver then
      Break;
    Result := CandidateIndex;
  end;
end;

function TryGetIteratorBinding(
  NodeIndex: Integer;
  out DriverIndex: Integer;
  out IteratorTokenRef: Integer
): Boolean; forward;

function ResolveRepeatDriver(
  Context: TContext;
  OwnerIndex: Integer;
  DriverRootIndex: Integer;
  out EffectiveDriverIndex: Integer;
  out IteratorTokenRef: Integer
): Boolean;
var
  VariableIndex: Integer;
  VariablePrev: Integer;
  BoundDriverIndex: Integer;
begin
  Result := False;
  EffectiveDriverIndex := UnwrapIteratorDriver(DriverRootIndex);
  IteratorTokenRef := EOT;

  while (DriverRootIndex <> EOT) and
    FindResolvableVariableWithPrev(
      GlobalTree, Context, DriverRootIndex, OwnerIndex, OBJ_VARIABLE, VariableIndex, VariablePrev
    ) do
    if not ResolveVariableNode(GlobalTree, Context, VariableIndex, VariablePrev, vrmAuto) then
      Break;

  if IsDirectVariableNode(EffectiveDriverIndex) then
    Exit(False);

  if TryGetIteratorBinding(EffectiveDriverIndex, BoundDriverIndex, IteratorTokenRef) or
     TryGetIteratorBinding(DriverRootIndex, BoundDriverIndex, IteratorTokenRef) then
  begin
    EffectiveDriverIndex := UnwrapIteratorDriver(BoundDriverIndex);
    if IsDirectVariableNode(EffectiveDriverIndex) then
      Exit(False);
  end;

  Result := EffectiveDriverIndex <> EOT;
end;

function TryGetIteratorBinding(
  NodeIndex: Integer;
  out DriverIndex: Integer;
  out IteratorTokenRef: Integer
): Boolean;
begin
  Result := (NodeIndex <> EOT) and
            (GlobalTree[NodeIndex]^.Id = OBJ_ITERATOR_BIND) and
            (GlobalTree[NodeIndex]^.LHS <> EOT) and
            (GlobalTree[NodeIndex]^.Ref <> EOT);
  if Result then
  begin
    DriverIndex := GlobalTree[NodeIndex]^.LHS;
    IteratorTokenRef := GlobalTree[NodeIndex]^.Ref;
  end
  else
  begin
    DriverIndex := EOT;
    IteratorTokenRef := EOT;
  end;
end;

function CreateDetachedIntegerNode(const Value: Int64): Integer;
begin
  Result := GlobalTree.AllocateNode;
  TIntegerNode.InitTreeNode(Result);
  GlobalTree[Result]^.Ref := GlobalTree.Expression.Append(TK_INTEGER, IntToStr(Value));
end;

function CreateDetachedSingleCharStringNode(CharCode: Integer): Integer;
begin
  Result := GlobalTree.AllocateNode;
  TStringNode.InitTreeNode(Result);
  GlobalTree[Result]^.Ref :=
    GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(Chr(CharCode)));
end;

function PushIteratorValueByToken(
  Context: TContext;
  IteratorTokenRef: Integer;
  IteratorValueNode: Integer
): Boolean;
var
  IteratorName: ansistring;
begin
  Result := False;
  if (not Assigned(Context)) or (IteratorTokenRef = EOT) then
    Exit(False);

  IteratorName := Trim(GlobalTree.Expression.TokenValue(IteratorTokenRef));
  if IteratorName = '' then
    raise Exception.Create('Missing iterator name');

  Context.PushExactScope('repeat.iterator');
  if not Context.TryAddScopedExactVariable(IteratorName, IteratorValueNode) then
  begin
    Context.PopExactScope;
    raise Exception.CreateFmt('Invalid iterator binding name: %s', [IteratorName]);
  end;
  Result := True;
end;

function PushRepeatIteratorValue(
  Context: TContext;
  IteratorValueNode: Integer
): Boolean;
var
  IteratorTokenRef: Integer;
begin
  Result := False;
  if not TryGetRepeatIteratorToken(Context, IteratorTokenRef) then
    Exit(False);
  Result := PushIteratorValueByToken(Context, IteratorTokenRef, IteratorValueNode);
end;

procedure PopRepeatIteratorValue(Context: TContext; Bound: Boolean);
begin
  if Bound and Assigned(Context) then
    Context.PopExactScope;
end;

procedure NormalizeRepeatIteratorClone(Context: TContext; RootIndex: Integer);
var
  IteratorTokenRef: Integer;
begin
  if (RootIndex = EOT) or (not Assigned(Context)) then
    Exit;
  if not TryGetRepeatIteratorToken(Context, IteratorTokenRef) then
    Exit;
  NormalizeResolvableVariables(GlobalTree, Context, RootIndex, EOT);
end;

procedure RegisterObject(vmt: Pvmt; id: Integer);
begin
  VMT_TABLE[id] := vmt;
  vmt^.vInstanceSize2 := id;
end;

procedure RegisterObjects;
begin
  // Add all objects to a list (?)
  RegisterObject(TypeOf(TCustomNode), OBJ_CUSTOM_NODE);
  RegisterObject(TypeOf(TBaseNode), OBJ_BASE_NODE);

  // SCOPES
  RegisterObject(TypeOf(TExpressionNode), OBJ_EXPRESSION);
  RegisterObject(TypeOf(TArrayNode), OBJ_ARRAY);
  RegisterObject(TypeOf(TEvaluationNode), OBJ_EVALUATION);
  RegisterObject(TypeOf(TComputeNode), OBJ_COMPUTE);

  // IDENTIFIERS
  RegisterObject(TypeOf(TVariableNode), OBJ_VARIABLE);
  RegisterObject(TypeOf(TIntegerNode), OBJ_INTEGER);
  RegisterObject(TypeOf(TFloatNode), OBJ_FLOAT);
  RegisterObject(TypeOf(TComplexNode), OBJ_COMPLEX);
  RegisterObject(TypeOf(TSelectionPolicyNode), OBJ_SELECTION_POLICY);
  RegisterObject(TypeOf(TForwardRuleNode), OBJ_RULE_FORWARD);
  RegisterObject(TypeOf(TReverseRuleNode), OBJ_RULE_REVERSE);
  RegisterObject(TypeOf(TDefineNode), OBJ_DEFINE);
  RegisterObject(TypeOf(TStringNode), OBJ_STRING);
  RegisterObject(TypeOf(TPackageNode), OBJ_PACKAGE);
  RegisterObject(TypeOf(TImportNode), OBJ_IMPORT);
  RegisterObject(TypeOf(TIncludeNode), OBJ_INCLUDE);
  RegisterObject(TypeOf(TGlobalNode), OBJ_GLOBAL);
  RegisterObject(TypeOf(TScopeFrameNode), OBJ_SCOPE_FRAME);
  RegisterObject(TypeOf(TAliasNode), OBJ_ALIAS);
  RegisterObject(TypeOf(TCallableNode), OBJ_CALLABLE);
  RegisterObject(TypeOf(TExplodeNode), OBJ_EXPLODE);
  RegisterObject(TypeOf(TImplodeNode), OBJ_IMPLODE);
  RegisterObject(TypeOf(TPatternNode), OBJ_PATTERN);
  RegisterObject(TypeOf(TQueryKeysNode), OBJ_QUERY_KEYS);
  RegisterObject(TypeOf(TQueryValuesNode), OBJ_QUERY_VALUES);
  RegisterObject(TypeOf(TQueryChildrenNode), OBJ_QUERY_CHILDREN);
  RegisterObject(TypeOf(TGetNode), OBJ_GET);
  RegisterObject(TypeOf(TPathSegmentNode), OBJ_PATH_SEGMENT);
  RegisterObject(TypeOf(TMakePairNode), OBJ_MAKE_PAIR);
  RegisterObject(TypeOf(TFmtNode), OBJ_FMT);
  RegisterObject(TypeOf(TPrintfNode), OBJ_PRINTF);
  RegisterObject(TypeOf(TRenderNode), OBJ_RENDER);
  RegisterObject(TypeOf(TJsonLoadNode), OBJ_JSON_LOAD);
  RegisterObject(TypeOf(TJsonEncodeNode), OBJ_JSON_ENCODE);
  RegisterObject(TypeOf(TJsonSaveNode), OBJ_JSON_SAVE);
  RegisterObject(TypeOf(TDisplayNode), OBJ_DISPLAY);
  RegisterObject(TypeOf(TYamlLoadNode), OBJ_YAML_LOAD);
  RegisterObject(TypeOf(TSystemNode), OBJ_SYSTEM);
  RegisterObject(TypeOf(TAssignPathNode), OBJ_ASSIGN_PATH);
  RegisterObject(TypeOf(TExecNode), OBJ_EXEC);

  // SPECIAL
  RegisterObject(TypeOf(TAssignmentNode), OBJ_ASSIGNMENT);
  RegisterObject(TypeOf(TDeepAssignmentNode), OBJ_DEEP_ASSIGNMENT);
  RegisterObject(TypeOf(TRepeatNode), OBJ_REPEAT);
  RegisterObject(TypeOf(TStagedRepeatNode), OBJ_STAGED_REPEAT);
  RegisterObject(TypeOf(TRecurseNode), OBJ_RECURSE);
  RegisterObject(TypeOf(TIteratorBindingNode), OBJ_ITERATOR_BIND);
  RegisterObject(TypeOf(TIndexLookupNode), OBJ_INDEX_LOOKUP);
  RegisterObject(TypeOf(TSelectionNode), OBJ_SELECTION);
  RegisterObject(TypeOf(TInlineSelectionNode), OBJ_INLINE_SELECTION);
  RegisterObject(TypeOf(TFallbackNode), OBJ_FALLBACK);
  RegisterObject(TypeOf(TTransformationNode), OBJ_TRANSFORMATION);
  RegisterObject(TypeOf(TEquivalenceNode), OBJ_EQUIVALENCE);
  RegisterObject(TypeOf(TInlineTransformationNode), OBJ_INLINE_TRANSFORMATION);
  RegisterObject(TypeOf(TSubstitutionNode), OBJ_SUBST_TRANSFORM);
  RegisterObject(TypeOf(TSymbolSubstitutionNode), OBJ_SYMBOL_SUBST_TRANSFORM);
  RegisterObject(TypeOf(TEquivalenceSubstitutionNode), OBJ_SUBST_EQUIVALENCE);
  RegisterObject(TypeOf(TSeparatorNode), OBJ_SEPARATOR);
  RegisterObject(TypeOf(TRangeNode), OBJ_RANGE);
  RegisterObject(TypeOf(TSteppedRangeNode), OBJ_STEPPED_RANGE);
  RegisterObject(TypeOf(TConcatenateNode), OBJ_CONCATENATE);
  RegisterObject(TypeOf(TMatchAnyNode), OBJ_MATCH_ANY);
  RegisterObject(TypeOf(TInferenceNode), OBJ_INFERENCE);
  RegisterObject(TypeOf(TInferenceWitnessNode), OBJ_INFERENCE_WITNESS);
  RegisterObject(TypeOf(TVariableSubtreeNode), OBJ_VARIABLE_SUBTREE);
  RegisterObject(TypeOf(TPipeNode), OBJ_PIPE);
  RegisterObject(TypeOf(TRuleNode), OBJ_RULE);
  RegisterObject(TypeOf(TOutputNode), OBJ_OUTPUT);
  RegisterObject(TypeOf(TTreeOutputNode), OBJ_TREE_OUTPUT);
  RegisterObject(TypeOf(TIROutputNode), OBJ_IR_OUTPUT);

  // OTHER
  RegisterObject(TypeOf(TStatementNode), OBJ_STATEMENT);

  RegisterBuiltinSystemCommands;
  RegisterBuiltinNativeFunctions;
end;

// @todo : complete implementation
function GetCombinedOp(X, Y: Integer): Integer;
begin
  if ((X or Y) and (TK_PLUS or TK_MINUS or TK_MULTIPLY or TK_DIVIDE)) <> 0 then
    Exit(compute.GetCombinedOp(X, Y));

  // Accept either full token IDs (e.g. $00810000) or raw op-bytes (e.g. $81).
  // if (X <> 0) and ((X and TK_OPERATOR_MASK) = 0) then
  //   X := X shl 16;
  // if (Y <> 0) and ((Y and TK_OPERATOR_MASK) = 0) then
  //   Y := Y shl 16;

  Result := TK_ERROR;
  if X = 0 then
    Exit(Y);
  if Y = 0 then
    Exit(X);

  if ((X = TK_PLUS) or (X = TK_MINUS)) and
     ((Y = TK_PLUS) or (Y = TK_MINUS)) then
  begin
    if X = Y then
      Exit(TK_PLUS)
    else
      Exit(TK_MINUS);
  end;

  // Unary reciprocal/product wrappers keep their semantics when the wrapped node
  // carries an explicit unary plus (e.g. / ( + x ) -> / x).
  if (Y = TK_PLUS) and ((X = TK_DIVIDE) or (X = TK_MULTIPLY)) then
    Exit(X);

  if X = Y then
  begin
    case X of
      TK_ASTERISK, TK_RELATIONAL_LT:
        Exit(X);
    end;
  end;
end;

function GetScopeCombinedOp(ParentOp, ChildOp: Integer): Integer;
begin
  Result := CombineLHS(ChildOp, ParentOp);
end;

{ TAbstractNode }

function TAbstractNode.GetVMT: Pointer;
begin
   Result := Pointer(PtrInt(@Self));
end;

procedure TAbstractNode.SetVMT(Value: Pointer);
begin
  PPointer(PtrInt(@Self))^ := Value;
end;

constructor TAbstractNode.Initialize;
begin
end;

function TCustomNode.GetTreeNode: PTreeNode;
begin
  Result := GlobalTree[Index];
end;



{ TCustomNode }

constructor TCustomNode.Initialize(Flags: Integer);
begin
  Index := EOT;
  PrevIndex := EOT;
  Extra := 0;
end;

function TCustomNode.ObjectId: Integer;
begin
  Result := PVmt(Self)^.vInstanceSize2;
end;

function TCustomNode.LHS: Integer;
begin
  Result := TreeNode^.LHS;
end;

function TCustomNode.RHS: Integer;
begin
  Result := TreeNode^.RHS;
end;

function TCustomNode.GetTree: TCustomTree;
begin
  Result := nil;
end;

function TCustomNode.GetToken: Integer;
begin
  //Result := TreeNode^.Child;
  Result := TreeNode^.Ref;
end;

procedure TCustomNode.SetToken(Value: Integer);
begin
  //TreeNode^.Child := Value;
  TreeNode^.Ref := Value;
end;

// @todo : adjust logic
function TCustomNode.GetTokenID: Integer;
var
  T: TCustomTree;
begin
  Result := 0;
  T := GetTree;
  if Assigned(T) then
    Result := T.Expression.TokenID(TreeNode^.Ref);
end;

// @todo : adjust logic
function TCustomNode.GetTokenKey: Integer;
var
  T: TCustomTree;
begin
  Result := 0;
  T := GetTree;
  if Assigned(T) then
    Result := T.Expression.Token[Token]^.Index;
end;

// @todo : adjust logic
procedure TCustomNode.SetTokenID(Value: Integer);
var
  T: TCustomTree;
begin
  Assert(Token >= 0);
  T := GetTree;
  if Assigned(T) then
    T.Expression.Token[Token]^.ID := Value;
end;


function TCustomNode.RealVMT: Pointer; static;
begin
  Result := Self;
end;


{ TBaseNode }

procedure TBaseNode.InitTreeNode(AIndex: Integer; AToken: Integer = 0);
begin
  // Q: Id <-> RefData ???
  GlobalTree[AIndex]^.Data := ObjectId;
  GlobalTree[AIndex]^.Ref := AToken;

  GlobalTree[AIndex]^.LHS := EOT;
  GlobalTree[AIndex]^.RHS := EOT;
  // Q: use AToken for debugging?
end;

function TBaseNode.GetNode(AIndex: Integer): TBaseNode;
begin
  Result := nodes.GetNode(AIndex, Index);
end;

function TBaseNode.Child: TBaseNode;
begin
  Result := Node[TreeNode^.LHS];
end;

function TBaseNode.Prev: TBaseNode;
begin
  Result := nodes.GetNode(PrevIndex);
end;

function TBaseNode.Next: TBaseNode;
begin
  Result := Node[TreeNode^.RHS];
end;

// DEBUGGING FUNCTIONS

// Create a "wrapper" node and place existing node as child
function TBaseNode.WrapNode: Integer;
begin
  Result := GlobalTree.AllocateNode;
  GlobalTree[Result]^ := TreeNode^;
  //GlobalTree[Result]^.Prev := NodeIndex;
  GlobalTree[Result]^.RHS := EOT;        // N: moved to wrapper
  //Token := AddToken(TK_PARENTHESIS_BEGIN, '(');
  //VMT := TExpressionNode.RealVMT;
  TreeNode^.LHS := Result;
end;

function TBaseNode.AsString: ansistring; overload;
begin
  Result := TokenValue(formatters.DefaultFormat);
end;

function TBaseNode.AsString(var Config: TFormatConfig): ansistring; overload;
begin
(*
  if Token < 0 then
    Result := GetDynToken(Token)^.Value
  else
  *)
  //! Result := Tree.TokenValue(Token);
  //Result := WriteValue(Result, Config);
  //Inc(Config.Offset, Length(Result));
end;

function TBaseNode.TokenValue: ansistring;
begin
  //Result := ElementValue(DefaultFormat);
  Result := nodes.TokenValue(TreeNode^.Ref);
end;

function TBaseNode.TokenValue(var Config: TFormatConfig): ansistring;
begin
  //Result := ElementValue(DefaultFormat);
  Result := nodes.TokenValue(TreeNode^.Ref);
end;


function TBaseNode.ElementValue: ansistring;
begin
  Result := ElementValue(formatters.DefaultFormat);
end;

function TBaseNode.ElementValue(var Config: TFormatConfig): ansistring;
begin
  Result := TokenValue(Config);
  IncludeOperator(Result);
end;

function TBaseNode.GetOperator: ansistring;
var
  SelectorTokenId: Integer;
  SelectorOp: ansistring;
  ArithmeticOp: ansistring;
begin
  //Result := TokenFromID(TokenID and TK_META_MASK);
  //Result := Result + TokenFromID(GetOperatorID);
  ArithmeticOp := TokenFromID(TreeNode^.Data and TK_OPERATOR_MASK);
  SelectorTokenId := TreeNode^.Data and TK_SELECTOR_MASK;
  if SelectorTokenId <> 0 then
    SelectorOp := TokenFromID(SelectorTokenId)
  else
    SelectorOp := '';

  if (SelectorOp <> '') and (ArithmeticOp <> '') then
    Result := SelectorOp + ' ' + ArithmeticOp
  else if SelectorOp <> '' then
    Result := SelectorOp
  else
    Result := ArithmeticOp;
end;

procedure TBaseNode.IncludeOperator(var Value: ansistring);
var
  Op: ansistring;
begin
  Op := GetOperator;
  if Op <> '' then
    Value := Op + ' ' + Value;
end;

function TBaseNode.TreeValue: ansistring;
begin
  Result := TreeValue(formatters.DefaultFormat);
end;

function TBaseNode.TreeValue(var Config: TFormatConfig): ansistring;
begin
  //Result := Tree.TokenValue(Token) + ' '; //
  Result := ElementValue(Config);
  //if Child <> EOT then Result := Result + (Node.Node[Child])^.TreeValue(Context);

  // N: linebreak at the end of LHS / RHS
  if RHS  <> EOT then
  begin
    Result := Result + ' ' + Next.TreeValue(Config);
  end;
end;

function TBaseNode.Formatted: ansistring;
var
  Formatter: TCustomFormatter;
begin
  Formatter := GetFormatter;
  try
    Result := Formatted(Formatter);
  finally
    Formatter.Free;
  end;
end;

function TBaseNode.GetFormatter: TCustomFormatter;
begin
  Result := TFormatter.Create;
end;

// function TBaseNode.TreeFormatted: ansistring;
// var
//   Formatter: TCustomFormatter;
// begin
//   Formatter := TTreeFormatter.Create;
//   try
//     Result := Formatted(Formatter);
//   finally
//     Formatter.Free;
//   end;
// end;

function TBaseNode.Formatted(Formatter: TCustomFormatter): ansistring;
begin
  Formatter.WriteFormatted(Index);
  Result := Formatter.Output;
end;

function TBaseNode.FindObject(Id: Integer): Integer;
begin
  Result := EOT;
  if Id = ObjectId then
    Result := Index
  else
  begin
    if LHS <> EOT then Result := Node[LHS].FindObject(Id);
    if (Result = EOT) and (RHS <> EOT) then Result := Node[RHS].FindObject(Id);
  end;
end;

// Invoke virtual methods through non-virtual dispatch callback.
procedure Dispatch(Index, PrevIndex: Integer; Proc: Pointer; Context: TContext);
var
  Node: TBaseNode;
  M: TMethod;
begin
  if Index <> EOT then
  begin
    Node := GetNode(Index, PrevIndex);
    TMethod(M).Data := @Node;
    TMethod(M).Code := Proc;
    TContextProc(M)(Context);
  end;
end;

// dispatch to LHS and RHS
procedure TBaseNode.Dispatch(Proc: Pointer; Context: TContext);
begin
  // Q: allow order to change?
  // if Context.Meta and META_RHS_FIRST = META_RHS_FIRST then ...
  nodes.Dispatch(LHS, Index, Proc, Context);
  nodes.Dispatch(RHS, Index, Proc, Context);
end;

// non-virtual trampolines
procedure TBaseNode.DispatchExecute(Context: TContext);
begin
  Execute(Context);
end;

procedure TBaseNode.DispatchEvaluate(Context: TContext);
begin
  Evaluate(Context);
end;

procedure TBaseNode.DispatchCompute(Context: TContext);
begin
  Compute(Context);
end;

procedure TBaseNode.DispatchExpand(Context: TContext);
begin
  Expand(Context);
end;

procedure TBaseNode.DispatchTransform(Context: TContext);
begin
  Transform(Context);
end;

function TBaseNode.TransformPartial(Depth: Integer): Integer;
// var
//   X: Integer;

//   function Wrapper(Index, Last: Integer): Integer;
//   begin
//     Result := Index;

//     if Index <> EOT then
//     begin
//       //WriteLn('[ T ] >>> ', (Node[Index])^.TreeValue);

//       // add wrapper only if necessary
//       if (Tree.RHS[Index] <> EOT) or ((Node[Index])^.TokenID and TK_SCOPE_MASK <> TK_BRACKET_BEGIN) then
//       begin
//         //WriteLn('wrap');
//         //WriteLn('[   ] >>> ', TreeValue);
//         Result := Tree.AllocateNode;
//         PSeparatorNode(Tree[Result])^.Initialize;
//         PSeparatorNode(Tree[Result])^.Token := AddToken(TK_COMMA, ',');

//         PSeparatorNode(Tree[Result])^.TreeNode^.LHS := EOT;
//         PSeparatorNode(Tree[Result])^.TreeNode^.RHS := EOT;

//         //WriteLn('[ I ] >>> ', (Node[Index])^.TreeValue);
//         //WriteLn('[   ] >>> ', TreeValue);
//         Tree.LinkChild(Result, Index);
//         //WriteLn('[ R ] >>> ', (Node[Result])^.TreeValue);
//         //WriteLn('[   ] >>> ', TreeValue);
//       end;
//       Tree.LinkNext(Last, Result);
//     end;
//     //else
//     //  WriteLn('[ ! ]');
//   end;

begin
//   Result := NodeIndex;
//   X := EOT;
//   //Assert(Tree.Next[P] = NodeIndex);
//   while (FindToken(TK_CURLY_BEGIN, TK_CURLY_BEGIN) <> EOT) and (Depth > 0) do
//   begin
// {$IFDEF DEBUG_TRANSFORMATIONS}
//     WriteLn('[ X ] >>> ', TreeValue);
// {$ENDIF}
//     X := Wrapper(CopyNodes(NodeIndex, @PartialSplit), X);
//     Dec(Depth);
//   end;
//   // N: if evaluation node is expanded NodeIndex is invalid

//   if X <> EOT then
//   begin
//     Result := Tree.FirstSibling[X];
// {$IFDEF DEBUG_TRANSFORMATIONS}
//     WriteLn('[ = ] >>> ', (Node[Result])^.TreeValue);
// {$ENDIF}
//     Delete;
//   end;
end;

procedure TBaseNode.ClearRewrite;
begin
  //if Child <> EOT then Node[LHS]^.ClearRewrite;
  //if Next  <> EOT then (Node[Next])^.ClearRewrite;
  Clear(TK_FORWARD, TK_FORWARD);
  Clear(TK_TRIPLEDOT, TK_TRIPLEDOT);
end;

procedure TBaseNode.ClearEvaluation;
begin
  Clear(TK_CURLY_BEGIN, TK_CURLY_BEGIN);
end;

procedure TBaseNode.ClearEmptyScopes;
begin
  if LHS <> EOT then Node[LHS].ClearEmptyScopes;
  if RHS <> EOT then Node[RHS].ClearEmptyScopes;
end;

procedure TBaseNode.Clear(AToken, Mask: Integer);
begin
  if LHS <> EOT then nodes.GetNode(LHS, Index).Clear(AToken, Mask);
  if RHS <> EOT then nodes.GetNode(RHS, Index).Clear(AToken, Mask);
  //WriteLn(Format('%s, %d, %d', [TokenValue, TokenID, AToken]));
  if TreeNode^.Id = AToken then
    Delete;
end;

procedure TBaseNode.Complete;
begin
  ClearRewrite;
  ClearEvaluation;
end;

// virtual methods
procedure TBaseNode.Execute(Context: TContext);
begin
  Dispatch(@TBaseNode.DispatchExecute, Context);
end;

procedure TBaseNode.Evaluate(Context: TContext);
begin
  if TreeNode^.Data and TK_UNFIX = TK_UNFIX then
    TreeNode^.Data := TreeNode^.Data and (not TK_UNFIX) and (not TK_FIXED);

  if TreeNode^.Data and TK_FIXED = TK_FIXED then
  begin
    if RHS <> EOT then
      Node[RHS].Evaluate(Context);
    Exit;
  end;

  // BeforeEvaluate(Context);

  Dispatch(@TBaseNode.DispatchEvaluate, Context);
  DoEvaluate(Context);

  if TreeNode^.Data and TK_TILDE = TK_TILDE then
  begin
    Compute(Context);
    TreeNode^.Data := TreeNode^.Data xor TK_TILDE;
  end;

  if ObjectId = OBJ_EVALUATION then
    GlobalTree.Expand(PrevIndex, Index);

  //AfterEvaluate(Context);
end;

procedure TBaseNode.DoEvaluate(Context: TContext);
begin
end;

procedure TBaseNode.Compute(Context: TContext);
begin
  if TreeNode^.Data and TK_UNFIX = TK_UNFIX then
    TreeNode^.Data := TreeNode^.Data and (not TK_UNFIX) and (not TK_FIXED);

  if TreeNode^.Data and TK_FIXED = TK_FIXED then
  begin
    if RHS <> EOT then
      Node[RHS].Compute(Context);
    Exit;
  end;

  Dispatch(@TBaseNode.DispatchCompute, Context);
end;

procedure TBaseNode.Expand(Context: TContext);
begin
  Dispatch(@TBaseNode.DispatchExpand, Context);
end;

procedure TBaseNode.Transform(Context: TContext);
begin
  if TreeNode^.Data and TK_UNFIX = TK_UNFIX then
    TreeNode^.Data := TreeNode^.Data and (not TK_UNFIX) and (not TK_FIXED);

  if TreeNode^.Data and TK_FIXED = TK_FIXED then
  begin
    if RHS <> EOT then
      Node[RHS].Transform(Context);
    Exit;
  end;

  Dispatch(@TBaseNode.DispatchTransform, Context);
end;


procedure TBaseNode.FixRecursion;
var
  X, Y: Integer;
  SelectionIndex: Integer;
  SkipBySelectionMode: Boolean;
begin
  SkipBySelectionMode := False;
  if SKIP_IMPLICIT_RECURSE_FOR_SELECTION then
  begin
    SelectionIndex := FindObject(OBJ_SELECTION);
    if SelectionIndex = EOT then
      SelectionIndex := FindObject(OBJ_INLINE_SELECTION);
    SkipBySelectionMode := SelectionIndex <> EOT;
  end
  else
  begin
    SelectionIndex := FindObject(OBJ_SELECTION);
    if SelectionIndex = EOT then
      SelectionIndex := FindObject(OBJ_INLINE_SELECTION);
    SkipBySelectionMode := (SelectionIndex <> EOT) and
      ((GlobalTree[SelectionIndex]^.Data and TK_DOLLAR) = TK_DOLLAR);
  end;

  if (FindObject(OBJ_RECURSE) = EOT) and (not SkipBySelectionMode) then
  begin
    X := GlobalTree.LastSibling[Index];
    Y := GlobalTree.AllocateNode;
    TRecurseNode.InitTreeNode(Y);

    //Tree[Y]^.Token := Tree.Expression.Append(TK_TRIPLEDOT, '...');
    GlobalTree[Y]^.Ref := GlobalTree.Expression.Append(TK_TRIPLEDOT, '...');
    GlobalTree[X]^.RHS := Y;
  end;
end;

procedure TBaseNode.AppendOperator(DstOp: Integer; IncludeNext: Boolean);
var
  SrcOp, CombinedOp: Integer;
begin
  if (DstOp <> 0) and ((DstOp and TK_OPERATOR_MASK) = 0) then
    DstOp := DstOp shl 16;

  SrcOp := TreeNode^.Data and TK_OPERATOR_MASK;
  CombinedOp := GetCombinedOp(SrcOp, DstOp);
  if CombinedOp <> TK_ERROR then
  begin
    TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or
                      (CombinedOp and TK_OPERATOR_MASK);
  end
  else
  begin
    WrapNode;
    TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or
                      (DstOp and TK_OPERATOR_MASK);
  end;

  if IncludeNext and (RHS <> EOT) then
    Node[RHS].AppendOperator(DstOp, IncludeNext);
end;



procedure TBaseNode.Delete;
begin
  GlobalTree.Delete(PrevIndex, Index);
end;

// N: implemented also by TRecurseNode.Transform ( ">>", "..." )
// procedure TBaseNode.Transform(Context: TContext; Src, Depth: Integer);
// begin
//   if LHS <> EOT then Node[LHS]^.Transform(Context, Src, Depth);
//   if RHS <> EOT then Node[RHS]^.Transform(Context, Src, Depth);
// end;

// N: implemented also by TRecurseNode.RewriteReverse ( "<<" )
// procedure TBaseNode.RewriteReverse(Context: TContext; Src: Integer);
// begin
//   if Child <> EOT then Node[LHS]^.RewriteReverse(Context, Src);
//   if Next  <> EOT then Node[RHS]^.RewriteReverse(Context, Src);
// end;

// procedure TBaseNode.ClearRewrite;
// begin
//   Clear(TK_REVERSE, TK_REVERSE);
//   Clear(TK_FORWARD, TK_FORWARD);
//   Clear(TK_TRIPLEDOT, TK_TRIPLEDOT);
// end;


{ TEndOfTreeNode }

procedure TEndOfTreeNode.Execute(Context: TContext);
begin
end;

procedure TEndOfTreeNode.Evaluate(Context: TContext);
begin
end;

procedure TEndOfTreeNode.Compute(Context: TContext);
begin
end;

type
  TRangeDomainKind = (rdkInteger, rdkFloat, rdkCharacter);

  TRangeDomain = record
    Kind: TRangeDomainKind;
    StartInt: Int64;
    EndInt: Int64;
    StepInt: Int64;
    StartFloat: Double;
    EndFloat: Double;
    StepFloat: Double;
    StartChar: Integer;
    EndChar: Integer;
    StepChar: Integer;
    Ordinal: Int64;
  end;

function TryReadSignedInteger(NodeIndex: Integer; out Value: Int64): Boolean;
var
  OpBits: Integer;
begin
  Result := (NodeIndex <> EOT) and (GetNode(NodeIndex).ObjectId = OBJ_INTEGER);
  if not Result then
    Exit;
  TIntegerNode(GetNode(NodeIndex)).GetValue(Value);
  OpBits := GlobalTree[NodeIndex]^.Data and TK_OPERATOR_MASK;
  if (OpBits and TK_MINUS) <> 0 then
    Value := -Value
  else if (OpBits <> 0) and (OpBits <> TK_PLUS) then
    Exit(False);
end;

function TryReadSignedFloat(NodeIndex: Integer; out Value: Double): Boolean;
var
  IntValue: Int64;
  OpBits: Integer;
begin
  Result := False;
  if NodeIndex = EOT then
    Exit;
  if GetNode(NodeIndex).ObjectId = OBJ_INTEGER then
  begin
    if not TryReadSignedInteger(NodeIndex, IntValue) then
      Exit;
    Value := IntValue;
    Exit(True);
  end;
  if GetNode(NodeIndex).ObjectId <> OBJ_FLOAT then
    Exit;
  TFloatNode(GetNode(NodeIndex)).GetValue(Value);
  OpBits := GlobalTree[NodeIndex]^.Data and TK_OPERATOR_MASK;
  if (OpBits and TK_MINUS) <> 0 then
    Value := -Value
  else if (OpBits <> 0) and (OpBits <> TK_PLUS) then
    Exit(False);
  Result := True;
end;

function CreateDetachedFloatNode(const Value: Double): Integer;
var
  Magnitude: Double;
begin
  Result := GlobalTree.AllocateNode;
  TFloatNode.InitTreeNode(Result);
  Magnitude := Value;
  if Magnitude < 0 then
  begin
    Magnitude := -Magnitude;
    GlobalTree[Result]^.Data := GlobalTree[Result]^.Data or TK_MINUS;
  end;
  GlobalTree[Result]^.Ref := GlobalTree.Expression.Append(
    TK_FLOAT, FloatToStr(Magnitude, DefaultFormatSettings)
  );
end;

procedure EvaluateRangeOperand(Context: TContext; ParentIndex: Integer; NodeIndex: Integer);
begin
  if NodeIndex <> EOT then
    nodes.GetNode(NodeIndex, ParentIndex).Evaluate(Context);
end;

function TryBuildRangeDomain(
  Context: TContext;
  TargetIndex: Integer;
  RangeIndex: Integer;
  StepIndex: Integer;
  out Domain: TRangeDomain
): Boolean;
var
  StartIndex, EndIndex: Integer;
  StartIsFloat, EndIsFloat, StepIsFloat: Boolean;
  StartText, EndText: ansistring;
begin
  Result := False;
  FillChar(Domain, SizeOf(Domain), 0);
  if (RangeIndex = EOT) or (GlobalTree[RangeIndex]^.Id <> OBJ_RANGE) then
    Exit;

  StartIndex := GlobalTree[RangeIndex]^.LHS;
  EvaluateRangeOperand(Context, RangeIndex, StartIndex);
  StartIndex := GlobalTree[RangeIndex]^.LHS;
  EndIndex := GlobalTree[RangeIndex]^.RHS;
  EvaluateRangeOperand(Context, RangeIndex, EndIndex);
  StartIndex := GlobalTree[RangeIndex]^.LHS;
  EndIndex := GlobalTree[RangeIndex]^.RHS;
  if (StartIndex = EOT) or (EndIndex = EOT) then
    Exit;

  if StepIndex <> EOT then
  begin
    EvaluateRangeOperand(Context, TargetIndex, StepIndex);
    StepIndex := GlobalTree[TargetIndex]^.RHS;
    if GlobalTree[RangeIndex]^.Id <> OBJ_RANGE then
      Exit;
  end;

  if (GetNode(StartIndex).ObjectId = OBJ_STRING) and
     (GetNode(EndIndex).ObjectId = OBJ_STRING) then
  begin
    if StepIndex <> EOT then
      raise Exception.Create('explicit character range steps are not supported');
    StartText := GetNode(StartIndex).TokenValue;
    EndText := GetNode(EndIndex).TokenValue;
    if (not UnquoteSingleChar(StartText, Domain.StartChar)) or
       (not UnquoteSingleChar(EndText, Domain.EndChar)) then
      Exit;
    Domain.Kind := rdkCharacter;
    if Domain.StartChar <= Domain.EndChar then
      Domain.StepChar := 1
    else
      Domain.StepChar := -1;
    Exit(True);
  end;

  StartIsFloat := GetNode(StartIndex).ObjectId = OBJ_FLOAT;
  EndIsFloat := GetNode(EndIndex).ObjectId = OBJ_FLOAT;
  StepIsFloat := (StepIndex <> EOT) and (GetNode(StepIndex).ObjectId = OBJ_FLOAT);
  if not ((GetNode(StartIndex).ObjectId in [OBJ_INTEGER, OBJ_FLOAT]) and
          (GetNode(EndIndex).ObjectId in [OBJ_INTEGER, OBJ_FLOAT])) then
    Exit;
  if (StepIndex <> EOT) and
     not (GetNode(StepIndex).ObjectId in [OBJ_INTEGER, OBJ_FLOAT]) then
    raise Exception.Create('range step must be numeric');

  if StartIsFloat or EndIsFloat or StepIsFloat then
  begin
    if (not TryReadSignedFloat(StartIndex, Domain.StartFloat)) or
       (not TryReadSignedFloat(EndIndex, Domain.EndFloat)) then
      Exit;
    Domain.Kind := rdkFloat;
    if StepIndex <> EOT then
    begin
      if not TryReadSignedFloat(StepIndex, Domain.StepFloat) then
        raise Exception.Create('range step must be numeric');
    end
    else if Domain.StartFloat <= Domain.EndFloat then
      Domain.StepFloat := 1.0
    else
      Domain.StepFloat := -1.0;
    if IsNan(Domain.StartFloat) or IsInfinite(Domain.StartFloat) or
       IsNan(Domain.EndFloat) or IsInfinite(Domain.EndFloat) or
       IsNan(Domain.StepFloat) or IsInfinite(Domain.StepFloat) then
      raise Exception.Create('range values and step must be finite');
    if Domain.StepFloat = 0.0 then
      raise Exception.Create('range step cannot be zero');
    if ((Domain.StartFloat < Domain.EndFloat) and (Domain.StepFloat < 0.0)) or
       ((Domain.StartFloat > Domain.EndFloat) and (Domain.StepFloat > 0.0)) then
      raise Exception.Create('range step direction does not reach end');
  end
  else
  begin
    if (not TryReadSignedInteger(StartIndex, Domain.StartInt)) or
       (not TryReadSignedInteger(EndIndex, Domain.EndInt)) then
      Exit;
    Domain.Kind := rdkInteger;
    if StepIndex <> EOT then
    begin
      if not TryReadSignedInteger(StepIndex, Domain.StepInt) then
        raise Exception.Create('range step must be an integer');
    end
    else if Domain.StartInt <= Domain.EndInt then
      Domain.StepInt := 1
    else
      Domain.StepInt := -1;
    if Domain.StepInt = 0 then
      raise Exception.Create('range step cannot be zero');
    if ((Domain.StartInt < Domain.EndInt) and (Domain.StepInt < 0)) or
       ((Domain.StartInt > Domain.EndInt) and (Domain.StepInt > 0)) then
      raise Exception.Create('range step direction does not reach end');
  end;

  Domain.Ordinal := 0;
  Result := True;
end;

function RangeDomainNext(var Domain: TRangeDomain; out ValueNode: Integer): Boolean;
var
  IntValue: Int64;
  FloatValue: Double;
  CharValue: Integer;
  Tolerance: Double;
begin
  Result := False;
  ValueNode := EOT;
  case Domain.Kind of
    rdkInteger:
      begin
        IntValue := Domain.StartInt + Domain.Ordinal * Domain.StepInt;
        if ((Domain.StepInt > 0) and (IntValue > Domain.EndInt)) or
           ((Domain.StepInt < 0) and (IntValue < Domain.EndInt)) then
          Exit;
        ValueNode := CreateDetachedIntegerNode(IntValue);
      end;
    rdkFloat:
      begin
        FloatValue := Domain.StartFloat + Domain.Ordinal * Domain.StepFloat;
        Tolerance := 1.0e-12 * (
          1.0 + Abs(Domain.StartFloat) + Abs(Domain.EndFloat) +
          Abs(Domain.StepFloat) * Abs(Domain.Ordinal)
        );
        if ((Domain.StepFloat > 0.0) and (FloatValue > Domain.EndFloat + Tolerance)) or
           ((Domain.StepFloat < 0.0) and (FloatValue < Domain.EndFloat - Tolerance)) then
          Exit;
        if Abs(FloatValue - Domain.EndFloat) <= Tolerance then
          FloatValue := Domain.EndFloat;
        ValueNode := CreateDetachedFloatNode(FloatValue);
      end;
    rdkCharacter:
      begin
        CharValue := Domain.StartChar + Domain.Ordinal * Domain.StepChar;
        if ((Domain.StepChar > 0) and (CharValue > Domain.EndChar)) or
           ((Domain.StepChar < 0) and (CharValue < Domain.EndChar)) then
          Exit;
        ValueNode := CreateDetachedSingleCharStringNode(CharValue);
      end;
  end;
  Inc(Domain.Ordinal);
  Result := True;
end;

function CountRangeDomain(const Source: TRangeDomain): Int64;
var
  Cursor: TRangeDomain;
  ValueNode: Integer;
begin
  Result := 0;
  Cursor := Source;
  while RangeDomainNext(Cursor, ValueNode) do
  begin
    Inc(Result);
    GlobalTree.DeleteSubtree(EOT, ValueNode);
  end;
end;

procedure MaterializeRange(
  Context: TContext;
  TargetIndex: Integer;
  RangeIndex: Integer;
  StepIndex: Integer
);
var
  Domain: TRangeDomain;
  TailOwner, TailIndex: Integer;
  OldLHS, OldRHS: Integer;
  FirstValue, NextValue, LastValue: Integer;
begin
  if not TryBuildRangeDomain(Context, TargetIndex, RangeIndex, StepIndex, Domain) then
    Exit;

  if StepIndex <> EOT then
    TailOwner := GlobalTree[TargetIndex]^.RHS
  else
    TailOwner := GlobalTree[RangeIndex]^.RHS;
  TailIndex := EOT;
  if TailOwner <> EOT then
  begin
    TailIndex := GlobalTree[TailOwner]^.RHS;
    GlobalTree[TailOwner]^.RHS := EOT;
  end;

  if not RangeDomainNext(Domain, FirstValue) then
    Exit;

  OldLHS := GlobalTree[TargetIndex]^.LHS;
  OldRHS := GlobalTree[TargetIndex]^.RHS;
  GlobalTree[TargetIndex]^.LHS := EOT;
  GlobalTree[TargetIndex]^.RHS := EOT;
  if OldLHS <> EOT then
    GlobalTree.DeleteSubtree(EOT, OldLHS);
  if OldRHS <> EOT then
    GlobalTree.DeleteSubtree(EOT, OldRHS);

  GlobalTree[TargetIndex]^.Id := GlobalTree[FirstValue]^.Id;
  GlobalTree[TargetIndex]^.Ref := GlobalTree[FirstValue]^.Ref;
  GlobalTree[TargetIndex]^.Data := GlobalTree[FirstValue]^.Data;
  GlobalTree.DeleteSubtree(EOT, FirstValue);
  LastValue := TargetIndex;

  while RangeDomainNext(Domain, NextValue) do
  begin
    GlobalTree.LinkRHS(LastValue, NextValue);
    LastValue := NextValue;
  end;
  if TailIndex <> EOT then
    GlobalTree.LinkRHS(LastValue, TailIndex);
end;

procedure ExpandRangeRepeat(
  Context: TContext;
  TargetIndex: Integer;
  TargetPrev: Integer;
  RangeIndex: Integer;
  StepIndex: Integer
);
var
  Src, Dst, Op: Integer;
  Domain: TRangeDomain;
  UseIterator, IteratorBound, FirstIteration, SelectionMode: Boolean;
  IteratorTokenRef, IteratorValueNode: Integer;
  SelectionIndex, SelectionPrev: Integer;
  IterCount: Int64;
  OldLHS, OldRHS: Integer;
begin
  if not TryGetRepeatExpandSource(Context, Src) then
    Exit;
  if not TryBuildRangeDomain(Context, TargetIndex, RangeIndex, StepIndex, Domain) then
    Exit;

  Op := GlobalTree[TargetIndex]^.Data and TK_OPERATOR_MASK;
  UseIterator := TryGetRepeatIteratorToken(Context, IteratorTokenRef);
  SelectionMode := UsesStateSelectionMode(GlobalTree, Src);

  if SelectionMode and (not UseIterator) then
  begin
    IterCount := CountRangeDomain(Domain);
    Dst := ExpandStateSelection(
      GlobalTree, Context, Src, Op, IterCount, CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT
    );
  end
  else
  begin
    GetNode(Src).FixRecursion;
    Dst := GlobalTree.CloneSubtree(Src);
    GetNode(Dst).AppendOperator(Op);
    FirstIteration := True;

    while RangeDomainNext(Domain, IteratorValueNode) do
    begin
      if UseIterator then
        IteratorBound := PushRepeatIteratorValue(Context, IteratorValueNode)
      else
      begin
        GlobalTree.DeleteSubtree(EOT, IteratorValueNode);
        IteratorBound := False;
      end;

      try
        if SelectionMode then
        begin
          NormalizeRepeatIteratorClone(Context, Dst);
          if FindSelectionWithPrev(GlobalTree, Dst, EOT, SelectionIndex, SelectionPrev) then
            nodes.GetNode(SelectionIndex, SelectionPrev).Transform(Context)
          else
            Break;
        end
        else if UseIterator and FirstIteration then
          NormalizeRepeatIteratorClone(Context, Dst)
        else if not FirstIteration then
          GetNode(Dst).Transform(Context);
      finally
        PopRepeatIteratorValue(Context, IteratorBound);
      end;
      FirstIteration := False;
    end;

    if SelectionMode and
       FindSelectionWithPrev(GlobalTree, Dst, EOT, SelectionIndex, SelectionPrev) then
      CleanupSelectionNode(GlobalTree, SelectionIndex, SelectionPrev);
    GetNode(Dst).Complete;
    GetNode(Dst).AppendOperator(Op, True);
  end;

  OldLHS := GlobalTree[TargetIndex]^.LHS;
  OldRHS := GlobalTree[TargetIndex]^.RHS;
  GlobalTree[TargetIndex]^.LHS := EOT;
  GlobalTree[TargetIndex]^.RHS := EOT;
  if OldLHS <> EOT then
    GlobalTree.DeleteSubtree(EOT, OldLHS);
  if OldRHS <> EOT then
    GlobalTree.DeleteSubtree(EOT, OldRHS);
  GlobalTree[TargetIndex]^.LHS := Dst;
  GlobalTree.ExpandInline(TargetPrev, TargetIndex);
end;

{ TRangeNode }

procedure TRangeNode.Evaluate(Context: TContext);
begin
  MaterializeRange(Context, Index, Index, EOT);
end;

procedure TRangeNode.Expand(Context: TContext);
var
  Src: Integer;
begin
  if not TryGetRepeatExpandSource(Context, Src) then
  begin
    inherited Expand(Context);
    Exit;
  end;
  ExpandRangeRepeat(Context, Index, PrevIndex, Index, EOT);
end;

{ TSteppedRangeNode }

procedure TSteppedRangeNode.Evaluate(Context: TContext);
begin
  if (LHS = EOT) or (GlobalTree[LHS]^.Id <> OBJ_RANGE) then
    Exit;
  MaterializeRange(Context, Index, LHS, RHS);
end;

procedure TSteppedRangeNode.Expand(Context: TContext);
var
  Src: Integer;
begin
  if not TryGetRepeatExpandSource(Context, Src) then
  begin
    inherited Expand(Context);
    Exit;
  end;
  if (LHS = EOT) or (GlobalTree[LHS]^.Id <> OBJ_RANGE) then
    Exit;
  ExpandRangeRepeat(Context, Index, PrevIndex, LHS, RHS);
end;

{ TConcatenateNode }

procedure TConcatenateNode.Evaluate(Context: TContext);
var
  Operands: array of Integer;
  OldLHS, OldRHS: Integer;
  Cur: Integer;
  OperandKind: Integer;
  I: Integer;
  Part, ClonedPart: Integer;
  CombinedHead, CombinedLast: Integer;
  CombinedText, PieceText: ansistring;
  IsStringLiteral: Boolean;

  procedure CollectChain(StartIndex: Integer);
  var
    L: Integer;
  begin
    Cur := StartIndex;
    while Cur <> EOT do
    begin
      L := Length(Operands);
      SetLength(Operands, L + 1);
      Operands[L] := Cur;
      Cur := GlobalTree[Cur]^.RHS;
    end;
  end;

  procedure ResetAs(NodeObjectId: Integer);
  begin
    case NodeObjectId of
      OBJ_ARRAY: TArrayNode.InitTreeNode(Index);
      OBJ_EXPRESSION: TExpressionNode.InitTreeNode(Index);
      OBJ_STRING: TStringNode.InitTreeNode(Index);
    end;
  end;

begin
  if LHS <> EOT then
    Node[LHS].Evaluate(Context);
  if RHS <> EOT then
    Node[RHS].Evaluate(Context);

  Operands := nil;
  CollectChain(LHS);
  CollectChain(RHS);
  if Length(Operands) = 0 then
    Exit;

  OperandKind := Node[Operands[0]].ObjectId;
  if (OperandKind <> OBJ_ARRAY) and
     (OperandKind <> OBJ_EXPRESSION) and
     (OperandKind <> OBJ_STRING) then
    Exit;

  OldLHS := LHS;
  OldRHS := RHS;

  if OperandKind = OBJ_STRING then
  begin
    CombinedText := '';
    for I := 0 to High(Operands) do
    begin
      if Node[Operands[I]].ObjectId <> OBJ_STRING then
        Exit;
      IsStringLiteral := UnquoteStringLiteral(Node[Operands[I]].TokenValue, PieceText);
      if not IsStringLiteral then
        Exit;
      CombinedText := CombinedText + PieceText;
    end;

    if OldLHS <> EOT then
      GlobalTree.DeleteSubtree(Index, OldLHS);
    if OldRHS <> EOT then
      GlobalTree.DeleteSubtree(Index, OldRHS);
    ResetAs(OBJ_STRING);
    TreeNode^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(CombinedText));
    Exit;
  end;

  for I := 0 to High(Operands) do
    if Node[Operands[I]].ObjectId <> OperandKind then
      Exit;

  CombinedHead := EOT;
  CombinedLast := EOT;
  for I := 0 to High(Operands) do
  begin
    Part := GlobalTree[Operands[I]]^.LHS;
    if Part = EOT then
      Continue;
    ClonedPart := GlobalTree.CloneSubtree(Part);
    if ClonedPart = EOT then
      Continue;
    if CombinedHead = EOT then
      CombinedHead := ClonedPart
    else
      GlobalTree.LinkRHS(CombinedLast, ClonedPart);
    CombinedLast := GlobalTree.LastSibling[ClonedPart];
  end;

  if OldLHS <> EOT then
    GlobalTree.DeleteSubtree(Index, OldLHS);
  if OldRHS <> EOT then
    GlobalTree.DeleteSubtree(Index, OldRHS);
  ResetAs(OperandKind);
  if CombinedHead <> EOT then
    GlobalTree.LinkLHS(Index, CombinedHead);
end;

{ TInferenceNode }

procedure TInferenceNode.Evaluate(Context: TContext);
var
  QueryIndex: Integer;
  RulesIndex: Integer;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  Holds: Boolean;
  TruthToken: Integer;
  IsEquivalentQuery: Boolean;
  Config: TInferenceConfig;
  EffectiveCongruenceBudget: Integer;
  EffectiveBeamWidth: Integer;
  EffectiveUseCostPolicy: Boolean;
  EffectiveBeamDelta: Integer;
  EffectiveBeamMax: Integer;
  EffectiveProfileSearch: Boolean;
begin
  QueryIndex := LHS;
  RulesIndex := RHS;
  Config.MatchSubexpressions := (TreeNode^.Data and TK_CARET) <> TK_CARET;
  Config.StepLimit := InferenceRewriteMaxSteps;
  if Config.StepLimit < 0 then
    Config.StepLimit := 0;
  ApplyDefaultInferenceOverrides(
    GlobalTree, Context, InferenceCongruenceBudget, InferenceBeamWidth,
    EffectiveCongruenceBudget, EffectiveBeamWidth, EffectiveUseCostPolicy,
    EffectiveBeamDelta, EffectiveBeamMax, EffectiveProfileSearch
  );
  Config.CongruenceBudget := EffectiveCongruenceBudget;
  Config.BeamWidth := EffectiveBeamWidth;
  Config.UseCostPolicy := EffectiveUseCostPolicy;
  Config.BeamDelta := EffectiveBeamDelta;
  Config.BeamMax := EffectiveBeamMax;
  Config.ProfileSearch := EffectiveProfileSearch;
  ResolveInferenceOperands(GlobalTree, Context, Index, QueryIndex, RulesIndex);

  Holds := False;
  if (QueryIndex <> EOT) and (RulesIndex <> EOT) and
     TryExtractInferenceQuery(
       GlobalTree, QueryIndex, SubjectIndex, TargetIndex, IsEquivalentQuery
     ) then
  begin
    NormalizeInferenceQueryOperands(
      GlobalTree, Context, QueryIndex, SubjectIndex, TargetIndex
    );
    Holds := RunDirectionalInference(
      GlobalTree, SubjectIndex, TargetIndex, RulesIndex, Context, Config
    );
    if Holds and IsEquivalentQuery then
      Holds := RunDirectionalInference(
        GlobalTree, TargetIndex, SubjectIndex, RulesIndex, Context, Config
      );
  end;
  if Holds and Assigned(Context) then
    Context.MarkInferenceProgress;

  if LHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, LHS);
    TreeNode^.LHS := EOT;
  end;
  if RHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, RHS);
    TreeNode^.RHS := EOT;
  end;

  TreeNode^.Id := OBJ_INTEGER;
  if Holds then
    TruthToken := GlobalTree.Expression.Append(TK_INTEGER, '1')
  else
    TruthToken := GlobalTree.Expression.Append(TK_INTEGER, '0');
  TreeNode^.Ref := TruthToken;
end;

{ TInferenceWitnessNode }

procedure TInferenceWitnessNode.Evaluate(Context: TContext);
var
  QueryIndex: Integer;
  RulesIndex: Integer;
  SubjectIndex: Integer;
  TargetIndex: Integer;
  IsEquivalentQuery: Boolean;
  WitnessOK: Boolean;
  Config: TInferenceConfig;
  EffectiveCongruenceBudget: Integer;
  EffectiveBeamWidth: Integer;
  EffectiveUseCostPolicy: Boolean;
  EffectiveBeamDelta: Integer;
  EffectiveBeamMax: Integer;
  EffectiveProfileSearch: Boolean;
  WitnessState: TWitnessBuildState;
  WitnessRunInfo: TInferenceRunInfo;
  ReverseRunInfo: TInferenceRunInfo;
  WitnessPrefixBase: ansistring;
  WitnessPrefix: ansistring;
  CountNode: Integer;
  OkNode: Integer;
  PolicyNode: Integer;
  InitialBeamNode: Integer;
  EffectiveBeamNode: Integer;
  AttemptsNode: Integer;

  function CreateIntegerNode(Value: Int64): Integer;
  begin
    Result := GlobalTree.AllocateNode;
    TIntegerNode.InitTreeNode(Result);
    GlobalTree[Result]^.Ref := GlobalTree.Expression.Append(TK_INTEGER, IntToStr(Value));
  end;

  function CreateStringNode(const Value: ansistring): Integer;
  begin
    Result := GlobalTree.AllocateNode;
    TStringNode.InitTreeNode(Result);
    GlobalTree[Result]^.Ref :=
      GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(Value));
  end;

  function InferAssignmentPrefixBase: ansistring;
  var
    AssignLHS: Integer;
  begin
    Result := '';
    if PrevIndex = EOT then
      Exit;
    if Node[PrevIndex].ObjectId <> OBJ_ASSIGNMENT then
      Exit;
    if GlobalTree[PrevIndex]^.RHS <> Index then
      Exit;
    AssignLHS := GlobalTree[PrevIndex]^.LHS;
    if (AssignLHS = EOT) or (Node[AssignLHS].ObjectId <> OBJ_VARIABLE) then
      Exit;
    if GlobalTree[AssignLHS]^.RHS <> EOT then
      Exit;
    Result := Node[AssignLHS].TokenValue;
  end;
begin
  QueryIndex := LHS;
  RulesIndex := RHS;
  Config.MatchSubexpressions := (TreeNode^.Data and TK_CARET) <> TK_CARET;
  Config.StepLimit := InferenceRewriteMaxSteps;
  if Config.StepLimit < 0 then
    Config.StepLimit := 0;
  ApplyDefaultInferenceOverrides(
    GlobalTree, Context, InferenceCongruenceBudget, InferenceBeamWidth,
    EffectiveCongruenceBudget, EffectiveBeamWidth, EffectiveUseCostPolicy,
    EffectiveBeamDelta, EffectiveBeamMax, EffectiveProfileSearch
  );
  Config.CongruenceBudget := EffectiveCongruenceBudget;
  Config.BeamWidth := EffectiveBeamWidth;
  Config.UseCostPolicy := EffectiveUseCostPolicy;
  Config.BeamDelta := EffectiveBeamDelta;
  Config.BeamMax := EffectiveBeamMax;
  Config.ProfileSearch := EffectiveProfileSearch;
  if (EffectiveBeamWidth > 1) and Assigned(Context) and Context.EventEnabled(ellDiag) then
    Context.LogDiag('witness inference currently uses a single-path rewrite trace');
  ResolveInferenceOperands(GlobalTree, Context, Index, QueryIndex, RulesIndex);

  WitnessPrefixBase := InferAssignmentPrefixBase;
  if Assigned(Context) then
    WitnessPrefix := Context.AllocateWitnessPrefix(WitnessPrefixBase)
  else
    WitnessPrefix := '';
  InitWitnessBuildState(WitnessState, Config.MatchSubexpressions, Context, WitnessPrefix);
  if Config.UseCostPolicy then
    WitnessRunInfo.Policy := 'cost'
  else
    WitnessRunInfo.Policy := 'default';
  WitnessRunInfo.InitialBeamWidth := Config.BeamWidth;
  WitnessRunInfo.EffectiveBeamWidth := Config.BeamWidth;
  WitnessRunInfo.Attempts := 0;
  WitnessOK := False;
  if (QueryIndex <> EOT) and (RulesIndex <> EOT) and
     TryExtractInferenceQuery(
       GlobalTree, QueryIndex, SubjectIndex, TargetIndex, IsEquivalentQuery
     ) then
  begin
    NormalizeInferenceQueryOperands(
      GlobalTree, Context, QueryIndex, SubjectIndex, TargetIndex
    );
    WitnessOK := RunDirectionalInference(
      GlobalTree, SubjectIndex, TargetIndex, RulesIndex, Context, Config,
      @InferenceWitnessStepCallback, @WitnessState, @WitnessRunInfo
    );
    if WitnessOK and IsEquivalentQuery then
    begin
      WitnessOK := RunDirectionalInference(
        GlobalTree, TargetIndex, SubjectIndex, RulesIndex, Context, Config,
        @InferenceWitnessStepCallback, @WitnessState, @ReverseRunInfo
      );
      if ReverseRunInfo.EffectiveBeamWidth > WitnessRunInfo.EffectiveBeamWidth then
        WitnessRunInfo.EffectiveBeamWidth := ReverseRunInfo.EffectiveBeamWidth;
      Inc(WitnessRunInfo.Attempts, ReverseRunInfo.Attempts);
    end;
  end;
  if WitnessOK and Assigned(Context) then
    Context.MarkInferenceProgress;

  if Assigned(Context) and (WitnessPrefix <> '') then
  begin
    OkNode := CreateIntegerNode(Ord(WitnessOK));
    CountNode := CreateIntegerNode(WitnessState.StepCount);
    PolicyNode := CreateStringNode(WitnessRunInfo.Policy);
    InitialBeamNode := CreateIntegerNode(WitnessRunInfo.InitialBeamWidth);
    EffectiveBeamNode := CreateIntegerNode(WitnessRunInfo.EffectiveBeamWidth);
    AttemptsNode := CreateIntegerNode(WitnessRunInfo.Attempts);
    Context.AddVariable(WitnessPrefix + '.ok', OkNode);
    Context.AddVariable(WitnessPrefix + '.count', CountNode);
    Context.AddVariable(WitnessPrefix + '.policy', PolicyNode);
    Context.AddVariable(WitnessPrefix + '.initial_beam', InitialBeamNode);
    Context.AddVariable(WitnessPrefix + '.effective_beam', EffectiveBeamNode);
    Context.AddVariable(WitnessPrefix + '.attempts', AttemptsNode);
  end;
  ClearWitnessBuildState(GlobalTree, WitnessState);

  if LHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, LHS);
    TreeNode^.LHS := EOT;
  end;
  if RHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, RHS);
    TreeNode^.RHS := EOT;
  end;

  TStringNode.InitTreeNode(Index);
  TreeNode^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(WitnessPrefix));
end;

// function TBaseNode.Compute: Complex;
// begin
//   if RHS <> EOT then
//     Result := ComputeBinary(FloatValue, Node[RHS]^.Compute, GetOperatorID, Node[RHS]^.GetOperatorId)
//   else
//     Result := ComputeUnitary(FloatValue, GetOperatorID);
// end;

// function TBaseNode.FloatValue: Complex;
// begin
//   Assert(LHS <> EOT);
//   Result := Node[LHS]^.Compute;
// end;

// function TBaseNode.Computable: Boolean;
// begin
//   // Q : last item in comma-separated list (RHS = EOT) ?
//   Result := TokenID and TK_OPERATOR_MASK <> 0; //& or (RHS = EOT);
//   //if LHS <> EOT then Result := Result and Node[LHS]^.Computable;
//   //if RHS <> EOT then Result := Result and Node[RHS]^.Computable;
// end;


// function TBaseNode.ComputeTree: Boolean;
// var
//   L, R: Boolean;

//   procedure ComputeSubtree(Index: Integer);
//   var
//     P: PBaseNode;
//     V: Complex;
//   begin
//     P := Node[Index];
//     V := P^.Compute;

//     case NumberType(V) of
//       TK_COMPLEX:
//         begin
//           P^.VMT := TComplexNode.RealVMT;
//           P^.Token := AddToken(TK_COMPLEX, ComplexToString(V));
//         end;
//       TK_FLOAT:
//         begin
//           P^.VMT := TFloatNode.RealVMT;
//           P^.Token := AddToken(TK_FLOAT, FloatToStr(V.Re));
//         end;
//       TK_INTEGER:
//         begin
//           P^.VMT := TIntegerNode.RealVMT;
//           P^.Token := AddToken(TK_INTEGER, IntToStr(Round(V.Re)));
//         end;
//     end;

//     if P^.LHS <> EOT then Tree.DeleteSubtree(P^.LHS);
//     if P^.RHS <> EOT then Tree.DeleteSubtree(P^.RHS);
//     P^.TreeNode^.LHS := EOT;
//     P^.TreeNode^.RHS := EOT;
//   end;

//   procedure ExpandParenthesis;
//   var
//     Op: Integer;
//   begin
//     // ( 123 )  ( 123, )
//     if (LHS <> EOT) and ExpandScope then
//     begin
//       if Tree[LHS]^.Next = EOT then
//       begin
//         Op := TokenID and TK_OPERATOR_MASK;
//         Tree.ExpandInline(NodeIndex);
//         AppendOperator(Op);
//       end;
//     end;
//   end;

// begin
//   // N: unitary paragraphs or separators (,) are expanded
//   // ( 123 ) -> 123

// {$IFDEF DEBUG_COMPUTATIONS}
//   WriteLn('> ' + TreeValue);
// {$ENDIF}
//   R := (RHS = EOT) or Node[RHS]^.ComputeTree;
//   L := (LHS = EOT) or Node[LHS]^.ComputeTree;
//   ExpandParenthesis;
//   L := (LHS = EOT) or L;

//   Result := (L and R) and Computable;

// {$IFDEF DEBUG_COMPUTATIONS}
//   WriteLn('>> ' + TreeValue);
// {$ENDIF}
//   //if (not Computable) then
//   if Result then
//   begin
//     //if L and (LHS <> EOT) then ComputeSubtree(LHS);
//     //if R and (RHS <> EOT) then ComputeSubtree(RHS);
//     ComputeSubtree(NodeIndex);
//   end
//   else
//   if Computable then
//   begin
//     WriteLn('~~~ = ' + TreeValue);
//   end;

// {$IFDEF DEBUG_COMPUTATIONS}
//   WriteTree;
// {$ENDIF}
// end;


{ TIteratorBindingNode }

procedure TIteratorBindingNode.Evaluate(Context: TContext);
begin
  if LHS <> EOT then
    Node[LHS].Evaluate(Context);

  if PrevIndex = EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else if LHS <> EOT then
    GlobalTree.Expand(PrevIndex, Index)
  else
    Delete;
end;

procedure TIteratorBindingNode.Expand(Context: TContext);
begin
  if LHS <> EOT then
    Node[LHS].Expand(Context);

  if PrevIndex = EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else if LHS <> EOT then
    GlobalTree.Expand(PrevIndex, Index)
  else
    Delete;
end;

{ TIndexLookupNode }

procedure TIndexLookupNode.Evaluate(Context: TContext);
var
  ValueIndex: Integer;
  IndexIndex: Integer;
  RangeStartIndex: Integer;
  RangeEndIndex: Integer;
  CurrentIndex: Integer;
  SelectedIndex: Integer;
  SelectedClone: Integer;
  SliceContainer: Integer;
  SliceLast: Integer;
  ItemCount: Integer;
  RequestedIndex: Int64;
  RangeStart: Int64;
  RangeEnd: Int64;
  RangePosition: Int64;
  RangeStep: Int64;
  IndexOp: Integer;
  ItemIndices: array of Integer;

  function ReadSliceEndpoint(NodeIndex: Integer; const EndpointName: ansistring): Int64;
  var
    EndpointOp: Integer;
  begin
    if Node[NodeIndex].ObjectId <> OBJ_INTEGER then
      raise Exception.CreateFmt(
        'slice %s must be an integer, got %s',
        [EndpointName, Node[NodeIndex].TreeValue]
      );

    TIntegerNode(Node[NodeIndex]).GetValue(Result);
    EndpointOp := GlobalTree[NodeIndex]^.Data and TK_OPERATOR_MASK;
    if (EndpointOp and TK_MINUS) = TK_MINUS then
      Result := -Result
    else if (EndpointOp <> 0) and (EndpointOp <> TK_PLUS) then
      raise Exception.CreateFmt(
        'slice %s must be an integer, got %s',
        [EndpointName, Node[NodeIndex].TreeValue]
      );

    if Result <= 0 then
      raise Exception.CreateFmt(
        'slice %s must be greater than zero, got %d',
        [EndpointName, Result]
      );
  end;

begin
  if LHS = EOT then
    raise Exception.Create('indexed lookup is missing a value');
  if RHS = EOT then
    raise Exception.Create('indexed lookup is missing an index');

  Node[LHS].Evaluate(Context);
  if Node[RHS].ObjectId = OBJ_RANGE then
  begin
    RangeStartIndex := GlobalTree[RHS]^.LHS;
    RangeEndIndex := GlobalTree[RHS]^.RHS;
    if RangeStartIndex = EOT then
      raise Exception.Create('slice is missing a start index');
    if RangeEndIndex = EOT then
      raise Exception.Create('slice is missing an end index');

    nodes.GetNode(RangeStartIndex, RHS).Evaluate(Context);
    RangeStartIndex := GlobalTree[RHS]^.LHS;
    RangeEndIndex := GlobalTree[RHS]^.RHS;
    if RangeStartIndex = EOT then
      raise Exception.Create('slice start evaluated to an empty result');
    if RangeEndIndex = EOT then
      raise Exception.Create('slice end evaluated to an empty result');
    nodes.GetNode(RangeEndIndex, RHS).Evaluate(Context);
    RangeStartIndex := GlobalTree[RHS]^.LHS;
    RangeEndIndex := GlobalTree[RHS]^.RHS;
    if RangeStartIndex = EOT then
      raise Exception.Create('slice start evaluated to an empty result');
    if RangeEndIndex = EOT then
      raise Exception.Create('slice end evaluated to an empty result');
  end
  else
    Node[RHS].Evaluate(Context);

  ValueIndex := LHS;
  IndexIndex := RHS;
  if ValueIndex = EOT then
    raise Exception.Create('indexed lookup value evaluated to an empty result');
  if IndexIndex = EOT then
    raise Exception.Create('indexed lookup index evaluated to an empty result');

  // Unresolved operands remain symbolic and may become concrete after a later
  // substitution or rewrite.
  if (Node[ValueIndex].ObjectId = OBJ_VARIABLE) or
     (Node[IndexIndex].FindObject(OBJ_VARIABLE) <> EOT) then
    Exit;

  if Node[IndexIndex].ObjectId = OBJ_RANGE then
  begin
    if (Node[ValueIndex].ObjectId <> OBJ_ARRAY) and
       (Node[ValueIndex].ObjectId <> OBJ_EXPRESSION) then
      raise Exception.CreateFmt(
        'value is not indexable: %s',
        [Node[ValueIndex].TreeValue]
      );

    RangeStartIndex := GlobalTree[IndexIndex]^.LHS;
    RangeEndIndex := GlobalTree[IndexIndex]^.RHS;
    if GlobalTree[RangeStartIndex]^.RHS <> EOT then
      raise Exception.CreateFmt(
        'slice start must evaluate to one integer, got %s',
        [Node[RangeStartIndex].TreeValue]
      );
    if GlobalTree[RangeEndIndex]^.RHS <> EOT then
      raise Exception.CreateFmt(
        'slice end must evaluate to one integer, got %s',
        [Node[RangeEndIndex].TreeValue]
      );
    RangeStart := ReadSliceEndpoint(RangeStartIndex, 'start');
    RangeEnd := ReadSliceEndpoint(RangeEndIndex, 'end');

    CurrentIndex := GlobalTree[ValueIndex]^.LHS;
    ItemCount := 0;
    while CurrentIndex <> EOT do
    begin
      Inc(ItemCount);
      CurrentIndex := GlobalTree[CurrentIndex]^.RHS;
    end;
    SetLength(ItemIndices, ItemCount);
    CurrentIndex := GlobalTree[ValueIndex]^.LHS;
    ItemCount := 0;
    while CurrentIndex <> EOT do
    begin
      ItemIndices[ItemCount] := CurrentIndex;
      Inc(ItemCount);
      CurrentIndex := GlobalTree[CurrentIndex]^.RHS;
    end;

    if RangeStart > ItemCount then
      raise Exception.CreateFmt(
        'slice start %d is out of bounds for value with %d items',
        [RangeStart, ItemCount]
      );
    if RangeEnd > ItemCount then
      raise Exception.CreateFmt(
        'slice end %d is out of bounds for value with %d items',
        [RangeEnd, ItemCount]
      );

    SliceContainer := GlobalTree.AllocateNode;
    case Node[ValueIndex].ObjectId of
      OBJ_ARRAY: TArrayNode.InitTreeNode(SliceContainer);
      OBJ_EXPRESSION: TExpressionNode.InitTreeNode(SliceContainer);
    end;

    SliceLast := EOT;
    if RangeStart <= RangeEnd then
      RangeStep := 1
    else
      RangeStep := -1;
    RangePosition := RangeStart;
    while True do
    begin
      SelectedClone := GlobalTree.CloneLHS(
        ItemIndices[Integer(RangePosition) - 1]
      );
      if SliceLast = EOT then
        GlobalTree.LinkLHS(SliceContainer, SelectedClone)
      else
        GlobalTree.LinkRHS(SliceLast, SelectedClone);
      SliceLast := SelectedClone;

      if RangePosition = RangeEnd then
        Break;
      Inc(RangePosition, RangeStep);
    end;

    ValueIndex := LHS;
    IndexIndex := RHS;
    TreeNode^.LHS := EOT;
    TreeNode^.RHS := EOT;
    GlobalTree.DeleteSubtree(EOT, ValueIndex);
    GlobalTree.DeleteSubtree(EOT, IndexIndex);
    GlobalTree.LinkLHS(Index, SliceContainer);
    GlobalTree.ExpandInline(PrevIndex, Index);
    Exit;
  end;

  if Node[IndexIndex].ObjectId <> OBJ_INTEGER then
    raise Exception.CreateFmt(
      'index must be an integer, got %s',
      [Node[IndexIndex].TreeValue]
    );

  TIntegerNode(Node[IndexIndex]).GetValue(RequestedIndex);
  IndexOp := GlobalTree[IndexIndex]^.Data and TK_OPERATOR_MASK;
  if (IndexOp and TK_MINUS) = TK_MINUS then
    RequestedIndex := -RequestedIndex
  else if (IndexOp <> 0) and (IndexOp <> TK_PLUS) then
    raise Exception.CreateFmt(
      'index must be an integer, got %s',
      [Node[IndexIndex].TreeValue]
    );

  if RequestedIndex <= 0 then
    raise Exception.CreateFmt(
      'index must be greater than zero, got %d',
      [RequestedIndex]
    );

  if (Node[ValueIndex].ObjectId <> OBJ_ARRAY) and
     (Node[ValueIndex].ObjectId <> OBJ_EXPRESSION) then
    raise Exception.CreateFmt(
      'value is not indexable: %s',
      [Node[ValueIndex].TreeValue]
    );

  CurrentIndex := GlobalTree[ValueIndex]^.LHS;
  SelectedIndex := EOT;
  ItemCount := 0;
  while CurrentIndex <> EOT do
  begin
    Inc(ItemCount);
    if ItemCount = RequestedIndex then
      SelectedIndex := CurrentIndex;
    CurrentIndex := GlobalTree[CurrentIndex]^.RHS;
  end;

  if SelectedIndex = EOT then
    raise Exception.CreateFmt(
      'index %d is out of bounds for value with %d items',
      [RequestedIndex, ItemCount]
    );

  SelectedClone := GlobalTree.CloneLHS(SelectedIndex);

  ValueIndex := LHS;
  IndexIndex := RHS;
  TreeNode^.LHS := EOT;
  TreeNode^.RHS := EOT;
  GlobalTree.DeleteSubtree(EOT, ValueIndex);
  GlobalTree.DeleteSubtree(EOT, IndexIndex);
  GlobalTree.LinkLHS(Index, SelectedClone);
  GlobalTree.ExpandInline(PrevIndex, Index);
end;

(*
// ( X < ( Y < Z ) )
// X | x . y => x < y ...

// <^ X Y Z     ==   ^ ( < X Y ) ( < Y Z )   ???
// <^, <=^, >^, >=^
// <|, <=|, >|, >=|
//

object SORT {}

namespace SORT {
 merge X Y     =>  merge [ ( X | .x ) < ( Y | .y ) ? x. y. ]
 merge X       =>  X
}


  selector merge default/sequential/random/min/max/LHS-len/RHS-len;

  RULE DEFINITIONS:
  selector MERGE DEFAULT;
  direction MERGE

  rule merge 0.3 { merge X Y  =>  merge [ < X|.x , Y|.y ? x. y. ] }
  rule merge 0.3 { merge X Y  =>  merge [ < X|.x , Y|.y ? x. y. ] }
  rule merge 0.7 { merge X    =>  X }

  rule [weight] definition

  selector SIMPLIFY MINIMIZE;
  direction SIMPLIFY MINIMIZE;
  rule SIMPLIFY { * x x    ==  sqr x }
  rule SIMPLIFY { + a:n    ==  * a n }
  rule SIMPLIFY { ( + m )  ==  m     }

  X => SIMPLIFY     [ "transform by transform(s)" ]

  merge [ 3 7 8 11 ] [ 2 5 9 13 ]

 // match scopes (for X and Y)

 msort X       =>  X | x y => ~ merge [ x ] [ y ] ...
*)
(*
  x , y , z | [ 'x' => x , y => y , z => z ]
  x , y , z ? [ 'x' => x , y => y , z => z ]

  0. Expand LHS patterns into subexpressions (search)
  1. Iterate through LHS subexpressions
  2. Iterate through selected subexpression
  3. Find all matching indices/patterns (transforms)*

     Context.ClearPatterns;
     for each transformation (recurse):
       if Match(Index, Pattern) then
         Context.AddPattern(Pattern);

  4. Select one or more (first/last matching, shortest/longest matching)
  5. Advance according to transformation rule
*)

{ TRepeatNode }

procedure TRepeatNode.Transform(Context: TContext);
begin
end;

procedure TRepeatNode.Evaluate(Context: TContext);
var
  VariableIndex, VariablePrev: Integer;
  InferenceSteps: Integer;
  PrevInferenceSteps: Integer;
  PrevData: Pointer;
  RepeatExpandContext: TRepeatExpandContext;
  IteratorDriverIndex: Integer;
  IteratorTokenRef: Integer;
begin
  // WriteLn('- TRepeatNode.Evaluate;');

  // 1:5
  // 1 = LHS = replace
  // 5 = RHS = subject (to be "expanded")

  // all integers in 'subject' are replaced by 'replace' value
  Assert(LHS <> EOT);
  Assert(RHS <> EOT);

  // Special form:
  //   <query> |= <rules> : <n>
  // interpreted as bounded inference with max depth <n>.
  if (Node[LHS].FindObject(OBJ_INFERENCE) <> EOT) or
     (Node[LHS].FindObject(OBJ_INFERENCE_WITNESS) <> EOT) then
  begin
    while (RHS <> EOT) and
          FindResolvableVariableWithPrev(
            GlobalTree, Context, RHS, Index, OBJ_VARIABLE, VariableIndex, VariablePrev
          ) do
      if not ResolveVariableNode(GlobalTree, Context, VariableIndex, VariablePrev, vrmAuto) then
        Break;

    if RHS <> EOT then
      Node[RHS].Evaluate(Context);

    InferenceSteps := 0;
    if (RHS <> EOT) and (Node[RHS].ObjectId = OBJ_INTEGER) then
      InferenceSteps := StrToIntDef(Node[RHS].TokenValue, 0);
    if InferenceSteps < 0 then
      InferenceSteps := 0;

    PrevInferenceSteps := InferenceRewriteMaxSteps;
    InferenceRewriteMaxSteps := InferenceSteps;
    try
      Node[LHS].Evaluate(Context);
    finally
      InferenceRewriteMaxSteps := PrevInferenceSteps;
    end;

    if RHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, RHS);
      TreeNode^.RHS := EOT;
    end;

    if LHS <> EOT then
    begin
      if PrevIndex = EOT then
        GlobalTree.ExpandInline(PrevIndex, Index)
      else
        GlobalTree.Expand(PrevIndex, Index);
    end
    else
      Delete;
    Exit;
  end;

  //WriteLn('1> ', Node[LHS]^.TreeValue);
  if (Node[LHS].FindObject(OBJ_SELECTION) = EOT) and
     (Node[LHS].FindObject(OBJ_INLINE_SELECTION) = EOT) then
    Node[LHS].Evaluate(Context);
  //WriteLn('2> ', Node[LHS]^.TreeValue);

  if not ResolveRepeatDriver(Context, Index, RHS, IteratorDriverIndex, IteratorTokenRef) then
    Exit;

  RepeatExpandContext.SourceIndex := TreeNode^.LHS;
  RepeatExpandContext.IteratorTokenRef := IteratorTokenRef;
  PrevData := Context.Data;
  Context.Data := @RepeatExpandContext;
  try
    Node[RHS].Expand(Context);
  finally
    Context.Data := PrevData;
  end;

  // Evaluate the expanded result once, preserving existing "compute on next iteration"
  // behavior used by repeat fixtures.
  Node[RHS].Evaluate(Context);

  //! Node[RHS]^.AfterEvaluate(Context);

  // do not compute LHS in AfterEvaluate
  Node[LHS].Delete;
  TreeNode^.LHS := EOT;

  //! AfterEvaluate(Context);

  //if TokenID and TK_TILDE = TK_TILDE then
  //  ComputeTree;

  // Delete self + LHS, but keep RHS.
  Delete;
end;

{ TSelectionNode }

procedure TTransformationNode.Evaluate(Context: TContext);
begin
  // Keep transformation templates unevaluated (both LHS and RHS).
  // This preserves matcher-pattern semantics (e.g. range predicates)
  // and defers any evaluation to explicit rewrite/guard handling.
end;

procedure TSelectionNode.Execute(Context: TContext);
begin
  Evaluate(Context);
end;

procedure TStagedRepeatNode.Transform(Context: TContext);
begin
end;

procedure TStagedRepeatNode.Evaluate(Context: TContext);
var
  DriverIndex: Integer;
  IteratorTokenRef: Integer;
  ResultHead, ResultTail: Integer;
  SequenceNode, SequenceItem, IteratorValueNode: Integer;
  RangeIndex, StepIndex: Integer;
  Domain: TRangeDomain;
  LimitValue: Int64;
  CurrentInt: Int64;

  function EvaluateDetachedStageItem(IteratorValueNode: Integer = EOT): Integer;
  var
    WorkingIndex: Integer;
    WrapperIndex: Integer;
    IteratorBound: Boolean;
  begin
    Result := EOT;
    WorkingIndex := GlobalTree.CloneSubtree(LHS);
    if WorkingIndex = EOT then
      Exit;

    WrapperIndex := GlobalTree.AllocateNode;
    TSeparatorNode.InitTreeNode(WrapperIndex);
    GlobalTree.LinkLHS(WrapperIndex, WorkingIndex);

    if IteratorTokenRef <> EOT then
      IteratorBound := PushIteratorValueByToken(Context, IteratorTokenRef, IteratorValueNode)
    else
      IteratorBound := False;
    try
      nodes.GetNode(WorkingIndex, WrapperIndex).Evaluate(Context);
    finally
      PopRepeatIteratorValue(Context, IteratorBound);
    end;

    Result := GlobalTree[WrapperIndex]^.LHS;
    GlobalTree[WrapperIndex]^.LHS := EOT;
    GlobalTree.DeleteSubtree(EOT, WrapperIndex);
  end;

  function FindSiblingTail(HeadIndex: Integer): Integer;
  begin
    Result := HeadIndex;
    while (Result <> EOT) and (GlobalTree[Result]^.RHS <> EOT) do
      Result := GlobalTree[Result]^.RHS;
  end;

  procedure AppendStageResult(HeadIndex: Integer);
  var
    TailIndex: Integer;
  begin
    if HeadIndex = EOT then
      Exit;
    TailIndex := FindSiblingTail(HeadIndex);
    if ResultHead = EOT then
    begin
      ResultHead := HeadIndex;
      ResultTail := TailIndex;
    end
    else
    begin
      GlobalTree.LinkRHS(ResultTail, HeadIndex);
      ResultTail := TailIndex;
    end;
  end;

  procedure FinalizeStageResult;
  begin
    if LHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, LHS);
      TreeNode^.LHS := EOT;
    end;
    if RHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, RHS);
      TreeNode^.RHS := EOT;
    end;

    if ResultHead <> EOT then
    begin
      TreeNode^.LHS := ResultHead;
      if PrevIndex = EOT then
        GlobalTree.ExpandInline(PrevIndex, Index)
      else
        GlobalTree.Expand(PrevIndex, Index);
    end
    else if PrevIndex = EOT then
      GlobalTree.ExpandInline(PrevIndex, Index)
    else
      Delete;
  end;
begin
  Assert(LHS <> EOT);
  Assert(RHS <> EOT);

  if not ResolveRepeatDriver(Context, Index, RHS, DriverIndex, IteratorTokenRef) then
    Exit;

  ResultHead := EOT;
  ResultTail := EOT;

  if (Node[DriverIndex].ObjectId = OBJ_ARRAY) or
     (Node[DriverIndex].ObjectId = OBJ_EXPRESSION) then
  begin
    SequenceNode := GlobalTree[DriverIndex]^.LHS;
    while SequenceNode <> EOT do
    begin
      if GlobalTree[SequenceNode]^.Id = OBJ_SEPARATOR then
        SequenceItem := GlobalTree[SequenceNode]^.LHS
      else
        SequenceItem := SequenceNode;

      if IteratorTokenRef <> EOT then
      begin
        if GlobalTree[SequenceNode]^.Id = OBJ_SEPARATOR then
          IteratorValueNode := GlobalTree.CloneSubtree(SequenceItem)
        else
          IteratorValueNode := GlobalTree.CloneLHS(SequenceItem);
        AppendStageResult(EvaluateDetachedStageItem(IteratorValueNode));
      end
      else
        AppendStageResult(EvaluateDetachedStageItem);

      SequenceNode := GlobalTree[SequenceNode]^.RHS;
    end;

    FinalizeStageResult;
    Exit;
  end;

  if Node[DriverIndex].ObjectId = OBJ_INTEGER then
  begin
    if not TryStrToInt64(Node[DriverIndex].TokenValue, LimitValue) then
      Exit;
    if LimitValue <= 0 then
    begin
      FinalizeStageResult;
      Exit;
    end;

    CurrentInt := 1;
    while CurrentInt <= LimitValue do
    begin
      if IteratorTokenRef <> EOT then
        AppendStageResult(EvaluateDetachedStageItem(CreateDetachedIntegerNode(CurrentInt)))
      else
        AppendStageResult(EvaluateDetachedStageItem);
      Inc(CurrentInt);
    end;

    FinalizeStageResult;
    Exit;
  end;

  if (Node[DriverIndex].ObjectId = OBJ_RANGE) or
     (Node[DriverIndex].ObjectId = OBJ_STEPPED_RANGE) then
  begin
    if Node[DriverIndex].ObjectId = OBJ_STEPPED_RANGE then
    begin
      RangeIndex := GlobalTree[DriverIndex]^.LHS;
      StepIndex := GlobalTree[DriverIndex]^.RHS;
    end
    else
    begin
      RangeIndex := DriverIndex;
      StepIndex := EOT;
    end;

    if not TryBuildRangeDomain(Context, DriverIndex, RangeIndex, StepIndex, Domain) then
      Exit;
    while RangeDomainNext(Domain, IteratorValueNode) do
    begin
      if IteratorTokenRef <> EOT then
        AppendStageResult(EvaluateDetachedStageItem(IteratorValueNode))
      else
      begin
        GlobalTree.DeleteSubtree(EOT, IteratorValueNode);
        AppendStageResult(EvaluateDetachedStageItem);
      end;
    end;
    FinalizeStageResult;
    Exit;
  end;
end;

procedure TSelectionNode.Evaluate(Context: TContext);
var
  Rewritten: Integer;
  MatchSubexpressions: Boolean;
begin
  MatchSubexpressions := (TreeNode^.Data and TK_CARET) <> TK_CARET;

  if LHS <> EOT then
    Node[LHS].Evaluate(Context);
  if (LHS <> EOT) and Assigned(Context) then
    NormalizeResolvableVariables(GlobalTree, Context, LHS, Index);
  while (RHS <> EOT) and (Node[RHS].ObjectId = OBJ_VARIABLE) do
    if not ResolveVariableNode(GlobalTree, Context, RHS, Index, vrmAuto) then
      Break;

  if (LHS <> EOT) and (RHS <> EOT) then
  begin
    if RewriteOneByRules(
         GlobalTree, LHS, RHS, Context, Rewritten, MatchSubexpressions, False
       ) then
    begin
      if Assigned(Context) then
        Context.MarkSelectionProgress;
      if not MatchSubexpressions then
        GlobalTree.DeleteSubtree(Index, LHS);
      TreeNode^.LHS := Rewritten;
    end;
  end;

  if RHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, RHS);
    TreeNode^.RHS := EOT;
  end;

  if LHS <> EOT then
  begin
    if PrevIndex = EOT then
      GlobalTree.ExpandInline(PrevIndex, Index)
    else
      GlobalTree.Expand(PrevIndex, Index);
  end
  else
  begin
    if PrevIndex = EOT then
      GlobalTree.ExpandInline(PrevIndex, Index)
    else
      Delete;
  end;
end;

procedure TSelectionNode.Transform(Context: TContext);
var
  Rewritten: Integer;
  RewrittenStep: Boolean;
  MatchSubexpressions: Boolean;
begin
  MatchSubexpressions := (TreeNode^.Data and TK_CARET) <> TK_CARET;

  if LHS <> EOT then
    Node[LHS].Evaluate(Context);
  if (LHS <> EOT) and Assigned(Context) then
    NormalizeResolvableVariables(GlobalTree, Context, LHS, Index);
  while (RHS <> EOT) and (Node[RHS].ObjectId = OBJ_VARIABLE) do
    if not ResolveVariableNode(GlobalTree, Context, RHS, Index, vrmAuto) then
      Break;

  RewrittenStep := False;
  if (LHS <> EOT) and (RHS <> EOT) then
  begin
    if RewriteOneByRules(
         GlobalTree, LHS, RHS, Context, Rewritten, MatchSubexpressions, False
       ) then
    begin
      if Assigned(Context) then
        Context.MarkSelectionProgress;
      if not MatchSubexpressions then
        GlobalTree.DeleteSubtree(Index, LHS);
      TreeNode^.LHS := Rewritten;
      RewrittenStep := True;
    end;
  end;

  if CLEANUP_SELECTION_ON_STALL and (not RewrittenStep) then
  begin
    if RHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, RHS);
      TreeNode^.RHS := EOT;
    end;

    if LHS <> EOT then
    begin
      if PrevIndex = EOT then
        GlobalTree.ExpandInline(PrevIndex, Index)
      else
        GlobalTree.Expand(PrevIndex, Index);
    end
    else
    begin
      if PrevIndex = EOT then
        GlobalTree.ExpandInline(PrevIndex, Index)
      else
        Delete;
    end;
  end;
end;

{ TFallbackNode }
procedure TFallbackNode.Evaluate(Context: TContext);
var
  Snapshot: TProgressSnapshot;
  UseRHS: Boolean;
begin
  UseRHS := False;
  if Assigned(Context) then
    Snapshot := Context.GetProgressSnapshot;

  if LHS <> EOT then
    Node[LHS].Evaluate(Context);

  if Assigned(Context) then
    UseRHS := not Context.HasProgressSince(Snapshot);

  if UseRHS then
  begin
    if RHS <> EOT then
      Node[RHS].Evaluate(Context);
    if LHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, LHS);
      TreeNode^.LHS := EOT;
    end;
    if RHS <> EOT then
    begin
      TreeNode^.LHS := RHS;
      TreeNode^.RHS := EOT;
    end;
  end
  else if RHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, RHS);
    TreeNode^.RHS := EOT;
  end;

  if LHS <> EOT then
  begin
    if PrevIndex = EOT then
      GlobalTree.ExpandInline(PrevIndex, Index)
    else
      GlobalTree.Expand(PrevIndex, Index);
  end
  else
  begin
    if PrevIndex = EOT then
      GlobalTree.ExpandInline(PrevIndex, Index)
    else
      Delete;
  end;
end;

{ TAssignmentNode }

procedure TAssignmentNode.Execute(Context: TContext);
var
  Name: ansistring;
  ValueRef: Integer;
  WroteLocal: Boolean;
begin
  Assert(Assigned(Context));
  Assert(LHS <> EOT);
  Assert(RHS <> EOT);

  if Node[LHS].ObjectId <> OBJ_VARIABLE then
    raise Exception.CreateFmt('Invalid assignment target: %s', [Node[LHS].TreeValue]);

  if Node[LHS].RHS <> EOT then
    raise Exception.CreateFmt('Assignment target must be a single variable: %s', [Node[LHS].TreeValue]);

  Name := Node[LHS].TokenValue;
  ValueRef := GlobalTree.CloneSubtree(RHS);
  WroteLocal := Context.TryAddScopedExactVariable(Name, ValueRef);
  if not WroteLocal then
  begin
    Context.AddVariable(Name, ValueRef);
    Context.RemoveCallable(Name);
  end;
end;

procedure TAssignmentNode.Evaluate(Context: TContext);
var
  Name: ansistring;
  ValueRef: Integer;
  WroteLocal: Boolean;
begin
  Assert(Assigned(Context));
  Assert(LHS <> EOT);
  Assert(RHS <> EOT);

  if Node[LHS].ObjectId <> OBJ_VARIABLE then
    raise Exception.CreateFmt('Invalid assignment target: %s', [Node[LHS].TreeValue]);

  if Node[LHS].RHS <> EOT then
    raise Exception.CreateFmt('Assignment target must be a single variable: %s', [Node[LHS].TreeValue]);

  Node[RHS].Evaluate(Context);

  Name := Node[LHS].TokenValue;
  ValueRef := GlobalTree.CloneSubtree(RHS);
  WroteLocal := Context.TryAddScopedExactVariable(Name, ValueRef);
  if not WroteLocal then
  begin
    Context.AddVariable(Name, ValueRef);
    Context.RemoveCallable(Name);
  end;
end;

{ TDeepAssignmentNode }

procedure TDeepAssignmentNode.Execute(Context: TContext);
var
  DstPrefix: ansistring;
  SrcPrefix: ansistring;
  Mode: TVariableTrie.TCopyMode;
  RelationalBits: Integer;
begin
  Assert(Assigned(Context));
  Assert(LHS <> EOT);
  Assert(RHS <> EOT);

  if Node[LHS].ObjectId <> OBJ_VARIABLE then
    raise Exception.CreateFmt('Invalid deep-assignment target: %s', [Node[LHS].TreeValue]);
  if Node[LHS].RHS <> EOT then
    raise Exception.CreateFmt(
      'Deep-assignment target must be a single variable: %s',
      [Node[LHS].TreeValue]
    );

  if Node[RHS].ObjectId <> OBJ_VARIABLE then
    raise Exception.CreateFmt('Invalid deep-assignment source: %s', [Node[RHS].TreeValue]);
  if Node[RHS].RHS <> EOT then
    raise Exception.CreateFmt(
      'Deep-assignment source must be a single variable: %s',
      [Node[RHS].TreeValue]
    );

  RelationalBits := TreeNode^.Data and TK_RELATIONAL_MASK;
  case RelationalBits of
    0: Mode := TVariableTrie.TCopyMode(0);                     // cmReplace (:=)
    TK_RELATIONAL_GT: Mode := TVariableTrie.TCopyMode(1);      // cmMergeOverwrite (>:=)
    TK_RELATIONAL_LT: Mode := TVariableTrie.TCopyMode(2);      // cmMergeKeep (<:=)
    TK_RELATIONAL_NOT: Mode := TVariableTrie.TCopyMode(3);     // cmFailOnConflict (!:=)
  else
    raise Exception.CreateFmt('Invalid deep-assignment mode bits: 0x%x', [RelationalBits]);
  end;

  DstPrefix := Node[LHS].TokenValue;
  SrcPrefix := Node[RHS].TokenValue;
  if not Context.CopyVariableSubtree(SrcPrefix, DstPrefix, Mode) then
    raise Exception.CreateFmt(
      'Deep-assignment failed (%s <- %s)',
      [DstPrefix, SrcPrefix]
    );
  Context.RemoveCallable(DstPrefix);
end;

procedure TDeepAssignmentNode.Evaluate(Context: TContext);
begin
  Execute(Context);
end;

{ TDefineNode }

procedure TDefineNode.Execute(Context: TContext);
  procedure AddKeywords(Index: Integer);
  begin
    if Index = EOT then
      Exit;

    case Node[Index].ObjectId of
      OBJ_VARIABLE, OBJ_STRING:
        Context.AddKeyword(Node[Index].TokenValue);
    end;

    AddKeywords(Node[Index].LHS);
    AddKeywords(Node[Index].RHS);
  end;
begin
  Assert(Assigned(Context));
  AddKeywords(LHS);
  Delete;
end;

procedure TDefineNode.Evaluate(Context: TContext);
begin
  if EvaluationExecutionDepth > 0 then
    Execute(Context);
end;

{ TCallableNode }

procedure TCallableNode.Execute(Context: TContext);
  function IsInternalCallableSymbol(const Name: ansistring): Boolean;
  begin
    Result := (Length(Name) >= 2) and (Name[1] = '_') and (Name[2] = '_');
  end;
  procedure AddCallableSymbols(Index: Integer);
  var
    SymbolName: ansistring;
  begin
    if Index = EOT then
      Exit;

    case Node[Index].ObjectId of
      OBJ_VARIABLE, OBJ_STRING:
        begin
          SymbolName := Node[Index].TokenValue;
          Context.AddKeyword(SymbolName);
          Context.AddCallable(SymbolName);
          if IsInternalCallableSymbol(SymbolName) then
            Context.AddNonBindable(SymbolName);
        end;
    end;

    AddCallableSymbols(Node[Index].LHS);
    AddCallableSymbols(Node[Index].RHS);
  end;
begin
  Assert(Assigned(Context));
  AddCallableSymbols(LHS);
  Delete;
end;

procedure TCallableNode.Evaluate(Context: TContext);
begin
  if EvaluationExecutionDepth > 0 then
    Execute(Context);
end;

{ TRuleNode }

procedure TRuleNode.Execute(Context: TContext);
var
  Name: ansistring;
  RuleRef: Integer;
  DefinitionRef: Integer;
  DefinitionIsScope: Boolean;
begin
  Assert(Assigned(Context));
  Assert(LHS <> EOT);

  if Node[LHS].ObjectId <> OBJ_VARIABLE then
    raise Exception.CreateFmt('Invalid rule name: %s', [Node[LHS].TreeValue]);

  DefinitionRef := RHS;
  if DefinitionRef = EOT then
    DefinitionRef := Node[LHS].RHS;
  if DefinitionRef = EOT then
    raise Exception.CreateFmt('Missing rule definition for "%s"', [Node[LHS].TokenValue]);

  Name := Node[LHS].TokenValue;
  Context.AddKeyword(Name);
  DefinitionIsScope :=
    (GlobalTree[DefinitionRef]^.Id and OBJ_CATEGORY_MASK) = OBJ_SCOPE;
  if DefinitionIsScope then
    RuleRef := GlobalTree.CloneLHS(DefinitionRef)
  else
    RuleRef := GlobalTree.CloneSubtree(DefinitionRef);
  Context.AddVariable(Name, RuleRef);
  Context.AddCallable(Name);
  Context.AddCallableBinding(Name, RuleRef, Name, Context.CurrentNamespace);
end;

procedure TRuleNode.Evaluate(Context: TContext);
var
  DefinitionRef: Integer;
  TailRef: Integer;
  DefinitionIsScope: Boolean;
begin
  if EvaluationExecutionDepth <= 0 then
    Exit;

  DefinitionRef := RHS;
  if (DefinitionRef = EOT) and (LHS <> EOT) then
    DefinitionRef := Node[LHS].RHS;
  DefinitionIsScope := (DefinitionRef <> EOT) and
    ((GlobalTree[DefinitionRef]^.Id and OBJ_CATEGORY_MASK) = OBJ_SCOPE);
  if DefinitionIsScope then
    TailRef := GlobalTree[DefinitionRef]^.RHS
  else
    TailRef := EOT;

  Execute(Context);

  if (DefinitionRef <> EOT) and (TailRef <> EOT) and DefinitionIsScope then
  begin
    GlobalTree[DefinitionRef]^.RHS := EOT;
    GlobalTree.DeleteSubtree(Index, DefinitionRef);
    GlobalTree.LinkRHS(Index, TailRef);
    Node[TailRef].Evaluate(Context);
  end;

  Delete;
end;

{ TAliasNode }

procedure TAliasNode.Execute(Context: TContext);
var
  AssignIndex: Integer;
  AliasVarIndex: Integer;
  TargetIndex: Integer;
  AliasName: ansistring;
  TargetName: ansistring;
  ResolvedName: ansistring;
  RulesIndex: Integer;
  DispatchHead: ansistring;
  NamespacePath: ansistring;

  function PeelTransparentWrappers(NodeIndex: Integer): Integer;
  var
    WrapperKind: Integer;
  begin
    Result := NodeIndex;
    while (Result <> EOT) and
          (GlobalTree[Result]^.RHS = EOT) and
          (GlobalTree[Result]^.LHS <> EOT) do
    begin
      WrapperKind := Node[Result].ObjectId;
      if (WrapperKind <> OBJ_SCOPE) and (WrapperKind <> OBJ_EXPRESSION) then
        Break;
      Result := GlobalTree[Result]^.LHS;
    end;
  end;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  AssignIndex := PeelTransparentWrappers(LHS);
  if (AssignIndex = EOT) or (Node[AssignIndex].ObjectId <> OBJ_ASSIGNMENT) then
    raise Exception.CreateFmt('Invalid alias definition: %s', [TreeValue]);

  AliasVarIndex := GlobalTree[AssignIndex]^.LHS;
  TargetIndex := PeelTransparentWrappers(GlobalTree[AssignIndex]^.RHS);
  if (AliasVarIndex = EOT) or (Node[AliasVarIndex].ObjectId <> OBJ_VARIABLE) or
     (GlobalTree[AliasVarIndex]^.RHS <> EOT) then
    raise Exception.CreateFmt('Invalid alias target name: %s', [Node[AssignIndex].TreeValue]);
  if (TargetIndex = EOT) or (Node[TargetIndex].ObjectId <> OBJ_VARIABLE) or
     (GlobalTree[TargetIndex]^.LHS <> EOT) or (GlobalTree[TargetIndex]^.RHS <> EOT) then
    raise Exception.CreateFmt('Alias target must be a callable name: %s', [Node[AssignIndex].TreeValue]);

  AliasName := Node[AliasVarIndex].TokenValue;
  TargetName := Node[TargetIndex].TokenValue;
  if not Context.TryResolveCallableBinding(
           TargetName, ResolvedName, RulesIndex, DispatchHead, NamespacePath
         ) then
    raise Exception.CreateFmt('Alias target is not a callable binding: %s', [TargetName]);

  if DispatchHead = '' then
    DispatchHead := TargetName;

  Context.AddKeyword(AliasName);
  Context.AddVariable(AliasName, RulesIndex);
  Context.AddCallable(AliasName);
  Context.AddCallableBinding(AliasName, RulesIndex, DispatchHead, NamespacePath);
  Delete;
end;

procedure TAliasNode.Evaluate(Context: TContext);
begin
  Execute(Context);
end;

{ TVariableSubtreeNode }

procedure TVariableSubtreeNode.Evaluate(Context: TContext);
var
  KeyName: ansistring;
  ResolvedIndex: Integer;
begin
  if Assigned(Context) and
     ((TreeNode^.Data and TK_DOLLAR) = TK_DOLLAR) and
     (TreeNode^.Ref <> EOT) then
  begin
    KeyName := GlobalTree.Expression.TokenValue(TreeNode^.Ref);
    if ResolveDollarVariableChainByName(GlobalTree, Context, KeyName, ResolvedIndex) and
       (ResolvedIndex <> EOT) and
       (GlobalTree[ResolvedIndex]^.LHS = EOT) and
       (GlobalTree[ResolvedIndex]^.RHS = EOT) and
       (GlobalTree[ResolvedIndex]^.Ref <> EOT) then
    begin
      TreeNode^.Ref := GlobalTree[ResolvedIndex]^.Ref;
      TreeNode^.Data := TreeNode^.Data and (not TK_DOLLAR);
    end;
  end;

  inherited Evaluate(Context);
end;

function TVariableSubtreeNode.TokenValue(var Config: TFormatConfig): ansistring;
begin
  Result := '';
  if TreeNode^.Ref <> EOT then
    Result := GlobalTree.Expression.TokenValue(TreeNode^.Ref);
  if LHS <> EOT then
    Result := Format('%s -> %s', [Result, Node[LHS].TreeValue(Config)])
  else
    Result := Result + ' ->';
end;

function TVariableSubtreeNode.TreeValue(var Config: TFormatConfig): ansistring;
begin
  Result := TokenValue(Config);
  if RHS <> EOT then
  begin
    if GlobalTree[RHS]^.Id = OBJ_SEPARATOR then
      Result := Result + ' , ' + Node[RHS].TreeValue(Config)
    else
      Result := Result + '  ' + Node[RHS].TreeValue(Config);
  end;
end;

const
  QUERY_PROJECT_KEYS = 0;
  QUERY_PROJECT_VALUES = 1;

function CreateNodeFromTokenRef(TokenRef: Integer): Integer;
var
  TokenId: Integer;
begin
  Result := GlobalTree.AllocateNode;
  TokenId := GlobalTree.Expression.TokenID(TokenRef);
  case TokenId of
    TK_INTEGER: TIntegerNode.InitTreeNode(Result);
    TK_FLOAT: TFloatNode.InitTreeNode(Result);
    TK_COMPLEX: TComplexNode.InitTreeNode(Result);
    TK_STRING: TStringNode.InitTreeNode(Result);
  else
    TVariableNode.InitTreeNode(Result);
  end;
  GlobalTree[Result]^.Ref := TokenRef;
end;

function BuildQueryProjectionSequence(SourceIndex: Integer; Mode: Integer): Integer;
var
  FirstItem: Integer;
  LastItem: Integer;
  Cur: Integer;
  EntryNode: Integer;
  PairNode: Integer;
  ItemNode: Integer;
  ValueNode: Integer;
begin
  FirstItem := EOT;
  LastItem := EOT;

  if (SourceIndex <> EOT) and (GlobalTree[SourceIndex]^.Id = OBJ_ARRAY) then
    Cur := GlobalTree[SourceIndex]^.LHS
  else
    Cur := SourceIndex;

  while Cur <> EOT do
  begin
    if GlobalTree[Cur]^.Id = OBJ_SEPARATOR then
    begin
      EntryNode := GlobalTree[Cur]^.LHS;
      Cur := GlobalTree[Cur]^.RHS;
    end
    else
    begin
      EntryNode := Cur;
      Cur := GlobalTree[Cur]^.RHS;
    end;

    if EntryNode = EOT then
      Continue;

    ItemNode := EOT;
    case GlobalTree[EntryNode]^.Id of
      OBJ_VARIABLE_SUBTREE:
        begin
          if Mode = QUERY_PROJECT_KEYS then
          begin
            if GlobalTree[EntryNode]^.Ref <> EOT then
              ItemNode := CreateNodeFromTokenRef(GlobalTree[EntryNode]^.Ref);
          end
          else
          begin
            ValueNode := GlobalTree[EntryNode]^.LHS;
            if ValueNode <> EOT then
              ItemNode := GlobalTree.CloneSubtree(ValueNode);
          end;
        end;
    end;

    if ItemNode = EOT then
      Continue;

    PairNode := ItemNode;
    if FirstItem = EOT then
      FirstItem := PairNode
    else
      GlobalTree.LinkRHS(LastItem, PairNode);
    LastItem := PairNode;
  end;

  Result := FirstItem;
end;

procedure EvaluateQueryProjectionNode(ANode, APrevIndex, Mode: Integer; Context: TContext);
var
  SourceIndex: Integer;
  ProjectedRoot: Integer;
begin
  if ANode = EOT then
    Exit;

  SourceIndex := GlobalTree[ANode]^.LHS;
  if SourceIndex <> EOT then
  begin
    GetNode(SourceIndex, ANode).Evaluate(Context);
    SourceIndex := GlobalTree[ANode]^.LHS;
  end;

  ProjectedRoot := BuildQueryProjectionSequence(SourceIndex, Mode);
  GlobalTree[ANode]^.LHS := ProjectedRoot;
  if SourceIndex <> EOT then
    GlobalTree.DeleteSubtree(EOT, SourceIndex);
  GlobalTree.ExpandInline(APrevIndex, ANode);
end;

{ TPatternNode }

procedure TPatternNode.Evaluate(Context: TContext);
var
  PatternText: ansistring;
  ResolvedPatternText: ansistring;
  PatternResolved: Boolean;
  Matches: TStringList;
  MatchIndex: Integer;
  MatchName: ansistring;
  MatchValueRef: Integer;
  ArrayNode: Integer;
  FirstPair: Integer;
  LastPair: Integer;
  PairNode: Integer;
  ValueNode: Integer;

  function NormalizeScalarTokenValue(const Value: ansistring): ansistring;
  begin
    Result := Trim(Value);
    if Length(Result) >= 2 then
    begin
      if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
         ((Result[1] = #39) and (Result[Length(Result)] = #39)) then
        Result := Copy(Result, 2, Length(Result) - 2);
    end;
    Result := Trim(Result);
  end;

  function TryResolveDollarPattern(const RawPattern: ansistring; out Resolved: ansistring): Boolean;
  var
    I: Integer;
    HeadName: ansistring;
    TailPattern: ansistring;
    ResolvedIndex: Integer;
    ResolvedHead: ansistring;
  begin
    Result := False;
    Resolved := RawPattern;
    if ((TreeNode^.Data and TK_DOLLAR) <> TK_DOLLAR) or (RawPattern = '') then
      Exit(False);

    I := 1;
    while (I <= Length(RawPattern)) and not (RawPattern[I] in ['.', '[', '*']) do
      Inc(I);
    HeadName := Copy(RawPattern, 1, I - 1);
    TailPattern := Copy(RawPattern, I, MaxInt);

    if HeadName = '' then
      Exit(False);

    if ResolveDollarVariableChainByName(GlobalTree, Context, HeadName, ResolvedIndex) and
       (ResolvedIndex <> EOT) and
       (GlobalTree[ResolvedIndex]^.LHS = EOT) and
       (GlobalTree[ResolvedIndex]^.RHS = EOT) and
       (GlobalTree[ResolvedIndex]^.Ref <> EOT) then
    begin
      ResolvedHead := NormalizeScalarTokenValue(
        GlobalTree.Expression.TokenValue(GlobalTree[ResolvedIndex]^.Ref)
      );
      if ResolvedHead = '' then
        Exit(False);
      Resolved := ResolvedHead + TailPattern;
      Exit(True);
    end;
  end;
begin
  if not Assigned(Context) then
    Exit;

  PatternText := TokenValue;
  if PatternText = '' then
    Exit;
  ResolvedPatternText := PatternText;
  if TryResolveDollarPattern(PatternText, ResolvedPatternText) then
    PatternText := ResolvedPatternText;

  Matches := TStringList.Create;
  try
    Matches.Sorted := True;
    Matches.Duplicates := dupIgnore;
    ResolvedPatternText := PatternText;
    PatternResolved := Context.ResolveIndexedVariablePattern(PatternText, ResolvedPatternText);
    if PatternResolved and (ResolvedPatternText <> '') then
      Context.ScanVariables(ResolvedPatternText, Matches);

    ArrayNode := GlobalTree.AllocateNode;
    TArrayNode.InitTreeNode(ArrayNode);
    GlobalTree[ArrayNode]^.Ref := GlobalTree.Expression.Append(TK_BRACKET_BEGIN, '[');

    FirstPair := EOT;
    LastPair := EOT;
    for MatchIndex := 0 to Matches.Count - 1 do
    begin
      MatchName := Matches[MatchIndex];
      MatchValueRef := PtrInt(Matches.Objects[MatchIndex]);
      if MatchValueRef = EOT then
        Continue;

      PairNode := GlobalTree.AllocateNode;
      TVariableSubtreeNode.InitTreeNode(PairNode);
      GlobalTree[PairNode]^.Ref :=
        GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(MatchName));

      ValueNode := GlobalTree.CloneSubtree(MatchValueRef);
      if ValueNode = EOT then
      begin
        GlobalTree.DeleteSubtree(EOT, PairNode);
        Continue;
      end;

      GlobalTree.LinkLHS(PairNode, ValueNode);
      if FirstPair = EOT then
        FirstPair := PairNode
      else
        GlobalTree.LinkRHS(LastPair, PairNode);
      LastPair := PairNode;
    end;

    if FirstPair <> EOT then
      GlobalTree.LinkLHS(ArrayNode, FirstPair);

    TreeNode^.LHS := ArrayNode;
    GlobalTree.ExpandInline(PrevIndex, Index);
  finally
    Matches.Free;
  end;
end;

{ TQueryKeysNode }

procedure TQueryKeysNode.Evaluate(Context: TContext);
begin
  EvaluateQueryProjectionNode(Index, PrevIndex, QUERY_PROJECT_KEYS, Context);
end;

{ TQueryValuesNode }

procedure TQueryValuesNode.Evaluate(Context: TContext);
begin
  EvaluateQueryProjectionNode(Index, PrevIndex, QUERY_PROJECT_VALUES, Context);
end;

function PeelSingleChildQueryWrappers(NodeIndex: Integer): Integer;
begin
  Result := NodeIndex;
  while (Result <> EOT) and
        ((GlobalTree[Result]^.Id and OBJ_CATEGORY_MASK) = OBJ_SCOPE) and
        (GlobalTree[Result]^.RHS = EOT) and
        (GlobalTree[Result]^.LHS <> EOT) do
    Result := GlobalTree[Result]^.LHS;
end;

function QueryArgumentNeedsEvaluation(NodeIndex: Integer): Boolean;
var
  EffectiveIndex: Integer;
begin
  EffectiveIndex := PeelSingleChildQueryWrappers(NodeIndex);
  if EffectiveIndex = EOT then
    Exit(False);

  case GlobalTree[EffectiveIndex]^.Id of
    OBJ_STRING, OBJ_VARIABLE, OBJ_PATTERN:
      Result := False;
  else
    Result := True;
  end;
end;

function QueryArgumentRawValue(OwnerIndex, NodeIndex: Integer): ansistring;
begin
  if NodeIndex = EOT then
    Exit('');
  case GlobalTree[NodeIndex]^.Id of
    OBJ_STRING, OBJ_VARIABLE, OBJ_PATTERN:
      Result := nodes.GetNode(NodeIndex, OwnerIndex).TokenValue;
  else
    Result := nodes.GetNode(NodeIndex, OwnerIndex).TreeValue;
  end;
end;

function NormalizeQueryArgumentValue(const Value: ansistring): ansistring;
begin
  Result := Trim(Value);
  if Length(Result) >= 2 then
  begin
    if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
       ((Result[1] = #39) and (Result[Length(Result)] = #39)) then
      Result := Copy(Result, 2, Length(Result) - 2);
  end;
  Result := Trim(Result);
end;

function ResolveDollarQueryArgumentNode(
  OwnerIndex: Integer;
  NodeIndex: Integer;
  Context: TContext
): Integer;
var
  VariableNode: TVariableNode;
begin
  Result := NodeIndex;
  if NodeIndex = EOT then
    Exit;
  if GlobalTree[NodeIndex]^.Id <> OBJ_VARIABLE then
    Exit;

  VariableNode := TVariableNode(nodes.GetNode(NodeIndex, OwnerIndex));
  if not VariableNode.TryResolveDollarReference(Context, Result) then
    Result := NodeIndex;
end;

function ResolveQueryArgumentText(
  OwnerIndex: Integer;
  Context: TContext;
  const QueryName: ansistring
): ansistring;
var
  SourceIndex: Integer;
  ArgIndex: Integer;
  EffectiveArgIndex: Integer;
  ResolvedArgIndex: Integer;
  WorkingIndex: Integer;
  WorkingOwnerIndex: Integer;
begin
  SourceIndex := GlobalTree[OwnerIndex]^.LHS;
  if SourceIndex = EOT then
    raise Exception.CreateFmt('%s expects exactly 1 argument', [QueryName]);

  ArgIndex := SourceIndex;
  EffectiveArgIndex := PeelSingleChildQueryWrappers(ArgIndex);
  if (EffectiveArgIndex <> EOT) and
     ((GlobalTree[EffectiveArgIndex]^.Id = OBJ_VARIABLE) or
      (GlobalTree[EffectiveArgIndex]^.Id = OBJ_PATTERN)) and
     (GlobalTree[EffectiveArgIndex]^.LHS = EOT) and
     (GlobalTree[EffectiveArgIndex]^.RHS = EOT) and
     ((GlobalTree[EffectiveArgIndex]^.Data and TK_DOLLAR) <> TK_DOLLAR) then
  begin
    Result := NormalizeQueryArgumentValue(
      QueryArgumentRawValue(OwnerIndex, EffectiveArgIndex)
    );
    Exit;
  end;

  WorkingIndex := SourceIndex;
  WorkingOwnerIndex := OwnerIndex;
  if QueryArgumentNeedsEvaluation(ArgIndex) and (ArgIndex <> EOT) then
  begin
    WorkingIndex := GlobalTree.CloneSubtree(ArgIndex);
    if WorkingIndex = EOT then
      Exit('');
    WorkingOwnerIndex := EOT;
    nodes.GetNode(WorkingIndex, EOT).Evaluate(Context);
  end;

  ResolvedArgIndex := ResolveDollarQueryArgumentNode(WorkingOwnerIndex, WorkingIndex, Context);
  Result := NormalizeQueryArgumentValue(QueryArgumentRawValue(WorkingOwnerIndex, ResolvedArgIndex));

  if (WorkingIndex <> EOT) and (WorkingIndex <> ArgIndex) then
    GlobalTree.DeleteSubtree(EOT, WorkingIndex);
end;

{ TQueryChildrenNode }

procedure TQueryChildrenNode.Evaluate(Context: TContext);
var
  SourceIndex: Integer;
  PrefixText: ansistring;
  ResolvedPrefixText: ansistring;
  Children: TStringList;
  I: Integer;
  ItemNode: Integer;
  FirstItem: Integer;
  LastItem: Integer;
begin
  if not Assigned(Context) then
    Exit;

  SourceIndex := GlobalTree[Index]^.LHS;
  PrefixText := ResolveQueryArgumentText(Index, Context, 'query_children');
  ResolvedPrefixText := PrefixText;
  if Context.ResolveIndexedVariablePattern(PrefixText, ResolvedPrefixText) and
     (ResolvedPrefixText <> '') then
    PrefixText := ResolvedPrefixText;

  Children := TStringList.Create;
  try
    Context.ScanVariableChildren(PrefixText, Children);

    FirstItem := EOT;
    LastItem := EOT;
    for I := 0 to Children.Count - 1 do
    begin
      ItemNode := CreateStringNodeFromText(Children[I]);
      if ItemNode = EOT then
        Continue;
      if FirstItem = EOT then
        FirstItem := ItemNode
      else
        GlobalTree.LinkRHS(LastItem, ItemNode);
      LastItem := ItemNode;
    end;

    TreeNode^.LHS := FirstItem;
    if SourceIndex <> EOT then
      GlobalTree.DeleteSubtree(EOT, SourceIndex);
    GlobalTree.ExpandInline(PrevIndex, Index);
  finally
    Children.Free;
  end;
end;

{ TGetNode }

procedure TGetNode.Evaluate(Context: TContext);
var
  SourceIndex: Integer;
  PathText: ansistring;
  ResolvedPathText: ansistring;
  ValueRef: Integer;
  ValueNode: Integer;
  Matches: TStringList;

  function TryFindValueRef(const Path: ansistring; out Ref: Integer): Boolean;
  var
    I: Integer;
  begin
    Ref := EOT;
    if Path = '' then
      Exit(False);

    if Context.TryFindVariable(Path, Ref) then
      Exit(True);

    Matches := TStringList.Create;
    try
      Context.ScanVariables(Path, Matches);
      for I := 0 to Matches.Count - 1 do
      begin
        if ansistring(Matches[I]) <> Path then
          Continue;
        Ref := PtrInt(Matches.Objects[I]);
        Exit(Ref <> EOT);
      end;
    finally
      Matches.Free;
    end;

    Result := False;
  end;

begin
  if not Assigned(Context) then
    Exit;

  SourceIndex := GlobalTree[Index]^.LHS;
  PathText := ResolveQueryArgumentText(Index, Context, 'get');
  ValueNode := EOT;
  if TryFindValueRef(PathText, ValueRef) then
    ValueNode := GlobalTree.CloneSubtree(ValueRef);
  if (ValueNode = EOT) and (PathText <> '') then
  begin
    ResolvedPathText := PathText;
    if Context.ResolveIndexedVariablePattern(PathText, ResolvedPathText) and
       (ResolvedPathText <> '') and
       (ResolvedPathText <> PathText) and
       TryFindValueRef(ResolvedPathText, ValueRef) then
      ValueNode := GlobalTree.CloneSubtree(ValueRef);
  end;

  TreeNode^.LHS := ValueNode;
  if SourceIndex <> EOT then
    GlobalTree.DeleteSubtree(EOT, SourceIndex);
  GlobalTree.ExpandInline(PrevIndex, Index);
end;

{ TPathSegmentNode }

procedure TPathSegmentNode.Evaluate(Context: TContext);
var
  SourceIndex: Integer;
  ArgNodes: array[0..1] of Integer;
  ArgCount: Integer;
  Cur: Integer;
  EntryNode: Integer;
  PathArgIndex: Integer;
  IndexArgIndex: Integer;
  ResolvedPathArgIndex: Integer;
  PathText: ansistring;
  SegmentNode: Integer;
  SegmentText: ansistring;
  SegmentIndex: Integer;
  SegmentPos: Integer;
  Segments: TStringList;
  SegmentIsIndex: array of Boolean;
  SegmentFromIndex: Boolean;
  SegmentAsInteger: Integer;
  I: Integer;

  function RawNodeValue(NodeIndex: Integer): ansistring;
  begin
    if NodeIndex = EOT then
      Exit('');
    case GlobalTree[NodeIndex]^.Id of
      OBJ_STRING, OBJ_VARIABLE:
        Result := nodes.GetNode(NodeIndex, Index).TokenValue;
    else
      Result := nodes.GetNode(NodeIndex, Index).TreeValue;
    end;
  end;

  function NormalizeValue(const Value: ansistring): ansistring;
  begin
    Result := Trim(Value);
    if Length(Result) >= 2 then
    begin
      if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
         ((Result[1] = #39) and (Result[Length(Result)] = #39)) then
        Result := Copy(Result, 2, Length(Result) - 2);
    end;
    Result := Trim(Result);
  end;

  function ResolveDollarArgumentNode(NodeIndex: Integer): Integer;
  var
    VariableNode: TVariableNode;
  begin
    Result := NodeIndex;
    if NodeIndex = EOT then
      Exit;
    if GlobalTree[NodeIndex]^.Id <> OBJ_VARIABLE then
      Exit;
    VariableNode := TVariableNode(nodes.GetNode(NodeIndex, Index));
    if not VariableNode.TryResolveDollarReference(Context, Result) then
      Result := NodeIndex;
  end;

  function ParseSegmentIndex(NodeIndex: Integer; out Value: Integer): Boolean;
  var
    TextValue: ansistring;
    OpBits: Integer;
    Sign: Integer;
  begin
    Value := 0;
    if NodeIndex = EOT then
      Exit(False);

    if GlobalTree[NodeIndex]^.Id = OBJ_INTEGER then
    begin
      Sign := 1;
      OpBits := GlobalTree[NodeIndex]^.Data and TK_OPERATOR_MASK;
      if OpBits = TK_MINUS then
        Sign := -1;
      TextValue := GlobalTree.Expression.TokenValue(GlobalTree[NodeIndex]^.Ref);
      if TextValue = '' then
        Exit(False);
      Value := Sign * StrToIntDef(TextValue, 0);
      Exit(True);
    end;

    TextValue := NormalizeValue(RawNodeValue(NodeIndex));
    TextValue := StringReplace(TextValue, ' ', '', [rfReplaceAll]);
    if TextValue = '' then
      Exit(False);

    try
      Value := StrToInt(TextValue);
      Result := True;
    except
      Result := False;
    end;
  end;

  procedure SplitPathIntoSegments(const Path: ansistring; OutSegments: TStrings);
  var
    PosIdx: Integer;
    StartIdx: Integer;
    Part: ansistring;
    procedure AddPart(const RawPart: ansistring; IsIndexPart: Boolean);
    var
      P: ansistring;
    begin
      P := Trim(RawPart);
      if P <> '' then
      begin
        OutSegments.Add(P);
        SetLength(SegmentIsIndex, Length(SegmentIsIndex) + 1);
        SegmentIsIndex[High(SegmentIsIndex)] := IsIndexPart;
      end;
    end;
  begin
    OutSegments.Clear;
    SetLength(SegmentIsIndex, 0);
    Part := '';
    PosIdx := 1;
    while PosIdx <= Length(Path) do
    begin
      case Path[PosIdx] of
        '.':
          begin
            AddPart(Part, False);
            Part := '';
            Inc(PosIdx);
          end;
        '[':
          begin
            AddPart(Part, False);
            Part := '';
            Inc(PosIdx); // skip '['
            StartIdx := PosIdx;
            while (PosIdx <= Length(Path)) and (Path[PosIdx] <> ']') do
              Inc(PosIdx);

            if PosIdx <= Length(Path) then
              AddPart(Copy(Path, StartIdx, PosIdx - StartIdx), True)
            else
              AddPart(Copy(Path, StartIdx, MaxInt), True);

            if (PosIdx <= Length(Path)) and (Path[PosIdx] = ']') then
              Inc(PosIdx); // skip ']'
          end;
        ']':
          begin
            // ignore unmatched close bracket
            Inc(PosIdx);
          end;
      else
        begin
          Part := Part + Path[PosIdx];
          Inc(PosIdx);
        end;
      end;
    end;
    AddPart(Part, False);
  end;
begin
  if not Assigned(Context) then
    Exit;

  SourceIndex := GlobalTree[Index]^.LHS;
  ArgCount := 0;
  Cur := SourceIndex;
  while Cur <> EOT do
  begin
    if GlobalTree[Cur]^.Id = OBJ_SEPARATOR then
    begin
      EntryNode := GlobalTree[Cur]^.LHS;
      Cur := GlobalTree[Cur]^.RHS;
    end
    else
    begin
      EntryNode := Cur;
      Cur := GlobalTree[Cur]^.RHS;
    end;

    if EntryNode = EOT then
      Continue;
    if ArgCount < Length(ArgNodes) then
      ArgNodes[ArgCount] := EntryNode;
    Inc(ArgCount);
  end;

  if ArgCount <> 2 then
    raise Exception.Create('path_segment expects exactly 2 arguments: path_segment <path> <index>');

  PathArgIndex := ArgNodes[0];
  IndexArgIndex := ArgNodes[1];

  ResolvedPathArgIndex := PathArgIndex;
  if (PathArgIndex <> EOT) and
     (GlobalTree[PathArgIndex]^.Id = OBJ_VARIABLE) and
     ((GlobalTree[PathArgIndex]^.Data and TK_DOLLAR) = TK_DOLLAR) then
    ResolvedPathArgIndex := ResolveDollarArgumentNode(PathArgIndex);

  PathText := NormalizeValue(RawNodeValue(ResolvedPathArgIndex));
  if not ParseSegmentIndex(IndexArgIndex, SegmentIndex) then
    raise Exception.Create('path_segment index must be an integer');

  SegmentText := '';
  SegmentFromIndex := False;
  Segments := TStringList.Create;
  try
    SplitPathIntoSegments(PathText, Segments);

    if SegmentIndex > 0 then
      SegmentPos := SegmentIndex
    else if SegmentIndex < 0 then
      SegmentPos := Segments.Count + SegmentIndex + 1
    else
      SegmentPos := 0;

    if (SegmentPos >= 1) and (SegmentPos <= Segments.Count) then
    begin
      SegmentText := Segments[SegmentPos - 1]
      ;
      if (SegmentPos - 1 >= 0) and (SegmentPos - 1 < Length(SegmentIsIndex)) then
        SegmentFromIndex := SegmentIsIndex[SegmentPos - 1];
    end
    else
      SegmentText := '';

    // Normalize any accidental empty segment artifacts from delimiters.
    if SegmentText <> '' then
    begin
      I := 1;
      while I <= Length(SegmentText) do
      begin
        if SegmentText[I] <> #0 then
          Break;
        Inc(I);
      end;
      if I > 1 then
        SegmentText := Copy(SegmentText, I, MaxInt);
    end;
  finally
    Segments.Free;
  end;

  if SegmentFromIndex and TryStrToInt(SegmentText, SegmentAsInteger) then
  begin
    SegmentNode := GlobalTree.AllocateNode;
    TIntegerNode.InitTreeNode(SegmentNode);
    GlobalTree[SegmentNode]^.Ref := GlobalTree.Expression.Append(TK_INTEGER, SegmentText);
  end
  else
    SegmentNode := CreateStringNodeFromText(SegmentText);
  TreeNode^.LHS := SegmentNode;
  if SourceIndex <> EOT then
    GlobalTree.DeleteSubtree(EOT, SourceIndex);
  GlobalTree.ExpandInline(PrevIndex, Index);
end;

{ TMakePairNode }

procedure TMakePairNode.Evaluate(Context: TContext);
var
  SourceIndex: Integer;
  ArgNodes: array[0..1] of Integer;
  ArgCount: Integer;
  Cur: Integer;
  EntryNode: Integer;
  KeyArgIndex: Integer;
  ValueArgIndex: Integer;
  KeyRef: Integer;
  KeyData: Integer;
  KeyCandidateIndex: Integer;
  PairNode: Integer;
  ValueClone: Integer;
  function PeelSingleChildWrappers(NodeIndex: Integer): Integer;
  begin
    Result := NodeIndex;
    while (Result <> EOT) and
          ((GlobalTree[Result]^.Id and OBJ_CATEGORY_MASK) = OBJ_SCOPE) and
          (GlobalTree[Result]^.RHS = EOT) and
          (GlobalTree[Result]^.LHS <> EOT) do
      Result := GlobalTree[Result]^.LHS;
  end;

  function TryExtractAtomicKeyRef(NodeIndex: Integer; out AKeyRef: Integer; out AKeyData: Integer): Boolean;
  begin
    Result := False;
    AKeyRef := EOT;
    AKeyData := 0;
    NodeIndex := PeelSingleChildWrappers(NodeIndex);
    if NodeIndex = EOT then
      Exit(False);
    if (GlobalTree[NodeIndex]^.LHS <> EOT) or (GlobalTree[NodeIndex]^.RHS <> EOT) then
      Exit(False);
    if GlobalTree[NodeIndex]^.Ref = EOT then
      Exit(False);
    AKeyRef := GlobalTree[NodeIndex]^.Ref;
    AKeyData := GlobalTree[NodeIndex]^.Data;
    Result := True;
  end;
begin
  if not Assigned(Context) then
    Exit;

  SourceIndex := GlobalTree[Index]^.LHS;
  if SourceIndex <> EOT then
    Node[SourceIndex].Evaluate(Context);
  SourceIndex := GlobalTree[Index]^.LHS;

  ArgCount := 0;
  Cur := SourceIndex;
  while Cur <> EOT do
  begin
    if GlobalTree[Cur]^.Id = OBJ_SEPARATOR then
    begin
      EntryNode := GlobalTree[Cur]^.LHS;
      Cur := GlobalTree[Cur]^.RHS;
    end
    else
    begin
      EntryNode := Cur;
      Cur := GlobalTree[Cur]^.RHS;
    end;

    if EntryNode = EOT then
      Continue;
    if ArgCount < Length(ArgNodes) then
      ArgNodes[ArgCount] := EntryNode;
    Inc(ArgCount);
  end;

  if ArgCount < 2 then
    raise Exception.Create('make_pair expects at least 2 arguments: make_pair <key> <value...>');

  KeyArgIndex := ArgNodes[0];
  ValueArgIndex := ArgNodes[1];
  KeyCandidateIndex := GlobalTree.CloneSubtree(KeyArgIndex);
  if KeyCandidateIndex = EOT then
    raise Exception.Create('make_pair failed to clone key argument');
  try
    // Argument lists are RHS-chained; trim sibling tail before key validation.
    GlobalTree[KeyCandidateIndex]^.RHS := EOT;
    if not TryExtractAtomicKeyRef(KeyCandidateIndex, KeyRef, KeyData) then
      raise Exception.Create(
        'make_pair key must evaluate to an atomic identifier/string/integer token'
      );
  finally
    GlobalTree.DeleteSubtree(EOT, KeyCandidateIndex);
  end;

  PairNode := GlobalTree.AllocateNode;
  TVariableSubtreeNode.InitTreeNode(PairNode);
  GlobalTree[PairNode]^.Ref := KeyRef;
  if (KeyData and TK_DOLLAR) = TK_DOLLAR then
    GlobalTree[PairNode]^.Data := GlobalTree[PairNode]^.Data or TK_DOLLAR;
  if (KeyData and TK_ALLCAPS) = TK_ALLCAPS then
    GlobalTree[PairNode]^.Data := GlobalTree[PairNode]^.Data or TK_ALLCAPS;

  ValueClone := GlobalTree.CloneSubtree(ValueArgIndex);
  if ValueClone <> EOT then
    GlobalTree.LinkLHS(PairNode, ValueClone);

  TreeNode^.LHS := PairNode;
  if SourceIndex <> EOT then
    GlobalTree.DeleteSubtree(EOT, SourceIndex);
  GlobalTree.ExpandInline(PrevIndex, Index);
end;

type
  TNodeIndexArray = array of Integer;

type
  TRenderColumnSpec = record
    Name: ansistring;
    Kind: ansistring;
    Path: ansistring;
    SegmentIndex: Integer;
  end;

  TRenderColumnSpecArray = array of TRenderColumnSpec;
  TStringArray = array of ansistring;
  TStringMatrix = array of TStringArray;

procedure CollectInvocationEntries(InvocationIndex: Integer; var Entries: TNodeIndexArray);
var
  Cur: Integer;
  EntryNode: Integer;
  Count: Integer;
begin
  SetLength(Entries, 0);
  if InvocationIndex = EOT then
    Exit;

  Cur := GlobalTree[InvocationIndex]^.LHS;
  while Cur <> EOT do
  begin
    if GlobalTree[Cur]^.Id = OBJ_SEPARATOR then
    begin
      EntryNode := GlobalTree[Cur]^.LHS;
      Cur := GlobalTree[Cur]^.RHS;
    end
    else
    begin
      EntryNode := Cur;
      Cur := GlobalTree[Cur]^.RHS;
    end;

    if EntryNode = EOT then
      Continue;

    Count := Length(Entries);
    SetLength(Entries, Count + 1);
    Entries[Count] := EntryNode;
  end;
end;

function CloneDetachedArgument(NodeIndex: Integer): Integer;
begin
  Result := GlobalTree.CloneSubtree(NodeIndex);
  if Result <> EOT then
    GlobalTree[Result]^.RHS := EOT;
end;

function InvocationArgumentStringValue(NodeIndex: Integer): ansistring;
var
  RawValue: ansistring;
begin
  if NodeIndex = EOT then
    Exit('');

  case GlobalTree[NodeIndex]^.Id of
    OBJ_STRING:
      begin
        RawValue := GetNode(NodeIndex).TokenValue;
        if not UnquoteStringLiteral(RawValue, Result) then
          Result := RawValue;
      end;
    OBJ_VARIABLE, OBJ_INTEGER, OBJ_FLOAT, OBJ_COMPLEX, OBJ_NULL:
      Result := GetNode(NodeIndex).TokenValue;
  else
    Result := GetNode(NodeIndex).TreeValue;
  end;
end;

function InvocationArgumentIntegerValue(NodeIndex: Integer): Int64;
var
  RawValue: ansistring;
begin
  RawValue := Trim(InvocationArgumentStringValue(NodeIndex));
  if not TryStrToInt64(RawValue, Result) then
    raise Exception.CreateFmt(
      'fmt %%d expects an integer, got %s',
      [GetNode(NodeIndex).TreeValue]
    );
end;

function InvocationArgumentFloatValue(NodeIndex: Integer): Double;
var
  RawValue: ansistring;
begin
  RawValue := Trim(InvocationArgumentStringValue(NodeIndex));
  if not TryStrToFloat(RawValue, Result, DefaultFormatSettings) then
    raise Exception.CreateFmt(
      'fmt %%f expects a number, got %s',
      [GetNode(NodeIndex).TreeValue]
    );
end;

procedure DeleteClonedArgs(var Args: TNodeIndexArray);
var
  J: Integer;
begin
  for J := 0 to High(Args) do
    if Args[J] <> EOT then
      GlobalTree.DeleteSubtree(EOT, Args[J]);
  SetLength(Args, 0);
end;

function ResolveRawFormatArgumentNode(
  OwnerIndex: Integer;
  NodeIndex: Integer;
  Context: TContext
): Integer;
var
  VariableNode: TVariableNode;
  VariableName: ansistring;
  ResolvedIndex: Integer;
begin
  Result := NodeIndex;
  if NodeIndex = EOT then
    Exit;
  if GlobalTree[NodeIndex]^.Id <> OBJ_VARIABLE then
    Exit;

  VariableNode := TVariableNode(nodes.GetNode(NodeIndex, OwnerIndex));
  if VariableNode.TryResolveDollarReference(Context, ResolvedIndex) and
     (ResolvedIndex <> EOT) then
    Exit(ResolvedIndex);

  VariableName := VariableNode.TokenValue;
  if Assigned(Context) and (VariableName <> '') and
     Context.TryFindVariable(VariableName, ResolvedIndex) then
    Exit(ResolvedIndex);
end;

function ShouldEvaluateTreeFormatArgument(NodeIndex: Integer): Boolean;
begin
  Result := False;
  if NodeIndex = EOT then
    Exit;

  case GlobalTree[NodeIndex]^.Id of
    OBJ_EVALUATION,
    OBJ_COMPUTE:
      Result := True;
  end;
end;

function IsRenderableFormatArgumentNode(NodeIndex: Integer): Boolean;
begin
  Result := (NodeIndex <> EOT) and
            (NodeIndex >= 0) and
            (NodeIndex < GlobalTree.Count) and
            (GlobalTree[NodeIndex]^.Id <> 0);
end;

function RenderFmtInvocation(InvocationIndex: Integer; Context: TContext): ansistring;
var
  InvocationArgs: TNodeIndexArray;
  FormatArgs: TNodeIndexArray;
  ArrayEntries: TNodeIndexArray;
  PlaceholderVerbs: TAnsiCharArray;
  Replacements: TAnsiStringArray;
  FormatText: ansistring;
  FormatNode: Integer;
  ArrayContainerArg: Integer;
  ArrayProbeArg: Integer;
  ShouldProbeArrayContainer: Boolean;
  TreeArgIndex: Integer;
  I: Integer;
begin
  CollectInvocationEntries(InvocationIndex, InvocationArgs);
  if Length(InvocationArgs) = 0 then
    raise Exception.Create('fmt expects a format string');

  FormatNode := CloneDetachedArgument(InvocationArgs[0]);
  if FormatNode = EOT then
    raise Exception.Create('fmt failed to clone the format string');

  ArrayContainerArg := EOT;
  ArrayProbeArg := EOT;
  SetLength(ArrayEntries, 0);
  SetLength(FormatArgs, 0);
  SetLength(PlaceholderVerbs, 0);
  try
    GetNode(FormatNode).Evaluate(Context);
    FormatText := InvocationArgumentStringValue(FormatNode);
    CollectPercentFormatVerbs(FormatText, PlaceholderVerbs);

    if Length(InvocationArgs) = 2 then
    begin
      ArrayContainerArg := CloneDetachedArgument(InvocationArgs[1]);
      ShouldProbeArrayContainer :=
        not (
          (Length(PlaceholderVerbs) = 1) and
          ((PlaceholderVerbs[0] = 't') or (PlaceholderVerbs[0] = 'T'))
        );
      if ShouldProbeArrayContainer then
      begin
        ArrayProbeArg := CloneDetachedArgument(InvocationArgs[1]);
        if ArrayProbeArg <> EOT then
          GetNode(ArrayProbeArg).Evaluate(Context);
      end;

      if (ArrayProbeArg <> EOT) and
         (GlobalTree[ArrayProbeArg]^.Id = OBJ_ARRAY) then
      begin
        if ArrayContainerArg <> EOT then
        begin
          GlobalTree.DeleteSubtree(EOT, ArrayContainerArg);
          ArrayContainerArg := EOT;
        end;

        ArrayContainerArg := ArrayProbeArg;
        ArrayProbeArg := EOT;
        CollectInvocationEntries(ArrayContainerArg, ArrayEntries);
        SetLength(FormatArgs, Length(ArrayEntries));
        for I := 0 to High(ArrayEntries) do
          FormatArgs[I] := CloneDetachedArgument(ArrayEntries[I]);
      end
      else if ArrayContainerArg <> EOT then
      begin
        SetLength(FormatArgs, 1);
        FormatArgs[0] := ArrayContainerArg;
        ArrayContainerArg := EOT;
      end;

      if ArrayProbeArg <> EOT then
        GlobalTree.DeleteSubtree(EOT, ArrayProbeArg);
    end
    else
    begin
      SetLength(FormatArgs, Length(InvocationArgs) - 1);
      for I := 1 to High(InvocationArgs) do
      begin
        FormatArgs[I - 1] := CloneDetachedArgument(InvocationArgs[I]);
      end;
    end;

    if Length(FormatArgs) <> Length(PlaceholderVerbs) then
      raise Exception.CreateFmt(
        'fmt expected %d arguments but got %d',
        [Length(PlaceholderVerbs), Length(FormatArgs)]
      );

    SetLength(Replacements, Length(PlaceholderVerbs));
    for I := 0 to High(PlaceholderVerbs) do
    begin
      case PlaceholderVerbs[I] of
        's', 'S':
          begin
            if FormatArgs[I] <> EOT then
              GetNode(FormatArgs[I]).Evaluate(Context);
            Replacements[I] := InvocationArgumentStringValue(FormatArgs[I]);
          end;
        'd', 'D':
          begin
            if FormatArgs[I] <> EOT then
              GetNode(FormatArgs[I]).Evaluate(Context);
            Replacements[I] := IntToStr(InvocationArgumentIntegerValue(FormatArgs[I]));
          end;
        'f', 'F':
          begin
            if FormatArgs[I] <> EOT then
              GetNode(FormatArgs[I]).Evaluate(Context);
            Replacements[I] := FloatToStr(
              InvocationArgumentFloatValue(FormatArgs[I]),
              DefaultFormatSettings
            );
          end;
        't', 'T':
          begin
            if ShouldEvaluateTreeFormatArgument(FormatArgs[I]) then
              GetNode(FormatArgs[I]).Evaluate(Context);
            TreeArgIndex := ResolveRawFormatArgumentNode(EOT, FormatArgs[I], Context);
            if IsRenderableFormatArgumentNode(TreeArgIndex) then
              Replacements[I] := GetNode(TreeArgIndex).TreeValue
            else
              Replacements[I] := '';
          end;
        'q', 'Q':
          begin
            if FormatArgs[I] <> EOT then
              GetNode(FormatArgs[I]).Evaluate(Context);
            Replacements[I] := QuoteStringLiteral(InvocationArgumentStringValue(FormatArgs[I]));
          end;
      else
        raise Exception.CreateFmt(
          'fmt does not support %%%s',
          [ansistring(PlaceholderVerbs[I])]
        );
      end;
    end;

    Result := ExpandPercentFormatTemplate(FormatText, Replacements);
  finally
    if FormatNode <> EOT then
      GlobalTree.DeleteSubtree(EOT, FormatNode);
    if ArrayContainerArg <> EOT then
      GlobalTree.DeleteSubtree(EOT, ArrayContainerArg);
    DeleteClonedArgs(FormatArgs);
  end;
end;

procedure ResetInvocationNodeAsString(NodeIndex: Integer; const ValueText: ansistring);
begin
  if GlobalTree[NodeIndex]^.LHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(NodeIndex, GlobalTree[NodeIndex]^.LHS);
    GlobalTree[NodeIndex]^.LHS := EOT;
  end;
  if GlobalTree[NodeIndex]^.RHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(NodeIndex, GlobalTree[NodeIndex]^.RHS);
    GlobalTree[NodeIndex]^.RHS := EOT;
  end;

  TStringNode.InitTreeNode(NodeIndex);
  GlobalTree[NodeIndex]^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(ValueText));
end;

function ResolveRenderArgumentText(
  ArgIndex: Integer;
  Context: TContext;
  ForceEvaluate: Boolean
): ansistring;
var
  ResolvedArgIndex: Integer;
  WorkingIndex: Integer;
  ArgNeedsEvaluation: Boolean;
begin
  Result := '';
  if ArgIndex = EOT then
    Exit;

  ArgNeedsEvaluation := ForceEvaluate or QueryArgumentNeedsEvaluation(ArgIndex);
  WorkingIndex := ArgIndex;
  if ArgNeedsEvaluation then
  begin
    WorkingIndex := CloneDetachedArgument(ArgIndex);
    if WorkingIndex = EOT then
      Exit;
    nodes.GetNode(WorkingIndex, EOT).Evaluate(Context);
  end;

  ResolvedArgIndex := ResolveDollarQueryArgumentNode(EOT, WorkingIndex, Context);
  Result := NormalizeQueryArgumentValue(QueryArgumentRawValue(EOT, ResolvedArgIndex));

  if ArgNeedsEvaluation and (WorkingIndex <> EOT) then
    GlobalTree.DeleteSubtree(EOT, WorkingIndex);
end;

function NormalizeRenderCellText(const Value: ansistring): ansistring;
begin
  Result := StringReplace(Value, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

function RenderNodeDisplayText(NodeIndex: Integer): ansistring;
var
  IsStructuredScalar: Boolean;
begin
  if NodeIndex = EOT then
    Exit('');

  IsStructuredScalar :=
    (GlobalTree[NodeIndex]^.LHS <> EOT) or
    (GlobalTree[NodeIndex]^.RHS <> EOT) or
    ((GlobalTree[NodeIndex]^.Data and TK_OPERATOR_MASK) <> 0);

  if not IsStructuredScalar then
    case GlobalTree[NodeIndex]^.Id of
      OBJ_STRING:
        Result := InvocationArgumentStringValue(NodeIndex);
      OBJ_VARIABLE, OBJ_INTEGER, OBJ_FLOAT, OBJ_COMPLEX, OBJ_NULL:
        Result := nodes.GetNode(NodeIndex).TokenValue;
    else
      Result := nodes.GetNode(NodeIndex).TreeValue;
    end
  else
    Result := nodes.GetNode(NodeIndex).TreeValue;
  Result := NormalizeRenderCellText(Result);
end;

function TryFindContextValueRef(
  Context: TContext;
  const RawPath: ansistring;
  out ValueRef: Integer
): Boolean;
var
  ResolvedPath: ansistring;
begin
  ValueRef := EOT;
  if not Assigned(Context) then
    Exit(False);

  ResolvedPath := Trim(RawPath);
  if ResolvedPath = '' then
    Exit(False);

  if Context.TryFindVariable(ResolvedPath, ValueRef) then
    Exit(True);

  if Context.ResolveIndexedVariablePattern(ResolvedPath, ResolvedPath) and
     (ResolvedPath <> '') and
     Context.TryFindVariable(ResolvedPath, ValueRef) then
    Exit(True);

  Result := False;
end;

function TryGetContextScalarText(
  Context: TContext;
  const Path: ansistring;
  out Value: ansistring
): Boolean;
var
  ValueRef: Integer;
begin
  Value := '';
  if not TryFindContextValueRef(Context, Path, ValueRef) then
    Exit(False);
  Value := RenderNodeDisplayText(ValueRef);
  Result := True;
end;

function TryGetContextInteger(
  Context: TContext;
  const Path: ansistring;
  out Value: Integer
): Boolean;
var
  ValueRef: Integer;
  TextValue: ansistring;
  OpBits: Integer;
  Sign: Integer;
begin
  Value := 0;
  if not TryFindContextValueRef(Context, Path, ValueRef) then
    Exit(False);

  if GlobalTree[ValueRef]^.Id = OBJ_INTEGER then
  begin
    Sign := 1;
    OpBits := GlobalTree[ValueRef]^.Data and TK_OPERATOR_MASK;
    if OpBits = TK_MINUS then
      Sign := -1;
    TextValue := Trim(GlobalTree.Expression.TokenValue(GlobalTree[ValueRef]^.Ref));
    if TextValue = '' then
      Exit(False);
    Value := Sign * StrToIntDef(TextValue, 0);
    Exit(True);
  end;

  TextValue := NormalizeRenderCellText(RenderNodeDisplayText(ValueRef));
  TextValue := StringReplace(TextValue, ' ', '', [rfReplaceAll]);
  Result := TryStrToInt(TextValue, Value);
end;

function PeelSingleChildValueWrappers(NodeIndex: Integer): Integer;
begin
  Result := NodeIndex;
  while (Result <> EOT) and
        ((GlobalTree[Result]^.Id and OBJ_CATEGORY_MASK) = OBJ_SCOPE) and
        (GlobalTree[Result]^.RHS = EOT) and
        (GlobalTree[Result]^.LHS <> EOT) do
    Result := GlobalTree[Result]^.LHS;
end;

function TryGetLeafObjectFieldNode(
  ValueRef: Integer;
  const FieldName: ansistring;
  out FieldNode: Integer
): Boolean;
  function TryFindInSubtree(NodeIndex: Integer): Boolean;
  var
    EntryName: ansistring;
    EffectiveIndex: Integer;
  begin
    Result := False;
    if NodeIndex = EOT then
      Exit(False);

    EffectiveIndex := PeelSingleChildValueWrappers(NodeIndex);
    if EffectiveIndex = EOT then
      Exit(False);

    if (GlobalTree[EffectiveIndex]^.Id = OBJ_VARIABLE_SUBTREE) and
       (GlobalTree[EffectiveIndex]^.Ref <> EOT) then
    begin
      EntryName := GlobalTree.Expression.TokenValue(GlobalTree[EffectiveIndex]^.Ref);
      if SameText(Trim(EntryName), Trim(FieldName)) then
      begin
        FieldNode := GlobalTree[EffectiveIndex]^.LHS;
        Exit(FieldNode <> EOT);
      end;
    end;

    if TryFindInSubtree(GlobalTree[EffectiveIndex]^.LHS) then
      Exit(True);
    if TryFindInSubtree(GlobalTree[EffectiveIndex]^.RHS) then
      Exit(True);
  end;
begin
  FieldNode := EOT;
  Result := TryFindInSubtree(ValueRef);
end;

function TryGetLeafObjectFieldPathNode(
  ValueRef: Integer;
  const FieldPath: ansistring;
  out FieldNode: Integer
): Boolean;
var
  RemainingPath: ansistring;
  SegmentName: ansistring;
  DotPos: Integer;
  CurrentNode: Integer;
  NextNode: Integer;
begin
  FieldNode := EOT;
  RemainingPath := Trim(FieldPath);
  if RemainingPath = '' then
    Exit(False);

  CurrentNode := ValueRef;
  while RemainingPath <> '' do
  begin
    DotPos := Pos('.', RemainingPath);
    if DotPos > 0 then
    begin
      SegmentName := Trim(Copy(RemainingPath, 1, DotPos - 1));
      Delete(RemainingPath, 1, DotPos);
    end
    else
    begin
      SegmentName := Trim(RemainingPath);
      RemainingPath := '';
    end;

    if SegmentName = '' then
      Exit(False);
    if not TryGetLeafObjectFieldNode(CurrentNode, SegmentName, NextNode) then
      Exit(False);
    CurrentNode := NextNode;
  end;

  FieldNode := CurrentNode;
  Result := FieldNode <> EOT;
end;

function TryGetProfileLeafFieldText(
  Context: TContext;
  const BasePath: ansistring;
  const FieldName: ansistring;
  out Value: ansistring
): Boolean;
var
  ValueRef: Integer;
  FieldNode: Integer;
begin
  Value := '';

  if TryGetContextScalarText(Context, JoinTriePath(BasePath, FieldName), Value) then
    Exit(True);

  if not TryFindContextValueRef(Context, BasePath, ValueRef) then
    Exit(False);
  if not TryGetLeafObjectFieldPathNode(ValueRef, FieldName, FieldNode) then
    Exit(False);

  Value := RenderNodeDisplayText(FieldNode);
  Result := True;
end;

function TryGetProfileLeafFieldInteger(
  Context: TContext;
  const BasePath: ansistring;
  const FieldName: ansistring;
  out Value: Integer
): Boolean;
var
  ValueRef: Integer;
  FieldNode: Integer;
  TextValue: ansistring;
  OpBits: Integer;
  Sign: Integer;
begin
  Value := 0;

  if TryGetContextInteger(Context, JoinTriePath(BasePath, FieldName), Value) then
    Exit(True);

  if not TryFindContextValueRef(Context, BasePath, ValueRef) then
    Exit(False);
  if not TryGetLeafObjectFieldPathNode(ValueRef, FieldName, FieldNode) then
    Exit(False);

  if GlobalTree[FieldNode]^.Id = OBJ_INTEGER then
  begin
    Sign := 1;
    OpBits := GlobalTree[FieldNode]^.Data and TK_OPERATOR_MASK;
    if OpBits = TK_MINUS then
      Sign := -1;
    TextValue := Trim(GlobalTree.Expression.TokenValue(GlobalTree[FieldNode]^.Ref));
    if TextValue = '' then
      Exit(False);
    Value := Sign * StrToIntDef(TextValue, 0);
    Exit(True);
  end;

  TextValue := NormalizeRenderCellText(RenderNodeDisplayText(FieldNode));
  TextValue := StringReplace(TextValue, ' ', '', [rfReplaceAll]);
  Result := TryStrToInt(TextValue, Value);
end;

function TryParseBooleanText(const RawValue: ansistring; out Value: Boolean): Boolean;
var
  NormalizedValue: ansistring;
begin
  NormalizedValue := LowerCase(Trim(RawValue));
  if (NormalizedValue = '1') or (NormalizedValue = 'true') or
     (NormalizedValue = 'yes') or (NormalizedValue = 'on') or
     (NormalizedValue = 'strict') or (NormalizedValue = 'enabled') then
  begin
    Value := True;
    Exit(True);
  end;
  if (NormalizedValue = '0') or (NormalizedValue = 'false') or
     (NormalizedValue = 'no') or (NormalizedValue = 'off') or
     (NormalizedValue = 'loose') or (NormalizedValue = 'disabled') then
  begin
    Value := False;
    Exit(True);
  end;
  Result := False;
end;

function TryExtractTrailingIndex(const Path: ansistring; out Value: Integer): Boolean;
var
  L, R: Integer;
  SegmentText: ansistring;
begin
  Value := 0;
  Result := False;

  R := Length(Path);
  while (R > 0) and (Path[R] <= ' ') do
    Dec(R);
  if R <= 0 then
    Exit(False);

  if Path[R] = ']' then
  begin
    L := R - 1;
    while (L > 0) and (Path[L] <> '[') do
      Dec(L);
    if L <= 0 then
      Exit(False);
    SegmentText := Copy(Path, L + 1, R - L - 1);
    Exit(TryStrToInt(SegmentText, Value));
  end;

  L := R;
  while (L > 0) and (Path[L] <> '.') do
    Dec(L);
  if L <= 0 then
    Exit(False);
  SegmentText := Copy(Path, L + 1, R - L);
  Result := TryStrToInt(SegmentText, Value);
end;

procedure SortPathsByTrailingIndex(Paths: TStrings);
var
  I, J: Integer;
  LeftText, RightText: ansistring;
  LeftIndex, RightIndex: Integer;
  LeftHasIndex, RightHasIndex: Boolean;
begin
  if not Assigned(Paths) then
    Exit;
  for I := 0 to Paths.Count - 2 do
    for J := I + 1 to Paths.Count - 1 do
    begin
      LeftText := Paths[I];
      RightText := Paths[J];
      LeftHasIndex := TryExtractTrailingIndex(LeftText, LeftIndex);
      RightHasIndex := TryExtractTrailingIndex(RightText, RightIndex);
      if LeftHasIndex and RightHasIndex then
      begin
        if LeftIndex > RightIndex then
          Paths.Exchange(I, J);
      end
      else if AnsiCompareText(LeftText, RightText) > 0 then
        Paths.Exchange(I, J);
    end;
end;

function PathSegmentTextAt(const Path: ansistring; SegmentIndex: Integer): ansistring;
var
  Segments: TStringList;
  SegmentFlags: array of Boolean;
  PosIdx: Integer;
  StartIdx: Integer;
  Part: ansistring;
  SegmentPos: Integer;
  SegmentText: ansistring;
  SegmentAsInteger: Integer;
  SegmentFromIndex: Boolean;
  procedure AddPart(const RawPart: ansistring; IsIndexPart: Boolean);
  var
    P: ansistring;
  begin
    P := Trim(RawPart);
    if P <> '' then
    begin
      Segments.Add(P);
      SetLength(SegmentFlags, Length(SegmentFlags) + 1);
      SegmentFlags[High(SegmentFlags)] := IsIndexPart;
    end;
  end;
begin
  Result := '';
  Segments := TStringList.Create;
  try
    SetLength(SegmentFlags, 0);
    Part := '';
    PosIdx := 1;
    while PosIdx <= Length(Path) do
    begin
      case Path[PosIdx] of
        '.':
          begin
            AddPart(Part, False);
            Part := '';
            Inc(PosIdx);
          end;
        '[':
          begin
            AddPart(Part, False);
            Part := '';
            Inc(PosIdx);
            StartIdx := PosIdx;
            while (PosIdx <= Length(Path)) and (Path[PosIdx] <> ']') do
              Inc(PosIdx);
            if PosIdx <= Length(Path) then
              AddPart(Copy(Path, StartIdx, PosIdx - StartIdx), True)
            else
              AddPart(Copy(Path, StartIdx, MaxInt), True);
            if (PosIdx <= Length(Path)) and (Path[PosIdx] = ']') then
              Inc(PosIdx);
          end;
        ']':
          Inc(PosIdx);
      else
        begin
          Part := Part + Path[PosIdx];
          Inc(PosIdx);
        end;
      end;
    end;
    AddPart(Part, False);

    if SegmentIndex > 0 then
      SegmentPos := SegmentIndex
    else if SegmentIndex < 0 then
      SegmentPos := Segments.Count + SegmentIndex + 1
    else
      Exit('');

    if (SegmentPos < 1) or (SegmentPos > Segments.Count) then
      Exit('');

    SegmentText := Segments[SegmentPos - 1];
    SegmentFromIndex := (SegmentPos - 1 <= High(SegmentFlags)) and SegmentFlags[SegmentPos - 1];
    if SegmentFromIndex and TryStrToInt(SegmentText, SegmentAsInteger) then
      Result := IntToStr(SegmentAsInteger)
    else
      Result := SegmentText;
  finally
    Segments.Free;
  end;
end;

function FormatColumnsTable(
  const Headers: TStringArray;
  const Rows: TStringMatrix;
  IncludeHeader: Boolean
): ansistring;
var
  Widths: array of Integer;
  I, J: Integer;
  LineText: ansistring;
  function PadRightText(const Value: ansistring; Width: Integer): ansistring;
  begin
    Result := Value;
    if Length(Result) < Width then
      Result := Result + StringOfChar(' ', Width - Length(Result));
  end;
  function BuildLine(const Cells: TStringArray): ansistring;
  var
    K: Integer;
  begin
    Result := '';
    for K := 0 to High(Cells) do
    begin
      if K > 0 then
        Result := Result + '  ';
      if K < High(Cells) then
        Result := Result + PadRightText(Cells[K], Widths[K])
      else
        Result := Result + Cells[K];
    end;
  end;
begin
  SetLength(Widths, Length(Headers));
  for I := 0 to High(Headers) do
    Widths[I] := Length(Headers[I]);

  for I := 0 to High(Rows) do
    for J := 0 to High(Rows[I]) do
      if (J <= High(Widths)) and (Length(Rows[I][J]) > Widths[J]) then
        Widths[J] := Length(Rows[I][J]);

  Result := '';
  if IncludeHeader and (Length(Headers) > 0) then
    Result := BuildLine(Headers);

  for I := 0 to High(Rows) do
  begin
    LineText := BuildLine(Rows[I]);
    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + LineText;
  end;
end;

function EscapeCsvCell(const Value: ansistring; const Delimiter: ansistring): ansistring;
begin
  Result := StringReplace(Value, '"', '""', [rfReplaceAll]);
  if ((Delimiter <> '') and (Pos(Delimiter, Value) > 0)) or
     (Pos('"', Value) > 0) or
     (Pos(#13, Value) > 0) or
     (Pos(#10, Value) > 0) then
    Result := '"' + Result + '"';
end;

function FormatCsvTable(
  const Headers: TStringArray;
  const Rows: TStringMatrix;
  IncludeHeader: Boolean;
  const Delimiter: ansistring
): ansistring;
var
  I: Integer;
  LineText: ansistring;
  function BuildLine(const Cells: TStringArray): ansistring;
  var
    K: Integer;
  begin
    Result := '';
    for K := 0 to High(Cells) do
    begin
      if K > 0 then
        Result := Result + Delimiter;
      Result := Result + EscapeCsvCell(Cells[K], Delimiter);
    end;
  end;
begin
  Result := '';
  if IncludeHeader and (Length(Headers) > 0) then
    Result := BuildLine(Headers);

  for I := 0 to High(Rows) do
  begin
    LineText := BuildLine(Rows[I]);
    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + LineText;
  end;
end;

function TryGetRenderOptionText(
  Context: TContext;
  const ProfilePath: ansistring;
  const FormatName: ansistring;
  const OptionName: ansistring;
  out Value: ansistring
): Boolean;
begin
  Value := '';
  if TryGetContextScalarText(Context, JoinTriePath(ProfilePath, 'options.' + FormatName + '.' + OptionName), Value) then
    Exit(True);
  if TryGetProfileLeafFieldText(Context, JoinTriePath(ProfilePath, 'options'), FormatName + '.' + OptionName, Value) then
    Exit(True);
  if TryGetContextScalarText(Context, JoinTriePath(ProfilePath, 'options.' + OptionName), Value) then
    Exit(True);
  if TryGetProfileLeafFieldText(Context, JoinTriePath(ProfilePath, 'options'), OptionName, Value) then
    Exit(True);
  Result := False;
end;

function TryGetRenderOptionBoolean(
  Context: TContext;
  const ProfilePath: ansistring;
  const FormatName: ansistring;
  const OptionName: ansistring;
  out Value: Boolean
): Boolean;
var
  SourceName: ansistring;
  IntValue: Integer;
  TextValue: ansistring;
begin
  Result := False;
  if ReadBooleanSetting(
       GlobalTree,
       Context,
       [JoinTriePath(ProfilePath, 'options.' + FormatName + '.' + OptionName)],
       Value,
       SourceName
     ) = srrFound then
    Exit(True);

  if TryGetProfileLeafFieldInteger(Context, JoinTriePath(ProfilePath, 'options'), FormatName + '.' + OptionName, IntValue) then
  begin
    Value := IntValue <> 0;
    Exit(True);
  end;
  if TryGetProfileLeafFieldText(Context, JoinTriePath(ProfilePath, 'options'), FormatName + '.' + OptionName, TextValue) and
     TryParseBooleanText(TextValue, Value) then
    Exit(True);
  if ReadBooleanSetting(
       GlobalTree,
       Context,
       [JoinTriePath(ProfilePath, 'options.' + OptionName), JoinTriePath(ProfilePath, OptionName)],
       Value,
       SourceName
     ) = srrFound then
    Exit(True);
  if TryGetProfileLeafFieldInteger(Context, JoinTriePath(ProfilePath, 'options'), OptionName, IntValue) then
  begin
    Value := IntValue <> 0;
    Exit(True);
  end;
  if TryGetProfileLeafFieldText(Context, JoinTriePath(ProfilePath, 'options'), OptionName, TextValue) and
     TryParseBooleanText(TextValue, Value) then
    Exit(True);
end;

function LoadRenderTabularProfile(
  Context: TContext;
  const FormatName: ansistring;
  const ProfilePath: ansistring;
  out IncludeHeader: Boolean;
  out Delimiter: ansistring;
  out RowsKind: ansistring;
  out RowsPathSuffix: ansistring;
  out Columns: TRenderColumnSpecArray
): Boolean;
var
  KindText: ansistring;
  ColumnPaths: TStringList;
  I: Integer;
  ColumnPath: ansistring;
begin
  Result := False;
  IncludeHeader := True;
  Delimiter := ',';
  RowsKind := '';
  RowsPathSuffix := '';
  SetLength(Columns, 0);

  if not TryGetContextScalarText(Context, JoinTriePath(ProfilePath, 'kind'), KindText) then
    Exit(False);
  if not SameText(KindText, 'tabular') then
    raise Exception.CreateFmt(
      'render %s expects profile kind "tabular", got %s',
      [FormatName, KindText]
    );

  if not TryGetRenderOptionBoolean(Context, ProfilePath, FormatName, 'header', IncludeHeader) then
    IncludeHeader := True;

  if SameText(FormatName, 'csv') then
  begin
    if not TryGetRenderOptionText(Context, ProfilePath, FormatName, 'delimiter', Delimiter) or
       (Delimiter = '') then
      Delimiter := ',';
  end;

  if not TryGetContextScalarText(Context, JoinTriePath(ProfilePath, 'rows.kind'), RowsKind) then
    if not TryGetProfileLeafFieldText(
             Context,
             JoinTriePath(ProfilePath, 'rows'),
             'kind',
             RowsKind
           ) then
      raise Exception.CreateFmt('render %s missing %s', [FormatName, JoinTriePath(ProfilePath, 'rows.kind')]);
  if not TryGetContextScalarText(Context, JoinTriePath(ProfilePath, 'rows.path_suffix'), RowsPathSuffix) then
    if not TryGetProfileLeafFieldText(
             Context,
             JoinTriePath(ProfilePath, 'rows'),
             'path_suffix',
             RowsPathSuffix
           ) then
      RowsPathSuffix := '';

  ColumnPaths := TStringList.Create;
  try
    Context.ScanVariableChildren(JoinTriePath(ProfilePath, 'columns'), ColumnPaths);
    SortPathsByTrailingIndex(ColumnPaths);
    SetLength(Columns, ColumnPaths.Count);
    for I := 0 to ColumnPaths.Count - 1 do
    begin
      ColumnPath := ColumnPaths[I];
      FillChar(Columns[I], SizeOf(Columns[I]), 0);
      Columns[I].SegmentIndex := 0;
      if not TryGetProfileLeafFieldText(Context, ColumnPath, 'name', Columns[I].Name) then
        raise Exception.CreateFmt('render %s missing %s.name', [FormatName, ColumnPath]);
      if not TryGetProfileLeafFieldText(Context, ColumnPath, 'kind', Columns[I].Kind) then
        raise Exception.CreateFmt('render %s missing %s.kind', [FormatName, ColumnPath]);
      if SameText(Columns[I].Kind, 'relative_get') then
      begin
        if not TryGetProfileLeafFieldText(Context, ColumnPath, 'path', Columns[I].Path) then
          raise Exception.CreateFmt('render %s missing %s.path', [FormatName, ColumnPath]);
      end
      else if SameText(Columns[I].Kind, 'path_segment') then
      begin
        if not TryGetProfileLeafFieldInteger(Context, ColumnPath, 'index', Columns[I].SegmentIndex) then
          raise Exception.CreateFmt('render %s missing %s.index', [FormatName, ColumnPath]);
      end
      else
        raise Exception.CreateFmt(
          'render %s does not support column kind %s',
          [FormatName, Columns[I].Kind]
        );
    end;
  finally
    ColumnPaths.Free;
  end;

  Result := True;
end;

function RenderColumnsInvocation(InvocationIndex: Integer; Context: TContext): ansistring;
var
  InvocationArgs: TNodeIndexArray;
  FormatName: ansistring;
  ProfilePath: ansistring;
  SubjectPath: ansistring;
  IncludeHeader: Boolean;
  Delimiter: ansistring;
  RowsKind: ansistring;
  RowsPathSuffix: ansistring;
  Columns: TRenderColumnSpecArray;
  RowPaths: TStringList;
  Headers: TStringArray;
  Rows: TStringMatrix;
  RowPath: ansistring;
  CellPath: ansistring;
  CellValueText: ansistring;
  LeafFieldName: ansistring;
  ValueRef: Integer;
  I, J: Integer;
begin
  CollectInvocationEntries(InvocationIndex, InvocationArgs);
  if Length(InvocationArgs) <> 3 then
    raise Exception.Create(
      'render expects 3 arguments: render <format> <profile> <subject>'
    );

  FormatName := LowerCase(ResolveRenderArgumentText(InvocationArgs[0], Context, False));
  if (FormatName <> 'columns') and (FormatName <> 'csv') then
    raise Exception.CreateFmt('render does not support format %s', [FormatName]);

  ProfilePath := ResolveRenderArgumentText(InvocationArgs[1], Context, False);
  SubjectPath := ResolveRenderArgumentText(InvocationArgs[2], Context, True);
  if SubjectPath = '' then
    raise Exception.CreateFmt('render %s subject cannot be empty', [FormatName]);

  if not LoadRenderTabularProfile(
           Context, FormatName, ProfilePath, IncludeHeader, Delimiter, RowsKind, RowsPathSuffix, Columns
         ) then
    raise Exception.CreateFmt('render %s profile not found: %s', [FormatName, ProfilePath]);

  if not SameText(RowsKind, 'trie_children') then
    raise Exception.CreateFmt(
      'render %s does not support rows.kind %s',
      [FormatName, RowsKind]
    );

  RowPaths := TStringList.Create;
  try
    Context.ScanVariableChildren(JoinTriePath(SubjectPath, RowsPathSuffix), RowPaths);
    SortPathsByTrailingIndex(RowPaths);
    SetLength(Headers, Length(Columns));
    for I := 0 to High(Columns) do
      Headers[I] := Columns[I].Name;

    SetLength(Rows, RowPaths.Count);
    for I := 0 to RowPaths.Count - 1 do
    begin
      RowPath := RowPaths[I];
      SetLength(Rows[I], Length(Columns));
      for J := 0 to High(Columns) do
      begin
        if SameText(Columns[J].Kind, 'path_segment') then
          Rows[I][J] := NormalizeRenderCellText(
            PathSegmentTextAt(RowPath, Columns[J].SegmentIndex)
          )
        else if SameText(Columns[J].Kind, 'relative_get') then
        begin
          CellPath := JoinTriePath(RowPath, Columns[J].Path);
          if TryFindContextValueRef(Context, CellPath, ValueRef) then
            Rows[I][J] := RenderNodeDisplayText(ValueRef)
          else
          begin
            LeafFieldName := Trim(Columns[J].Path);
            if (LeafFieldName <> '') and (LeafFieldName[1] = '.') then
              Delete(LeafFieldName, 1, 1);
            if (LeafFieldName <> '') and
               (Pos('.', LeafFieldName) = 0) and
               (Pos('[', LeafFieldName) = 0) and
               TryGetProfileLeafFieldText(Context, RowPath, LeafFieldName, CellValueText) then
              Rows[I][J] := CellValueText
            else
              Rows[I][J] := '';
          end
        end
        else
          Rows[I][J] := '';
      end;
    end;

    if FormatName = 'columns' then
      Result := FormatColumnsTable(Headers, Rows, IncludeHeader)
    else
      Result := FormatCsvTable(Headers, Rows, IncludeHeader, Delimiter);
  finally
    RowPaths.Free;
  end;
end;

function IsDisplayEffectAllowed(
  Context: TContext;
  const PhaseName: ansistring;
  DefaultValue: Boolean = False
): Boolean;
var
  SourceName: ansistring;
  ReadResult: TSettingReadResult;
begin
  ReadResult := ReadBooleanSetting(
                  GlobalTree,
                  Context,
                  [Format('mantra.effects.display.%s', [PhaseName])],
                  Result,
                  SourceName
                );
  if ReadResult = srrNotFound then
    Result := DefaultValue
  else if ReadResult = srrInvalid then
  begin
    Result := DefaultValue;
    if Assigned(Context) and Context.EventEnabled(ellDiag) then
      Context.LogDiag(
        Format('invalid %s value (expected boolean or 0/1)', [SourceName])
      );
  end;
end;

function ShouldDeferExplicitExecuteInEvaluation(Context: TContext; NodeIndex: Integer): Boolean;
begin
  Result := (EvaluationExecutionDepth > 0) and
            (NodeIndex <> EOT) and
            (GlobalTree[NodeIndex]^.Id = OBJ_PRINTF) and
            IsDisplayEffectAllowed(Context, 'evaluate');
end;

{ TFmtNode }

procedure TFmtNode.Evaluate(Context: TContext);
begin
  ResetInvocationNodeAsString(Index, RenderFmtInvocation(Index, Context));
end;

procedure TRenderNode.Evaluate(Context: TContext);
begin
  ResetInvocationNodeAsString(Index, RenderColumnsInvocation(Index, Context));
end;

procedure TPrintfNode.Execute(Context: TContext);
begin
  EmitRuntimeOutputLine(RenderFmtInvocation(Index, Context));
end;

procedure TPrintfNode.Evaluate(Context: TContext);
begin
  if (EvaluationExecutionDepth > 0) and IsDisplayEffectAllowed(Context, 'evaluate') then
  begin
    Execute(Context);
    Delete;
    Exit;
  end;
  inherited Evaluate(Context);
end;

procedure TPrintfNode.Compute(Context: TContext);
begin
  if IsDisplayEffectAllowed(Context, 'compute') then
  begin
    Execute(Context);
    Delete;
    Exit;
  end;
  inherited Compute(Context);
end;

function IsRuleTransformationNodeId(NodeId: Integer): Boolean; inline;
begin
  Result := (NodeId = OBJ_TRANSFORMATION) or
            (NodeId = OBJ_EQUIVALENCE) or
            (NodeId = OBJ_INLINE_TRANSFORMATION) or
            (NodeId = OBJ_SUBST_TRANSFORM) or
            (NodeId = OBJ_SYMBOL_SUBST_TRANSFORM) or
            (NodeId = OBJ_SUBST_EQUIVALENCE);
end;

function TryFindRuleHeadToken(Index: Integer; out HeadToken: ansistring): Boolean;
var
  HeadIndex: Integer;
begin
  HeadToken := '';
  if Index = EOT then
    Exit(False);

  if IsRuleTransformationNodeId(GlobalTree[Index]^.Id) then
  begin
    HeadIndex := GlobalTree[Index]^.LHS;
    while (HeadIndex <> EOT) and
          ((GlobalTree[HeadIndex]^.Id = OBJ_EXPRESSION) or
           (GlobalTree[HeadIndex]^.Id = OBJ_EVALUATION) or
           (GlobalTree[HeadIndex]^.Id = OBJ_ARRAY) or
           (GlobalTree[HeadIndex]^.Id = OBJ_SEPARATOR)) and
          (GlobalTree[HeadIndex]^.LHS <> EOT) do
      HeadIndex := GlobalTree[HeadIndex]^.LHS;

    if (HeadIndex <> EOT) and (GlobalTree[HeadIndex]^.Id = OBJ_VARIABLE) then
    begin
      HeadToken := nodes.GetNode(HeadIndex).TokenValue;
      Exit(HeadToken <> '');
    end;
    Exit(False);
  end;

  Result := TryFindRuleHeadToken(GlobalTree[Index]^.LHS, HeadToken);
  if Result then
    Exit(True);
  Result := TryFindRuleHeadToken(GlobalTree[Index]^.RHS, HeadToken);
end;

function NamespaceFromQualifiedName(const Name: ansistring): ansistring;
var
  P: SizeInt;
begin
  Result := Trim(Name);
  if Result = '' then
    Exit('');
  P := LastDelimiter('.', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1)
  else
    Result := '';
end;

procedure RewriteInvocationHeadTokens(
  Index: Integer;
  const SourceName: ansistring;
  const TargetName: ansistring
);
var
  Cur: Integer;
begin
  Cur := Index;
  while Cur <> EOT do
  begin
    if (GlobalTree[Cur]^.Id = OBJ_VARIABLE) and
       (GlobalTree[Cur]^.RHS <> EOT) and
       (nodes.GetNode(Cur).TokenValue = SourceName) then
      GlobalTree[Cur]^.Ref := GlobalTree.Expression.AddToken(
        TK_VARIABLE,
        TargetName
      );

    if GlobalTree[Cur]^.LHS <> EOT then
      RewriteInvocationHeadTokens(
        GlobalTree[Cur]^.LHS,
        SourceName,
        TargetName
      );
    Cur := GlobalTree[Cur]^.RHS;
  end;
end;

{ TVariableNode }

function TVariableNode.TryResolveDollarReference(Context: TContext; out ResolvedIndex: Integer): Boolean;
begin
  Result := ResolveDollarVariableChain(GlobalTree, Context, Index, ResolvedIndex);
  if not Result then
    ResolvedIndex := Index;
end;

procedure TVariableNode.Expand(Context: TContext);
var
  SourceIndex: Integer;
  ResidualIndex: Integer;
  ResidualSourceIndex: Integer;
  WrapperIndex: Integer;
  NextSibling: Integer;
begin
  if not TryGetRepeatExpandSource(Context, SourceIndex) then
  begin
    inherited Expand(Context);
    Exit;
  end;

  NextSibling := RHS;

  ResidualIndex := GlobalTree.AllocateNode;
  TRepeatNode.InitTreeNode(ResidualIndex);
  ResidualSourceIndex := GlobalTree.CloneSubtree(SourceIndex);
  if ResidualSourceIndex <> EOT then
    Node[ResidualSourceIndex].ClearRewrite;
  GlobalTree.LinkLHS(ResidualIndex, ResidualSourceIndex);
  GlobalTree.LinkRHS(ResidualIndex, GlobalTree.CloneLHS(Index));

  if NextSibling <> EOT then
  begin
    WrapperIndex := GlobalTree.AllocateNode;
    TExpressionNode.InitTreeNode(WrapperIndex);
    GlobalTree.LinkLHS(WrapperIndex, ResidualIndex);
    TreeNode^.LHS := WrapperIndex;
  end
  else
    TreeNode^.LHS := ResidualIndex;
  GlobalTree.ExpandInline(PrevIndex, Index);

  if NextSibling <> EOT then
    Node[NextSibling].Expand(Context);
end;

procedure TVariableNode.Evaluate(Context: TContext);
var
  Name: ansistring;
  RulesIndex: Integer;
  DispatchHeadName: ansistring;
  DispatchNamespace: ansistring;
  ResolvedCallableName: ansistring;
  ResolveMode: TVariableResolveMode;
  RewrittenIndex: Integer;
  RevisionBefore: QWord;
  NativeContract: TNativeFunctionContract;

  function IsInvocationNodeAlive: Boolean;
  begin
    Result := (Index <> EOT) and
              (Index >= 0) and
              (Index < GlobalTree.Count) and
              ((GlobalTree[Index]^.Id and (TK_TYPE or TK_ID_MASK)) = OBJ_VARIABLE);
    if not Result then
      Exit;
    if PrevIndex = EOT then
      Exit(True);
    Result := (PrevIndex >= 0) and (PrevIndex < GlobalTree.Count) and
              ((GlobalTree[PrevIndex]^.LHS = Index) or
               (GlobalTree[PrevIndex]^.RHS = Index));
  end;

  function TryHeadDispatch: Boolean;
  var
    DispatchSubjectIndex: Integer;
    PushedSettingNamespace: Boolean;
    UseHeadOverride: Boolean;
    RewriteApplied: Boolean;
    DebugFrame: TDebuggerFrame;
    DispatchCompleted: Boolean;
  begin
    Result := False;
    if not HeadInvocationDispatchEnabled then
      Exit(False);
    if HeadDispatchDepth >= MAX_HEAD_DISPATCH_STEPS then
      Exit(False);
    if RulesIndex = EOT then
      Exit(False);

    RewrittenIndex := EOT;
    DispatchSubjectIndex := Index;
    UseHeadOverride := (DispatchHeadName <> '') and (DispatchHeadName <> Name);
    if DispatchNamespace = '' then
      DispatchNamespace := Context.CurrentNamespace;
    PushedSettingNamespace := DispatchNamespace <> '';

    if UseHeadOverride then
    begin
      DispatchSubjectIndex := GlobalTree.CloneSubtree(Index);
      if DispatchSubjectIndex = EOT then
        Exit(False);
      if GlobalTree[DispatchSubjectIndex]^.Id <> OBJ_VARIABLE then
      begin
        GlobalTree.DeleteSubtree(EOT, DispatchSubjectIndex);
        Exit(False);
      end;
      GlobalTree[DispatchSubjectIndex]^.Ref := GlobalTree.Expression.AddToken(
        TK_VARIABLE,
        DispatchHeadName
      );
    end;

    DispatchCompleted := False;
    if DebuggerAttached then
    begin
      DebugFrame := TDebuggerFrame.Create(
        dfkCallableDispatch,
        ResolvedCallableName,
        TreeValue,
        Index,
        RulesIndex
      );
      EmitDebuggerEvent(dekCallableDispatchEnter, DebugFrame);
      HandleDebuggerPause(Context);
    end;

    Inc(HeadDispatchDepth);
    try
      if PushedSettingNamespace then
        Context.PushCallableNamespace(DispatchNamespace);
      if PushedSettingNamespace then
        Context.PushSettingNamespace(DispatchNamespace);

      RewriteApplied := RewriteOneByRules(
           GlobalTree,
           DispatchSubjectIndex,
           RulesIndex,
           Context,
           RewrittenIndex,
           False,
           not UseHeadOverride
         );
      if RewriteApplied and (UseHeadOverride or (RewrittenIndex <> Index)) then
      begin
        if ReplaceNodeInParent(PrevIndex, Index, RewrittenIndex) and
           (RewrittenIndex <> EOT) then
        begin
          if Assigned(Context) then
            Context.MarkDispatchProgress;
          nodes.GetNode(RewrittenIndex, PrevIndex).Evaluate(Context);
        end;
        DispatchCompleted := True;
        Result := True;
        Exit(True);
      end;
      DispatchCompleted := True;
    finally
      if UseHeadOverride and
         (DispatchSubjectIndex <> EOT) and
         (not Result) then
        GlobalTree.DeleteSubtree(EOT, DispatchSubjectIndex);
      if PushedSettingNamespace then
        Context.PopCallableNamespace;
      if PushedSettingNamespace then
        Context.PopSettingNamespace;
      if DebuggerAttached and DispatchCompleted then
      begin
        EmitDebuggerEvent(dekCallableDispatchExit, DebugFrame);
        HandleDebuggerPause(Context);
      end;
      Dec(HeadDispatchDepth);
    end;
  end;
begin
  if not Assigned(Context) then
    Exit;

  Name := TokenValue;
  ResolvedCallableName := Name;
  ResolveMode := GetVariableResolveMode(GlobalTree, Index, PrevIndex);

  if ResolveMode <> vrmSelectionRulesTemplate then
  begin
    if (Name <> '') and Context.IsCallable(Name) then
    begin
      if Context.TryResolveCallableBinding(
           Name,
           ResolvedCallableName,
           RulesIndex,
           DispatchHeadName,
           DispatchNamespace
         ) and
         ((RHS <> EOT) or Context.IsKeyword(Name)) then
      begin
        if TryHeadDispatch then
          Exit;

        RevisionBefore := GlobalTree.Revision;
        inherited Evaluate(Context);

        if (GlobalTree.Revision <> RevisionBefore) and
           IsInvocationNodeAlive and
           (RHS <> EOT) then
        begin
          if Context.IsCallable(Name) and
             Context.TryResolveCallableBinding(
               Name,
               ResolvedCallableName,
               RulesIndex,
               DispatchHeadName,
               DispatchNamespace
             ) and
             TryHeadDispatch then
            Exit;
        end;
        Exit;
      end;

      if RHS <> EOT then
      begin
        inherited Evaluate(Context);
        Exit;
      end;
    end;
  end;

  if ResolveVariableNode(GlobalTree, Context, Index, PrevIndex, ResolveMode) then
    Exit;

  // Allow unresolved invocation heads to continue evaluating their RHS tail.
  // This enables eager evaluation of nested constructs carried as arguments.
  if (ResolveMode <> vrmSelectionRulesTemplate) and
     ((RHS <> EOT) or
      (((TreeNode^.Data and TK_TILDE) = TK_TILDE) and
       TryResolveNativeFunction(Name, NativeContract))) then
    inherited Evaluate(Context);
end;

procedure TVariableNode.Compute(Context: TContext);
var
  Name: ansistring;
  Contract: TNativeFunctionContract;
  Args: TNativeNumericValues;
  Value: TNativeNumericValue;
  Status: TNativeCallStatus;
  ArgIndex: Integer;
  ArgCount: Integer;
  IntValue: Int64;
  FloatValue: Double;
  OldData: Integer;
  ResultOp: Integer;
  MagnitudeFloat: Double;
  MagnitudeInteger: Int64;
begin
  inherited Compute(Context);

  Name := TokenValue;
  if not TryResolveNativeFunction(Name, Contract) then
    Exit;

  ArgCount := 0;
  ArgIndex := RHS;
  while ArgIndex <> EOT do
  begin
    Inc(ArgCount);
    ArgIndex := GlobalTree[ArgIndex]^.RHS;
  end;

  if ArgCount < Contract.MinArity then
    raise Exception.CreateFmt(
      'native function "%s" expects at least %d argument(s), got %d',
      [Contract.CanonicalName, Contract.MinArity, ArgCount]
    );
  if (Contract.MaxArity >= 0) and (ArgCount > Contract.MaxArity) then
    raise Exception.CreateFmt(
      'native function "%s" expects at most %d argument(s), got %d',
      [Contract.CanonicalName, Contract.MaxArity, ArgCount]
    );

  SetLength(Args, ArgCount);
  ArgIndex := RHS;
  ArgCount := 0;
  while ArgIndex <> EOT do
  begin
    if TryReadSignedInteger(ArgIndex, IntValue) then
    begin
      Args[ArgCount].Kind := nnInteger;
      Args[ArgCount].IntValue := IntValue;
      Args[ArgCount].FloatValue := IntValue;
    end
    else if TryReadSignedFloat(ArgIndex, FloatValue) then
    begin
      Args[ArgCount].Kind := nnFloat;
      Args[ArgCount].IntValue := 0;
      Args[ArgCount].FloatValue := FloatValue;
    end
    else
      Exit;
    Inc(ArgCount);
    ArgIndex := GlobalTree[ArgIndex]^.RHS;
  end;

  Status := InvokeNativeFunction(Contract, Args, Value);
  if Status <> ncsSuccess then
    Exit;

  OldData := TreeNode^.Data;
  if RHS <> EOT then
    GlobalTree.DeleteSubtree(Index, RHS);
  TreeNode^.RHS := EOT;
  TreeNode^.LHS := EOT;

  ResultOp := OldData and TK_OPERATOR_MASK;
  if Value.Kind = nnInteger then
  begin
    MagnitudeInteger := Value.IntValue;
    if MagnitudeInteger < 0 then
    begin
      MagnitudeInteger := -MagnitudeInteger;
      ResultOp := GetCombinedOp(ResultOp, TK_MINUS);
    end;
    TreeNode^.Data :=
      OBJ_INTEGER or (OldData and TK_META_MASK) or
      (ResultOp and TK_OPERATOR_MASK);
    TreeNode^.Ref := GlobalTree.Expression.Append(
      TK_INTEGER,
      IntToStr(MagnitudeInteger)
    );
  end
  else
  begin
    MagnitudeFloat := Value.FloatValue;
    if MagnitudeFloat < 0.0 then
    begin
      MagnitudeFloat := -MagnitudeFloat;
      ResultOp := GetCombinedOp(ResultOp, TK_MINUS);
    end;
    TreeNode^.Data :=
      OBJ_FLOAT or (OldData and TK_META_MASK) or
      (ResultOp and TK_OPERATOR_MASK);
    TreeNode^.Ref := GlobalTree.Expression.Append(
      TK_FLOAT,
      FloatToStr(MagnitudeFloat, DefaultFormatSettings)
    );
  end;

  if Assigned(Context) then
    Context.MarkDispatchProgress;
end;

{ TSelectionPolicyNode }

procedure TSelectionPolicyNode.Execute(Context: TContext);
begin
  Evaluate(Context);
end;

procedure TSelectionPolicyNode.Evaluate(Context: TContext);
var
  Strategy: TSelectionStrategyKind;
  PreviousStrategy: TSelectionStrategyKind;
  PreviousExhaustive: Boolean;
  PolicyNode: Integer;
  PayloadNode: Integer;
  PolicyText: ansistring;
  PolicyOperator: Integer;
  HasExhaustiveOverride: Boolean;
  ExhaustiveOverride: Boolean;
begin
  Strategy := DefaultSelectionStrategy;
  PolicyNode := LHS;
  PayloadNode := RHS;
  PolicyOperator := TreeNode^.Data and TK_OPERATOR_MASK;
  HasExhaustiveOverride := False;
  ExhaustiveOverride := False;

  if PolicyNode <> EOT then
  begin
    if (Node[PolicyNode].ObjectId <> OBJ_VARIABLE) and
       (Node[PolicyNode].ObjectId <> OBJ_STRING) then
      raise Exception.CreateFmt(
        'Invalid selection strategy expression: %s',
        [Node[PolicyNode].TreeValue]
      );

    PolicyText := Node[PolicyNode].TokenValue;
    if not TryParseSelectionStrategy(PolicyText, Strategy) then
      raise Exception.CreateFmt('Unknown selection strategy: %s', [PolicyText]);

    GlobalTree.DeleteSubtree(Index, PolicyNode);
    TreeNode^.LHS := EOT;
  end;

  if PolicyOperator <> 0 then
    case PolicyOperator of
      TK_PLUS:
        begin
          HasExhaustiveOverride := True;
          ExhaustiveOverride := True;
        end;
      TK_MINUS:
        begin
          HasExhaustiveOverride := True;
          ExhaustiveOverride := False;
        end;
    else
      raise Exception.CreateFmt(
        'Invalid selector policy operator: %s',
        [TokenFromID(PolicyOperator)]
      );
    end;

  PreviousStrategy := MatcherSelectionStrategy;
  PreviousExhaustive := MatcherExhaustiveSelection;
  MatcherSelectionStrategy := Strategy;
  if HasExhaustiveOverride then
    MatcherExhaustiveSelection := ExhaustiveOverride;
  try
    if PayloadNode <> EOT then
      nodes.GetNode(PayloadNode, Index).Evaluate(Context);
  finally
    MatcherSelectionStrategy := PreviousStrategy;
    MatcherExhaustiveSelection := PreviousExhaustive;
  end;

  PayloadNode := TreeNode^.RHS;
  TreeNode^.RHS := EOT;
  TreeNode^.LHS := PayloadNode;

  if PayloadNode <> EOT then
  begin
    if PrevIndex = EOT then
      GlobalTree.ExpandInline(PrevIndex, Index)
    else
      GlobalTree.Expand(PrevIndex, Index);
  end
  else
    Delete;
end;

function NormalizeDirectiveValue(const Value: ansistring): ansistring;
begin
  Result := Trim(Value);
  if Length(Result) >= 2 then
  begin
    if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
       ((Result[1] = #39) and (Result[Length(Result)] = #39)) then
      Result := Copy(Result, 2, Length(Result) - 2);
  end;
  Result := Trim(Result);
end;

function NormalizeImportPath(const Value: ansistring): ansistring;
begin
  Result := Trim(Value);
  if (Length(Result) >= 2) and
     (Result[1] = '<') and (Result[Length(Result)] = '>') then
    Result := Copy(Result, 2, Length(Result) - 2);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := Trim(Result);
end;

function DirectiveArgumentValue(NodeIndex: Integer): ansistring;
var
  ArgIndex: Integer;
begin
  Result := '';
  if NodeIndex = EOT then
    Exit;
  ArgIndex := GlobalTree[NodeIndex]^.LHS;
  if ArgIndex <> EOT then
    Result := nodes.GetNode(ArgIndex, NodeIndex).TreeValue;
end;

function DirectiveNodeRawValue(NodeIndex: Integer): ansistring;
var
  N: TBaseNode;
begin
  if NodeIndex = EOT then
    Exit('');
  N := nodes.GetNode(NodeIndex, EOT);
  case GlobalTree[NodeIndex]^.Id of
    OBJ_STRING, OBJ_VARIABLE:
      Result := N.TokenValue;
  else
    Result := N.TreeValue;
  end;
end;

procedure CollectDirectiveArguments(NodeIndex: Integer; var Args: array of Integer; out Count: Integer);
var
  Cur: Integer;
  EntryNode: Integer;
begin
  Count := 0;
  if NodeIndex = EOT then
    Exit;

  Cur := GlobalTree[NodeIndex]^.LHS;
  while Cur <> EOT do
  begin
    if GlobalTree[Cur]^.Id = OBJ_SEPARATOR then
    begin
      EntryNode := GlobalTree[Cur]^.LHS;
      Cur := GlobalTree[Cur]^.RHS;
    end
    else
    begin
      EntryNode := Cur;
      Cur := GlobalTree[Cur]^.RHS;
    end;

    if EntryNode = EOT then
      Continue;
    if Count < Length(Args) then
      Args[Count] := EntryNode;
    Inc(Count);
  end;
end;

function JoinTriePath(const Prefix, Suffix: ansistring): ansistring;
begin
  if Prefix = '' then
    Exit(Suffix);
  if Suffix = '' then
    Exit(Prefix);

  if (Suffix[1] = '[') or (Suffix[1] = '.') then
    Exit(Prefix + Suffix);

  Result := Prefix + '.' + Suffix;
end;

{ TPackageNode }

procedure TPackageNode.Execute(Context: TContext);
var
  PackagePath: ansistring;
begin
  if Assigned(Context) then
  begin
    PackagePath := NormalizeImportPath(DirectiveArgumentValue(Index));
    if PackagePath <> '' then
      Context.CurrentNamespace := PackagePath;
  end;
  Delete;
end;

{ TImportNode }

procedure TImportNode.Execute(Context: TContext);
var
  PackagePath: ansistring;
  SourceSegments: TResolvedSourceSegmentArray;
  SegmentIndex: Integer;
  DebugFrame: TDebuggerFrame;
  ImportCompleted: Boolean;
begin
  PackagePath := NormalizeImportPath(DirectiveArgumentValue(Index));
  if PackagePath <> '' then
  begin
    ImportCompleted := False;
    if DebuggerAttached then
    begin
      DebugFrame := TDebuggerFrame.Create(dfkImport, PackagePath, 'import', Index);
      EmitDebuggerEvent(dekImportEnter, DebugFrame);
      HandleDebuggerPause(Context);
    end;
    if Assigned(Context) then
      SourceSegments := ResolveImportDirectiveSegments(PackagePath, Context.CurrentNamespace)
    else
      SourceSegments := ResolveImportDirectiveSegments(PackagePath, '');
    try
      for SegmentIndex := 0 to High(SourceSegments) do
        AppendSourceChunk(
          SourceSegments[SegmentIndex].Text,
          SourceSegments[SegmentIndex].FilePath,
          SourceSegments[SegmentIndex].StartLine
        );
      ImportCompleted := True;
    finally
      if DebuggerAttached and ImportCompleted then
      begin
        EmitDebuggerEvent(dekImportExit, DebugFrame);
        HandleDebuggerPause(Context);
      end;
    end;
  end;
  Delete;
end;

{ TIncludeNode }

procedure TIncludeNode.Execute(Context: TContext);
var
  IncludePath: ansistring;
  SourceSegments: TResolvedSourceSegmentArray;
  SegmentIndex: Integer;
  DebugFrame: TDebuggerFrame;
  IncludeCompleted: Boolean;
begin
  IncludePath := NormalizeDirectiveValue(DirectiveArgumentValue(Index));
  if IncludePath <> '' then
  begin
    IncludeCompleted := False;
    if DebuggerAttached then
    begin
      DebugFrame := TDebuggerFrame.Create(dfkImport, IncludePath, 'include', Index);
      EmitDebuggerEvent(dekImportEnter, DebugFrame);
      HandleDebuggerPause(Context);
    end;
    if Assigned(Context) then
      SourceSegments := ResolveIncludeDirectiveSegments(IncludePath, Context.CurrentNamespace)
    else
      SourceSegments := ResolveIncludeDirectiveSegments(IncludePath, '');
    try
      for SegmentIndex := 0 to High(SourceSegments) do
        AppendSourceChunk(
          SourceSegments[SegmentIndex].Text,
          SourceSegments[SegmentIndex].FilePath,
          SourceSegments[SegmentIndex].StartLine
        );
      IncludeCompleted := True;
    finally
      if DebuggerAttached and IncludeCompleted then
      begin
        EmitDebuggerEvent(dekImportExit, DebugFrame);
        HandleDebuggerPause(Context);
      end;
    end;
  end;
  Delete;
end;

{ TGlobalNode }

procedure TGlobalNode.Execute(Context: TContext);
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  Context.PushGlobalWrites;
  try
    if LHS <> EOT then
      Node[LHS].Execute(Context);
  finally
    Context.PopGlobalWrites;
  end;

  Delete;
end;

procedure TGlobalNode.Evaluate(Context: TContext);
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  Context.PushGlobalWrites;
  try
    if LHS <> EOT then
    begin
      if not ShouldDeferExplicitExecuteInEvaluation(Context, LHS) then
        Node[LHS].Execute(Context);
      if LHS <> EOT then
        Node[LHS].Evaluate(Context);
    end;
  finally
    Context.PopGlobalWrites;
  end;

  if LHS <> EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else
    Delete;
end;

{ TScopeFrameNode }

function TScopeFrameNode.TryResolveBodyAndLabel(
  out BodyIndex: Integer;
  out LabelText: ansistring
): Boolean;
begin
  BodyIndex := LHS;
  LabelText := '';
  Result := False;

  if BodyIndex = EOT then
    Exit(False);
  if (GlobalTree[BodyIndex]^.Id <> OBJ_EVALUATION) or
     (GlobalTree[BodyIndex]^.RHS <> EOT) then
    Exit(False);

  if RHS <> EOT then
  begin
    if ((GlobalTree[RHS]^.Id <> OBJ_VARIABLE) and
        (GlobalTree[RHS]^.Id <> OBJ_STRING)) or
       (GlobalTree[RHS]^.LHS <> EOT) or
       (GlobalTree[RHS]^.RHS <> EOT) then
      Exit(False);
    LabelText := Node[RHS].TokenValue;
  end;

  Result := True;
end;

procedure TScopeFrameNode.CleanupLabelNode;
begin
  if RHS <> EOT then
  begin
    GlobalTree.DeleteSubtree(Index, RHS);
    TreeNode^.RHS := EOT;
  end;
end;

procedure TScopeFrameNode.RunScopedBody(Context: TContext; EvaluateLast: Boolean);
var
  BodyIndex: Integer;
  LabelText: ansistring;
  Cur: Integer;
  NextCur: Integer;
  EntryIndex: Integer;
  EntryPrev: Integer;
  EntryObjectId: Integer;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  if not TryResolveBodyAndLabel(BodyIndex, LabelText) then
    raise Exception.Create('scope requires the form scope { ... }');

  Context.PushExactScope(LabelText);
  try
    Cur := GlobalTree[BodyIndex]^.LHS;
    while Cur <> EOT do
    begin
      if GlobalTree[Cur]^.Id = OBJ_SEPARATOR then
      begin
        EntryIndex := GlobalTree[Cur]^.LHS;
        EntryPrev := Cur;
        NextCur := GlobalTree[Cur]^.RHS;
      end
      else
      begin
        EntryIndex := Cur;
        EntryPrev := BodyIndex;
        NextCur := GlobalTree[Cur]^.RHS;
      end;

      if EntryIndex <> EOT then
      begin
        EntryObjectId := GlobalTree[EntryIndex]^.Id;
        if EvaluateLast and (NextCur = EOT) then
          nodes.GetNode(EntryIndex, EntryPrev).Evaluate(Context)
        else if EntryObjectId in [OBJ_OUTPUT, OBJ_TREE_OUTPUT, OBJ_IR_OUTPUT] then
          nodes.GetNode(EntryIndex, EntryPrev).Execute(Context)
        else
          nodes.GetNode(EntryIndex, EntryPrev).Evaluate(Context);
      end;

      Cur := NextCur;
    end;

    if BodyIndex <> EOT then
      GlobalTree.Expand(Index, BodyIndex);
  finally
    Context.PopExactScope;
  end;

  CleanupLabelNode;
  if LHS <> EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else
    Delete;
end;

procedure TScopeFrameNode.Execute(Context: TContext);
begin
  RunScopedBody(Context, False);
end;

procedure TScopeFrameNode.Evaluate(Context: TContext);
begin
  RunScopedBody(Context, True);
end;

{ TJsonLoadNode }

procedure ResolveStructuredLoadArgs(
  const LoaderName: ansistring;
  InvocationIndex: Integer;
  out SourcePath: ansistring;
  out DestPrefix: ansistring
);
var
  ArgNodes: array[0..7] of Integer;
  ArgCount: Integer;
begin
  CollectDirectiveArguments(InvocationIndex, ArgNodes, ArgCount);
  if ArgCount <> 2 then
    raise Exception.CreateFmt(
      '%s expects exactly 2 arguments: %s "<file>" <prefix>',
      [LoaderName, LoaderName]
    );

  SourcePath := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[0]));
  if SourcePath = '' then
    raise Exception.CreateFmt('%s source path cannot be empty', [LoaderName]);

  if GlobalTree[ArgNodes[1]]^.Id = OBJ_VARIABLE then
    DestPrefix := GlobalTree.Expression.TokenValue(GlobalTree[ArgNodes[1]]^.Ref)
  else
    DestPrefix := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[1]));
  if DestPrefix = '' then
    raise Exception.CreateFmt('%s destination prefix cannot be empty', [LoaderName]);

  if not FileExists(SourcePath) then
    raise Exception.CreateFmt('%s source file not found: %s', [LoaderName, SourcePath]);
end;

procedure MaterializeLoadedDocument(
  const LoaderName: ansistring;
  Context: TContext;
  const DestPrefix: ansistring;
  RootValue: TJSONData
);
begin
  if not MaterializeJsonValueAtPath(Context, DestPrefix, RootValue) then
    raise Exception.CreateFmt('%s failed to materialize payload into prefix: %s', [LoaderName, DestPrefix]);
end;

procedure TJsonLoadNode.Execute(Context: TContext);
var
  SourcePath: ansistring;
  DestPrefix: ansistring;
  JsonText: ansistring;
  JsonRoot: TJSONData;
  JsonFile: TStringList;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  ResolveStructuredLoadArgs('json_load', Index, SourcePath, DestPrefix);

  JsonFile := TStringList.Create;
  JsonRoot := nil;
  try
    JsonFile.LoadFromFile(SourcePath);
    JsonText := JsonFile.Text;
    try
      JsonRoot := GetJSON(JsonText);
    except
      on E: Exception do
        raise Exception.CreateFmt(
          'json_load parse error in "%s": %s',
          [SourcePath, E.Message]
        );
    end;

    MaterializeLoadedDocument('json_load', Context, DestPrefix, JsonRoot);
  finally
    JsonRoot.Free;
    JsonFile.Free;
  end;

  Delete;
end;

{ TJsonEncodeNode }

procedure TJsonEncodeNode.Evaluate(Context: TContext);
var
  PathText: ansistring;
begin
  PathText := ResolveQueryArgumentText(Index, Context, 'json_encode');
  ResetInvocationNodeAsString(Index, EncodeJsonPath(Context, PathText));
end;

{ TJsonSaveNode }

procedure ResolveJsonSaveArgs(
  InvocationIndex: Integer;
  out SourcePath: ansistring;
  out DestPath: ansistring
);
var
  ArgNodes: array[0..7] of Integer;
  ArgCount: Integer;
begin
  CollectDirectiveArguments(InvocationIndex, ArgNodes, ArgCount);
  if ArgCount <> 2 then
    raise Exception.Create(
      'json_save expects exactly 2 arguments: json_save <source-prefix> "<file>"'
    );

  if GlobalTree[ArgNodes[0]]^.Id = OBJ_VARIABLE then
    SourcePath := GlobalTree.Expression.TokenValue(GlobalTree[ArgNodes[0]]^.Ref)
  else
    SourcePath := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[0]));
  SourcePath := Trim(SourcePath);
  if SourcePath = '' then
    raise Exception.Create('json_save source prefix cannot be empty');

  DestPath := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[1]));
  DestPath := Trim(DestPath);
  if DestPath = '' then
    raise Exception.Create('json_save destination path cannot be empty');
end;

procedure WriteJsonFileAtomic(
  const DestPath: ansistring;
  const JsonText: ansistring
);
var
  TempPath: ansistring;
  ParentPath: ansistring;
  Payload: ansistring;
  Stream: TFileStream;
begin
  ParentPath := ExtractFileDir(ExpandFileName(DestPath));
  if (ParentPath <> '') and (not DirectoryExists(ParentPath)) then
    raise Exception.CreateFmt(
      'json_save destination directory not found: %s',
      [ParentPath]
    );

  TempPath := DestPath + '.tmp.' + IntToStr(fpGetPid) + '.' +
              IntToStr(GetTickCount64);
  Payload := JsonText + LineEnding;
  Stream := nil;
  try
    Stream := TFileStream.Create(TempPath, fmCreate or fmShareExclusive);
    if Payload <> '' then
      Stream.WriteBuffer(Payload[1], Length(Payload));
    FreeAndNil(Stream);
    if fpRename(PChar(TempPath), PChar(DestPath)) <> 0 then
      raise Exception.CreateFmt(
        'json_save failed to replace "%s": %s',
        [DestPath, SysErrorMessage(fpGetErrNo)]
      );
  except
    Stream.Free;
    if FileExists(TempPath) then
      DeleteFile(TempPath);
    raise;
  end;
end;

procedure TJsonSaveNode.Execute(Context: TContext);
var
  SourcePath: ansistring;
  DestPath: ansistring;
  JsonValue: TJSONData;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  ResolveJsonSaveArgs(Index, SourcePath, DestPath);
  JsonValue := BuildJsonDataFromPath(Context, SourcePath);
  try
    WriteJsonFileAtomic(DestPath, JsonValue.AsJSON);
  finally
    JsonValue.Free;
  end;
  Delete;
end;

procedure EmitJsonDisplay(InvocationIndex: Integer; Context: TContext);
var
  InvocationArgs: TNodeIndexArray;
  MimeType: ansistring;
  LowerMimeType: ansistring;
  PathText: ansistring;
begin
  CollectInvocationEntries(InvocationIndex, InvocationArgs);
  if Length(InvocationArgs) <> 2 then
    raise Exception.Create(
      'display expects 2 arguments: display <json-mime> <path>'
    );

  MimeType := ResolveRenderArgumentText(InvocationArgs[0], Context, False);
  LowerMimeType := LowerCase(Trim(MimeType));
  if (LowerMimeType <> 'application/json') and
     ((Length(LowerMimeType) < 5) or
      (Copy(LowerMimeType, Length(LowerMimeType) - 4, 5) <> '+json')) then
    raise Exception.CreateFmt(
      'display MVP supports JSON MIME types only, got %s',
      [MimeType]
    );

  PathText := ResolveRenderArgumentText(InvocationArgs[1], Context, False);
  if Pos('application/vnd.vegalite.', LowerMimeType) = 1 then
    EmitRuntimeJsonOutput(
      MimeType,
      BuildVegaLiteJsonDataFromPath(Context, PathText)
    )
  else
    EmitRuntimeJsonOutput(
      MimeType,
      BuildJsonDataFromPath(Context, PathText)
    );
end;

{ TDisplayNode }

procedure TDisplayNode.Execute(Context: TContext);
begin
  EmitJsonDisplay(Index, Context);
  Delete;
end;

procedure TDisplayNode.Evaluate(Context: TContext);
begin
  Execute(Context);
end;

{ TYamlLoadNode }

procedure TYamlLoadNode.Execute(Context: TContext);
var
  SourcePath: ansistring;
  DestPrefix: ansistring;
  YamlParser: TYAMLParser;
  YamlRoot: TYAMLStream;
  JsonRoot: TJSONData;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  ResolveStructuredLoadArgs('yaml_load', Index, SourcePath, DestPrefix);

  YamlParser := TYAMLParser.Create(SourcePath);
  YamlRoot := nil;
  JsonRoot := nil;
  try
    try
      YamlRoot := YamlParser.Parse;
      JsonRoot := YAMLToJSON(YamlRoot);
    except
      on E: Exception do
        raise Exception.CreateFmt(
          'yaml_load parse error in "%s": %s',
          [SourcePath, E.Message]
        );
    end;

    MaterializeLoadedDocument('yaml_load', Context, DestPrefix, JsonRoot);
  finally
    JsonRoot.Free;
    YamlRoot.Free;
    YamlParser.Free;
  end;

  Delete;
end;

{ TSystemNode }

procedure TSystemNode.Execute(Context: TContext);
var
  ArgNodes: array[0..31] of Integer;
  ArgCount: Integer;
  I: Integer;
  CommandName: ansistring;
  DestPrefix: ansistring;
  ErrorText: ansistring;
  ResultHandle: ansistring;
  CommandArgs: TCommandArgs;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  CollectDirectiveArguments(Index, ArgNodes, ArgCount);
  if ArgCount < 2 then
    raise Exception.Create('system expects at least 2 arguments: system <command> <dest-prefix> [args...]');

  CommandName := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[0]));
  if CommandName = '' then
    raise Exception.Create('system command name cannot be empty');

  if Node[ArgNodes[1]].ObjectId = OBJ_VARIABLE then
    DestPrefix := Node[ArgNodes[1]].TokenValue
  else
    DestPrefix := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[1]));
  if DestPrefix = '' then
    raise Exception.Create('system destination prefix cannot be empty');

  SetLength(CommandArgs, ArgCount - 2);
  for I := 0 to High(CommandArgs) do
  begin
    if Node[ArgNodes[I + 2]].ObjectId = OBJ_VARIABLE then
      CommandArgs[I] := Node[ArgNodes[I + 2]].TokenValue
    else
      CommandArgs[I] := NormalizeDirectiveValue(DirectiveNodeRawValue(ArgNodes[I + 2]));
  end;

  if not ExecuteSystemCommand(
    Context,
    CommandName,
    DestPrefix,
    CommandArgs,
    ResultHandle,
    ErrorText
  ) then
  begin
    if ErrorText <> '' then
      raise Exception.CreateFmt('system %s: %s', [CommandName, ErrorText])
    else
      raise Exception.CreateFmt('system %s failed', [CommandName]);
  end;

  if ResultHandle <> '' then
  begin
    if LHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, LHS);
      TreeNode^.LHS := EOT;
    end;
    if RHS <> EOT then
    begin
      GlobalTree.DeleteSubtree(Index, RHS);
      TreeNode^.RHS := EOT;
    end;
    TStringNode.InitTreeNode(Index);
    TreeNode^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(ResultHandle));
  end
  else
    Delete;
end;

{ TAssignPathNode }

procedure TAssignPathNode.ApplyAssignPath(Context: TContext; EvaluateInputs: Boolean);
var
  ArgNodes: array[0..7] of Integer;
  ArgCount: Integer;
  UseThreeArgumentForm: Boolean;
  DestArg: Integer;
  PathArg: Integer;
  ValueArg: Integer;
  PairArg: Integer;
  PairNodeIndex: Integer;
  PairValueIndex: Integer;
  DestPrefix: ansistring;
  PathSuffix: ansistring;
  TargetPath: ansistring;
  ValueRef: Integer;
  function PeelTransparentWrappers(NodeIndex: Integer): Integer;
  var
    WrapperKind: Integer;
  begin
    Result := NodeIndex;
    while (Result <> EOT) and
          (GlobalTree[Result]^.RHS = EOT) and
          (GlobalTree[Result]^.LHS <> EOT) do
    begin
      WrapperKind := nodes.GetNode(Result, Index).ObjectId;
      if (WrapperKind <> OBJ_SCOPE) and (WrapperKind <> OBJ_EXPRESSION) then
        Break;
      Result := GlobalTree[Result]^.LHS;
    end;
  end;
  function TryResolveScalarPathText(
    NodeIndex: Integer;
    EvaluateArg: Boolean;
    out Value: ansistring
  ): Boolean;
  var
    ProbeNode: Integer;
    InitialIndex: Integer;
    ResolvedIndex: Integer;
    BoundIndex: Integer;
    VariableName: ansistring;
    ResolvedNode: TBaseNode;
  begin
    Value := '';
    ProbeNode := CloneDetachedArgument(NodeIndex);
    try
      InitialIndex := PeelTransparentWrappers(ProbeNode);
      if EvaluateArg and (ProbeNode <> EOT) and (InitialIndex <> EOT) then
        case nodes.GetNode(InitialIndex, Index).ObjectId of
          OBJ_STRING, OBJ_VARIABLE, OBJ_INTEGER, OBJ_FLOAT, OBJ_COMPLEX, OBJ_NULL:
            ;
        else
          nodes.GetNode(ProbeNode, EOT).Evaluate(Context);
        end;

      ResolvedIndex := PeelTransparentWrappers(ProbeNode);
      if ResolvedIndex = EOT then
        Exit(False);

      if nodes.GetNode(ResolvedIndex, Index).ObjectId = OBJ_VARIABLE then
      begin
        VariableName := nodes.GetNode(ResolvedIndex, Index).TokenValue;
        if VariableName <> '' then
        begin
          BoundIndex := EOT;
          if Context.TryFindVariable(VariableName, BoundIndex) then
            ResolvedIndex := PeelTransparentWrappers(BoundIndex);
        end;
      end;

      if ResolvedIndex = EOT then
        Exit(False);

      ResolvedNode := nodes.GetNode(ResolvedIndex, Index);
      if (ResolvedNode.GetOperator <> '') or (GlobalTree[ResolvedIndex]^.RHS <> EOT) then
        Exit(False);

      case ResolvedNode.ObjectId of
        OBJ_STRING, OBJ_VARIABLE, OBJ_INTEGER, OBJ_FLOAT, OBJ_COMPLEX, OBJ_NULL:
          begin
            Value := NormalizeDirectiveValue(DirectiveNodeRawValue(ResolvedIndex));
            Exit(True);
          end;
      else
        Exit(False);
      end;
    finally
      if ProbeNode <> EOT then
        GlobalTree.DeleteSubtree(EOT, ProbeNode);
    end;
  end;
  function ResolveScalarPathText(
    NodeIndex: Integer;
    EvaluateArg: Boolean;
    const Role: ansistring
  ): ansistring;
  begin
    if not TryResolveScalarPathText(NodeIndex, EvaluateArg, Result) then
      raise Exception.CreateFmt(
        'assign_path %s must resolve to scalar path text; wrap structured values in (...) or {...}',
        [Role]
      );
  end;
  function ClonePreparedValue(NodeIndex: Integer; EvaluateArg: Boolean): Integer;
  var
    ProbeNode: Integer;
    EffectiveIndex: Integer;
    PreserveWrapper: Boolean;
    ClonedValue: Integer;
    WrappedValue: Integer;
  begin
    Result := EOT;
    ProbeNode := CloneDetachedArgument(NodeIndex);
    try
      if EvaluateArg and (ProbeNode <> EOT) then
        nodes.GetNode(ProbeNode, EOT).Evaluate(Context);

      EffectiveIndex := PeelTransparentWrappers(ProbeNode);
      if EffectiveIndex = EOT then
        Exit(EOT);

      // Keep object-like pair wrappers so leaf object fields remain discoverable
      // via the existing leaf-field fallback helpers.
      PreserveWrapper := (EffectiveIndex <> ProbeNode) and
                         (nodes.GetNode(EffectiveIndex, Index).ObjectId = OBJ_VARIABLE_SUBTREE);
      if PreserveWrapper then
        Result := GlobalTree.CloneSubtree(ProbeNode)
      else
      begin
        ClonedValue := GlobalTree.CloneSubtree(EffectiveIndex);
        if (ClonedValue <> EOT) and
           (nodes.GetNode(ClonedValue, Index).ObjectId = OBJ_VARIABLE_SUBTREE) then
        begin
          WrappedValue := GlobalTree.AllocateNode;
          TExpressionNode.InitTreeNode(WrappedValue);
          GlobalTree[WrappedValue]^.LHS := ClonedValue;
          Result := WrappedValue;
        end
        else
          Result := ClonedValue;
      end;
    finally
      if ProbeNode <> EOT then
        GlobalTree.DeleteSubtree(EOT, ProbeNode);
    end;
  end;
  procedure DecodeAssignArguments;
  var
    PairProbeIndex: Integer;
  begin
    PairArg := EOT;
    UseThreeArgumentForm := False;
    PairProbeIndex := EOT;
    if ArgCount >= 2 then
      PairProbeIndex := PeelTransparentWrappers(ArgNodes[1]);

    if (PairProbeIndex <> EOT) and
       (nodes.GetNode(PairProbeIndex, Index).ObjectId = OBJ_VARIABLE_SUBTREE) then
    begin
      DestArg := ArgNodes[0];
      PathArg := EOT;
      ValueArg := EOT;
      PairArg := ArgNodes[1];
    end
    else if ArgCount = 2 then
    begin
      DestArg := EOT;
      PathArg := ArgNodes[0];
      ValueArg := ArgNodes[1];
    end
    else if ArgCount = 3 then
    begin
      UseThreeArgumentForm := True;
      DestArg := ArgNodes[0];
      PathArg := ArgNodes[1];
      ValueArg := ArgNodes[2];
    end
    else
      raise Exception.Create(
        'assign_path does not accept unboxed structural values; wrap the value in (...) or {...}'
      );
  end;
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  FillChar(ArgNodes, SizeOf(ArgNodes), #$FF);
  CollectDirectiveArguments(Index, ArgNodes, ArgCount);
  if ArgCount < 2 then
    raise Exception.Create(
      'assign_path expects 2 or 3 arguments: assign_path <path> <value> or assign_path <root> <path> <value>'
    );

  DecodeAssignArguments;

  if UseThreeArgumentForm or (PairArg <> EOT) then
    DestPrefix := ResolveScalarPathText(DestArg, EvaluateInputs, 'root')
  else
    DestPrefix := '';

  if PairArg <> EOT then
  begin
    PairNodeIndex := PeelTransparentWrappers(PairArg);
    if (PairNodeIndex = EOT) or (GlobalTree[PairNodeIndex]^.Id <> OBJ_VARIABLE_SUBTREE) then
      raise Exception.Create('assign_path expected a variable-subtree pair as second argument');
    if GlobalTree[PairNodeIndex]^.Ref = EOT then
      raise Exception.Create('assign_path pair key is missing');
    PathSuffix := NormalizeDirectiveValue(
      GlobalTree.Expression.TokenValue(GlobalTree[PairNodeIndex]^.Ref)
    );
    PairValueIndex := GlobalTree[PairNodeIndex]^.LHS;
    if PairValueIndex = EOT then
      raise Exception.Create('assign_path pair value is missing');
    ValueRef := ClonePreparedValue(PairValueIndex, EvaluateInputs);
    if ValueRef = EOT then
      raise Exception.Create('assign_path failed to clone pair value');
  end
  else
  begin
    PathSuffix := ResolveScalarPathText(PathArg, EvaluateInputs, 'path');
    if ValueArg = EOT then
      raise Exception.Create('assign_path missing value argument');
    ValueRef := ClonePreparedValue(ValueArg, EvaluateInputs);
    if ValueRef = EOT then
      raise Exception.Create('assign_path failed to clone value');
  end;
  if (PathSuffix = '') and (DestPrefix = '') then
    raise Exception.Create('assign_path target path cannot be empty');

  TargetPath := JoinTriePath(DestPrefix, PathSuffix);
  if TargetPath = '' then
    raise Exception.Create('assign_path resolved empty target path');

  Context.AddVariable(TargetPath, ValueRef);
  Context.RemoveCallable(TargetPath);
  Delete;
end;

procedure TAssignPathNode.Execute(Context: TContext);
begin
  ApplyAssignPath(Context, False);
end;

procedure TAssignPathNode.Evaluate(Context: TContext);
begin
  ApplyAssignPath(Context, True);
end;

{ TExecNode }

procedure TExecNode.Evaluate(Context: TContext);
begin
  if not Assigned(Context) then
  begin
    Delete;
    Exit;
  end;

  if LHS <> EOT then
  begin
    if not ShouldDeferExplicitExecuteInEvaluation(Context, LHS) then
      Node[LHS].Execute(Context);
    if LHS <> EOT then
      Node[LHS].Evaluate(Context);
  end;

  if LHS <> EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else
    Delete;
end;

{ TExplodeNode }

procedure TExplodeNode.Evaluate(Context: TContext);
var
  PrevNode: Integer;
  Current: Integer;
  Tail: Integer;
  Last: Integer;
  NextNode: Integer;
  I: Integer;
  RawValue: ansistring;
  CharValue: ansistring;
begin
  if LHS <> EOT then
    Node[LHS].Evaluate(Context);

  PrevNode := Index;
  Current := LHS;
  while Current <> EOT do
  begin
    if Node[Current].ObjectId = OBJ_STRING then
    begin
      if not UnquoteStringLiteral(Node[Current].TokenValue, RawValue) then
      begin
        PrevNode := Current;
        Current := GlobalTree[Current]^.RHS;
        Continue;
      end;

      Tail := GlobalTree[Current]^.RHS;
      if RawValue = '' then
      begin
        GlobalTree.Delete(PrevNode, Current);
        Current := Tail;
        Continue;
      end;

      CharValue := Copy(RawValue, 1, 1);
      GlobalTree[Current]^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(CharValue));
      GlobalTree[Current]^.RHS := EOT;

      Last := Current;
      for I := 2 to Length(RawValue) do
      begin
        NextNode := GlobalTree.AllocateNode;
        TStringNode.InitTreeNode(NextNode);
        CharValue := Copy(RawValue, I, 1);
        GlobalTree[NextNode]^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(CharValue));
        GlobalTree.LinkRHS(Last, NextNode);
        Last := NextNode;
      end;

      GlobalTree.LinkRHS(Last, Tail);
      PrevNode := Last;
      Current := Tail;
      Continue;
    end;

    PrevNode := Current;
    Current := GlobalTree[Current]^.RHS;
  end;

  if PrevIndex = EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else
    GlobalTree.Expand(PrevIndex, Index);
end;

{ TImplodeNode }

procedure TImplodeNode.Evaluate(Context: TContext);
var
  Current: Integer;
  NextNode: Integer;
  Combined: ansistring;
  Piece: ansistring;
begin
  if LHS <> EOT then
    Node[LHS].Evaluate(Context);

  Current := LHS;
  while Current <> EOT do
  begin
    if Node[Current].ObjectId <> OBJ_STRING then
    begin
      Current := GlobalTree[Current]^.RHS;
      Continue;
    end;

    if not UnquoteStringLiteral(Node[Current].TokenValue, Combined) then
    begin
      Current := GlobalTree[Current]^.RHS;
      Continue;
    end;

    NextNode := GlobalTree[Current]^.RHS;
    while (NextNode <> EOT) and (Node[NextNode].ObjectId = OBJ_STRING) do
    begin
      if UnquoteStringLiteral(Node[NextNode].TokenValue, Piece) then
        Combined := Combined + Piece
      else
        Break;
      GlobalTree.Delete(Current, NextNode);
      NextNode := GlobalTree[Current]^.RHS;
    end;

    GlobalTree[Current]^.Ref := GlobalTree.Expression.Append(TK_STRING, QuoteStringLiteral(Combined));
    Current := GlobalTree[Current]^.RHS;
  end;

  if PrevIndex = EOT then
    GlobalTree.ExpandInline(PrevIndex, Index)
  else
    GlobalTree.Expand(PrevIndex, Index);
end;

//procedure TRepeatNode.Expand(Context: TContext);
//begin
  // if LHS <> EOT then Node[LHS]^.ExpandRepeat(Context, Src);
  // if RHS <> EOT then Node[RHS]^.ExpandRepeat(Context, Src);
//end;

{ TNumericalNode }

function IsBucketNumericNode(NodeIndex: Integer): Boolean; forward;
function IsQuaternionMultiplicationPair(Index1, Index2: Integer): Boolean; forward;

procedure TNumericalNode.Recurse(Context: TContext; NextIndex: Integer);
var
  CurrentIndex: Integer;
  RevisionBefore: QWord;
  RevisionAfterCombine: QWord;
  PreviousRHS: Integer;
  Candidate: Integer;
begin
  CurrentIndex := NextIndex;
  while True do
  begin
    if CurrentIndex = EOT then
    begin
      ApplyUnaryAndStoreSelf;
      Break;
    end;

    // Q: multiple buckets per imaginary component.
    //    TryCombineSiblingAndStore compatible with multiplication.
    if IsNumericNodeForCompute(CurrentIndex) or
       IsQuaternionMultiplicationPair(Index, CurrentIndex) then
    begin
      PreviousRHS := RHS;
      RevisionBefore := GlobalTree.Revision;
      if not TryCombineSiblingAndStore(CurrentIndex) then
        Break;
      GlobalTree.Delete(Index, CurrentIndex);
      RevisionAfterCombine := GlobalTree.Revision;
      if (RHS = PreviousRHS) and (RevisionAfterCombine = RevisionBefore) then
        Break;
      CurrentIndex := RHS;
      Continue;
    end;

    RevisionBefore := GlobalTree.Revision;
    Node[CurrentIndex].Compute(Context);
    Candidate := CurrentIndex;
    if (GlobalTree.Revision <> RevisionBefore) or (RHS <> CurrentIndex) then
      Candidate := RHS;
    if (Candidate <> EOT) and
       (IsNumericNodeForCompute(Candidate) or
        IsQuaternionMultiplicationPair(Index, Candidate)) then
    begin
      CurrentIndex := Candidate;
      Continue;
    end;
    Break;
  end;
end;

function GetImaginaryComponent(NodeIndex: Integer): Integer;
begin
  if NodeIndex = EOT then
    Result := -1
  else
    Result := GlobalTree[NodeIndex]^.Data and TK_EXTRA_MASK;
end;

procedure SetImaginaryComponent(NodeIndex, Component: Integer);
begin
  GlobalTree[NodeIndex]^.Data :=
    (GlobalTree[NodeIndex]^.Data and (not TK_EXTRA_MASK)) or
    (Component and TK_EXTRA_MASK);
end;

function IsBucketNumericNode(NodeIndex: Integer): Boolean;
begin
  Result := (NodeIndex <> EOT) and
            ((GlobalTree[NodeIndex]^.Id = OBJ_INTEGER) or
             (GlobalTree[NodeIndex]^.Id = OBJ_FLOAT));
end;

function IsQuaternionMultiplicationPair(Index1, Index2: Integer): Boolean;
var
  XOp, YOp: Integer;
  XComponent, YComponent: Integer;
  ResultComponent, BasisSignOp: Integer;
begin
  Result := False;
  if (not IsBucketNumericNode(Index1)) or
     (not IsBucketNumericNode(Index2)) then
    Exit;

  XOp := GlobalTree[Index1]^.Data and TK_OPERATOR_MASK;
  YOp := GlobalTree[Index2]^.Data and TK_OPERATOR_MASK;
  if (XOp and YOp and TK_MULTIPLY) = 0 then
    Exit;
  if ((XOp or YOp) and TK_DIVIDE) <> 0 then
    Exit;

  XComponent := GetImaginaryComponent(Index1);
  YComponent := GetImaginaryComponent(Index2);
  if (not IsKnownImaginaryComponent(XComponent)) or
     (not IsKnownImaginaryComponent(YComponent)) then
    Exit;
  if (XComponent = 0) and (YComponent = 0) then
    Exit;

  Result := CombineQuaternionBasis(
    XComponent, YComponent, ResultComponent, BasisSignOp
  );
end;

function IsAdditiveBucketOperand(Op: Integer): Boolean;
const
  ADDITIVE_BUCKET_OPERATOR_MASK = TK_PLUS or TK_MINUS or TK_BINARY;
begin
  Result := ((Op and (not ADDITIVE_BUCKET_OPERATOR_MASK)) = 0) and
            ((Op = 0) or ((Op and (TK_PLUS or TK_MINUS)) <> 0));
end;

procedure StoreIntegerBucketValue(NodeIndex, Component, Op: Integer; Value: Int64);
var
  TextValue: ansistring;
begin
  GlobalTree[NodeIndex]^.Id := OBJ_INTEGER;
  if Value < 0 then
  begin
    Value := -Value;
    Op := TK_MINUS;
  end;
  TextValue := IntToStr(Value) + ImaginaryComponentSuffix(Component);
  GlobalTree[NodeIndex]^.Ref := GlobalTree.Expression.Append(
    NumericTokenId(TK_INTEGER, Component), TextValue
  );
  SetImaginaryComponent(NodeIndex, Component);
  GlobalTree[NodeIndex]^.Data :=
    (GlobalTree[NodeIndex]^.Data and (not TK_OPERATOR_MASK)) or
    (Op and TK_OPERATOR_MASK);
end;

procedure StoreFloatBucketValue(NodeIndex, Component, Op: Integer; Value: Double);
var
  TextValue: ansistring;
begin
  GlobalTree[NodeIndex]^.Id := OBJ_FLOAT;
  if Value < 0.0 then
  begin
    Value := -Value;
    Op := TK_MINUS;
  end;
  TextValue := FloatToStr(Value, DefaultFormatSettings) + ImaginaryComponentSuffix(Component);
  GlobalTree[NodeIndex]^.Ref := GlobalTree.Expression.Append(
    NumericTokenId(TK_FLOAT, Component), TextValue
  );
  SetImaginaryComponent(NodeIndex, Component);
  GlobalTree[NodeIndex]^.Data :=
    (GlobalTree[NodeIndex]^.Data and (not TK_OPERATOR_MASK)) or
    (Op and TK_OPERATOR_MASK);
end;

procedure StoreBucketValue(NodeIndex: Integer; const Bucket: TImaginaryBucket; IsFirst: Boolean);
var
  Op: Integer;
begin
  if IsFirst then
    Op := TK_PLUS
  else
    Op := 0;

  if Bucket.IsFloat then
    StoreFloatBucketValue(NodeIndex, Bucket.Component, Op, Bucket.FloatValue)
  else
    StoreIntegerBucketValue(NodeIndex, Bucket.Component, Op, Bucket.IntValue);
end;

procedure EmitBucketChain(
  NodeIndex: Integer;
  const Buckets: TImaginaryBuckets;
  TailIndex: Integer
);
var
  I: Integer;
  Emitted: Boolean;
  LastEmitted: Integer;
  NewNode: Integer;
begin
  Emitted := False;
  LastEmitted := EOT;
  for I := 0 to High(Buckets) do
  begin
    if (not Buckets[I].HasValue) or IsZeroBucket(Buckets[I]) then
      Continue;

    if not Emitted then
    begin
      StoreBucketValue(NodeIndex, Buckets[I], True);
      LastEmitted := NodeIndex;
      Emitted := True;
    end
    else
    begin
      NewNode := GlobalTree.AllocateNode;
      if Buckets[I].IsFloat then
        TFloatNode.InitTreeNode(NewNode)
      else
        TIntegerNode.InitTreeNode(NewNode);
      StoreBucketValue(NewNode, Buckets[I], False);
      GlobalTree.LinkRHS(LastEmitted, NewNode);
      LastEmitted := NewNode;
    end;
  end;

  if not Emitted then
  begin
    StoreIntegerBucketValue(NodeIndex, 0, TK_PLUS, 0);
    LastEmitted := NodeIndex;
  end;

  if TailIndex <> EOT then
    GlobalTree.LinkRHS(LastEmitted, TailIndex);
end;

function TryExtractQuaternionValue(ExpressionIndex: Integer; out Buckets: TImaginaryBuckets): Boolean;
var
  CurrentIndex: Integer;
  CurrentOp: Integer;
  Component: Integer;
  BucketIndex: Integer;
  IntValue: Int64;
  FloatValue: Double;
begin
  Result := False;
  InitializeImaginaryBuckets(Buckets);

  if (ExpressionIndex = EOT) or
     (GlobalTree[ExpressionIndex]^.Id <> OBJ_EXPRESSION) then
    Exit;

  CurrentIndex := GlobalTree[ExpressionIndex]^.LHS;
  if CurrentIndex = EOT then
    Exit;

  while CurrentIndex <> EOT do
  begin
    if not IsBucketNumericNode(CurrentIndex) then
      Exit;

    CurrentOp := GlobalTree[CurrentIndex]^.Data and TK_OPERATOR_MASK;
    if not IsAdditiveBucketOperand(CurrentOp) then
      Exit;

    Component := GetImaginaryComponent(CurrentIndex);
    if not IsKnownImaginaryComponent(Component) then
      Exit;

    BucketIndex := ImaginaryBucketIndex(Component);
    if BucketIndex < 0 then
      Exit;

    if GlobalTree[CurrentIndex]^.Id = OBJ_FLOAT then
    begin
      TNumericalNode(GetNode(CurrentIndex)).GetValue(FloatValue);
      if (CurrentOp and TK_MINUS) <> 0 then
        FloatValue := -FloatValue;
      AddFloatToBucket(Buckets[BucketIndex], FloatValue);
    end
    else
    begin
      TNumericalNode(GetNode(CurrentIndex)).GetValue(IntValue);
      if (CurrentOp and TK_MINUS) <> 0 then
        IntValue := -IntValue;
      AddIntegerToBucket(Buckets[BucketIndex], IntValue);
    end;

    CurrentIndex := GlobalTree[CurrentIndex]^.RHS;
  end;

  Result := True;
end;

function TryInvertQuaternionExpressionValue(ExpressionIndex: Integer): Boolean;
var
  ExpressionOp: Integer;
  SourceBuckets: TImaginaryBuckets;
  ResultBuckets: TImaginaryBuckets;
begin
  Result := False;
  if (ExpressionIndex = EOT) or
     (GlobalTree[ExpressionIndex]^.Id <> OBJ_EXPRESSION) then
    Exit;

  ExpressionOp := GlobalTree[ExpressionIndex]^.Data and TK_OPERATOR_MASK;
  if ExpressionOp <> TK_DIVIDE then
    Exit;

  if GlobalTree[ExpressionIndex]^.RHS <> EOT then
    Exit;

  if not TryExtractQuaternionValue(ExpressionIndex, SourceBuckets) then
    Exit;
  if not TryInvertQuaternionValue(SourceBuckets, ResultBuckets) then
    Exit;

  GlobalTree.DeleteSubtree(ExpressionIndex, GlobalTree[ExpressionIndex]^.LHS);
  GlobalTree[ExpressionIndex]^.LHS := EOT;
  GlobalTree[ExpressionIndex]^.Data :=
    (GlobalTree[ExpressionIndex]^.Data and (not TK_OPERATOR_MASK)) or TK_PLUS;
  EmitBucketChain(ExpressionIndex, ResultBuckets, EOT);
  Result := True;
end;

function TryDistributeQuaternionExpressionProduct(PrevIndex, ExpressionIndex: Integer): Boolean;
var
  RightIndex: Integer;
  LeftOp: Integer;
  RightOp: Integer;
  LeftBuckets: TImaginaryBuckets;
  RightBuckets: TImaginaryBuckets;
  ResultBuckets: TImaginaryBuckets;
begin
  Result := False;
  if (ExpressionIndex = EOT) or
     (GlobalTree[ExpressionIndex]^.Id <> OBJ_EXPRESSION) then
    Exit;
  if (PrevIndex <> EOT) and (GlobalTree[PrevIndex]^.LHS <> ExpressionIndex) then
    Exit;

  RightIndex := GlobalTree[ExpressionIndex]^.RHS;
  if (RightIndex = EOT) or
     (GlobalTree[RightIndex]^.Id <> OBJ_EXPRESSION) or
     (GlobalTree[RightIndex]^.RHS <> EOT) then
    Exit;

  LeftOp := GlobalTree[ExpressionIndex]^.Data and TK_OPERATOR_MASK;
  RightOp := GlobalTree[RightIndex]^.Data and TK_OPERATOR_MASK;
  if (LeftOp <> TK_MULTIPLY) or (RightOp <> TK_MULTIPLY) then
    Exit;

  if not TryExtractQuaternionValue(ExpressionIndex, LeftBuckets) then
    Exit;
  if not TryExtractQuaternionValue(RightIndex, RightBuckets) then
    Exit;

  MultiplyQuaternionValues(LeftBuckets, RightBuckets, ResultBuckets);

  GlobalTree.DeleteSubtree(ExpressionIndex, GlobalTree[ExpressionIndex]^.LHS);
  GlobalTree.DeleteSubtree(ExpressionIndex, RightIndex);
  GlobalTree[ExpressionIndex]^.LHS := EOT;
  GlobalTree[ExpressionIndex]^.RHS := EOT;
  EmitBucketChain(ExpressionIndex, ResultBuckets, EOT);
  Result := True;
end;

function TNumericalNode.TryComputeAdditiveBuckets(Context: TContext): Boolean;
var
  Buckets: TImaginaryBuckets;
  BucketIndex: Integer;
  CurrentIndex: Integer;
  TailIndex: Integer;
  LastConsumed: Integer;
  OriginalRHS: Integer;
  CurrentOp: Integer;
  Component: Integer;
  IntValue: Int64;
  FloatValue: Double;
  RevisionBefore: QWord;
  Candidate: Integer;

begin
  Result := False;
  CurrentOp := TreeNode^.Data and TK_OPERATOR_MASK;
  if CurrentOp <> TK_PLUS then
    Exit;

  InitializeImaginaryBuckets(Buckets);
  OriginalRHS := RHS;
  CurrentIndex := Index;
  LastConsumed := EOT;

  while CurrentIndex <> EOT do
  begin
    if IsBucketNumericNode(CurrentIndex) then
    begin
      CurrentOp := GlobalTree[CurrentIndex]^.Data and TK_OPERATOR_MASK;
      if not IsAdditiveBucketOperand(CurrentOp) then
        Break;

      Component := GetImaginaryComponent(CurrentIndex);
      if not IsKnownImaginaryComponent(Component) then
        Break;

      BucketIndex := ImaginaryBucketIndex(Component);
      if BucketIndex < 0 then
        Break;

      if GlobalTree[CurrentIndex]^.Id = OBJ_FLOAT then
      begin
        TNumericalNode(Node[CurrentIndex]).GetValue(FloatValue);
        if (CurrentOp and TK_MINUS) <> 0 then
          FloatValue := -FloatValue;
        AddFloatToBucket(Buckets[BucketIndex], FloatValue);
      end
      else
      begin
        TNumericalNode(Node[CurrentIndex]).GetValue(IntValue);
        if (CurrentOp and TK_MINUS) <> 0 then
          IntValue := -IntValue;
        AddIntegerToBucket(Buckets[BucketIndex], IntValue);
      end;

      LastConsumed := CurrentIndex;
      CurrentIndex := GlobalTree[CurrentIndex]^.RHS;
      Continue;
    end;

    RevisionBefore := GlobalTree.Revision;
    Node[CurrentIndex].Compute(Context);
    if GlobalTree.Revision = RevisionBefore then
      Break;

    if LastConsumed = EOT then
      Candidate := Index
    else
      Candidate := GlobalTree[LastConsumed]^.RHS;
    if Candidate = EOT then
      Break;
    if (Candidate = CurrentIndex) and (not IsBucketNumericNode(Candidate)) then
      Break;
    CurrentIndex := Candidate;
  end;

  if LastConsumed = EOT then
    Exit;

  TailIndex := CurrentIndex;
  if LastConsumed = Index then
    TreeNode^.RHS := EOT
  else
  begin
    GlobalTree[LastConsumed]^.RHS := EOT;
    if OriginalRHS <> EOT then
      GlobalTree.DeleteSubtree(Index, OriginalRHS);
    TreeNode^.RHS := EOT;
  end;

  EmitBucketChain(Index, Buckets, TailIndex);
  Result := True;
end;

procedure TNumericalNode.StoreAccumulator(const Op: Integer; var AValue);
var
  FinalOp: Integer;
begin
  FinalOp := Op;
  if IsPredicateOperator(Op) then
  begin
    TreeNode^.Ref := AppendValueToExpression(AValue);
    FinalOp := 0;
    TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or (FinalOp and TK_OPERATOR_MASK);
    Exit;
  end;

  if GetRelationalOps^.IsNegative(AValue) then
  begin
    GetArithmeticOps^.Neg(AValue);
    FinalOp := FinalOp or TK_MINUS;
  end
  else
  begin
    FinalOp := Op;
  end;
  TreeNode^.Ref := AppendValueToExpression(AValue);
  TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or (FinalOp and TK_OPERATOR_MASK);
end;

function GetCombinedType(Index1, Index2: Integer): Integer;
var
  Type1, Type2: Integer;
begin
  Type1 := GlobalTree[Index1]^.Data and TK_TYPE_MASK;
  Type2 := GlobalTree[Index2]^.Data and TK_TYPE_MASK;
  if Type1 = Type2 then
    Result := Type1
  else if (Type1 = TK_FLOAT) or (Type2 = TK_FLOAT) then
    Result := TK_FLOAT
  else
    Result := TK_INTEGER;
end;

procedure StoreNumericResult(
  NodeIndex,
  ResultType,
  Component,
  Op: Integer;
  var Value
);
begin
  GlobalTree[NodeIndex]^.Id := ResultType;
  SetImaginaryComponent(NodeIndex, Component);
  TNumericalNode(GetNode(NodeIndex)).StoreAccumulator(Op, Value);
end;

function TryStoreSingleTermInverse(NodeIndex, Op: Integer; Value: Double): Boolean;
var
  Component, ResultComponent, BasisSignOp, ResultOp: Integer;
  Negative: Boolean;
  Magnitude, InverseValue: Double;
begin
  Result := False;
  if (Op and TK_DIVIDE) = 0 then
    Exit;

  Component := GetImaginaryComponent(NodeIndex);
  if not CombineQuaternionInverseBasis(Component, ResultComponent, BasisSignOp) then
    Exit;

  Negative := ((Op and TK_MINUS) <> 0) xor
              ((BasisSignOp and TK_MINUS) <> 0);
  Magnitude := Value;
  if Magnitude < 0.0 then
  begin
    Magnitude := -Magnitude;
    Negative := not Negative;
  end;

  if Magnitude = 0.0 then
  begin
    InverseValue := 0.0 / 0.0;
    Negative := False;
  end
  else
    InverseValue := 1.0 / Magnitude;

  if (Op and TK_MULTIPLY) <> 0 then
    ResultOp := TK_MULTIPLY
  else
    ResultOp := TK_PLUS;
  if Negative then
  begin
    ResultOp := ResultOp and (not TK_PLUS);
    ResultOp := ResultOp or TK_MINUS;
  end;

  StoreNumericResult(NodeIndex, OBJ_FLOAT, ResultComponent, ResultOp, InverseValue);
  Result := True;
end;

function TNumericalNode.TryCombineSiblingAndStore(SiblingIndex: Integer): Boolean;
var
  XOp, YOp, ResultOp, IgnoredOp, CombinedType: Integer;
  XComponent, YComponent, ResultComponent, BasisSignOp: Integer;
  XValue, YValue, WValue: GenericValue;
  IsQuaternionMultiplication: Boolean;
begin
  XOp := TreeNode^.Data and TK_OPERATOR_MASK;
  YOp := GlobalTree[SiblingIndex]^.Data and TK_OPERATOR_MASK;
  XComponent := GetImaginaryComponent(Index);
  YComponent := GetImaginaryComponent(SiblingIndex);
  if (not IsKnownImaginaryComponent(XComponent)) or
     (not IsKnownImaginaryComponent(YComponent)) then
    Exit(False);

  IsQuaternionMultiplication :=
    IsQuaternionMultiplicationPair(Index, SiblingIndex);

  if IsQuaternionMultiplication then
  begin
    if not CombineQuaternionBasis(
      XComponent, YComponent, ResultComponent, BasisSignOp
    ) then
      Exit(False);

    ResultOp := CombineQuaternionProductOp(XOp, YOp, BasisSignOp);
    if ResultOp = TK_ERROR then
      Exit(False);

    CombinedType := GetCombinedType(Index, SiblingIndex);
    GlobalTree[Index]^.Id := CombinedType;
    GlobalTree[SiblingIndex]^.Id := CombinedType;

    TNumericalNode(GetNode(Index)).GetValue(XValue);
    TNumericalNode(GetNode(SiblingIndex)).GetValue(YValue);
    TNumericalNode(GetNode(Index)).GetArithmeticOps^.Mul(XValue, YValue, WValue);

    StoreNumericResult(Index, CombinedType, ResultComponent, ResultOp, WValue);
    Exit(True);
  end;

  if XComponent <> YComponent then
    Exit(False);

  CombinedType := GetCombinedType(Index, SiblingIndex);
  GlobalTree[Index]^.Id := CombinedType;
  GlobalTree[SiblingIndex]^.Id := CombinedType;

  TNumericalNode(GetNode(Index)).GetValue(XValue);
  TNumericalNode(GetNode(SiblingIndex)).GetValue(YValue);

  Result := TryCombineBinary(XOp, YOp, TNumericalNode(GetNode(Index)).GetArithmeticOps^, XValue, YValue, IgnoredOp, WValue);
  if not Result then
    Exit;

  if (XOp and YOp and TK_MULTIPLY) <> 0 then
    ResultOp := TK_MULTIPLY
  else
    ResultOp := TK_PLUS;
  StoreNumericResult(Index, CombinedType, XComponent, ResultOp, WValue);
end;


{ TIntegerNode }

function TIntegerNode.GetArithmeticOps: PArithmeticOps;
begin
  Result := @OPS_PROCS_INT;
end;

function TIntegerNode.GetRelationalOps: PRelationalOps;
begin
  Result := @OPS_RELATIONAL_INT;
end;

procedure TIntegerNode.GetValue(out Value);
var
  s: ansistring;
  Ref: Integer;
  ParsedValue: Int64;
begin
  Ref := TreeNode^.Ref;
  s := StripImaginarySuffix(nodes.TokenValue(Ref));
  if not TryStrToInt64(s, ParsedValue) then
    ParsedValue := 0;
  Int64(Value) := ParsedValue;
end;

function TIntegerNode.NodeNumericValue(NodeIndex: Integer): Int64;
begin
  TNumericalNode(Node[NodeIndex]).GetValue(Result);
end;

function TIntegerNode.IsNumericNodeForCompute(NodeIndex: Integer): Boolean;
begin
  Result := GlobalTree[NodeIndex]^.Id = OBJ_INTEGER;
end;

function TIntegerNode.AppendValueToExpression(const Value): Integer;
var
  Component: Integer;
  TextValue: ansistring;
begin
  Component := GetImaginaryComponent(Index);
  if not IsKnownImaginaryComponent(Component) then
    Component := 0;
  TextValue := IntToStr(Int64(Value)) + ImaginaryComponentSuffix(Component);
  Result := GlobalTree.Expression.Append(NumericTokenId(TK_INTEGER, Component), TextValue);
end;

procedure TIntegerNode.ApplyUnaryAndStoreSelf;
var
  Op: Integer;
  Value: Int64;
begin
  Op := TreeNode^.Data and TK_OPERATOR_MASK;
  GetValue(Value);
  if TryStoreSingleTermInverse(Index, Op, Value) then
    Exit;
  ComputeUnary(Op, Value, OPS_PROCS_INT);
  StoreAccumulator(Op, Value);
end;

procedure TIntegerNode.Compute(Context: TContext);
var
  Acc: Int64;
  PrevValue: Int64;
  Value: Int64;
  BooleanResult: Boolean;
  RevisionBefore: QWord;
  Snapshot: TTreeNode;
  NextIndex: Integer;
  CurrentOp: Integer;
  OriginalOp: Integer;
  NextOp: Integer;
  Folded: Boolean;
  RelationalResult: Boolean;

  function IsFoldableOperator(Op: Integer): Boolean;
  begin
    Result := IsFoldableArithmeticOperator(Op, False) or IsPredicateOperator(Op);
  end;

  function TryComputeNonNumericSibling(var SiblingIndex: Integer): Boolean;
  begin
    Result := False;
    if (SiblingIndex = EOT) or IsNumericNodeForCompute(SiblingIndex) then
      Exit;

    Snapshot := GlobalTree[SiblingIndex]^;
    RevisionBefore := GlobalTree.Revision;
    Node[SiblingIndex].Compute(Context);

    Result := (GlobalTree.Revision <> RevisionBefore) or
              (RHS <> SiblingIndex);
    if not Result then
      Result :=
        (GlobalTree[SiblingIndex]^.Id <> Snapshot.Id) or
        (GlobalTree[SiblingIndex]^.Data <> Snapshot.Data) or
        (GlobalTree[SiblingIndex]^.Ref <> Snapshot.Ref) or
        (GlobalTree[SiblingIndex]^.LHS <> Snapshot.LHS) or
        (GlobalTree[SiblingIndex]^.RHS <> Snapshot.RHS);

    if Result then
      SiblingIndex := RHS;
  end;
begin
  CurrentOp := TreeNode^.Data and TK_OPERATOR_MASK;
  if (CurrentOp and TK_DIVIDE) <> 0 then
  begin
    TreeNode^.Id := OBJ_FLOAT;
    TreeNode^.Data :=
      (TreeNode^.Data and (not TK_TYPE_MASK)) or TK_FLOAT;
    TFloatNode(GetNode(Index)).Compute(Context);
    Exit;
  end;
  OriginalOp := CurrentOp;
  if TryComputeAdditiveBuckets(Context) then
  begin
    if RHS <> EOT then
      Node[RHS].Compute(Context);
    Exit;
  end;
  if IsFoldableOperator(CurrentOp) then
  begin
    if IsComparisonOperator(CurrentOp) then
    begin
      GetValue(PrevValue);
      Folded := False;
      RelationalResult := True;
      NextIndex := RHS;
      while NextIndex <> EOT do
      begin
        if not IsNumericNodeForCompute(NextIndex) then
        begin
          if not TryComputeNonNumericSibling(NextIndex) then
            Break;
          Continue;
        end;

        NextOp := GlobalTree[NextIndex]^.Data and TK_OPERATOR_MASK;
        if not IsSiblingOperand(NextOp, CurrentOp, False) then
          Break;

        Value := NodeNumericValue(NextIndex);
        if not ComputeRelational(CurrentOp, PrevValue, Value, OPS_RELATIONAL_INT) then
          RelationalResult := False;
        PrevValue := Value;
        Folded := True;
        GlobalTree.Delete(Index, NextIndex);
        NextIndex := RHS;
      end;

      if Folded then
        Acc := Ord(RelationalResult);

      if Folded then
        StoreAccumulator(OriginalOp, Acc);
    end
    else if IsBooleanOperator(CurrentOp) then
    begin
      GetValue(PrevValue);
      Folded := False;
      BooleanResult := PrevValue <> 0;
      NextIndex := RHS;
      while NextIndex <> EOT do
      begin
        if not IsNumericNodeForCompute(NextIndex) then
        begin
          if not TryComputeNonNumericSibling(NextIndex) then
            Break;
          Continue;
        end;

        NextOp := GlobalTree[NextIndex]^.Data and TK_OPERATOR_MASK;
        if not IsSiblingOperand(NextOp, CurrentOp, False) then
          Break;

        Value := NodeNumericValue(NextIndex);
        BooleanResult := ComputeBoolean(CurrentOp, BooleanResult, Value <> 0);
        Folded := True;
        GlobalTree.Delete(Index, NextIndex);
        NextIndex := RHS;
      end;

      if Folded then
        Acc := Ord(BooleanResult);

      if Folded then
        StoreAccumulator(OriginalOp, Acc);
    end
    else
      Recurse(Context, RHS);
  end;

  if RHS <> EOT then
    Node[RHS].Compute(Context);
end;

procedure TIntegerNode.Expand(Context: TContext);
var
  Value: Int64;
  Src, Dst, N, Op: Integer;
  IteratorTokenRef: Integer;
  CurrentValue: Int64;
  IteratorValueNode: Integer;
  IteratorBound: Boolean;
  SelectionIndex: Integer;
  SelectionPrev: Integer;
begin
  if not TryGetRepeatExpandSource(Context, Src) then
  begin
    inherited Expand(Context);
    Exit;
  end;

  Dst := Index;
  Op := TreeNode^.Data and TK_OPERATOR_MASK;
  GetValue(Value);
  N := RHS;

  if Value <= 0 then
    Delete
  else if UsesStateSelectionMode(GlobalTree, Src) and
          (not TryGetRepeatIteratorToken(Context, IteratorTokenRef)) then
  begin
    Dst := ExpandStateSelection(GlobalTree, Context, Src, Op, Value, CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT);
    TreeNode^.LHS := Dst;
    GlobalTree.ExpandInline(PrevIndex, Index);
  end
  else
  begin
    Node[Src].FixRecursion;
    Dst := GlobalTree.CloneSubtree(Src);
    Node[Dst].AppendOperator(Op);

    if TryGetRepeatIteratorToken(Context, IteratorTokenRef) then
    begin
      CurrentValue := 1;
      while CurrentValue <= Value do
      begin
        IteratorValueNode := CreateDetachedIntegerNode(CurrentValue);
        IteratorBound := PushRepeatIteratorValue(Context, IteratorValueNode);
        try
          if UsesStateSelectionMode(GlobalTree, Src) then
          begin
            NormalizeRepeatIteratorClone(Context, Dst);
            if FindSelectionWithPrev(GlobalTree, Dst, EOT, SelectionIndex, SelectionPrev) then
              nodes.GetNode(SelectionIndex, SelectionPrev).Transform(Context)
            else
              Break;
          end
          else if CurrentValue = 1 then
            NormalizeRepeatIteratorClone(Context, Dst)
          else
            Node[Dst].Transform(Context);
        finally
          PopRepeatIteratorValue(Context, IteratorBound);
        end;
        Inc(CurrentValue);
      end;

      if UsesStateSelectionMode(GlobalTree, Src) and
         FindSelectionWithPrev(GlobalTree, Dst, EOT, SelectionIndex, SelectionPrev) then
        CleanupSelectionNode(GlobalTree, SelectionIndex, SelectionPrev);
    end
    else
    begin
      Dec(Value);
      while Value > 0 do
      begin
        Node[Dst].Transform(Context);
        Dec(Value);
      end;
    end;

    Node[Dst].Complete;
    Node[Dst].AppendOperator(Op, True);
    TreeNode^.LHS := Dst;
    GlobalTree.ExpandInline(PrevIndex, Index);
  end;

  if N <> EOT then
    Node[N].Expand(Context);
end;

{ TFloatNode }

function TFloatNode.GetArithmeticOps: PArithmeticOps;
begin
  Result := @OPS_PROCS_FLOAT;
end;

function TFloatNode.GetRelationalOps: PRelationalOps;
begin
  Result := @OPS_RELATIONAL_FLOAT;
end;

function TFloatNode.AppendValueToExpression(const Value): Integer;
var
  Component: Integer;
  TextValue: ansistring;
begin
  Component := GetImaginaryComponent(Index);
  if not IsKnownImaginaryComponent(Component) then
    Component := 0;
  TextValue := FloatToStr(Double(Value), DefaultFormatSettings) +
               ImaginaryComponentSuffix(Component);
  Result := GlobalTree.Expression.Append(NumericTokenId(TK_FLOAT, Component), TextValue);
end;

function TFloatNode.IsNumericNodeForCompute(NodeIndex: Integer): Boolean;
begin
  Result := (GlobalTree[NodeIndex]^.Id = OBJ_FLOAT) or
            (GlobalTree[NodeIndex]^.Id = OBJ_INTEGER);
end;

procedure TFloatNode.StoreAccumulator(const Op: Integer; const AValue: Double);
var
  Magnitude: Double;
  FinalOp: Integer;
  EffectiveOp: Integer;
  IntResult: Int64;
  Component: Integer;
begin
  EffectiveOp := Op;
  Component := GetImaginaryComponent(Index);
  if not IsKnownImaginaryComponent(Component) then
    Component := 0;
  if (EffectiveOp and TK_DIVIDE) <> 0 then
  begin
    EffectiveOp := EffectiveOp and (not TK_DIVIDE);
    if (EffectiveOp and (TK_PLUS or TK_MINUS or TK_MULTIPLY)) = 0 then
      EffectiveOp := EffectiveOp or TK_PLUS;
  end;
  FinalOp := EffectiveOp;
  if IsPredicateOperator(Op) then
  begin
    IntResult := Round(AValue);
    TreeNode^.Ref := GlobalTree.Expression.Append(TK_INTEGER, IntToStr(IntResult));
    FinalOp := 0;
    GlobalTree[Index]^.Id := OBJ_INTEGER;
    SetImaginaryComponent(Index, 0);
    TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or
                      (FinalOp and TK_OPERATOR_MASK);
    Exit;
  end;

  if AValue < 0 then
  begin
    Magnitude := -AValue;
    TreeNode^.Ref := GlobalTree.Expression.Append(
      NumericTokenId(TK_FLOAT, Component),
      FloatToStr(Magnitude, DefaultFormatSettings) + ImaginaryComponentSuffix(Component)
    );
    FinalOp := FinalOp or TK_MINUS;
  end
  else
  begin
    TreeNode^.Ref := GlobalTree.Expression.Append(
      NumericTokenId(TK_FLOAT, Component),
      FloatToStr(AValue, DefaultFormatSettings) + ImaginaryComponentSuffix(Component)
    );
    FinalOp := EffectiveOp;
  end;
  GlobalTree[Index]^.Id := OBJ_FLOAT;
  SetImaginaryComponent(Index, Component);
  TreeNode^.Data := (TreeNode^.Data and (not TK_OPERATOR_MASK)) or
                    (FinalOp and TK_OPERATOR_MASK);
end;

procedure TFloatNode.ApplyUnaryAndStoreSelf;
var
  Op: Integer;
  Value: Double;
begin
  Op := TreeNode^.Data and TK_OPERATOR_MASK;
  GetValue(Value);
  if TryStoreSingleTermInverse(Index, Op, Value) then
    Exit;
  ComputeUnary(Op, Value, OPS_PROCS_FLOAT);
  StoreAccumulator(Op, Value);
end;


procedure TFloatNode.GetValue(out Value);
var
  S: ansistring;
  D: Double;
begin
  S := StripImaginarySuffix(nodes.TokenValue(GlobalTree[Index]^.Ref));
  if not TryStrToFloat(S, D, DefaultFormatSettings) then
    D := 0.0;
  Double(Value) := D;
end;

function TFloatNode.NodeNumericValue(NodeIndex: Integer): Double;
var
  S: ansistring;
begin
  S := StripImaginarySuffix(nodes.TokenValue(GlobalTree[NodeIndex]^.Ref));
  if not TryStrToFloat(S, Result, DefaultFormatSettings) then
    Result := 0.0;
end;

procedure TFloatNode.Compute(Context: TContext);
var
  Acc: Double;
  PrevValue: Double;
  Value: Double;
  BooleanResult: Boolean;
  RevisionBefore: QWord;
  Snapshot: TTreeNode;
  NextIndex: Integer;
  CurrentOp: Integer;
  OriginalOp: Integer;
  NextOp: Integer;
  Folded: Boolean;
  RelationalResult: Boolean;

  function TryComputeNonNumericSibling(var SiblingIndex: Integer): Boolean;
  begin
    Result := False;
    if (SiblingIndex = EOT) or IsNumericNodeForCompute(SiblingIndex) then
      Exit;

    Snapshot := GlobalTree[SiblingIndex]^;
    RevisionBefore := GlobalTree.Revision;
    Node[SiblingIndex].Compute(Context);

    Result := (GlobalTree.Revision <> RevisionBefore) or
              (RHS <> SiblingIndex);
    if not Result then
      Result :=
        (GlobalTree[SiblingIndex]^.Id <> Snapshot.Id) or
        (GlobalTree[SiblingIndex]^.Data <> Snapshot.Data) or
        (GlobalTree[SiblingIndex]^.Ref <> Snapshot.Ref) or
        (GlobalTree[SiblingIndex]^.LHS <> Snapshot.LHS) or
        (GlobalTree[SiblingIndex]^.RHS <> Snapshot.RHS);

    if Result then
      SiblingIndex := RHS;
  end;

  function IsFoldableOperator(Op: Integer): Boolean;
  begin
    Result := IsFoldableArithmeticOperator(Op, True) or IsPredicateOperator(Op);
  end;

begin
  CurrentOp := TreeNode^.Data and TK_OPERATOR_MASK;
  OriginalOp := CurrentOp;
  if TryComputeAdditiveBuckets(Context) then
  begin
    if RHS <> EOT then
      Node[RHS].Compute(Context);
    Exit;
  end;
  if IsFoldableOperator(CurrentOp) then
  begin
    if IsComparisonOperator(CurrentOp) then
    begin
      GetValue(PrevValue);
      Folded := False;
      RelationalResult := True;
      NextIndex := RHS;
      while NextIndex <> EOT do
      begin
        if not IsNumericNodeForCompute(NextIndex) then
        begin
          if not TryComputeNonNumericSibling(NextIndex) then
            Break;
          Continue;
        end;

        NextOp := GlobalTree[NextIndex]^.Data and TK_OPERATOR_MASK;
        if not IsSiblingOperand(NextOp, CurrentOp, True) then
          Break;

        Value := NodeNumericValue(NextIndex);
        if not ComputeRelational(CurrentOp, PrevValue, Value, OPS_RELATIONAL_FLOAT) then
          RelationalResult := False;
        PrevValue := Value;
        Folded := True;
        GlobalTree.Delete(Index, NextIndex);
        NextIndex := RHS;
      end;

      if Folded then
        Acc := Ord(RelationalResult);

      if Folded then
        StoreAccumulator(OriginalOp, Acc);
    end
    else if IsBooleanOperator(CurrentOp) then
    begin
      GetValue(PrevValue);
      Folded := False;
      BooleanResult := PrevValue <> 0.0;
      NextIndex := RHS;
      while NextIndex <> EOT do
      begin
        if not IsNumericNodeForCompute(NextIndex) then
        begin
          if not TryComputeNonNumericSibling(NextIndex) then
            Break;
          Continue;
        end;

        NextOp := GlobalTree[NextIndex]^.Data and TK_OPERATOR_MASK;
        if not IsSiblingOperand(NextOp, CurrentOp, True) then
          Break;

        Value := NodeNumericValue(NextIndex);
        BooleanResult := ComputeBoolean(CurrentOp, BooleanResult, Value <> 0.0);
        Folded := True;
        GlobalTree.Delete(Index, NextIndex);
        NextIndex := RHS;
      end;

      if Folded then
        Acc := Ord(BooleanResult);

      if Folded then
        StoreAccumulator(OriginalOp, Acc);
    end
    else
      Recurse(Context, RHS);

    //if Folded then
    //  StoreAccumulator(OriginalOp, Acc);
  end;

  if RHS <> EOT then
    Node[RHS].Compute(Context);

  // Second pass for additive chains allows + node to absorb adjacent - nodes.
  // CurrentOp := TreeNode^.Data and TK_OPERATOR_MASK;
  // if CurrentOp = TK_PLUS then
  // begin
  //   Acc := GetValue;
  //   Folded := False;
  //   NextIndex := RHS;
  //   while NextIndex <> EOT do
  //   begin
  //     if not IsNumericNode(NextIndex) then
  //       Break;

  //     NextOp := GlobalTree[NextIndex]^.Data and TK_OPERATOR_MASK;
  //     if (NextOp <> TK_PLUS) and (NextOp <> TK_MINUS) then
  //       Break;

  //     Value := GetNodeNumericValue(NextIndex);
  //     if NextOp = TK_PLUS then
  //       Acc := Acc + Value
  //     else
  //       Acc := Acc - Value;

  //     Folded := True;
  //     GlobalTree.Delete(Index, NextIndex);
  //     NextIndex := RHS;
  //   end;

  //   if Folded then
  //     StoreAccumulator(TK_PLUS, Acc);
  // end;
end;


function ReplaceNodeInParent(ParentIndex, OldNodeIndex, NewNodeIndex: Integer): Boolean;
var
  IsLHS: Boolean;
  IsRHS: Boolean;
begin
  Result := False;
  if OldNodeIndex = EOT then
    Exit;

  if ParentIndex = EOT then
  begin
    GlobalTree.DeleteSubtree(EOT, OldNodeIndex);
    Exit(True);
  end;

  IsLHS := GlobalTree[ParentIndex]^.LHS = OldNodeIndex;
  IsRHS := GlobalTree[ParentIndex]^.RHS = OldNodeIndex;
  if (not IsLHS) and (not IsRHS) then
    Exit;

  if IsLHS then
    GlobalTree[ParentIndex]^.LHS := EOT;
  if IsRHS then
    GlobalTree[ParentIndex]^.RHS := EOT;

  GlobalTree.DeleteSubtree(EOT, OldNodeIndex);

  if NewNodeIndex <> EOT then
  begin
    if IsLHS then
      GlobalTree.LinkLHS(ParentIndex, NewNodeIndex)
    else
      GlobalTree.LinkRHS(ParentIndex, NewNodeIndex);
  end;
  Result := True;
end;

procedure TEvaluationNode.Execute(Context: TContext);
var
  DebugFrame: TDebuggerFrame;
  EvaluationCompleted: Boolean;
begin
  EvaluationCompleted := False;
  if DebuggerAttached then
  begin
    DebugFrame := TDebuggerFrame.Create(dfkEvalScope, '', TreeValue, Index);
    EmitDebuggerEvent(dekEvalScopeEnter, DebugFrame);
    HandleDebuggerPause(Context);
  end;
  Inc(EvaluationExecutionDepth);
  try
    Evaluate(Context);
    EvaluationCompleted := True;
  finally
    Dec(EvaluationExecutionDepth);
    if DebuggerAttached and EvaluationCompleted then
    begin
      EmitDebuggerEvent(dekEvalScopeExit, DebugFrame);
      HandleDebuggerPause(Context);
    end;
  end;
end;

{ TComputeNode }

procedure TComputeNode.Evaluate(Context: TContext);
begin
  inherited Evaluate(Context);
  if LHS <> EOT then Node[LHS].Compute(Context);
  GlobalTree.Expand(PrevIndex, Index);
end;


{ TSpecialNode }

function TSpecialNode.TokenValue(var Config: TFormatConfig): ansistring;
var
  L, R: ansistring;
  Op: ansistring;
begin
  L := ''; R := '';
  if LHS <> EOT then L := Node[LHS].TreeValue(Config);
  if RHS <> EOT then R := Node[RHS].TreeValue(Config);

  case ObjectId of
    OBJ_ASSIGNMENT: Result := Format('%s = %s', [L, R]);
    OBJ_DEEP_ASSIGNMENT:
      begin
        case TreeNode^.Data and TK_RELATIONAL_MASK of
          TK_RELATIONAL_GT: Op := ' >:= ';
          TK_RELATIONAL_LT: Op := ' <:= ';
          TK_RELATIONAL_NOT: Op := ' !:= ';
        else
          Op := ' := ';
        end;
        Result := L + Op + R;
      end;
    OBJ_DEFINE: Result := Format('define %s', [L]);
    OBJ_CALLABLE: Result := Format('callable %s', [L]);
    OBJ_RULE: Result := Format('rule %s %s', [L, R]);
    OBJ_EXPLODE: Result := Format('explode %s', [L]);
    OBJ_IMPLODE: Result := Format('implode %s', [L]);
    OBJ_SELECTION: Result := Format('%s ? %s', [L, R]);
    OBJ_FALLBACK: Result := Format('%s ?? %s', [L, R]);
    OBJ_REPEAT { TK_COLON }: Result := Format('%s : %s', [L, R]);
    OBJ_STAGED_REPEAT: Result := Format('%s :: %s', [L, R]);
    OBJ_INDEX_LOOKUP: Result := Format('%s @ %s', [L, R]);
    OBJ_ITERATOR_BIND:
      begin
        Op := '';
        if TreeNode^.Ref <> EOT then
          Op := GlobalTree.Expression.TokenValue(TreeNode^.Ref);
        if Op <> '' then
          Result := Format('%s @ %s', [L, Op])
        else
          Result := L + ' @';
      end;
    OBJ_TRANSFORMATION: Result := Format('%s => %s', [L, R]);
    OBJ_EQUIVALENCE: Result := Format('%s <=> %s', [L, R]);
    OBJ_INFERENCE: Result := Format('%s |= %s', [L, R]);
    OBJ_INFERENCE_WITNESS: Result := Format('%s ?|= %s', [L, R]);
    OBJ_INLINE_TRANSFORMATION: Result := Format('%s =>> %s', [L, R]);
    OBJ_SUBST_TRANSFORM: Result := Format('%s ==>> %s', [L, R]);
    OBJ_SYMBOL_SUBST_TRANSFORM: Result := Format('%s ==> %s', [L, R]);
    OBJ_SUBST_EQUIVALENCE: Result := Format('%s <==> %s', [L, R]);
    OBJ_VARIABLE_SUBTREE:
      begin
        Op := '';
        if TreeNode^.Ref <> EOT then
          Op := GlobalTree.Expression.TokenValue(TreeNode^.Ref);
        if L <> '' then
          Result := Format('%s -> %s', [Op, L])
        else
          Result := Op + ' ->';
        if R <> '' then
          Result := Result + ' ' + R;
      end;
    TK_PIPE: Result := Format('%s | %s', [L, R]);
    OBJ_RANGE: Result := Format('%s .. %s', [L, R]);
    OBJ_STEPPED_RANGE: Result := Format('%s by %s', [L, R]);
    OBJ_CONCATENATE: Result := Format('%s & %s', [L, R]);
    OBJ_RECURSE:
      Result := TokenFromID(ObjectId);
    OBJ_SEPARATOR { TK_COMMA }:
      begin
        if RHS = EOT then
          Result := L
        else
          Result := L + ' , ' + R;
      end;
  else
    begin
      Op := TokenFromID(ObjectId);
      if (L <> '') and (R <> '') and (Op <> '') then
        Result := Format('%s %s %s', [L, Op, R])
      else if (L <> '') and (R <> '') then
        Result := L + ' ' + R
      else if L <> '' then
        Result := L
      else if R <> '' then
        Result := R
      else
        Result := Op;
    end;
  end;
{$IFDEF DEBUG_SCOPES}
  Result := Format('( %s )', [Result]);
  if ObjectId = OBJ_SEPARATOR then
  begin
    //IncludeOperator(Result);
  end;
{$ENDIF SHOW_SCOPES}
  //Inc(Config.Offset, Length(Result));
end;

function TSpecialNode.TreeValue(var Config: TFormatConfig): ansistring;
begin
  Result := TokenValue(Config);
end;

{ TScopeNode }
procedure TScopeNode.Compute(Context: TContext);
var
  ChildIndex: Integer;
  ParentOp: Integer;
  ChildOp: Integer;
  CombinedOp: Integer;
begin
  inherited Compute(Context);

  if (ObjectId = OBJ_EXPRESSION) and TryInvertQuaternionExpressionValue(Index) then
    Exit;

  if (ObjectId = OBJ_EXPRESSION) and
     TryDistributeQuaternionExpressionProduct(PrevIndex, Index) then
    Exit;

  ChildIndex := LHS;
  ParentOp := TreeNode^.Data and TK_OPERATOR_MASK;
  if ChildIndex = EOT then
  begin
    // Numeric wrappers like "/ ()" cannot be reduced further and should be
    // removed so parent operators can continue folding.
    if (ObjectId = OBJ_EXPRESSION) and (ParentOp <> 0) then
    begin
      if PrevIndex = EOT then
        GlobalTree.ExpandInline(PrevIndex, Index)
      else
        GlobalTree.Delete(PrevIndex, Index);
    end;
    Exit;
  end;

  // Only unwrap trivial wrappers (single-child scopes).
  if Node[ChildIndex].RHS <> EOT then
    Exit;

  if ObjectId = OBJ_ARRAY then
  begin
    // Preserve structural arrays by default. Only collapse arrays that carry an operator.
    if ParentOp = 0 then
      Exit;
  end
  else if ObjectId <> OBJ_EXPRESSION then
    Exit;

  ChildOp := GlobalTree[ChildIndex]^.Data and TK_OPERATOR_MASK;
  CombinedOp := GetScopeCombinedOp(ParentOp, ChildOp);
  if CombinedOp = TK_ERROR then
    Exit;

  GlobalTree[ChildIndex]^.Data :=
    (GlobalTree[ChildIndex]^.Data and (not TK_OPERATOR_MASK)) or
    (CombinedOp and TK_OPERATOR_MASK);
  GlobalTree.ExpandInline(PrevIndex, Index);
  GlobalTree[Index]^.Data :=
    (GlobalTree[Index]^.Data and (not TK_OPERATOR_MASK)) or
    (CombinedOp and TK_OPERATOR_MASK);

  // Continue compute on the replacement node in the same pass.
  nodes.Dispatch(Index, PrevIndex, @TBaseNode.DispatchCompute, Context);
end;

function TScopeNode.TokenValue(var Config: TFormatConfig): ansistring;
begin
  Result := '';
  if LHS <> EOT then
    Result := Node[LHS].TreeValue(Config);


  case ObjectID of
    //TK_BACKTICK, TK_APOSTROPHE: ;
    OBJ_COMPUTE: ;
  else
    if Result <> '' then Result := ' ' + Result + ' ';
  end;

  case ObjectID of
    OBJ_EXPRESSION: Result := Format('(%s)', [Result]);
    OBJ_EVALUATION: Result := Format('{%s}', [Result]);
    OBJ_ARRAY: Result := Format('[%s]', [Result]);
    OBJ_COMPUTE: Result := Format('`%s`', [Result]);
    //TK_APOSTROPHE: Result := Format('''%s''', [Result]);
  end;
end;

{ TRecurseNode }
procedure TRecurseNode.Expand(Context: TContext);
var
  Src, Dst, N, DstOp: Integer;
begin
  if not TryGetRepeatExpandSource(Context, Src) then
  begin
    inherited Expand(Context);
    Exit;
  end;

  N := RHS;
  DstOp := TreeNode^.Data and TK_OPERATOR_MASK;

  if UsesStateSelectionMode(GlobalTree, Src) then
    Dst := ExpandStateSelection(GlobalTree, Context, Src, DstOp, MAX_FIXPOINT_STEPS, CLEANUP_SELECTION_AFTER_DOLLAR_REPEAT)
  else
  begin
    Node[Src].FixRecursion;
    Dst := GlobalTree.CloneSubtree(Src);
    NormalizeRepeatIteratorClone(Context, Dst);
    Node[Dst].AppendOperator(DstOp);
    Node[Dst].Complete;
    Node[Dst].AppendOperator(DstOp, True);
  end;

  TreeNode^.LHS := Dst;
  GlobalTree.ExpandInline(PrevIndex, Index);

  if N <> EOT then
    Node[N].Expand(Context);
end;

procedure TRecurseNode.Transform(Context: TContext);
var
  Src, DstOp: Integer;
begin
  //if RHS <> EOT then Node[RHS]^.Transform(Context, Src, Depth);

  //if Next <> EOT then (Node[Next])^.Transform(Context, Src);
  //WriteLn(TreeValue);
  inherited;

  if not TryGetRepeatExpandSource(Context, Src) then
    Exit;
  DstOp := TreeNode^.Data and TK_OPERATOR_MASK;

  // Make a copy of source pattern.
  TreeNode^.LHS := GlobalTree.CloneSubtree(Src);
  NormalizeRepeatIteratorClone(Context, TreeNode^.LHS);

  //DstOp := TokenID and TK_OPERATOR_MASK;
  Node[LHS].AppendOperator(DstOp);

  // previously: GlobalTree.Expand(Index);
  GlobalTree.Expand(PrevIndex, Index);
  // Q: GlobalTree.NodeIndex(@Self) ???
  //GlobalTree.Expand(GlobalTree.NodeIndex(@Self));
end;

{ TPipeNode }
procedure TPipeNode.Evaluate(Context: TContext);
var
  LeftHead: Integer;
  RightHead: Integer;
  RightTail: Integer;
begin
  LeftHead := LHS;
  RightHead := RHS;

  TreeNode^.LHS := EOT;
  TreeNode^.RHS := EOT;

  if RightHead <> EOT then
  begin
    RightTail := GlobalTree.LastSibling[RightHead];
    if (RightTail <> EOT) and (LeftHead <> EOT) then
      GlobalTree[RightTail]^.RHS := LeftHead;
    TreeNode^.LHS := RightHead;
  end
  else
    TreeNode^.LHS := LeftHead;

  if TreeNode^.LHS <> EOT then
    Node[TreeNode^.LHS].Evaluate(Context);

  GlobalTree.ExpandInline(PrevIndex, Index);
end;

{ TArrayNode}
procedure TArrayNode.Execute(Context: TContext);
begin
  inherited Execute(Context);
end;

{ TStatementNode }
procedure TStatementNode.Execute(Context: TContext);
begin
  inherited Execute(Context);
end;

function TStatementNode.TokenValue(var Config: TFormatConfig): ansistring;
begin
  Result := '';
  if LHS <> EOT then
    Result := Child.TreeValue(Config);
end;

{ TOutputNode }
procedure TOutputNode.Execute(Context: TContext);
var
  OutputText: ansistring;
  Formatter: TCustomFormatter;
begin
  inherited Execute(Context);
  OutputText := '';
  if LHS <> EOT then
  begin
    if GlobalExecutable.RunOptions.Raw and (TreeNode^.Id = OBJ_OUTPUT) then
      OutputText := Node[LHS].TreeValue
    else
    begin
      Formatter := GetFormatter;
      try
        OutputText := Node[LHS].Formatted(Formatter);
      finally
        Formatter.Free;
      end;
    end;
  end;
  EmitRuntimeOutputLine(OutputText);
end;

{ TTreeOutputNode }
function TTreeOutputNode.GetFormatter: TCustomFormatter;
begin
  Result := TTreeFormatter.Create;
end;

{ TIROutputNode }
procedure TIROutputNode.Execute(Context: TContext);
var
  OutputIndex: Integer;
  OutputText: ansistring;
  Formatter: TCustomFormatter;
  VariableName: ansistring;
  ResolvedIndex: Integer;
  VariableNode: TVariableNode;
begin
  Expand(Context);

  OutputText := '';
  if LHS <> EOT then
  begin
    OutputIndex := LHS;
    if GlobalTree[OutputIndex]^.Id = OBJ_VARIABLE then
    begin
      VariableNode := TVariableNode(nodes.GetNode(OutputIndex, Index));
      if VariableNode.TryResolveDollarReference(Context, ResolvedIndex) and
         (ResolvedIndex <> EOT) then
        OutputIndex := ResolvedIndex
      else
      begin
        VariableName := VariableNode.TokenValue;
        if (VariableName <> '') and Context.TryFindVariable(VariableName, ResolvedIndex) then
          OutputIndex := ResolvedIndex;
      end;
    end;

    Formatter := GetFormatter;
    try
      OutputText := Node[OutputIndex].Formatted(Formatter);
    finally
      Formatter.Free;
    end;
  end;

  EmitRuntimeOutputLine(OutputText);
end;

function TIROutputNode.GetFormatter: TCustomFormatter;
begin
  Result := TIRFormatter.Create;
end;

end.
