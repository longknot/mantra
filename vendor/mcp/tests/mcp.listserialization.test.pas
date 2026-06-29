unit mcp.listserialization.test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, mcp.types;

type
  TListSerializationTest = class(TTestCase)
  private
    FToolList: TMCPToolInfoList;
    FPromptList: TMCPPromptInfoArray;
    FResourceList: TMCPResourceInfoArray;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestToolInfoListToJSON;
    procedure TestToolInfoListFromJSON;
    procedure TestToolInfoListRoundTrip;
    procedure TestPromptInfoListToJSON;
    procedure TestPromptInfoListFromJSON;
    procedure TestPromptInfoListRoundTrip;
    procedure TestResourceInfoListToJSON;
    procedure TestResourceInfoListFromJSON;
    procedure TestResourceInfoListRoundTrip;
    procedure TestEmptyListSerialization;
    procedure TestNullJSONHandling;
  end;

implementation

procedure TListSerializationTest.SetUp;
begin
  inherited SetUp;
  FToolList := TMCPToolInfoList.Create(True);
  FPromptList := [];
  FResourceList := [];
end;

procedure TListSerializationTest.TearDown;
begin
  FToolList.Free;
  inherited TearDown;
end;

procedure TListSerializationTest.TestToolInfoListToJSON;
var
  Tool1, Tool2: TMCPToolInfo;
  JSONArr: TJSONArray;
begin
  Tool1 := TMCPToolInfo.Create('test-tool-1', 'First test tool');
  Tool2 := TMCPToolInfo.Create('test-tool-2', 'Second test tool');

  FToolList.Add(Tool1);
  FToolList.Add(Tool2);

  JSONArr := FToolList.ToJSON;
  try
    AssertEquals('Should have 2 items', 2, JSONArr.Count);
    AssertTrue('First item should be JSON object', JSONArr[0] is TJSONObject);
    AssertTrue('Second item should be JSON object', JSONArr[1] is TJSONObject);

    AssertEquals('First tool name', 'test-tool-1', TJSONObject(JSONArr[0]).Get('name', ''));
    AssertEquals('Second tool name', 'test-tool-2', TJSONObject(JSONArr[1]).Get('name', ''));
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestToolInfoListFromJSON;
var
  JSONArr: TJSONArray;
  Tool1, Tool2: TJSONObject;
begin
  JSONArr := TJSONArray.Create;
  try
    Tool1 := TJSONObject.Create;
    Tool1.Add('name', 'imported-tool-1');
    Tool1.Add('description', 'First imported tool');
    JSONArr.Add(Tool1);

    Tool2 := TJSONObject.Create;
    Tool2.Add('name', 'imported-tool-2');
    Tool2.Add('description', 'Second imported tool');
    JSONArr.Add(Tool2);

    FToolList.FromJSON(JSONArr);

    AssertEquals('Should have 2 tools', 2, FToolList.Count);
    AssertEquals('First tool name', 'imported-tool-1', FToolList[0].Name);
    AssertEquals('Second tool name', 'imported-tool-2', FToolList[1].Name);
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestToolInfoListRoundTrip;
var
  Tool1, Tool2: TMCPToolInfo;
  JSONArr: TJSONArray;
  NewList: TMCPToolInfoList;
begin
  Tool1 := TMCPToolInfo.Create('roundtrip-tool-1', 'First roundtrip tool');
  Tool2 := TMCPToolInfo.Create('roundtrip-tool-2', 'Second roundtrip tool');

  FToolList.Add(Tool1);
  FToolList.Add(Tool2);

  JSONArr := FToolList.ToJSON;
  try
    NewList := TMCPToolInfoList.Create(True);
    try
      NewList.FromJSON(JSONArr);

      AssertEquals('Original and new list should have same count', FToolList.Count, NewList.Count);
      AssertEquals('First tool name should match', FToolList[0].Name, NewList[0].Name);
      AssertEquals('Second tool name should match', FToolList[1].Name, NewList[1].Name);
    finally
      NewList.Free;
    end;
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestPromptInfoListToJSON;
var
  Prompt1, Prompt2: TMCPPromptInfo;
  JSONArr: TJSONArray;
begin
  Prompt1 := TMCPPromptInfo.Create('test-prompt-1', 'Test Prompt 1', 'First test prompt');
  Prompt2 := TMCPPromptInfo.Create('test-prompt-2', 'Test Prompt 2', 'Second test prompt');

  SetLength(FPromptList,2);
  FPromptList[0]:=Prompt1;
  FPromptList[1]:=Prompt2;

  JSONArr := FPromptList.ToJSON;
  try
    AssertEquals('Should have 2 items', 2, JSONArr.Count);
    AssertEquals('First prompt name', 'test-prompt-1', TJSONObject(JSONArr[0]).Get('name', ''));
    AssertEquals('Second prompt name', 'test-prompt-2', TJSONObject(JSONArr[1]).Get('name', ''));
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestPromptInfoListFromJSON;
var
  JSONArr: TJSONArray;
  Prompt1, Prompt2: TJSONObject;
begin
  JSONArr := TJSONArray.Create;
  try
    Prompt1 := TJSONObject.Create;
    Prompt1.Add('name', 'imported-prompt-1');
    Prompt1.Add('title', 'Imported Prompt 1');
    Prompt1.Add('description', 'First imported prompt');
    JSONArr.Add(Prompt1);

    Prompt2 := TJSONObject.Create;
    Prompt2.Add('name', 'imported-prompt-2');
    Prompt2.Add('title', 'Imported Prompt 2');
    Prompt2.Add('description', 'Second imported prompt');
    JSONArr.Add(Prompt2);

    FPromptList.FromJSON(JSONArr);

    AssertEquals('Should have 2 prompts', 2, FPromptList.Count);
    AssertEquals('First prompt name', 'imported-prompt-1', FPromptList[0].Name);
    AssertEquals('Second prompt name', 'imported-prompt-2', FPromptList[1].Name);
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestPromptInfoListRoundTrip;
var
  Prompt1, Prompt2: TMCPPromptInfo;
  JSONArr: TJSONArray;
  NewList: TMCPPromptInfoArray;
