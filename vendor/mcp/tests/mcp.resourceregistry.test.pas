unit mcp.resourceregistry.test;

{$mode objfpc}{$H+}

interface

uses
  TestRegistry, Classes, SysUtils, fpcunit, fpjson,
  mcp.types,
  mcp.resources;

type

  { TMCPResourceRegistryTest }

  TMCPResourceRegistryTest = class(TTestCase)
  private
    FRegistry: TMCPResourceRegistry;
    FOnChangeTriggeredCount: Integer;
    procedure HandleRegistryChange(Sender: TObject);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSingletonInstance;
    procedure TestInitClassProcedure;
    procedure TestAddResource;
    procedure TestRemoveResourceByURI;
    procedure TestRemoveResourceByObject;
    procedure TestFindResource;
    procedure TestGetResource;
    procedure TestLockListTFPList;
    procedure TestLockListTMCPResourceArray;
    procedure TestOnChangeEvent;
    procedure TestResourceOwnershipOnAddRemove;
  end;

implementation

uses
  mcp.strings,
  TypInfo;

{ TMCPResourceRegistryTest }

procedure TMCPResourceRegistryTest.HandleRegistryChange(Sender: TObject);
begin
  Inc(FOnChangeTriggeredCount);
end;

procedure TMCPResourceRegistryTest.SetUp;
begin
  inherited SetUp;
  TMCPResourceRegistry.Done;
  FRegistry:=TMCPResourceRegistry.Instance;
  FOnChangeTriggeredCount:=0;
  FRegistry.OnChange:=@HandleRegistryChange;
end;

procedure TMCPResourceRegistryTest.TearDown;
begin
  TMCPResourceRegistry.Done;
  FRegistry:=Nil;
  inherited TearDown;
end;

procedure TMCPResourceRegistryTest.TestSingletonInstance;
var
  Instance1, Instance2: TMCPResourceRegistry;
begin
  Instance1:=ResourceRegistry;
  Instance2:=ResourceRegistry;
  AssertSame('ResourceRegistry should return the same instance', Instance1, Instance2);
  AssertSame('Instance should be the one created in SetUp', FRegistry, Instance1);
end;

procedure TMCPResourceRegistryTest.TestInitClassProcedure;
begin
  try
    TMCPResourceRegistry.Init(TMCPResourceRegistry);
    Fail('Expected EMCPException (Registry already instantiated) but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for already instantiated registry', SErrRegistryALreadyInstantiated, E.Message);
  end;
  TMCPResourceRegistry.Done;
  try
    TMCPResourceRegistry.Init(nil);
    Fail('Expected EMCPException (Registry class empty) but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for empty registry class', SErrRegistryClassEmpty, E.Message);
  end;
end;


procedure TMCPResourceRegistryTest.TestAddResource;
var
  Resource1, Resource2: TMCPResource;
   Resource1New: TMCPResource;
begin
  Resource1:=TMCPResource.Create('uri1', 'name1');
  Resource2:=TMCPResource.Create('uri2', 'name2');
  FRegistry.Add(Resource1);
  AssertEquals('Count should be 1 after adding first resource', 1, FRegistry.Count);
  AssertNotNull('Resource1 should be findable by URI', FRegistry.Find('uri1'));
  AssertSame('Resource1 should be the correct instance', Resource1, FRegistry.Find('uri1'));
  AssertEquals('OnChange should be triggered once after Add', 1, FOnChangeTriggeredCount);
  FRegistry.Add(Resource2);
  AssertEquals('Count should be 2 after adding second resource', 2, FRegistry.Count);
  AssertNotNull('Resource2 should be findable by URI', FRegistry.Find('uri2'));
  AssertEquals('OnChange should be triggered twice after Add', 2, FOnChangeTriggeredCount);
  Resource1New:=TMCPResource.Create('uri1', 'name1_new');
  try
    FRegistry.Add(Resource1New);
    Fail('Expected exception for duplicate resource, got none')
  except
    Resource1New.Free;
  end;
end;

procedure TMCPResourceRegistryTest.TestRemoveResourceByURI;
var
  Resource1, Resource2: TMCPResource;
