unit mcp.tools.test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, types, fpjson,
  mcp.types,
  mcp.strings,
  mcp.tools;

{$IF DECLARED(TMCPCallTool)}
{$DEFINE USE_RTTI}
{$ENDIF}

type
  TMockToolRegistry = class(TMCPToolRegistry)
  end;

  { TTestConcreteTool }

  TTestConcreteTool = class(TMCPTool)
  private
    FMockDoExecuteResult: TJSONObject;
    FRecordedDoExecuteInput: TJSONObject;
  protected
    procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
  public
    constructor Create(const aName, aDescription: string); override;
    destructor Destroy; override;

    property MockDoExecuteResult: TJSONObject write FMockDoExecuteResult;
    property RecordedDoExecuteInput: TJSONObject read FRecordedDoExecuteInput;
  end;


  { TMCPToolsTest }
  TMCPToolsTest = class(TTestCase)
  private
    FMockToolRegistry: TMockToolRegistry;
    FEventToolTriggered: Boolean;
    FEventToolReceivedInput: TJSONData;
    FEventToolSetOutput: TJSONData;
    procedure HandleToolInvocationEvent(aInput: TJSONData; var aOutput: TMCPToolResultArray);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestToolCreationAndProperties;
    procedure TestToolMetaOwnership;
    procedure TestToolExecuteMethod;
    procedure TestEventToolCreation;
    procedure TestEventToolExecution;
    procedure TestToolRegistryAddFindRemove;
    procedure TestToolRegistryGetAndExceptions;
    procedure TestToolRegistryCountProperty;
    procedure TestToolRegistryLockUnlockList;
    procedure TestToolRegistryInitMethod;
  end;

  {$IFDEF USE_RTTI}

  { TTestCallTool }

  TTestCallTool = Class(TTestCase)
  public
    function callTool(aClass: TMCPCallToolClass; aResult: string; aIsText : boolean = True): string;
  published
    Procedure TestStringResult;
    Procedure TestCharResult;
    Procedure TestAstringResult;
    Procedure TestUCharResult;
    Procedure TestWcharResult;
    Procedure TestWStringResult;
    Procedure TestIntegerResult;
    Procedure TestInt64Result;
    Procedure TestQWordResult;
    Procedure TestBoolResult;
    Procedure TestEnumerationResult;
    Procedure TestFloatResult;
    Procedure TestSetResult;
    Procedure TestArrayResult;
    Procedure TestClassResult;
    Procedure TestClassRefResult;
    Procedure TestMCPToolResult;
    Procedure TestMCPToolArrayResult;
  end;

  {$RTTI EXPLICIT
      PROPERTIES([vcPrivate,vcProtected,vcPublic,vcPublished])
      FIELDS([vcPrivate,vcProtected,vcPublic,vcPublished])
      METHODS([vcPrivate,vcProtected,vcPublic,vcPublished])}

  TStringCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : shortstring;
  end;

  TAnsiStringCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : Ansistring;
  end;

  TMyEnum = (one,two,three);
  TMyEnums = set of TMyEnum;

  TEnumCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TMyEnum;
  end;

  TSetCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TMyEnums;
  end;

  TArrayCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TStringDynArray;
  end;

  TClassCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TObject;
  end;

  TClassRefCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TClass;
  end;

  TWideStringCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : WideString;
  end;

  TIntegerCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : Integer;
  end;

  TInt64CallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : Int64;
  end;

  TQWordCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : QWord;
  end;

  TBooleanCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : Boolean;
  end;

  TAnsiCharCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : Ansichar;
  end;

  TUnicodeCharCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : UnicodeChar;
  end;

  TWideCharCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : WideChar;
  end;

  TFloatCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : Double;
  end;

  { TMCPToolResultCallTool }

  TMCPToolResultCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TMCPToolResult;
  end;

  { TMCPToolResultArrayCallTool }

  TMCPToolResultArrayCallTool = class(TMCPCallTool)
  Public
    function Call(s : string) : TMCPToolResultArray;
  end;

  {$ENDIF}



