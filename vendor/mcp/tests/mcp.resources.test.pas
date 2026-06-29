unit mcp.resources.test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson,
  mcp.types,
  mcp.resources,
  mcp.utils;

type
  TMockResourceRegistry = class(TMCPResourceRegistry)
  public
    AddedResources: TThreadSafeObjectHash;
    WasChanged: Boolean;
    constructor Create; override;
    destructor Destroy; override;
    procedure Add(aResource: TMCPResource); override;
    procedure Remove(const aURI: String); override;
    function Find(const aURI: String): TMCPResource; override;
  end;

  { TMCPResourceTest }

  TMCPResourceTest = class(TTestCase)
  private
    FMockRegistry: TMockResourceRegistry;
    FCallbackTriggered: Boolean;
    FTestData: TBytes;
    procedure AssertEquals(const Msg: string; aExpected, aActual: TMCPResourceKind); overload;
    procedure AssertEquals(const Msg: string; aExpected, aActual: TBytes); overload;
    procedure MyCallback(aResource: TMCPResource);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCreateURIAndName;
    procedure TestCreateURIAndNameWithText;
    procedure TestCreateURIAndNameWithData;
    procedure TestCreateURIAndNameWithKindAndCallback;
    procedure TestPropertiesSetGet;
    procedure TestKindDetermination;
    procedure TestSizeCalculation;
    procedure TestUriSetterValidation;
    procedure TestToJSONWithoutData;
    procedure TestToJSONWithTextData;
    procedure TestToJSONWithBinaryData;
    procedure TestRegisterMethod;
  end;

implementation

uses
  mcp.strings, typinfo;

{ TMockResourceRegistry }

constructor TMockResourceRegistry.Create;
begin
  inherited Create;
  AddedResources:=TThreadSafeObjectHash.Create(True);
  WasChanged:=False;
end;

destructor TMockResourceRegistry.Destroy;
begin
  AddedResources.Destroy;
  inherited Destroy;
end;

procedure TMockResourceRegistry.Add(aResource: TMCPResource);
begin
  AddedResources.Add(aResource.Uri, aResource);
  WasChanged:=True;
end;

procedure TMockResourceRegistry.Remove(const aURI: String);
begin
  AddedResources.Remove(aURI);
end;

function TMockResourceRegistry.Find(const aURI: String): TMCPResource;
begin
  Result:=TMCPResource(AddedResources.Get(aURI));
end;

{ TMCPResourceTest }

procedure TMCPResourceTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPResourceKind);
begin
  AssertEquals(Msg,
               GetEnumName(TypeInfo(TMCPResourceKind), Ord(aExpected)),
               GetEnumName(TypeInfo(TMCPResourceKind), Ord(aActual)));
end;

procedure TMCPResourceTest.AssertEquals(const Msg: string; aExpected, aActual: TBytes);
var
  I : integer;
begin
  AssertEquals(Msg+' length',Length(aExpected),Length(aActual));
  For I:=0 to Length(aExpected)-1 do
    AssertEquals(Msg+' byte '+IntToStr(i),aExpected[i],aActual[i]);
end;

procedure TMCPResourceTest.SetUp;
begin
  inherited SetUp;
  TMCPResourceRegistry.Done;
  TMCPResourceRegistry.Init(TMockResourceRegistry);
  FMockRegistry:=TMCPResourceRegistry.instance as TMockResourceRegistry;
end;

procedure TMCPResourceTest.TearDown;
begin
  TMCPResourceRegistry.Done;
  inherited TearDown;
end;

procedure TMCPResourceTest.TestCreateURIAndName;
var
  Resource: TMCPResource;
begin
  Resource:=TMCPResource.Create('http://example.com/res1', 'res1');
  try
    AssertNotNull('Resource should be created', Resource);
    AssertEquals('URI should be set', 'http://example.com/res1', Resource.Uri);
    AssertEquals('Name should be set', 'res1', Resource.Name);
    AssertEquals('Kind should be unknown by default', rkUnknown, Resource.Kind);
    AssertEquals('Size should be 0 by default', 0, Resource.Size);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestCreateURIAndNameWithText;
var
  Resource: TMCPResource;
begin
  Resource:=TMCPResource.Create('http://example.com/res2', 'res2', 'Hello Text');
  try
    AssertNotNull('Resource should be created', Resource);
    AssertEquals('URI should be set', 'http://example.com/res2', Resource.Uri);
    AssertEquals('Name should be set', 'res2', Resource.Name);
    AssertEquals('Text should be set', 'Hello Text', Resource.Text);
    AssertEquals('Kind should be rkText', rkText, Resource.Kind);
    AssertEquals('Size should match text length', Length('Hello Text'), Resource.Size);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestCreateURIAndNameWithData;
