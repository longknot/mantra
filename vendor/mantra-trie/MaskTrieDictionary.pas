unit MaskTrieDictionary;

{$mode objfpc}{$H+}

interface

type
  generic TTrieDictionary<TValue> = class
  public type
    TPatternScanProc = procedure(
      const Key: ansistring;
      const Value: TValue;
      var Continue: Boolean
    ) of object;
  private type
    PValue = ^TValue;
  private
    type
      PMaskState = ^TMaskState;
      TMaskState = packed record
        SetBits: Byte;
        MaskBits: Byte;
        Flags: Byte;
        Reserved: Byte;
        Value: Pointer;
        Transitions: array[0..0] of Pointer;
      end;

      TMaskNodeManager = class
      private
        const
          STATE_INITIALIZED = $01;
          STATE_HAS_VALUE = $02;
          STATE_HEADER_SIZE = SizeOf(TMaskState) - SizeOf(Pointer);
      private
        type
          TLUT256x256 = array [Byte, Byte] of Byte;
      private
        class var
          LUTInitialized: Boolean;
          PACK_BITS: TLUT256x256;
          UNPACK_BITS: TLUT256x256;
        private
          FValueSize: SizeInt;
          FRootState: PMaskState;
          FCurrentState: PPointer;
          class procedure InitializeLookups; static;
          class function PackBits(const Mask, X: Integer): Integer; static;
          class function UnpackBits(const Mask, X: Integer): Integer; static;
          class function TransitionCount(const MaskBits: Byte): Integer; static;
          class function IsInitialized(State: PMaskState): Boolean; static;
          class function HasValue(State: PMaskState): Boolean; static;
          class function Transitions(State: PMaskState): PPointer; static;
          class procedure ReallocState(var State: PMaskState; ATransitionCount: Integer); static;
          procedure FreeSubtree(State: PMaskState);
          function CountSubtreeValues(State: PMaskState): SizeInt;
          function NewState: PMaskState;
          function GetValue: Pointer;
          procedure SetValue(Value: Pointer);
          function RemoveValue: Boolean;
        public
          constructor Create(AValueSize: SizeInt);
          destructor Destroy; override;
          procedure Reset;
          procedure Clear;
          procedure AddTransition(Symbol: Byte);
          function Advance(Symbol: Byte): Boolean;
          function CountCurrentSubtreeValues: SizeInt;
          function GetRootStatePtr: Pointer;
          function GetCurrentStatePtr: Pointer;
          property Value: Pointer read GetValue write SetValue;
        end;
  private
    FNodeManager: TMaskNodeManager;
    FCount: SizeInt;
  private type
    TSegmentArray = array of ansistring;
  private
    function Traverse(const Key: ansistring; CreateMissing: Boolean): Boolean;
    class function ExtractNextSegment(
      const S: ansistring;
      var Position: SizeInt;
      out Segment: ansistring
    ): Boolean; static;
    class function GlobMatch(const Pattern, Text: ansistring): Boolean; static;
    class procedure SplitSegments(const S: ansistring; out Segments: TSegmentArray); static;
    class function MatchSegments(
      const PatternSegments, TextSegments: TSegmentArray;
      PatternIndex, TextIndex: SizeInt
    ): Boolean; static;
    class function WildcardMatch(const Pattern, Text: ansistring): Boolean; static;
    function BuildLiteralPrefix(const Pattern: ansistring): ansistring;
    function MatchPatternKey(const Key, Pattern: ansistring): Boolean;
    function TryLocatePrefixState(const Prefix: ansistring; out State: PMaskState): Boolean;
    function ScanPatternFromState(
      State: PMaskState;
      const Pattern: ansistring;
      var KeyBuffer: ansistring;
      const Callback: TPatternScanProc;
      var ContinueScan: Boolean
    ): SizeInt;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(const Key: ansistring; const Value: TValue);
    function Remove(const Key: ansistring): Boolean;
    function TryGetValue(const Key: ansistring; out Value: TValue): Boolean;
    function ContainsKey(const Key: ansistring): Boolean;
    function PrefixCount(const Prefix: ansistring): SizeInt;
    function ScanPattern(const Pattern: ansistring; const Callback: TPatternScanProc): SizeInt;
    function PatternCount(const Pattern: ansistring): SizeInt;
    property Count: SizeInt read FCount;
  end;

