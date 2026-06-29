unit mcp.toolregistry.test;

{$mode objfpc}{$H+}

interface

uses
  TestRegistry, Classes, SysUtils, fpcunit, fpjson,
  mcp.types,
  mcp.tools;

type
  
  { TMCPEmptyTool }

  TMCPEmptyTool = class(TMCPTool)

  protected
    procedure DoExecute(aInput: TJSONObject; aOutput: TJSONObject); override;
  end;
  
  { TMCPToolRegistryTest }

  TMCPToolRegistryTest = class(TTestCase)
  private
    FRegistry: TMCPToolRegistry;
    FOnChangeTriggeredCount: Integer;
    procedure HandleRegistryChange(Sender: TObject);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSingletonInstance;
    procedure TestInitClassProcedure;
    procedure TestAddTool;
    procedure TestRemoveToolByname;
    procedure TestRemoveToolByObject;
    procedure TestFindTool;
    procedure TestGetTool;
    procedure TestLockListTFPList;
    procedure TestLockListTMCPToolArray;
    procedure TestOnChangeEvent;
    procedure TestToolOwnershipOnAddRemove;
  end;

implementation

uses
  mcp.strings,
  TypInfo;

{ TMCPEmptyTool }

procedure TMCPEmptyTool.DoExecute(aInput: TJSONObject; aOutput: TJSONObject);
begin
  //
end;

{ TMCPEmptyTool }



{ TMCPToolRegistryTest }

procedure TMCPToolRegistryTest.HandleRegistryChange(Sender: TObject);
begin
  Inc(FOnChangeTriggeredCount);
end;

procedure TMCPToolRegistryTest.SetUp;
begin
  inherited SetUp;
  TMCPToolRegistry.Done;
  FRegistry:=TMCPToolRegistry.Instance;
  FOnChangeTriggeredCount:=0;
  FRegistry.OnChange:=@HandleRegistryChange;
end;

procedure TMCPToolRegistryTest.TearDown;
begin
  TMCPToolRegistry.Done;
  FRegistry:=Nil;

  inherited TearDown;
end;

procedure TMCPToolRegistryTest.TestSingletonInstance;
var
  Instance1, Instance2: TMCPToolRegistry;
begin

  Instance1:=ToolRegistry;
  Instance2:=ToolRegistry;
  AssertSame('ToolRegistry should return the same instance', Instance1, Instance2);
  AssertSame('Instance should be the one created in SetUp', FRegistry, Instance1);
end;

procedure TMCPToolRegistryTest.TestInitClassProcedure;

begin

  try
    TMCPToolRegistry.Init(TMCPToolRegistry);
    Fail('Expected EMCPException (Registry already instantiated) but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for already instantiated registry', SErrRegistryALreadyInstantiated, E.Message);
  end;


  TMCPToolRegistry.Done;
  try
    TMCPToolRegistry.Init(nil);
    Fail('Expected EMCPException (Registry class empty) but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for empty registry class', SErrRegistryClassEmpty, E.Message);
  end;

end;


procedure TMCPToolRegistryTest.TestAddTool;
var
  Tool1, Tool2: TMCPTool;
   Tool1New: TMCPTool;
begin
  Tool1:=TMCPEmptyTool.Create('name1', 'Title1');
  Tool2:=TMCPEmptyTool.Create('name2', 'Title2');

  FRegistry.Add(Tool1);
  AssertEquals('Count should be 1 after adding first Tool', 1, FRegistry.Count);
  AssertNotNull('Tool1 should be findable by name', FRegistry.Find('name1'));
  AssertSame('Tool1 should be the correct instance', Tool1, FRegistry.Find('name1'));
  AssertEquals('OnChange should be triggered once after Add', 1, FOnChangeTriggeredCount);

  FRegistry.Add(Tool2);
  AssertEquals('Count should be 2 after adding second Tool', 2, FRegistry.Count);
  AssertNotNull('Tool2 should be findable by name', FRegistry.Find('name2'));
  AssertEquals('OnChange should be triggered twice after Add', 2, FOnChangeTriggeredCount);



  Tool1New:=TMCPEmptyTool.Create('name1', 'Title1_new');
  try
    FRegistry.Add(Tool1New);
    Fail('Expected exception for duplicate Tool, got none')
  except
    Tool1New.Free;
  end;
end;

procedure TMCPToolRegistryTest.TestRemoveToolByname;
var
  Tool1, Tool2: TMCPTool;
