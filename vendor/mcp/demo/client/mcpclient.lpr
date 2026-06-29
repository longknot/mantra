program mcpclient;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  Classes, SysUtils, CustApp, fpjson, jsonscanner, jsonparser, strutils,
  mcp.client.base, mcp.client.calls, rpc.client.stdio, mcp.types, mcp.client;

type
  EMCPClientApp = class(Exception);

  { Server command handler type }
  TServerCommandHandler = procedure of object;

  { Response type enumeration }
  TResponseType = (rtNone, rtInitialize, rtToolCall, rtToolsList, rtPromptsList, rtResourcesList, rtResourceGet, rtCompletion);

  { TMCPClientOptions }

  TMCPClientOptions = record
    ConfigFile: string;
    ServerName: string;
    Command: string;
    ToolName: string;
    ParamsFile: string;
    ResourceURI: string;
    OutputFile: string;
    CompletionType: string;
    CompletionName: string;
    CompletionArg: string;
    CompletionValue: string;
    ContextFile: string;
    procedure Initialize;
  end;

  { TMCPClientApplication }

  TMCPClientApplication = class(TCustomApplication)
  private
    FOptions: TMCPClientOptions;
    FConfigData: TJSONObject;
    FClient: TMCPClient;
    FLastResponse: TResponseType;
    FToolCallResponse: TMCPToolCallResponse;
    FToolsList: TMCPToolInfoList;
    FPromptsList: TMCPPromptInfoArray;
    FResourcesList: TMCPResourceInfoArray;
    FResourceGetResponse: TMCPReadResourceResponse;
    FCompletionResponse: TMCPCompletionResponse;
    FProcessTransport: TMCPClientStdioTransport;
    FInitializeResponse: TMCPInitializeResponse;
    // Configuration management
    function GetCompletionContext(aFileName: string; out aContext: TMCPCompletionContext): Boolean;
    procedure LoadConfiguration;
    procedure OnInitialized(const aResponse: TMCPInitializeResponse; aError: TRPCError);
    // Get config for a particular server Do not free aServerconfig!
    procedure ParseServerConfig(const aServerName: string; out aServerConfig: TJSONObject);
    function ParseOptions: Boolean;
    function ValidateOptions: Boolean;

    // Client connection management
    function CreateAndConnectClient(aServerConfig: TJSONObject): Boolean;
    procedure DisconnectClient;
    procedure ExecuteWithServer(const aLogMessage: string; aHandler: TServerCommandHandler);
    function WaitForResponse(aExpectedType: TResponseType; const aTask: string): Boolean;

    // Command handlers
    procedure ExecuteCommand;
    procedure HandleServersList;

    // Business logic handlers (called by ExecuteWithServer)
    procedure DoHandleToolCall;
    procedure DoHandleToolsList;
    procedure DoHandlePromptsList;
    procedure DoHandleResourcesList;
    procedure DoHandleResourceGet;
    procedure DoHandleComplete;

    // Event handlers
    procedure OnToolCallReply(aResponse: TMCPToolCallResponse; aError: TRPCError);
    procedure OnToolsListReply(aSender: TObject; var aList: TMCPToolInfoList; const aError: TRPCError);
    procedure OnPromptsListReply(aSender: TObject; aList: TMCPPromptInfoArray; const aError: TRPCError);
    procedure OnResourcesListReply(aSender: TObject; aList: TMCPResourceInfoArray; const aError: TRPCError);
    procedure OnResourceGetReply(aInfo: TMCPReadResourceResponse; const aError: TRPCError);
    procedure OnCompletionReply(aResponse: TMCPCompletionResponse; const aError: TRPCError);

    // Utility methods
    procedure Usage(const aErr: string);
    procedure LogInfo(const aMsg: string);
    procedure LogError(const aMsg: string);
    function JSONArrayToStringList(aArray: TJSONArray): TStrings;
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Application: TMCPClientApplication;

{ TMCPClientOptions }

procedure TMCPClientOptions.Initialize;
var
  HomeDir: string;
