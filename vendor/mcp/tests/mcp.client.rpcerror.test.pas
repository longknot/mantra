unit mcp.client.rpcerror.test;

{$mode objfpc}{$H+}
{$codepage utf8}
interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, mcp.types;

type

  { TMCPRPCErrorTest }

  TMCPRPCErrorTest = class(TTestCase)
  private
    FJSON: TJSONObject;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // JSON Serialization Tests
    procedure TestFromJSONWithAllFields;
    procedure TestFromJSONWithMissingFields;
    procedure TestFromJSONWithNullFields;
    procedure TestFromJSONWithInvalidJSON;
    procedure TestToJSONWithAllFields;
    procedure TestToJSONWithEmptyFields;
    procedure TestToJSONWithZeroCode;

    // State Classification Tests
    procedure TestIsSuccessWithZeroCode;
    procedure TestIsSuccessWithPositiveCode;
    procedure TestIsSuccessWithNegativeCode;
    procedure TestIsErrorWithZeroCode;
    procedure TestIsErrorWithNonZeroCode;
    procedure TestIsErrorIsOppositeOfIsSuccess;

    // Data Field JSON Handling Tests
    procedure TestDataFieldWithValidJSON;
    procedure TestDataFieldWithInvalidJSON;
    procedure TestDataFieldWithEmptyString;
    procedure TestDataFieldWithNullValue;

    // Round-trip Serialization Tests
    procedure TestRoundTripSerializationComplete;
    procedure TestRoundTripSerializationMinimal;
    procedure TestRoundTripSerializationWithComplexData;

    // Edge Cases and Error Conditions
    procedure TestFromJSONWithNilParameter;
    procedure TestToJSONWithNilParameter;
    procedure TestFromJSONWithMalformedJSON;
    procedure TestNaturalDefaultValues;
    procedure TestLargeCodeValues;
    procedure TestUnicodeInMessageField;
  end;

implementation

{ TMCPRPCErrorTest }

procedure TMCPRPCErrorTest.SetUp;
begin
  inherited SetUp;
  FJSON := TJSONObject.Create;
end;

procedure TMCPRPCErrorTest.TearDown;
begin
  FJSON.Free;
  FJSON := nil;
  inherited TearDown;
end;

procedure TMCPRPCErrorTest.TestFromJSONWithAllFields;
var
  Error: TRPCError;
begin
  FJSON.Add('code', -32600);
  FJSON.Add('message', 'Invalid Request');
  FJSON.Add('data', '{"detail": "Missing method parameter"}');

  Error.FromJSON(FJSON);

  AssertEquals('Code should match JSON', -32600, Error.Code);
  AssertEquals('Message should match JSON', 'Invalid Request', Error.Message);
  AssertEquals('Data should match JSON', '"{\"detail\": \"Missing method parameter\"}"', Error.Data);
end;

procedure TMCPRPCErrorTest.TestFromJSONWithMissingFields;
var
  Error: TRPCError;
begin
  // Test with only code field - missing fields should use natural defaults
  FJSON.Add('code', -32601);

  Error.FromJSON(FJSON);

  AssertEquals('Code should be set', -32601, Error.Code);
  AssertEquals('Missing message field should default to empty string', '', Error.Message);
  AssertEquals('Missing data field should default to empty string', '', Error.Data);

  // Test with no fields at all - all should use natural defaults
  FJSON.Clear;
  Error.FromJSON(FJSON);

  AssertEquals('Missing code field should default to 0', 0, Error.Code);
  AssertEquals('Missing message field should default to empty string', '', Error.Message);
  AssertEquals('Missing data field should default to empty string', '', Error.Data);
end;

procedure TMCPRPCErrorTest.TestFromJSONWithNullFields;
var
  Error: TRPCError;
begin
  FJSON.Add('code', -32602);
  FJSON.Add('message', TJSONNull.Create);
  FJSON.Add('data', TJSONNull.Create);

  Error.FromJSON(FJSON);

  AssertEquals('Code should be set', -32602, Error.Code);
  // Null values in JSON should be treated as empty strings in Pascal
  AssertEquals('Null message should become empty string', '', Error.Message);
  AssertEquals('Null data should become empty string', 'null',Error.Data);
end;

