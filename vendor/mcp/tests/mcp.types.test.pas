unit mcp.types.test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, fpjson, testregistry, mcp.types, dateutils; // Added dateutils for ISO date functions

type

  { TMCPTypesTest }

  TMCPTypesTest = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure AssertEquals(const Msg : string; aExpected,aActual : TMCPPromptKind); overload;
    procedure AssertEquals(const Msg : string; aExpected,aActual : TMCPRole); overload;
    procedure AssertEquals(const Msg : string; aExpected,aActual : TMCPRoles); overload;
  published
    procedure TestTMCPPromptKindHelper;
    procedure TestTMCPRoleHelper;
    procedure TestTMCPAnnotation;
    procedure TestTMCPSchema;
  end;

  { TMCPToolInfoTest }

  TMCPToolInfoTest = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestToJSONWithMinimalData;
    procedure TestToJSONWithFullData;
    procedure TestToJSONWithAnnotations;
    procedure TestToJSONWithInputSchema;
    procedure TestToJSONWithMeta;
    procedure TestToJSONProcedureVersion;
    procedure TestCreateAndDestroy;
    procedure TestPropertyAccess;
    procedure TestFromJSONWithMinimalData;
    procedure TestFromJSONWithFullData;
    procedure TestFromJSONWithAnnotations;
    procedure TestFromJSONWithInputSchema;
    procedure TestFromJSONWithMissingFields;
    procedure TestFromJSONWithNilParameter;
    procedure TestRoundTripSerialization;
  end;

  { TMCPResourceInfoTest }

  TMCPResourceInfoTest = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure AssertEquals(const Msg: string; aExpected, aActual: TMCPResourceKind); overload;
  published
    procedure TestToJSONWithMinimalData;
    procedure TestToJSONWithTextData;
    procedure TestToJSONWithBinaryData;
    procedure TestToJSONWithoutData;
    procedure TestToJSONProcedureVersion;
    procedure TestCreateAndDestroy;
    procedure TestPropertyAccess;
    procedure TestFromJSONWithMinimalData;
    procedure TestFromJSONWithTextData;
    procedure TestFromJSONWithBinaryData;
    procedure TestFromJSONWithMissingFields;
    procedure TestFromJSONWithNilParameter;
    procedure TestRoundTripSerialization;
    procedure TestKindDetermination;
    procedure TestSizeCalculation;
    procedure TestUriValidation;
  end;

implementation

uses typinfo;

{ TMCPTypesTest }

procedure TMCPTypesTest.SetUp;
begin
  inherited SetUp;
end;

procedure TMCPTypesTest.TearDown;
begin
  inherited TearDown;
end;

procedure TMCPTypesTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPPromptKind);
begin
  AssertEquals(Msg,GetEnumName(TypeInfo(TMCPPromptKind),ord(aExpected)),
                   GetEnumName(TypeInfo(TMCPPromptKind),ord(aActual)));
end;

procedure TMCPTypesTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPRole);
begin
  AssertEquals(Msg,GetEnumName(TypeInfo(TMCPRole),ord(aExpected)),
                   GetEnumName(TypeInfo(TMCPRole),ord(aActual)));
end;

procedure TMCPTypesTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPRoles);
begin
  AssertEquals(Msg,SetToString(PTypeInfo(TypeInfo(TMCPRoles)),Integer(aExpected),True),
                   SetToString(PTypeInfo(TypeInfo(TMCPRoles)),Integer(aActual),True));
end;

procedure TMCPTypesTest.TestTMCPPromptKindHelper;
var
  Kind: TMCPPromptKind;
begin
  // Test ToString
  Kind := pkText;
  AssertEquals('TMCPPromptKindHelper.ToString (pkText) failed', 'text', Kind.AsString);

  Kind := pkImage;
  AssertEquals('TMCPPromptKindHelper.ToString (pkImage) failed', 'image', Kind.AsString);

  Kind := pkEmbeddedResource;
  AssertEquals('TMCPPromptKindHelper.ToString (pkEmbeddedResource) failed', 'resource', Kind.AsString);

  // Test SetAsString
  Kind := pkText;
  Kind.AsString := 'image';
  AssertEquals('TMCPPromptKindHelper.SetAsString (image) failed', pkImage, Kind);

  Kind := pkAudio;
  Kind.AsString := 'resource';
  AssertEquals('TMCPPromptKindHelper.SetAsString (resource) failed', pkEmbeddedResource, Kind);
end;

procedure TMCPTypesTest.TestTMCPRoleHelper;
var
  Role: TMCPRole;
begin
  // Test ToString
  Role := prUser;
  AssertEquals('TMCPRoleHelper.ToString (prUser) failed', 'user', Role.AsString);

  Role := prAssistant;
  AssertEquals('TMCPRoleHelper.ToString (prAssistant) failed', 'assistant', Role.AsString);

  // Test SetAsString
  Role := prUser;
  Role.AsString := 'assistant';
  AssertEquals('TMCPRoleHelper.SetAsString (assistant) failed', prAssistant, Role);

  Role := prAssistant;
  Role.AsString := 'user';
  AssertEquals('TMCPRoleHelper.SetAsString (user) failed', prUser, Role);

  // Test invalid role (should raise exception)
  try
    Role.AsString := 'invalid';
    Fail('Expected EMCPException for invalid role but none was raised');
  except
    on E: EMCPException do
      AssertEquals('EMCPException for invalid role message mismatch', 'Invalid role: invalid', E.Message);
  end;
end;

procedure TMCPTypesTest.TestTMCPAnnotation;
var
  Annotation, LoadedAnnotation: TMCPAnnotation;
  JSON: TJSONObject;
  RolesArray: TJSONArray;
  TestDate: TDateTime;