implementation

uses
  TypInfo;

constructor TTestConcreteTool.Create(const aName, aDescription: string);
begin
  inherited Create(aName, aDescription);
  FMockDoExecuteResult := nil;
  FRecordedDoExecuteInput := nil;
end;

destructor TTestConcreteTool.Destroy;
begin
  FreeAndNil(FMockDoExecuteResult);
  inherited Destroy;
end;

procedure TTestConcreteTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
var
  i : Integer;
begin
  FreeAndNil(FRecordedDoExecuteInput);
  if Assigned(aInput) then
    FRecordedDoExecuteInput := aInput
  else
    FRecordedDoExecuteInput := nil;
  for I:=0 to FMockDoExecuteResult.Count-1 do
    aResult.Add(FMockDoExecuteResult.Names[i], FMockDoExecuteResult.Items[i].Clone);
  FMockDoExecuteResult := nil;
end;

procedure TMCPToolsTest.HandleToolInvocationEvent(aInput: TJSONData; var aOutput: TMCPToolResultArray);
var
  lOutput : TJSONObject;
begin
  FEventToolTriggered := True;
  FEventToolReceivedInput := aInput;
  lOutput := TJSONObject.Create;
  try
    if (aInput is TJSONObject) and ((aInput as TJSONObject).IndexOfName('input_value') <> -1) then
      begin
      lOutput.Add('result', 'success');
      lOutput.Add('calculated_value', (aInput as TJSONObject).Get('input_value',0) * 10);
      end
    else
      begin
      lOutput.Add('result', 'error');
      end;
    SetLength(aOUtput,1);
    aOutput[0]:= TMCPToolResult.CreateText(lOutput);
  finally
    lOutput.Free;
  end;
end;

procedure TMCPToolsTest.SetUp;
begin
  inherited SetUp;
  FEventToolTriggered := False;
  FEventToolReceivedInput := nil;
  FEventToolSetOutput := nil;
  TMCPToolRegistry.Done;
  TMCPToolRegistry.Init(TMockToolRegistry);
  FMockToolRegistry:=TMCPToolRegistry.Instance as TMockToolRegistry;
end;

procedure TMCPToolsTest.TearDown;
begin
  TMCPToolRegistry.Done;
  FMockToolRegistry:=nil;
  FreeAndNil(FEventToolSetOutput);
  inherited TearDown;
end;

procedure TMCPToolsTest.TestToolCreationAndProperties;
var
  Tool: TTestConcreteTool;
  TestMeta: TJSONObject;
  Annotation: TMCPAnnotation;
begin
  Tool := TTestConcreteTool.Create('test_tool_name', 'This is a test tool description.');
  TestMeta := TJSONObject.Create;
  TestMeta.Add('version', '1.0');
  TestMeta.Add('author', 'Tester');
  try
    AssertEquals('Name property should match constructor argument', 'test_tool_name', Tool.Name);
    AssertEquals('Description property should match constructor argument', 'This is a test tool description.', Tool.Description);
    AssertNotNull('InputSchema should be created', Tool.InputSchema);
    AssertNull('_Meta should be nil by default', Tool._Meta);
    AssertFalse('Annotations should be uninitialized by default', Tool.Annotations.Initialized);
    Tool._Meta := TestMeta;
    AssertSame('_Meta property should return the assigned object', TestMeta, Tool._Meta);

    // Create a complete annotation record and assign it
    Annotation := Tool.Annotations; // Start with current annotation
    Annotation.Priority := True;
    Annotation.Roles := Annotation.Roles + [prAssistant];
    Tool.Annotations := Annotation; // Assign the complete record back

    AssertTrue('Annotations.Priority should be true', Tool.Annotations.Priority);
    AssertTrue('Annotations.Roles should include prAssistant', prAssistant in Tool.Annotations.Roles);
  finally
    Tool.Free;
  end;
end;