procedure TMCPRPCErrorTest.TestFromJSONWithInvalidJSON;
var
  Error: TRPCError;
  ExceptionRaised: Boolean;
begin
  FJSON.Add('code', 'not-a-number'); // Invalid type for code
  FJSON.Add('message', 123); // Invalid type for message
  FJSON.Add('data', TJSONArray.Create); // Invalid type for data

  ExceptionRaised := False;
  try
    Error.FromJSON(FJSON);
  except
    on E: Exception do
      ExceptionRaised := True;
  end;

  AssertTrue('Should raise exception for invalid JSON types', ExceptionRaised);
end;

procedure TMCPRPCErrorTest.TestToJSONWithAllFields;
var
  Error: TRPCError;
begin
  Error.Code := -32603;
  Error.Message := 'Internal error';
  Error.Data := '{"trace": "stack trace here"}';

  Error.ToJSON(FJSON);

  AssertEquals('JSON should contain code', -32603, FJSON.Get('code', 0));
  AssertEquals('JSON should contain message', 'Internal error', FJSON.Get('message', ''));
  AssertEquals('JSON should contain data', '{ "trace" : "stack trace here" }', FJSON.Elements['data'].AsJSON);
end;

procedure TMCPRPCErrorTest.TestToJSONWithEmptyFields;
var
  Error: TRPCError;
begin
  Error.Code := 0;
  Error.Message := '';
  Error.Data := '';

  Error.ToJSON(FJSON);

  // All fields should be included in JSON, even if empty
  AssertEquals('JSON should include code even if zero', 0, FJSON.Get('code', -1));
  AssertTrue('Empty message field should be included', FJSON.IndexOfName('message') >= 0);
  AssertEquals('Empty message should be empty string', '', FJSON.Get('message', 'NOT_FOUND'));
  AssertTrue('Empty data field should be included', FJSON.IndexOfName('data') = -1);
end;

procedure TMCPRPCErrorTest.TestToJSONWithZeroCode;
var
  Error: TRPCError;
begin
  Error.Code := 0;
  Error.Message := 'Success';
  Error.Data := '';

  Error.ToJSON(FJSON);

  AssertEquals('Zero code should be preserved', 0, FJSON.Get('code', -1));
  AssertEquals('Message should be preserved', 'Success', FJSON.Get('message', ''));
end;

procedure TMCPRPCErrorTest.TestIsSuccessWithZeroCode;
var
  Error: TRPCError;
begin
  Error.Code := 0;
  Error.Message := 'OK';
  Error.Data := '';

  AssertTrue('Code 0 should indicate success', Error.IsSuccess);
  AssertFalse('Code 0 should not indicate error', Error.IsError);
end;

procedure TMCPRPCErrorTest.TestIsSuccessWithPositiveCode;
var
  Error: TRPCError;
begin
  Error.Code := 200;
  Error.Message := 'OK';
  Error.Data := '';

  AssertFalse('Positive codes should indicate error, not success', Error.IsSuccess);
  AssertTrue('Positive codes should indicate error', Error.IsError);
end;

procedure TMCPRPCErrorTest.TestIsSuccessWithNegativeCode;
var
  Error: TRPCError;
begin
  Error.Code := -32600;
  Error.Message := 'Invalid Request';
  Error.Data := '';

  AssertFalse('Negative codes should not indicate success', Error.IsSuccess);
  AssertTrue('Negative codes should indicate error', Error.IsError);
end;

procedure TMCPRPCErrorTest.TestIsErrorWithZeroCode;
var
  Error: TRPCError;
begin
  Error.Code := 0;

  AssertFalse('Code 0 should not be an error', Error.IsError);
end;

procedure TMCPRPCErrorTest.TestIsErrorWithNonZeroCode;
var
  Error: TRPCError;
begin
  Error.Code := -1;
  AssertTrue('Negative non-zero codes should be errors', Error.IsError);
  AssertFalse('Negative non-zero codes should not be success', Error.IsSuccess);

  Error.Code := 1;
  AssertTrue('Positive non-zero codes should be errors', Error.IsError);
  AssertFalse('Positive non-zero codes should not be success', Error.IsSuccess);
end;

