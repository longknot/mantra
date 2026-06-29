unit mantra_session;

{$I mantra.inc}

interface

uses
  Classes, SysUtils, Contnrs, mathparser, context, parsetree, runtime_output;

type
  TMantraResult = class
  public
    Ok: Boolean;
    Text: ansistring;
    Kind: ansistring;
    FormatName: ansistring;
    ErrorCode: ansistring;
    ErrorMessage: ansistring;
    Items: TStringList;
    Events: TStringList;
    Outputs: TObjectList;
    constructor Create;
    destructor Destroy; override;
  end;

  { TMantraSession }
  TMantraSession = class
  private
    FOptions: TRunOptions;
    FExecutable: TExecutable;
    FContext: TContext;
    FNextStmtIndex: Integer;
    FCapturedOutput: TStringList;
    FActiveResult: TMantraResult;
    procedure Activate;
    procedure InitializeRuntime;
    procedure FinalizeRuntime;
    procedure ConfigureRuntime;
    procedure CompileChunk(const Code: ansistring);
    procedure CaptureOutputLine(const LineText: ansistring);
    procedure CaptureRichOutput(Output: TRuntimeRichOutput);
    procedure AddEventsSince(StartIndex: Integer; Result: TMantraResult);
    function CapturedOutputText: ansistring;
    function KindForNode(NodeIndex: Integer): ansistring;
  public
    constructor Create(const Options: TRunOptions);
    destructor Destroy; override;
    procedure Reset;
    function Exec(const Code: ansistring): TMantraResult;
    function Eval(const Expr: ansistring): TMantraResult;
    function GetValue(const Path: ansistring): TMantraResult;
    function QueryChildren(const Prefix: ansistring): TMantraResult;
    function Scan(const Pattern: ansistring): TMantraResult;
    function Render(
      const FormatName: ansistring;
      const Profile: ansistring;
      const Subject: ansistring
    ): TMantraResult;
    function Events(Clear: Boolean): TMantraResult;
  end;

implementation

uses
  Types, exp_tokenizer, exp_trees, tokens, nodes, matcher_ir, module_loader,
  fpjson;

constructor TMantraResult.Create;
begin
  inherited Create;
  Ok := True;
  Text := '';
  Kind := '';
  FormatName := '';
  ErrorCode := '';
  ErrorMessage := '';
  Items := TStringList.Create;
  Events := TStringList.Create;
  Outputs := TObjectList.Create(True);
end;

destructor TMantraResult.Destroy;
begin
  Outputs.Free;
  Events.Free;
  Items.Free;
  inherited Destroy;
end;

constructor TMantraSession.Create(const Options: TRunOptions);
begin
  inherited Create;
  FOptions := Options;
  FCapturedOutput := TStringList.Create;
  FActiveResult := nil;
  InitializeRuntime;
end;

destructor TMantraSession.Destroy;
begin
  FinalizeRuntime;
  FCapturedOutput.Free;
  inherited Destroy;
end;

procedure TMantraSession.Activate;
begin
  GlobalExecutable := FExecutable;
  GlobalTree := FExecutable.Tree;
end;

procedure TMantraSession.InitializeRuntime;
var
  AssignmentSpec: ansistring;
  I: Integer;
begin
  RegisterObjects;
  FExecutable := TExecutable.Create;
  FContext := TContext.Create;
  FContext.Tree := FExecutable.Tree;
  FNextStmtIndex := 0;
  Activate;
  ConfigureRuntime;
  SetModulePackageRoots(FOptions.PackageRoots);
  ResetModuleLoaderState('mantra-server');

  for I := 0 to High(FOptions.SetAssignments) do
  begin
    AssignmentSpec := Trim(FOptions.SetAssignments[I]);
    if AssignmentSpec <> '' then
      Exec('. ' + AssignmentSpec).Free;
  end;
end;

procedure TMantraSession.FinalizeRuntime;
begin
  if GlobalExecutable = FExecutable then
  begin
    GlobalExecutable := nil;
    GlobalTree := nil;
  end;
  if Assigned(FContext) then
    FreeAndNil(FContext);
  if Assigned(FExecutable) then
    FreeAndNil(FExecutable);
end;

procedure TMantraSession.ConfigureRuntime;
begin
  Activate;
  FExecutable.RunOptions := FOptions;
  FContext.EventLogLevel := FOptions.EventLogLevel;
  FContext.EventLogStdout := FOptions.EventLogStdout;
  FContext.EventLogFormat := FOptions.EventLogFormat;
  nodes.InferenceCongruenceBudget := FOptions.InferenceCongruenceBudget;
  nodes.InferenceBeamWidth := FOptions.InferenceBeamWidth;
  nodes.HeadInvocationDispatchEnabled := FOptions.HeadDispatch;
  matcher_ir.MatcherBacktrackingEnabled := FOptions.Backtracking;
end;

procedure TMantraSession.Reset;
begin
  FinalizeRuntime;
  InitializeRuntime;
end;

