unit exp_tokenizer;

{$I mantra.inc}

interface

uses
  objects, classes, stringlist, consts;

type
  (*
  PTokenInfo = ^TTokenInfo;
  TTokenInfo = record
    ID: Integer;          // Word (?)
    case Integer of
      0: (IntValue: Int64);
      1: (FloatValue: Double);
      2: (Symbol, Flags: Cardinal);
      3: (Data: Pointer);
  end;
  *)
  PTokenInfo = ^TTokenInfo;
  TTokenInfo = packed record
    ID: Cardinal;
    //Raw: ansistring;
    Line, Col: Integer;      // location in source file
    //Offset: Integer;
    // N: string uniquely defined by index in hash list (hash value can match multiple strings)
    Index: Integer;      // index in hash list
    //Hash: Cardinal;
  end;
  TArrayOfTokenInfo = array of TTokenInfo;
  //TExpression = array of TTokenData;

const
  EMPTY_TOKEN: TTokenInfo = (
    ID: 0;
    //Raw: '';
    Line: 0;
    Col: 0;
    //Offset: 0;
    Index: -1;
  );
// text <-> expression
type
  TCustomTokenizer = class;

  { TStringHelper }
  TStringHelper = class
  private
    FInput: ansistring;
    FIndex: Integer;
    //FStartIndex: Integer;
    //FPushedIndex: Integer; // not really a stack!
  public
    constructor Create(const AInput: ansistring);
    //procedure Push;
    //procedure Pop;
    function ReadChar(Advance: Boolean = True): AnsiChar;
    function Offset(AOffset: Integer): Integer;
    function Search(const Pattern: ansistring): Integer;
    property Index: Integer read FIndex write FIndex;
  end;

//  TTokenParserFunc = function(Helper: TStringHelper; out Data: TTokenData): Boolean of object;
//  TArrayOfTokenParser = array of TTokenParserFunc;

  { TCustomExpression }
  TCustomExpression = class(TPersistent)
  private
    //FHashList: THashList;
    FValues: TLKStringList;

    FTokens: TArrayOfTokenInfo;
    FSize: Integer;
    FCapacity: Integer;

    FIndex: Integer;
    //FHelper: TStringHelper;
    FSource: ansistring;
    function GetToken(AIndex: Integer): PTokenInfo;
  public
    constructor Create;
    destructor Destroy; override;
    function AddToken(const AToken: TTokenInfo): Integer; virtual;
    function AddToken(ID: Cardinal; const Value: ansistring; ALine: Integer = 0;
      ACol: Integer = 0): Integer; virtual;
    function NextToken: PTokenInfo;
    function LastToken: PTokenInfo;
    function CurToken: PTokenInfo;
    function GetTokenizer: TCustomTokenizer; virtual;

    function Accept(ID: Cardinal; Mask: Cardinal = $ffffffff): Integer;
    function AcceptMask(Mask: Cardinal): Integer;
    function Expect(ID: Cardinal; Mask: Cardinal = $ffffffff): Integer;
    function TokenFromID(ID: Cardinal): ansistring;

    function Clone(AIndex: Integer): Integer;
    function Append(ID: Cardinal; const Value: ansistring): Integer; overload;
    function Append(ID: Cardinal; const Value: Double): Integer; overload;
    //function Consume(ID: Integer): PTokenInfo;

    function TokenValue(AIndex: Integer): ansistring; overload;
    function TokenValue(AIndex, Next: Integer): ansistring; overload;
    function TokenID(AIndex: Integer): Integer;
    //function ValueIndex(AIndex: Integer): Integer;
    function CurTokenValue: ansistring;

    property Tokens: TArrayOfTokenInfo read FTokens;
    property Token[Index: Integer]: PTokenInfo read GetToken;

    function PrintExpression: string;

    //property Helper: TStringHelper read FHelper;
    property Source: ansistring read FSource write FSource;
    property Index: Integer read FIndex write FIndex;
    property Size: Integer read FSize;
    property Capacity: Integer read FCapacity;
    property Values: TLKStringList read FValues;
  end;



  TTransition = array [AnsiChar] of Integer;
  //TArrayOfTransition = array of TTransition;

  PState = ^TState;
  TState = record
    Transitions: TTransition;
    ID: Integer;       // state identifier
    //RealID: Integer;
    PrevID: Integer;   // previous state identifier
    Index: Integer;    // position in state array
    Token: ansistring;
  end;
  TArrayOfState = array of TState;

  TTokenOption = (toCaseInsensitive);
  TTokenOptions = set of TTokenOption;

  { TCustomTokenizer }
  TCustomTokenizer = class(TPersistent)
  private
    FIgnoreMask: Cardinal;
    //FStates: TArrayOfState;
    FStates: TList;
    FNextStateID: Integer;
    FOptions: TTokenOptions;
  protected
    function RealState(ID: Integer): Integer;
    function GetNextStateID: Integer;
    function GetCharSet(const X: TCharSet): TCharSet;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    // advance from one state to another
    function AddState: PState;
    function AddState(ID: Integer): PState;
    function FindState(ID: Integer): PState;
    function AddTransition(Src, Dst: PState; C: Char): PState; overload;
    function AddTransition(const X: ansistring; Dst: Integer): PState; overload;
    function AddTransition(const X: ansistring; Src, Dst: Integer): PState; overload;
    function AddTransition(const X: TCharSet; Dst: Integer): PState; overload;
    function AddTransition(const X: TCharSet; Src, Dst: Integer): PState; overload;
    procedure PostprocessTransitions;

    function Advance(ID: Integer; Token: AnsiChar): Integer; overload;
    function Advance(ID: Integer; const Tokens: ansistring): Integer; overload;
    procedure Tokenize(
      const Input: ansistring;
      Expression: TCustomExpression;
      ALineOffset: Integer = 0;
      AColOffset: Integer = 0
    );

    property Options: TTokenOptions read FOptions write FOptions;
    property IgnoreMask: Cardinal read FIgnoreMask write FIgnoreMask;
  end;

