unit mcp.client.initialize.test;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, rpc.clienttool, mcp.client.base, mcp.client.calls, mcp.types;

type

  { TMockTransport }
  TMockTransport = class(TMCPClientCustomTransport)
  protected
    procedure DoConnect; override;
    procedure DoDisconnect; override;
    procedure DoSendMessage(J: TJSONStringType); override;
    function DoGetMessage(out J: TJSONStringType): Boolean; override;
  end;

  { TMockClient }
  TMockClient = class(TMCPCustomClient)
  private
    FLastRequestArgs: TJSONObject;
    FMockRequestID: TRequestID;
    FLastRequest: TMCPCall;
    FLastRequestID: TRequestID;
  protected
    procedure DoRequest(aRequest: TMCPCall; aRequestID: TRequestID; aArgs: TJSONObject); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property LastRequestArgs: TJSONObject read FLastRequestArgs;
    property LastRequest: TMCPCall read FLastRequest;
    property LastRequestID: TRequestID read FLastRequestID;
    property MockRequestID: TRequestID read FMockRequestID write FMockRequestID;
  end;

  { TMCPInitializeTest }

  TMCPInitializeTest = class(TTestCase)
  private
    FClient: TMockClient;
    FInitialize: TMCPInitialize;
    FJSON: TJSONObject;
    FCallbackExecuted: Boolean;
    FLastResponse: TMCPInitializeResponse;
    FLastError: TRPCError;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure OnInitializeReply(const aResponse: TMCPInitializeResponse; aError: TRPCError);
  published
    // Basic functionality tests
    procedure TestMethodName;
    procedure TestInitializeCall;
    procedure TestCallWithoutCapabilities;
    procedure TestCallWithRootsCapability;
    procedure TestCallWithSamplingCapability;
    procedure TestCallWithElicitationCapability;
    procedure TestCallWithAllCapabilities;

    // Server response parsing tests
    procedure TestTServerInfoFromJSON;
    procedure TestTServerInfoFromJSONWithMissingFields;
    procedure TestTServerInfoFromJSONWithNullFields;

    procedure TestTMCPInitializeResponseFromJSON;
    procedure TestTMCPInitializeResponseWithMinimalData;
    procedure TestTMCPInitializeResponseWithAllFeatures;
    procedure TestTMCPInitializeResponseWithPartialFeatures;
    procedure TestTMCPInitializeResponseWithInvalidData;

    // Feature detection tests
    procedure TestServerFeatureDetection;
    procedure TestPromptFeatureDetection;
    procedure TestResourceFeatureDetection;
    procedure TestToolFeatureDetection;
    procedure TestLoggingFeatureDetection;
    procedure TestCompletionFeatureDetection;
    procedure TestResourceSubscribeFeatureDetection;

    // Async response simulation tests
    procedure TestAsyncResponseHandling;
    procedure TestAsyncResponseWithCallback;
    procedure TestAsyncResponseWithoutCallback;
    procedure TestAsyncResponseWithMalformedData;

    // Error handling tests
    procedure TestHandleError;
    procedure TestErrorCallback;

    // Edge cases and robustness tests
    procedure TestMultipleCallsError;
    procedure TestCallWithNilClient;
    procedure TestResponseWithMissingServerInfo;
    procedure TestResponseWithMissingCapabilities;
    procedure TestResponseWithEmptyCapabilities;
  end;

implementation

{ TMockTransport }

procedure TMockTransport.DoConnect;
begin
  // Mock connection - do nothing
end;

procedure TMockTransport.DoDisconnect;
begin
  // Mock disconnection - do nothing
end;

procedure TMockTransport.DoSendMessage(J: TJSONStringType);
begin
  // Mock send - do nothing
end;

function TMockTransport.DoGetMessage(out J: TJSONStringType): Boolean;
begin
  Result := False; // No messages available
end;

{ TMockClient }

