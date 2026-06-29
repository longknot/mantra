unit formatters;

{$I mantra.inc}

interface

type
  TFormatOption = (foFormatArrays);
  TFormatOptions = set of TFormatOption;

  TFormatConfig = record
    Offset: Integer;
    ColumnWidth: Integer;
    Separator: ansistring;
    NewLine: Boolean;
    Options: TFormatOptions;
  end;

  { TCustomFormatter }
  TCustomFormatter = class
  private
    FOutput: ansistring;
  public
    procedure Write(const Value: ansistring); virtual; overload;
    procedure WriteFormatted(Index: Integer); virtual;
    property Output: ansistring read FOutput;
  end;

  { TFormatter }
  TFormatter = class(TCustomFormatter)
  private
    //FArrayCount: Integer;
    FColumn: Boolean;
    FColumnWidth: Integer;

    FColumnPos: Integer;
    FNewLinePos: Integer;
    FMaxColWidth: Integer;
    FDynamicColWidth: Boolean;
    FSuppressRepeatedRHSOperators: Boolean;

    FColumnWidths: array [0..31] of Integer;
    FColumnIndex: Integer;

  public
    procedure Write(const Value: ansistring); override;
    constructor Create;
    procedure BeginColumn;
    procedure EndColumn;
    procedure Write(Index: Integer; Column: Boolean = False; PrevRHSOp: Integer = 0); overload;
    procedure WriteFormatted(Index: Integer); override;
    procedure WriteNewline;
    property DynamicColWidth: Boolean read FDynamicColWidth;
    property SuppressRepeatedRHSOperators: Boolean read FSuppressRepeatedRHSOperators write FSuppressRepeatedRHSOperators;
  end;

  { TTreeFormatter }
  TTreeFormatter = class(TCustomFormatter)
  private
    FNodes: array [Byte] of Integer;
  public
    procedure Write(Index, Level: Integer); overload;
    procedure WriteFormatted(Index: Integer); override;
  end;

  { TIRFormatter }
  TIRFormatter = class(TCustomFormatter)
  private
    function EscapeValue(const Value: ansistring): ansistring;
    procedure WriteNode(Index, ParentIndex, Depth: Integer);
  public
    procedure WriteFormatted(Index: Integer); override;
  end;

const
  DefaultFormat: TFormatConfig = (
    Offset: 0;
    ColumnWidth: 6;
    Separator: ' ';
    NewLine: False;
    Options: []
  );

implementation

uses
  strutils, sysutils, math, exp_trees, parsetree, tokens, nodes;

{ TCustomFormatter }

procedure TCustomFormatter.Write(const Value: ansistring);
begin
  FOutput := FOutput + Value; // + ' ';
end;

procedure TCustomFormatter.WriteFormatted(Index: Integer);
begin
  Write(GetNode(Index).TreeValue);
end;


{ TFormatter }

procedure TFormatter.Write(const Value: ansistring);
begin
  if Value <> '' then
    inherited Write(Value + ' ');
end;

constructor TFormatter.Create;
var
  I: Integer;
begin
  FDynamicColWidth := True;
  FSuppressRepeatedRHSOperators := True;
  for I := Low(FColumnWidths) to High(FColumnWidths) do
    FColumnWidths[I] := 0;
end;

procedure TFormatter.BeginColumn;
begin
  //FOutput := FOutput + ' ';
  FColumn := True;
  FColumnPos := Length(FOutput) + 1;
  FColumnIndex := FColumnIndex + 1;

  FColumnWidth := FColumnWidths[FColumnIndex];
  //FMaxColWidth := 0;
end;

procedure TFormatter.EndColumn;
var
  ColValue: ansistring;
begin
  ColValue := Copy(FOutput, FColumnPos, MaxInt);
  //ColValue := Copy(FOutput, FColumnPos, Length(FOutput) - FColumnPos);
  ColValue := Trim(ColValue);

  //FColumnWidth := 15;
  //FMaxColWidth := Max(FMaxColWidth, Length(ColValue));
  FColumnWidths[FColumnIndex] := Max(FColumnWidths[FColumnIndex], Length(ColValue));
  //FColumnWidth := FMaxColWidth + 1;

  //ColValue := Copy(Colvalue, 1, FColumnWidth);

  ColValue := StringOfChar(' ', FColumnWidth - Length(ColValue)) + ColValue + ' ';
  SetLength(FOutput, FColumnPos - 1);

  FOutput := FOutput + ColValue;

  FColumnIndex := FColumnIndex - 1;
  //FColumnWidths[FColumnIndex] := FMaxColWidth;
end;

procedure TFormatter.WriteNewline;
begin
  FOutput := FOutput + #10;
  FNewLinePos := Length(FOutput);
end;