implementation

uses
  SysUtils;

class function TTrieDictionary.GlobMatch(
  const Pattern, Text: ansistring
): Boolean;
var
  PatternPos: SizeInt;
  TextPos: SizeInt;
  StarPatternPos: SizeInt;
  StarTextPos: SizeInt;
begin
  PatternPos := 1;
  TextPos := 1;
  StarPatternPos := 0;
  StarTextPos := 0;

  while TextPos <= Length(Text) do
  begin
    if (PatternPos <= Length(Pattern)) and
       ((Pattern[PatternPos] = Text[TextPos]) or (Pattern[PatternPos] = '?')) then
    begin
      Inc(PatternPos);
      Inc(TextPos);
      Continue;
    end;

    if (PatternPos <= Length(Pattern)) and (Pattern[PatternPos] = '*') then
    begin
      StarPatternPos := PatternPos;
      StarTextPos := TextPos;
      Inc(PatternPos);
      Continue;
    end;

    if StarPatternPos <> 0 then
    begin
      PatternPos := StarPatternPos + 1;
      Inc(StarTextPos);
      TextPos := StarTextPos;
      Continue;
    end;

    Exit(False);
  end;

  while (PatternPos <= Length(Pattern)) and (Pattern[PatternPos] = '*') do
    Inc(PatternPos);

  Result := PatternPos > Length(Pattern);
end;

class procedure TTrieDictionary.SplitSegments(
  const S: ansistring;
  out Segments: TSegmentArray
);
var
  Position: SizeInt;
  Segment: ansistring;
  SegmentCount: SizeInt;
begin
  SetLength(Segments, 0);
  if S = '' then
    Exit;

  Position := 1;
  SegmentCount := 0;
  while ExtractNextSegment(S, Position, Segment) do
  begin
    SetLength(Segments, SegmentCount + 1);
    Segments[SegmentCount] := Segment;
    Inc(SegmentCount);
  end;
end;

class function TTrieDictionary.MatchSegments(
  const PatternSegments, TextSegments: TSegmentArray;
  PatternIndex, TextIndex: SizeInt
): Boolean;
begin
  if PatternIndex >= Length(PatternSegments) then
    Exit(TextIndex >= Length(TextSegments));

  if PatternSegments[PatternIndex] = '**' then
  begin
    // '**' matches zero or more complete key segments.
    if MatchSegments(PatternSegments, TextSegments, PatternIndex + 1, TextIndex) then
      Exit(True);
    if TextIndex < Length(TextSegments) then
      Exit(MatchSegments(PatternSegments, TextSegments, PatternIndex, TextIndex + 1));
    Exit(False);
  end;

  if TextIndex >= Length(TextSegments) then
    Exit(False);

  if not GlobMatch(PatternSegments[PatternIndex], TextSegments[TextIndex]) then
    Exit(False);

  Result := MatchSegments(PatternSegments, TextSegments, PatternIndex + 1, TextIndex + 1);
end;

class function TTrieDictionary.WildcardMatch(
  const Pattern, Text: ansistring
): Boolean;
var
  PatternSegments: TSegmentArray;
  TextSegments: TSegmentArray;
begin
  // Legacy behavior remains unchanged unless deep wildcard is used.
  if Pos('**', Pattern) = 0 then
    Exit(GlobMatch(Pattern, Text));

  SplitSegments(Pattern, PatternSegments);
  SplitSegments(Text, TextSegments);
  Result := MatchSegments(PatternSegments, TextSegments, 0, 0);
end;

{ TTrieDictionary.TMaskNodeManager }

class function TTrieDictionary.TMaskNodeManager.PackBits(const Mask, X: Integer): Integer;
var
  I, J, S: Integer;
