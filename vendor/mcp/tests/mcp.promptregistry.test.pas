unit mcp.promptregistry.test;

{$mode objfpc}{$H+}

interface

uses
  TestRegistry, Classes, SysUtils, fpcunit, fpjson,
  mcp.types,
  mcp.Prompts;

type
  
  { TMCPEmptyPrompt }

  TMCPEmptyPrompt = class(TMCPPrompt)

  public
    function GetPrompt(aArguments: TStrings): TMCPPromptMessageArray; override;
  end;
  { TMCPPromptRegistryTest }

  TMCPPromptRegistryTest = class(TTestCase)
  private
    FRegistry: TMCPPromptRegistry;
    FOnChangeTriggeredCount: Integer;
    procedure HandleRegistryChange(Sender: TObject);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSingletonInstance;
    procedure TestInitClassProcedure;
    procedure TestAddPrompt;
    procedure TestRemovePromptByname;
    procedure TestRemovePromptByObject;
    procedure TestFindPrompt;
    procedure TestGetPrompt;
    procedure TestLockListTFPList;
    procedure TestLockListTMCPPromptArray;
    procedure TestOnChangeEvent;
    procedure TestPromptOwnershipOnAddRemove;
  end;

implementation

uses
  mcp.strings,
  TypInfo;

{ TMCPEmptyPrompt }

function TMCPEmptyPrompt.GetPrompt(aArguments: TStrings): TMCPPromptMessageArray;
begin
   Result:=[];
end;


{ TMCPPromptRegistryTest }

procedure TMCPPromptRegistryTest.HandleRegistryChange(Sender: TObject);
begin
  Inc(FOnChangeTriggeredCount);
end;

procedure TMCPPromptRegistryTest.SetUp;
begin
  inherited SetUp;
  TMCPPromptRegistry.Done;
  FRegistry:=TMCPPromptRegistry.Instance;
  FOnChangeTriggeredCount:=0;
  FRegistry.OnChange:=@HandleRegistryChange;
end;

procedure TMCPPromptRegistryTest.TearDown;
begin
  TMCPPromptRegistry.Done;
  FRegistry:=Nil;

  inherited TearDown;
end;

procedure TMCPPromptRegistryTest.TestSingletonInstance;
var
  Instance1, Instance2: TMCPPromptRegistry;
begin

  Instance1:=PromptRegistry;
  Instance2:=PromptRegistry;
  AssertSame('PromptRegistry should return the same instance', Instance1, Instance2);
  AssertSame('Instance should be the one created in SetUp', FRegistry, Instance1);
end;

procedure TMCPPromptRegistryTest.TestInitClassProcedure;

begin

  try
    TMCPPromptRegistry.Init(TMCPPromptRegistry);
    Fail('Expected EMCPException (Registry already instantiated) but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for already instantiated registry', SErrRegistryALreadyInstantiated, E.Message);
  end;


  TMCPPromptRegistry.Done;
  try
    TMCPPromptRegistry.Init(nil);
    Fail('Expected EMCPException (Registry class empty) but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for empty registry class', SErrRegistryClassEmpty, E.Message);
  end;

end;


procedure TMCPPromptRegistryTest.TestAddPrompt;
var
  Prompt1, Prompt2: TMCPPrompt;
   Prompt1New: TMCPPrompt;
begin
  Prompt1:=TMCPEmptyPrompt.Create('name1', 'Title1');
  Prompt2:=TMCPEmptyPrompt.Create('name2', 'Title2');

  FRegistry.Add(Prompt1);
  AssertEquals('Count should be 1 after adding first Prompt', 1, FRegistry.Count);
  AssertNotNull('Prompt1 should be findable by name', FRegistry.Find('name1'));
  AssertSame('Prompt1 should be the correct instance', Prompt1, FRegistry.Find('name1'));
  AssertEquals('OnChange should be triggered once after Add', 1, FOnChangeTriggeredCount);

  FRegistry.Add(Prompt2);
  AssertEquals('Count should be 2 after adding second Prompt', 2, FRegistry.Count);
  AssertNotNull('Prompt2 should be findable by name', FRegistry.Find('name2'));
  AssertEquals('OnChange should be triggered twice after Add', 2, FOnChangeTriggeredCount);



  Prompt1New:=TMCPEmptyPrompt.Create('name1', 'Title1_new');
  try
    FRegistry.Add(Prompt1New);
    Fail('Expected exception for duplicate Prompt, got none')
  except
    Prompt1New.Free;
  end;
end;

procedure TMCPPromptRegistryTest.TestRemovePromptByname;
var
  Prompt1, Prompt2: TMCPPrompt;
