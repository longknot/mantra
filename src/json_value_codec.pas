unit json_value_codec;

{$I mantra.inc}

interface

uses
  context, fpjson;

function BuildJsonDataFromPath(
  Context: TContext;
  const Path: ansistring
): TJSONData;

function EscapeTrieSegment(const Segment: ansistring): ansistring;
function DecodeTrieSegment(
  const Encoded: ansistring;
  out Decoded: ansistring
): Boolean;

function MaterializeJsonValueAtState(
  Context: TContext;
  const TargetState: TVariableTrieState;
  JsonValue: TJSONData
): Boolean;

function MaterializeJsonValueAtPath(
  Context: TContext;
  const Path: ansistring;
  JsonValue: TJSONData
): Boolean;

function BuildVegaLiteJsonDataFromPath(
  Context: TContext;
  const Path: ansistring
): TJSONData;

function EncodeJsonPath(
  Context: TContext;
  const Path: ansistring
): ansistring;

implementation

uses
  Classes, SysUtils, Math, exp_trees, parsetree, tokens, string_utils,
  value_node_helpers;

function EscapeTrieSegment(const Segment: ansistring): ansistring;
var
  I: Integer;
  C: ansichar;
begin
  Result := '';
  for I := 1 to Length(Segment) do
  begin
    C := Segment[I];
    case C of
      '.', '[', ']', '*', '?', '%', '_':
        Result := Result + '_x' + IntToHex(Ord(C), 2) + '_';
    else
      Result := Result + C;
    end;
  end;
end;

function DecodeTrieSegment(
  const Encoded: ansistring;
  out Decoded: ansistring
): Boolean;
var
  I: Integer;
  HexValue: Integer;
  HexText: ansistring;
begin
  Result := False;
  Decoded := '';
  I := 1;
  while I <= Length(Encoded) do
  begin
    if (Encoded[I] = '_') and
       (I + 4 <= Length(Encoded)) and
       (Encoded[I + 1] = 'x') and
       (Encoded[I + 4] = '_') then
    begin
      HexText := Copy(Encoded, I + 2, 2);
      if not TryStrToInt('$' + HexText, HexValue) then
        Exit(False);
      Decoded := Decoded + AnsiChar(HexValue);
      Inc(I, 5);
    end
    else
    begin
      Decoded := Decoded + Encoded[I];
      Inc(I);
    end;
  end;
  Result := True;
end;

function MaterializeJsonValueAtState(
  Context: TContext;
  const TargetState: TVariableTrieState;
  JsonValue: TJSONData
): Boolean;
var
  I: Integer;
  ChildState: TVariableTrieState;
  FieldSuffix: ansistring;
  ScalarNode: Integer;
  JsonObject: TJSONObject;
  JsonArray: TJSONArray;
begin
  Result := False;
  if not Assigned(Context) or (JsonValue = nil) then
    Exit(False);

  case JsonValue.JSONType of
    jtObject:
      begin
        JsonObject := TJSONObject(JsonValue);
        if JsonObject.Count = 0 then
        begin
          ScalarNode := CreateJsonEmptyContainerNode(False);
          Result := (ScalarNode <> EOT) and
                    Context.AddVariableAtState(TargetState, ScalarNode);
          if (ScalarNode <> EOT) and (not Result) then
            GlobalTree.DeleteSubtree(EOT, ScalarNode);
          Exit;
        end;
        for I := 0 to JsonObject.Count - 1 do
        begin
          FieldSuffix := '.' + EscapeTrieSegment(JsonObject.Names[I]);
          if not Context.EnsureVariableSuffixState(TargetState, FieldSuffix, ChildState) then
            Exit(False);
          if not MaterializeJsonValueAtState(Context, ChildState, JsonObject.Items[I]) then
            Exit(False);
        end;
        Result := True;
      end;
    jtArray:
      begin
        JsonArray := TJSONArray(JsonValue);
        if not Context.IsVariableStateIndexed(TargetState) then
          if not Context.MarkVariableStateIndexed(TargetState, JsonArray.Count) then
            Exit(False);
        if JsonArray.Count = 0 then
        begin
          ScalarNode := CreateJsonEmptyContainerNode(True);
          Result := (ScalarNode <> EOT) and
                    Context.AddVariableAtState(TargetState, ScalarNode);
          if (ScalarNode <> EOT) and (not Result) then
            GlobalTree.DeleteSubtree(EOT, ScalarNode);
          Exit;
        end;
        for I := 0 to JsonArray.Count - 1 do
        begin
          if not Context.EnsureIndexedVariableChild(TargetState, I, ChildState) then
            Exit(False);
          if not MaterializeJsonValueAtState(Context, ChildState, JsonArray.Items[I]) then
            Exit(False);
        end;
        Result := True;
      end;
  else
    begin
      ScalarNode := CreateScalarNodeFromJson(JsonValue);
      if ScalarNode = EOT then
        Exit(False);
      Result := Context.AddVariableAtState(TargetState, ScalarNode);
      if not Result then
        GlobalTree.DeleteSubtree(EOT, ScalarNode);
    end;
  end;