var
  Resource: TMCPResource;
  Bytes: TBytes;
begin
  Bytes:=TBytes.Create(1, 2, 3, 4, 5);
  Resource:=TMCPResource.Create('http://example.com/res3', 'res3', Bytes);
  try
    AssertNotNull('Resource should be created', Resource);
    AssertEquals('URI should be set', 'http://example.com/res3', Resource.Uri);
    AssertEquals('Name should be set', 'res3', Resource.Name);
    AssertEquals('Data should be set', Bytes, Resource.Data);
    AssertEquals('Kind should be rkData', rkData, Resource.Kind);
    AssertEquals('Size should match data length', Length(Bytes), Resource.Size);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.MyCallback(aResource: TMCPResource);

begin
  FCallbackTriggered:=True;
  FTestData:=TBytes.Create(6, 7, 8);
  aResource.Data:=FTestData;
end;

procedure TMCPResourceTest.TestCreateURIAndNameWithKindAndCallback;
var
  Resource: TMCPResource;
  TestURI: string;

begin
  FCallbackTriggered:=False;
  TestURI:='http://example.com/res4';
  Resource:=TMCPResource.Create(TestURI, 'res4', rkData, @MyCallback);
  try
    AssertNotNull('Resource should be created', Resource);
    AssertEquals('URI should be set', TestURI, Resource.Uri);
    AssertEquals('Name should be set', 'res4', Resource.Name);
    AssertEquals('Kind should be rkData', rkData, Resource.Kind);
    AssertSame('OnData callback should be assigned', TMethod(@MyCallback).Code, TMethod(Resource.OnData).Code);
    Resource.OnData(Resource);
    AssertTrue('OnData callback should be triggered', FCallbackTriggered);
    AssertEquals('Data should be set by callback', FTestData, Resource.Data);
    AssertEquals('Size should match data length from callback', Length(FTestData), Resource.Size);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestPropertiesSetGet;
var
  Resource: TMCPResource;
begin
  Resource:=TMCPResource.Create('http://test.com/prop', 'propRes');
  try
    Resource.Title:='My Title';
    AssertEquals('Title should be settable and gettable', 'My Title', Resource.Title);
    Resource.Description:='My Description';
    AssertEquals('Description should be settable and gettable', 'My Description', Resource.Description);
    AssertEquals('Title and Description should be independent', 'My Title', Resource.Title);
    Resource.MimeType:='application/json';
    AssertEquals('MimeType should be settable and gettable', 'application/json', Resource.MimeType);
    Resource.Name:='NewName';
    AssertEquals('Name should be settable and gettable', 'NewName', Resource.Name);
    Resource.Text:='Some text data';
    AssertEquals('Text should be settable and gettable', 'Some text data', Resource.Text);
    AssertEquals('Kind should change to rkText when Text is set', rkText, Resource.Kind);
    AssertEquals('Data should be nil when Text is set', TBytes([]), Resource.Data);
    Resource.Data:=TBytes.Create(10, 20, 30);
    AssertEquals('Data should be settable and gettable', TBytes.Create(10, 20, 30), Resource.Data);
    AssertEquals('Kind should change to rkData when Data is set', rkData, Resource.Kind);
    AssertEquals('Text should be empty when Data is set', '', Resource.Text);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestKindDetermination;
var
  Resource: TMCPResource;
begin
  Resource:=TMCPResource.Create('http://kind.test', 'kind');
  try
    AssertEquals('Initial kind should be unknown', rkUnknown, Resource.Kind);
    Resource.Text:='hello';
    AssertEquals('Kind should be rkText after setting Text', rkText, Resource.Kind);
    Resource.Data:=TBytes.Create(1);
    AssertEquals('Kind should be rkData after setting Data', rkData, Resource.Kind);
    Resource.Text:='text again';
    Resource.Data:=TBytes.Create(1, 2);
    AssertEquals('Kind should remain rkData if Data is set last', rkData, Resource.Kind);
    Resource.Data:=TBytes([]);
    Resource.Text:='final text';
    AssertEquals('Kind should be rkText if Data is cleared and Text is set', rkText, Resource.Kind);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestSizeCalculation;
var
  Resource: TMCPResource;
  TestBytes: TBytes;
begin
  Resource:=TMCPResource.Create('http://size.test', 'size');
  try
    AssertEquals('Initial size should be 0', 0, Resource.Size);
    Resource.Size:=100;
    AssertEquals('Size property getter should prioritize set size', 100, Resource.Size);
    Resource.Size:=0;
    Resource.Text:='12345';
    AssertEquals('Size should be text length', 5, Resource.Size);
    TestBytes:=TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    Resource.Data:=TestBytes;
    AssertEquals('Size should be data length', 10, Resource.Size);
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestUriSetterValidation;
var
  Resource: TMCPResource;
