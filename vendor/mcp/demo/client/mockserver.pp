program mockserver;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson, jsonparser;

var
  HasInitialized :Boolean;

procedure SendResponse(const Response: TJSONObject);
var
  JSONStr: string;
begin
  JSONStr := Response.AsJSON;
  WriteLn(JSONStr);
  Flush(Output);
end;

procedure HandleInitialize(RequestID: Integer);
var
  Response, Result, Capabilities, Tools, ServerInfo: TJSONObject;
begin
  HasInitialized:=True;
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  Capabilities := TJSONObject.Create;
  Tools := TJSONObject.Create;
  ServerInfo := TJSONObject.Create;
  try
    Tools.Add('listChanged', True);
    Capabilities.Add('tools', Tools);

    ServerInfo.Add('name', 'mock-server');
    ServerInfo.Add('version', '1.0.0');

    Result.Add('protocolVersion', '2025-06-18');
    Result.Add('capabilities', Capabilities);
    Result.Add('serverInfo', ServerInfo);

    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure HandleToolsList(RequestID: Integer);
var
  Response, Result, Tools, Tool1, Tool2: TJSONObject;
  ToolsArray: TJSONArray;
  Schema1, Schema2, Props1, Props2, Text1, Name2: TJSONObject;
  Required1, Required2: TJSONArray;
begin
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  ToolsArray := TJSONArray.Create;

  try
    // Tool 1: echo
    Tool1 := TJSONObject.Create;
    Schema1 := TJSONObject.Create;
    Props1 := TJSONObject.Create;
    Text1 := TJSONObject.Create;
    Required1 := TJSONArray.Create;

    Text1.Add('type', 'string');
    Text1.Add('description', 'Text to echo back');
    Props1.Add('text', Text1);
    Required1.Add('text');

    Schema1.Add('type', 'object');
    Schema1.Add('properties', Props1);
    Schema1.Add('required', Required1);

    Tool1.Add('name', 'echo');
    Tool1.Add('description', 'Echo back the input text');
    Tool1.Add('inputSchema', Schema1);
    ToolsArray.Add(Tool1);

    // Tool 2: greet
    Tool2 := TJSONObject.Create;
    Schema2 := TJSONObject.Create;
    Props2 := TJSONObject.Create;
    Name2 := TJSONObject.Create;
    Required2 := TJSONArray.Create;

    Name2.Add('type', 'string');
    Name2.Add('description', 'Name to greet');
    Props2.Add('name', Name2);
    Required2.Add('name');

    Schema2.Add('type', 'object');
    Schema2.Add('properties', Props2);
    Schema2.Add('required', Required2);

    Tool2.Add('name', 'greet');
    Tool2.Add('description', 'Greet the user with a name');
    Tool2.Add('inputSchema', Schema2);
    ToolsArray.Add(Tool2);

    Result.Add('tools', ToolsArray);
    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure HandlePromptsList(RequestID: Integer);
var
  Response, Result: TJSONObject;
  PromptsArray: TJSONArray;
  Prompt1, Prompt2: TJSONObject;
  Args1Array, Args2Array: TJSONArray;
  Arg1, Arg2, Arg3, Arg4: TJSONObject;
begin
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  PromptsArray := TJSONArray.Create;

  try
    // Prompt 1: summarize
    Prompt1 := TJSONObject.Create;
    Args1Array := TJSONArray.Create;

    Arg1 := TJSONObject.Create;
    Arg1.Add('name', 'text');
    Arg1.Add('description', 'Text to summarize');
    Arg1.Add('required', True);
    Args1Array.Add(Arg1);

    Arg2 := TJSONObject.Create;
    Arg2.Add('name', 'max_words');
    Arg2.Add('description', 'Maximum number of words in summary');
    Arg2.Add('required', False);
    Args1Array.Add(Arg2);

    Prompt1.Add('name', 'summarize');
    Prompt1.Add('description', 'Summarize the given text');
    Prompt1.Add('arguments', Args1Array);
    PromptsArray.Add(Prompt1);

    // Prompt 2: translate
    Prompt2 := TJSONObject.Create;
    Args2Array := TJSONArray.Create;

    Arg3 := TJSONObject.Create;
    Arg3.Add('name', 'text');
    Arg3.Add('description', 'Text to translate');
    Arg3.Add('required', True);
    Args2Array.Add(Arg3);

    Arg4 := TJSONObject.Create;
    Arg4.Add('name', 'target_language');
    Arg4.Add('description', 'Target language code');
    Arg4.Add('required', True);
    Args2Array.Add(Arg4);

    Prompt2.Add('name', 'translate');
    Prompt2.Add('description', 'Translate text to another language');
    Prompt2.Add('arguments', Args2Array);
    PromptsArray.Add(Prompt2);

    Result.Add('prompts', PromptsArray);
    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure HandleResourcesList(RequestID: Integer);
