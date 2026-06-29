program mantra_server;

{$I mantra.inc}

uses
  SysUtils, Classes, Contnrs, fpjson, jsonparser, mathparser, mantra_session,
  runtime_output;

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

procedure AddRequestId(Response: TJSONObject; Request: TJSONObject);
var
  IdData: TJSONData;
begin
  if not Assigned(Response) then
    Exit;
  if Assigned(Request) then
  begin
    IdData := Request.Find('id');
    if Assigned(IdData) then
    begin
      Response.Add('id', IdData.Clone);
      Exit;
    end;
  end;
  Response.Add('id', '');
end;

function ResultToJson(Request: TJSONObject; CallResult: TMantraResult): TJSONObject;
var
  ResultObj: TJSONObject;
  ErrorObj: TJSONObject;
begin
  ResultToJson := TJSONObject.Create;
  AddRequestId(ResultToJson, Request);
  ResultToJson.Add('ok', Assigned(CallResult) and CallResult.Ok);

  if Assigned(CallResult) and CallResult.Ok then
  begin
    ResultObj := TJSONObject.Create;
    ResultObj.Add('text', CallResult.Text);
    ResultObj.Add('kind', CallResult.Kind);
    ResultObj.Add('format', CallResult.FormatName);
    ResultObj.Add('items', StringListJsonArray(CallResult.Items));
    ResultObj.Add('events', StringListJsonArray(CallResult.Events));
    ResultObj.Add('outputs', RichOutputsJsonArray(CallResult.Outputs));
    ResultToJson.Add('result', ResultObj);
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
    ResultToJson.Add('error', ErrorObj);
  end;
end;

function ErrorToJson(
  Request: TJSONObject;
  const Code: ansistring;
  const MessageText: ansistring
): TJSONObject;
var
  ErrorObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  AddRequestId(Result, Request);
  Result.Add('ok', False);
  ErrorObj := TJSONObject.Create;
  ErrorObj.Add('code', Code);
  ErrorObj.Add('message', MessageText);
  Result.Add('error', ErrorObj);
end;

function DispatchRequest(
  Session: TMantraSession;
  Request: TJSONObject;
  out Shutdown: Boolean
): TMantraResult;
var
  MethodName: ansistring;
  ParamsData: TJSONData;
  Params: TJSONObject;
begin
  Result := nil;
  Shutdown := False;
  MethodName := JsonString(Request, 'method', '');
  Params := nil;
  ParamsData := Request.Find('params');
  if Assigned(ParamsData) and (ParamsData is TJSONObject) then
    Params := TJSONObject(ParamsData);

  if MethodName = 'exec' then
    Exit(Session.Exec(JsonString(Params, 'code', '')))
  else if MethodName = 'eval' then
    Exit(Session.Eval(JsonString(Params, 'expr', '')))
  else if (MethodName = 'get') or (MethodName = 'query') then
    Exit(Session.GetValue(JsonString(Params, 'path', '')))
  else if MethodName = 'query_children' then
    Exit(Session.QueryChildren(JsonString(Params, 'prefix', '')))
  else if MethodName = 'scan' then
    Exit(Session.Scan(JsonString(Params, 'pattern', '')))
  else if MethodName = 'render' then
    Exit(Session.Render(
      JsonString(Params, 'format', ''),
      JsonString(Params, 'profile', ''),
      JsonString(Params, 'subject', '')
    ))
  else if MethodName = 'events' then
    Exit(Session.Events(JsonBoolean(Params, 'clear', False)))
  else if MethodName = 'session.reset' then
  begin
    Session.Reset;
    Result := TMantraResult.Create;
    Result.Kind := 'status';
    Result.FormatName := 'text';
    Result.Text := 'reset';
    Exit;
  end
  else if MethodName = 'shutdown' then
  begin
    Shutdown := True;
    Result := TMantraResult.Create;
    Result.Kind := 'status';
    Result.FormatName := 'text';
    Result.Text := 'shutdown';
    Exit;
  end;

  Result := TMantraResult.Create;
  Result.Ok := False;
  Result.ErrorCode := 'method_not_found';
  Result.ErrorMessage := 'unknown method: ' + MethodName;
end;

procedure RunServer;
var
  Options: TRunOptions;
  Session: TMantraSession;
  Line: ansistring;
  Data: TJSONData;
  Request: TJSONObject;
  Response: TJSONObject;
  CallResult: TMantraResult;
  Shutdown: Boolean;
begin
  Options := DefaultRunOptions;
  Options.EventLogStdout := False;
  Options.DebuggerEnabled := False;
  Options.DebuggerCLI := False;
  Options.DebuggerPostmortem := False;

  Session := TMantraSession.Create(Options);
  try
    while not EOF(Input) do
    begin
      ReadLn(Line);
      if Trim(Line) = '' then
        Continue;

      Data := nil;
      Request := nil;
      Response := nil;
      CallResult := nil;
      Shutdown := False;
      try
        try
          Data := GetJSON(Line);
          if not (Data is TJSONObject) then
          begin
            Response := ErrorToJson(nil, 'invalid_request', 'request must be a JSON object');
          end
          else
          begin
            Request := TJSONObject(Data);
            CallResult := DispatchRequest(Session, Request, Shutdown);
            Response := ResultToJson(Request, CallResult);
          end;
        except
          on E: Exception do
            Response := ErrorToJson(Request, 'parse_error', E.Message);
        end;

        WriteLn(Response.AsJSON);
        Flush(Output);
      finally
        CallResult.Free;
        Response.Free;
        Data.Free;
      end;

      if Shutdown then
        Break;
    end;
  finally
    Session.Free;
  end;
end;

begin
  try
    RunServer;
  except
    on E: Exception do
    begin
      WriteLn(ErrOutput, 'Error: ', E.Message);
      Halt(1);
    end;
  end;
end.