begin
  Tool1:=TMCPEmptyTool.Create('name1', 'Title1');
  Tool2:=TMCPEmptyTool.Create('name2', 'Title2');
  FRegistry.Add(Tool1);
  FRegistry.Add(Tool2);
  FOnChangeTriggeredCount:=0;
  FRegistry.Remove('name1');
  AssertEquals('Count should be 1 after removing Tool by name', 1, FRegistry.Count);
  AssertNull('Tool1 should no longer be findable', FRegistry.Find('name1'));
  AssertEquals('OnChange should be triggered once after Remove by name', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('nonexistent');
  AssertEquals('Count should remain 1 after removing non-existent name', 1, FRegistry.Count);
  AssertEquals('OnChange should not be triggered for non-existent name removal', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('name2');
  AssertEquals('Count should be 0 after removing last Tool', 0, FRegistry.Count);
  AssertNull('Tool2 should no longer be findable', FRegistry.Find('name2'));
  AssertEquals('OnChange should be triggered twice after Remove by name', 2, FOnChangeTriggeredCount);
end;

procedure TMCPToolRegistryTest.TestRemoveToolByObject;
var
  Tool1, Tool2: TMCPTool;
  NonAddedTool: TMCPTool;
begin
  Tool1:=TMCPEmptyTool.Create('name1', 'Title1');
  Tool2:=TMCPEmptyTool.Create('name2', 'Title2');
  FRegistry.Add(Tool1);
  FRegistry.Add(Tool2);
  FOnChangeTriggeredCount:=0;
  FRegistry.Remove(Tool1);
  AssertEquals('Count should be 1 after removing Tool by object', 1, FRegistry.Count);
  AssertNull('Tool1 should no longer be findable', FRegistry.Find('name1'));
  AssertEquals('OnChange should be triggered once after Remove by object', 1, FOnChangeTriggeredCount);
  NonAddedTool:=TMCPEmptyTool.Create('name3', 'name3');
  try
    FRegistry.Remove(NonAddedTool);
    AssertEquals('Count should remain 1 after removing non-added object', 1, FRegistry.Count);
    AssertEquals('OnChange should not be triggered for non-added object removal', 1, FOnChangeTriggeredCount);
  finally
    NonAddedTool.Free; // Must free manually as registry didn't own it
  end;
  FRegistry.Remove(Tool2);
  AssertEquals('Count should be 0 after removing last Tool by object', 0, FRegistry.Count);
  AssertNull('Tool2 should no longer be findable', FRegistry.Find('name2'));
  AssertEquals('OnChange should be triggered twice after Remove by object', 2, FOnChangeTriggeredCount);
end;

procedure TMCPToolRegistryTest.TestFindTool;
var
  Tool1, FoundTool: TMCPTool;
begin
  Tool1:=TMCPEmptyTool.Create('find_name', 'find_name');
  FRegistry.Add(Tool1);
  FoundTool:=FRegistry.Find('find_name');
  AssertNotNull('Find should return a Tool for existing name', FoundTool);
  AssertSame('Found Tool should be the correct instance', Tool1, FoundTool);
  FoundTool:=FRegistry.Find('non_existent_name');
  AssertNull('Find should return nil for non-existent name', FoundTool);
end;

procedure TMCPToolRegistryTest.TestGetTool;
var
  Tool1, GotTool: TMCPTool;
begin
  Tool1:=TMCPEmptyTool.Create('get_name', 'get_name');
  FRegistry.Add(Tool1);
  GotTool:=FRegistry.Get('get_name');
  AssertNotNull('Get should return a Tool for existing name', GotTool);
  AssertSame('Got Tool should be the correct instance', Tool1, GotTool);
  try
    FRegistry.Get('non_existent_name');
    Fail('Expected EMCPException for non-existent Tool but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for unknown Tool', Format(SErrUnknownTool, ['non_existent_name']), E.Message);
  end;
end;

procedure TMCPToolRegistryTest.TestLockListTFPList;
var
  Tool1, Tool2, Tool3: TMCPTool;
  LockedList: TFPList;
  ToolNew: TMCPTool;

begin
  Tool1:=TMCPEmptyTool.Create('lock_name1', 'lock_Title1');
  Tool2:=TMCPEmptyTool.Create('lock_name2', 'lock_Title2');
  Tool3:=TMCPEmptyTool.Create('lock_name3', 'lock_name3');
  FRegistry.Add(Tool1);
  FRegistry.Add(Tool2);
  FRegistry.Add(Tool3);
  LockedList:=TFPList.Create;
  try
    FRegistry.LockList(LockedList);
    AssertEquals('LockedList should have the same count as registry', FRegistry.Count, LockedList.Count);
    AssertTrue('LockedList should contain Tool1', LockedList.IndexOf(Tool1) <> -1);
    AssertTrue('LockedList should contain Tool2', LockedList.IndexOf(Tool2) <> -1);
    AssertTrue('LockedList should contain Tool3', LockedList.IndexOf(Tool3) <> -1);
    ToolNew:=TMCPEmptyTool.Create('lock_name_new', 'lock_name_new');
    FRegistry.Add(ToolNew);
    AssertFalse('LockedList should not contain newly added Tool', LockedList.IndexOf(ToolNew) <> -1);
    AssertEquals('Registry count should increase', 4, FRegistry.Count);
    AssertEquals('LockedList count should remain the same', 3, LockedList.Count);
  finally
    LockedList.Free;
    FRegistry.UnlockList;
  end;
end;

procedure TMCPToolRegistryTest.TestLockListTMCPToolArray;
var
  Res, Tool1, Tool2: TMCPTool;
  ToolNew: TMCPTool;
  LockedArray: TMCPToolArray;
  FoundCount: Integer;
begin
  LockedArray:=[];
  Tool1:=TMCPEmptyTool.Create('array_name1', 'array_Title1');
  Tool2:=TMCPEmptyTool.Create('array_name2', 'array_Title2');
  FRegistry.Add(Tool1);
  FRegistry.Add(Tool2);
  FRegistry.LockList(LockedArray);
  AssertEquals('LockedArray should have the same count as registry', FRegistry.Count, Length(LockedArray));
  FoundCount:=0;
  for Res in LockedArray do
  begin
    if (Res = Tool1) or (Res = Tool2) then
      Inc(FoundCount);
  end;
  AssertEquals('LockedArray should contain all added Tools', 2, FoundCount);
  ToolNew:=TMCPEmptyTool.Create('array_name_new', 'array_name_new');
  FRegistry.Add(ToolNew);
  AssertEquals('Registry count should increase', 3, FRegistry.Count);
  AssertEquals('LockedArray length should remain the same', 2, Length(LockedArray));
  FRegistry.UnlockList;
end;

procedure TMCPToolRegistryTest.TestOnChangeEvent;
var
  Tool: TMCPTool;
  ToolNew: TMCPTool;
begin
  AssertEquals('Initial OnChange count should be 0', 0, FOnChangeTriggeredCount);
  Tool:=TMCPEmptyTool.Create('event_name1', 'event_Title1');
  FRegistry.Add(Tool);
  AssertEquals('OnChange should trigger on Add', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('event_name1');
  AssertEquals('OnChange should trigger on Remove', 2, FOnChangeTriggeredCount);
  FRegistry.Remove('non_existent_event');
  AssertEquals('OnChange should not trigger on non-existent Remove', 2, FOnChangeTriggeredCount);
  ToolNew:=TMCPEmptyTool.Create('event_name1', 'event_Title1_new');
  FRegistry.Add(ToolNew);
  AssertEquals('OnChange should trigger on replacing existing Tool', 3, FOnChangeTriggeredCount);
end;

Type

  { TTrackedTool }

  TTrackedTool = class(TMCPEmptyTool)
    class var FreedCount : integer;
  public
    destructor Destroy; override;
  end;

  destructor TTrackedTool.Destroy;
  begin
    Inc(FreedCount);
    inherited Destroy;
  end;

procedure TMCPToolRegistryTest.TestToolOwnershipOnAddRemove;
var
  Tool1, Tool2: TMCPTool;
  DummyTool: TMCPTool;
  Tool1New: TTrackedTool;

begin
  TTrackedTool.FreedCount:=0;
  Tool1:=TTrackedTool.Create('owner_name1', 'owner_Title1');
  FRegistry.Add(Tool1);
  Tool2:=TTrackedTool.Create('owner_name2', 'owner_Title2');
  FRegistry.Add(Tool2);
  AssertEquals('No Tools should be freed yet (owned by registry)', 0, TTrackedTool.FreedCount);
  FRegistry.Remove('owner_name1');
  AssertEquals('Tool1 should be freed after removal by name', 1, TTrackedTool.FreedCount);
  FRegistry.Remove(Tool2);
  AssertEquals('Tool2 should be freed after removal by object', 2, TTrackedTool.FreedCount);
  Tool1New:=TTrackedTool.Create('owner_name1', 'owner_Title1_new');
  FRegistry.Add(Tool1New);
  DummyTool:=TTrackedTool.Create('dummy_name', 'dummy_name');
  try
    FRegistry.Remove('dummy_name');
    AssertEquals('DummyTool should not be freed by registry (not added)', 2, TTrackedTool.FreedCount);
  finally
    DummyTool.Free;
    Inc(TTrackedTool.FreedCount);
    AssertEquals('DummyTool should be freed manually', 4, TTrackedTool.FreedCount);
  end;
end;


initialization
  RegisterTest(TMCPToolRegistryTest);
end.
