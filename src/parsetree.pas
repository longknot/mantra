unit parsetree;

{$I mantra.inc}

interface

uses
  mathparser, exp_tokenizer, exp_trees, nodes, consts, tokens, context;

type
  { TExecutable }
  TExecutable = class
  private
    FExpression: TExpression;         // N: single object
    FTree: TExpressionTree;
    FRunOptions: TRunOptions;
    //FStatements: TList;               // N: each statement = a tree

    // variables stored as trees ("->" writes tree to variable list)
    //FFunctions: TList;
    //FTransforms: TList;
  public
    constructor Create;
    destructor Destroy; override;
    // procedure AddStatement(Stmt: string);
    procedure Compile(const Source: ansistring);
    procedure Execute;
    procedure Execute(var NextStmtIndex: Integer; AContext: TContext); overload;
    // procedure ExecuteLast;  // execute only the last statement (interactive)
    property Expression: TExpression read FExpression;
    property Tree: TExpressionTree read FTree;
    property RunOptions: TRunOptions read FRunOptions write FRunOptions;
  end;

  // TFormatOption = (foFormatArrays);
  // TFormatOptions = set of TFormatOption;

  // TFormatConfig = record
  //   Offset: Integer;
  //   ColumnWidth: Integer;
  //   Separator: ansistring;
  //   NewLine: Boolean;
  //   Options: TFormatOptions;
  // end;

var
  GlobalTree: TExpressionTree;
  GlobalStmt: Integer = 0;
  GlobalExecutable: TExecutable;

function TokenFromID(ID: Integer): ansistring;

implementation

uses
  math, formatters, sysutils, debugger_api, debugger_types, debugger_runtime,
  runtime_output;

function TokenFromID(ID: Integer): ansistring;
const
  OPERATORS: array [0..4] of Char = ('+', '-', '*', '/', 'i');
var
  S: PState;
  Op, I: Integer;
  SignPart: ansistring;
  MagPart: ansistring;
  ImPart: ansistring;
begin
  Result := '';
  if ID <> 0 then
  begin
    S := Tokenizer.FindState(ID);
    if Assigned(S) and (S^.Token <> '') then
      Exit(S^.Token);

    Op := (ID and TK_OPERATOR_MASK) shr 16;

    for I := Low(OPERATORS) + 1 to High(OPERATORS) do
    begin
      if (Op and (1 shl I)) <> 0 then
        Result := Result + OPERATORS[I] + ' ';
    end;
    if Result <> '' then
      Result := TrimRight(Result)
    else
      if ID and TK_PLUS <> 0 then Result := '+';

    // if Op <> 0 then
    // begin
    //   case Op of
    //     TK_PLUS: Exit('+');
    //     TK_MINUS: Exit('-');
    //     TK_MULTIPLY: Exit('*');
    //     TK_DIVIDE: Exit('/');
    //   end;

    //   // SignPart := '';
    //   // MagPart := '';
    //   // if (Op and TK_MINUS) <> 0 then
    //   //   SignPart := '-'
    //   // else if (Op and TK_PLUS) <> 0 then
    //   //   SignPart := '+';

    //   // if (Op and TK_DIVIDE) <> 0 then
    //   //   MagPart := '/'
    //   // else if (Op and TK_MULTIPLY) <> 0 then
    //   //   MagPart := '*';

    //   // if (SignPart <> '') and (MagPart <> '') then
    //   //   Result := SignPart + ' ' + MagPart
    //   // else
    //   //   Result := SignPart + MagPart;

    //   // if (Op and TK_IMAG) <> 0 then
    //   // begin
    //   //   if Result <> '' then
    //   //     Result := Result + ' ';
    //   //   Result := Result + 'i';
    //   // end;
    // end;
  end;
end;

{ TExecutable }

constructor TExecutable.Create;
begin
  FExpression := TExpression.Create;
  FTree := TExpressionTree.Create;
  FTree.Expression := FExpression;
  FTree.Size := TREE_CAPACITY;

  GlobalTree := FTree;
  //FStatements := TList.Create;
end;

destructor TExecutable.Destroy;
begin
  //FStatements.Free;
  FTree.Free;
  FExpression.Free;
  inherited Destroy;
end;


// N: permit new statements to be added / dynamic execution
procedure TExecutable.Compile(const Source: ansistring);
begin
  Expression.Index := Expression.Size;
  Tokenizer.Tokenize(Source, Expression);
  //WriteLn(Expression.PrintExpression);

  // parse statements
  Tree.Parse(Expression);
  //Expression.NextToken;
end;

procedure TExecutable.Execute;
var
  NextStmtIndex: Integer;
  Context: TContext;
begin
  Context := TContext.Create;
  try
    NextStmtIndex := 0;
    Execute(NextStmtIndex, Context);
  finally
    Context.Free;
  end;
end;

procedure TExecutable.Execute(var NextStmtIndex: Integer; AContext: TContext);
var
  Stmt: Integer;
  StmtIndex: Integer;
  QueueLen: Integer;
  StatementCountBefore, StatementCountAfter: Integer;
  AddedCount: Integer;
  ShiftIndex: Integer;
  InsertAt: Integer;
  ExecQueue: array of Integer;
  Node: TBaseNode;
  Formatter: TCustomFormatter;
  InputValue: ansistring;
  DebugValue: ansistring;
  FirstNode: Integer;
  HasOutputAtStart: Boolean;
  DebugFrame: TDebuggerFrame;
  StatementCompleted: Boolean;
  StatementToken: Integer;
  StatementTokenInfo: PTokenInfo;
  StatementSourcePath: ansistring;
  function IsOutputNode(Index: Integer): Boolean;
  begin
    Result := (Index <> EOT) and (Tree.Node[Index]^.Id in [OBJ_OUTPUT, OBJ_TREE_OUTPUT, OBJ_IR_OUTPUT]);
  end;