procedure TFormatter.Write(Index: Integer; Column: Boolean; PrevRHSOp: Integer);
var
  TokenId, CurOp: Integer;

  function StartsCompositeSibling(Index: Integer): Boolean;
  var
    NextId: Integer;
  begin
    Result := False;
    if Index = EOT then
      Exit;

    NextId := GlobalTree[Index]^.Id;
    if (NextId = OBJ_SEPARATOR) or (NextId = OBJ_VARIABLE_SUBTREE) then
      Exit;

    if (NextId and OBJ_CATEGORY_MASK) = OBJ_SPECIAL then
      Result := True;
  end;

  procedure WriteColumns(Index: Integer);
  var
    InnerTokenId: Integer;
    V: Boolean;
  begin
    if Index <> EOT then
    begin
      InnerTokenId := GlobalTree[Index]^.Id;
      V := (InnerTokenId <> OBJ_ARRAY) and (InnerTokenId <> OBJ_SEPARATOR) and (InnerTokenId <> OBJ_VARIABLE_SUBTREE);
(*
    if V then
    begin
      // adjust column width in first iteration
      L := Length(FOutput);
      FColumnWidth := 0;
      Write(Index, V);
      Inc(FColumnWidth, 3);
      SetLength(FOutput, L);
    end;
    *)
      Write(Index, V, 0);
    end;
  end;

  procedure WriteScope(Index: Integer);
  var
    ScopeStart: Integer;
    Indent: Integer;
    //ScopeTokenId: Integer;
  begin
    //ScopeTokenId := GlobalTree[Index]^.Id;
    ScopeStart := Length(FOutput);
    //NewLine := FNewLinePos;
    Indent := ScopeStart - FNewLinePos;
    //Write(P^.GetOperator);
    case TokenId of
      OBJ_EXPRESSION:
        begin
          Write('('); Write(GlobalTree[Index]^.LHS, False, 0); Write(')');
        end;
      OBJ_ARRAY:
        begin
          Write('[');
          //Write(P^.Child);
          WriteColumns(GlobalTree[Index]^.LHS);
          Write(']');
          if GlobalTree[Index]^.RHS <> EOT then
          begin
            //Write(#13#10);
            WriteNewLine;
            FOutput := FOutput + StringOfChar(' ', Indent);
            //Write(StringOfChar);
          end;
        end;
      OBJ_EVALUATION:
        begin
          Write('{'); Write(GlobalTree[Index]^.LHS, False, 0); Write('}');
        end;
      OBJ_COMPUTE:
        begin
          Write('`'); Write(GlobalTree[Index]^.LHS, False, 0); Write('`');
        end;
      // TK_COMMA ???
    end;
  end;


  procedure WriteSpecial(Index: Integer);
  var
    Indent, ScopeStart: Integer;
  begin
    //V := GlobalTree[Index]^.Data and TK_SPECIAL_MASK;
    ScopeStart := Length(FOutput);
    Indent := ScopeStart - FNewLinePos;
    case TokenId of
      OBJ_SEPARATOR:
        begin
          //Write(GlobalTree[Index]^.LHS, False, 0);
          WriteColumns(GlobalTree[Index]^.LHS);
          if GlobalTree[Index]^.RHS <> EOT then
          begin
            Write(',');
            WriteNewLine;
            FOutput := FOutput + StringOfChar(' ', Indent);
          end;
        end;
      OBJ_INDEX_LOOKUP:
        begin
          Write(GlobalTree[Index]^.LHS, False, 0);
          Write('@');
        end;
    else
      Write(GlobalTree[Index]^.LHS, False, 0);
      Write(TokenFromID(TokenId));
    end;
  end;

  procedure WritePairValue(Index: Integer);
  var
    Indent, ScopeStart: Integer;
  begin
    ScopeStart := Length(FOutput);
    Indent := ScopeStart - FNewLinePos;

    if GlobalTree[Index]^.Ref <> EOT then
      Write(GlobalTree.Expression.TokenValue(GlobalTree[Index]^.Ref));

    Write('->');
    WriteColumns(GlobalTree[Index]^.LHS);

    if GlobalTree[Index]^.RHS <> EOT then
    begin
      WriteNewLine;
      FOutput := FOutput + StringOfChar(' ', Indent);
    end;
  end;

begin

  // Q: compute maximum column width of entire tree?
  if Index <> EOT then
  begin
    TokenId := GlobalTree[Index]^.Id;

    if TokenId = OBJ_STATEMENT then
    begin
      Write(GlobalTree[Index]^.LHS, Column, 0);
      Write(GlobalTree[Index]^.RHS, Column, 0);
      Exit;
    end;

    CurOp := GlobalTree[Index]^.Data and TK_OPERATOR_MASK;
    if (GlobalTree[Index]^.Data and TK_CARET) = TK_CARET then
      Write('^');
    if CurOp <> 0 then
      if (not FSuppressRepeatedRHSOperators) or (CurOp <> PrevRHSOp) then
        Write(TokenFromID(CurOp));

    if Column then BeginColumn;

    if TokenId = OBJ_VARIABLE_SUBTREE then
      WritePairValue(Index)
    else
    if (TokenId and OBJ_CATEGORY_MASK) = OBJ_SCOPE then
      WriteScope(Index)
    else if TokenId and OBJ_CATEGORY_MASK = OBJ_SPECIAL then
    begin
      //if TokenId = OBJ_SEPARATOR then
        WriteSpecial(Index);
    end
    // else if TokenId and TK_RULE <> 0 then
    // begin
    //   // No rule-specific formatting yet; fall back to token text.
    //   if GlobalTree[Index]^.Ref >= 0 then
    //     Write(GlobalTree.Expression.TokenValue(GlobalTree[Index]^.Ref));
    //   Exit;
    // end
    else
    begin
      if (TokenId = TK_UNKNOWN) or
         ((GlobalTree[Index]^.Ref = EOT) and (GlobalTree[Index]^.LHS <> EOT)) then
        Write(GlobalTree[Index]^.LHS, False, 0);

      if TokenId <> TK_UNKNOWN then
        Write(GlobalTree.Expression.TokenValue(GlobalTree[Index]^.Ref));

    end;

    if Column then EndColumn;
      //FOutput := FOutput + P^.TokenValue + ' ';

    // N: linebreak at the end of LHS / RHS
    if (GlobalTree[Index]^.RHS <> EOT) and (not Column) and
       StartsCompositeSibling(GlobalTree[Index]^.RHS) then
      inherited Write('  ');
    Write(GlobalTree[Index]^.RHS, Column, CurOp);
  end;