begin
  Result := 0;
  J := 0;
  for I := 0 to 7 do
  begin
    S := 1 shl I;
    if Mask and S <> 0 then
    begin
      Result := Result or ((1 shl J) * Ord((X and S) <> 0));
      Inc(J);
    end;
  end;
end;

class function TTrieDictionary.TMaskNodeManager.UnpackBits(const Mask, X: Integer): Integer;
var
  I, J, S: Integer;
begin
  Result := 0;
  J := 0;
  for I := 0 to 7 do
  begin
    S := 1 shl I;
    if Mask and S <> 0 then
    begin
      Result := Result or (S * Ord(X and (1 shl J) <> 0));
      Inc(J);
    end;
  end;
end;

class procedure TTrieDictionary.TMaskNodeManager.InitializeLookups;
var
  I, J: Integer;
begin
  if LUTInitialized then
    Exit;

  for I := Low(Byte) to High(Byte) do
    for J := Low(Byte) to High(Byte) do
    begin
      PACK_BITS[I, J] := PackBits(I, J);
      UNPACK_BITS[I, J] := UnpackBits(I, J);
    end;

  LUTInitialized := True;
end;

class function TTrieDictionary.TMaskNodeManager.TransitionCount(
  const MaskBits: Byte): Integer;
begin
  Result := PACK_BITS[MaskBits, $FF] + 1;
end;

class function TTrieDictionary.TMaskNodeManager.IsInitialized(
  State: PMaskState): Boolean;
begin
  Result := (State <> nil) and ((State^.Flags and STATE_INITIALIZED) <> 0);
end;

class function TTrieDictionary.TMaskNodeManager.HasValue(
  State: PMaskState): Boolean;
begin
  Result := (State <> nil) and ((State^.Flags and STATE_HAS_VALUE) <> 0);
end;

class function TTrieDictionary.TMaskNodeManager.Transitions(
  State: PMaskState): PPointer;
begin
  Result := @State^.Transitions[0];
end;

class procedure TTrieDictionary.TMaskNodeManager.ReallocState(var State: PMaskState;
  ATransitionCount: Integer);
var
  NewSize: SizeUInt;
begin
  if ATransitionCount < 0 then
    ATransitionCount := 0;
  NewSize := STATE_HEADER_SIZE + (SizeUInt(ATransitionCount) * SizeOf(Pointer));
  ReallocMem(State, NewSize);
end;

constructor TTrieDictionary.TMaskNodeManager.Create(AValueSize: SizeInt);
begin
  inherited Create;
  InitializeLookups;
  FValueSize := AValueSize;
  FRootState := NewState;
  FCurrentState := @FRootState;
end;

destructor TTrieDictionary.TMaskNodeManager.Destroy;
begin
  FreeSubtree(FRootState);
  inherited Destroy;
end;

function TTrieDictionary.TMaskNodeManager.NewState: PMaskState;
begin
  GetMem(Result, STATE_HEADER_SIZE);
  FillChar(Result^, STATE_HEADER_SIZE, 0);
end;

procedure TTrieDictionary.TMaskNodeManager.FreeSubtree(State: PMaskState);
var
  I, N: Integer;
  Child: PMaskState;
  T: PPointer;
begin
  if State = nil then
    Exit;

  if IsInitialized(State) then
  begin
    N := TransitionCount(State^.MaskBits);
    T := Transitions(State);
    for I := 0 to N - 1 do
    begin
      Child := PMaskState(T[I]);
      if Child <> nil then
        FreeSubtree(Child);
    end;
  end;

  if HasValue(State) then
    FreeMem(State^.Value);

  FreeMem(State);
end;

function TTrieDictionary.TMaskNodeManager.CountSubtreeValues(
  State: PMaskState): SizeInt;
var
  I, N: Integer;
  T: PPointer;
begin
  Result := 0;
  if State = nil then
    Exit;

  if HasValue(State) then
    Inc(Result);

  if not IsInitialized(State) then
    Exit;

  N := TransitionCount(State^.MaskBits);
  T := Transitions(State);
  for I := 0 to N - 1 do
    if T[I] <> nil then
      Inc(Result, CountSubtreeValues(PMaskState(T[I])));