end;

function MaterializeJsonValueAtPath(
  Context: TContext;
  const Path: ansistring;
  JsonValue: TJSONData
): Boolean;
var
  RootState: TVariableTrieState;
begin
  Result := Assigned(Context) and
            (Trim(Path) <> '') and
            Context.EnsureVariableState(Path, RootState) and
            MaterializeJsonValueAtState(Context, RootState, JsonValue);
end;

function TryParseIndexedChild(
  const ParentPath, ChildPath: ansistring;
  out IndexOneBased: SizeInt
): Boolean;
var
  Suffix: ansistring;
  IndexText: ansistring;
  ParsedIndex: QWord;
begin
  Result := False;
  IndexOneBased := 0;
  if Copy(ChildPath, 1, Length(ParentPath)) <> ParentPath then
    Exit(False);
  Suffix := Copy(ChildPath, Length(ParentPath) + 1, MaxInt);
  if (Length(Suffix) < 3) or
     (Suffix[1] <> '[') or
     (Suffix[Length(Suffix)] <> ']') then
    Exit(False);
  IndexText := Copy(Suffix, 2, Length(Suffix) - 2);
  if (IndexText = '') or (not TryStrToQWord(IndexText, ParsedIndex)) or
     (ParsedIndex = 0) or (ParsedIndex > High(SizeInt)) then
    Exit(False);
  IndexOneBased := SizeInt(ParsedIndex);
  Result := True;
end;

function JsonScalarFromNode(
  ValueRef: Integer;
  AllowInvalidValue: Boolean
): TJSONData;
var
  TokenId: Integer;
  TokenText: ansistring;
  StringValue: ansistring;
  NumericText: ansistring;
  OperatorBits: Integer;
  IntegerValue: Int64;
  FloatValue: Double;
begin
  if (ValueRef = EOT) or
     (GlobalTree[ValueRef]^.LHS <> EOT) or
     (GlobalTree[ValueRef]^.RHS <> EOT) then
  begin
    if AllowInvalidValue then
      Exit(TJSONNull.Create);
    raise Exception.Create('json_encode supports scalar leaf nodes only');
  end;

  TokenId := GlobalTree.Expression.TokenID(GlobalTree[ValueRef]^.Ref);
  TokenText := GlobalTree.Expression.TokenValue(GlobalTree[ValueRef]^.Ref);
  NumericText := Trim(TokenText);
  OperatorBits := GlobalTree[ValueRef]^.Data and TK_OPERATOR_MASK;
  if (OperatorBits and (not (TK_PLUS or TK_MINUS))) <> 0 then
  begin
    if AllowInvalidValue then
      Exit(TJSONNull.Create);
    raise Exception.CreateFmt(
      'json_encode does not support numeric operator on %s',
      [TokenText]
    );
  end;
  if (OperatorBits and TK_MINUS) <> 0 then
  begin
    if (NumericText = '') or (NumericText[1] <> '-') then
      NumericText := '-' + NumericText;
  end;

  case GlobalTree[ValueRef]^.Id of
    TK_STRING:
      begin
        if not UnquoteStringLiteral(TokenText, StringValue) then
          raise Exception.Create('json_encode encountered an invalid string literal');
        Result := TJSONString.Create(StringValue);
      end;
    TK_INTEGER:
      begin
        if not TryStrToInt64(NumericText, IntegerValue) then
        begin
          if AllowInvalidValue then
            Exit(TJSONNull.Create);
          raise Exception.CreateFmt(
            'json_encode encountered an invalid integer: %s',
            [TokenText]
          );
        end;
        Result := TJSONIntegerNumber.Create(IntegerValue);
      end;
    TK_FLOAT:
      begin
        if not TryStrToFloat(NumericText, FloatValue, DefaultFormatSettings) or
           IsNan(FloatValue) or IsInfinite(FloatValue) then
        begin
          if AllowInvalidValue then
            Exit(TJSONNull.Create);
          raise Exception.CreateFmt(
            'json_encode requires a finite float, got %s',
            [TokenText]
          );
        end;
        Result := TJSONFloatNumber.Create(FloatValue);
      end;
    TK_VARIABLE:
      case TokenId of
        TK_NULL:
          Result := TJSONNull.Create;
        TK_BOOLEAN:
          Result := TJSONBoolean.Create(SameText(Trim(TokenText), 'true'));
        TK_JSON_EMPTY_OBJECT, TK_JSON_EMPTY_ARRAY:
          Result := nil;
      else
        begin
          if AllowInvalidValue then
            Exit(TJSONNull.Create);
        raise Exception.CreateFmt(
          'json_encode does not support variable leaf %s',
          [TokenText]
        );
        end;
      end;
  else
    begin
      if AllowInvalidValue then
        Exit(TJSONNull.Create);
    raise Exception.CreateFmt(
      'json_encode does not support node type %d',
      [GlobalTree[ValueRef]^.Id]
    );
    end;
  end;