begin
  if not Assigned(AContext) then
    Exit;

  //softfloat_exception_flags := [];
  SetExceptionMask([
    exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision
  ]);

  ExecQueue := Tree.Statements;
  StmtIndex := NextStmtIndex;
  while StmtIndex < Length(ExecQueue) do
  begin
    Stmt := ExecQueue[StmtIndex];
    GlobalStmt := Stmt;

    // Get base node.
    Node := GetNode(Stmt); // PBaseNode(Tree[Stmt]);
    FirstNode := Node.LHS;
    HasOutputAtStart := IsOutputNode(FirstNode);

    // @todo - useful for debugging, but this computation is redundant.
    InputValue := Node.TreeValue;
    if RunOptions.ShowInput then
    begin
      EmitRuntimeOutputLine('> ' + InputValue);
    end;

    //Node^.CheckIntegrity;  // check for tree errors: LHS <> PREV, RHS <> PREV
    StatementCountBefore := Length(Tree.Statements);
    StatementCompleted := False;
    if DebuggerAttached then
    begin
      DebugFrame := TDebuggerFrame.Create(dfkStatement, '', InputValue, Stmt);
      StatementToken := Tree.Node[Stmt]^.Ref;
      StatementTokenInfo := nil;
      if (StatementToken >= 0) and (StatementToken < Tree.Expression.Size) then
        StatementTokenInfo := Tree.Expression.Token[StatementToken];
      StatementSourcePath := StatementDebuggerSourcePath(Stmt);
      if StatementSourcePath = '' then
        StatementSourcePath := CurrentDebuggerSourcePath;
      if Assigned(StatementTokenInfo) and
         ((StatementTokenInfo^.Line > 0) or (StatementTokenInfo^.Col > 0)) then
        DebugFrame.Source := TDebuggerSourceLocation.Create(
          StatementSourcePath,
          StatementTokenInfo^.Line,
          StatementTokenInfo^.Col
        )
      else if StatementSourcePath <> '' then
        DebugFrame.Source := TDebuggerSourceLocation.Create(StatementSourcePath, 0, 0);
      EmitDebuggerEvent(dekStatementEnter, DebugFrame);
      HandleDebuggerPause(AContext);
    end;
    try
      Node.Execute(AContext);
      StatementCountAfter := Length(Tree.Statements);
      StatementCompleted := True;
    finally
      if DebuggerAttached and StatementCompleted then
      begin
        EmitDebuggerEvent(dekStatementExit, DebugFrame);
        HandleDebuggerPause(AContext);
      end;
    end;

    // print/tree now own their output in node Execute; debug emits only for non-output statements.
    if RunOptions.DebugIR and (not HasOutputAtStart) then
    begin
      Formatter := TIRFormatter.Create;
      try
        DebugValue := Node.Formatted(Formatter);
        if Trim(DebugValue) <> '' then
          EmitRuntimeOutputLine(DebugValue);
      finally
        Formatter.Free;
      end;
    end
    else if RunOptions.DebugOutput and (not HasOutputAtStart) then
    begin
      if RunOptions.Raw then
        DebugValue := Node.TreeValue
      else
        DebugValue := Node.Formatted;
      if Trim(DebugValue) <> '' then
        EmitRuntimeOutputLine(DebugValue);
    end;

    if StatementCountAfter > StatementCountBefore then
    begin
      AddedCount := StatementCountAfter - StatementCountBefore;
      QueueLen := Length(ExecQueue);
      InsertAt := StmtIndex + 1;
      SetLength(ExecQueue, QueueLen + AddedCount);
      for ShiftIndex := QueueLen - 1 downto InsertAt do
        ExecQueue[ShiftIndex + AddedCount] := ExecQueue[ShiftIndex];
      for ShiftIndex := 0 to AddedCount - 1 do
        ExecQueue[InsertAt + ShiftIndex] := Tree.Statements[StatementCountBefore + ShiftIndex];
    end;

    Inc(StmtIndex);
  end;

  NextStmtIndex := StmtIndex;
end;

(*

// text <-> tokens <-> tree

function NewTree(
  const Info: TSymbolInfo;
  Prev: PExpressionTree = nil;
  Next: PExpressionTree = nil;
  Subtree: PExpressionTree = nil;
  Index: PExpressionTree = nil
): PExpressionTree;
begin
  New(Result);
  Result^.Info := Info;
  Result^.Prev := Prev;
  Result^.Next := Next;
  Result^.Subtree := Subtree;
  Result^.Index := Index;
end;

function CopyNode(Src: PExpressionTree): PExpressionTree;
begin
  New(Result);
  Result^.Info := Src^.Info;
end;

function CopyTree(Src: PExpressionTree): PExpressionTree;
begin
  if Src = nil then Exit(nil);
  Result := CopyNode(Src);
  if Src^.Info.Flags and FLAG_RECURSE = 0 then
    Result^.Next := CopyTree(Src^.Next);
  Result^.Subtree := CopyTree(Src^.Subtree);
  Result^.Index := CopyTree(Src^.Index);
end;

procedure DisposeTree(P: PExpressionTree);
begin
  if P = nil then Exit;
  if P^.Info.Flags and FLAG_RECURSE = 0 then
    DisposeTree(P^.Next);
  DisposeTree(P^.Subtree);
  DisposeTree(P^.Index);
  Dispose(P);
end;
*)


end.
