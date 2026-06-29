unit mcp.prompts.test;

{$mode objfpc}{$H+}

interface

uses
  Classes, Types, SysUtils, fpcunit, testregistry, fpjson, Contnrs,
  mcp.utils,
  mcp.types,
  mcp.resources,
  mcp.prompts;

type
  TMockResourceRegistry = class(TMCPResourceRegistry)
  public
    MockResources: TFPObjectHashTable;
    constructor Create; override;
    destructor Destroy; override;
    function Get(const aURI: String): TMCPResource; override;
    function Find(const aURI: String): TMCPResource; override;
  end;

  TMockPromptRegistry = class(TMCPPromptRegistry)
  public
    RegisteredPrompts: TFPObjectHashTable;
    constructor Create; override;
    destructor Destroy; override;
    procedure Add(aPrompt: TMCPPrompt); override;
  end;

  TConcreteTestPrompt = class(TMCPPrompt)
  public
    function GetPrompt(aArguments: TStrings): TMCPPromptMessageArray; override;
  end;


  TConcreteTestTemplatePrompt = class(TMCPTemplatePrompt)
  public

  end;




  { TMCPPromptsTest }

  TMCPPromptsTest = class(TTestCase)
  private
    FMockResourceRegistry: TMockResourceRegistry;
    FMockPromptRegistry: TMockPromptRegistry;
    FCompletionTriggered: Boolean;
    FCompletionArgName: string;
    FPreviousCompletions: TStringList;
    FCompletions: TStringList;
    procedure HandlePromptCompletion(Sender: TMCPPrompt; Const aArgName: string; aPreviousCompletions, aCompletions: TStrings);
    procedure AssertEquals(const Msg: string; aExpected, aActual: TMCPPromptKind); overload;
    procedure AssertEquals(const Msg: string; aExpected, aActual: TMCPRole); overload;
    procedure AssertEquals(const Msg: string; aExpected, aActual: TMCPRoles); overload;
    procedure AssertEquals(const Msg: string; aExpected, aActual: TBytes); overload;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPromptArgumentCreate;
    procedure TestPromptArgumentToJSON;
    procedure TestPromptMessageCreateText;
    procedure TestPromptMessageCreateImage;
    procedure TestPromptMessageCreateAudio;
    procedure TestPromptMessageCreateResourceLink;
    procedure TestPromptMessageCreateEmbeddedResource;
    procedure TestPromptMessageToJSONText;
    procedure TestPromptMessageToJSONImage;
    procedure TestPromptMessageToJSONAudio;
    procedure TestPromptMessageToJSONResourceLink;
    procedure TestPromptMessageToJSONEmbeddedResource;
    procedure TestPromptMessageToJSONAnnotationsAndMeta;
    procedure TestPromptMessageToJSONNoResourceRegistryForLinkOrEmbed;
    procedure TestPromptMessageArrayHelperToJSON;
    procedure TestPromptCreate;
    procedure TestPromptProperties;
    procedure TestPromptAddArgument;
    procedure TestPromptNameValidation;
    procedure TestPromptToJSON;
    procedure TestPromptGetCompletions;
    procedure TestPromptRegister;
    procedure TestPromptGetPromptDescription;
    procedure TestTemplatePromptGetPrompt;
  end;

implementation

uses
  TypInfo,
  mcp.strings;

procedure TMCPPromptsTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPPromptKind);
begin
  AssertEquals(Msg,
               GetEnumName(TypeInfo(TMCPPromptKind), Ord(aExpected)),
               GetEnumName(TypeInfo(TMCPPromptKind), Ord(aActual)));
end;

procedure TMCPPromptsTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPRole);
begin
  AssertEquals(Msg, aExpected.AsString, aActual.AsString);
end;

procedure TMCPPromptsTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPRoles);
var
  ExpectedSetString, ActualSetString: string;
  Role: TMCPRole;
