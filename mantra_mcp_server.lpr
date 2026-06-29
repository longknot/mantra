program mantra_mcp_server;

{$I mantra.inc}

uses
  SysUtils, Classes, Contnrs, fpjson, mathparser, mantra_session,
  runtime_output,
  mcp.application.stdio, mcp.controller, mcp.tools, mcp.types;

function JsonString(Obj: TJSONObject; const Name, DefaultValue: ansistring): ansistring;
var
  Data: TJSONData;
begin
  Result := DefaultValue;
  if not Assigned(Obj) then
    Exit;
  Data := Obj.Find(Name);
  if Assigned(Data) then
    Result := Data.AsString;
end;

function JsonBoolean(Obj: TJSONObject; const Name: ansistring; DefaultValue: Boolean): Boolean;
var
  Data: TJSONData;
begin
  Result := DefaultValue;
  if not Assigned(Obj) then
    Exit;
  Data := Obj.Find(Name);
  if Assigned(Data) then
    Result := Data.AsBoolean;
end;

function StringListJsonArray(List: TStrings): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  if not Assigned(List) then
    Exit;
  for I := 0 to List.Count - 1 do
    Result.Add(List[I]);
end;

function RichOutputsJsonArray(Outputs: TObjectList): TJSONArray;
var
  I: Integer;
  Output: TRuntimeRichOutput;
  OutputObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  if not Assigned(Outputs) then
    Exit;
  for I := 0 to Outputs.Count - 1 do
  begin
    Output := TRuntimeRichOutput(Outputs[I]);
    if not Assigned(Output) then
      Continue;
    OutputObj := TJSONObject.Create;
    OutputObj.Add('mime', Output.MimeType);
    if Output.Encoding <> '' then
      OutputObj.Add('encoding', Output.Encoding);
    if Assigned(Output.Data) then
      OutputObj.Add('data', Output.Data.Clone)
    else
      OutputObj.Add('data', TJSONNull.Create);
    if Assigned(Output.Metadata) and (Output.Metadata.Count > 0) then
      OutputObj.Add('metadata', Output.Metadata.Clone);
    Result.Add(OutputObj);
  end;
end;

function MantraResultToJSONText(CallResult: TMantraResult): ansistring;
var
  Obj: TJSONObject;
  ResultObj: TJSONObject;
  ErrorObj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('ok', Assigned(CallResult) and CallResult.Ok);
    if Assigned(CallResult) and CallResult.Ok then
    begin
      ResultObj := TJSONObject.Create;
      ResultObj.Add('text', CallResult.Text);
      ResultObj.Add('kind', CallResult.Kind);
      ResultObj.Add('format', CallResult.FormatName);
      ResultObj.Add('items', StringListJsonArray(CallResult.Items));
      ResultObj.Add('events', StringListJsonArray(CallResult.Events));
      ResultObj.Add('outputs', RichOutputsJsonArray(CallResult.Outputs));
      Obj.Add('result', ResultObj);
    end
    else
    begin
      ErrorObj := TJSONObject.Create;
      if Assigned(CallResult) then
      begin
        ErrorObj.Add('code', CallResult.ErrorCode);
        ErrorObj.Add('message', CallResult.ErrorMessage);
      end
      else
      begin
        ErrorObj.Add('code', 'internal_error');
        ErrorObj.Add('message', 'missing result');
      end;
      Obj.Add('error', ErrorObj);
    end;
    MantraResultToJSONText := Obj.AsJSON;
  finally
    Obj.Free;
  end;
end;

procedure SetSingleTextResult(const Text: ansistring; var Output: TMCPToolResultArray);
begin
  SetLength(Output, 1);
  Output[0] := TMCPToolResult.CreateText(Text);
end;

type
  { TMantraTool }

  TMantraTool = class(TMCPTool)
  private
    FSession: TMantraSession;
  protected
    function Run(aInput: TJSONObject): TMantraResult; virtual; abstract;
    procedure DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray); override;
  public
    constructor Create(
      const aName: string;
      const aDescription: string;
      ASession: TMantraSession
    ); reintroduce; virtual;
  end;

  TMantraExecTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  TMantraEvalTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  TMantraGetTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  TMantraQueryChildrenTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  TMantraScanTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  TMantraEventsTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  TMantraResetTool = class(TMantraTool)
  protected
    function Run(aInput: TJSONObject): TMantraResult; override;
  public
    constructor Create(ASession: TMantraSession); reintroduce;
  end;

  { TMantraMCPApplication }

  TMantraMCPApplication = class(TMCPStdIOApplication)
  private
    FSession: TMantraSession;
    procedure RegisterMantraTools;
  protected
    procedure DoRun; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