procedure TMCPToolsTest.TestToolMetaOwnership;
var
  Tool: TTestConcreteTool;
  Meta1, Meta2: TJSONObject;
begin
  Tool := TTestConcreteTool.Create('owner_tool', 'Tests _Meta ownership.');
  Meta1 := TJSONObject.Create;
  Meta1.Add('id', 1);
  Meta2 := TJSONObject.Create;
  Meta2.Add('id', 2);
  try
    Tool._Meta := Meta1;
    AssertSame('Tool should now own Meta1', Meta1, Tool._Meta);
    Tool._Meta := Meta2;
    AssertSame('Tool should now own Meta2', Meta2, Tool._Meta);
    Tool._Meta := nil;
    AssertNull('Tool should have no _Meta object', Tool._Meta);
  finally
    Tool.Free;
  end;
end;

procedure TMCPToolsTest.TestToolExecuteMethod;
var
  Tool: TTestConcreteTool;
  res : TJSONData;
  InputJson: TJSONObject;
  ExpectedOutputJson: TJSONObject;
  ActualOutputJson: TJSONObject;
  lJSON : TJSONObject;
begin
  ActualOutputJson:=TJSONObject.Create;
  InputJson:=Nil;
  lJSON:=NIl;
  Res:=Nil;
  Tool := TTestConcreteTool.Create('exec_tool', 'Tests the Execute method.');
  try
    InputJson := TJSONObject.Create;
    InputJson.Add('param1', 'value1');
    InputJson.Add('param2', 123);
    ExpectedOutputJson := TJSONObject.Create;
    ExpectedOutputJson.Add('status', 'OK');
    ExpectedOutputJson.Add('data', 'processed');
    Tool.MockDoExecuteResult := ExpectedOutputJson;
    Tool.Execute(InputJson,ActualOutputJson);
    AssertNotNull('Recorded input to DoExecute should not be nil', Tool.RecordedDoExecuteInput);
    AssertEquals('Recorded input param1 should match original', InputJson.Get('param1',''), Tool.RecordedDoExecuteInput.Get('param1',''));
    AssertEquals('Recorded input param2 should match original', InputJson.Get('param2',0), Tool.RecordedDoExecuteInput.Get('param2',0));
    AssertNotNull('Actual output from Execute should not be nil', ActualOutputJson);
    Res:=ActualOutputJson.FindPath('content[0].text');
    AssertNotNull('Found text', Res);
    AssertTrue('String',Res.JSONType=jtString);
    lJSON:=GetJSON(Res.AsString) as TJSONObject;
    AssertEquals('Actual output object should be the expected mock result', ExpectedOutputJson.AsJSON, lJSON.AsJSON);
    AssertEquals('Output status should be OK', 'OK', lJson.Get('status',''));
    AssertEquals('Output data should be processed', 'processed', lJson.Get('data',''));
  finally
    lJSON.Free;
    ExpectedOutputJson.Free;
    ActualOutputJson.Free;
    InputJson.Free;
    Tool.Free;
  end;
end;

Type
  TMyEventTool = Class(TMCPEventTool)
  public
    Property OnExecute;
  end;

procedure TMCPToolsTest.TestEventToolCreation;
var
  Tool: TMyEventTool;
begin
  Tool := TMyEventTool.Create('event_create_tool', 'Event tool description.', @HandleToolInvocationEvent);
  try
    AssertEquals('Name property should be set', 'event_create_tool', Tool.Name);
    AssertEquals('Description property should be set', 'Event tool description.', Tool.Description);
    AssertSame('OnExecute event should be assigned', TMethod(@HandleToolInvocationEvent).Code, TMethod(Tool.OnExecute).code);
  finally
    Tool.Free;
  end;
end;

procedure TMCPToolsTest.TestEventToolExecution;
var
  Tool: TMyEventTool;
  InputJson: TJSONObject;
  lArr : TJSONArray;
  lJSON,lCont,lOutput : TJSONObject;