begin
  // Set default config file path
  HomeDir := GetEnvironmentVariable('HOME');
  if HomeDir = '' then
    HomeDir := GetEnvironmentVariable('USERPROFILE');

  if HomeDir <> '' then
    ConfigFile := IncludeTrailingPathDelimiter(HomeDir) + '.config/claude/settings.json'
  else
    ConfigFile := 'settings.json';

  ServerName := '';
  Command := '';
  ToolName := '';
  ParamsFile := '';
  ResourceURI := '';
  OutputFile := '';
  CompletionType := '';
  CompletionName := '';
  CompletionArg := '';
  CompletionValue := '';
  ContextFile := '';
end;

{ TMCPClientApplication }

constructor TMCPClientApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FOptions.Initialize;
  FConfigData := nil;
  FClient := nil;
  FLastResponse := rtNone;
  FToolsList := nil;
  FPromptsList := nil;
  FResourcesList := nil;
end;

destructor TMCPClientApplication.Destroy;
begin
  DisconnectClient;
  FreeAndNil(FConfigData);
  FreeAndNil(FToolsList);
  FreeAndNil(FPromptsList);
  FreeAndNil(FResourcesList);
  FreeAndNil(FProcessTransport);
  FToolCallResponse.Clear; // Clean up tool call response
  inherited Destroy;
end;


procedure TMCPClientApplication.LogInfo(const aMsg: string);
begin
  WriteLn('[INFO] ', aMsg);
end;

procedure TMCPClientApplication.LogError(const aMsg: string);
begin
  WriteLn(StdErr, '[ERROR] ', aMsg);
end;

function TMCPClientApplication.JSONArrayToStringList(aArray: TJSONArray): TStrings;
var
  i: Integer;
begin
  Result := TStringList.Create;
  if Assigned(aArray) then
  begin
    for i := 0 to aArray.Count - 1 do
    begin
      if aArray.Types[i] = jtString then
        Result.Add(aArray.Strings[i]);
    end;
  end;
end;

procedure TMCPClientApplication.LoadConfiguration;
var
  ConfigStream: TFileStream;
  JSONStr: string;
  Parser: TJSONParser;
begin
  if not FileExists(FOptions.ConfigFile) then
    raise EMCPClientApp.CreateFmt('Configuration file not found: %s', [FOptions.ConfigFile]);

  try
    ConfigStream := TFileStream.Create(FOptions.ConfigFile, fmOpenRead);
    try
      SetLength(JSONStr, ConfigStream.Size);
      if ConfigStream.Size > 0 then
        ConfigStream.ReadBuffer(JSONStr[1], ConfigStream.Size);
    finally
      ConfigStream.Free;
    end;

    Parser := TJSONParser.Create(JSONStr);
    try
      FConfigData := Parser.Parse as TJSONObject;
    finally
      Parser.Free;
    end;
  except
    on E: Exception do
      raise EMCPClientApp.CreateFmt('Failed to load configuration: %s', [E.Message]);
  end;
end;

procedure TMCPClientApplication.OnInitialized(const aResponse: TMCPInitializeResponse; aError: TRPCError);
begin
  FInitializeResponse:=aResponse;
  FLastResponse:=rtInitialize;
end;

procedure TMCPClientApplication.ParseServerConfig(const aServerName: string; out aServerConfig: TJSONObject);
var
  ServersObj: TJSONObject;
begin
  aServerConfig := nil;

  if not Assigned(FConfigData) then
    raise EMCPClientApp.Create('Configuration not loaded');

  ServersObj := FConfigData.Get('mcpServers', TJSONObject(nil));
  if not Assigned(ServersObj) then
    raise EMCPClientApp.Create('No mcpServers section found in configuration');

  aServerConfig := ServersObj.Get(aServerName, TJSONObject(nil));
  if not Assigned(aServerConfig) then
    raise EMCPClientApp.CreateFmt('Server "%s" not found in configuration', [aServerName]);
end;

function TMCPClientApplication.ParseOptions : Boolean;

const
  ShortOptions = 'hc:s:o:t:n:a:v:x:p:';
  LongOptions: array of string = ('help', 'config:', 'server:', 'output:', 'type:', 'name:', 'arg:', 'value:', 'context:', 'params:');

var
  Err: String;
  NonOptions: TStringList;