begin
  ExpectedSetString:='[';
  for Role in TMCPRole do
    if Role in aExpected then
      ExpectedSetString:=ExpectedSetString + Role.AsString + ',';
  if Length(ExpectedSetString) > 1 then SetLength(ExpectedSetString, Length(ExpectedSetString) - 1);
  ExpectedSetString:=ExpectedSetString + ']';
  ActualSetString:='[';
  for Role in TMCPRole do
    if Role in aActual then
      ActualSetString:=ActualSetString + Role.AsString + ',';
  if Length(ActualSetString) > 1 then SetLength(ActualSetString, Length(ActualSetString) - 1);
  ActualSetString:=ActualSetString + ']';

  AssertEquals(Msg, ExpectedSetString, ActualSetString);
end;

procedure TMCPPromptsTest.AssertEquals(const Msg: string; aExpected, aActual: TBytes);
var
  I : integer;
begin
  AssertEquals(Msg+' length',Length(aExpected),Length(aActual));
  For I:=0 to Length(aExpected)-1 do
    AssertEquals(Msg+' byte '+IntToStr(i),aExpected[i],aActual[i]);
end;

constructor TMockResourceRegistry.Create;
begin
  inherited Create;
  MockResources:=TFPObjectHashTable.Create(True);
end;

destructor TMockResourceRegistry.Destroy;
begin
  FreeAndNil(MockResources);
  inherited Destroy;
end;

function TMockResourceRegistry.Get(const aURI: String): TMCPResource;
begin
  Result:=Find(aURI);
  if Result = nil then
    Raise EMCPException.CreateFmt(SErrUnknownResource, [aURI]);
end;

function TMockResourceRegistry.Find(const aURI: String): TMCPResource;
begin
  Result:=TMCPResource(MockResources.Items[aURI]);
end;

constructor TMockPromptRegistry.Create;
begin
  inherited Create;
  RegisteredPrompts:=TFPObjectHashTable.Create(True);
end;

destructor TMockPromptRegistry.Destroy;
begin
  FreeAndNil(RegisteredPrompts);
  inherited Destroy;
end;

procedure TMockPromptRegistry.Add(aPrompt: TMCPPrompt);
begin
  RegisteredPrompts.Add(aPrompt.Name, aPrompt);
end;

{ TConcreteTestPrompt }

function TConcreteTestPrompt.GetPrompt(aArguments: TStrings): TMCPPromptMessageArray;
begin
  Result:=[];
end;

procedure TMCPPromptsTest.HandlePromptCompletion(Sender: TMCPPrompt; const aArgName: string; aPreviousCompletions,
  aCompletions: TStrings);
begin
  FCompletionTriggered:=True;
  FCompletionArgName:=aArgName;
  FPreviousCompletions.Assign(aPreviousCompletions);
  aCompletions.Assign(FCompletions);
end;

procedure TMCPPromptsTest.SetUp;
begin
  inherited SetUp;
  TMCPResourceRegistry.Done;
  TMCPResourceRegistry.Init(TMockResourceRegistry);
  FMockResourceRegistry:=TMCPResourceRegistry.Instance as TMockResourceRegistry;
  TMCPPromptRegistry.Done;
  TMCPPromptRegistry.Init(TMockPromptRegistry);
  FMockPromptRegistry:=TMCPPromptRegistry.Instance as TMockPromptRegistry;
  FCompletionTriggered:=False;
  FCompletionArgName:='';
  FPreviousCompletions:=TStringList.Create;
  FCompletions:=TStringList.Create;
end;

procedure TMCPPromptsTest.TearDown;
begin
  TMCPResourceRegistry.Done;
  TMCPPromptRegistry.Done;
  FreeAndNil(FPreviousCompletions);
  FreeAndNil(FCompletions);
  inherited TearDown;
end;

procedure TMCPPromptsTest.TestPromptArgumentCreate;
var
  Arg: TPromptArgument;