constructor TMantraTool.Create(
  const aName: string;
  const aDescription: string;
  ASession: TMantraSession
);
begin
  inherited Create(aName, aDescription);
  FSession := ASession;
end;

procedure TMantraTool.DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray);
var
  CallResult: TMantraResult;
begin
  CallResult := nil;
  try
    CallResult := Run(aInput);
    SetSingleTextResult(MantraResultToJSONText(CallResult), aResult);
  finally
    CallResult.Free;
  end;
end;

constructor TMantraExecTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_exec', 'Compile and execute Mantra code in the persistent session.', ASession);
  InputSchema.AddArgument('code', TJSONObject.Create(['type', 'string']), True);
end;

function TMantraExecTool.Run(aInput: TJSONObject): TMantraResult;
begin
  Result := FSession.Exec(JsonString(aInput, 'code', ''));
end;

constructor TMantraEvalTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_eval', 'Evaluate a Mantra expression in the persistent session.', ASession);
  InputSchema.AddArgument('expr', TJSONObject.Create(['type', 'string']), True);
end;

function TMantraEvalTool.Run(aInput: TJSONObject): TMantraResult;
begin
  Result := FSession.Eval(JsonString(aInput, 'expr', ''));
end;

constructor TMantraGetTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_get', 'Read a Mantra variable or trie path by exact name.', ASession);
  InputSchema.AddArgument('path', TJSONObject.Create(['type', 'string']), True);
end;

function TMantraGetTool.Run(aInput: TJSONObject): TMantraResult;
begin
  Result := FSession.GetValue(JsonString(aInput, 'path', ''));
end;

constructor TMantraQueryChildrenTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_query_children', 'List immediate Mantra trie children under a prefix.', ASession);
  InputSchema.AddArgument('prefix', TJSONObject.Create(['type', 'string']), True);
end;

function TMantraQueryChildrenTool.Run(aInput: TJSONObject): TMantraResult;
begin
  Result := FSession.QueryChildren(JsonString(aInput, 'prefix', ''));
end;

constructor TMantraScanTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_scan', 'Scan Mantra variable paths matching a pattern.', ASession);
  InputSchema.AddArgument('pattern', TJSONObject.Create(['type', 'string']), True);
end;

function TMantraScanTool.Run(aInput: TJSONObject): TMantraResult;
begin
  Result := FSession.Scan(JsonString(aInput, 'pattern', ''));
end;

constructor TMantraEventsTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_events', 'Read cumulative Mantra session events.', ASession);
  InputSchema.AddArgument('clear', TJSONObject.Create(['type', 'boolean']), False);
end;

function TMantraEventsTool.Run(aInput: TJSONObject): TMantraResult;
begin
  Result := FSession.Events(JsonBoolean(aInput, 'clear', False));
end;

constructor TMantraResetTool.Create(ASession: TMantraSession);
begin
  inherited Create('mantra_reset', 'Reset the persistent Mantra session.', ASession);
end;

function TMantraResetTool.Run(aInput: TJSONObject): TMantraResult;
begin
  FSession.Reset;
  Result := TMantraResult.Create;
  Result.Kind := 'status';
  Result.FormatName := 'text';
  Result.Text := 'reset';
end;

constructor TMantraMCPApplication.Create(AOwner: TComponent);
var
  Options: TRunOptions;
begin
  inherited Create(AOwner);
  Options := DefaultRunOptions;
  Options.EventLogStdout := False;
  Options.DebuggerEnabled := False;
  Options.DebuggerCLI := False;
  Options.DebuggerPostmortem := False;
  FSession := TMantraSession.Create(Options);
end;

destructor TMantraMCPApplication.Destroy;
begin
  FSession.Free;
  inherited Destroy;
end;

procedure TMantraMCPApplication.RegisterMantraTools;
begin
  TMantraExecTool.Create(FSession).Register;
  TMantraEvalTool.Create(FSession).Register;
  TMantraGetTool.Create(FSession).Register;
  TMantraQueryChildrenTool.Create(FSession).Register;
  TMantraScanTool.Create(FSession).Register;
  TMantraEventsTool.Create(FSession).Register;
  TMantraResetTool.Create(FSession).Register;
end;

procedure TMantraMCPApplication.DoRun;
begin
  TMCPController.Instance.ServiceName := 'mantra';
  TMCPController.Instance.ServiceVersion := '0.1';
  TMCPController.Instance.ProtocolVersion := '2025-06-18';
  TMCPController.Instance.ServiceInstructions.Text :=
    'Use the Mantra tools to execute code and inspect the persistent Mantra session.';
  RegisterMantraTools;
  inherited DoRun;
end;

var
  Application: TMantraMCPApplication;

begin
  Application := TMantraMCPApplication.Create(nil);
  try
    Application.Initialize;
    Application.Run;
  finally
    Application.Free;
  end;
end.