begin
  InputJSON:=Nil;
  lJSON:=Nil;
  lOutput:=nil;
  Tool := TMyEventTool.Create('event_exec_tool', 'Event tool for execution.', @HandleToolInvocationEvent);
  try
    InputJson := TJSONObject.Create;
    InputJson.Add('input_value', 5);
    InputJson.Add('some_other_key', 'hello');
    lOutput:=TJSONObject.Create;
    Tool.Execute(InputJson,lOutput);
    lArr:=lOutput.Get('content',TJSONArray(Nil));
    AssertNotNull('Have content',lArr);
    AssertEquals('Correct content length',1,lArr.Count);
    AssertTrue('Correct element type',lArr.Types[0]=jtObject);
    lCont:=lArr.Objects[0];
    AssertEquals('Correct output content type','text',lCont.Get('type',''));
    AssertTrue('Correct output content',''<>lCont.Get('text',''));
    AssertTrue('HandleToolInvocationEvent should have been triggered', FEventToolTriggered);
    AssertSame('Input JSON received by event handler should be the same object as passed', InputJson, FEventToolReceivedInput);
    lJSON:=GetJSON(lCont.Get('text','')) as TJSONObject;
    AssertNotNull('Actual output JSON should not be nil', lJson);
    AssertTrue('Output should contain "result" key', lJson.IndexOfName('result') <> -1);
    AssertEquals('Output result should be "success"', 'success', lJson.Get('result',''));
    AssertTrue('Output should contain "calculated_value" key', lJson.IndexOfName('calculated_value') <> -1);
    AssertEquals('Calculated value should be 50 (5 * 10)', 50, lJson.Get('calculated_value',0));
  finally
    lJSON.Free;
    lOutput.Free;
    InputJson.Free;
    Tool.Free;
  end;
end;



procedure TMCPToolsTest.TestToolRegistryAddFindRemove;
var
  Tool1, Tool2: TMCPTool;
begin
  Tool1 := TTestConcreteTool.Create('tool_A', 'Description A');
  Tool2 := TTestConcreteTool.Create('tool_B', 'Description B');


  FMockToolRegistry.Add(Tool1);
  AssertEquals('Count should be 1 after adding tool_A', 1, FMockToolRegistry.Count);
  AssertSame('Find("tool_A") should return Tool1', Tool1, FMockToolRegistry.Find('tool_A'));
  AssertNull('Find("non_existent") should return nil', FMockToolRegistry.Find('non_existent'));

  FMockToolRegistry.Add(Tool2);
  AssertEquals('Count should be 2 after adding tool_B', 2, FMockToolRegistry.Count);
  AssertSame('Find("tool_B") should return Tool2', Tool2, FMockToolRegistry.Find('tool_B'));


  FMockToolRegistry.Remove('tool_A');
  AssertEquals('Count should be 1 after removing tool_A by name', 1, FMockToolRegistry.Count);
  AssertNull('Find("tool_A") should now return nil', FMockToolRegistry.Find('tool_A'));


  FMockToolRegistry.Remove(Tool2);
  AssertEquals('Count should be 0 after removing tool_B by object', 0, FMockToolRegistry.Count);
  AssertNull('Find("tool_B") should now return nil', FMockToolRegistry.Find('tool_B'));


end;

procedure TMCPToolsTest.TestToolRegistryGetAndExceptions;
var
  Tool: TMCPTool;
begin
  Tool := TTestConcreteTool.Create('get_me', 'A tool to be retrieved.');
  FMockToolRegistry.Add(Tool);


  AssertSame('Get("get_me") should return the correct tool', Tool, FMockToolRegistry.Get('get_me'));


  try
    FMockToolRegistry.Get('non_existent_tool_for_get');
    Fail('Expected EMCPException for Get of a non-existent tool.');
  except
    on E: EMCPException do
      AssertEquals('Exception message should indicate unknown tool', Format(SErrUnknownTool, ['non_existent_tool_for_get']), E.Message);
  end;

end;

procedure TMCPToolsTest.TestToolRegistryCountProperty;
var
  Tool1, Tool2: TMCPTool;