//function StringToExpression(const S: ansistring): TExpression;
//function ExpressionToString(const E: TExpression): ansistring;
//procedure RegisterToken(Value: ansistring; TokenType: Cardinal; Symbol: Cardinal = 0; Flags: Cardinal = 0);

implementation

uses
  StrUtils, SysUtils;

function TCustomExpression.PrintExpression: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Size - 1 do //High(Tokens) do
  begin
    //Result := Result + '[' + Tokens[I].Raw + ']';
    //Result := Result + Tokens[I].Raw + ' ';
    Result := Result + '[ ' + TokenValue(I) + ' ] ';
  end;
end;

function TCustomExpression.GetToken(AIndex: Integer): PTokenInfo;
begin
  Result := @FTokens[AIndex];
end;

constructor TCustomExpression.Create;
begin
  inherited Create;
  FIndex := 0;
  FSize := 0;
  FCapacity := EXP_CAPACITY;
  SetLength(FTokens, FCapacity);
  FValues := TLKStringList.Create;
end;

destructor TCustomExpression.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

function TCustomExpression.AddToken(const AToken: TTokenInfo): Integer;
begin
  Result := FSize;
  Inc(FSize);
  if FSize >= FCapacity then
  begin
    FCapacity := FCapacity * 2;
    SetLength(FTokens, FCapacity);
  end;
  FTokens[Result] := AToken;
end;

function TCustomExpression.AddToken(ID: Cardinal; const Value: ansistring;
  ALine: Integer; ACol: Integer): Integer;
var
  T: TTokenInfo;
begin
  T := EMPTY_TOKEN;
  T.ID := ID;
  T.Line := ALine;
  T.Col := ACol;
  if ID <> 0 then
    T.Index := FValues.Add(Value);
  Result := AddToken(T);
end;

function TCustomExpression.NextToken: PTokenInfo;
begin
  Result := nil;
  if FIndex < FSize then
  begin
    Result := @FTokens[FIndex];
    if Result^.ID = 0 then
      Exit(nil);
    Inc(FIndex);
  end;
end;

function TCustomExpression.LastToken: PTokenInfo;
begin
  Result := nil;
  if FIndex >= 1 then
    Result := @FTokens[FIndex - 1];
end;

function TCustomExpression.Accept(ID: Cardinal; Mask: Cardinal): Integer;
var
  P: PTokenInfo;