procedure TMantraSession.CompileChunk(const Code: ansistring);
begin
  if Trim(Code) = '' then
    Exit;
  Activate;
  FExecutable.Expression.Index := FExecutable.Expression.Size;
  Tokenizer.Tokenize(Code + #00, FExecutable.Expression, 0, 0);
  FExecutable.Tree.Parse(FExecutable.Expression);
end;

procedure TMantraSession.CaptureOutputLine(const LineText: ansistring);
begin
  FCapturedOutput.Add(LineText);
end;

procedure TMantraSession.CaptureRichOutput(Output: TRuntimeRichOutput);
begin
  if Assigned(FActiveResult) and Assigned(Output) then
    FActiveResult.Outputs.Add(Output)
  else
    Output.Free;
end;

function TMantraSession.CapturedOutputText: ansistring;
begin
  Result := FCapturedOutput.Text;
  while (Result <> '') and (Result[Length(Result)] in [#10, #13]) do
    Delete(Result, Length(Result), 1);
end;

procedure TMantraSession.AddEventsSince(StartIndex: Integer; Result: TMantraResult);
var
  I: Integer;
begin
  if not Assigned(FContext) or not Assigned(Result) then
    Exit;
  if StartIndex < 0 then
    StartIndex := 0;
  for I := StartIndex to FContext.EventLines.Count - 1 do
    Result.Events.Add(FContext.EventLines[I]);
end;

function TMantraSession.Exec(const Code: ansistring): TMantraResult;
var
  EventStart: Integer;
begin
  Result := TMantraResult.Create;
  Result.Kind := 'output';
  Result.FormatName := 'text';
  Activate;
  ConfigureRuntime;
  FCapturedOutput.Clear;
  EventStart := FContext.EventLines.Count;
  FActiveResult := Result;
  SetRuntimeOutputSink(@CaptureOutputLine);
  SetRuntimeRichOutputSink(@CaptureRichOutput);
  try
    try
      CompileChunk(Code);
      FExecutable.Execute(FNextStmtIndex, FContext);
      Result.Text := CapturedOutputText;
    except
      on E: Exception do
      begin
        Result.Ok := False;
        Result.ErrorCode := 'runtime_error';
        Result.ErrorMessage := E.Message;
        Result.Text := CapturedOutputText;
      end;
    end;
  finally
    ClearRuntimeRichOutputSink;
    ClearRuntimeOutputSink;
    FActiveResult := nil;
    AddEventsSince(EventStart, Result);
  end;
end;

function TMantraSession.Eval(const Expr: ansistring): TMantraResult;
begin
  Result := Exec('print { ' + Expr + ' }');
  Result.Kind := 'tree';
  Result.FormatName := 'tree';
end;

function TMantraSession.KindForNode(NodeIndex: Integer): ansistring;
begin
  Result := 'tree';
  if (NodeIndex = EOT) or (NodeIndex < 0) or (NodeIndex >= GlobalTree.Count) then
    Exit('missing');
  case GlobalTree[NodeIndex]^.Id of
    OBJ_STRING: Result := 'string';
    OBJ_INTEGER: Result := 'integer';
    OBJ_FLOAT: Result := 'float';
    OBJ_COMPLEX: Result := 'complex';
    OBJ_NULL: Result := 'null';
    OBJ_VARIABLE: Result := 'variable';
  else
    Result := 'tree';
  end;
end;

function TMantraSession.GetValue(const Path: ansistring): TMantraResult;
var
  ValueIndex: Integer;
begin
  Result := TMantraResult.Create;
  Activate;
  if FContext.TryFindVariable(Path, ValueIndex) then
  begin
    Result.Text := nodes.GetNode(ValueIndex).TreeValue;
    Result.Kind := KindForNode(ValueIndex);
    Result.FormatName := 'tree';
  end
  else
  begin
    Result.Ok := False;
    Result.ErrorCode := 'not_found';
    Result.ErrorMessage := 'path not found: ' + Path;
    Result.Kind := 'missing';
  end;
end;

function TMantraSession.QueryChildren(const Prefix: ansistring): TMantraResult;
begin
  Result := TMantraResult.Create;
  Result.Kind := 'list';
  FContext.ScanVariableChildren(Prefix, Result.Items);
  Result.Text := Result.Items.Text;
  while (Result.Text <> '') and (Result.Text[Length(Result.Text)] in [#10, #13]) do
    Delete(Result.Text, Length(Result.Text), 1);
end;

function TMantraSession.Scan(const Pattern: ansistring): TMantraResult;
begin
  Result := TMantraResult.Create;
  Result.Kind := 'list';
  FContext.ScanVariables(Pattern, Result.Items);
  Result.Text := Result.Items.Text;
  while (Result.Text <> '') and (Result.Text[Length(Result.Text)] in [#10, #13]) do
    Delete(Result.Text, Length(Result.Text), 1);
end;

function TMantraSession.Render(
  const FormatName: ansistring;
  const Profile: ansistring;
  const Subject: ansistring
): TMantraResult;
begin
  Result := Exec('print { render ' + FormatName + ' ' + Profile + ' ' + Subject + ' }');
  Result.Kind := 'string';
  Result.FormatName := FormatName;
end;

function TMantraSession.Events(Clear: Boolean): TMantraResult;
var
  I: Integer;
begin
  Result := TMantraResult.Create;
  Result.Kind := 'events';
  for I := 0 to FContext.EventLines.Count - 1 do
    Result.Events.Add(FContext.EventLines[I]);
  Result.Text := Result.Events.Text;
  while (Result.Text <> '') and (Result.Text[Length(Result.Text)] in [#10, #13]) do
    Delete(Result.Text, Length(Result.Text), 1);
  if Clear then
    FContext.ClearEvents;
end;

end.