begin
  Result:=False;
  Err := CheckOptions(ShortOptions,LongOptions);
  if (Err <> '') or HasOption('h','help') then
    begin
    Usage(Err);
    Exit;
    end;

  // Parse options
  FOptions.ConfigFile := GetOptionValue('c', 'config');
  FOptions.ServerName := GetOptionValue('s', 'server');
  FOptions.OutputFile := GetOptionValue('o', 'output');
  FOptions.CompletionType := GetOptionValue('t', 'type');
  FOptions.CompletionName := GetOptionValue('n', 'name');
  FOptions.CompletionArg := GetOptionValue('a', 'arg');
  FOptions.CompletionValue := GetOptionValue('v', 'value');
  FOptions.ContextFile := GetOptionValue('x', 'context');
  FOptions.ParamsFile := GetOptionValue('p', 'params');

  // Get command from non-option parameters
  NonOptions := TStringList.Create;
  try
    GetNonOptions(ShortOptions, LongOptions, NonOptions);
    if NonOptions.Count = 0 then
      begin
      Usage('No command specified');
      exit;
      end;

    FOptions.Command := NonOptions[0];

    // For resources-get command, get the resource URI as second argument
    if (FOptions.Command = 'resources-get') and (NonOptions.Count > 1) then
      FOptions.ResourceURI := NonOptions[1];

    // For tool-call command, get the tool name as second argument
    if (FOptions.Command = 'tool-call') and (NonOptions.Count > 1) then
      FOptions.ToolName := NonOptions[1];
  finally
    NonOptions.Free;
  end;
  Result:=True;
end;

function TMCPClientApplication.ValidateOptions: Boolean;

const
  ServerCmds : array of string = ('tool-call','tools-list','prompts-list', 'resources-list', 'resources-get','complete');
  AllCmds : array of string = ('servers-list','tool-call','tools-list','prompts-list', 'resources-list', 'resources-get','complete');
begin
  Result := False;

  if IndexStr(FOptions.Command,AllCmds)=-1 then
    begin
    Usage('Unknown command: ' + FOptions.Command);
    Exit;
    end;

  if IndexStr(FOptions.Command,ServerCmds)=-1 then
     begin
     Result := True;  // Non-server commands like servers-list are valid
     exit;
     end;

  if FOptions.ServerName = '' then
    begin
    Usage('Server name is required for command: '+FOptions.Command);
    Exit;
    end;

  if FOptions.Command = 'resources-get' then
    begin
    if FOptions.ResourceURI = '' then
      begin
      Usage('Resource URI must be provided as first argument');
      Exit;
      end;

    if FOptions.OutputFile = '' then
      begin
      Usage('Missing -o/--output option');
      Exit;
      end;
    end;

  if FOptions.Command = 'complete' then
    begin
    if FOptions.CompletionType = '' then
      begin
      Usage('Missing -t/--type option (prompt or resource)');
      Exit;
      end;
    if FOptions.CompletionName = '' then
      begin
      Usage('Missing -n/--name option');
      Exit;
      end;
    if FOptions.CompletionArg = '' then
      begin
      Usage('Missing -a/--arg option');
      Result := False;
      Exit;
      end;
    if FOptions.CompletionValue = '' then
      begin
      Usage('Missing -v/--value option');
      Exit;
      end;
    if not ((FOptions.CompletionType = 'prompt') or (FOptions.CompletionType = 'resource')) then
      begin
      Usage('Invalid -t/--type value');
      Exit;
      end;
    end;

  // Check specific requirements for tool-call command
  if FOptions.Command = 'tool-call' then
    begin
    if FOptions.ToolName = '' then
      begin
      Usage('Tool name required for tool-call command as second argument');
      Exit;
      end;

    if FOptions.ParamsFile = '' then
      begin
      Usage('Missing -p/--params option');
      Exit;
      end;
    end;

  Result:=True;
end;

procedure TMCPClientApplication.ExecuteWithServer(const aLogMessage: string; aHandler: TServerCommandHandler);
var
  ServerConfig: TJSONObject;