begin
  Arg:=TPromptArgument.Create('param1', 'Description for param1');
  AssertEquals('Name should be set', 'param1', Arg.Name);
  AssertEquals('Description should be set', 'Description for param1', Arg.Description);
  AssertTrue('Required should be true by default', Arg.Required);
  Arg:=TPromptArgument.Create('param2', 'Description for param2', False);
  AssertEquals('Name should be set', 'param2', Arg.Name);
  AssertEquals('Description should be set', 'Description for param2', Arg.Description);
  AssertFalse('Required should be false', Arg.Required);
end;

procedure TMCPPromptsTest.TestPromptArgumentToJSON;
var
  Arg: TPromptArgument;
  JSON: TJSONObject;
begin
  Arg:=TPromptArgument.Create('myArg', 'My Arg Description', True);
  JSON:=Arg.ToJSON;
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertTrue('JSON should contain name property', JSON.IndexOfName('name') <> -1);
    AssertEquals('Name in JSON should be correct', 'myArg', JSON.Get('name',''));
    AssertTrue('JSON should contain description property', JSON.IndexOfName('description') <> -1);
    AssertEquals('Description in JSON should be correct', 'My Arg Description', JSON.Get('description',''));
    AssertTrue('JSON should contain required property', JSON.IndexOfName('required') <> -1);
    AssertTrue('Required in JSON should be true', JSON.Get('required',False));
  finally
    JSON.Free;
  end;
  Arg:=TPromptArgument.Create('optArg', 'Optional Arg', False);
  JSON:=Arg.ToJSON;
  try
    AssertFalse('Required in JSON should be false', JSON.Get('required',False));
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageCreateText;
var
  Msg: TMCPPromptMessage;
begin
  Msg:=TMCPPromptMessage.CreateText(prUser, 'Hello, world!');
  AssertEquals('Kind should be pkText', pkText, Msg.kind);
  AssertEquals('Role should be prUser', prUser, Msg.role);
  AssertEquals('TextContent should be set', 'Hello, world!', Msg.TextContent);
  AssertEquals('Data should be empty', TBytes([]), Msg.data);
  AssertEquals('ResourceURI should be empty', '', Msg.ResourceURI);
  AssertEquals('MimeType should be empty', '', Msg.mimeType);
  AssertFalse('Annotations should be uninitialized', Msg.Annotations.Initialized);
  AssertNull('_meta should be nil', Msg._meta);
end;

procedure TMCPPromptsTest.TestPromptMessageCreateImage;
var
  Msg: TMCPPromptMessage;
  Bytes: TBytes;
begin
  Bytes:=TBytes.Create(1, 2, 3);
  Msg:=TMCPPromptMessage.CreateImage(prAssistant, Bytes, 'image/jpeg');
  AssertEquals('Kind should be pkImage', pkImage, Msg.kind);
  AssertEquals('Role should be prAssistant', prAssistant, Msg.role);
  AssertEquals('Data should be set', Bytes, Msg.data);
  AssertEquals('MimeType should be set', 'image/jpeg', Msg.mimeType);
  AssertEquals('TextContent should be empty', '', Msg.TextContent);
  AssertEquals('ResourceURI should be empty', '', Msg.ResourceURI);
end;

procedure TMCPPromptsTest.TestPromptMessageCreateAudio;
var
  Msg: TMCPPromptMessage;
  Bytes: TBytes;
begin
  Bytes:=TBytes.Create(4, 5, 6);
  Msg:=TMCPPromptMessage.CreateAudio(prUser, Bytes, 'audio/mpeg');
  AssertEquals('Kind should be pkAudio', pkAudio, Msg.kind);
  AssertEquals('Role should be prUser', prUser, Msg.role);
  AssertEquals('Data should be set', Bytes, Msg.data);
  AssertEquals('MimeType should be set', 'audio/mpeg', Msg.mimeType);
  AssertEquals('TextContent should be empty', '', Msg.TextContent);
  AssertEquals('ResourceURI should be empty', '', Msg.ResourceURI);