begin
  AssertEquals('Initial registry count should be 0', 0, FMockToolRegistry.Count);

  Tool1 := TTestConcreteTool.Create('count_tool_1', '');
  FMockToolRegistry.Add(Tool1);
  AssertEquals('Count should be 1 after adding one tool', 1, FMockToolRegistry.Count);

  Tool2 := TTestConcreteTool.Create('count_tool_2', '');
  FMockToolRegistry.Add(Tool2);
  AssertEquals('Count should be 2 after adding a second tool', 2, FMockToolRegistry.Count);

  FMockToolRegistry.Remove(Tool1);
  AssertEquals('Count should be 1 after removing one tool', 1, FMockToolRegistry.Count);

  FMockToolRegistry.Remove(Tool2);
  AssertEquals('Count should be 0 after removing all tools', 0, FMockToolRegistry.Count);
end;

procedure TMCPToolsTest.TestToolRegistryLockUnlockList;
var
  Tool1, Tool2, Tool3: TMCPTool;
  ToolArray: TMCPToolArray;
  FPList: TFPList;
begin
  Tool1 := TTestConcreteTool.Create('lock_tool_1', '');
  Tool2 := TTestConcreteTool.Create('lock_tool_2', '');
  Tool3 := TTestConcreteTool.Create('lock_tool_3', '');

  FMockToolRegistry.Add(Tool1);
  FMockToolRegistry.Add(Tool2);
  FMockToolRegistry.Add(Tool3);


  ToolArray := nil; // Ensure it's empty before locking
  FMockToolRegistry.LockList(ToolArray);
  try
    AssertEquals('Locked TMCPToolArray should have 3 elements', 3, Length(ToolArray));

    AssertTrue('Tool1 should be in the array', (ToolArray[0] = Tool1) or (ToolArray[1] = Tool1) or (ToolArray[2] = Tool1));
    AssertTrue('Tool2 should be in the array', (ToolArray[0] = Tool2) or (ToolArray[1] = Tool2) or (ToolArray[2] = Tool2));
    AssertTrue('Tool3 should be in the array', (ToolArray[0] = Tool3) or (ToolArray[1] = Tool3) or (ToolArray[2] = Tool3));
  finally
    FMockToolRegistry.UnlockList;
    // ToolArray does not need manual SetLength(0) as it's a local variable and will be managed.
  end;


  FPList := TFPList.Create;
  try
    FMockToolRegistry.LockList(FPList);
    try
      AssertEquals('Locked TFPList should have 3 elements', 3, FPList.Count);

      AssertTrue('Tool1 should be in the TFPList', FPList.IndexOf(Tool1)<>-1);
      AssertTrue('Tool2 should be in the TFPList', FPList.IndexOf(Tool2)<>-1);
      AssertTrue('Tool3 should be in the TFPList', FPList.IndexOf(Tool3)<>-1);
    finally
      FMockToolRegistry.UnlockList;
    end;
  finally
    FPList.Free;
  end;

end;

procedure TMCPToolsTest.TestToolRegistryInitMethod;
var
  TempInstance: TMCPToolRegistry;
begin

  TempInstance := TMCPToolRegistry.Instance;
  PPointer(@TMCPToolRegistry._instance)^ := nil;
  FreeAndNil(TempInstance);


  try
    TMCPToolRegistry.Init(TMCPToolRegistry);
    AssertNotNull('TMCPToolRegistry.Instance should not be nil after Init', TMCPToolRegistry.Instance);
    AssertTrue('Instance should be of TMCPToolRegistry type', TMCPToolRegistry.Instance is TMCPToolRegistry);
  except
    on E: Exception do
      Fail(Format('Unexpected exception during initial TMCPToolRegistry.Init: %s', [E.Message]));
  end;


  try
    TMCPToolRegistry.Init(TMCPToolRegistry);
    Fail('Expected EMCPException when Init is called on an already instantiated registry');
  except
    on E: EMCPException do
      AssertEquals('Exception message should be SErrRegistryALreadyInstantiated', SErrRegistryALreadyInstantiated, E.Message);
  end;


  TMCPToolRegistry.Done;

  try
    TMCPToolRegistry.Init(nil);
    Fail('Expected EMCPException when Init is called with a nil class');
  except
    on E: EMCPException do
      AssertEquals('Exception message should be SErrRegistryClassEmpty', SErrRegistryClassEmpty, E.Message);
  end;