begin
  ParseServerConfig(FOptions.ServerName, ServerConfig);
  LogInfo('Connecting to server: ' + FOptions.ServerName);

  if not CreateAndConnectClient(ServerConfig) then
    begin
    LogError('Failed to connect to server');
    ExitCode := 1;
    Exit;
    end;

  LogInfo('Initializing MCP server: '+FOptions.ServerName);
  FClient.Initialize(@OnInitialized);
  WaitForResponse(rtInitialize,'Initialization');

  try
    if aLogMessage <> '' then
      LogInfo(aLogMessage);
    aHandler(); // Execute the business logic
  finally
    DisconnectClient;
  end;
end;

function TMCPClientApplication.CreateAndConnectClient(aServerConfig: TJSONObject): Boolean;
var
  Command: string;
  Args: TJSONArray;
  ArgsList: TStrings;
begin
  Result := False;

  Command := aServerConfig.Get('command', '');
  if Command = '' then
    begin
    LogError('Server configuration missing command');
    Exit;
    end;

  Args := aServerConfig.Get('args', TJSONArray(nil));

  try
    // Create process-based transport
    FProcessTransport := TMCPClientStdioTransport.Create(nil);

    FProcessTransport.Executable := Command;
    if Assigned(Args) then
      begin
      ArgsList := JSONArrayToStringList(Args);
      try
        FProcessTransport.Arguments.Assign(ArgsList);
      finally
        ArgsList.Free;
      end;
      end;

    FClient := TMCPClient.Create(nil);
    FClient.ClientName := 'mcpclient-demo';
    FClient.ClientVersion := '1.0';
    FClient.Transport := FProcessTransport;

    // Connect
    LogInfo('Starting server process: ' + Command);
    FProcessTransport.Connect;
    Result := FProcessTransport.Connected;

    if Result then
      LogInfo('Connected to MCP server')
    else
      LogError('Failed to connect to server');

  except
    on E: Exception do
      begin
      LogError('Connection failed: ' + E.Message);
      FreeAndNil(FClient);
      end;
  end;
end;

procedure TMCPClientApplication.DisconnectClient;
begin
  if Assigned(FClient) then
    begin
    if Assigned(FClient.Transport) then
      begin
      FClient.Transport.Disconnect;
      LogInfo('Disconnected from MCP server');
      end;
    FreeAndNil(FClient);
    end;
end;

function TMCPClientApplication.WaitForResponse(aExpectedType: TResponseType; const aTask: string): Boolean;
var
  TimeoutCount: Integer;
begin
  Result := True;
  TimeoutCount := 0;
  while (FLastResponse <> aExpectedType) and (TimeoutCount < 500) do  // 5 second timeout
    begin
    FClient.CheckMessages;
    Sleep(10);
    Inc(TimeoutCount);
    end;

  if FLastResponse <> aExpectedType then
    begin
    LogError('Timeout waiting for ' + aTask + ' response');
    ExitCode := 1;
    Result := False;
    end;
end;

procedure TMCPClientApplication.HandleServersList;
var
  ServersObj: TJSONObject;
  ServerName: string;
  ServerConfig: TJSONObject;
  i: Integer;
  Command: string;
  Args: TJSONArray;
  ArgsStr: string;
  j: Integer;
begin
  LogInfo('Available MCP servers:');

  ServersObj := FConfigData.Get('mcpServers', TJSONObject(nil));
  if not Assigned(ServersObj) then
    begin
    LogInfo('  No servers configured.');
    Exit;
    end;

  for i := 0 to ServersObj.Count - 1 do
    begin
    ServerName := ServersObj.Names[i];
    ServerConfig := ServersObj.Objects[ServersObj.Names[i]];

    Command := ServerConfig.Get('command', '<no command>');
    Args := ServerConfig.Get('args', TJSONArray(nil));

    ArgsStr := '';
    if Assigned(Args) then
      for j := 0 to Args.Count - 1 do
        begin
        if j > 0 then ArgsStr := ArgsStr + ' ';
        ArgsStr := ArgsStr + Args.Strings[j];
        end;

    WriteLn(Format('  %-20s: %s %s', [ServerName, Command, ArgsStr]));
    end;
end;

procedure TMCPClientApplication.OnToolCallReply(aResponse: TMCPToolCallResponse; aError: TRPCError);
var
  i: Integer;