begin
  // Test Initialize (class operator)
  Initialize(Annotation);
  AssertFalse('Annotation should not be initialized after default initialize', Annotation.Initialized);
  AssertEquals('LastModified should be 0 after initialize', 0, Annotation.LastModified);
  AssertEquals('Roles should be empty after initialize', [], Annotation.Roles);
  AssertFalse('Priority should be false after initialize', Annotation.Priority);


  // Test Setters and Initialized property
  Initialize(Annotation);
  Annotation.Priority := True;
  AssertTrue('Initialized should be true after setting priority', Annotation.Initialized);
  AssertTrue('Priority should be true', Annotation.Priority);

  TestDate := Now; // Capture current time for comparison
  Annotation.LastModified := TestDate;
  AssertTrue('Initialized should be true after setting LastModified', Annotation.Initialized);
  // Compare ISO8601 strings for TDateTime due to potential floating point inaccuracies
  AssertEquals('LastModified should be set', DateToISO8601(TestDate), DateToISO8601(Annotation.LastModified));

  Annotation.Roles:=Annotation.Roles+[prUser];
  AssertTrue('Initialized should be true after setting Roles', Annotation.Initialized);
  AssertTrue('Roles should include prUser', prUser in Annotation.Roles);

  // Test ToJSON (function) and ToJSON (procedure)
  JSON := Annotation.ToJSON;
  AssertNotNull('ToJSON function should return a JSON object', JSON);
  try
    AssertEquals('JSON priority should be 1', 1, JSON.Get('priority', 0));
    AssertTrue('JSON should contain lastModified', JSON.IndexOfName('lastModified')<>-1);
    AssertTrue('JSON should contain roles', JSON.IndexOfName('roles')<>-1);

    RolesArray := JSON.Get('roles',TJSONArray(Nil));
    AssertNotNull('Roles in JSON should be a JSONArray', RolesArray);
    AssertEquals('Roles array should have 1 item', 1, RolesArray.Count);
    AssertEquals('Role in JSON should be "user"', 'user', RolesArray.Items[0].AsString);
  finally
    JSON.Free;
  end;

  // Test FromJSON
  Initialize(LoadedAnnotation);
  JSON := TJSONObject.Create;
  try
    JSON.Add('priority', 0);
    JSON.Add('lastModified', DateToISO8601(EncodeDate(2023, 1, 1)));
    RolesArray := TJSONArray.Create;
    RolesArray.Add('assistant');
    JSON.Add('roles', RolesArray);

    LoadedAnnotation.FromJSON(JSON);
    AssertTrue('LoadedAnnotation should be initialized from JSON', LoadedAnnotation.Initialized);
    AssertFalse('LoadedAnnotation priority should be false', LoadedAnnotation.Priority);
    AssertEquals('LoadedAnnotation LastModified should match', EncodeDate(2023, 1, 1), LoadedAnnotation.LastModified);
    AssertTrue('LoadedAnnotation roles should include prAssistant', prAssistant in LoadedAnnotation.Roles);
    AssertTrue('LoadedAnnotation roles should have 1 member', LoadedAnnotation.Roles=[prAssistant]);
  finally
    JSON.Free;
  end;
end;

procedure TMCPTypesTest.TestTMCPSchema;
var
  Schema: TMCPSchema;
  ArgumentSchema: TJSONObject;
  JSON: TJSONObject;
  RequiredArray: TJSONArray;
  PropertiesObject: TJSONObject;
begin
  Schema := TMCPSchema.Create;
  try
    // Test AddArgument
    ArgumentSchema := TJSONObject.Create;
    ArgumentSchema.Add('type', 'string');
    Schema.AddArgument('param1', ArgumentSchema); // Added as required by default
    AssertNotNull('Argument param1 should exist', Schema.Arguments['param1']);
    AssertEquals('param1 type should be string', 'string', (Schema.Arguments['param1'] as TJSONObject).Get('type',''));
    AssertEquals('Required count should be 1', 1, Length(Schema.Required));
    AssertEquals('param1 should be in Required', 'param1', Schema.Required[0]);

    ArgumentSchema := TJSONObject.Create;
    ArgumentSchema.Add('type', 'integer');
    Schema.AddArgument('param2', ArgumentSchema, False); // Not required
    AssertNotNull('Argument param2 should exist', Schema.Arguments['param2']);
    AssertEquals('Required count should still be 1', 1, Length(Schema.Required)); // param2 is not required

    // Test ToJSON
    JSON := Schema.ToJSON;
    AssertNotNull('ToJSON should return a JSON object', JSON);
    try
      AssertEquals('JSON type should be object', 'object', JSON.Get('type',''));
      AssertTrue('JSON should contain properties', JSON.IndexOfName('properties')<>-1);
      AssertTrue('JSON should contain required', JSON.IndexOfName('required')<>-1);

      PropertiesObject := JSON.Get('properties',TJSONObject(Nil));
      AssertNotNull('Properties should be a JSON object', PropertiesObject);
      AssertTrue('Properties should contain param1', PropertiesObject.IndexOfName('param1')<>-1);
      AssertTrue('Properties should contain param2', PropertiesObject.IndexOfName('param2')<>-1);
      AssertEquals('param1 type in JSON', 'string', PropertiesObject.Get('param1',TJSONObject(Nil)).Get('type',''));
      AssertEquals('param2 type in JSON', 'integer', PropertiesObject.Get('param2',TJSONObject(Nil)).Get('type',''));

      RequiredArray := JSON.Get('required',TJSONArray(Nil));
      AssertNotNull('Required should be a JSON array', RequiredArray);
      AssertEquals('Required array count should be 1', 1, RequiredArray.Count);
      AssertEquals('Required array should contain param1', 'param1', RequiredArray.Items[0].AsString);

    finally
      JSON.Free;
    end;
  finally
    Schema.Free;
  end;
end;

{ TMCPToolInfoTest }

procedure TMCPToolInfoTest.SetUp;
begin
  inherited SetUp;
end;

procedure TMCPToolInfoTest.TearDown;
begin
  inherited TearDown;
end;

procedure TMCPToolInfoTest.TestToJSONWithMinimalData;
var
  ToolInfo: TMCPToolInfo;
  JSON: TJSONObject;
begin
  ToolInfo := TMCPToolInfo.Create('test_tool', 'A test tool');
  try
    JSON := ToolInfo.ToJSON;
    try
      AssertNotNull('ToJSON should return a JSON object', JSON);
      AssertEquals('JSON should contain name', 'test_tool', JSON.Get('name', ''));
      AssertEquals('JSON should contain description', 'A test tool', JSON.Get('description', ''));
      AssertTrue('JSON should contain inputSchema', JSON.IndexOfName('inputSchema') >= 0);
      AssertNotNull('inputSchema should be a JSON object', JSON.Objects['inputSchema']);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestToJSONWithFullData;
var
  ToolInfo: TMCPToolInfo;
  JSON: TJSONObject;
  Annotation: TMCPAnnotation;
  Meta: TJSONObject;