begin
  //WriteLn(Format('Index(%d), Accept(%s)', [FIndex, TokenFromID(ID)]));
  Result := -1;
  // Result := False;
  P := CurToken;
  if Assigned(P) and (CurToken^.ID and Mask = ID) then
  begin
    Result := FIndex;
    NextToken;
    //Result := True;
  end;
end;

function TCustomExpression.AcceptMask(Mask: Cardinal): Integer;
var
  P: PTokenInfo;
begin
  //WriteLn(Format('Index(%d) AcceptMask', [FIndex]));
  //if CurToken = nil then
  //  WriteLn('curtoken = nil');
  //Result := False;
  Result := -1;
  P := CurToken;
  if Assigned(P) and (CurToken^.ID and Mask <> 0) then
  begin
    Result := FIndex;
    NextToken;
    //Result := True;
  end;
end;

function TCustomExpression.Expect(ID: Cardinal; Mask: Cardinal): Integer;
begin
  //WriteLn(Format('Index(%d), Expect(%s)', [FIndex, TokenFromID(ID)]));
  //Result := True;
  Result := Accept(ID, Mask);
  if Result = -1 then
  begin
    if Assigned(CurToken) then
      raise Exception.CreateFmt(
        'Unexpected symbol at %d:%d (%s). Expected: %s',
        [CurToken^.Line, CurToken^.Col, TokenValue(FIndex), TokenFromID(ID)]
      );
    raise Exception.CreateFmt('Unexpected end of input. Expected: %s', [TokenFromID(ID)]);
  end;
end;

function TCustomExpression.TokenFromID(ID: Cardinal): ansistring;
var
  T: TCustomTokenizer;
  S: PState;
begin
  Result := '';
  T := GetTokenizer;
  if Assigned(T) then
  begin
    S := T.FindState(ID);
    if Assigned(S) then
      Result := S^.Token;
  end;
end;

function TCustomExpression.Clone(AIndex: Integer): Integer;
begin

  // Q: negative offset ---> dynamic lookup
  Result := AddToken(FTokens[AIndex]);
  (*
  if AIndex < 0  then
    Result := AIndex
  else
  begin
    L := Length(FSource);
    FSource := FSource + TokenValue(AIndex);
    Result := AddToken(FTokens[AIndex]);
    FTokens[Result].Offset := L + 1;
  end;
  *)
end;

function TCustomExpression.Append(ID: Cardinal; const Value: ansistring
  ): Integer;
var
  T: TTokenInfo;
begin
  T := EMPTY_TOKEN;
  T.ID := ID;
  T.Index := FValues.Add(Value);
  Result := AddToken(T);
  //FSource := FSource + Value;
end;

function TCustomExpression.Append(ID: Cardinal; const Value: Double): Integer;
var
  L: Integer;
begin
  L := Length(FSource);
  SetLength(FSource, L + SizeOf(Double));
  Move(Value, FSource[L], SizeOf(Double));
  Result := L;
end;

function TCustomExpression.TokenValue(AIndex: Integer): ansistring;
begin
  Result := TokenValue(AIndex, AIndex + 1);
end;

function TCustomExpression.TokenValue(AIndex, Next: Integer): ansistring;
var
  I, H: Integer;
begin
  Result := '';
  H := FSize - 1; //High(FTokens);
  if (AIndex >= 0) and (AIndex <= H) then
  begin
    for I := AIndex to Next - 1 do
    begin
    (*
      X1 := FTokens[I].Offset;
      X2 := MaxInt;
      if I < H then X2 := FTokens[I + 1].Offset;

      Result := Result + Copy(FSource, X1, X2 - X1) + ' ';
      *)
      Result := Result + FValues.Value[FTokens[I].Index];
    end;
    //SetLength(Result, Length(Result) - 1);
  end
  else
    Result := '#';
    //raise Exception.CreateFmt('Token index %d is out of bounds.', [Index]);
end;

function TCustomExpression.TokenID(AIndex: Integer): Integer;
begin
  if (AIndex >= 0) and (AIndex < FSize) then
  begin
    Result := FTokens[AIndex].ID
  end
  else
    raise Exception.CreateFmt('Token index %d is out of bounds.', [AIndex]);
end;