begin
  // Initialize and copy the response to avoid access violations after Clear
  FToolCallResponse.Initialize;
  FToolCallResponse.IsError := aResponse.IsError;

  // Copy content array
  SetLength(FToolCallResponse.Content, Length(aResponse.Content));
  for i := 0 to Length(aResponse.Content) - 1 do
    FToolCallResponse.Content[i] := aResponse.Content[i];

  // Copy meta data if present
  if Assigned(aResponse.Meta) then
    begin
    FToolCallResponse.Meta.Free;
    FToolCallResponse.Meta := aResponse.Meta.Clone as TJSONObject;
    end;

  FLastResponse := rtToolCall;
end;

procedure TMCPClientApplication.OnToolsListReply(aSender: TObject; var aList: TMCPToolInfoList; const aError: TRPCError);
begin
  FToolsList := aList;
  aList:=Nil;
  FLastResponse := rtToolsList;
end;

procedure TMCPClientApplication.OnPromptsListReply(aSender: TObject; aList: TMCPPromptInfoArray; const aError: TRPCError);
begin
  FPromptsList := aList;
  FLastResponse := rtPromptsList;
end;

procedure TMCPClientApplication.OnResourcesListReply(aSender: TObject; aList: TMCPResourceInfoArray; const aError: TRPCError);
begin
  FResourcesList := aList;
  aList:=nil;
  FLastResponse := rtResourcesList;
end;

procedure TMCPClientApplication.OnResourceGetReply(aInfo: TMCPReadResourceResponse; const aError: TRPCError);
begin
  FResourceGetResponse := aInfo;
  FLastResponse := rtResourceGet;
end;

procedure TMCPClientApplication.OnCompletionReply(aResponse: TMCPCompletionResponse; const aError: TRPCError);
begin
  FCompletionResponse := aResponse;
  FLastResponse := rtCompletion;
end;

procedure TMCPClientApplication.DoHandleToolCall;
var
  CallToolCall: TMCPToolCall;
  ParamsStream: TFileStream;
  ParamsJSON: TJSONObject;
  i: Integer;
begin
  FLastResponse := rtNone;

  // Load parameters from JSON file
  if not FileExists(FOptions.ParamsFile) then
  begin
    LogError('Parameters file not found: ' + FOptions.ParamsFile);
    ExitCode := 1;
    Exit;
  end;

  ParamsJSON := nil;
  ParamsStream := TFileStream.Create(FOptions.ParamsFile, fmOpenRead);
  try
    try
      ParamsJSON := GetJSON(ParamsStream, True) as TJSONObject;
    except
      on E: Exception do
      begin
        LogError('Failed to parse parameters file: ' + E.Message);
        ExitCode := 1;
        Exit;
      end;
    end;
  finally
    ParamsStream.Free;
  end;

  CallToolCall := TMCPToolCall.Create(FClient);
  try
    CallToolCall.OnReply := @OnToolCallReply;
    CallToolCall.Call(FOptions.ToolName, ParamsJSON);

    if not WaitForResponse(rtToolCall, 'tool call') then
      exit;

    // Display tool call results
    LogInfo(Format('Tool "%s" executed successfully:', [FOptions.ToolName]));

    // Display tool outputs
    if Length(FToolCallResponse.Content) > 0 then
    begin
      for i := 0 to Length(FToolCallResponse.Content) - 1 do
      begin
        case FToolCallResponse.Content[i].ContentType of
          ctText:
            begin
              WriteLn('Text output:');
              WriteLn(FToolCallResponse.Content[i].Content);
            end;
          ctImage:
            begin
              WriteLn('Image output:');
              WriteLn('  MIME type: ', FToolCallResponse.Content[i].MimeType);
              WriteLn('  Data: Base64 encoded content');
            end;
          ctAudio:
            begin
              WriteLn('Audio output:');
              WriteLn('  MIME type: ', FToolCallResponse.Content[i].MimeType);
              WriteLn('  Data: Base64 encoded content');
            end;
          ctResource:
            begin
              WriteLn('Resource output:');
              WriteLn('  URI: ', FToolCallResponse.Content[i].Content);
              WriteLn('  Description: ', FToolCallResponse.Content[i].Description);
              WriteLn('  MIME type: ', FToolCallResponse.Content[i].MimeType);
            end;
        end;
      end;
    end
    else
      LogInfo('Tool call completed with no output');

    // Display meta information if available
    if Assigned(FToolCallResponse.Meta) then
    begin
      WriteLn('Meta information:');
      WriteLn(FToolCallResponse.Meta.AsJSON);
    end;

  finally
    CallToolCall.Free;
    ParamsJSON.Free;
  end;