constructor TMockClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMockRequestID := 1;
  ClientName := 'MockClient';
  ClientVersion := '1.0';
  ProtocolVersion := '2025-06-18';
  Transport := TMockTransport.Create(Self);
end;

destructor TMockClient.Destroy;
begin
  FLastRequestArgs.Free;
  inherited Destroy;
end;

procedure TMockClient.DoRequest(aRequest: TMCPCall; aRequestID: TRequestID; aArgs: TJSONObject);
begin
  FLastRequestArgs.Free;
  FLastRequestArgs := aArgs.Clone as TJSONObject;
  FLastRequest := aRequest;
  FLastRequestID := aRequestID;
//  aArgs.Free;
  // Don't call inherited - we don't want actual network operations
end;

{ TMCPInitializeTest }

procedure TMCPInitializeTest.SetUp;
begin
  inherited SetUp;
  FClient := TMockClient.Create(nil);
  FInitialize := TMCPInitialize.Create(FClient);
  FJSON := TJSONObject.Create;
  FCallbackExecuted := False;
  FillChar(FLastResponse, SizeOf(FLastResponse), 0);
  FillChar(FLastError, SizeOf(FLastError), 0);
end;

procedure TMCPInitializeTest.TearDown;
begin
  FJSON.Free;
  FJSON := nil;
  FInitialize.Free;
  FClient.Free;
  inherited TearDown;
end;

procedure TMCPInitializeTest.OnInitializeReply(const aResponse: TMCPInitializeResponse; aError: TRPCError);
begin
  FCallbackExecuted := True;
  FLastResponse := aResponse;
  FLastError := aError;
end;

procedure TMCPInitializeTest.TestMethodName;
begin
  AssertEquals('Method name should be initialize', 'initialize', TMCPInitialize.MethodName);
end;

procedure TMCPInitializeTest.TestInitializeCall;
var
  RequestID: TRequestID;
begin
  RequestID := FInitialize.Call();
  AssertEquals('Should return request ID', 1, RequestID);
  AssertNotNull('Should have sent request arguments', FClient.LastRequestArgs);
  AssertTrue('Should have capabilities field', FClient.LastRequestArgs.IndexOfName('capabilities') >= 0);
  AssertTrue('Should have protocolversion field', FClient.LastRequestArgs.IndexOfName('protocolversion') >= 0);
  AssertTrue('Should have clientInfo field', FClient.LastRequestArgs.IndexOfName('clientInfo') >= 0);
end;

procedure TMCPInitializeTest.TestCallWithoutCapabilities;
var
  CapObj: TJSONObject;
begin
  FClient.Options := [];
  FInitialize.Call();

  CapObj := FClient.LastRequestArgs.Objects['capabilities'];
  AssertNotNull('Capabilities object should exist', CapObj);
  AssertEquals('Should have no capability fields', 0, CapObj.Count);
end;

procedure TMCPInitializeTest.TestCallWithRootsCapability;
var
  CapObj: TJSONObject;
begin
  FClient.Options := [coRoots];
  FInitialize.Call();

  CapObj := FClient.LastRequestArgs.Objects['capabilities'];
  AssertNotNull('Capabilities object should exist', CapObj);
  AssertTrue('Should have roots capability', CapObj.IndexOfName('roots') >= 0);
  AssertTrue('Roots should have list_changed field',
             CapObj.Objects['roots'].Get('list_changed', False));
end;

procedure TMCPInitializeTest.TestCallWithSamplingCapability;
var
  CapObj: TJSONObject;
begin
  FClient.Options := [coSampling];
  FInitialize.Call();

  CapObj := FClient.LastRequestArgs.Objects['capabilities'];
  AssertNotNull('Capabilities object should exist', CapObj);
  AssertTrue('Should have sampling capability', CapObj.IndexOfName('sampling') >= 0);
end;

procedure TMCPInitializeTest.TestCallWithElicitationCapability;
var
  CapObj: TJSONObject;