var
  Response, Result: TJSONObject;
  ResourcesArray: TJSONArray;
  Resource1, Resource2, Resource3: TJSONObject;
begin
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  ResourcesArray := TJSONArray.Create;

  try
    Resource1 := TJSONObject.Create;
    Resource1.Add('uri', 'file:///tmp/example.txt');
    Resource1.Add('name', 'example-file');
    Resource1.Add('description', 'Example text file');
    Resource1.Add('mimeType', 'text/plain');
    ResourcesArray.Add(Resource1);

    Resource2 := TJSONObject.Create;
    Resource2.Add('uri', 'https://api.example.com/data');
    Resource2.Add('name', 'example-api');
    Resource2.Add('description', 'Example API endpoint');
    Resource2.Add('mimeType', 'application/json');
    ResourcesArray.Add(Resource2);

    Resource3 := TJSONObject.Create;
    Resource3.Add('uri', 'file:///tmp/image.png');
    Resource3.Add('name', 'example-image');
    Resource3.Add('description', 'Example image file');
    Resource3.Add('mimeType', 'image/png');
    ResourcesArray.Add(Resource3);

    Result.Add('resources', ResourcesArray);
    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure HandleResourcesRead(RequestID: Integer; const Params: TJSONObject);
var
  Response, Result, Content: TJSONObject;
  ContentsArray: TJSONArray;
  URI: string;
begin
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  ContentsArray := TJSONArray.Create;

  try
    URI := '';
    if Assigned(Params) then
      URI := Params.Get('uri', '');

    Content := TJSONObject.Create;
    Content.Add('uri', URI);
    Content.Add('mimeType', 'text/plain');
    Content.Add('text', Format('This is the content of the resource at %s' + LineEnding +
                               'Generated by mock MCP server.' + LineEnding +
                               'Timestamp: 2025-01-01T00:00:00Z', [URI]));
    ContentsArray.Add(Content);

    Result.Add('contents', ContentsArray);
    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure HandleCompletionComplete(RequestID: Integer; const Params: TJSONObject);
var
  Response, Result, Completion: TJSONObject;
  Ref, Argument: TJSONObject;
  RefType, Name, ArgName, Value: string;
  CompletionsArray: TJSONArray;
begin
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  Completion := TJSONObject.Create;
  CompletionsArray := TJSONArray.Create;

  try
    RefType := '';
    Name := '';
    ArgName := '';
    Value := '';

    if Assigned(Params) then
    begin
      Ref := Params.Get('ref', TJSONObject(nil));
      if Assigned(Ref) then
      begin
        RefType := Ref.Get('type', '');
        Name := Ref.Get('name', '');
      end;

      Argument := Params.Get('argument', TJSONObject(nil));
      if Assigned(Argument) then
      begin
        ArgName := Argument.Get('name', '');
        Value := Argument.Get('value', '');
      end;
    end;

    // Mock completion suggestions
    if (RefType = 'ref/prompt') and (Name = 'summarize') and (ArgName = 'text') then
    begin
      CompletionsArray.Add('Hello world');
      CompletionsArray.Add('Hello weather');
      CompletionsArray.Add('Hello workshop');
    end
    else if (RefType = 'ref/resource') and (ArgName = 'path') then
    begin
      CompletionsArray.Add('/tmp/example.txt');
      CompletionsArray.Add('/tmp/data.json');
    end;

    Completion.Add('values', CompletionsArray);
    Completion.Add('total', CompletionsArray.Count);
    Completion.Add('hasMore', False);

    Result.Add('completion', Completion);
    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;


procedure SendError(RequestID: Integer; const ErrorMessage: string);

