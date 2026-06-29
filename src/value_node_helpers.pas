unit value_node_helpers;

{$I mantra.inc}

interface

uses
  exp_trees,
  fpjson;

function CreateIntegerNodeFromText(const ValueText: ansistring): Integer;
function CreateFloatNodeFromText(const ValueText: ansistring): Integer;
function CreateStringNodeFromText(const ValueText: ansistring): Integer;
function CreateNullNode: Integer;
function CreateBooleanNode(const Value: Boolean): Integer;
function CreateJsonEmptyContainerNode(const IsArray: Boolean): Integer;
function CreateScalarNodeFromJson(JsonValue: TJSONData): Integer;

implementation

uses
  SysUtils, tokens, string_utils, parsetree;

procedure InitValueNode(
  const ObjectId: Integer;
  const TokenId: Integer;
  const TokenText: ansistring;
  out NodeIndex: Integer
);
begin
  NodeIndex := GlobalTree.AllocateNode;
  GlobalTree[NodeIndex]^.Data := ObjectId;
  GlobalTree[NodeIndex]^.LHS := EOT;
  GlobalTree[NodeIndex]^.RHS := EOT;
  GlobalTree[NodeIndex]^.Ref := GlobalTree.Expression.Append(TokenId, TokenText);
end;

function CreateIntegerNodeFromText(const ValueText: ansistring): Integer;
begin
  InitValueNode(TK_INTEGER, TK_INTEGER, ValueText, Result);
end;

function CreateFloatNodeFromText(
  const ValueText: ansistring
): Integer;
begin
  InitValueNode(TK_FLOAT, TK_FLOAT, ValueText, Result);
end;

function CreateStringNodeFromText(
  const ValueText: ansistring
): Integer;
begin
  InitValueNode(TK_STRING, TK_STRING, QuoteStringLiteral(ValueText), Result);
end;

function CreateNullNode: Integer;
begin
  InitValueNode(TK_VARIABLE, TK_NULL, 'null', Result);
end;

function CreateBooleanNode(const Value: Boolean): Integer;
begin
  if Value then
    InitValueNode(TK_VARIABLE, TK_BOOLEAN, 'true', Result)
  else
    InitValueNode(TK_VARIABLE, TK_BOOLEAN, 'false', Result);
end;

function CreateJsonEmptyContainerNode(const IsArray: Boolean): Integer;
begin
  if IsArray then
    InitValueNode(TK_VARIABLE, TK_JSON_EMPTY_ARRAY, '[]', Result)
  else
    InitValueNode(TK_VARIABLE, TK_JSON_EMPTY_OBJECT, '{}', Result);
end;

function CreateScalarNodeFromJson(JsonValue: TJSONData): Integer;
var
  NumberText: ansistring;
  LowerText: ansistring;
begin
  Result := EOT;
  if JsonValue = nil then
    Exit(EOT);

  case JsonValue.JSONType of
    jtString:
      Result := CreateStringNodeFromText(JsonValue.AsString);
    jtNumber:
      begin
        NumberText := Trim(JsonValue.AsJSON);
        LowerText := LowerCase(NumberText);
        if (Pos('.', NumberText) > 0) or
           (Pos('e', LowerText) > 0) then
          Result := CreateFloatNodeFromText(NumberText)
        else
          Result := CreateIntegerNodeFromText(NumberText);
      end;
    jtBoolean:
      Result := CreateBooleanNode(JsonValue.AsBoolean);
    jtNull:
      Result := CreateNullNode;
  end;
end;

end.