begin
  ToolInfo := TMCPToolInfo.Create('full_tool', 'A full featured tool');
  try
    // Set up annotations
    Annotation := ToolInfo.FAnnotations;
    Annotation.Priority := True;
    Annotation.Roles := [prUser, prAssistant];
    ToolInfo.FAnnotations := Annotation;

    // Set up metadata
    Meta := TJSONObject.Create;
    Meta.Add('version', '1.0');
    Meta.Add('author', 'Test Author');
    ToolInfo._Meta := Meta;

    // Add input schema argument
    ToolInfo.InputSchema.AddArgument('param1', TJSONObject.Create(['type', 'string']));

    JSON := ToolInfo.ToJSON;
    try
      AssertNotNull('ToJSON should return a JSON object', JSON);
      AssertEquals('JSON should contain name', 'full_tool', JSON.Get('name', ''));
      AssertEquals('JSON should contain description', 'A full featured tool', JSON.Get('description', ''));
      AssertTrue('JSON should contain annotations', JSON.IndexOfName('annotations') >= 0);
      AssertTrue('JSON should contain inputSchema', JSON.IndexOfName('inputSchema') >= 0);

      // Verify annotations are present
      AssertNotNull('annotations should be a JSON object', JSON.Objects['annotations']);

      // Verify input schema has the argument
      AssertNotNull('inputSchema should be a JSON object', JSON.Objects['inputSchema']);
      AssertTrue('inputSchema should contain properties', JSON.Objects['inputSchema'].IndexOfName('properties') >= 0);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestToJSONWithAnnotations;
var
  ToolInfo: TMCPToolInfo;
  JSON, AnnotationsJSON: TJSONObject;
  Annotation: TMCPAnnotation;
  RolesArray: TJSONArray;
begin
  ToolInfo := TMCPToolInfo.Create('annotated_tool', 'Tool with annotations');
  try
    // Set up detailed annotations
    Annotation := ToolInfo.FAnnotations;
    Annotation.Priority := True;
    Annotation.Roles := [prUser];
    Annotation.LastModified := EncodeDate(2024, 12, 19);
    ToolInfo.FAnnotations := Annotation;

    JSON := ToolInfo.ToJSON;
    try
      AssertTrue('JSON should contain annotations', JSON.IndexOfName('annotations') >= 0);
      AnnotationsJSON := JSON.Objects['annotations'];
      AssertNotNull('annotations should be a JSON object', AnnotationsJSON);

      AssertEquals('annotations priority should be 1', 1, AnnotationsJSON.Get('priority', 0));
      AssertTrue('annotations should contain lastModified', AnnotationsJSON.IndexOfName('lastModified') >= 0);
      AssertTrue('annotations should contain roles', AnnotationsJSON.IndexOfName('roles') >= 0);

      RolesArray := AnnotationsJSON.Arrays['roles'];
      AssertNotNull('roles should be an array', RolesArray);
      AssertEquals('roles array should have 1 item', 1, RolesArray.Count);
      AssertEquals('role should be user', 'user', RolesArray.Items[0].AsString);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestToJSONWithInputSchema;
var
  ToolInfo: TMCPToolInfo;
  JSON, SchemaJSON, PropertiesJSON: TJSONObject;
  RequiredArray: TJSONArray;
begin
  ToolInfo := TMCPToolInfo.Create('schema_tool', 'Tool with schema');
  try
    // Add multiple arguments to input schema
    ToolInfo.InputSchema.AddArgument('param1', TJSONObject.Create(['type', 'string']), True);
    ToolInfo.InputSchema.AddArgument('param2', TJSONObject.Create(['type', 'integer']), False);

    JSON := ToolInfo.ToJSON;
    try
      AssertTrue('JSON should contain inputSchema', JSON.IndexOfName('inputSchema') >= 0);
      SchemaJSON := JSON.Objects['inputSchema'];
      AssertNotNull('inputSchema should be a JSON object', SchemaJSON);

      AssertEquals('schema type should be object', 'object', SchemaJSON.Get('type', ''));
      AssertTrue('schema should contain properties', SchemaJSON.IndexOfName('properties') >= 0);
      AssertTrue('schema should contain required', SchemaJSON.IndexOfName('required') >= 0);

      PropertiesJSON := SchemaJSON.Objects['properties'];
      AssertNotNull('properties should be a JSON object', PropertiesJSON);
      AssertTrue('properties should contain param1', PropertiesJSON.IndexOfName('param1') >= 0);
      AssertTrue('properties should contain param2', PropertiesJSON.IndexOfName('param2') >= 0);

      RequiredArray := SchemaJSON.Arrays['required'];
      AssertNotNull('required should be an array', RequiredArray);
      AssertEquals('required array should have 1 item', 1, RequiredArray.Count);
      AssertEquals('required should contain param1', 'param1', RequiredArray.Items[0].AsString);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestToJSONWithMeta;
var
  ToolInfo: TMCPToolInfo;
  JSON: TJSONObject;
  Meta: TJSONObject;
begin
  ToolInfo := TMCPToolInfo.Create('meta_tool', 'Tool with metadata');
  try
    // Note: _Meta is not included in ToJSON output by design
    Meta := TJSONObject.Create;
    Meta.Add('version', '2.0');
    Meta.Add('category', 'utility');
    ToolInfo._Meta := Meta;

    JSON := ToolInfo.ToJSON;
    try
      AssertNotNull('ToJSON should return a JSON object', JSON);
      AssertEquals('JSON should contain name', 'meta_tool', JSON.Get('name', ''));
      AssertEquals('JSON should contain description', 'Tool with metadata', JSON.Get('description', ''));

      // _Meta is internal and should not appear in ToJSON output
      AssertFalse('JSON should not contain _Meta', JSON.IndexOfName('_Meta') >= 0);
      AssertFalse('JSON should not contain meta', JSON.IndexOfName('meta') >= 0);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestToJSONProcedureVersion;
var
  ToolInfo: TMCPToolInfo;
  JSON: TJSONObject;
  Annotation: TMCPAnnotation;
begin
  ToolInfo := TMCPToolInfo.Create('proc_tool', 'Test procedure version');
  try
    // Set up annotations
    Annotation := ToolInfo.FAnnotations;
    Annotation.Priority := False;
    Annotation.Roles := [prAssistant];
    ToolInfo.FAnnotations := Annotation;

    JSON := TJSONObject.Create;
    try
      ToolInfo.ToJSON(JSON);

      AssertNotNull('JSON should be populated', JSON);
      AssertEquals('JSON should contain name', 'proc_tool', JSON.Get('name', ''));
      AssertEquals('JSON should contain description', 'Test procedure version', JSON.Get('description', ''));
      AssertTrue('JSON should contain annotations', JSON.IndexOfName('annotations') >= 0);
      AssertTrue('JSON should contain inputSchema', JSON.IndexOfName('inputSchema') >= 0);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestCreateAndDestroy;
