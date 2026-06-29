unit runtime_settings;

{$I mantra.inc}

interface

uses
  exp_trees, context;

type
  TSettingReadResult = (
    srrNotFound,
    srrInvalid,
    srrFound
  );

function ReadIntegerSetting(
  Tree: TCustomTree;
  Context: TContext;
  const Names: array of ansistring;
  out Value: Integer;
  out SourceName: ansistring
): TSettingReadResult;

function ReadBooleanSetting(
  Tree: TCustomTree;
  Context: TContext;
  const Names: array of ansistring;
  out Value: Boolean;
  out SourceName: ansistring
): TSettingReadResult;

function ReadStringSetting(
  Tree: TCustomTree;
  Context: TContext;
  const Names: array of ansistring;
  out Value: ansistring;
  out SourceName: ansistring
): TSettingReadResult;

implementation

uses
  SysUtils, tokens;

const
  MAX_SETTING_RESOLVE_DEPTH = 32;

function NormalizeScalarText(const Text: ansistring): ansistring;
begin
  Result := Trim(Text);
  if Length(Result) >= 2 then
    if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
       ((Result[1] = #39) and (Result[Length(Result)] = #39)) then
      Result := Copy(Result, 2, Length(Result) - 2);
  Result := Trim(Result);
end;

function TryLookupSettingNode(
  Context: TContext;
  const Names: array of ansistring;
  out NodeIndex: Integer;
  out SourceName: ansistring
): Boolean;
var
  I: Integer;
  Candidate: ansistring;
begin
  Result := False;
  NodeIndex := EOT;
  SourceName := '';
  if not Assigned(Context) then
    Exit(False);

  for I := 0 to High(Names) do
  begin
    Candidate := Trim(Names[I]);
    if Candidate = '' then
      Continue;
    if Context.TryFindSettingVariable(Candidate, SourceName, NodeIndex) then
    begin
      Exit(True);
    end;
  end;
end;

function ResolveSettingLeafNode(
  Tree: TCustomTree;
  Context: TContext;
  StartIndex: Integer;
  out LeafIndex: Integer
): Boolean;
var
  CurIndex: Integer;
  NextIndex: Integer;
  ResolvedName: ansistring;
  SymbolName: ansistring;
  Depth: Integer;
begin
  Result := False;
  LeafIndex := EOT;
  CurIndex := StartIndex;

  for Depth := 0 to MAX_SETTING_RESOLVE_DEPTH - 1 do
  begin
    if CurIndex = EOT then
      Exit(False);

    case Tree[CurIndex]^.Id of
      TK_VARIABLE:
        begin
          SymbolName := Tree.Expression.TokenValue(Tree[CurIndex]^.Ref);
          if SymbolName = '' then
            Exit(False);
          if Assigned(Context) and
             Context.TryFindSettingVariable(SymbolName, ResolvedName, NextIndex) then
          begin
            CurIndex := NextIndex;
            Continue;
          end;
          LeafIndex := CurIndex;
          Exit(True);
        end;
      TK_CURLY_BEGIN, TK_PARENTHESIS_BEGIN:
        begin
          if (Tree[CurIndex]^.RHS <> EOT) or (Tree[CurIndex]^.LHS = EOT) then
            Exit(False);
          CurIndex := Tree[CurIndex]^.LHS;
        end;
    else
      begin
        LeafIndex := CurIndex;
        Exit(True);
      end;
    end;
  end;
end;

function ReadIntegerSetting(
  Tree: TCustomTree;
  Context: TContext;
  const Names: array of ansistring;
  out Value: Integer;
  out SourceName: ansistring
): TSettingReadResult;
var
  StartIndex: Integer;
  LeafIndex: Integer;
  TokenText: ansistring;
begin
  Value := 0;
  SourceName := '';
  if not TryLookupSettingNode(Context, Names, StartIndex, SourceName) then
    Exit(srrNotFound);
  if not ResolveSettingLeafNode(Tree, Context, StartIndex, LeafIndex) then
    Exit(srrInvalid);

  case Tree[LeafIndex]^.Id of
    TK_INTEGER:
      begin
        TokenText := Tree.Expression.TokenValue(Tree[LeafIndex]^.Ref);
        if not TryStrToInt(TokenText, Value) then
          Exit(srrInvalid);
        Exit(srrFound);
      end;
    TK_STRING:
      begin
        TokenText := NormalizeScalarText(Tree.Expression.TokenValue(Tree[LeafIndex]^.Ref));
        if not TryStrToInt(TokenText, Value) then
          Exit(srrInvalid);
        Exit(srrFound);
      end;
  else
    Exit(srrInvalid);
  end;
end;

function ReadBooleanSetting(
  Tree: TCustomTree;
  Context: TContext;
  const Names: array of ansistring;
  out Value: Boolean;
  out SourceName: ansistring
): TSettingReadResult;
var
  StartIndex: Integer;
  LeafIndex: Integer;
  TokenText: ansistring;
  NumberValue: Integer;
begin
  Value := False;
  SourceName := '';
  if not TryLookupSettingNode(Context, Names, StartIndex, SourceName) then
    Exit(srrNotFound);
  if not ResolveSettingLeafNode(Tree, Context, StartIndex, LeafIndex) then
    Exit(srrInvalid);

  if Tree[LeafIndex]^.Id = TK_INTEGER then
  begin
    TokenText := Tree.Expression.TokenValue(Tree[LeafIndex]^.Ref);
    if not TryStrToInt(TokenText, NumberValue) then
      Exit(srrInvalid);
    Value := NumberValue <> 0;
    Exit(srrFound);
  end;

  TokenText := '';
  case Tree[LeafIndex]^.Id of
    TK_STRING, TK_VARIABLE:
      TokenText := Tree.Expression.TokenValue(Tree[LeafIndex]^.Ref);
  else
    Exit(srrInvalid);
  end;

  TokenText := LowerCase(NormalizeScalarText(TokenText));
  if (TokenText = '1') or (TokenText = 'true') or
     (TokenText = 'yes') or (TokenText = 'on') or
     (TokenText = 'strict') or (TokenText = 'enabled') then
  begin
    Value := True;
    Exit(srrFound);
  end;
  if (TokenText = '0') or (TokenText = 'false') or
     (TokenText = 'no') or (TokenText = 'off') or
     (TokenText = 'loose') or (TokenText = 'disabled') then
  begin
    Value := False;
    Exit(srrFound);
  end;

  Exit(srrInvalid);
end;

function ReadStringSetting(
  Tree: TCustomTree;
  Context: TContext;
  const Names: array of ansistring;
  out Value: ansistring;
  out SourceName: ansistring
): TSettingReadResult;
var
  StartIndex: Integer;
  LeafIndex: Integer;
begin
  Value := '';
  SourceName := '';
  if not TryLookupSettingNode(Context, Names, StartIndex, SourceName) then
    Exit(srrNotFound);
  if not ResolveSettingLeafNode(Tree, Context, StartIndex, LeafIndex) then
    Exit(srrInvalid);

  case Tree[LeafIndex]^.Id of
    TK_STRING, TK_VARIABLE:
      begin
        Value := NormalizeScalarText(Tree.Expression.TokenValue(Tree[LeafIndex]^.Ref));
        Exit(srrFound);
      end;
  else
    Exit(srrInvalid);
  end;
end;

end.