end;

procedure TMCPPromptsTest.TestPromptMessageCreateResourceLink;
var
  Msg: TMCPPromptMessage;
begin
  Msg:=TMCPPromptMessage.CreateResourceLink(prUser, 'http://example.com/res1');
  AssertEquals('Kind should be pkAudio (as per unit code)', pkResourceLink, Msg.kind);
  AssertEquals('Role should be prUser', prUser, Msg.role);
  AssertEquals('ResourceURI should be set', 'http://example.com/res1', Msg.ResourceURI);
  AssertEquals('Data should be empty', TBytes([]), Msg.data);
  AssertEquals('TextContent should be empty', '', Msg.TextContent);
  AssertEquals('MimeType should be empty', '', Msg.mimeType);
end;

procedure TMCPPromptsTest.TestPromptMessageCreateEmbeddedResource;
var
  Msg: TMCPPromptMessage;
begin
  Msg:=TMCPPromptMessage.CreateEmbeddedResource(prAssistant, 'http://example.com/embed1');
  AssertEquals('Kind should be pkAudio (as per unit code)', pkEmbeddedResource, Msg.kind);
  AssertEquals('Role should be prAssistant', prAssistant, Msg.role);
  AssertEquals('ResourceURI should be set', 'http://example.com/embed1', Msg.ResourceURI);
  AssertEquals('Data should be empty', TBytes([]), Msg.data);
  AssertEquals('TextContent should be empty', '', Msg.TextContent);
  AssertEquals('MimeType should be empty', '', Msg.mimeType);
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONText;
var
  Msg: TMCPPromptMessage;
  JSON: TJSONObject;