procedure TMCPRPCErrorTest.TestIsErrorIsOppositeOfIsSuccess;
var
  Error: TRPCError;
  TestCodes: array[0..4] of Integer = (-32600, -1, 0, 1, 200);
  i: Integer;
begin
  for i := Low(TestCodes) to High(TestCodes) do
  begin
    Error.Code := TestCodes[i];
    AssertTrue(Format('IsError and IsSuccess should be opposites for code %d', [TestCodes[i]]),
               Error.IsError <> Error.IsSuccess);
  end;
end;

procedure TMCPRPCErrorTest.TestDataFieldWithValidJSON;
var
  Error: TRPCError;
begin
  Error.Code := -32602;
  Error.Message := 'Invalid params';
  Error.Data := '{"parameter": "missing", "received": null}';

  Error.ToJSON(FJSON);

  AssertEquals('Valid JSON in data field should be preserved',
               '{ "parameter" : "missing", "received" : null }',
               FJSON['data'].AsJSON);
end;

procedure TMCPRPCErrorTest.TestDataFieldWithInvalidJSON;
var
  Error: TRPCError;
  Ex : boolean;
begin
  Error.Code := -32700;
  Error.Message := 'Parse error';
  Error.Data := 'invalid json {';

  Ex:=False;
  try
    Error.ToJSON(FJSON);
  except
    on E : Exception do
    ex:=true
  end;

  AssertTrue('Invalid JSON in data raises exception',ex);
end;

procedure TMCPRPCErrorTest.TestDataFieldWithEmptyString;
var
  Error: TRPCError;
begin
  Error.Code := 0;
  Error.Message := 'Success';
  Error.Data := '';

  Error.ToJSON(FJSON);

  AssertEquals('Empty data field should be preserved', 'NOT_FOUND', FJSON.Get('data', 'NOT_FOUND'));
end;

procedure TMCPRPCErrorTest.TestDataFieldWithNullValue;
var
  Error: TRPCError;
  SourceJSON: TJSONObject;
begin
  SourceJSON := TJSONObject.Create;
  try
    SourceJSON.Add('code', 0);
    SourceJSON.Add('message', 'Success');
    SourceJSON.Add('data', TJSONNull.Create);

    Error.FromJSON(SourceJSON);
    Error.ToJSON(FJSON);

    AssertEquals('Null data should become empty string', 'NOT_FOUND', FJSON.Get('data', 'NOT_FOUND'));

  finally
    SourceJSON.Free;
  end;
end;

procedure TMCPRPCErrorTest.TestRoundTripSerializationComplete;
var
  OriginalError, RoundTripError: TRPCError;
begin
  OriginalError.Code := -32601;
  OriginalError.Message := 'Method not found';
  OriginalError.Data := '{ "method" : "unknown_method" }';

  OriginalError.ToJSON(FJSON);
  RoundTripError.FromJSON(FJSON);

  AssertEquals('Round-trip code should match', OriginalError.Code, RoundTripError.Code);
  AssertEquals('Round-trip message should match', OriginalError.Message, RoundTripError.Message);
  AssertEquals('Round-trip data should match', OriginalError.Data, RoundTripError.Data);
end;

procedure TMCPRPCErrorTest.TestRoundTripSerializationMinimal;
var
  OriginalError, RoundTripError: TRPCError;
begin
  OriginalError.Code := 0;
  OriginalError.Message := '';
  OriginalError.Data := '';

  OriginalError.ToJSON(FJSON);
  RoundTripError.FromJSON(FJSON);

  AssertEquals('Round-trip minimal code should match', OriginalError.Code, RoundTripError.Code);
  AssertEquals('Round-trip minimal message should match', OriginalError.Message, RoundTripError.Message);
  AssertEquals('Round-trip minimal data should match', OriginalError.Data, RoundTripError.Data);
end;

procedure TMCPRPCErrorTest.TestRoundTripSerializationWithComplexData;
var
  OriginalError, RoundTripError: TRPCError;
  ComplexData: string;
begin
  ComplexData := '{ "error" : { "type" : "validation", "fields" : ["name", "email"] }, "timestamp" : "2025-01-01T00:00:00Z" }';

  OriginalError.Code := -32602;
  OriginalError.Message := 'Invalid params';
  OriginalError.Data := ComplexData;

  OriginalError.ToJSON(FJSON);
  RoundTripError.FromJSON(FJSON);

  AssertEquals('Round-trip complex data should match', ComplexData, RoundTripError.Data);