function TCustomExpression.CurTokenValue: ansistring;
begin
  Result := TokenValue(FIndex);
end;

function TCustomExpression.CurToken: PTokenInfo;
begin
  Result := nil;
  if (FIndex < FSize) and (FTokens[FIndex].ID <> 0) then
    Result := @FTokens[FIndex];
end;

function TCustomExpression.GetTokenizer: TCustomTokenizer;
begin
  Result := nil;
end;

function TCustomTokenizer.RealState(ID: Integer): Integer;
begin
  if ID < 0 then
    Result := RealState(FindState(ID)^.PrevID)
  else
    Result := ID;
end;

procedure TCustomTokenizer.Tokenize(
  const Input: ansistring;
  Expression: TCustomExpression;
  ALineOffset: Integer;
  AColOffset: Integer
);
var
  Helper: TStringHelper;
  C: AnsiChar;
  I, J: Integer;
  S0, S1, S2: Integer;
  TokenCount: Integer;
  S: array of Integer;
  Raw: ansistring;
  AbsPos: Integer;
  TokenStartPos: Integer;
  TokenLength: Integer;
  TokenLine, TokenCol: Integer;
  LineCachePos, LineCacheLine, LineCacheCol: Integer;

  function CharAtPos(APos: Integer): AnsiChar;
  begin
    if (APos >= 1) and (APos <= Length(Input)) then
      Result := Input[APos]
    else
      Result := #00;
  end;

  procedure ResolveLineCol(APos: Integer; out ALine, ACol: Integer);
  var
    K: Integer;
  begin
    if APos < 1 then
      APos := 1;
    if APos < LineCachePos then
    begin
      LineCachePos := 1;
      LineCacheLine := 1;
      LineCacheCol := 1;
    end;
    for K := LineCachePos to APos - 1 do
    begin
      if Input[K] = #10 then
      begin
        Inc(LineCacheLine);
        LineCacheCol := 1;
      end
      else
        Inc(LineCacheCol);
    end;
    LineCachePos := APos;
    ALine := LineCacheLine + ALineOffset;
    if LineCacheLine = 1 then
      ACol := LineCacheCol + AColOffset
    else
      ACol := LineCacheCol;
  end;

  procedure ResetScannerAtPos(APos: Integer);
  begin
    AbsPos := APos;
    Helper.Index := AbsPos;
    C := Helper.ReadChar;
    S0 := 0;
    Raw := '';
    I := 0;
  end;

begin
  // N: source without whitespace -> expression
  // Expression.Source := Input;

  TokenCount := Expression.Size;
  Helper := TStringHelper.Create(Input);
  try
    Raw := '';
    LineCachePos := 1;
    LineCacheLine := 1;
    LineCacheCol := 1;
    //Offset := 1;
    //Offset := Helper.Index;
    C := Helper.ReadChar;
    if C = #00 then Exit;
    AbsPos := 1;
    TokenStartPos := AbsPos;
    S0 := 0;
    I := 0;
    SetLength(S, 256);
    while True do //C <> #00 do
    begin
      if I = 0 then
        TokenStartPos := AbsPos;
      if I >= Length(S) then
        SetLength(S, Length(S) * 2);
      S1 := Advance(S0, C);
      S[I] := S1;
      if S1 = 0 then
      begin
        Assert(I > 0);
        for J := I - 1 downto -1 do
        begin
          Assert(J >= 0, Format('Failed to parse ''%s''', [Raw]));
          S2 := S[J];
          Assert(S2 <> 0);
          S2 := RealState(S2);
          //Assert(S0 > 0, Format('Failed to parse ''%s'' ( state = %d )', [Raw, S0]));
          if S2 > 0 then
          begin

            if (Cardinal(S2) and IgnoreMask) <> Cardinal(S2) then
            begin
              //Token.ID := S2; //RealState(S0); //FindState(S0)^.ID;
              //Token.Raw := Raw;
              TokenLength := J + 1;
              Raw := Copy(Raw, 1, TokenLength);
              ResolveLineCol(TokenStartPos, TokenLine, TokenCol);
              Expression.AddToken(Cardinal(S2), Raw, TokenLine, TokenCol);
            end
            else
              TokenLength := J + 1;

            Helper.Index := Helper.Index + TokenLength - I;
            AbsPos := TokenStartPos + TokenLength;
            C := CharAtPos(AbsPos);
            //Expression.Source := Expression.Source + Raw;
            //Token.Offset := Offset;
            //Expression.AddToken(Token);
            S0 := 0;
            Raw := '';
            //Offset := Length(Expression.Source) + 1;
            I := 0;
            //Offset := Helper.Index - 1;
            Break;
          end;
        end;
        if C = #00 then Break;
      end
      else
      begin
        if C = #00 then Break;
        Raw := Raw + C;
        Inc(AbsPos);
        C := Helper.ReadChar;
        Inc(I);
        S0 := S1;
      end;
    end;
    //WriteLn(Input);
    if Expression.Size <> TokenCount then
      Expression.AddToken(0, '');
    // revert last character?
  finally
    Helper.Free;
  end;