end;

procedure TFormatter.WriteFormatted(Index: Integer);
const
  DEFAULT_COLUMN_WIDTH = 12;
begin
  if DynamicColWidth then
  begin
    FMaxColWidth := 0;
    FColumnWidth := 0;
    Write(Index);          // first pass: compute max column width
    FOutput := '';
    FColumnPos := 0;
    FNewLinePos := 0;
    FColumnWidth := FMaxColWidth;
  end
  else
    FColumnWidth := DEFAULT_COLUMN_WIDTH;

  Write(Index);
end;


{ TTreeFormatter }

procedure TTreeFormatter.Write(Index, Level: Integer);

  procedure WriteSubtree(Index: Integer);
  begin
    FNodes[Level] := Index;
    if GlobalTree[Index]^.LHS <> EOT then
    begin
      Write(GlobalTree[Index]^.LHS, Level + 1);
    end;
  end;

  procedure WriteEdge(Level: Integer);
  var
    I: Integer;
    S: string;
  begin
    if Level <= 0 then Exit;
    S := '';
    for I := 1 to Level - 1 do
    begin
      if GlobalTree[FNodes[I]]^.RHS <> EOT then
        S := S + '│   '
      else
        S := S + '    ';
    end;
    if GlobalTree[Index]^.RHS <> EOT then
      S := S + '├── '
    else
      S := S + '└── ';
    Write(S);
  end;

begin
  if Index <> EOT then
  begin
    //Write(StringOfChar(' ', Level * 4));
    WriteEdge(Level);
    //! Write(PBaseNode(GlobalTree[Index])^.ElementValue + #13#10);
    Write(GlobalTree.Expression.TokenValue(GlobalTree[Index]^.Ref) + #10);
    WriteSubtree(Index); //, Level + 1);
    Write(GlobalTree[Index]^.RHS, Level);
  end;
end;

procedure TTreeFormatter.WriteFormatted(Index: Integer);
begin
  Write(Index, 0);
end;

{ TIRFormatter }

function TIRFormatter.EscapeValue(const Value: ansistring): ansistring;
var
  I: Integer;
  C: AnsiChar;
begin
  Result := '';
  for I := 1 to Length(Value) do
  begin
    C := Value[I];
    case C of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9: Result := Result + '\t';
    else
      Result := Result + C;
    end;
  end;
end;

procedure TIRFormatter.WriteNode(Index, ParentIndex, Depth: Integer);
var
  NodeId: Integer;
  NodeToken: ansistring;
  RefToken: ansistring;
begin
  if Index = EOT then
    Exit;

  NodeId := GlobalTree[Index]^.Id;
  NodeToken := TokenFromID(NodeId);
  if NodeToken = '' then
    NodeToken := IntToStr(NodeId);

  RefToken := '';
  if GlobalTree[Index]^.Ref <> EOT then
    RefToken := GlobalTree.Expression.TokenValue(GlobalTree[Index]^.Ref);

  Write(Format(
    'node=%d parent=%d depth=%d id=%d id_token="%s" op=%d lhs=%d rhs=%d ref=%d data=0x%s ref_token="%s"' + LineEnding,
    [
      Index,
      ParentIndex,
      Depth,
      NodeId,
      EscapeValue(NodeToken),
      GlobalTree[Index]^.Data and TK_OPERATOR_MASK,
      GlobalTree[Index]^.LHS,
      GlobalTree[Index]^.RHS,
      GlobalTree[Index]^.Ref,
      IntToHex(GlobalTree[Index]^.Data, 8),
      EscapeValue(RefToken)
    ]
  ));

  WriteNode(GlobalTree[Index]^.LHS, Index, Depth + 1);
  WriteNode(GlobalTree[Index]^.RHS, ParentIndex, Depth);
end;

procedure TIRFormatter.WriteFormatted(Index: Integer);
begin
  if Index = EOT then
  begin
    Write('root=' + IntToStr(EOT));
    Exit;
  end;

  Write('root=' + IntToStr(Index) + LineEnding);
  WriteNode(Index, EOT, 0);
end;

end.