end;

{$IFDEF USE_RTTI}
function TAnsiStringCallTool.Call(s: string): Ansistring;
var
  l : String;
begin
  l:='Hello '+S;
  Result:=l;
end;

{ TEnumCallTool }

function TEnumCallTool.Call(s: string): TMyEnum;
begin
  Result:=Three;
end;

{ TSetCallTool }

function TSetCallTool.Call(s: string): TMyEnums;
begin
  Result:=[one,two];
end;

{ TArrayCallTool }

function TArrayCallTool.Call(s: string): TStringDynArray;
begin
  Result:=['one','two'];
end;

{ TClassCallTool }

function TClassCallTool.Call(s: string): TObject;
begin
  Result:=Self;
end;

{ TClassRefCallTool }

function TClassRefCallTool.Call(s: string): TClass;
begin
  Result:=Self.ClassType
end;

{ TWideStringCallTool }

function TWideStringCallTool.Call(s: string): WideString;
begin
  Result:='Hello '+S;
end;

{ TAnsicharCallTool }

function TAnsicharCallTool.Call(s: string): Ansichar;
begin
  Result:='z';
end;

{ TUnicodeCharCallTool }

function TUnicodeCharCallTool.Call(s: string): UnicodeChar;
begin
  Result:=UTF8Decode('é')[1];
end;

{ TWideCharCallTool }

function TWideCharCallTool.Call(s: string): WideChar;
begin
  Result:=UTF8Decode('é')[1];
end;

{ TFloatCallTool }

function TFloatCallTool.Call(s: string): Double;
begin
  Result:=123;
end;

{ TMCPToolResultCallTool }

function TMCPToolResultCallTool.Call(s: string): TMCPToolResult;
begin
  Result:=TMCPToolResult.CreateResource('blob','application/text',S);
end;

{ TMCPToolResultArrayCallTool }

function TMCPToolResultArrayCallTool.Call(s: string): TMCPToolResultArray;
begin
  SetLength(Result,1);
  Result[0]:=TMCPToolResult.CreateResource('blob','application/text',S);
end;

{ TAnsiStringCallTool }

function TIntegerCallTool.Call(s: string): Integer;
begin
  Result:=123;
end;

{ TInt64CallTool }

function TInt64CallTool.Call(s: string): Int64;
begin
  Result:=123
end;

{ TQWordCallTool }

function TQWordCallTool.Call(s: string): QWord;
begin
  Result:=123;
end;

{ TBooleanCallTool }

function TBooleanCallTool.Call(s: string): Boolean;
begin
  Result:=S<>'';
end;

{ TStringCallTool }

function TStringCallTool.Call(s: string): shortstring;
begin
  Result:='';
  Result:='Hello '+s;
end;


{ TTestCallTool }

function TTestCallTool.callTool(aClass: TMCPCallToolClass; aResult: string; aIsText: boolean): string;
var
  lTool : TMCPCallTool;
  lData : TJSONData;
  lObj : TJSONObject absolute lData;
  lInput,lOutput : TJSONObject;
  S : String;
begin
  lInput:=Nil;
  lTool:=aClass.create('test','descr');
  try
    lInput:=TJSONObject.Create(['s','input']);
    lOutput:=TJSONObject.Create;
    lTool.Execute(lInput,lOutput);
    lData:=lOutput.Get('content',TJSONArray(Nil));
    AssertNotNull('Have content',lData);
    AssertEquals('Content element count',1,lData.Count);
    lData:=lData.Items[0];
    AssertEquals('Content 0 is object',TJSONObject,lData.ClassType);
    if aIsText then
      begin
      AssertEquals('Object contains text','text',lObj.Get('type',''));
      S:=lObj.Get('text','');
      AssertEquals('Correct result content',aResult,S);
      end;
    Result:=lData.AsJSON;
  finally
    lTool.Free;
    lInput.Free;
    lOutput.Free;
  end;