begin
  Resource:=TMCPResource.Create('http://initial.com', 'initial');
  try
    Resource.Uri:='http://new.com/path';
    AssertEquals('URI should be updated', 'http://new.com/path', Resource.Uri);
  finally
    Resource.Free;
  end;
  Resource:=TMCPResource.Create('http://valid.com', 'valid');
  try
    try
      Resource.Uri:='';
      Fail('Expected EMCPException for empty URI but none was raised');
    except
      on E: EMCPException do
        AssertEquals('EMCPException for empty URI message mismatch', SErrUriCannotBeEmpty, E.Message);
    end;
  finally
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestToJSONWithoutData;
var
  Resource: TMCPResource;
  JSON: TJSONObject;
begin
  JSON:=nil;
  Resource:=TMCPResource.Create('http://json.test/res1', 'json1');
  try
    Resource.Title:='JSON Test Resource';
    Resource.Description:='JSON Test Resource';
    Resource.MimeType:='text/plain';
    JSON:=Resource.ToJSON(False);
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('URI should be in JSON', 'http://json.test/res1', JSON.Get('uri',''));
    AssertEquals('Name should be in JSON', 'json1', JSON.Get('name',''));
    AssertEquals('Title should be in JSON', 'JSON Test Resource', JSON.Get('title',''));
    AssertEquals('Description should be in JSON', 'JSON Test Resource', JSON.Get('description',''));
    AssertEquals('MimeType should be in JSON', 'text/plain', JSON.Get('mimetype',''));
    AssertFalse('Text should NOT be in JSON when withData is false', JSON.IndexOfName('text')<>-1);
  finally
    JSON.Free;
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestToJSONWithTextData;
var
  Resource: TMCPResource;
  JSON: TJSONObject;
begin
  JSON:=nil;
  Resource:=TMCPResource.Create('http://json.test/res2', 'json2', 'This is some text content.');
  try
    Resource.Title:='Text Content';
    Resource.MimeType:='text/markdown';
    JSON:=Resource.ToJSON(True);
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('URI should be in JSON', 'http://json.test/res2', JSON.Get('uri',''));
    AssertEquals('Name should be in JSON', 'json2', JSON.Get('name',''));
    AssertEquals('Title should be in JSON', 'Text Content', JSON.Get('title',''));
    AssertEquals('MimeType should be in JSON', 'text/markdown', JSON.Get('mimetype',''));
    AssertTrue('Text should be in JSON when withData is true', JSON.IndexOfName('text')<>-1);
    AssertEquals('Text content should match', 'This is some text content.', JSON.Get('text',''));
    AssertEquals('Kind should be rkText', rkText, Resource.Kind);
  finally
    JSON.Free;
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestToJSONWithBinaryData;
var
  Resource: TMCPResource;
  JSON: TJSONObject;
  TestBytes: TBytes;
begin
  TestBytes:=TBytes.Create(10, 20, 30, 255);
  JSON:=Nil;
  Resource:=TMCPResource.Create('http://json.test/res3', 'json3', TestBytes);
  try
    Resource.Title:='Binary Data';
    Resource.MimeType:='image/png';
    JSON:=Resource.ToJSON(True);
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('URI should be in JSON', 'http://json.test/res3', JSON.Get('uri',''));
    AssertEquals('Name should be in JSON', 'json3', JSON.Get('name',''));
    AssertEquals('Title should be in JSON', 'Binary Data', JSON.Get('title',''));
    AssertEquals('MimeType should be in JSON', 'image/png', JSON.Get('mimetype',''));
    AssertTrue('Text should be in JSON when withData is true', JSON.IndexOfName('text')<>-1);
    AssertEquals('Encoded binary data should match', mcp.utils.EncodeBytes(TestBytes), JSON.Get('text',''));
    AssertEquals('Kind should be rkData', rkData, Resource.Kind);
  finally
    JSON.Free;
    Resource.Free;
  end;
end;

procedure TMCPResourceTest.TestRegisterMethod;
var
  Resource: TMCPResource;
begin
  Resource:=TMCPResource.Create('http://register.test/res', 'register_res');
  Resource.Register;
  AssertTrue('Resource should be added to the mock registry', FMockRegistry.AddedResources.Get(Resource.Uri)<>Nil);
  AssertSame('Added resource in mock should be the same instance', Resource, FMockRegistry.AddedResources.Get(Resource.Uri));
end;

initialization
  RegisterTests([TMCPResourceTest]);
end.