begin
  Prompt1:=TMCPEmptyPrompt.Create('name1', 'Title1');
  Prompt2:=TMCPEmptyPrompt.Create('name2', 'Title2');
  FRegistry.Add(Prompt1);
  FRegistry.Add(Prompt2);
  FOnChangeTriggeredCount:=0;
  FRegistry.Remove('name1');
  AssertEquals('Count should be 1 after removing Prompt by name', 1, FRegistry.Count);
  AssertNull('Prompt1 should no longer be findable', FRegistry.Find('name1'));
  AssertEquals('OnChange should be triggered once after Remove by name', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('nonexistent');
  AssertEquals('Count should remain 1 after removing non-existent name', 1, FRegistry.Count);
  AssertEquals('OnChange should not be triggered for non-existent name removal', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('name2');
  AssertEquals('Count should be 0 after removing last Prompt', 0, FRegistry.Count);
  AssertNull('Prompt2 should no longer be findable', FRegistry.Find('name2'));
  AssertEquals('OnChange should be triggered twice after Remove by name', 2, FOnChangeTriggeredCount);
end;

procedure TMCPPromptRegistryTest.TestRemovePromptByObject;
var
  Prompt1, Prompt2: TMCPPrompt;
  NonAddedPrompt: TMCPPrompt;
begin
  Prompt1:=TMCPEmptyPrompt.Create('name1', 'Title1');
  Prompt2:=TMCPEmptyPrompt.Create('name2', 'Title2');
  FRegistry.Add(Prompt1);
  FRegistry.Add(Prompt2);
  FOnChangeTriggeredCount:=0;
  FRegistry.Remove(Prompt1);
  AssertEquals('Count should be 1 after removing Prompt by object', 1, FRegistry.Count);
  AssertNull('Prompt1 should no longer be findable', FRegistry.Find('name1'));
  AssertEquals('OnChange should be triggered once after Remove by object', 1, FOnChangeTriggeredCount);
  NonAddedPrompt:=TMCPEmptyPrompt.Create('name3', 'name3');
  try
    FRegistry.Remove(NonAddedPrompt);
    AssertEquals('Count should remain 1 after removing non-added object', 1, FRegistry.Count);
    AssertEquals('OnChange should not be triggered for non-added object removal', 1, FOnChangeTriggeredCount);
  finally
    NonAddedPrompt.Free; // Must free manually as registry didn't own it
  end;
  FRegistry.Remove(Prompt2);
  AssertEquals('Count should be 0 after removing last Prompt by object', 0, FRegistry.Count);
  AssertNull('Prompt2 should no longer be findable', FRegistry.Find('name2'));
  AssertEquals('OnChange should be triggered twice after Remove by object', 2, FOnChangeTriggeredCount);
end;

procedure TMCPPromptRegistryTest.TestFindPrompt;
var
  Prompt1, FoundPrompt: TMCPPrompt;
begin
  Prompt1:=TMCPEmptyPrompt.Create('find_name', 'find_name');
  FRegistry.Add(Prompt1);
  FoundPrompt:=FRegistry.Find('find_name');
  AssertNotNull('Find should return a Prompt for existing name', FoundPrompt);
  AssertSame('Found Prompt should be the correct instance', Prompt1, FoundPrompt);
  FoundPrompt:=FRegistry.Find('non_existent_name');
  AssertNull('Find should return nil for non-existent name', FoundPrompt);
end;

procedure TMCPPromptRegistryTest.TestGetPrompt;
var
  Prompt1, GotPrompt: TMCPPrompt;
begin
  Prompt1:=TMCPEmptyPrompt.Create('get_name', 'get_name');
  FRegistry.Add(Prompt1);
  GotPrompt:=FRegistry.Get('get_name');
  AssertNotNull('Get should return a Prompt for existing name', GotPrompt);
  AssertSame('Got Prompt should be the correct instance', Prompt1, GotPrompt);
  try
    FRegistry.Get('non_existent_name');
    Fail('Expected EMCPException for non-existent Prompt but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for unknown Prompt', Format(SErrUnknownPrompt, ['non_existent_name']), E.Message);
  end;
end;

procedure TMCPPromptRegistryTest.TestLockListTFPList;
var
  Prompt1, Prompt2, Prompt3: TMCPPrompt;
  LockedList: TFPList;
  PromptNew: TMCPPrompt;

begin
  Prompt1:=TMCPEmptyPrompt.Create('lock_name1', 'lock_Title1');
  Prompt2:=TMCPEmptyPrompt.Create('lock_name2', 'lock_Title2');
  Prompt3:=TMCPEmptyPrompt.Create('lock_name3', 'lock_name3');
  FRegistry.Add(Prompt1);
  FRegistry.Add(Prompt2);
  FRegistry.Add(Prompt3);
  LockedList:=TFPList.Create;
  try
    FRegistry.LockList(LockedList);
    AssertEquals('LockedList should have the same count as registry', FRegistry.Count, LockedList.Count);
    AssertTrue('LockedList should contain Prompt1', LockedList.IndexOf(Prompt1) <> -1);
    AssertTrue('LockedList should contain Prompt2', LockedList.IndexOf(Prompt2) <> -1);
    AssertTrue('LockedList should contain Prompt3', LockedList.IndexOf(Prompt3) <> -1);
    PromptNew:=TMCPEmptyPrompt.Create('lock_name_new', 'lock_name_new');
    FRegistry.Add(PromptNew);
    AssertFalse('LockedList should not contain newly added Prompt', LockedList.IndexOf(PromptNew) <> -1);
    AssertEquals('Registry count should increase', 4, FRegistry.Count);
    AssertEquals('LockedList count should remain the same', 3, LockedList.Count);
  finally
    LockedList.Free;
    FRegistry.UnlockList;
  end;
end;

procedure TMCPPromptRegistryTest.TestLockListTMCPPromptArray;
var
  Res, Prompt1, Prompt2: TMCPPrompt;
  PromptNew: TMCPPrompt;
  LockedArray: TMCPPromptArray;
  FoundCount: Integer;
begin
  LockedArray:=[];
  Prompt1:=TMCPEmptyPrompt.Create('array_name1', 'array_Title1');
  Prompt2:=TMCPEmptyPrompt.Create('array_name2', 'array_Title2');
  FRegistry.Add(Prompt1);
  FRegistry.Add(Prompt2);
  FRegistry.LockList(LockedArray);
  AssertEquals('LockedArray should have the same count as registry', FRegistry.Count, Length(LockedArray));
  FoundCount:=0;
  for Res in LockedArray do
  begin
    if (Res = Prompt1) or (Res = Prompt2) then
      Inc(FoundCount);
  end;
  AssertEquals('LockedArray should contain all added Prompts', 2, FoundCount);
  PromptNew:=TMCPEmptyPrompt.Create('array_name_new', 'array_name_new');
  FRegistry.Add(PromptNew);
  AssertEquals('Registry count should increase', 3, FRegistry.Count);
  AssertEquals('LockedArray length should remain the same', 2, Length(LockedArray));
  FRegistry.UnlockList;
end;

procedure TMCPPromptRegistryTest.TestOnChangeEvent;
var
  Prompt: TMCPPrompt;
  PromptNew: TMCPPrompt;
begin
  AssertEquals('Initial OnChange count should be 0', 0, FOnChangeTriggeredCount);
  Prompt:=TMCPEmptyPrompt.Create('event_name1', 'event_Title1');
  FRegistry.Add(Prompt);
  AssertEquals('OnChange should trigger on Add', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('event_name1');
  AssertEquals('OnChange should trigger on Remove', 2, FOnChangeTriggeredCount);
  FRegistry.Remove('non_existent_event');
  AssertEquals('OnChange should not trigger on non-existent Remove', 2, FOnChangeTriggeredCount);
  PromptNew:=TMCPEmptyPrompt.Create('event_name1', 'event_Title1_new');
  FRegistry.Add(PromptNew);
  AssertEquals('OnChange should trigger on replacing existing Prompt', 3, FOnChangeTriggeredCount);
end;

Type

  { TTrackedPrompt }

  TTrackedPrompt = class(TMCPPrompt)
    class var FreedCount : integer;
  public
    function GetPrompt(aArguments: TStrings): TMCPPromptMessageArray; override;
    destructor Destroy; override;
  end;

  function TTrackedPrompt.GetPrompt(aArguments: TStrings): TMCPPromptMessageArray;
  begin
    Result:=[];
  end;

  destructor TTrackedPrompt.Destroy;
  begin
    Inc(FreedCount);
    inherited Destroy;
  end;

procedure TMCPPromptRegistryTest.TestPromptOwnershipOnAddRemove;
var
  Prompt1, Prompt2: TMCPPrompt;
  DummyPrompt: TMCPPrompt;
  Prompt1New: TTrackedPrompt;

begin
  TTrackedPrompt.FreedCount:=0;
  Prompt1:=TTrackedPrompt.Create('owner_name1', 'owner_Title1');
  FRegistry.Add(Prompt1);
  Prompt2:=TTrackedPrompt.Create('owner_name2', 'owner_Title2');
  FRegistry.Add(Prompt2);
  AssertEquals('No Prompts should be freed yet (owned by registry)', 0, TTrackedPrompt.FreedCount);
  FRegistry.Remove('owner_name1');
  AssertEquals('Prompt1 should be freed after removal by name', 1, TTrackedPrompt.FreedCount);
  FRegistry.Remove(Prompt2);
  AssertEquals('Prompt2 should be freed after removal by object', 2, TTrackedPrompt.FreedCount);
  Prompt1New:=TTrackedPrompt.Create('owner_name1', 'owner_Title1_new');
  FRegistry.Add(Prompt1New);
  DummyPrompt:=TTrackedPrompt.Create('dummy_name', 'dummy_name');
  try
    FRegistry.Remove('dummy_name');
    AssertEquals('DummyPrompt should not be freed by registry (not added)', 2, TTrackedPrompt.FreedCount);
  finally
    DummyPrompt.Free;
    Inc(TTrackedPrompt.FreedCount);
    AssertEquals('DummyPrompt should be freed manually', 4, TTrackedPrompt.FreedCount);
  end;
end;


initialization
  RegisterTest(TMCPPromptRegistryTest);
end.