var
  ToolInfo: TMCPToolInfo;
begin
  ToolInfo := TMCPToolInfo.Create('create_test', 'Creation test');
  try
    AssertNotNull('ToolInfo should be created', ToolInfo);
    AssertEquals('Name should be set', 'create_test', ToolInfo.Name);
    AssertEquals('Description should be set', 'Creation test', ToolInfo.Description);
    AssertNotNull('InputSchema should be created', ToolInfo.InputSchema);
    AssertNotNull('OutputSchema should be created', ToolInfo.OutputSchema);
    AssertNull('_Meta should be nil by default', ToolInfo._Meta);
    AssertFalse('Annotations should not be initialized by default', ToolInfo.FAnnotations.Initialized);
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestPropertyAccess;
var
  ToolInfo: TMCPToolInfo;
  Meta: TJSONObject;
  Annotation: TMCPAnnotation;
begin
  ToolInfo := TMCPToolInfo.Create('prop_test', 'Property test');
  try
    // Test property read access
    AssertEquals('Name property should work', 'prop_test', ToolInfo.Name);
    AssertEquals('Description property should work', 'Property test', ToolInfo.Description);

    // Test property write access
    ToolInfo.Name := 'new_name';
    ToolInfo.Description := 'New description';
    AssertEquals('Name should be changeable', 'new_name', ToolInfo.Name);
    AssertEquals('Description should be changeable', 'New description', ToolInfo.Description);

    // Test _Meta property
    Meta := TJSONObject.Create;
    Meta.Add('test', 'value');
    ToolInfo._Meta := Meta;
    AssertSame('_Meta should return assigned object', Meta, ToolInfo._Meta);

    // Test annotations field access
    Annotation := ToolInfo.FAnnotations;
    Annotation.Priority := True;
    ToolInfo.FAnnotations := Annotation;
    AssertTrue('Annotations Priority should be settable', ToolInfo.FAnnotations.Priority);
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestFromJSONWithMinimalData;
var
  ToolInfo: TMCPToolInfo;
  JSON: TJSONObject;
begin
  ToolInfo := TMCPToolInfo.Create('', '');
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('name', 'from_json_tool');
      JSON.Add('description', 'Tool created from JSON');

      ToolInfo.FromJSON(JSON);

      AssertEquals('Name should be loaded from JSON', 'from_json_tool', ToolInfo.Name);
      AssertEquals('Description should be loaded from JSON', 'Tool created from JSON', ToolInfo.Description);
      AssertNotNull('InputSchema should still exist', ToolInfo.InputSchema);
      AssertFalse('Annotations should not be initialized', ToolInfo.FAnnotations.Initialized);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestFromJSONWithFullData;
var
  ToolInfo: TMCPToolInfo;
  JSON, AnnotationsJSON, InputSchemaJSON, PropertiesJSON, Param1JSON: TJSONObject;
  RolesArray, RequiredArray: TJSONArray;
begin
  ToolInfo := TMCPToolInfo.Create('', '');
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('name', 'full_json_tool');
      JSON.Add('description', 'Full tool from JSON');

      // Add annotations
      AnnotationsJSON := TJSONObject.Create;
      AnnotationsJSON.Add('priority', 1);
      AnnotationsJSON.Add('lastModified', DateToISO8601(EncodeDate(2024, 12, 19)));
      RolesArray := TJSONArray.Create;
      RolesArray.Add('user');
      RolesArray.Add('assistant');
      AnnotationsJSON.Add('roles', RolesArray);
      JSON.Add('annotations', AnnotationsJSON);

      // Add input schema
      InputSchemaJSON := TJSONObject.Create;
      InputSchemaJSON.Add('type', 'object');

      PropertiesJSON := TJSONObject.Create;
      Param1JSON := TJSONObject.Create;
      Param1JSON.Add('type', 'string');
      PropertiesJSON.Add('param1', Param1JSON);
      InputSchemaJSON.Add('properties', PropertiesJSON);

      RequiredArray := TJSONArray.Create;
      RequiredArray.Add('param1');
      InputSchemaJSON.Add('required', RequiredArray);

      JSON.Add('inputSchema', InputSchemaJSON);

      ToolInfo.FromJSON(JSON);

      AssertEquals('Name should be loaded', 'full_json_tool', ToolInfo.Name);
      AssertEquals('Description should be loaded', 'Full tool from JSON', ToolInfo.Description);
      AssertTrue('Annotations should be initialized', ToolInfo.FAnnotations.Initialized);
      AssertTrue('Priority should be true', ToolInfo.FAnnotations.Priority);
      AssertTrue('Roles should include prUser', prUser in ToolInfo.FAnnotations.Roles);
      AssertTrue('Roles should include prAssistant', prAssistant in ToolInfo.FAnnotations.Roles);
      AssertNotNull('param1 should exist in schema', ToolInfo.InputSchema.Arguments['param1']);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestFromJSONWithAnnotations;
var
  ToolInfo: TMCPToolInfo;
  JSON, AnnotationsJSON: TJSONObject;
  RolesArray: TJSONArray;
begin
  ToolInfo := TMCPToolInfo.Create('annot_tool', 'Annotation test');
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('name', 'annotation_tool');
      JSON.Add('description', 'Tool with annotations');

      // Add detailed annotations
      AnnotationsJSON := TJSONObject.Create;
      AnnotationsJSON.Add('priority', 0);
      AnnotationsJSON.Add('lastModified', DateToISO8601(EncodeDate(2024, 12, 19)));
      RolesArray := TJSONArray.Create;
      RolesArray.Add('assistant');
      AnnotationsJSON.Add('roles', RolesArray);
      JSON.Add('annotations', AnnotationsJSON);

      ToolInfo.FromJSON(JSON);

      AssertTrue('Annotations should be initialized', ToolInfo.FAnnotations.Initialized);
      AssertFalse('Priority should be false', ToolInfo.FAnnotations.Priority);
      AssertEquals('LastModified should be parsed', EncodeDate(2024, 12, 19), ToolInfo.FAnnotations.LastModified);
      AssertTrue('Roles should include prAssistant', prAssistant in ToolInfo.FAnnotations.Roles);
      AssertTrue('Roles should only have prAssistant', ToolInfo.FAnnotations.Roles = [prAssistant]);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestFromJSONWithInputSchema;
var
  ToolInfo: TMCPToolInfo;
  JSON, InputSchemaJSON, PropertiesJSON, Param1JSON, Param2JSON: TJSONObject;
  RequiredArray: TJSONArray;
begin
  ToolInfo := TMCPToolInfo.Create('schema_tool', 'Schema test');
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('name', 'schema_from_json');
      JSON.Add('description', 'Tool with input schema');

      // Create complex input schema
      InputSchemaJSON := TJSONObject.Create;
      InputSchemaJSON.Add('type', 'object');

      PropertiesJSON := TJSONObject.Create;

      Param1JSON := TJSONObject.Create;
      Param1JSON.Add('type', 'string');
      Param1JSON.Add('description', 'A string parameter');
      PropertiesJSON.Add('param1', Param1JSON);

      Param2JSON := TJSONObject.Create;
      Param2JSON.Add('type', 'integer');
      Param2JSON.Add('description', 'An integer parameter');
      PropertiesJSON.Add('param2', Param2JSON);

      InputSchemaJSON.Add('properties', PropertiesJSON);

      RequiredArray := TJSONArray.Create;
      RequiredArray.Add('param1');
      InputSchemaJSON.Add('required', RequiredArray);

      JSON.Add('inputSchema', InputSchemaJSON);

      ToolInfo.FromJSON(JSON);

      AssertNotNull('InputSchema should be recreated', ToolInfo.InputSchema);
      AssertNotNull('param1 should exist', ToolInfo.InputSchema.Arguments['param1']);
      AssertNotNull('param2 should exist', ToolInfo.InputSchema.Arguments['param2']);
      AssertEquals('param1 type should be string', 'string',
        (ToolInfo.InputSchema.Arguments['param1'] as TJSONObject).Get('type', ''));
      AssertEquals('param2 type should be integer', 'integer',
        (ToolInfo.InputSchema.Arguments['param2'] as TJSONObject).Get('type', ''));
      AssertEquals('Required should have param1', 1, Length(ToolInfo.InputSchema.Required));
      AssertEquals('Required should contain param1', 'param1', ToolInfo.InputSchema.Required[0]);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestFromJSONWithMissingFields;
var
  ToolInfo: TMCPToolInfo;
  JSON: TJSONObject;
begin
  ToolInfo := TMCPToolInfo.Create('original', 'Original description');
  try
    JSON := TJSONObject.Create;
    try
      // Only provide name, missing description and other fields
      JSON.Add('name', 'partial_tool');

      ToolInfo.FromJSON(JSON);

      AssertEquals('Name should be updated', 'partial_tool', ToolInfo.Name);
      AssertEquals('Description should be empty', '', ToolInfo.Description);
      AssertNotNull('InputSchema should still exist', ToolInfo.InputSchema);
      AssertFalse('Annotations should not be initialized', ToolInfo.FAnnotations.Initialized);
    finally
      JSON.Free;
    end;
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestFromJSONWithNilParameter;
var
  ToolInfo: TMCPToolInfo;
begin
  ToolInfo := TMCPToolInfo.Create('nil_test', 'Nil test');
  try
    // Should not crash with nil JSON
    ToolInfo.FromJSON(nil);

    // Values should remain unchanged
    AssertEquals('Name should remain unchanged', 'nil_test', ToolInfo.Name);
    AssertEquals('Description should remain unchanged', 'Nil test', ToolInfo.Description);
  finally
    ToolInfo.Free;
  end;
end;

procedure TMCPToolInfoTest.TestRoundTripSerialization;
var
  OriginalInfo, LoadedInfo: TMCPToolInfo;
  JSON: TJSONObject;
  Annotation: TMCPAnnotation;
begin
  OriginalInfo := TMCPToolInfo.Create('roundtrip_tool', 'Round trip test');
  LoadedInfo := TMCPToolInfo.Create('', '');
  try
    // Set up original with complex data
    Annotation := OriginalInfo.FAnnotations;
    Annotation.Priority := True;
    Annotation.Roles := [prUser, prAssistant];
    Annotation.LastModified := EncodeDate(2024, 12, 19);
    OriginalInfo.FAnnotations := Annotation;

    OriginalInfo.InputSchema.AddArgument('param1', TJSONObject.Create(['type', 'string']), True);
    OriginalInfo.InputSchema.AddArgument('param2', TJSONObject.Create(['type', 'integer']), False);

    // Serialize to JSON
    JSON := OriginalInfo.ToJSON;
    try
      // Deserialize to new object
      LoadedInfo.FromJSON(JSON);

      // Verify all data matches
      AssertEquals('Name should match', OriginalInfo.Name, LoadedInfo.Name);
      AssertEquals('Description should match', OriginalInfo.Description, LoadedInfo.Description);
      AssertEquals('Priority should match', OriginalInfo.FAnnotations.Priority, LoadedInfo.FAnnotations.Priority);
      AssertTrue('Roles should match', OriginalInfo.FAnnotations.Roles = LoadedInfo.FAnnotations.Roles);
      AssertEquals('LastModified should match',
        DateToISO8601(OriginalInfo.FAnnotations.LastModified),
        DateToISO8601(LoadedInfo.FAnnotations.LastModified));
      AssertNotNull('param1 should be preserved', LoadedInfo.InputSchema.Arguments['param1']);
      AssertNotNull('param2 should be preserved', LoadedInfo.InputSchema.Arguments['param2']);
      AssertEquals('Required count should match',
        Length(OriginalInfo.InputSchema.Required),
        Length(LoadedInfo.InputSchema.Required));
    finally
      JSON.Free;
    end;
  finally
    OriginalInfo.Free;
    LoadedInfo.Free;
  end;
end;

{ TMCPResourceInfoTest }

procedure TMCPResourceInfoTest.SetUp;
begin
  inherited SetUp;
end;

procedure TMCPResourceInfoTest.TearDown;
begin
  inherited TearDown;
end;

procedure TMCPResourceInfoTest.AssertEquals(const Msg: string; aExpected, aActual: TMCPResourceKind);
begin
  AssertEquals(Msg, GetEnumName(TypeInfo(TMCPResourceKind), ord(aExpected)),
                   GetEnumName(TypeInfo(TMCPResourceKind), ord(aActual)));