end;

procedure TMCPClientApplication.DoHandleToolsList;
var
  ListToolsCall: TMCPListTools;
  i: Integer;
  ToolInfo: TMCPToolInfo;
begin
  FLastResponse := rtNone;
  FreeAndNil(FToolsList);

  ListToolsCall := TMCPListTools.Create(FClient);
  try
    ListToolsCall.OnReply := @OnToolsListReply;
    ListToolsCall.Call();

    if not WaitForResponse(rtToolsList, 'tools list') then
      exit;

    if Assigned(FToolsList) then
      begin
      LogInfo(Format('Available tools (%d):', [FToolsList.Count]));
      for i := 0 to FToolsList.Count - 1 do
        begin
        ToolInfo := FToolsList[i];
        WriteLn(Format('  %-20s: %s', [ToolInfo.Name, ToolInfo.Description]));
        end;
      end
    else
      LogInfo('No tools available from server');

  finally
    ListToolsCall.Free;
  end;
end;

procedure TMCPClientApplication.DoHandlePromptsList;
var
  ListPromptsCall: TMCPReadPromptList;
  i: Integer;
  PromptInfo: TMCPPromptInfo;
begin
  FLastResponse := rtNone;
  FreeAndNil(FPromptsList);

  ListPromptsCall := TMCPReadPromptList.Create(FClient);
  try
    ListPromptsCall.OnReply := @OnPromptsListReply;
    ListPromptsCall.Call();

    if not WaitForResponse(rtPromptsList, 'prompts list') then
      exit;

    if Assigned(FPromptsList) then
      begin
      LogInfo(Format('Available prompts (%d):', [Length(FPromptsList)]));
      for i := 0 to Length(FPromptsList)-1 do
        begin
        PromptInfo := FPromptsList[i];
        WriteLn(Format('  %-20s: %s', [PromptInfo.Name, PromptInfo.Description]));
        end;
      end
    else
      LogInfo('No prompts available from server');
  finally
    ListPromptsCall.Free;
  end;
end;

procedure TMCPClientApplication.DoHandleResourcesList;
var
  ListResourcesCall: TMCPReadResourceList;
  i: Integer;
  ResourceInfo: TMCPResourceInfo;
begin
  FLastResponse := rtNone;
  FreeAndNil(FResourcesList);
  ListResourcesCall := TMCPReadResourceList.Create(FClient);
  try
    ListResourcesCall.OnReply := @OnResourcesListReply;
    ListResourcesCall.Call();
    if not WaitForResponse(rtResourcesList, 'resources list') then
      exit;
    if Assigned(FResourcesList) then
      begin
      LogInfo(Format('Available resources (%d):', [Length(FResourcesList)]));
      for i := 0 to Length(FResourcesList) do
        begin
        ResourceInfo := FResourcesList[i];
        WriteLn(Format('  %-20s: %s (%s)', [ResourceInfo.Name, ResourceInfo.Description, ResourceInfo.MimeType]));
        end;
      end
    else
      LogInfo('No resources available from server');
  finally
    ListResourcesCall.Free;
  end;
end;

procedure TMCPClientApplication.DoHandleResourceGet;
var
  GetResourceCall: TMCPReadResource;
  OutputFile: TFileStream;
  ContentStr: string;
  ContentBytes: TBytes;