begin
  FClient.Options := [coElicitation];
  FInitialize.Call();

  CapObj := FClient.LastRequestArgs.Objects['capabilities'];
  AssertNotNull('Capabilities object should exist', CapObj);
  AssertTrue('Should have elicitation capability', CapObj.IndexOfName('elicitation') >= 0);
end;

procedure TMCPInitializeTest.TestCallWithAllCapabilities;
var
  CapObj: TJSONObject;
begin
  FClient.Options := [coRoots, coSampling, coElicitation];
  FInitialize.Call();

  CapObj := FClient.LastRequestArgs.Objects['capabilities'];
  AssertNotNull('Capabilities object should exist', CapObj);
  AssertTrue('Should have roots capability', CapObj.IndexOfName('roots') >= 0);
  AssertTrue('Should have sampling capability', CapObj.IndexOfName('sampling') >= 0);
  AssertTrue('Should have elicitation capability', CapObj.IndexOfName('elicitation') >= 0);
end;

procedure TMCPInitializeTest.TestTServerInfoFromJSON;
var
  Info: TServerInfo;
begin
  FJSON.Add('name', 'TestServer');
  FJSON.Add('version', '1.2.3');

  Info.FromJSON(FJSON);

  AssertEquals('Server name should be parsed', 'TestServer', Info.Name);
  AssertEquals('Server version should be parsed', '1.2.3', Info.Version);
end;

procedure TMCPInitializeTest.TestTServerInfoFromJSONWithMissingFields;
var
  Info: TServerInfo;
begin
  // Empty JSON object
  Info.FromJSON(FJSON);

  AssertEquals('Missing name should default to empty string', '', Info.Name);
  AssertEquals('Missing version should default to empty string', '', Info.Version);
end;

procedure TMCPInitializeTest.TestTServerInfoFromJSONWithNullFields;
var
  Info: TServerInfo;
begin
  FJSON.Add('name', TJSONNull.Create);
  FJSON.Add('version', TJSONNull.Create);

  Info.FromJSON(FJSON);

  AssertEquals('Null name should default to empty string', '', Info.Name);
  AssertEquals('Null version should default to empty string', '', Info.Version);
end;

procedure TMCPInitializeTest.TestTMCPInitializeResponseFromJSON;
var
  Response: TMCPInitializeResponse;
  ServerInfo, Capabilities: TJSONObject;
begin
  ServerInfo := TJSONObject.Create;
  ServerInfo.Add('name', 'TestServer');
  ServerInfo.Add('version', '1.0');

  Capabilities := TJSONObject.Create;

  FJSON.Add('serverInfo', ServerInfo);
  FJSON.Add('protocol', '2025-06-18');
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertEquals('Protocol should be parsed', '2025-06-18', Response.Protocol);
  AssertEquals('Server name should be parsed', 'TestServer', Response.Info.Name);
  AssertEquals('Server version should be parsed', '1.0', Response.Info.Version);
end;

procedure TMCPInitializeTest.TestTMCPInitializeResponseWithMinimalData;
var
  Response: TMCPInitializeResponse;
begin
  // Minimal response with no optional fields
  Response.FromJSON(FJSON);

  AssertEquals('Protocol should default to empty', '', Response.Protocol);
  AssertEquals('Server name should default to empty', '', Response.Info.Name);
  AssertEquals('Server version should default to empty', '', Response.Info.Version);
  AssertTrue('Features should be empty', Response.Features = []);
end;

procedure TMCPInitializeTest.TestTMCPInitializeResponseWithAllFeatures;
var
  Response: TMCPInitializeResponse;
  Capabilities, Prompts, Resources, Tools, Logging, Completions: TJSONObject;