var
  Response, Error: TJSONObject;
begin
  Response := TJSONObject.Create;
  Error := TJSONObject.Create;
  try
    Error.Add('code', -32601);
    Error.Add('message', ErrorMessage);
    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('error', Error);

    SendResponse(Response);
  finally
    Response.Free;
  end;

end;

procedure HandleMethodNotFound(RequestID: Integer; const Method: string);
begin
  SendError(RequestID,Format('Method not found: %s', [Method]));
end;

procedure HandleToolsCall(RequestID: Integer; const Params: TJSONObject);
var
  Response, Result, Content: TJSONObject;
  ContentsArray: TJSONArray;
  ToolName: string;
  Arguments: TJSONObject;
  Text: string;
begin
  Response := TJSONObject.Create;
  Result := TJSONObject.Create;
  ContentsArray := TJSONArray.Create;

  try
    ToolName := '';
    if Assigned(Params) then
    begin
      ToolName := Params.Get('name', '');
      Arguments := Params.Get('arguments', TJSONObject(nil));
    end;

    Content := TJSONObject.Create;

    // Handle different tools
    if ToolName = 'echo' then
    begin
      Text := 'Echo: ';
      if Assigned(Arguments) then
        Text := Text + Arguments.Get('text', 'No text provided');

      Content.Add('type', 'text');
      Content.Add('text', Text);
    end
    else if ToolName = 'greet' then
    begin
      Text := 'Hello, ';
      if Assigned(Arguments) then
        Text := Text + Arguments.Get('name', 'World');
      Text := Text + '!';

      Content.Add('type', 'text');
      Content.Add('text', Text);
    end
    else
    begin
      Content.Add('type', 'text');
      Content.Add('text', Format('Tool "%s" executed successfully with mock response', [ToolName]));
    end;

    ContentsArray.Add(Content);
    Result.Add('content', ContentsArray);

    Response.Add('jsonrpc', '2.0');
    Response.Add('id', RequestID);
    Response.Add('result', Result);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure HandleInternalError(RequestID: Integer; const ErrorMsg: string);
var
  Response, Error: TJSONObject;
begin
  Response := TJSONObject.Create;
  Error := TJSONObject.Create;

  try
    Error.Add('code', -32603);
    Error.Add('message', Format('Internal error: %s', [ErrorMsg]));

    Response.Add('jsonrpc', '2.0');
    if RequestID <> 0 then
      Response.Add('id', RequestID)
    else
      Response.Add('id', TJSONNull.Create);

    SendResponse(Response);
  finally
    Response.Free;
  end;
end;

procedure ProcessRequest(const Line: string);
var
  Parser: TJSONParser;
  Request: TJSONObject;
  Method: string;
  RequestID: Integer;
  Params: TJSONObject;
begin
  if Trim(Line) = '' then
    Exit;

  Parser := TJSONParser.Create(Line);
  try
    try
      Request := Parser.Parse as TJSONObject;
      try
        Method := Request.Get('method', '');
        RequestID := Request.Get('id', 0);
        Params := Request.Get('params', TJSONObject(nil));

        if Method = 'initialize' then
          HandleInitialize(RequestID)
        else
          begin
          if not HasInitialized then
            SendError(RequestID,'Need initialize message first');
          if Method = 'tools/list' then
            HandleToolsList(RequestID)
          else if Method = 'prompts/list' then
            HandlePromptsList(RequestID)
          else if Method = 'resources/list' then
            HandleResourcesList(RequestID)
          else if Method = 'resources/read' then
            HandleResourcesRead(RequestID, Params)
          else if Method = 'completion/complete' then
            HandleCompletionComplete(RequestID, Params)
          else if Method = 'tools/call' then
            HandleToolsCall(RequestID, Params)
          else
            HandleMethodNotFound(RequestID, Method);
          end;

      finally
        Request.Free;
      end;
    except
      on E: Exception do
        HandleInternalError(RequestID, E.Message);
    end;
  finally
    Parser.Free;
  end;
end;

var
  Line: string;
begin
  HasInitialized:=False;
  try
    while not EOF do
    begin
      ReadLn(Line);
      ProcessRequest(Line);
    end;
  except
    on E: Exception do
      WriteLn(StdErr, 'Fatal error: ', E.Message);
  end;
end.