end;

procedure TTestCallTool.TestStringResult;
begin
  CallTool(TStringCallTool,'Hello input')
end;

procedure TTestCallTool.TestCharResult;
begin
  CallTool(TAnsiCharCallTool,'z')
end;

procedure TTestCallTool.TestAstringResult;
begin
  CallTool(TAnsiStringCallTool,'Hello input');
end;

procedure TTestCallTool.TestUCharResult;
begin
  CallTool(TUnicodeCharCallTool,'é')
end;

procedure TTestCallTool.TestWcharResult;
begin
  CallTool(TWideCharCallTool,'é')
end;

procedure TTestCallTool.TestWStringResult;
begin
  CallTool(TWidestringCallTool,'Hello input');
end;

procedure TTestCallTool.TestIntegerResult;
begin
  CallTool(TIntegerCallTool,'123')
end;

procedure TTestCallTool.TestInt64Result;
begin
  CallTool(TInt64CallTool,'123')
end;

procedure TTestCallTool.TestQWordResult;
begin
  CallTool(TQWordCallTool,'123')
end;

procedure TTestCallTool.TestBoolResult;
begin
  CallTool(TBooleanCallTool,'True')
end;

procedure TTestCallTool.TestEnumerationResult;
begin
  CallTool(TEnumCallTool,'three')
end;

procedure TTestCallTool.TestFloatResult;
begin
  CallTool(TFloatCallTool,'1.2300000000000000E+002')
end;

procedure TTestCallTool.TestSetResult;
begin
  CallTool(TSetCallTool,'[one,two]')
end;

procedure TTestCallTool.TestArrayResult;
begin
  CallTool(TArrayCallTool,'["one", "two"]')
end;

procedure TTestCallTool.TestClassResult;
begin
  CallTool(TClassCallTool,'TClassCallTool')
end;

procedure TTestCallTool.TestClassRefResult;
begin
  CallTool(TClassRefCallTool,'TClassRefCallTool')
end;

procedure TTestCallTool.TestMCPToolResult;
var
  S : String;
  lData : TJSONData;
  lJSON : TJSONObject absolute lData;
  lRes : TJSONObject;
begin
  S:=CallTool(TMCPToolResultCallTool,'',False);
  Writeln('S : ',S);
  lData:=GetJSON(S);
  try
    AssertEquals('Object',TJSONObject,lData.ClassType);
    AssertEquals('Type','resource',lJSON.Get('type',''));
    lRes:=lJSON.get('resource',TJSONObject(nil));
    AssertEquals('Mime type','application/text',lRes.Get('mimeType',''));
    AssertEquals('Content','input',lRes.Get('text',''));
  finally
    lData.Free;
  end;
end;

procedure TTestCallTool.TestMCPToolArrayResult;

var
  S : String;
  lData : TJSONData;
  lJSON : TJSONObject absolute lData;
  lRes : TJSONObject;
begin
  S:=CallTool(TMCPToolResultArrayCallTool,'',False);
  Writeln('S : ',S);
  lData:=GetJSON(S);
  try
    AssertEquals('Object',TJSONObject,lData.ClassType);
    AssertEquals('Type','resource',lJSON.Get('type',''));
    lRes:=lJSON.get('resource',TJSONObject(nil));
    AssertEquals('Mime type','application/text',lRes.Get('mimeType',''));
    AssertEquals('Content','input',lRes.Get('text',''));
  finally
    lData.Free;
  end;
end;

{$endif}


initialization
  RegisterTests([TMCPToolsTest]);
  {$IFDEF USE_RTTI}
  RegisterTest([TTestCallTool]);
  {$ENDIF}
end.