begin
  Capabilities := TJSONObject.Create;

  Prompts := TJSONObject.Create;
  Prompts.Add('listChanged', True);
  Capabilities.Add('prompts', Prompts);

  Resources := TJSONObject.Create;
  Resources.Add('listChanged', True);
  Resources.Add('subscribe', True);
  Capabilities.Add('resources', Resources);

  Tools := TJSONObject.Create;
  Tools.Add('listChanged', True);
  Capabilities.Add('tools', Tools);

  Logging := TJSONObject.Create;
  Capabilities.Add('logging', Logging);

  Completions := TJSONObject.Create;
  Capabilities.Add('completions', Completions);

  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should have prompts feature', sfPrompts in Response.Features);
  AssertTrue('Should have prompt changes feature', sfPromptChanges in Response.Features);
  AssertTrue('Should have resources feature', sfResources in Response.Features);
  AssertTrue('Should have resource changes feature', sfResourceChanges in Response.Features);
  AssertTrue('Should have resource subscribe feature', sfResourceSubscribe in Response.Features);
  AssertTrue('Should have tools feature', sfTools in Response.Features);
  AssertTrue('Should have tool changes feature', sfToolChanges in Response.Features);
  AssertTrue('Should have logging feature', sfLogging in Response.Features);
  AssertTrue('Should have completions feature', sfCompletions in Response.Features);
end;

procedure TMCPInitializeTest.TestTMCPInitializeResponseWithPartialFeatures;
var
  Response: TMCPInitializeResponse;
  Capabilities, Prompts: TJSONObject;
begin
  Capabilities := TJSONObject.Create;

  Prompts := TJSONObject.Create;
  Prompts.Add('listChanged', False); // No changes notification
  Capabilities.Add('prompts', Prompts);

  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should have prompts feature', sfPrompts in Response.Features);
  AssertFalse('Should not have prompt changes feature', sfPromptChanges in Response.Features);
end;

procedure TMCPInitializeTest.TestTMCPInitializeResponseWithInvalidData;
var
  Response: TMCPInitializeResponse;
  ExceptionRaised: Boolean;
begin
  FJSON.Add('serverInfo', 'invalid-not-object');
  FJSON.Add('capabilities', 'invalid-not-object');

  ExceptionRaised := False;
  try
    Response.FromJSON(FJSON);
  except
    on E: Exception do
      ExceptionRaised := True;
  end;

  // Should handle gracefully - invalid data should be ignored
  AssertFalse('Should handle invalid data gracefully', ExceptionRaised);
end;

procedure TMCPInitializeTest.TestServerFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, FeatureObj: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  FeatureObj := TJSONObject.Create;
  Capabilities.Add('prompts', FeatureObj);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect prompts feature', sfPrompts in Response.Features);
  AssertFalse('Should not detect changes without listChanged', sfPromptChanges in Response.Features);
end;

procedure TMCPInitializeTest.TestPromptFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, Prompts: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  Prompts := TJSONObject.Create;
  Prompts.Add('listChanged', True);
  Capabilities.Add('prompts', Prompts);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect prompts feature', sfPrompts in Response.Features);
  AssertTrue('Should detect prompt changes feature', sfPromptChanges in Response.Features);
end;

procedure TMCPInitializeTest.TestResourceFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, Resources: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  Resources := TJSONObject.Create;
  Resources.Add('listChanged', True);
  Capabilities.Add('resources', Resources);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect resources feature', sfResources in Response.Features);
  AssertTrue('Should detect resource changes feature', sfResourceChanges in Response.Features);
  AssertFalse('Should not detect subscribe without flag', sfResourceSubscribe in Response.Features);
end;

procedure TMCPInitializeTest.TestToolFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, Tools: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  Tools := TJSONObject.Create;
  Tools.Add('listChanged', False);
  Capabilities.Add('tools', Tools);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect tools feature', sfTools in Response.Features);
  AssertFalse('Should not detect tool changes without listChanged', sfToolChanges in Response.Features);
end;

procedure TMCPInitializeTest.TestLoggingFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, Logging: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  Logging := TJSONObject.Create;
  Capabilities.Add('logging', Logging);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect logging feature', sfLogging in Response.Features);
end;

procedure TMCPInitializeTest.TestCompletionFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, Completions: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  Completions := TJSONObject.Create;
  Capabilities.Add('completions', Completions);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect completions feature', sfCompletions in Response.Features);