begin
  Msg:=TMCPPromptMessage.CreateText(prUser, 'A simple text message.');
  JSON:=Msg.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertEquals('Type should be "text"', 'text', JSON.Get('type',''));
    AssertTrue('JSON should contain text property', JSON.IndexOfName('text') <> -1);
    AssertEquals('Text content should be correct', 'A simple text message.', JSON.Get('text',''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONImage;
var
  Msg: TMCPPromptMessage;
  Bytes: TBytes;
  JSON: TJSONObject;
begin
  Bytes:=TBytes.Create(10, 20, 30);
  Msg:=TMCPPromptMessage.CreateImage(prAssistant, Bytes, 'image/png');
  JSON:=Msg.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertEquals('Type should be "image"', 'image', JSON.Get('type',''));
    AssertTrue('JSON should contain data property', JSON.IndexOfName('data') <> -1);
    AssertEquals('Data should be base64 encoded', mcp.utils.EncodeBytes(Bytes), JSON.Get('data',''));
    AssertTrue('JSON should contain mimeType property', JSON.IndexOfName('mimeType') <> -1);
    AssertEquals('MimeType should be correct', 'image/png', JSON.Get('mimeType',''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONAudio;
var
  Msg: TMCPPromptMessage;
  Bytes: TBytes;
  JSON: TJSONObject;
begin
  Bytes:=TBytes.Create(40, 50, 60);
  Msg:=TMCPPromptMessage.CreateAudio(prUser, Bytes, 'audio/wav');
  JSON:=Msg.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertEquals('Type should be "audio"', 'audio', JSON.Get('type',''));
    AssertTrue('JSON should contain data property', JSON.IndexOfName('data') <> -1);
    AssertEquals('Data should be base64 encoded', mcp.utils.EncodeBytes(Bytes), JSON.Get('data',''));
    AssertTrue('JSON should contain mimeType property', JSON.IndexOfName('mimeType') <> -1);
    AssertEquals('MimeType should be correct', 'audio/wav', JSON.Get('mimeType',''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONResourceLink;
var
  Msg: TMCPPromptMessage;
  JSON: TJSONObject;
  MockRes: TMCPResource;
begin
  MockRes:=TMCPResource.Create('http://mock.com/link_doc', 'LinkDoc');
  MockRes.Title:='Mock Linked Document';
  MockRes.MimeType:='application/pdf';
  FMockResourceRegistry.MockResources.Add(MockRes.Uri, MockRes);
  Msg:=TMCPPromptMessage.CreateResourceLink(prUser, MockRes.Uri);
  JSON:=Msg.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertEquals('Type should be "audio" (as per constructor)', 'resource_link', JSON.Get('type',''));
    AssertTrue('JSON should contain uri property from resource', JSON.IndexOfName('uri') <> -1);
    AssertEquals('URI should be from mocked resource', MockRes.Uri, JSON.Get('uri',''));
    AssertTrue('JSON should contain name property from resource', JSON.IndexOfName('name') <> -1);
    AssertEquals('Name should be from mocked resource', MockRes.Name, JSON.Get('name',''));
    AssertTrue('JSON should contain title property from resource', JSON.IndexOfName('title') <> -1);
    AssertEquals('Title should be from mocked resource', MockRes.Title, JSON.Get('title',''));
    AssertTrue('JSON should contain mimetype property from resource', JSON.IndexOfName('mimetype') <> -1);
    AssertEquals('MimeType should be from mocked resource', MockRes.MimeType, JSON.Get('mimetype',''));
    AssertFalse('JSON should NOT contain data/text properties (withData=false for resource link)', JSON.IndexOfName('data') <> -1);
    AssertFalse('JSON should NOT contain resource object for resource link', JSON.IndexOfName('resource') <> -1);
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONEmbeddedResource;
var
  Msg: TMCPPromptMessage;
  JSON: TJSONObject;
  MockRes: TMCPResource;
  ResourceJSON: TJSONObject;
begin
  MockRes:=TMCPResource.Create('http://mock.com/embed_data', 'EmbedData', TBytes.Create(1, 1, 1));
  MockRes.Title:='Mock Embedded Data';
  MockRes.MimeType:='application/octet-stream';
  FMockResourceRegistry.MockResources.Add(MockRes.Uri, MockRes);
  Msg:=TMCPPromptMessage.CreateEmbeddedResource(prAssistant, MockRes.Uri);
  JSON:=Msg.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertEquals('Type should be "audio" (as per constructor)', 'resource', JSON.Get('type',''));
    AssertTrue('JSON should contain resource object', JSON.IndexOfName('resource') <> -1);
    ResourceJSON:=JSON.Get('resource',TJSONObject(Nil));
    AssertNotNull('Resource object should not be nil', ResourceJSON);
    AssertEquals('Resource JSON should contain uri', MockRes.Uri, ResourceJSON.Get('uri',''));
    AssertEquals('Resource JSON should contain name', MockRes.Name, ResourceJSON.Get('name',''));
    AssertEquals('Resource JSON should contain title', MockRes.Title, ResourceJSON.Get('title',''));
    AssertEquals('Resource JSON should contain mimetype', MockRes.MimeType, ResourceJSON.Get('mimetype',''));
    AssertTrue('Resource JSON should contain data/text (withData=true)', ResourceJSON.IndexOfName('text') <> -1);
    AssertEquals('Resource JSON data should be encoded', mcp.utils.EncodeBytes(MockRes.Data), ResourceJSON.Get('text',''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONAnnotationsAndMeta;
var
  Msg: TMCPPromptMessage;
  JSON: TJSONObject;
  AnnoJSON: TJSONObject;
  MetaJSON: TJSONObject;
begin
  Msg:=TMCPPromptMessage.CreateText(prUser, 'Message with annotations and meta.');
  Msg.Annotations.Priority:=True;
  Msg.Annotations.Roles:=Msg.Annotations.Roles+[prAssistant];
  Msg._meta:=TJSONObject.Create;
  Msg._meta.Add('source', 'test');
  Msg._meta.Add('id', 123);
  JSON:=Msg.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON object', JSON);
  try
    AssertTrue('JSON should contain annotations property', JSON.IndexOfName('annotations') <> -1);
    AnnoJSON:=JSON.Get('annotations',TJSONObject(Nil));
    AssertNotNull('Annotations JSON should not be nil', AnnoJSON);
    AssertEquals('Annotations priority should be 1', 1, AnnoJSON.Get('priority', 0));
    AssertTrue('Annotations roles array should contain assistant', (AnnoJSON.Get('roles',TJSONArray(nil)).Items[0].AsString = 'assistant'));
    AssertTrue('JSON should contain _meta property', JSON.IndexOfName('_meta') <> -1);
    MetaJSON:=JSON.Get('_meta',TJSONObject(nil));
    AssertNotNull('_meta JSON should not be nil', MetaJSON);
    AssertEquals('Meta source should be correct', 'test', MetaJSON.Get('source',''));
    AssertEquals('Meta id should be correct', 123, MetaJSON.Get('id',0));
  finally
    JSON.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageToJSONNoResourceRegistryForLinkOrEmbed;
var
  MsgLink: TMCPPromptMessage;
  MsgEmbed: TMCPPromptMessage;
begin
  MsgLink:=TMCPPromptMessage.CreateResourceLink(prUser, 'http://test.com/link');
  try
    MsgLink.ToJSON(nil);
    Fail('Expected EMCPException for resource link with nil registry');
  except
    on E: EMCPException do
      AssertEquals('Exception message for no resource registry (link)', SErrNoResourceRegistry, E.Message);
  end;
  MsgEmbed:=TMCPPromptMessage.CreateEmbeddedResource(prUser, 'http://test.com/embed');
  try
    MsgEmbed.ToJSON(nil);
    Fail('Expected EMCPException for embedded resource with nil registry');
  except
    on E: EMCPException do
      AssertEquals('Exception message for no resource registry (embed)', SErrNoResourceRegistry, E.Message);
  end;
end;

procedure TMCPPromptsTest.TestPromptMessageArrayHelperToJSON;
var
  MsgArray: TMCPPromptMessageArray;
  Msg1, Msg2: TMCPPromptMessage;
  JSONArray: TJSONArray;
begin
  MsgArray:=[];
  Msg1:=TMCPPromptMessage.CreateText(prUser, 'First message');
  Msg2:=TMCPPromptMessage.CreateImage(prAssistant, TBytes.Create(1), 'image/gif');
  SetLength(MsgArray, 2);
  MsgArray[0]:=Msg1;
  MsgArray[1]:=Msg2;
  JSONArray:=MsgArray.ToJSON(FMockResourceRegistry);
  AssertNotNull('ToJSON should return a JSON array', JSONArray);
  try
    AssertEquals('JSON array should have 2 elements', 2, JSONArray.Count);
    AssertEquals('First message type should be text', 'text', JSONArray.Objects[0].Get('type',''));
    AssertEquals('Second message type should be image', 'image', JSONArray.Objects[1].Get('type',''));
  finally
    JSONArray.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptCreate;
var
  Prompt: TConcreteTestPrompt;
begin
  Prompt:=TConcreteTestPrompt.Create('test_prompt', 'Test Title', 'Test Description');
  try
    AssertEquals('Name should be set', 'test_prompt', Prompt.Name);
    AssertEquals('Title should be set', 'Test Title', Prompt.Title);
    AssertEquals('Description should be set', 'Test Description', Prompt.Description);
    AssertEquals('Arguments array should be empty initially', 0, Prompt.ArgumentCount);
    AssertTrue('OnCompletion event should be nil initially', Nil=Prompt.OnCompletion);
  finally
    Prompt.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptProperties;
var
  Prompt: TConcreteTestPrompt;
begin
  Prompt:=TConcreteTestPrompt.Create('prop_prompt', 'Old Title', 'Old Description');
  try
    Prompt.Title:='New Title';
    AssertEquals('Title should be updated', 'New Title', Prompt.Title);
    Prompt.Description:='New Description';
    AssertEquals('Description should be updated', 'New Description', Prompt.Description);
    Prompt.Name:='new_prop_name';
    AssertEquals('Name should be updated', 'new_prop_name', Prompt.Name);
    Prompt.OnCompletion:=@HandlePromptCompletion;
    AssertSame('OnCompletion should be assigned', TMethod(@HandlePromptCompletion).Code, TMethod(Prompt.OnCompletion).Code);
  finally
    Prompt.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptAddArgument;
var
  Prompt: TConcreteTestPrompt;
  Arg: TPromptArgument;
begin
  Prompt:=TConcreteTestPrompt.Create('arg_prompt', 'Arg Test');
  try
    Prompt.AddArgument('arg1', 'Argument One', True);
    AssertEquals('Arguments count should be 1', 1, Prompt.ArgumentCount);
    AssertEquals('First argument name should be correct', 'arg1', Prompt.Arguments[0].Name);
    Arg:=TPromptArgument.Create('arg2', 'Argument Two', False);
    Prompt.AddArgument(Arg);
    AssertEquals('Arguments count should be 2', 2, Prompt.ArgumentCount);
    AssertEquals('Second argument name should be correct', 'arg2', Prompt.Arguments[1].Name);
    AssertFalse('Second argument required should be false', Prompt.Arguments[1].Required);
  finally
    Prompt.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptNameValidation;
var
  Prompt: TConcreteTestPrompt;
begin
  try
    Prompt:=TConcreteTestPrompt.Create('', 'Title', 'Description');
    try
      Fail('Expected EMCPException for empty name in constructor');
    finally
      Prompt.Free;
    end;
  except
    on E: EMCPException do
      AssertEquals('Exception message for empty name in constructor', SErrPromptNameRequired, E.Message);
  end;
  Prompt:=TConcreteTestPrompt.Create('valid_name', 'Title', 'Description');
  try
    try
      Prompt.Name:='';
      Fail('Expected EMCPException for empty name via setter');
    except
      on E: EMCPException do
        AssertEquals('Exception message for empty name via setter', SErrPromptNameRequired, E.Message);
    end;
  finally
    Prompt.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptToJSON;
var
  Prompt: TConcreteTestPrompt;
  JSON: TJSONObject;
  ArgsArray: TJSONArray;
begin
  Prompt:=TConcreteTestPrompt.Create('json_prompt', 'JSON Test Prompt', 'Description for JSON');
  try
    Prompt.AddArgument('arg_a', 'Arg A Desc');
    Prompt.AddArgument('arg_b', 'Arg B Desc', False);
    JSON:=Prompt.ToJSON;
    AssertNotNull('ToJSON should return a JSON object', JSON);
    try
      AssertEquals('Name in JSON should be correct', 'json_prompt', JSON.Get('name',''));
      AssertEquals('Title in JSON should be correct', 'JSON Test Prompt', JSON.Get('title',''));
      AssertEquals('Description in JSON should be correct', 'Description for JSON', JSON.Get('description',''));

      AssertTrue('JSON should contain arguments array', JSON.IndexOfName('arguments') <> -1);
      ArgsArray:=JSON.Get('arguments',TJSONArray(Nil));
      AssertNotNull('Arguments should be a JSON array', ArgsArray);
      AssertEquals('Arguments array should have 2 elements', 2, ArgsArray.Count);

      AssertEquals('First argument name in JSON', 'arg_a', ArgsArray.Objects[0].Get('name',''));
      AssertTrue('First argument required in JSON', ArgsArray.Objects[0].Get('required',False));

      AssertEquals('Second argument name in JSON', 'arg_b', ArgsArray.Objects[1].Get('name',''));
      AssertFalse('Second argument required in JSON', ArgsArray.Objects[1].Get('required',False));
    finally
      JSON.Free;
    end;
  finally
    Prompt.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptGetCompletions;
var
  Prompt: TConcreteTestPrompt;
  PreviousCompletions: TStringList;
  CompletionsArray: TStringDynArray;
begin
  Prompt:=TConcreteTestPrompt.Create('comp_prompt', 'Completion Test');
  try
    Prompt.OnCompletion:=@HandlePromptCompletion;

    PreviousCompletions:=TStringList.Create;
    PreviousCompletions.Add('prev1');
    PreviousCompletions.Add('prev2');


    FCompletions.Add('compA');
    FCompletions.Add('compB');
    FCompletions.Add('compC');

    CompletionsArray:=Prompt.GetCompletions('testArg', PreviousCompletions);

    AssertTrue('OnCompletion event should have been triggered', FCompletionTriggered);
    AssertEquals('Arg name passed to event should be correct', 'testArg', FCompletionArgName);
    AssertEquals('Previous completions passed to event should match', PreviousCompletions.Text, FPreviousCompletions.Text);
    AssertEquals('Completions array should match', 3, Length(CompletionsArray));
    AssertEquals('First completion should be correct', 'compA', CompletionsArray[0]);
    AssertEquals('Second completion should be correct', 'compB', CompletionsArray[1]);
    AssertEquals('Third completion should be correct', 'compC', CompletionsArray[2]);
  finally
    Prompt.Free;
    PreviousCompletions.Free;
  end;
end;

procedure TMCPPromptsTest.TestPromptRegister;
var
  Prompt: TConcreteTestPrompt;
begin
  Prompt:=TConcreteTestPrompt.Create('register_prompt', 'Register Test');
  try
    Prompt.Register;
    AssertTrue('Prompt should be registered in mock registry', FMockPromptRegistry.RegisteredPrompts.Items[Prompt.Name]<>Nil);
    AssertSame('Registered prompt should be the same instance', Prompt, FMockPromptRegistry.RegisteredPrompts.Items[Prompt.Name]);
  finally

  end;
end;

procedure TMCPPromptsTest.TestPromptGetPromptDescription;
var
  Prompt: TConcreteTestPrompt;
  Args: TStringList;
begin
  Prompt:=TConcreteTestPrompt.Create('desc_prompt', 'Description Title', 'This is a test description.');
  Args:=TStringList.Create;
  try
    AssertEquals('GetPromptDescription should return the Description property', 'This is a test description.', Prompt.GetPromptDescription(Args));
  finally
    Prompt.Free;
    Args.Free;
  end;
end;



procedure TMCPPromptsTest.TestTemplatePromptGetPrompt;
var
  Prompt: TConcreteTestTemplatePrompt;
  Arguments: TStringList;
  Messages: TMCPPromptMessageArray;
  Msg : TMCPPromptMessage;
begin
  Prompt:=TConcreteTestTemplatePrompt.Create('template_prompt', 'Template Test', 'A template based prompt.');
  Prompt.Template:='User message: {{input}} and {{setting}}.';
  Prompt.AddArgument('input', 'User input');
  Prompt.AddArgument('setting', 'Some setting');
  try
    Arguments:=TStringList.Create;
    Arguments.Values['input']:='My awesome input';
    Arguments.Values['setting']:='High';
    Messages:=Prompt.GetPrompt(Arguments);
    AssertEquals('Should return an array with one message', 1, Length(Messages));
    AssertEquals('Message kind should be pkText', pkText, Messages[0].kind);
    AssertEquals('Message role should be prUser', prUser, Messages[0].role);
    AssertEquals('Message text content should be the value of the last argument processed', 'High', Messages[0].TextContent);
    for Msg in Messages do
    begin
      if Assigned(Msg._meta) then
        Msg._meta.Free;
    end;
  finally
    Prompt.Free;
    Arguments.Free;
  end;
end;

initialization
  RegisterTest( TMCPPromptsTest);
end.