end;

function IsInlineDataValuePath(const Path: ansistring): Boolean;
var
  ValuesPos: SizeInt;
  CloseBracketPos: SizeInt;
begin
  ValuesPos := Pos('.data.values[', Path);
  if ValuesPos = 0 then
    ValuesPos := Pos('data.values[', Path);
  if ValuesPos = 0 then
    Exit(False);

  CloseBracketPos := Pos(']', Copy(Path, ValuesPos, MaxInt));
  Result := CloseBracketPos > 0;
end;

function BuildJsonDataFromPathWithPolicy(
  Context: TContext;
  const Path: ansistring;
  AllowInvalidDataValues: Boolean
): TJSONData;
var
  ResolvedPath: ansistring;
  LocatedPath: ansistring;
  ValuePath: ansistring;
  State: TVariableTrieState;
  StateLocated: Boolean;
  IsIndexedContainer: Boolean;
  ValueRef: Integer;
  HasValue: Boolean;
  TokenId: Integer;
  IsEmptyObjectMarker: Boolean;
  IsEmptyArrayMarker: Boolean;
  Children: TStringList;
  ChildValues: array of TJSONData;
  ChildIndexes: array of SizeInt;
  ChildPath: ansistring;
  ChildIndex: SizeInt;
  MaxIndex: SizeInt;
  I: Integer;
  Suffix: ansistring;
  FieldName: ansistring;
  JsonObject: TJSONObject;
  JsonArray: TJSONArray;