begin
  Resource1:=TMCPResource.Create('uri1', 'name1');
  Resource2:=TMCPResource.Create('uri2', 'name2');
  FRegistry.Add(Resource1);
  FRegistry.Add(Resource2);
  FOnChangeTriggeredCount:=0;
  FRegistry.Remove('uri1');
  AssertEquals('Count should be 1 after removing resource by URI', 1, FRegistry.Count);
  AssertNull('Resource1 should no longer be findable', FRegistry.Find('uri1'));
  AssertEquals('OnChange should be triggered once after Remove by URI', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('nonexistent');
  AssertEquals('Count should remain 1 after removing non-existent URI', 1, FRegistry.Count);
  AssertEquals('OnChange should not be triggered for non-existent URI removal', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('uri2');
  AssertEquals('Count should be 0 after removing last resource', 0, FRegistry.Count);
  AssertNull('Resource2 should no longer be findable', FRegistry.Find('uri2'));
  AssertEquals('OnChange should be triggered twice after Remove by URI', 2, FOnChangeTriggeredCount);
end;

procedure TMCPResourceRegistryTest.TestRemoveResourceByObject;
var
  Resource1, Resource2: TMCPResource;
  NonAddedResource: TMCPResource;
begin
  Resource1:=TMCPResource.Create('uri1', 'name1');
  Resource2:=TMCPResource.Create('uri2', 'name2');
  FRegistry.Add(Resource1);
  FRegistry.Add(Resource2);
  FOnChangeTriggeredCount:=0;
  FRegistry.Remove(Resource1);
  AssertEquals('Count should be 1 after removing resource by object', 1, FRegistry.Count);
  AssertNull('Resource1 should no longer be findable', FRegistry.Find('uri1'));
  AssertEquals('OnChange should be triggered once after Remove by object', 1, FOnChangeTriggeredCount);
  NonAddedResource:=TMCPResource.Create('uri3', 'name3');
  try
    FRegistry.Remove(NonAddedResource);
    AssertEquals('Count should remain 1 after removing non-added object', 1, FRegistry.Count);
    AssertEquals('OnChange should not be triggered for non-added object removal', 1, FOnChangeTriggeredCount);
  finally
    NonAddedResource.Free; // Must free manually as registry didn't own it
  end;
  FRegistry.Remove(Resource2);
  AssertEquals('Count should be 0 after removing last resource by object', 0, FRegistry.Count);
  AssertNull('Resource2 should no longer be findable', FRegistry.Find('uri2'));
  AssertEquals('OnChange should be triggered twice after Remove by object', 2, FOnChangeTriggeredCount);
end;

procedure TMCPResourceRegistryTest.TestFindResource;
var
  Resource1, FoundResource: TMCPResource;
begin
  Resource1:=TMCPResource.Create('find_uri', 'find_name');
  FRegistry.Add(Resource1);
  FoundResource:=FRegistry.Find('find_uri');
  AssertNotNull('Find should return a resource for existing URI', FoundResource);
  AssertSame('Found resource should be the correct instance', Resource1, FoundResource);
  FoundResource:=FRegistry.Find('non_existent_uri');
  AssertNull('Find should return nil for non-existent URI', FoundResource);
end;

procedure TMCPResourceRegistryTest.TestGetResource;
var
  Resource1, GotResource: TMCPResource;
begin
  Resource1:=TMCPResource.Create('get_uri', 'get_name');
  FRegistry.Add(Resource1);
  GotResource:=FRegistry.Get('get_uri');
  AssertNotNull('Get should return a resource for existing URI', GotResource);
  AssertSame('Got resource should be the correct instance', Resource1, GotResource);
  try
    FRegistry.Get('non_existent_uri');
    Fail('Expected EMCPException for non-existent resource but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException message mismatch for unknown resource', Format(SErrUnknownResource, ['non_existent_uri']), E.Message);
  end;
end;

procedure TMCPResourceRegistryTest.TestLockListTFPList;
var
  Resource1, Resource2, Resource3: TMCPResource;
  LockedList: TFPList;
  ResourceNew: TMCPResource;
begin
  Resource1:=TMCPResource.Create('lock_uri1', 'lock_name1');
  Resource2:=TMCPResource.Create('lock_uri2', 'lock_name2');
  Resource3:=TMCPResource.Create('lock_uri3', 'lock_name3');
  FRegistry.Add(Resource1);
  FRegistry.Add(Resource2);
  FRegistry.Add(Resource3);
  LockedList:=TFPList.Create;
  try
    FRegistry.LockList(LockedList);
    AssertEquals('LockedList should have the same count as registry', FRegistry.Count, LockedList.Count);
    AssertTrue('LockedList should contain Resource1', LockedList.IndexOf(Resource1) <> -1);
    AssertTrue('LockedList should contain Resource2', LockedList.IndexOf(Resource2) <> -1);
    AssertTrue('LockedList should contain Resource3', LockedList.IndexOf(Resource3) <> -1);
    ResourceNew:=TMCPResource.Create('lock_uri_new', 'lock_name_new');
    FRegistry.Add(ResourceNew);
    AssertFalse('LockedList should not contain newly added resource', LockedList.IndexOf(ResourceNew) <> -1);
    AssertEquals('Registry count should increase', 4, FRegistry.Count);
    AssertEquals('LockedList count should remain the same', 3, LockedList.Count);
  finally
    LockedList.Free;
    FRegistry.UnlockList;
  end;
end;

procedure TMCPResourceRegistryTest.TestLockListTMCPResourceArray;
var
  Res, Resource1, Resource2: TMCPResource;
  ResourceNew: TMCPResource;
  LockedArray: TMCPResourceArray;
  FoundCount: Integer;
begin
  LockedArray:=[];
  Resource1:=TMCPResource.Create('array_uri1', 'array_name1');
  Resource2:=TMCPResource.Create('array_uri2', 'array_name2');
  FRegistry.Add(Resource1);
  FRegistry.Add(Resource2);
  FRegistry.LockList(LockedArray);
  AssertEquals('LockedArray should have the same count as registry', FRegistry.Count, Length(LockedArray));
  FoundCount:=0;
  for Res in LockedArray do
  begin
    if (Res = Resource1) or (Res = Resource2) then
      Inc(FoundCount);
  end;
  AssertEquals('LockedArray should contain all added resources', 2, FoundCount);
  ResourceNew:=TMCPResource.Create('array_uri_new', 'array_name_new');
  FRegistry.Add(ResourceNew);
  AssertEquals('Registry count should increase', 3, FRegistry.Count);
  AssertEquals('LockedArray length should remain the same', 2, Length(LockedArray));
  FRegistry.UnlockList;
end;

procedure TMCPResourceRegistryTest.TestOnChangeEvent;
var
  Resource: TMCPResource;
  ResourceNew: TMCPResource;
begin
  AssertEquals('Initial OnChange count should be 0', 0, FOnChangeTriggeredCount);
  Resource:=TMCPResource.Create('event_uri1', 'event_name1');
  FRegistry.Add(Resource);
  AssertEquals('OnChange should trigger on Add', 1, FOnChangeTriggeredCount);
  FRegistry.Remove('event_uri1');
  AssertEquals('OnChange should trigger on Remove', 2, FOnChangeTriggeredCount);
  FRegistry.Remove('non_existent_event');
  AssertEquals('OnChange should not trigger on non-existent Remove', 2, FOnChangeTriggeredCount);
  ResourceNew:=TMCPResource.Create('event_uri1', 'event_name1_new');
  FRegistry.Add(ResourceNew);
  AssertEquals('OnChange should trigger on replacing existing resource', 3, FOnChangeTriggeredCount);
end;

Type

  TTrackedResource = class(TMCPResource)
    class var FreedCount : integer;
  public
    destructor Destroy; override;
  end;

  destructor TTrackedResource.Destroy;
  begin
    Inc(FreedCount);
    inherited Destroy;
  end;

procedure TMCPResourceRegistryTest.TestResourceOwnershipOnAddRemove;
var
  Resource1, Resource2: TMCPResource;
  DummyResource: TMCPResource;
  Resource1New: TTrackedResource;
begin
  TTrackedResource.FreedCount:=0;
  Resource1:=TTrackedResource.Create('owner_uri1', 'owner_name1');
  FRegistry.Add(Resource1);
  Resource2:=TTrackedResource.Create('owner_uri2', 'owner_name2');
  FRegistry.Add(Resource2);
  AssertEquals('No resources should be freed yet (owned by registry)', 0, TTrackedResource.FreedCount);
  FRegistry.Remove('owner_uri1');
  AssertEquals('Resource1 should be freed after removal by URI', 1, TTrackedResource.FreedCount);
  FRegistry.Remove(Resource2);
  AssertEquals('Resource2 should be freed after removal by object', 2, TTrackedResource.FreedCount);
  Resource1New:=TTrackedResource.Create('owner_uri1', 'owner_name1_new');
  FRegistry.Add(Resource1New);
  DummyResource:=TTrackedResource.Create('dummy_uri', 'dummy_name');
  try
    FRegistry.Remove('dummy_uri');
    AssertEquals('DummyResource should not be freed by registry (not added)', 2, TTrackedResource.FreedCount);
  finally
    DummyResource.Free;
    Inc(TTrackedResource.FreedCount);
    AssertEquals('DummyResource should be freed manually', 4, TTrackedResource.FreedCount);
  end;
end;


initialization
  RegisterTest(TMCPResourceRegistryTest);
end.