end;

procedure TTrieDictionary.TMaskNodeManager.Reset;
begin
  FCurrentState := @FRootState;
end;

procedure TTrieDictionary.TMaskNodeManager.Clear;
begin
  FreeSubtree(FRootState);
  FRootState := NewState;
  FCurrentState := @FRootState;
end;

procedure TTrieDictionary.TMaskNodeManager.AddTransition(Symbol: Byte);
var
  State, Child: PMaskState;
  OldMaskBits, NewMaskBits: Byte;
  OldSetBits, FixedBits, OldSymbol: Integer;
  OldCount, NewCount: Integer;
  I, TargetIndex: Integer;
  OldTransitions: array of Pointer;
  T: PPointer;
begin
  State := PMaskState(FCurrentState^);
  Child := NewState;

  if not IsInitialized(State) then
  begin
    OldMaskBits := 0;
    OldSetBits := 0;

    State^.MaskBits := 0;
    State^.SetBits := Symbol;
    State^.Flags := State^.Flags or STATE_INITIALIZED;

    ReallocState(State, 1);
    FCurrentState^ := State;
    Transitions(State)[0] := nil;
  end
  else
  begin
    OldMaskBits := State^.MaskBits;
    OldSetBits := State^.SetBits;
    State^.MaskBits := State^.MaskBits or (State^.SetBits xor Symbol);
    State^.SetBits := State^.SetBits or Symbol;
  end;

  NewMaskBits := State^.MaskBits;
  TargetIndex := PACK_BITS[NewMaskBits, Symbol];

  if NewMaskBits <> OldMaskBits then
  begin
    OldCount := TransitionCount(OldMaskBits);
    NewCount := TransitionCount(NewMaskBits);

    SetLength(OldTransitions, OldCount);
    T := Transitions(State);
    for I := 0 to OldCount - 1 do
      OldTransitions[I] := T[I];

    ReallocState(State, NewCount);
    FCurrentState^ := State;
    T := Transitions(State);
    FillChar(T^, NewCount * SizeOf(Pointer), 0);

    FixedBits := OldSetBits and (not OldMaskBits and $FF);
    for I := 0 to OldCount - 1 do
    begin
      if OldTransitions[I] = nil then
        Continue;
      OldSymbol := UNPACK_BITS[OldMaskBits, I] or FixedBits;
      T[PACK_BITS[NewMaskBits, OldSymbol]] := OldTransitions[I];
    end;
  end;

  Transitions(State)[TargetIndex] := Child;
  FCurrentState := @Transitions(State)[TargetIndex];
end;

function TTrieDictionary.TMaskNodeManager.Advance(Symbol: Byte): Boolean;
var
  State: PMaskState;
  Index: Integer;
  Slot: PPointer;
begin
  State := PMaskState(FCurrentState^);
  if not IsInitialized(State) then
    Exit(False);

  if (Symbol or State^.MaskBits) <> State^.SetBits then
    Exit(False);

  Index := PACK_BITS[State^.MaskBits, Symbol];
  Slot := @Transitions(State)[Index];
  Result := Assigned(Slot^);
  if Result then
    FCurrentState := Slot;
end;

function TTrieDictionary.TMaskNodeManager.CountCurrentSubtreeValues: SizeInt;
begin
  Result := CountSubtreeValues(PMaskState(FCurrentState^));
end;

function TTrieDictionary.TMaskNodeManager.GetRootStatePtr: Pointer;
begin
  Result := FRootState;
end;

function TTrieDictionary.TMaskNodeManager.GetCurrentStatePtr: Pointer;
begin
  Result := FCurrentState^;
end;

function TTrieDictionary.TMaskNodeManager.GetValue: Pointer;
var
  State: PMaskState;
begin
  State := PMaskState(FCurrentState^);
  if HasValue(State) then
    Result := State^.Value
  else
    Result := nil;