begin
  Result := nil;
  if not Assigned(Context) then
    raise Exception.Create('json_encode requires an execution context');
  if Trim(Path) = '' then
    raise Exception.Create('json_encode path cannot be empty');
  ResolvedPath := Trim(Path);
  StateLocated := Context.TryLocateVariableState(Path, LocatedPath, State);
  if StateLocated then
    ResolvedPath := LocatedPath;
  HasValue := Context.TryFindVariableResolved(Path, ValuePath, ValueRef);
  if HasValue then
    ResolvedPath := ValuePath;
  TokenId := 0;
  if HasValue then
    TokenId := GlobalTree.Expression.TokenID(GlobalTree[ValueRef]^.Ref);
  IsEmptyObjectMarker := HasValue and (TokenId = TK_JSON_EMPTY_OBJECT);
  IsEmptyArrayMarker := HasValue and (TokenId = TK_JSON_EMPTY_ARRAY);

  Children := TStringList.Create;
  try
    Context.ScanVariableChildren(ResolvedPath, Children);
    if (not StateLocated) and (not HasValue) and (Children.Count = 0) then
      raise Exception.CreateFmt('json_encode path not found: %s', [Path]);

    IsIndexedContainer := StateLocated and Context.IsVariableStateIndexed(State);
    if (not IsIndexedContainer) and (Children.Count > 0) then
      IsIndexedContainer :=
        Copy(Children[0], 1, Length(ResolvedPath) + 1) = ResolvedPath + '[';

    if IsIndexedContainer then
    begin
      if HasValue and (not IsEmptyArrayMarker) then
        raise Exception.CreateFmt(
          'json_encode array path also contains a scalar value: %s',
          [ResolvedPath]
        );
      if IsEmptyArrayMarker then
      begin
        if Children.Count <> 0 then
          raise Exception.CreateFmt(
            'json_encode empty-array marker has children: %s',
            [ResolvedPath]
          );
        Exit(TJSONArray.Create);
      end;

      MaxIndex := 0;
      SetLength(ChildIndexes, Children.Count);
      for I := 0 to Children.Count - 1 do
      begin
        if not TryParseIndexedChild(ResolvedPath, Children[I], ChildIndex) then
          raise Exception.CreateFmt(
            'json_encode array has a non-index child: %s',
            [Children[I]]
          );
        ChildIndexes[I] := ChildIndex;
        if ChildIndex > MaxIndex then
          MaxIndex := ChildIndex;
      end;
      if MaxIndex <> SizeInt(Children.Count) then
        raise Exception.CreateFmt(
          'json_encode requires contiguous arrays at %s',
          [ResolvedPath]
        );

      SetLength(ChildValues, Children.Count);
      for I := 0 to Children.Count - 1 do
      begin
        ChildIndex := ChildIndexes[I];
        if Assigned(ChildValues[ChildIndex - 1]) then
          raise Exception.CreateFmt(
            'json_encode array has duplicate index %d at %s',
            [ChildIndex, ResolvedPath]
          );
        ChildValues[ChildIndex - 1] :=
          BuildJsonDataFromPathWithPolicy(
            Context,
            Children[I],
            AllowInvalidDataValues
          );
      end;

      JsonArray := TJSONArray.Create;
      try
        for I := 0 to High(ChildValues) do
        begin
          if not Assigned(ChildValues[I]) then
            raise Exception.CreateFmt(
              'json_encode array is missing index %d at %s',
              [I + 1, ResolvedPath]
            );
          JsonArray.Add(ChildValues[I]);
          ChildValues[I] := nil;
        end;
        Result := JsonArray;
        JsonArray := nil;
      finally
        JsonArray.Free;
        for I := 0 to High(ChildValues) do
          ChildValues[I].Free;
      end;
      Exit;
    end;

    if IsEmptyArrayMarker then
      raise Exception.CreateFmt(
        'json_encode array marker is not on an indexed path: %s',
        [ResolvedPath]
      );
    if IsEmptyObjectMarker then
    begin
      if Children.Count <> 0 then
        raise Exception.CreateFmt(
          'json_encode empty-object marker has children: %s',
          [ResolvedPath]
        );
      Exit(TJSONObject.Create);
    end;

    if Children.Count = 0 then
    begin
      if not HasValue then
        raise Exception.CreateFmt(
          'json_encode cannot infer the empty container type at %s',
          [ResolvedPath]
        );
      Exit(JsonScalarFromNode(
        ValueRef,
        AllowInvalidDataValues and IsInlineDataValuePath(ResolvedPath)
      ));
    end;

    if HasValue then
      raise Exception.CreateFmt(
        'json_encode object path also contains a scalar value: %s',
        [ResolvedPath]
      );

    JsonObject := TJSONObject.Create;
    try
      for I := 0 to Children.Count - 1 do
      begin
        ChildPath := Children[I];
        if Copy(ChildPath, 1, Length(ResolvedPath) + 1) <> ResolvedPath + '.' then
          raise Exception.CreateFmt(
            'json_encode object child %s is not below %s',
            [ChildPath, ResolvedPath]
          );
        Suffix := Copy(ChildPath, Length(ResolvedPath) + 2, MaxInt);
        if (Suffix = '') or (Pos('.', Suffix) > 0) or (Pos('[', Suffix) > 0) then
          raise Exception.CreateFmt(
            'json_encode encountered an invalid immediate child: %s',
            [ChildPath]
          );
        if not DecodeTrieSegment(Suffix, FieldName) then
          raise Exception.CreateFmt(
            'json_encode encountered an invalid encoded key: %s',
            [Suffix]
          );
        JsonObject.Add(
          FieldName,
          BuildJsonDataFromPathWithPolicy(
            Context,
            ChildPath,
            AllowInvalidDataValues
          )
        );
      end;
      Result := JsonObject;
      JsonObject := nil;
    finally
      JsonObject.Free;
    end;
  finally
    Children.Free;
  end;
end;

function BuildJsonDataFromPath(
  Context: TContext;
  const Path: ansistring
): TJSONData;
begin
  Result := BuildJsonDataFromPathWithPolicy(Context, Path, False);
end;

function BuildVegaLiteJsonDataFromPath(
  Context: TContext;
  const Path: ansistring
): TJSONData;
begin
  Result := BuildJsonDataFromPathWithPolicy(Context, Path, True);
end;

function EncodeJsonPath(
  Context: TContext;
  const Path: ansistring
): ansistring;
var
  JsonValue: TJSONData;
begin
  JsonValue := BuildJsonDataFromPath(Context, Trim(Path));
  try
    Result := JsonValue.AsJSON;
  finally
    JsonValue.Free;
  end;
end;

end.