begin
  FLastResponse := rtNone;
  OutputFile := nil;
  GetResourceCall := TMCPReadResource.Create(FClient);
  try
    GetResourceCall.OnReply := @OnResourceGetReply;
    GetResourceCall.Call(FOptions.ResourceURI);

    if Not WaitForResponse(rtResourceGet, 'resource') then
      exit;

    // Create output file
    OutputFile := TFileStream.Create(FOptions.OutputFile, fmCreate);
    try
      LogInfo('Writing resource to file: ' + FOptions.OutputFile);

      // Handle different content types from the resource
      ContentStr := FResourceGetResponse.resource.Text;
      if ContentStr <> '' then
        begin
        // Write as text
        ContentBytes := TEncoding.UTF8.GetAnsiBytes(ContentStr);
        OutputFile.WriteBuffer(ContentBytes[0], Length(ContentBytes));
        end
      else if Length(FResourceGetResponse.resource.Data) > 0 then
        begin
        // Write as binary data
        OutputFile.WriteBuffer(FResourceGetResponse.resource.Data[0], Length(FResourceGetResponse.resource.Data));
        end
      else
        begin
        LogError('Resource has no content');
        ExitCode := 1;
        Exit;
        end;

      LogInfo(Format('Resource written successfully (%d bytes)', [OutputFile.Size]));

    except
      on E: Exception do
      begin
        LogError('Failed to write resource to file: ' + E.Message);
        ExitCode := 1;
      end;
    end;

  finally
    OutputFile.Free;
    GetResourceCall.Free;
  end;
end;

Function TMCPClientApplication.GetCompletionContext(aFileName : string; out aContext : TMCPCompletionContext) : Boolean;

var
  ContextStream: TFileStream;
  lJSON : TJSONObject;

begin
  Result:=False;
  if not FileExists(aFileName) then
    begin
    LogError('Context file not found: ' + aFileName);
    ExitCode := 1;
    Exit;
    end;
  lJSON:=Nil;
  ContextStream := TFileStream.Create(FOptions.ContextFile, fmOpenRead);
  try
    try
      lJSON := GetJSON(ContextStream,True) as TJSONObject;
      aContext := CreateCompletionContext(lJSON);
      Result:=True;
    except
      on E: Exception do
        begin
        LogError('Failed to load context file: ' + E.Message);
        ExitCode := 1;
        Exit;
        end;
    end;
  finally
    ContextStream.Free;
    lJSON.Free;
  end;
end;

procedure TMCPClientApplication.DoHandleComplete;
var
  CompletionCall: TMCPCompletionComplete;
  CompletionRef: TMCPCompletionRef;
  CompletionArg: TMCPCompletionArgument;
  CompletionContext: TMCPCompletionContext;
  i: Integer;
begin
  FLastResponse := rtNone;
  CompletionContext:=Default(TMCPCompletionContext);
  CompletionCall:=nil;

  // Create completion request objects
  if FOptions.CompletionType = 'prompt' then
    CompletionRef := CreateCompletionRef(crtPrompt, FOptions.CompletionName)
  else
    CompletionRef := CreateCompletionRef(crtResource, FOptions.CompletionName);

  CompletionArg := CreateCompletionArgument(FOptions.CompletionArg, FOptions.CompletionValue);

  // Load context if provided
  if FOptions.ContextFile <> '' then
    if not GetCompletionContext(FOptions.ContextFile,CompletionContext) then exit;
  try
    CompletionCall := TMCPCompletionComplete.Create(FClient);
    CompletionCall.OnReply := @OnCompletionReply;
    CompletionCall.Call(CompletionRef, CompletionArg, CompletionContext);

    if not WaitForResponse(rtCompletion, 'completion') then
      exit;

    LogInfo(Format('Completion suggestions (%d total, showing %d):',
                   [FCompletionResponse.Completion.Total, Length(FCompletionResponse.Completion.Values)]));

    for i := 0 to Length(FCompletionResponse.Completion.Values) - 1 do
      WriteLn(Format('  %s', [FCompletionResponse.Completion.Values[i]]));
    if FCompletionResponse.Completion.HasMore then
      LogInfo('Additional completions available (truncated)');

  finally
    CompletionContext.Clear;
    CompletionCall.Free;
  end;
end;