end;

procedure TCustomTokenizer.PostprocessTransitions;

  function RealStateID(State: PState): Integer;
  begin
    if State^.ID > 0 then
    begin
      Result := State^.ID
    end
    else
    begin
      Result := RealStateID(FindState(State^.PrevID));
      if Result <= 0 then
        Result := State^.ID;
    end;
  end;

  procedure Recurse(State, OldState: PState);
  var
    C: Char;
  begin
    // Q: multiple PrevID ??? ---> wrong transitions updated
    //WriteLn(Format('State.ID = %d, OldState.PrevID = %d', [State^.ID, OldState^.PrevID]));

    //OldState^.RealID := RealID;
    if OldState^.PrevID <> 0 then
    begin
      for C in [#$00..#$FF] do
        if State^.Transitions[C] = 0 then
          State^.Transitions[C] := OldState^.Transitions[C];
      Recurse(State, FindState(OldState^.PrevID));

      // state id from first state id > 0  (recurse previd)

      // merge "multi states"
      // map transitions [old state] -> [new state]
    end;
  end;

var
  I: Integer;
//  State: TState;
begin

  // evaluation order
  //for I := 0 to High(FStates) do
//  for State in FStates do
//    Recurse(@State, @State);
  for I := FStates.Count - 1 downto 0 do
    Recurse(PState(FStates[I]), PState(FStates[I]));
end;

{ TTokenizer }
(*
procedure TCustomTokenizer.RegisterToken(Value: ansistring; TokenType: Cardinal;
  Symbol: Cardinal; Flags: Cardinal);
var
  L: Integer;
begin
  L := Length(FTokenMap);
  SetLength(FTokenMap, L + 1);
  FTokenMap[L].Value := Value;
  FTokenMap[L].Data.Info.Symbol := Symbol;
  FTokenMap[L].Data.Info.Flags := Flags;
  FTokenMap[L].Data.TokenType := TokenType;
end;
*)

function TCustomTokenizer.GetNextStateID: Integer;
begin
  Dec(FNextStateID);
  Result := FNextStateID;
end;

function TCustomTokenizer.AddState: PState;
begin
  Result := AddState(GetNextStateID);
end;

function TCustomTokenizer.AddState(ID: Integer): PState;
var
  L: Integer;
  P: PState;
begin
  L := FStates.Count;
  New(P);
  FillChar(P^.Transitions[#00], 256*SizeOf(Integer), #00);
  P^.PrevID := 0;
  P^.ID := ID;
  P^.Index := L;
  FStates.Add(P);
  Result := P;
  // WriteLn('Addstate ' + inttostr(id));
  //L := FStates.Count; // Length(FStates);
  //SetLength(FStates, L + 1);
(*
  FillChar(FStates[L].Transitions[#00], 256*SizeOf(Integer), #00);
  FStates[L].PrevID := 0;
  FStates[L].ID := ID;
  FStates[L].Index := L;
  Result := @FStates[L];
  *)
end;

function TCustomTokenizer.FindState(ID: Integer): PState;
var
  I: Integer;
begin
  for I := 0 to FStates.Count - 1 do
    if ID = PState(FStates[I])^.ID then
      Exit(PState(FStates[I]));
  Result := AddState(ID);
end;

function TCustomTokenizer.AddTransition(const X: ansistring; Dst: Integer
  ): PState;
begin
  Result := AddTransition(X, 0, Dst);
  Result^.Token := X;
end;

function TCustomTokenizer.AddTransition(const X: ansistring; Src, Dst: Integer
  ): PState;
var
  I, L: Integer;
begin

  L := Length(X);
  for I := 1 to L - 1 do
  begin
    Src := AddTransition([X[I]], Src, GetNextStateID)^.ID;
  end;
  Result := AddTransition([X[L]], Src, Dst);
end;

function TCustomTokenizer.AddTransition(const X: TCharSet; Dst: Integer
  ): PState;
begin
  Result := AddTransition(X, 0, Dst);
end;

function TCustomTokenizer.AddTransition(const X: TCharSet; Src, Dst: Integer
  ): PState;
var
  C: AnsiChar;
  PSrc, PDst: PState;
begin
  // N: order important -- if state array is reallocated PSrc may be invalid
  PDst := FindState(Dst);
  PSrc := FindState(Src);
  for C in GetCharSet(X) do
  begin
    // keeping existing transitions ??? PSrc.Transitions[C]   --> merge states ??? (union + precedence)
    AddTransition(PSrc, PDst, C);
  end;
  Result := PDst;
end;

function TCustomTokenizer.AddTransition(Src, Dst: PState; C: Char): PState;
var
  P: PState;
begin
  Result := Dst;
  //Dst^.PrevID := Src^.Transitions[C];   // N: used to fix transitions in postprocess step
  if Src^.Transitions[C] <> 0 then
  begin
    // merge two transitions
    P := FindState(Src^.Transitions[C]);
    Dst^.Transitions := P^.Transitions;
    if Dst^.ID < 0 then
    begin
      Dst^.PrevID := P^.ID;
      //Dst^.ID := P^.ID;
      //P^.ID := -MaxInt;
    end;
  end;
  Src^.Transitions[C] := Dst^.ID;

  // Q: Dst^.PrevID already set ???
  // A -> 'a' -> X(1)
  // A -> 'a' -> X(2) -> 'b'    (X(2).PrevID = X(1); A['a'] = X(2))
  // A -> 'a' -> X(3) -> 'c'    (X(3).PrevID = X(2); A['a'] = X(3))
end;

function TCustomTokenizer.GetCharSet(const X: TCharSet): TCharSet;
var
  C: Char;
begin
  Result := X;
  if toCaseInsensitive in FOptions then
  begin
    for C in X * ['a'..'z', 'A'..'Z'] do
    begin
      Result := Result + [Lowercase(C), Upcase(C)];
    end;
  end;
end;

constructor TCustomTokenizer.Create;
begin
  FStates := TList.Create;
end;

destructor TCustomTokenizer.Destroy;
begin
  FStates.Free;
  inherited Destroy;
end;

function TCustomTokenizer.Advance(ID: Integer; Token: AnsiChar): Integer;
begin
  Result := FindState(ID)^.Transitions[Token];
end;

function TCustomTokenizer.Advance(ID: Integer; const Tokens: ansistring
  ): Integer;
var
  I: Integer;
begin
  for I := 1 to Length(Tokens) do
  begin
    ID := Advance(ID, Tokens[I]);
  end;
  Result := RealState(ID);
end;

(*
procedure TCustomTokenizer.RegisterTokenParser(Parser: TTokenParserProc);
var
  L: Integer;
begin
  L = Length(FTokenParsers);
  SetLength(FTokenParsers, L + 1);
  FTokenParsers[L] := Parser;
end;
*)

{ TStringHelper }

constructor TStringHelper.Create(const AInput: ansistring);
begin
  FInput := AInput;
  FIndex := 1;
end;

function TStringHelper.ReadChar(Advance: Boolean): AnsiChar;
begin
  if FIndex > Length(FInput) then
    Result := #00
  else
  begin
    Result := FInput[FIndex];
    if Advance then Inc(FIndex);
  end;
end;

function TStringHelper.Offset(AOffset: Integer): Integer;
begin
  FIndex := FIndex + AOffset;
  if FIndex < 0 then FIndex := 0;
  Result := FIndex;
end;

function TStringHelper.Search(const Pattern: ansistring): Integer;
begin
  Result := PosEx(Pattern, FInput, FIndex);
end;


end.