end;

procedure TTrieDictionary.TMaskNodeManager.SetValue(Value: Pointer);
var
  State: PMaskState;
begin
  State := PMaskState(FCurrentState^);
  if not HasValue(State) then
  begin
    GetMem(State^.Value, FValueSize);
    State^.Flags := State^.Flags or STATE_HAS_VALUE;
  end;
  Move(Value^, State^.Value^, FValueSize);
end;

function TTrieDictionary.TMaskNodeManager.RemoveValue: Boolean;
var
  State: PMaskState;
begin
  State := PMaskState(FCurrentState^);
  Result := HasValue(State);
  if not Result then
    Exit;

  FreeMem(State^.Value);
  State^.Value := nil;
  State^.Flags := State^.Flags and (not STATE_HAS_VALUE);
end;

{ TTrieDictionary }

constructor TTrieDictionary.Create;
begin
  inherited Create;
  FNodeManager := TMaskNodeManager.Create(SizeOf(TValue));
  FCount := 0;
end;

destructor TTrieDictionary.Destroy;
begin
  FNodeManager.Free;
  inherited Destroy;
end;

procedure TTrieDictionary.Clear;
begin
  FNodeManager.Clear;
  FCount := 0;
end;

class function TTrieDictionary.ExtractNextSegment(
  const S: ansistring;
  var Position: SizeInt;
  out Segment: ansistring
): Boolean;
var
  StartPos: SizeInt;
begin
  if Position > Length(S) then
    Exit(False);

  StartPos := Position;
  while (Position <= Length(S)) and (S[Position] <> '.') do
    Inc(Position);
  Segment := Copy(S, StartPos, Position - StartPos);
  if (Position <= Length(S)) and (S[Position] = '.') then
    Inc(Position);
  Result := True;
end;

function TTrieDictionary.BuildLiteralPrefix(const Pattern: ansistring): ansistring;
var
  I: SizeInt;
begin
  Result := Pattern;
  for I := 1 to Length(Pattern) do
  begin
    if (Pattern[I] = '*') or (Pattern[I] = '?') then
    begin
      Result := Copy(Pattern, 1, I - 1);
      Break;
    end;
  end;
end;

function TTrieDictionary.MatchPatternKey(const Key, Pattern: ansistring): Boolean;
begin
  Result := TTrieDictionary.WildcardMatch(Pattern, Key);
end;

function TTrieDictionary.TryLocatePrefixState(
  const Prefix: ansistring;
  out State: PMaskState
): Boolean;
var
  I: SizeInt;
begin
  if Prefix = '' then
  begin
    State := PMaskState(FNodeManager.GetRootStatePtr);
    Exit(State <> nil);
  end;

  FNodeManager.Reset;
  for I := 1 to Length(Prefix) do
    if not FNodeManager.Advance(Byte(Prefix[I])) then
    begin
      State := nil;
      Exit(False);
    end;

  State := PMaskState(FNodeManager.GetCurrentStatePtr);
  Result := State <> nil;
end;

function TTrieDictionary.ScanPatternFromState(
  State: PMaskState;
  const Pattern: ansistring;
  var KeyBuffer: ansistring;
  const Callback: TPatternScanProc;
  var ContinueScan: Boolean
): SizeInt;
  function PopCount8(B: Byte): Integer;
  begin
    Result := 0;
    while B <> 0 do
    begin
      Inc(Result, B and 1);
      B := B shr 1;
    end;
  end;

  function TransitionCountFromMask(Mask: Byte): Integer;
  begin
    Result := 1 shl PopCount8(Mask);
  end;
var
  I, N: Integer;
  T: PPointer;
  Child: PMaskState;
  FixedBits: Integer;
  Symbol: Integer;
  PreviousLength: SizeInt;
  EmitContinue: Boolean;
  EmitValue: TValue;