procedure TMCPClientApplication.ExecuteCommand;
begin
  case FOptions.Command of
    'servers-list': HandleServersList;
    'tool-call': ExecuteWithServer(Format('Calling tool "%s"...', [FOptions.ToolName]), @DoHandleToolCall);
    'tools-list': ExecuteWithServer('Requesting tools list...', @DoHandleToolsList);
    'prompts-list': ExecuteWithServer('Requesting prompts list...', @DoHandlePromptsList);
    'resources-list': ExecuteWithServer('Requesting resources list...', @DoHandleResourcesList);
    'resources-get': ExecuteWithServer('Requesting resource: ' + FOptions.ResourceURI, @DoHandleResourceGet);
    'complete': ExecuteWithServer(Format('Requesting completion for %s "%s" argument "%s" with value "%s"',
                                        [FOptions.CompletionType, FOptions.CompletionName, FOptions.CompletionArg, FOptions.CompletionValue]), @DoHandleComplete);
  end;
end;

procedure TMCPClientApplication.Usage(const aErr: string);
begin
  if aErr <> '' then
    begin
    LogError(aErr);
    WriteLn;
    end;

  WriteLn('Usage: ', ExeName, ' <command> [options]');
  WriteLn;
  WriteLn('Commands:');
  WriteLn('  servers-list     List all configured MCP servers');
  WriteLn('  tool-call        Call a specific tool with JSON parameters');
  WriteLn('  tools-list       List tools available from specified server');
  WriteLn('  prompts-list     List prompts available from specified server');
  WriteLn('  resources-list   List resources available from specified server');
  WriteLn('  resources-get    Get a specific resource and save to file');
  WriteLn('  complete         Get completions for prompt or resource arguments');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -c, --config=FILE     Configuration file path (default: ~/.config/claude/settings.json)');
  WriteLn('  -s, --server=SERVER   Server name from configuration (required for server commands)');
  WriteLn('  -p, --params=FILE     Parameters JSON file for tool-call command (required for tool-call)');
  WriteLn('  -o, --output=FILE     Output file for resources-get command (required for resources-get)');
  WriteLn('  -t, --type=TYPE       Completion type for complete command (prompt or resource, required)');
  WriteLn('  -n, --name=NAME       Name of prompt or resource pattern (required for complete)');
  WriteLn('  -a, --arg=ARG         Argument name to complete (required for complete)');
  WriteLn('  -v, --value=VALUE     Value to complete (required for complete)');
  WriteLn('  -x, --context=FILE    Context JSON file (optional for complete)');
  WriteLn('  -h, --help           Show this help message');
  WriteLn;
  WriteLn('Examples:');
  WriteLn('  ', ExeName, ' servers-list');
  WriteLn('  ', ExeName, ' -s mock-server -p params.json tool-call echo');
  WriteLn('  ', ExeName, ' -s weather-service tools-list');
  WriteLn('  ', ExeName, ' -s weather-service prompts-list');
  WriteLn('  ', ExeName, ' -s filesystem resources-list');
  WriteLn('  ', ExeName, ' -s filesystem -o output.txt resources-get file:///tmp/example.txt');
  WriteLn('  ', ExeName, ' -s weather -t prompt -n summarize -a text -v "Hello w" complete');
  WriteLn('  ', ExeName, ' -s filesystem -t resource -n "file://*" -a path -v "/tmp/" complete');
  WriteLn('  ', ExeName, ' -c myconfig.json -s filesystem tools-list');

  ExitCode := Ord(aErr <> '');
end;

procedure TMCPClientApplication.DoRun;
begin
  Terminate; // So we don't run in a loop.

  // Parse command line options
  if not ParseOptions then exit;

  // Check options validity - exit immediately if invalid
  if not ValidateOptions then
    begin
    ExitCode := 1;
    Exit;
    end;

  // Load configuration for all commands except help
  try
    LoadConfiguration;
  except
    on E: EMCPClientApp do
      begin
      LogError(E.Message);
      ExitCode := 1;
      Exit;
      end;
  end;
  // Execute command
  try
    ExecuteCommand;
  except
    on E: EMCPClientApp do
      begin
      LogError(E.Message);
      ExitCode := 1;
      end;
    on E: Exception do
      begin
      LogError('Unexpected error: ' + E.Message);
      ExitCode := 1;
      end;
  end;
end;

begin
  Application := TMCPClientApplication.Create(nil);
  try
    Application.Initialize;
    Application.Run;
  finally
    Application.Free;
  end;
end.