begin
  Prompt1 := TMCPPromptInfo.Create('roundtrip-prompt-1', 'Roundtrip Prompt 1', 'First roundtrip prompt');
  Prompt2 := TMCPPromptInfo.Create('roundtrip-prompt-2', 'Roundtrip Prompt 2', 'Second roundtrip prompt');
  SetLength(FPromptList,2);
  FPromptList[0]:=Prompt1;
  FPromptList[1]:=Prompt2;

  JSONArr := FPromptList.ToJSON;
  try
    NewList := [];
    NewList.FromJSON(JSONArr);
    AssertEquals('Original and new list should have same count', FPromptList.Count, NewList.Count);
    AssertEquals('First prompt name should match', FPromptList[0].Name, NewList[0].Name);
    AssertEquals('Second prompt name should match', FPromptList[1].Name, NewList[1].Name);
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestResourceInfoListToJSON;
var
  Resource1, Resource2: TMCPResourceInfo;
  JSONArr: TJSONArray;
begin
  Resource1 := TMCPResourceInfo.Create('file://test1.txt', 'Test Resource 1');
  Resource1.Description := 'First test resource';
  Resource2 := TMCPResourceInfo.Create('file://test2.txt', 'Test Resource 2');
  Resource2.Description := 'Second test resource';
  SetLength(FResourceList,2);
  FResourceList[0]:=Resource1;
  FResourceList[1]:=Resource2;

  JSONArr := FResourceList.ToJSON;
  try
    AssertEquals('Should have 2 items', 2, JSONArr.Count);
    AssertEquals('First resource URI', 'file://test1.txt', TJSONObject(JSONArr[0]).Get('uri', ''));
    AssertEquals('Second resource URI', 'file://test2.txt', TJSONObject(JSONArr[1]).Get('uri', ''));
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestResourceInfoListFromJSON;
var
  JSONArr: TJSONArray;
  Resource1, Resource2: TJSONObject;
begin
  JSONArr := TJSONArray.Create;
  try
    Resource1 := TJSONObject.Create;
    Resource1.Add('uri', 'file://imported1.txt');
    Resource1.Add('name', 'Imported Resource 1');
    Resource1.Add('description', 'First imported resource');
    JSONArr.Add(Resource1);

    Resource2 := TJSONObject.Create;
    Resource2.Add('uri', 'file://imported2.txt');
    Resource2.Add('name', 'Imported Resource 2');
    Resource2.Add('description', 'Second imported resource');
    JSONArr.Add(Resource2);

    FResourceList.FromJSON(JSONArr);

    AssertEquals('Should have 2 resources', 2, FResourceList.Count);
    AssertEquals('First resource URI', 'file://imported1.txt', FResourceList[0].URI);
    AssertEquals('Second resource URI', 'file://imported2.txt', FResourceList[1].URI);
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestResourceInfoListRoundTrip;
var
  Resource1, Resource2: TMCPResourceInfo;
  JSONArr: TJSONArray;
  NewList: TMCPResourceInfoArray;
begin
  Resource1 := TMCPResourceInfo.Create('file://roundtrip1.txt', 'Roundtrip Resource 1');
  Resource1.Description := 'First roundtrip resource';
  Resource2 := TMCPResourceInfo.Create('file://roundtrip2.txt', 'Roundtrip Resource 2');
  Resource2.Description := 'Second roundtrip resource';
  SetLength(FResourceList,2);
  FResourceList[0]:=Resource1;
  FResourceList[1]:=Resource2;

  JSONArr := FResourceList.ToJSON;
  try
    NewList := [];
    NewList.FromJSON(JSONArr);

    AssertEquals('Original and new list should have same count', FResourceList.Count, NewList.Count);
    AssertEquals('First resource URI should match', FResourceList[0].URI, NewList[0].URI);
    AssertEquals('Second resource URI should match', FResourceList[1].URI, NewList[1].URI);
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestEmptyListSerialization;
var
  JSONArr: TJSONArray;
begin
  JSONArr := FToolList.ToJSON;
  try
    AssertEquals('Empty list should produce empty JSON array', 0, JSONArr.Count);
  finally
    JSONArr.Free;
  end;

  JSONArr := FPromptList.ToJSON;
  try
    AssertEquals('Empty prompt list should produce empty JSON array', 0, JSONArr.Count);
  finally
    JSONArr.Free;
  end;

  JSONArr := FResourceList.ToJSON;
  try
    AssertEquals('Empty resource list should produce empty JSON array', 0, JSONArr.Count);
  finally
    JSONArr.Free;
  end;
end;

procedure TListSerializationTest.TestNullJSONHandling;
begin
  FToolList.FromJSON(nil);
  AssertEquals('FromJSON with nil should not crash and leave list empty', 0, FToolList.Count);

  FPromptList.FromJSON(nil);
  AssertEquals('FromJSON with nil should not crash and leave prompt list empty', 0, FPromptList.Count);

  FResourceList.FromJSON(nil);
  AssertEquals('FromJSON with nil should not crash and leave resource list empty', 0, FResourceList.Count);
end;

initialization
  RegisterTest(TListSerializationTest);

end.