end;

procedure TMCPResourceInfoTest.TestToJSONWithMinimalData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://resource', 'test_resource');
  JSON := ResourceInfo.ToJSON(False);
  try
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('JSON should contain uri', 'test://resource', JSON.Get('uri', ''));
    AssertEquals('JSON should contain name', 'test_resource', JSON.Get('name', ''));
    AssertEquals('JSON should contain title', '', JSON.Get('title', ''));
    AssertEquals('JSON should contain description', '', JSON.Get('description', ''));
    AssertEquals('JSON should contain mimetype', '', JSON.Get('mimetype', ''));
    AssertFalse('JSON should not contain text data', JSON.IndexOfName('text') >= 0);
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestToJSONWithTextData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://text', 'text_resource');
  ResourceInfo.Text := 'Hello, World!';
  ResourceInfo.Title := 'Test Text Resource';
  ResourceInfo.MimeType := 'text/plain';

  JSON := ResourceInfo.ToJSON(True);
  try
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('JSON should contain uri', 'test://text', JSON.Get('uri', ''));
    AssertEquals('JSON should contain name', 'text_resource', JSON.Get('name', ''));
    AssertEquals('JSON should contain title', 'Test Text Resource', JSON.Get('title', ''));
    AssertEquals('JSON should contain mimetype', 'text/plain', JSON.Get('mimetype', ''));
    AssertTrue('JSON should contain text data', JSON.IndexOfName('text') >= 0);
    AssertEquals('JSON text should match', 'Hello, World!', JSON.Get('text', ''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestToJSONWithBinaryData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
  BinaryData: TBytes;
  ExpectedEncoded: String;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://binary', 'binary_resource');
    // Create some test binary data
  SetLength(BinaryData, 3);
  BinaryData[0] := $48; // 'H'
  BinaryData[1] := $69; // 'i'
  BinaryData[2] := $21; // '!'
  ResourceInfo.Data := BinaryData;
  ResourceInfo.Title := 'Test Binary Resource';
  ResourceInfo.MimeType := 'application/octet-stream';

  // Expected Base64 encoding of "Hi!"
  ExpectedEncoded := 'SGkh';

  JSON := ResourceInfo.ToJSON(True);
  try
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('JSON should contain uri', 'test://binary', JSON.Get('uri', ''));
    AssertEquals('JSON should contain name', 'binary_resource', JSON.Get('name', ''));
    AssertEquals('JSON should contain title', 'Test Binary Resource', JSON.Get('title', ''));
    AssertEquals('JSON should contain mimetype', 'application/octet-stream', JSON.Get('mimetype', ''));
    AssertTrue('JSON should contain text data (encoded)', JSON.IndexOfName('text') >= 0);
    AssertEquals('JSON text should be base64 encoded', ExpectedEncoded, JSON.Get('text', ''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestToJSONWithoutData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://nodata', 'nodata_resource');
  ResourceInfo.Title := 'A resource with no content';
  ResourceInfo.Description := 'A resource with no content';
  ResourceInfo.MimeType := 'text/plain';

  JSON := ResourceInfo.ToJSON(False);
  try
    AssertNotNull('ToJSON should return a JSON object', JSON);
    AssertEquals('JSON should contain uri', 'test://nodata', JSON.Get('uri', ''));
    AssertEquals('JSON should contain name', 'nodata_resource', JSON.Get('name', ''));
    AssertEquals('JSON should contain title', 'A resource with no content', JSON.Get('title', ''));
    AssertEquals('JSON should contain description', 'A resource with no content', JSON.Get('description', ''));
    AssertEquals('JSON should contain mimetype', 'text/plain', JSON.Get('mimetype', ''));
    AssertFalse('JSON should not contain text when withData=False', JSON.IndexOfName('text') >= 0);
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestToJSONProcedureVersion;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://proc', 'proc_resource');
  ResourceInfo.Text := 'Procedure test';
  ResourceInfo.Title := 'Test Procedure Version';

  JSON := TJSONObject.Create;
  try
    ResourceInfo.ToJSON(JSON, True);

    AssertNotNull('JSON should be populated', JSON);
    AssertEquals('JSON should contain uri', 'test://proc', JSON.Get('uri', ''));
    AssertEquals('JSON should contain name', 'proc_resource', JSON.Get('name', ''));
    AssertEquals('JSON should contain title', 'Test Procedure Version', JSON.Get('title', ''));
    AssertTrue('JSON should contain text data', JSON.IndexOfName('text') >= 0);
    AssertEquals('JSON text should match', 'Procedure test', JSON.Get('text', ''));
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestCreateAndDestroy;
var
  ResourceInfo: TMCPResourceInfo;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://create', 'create_test');

  AssertEquals('Uri should be set', 'test://create', ResourceInfo.Uri);
  AssertEquals('Name should be set', 'create_test', ResourceInfo.Name);
  AssertEquals('Title should be empty by default', '', ResourceInfo.Title);
  AssertEquals('Description should be empty by default', '', ResourceInfo.Description);
  AssertEquals('MimeType should be empty by default', '', ResourceInfo.MimeType);
  AssertEquals('Text should be empty by default', '', ResourceInfo.Text);
  AssertEquals('Data should be empty by default', 0, Length(ResourceInfo.Data));
  AssertEquals('Size should be 0 by default', 0, ResourceInfo.Size);
  AssertEquals('Kind should be rkUnknown by default', rkUnknown, ResourceInfo.GetKind);
end;

procedure TMCPResourceInfoTest.TestPropertyAccess;
var
  ResourceInfo: TMCPResourceInfo;
  TestData: TBytes;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://prop', 'prop_test');
  // Test property write access
  ResourceInfo.Uri := 'test://newuri';
  ResourceInfo.Name := 'new_name';
  ResourceInfo.Title := 'New Title';
  ResourceInfo.Description := 'New Description';
  ResourceInfo.MimeType := 'text/plain';
  ResourceInfo.Text := 'Some text';
  ResourceInfo.Size := 100;

  // Test property read access
  AssertEquals('Uri should be changeable', 'test://newuri', ResourceInfo.Uri);
  AssertEquals('Name should be changeable', 'new_name', ResourceInfo.Name);
  AssertEquals('Title should be changeable', 'New Title', ResourceInfo.Title);
  AssertEquals('Description should be changeable', 'New Description', ResourceInfo.Description);
  AssertEquals('MimeType should be changeable', 'text/plain', ResourceInfo.MimeType);
  AssertEquals('Text should be changeable', 'Some text', ResourceInfo.Text);
  AssertEquals('Size should be changeable', 100, ResourceInfo.Size);

  // Test data property
  SetLength(TestData, 2);
  TestData[0] := $41; // 'A'
  TestData[1] := $42; // 'B'
  ResourceInfo.Data := TestData;
  AssertEquals('Data should be settable', 2, Length(ResourceInfo.Data));
  AssertEquals('Data[0] should match', $41, ResourceInfo.Data[0]);
  AssertEquals('Data[1] should match', $42, ResourceInfo.Data[1]);
end;

procedure TMCPResourceInfoTest.TestFromJSONWithMinimalData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('', '');
  JSON := TJSONObject.Create;
  try
    JSON.Add('uri', 'test://fromjson');
    JSON.Add('name', 'fromjson_resource');

    ResourceInfo.FromJSON(JSON);

    AssertEquals('Uri should be loaded from JSON', 'test://fromjson', ResourceInfo.Uri);
    AssertEquals('Name should be loaded from JSON', 'fromjson_resource', ResourceInfo.Name);
    AssertEquals('Title should be empty', '', ResourceInfo.Title);
    AssertEquals('Description should be empty', '', ResourceInfo.Description);
    AssertEquals('MimeType should be empty', '', ResourceInfo.MimeType);
    AssertEquals('Text should be empty', '', ResourceInfo.Text);
    AssertEquals('Data should be empty', 0, Length(ResourceInfo.Data));
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestFromJSONWithTextData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('', '');
  JSON := TJSONObject.Create;
  try
    JSON.Add('uri', 'test://textfromjson');
    JSON.Add('name', 'text_from_json');
    JSON.Add('title', 'Text From JSON');
    JSON.Add('description', 'A text resource loaded from JSON');
    JSON.Add('mimetype', 'text/plain');
    JSON.Add('text', 'Hello from JSON!');

    ResourceInfo.FromJSON(JSON);

    AssertEquals('Uri should be loaded', 'test://textfromjson', ResourceInfo.Uri);
    AssertEquals('Name should be loaded', 'text_from_json', ResourceInfo.Name);
    AssertEquals('Title should be loaded (from title field only)', 'Text From JSON', ResourceInfo.Title);
    AssertEquals('Description should be loaded from description field', 'A text resource loaded from JSON', ResourceInfo.Description);
    AssertEquals('MimeType should be loaded', 'text/plain', ResourceInfo.MimeType);
    AssertEquals('Text should be loaded', 'Hello from JSON!', ResourceInfo.Text);
    AssertEquals('Kind should be rkText', rkText, ResourceInfo.GetKind);
    AssertEquals('Size should be calculated', Length('Hello from JSON!'), ResourceInfo.GetSize);
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestFromJSONWithBinaryData;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
  ExpectedData: TBytes;
begin
  ResourceInfo := TMCPResourceInfo.Create('', '');
  JSON := TJSONObject.Create;
  try
    JSON.Add('uri', 'test://binaryfromjson');
    JSON.Add('name', 'binary_from_json');
    JSON.Add('title', 'Binary From JSON');
    JSON.Add('description', 'A binary resource loaded from JSON');
    JSON.Add('mimetype', 'application/octet-stream');
    JSON.Add('text', 'SGkh'); // Base64 for "Hi!"

    ResourceInfo.FromJSON(JSON);

    AssertEquals('Uri should be loaded', 'test://binaryfromjson', ResourceInfo.Uri);
    AssertEquals('Name should be loaded', 'binary_from_json', ResourceInfo.Name);
    AssertEquals('Title should be loaded (from title field only)', 'Binary From JSON', ResourceInfo.Title);
    AssertEquals('Description should be loaded from description field', 'A binary resource loaded from JSON', ResourceInfo.Description);
    AssertEquals('MimeType should be loaded', 'application/octet-stream', ResourceInfo.MimeType);

    // For binary data (non-text mimetype), should be decoded
    SetLength(ExpectedData, 3);
    ExpectedData[0] := $48; // 'H'
    ExpectedData[1] := $69; // 'i'
    ExpectedData[2] := $21; // '!'

    AssertEquals('Data length should match', Length(ExpectedData), Length(ResourceInfo.Data));
    if Length(ResourceInfo.Data) >= 3 then
    begin
      AssertEquals('Data[0] should match', ExpectedData[0], ResourceInfo.Data[0]);
      AssertEquals('Data[1] should match', ExpectedData[1], ResourceInfo.Data[1]);
      AssertEquals('Data[2] should match', ExpectedData[2], ResourceInfo.Data[2]);
    end;
    AssertEquals('Kind should be rkData', rkData, ResourceInfo.GetKind);
    AssertEquals('Size should be calculated', Length(ExpectedData), ResourceInfo.GetSize);
  finally
    JSON.Free;
    end;
end;

procedure TMCPResourceInfoTest.TestFromJSONWithMissingFields;
var
  ResourceInfo: TMCPResourceInfo;
  JSON: TJSONObject;
begin
  ResourceInfo := TMCPResourceInfo.Create('original://uri', 'original_name');
  // Set initial values
  ResourceInfo.Title := 'Original Title';
  ResourceInfo.Description := 'Original Description';

  JSON := TJSONObject.Create;
  try
    // Only provide uri and name, missing other fields
    JSON.Add('uri', 'test://partial');
    JSON.Add('name', 'partial_resource');

    ResourceInfo.FromJSON(JSON);

    AssertEquals('Uri should be updated', 'test://partial', ResourceInfo.Uri);
    AssertEquals('Name should be updated', 'partial_resource', ResourceInfo.Name);
    AssertEquals('Title should be cleared', '', ResourceInfo.Title);
    AssertEquals('Description should be cleared', '', ResourceInfo.Description);
    AssertEquals('MimeType should be empty', '', ResourceInfo.MimeType);
  finally
    JSON.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestFromJSONWithNilParameter;
var
  ResourceInfo: TMCPResourceInfo;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://nil', 'nil_test');
  ResourceInfo.Title := 'Original Title';

  // Should not crash with nil JSON
  ResourceInfo.FromJSON(nil);

  // Values should remain unchanged
  AssertEquals('Uri should remain unchanged', 'test://nil', ResourceInfo.Uri);
  AssertEquals('Name should remain unchanged', 'nil_test', ResourceInfo.Name);
  AssertEquals('Title should remain unchanged', 'Original Title', ResourceInfo.Title);
end;

procedure TMCPResourceInfoTest.TestRoundTripSerialization;
var
  OriginalInfo, LoadedInfo: TMCPResourceInfo;
  JSON: TJSONObject;
  TestData: TBytes;
begin
  OriginalInfo := TMCPResourceInfo.Create('test://roundtrip', 'roundtrip_test');
  LoadedInfo := TMCPResourceInfo.Create('', '');
  try
    // Set up original with complex data
    OriginalInfo.Description := 'Testing round trip serialization'; // Description overwrites Title
    OriginalInfo.MimeType := 'text/plain';
    OriginalInfo.Text := 'Round trip content';
    // Don't set explicit size - let it be calculated from content

    // Serialize to JSON
    JSON := OriginalInfo.ToJSON(True);
    try
      // Deserialize to new object
      LoadedInfo.FromJSON(JSON);

      // Verify all data matches
      AssertEquals('Uri should match', OriginalInfo.Uri, LoadedInfo.Uri);
      AssertEquals('Name should match', OriginalInfo.Name, LoadedInfo.Name);
      AssertEquals('Title should match', OriginalInfo.Title, LoadedInfo.Title);
      AssertEquals('Description should match', OriginalInfo.Description, LoadedInfo.Description);
      AssertEquals('MimeType should match', OriginalInfo.MimeType, LoadedInfo.MimeType);
      AssertEquals('Text should match', OriginalInfo.Text, LoadedInfo.Text);
      AssertEquals('Kind should match', OriginalInfo.GetKind, LoadedInfo.GetKind);
      AssertEquals('Size should match', OriginalInfo.GetSize, LoadedInfo.GetSize);
    finally
      JSON.Free;
    end;
  finally
    OriginalInfo.Free;
    LoadedInfo.Free;
  end;

  // Test binary data round trip separately
  OriginalInfo := TMCPResourceInfo.Create('test://binary-roundtrip', 'binary_test');
  LoadedInfo := TMCPResourceInfo.Create('', '');
  try
    SetLength(TestData, 4);
    TestData[0] := $DE;
    TestData[1] := $AD;
    TestData[2] := $BE;
    TestData[3] := $EF;
    OriginalInfo.Data := TestData;
    OriginalInfo.MimeType := 'application/octet-stream';
    OriginalInfo.Description := 'Binary test data';

    JSON := OriginalInfo.ToJSON(True);
    try
      LoadedInfo.FromJSON(JSON);

      AssertEquals('Binary Uri should match', OriginalInfo.Uri, LoadedInfo.Uri);
      AssertEquals('Binary MimeType should match', OriginalInfo.MimeType, LoadedInfo.MimeType);
      AssertEquals('Binary Kind should match', OriginalInfo.GetKind, LoadedInfo.GetKind);
      AssertEquals('Binary Size should match', OriginalInfo.GetSize, LoadedInfo.GetSize);
      AssertEquals('Binary Data length should match', Length(OriginalInfo.Data), Length(LoadedInfo.Data));
      if Length(LoadedInfo.Data) = 4 then
      begin
        AssertEquals('Binary Data[0] should match', TestData[0], LoadedInfo.Data[0]);
        AssertEquals('Binary Data[1] should match', TestData[1], LoadedInfo.Data[1]);
        AssertEquals('Binary Data[2] should match', TestData[2], LoadedInfo.Data[2]);
        AssertEquals('Binary Data[3] should match', TestData[3], LoadedInfo.Data[3]);
      end;
    finally
      JSON.Free;
    end;
  finally
    OriginalInfo.Free;
    LoadedInfo.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestKindDetermination;
var
  ResourceInfo: TMCPResourceInfo;
  TestData: TBytes;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://kind', 'kind_test');
  try
    // Test default kind
    AssertEquals('Default kind should be rkUnknown', rkUnknown, ResourceInfo.GetKind);

    // Test text kind
    ResourceInfo.Text := 'Some text';
    AssertEquals('Kind should be rkText after setting text', rkText, ResourceInfo.GetKind);

    // Test data kind
    SetLength(TestData, 2);
    TestData[0] := $FF;
    TestData[1] := $00;
    ResourceInfo.Data := TestData;
    AssertEquals('Kind should be rkData after setting binary data', rkData, ResourceInfo.GetKind);

    // Test kind override
    ResourceInfo.SetKind(rkText);
    AssertEquals('Kind should be rkText after explicit setting', rkText, ResourceInfo.GetKind);
  finally
    ResourceInfo.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestSizeCalculation;
var
  ResourceInfo: TMCPResourceInfo;
  TestData: TBytes;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://size', 'size_test');
  try
    // Test size with explicit size
    ResourceInfo.Size := 100;
    AssertEquals('Explicit size should be returned', 100, ResourceInfo.GetSize);

    // Test size calculation for text
    ResourceInfo.Size := 0; // Clear explicit size
    ResourceInfo.Text := 'Hello';
    AssertEquals('Text size should be calculated', 5, ResourceInfo.GetSize);

    // Test size calculation for data
    SetLength(TestData, 10);
    ResourceInfo.Data := TestData;
    AssertEquals('Data size should be calculated', 10, ResourceInfo.GetSize);

    // Test explicit size takes precedence
    ResourceInfo.Size := 50;
    AssertEquals('Explicit size should override calculated', 50, ResourceInfo.GetSize);
  finally
    ResourceInfo.Free;
  end;
end;

procedure TMCPResourceInfoTest.TestUriValidation;
var
  ResourceInfo: TMCPResourceInfo;
begin
  ResourceInfo := TMCPResourceInfo.Create('test://valid', 'valid_test');
  try
    // Test valid URI setting
    ResourceInfo.Uri := 'test://newuri';
    AssertEquals('Valid URI should be set', 'test://newuri', ResourceInfo.Uri);

    // Test empty URI validation
    try
      ResourceInfo.Uri := '';
      Fail('Expected EMCPException for empty URI but none was raised');
    except
      on E: EMCPException do
        AssertTrue('EMCPException should mention URI cannot be empty',
                  Pos('URI cannot be empty', E.Message) > 0);
    end;
  finally
    ResourceInfo.Free;
  end;
end;

initialization
  RegisterTests([TMCPTypesTest, TMCPToolInfoTest, TMCPResourceInfoTest]);
end.
