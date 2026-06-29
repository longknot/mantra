unit mathparser;

{$I mantra.inc}

(*
-----------------------------------------
0..255:
IDENTIFIER
CONSTANT
INTEGER
STRING
TRANSFORM
PATTERN
ARRAY
EXPRESSION
EVALUATION
DEEVALUATION
STATEMENT
OUTPUT
REPEAT
--> look up class / object

TOKEN              : 4 bytes    -> object
[PREV, LHS, RHS]   : 12 bytes
= 16 bytes

Tree.Next[Index]  --> initialize object from record
------
8 + 4 + 6 = 18
----------------------------------------
*)



// "Yet, in fact, as I shall show here with very good reasons, the properties of
//  the numbers known today have been mostly discovered by observation, and
//  discovered long before their truth has been confirmed by rigid demonstrations"
// "in the theory of numbers, which is still very imperfect, we can place our
//  highest hopes in observations, they will lead us continually to new properties
//  which we shall endeavor to prove afterwards"
// -- Leonhard Euler
//
// "20% of mathematics is trivial, the rest is abuse of notation."
// -- Hans-Bernhard Broeker

// discovery of new properties:
// 1. generate (computable) expressions
// 2. compute integer sequences from expressions
// 3. two matching sequences form a hypothesis
// 4. search for a proof (transformations + proof by induction)

// Array algorithm
// - cumulative sum/product ... [rfold/lfold]
// - merge + merge sort
// - infinite fractions
// - determinant (?)
// - window algorithms (?)

// matrix determinant
//   det M = det LU = det L * det U
//   http://paulbourke.net/miscellaneous/determinant/
// matrix inverse
//   inv(A) = 1/det(A) * adj(A)
//   - The adjoint matrix is the transpose of the cofactor matrix.
// https://en.wikipedia.org/wiki/Minor_(linear_algebra)
// https://en.wikipedia.org/wiki/Exterior_algebra

interface

uses
  Classes, SysUtils, Types, exp_tokenizer, exp_trees, tokens, nodes, context,
  matcher_ir, debugger_types;

const
  // identifiers
  ID_BASE     = $10000;
  ID_VARIABLE = ID_BASE + 1;               // pointer to expression tree (?)
  ID_CONSTANT = ID_BASE + 2;
  ID_FUNCTION = ID_BASE + 3;

type
  { TExpressionTokenizer }
  TExpressionTokenizer = class(TCustomTokenizer)
  private
    procedure RegisterTokens;
  protected
  public
    constructor Create; //override;
  end;

  { TExpression }
  TExpression = class(TCustomExpression)
  private
  public
    //procedure AddToken(const Token: TTokenData); override;
    function GetTokenizer: TCustomTokenizer; override;
  end;

  { TExpressionTree }
  TExpressionTree = class(TCustomTree)
  private
    FStatements: TIntegerDynArray;
    //procedure ConnectChild(Index, AChild: Integer);
    //procedure ConnectSibling(Index, ANext: Integer);
    function PrintNodes(Index: Integer; Data: Pointer): Integer;
  protected
    // procedure InitializeNode(var ANode: TTreeNode); override;
  public
    constructor Create; override;
    destructor Destroy; override;

    function TokenValue(Index: Integer): ansistring;
    function TokenID(Index: Integer): Integer;
    function AddStatement: Integer;
    function Parse(AExpression: TCustomExpression): PTreeNode;
    property Statements: TIntegerDynArray read FStatements;
  end;

var
  Tokenizer: TExpressionTokenizer;

type
  PRunOptions = ^TRunOptions;
  TRunOptions = record
    Raw: Boolean;
    DebugOutput: Boolean;
    DebugIR: Boolean;
    DebuggerEnabled: Boolean;
    DebuggerCLI: Boolean;
    DebuggerPostmortem: Boolean;
    EvalOutput: Boolean;
    Interactive: Boolean;
    HeadDispatch: Boolean;
    Backtracking: Boolean;
    ShowInput: Boolean;
    ShowTokens: Boolean;
    EventLogLevel: TEventLogLevel;
    EventLogStdout: Boolean;
    EventLogFormat: TEventLogFormat;
    InferenceCongruenceBudget: Integer;
    InferenceCongruenceBudgetExplicit: Boolean;
    InferenceBeamWidth: Integer;
    InferenceBeamWidthExplicit: Boolean;
    DebuggerBreakpoints: array of TDebuggerBreakpoint;
    SetAssignments: array of ansistring;
    EvalExpressions: array of ansistring;
    PackageRoots: array of ansistring;
  end;

function DefaultRunOptions: TRunOptions;
procedure Execute(const Source: ansistring); overload;
procedure Execute(const Source: ansistring; const Options: TRunOptions); overload;
procedure AppendSourceChunk(const Chunk: ansistring);
procedure AppendSourceChunk(
  const Chunk: ansistring;
  const SourcePath: ansistring;
  BaseLine: Integer
);
function CurrentDebuggerSourcePath: ansistring;
function StatementDebuggerSourcePath(StatementIndex: Integer): ansistring;

implementation

uses
  parsetree, module_loader, debugger_api, debugger_state, debugger_postmortem,
  debugger_cli, debugger_runtime, complex, repl_input;

var
  DebuggerSourcePath: ansistring = '';
  StatementSourcePaths: array of ansistring;

function CurrentDebuggerSourcePath: ansistring;
begin
  Result := DebuggerSourcePath;
end;

procedure SetStatementDebuggerSourcePath(
  StatementIndex: Integer;
  const SourcePath: ansistring
);
begin
  if StatementIndex < 0 then
    Exit;
  if StatementIndex >= Length(StatementSourcePaths) then
    SetLength(StatementSourcePaths, StatementIndex + 1);
  StatementSourcePaths[StatementIndex] := SourcePath;
end;

procedure ClearStatementDebuggerSourcePaths;
begin
  SetLength(StatementSourcePaths, 0);
end;

function StatementDebuggerSourcePath(StatementIndex: Integer): ansistring;
begin
  if (StatementIndex >= 0) and (StatementIndex < Length(StatementSourcePaths)) then
    Exit(StatementSourcePaths[StatementIndex]);
  Result := '';
end;

function IsUpperCase(const S: ansistring): Boolean;
begin
  Result := S = UpperCase(S);
end;

function TExpression.GetTokenizer: TCustomTokenizer;
begin
  Result := Tokenizer;
end;

function DefaultRunOptions: TRunOptions;
begin
  Result.Raw := False;
  Result.DebugOutput := False;
  Result.DebugIR := False;
  Result.DebuggerEnabled := False;
  Result.DebuggerCLI := False;
  Result.DebuggerPostmortem := False;
  Result.EvalOutput := False;
  Result.Interactive := False;
  Result.HeadDispatch := True;
  Result.Backtracking := False;
  Result.ShowInput := False;
  Result.ShowTokens := False;
  Result.EventLogLevel := ellOff;
  Result.EventLogStdout := False;
  Result.EventLogFormat := elfText;
  Result.InferenceCongruenceBudget := -1;
  Result.InferenceCongruenceBudgetExplicit := False;
  Result.InferenceBeamWidth := 1;
  Result.InferenceBeamWidthExplicit := False;
  SetLength(Result.DebuggerBreakpoints, 0);
  SetLength(Result.SetAssignments, 0);
  SetLength(Result.EvalExpressions, 0);
  SetLength(Result.PackageRoots, 0);
end;


procedure TExpressionTokenizer.RegisterTokens;
var
  TK_PARTIAL_STRING, TK_STRING_ESCAPE, TK_DECIMALPOINT, TK_FLOAT_EXPONENT,
  TK_PARTIAL_BLOCKCOMMENT, TK_STAR_IN_BLOCKCOMMENT, X: Integer;