begin
  Result := 0;
  if (State = nil) or (not ContinueScan) then
    Exit;

  if (State^.Flags and $02) <> 0 then
    if MatchPatternKey(KeyBuffer, Pattern) then
    begin
      Inc(Result);
      if Assigned(Callback) then
      begin
        EmitContinue := True;
        EmitValue := PValue(State^.Value)^;
        Callback(KeyBuffer, EmitValue, EmitContinue);
        if not EmitContinue then
        begin
          ContinueScan := False;
          Exit;
        end;
      end;
    end;

  if (State^.Flags and $01) = 0 then
    Exit;

  N := TransitionCountFromMask(State^.MaskBits);
  T := @State^.Transitions[0];
  FixedBits := State^.SetBits and (not State^.MaskBits and $FF);

  for I := 0 to N - 1 do
  begin
    if not ContinueScan then
      Break;
    Child := PMaskState(T[I]);
    if Child = nil then
      Continue;

    Symbol := (TMaskNodeManager.UNPACK_BITS[State^.MaskBits, I] or FixedBits) and $FF;
    PreviousLength := Length(KeyBuffer);
    SetLength(KeyBuffer, PreviousLength + 1);
    KeyBuffer[PreviousLength + 1] := AnsiChar(Byte(Symbol));
    Inc(Result, ScanPatternFromState(Child, Pattern, KeyBuffer, Callback, ContinueScan));
    SetLength(KeyBuffer, PreviousLength);
  end;
end;

function TTrieDictionary.Traverse(const Key: ansistring;
  CreateMissing: Boolean): Boolean;
var
  I, J, N: SizeInt;
begin
  FNodeManager.Reset;
  N := Length(Key);
  for I := 1 to N do
  begin
    if not FNodeManager.Advance(Byte(Key[I])) then
    begin
      if not CreateMissing then
        Exit(False);

      for J := I to N do
        FNodeManager.AddTransition(Byte(Key[J]));
      Exit(True);
    end;
  end;
  Result := True;
end;

procedure TTrieDictionary.Add(const Key: ansistring; const Value: TValue);
begin
  Traverse(Key, True);
  if FNodeManager.Value = nil then
    Inc(FCount);
  FNodeManager.Value := @Value;
end;

function TTrieDictionary.Remove(const Key: ansistring): Boolean;
begin
  if not Traverse(Key, False) then
    Exit(False);

  Result := FNodeManager.RemoveValue;
  if Result then
    Dec(FCount);

  // NOTE: This MVP intentionally does not prune empty nodes after removal.
  // Full pruning requires transition-table compaction and mask/set recomputation.
end;

function TTrieDictionary.TryGetValue(const Key: ansistring;
  out Value: TValue): Boolean;
var
  P: Pointer;
begin
  Value := Default(TValue);
  if not Traverse(Key, False) then
    Exit(False);

  P := FNodeManager.Value;
  Result := Assigned(P);
  if Result then
    Value := PValue(P)^;
end;

function TTrieDictionary.ContainsKey(const Key: ansistring): Boolean;
var
  Dummy: TValue;
begin
  Result := TryGetValue(Key, Dummy);
end;

function TTrieDictionary.PrefixCount(const Prefix: ansistring): SizeInt;
begin
  if not Traverse(Prefix, False) then
    Exit(0);
  Result := FNodeManager.CountCurrentSubtreeValues;
end;

function TTrieDictionary.ScanPattern(
  const Pattern: ansistring;
  const Callback: TPatternScanProc
): SizeInt;
var
  Prefix: ansistring;
  StartState: PMaskState;
  KeyBuffer: ansistring;
  ContinueScan: Boolean;
begin
  if Pattern = '' then
    Exit(0);

  Prefix := BuildLiteralPrefix(Pattern);
  if not TryLocatePrefixState(Prefix, StartState) then
    Exit(0);

  KeyBuffer := Prefix;
  ContinueScan := True;
  Result := ScanPatternFromState(StartState, Pattern, KeyBuffer, Callback, ContinueScan);
end;

function TTrieDictionary.PatternCount(const Pattern: ansistring): SizeInt;
begin
  Result := ScanPattern(Pattern, nil);
end;

end.