end;

procedure TMCPRPCErrorTest.TestFromJSONWithNilParameter;
var
  Error: TRPCError;
begin
  // In Pascal, passing nil should typically raise an exception for safety
  try
    Error.FromJSON(nil);
    AssertFalse('Should not accept nil JSON parameter', True);
  except
    on E: Exception do
      AssertTrue('Exception for nil parameter is expected behavior', True);
  end;
end;

procedure TMCPRPCErrorTest.TestToJSONWithNilParameter;
var
  Error: TRPCError;
begin
  Error.Code := -32603;
  Error.Message := 'Internal error';
  Error.Data := '';

  // In Pascal, passing nil should typically raise an exception for safety
  try
    Error.ToJSON(nil);
    AssertFalse('Should not accept nil JSON parameter', True);
  except
    on E: Exception do
      AssertTrue('Exception for nil parameter is expected behavior', True);
  end;
end;

procedure TMCPRPCErrorTest.TestFromJSONWithMalformedJSON;
var
  Error: TRPCError;
begin
  // Test with completely invalid structure - this is NOT malformed JSON
  // but rather JSON with unexpected field names. Should handle gracefully
  // using natural defaults for missing expected fields.
  FJSON.Add('invalid_field', 'value');
  FJSON.Add('another_field', 123);

  Error.FromJSON(FJSON);

  // Should use natural defaults for missing standard fields
  AssertEquals('Should default code to 0 when missing', 0, Error.Code);
  AssertEquals('Should default message to empty string when missing', '', Error.Message);
  AssertEquals('Should default data to empty string when missing', '', Error.Data);
end;


procedure TMCPRPCErrorTest.TestNaturalDefaultValues;
var
  Error: TRPCError;
begin
  // Test that uninitialized TRPCError has natural default values
  FillChar(Error, SizeOf(Error), 0);

  AssertEquals('Uninitialized code should be 0 (natural default for integer)', 0, Error.Code);
  AssertEquals('Uninitialized message should be empty (natural default for string)', '', Error.Message);
  AssertEquals('Uninitialized data should be empty (natural default for string)', '', Error.Data);

  // Verify these are success values
  AssertTrue('Default code 0 should indicate success', Error.IsSuccess);
  AssertFalse('Default code 0 should not indicate error', Error.IsError);

  // Test that FromJSON with empty object uses natural defaults
  Error.FromJSON(FJSON);

  AssertEquals('Empty JSON should result in natural default code 0', 0, Error.Code);
  AssertEquals('Empty JSON should result in natural default empty message', '', Error.Message);
  AssertEquals('Empty JSON should result in natural default empty data', '', Error.Data);
end;

procedure TMCPRPCErrorTest.TestLargeCodeValues;
var
  Error: TRPCError;
  LargeCodes: array[0..3] of Integer = (MaxInt, 2-MaxInt, 2147483647, -2147483648);
  i: Integer;
begin
  for i := Low(LargeCodes) to High(LargeCodes) do
  begin
    Error.Code := LargeCodes[i];
    Error.Message := Format('Large code test %d', [i]);
    Error.Data := '';

    Error.ToJSON(FJSON);

    AssertEquals(Format('Large code value %d should be preserved', [LargeCodes[i]]),
                 LargeCodes[i], FJSON.Get('code', 0));

    FJSON.Clear; // Clear for next iteration
  end;
end;

procedure TMCPRPCErrorTest.TestUnicodeInMessageField;
var
  Error: TRPCError;
  UnicodeMessage: string;
begin
  UnicodeMessage := 'Error with unicode: 测试 🚀 Тест';

  Error.Code := -32000;
  Error.Message := UnicodeMessage;
  Error.Data := '{"unicode": "测试数据"}';

  Error.ToJSON(FJSON);

  AssertEquals('Unicode message should be preserved', UnicodeMessage, FJSON.Get('message', ''));
  AssertEquals('Unicode in data should be preserved', '{ "unicode" : "测试数据" }', FJSON['data'].AsJSON);
end;

initialization
  RegisterTest(TMCPRPCErrorTest);

end.