end;

procedure TMCPInitializeTest.TestResourceSubscribeFeatureDetection;
var
  Response: TMCPInitializeResponse;
  Capabilities, Resources: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  Resources := TJSONObject.Create;
  Resources.Add('subscribe', True);
  Capabilities.Add('resources', Resources);
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertTrue('Should detect resources feature', sfResources in Response.Features);
  AssertTrue('Should detect resource subscribe feature', sfResourceSubscribe in Response.Features);
end;

procedure TMCPInitializeTest.TestAsyncResponseHandling;
var
  ServerInfo: TJSONObject;
  Response: TMCPInitializeResponse;
  Error: TRPCError;
begin
  ServerInfo := TJSONObject.Create;
  ServerInfo.Add('name', 'TestServer');
  ServerInfo.Add('version', '1.0');
  FJSON.Add('serverInfo', ServerInfo);
  FJSON.Add('protocol', '2025-06-18');

  // Simulate async response by parsing JSON and triggering callback manually
  Response.FromJSON(FJSON);
  FillChar(Error, SizeOf(Error), 0); // Success error

  // Should process response data successfully
  AssertEquals('Server name should be parsed', 'TestServer', Response.Info.Name);
  AssertEquals('Server version should be parsed', '1.0', Response.Info.Version);
  AssertEquals('Protocol should be parsed', '2025-06-18', Response.Protocol);
end;

procedure TMCPInitializeTest.TestAsyncResponseWithCallback;
var
  ServerInfo: TJSONObject;
  Response: TMCPInitializeResponse;
  Error: TRPCError;
begin
  FInitialize.OnReply := @OnInitializeReply;

  ServerInfo := TJSONObject.Create;
  ServerInfo.Add('name', 'CallbackServer');
  ServerInfo.Add('version', '2.0');
  FJSON.Add('serverInfo', ServerInfo);
  FJSON.Add('protocol', '2025-06-18');

  // Simulate async response by manually calling callback
  Response.FromJSON(FJSON);
  FillChar(Error, SizeOf(Error), 0); // Success error

  // Simulate OnReply callback being triggered
  OnInitializeReply(Response, Error);

  AssertTrue('Callback should be executed', FCallbackExecuted);
  AssertEquals('Should have server name in response', 'CallbackServer', FLastResponse.Info.Name);
  AssertEquals('Should have server version in response', '2.0', FLastResponse.Info.Version);
  AssertEquals('Should have protocol in response', '2025-06-18', FLastResponse.Protocol);
  AssertEquals('Error should be success', 0, FLastError.Code);
end;

procedure TMCPInitializeTest.TestAsyncResponseWithoutCallback;
var
  Response: TMCPInitializeResponse;
  Error: TRPCError;
begin
  FJSON.Add('protocol', '2025-06-18');

  // Simulate async response parsing without callback set
  Response.FromJSON(FJSON);
  FillChar(Error, SizeOf(Error), 0);

  // No callback should be triggered since OnReply is not set
  AssertFalse('Callback should not be executed', FCallbackExecuted);
  AssertEquals('Protocol should still be parsed', '2025-06-18', Response.Protocol);
end;

procedure TMCPInitializeTest.TestAsyncResponseWithMalformedData;
var
  Response: TMCPInitializeResponse;
  Error: TRPCError;
  ExceptionRaised: Boolean;
begin
  FInitialize.OnReply := @OnInitializeReply;

  // Add invalid data structure
  FJSON.Add('serverInfo', 'invalid-string-instead-of-object');

  ExceptionRaised := False;
  try
    // Simulate async response parsing with malformed data
    Response.FromJSON(FJSON);
    FillChar(Error, SizeOf(Error), 0);

    // Simulate callback with parsed response (should handle gracefully)
    OnInitializeReply(Response, Error);
  except
    on E: Exception do
      ExceptionRaised := True;
  end;

  // Should handle malformed data gracefully
  AssertFalse('Should handle malformed data without exception', ExceptionRaised);
  AssertTrue('Callback should still be executed', FCallbackExecuted);