begin
  Options := [toCaseInsensitive];
  IgnoreMask := TK_SPACE or TK_TAB or TK_LINECOMMENT or
                TK_BLOCKCOMMENT or TK_NEWLINE or TK_CR;

  // stop token
  AddTransition(#00, TK_UNKNOWN);

  // comments
  AddTransition('//', TK_LINECOMMENT);
  AddTransition([#0..#255] - [#10], TK_LINECOMMENT, TK_LINECOMMENT);

  TK_PARTIAL_BLOCKCOMMENT := GetNextStateID;
  TK_STAR_IN_BLOCKCOMMENT := GetNextStateID;
  AddTransition('/*', TK_PARTIAL_BLOCKCOMMENT);
  AddTransition([#0..#255] - ['*'], TK_PARTIAL_BLOCKCOMMENT, TK_PARTIAL_BLOCKCOMMENT);
  // N: this does not account for single '*' within block comment.
  //AddTransition('*/', TK_PARTIAL_BLOCKCOMMENT, TK_BLOCKCOMMENT);

  AddTransition('*', TK_PARTIAL_BLOCKCOMMENT, TK_STAR_IN_BLOCKCOMMENT);
  AddTransition([#0..#255] - ['/'], TK_STAR_IN_BLOCKCOMMENT, TK_PARTIAL_BLOCKCOMMENT);
  AddTransition('/', TK_STAR_IN_BLOCKCOMMENT, TK_BLOCKCOMMENT);

  // parentheses
  AddTransition('(', TK_PARENTHESIS_BEGIN);
  AddTransition(')', TK_PARENTHESIS_END);

  AddTransition('[', TK_BRACKET_BEGIN);
  AddTransition(']', TK_BRACKET_END);

  AddTransition('{', TK_CURLY_BEGIN);
  AddTransition('}', TK_CURLY_END);
  AddTransition('<<', TK_GROUP_BEGIN);
  AddTransition('>>', TK_GROUP_END);

  AddTransition('''', TK_APOSTROPHE);
  AddTransition('`', TK_BACKTICK);

  TK_PARTIAL_STRING := GetNextStateID;
  TK_STRING_ESCAPE := GetNextStateID;
  AddTransition('"', TK_PARTIAL_STRING);
  AddTransition([#0..#255] - [#10,#13,'"','\'], TK_PARTIAL_STRING, TK_PARTIAL_STRING);
  AddTransition('\', TK_PARTIAL_STRING, TK_STRING_ESCAPE);
  AddTransition([#1..#255], TK_STRING_ESCAPE, TK_PARTIAL_STRING);
  AddTransition('"', TK_PARTIAL_STRING, TK_STRING);

  // delimiters
  AddTransition(' ', TK_SPACE);
  AddTransition(',', TK_COMMA);
  AddTransition(';', TK_SEMICOLON);
  AddTransition(#9, TK_TAB);

  // numeric
  TK_DECIMALPOINT := GetNextStateID;
  TK_FLOAT_EXPONENT := GetNextStateID;
  AddTransition(['0'..'9'], TK_INTEGER);
  AddTransition(['0'..'9'], TK_INTEGER, TK_INTEGER);
  AddTransition('.', TK_INTEGER, TK_DECIMALPOINT);
  AddTransition(['0'..'9'], TK_DECIMALPOINT, TK_FLOAT);
  AddTransition(['0'..'9'], TK_FLOAT, TK_FLOAT);
  AddTransition('E', TK_FLOAT, TK_FLOAT_EXPONENT);
  AddTransition('E', TK_INTEGER, TK_FLOAT_EXPONENT);
  AddTransition(['0'..'9'], TK_FLOAT_EXPONENT, TK_FLOAT);

  AddTransition('i', TK_INTEGER, TK_IMAG_I_INT);
  AddTransition('i', TK_FLOAT, TK_IMAG_I_FLOAT);
  AddTransition('j', TK_INTEGER, TK_IMAG_J_INT);
  AddTransition('j', TK_FLOAT, TK_IMAG_J_FLOAT);
  AddTransition('k', TK_INTEGER, TK_IMAG_K_INT);
  AddTransition('k', TK_FLOAT, TK_IMAG_K_FLOAT);


  // variables + constants
  AddTransition(['_', 'a'..'z'], TK_IDENTIFIER);
  AddTransition(['_', 'a'..'z', '0'..'9', '.'], TK_IDENTIFIER, TK_IDENTIFIER);

  AddTransition(['*'], TK_IDENTIFIER, TK_PATTERN);

  AddTransition(['_', 'a'..'z', '0'..'9', '.', '*'], TK_PATTERN, TK_PATTERN);
  AddTransition(['['], TK_IDENTIFIER, TK_PATTERN_KEY);
  AddTransition(['['], TK_PATTERN, TK_PATTERN_KEY);
  AddTransition(['0'..'9'], TK_PATTERN_KEY, TK_PATTERN_INDEX);
  AddTransition([']'], TK_PATTERN_INDEX, TK_PATTERN);

  AddTransition('nan', TK_FLOAT);
  AddTransition('inf', TK_FLOAT);
  AddTransition('null', TK_NULL);
  AddTransition('true', TK_BOOLEAN);
  AddTransition('false', TK_BOOLEAN);
  AddTransition('exec', TK_EXEC);


  //AddTransition('and', TK_AND);  // a -> n -> d  (N: copy transitions for identifiers!)
  //AddTransition('or', TK_OR);
  //AddTransition('xor', TK_XOR);

  // AddTransition('_', TK_UNDERSCORE);
  //AddTransition('+', TK_PLUS);
  //S := Advance(0, '+');

  // OPERATORS
  //AddTransition('**', TK_POWER);
  AddTransition('*', TK_ASTERISK);
  AddTransition('+', TK_PLUS);
  AddTransition('-', TK_MINUS);
  AddTransition('/', TK_SLASH);
  //AddTransition('!', TK_EXCLAMATIONMARK);
  //AddTransition('!!', TK_DOUBLEFACTORIAL);
  AddTransition('|', TK_PIPE);
  AddTransition('#', TK_HASH);
  //AddTransition('%', TK_PERCENTAGE);
  AddTransition('<==>', TK_SUBST_EQUIVALENCE);
  AddTransition('==>', TK_SYMBOL_SUBST_TRANSFORM);
  AddTransition('==>>', TK_SUBST_TRANSFORM);
  AddTransition('==', TK_RELATIONAL_EQ);
  AddTransition('>', TK_RELATIONAL_GT);
  AddTransition('>=', TK_RELATIONAL_GE);
  AddTransition('<', TK_RELATIONAL_LT);
  AddTransition('<=', TK_RELATIONAL_LE);
  AddTransition('!=', TK_RELATIONAL_NEQ);
  AddTransition('!', TK_RELATIONAL_NOT);

  AddTransition('and', TK_BOOLEAN_AND);
  AddTransition('or', TK_BOOLEAN_OR);
  AddTransition('xor', TK_BOOLEAN_XOR);
  AddTransition('not', TK_BOOLEAN_NOT);
  //AddTransition('nand', TK_BOOLEAN_NAND);
  //AddTransition('nor', TK_BOOLEAN_NOR);
  //AddTransition('nxor', TK_BOOLEAN_NXOR);

  AddTransition('@', TK_AT);
  AddTransition('^', TK_CARET);
  AddTransition(#10, TK_NEWLINE);

  // possible additional operators:
  // ->  <-  :>  <:  ::
  // (:)


  // SPECIAL
  AddTransition('\', TK_FIXED);
  AddTransition('\\', TK_UNFIX);
  AddTransition('::', TK_ITERATOR);
  AddTransition('&', TK_AMPERSAND);

  AddTransition('?', TK_QUESTIONMARK);
  AddTransition('??', TK_FALLBACK);

  AddTransition('.', TK_DOT);
  AddTransition('..', TK_DOUBLEDOT);
  AddTransition('...', TK_TRIPLEDOT);

  AddTransition('~', TK_TILDE);
  AddTransition('$', TK_DOLLAR);

  AddTransition('>:=', TK_DEEP_ASSIGN_OVERWRITE);
  AddTransition('<:=', TK_DEEP_ASSIGN_KEEP);
  AddTransition('!:=', TK_DEEP_ASSIGN_FAIL);
  AddTransition(':=', TK_DEEP_ASSIGN);

  AddTransition(':', TK_COLON);             // "tile operator"
  AddTransition('=', TK_ASSIGNMENT);             // "tile operator"
  AddTransition('=>>', TK_INLINE_TRANSFORM);
  AddTransition('=>', TK_IMPLIES);          // inference rules
  AddTransition('<=>', TK_EQUIVALENCE);     // inference rules

  AddTransition('->', TK_RIGHT_ARROW);
  AddTransition('->', TK_VARIABLE_SUBTREE_ARROW);
  AddTransition('<-', TK_LEFT_ARROW);

  //AddTransition(':=?', TK_INLINE_SELECTION);
  AddTransition('?|=', TK_INFERENCE_WITNESS);
  AddTransition('|=', TK_INFERENCE);


  // N: order important!
  //AddTransition('>>>', TK_FORWARD_DFS);
  //AddTransition('<<<', TK_REVERSE_DFS);
  //AddTransition('>>', TK_FORWARD);
  //AddTransition('<<', TK_REVERSE);
  //AddTransition('___', TK_REVERSE);
  AddTransition('--', TK_MATCH_ANY);
  AddTransition('---', TK_MATCH_ANY_LONG);

  // AddTransition('min', TK_MIN);
  // AddTransition('max', TK_MAX);
  // AddTransition('abs',  TK_ABS);
  // AddTransition('sgn',  TK_SIGN);
  // AddTransition('floor', TK_FLOOR);
  // AddTransition('ceil', TK_CEIL);
  // AddTransition('round', TK_ROUND);
  // AddTransition('trunc', TK_TRUNC);

  // AddTransition('rand', TK_RAND);
  // AddTransition('randint', TK_RANDINT);


  // AddTransition('sqr', TK_SQR);
  // //AddTransition('²', TK_SQR);
  // AddTransition('sqrt', TK_SQRT);
  // AddTransition('im',  TK_IM);
  // AddTransition('conj',  TK_CONJ);
  // AddTransition('arg',  TK_ARG);
  // AddTransition('im',  TK_IMAG);
  // AddTransition('real',  TK_REAL);
  // AddTransition('cube',  TK_CUBE);
  // AddTransition('mod', TK_MODULUS);
  // //AddTransition('³', TK_CUBE);
  // AddTransition('exp', TK_EXP);
  // AddTransition('ln',  TK_LN);
  // AddTransition('log2', TK_LOG2);
  // AddTransition('log', TK_LOG10);
  // AddTransition('logn', TK_LOGN);

  // AddTransition('sin', TK_SIN);
  // AddTransition('cos', TK_COS);
  // AddTransition('tan', TK_TAN);

  // AddTransition('cot', TK_COT);
  // AddTransition('sec', TK_SEC);
  // AddTransition('csc', TK_CSC);
  // AddTransition('arcsin', TK_ARCSIN);
  // AddTransition('arccos', TK_ARCCOS);
  // AddTransition('arctan', TK_ARCTAN);
  // AddTransition('sinh', TK_SINH);

  // AddTransition('cosh', TK_COSH);
  // AddTransition('tanh', TK_TANH);

  // AddTransition('frac', TK_FRAC);
  // //AddTransition('÷', TK_FRAC);
  // AddTransition('diff', TK_DIFF);

  //AddTransition('next', TK_NEXT);
  //AddTransition('prev', TK_PREV);
  AddTransition('lhs', TK_SELECTOR_LHS);
  AddTransition('rhs', TK_SELECTOR_RHS);
  //AddTransition('sub', TK_SUB);
  //AddTransition('sup', TK_SUP);
  AddTransition('all', TK_SELECTOR_ALL);
  AddTransition('op', TK_SELECTOR_OP);

  AddTransition('const', TK_CONSTANT);
  AddTransition('rule', TK_RULE);
  AddTransition('function', TK_FUNCTION);
  AddTransition('namespace', TK_NAMESPACE);
  AddTransition('object', TK_OBJECT);
  AddTransition('selector', TK_SELECTOR);
  AddTransition('define', TK_DEFINE);
  //AddTransition('operator', TK_DEFINE_OPERATOR);
  AddTransition('package', TK_PACKAGE);
  AddTransition('import', TK_IMPORT);
  AddTransition('include', TK_INCLUDE);
  AddTransition('print', TK_PRINT);
  AddTransition('explode', TK_EXPLODE);
  AddTransition('implode', TK_IMPLODE);
  AddTransition('tree', TK_TREE);
  AddTransition('callable', TK_CALLABLE);
  AddTransition('ir', TK_IR);
  AddTransition('query_keys', TK_QUERY_KEYS);
  AddTransition('query_values', TK_QUERY_VALUES);
  AddTransition('query_children', TK_QUERY_CHILDREN);
  AddTransition('get', TK_GET);
  AddTransition('path_segment', TK_PATH_SEGMENT);
  AddTransition('make_pair', TK_MAKE_PAIR);
  AddTransition('fmt', TK_FMT);
  AddTransition('printf', TK_PRINTF);
  AddTransition('render', TK_RENDER);
  AddTransition('global', TK_GLOBAL);
  AddTransition('scope', TK_SCOPE_FRAME);
  AddTransition('alias', TK_ALIAS);
  AddTransition('forward', TK_RULE_FORWARD);
  AddTransition('reverse', TK_RULE_REVERSE);
  AddTransition('json_load', TK_JSON_LOAD);
  AddTransition('json_encode', TK_JSON_ENCODE);
  AddTransition('json_save', TK_JSON_SAVE);
  AddTransition('display', TK_DISPLAY);
  AddTransition('yaml_load', TK_YAML_LOAD);
  AddTransition('system', TK_SYSTEM);
  AddTransition('assign_path', TK_ASSIGN_PATH);

  PostprocessTransitions;

(*
  WriteLn(Advance(0, 'cos'));
  WriteLn(Advance(0, 'cosh'));
  AddTransition('co', 1234);
  AddTransition('cost', 12345);
  WriteLn(Advance(0, 'cos'));
  WriteLn(Advance(0, 'cosh'));
  WriteLn(Advance(0, 'co'));
  WriteLn(Advance(0, 'cost'));
*)


  (*
  S := TokenFromID(TK_SIN);

  X := Advance(0, 'sin');
  Y := Advance(0, 'sinh');
*)

  // %X, $X, #X, ^X, ~X, @X, ?X, !X, |X|
  // STREAM READ / WRITE OPERATIONS
  // READ(X, Offset, Count, Skip);
  //   Result := X[Offset..Offset+Count-1]
  //   Current(X) := Current(X) + Skip

  // =>, <=, ->, <-, |>, <|, |->, <-|
  // + _ _    -> _
  // Q: [1 2 3]
  // + _ _ _  -> _
  // + %1 %2  => _
  // + %1 _   => %1 _
  // "rewrite rules"


  // 1: match from input (LHS)
  // 2: rewrite matching expression - build output expression (RHS)
  // (2.5: inline replacements of existing symbolic expressions?)
  // 3: evaluate at evaluation points
  // _ _  =>  / _ ( + _ ... )
  // _:2  =>  / _ ( + _ ... )
  // _  =>  + _ (...)
  // _  =>  + _ . (...)           // evaluate at '.' position
  // _  =>  + _ , (...)           // evaluate at ',' position

  // _ _  =>  _ . / ( + _ ... )
  // [1 2 3 4 5] => [1 . / ( + 2 3 . / ( + 4 5 . ) ) ) ]
  // EVAL: [ 1, 1/(+2 3), 1/(+2 3/(+ 4 5)) ]

  // _ _  =>  / _  ( + _ ... )
  // [1 2 3 4 5] => [/ 1 ( + 2 / 3 ( + 4 5 ) ) ) ]

  // _ _  =>  _ . / ( _ + ... )
  // [1 2 3 4 5] => [1 . / ( 2 + 3 . / ( 4 + 5 . ) ) ) ]

  // _ => + _ (...)


  // inner recursion (... is replaced by current input)
  // + 1 (...),   + 1 ( + 2 (...) ),  + 1 ( + 2 ( + 3 (...) ) )

  // outer recursion (... is replaced by current output)
  // Q: use different symbol? e.g. _ => + _ (~)
  // + 1 (...),   + 2 ( + 1 ), + 3 ( + 2 ( + 1 ) )

  // rewrite, fold, recursion, transform, expand, ...

  // combine inner + outer ???
  // X^ < Y^ ? { X => _ ... | Y => _ ... } * [X Y]
  // conditional rule selection -> CFDG ?
  // COMBINE LISTS: * X Y
  // QUERY ? * X Y

  // @_  = index ?
  // #_  = index ?


  // X = +X  --> associate "operator" with quantity (?)

  // _ _  =>  / _  ( + _ { ... } )
  // _ _  =>  / _  ( _ { ... } )
  // _ _  =>  / _  ( _ {} )
  // [1 2 3 4 5] => / 1 ( + 2),  / 1 ( + 2 / ( + 3 / (+ 4))), / 1 ( + 2 / ( + 3 / ))

  // -> 1/2, 1/(2 + 3/4), 1/(2 + 3/(4 + 5/6))
  // -> 1/1, 1/(1 + 1), 1/(1 + 1/(1 + 1)), 1/(1 + 1/(1 + 1/(1 + 1)))

  // combine (operator, quantity) => easier pattern matching (!!!)

  // merge in haskell:
  // merge []         ys                   = ys
  // merge xs         []                   = xs
  // merge xs@(x:xt) ys@(y:yt) | x <= y    = x : merge xt ys
  //                           | otherwise = y : merge xs yt

  // CONTINUED FRACTIONS
  // Pi:
  // Pi/2 = 2/1 * 2/3 * 4/3 * 4/5 * 6/5 * 6/7
  // * (/ _ _) { ... }
  // 1/2 * 3/4 * 5/6 * 7/8 * 9/10

  // x in X -> /( * x ( / (+ x 1)) { ... } )
  // 1..100 | x ->
  // / (* 1 (/2) { /(* 2 (/3) { /(* 3 (/4) { ... } ) } ) } )
  // Q: how to evaluate (?)
  // Q: reuse previous computations?

  // golden ratio:
  // + 1 ( / {} )

  // exp (1):
  // + x (frac x {})
  // + 1 (frac 1 {+ 2 (frac 2 {+ 3 (frac 3 {+ 4 (frac 4 {})})})})
  // f = 1 + 1/(2 + 2/(3 + 3/ ... ))
  // e = +2 (/ f)

  // 0:10:10 -> 10x10 matrix (zeroes)
  // x[0]
  // stream operations
  // x$0  -> advance 0 steps
  // /( frac x$0 (+ x 1) { ... } )

  // ------------------------------------------------------------------------
  // merge
  // X, Y -> X$0 < Y$0 ? [X Y] {}

  // defining a function:
  // G x -> + x 1
  //
  // defining an axiom:
  // A ::   + x:n      <=>  * x n
  // B ::   + x (- x)  <=>  0

  // $ = stream index (relative to current position)
  // @ = absolute index


  // - multiple inputs (?)
  // - reusing inputs (?)
  // - advancing inputs (?)

  // X:N  =  repeat X N times
  // 5?X  =  get 5th item
  // X ? [ FALSE, TRUE ]
  // X|5
  // x
  // frac x y  <=>  * x ( / y )
  // X[1 2 3]   = extract item from indices



  // SEQUENCE OF INTEGERS
  // 1..N

  // SEQUENCE OF ODD INTEGERS ???
  // 1 { + 2 ... }:N
  // 1 { +


  // ===========================================================================
  // 2018-03-12:
  // mulinv: * m (/ m)   ==   1
  // addinv: + m (- m)   ==   0
  // _ _ -> x y => * x (/ y)
  // _ => / ( _ {} )
  // [1 1 1 1 1]  =>  /(1),  /(1 /(1)), /(1 /(1 /(1)))
  // [1 2 3 4 5]  =>  /(1),  /(1 /(2)), /(1 /(2 /(3))),  /(1 /(2 /(3 /(4))))

  // CUMSUM ::  _ => _ {}
  // SUM ::     _ => _ ...
  //

  // let your genius be
  // certified by sanity + (financed/sanctioned/supported/endorsed)
  // let's go to a nation of exaltation where we can even begin to shine
  // let your genius be certified by science and sanctioned by God.

end;

constructor TExpressionTokenizer.Create;
begin
  inherited Create;
  RegisterTokens;
end;

(*

GRAMMAR
=======

Array:
'[' (Array | Expression | Transform):* ']'

Evaluation:
'{' Expression | Transform '}'

Transform:
Expression '=>' Expression

Subtree:
'(' Expression ')'

Expression:
(Operator | Identifier | Subtree | Evaluation ):*

Assignment:
TK_VARIABLE '=' Expression

Statement:
Evaluation | Expression | Assignment ...

Main:
(Statement):*
// definitions/declarations/functions ?

{ _ => + _ {} } [ 1 2 3 4 5 ]


*)

(*
function TExpressionTree.AddStatement: Integer;
var
  L: Integer;
begin
  Result := AllocateNode;
  //Node[Result].Initialize;

  L := Length(FStatements);
  SetLength(FStatements, L + 1);
  FStatements[L] := Result;
end;

procedure TExpressionTree.ConnectChild(Index, AChild: Integer);
begin
  Node[Index]^.Child := AChild;
  Node[AChild]^.Prev := Index;
end;

procedure TExpressionTree.ConnectSibling(Index, ANext: Integer);
begin
  Node[Index]^.Next := ANext;
  Node[ANext]^.Prev := Index;
end;
*)


{ TExpressionTree }
function TExpressionTree.Parse(AExpression: TCustomExpression): PTreeNode;
var
  X: PTokenInfo;
  T: Integer;
  ComputeScope, FixedScope: Boolean;

  //function ParseExpression(Index: Integer; ScopeID: Integer = 0): Boolean; forward;

  function ParseExpression(
    Index: Integer;
    ScopeID: Integer = 0;
    IsNext: Boolean = False;
    StopAtCommaTopLevel: Boolean = False
  ): Boolean;
  var
    Meta, Op, Extra: Integer;
    Ids: TIntegerDynArray;

    function ParseEvaluation: Integer;
    begin
      Result := EOT;
      T := Expression.Accept(TK_CURLY_BEGIN);
      if T <> -1 then
      begin
        Result := AllocateNode;
        //PEvaluationNode(Node[Result])^.Initialize;
        TEvaluationNode.InitTreeNode(Result);
        //! Node[Result]^.ID := 0;
        Node[Result]^.Ref := T;
        //Expression.Token[T]^.ID := Expression.Token[T]^.ID or Op;
        ParseExpression(Result, ScopeID);
        Expression.Expect(TK_CURLY_END);
      end;
    end;

    function ParseSubexpression: Integer;
    begin
      Result := EOT;
      T := Expression.Accept(TK_PARENTHESIS_BEGIN);
      if T <> -1 then
      begin
        Result := AllocateNode;
        //PExpressionNode(Node[Result])^.Initialize;
        TExpressionNode.InitTreeNode(Result);
        Node[Result]^.Ref := T;
        //Expression.Token[T]^.ID := Expression.Token[T]^.ID or Op;
        ParseExpression(Result, ScopeID);
        Expression.Expect(TK_PARENTHESIS_END);
      end;
    end;

    function ParseArray: Integer;
    begin
      Result := EOT;
      T := Expression.Accept(TK_BRACKET_BEGIN);
      if T <> -1 then
      begin
        Result := AllocateNode;
        //PArrayNode(Node[Result])^.Initialize;
        TArrayNode.InitTreeNode(Result);
        Node[Result]^.Ref := T;
        //Expression.Token[T]^.ID := Expression.Token[T]^.ID or Op;
        ParseExpression(Result, ScopeID);
        Expression.Expect(TK_BRACKET_END);
      end;
    end;

    function ParseGrouping: Integer;
    var
      Container: Integer;

      function FixedMetaContinuesTransform: Boolean;
      var
        NextTokenId: Integer;
      begin
        Result := False;
        if not Assigned(Expression.CurToken) or
           (Expression.CurToken^.ID <> TK_FIXED) or
           (Expression.Index + 1 >= Expression.Size) then
          Exit;

        NextTokenId := Expression.Token[Expression.Index + 1]^.ID and TK_SPECIAL_MASK;
        Result := (NextTokenId = TK_IMPLIES) or (NextTokenId = TK_EQUIVALENCE);
      end;

      function TokenStartsImplicitSibling(TokenId: Integer): Boolean;
      begin
        Result := ((TokenId and TK_TYPE) = TK_IDENTIFIER) or
                  (TokenId = TK_PARENTHESIS_BEGIN) or
                  (TokenId = TK_CURLY_BEGIN) or
                  (TokenId = TK_BRACKET_BEGIN) or
                  (TokenId = TK_GROUP_BEGIN) or
                  (TokenId = TK_APOSTROPHE) or
                  (TokenId = TK_BACKTICK) or
                  ((TokenId and TK_OPERATOR_MASK) <> 0) or
                  ((TokenId and TK_SELECTOR_EXTRA_MASK) <> 0) or
                  ((((TokenId and TK_META_MASK) <> 0) and (TokenId <> TK_AT)) and
                   (not FixedMetaContinuesTransform));
      end;
    begin
      Result := EOT;
      T := Expression.Accept(TK_GROUP_BEGIN);
      if T <> -1 then
      begin
        Container := AllocateNode;
        TExpressionNode.InitTreeNode(Container);
        Node[Container]^.Ref := T;
        ParseExpression(Container, ScopeID);
        Expression.Expect(TK_GROUP_END);

        Result := Node[Container]^.LHS;
        Node[Container]^.LHS := EOT;
        GlobalTree.DeleteSubtree(EOT, Container);
        if Result = EOT then
          raise Exception.Create('transparent grouping cannot be empty');
        if (Node[Result]^.RHS <> EOT) and
           Assigned(Expression.CurToken) and
           TokenStartsImplicitSibling(Expression.CurToken^.ID) then
          raise Exception.Create(
            'non-atomic transparent grouping cannot be followed by an implicit sibling'
          );
      end;
    end;

    function ParseCompute: Integer;
    begin
      Result := EOT;
      // N: nested scopes are not allowed
      if not ComputeScope then
      begin
        T := Expression.Accept(TK_BACKTICK);
        if (T <> -1) then
        begin
          ComputeScope := True;
          Result := AllocateNode;
          //PComputeNode(Node[Result])^.Initialize;
          TComputeNode.InitTreeNode(Result);

          //! Node[Result]^.Token := T;

          //Expression.Token[T]^.ID := Expression.Token[T]^.ID or Op;
          ParseExpression(Result, ScopeID);
          Expression.Expect(TK_BACKTICK);
          ComputeScope := False;
        end;
      end;
    end;

    // fixed expression ( = static / is not included in evaluation )
    function ParseFixed: Integer;
    begin
      Result := EOT;
      // N: nested scopes are not allowed
      if not FixedScope then
      begin
        T := Expression.Accept(TK_APOSTROPHE);
        if (T <> -1) then
        begin
          FixedScope := True;
          Result := AllocateNode;
          TExpressionNode.InitTreeNode(Result, T);
          Node[Result]^.Data := Node[Result]^.Data or TK_FIXED;
          ParseExpression(Result, ScopeID or TK_FIXED);
          Expression.Expect(TK_APOSTROPHE);
          FixedScope := False;
        end;
      end;
    end;


  (*
  function ParseString: Integer;
  begin
    Result := EOT;
    T := Expression.Accept(TK_QUOTATIONMARK);
    if T <> -1 then
    begin
      Result := AllocateNode;
      PStringNode(Node[Result])^.Initialize;
      Node[Result]^.Token := T;
      //ParseExpression(Result);
      Expression.Expect(TK_QUOTATIONMARK);
    end;
  end;
  *)


    function AddNode(ID: Integer): Boolean;
    var
      L, T: Integer;
    begin
      Result := False;
      if ID <> EOT then
      begin
        Result := True;
        L := Length(Ids);
        SetLength(Ids, L + 1);
        Ids[L] := ID;

        T := Node[ID]^.Ref;
        Node[ID]^.Data := Node[ID]^.Data or Op or Meta or Extra;
        //WriteLn('ID = ', ID, ', Op = ', Node[ID]^.Op);

        if T >= 0 then
          Expression.Token[T]^.ID := Expression.Token[T]^.ID or Op or Meta or Extra or ScopeID;

        Meta := 0;
        Extra := 0;
      end;
    end;

    function ParseScopes: Boolean;
    begin
{$IFDEF DEBUG_PARSING}
      WriteLn('ParseScopes');
{$ENDIF}
      Result := False;
      if AddNode(ParseSubexpression) then
        Result := True
      else if AddNode(ParseEvaluation) then
        Result := True
      else if AddNode(ParseArray) then
        Result := True
      else if AddNode(ParseGrouping) then
        Result := True
      else if AddNode(ParseCompute) then
        Result := True
      else if AddNode(ParseFixed) then
        Result := True;
      //else if AddNode(ParseString) then
      //  Result := True;
      //Result := ParseSubexpression(Index) or ParseEvaluation(Index) or ParseArray(Index);
    end;

    procedure LinkNodes;
    var
      I: Integer;
    begin
      for I := 0 to High(Ids) - 1 do
        LinkRHS(Ids[I], Ids[I + 1]);
    end;

    function ParseIdentifier: Boolean;
    var
      ID, TT, Definition, RuleNameToken, RuleNameNode: Integer;
      PolicyToken, PolicyNode: Integer;
      NumericLiteralType: Integer;
      ImaginaryComponent: Integer;

      function ParseScopeBody: Integer;
      var
        BodyID: Integer;
        EntryContainer: Integer;
        EntryNode: Integer;
        SeparatorNode: Integer;
        FirstSeparator: Integer;
        LastSeparator: Integer;
        OpenToken: Integer;
      begin
        Result := EOT;
        OpenToken := Expression.Accept(TK_CURLY_BEGIN);
        if OpenToken = -1 then
          Exit(EOT);

        BodyID := AllocateNode;
        TEvaluationNode.InitTreeNode(BodyID);
        Node[BodyID]^.Ref := OpenToken;
        FirstSeparator := EOT;
        LastSeparator := EOT;

        while Expression.CurToken <> nil do
        begin
          if Expression.Accept(TK_CURLY_END) <> -1 then
          begin
            if FirstSeparator <> EOT then
              LinkLHS(BodyID, FirstSeparator);
            Exit(BodyID);
          end;

          EntryContainer := AllocateNode;
          TExpressionNode.InitTreeNode(EntryContainer);
          ParseExpression(EntryContainer, ScopeID, True, True);
          EntryNode := Node[EntryContainer]^.RHS;
          Node[EntryContainer]^.RHS := EOT;
          GlobalTree.DeleteSubtree(EOT, EntryContainer);

          if EntryNode = EOT then
            raise Exception.Create('scope body cannot contain an empty entry');

          SeparatorNode := AllocateNode;
          TSeparatorNode.InitTreeNode(SeparatorNode);
          LinkLHS(SeparatorNode, EntryNode);
          if FirstSeparator = EOT then
            FirstSeparator := SeparatorNode
          else
            LinkRHS(LastSeparator, SeparatorNode);
          LastSeparator := SeparatorNode;

          if Expression.Accept(TK_COMMA) <> -1 then
            Continue;
          if Expression.Accept(TK_CURLY_END) <> -1 then
          begin
            LinkLHS(BodyID, FirstSeparator);
            Exit(BodyID);
          end;

          Expression.Expect(TK_CURLY_END);
        end;

        Expression.Expect(TK_CURLY_END);
      end;
    begin
{$IFDEF DEBUG_PARSING}
      WriteLn('ParseIdentifier');
{$ENDIF}
      TT := -1;
      if Assigned(Expression.CurToken) and
         (Expression.CurToken^.ID and TK_TYPE = TK_IDENTIFIER) then
        TT := Expression.Accept(Expression.CurToken^.ID);
      Result := TT <> -1;
      if Result then
      begin
        ID := AllocateNode;
        if TryGetImaginaryNumericLiteral(
          Expression.TokenValue(TT), NumericLiteralType, ImaginaryComponent
        ) then
        begin
          if NumericLiteralType = TK_FLOAT then
            TFloatNode.InitTreeNode(ID)
          else
            TIntegerNode.InitTreeNode(ID);
          Extra := Extra or ImaginaryComponent;
        end
        else case X^.ID of
          TK_INTEGER:
            TIntegerNode.InitTreeNode(ID); //PIntegerNode(Node[ID])^.Initialize;
          // TK_CONSTANT: ;
          TK_FLOAT:
            TFloatNode.InitTreeNode(ID); //PFloatNode(Node[ID])^.Initialize;
          TK_IMAG_I_INT, TK_IMAG_J_INT, TK_IMAG_K_INT:
            begin
              TIntegerNode.InitTreeNode(ID);
              Extra := Extra or (X^.ID and TK_EXTRA_MASK);
            end;
          TK_IMAG_I_FLOAT, TK_IMAG_J_FLOAT, TK_IMAG_K_FLOAT:
            begin
              TFloatNode.InitTreeNode(ID);
              Extra := Extra or (X^.ID and TK_EXTRA_MASK);
            end;
          TK_STRING: TStringNode.InitTreeNode(ID); //PStringNode(Node[ID])^.Initialize;
          TK_PACKAGE:
            begin
              TPackageNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_IMPORT:
            begin
              TImportNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_INCLUDE:
            begin
              TIncludeNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_GLOBAL:
            begin
              TGlobalNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_SCOPE_FRAME:
            begin
              TScopeFrameNode.InitTreeNode(ID);
              Definition := ParseScopeBody;
              if Definition = EOT then
                raise Exception.Create('scope requires a { ... } body');
              LinkLHS(ID, Definition);
            end;
          TK_ALIAS:
            begin
              TAliasNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_PRINT:
            begin
              TOutputNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_TREE:
            begin
              TTreeOutputNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_IR:
            begin
              TIROutputNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_QUERY_KEYS:
            begin
              TQueryKeysNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_QUERY_VALUES:
            begin
              TQueryValuesNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_QUERY_CHILDREN:
            begin
              TQueryChildrenNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_GET:
            begin
              TGetNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_PATH_SEGMENT:
            begin
              TPathSegmentNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_MAKE_PAIR:
            begin
              TMakePairNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_FMT:
            begin
              TFmtNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_PRINTF:
            begin
              TPrintfNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_RENDER:
            begin
              TRenderNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_JSON_LOAD:
            begin
              TJsonLoadNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_JSON_ENCODE:
            begin
              TJsonEncodeNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_JSON_SAVE:
            begin
              TJsonSaveNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_DISPLAY:
            begin
              TDisplayNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_YAML_LOAD:
            begin
              TYamlLoadNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_SYSTEM:
            begin
              TSystemNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_ASSIGN_PATH:
            begin
              TAssignPathNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_EXEC:
            begin
              TExecNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_EXPLODE:
            begin
              TExplodeNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_IMPLODE:
            begin
              TImplodeNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_DEFINE:
            begin
              TDefineNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_CALLABLE:
            begin
              TCallableNode.InitTreeNode(ID);
              Meta := Meta or TK_DOT;
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition <> EOT then
              begin
                Node[ID]^.RHS := EOT;
                LinkLHS(ID, Definition);
              end;
            end;
          TK_SELECTOR:
            begin
              TSelectionPolicyNode.InitTreeNode(ID);
              PolicyToken := -1;
              if Assigned(Expression.CurToken) and
                 (((Expression.CurToken^.ID and TK_TYPE) = TK_IDENTIFIER) or
                  (Expression.CurToken^.ID = TK_STRING)) then
                PolicyToken := Expression.Accept(Expression.CurToken^.ID);

              if PolicyToken <> -1 then
              begin
                PolicyNode := AllocateNode;
                if Expression.TokenID(PolicyToken) = TK_STRING then
                  TStringNode.InitTreeNode(PolicyNode)
                else
                  TVariableNode.InitTreeNode(PolicyNode);
                Node[PolicyNode]^.Ref := PolicyToken;
                LinkLHS(ID, PolicyNode);
              end;

              ParseExpression(ID, ScopeID, True);
            end;
          TK_RULE_FORWARD, TK_RULE_REVERSE:
            begin
              if X^.ID = TK_RULE_FORWARD then
                TForwardRuleNode.InitTreeNode(ID)
              else
                TReverseRuleNode.InitTreeNode(ID);
              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition = EOT then
                raise Exception.Create('Missing rule reference after orientation keyword');
              Node[ID]^.RHS := EOT;
              LinkLHS(ID, Definition);
            end;
          TK_RULE:
            begin
              TRuleNode.InitTreeNode(ID);

              RuleNameToken := -1;
              if Assigned(Expression.CurToken) and
                 (Expression.CurToken^.ID and TK_TYPE = TK_IDENTIFIER) then
                RuleNameToken := Expression.Accept(Expression.CurToken^.ID);
              if RuleNameToken = -1 then
                raise Exception.Create('Missing rule name after "rule"');

              RuleNameNode := AllocateNode;
              TVariableNode.InitTreeNode(RuleNameNode);
              Node[RuleNameNode]^.Ref := RuleNameToken;
              if IsUpperCase(Expression.TokenValue(RuleNameToken)) then
                Node[RuleNameNode]^.Data := Node[RuleNameNode]^.Data or TK_ALLCAPS;

              ParseExpression(ID, ScopeID, True);
              Definition := Node[ID]^.RHS;
              if Definition = EOT then
                raise Exception.CreateFmt(
                  'Missing rule definition for "%s"',
                  [Expression.TokenValue(RuleNameToken)]
                );

              LinkLHS(ID, RuleNameNode);
            end;

          TK_OBJECT, TK_NAMESPACE, TK_FUNCTION:
            begin
              // object XYZ { ... }
              // -> parse scope (LHS)
            end;

          TK_PATTERN:
            begin
              TPatternNode.InitTreeNode(ID);
              //Meta := Meta or TK_PATTERN;
              //ParseExpression(ID, ScopeID, True);
            end;

        else
          //PVariableNode(Node[ID])^.Initialize;
          TVariableNode.InitTreeNode(ID);
          if IsUpperCase(Expression.TokenValue(TT)) then
            Extra := Extra or TK_ALLCAPS;
            //Expression.Token[TT]^.ID := Expression.Token[TT]^.ID
        end;
        // Note to self : combining OPERATOR and IDENTIFIER
        // -> write back to token in expression
        //Expression.Tokens[T].ID := X^.ID or Op;     // OK!
        //Expression.Token[T]^.ID := X^.ID or Op;     // OK!
        //WriteLn(Expression.Token[T]^.ID and TK_OPERATOR_MASK);

        //! Node[ID]^.Token := TT;
        Node[ID]^.Ref := TT;
        AddNode(ID);
        //WriteLn(PBaseNode(Node[ID])^.TreeValue);


        //Writeln(SizeOf(Node[ID]^));
        //Node[ID]^.Token := X^; //Expression.CurToken^;
        //Node[ID]^.Token.ID := X^.ID or Op;
      end;
    end;

    function ParseIdentifierOrScope: Boolean;
    begin
      Result := False;
      X := Expression.CurToken;      // N: refactor
      if ParseIdentifier then
        Result := True
      else if ParseScopes then
        Result := True;
      // ParseOperator ???
    end;

    function PopId: Integer;
    var
      H: Integer;
    begin
      H := High(Ids);
      Result := Ids[H];
      SetLength(Ids, H);
    end;

    function ParseOperator: Boolean; forward;
    function ParseExtra: Boolean; forward;

    function TryExtractVariableSubtreeKeyRef(KeyIndex: Integer; out KeyRef: Integer): Boolean;
    begin
      Result := False;
      KeyRef := EOT;
      if KeyIndex = EOT then
        Exit(False);

      // Keep parser-side conversion conservative to avoid losing structural keys.
      if Node[KeyIndex]^.RHS <> EOT then
        Exit(False);
      if Node[KeyIndex]^.LHS <> EOT then
        Exit(False);
      if Node[KeyIndex]^.Ref = EOT then
        Exit(False);

      KeyRef := Node[KeyIndex]^.Ref;
      Result := True;
    end;

    procedure NormalizeVariableSubtreeNodes(RootIndex: Integer);
      procedure Visit(NodeIndex: Integer);
      var
        LeftIndex, RightIndex: Integer;
        KeyRef: Integer;
        KeyData: Integer;
      begin
        if NodeIndex = EOT then
          Exit;

        LeftIndex := Node[NodeIndex]^.LHS;
        RightIndex := Node[NodeIndex]^.RHS;

        Visit(LeftIndex);
        Visit(RightIndex);

        if Node[NodeIndex]^.Id <> OBJ_VARIABLE_SUBTREE then
          Exit;
        if (LeftIndex = EOT) or (RightIndex = EOT) then
          Exit;
        if not TryExtractVariableSubtreeKeyRef(LeftIndex, KeyRef) then
          raise Exception.Create(
            'Invalid key for "->": key must be an atomic identifier/string token'
          );
        KeyData := Node[LeftIndex]^.Data;

        // Variable subtree shape:
        //   Ref = key token, LHS = payload subtree, RHS = sibling chain.
        Node[NodeIndex]^.Ref := KeyRef;
        if (KeyData and TK_DOLLAR) = TK_DOLLAR then
          Node[NodeIndex]^.Data := Node[NodeIndex]^.Data or TK_DOLLAR;
        if (KeyData and TK_ALLCAPS) = TK_ALLCAPS then
          Node[NodeIndex]^.Data := Node[NodeIndex]^.Data or TK_ALLCAPS;
        Node[NodeIndex]^.LHS := EOT;
        Node[NodeIndex]^.RHS := EOT;
        LinkLHS(NodeIndex, RightIndex);
        DeleteSubtree(EOT, LeftIndex);
      end;
    begin
      Visit(RootIndex);
    end;

    function ParseSpecial: Boolean;
    var
      NID, U, V: Integer;
      SpecialTokenId: Integer;
      SpecialOpBits: Integer;
    begin
{$IFDEF DEBUG_PARSING}
      WriteLn('ParseSpecial ', Expression.CurToken^.Index, ' ', Expression.Index, ' = ', Expression.Values[Expression.CurToken^.Index]);
      WriteLn('T := Expression.AcceptMask(TK_SPECIAL_MASK)');
{$ENDIF}

      if StopAtCommaTopLevel and Assigned(Expression.CurToken) and
         (Expression.CurToken^.ID = TK_COMMA) then
        Exit(False);

      //Result := IsSpecialToken(X^.ID);
      //if Result then
      //  T := Expression.Accept(X^.ID);
      // Category-equality match (not bit-presence), otherwise overlapping
      // 2-bit category encodings can misclassify e.g. scope tokens as special.
      T := Expression.Accept(TK_SPECIAL, TK_TYPE);
      Result := T <> -1;

      if Result then
      begin
        SpecialTokenId := X^.ID and TK_SPECIAL_MASK;
        case SpecialTokenId of
          TK_DEEP_ASSIGN_OVERWRITE: SpecialOpBits := TK_RELATIONAL_GT;
          TK_DEEP_ASSIGN_KEEP: SpecialOpBits := TK_RELATIONAL_LT;
          TK_DEEP_ASSIGN_FAIL: SpecialOpBits := TK_RELATIONAL_NOT;
        else
          SpecialOpBits := X^.ID and TK_OPERATOR_MASK;
        end;

        // LHS => RHS,  LHS <=> RHS,  LHS -> RHS,  LHS <-> RHS

        // allocate "=>" node
        NID := AllocateNode;
        case SpecialTokenId of
          TK_IMPLIES:       TTransformationNode.InitTreeNode(NID);
          TK_EQUIVALENCE:   TEquivalenceNode.InitTreeNode(NID);
          TK_INLINE_TRANSFORM: TInlineTransformationNode.InitTreeNode(NID);
          TK_PIPE:          TPipeNode.InitTreeNode(NID);
          TK_RIGHT_ARROW:   TVariableSubtreeNode.InitTreeNode(NID);
          TK_VARIABLE_SUBTREE_ARROW: TVariableSubtreeNode.InitTreeNode(NID);
          TK_ASSIGNMENT:    TAssignmentNode.InitTreeNode(NID);
          TK_DEEP_ASSIGN,
          TK_DEEP_ASSIGN_OVERWRITE,
          TK_DEEP_ASSIGN_KEEP,
          TK_DEEP_ASSIGN_FAIL: TDeepAssignmentNode.InitTreeNode(NID);
          TK_COLON:         TRepeatNode.InitTreeNode(NID);
          TK_ITERATOR:      TStagedRepeatNode.InitTreeNode(NID);
          TK_HASH:          TPermuteDimensionsNode.InitTreeNode(NID);
          TK_COMMA:         TSeparatorNode.InitTreeNode(NID);
          TK_QUESTIONMARK:  TSelectionNode.InitTreeNode(NID);
          TK_FALLBACK:      TFallbackNode.InitTreeNode(NID);
          //TK_INLINE_SELECTION: TInlineSelectionNode.InitTreeNode(NID);
          TK_SUBST_TRANSFORM: TSubstitutionNode.InitTreeNode(NID);
          TK_SYMBOL_SUBST_TRANSFORM: TSymbolSubstitutionNode.InitTreeNode(NID);
          TK_SUBST_EQUIVALENCE: TEquivalenceSubstitutionNode.InitTreeNode(NID);
          TK_INFERENCE:     TInferenceNode.InitTreeNode(NID);
          TK_INFERENCE_WITNESS: TInferenceWitnessNode.InitTreeNode(NID);
          TK_AMPERSAND:     //PEntrywiseProductNode(Node[NID])^.Initialize;
                            TConcatenateNode.InitTreeNode(NID);
          //TK_BACKSLASH:     PInnerProductNode(Node[NID])^.Initialize;
          //TK_CARTESIAN:     PCartesianProductNode(Node[NID])^.Initialize;
          TK_MATCH_ANY, TK_MATCH_ANY_LONG:
                            TMatchAnyNode.InitTreeNode(NID);
          TK_TRIPLEDOT, TK_FORWARD: //, TK_FORWARD_DFS, TK_REVERSE_DFS:
            TRecurseNode.InitTreeNode(NID);
        end;
        Node[NID]^.Ref := T;
        Expression.Token[T]^.ID := X^.ID or Meta or Extra;
        Node[NID]^.Data := Node[NID]^.Data or Meta or Extra or SpecialOpBits;

        case SpecialTokenId of
          TK_TRIPLEDOT, TK_FORWARD, TK_MATCH_ANY, TK_MATCH_ANY_LONG: //, TK_FORWARD_DFS, TK_REVERSE_DFS:
            begin
              AddNode(NID);
              //Expression.Token[T]^.ID := X^.ID or Op or Meta;   // token id
            end;

          TK_COMMA:  // count whitespace?
            begin
              // [ 1 , 2 ] | parseexpression => NID.Child = 2, Ids = 1
              // -> [ comma( 1 ) comma( 2 ) ]
              ParseExpression(NID, ScopeID, False, StopAtCommaTopLevel);  // NID = parent node (separator)
              U := Node[NID]^.LHS;
              //WriteLn(PBaseNode(Node[U])^.TreeValue);

              // wrap child if last in list

              //WriteLn(PBaseNode(Node[NID])^.TreeValue);
              //! if (U <> EOT) and (Node[U]^.TokenID and TK_COMMA <> TK_COMMA) then
              if (U <> EOT) and (Node[U]^.RefData and TK_COMMA <> TK_COMMA) then
              begin
                V := AllocateNode;
                TSeparatorNode.InitTreeNode(V);
                Node[V]^.Ref := Expression.Append(TK_COMMA, ',');
                LinkLHS(V, U);
                U := V;
              end;

              LinkRHS(NID, U);
              Node[NID]^.LHS := EOT;

              LinkNodes;
              LinkLHS(NID, Ids[0]);

              SetLength(Ids, 1);
              Ids[0] := NID;
              Op := 0;
            end;
          TK_BACKSLASH:
            begin
              ParseExpression(NID, ScopeID, False, StopAtCommaTopLevel);
              AddNode(NID);
            end;
          TK_ASSIGNMENT,
          TK_DEEP_ASSIGN,
          TK_DEEP_ASSIGN_OVERWRITE,
          TK_DEEP_ASSIGN_KEEP,
          TK_DEEP_ASSIGN_FAIL:
            begin
              ParseExpression(NID, ScopeID, False, StopAtCommaTopLevel);
              if Length(Ids) = 0 then
                raise Exception.Create('Missing assignment target before "="');

              U := Node[NID]^.LHS;
              if U = EOT then
                raise Exception.Create('Missing assignment value after "="');

              LinkRHS(NID, U);
              Node[NID]^.LHS := EOT;

              LinkNodes;
              LinkLHS(NID, Ids[0]);

              SetLength(Ids, 1);
              Ids[0] := NID;
              Op := 0;
            end;
          TK_AMPERSAND:
            begin
              if Length(Ids) = 0 then
              begin
                ParseExpression(NID, ScopeID, False, StopAtCommaTopLevel);
                AddNode(NID);
              end
              else
              begin
                LinkNodes;
                LinkLHS(NID, Ids[0]);
                SetLength(Ids, 1);
                Ids[0] := NID;
              end;
              Op := 0;
            end;
         (*
          TK_COMMA:
            begin
              CommaSeparated := True;
              AddNode(NID);
              LinkNodes;
              // LHS is the child of the "=>" node
              ConnectChild(NID, Ids[0]);
              if LastNID <> EOT then
                ConnectSibling(LastNID, NID);
              // RHS will be appended to the Ids list
              //SetLength(Ids, 1);
              //Ids[0] := NID;
              SetLength(Ids, 0);
              LastNID := NID;
            end;
          *)
        else
          // TK_IMPLIES, TK_PIPE, TK_COLON, TK_RIGHT_ARROW, TK_HASH
          begin

          // link LHS nodes
            LinkNodes;
            // LHS is the child of the "=>" node
            //WriteLn(PBaseNode(Node[NID])^.TreeValue);

            LinkLHS(NID, Ids[0]);
            // RHS will be appended to the Ids list
            SetLength(Ids, 1);
            Ids[0] := NID;

            Op := 0;
          end;
        end;
        Meta := 0;
      end;
    end;

    // algebraic operators
    function ParseOperator: Boolean;
    begin
      Result := Expression.AcceptMask(TK_OPERATOR_MASK) <> - 1;
      if Result then
        Op := Op or X^.ID and TK_OPERATOR_MASK;
    end;

    // extra bits
    function ParseExtra: Boolean;
    begin
      Result := Expression.AcceptMask(TK_SELECTOR_EXTRA_MASK) <> - 1;

      // case Result of
      //   TK_IMAG_I, TK_IMAG_J, TK_IMAG_K:
      //     begin
      //       TFloatNode.InitTreeNode(ID);
      //       Extra := Extra or X^.ID;
      //     end;
      // end;

      if Result then
        Extra := Extra or (X^.ID and TK_SELECTOR_EXTRA_MASK);
    end;

    function ParsePrefixedValue(out ValueIndex: Integer): Boolean;
    var
      StartLength: Integer;
    begin
      Result := False;
      ValueIndex := EOT;
      StartLength := Length(Ids);

      while Assigned(Expression.CurToken) do
      begin
        X := Expression.CurToken;
        if ParseOperator then
          Continue;
        X := Expression.CurToken;
        if ParseExtra then
          Continue;
        Break;
      end;

      if not ParseIdentifierOrScope then
        Exit(False);
      if Length(Ids) <> StartLength + 1 then
        raise Exception.Create('Expected one value');

      ValueIndex := PopId;
      Result := True;
    end;

    function ParseRangeFromLeft(
      LeftIndex: Integer;
      AllowExplicitStep: Boolean;
      out RangeIndex: Integer
    ): Boolean;
    var
      RangeToken: Integer;
      RightIndex: Integer;
      StepKeywordToken: Integer;
      StepIndex: Integer;
      WrapperIndex: Integer;
    begin
      Result := False;
      RangeIndex := EOT;
      if not Assigned(Expression.CurToken) or
         (Expression.CurToken^.ID <> TK_DOUBLEDOT) then
        Exit(False);

      RangeToken := Expression.Accept(TK_DOUBLEDOT);
      Op := 0;
      Meta := 0;
      Extra := 0;
      if not ParsePrefixedValue(RightIndex) then
        raise Exception.Create('Missing range endpoint after ".."');

      RangeIndex := AllocateNode;
      TRangeNode.InitTreeNode(RangeIndex);
      Node[RangeIndex]^.Ref := RangeToken;
      LinkLHS(RangeIndex, LeftIndex);
      LinkRHS(RangeIndex, RightIndex);

      Op := 0;
      Meta := 0;
      Extra := 0;
      if AllowExplicitStep and Assigned(Expression.CurToken) and
         ((Expression.CurToken^.ID and TK_TYPE) = TK_IDENTIFIER) and
         (Expression.CurTokenValue = 'by') then
      begin
        StepKeywordToken := Expression.Accept(Expression.CurToken^.ID);
        if not ParsePrefixedValue(StepIndex) then
          raise Exception.Create('Missing range step after "by"');

        WrapperIndex := AllocateNode;
        TSteppedRangeNode.InitTreeNode(WrapperIndex);
        Node[WrapperIndex]^.Ref := StepKeywordToken;
        LinkLHS(WrapperIndex, RangeIndex);
        LinkRHS(WrapperIndex, StepIndex);
        RangeIndex := WrapperIndex;
      end;

      Op := 0;
      Meta := 0;
      Extra := 0;
      Result := True;
    end;

    function ParseRangeOperation: Boolean;
    var
      LeftIndex: Integer;
      RangeIndex: Integer;
    begin
      Result := False;
      if not Assigned(Expression.CurToken) or
         (Expression.CurToken^.ID <> TK_DOUBLEDOT) then
        Exit(False);
      if Length(Ids) = 0 then
        raise Exception.Create('Missing range start before ".."');

      LeftIndex := PopId;
      if not ParseRangeFromLeft(LeftIndex, True, RangeIndex) then
        Exit(False);
      AddNode(RangeIndex);
      Result := True;
    end;

    function HasPendingRepeatDriver: Boolean;
    begin
      Result :=
        (Length(Ids) > 1) and
        ((Node[Ids[0]]^.Id = OBJ_REPEAT) or
         (Node[Ids[0]]^.Id = OBJ_STAGED_REPEAT)) and
        (Node[Ids[0]]^.RHS = EOT);
    end;

    procedure BindPendingRepeatDriver(IteratorToken: Integer);
    var
      WrapperIndex: Integer;
      DriverRoot: Integer;
      I: Integer;
    begin
      for I := 1 to High(Ids) - 1 do
        LinkRHS(Ids[I], Ids[I + 1]);
      DriverRoot := Ids[1];

      WrapperIndex := AllocateNode;
      TIteratorBindingNode.InitTreeNode(WrapperIndex);
      Node[WrapperIndex]^.Data := Node[WrapperIndex]^.Data or TK_AT;
      Node[WrapperIndex]^.Ref := IteratorToken;
      LinkLHS(WrapperIndex, DriverRoot);

      SetLength(Ids, 2);
      Ids[1] := WrapperIndex;
    end;

    function ParseAtOperation: Boolean;
    var
      IteratorToken: Integer;
      WrapperIndex: Integer;
      ValueRoot: Integer;
      IndexRoot: Integer;
      RangeIndex: Integer;
      IsRepeatBinding: Boolean;
    begin
      Result := False;
      if not Assigned(Expression.CurToken) or
         (Expression.CurToken^.ID <> TK_AT) then
        Exit(False);

      if Length(Ids) = 0 then
        raise Exception.Create('Missing value before "@"');

      IsRepeatBinding := HasPendingRepeatDriver;

      T := Expression.Accept(TK_AT);
      if IsRepeatBinding then
      begin
        if not Assigned(Expression.CurToken) or
           ((Expression.CurToken^.ID and TK_TYPE) <> TK_IDENTIFIER) then
          raise Exception.Create('Missing iterator name after "@"');

        IteratorToken := Expression.Accept(Expression.CurToken^.ID);
        BindPendingRepeatDriver(IteratorToken);
        Op := 0;
        Meta := 0;
        Extra := 0;
        Exit(True);
      end;

      LinkNodes;
      ValueRoot := Ids[0];
      SetLength(Ids, 0);

      if not ParsePrefixedValue(IndexRoot) then
        raise Exception.Create('Missing index expression after "@"');
      if ParseRangeFromLeft(IndexRoot, False, RangeIndex) then
      begin
        IndexRoot := RangeIndex;
        if Assigned(Expression.CurToken) and
           ((Expression.CurToken^.ID and TK_TYPE) = TK_IDENTIFIER) and
           (Expression.CurTokenValue = 'by') then
          raise Exception.Create('Stepped index slices are not supported');
      end;

      WrapperIndex := AllocateNode;
      TIndexLookupNode.InitTreeNode(WrapperIndex);
      Node[WrapperIndex]^.Data := Node[WrapperIndex]^.Data or TK_AT;
      Node[WrapperIndex]^.Ref := T;
      LinkLHS(WrapperIndex, ValueRoot);
      LinkRHS(WrapperIndex, IndexRoot);

      SetLength(Ids, 1);
      Ids[0] := WrapperIndex;
      Op := 0;
      Meta := 0;
      Extra := 0;
      Result := True;
    end;

    // meta operators
    function ParseMeta: Boolean;
    var
      MetaToken: PTokenInfo;
    begin
      Result := False;
      MetaToken := Expression.CurToken;
      if not Assigned(MetaToken) then
        Exit(False);

      if (MetaToken^.ID = TK_CARET) or
         (((MetaToken^.ID and TK_META_MASK) <> 0) and
          (MetaToken^.ID <> TK_AT)) then
      begin
        Meta := Meta or MetaToken^.ID;
        Expression.NextToken;
        Exit(True);
      end;
    end;

  begin
    Result := True; // accept empty expressions
    Op := 0;
    Meta := 0;
    Extra := 0;
    //LastNID := EOT;
    while Expression.CurToken <> nil do
    begin
      X := Expression.CurToken;            // N: refactor
      //WriteLn('X := Expression.CurToken');
{$IFDEF DEBUG_PARSING}
      WriteLn('X = ' , X^.Index, ' ', Expression.Values[X^.Index], ' | ID = ', X^.ID);
{$ENDIF}
      if ParseIdentifier or ParseOperator or ParseRangeOperation or
         ParseAtOperation or ParseMeta or
         ParseExtra or ParseSpecial or ParseScopes then
        Continue;
      Break; // nothing more to accept
    end;
    if Length(Ids) > 0 then
    begin
      LinkNodes;
      NormalizeVariableSubtreeNodes(Ids[0]);
      //ConnectChild(Index, Ids[0]);
      //ConnectChild(Index, Ids[0]);
      LinkLHSOrRHS(Index, Ids[0], Ord(IsNext));
      // N: keep parent as a separate node (so that it can be manipulated as a variable)
    end;
  end;

  function ParseStatement: Boolean;
  var
    ID: Integer;
  begin
    Result := True;
    ComputeScope := False;
    FixedScope := False;
    ID := AddStatement;
    SetStatementDebuggerSourcePath(ID, DebuggerSourcePath);
    TStatementNode.InitTreeNode(ID);
    if Assigned(Expression.CurToken) then
      Node[ID]^.Ref := Expression.Index;
    ParseExpression(ID);
  end;

begin
  Self.Expression := AExpression;
  while Expression.CurToken <> nil do
  begin
    //WriteLn(Format('[ #tokens = %d ]', [Expression.Size]));
    //ID := AllocateNode;
    //Assert(ID = 0);

    ParseStatement;

    if Expression.CurToken = nil then Break;

    Expression.Expect(TK_SEMICOLON);
  end;
//  until Expression.CurToken = nil;
  // ParseExpression;
  // Expression;
  // Assignment;


end;

function TExpressionTree.PrintNodes(Index: Integer; Data: Pointer): Integer;
begin
  //WriteLn(Node[Index]^.Token.Raw);
  // if Node[Index]^.Token >= 0 then
  //   WriteLn(Expression.TokenValue(Node[Index]^.Token))
  // else
  //   WriteLn(Format('Node[%d].Token = %d', [Index, Node[Index]^.Token]));
  // Result := TRAVERSE_CONTINUE;
  // PBaseNode(Node[Index])^.Evaluate(TContext(Data));
end;

constructor TExpressionTree.Create;
begin
  inherited Create;
  FStatements := nil;
end;

destructor TExpressionTree.Destroy;
begin
  FStatements := nil;
  inherited Destroy;
end;

function TExpressionTree.TokenValue(Index: Integer): ansistring;
begin
  Result := '';
  if Assigned(Expression) then
    Result := Expression.TokenValue(Index)
  else
    raise Exception.Create('No expression assigned to tree.');
end;

function TExpressionTree.TokenID(Index: Integer): Integer;
begin
  Result := -1;
  if Assigned(Expression) then
    Result := Expression.TokenID(Index)
  else
    raise Exception.Create('No expression assigned to tree.');
end;

function TExpressionTree.AddStatement: Integer;
var
  L: Integer;
begin
  Result := AllocateNode;
  L := Length(FStatements);
  SetLength(FStatements, L + 1);
  FStatements[L] := Result;
end;





procedure TokenizerTest;
var
  Exp: TExpression;
  Tree: TExpressionTree;
  S: string;
  Context: TContext;
begin
  Exp := TExpression.Create;
  try
    //Tokenizer.Tokenize('abc >= X', Exp);
    //Tokenizer.Tokenize('and', Exp);
    //Tokenizer.Tokenize('a', Exp);

    Tokenizer.Tokenize('[{ _ => + _ ( + x  y ) {} }] [ [ + 1 2 3 ][ 4 5 6 ] ]', Exp);

    // composite operation
    // [1 2 3]^[4 5 6] -> [[(1 4) (1 5) (1 6)][(2 4) (2 5) (2 6)][(3 4) (3 5) (3 6)]

    // concatenation
    // [1 2 3].[4 5 6] -> [1 2 3 4 5 6]

    // repeat + interpolation
    // [1 2 3]::[4 5 6]


    // { A as a, B as b => transform } [A B]
    // { {x x}::xs, y::ys => x x y {} }

    // evaluate will generate new tree / expression

    // reductions:
    // - multiply inputs?
    // - reduce specific dimensions ???
    // - BFS/DFS/rfold/lfold

    // reduce applied to lists ?
    // [ [ [ x y z ] [ a b c ] ] [ q w e ] ]   =>   [ [ xyz abc ] qwe ]

    // matrix inverse
    // A ^ (inv A) = Identity
    // C = A * B
    // c_ij = a_i1 * b_1j + ... + a_im * b_mj = sum (k = 1..m) a_ik * b_kj

    // [2] * [2] => [4]
    // multiply *all* values
    // A = [ [ 1 2 ]
    //       [ 3 4 ] ]
    // B = [ [ 5 6 ]
    //       [ 7 8 ] ]
    // C = [ [ (1 * 5) + (2 * 7)   (3 * 5) + (4 * 7) ]
    //       [ (1 * 6) + (1 * 8)   (3 * 7) + (3 * 8) ] ]
    //
    // { a in A, b in B => (* a b) ... }
    //
    // one-dimensional arrays:
    // { a, b => + (* a b) ... }
    //


    S := Exp.PrintExpression;
    WriteLn(S);
    Tree := TExpressionTree.Create;
    try
      Tree.Parse(Exp);

      Context := TContext.Create;
      Context.Tree := Tree;
      try
        WriteLn('=== PrintNodes ===');
        Tree.TraverseTree(0, 0, Context, @Tree.PrintNodes);
        WriteLn('=== Execute ===');
        PBaseNode(Tree.Node[0])^.Execute(Context);
      finally
        Context.Free;
      end;

    finally
      Tree.Free;
    end;
  finally
    Exp.Free;
  end;
end;


procedure Execute(const Source: ansistring);
begin
  Execute(Source, DefaultRunOptions);
end;

procedure Execute(const Source: ansistring; const Options: TRunOptions);
var
  P: TExecutable;
  S, Code: ansistring;
  F: TextFile;
  AssignmentSpec: ansistring;
  EvalSpec: ansistring;
  I: Integer;
  StartToken: Integer;
  ParenDepth, BracketDepth, CurlyDepth: Integer;
  InString: Boolean;
  InBacktick: Boolean;
  InApostrophe: Boolean;
  InBlockComment: Boolean;
  RuntimeContext: TContext;
  NextStmtIndex: Integer;
  LineTrim: ansistring;
  InteractivePrompt: ansistring;
  DebuggerState: TDebuggerState;
  ChunkStartLine: Integer;
  CurrentSourceLine: Integer;
  ActiveSourcePath: ansistring;

  procedure ResetBalanceState;
  begin
    Code := '';
    ParenDepth := 0;
    BracketDepth := 0;
    CurlyDepth := 0;
    InString := False;
    InBacktick := False;
    InApostrophe := False;
    InBlockComment := False;
    ChunkStartLine := 1;
    CurrentSourceLine := 0;
  end;

  procedure CompileChunk(
    const Chunk: ansistring;
    BaseLine: Integer = 1;
    const SourcePath: ansistring = ''
  );
  var
    I: Integer;
    TokenInfo: PTokenInfo;
    FirstShownToken: Boolean;
  begin
    if Trim(Chunk) = '' then
      Exit;

    if SourcePath <> '' then
      DebuggerSourcePath := SourcePath;
    StartToken := P.Expression.Size;
    P.Expression.Index := StartToken;
    Tokenizer.Tokenize(Chunk + #00, P.Expression, BaseLine - 1, 0);
    P.Tree.Parse(P.Expression);
    if Options.ShowTokens then
    begin
      FirstShownToken := True;
      for I := StartToken to P.Expression.Size - 1 do
      begin
        TokenInfo := P.Expression.Token[I];
        if Assigned(TokenInfo) and (TokenInfo^.ID <> 0) and (TokenInfo^.Index >= 0) then
        begin
          if not FirstShownToken then
            Write(' ');
          Write('[ ', P.Expression.TokenValue(I), ' @', TokenInfo^.Line, ':', TokenInfo^.Col, ' ]');
          FirstShownToken := False;
        end;
      end;
      WriteLn;
    end;
  end;

  procedure UpdateBalance(const Line: ansistring);
  var
    J: Integer;
    C, N: AnsiChar;
  begin
    J := 1;
    while J <= Length(Line) do
    begin
      C := Line[J];
      if J < Length(Line) then
        N := Line[J + 1]
      else
        N := #0;

      if InBlockComment then
      begin
        if (C = '*') and (N = '/') then
        begin
          InBlockComment := False;
          Inc(J, 2);
        end
        else
          Inc(J);
        Continue;
      end;

      if InString then
      begin
        if (C = '\') and (N <> #0) then
        begin
          Inc(J, 2);
          Continue;
        end;
        if C = '"' then
          InString := False;
        Inc(J);
        Continue;
      end;

      if InBacktick then
      begin
        if C = '`' then
          InBacktick := False;
        Inc(J);
        Continue;
      end;

      if InApostrophe then
      begin
        if C = #39 then
          InApostrophe := False;
        Inc(J);
        Continue;
      end;

      if (C = '/') and (N = '/') then
        Break;

      if (C = '/') and (N = '*') then
      begin
        InBlockComment := True;
        Inc(J, 2);
        Continue;
      end;

      case C of
        '"': InString := True;
        '`': InBacktick := True;
        #39: InApostrophe := True;
        '(' : Inc(ParenDepth);
        ')' : if ParenDepth > 0 then Dec(ParenDepth);
        '[' : Inc(BracketDepth);
        ']' : if BracketDepth > 0 then Dec(BracketDepth);
        '{' : Inc(CurlyDepth);
        '}' : if CurlyDepth > 0 then Dec(CurlyDepth);
      end;
      Inc(J);
    end;
  end;

  function IsStatementBoundary: Boolean;
  begin
    Result :=
      (ParenDepth = 0) and
      (BracketDepth = 0) and
      (CurlyDepth = 0) and
      (not InString) and
      (not InBacktick) and
      (not InApostrophe) and
      (not InBlockComment);
  end;

  function IsStdinSource(const Path: ansistring): Boolean;
  begin
    Result := (Path = '') or (Path = '-') or (Path = '/dev/stdin');
  end;

  procedure PublishIntegerRuntimeSetting(const Name: ansistring; const Value: Integer);
  var
    ValueNode: Integer;
    DebugFrame: TDebuggerFrame;
  begin
    if (Name = '') or (not Assigned(RuntimeContext)) then
      Exit;
    ValueNode := GlobalTree.AllocateNode;
    TIntegerNode.InitTreeNode(ValueNode);
    GlobalTree[ValueNode]^.Ref := GlobalTree.Expression.Append(TK_INTEGER, IntToStr(Value));
    RuntimeContext.AddVariable(Name, ValueNode);
    if DebuggerAttached then
    begin
      DebugFrame := TDebuggerFrame.Create(dfkUnknown, Name, 'runtime-setting');
      EmitDebuggerEvent(dekSettingWrite, DebugFrame, IntToStr(Value));
    end;
  end;

  procedure EmitDebuggerException(const MessageText: ansistring);
  var
    Frame: TDebuggerFrame;
  begin
    if DebuggerState = nil then
      Exit;
    if not DebuggerState.TryGetTopFrame(Frame) then
      Frame := TDebuggerFrame.Create(dfkUnknown);
    EmitDebuggerEvent(dekExceptionRaised, Frame, MessageText);
  end;

  procedure PrintDebuggerPostmortem;
  begin
    if (DebuggerState = nil) or (not Options.DebuggerPostmortem) then
      Exit;
    Write(BuildDebuggerPostmortemReport(DebuggerState));
  end;

  procedure HandleExecutionException(E: Exception);
  begin
    EmitDebuggerException(E.Message);
    WriteLn('Error: ', E.Message);
    PrintDebuggerPostmortem;
    if Options.DebuggerCLI then
      RunDebuggerCommandLoop(DebuggerState, RuntimeContext);
    if DebuggerState <> nil then
      DebuggerState.Clear;
  end;

  procedure ExecutePendingStatements;
  begin
    P.Execute(NextStmtIndex, RuntimeContext);
  end;

  procedure CompileAndRunChunk(const Chunk: ansistring);
  begin
    try
      CompileChunk(Chunk);
      ExecutePendingStatements;
    except
      on E: Exception do
        HandleExecutionException(E);
    end;
  end;

  procedure CompileSourceFile(const Path: ansistring);
  begin
    ResetBalanceState;
    ActiveSourcePath := ExpandFileName(Path);
    DebuggerSourcePath := ActiveSourcePath;
    AssignFile(F, Path);
    try
      Reset(F);
      while not EOF(F) do
      begin
        ReadLn(F, S);
        Inc(CurrentSourceLine);
        Code := Code + S + #10;
        UpdateBalance(S);
        if IsStatementBoundary then
        begin
          CompileChunk(Code, ChunkStartLine, ActiveSourcePath);
          Code := '';
          ChunkStartLine := CurrentSourceLine + 1;
        end;
      end;
      CloseFile(F);
      CompileChunk(Code, ChunkStartLine, ActiveSourcePath);
    except
      on E: EInOutError do
        WriteLn('File handling error occurred. Details: ', E.Message);
    end;
  end;
begin
  P := TExecutable.Create;
  GlobalExecutable := P;
  RuntimeContext := TContext.Create;
  DebuggerState := nil;
  ClearStatementDebuggerSourcePaths;
  try
    try
      if Options.DebuggerEnabled then
      begin
        DebuggerState := TDebuggerState.Create;
        DebuggerState.RecentEventLimit := 512;
        for I := 0 to High(Options.DebuggerBreakpoints) do
          DebuggerState.AddBreakpoint(Options.DebuggerBreakpoints[I]);
        SetDebuggerSink(DebuggerState);
        ConfigureDebuggerRuntime(DebuggerState, Options.DebuggerCLI);
      end;
      P.RunOptions := Options;
      RuntimeContext.EventLogLevel := Options.EventLogLevel;
      RuntimeContext.EventLogStdout := Options.EventLogStdout;
      RuntimeContext.EventLogFormat := Options.EventLogFormat;
      nodes.InferenceCongruenceBudget := Options.InferenceCongruenceBudget;
      nodes.InferenceBeamWidth := Options.InferenceBeamWidth;
      nodes.HeadInvocationDispatchEnabled := Options.HeadDispatch;
      matcher_ir.MatcherBacktrackingEnabled := Options.Backtracking;
      if Options.InferenceCongruenceBudgetExplicit then
        PublishIntegerRuntimeSetting('mantra.inference.budget', Options.InferenceCongruenceBudget);
      if Options.InferenceBeamWidthExplicit then
        PublishIntegerRuntimeSetting('mantra.inference.beam', Options.InferenceBeamWidth);
      SetModulePackageRoots(Options.PackageRoots);
      ResetModuleLoaderState(Source);
      NextStmtIndex := 0;
      ResetBalanceState;
      if not IsStdinSource(Source) then
        DebuggerSourcePath := ExpandFileName(Source)
      else
        DebuggerSourcePath := '';

      for I := 0 to High(Options.SetAssignments) do
      begin
        AssignmentSpec := Trim(Options.SetAssignments[I]);
        if AssignmentSpec <> '' then
        begin
          if Options.Interactive then
            CompileAndRunChunk('. ' + AssignmentSpec)
          else
            CompileChunk('. ' + AssignmentSpec);
        end;
      end;

      if not IsStdinSource(Source) then
      begin
        if Options.Interactive then
        begin
          CompileSourceFile(Source);
          ExecutePendingStatements;
        end
        else
          CompileSourceFile(Source);
      end
      else if not Options.Interactive then
        CompileSourceFile('/dev/stdin');

      for I := 0 to High(Options.EvalExpressions) do
      begin
        EvalSpec := Trim(Options.EvalExpressions[I]);
        if EvalSpec <> '' then
        begin
          if Options.Interactive then
            CompileAndRunChunk('print { ' + EvalSpec + ' }')
          else
            CompileChunk('print { ' + EvalSpec + ' }');
        end;
      end;

      if not Options.Interactive then
      begin
        ExecutePendingStatements;
        Exit;
      end;

      ResetBalanceState;
      while True do
      begin
        if IsStatementBoundary then
          InteractivePrompt := 'mantra> '
        else
          InteractivePrompt := '...> ';

        if not ReadInteractiveLine(InteractivePrompt, S) then
          Break;

        LineTrim := Trim(S);
        if IsStatementBoundary then
        begin
          if (LineTrim = ':quit') or (LineTrim = '.quit') or
             (LineTrim = ':exit') or (LineTrim = '.exit') then
            Break;
          if (LineTrim = ':help') or (LineTrim = '.help') then
          begin
            WriteLn('REPL commands: :help, :quit');
            Continue;
          end;
        end;

        Code := Code + S + #10;
        UpdateBalance(S);
        if IsStatementBoundary then
        begin
          CompileAndRunChunk(Code);
          Code := '';
        end;
      end;
      if Trim(Code) <> '' then
        CompileAndRunChunk(Code);
    except
      on E: Exception do
        HandleExecutionException(E);
    end;
  finally
    ClearDebuggerSink;
    ClearDebuggerRuntime;
    DebuggerState.Free;
    RuntimeContext.Free;
    P.Free;
  end;
end;

procedure AppendSourceChunk(
  const Chunk: ansistring;
  const SourcePath: ansistring;
  BaseLine: Integer
);
begin
  if Trim(Chunk) = '' then
    Exit;
  if (not Assigned(GlobalTree)) or (not Assigned(GlobalTree.Expression)) then
    Exit;

  if SourcePath <> '' then
    DebuggerSourcePath := SourcePath;
  GlobalTree.Expression.Index := GlobalTree.Expression.Size;
  Tokenizer.Tokenize(Chunk + #00, GlobalTree.Expression, BaseLine - 1, 0);
  GlobalTree.Parse(GlobalTree.Expression);
end;

procedure AppendSourceChunk(const Chunk: ansistring);
begin
  AppendSourceChunk(Chunk, '', 1);
end;




initialization
  //DecimalSeparator := '.';
  DefaultFormatSettings.DecimalSeparator := '.';

  Tokenizer := TExpressionTokenizer.Create;
  //TokenizerTest;
  //CompileTest;


finalization
  Tokenizer.Free;
  Tokenizer := nil;

end.