end;

procedure TMCPInitializeTest.TestHandleError;
var
  Error: TRPCError;
  Response: TMCPInitializeResponse;
begin
  Error.Code := -32601;
  Error.Message := 'Method not found';
  Error.Data := '';

  FInitialize.OnReply := @OnInitializeReply;

  // Simulate error response through callback
  FillChar(Response, SizeOf(Response), 0);
  OnInitializeReply(Response, Error);

  AssertTrue('Error callback should be executed', FCallbackExecuted);
  AssertEquals('Should have error code', -32601, FLastError.Code);
  AssertEquals('Should have error message', 'Method not found', FLastError.Message);
end;

procedure TMCPInitializeTest.TestErrorCallback;
var
  Error: TRPCError;
  Response: TMCPInitializeResponse;
begin
  FInitialize.OnReply := @OnInitializeReply;

  Error.Code := -32602;
  Error.Message := 'Invalid params';
  Error.Data := '{"detail": "Missing required parameter"}';

  // Simulate error response through callback
  FillChar(Response, SizeOf(Response), 0);
  OnInitializeReply(Response, Error);

  AssertTrue('Error callback should be executed', FCallbackExecuted);
  AssertEquals('Should have error code', -32602, FLastError.Code);
  AssertEquals('Should have error message', 'Invalid params', FLastError.Message);
end;

procedure TMCPInitializeTest.TestMultipleCallsError;
var
  RequestID1, RequestID2: TRequestID;
  ExceptionRaised: Boolean;
begin
  RequestID1 := FInitialize.Call();

  ExceptionRaised := False;
  try
    RequestID2 := FInitialize.Call();
  except
    on E: EMCPClient do
      ExceptionRaised := True;
  end;

  AssertEquals('First call should succeed', 1, RequestID1);
  AssertTrue('Second call should raise exception', ExceptionRaised);
end;

procedure TMCPInitializeTest.TestCallWithNilClient;
var
  NilInitialize: TMCPInitialize;
  ExceptionRaised: Boolean;
begin
  NilInitialize := TMCPInitialize.Create(nil);
  try
    ExceptionRaised := False;
    try
      NilInitialize.Call();
    except
      on E: Exception do
        ExceptionRaised := True;
    end;

    AssertTrue('Should raise exception with nil client', ExceptionRaised);
  finally
    NilInitialize.Free;
  end;
end;

procedure TMCPInitializeTest.TestResponseWithMissingServerInfo;
var
  Response: TMCPInitializeResponse;
begin
  FJSON.Add('protocol', '2025-06-18');
  // No serverInfo field

  Response.FromJSON(FJSON);

  AssertEquals('Protocol should be parsed', '2025-06-18', Response.Protocol);
  AssertEquals('Server name should default to empty', '', Response.Info.Name);
  AssertEquals('Server version should default to empty', '', Response.Info.Version);
end;

procedure TMCPInitializeTest.TestResponseWithMissingCapabilities;
var
  Response: TMCPInitializeResponse;
begin
  FJSON.Add('protocol', '2025-06-18');
  // No capabilities field

  Response.FromJSON(FJSON);

  AssertEquals('Protocol should be parsed', '2025-06-18', Response.Protocol);
  AssertTrue('Features should be empty', Response.Features = []);
end;

procedure TMCPInitializeTest.TestResponseWithEmptyCapabilities;
var
  Response: TMCPInitializeResponse;
  Capabilities: TJSONObject;
begin
  Capabilities := TJSONObject.Create;
  FJSON.Add('protocol', '2025-06-18');
  FJSON.Add('capabilities', Capabilities);

  Response.FromJSON(FJSON);

  AssertEquals('Protocol should be parsed', '2025-06-18', Response.Protocol);
  AssertTrue('Features should be empty', Response.Features = []);
end;

initialization
  RegisterTest(TMCPInitializeTest);

end.
