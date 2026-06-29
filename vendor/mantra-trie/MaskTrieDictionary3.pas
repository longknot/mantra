unit MaskTrieDictionary3;

{$mode objfpc}{$H+}

interface

type
  TTrieDictionary = class
  public type
    TStateHandle = UInt32;
    TCopyMode = (
      cmReplace,
      cmMergeOverwrite,
      cmMergeKeep,
      cmFailOnConflict
    );
  public type
    TPatternScanProc = procedure(
      const Key: ansistring;
      const Value: Integer;
      var Continue: Boolean
    ) of object;
    TPathScanProc = procedure(
      const Path: ansistring;
      var Continue: Boolean
    ) of object;
  private type
    PValue = ^Integer;
    TScanItem = record
      Key: ansistring;
      Value: Integer;
    end;
    TScanItemArray = array of TScanItem;
    TScanCollector = class
    public
      Items: TScanItemArray;
      procedure HandleMatch(
        const Key: ansistring;
        const Value: Integer;
        var Continue: Boolean
      );
      procedure Clear;
    end;
  private
    type
      TStateId = UInt32;
      TStateIdArray = array of TStateId;
      PMaskState = ^TMaskState;
      TMaskState = packed record
        SetBits: Byte;
        MaskBits: Byte;
        Flags: Byte;
        Reserved: Byte;
        Value: Integer;
        TransBase: UInt32;
      end;

      TMaskNodeManager = class
      private
        const
          STATE_INITIALIZED = $01;
          STATE_HAS_VALUE = $02;
          STATE_INDEXED = $04;
          STATE_COMPRESSED = $08;
          INVALID_STATE_ID: TStateId = 0;
      private
        type
          TLUT256x256 = array [Byte, Byte] of Byte;
      private
        class var
          LUTInitialized: Boolean;
          PACK_BITS: TLUT256x256;
          UNPACK_BITS: TLUT256x256;
        private
          FStates: array of TMaskState;
          FTransitions: TStateIdArray;
          FRootState: TStateId;
          FCurrentState: TStateId;
          class procedure InitializeLookups; static;
          class function PackBits(const Mask, X: Integer): Integer; static;
          class function UnpackBits(const Mask, X: Integer): Integer; static;
          class function TransitionCount(const MaskBits: Byte): Integer; static;
          class function IsInitialized(const State: PMaskState): Boolean; static;
          class function HasValue(const State: PMaskState): Boolean; static;
          function NewState: TStateId;
          function StatePtr(const StateId: TStateId): PMaskState;
          function AllocTransitionBlock(const ATransitionCount: Integer): UInt32;
          procedure FreeTransitionBlock(const ABase: UInt32; const ATransitionCount: Integer);
          function StateTransitionCount(const State: PMaskState): Integer;
          function EnsureIndexedCapacity(const State: PMaskState; const RequiredCount: Integer): Boolean;
          function GetTransition(const State: PMaskState; const Index: Integer): TStateId;
          procedure SetTransition(const State: PMaskState; const Index: Integer; const Child: TStateId);
          procedure FreeAllValues;
          function CountSubtreeValues(const StateId: TStateId): SizeInt;
          function ClearSubtreeValues(const StateId: TStateId): SizeInt;
          function GetValue: Pointer;
          procedure SetValue(Value: Pointer);
          function RemoveValue: Boolean;
          function ValuePtrAtState(const StateId: TStateId): Pointer;
          procedure SetValueAtState(const StateId: TStateId; Value: Pointer);
          function SetCurrentStateId(const StateId: TStateId): Boolean;
        public
          constructor Create;
          destructor Destroy; override;
          procedure Reset;
          procedure Clear;
          procedure AddTransition(Symbol: Byte);
          function Advance(Symbol: Byte): Boolean;
          function CountCurrentSubtreeValues: SizeInt;
          function GetRootStateId: TStateId;
          function GetCurrentStateId: TStateId;
          function GetStateById(const StateId: TStateId): PMaskState;
          function IsIndexedState(const StateId: TStateId): Boolean;
          function MarkIndexedState(const StateId: TStateId; const InitialCapacity: Integer): Boolean;
          function TryGetIndexedChild(const StateId: TStateId; const Index: Integer; out Child: TStateId): Boolean;
          function EnsureIndexedChild(const StateId: TStateId; const Index: Integer; out Child: TStateId): Boolean;
          function DetachSymbolChild(const StateId: TStateId; const Symbol: Byte; out Child: TStateId): Boolean;
          function DetachIndexedChild(const StateId: TStateId; const Index: Integer; out Child: TStateId): Boolean;
          property Value: Pointer read GetValue write SetValue;
        end;
  private
    FNodeManager: TMaskNodeManager;
    FCount: SizeInt;
    FCompressedLabels: array of ansistring;
    FCompressedChildren: TStateIdArray;
  private type
    TSegmentArray = array of ansistring;
    TPrefixResolveKind = (
      prNone,
      prExactState,
      prCompressedPrefix
    );
    TPrefixResolveResult = record
      Kind: TPrefixResolveKind;
      State: TStateId;
      CompressedOwner: TStateId;
      CompressedChild: TStateId;
      CompressedNextChar: AnsiChar;
      CompressedRemainder: ansistring;
    end;
  private
    procedure EnsureCompressedSlot(const State: TStateId);
    function HasCompressedEdge(const State: TStateId): Boolean; overload;
    function HasCompressedEdge(
      const State: TStateId;
      out EdgeLabel: ansistring;
      out Child: TStateId
    ): Boolean; overload;
    procedure ClearCompressedEdge(const State: TStateId);
    procedure SetCompressedEdge(
      const State: TStateId;
      const EdgeLabel: ansistring;
      const Child: TStateId
    );
    function TryGetSymbolChild(
      const State: TStateId;
      const Symbol: Byte;
      out Child: TStateId
    ): Boolean;
    function EnsureSymbolChild(
      const State: TStateId;
      const Symbol: Byte;
      out Child: TStateId
    ): Boolean;
    function ExpandCompressedEdge(const State: TStateId): Boolean;
    function TraverseFromState(
      const StartState: TStateId;
      const Key: ansistring;
      CreateMissing: Boolean;
      out State: TStateId
    ): Boolean;
    procedure ClearCompressedSubtree(const State: TStateId);
    function TraverseToState(
      const Key: ansistring;
      CreateMissing: Boolean;
      out State: TStateId
    ): Boolean;
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
    class function IsBoundaryChar(const C: AnsiChar): Boolean; static;
    class function PrefixEndsAtBoundary(const Prefix: ansistring): Boolean; static;
    class function TryParseIndexedToken(
      const Path: ansistring;
      var Position: SizeInt;
      out IndexZeroBased: Integer
    ): Boolean; static;
    function ResolvePrefixForSubtree(
      const Prefix: ansistring;
      out Resolved: TPrefixResolveResult
    ): Boolean;
    function VisitSubtreeValues(
      const State: TStateId;
      const ClearValues: Boolean
    ): SizeInt;
    function CountSubtreeValuesWithCompressed(const State: TStateId): SizeInt;
    function ClearSubtreeValuesWithCompressed(const State: TStateId): SizeInt;
    function VisitDelimitedDescendants(
      const State: TStateId;
      const ClearValues: Boolean
    ): SizeInt;
    function CountDelimitedDescendants(const State: TStateId): SizeInt;
    function ClearDelimitedDescendants(const State: TStateId): SizeInt;
    function ClearValueAtState(const State: TStateId): SizeInt;
    function TryLocatePrefixState(const Prefix: ansistring; out State: TStateId): Boolean;
    function ScanPatternFromState(
      State: TStateId;
      const Pattern: ansistring;
      var KeyBuffer: ansistring;
      const Callback: TPatternScanProc;
      var ContinueScan: Boolean
    ): SizeInt;
    class function TryExtractImmediateChildPath(
      const Prefix: ansistring;
      const Key: ansistring;
      out ChildPath: ansistring
    ): Boolean; static;
    class function IsSubtreeKey(
      const Key: ansistring;
      const Prefix: ansistring
    ): Boolean; static;
    class function RewriteSubtreeKey(
      const SrcKey: ansistring;
      const SrcPrefix: ansistring;
      const DstPrefix: ansistring
    ): ansistring; static;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(const Key: ansistring; const Value: Integer);
    function Remove(const Key: ansistring): Boolean;
    function RemoveSubtree(const Path: ansistring): Boolean;
    function CopySubtree(
      const SrcPrefix: ansistring;
      const DstPrefix: ansistring;
      const Mode: TCopyMode = cmMergeOverwrite
    ): Boolean;
    function TryGetValue(const Key: ansistring; out Value: Integer): Boolean;
    function ContainsKey(const Key: ansistring): Boolean;
    function PrefixCount(const Prefix: ansistring): SizeInt;
    function ScanPattern(const Pattern: ansistring; const Callback: TPatternScanProc): SizeInt;
    function PatternCount(const Pattern: ansistring): SizeInt;
    function ScanImmediateChildren(
      const Prefix: ansistring;
      const Callback: TPathScanProc
    ): SizeInt;
    function TryLocateState(const Prefix: ansistring; out State: TStateHandle): Boolean;
    function EnsureState(const Prefix: ansistring; out State: TStateHandle): Boolean;
    function EnsureSuffixState(
      const BaseState: TStateHandle;
      const Suffix: ansistring;
      out State: TStateHandle
    ): Boolean;
    function AddAtState(const State: TStateHandle; const Value: Integer): Boolean;
    function GetRootState: TStateHandle;
    function IsIndexedState(const State: TStateHandle): Boolean;
    function MarkStateIndexed(const State: TStateHandle; const InitialCapacity: SizeInt = 0): Boolean;
    function TryGetIndexedState(
      const State: TStateHandle;
      const Index: SizeInt;
      out ChildState: TStateHandle
    ): Boolean;
    function EnsureIndexedState(
      const State: TStateHandle;
      const Index: SizeInt;
      out ChildState: TStateHandle
    ): Boolean;
    function AddIndexed(
      const State: TStateHandle;
      const Index: SizeInt;
      const Value: Integer
    ): Boolean;
    function TryGetIndexed(
      const State: TStateHandle;
      const Index: SizeInt;
      out Value: Integer
    ): Boolean;
    function ResolveIndexedPattern(
      const Pattern: ansistring;
      out ResolvedPattern: ansistring
    ): Boolean;
    property Count: SizeInt read FCount;
  end;

const
  TRIE_BOUNDARY_CHARS = ['.', '[', ':'];

implementation

uses
  SysUtils, Classes;

{ TTrieDictionary.TScanCollector }

procedure TTrieDictionary.TScanCollector.HandleMatch(
  const Key: ansistring;
  const Value: Integer;
  var Continue: Boolean
);
var
  ItemIndex: SizeInt;
begin
  Continue := True;
  ItemIndex := Length(Items);
  SetLength(Items, ItemIndex + 1);
  Items[ItemIndex].Key := Key;
  Items[ItemIndex].Value := Value;
end;

procedure TTrieDictionary.TScanCollector.Clear;
begin
  SetLength(Items, 0);
end;

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
  const State: PMaskState): Boolean;
begin
  Result := (State <> nil) and ((State^.Flags and STATE_INITIALIZED) <> 0);
end;

class function TTrieDictionary.TMaskNodeManager.HasValue(
  const State: PMaskState): Boolean;
begin
  Result := (State <> nil) and ((State^.Flags and STATE_HAS_VALUE) <> 0);
end;

constructor TTrieDictionary.TMaskNodeManager.Create;
begin
  inherited Create;
  InitializeLookups;

  SetLength(FStates, 1);
  FillChar(FStates[0], SizeOf(TMaskState), 0);

  SetLength(FTransitions, 1);
  FTransitions[0] := INVALID_STATE_ID;

  FRootState := NewState;
  FCurrentState := FRootState;
end;

destructor TTrieDictionary.TMaskNodeManager.Destroy;
begin
  FreeAllValues;
  inherited Destroy;
end;

function TTrieDictionary.TMaskNodeManager.NewState: TStateId;
begin
  Result := TStateId(Length(FStates));
  SetLength(FStates, Result + 1);
  FillChar(FStates[Result], SizeOf(TMaskState), 0);
end;

function TTrieDictionary.TMaskNodeManager.StatePtr(const StateId: TStateId): PMaskState;
begin
  if (StateId = INVALID_STATE_ID) or (StateId >= TStateId(Length(FStates))) then
    Exit(nil);
  Result := @FStates[StateId];
end;

function TTrieDictionary.TMaskNodeManager.AllocTransitionBlock(
  const ATransitionCount: Integer): UInt32;
begin
  if ATransitionCount <= 0 then
    Exit(0);

  Result := UInt32(Length(FTransitions));
  SetLength(FTransitions, Length(FTransitions) + ATransitionCount);
  FillChar(FTransitions[Result], ATransitionCount * SizeOf(TStateId), 0);
end;

procedure TTrieDictionary.TMaskNodeManager.FreeTransitionBlock(
  const ABase: UInt32;
  const ATransitionCount: Integer);
begin
  // MVP: transition blocks are append-only. Free-list compaction can be added later.
  if (ABase = 0) or (ATransitionCount <= 0) then
    Exit;
end;

function TTrieDictionary.TMaskNodeManager.StateTransitionCount(
  const State: PMaskState): Integer;
begin
  if State = nil then
    Exit(0);
  if (State^.Flags and STATE_INDEXED) <> 0 then
    Exit(State^.Reserved);
  Result := TransitionCount(State^.MaskBits);
end;

function TTrieDictionary.TMaskNodeManager.EnsureIndexedCapacity(
  const State: PMaskState;
  const RequiredCount: Integer
): Boolean;
var
  OldCount: Integer;
  NewCount: Integer;
  OldBase: UInt32;
  NewBase: UInt32;
  I: Integer;
begin
  Result := False;
  if (State = nil) or (RequiredCount <= 0) then
    Exit;
  if RequiredCount > High(Byte) then
    Exit; // MVP: indexed capacity is stored in Reserved (0..255)

  OldCount := State^.Reserved;
  if OldCount >= RequiredCount then
    Exit(True);

  NewCount := OldCount;
  if NewCount < 4 then
    NewCount := 4;
  while NewCount < RequiredCount do
    NewCount := NewCount * 2;
  if NewCount > High(Byte) then
    NewCount := High(Byte);
  if NewCount < RequiredCount then
    Exit(False);

  OldBase := State^.TransBase;
  NewBase := AllocTransitionBlock(NewCount);
  if OldBase <> 0 then
    for I := 0 to OldCount - 1 do
      FTransitions[NewBase + UInt32(I)] := FTransitions[OldBase + UInt32(I)];

  FreeTransitionBlock(OldBase, OldCount);
  State^.TransBase := NewBase;
  State^.Reserved := Byte(NewCount);
  Result := True;
end;

function TTrieDictionary.TMaskNodeManager.CountSubtreeValues(
  const StateId: TStateId): SizeInt;
var
  State: PMaskState;
  I: Integer;
  N: Integer;
  Child: TStateId;
begin
  Result := 0;
  State := StatePtr(StateId);
  if State = nil then
    Exit;

  if HasValue(State) then
    Inc(Result);

  if not IsInitialized(State) then
    Exit;

  N := StateTransitionCount(State);
  for I := 0 to N - 1 do
  begin
    Child := GetTransition(State, I);
    if Child <> INVALID_STATE_ID then
      Inc(Result, CountSubtreeValues(Child));
  end;
end;

function TTrieDictionary.TMaskNodeManager.ClearSubtreeValues(
  const StateId: TStateId): SizeInt;
var
  State: PMaskState;
  I: Integer;
  N: Integer;
  Child: TStateId;
begin
  Result := 0;
  State := StatePtr(StateId);
  if State = nil then
    Exit;

  if HasValue(State) then
  begin
    State^.Value := 0;
    State^.Flags := State^.Flags and (not STATE_HAS_VALUE);
    Inc(Result);
  end;

  if not IsInitialized(State) then
    Exit;

  N := StateTransitionCount(State);
  for I := 0 to N - 1 do
  begin
    Child := GetTransition(State, I);
    if Child <> INVALID_STATE_ID then
      Inc(Result, ClearSubtreeValues(Child));
  end;
end;

procedure TTrieDictionary.TMaskNodeManager.Reset;
begin
  FCurrentState := FRootState;
end;

procedure TTrieDictionary.TMaskNodeManager.FreeAllValues;
var
  I: SizeInt;
begin
  for I := 1 to High(FStates) do
    if HasValue(@FStates[I]) then
    begin
      FStates[I].Value := 0;
      FStates[I].Flags := FStates[I].Flags and (not STATE_HAS_VALUE);
    end;
end;

procedure TTrieDictionary.TMaskNodeManager.Clear;
begin
  FreeAllValues;

  SetLength(FStates, 1);
  FillChar(FStates[0], SizeOf(TMaskState), 0);

  SetLength(FTransitions, 1);
  FTransitions[0] := INVALID_STATE_ID;

  FRootState := NewState;
  FCurrentState := FRootState;
end;

function TTrieDictionary.TMaskNodeManager.GetTransition(
  const State: PMaskState;
  const Index: Integer
): TStateId;
begin
  if (State = nil) or (State^.TransBase = 0) then
    Exit(INVALID_STATE_ID);
  Result := FTransitions[State^.TransBase + UInt32(Index)];
end;

procedure TTrieDictionary.TMaskNodeManager.SetTransition(
  const State: PMaskState;
  const Index: Integer;
  const Child: TStateId
);
begin
  if (State = nil) or (State^.TransBase = 0) then
    Exit;
  FTransitions[State^.TransBase + UInt32(Index)] := Child;
end;

procedure TTrieDictionary.TMaskNodeManager.AddTransition(Symbol: Byte);
var
  State: PMaskState;
  Child: TStateId;
  OldMaskBits, NewMaskBits: Byte;
  OldSetBits, FixedBits, OldSymbol: Integer;
  OldCount, NewCount: Integer;
  I, TargetIndex: Integer;
  OldTransitions: TStateIdArray;
  OldBase, NewBase: UInt32;
begin
  State := StatePtr(FCurrentState);
  if State = nil then
    Exit;
  if (State^.Flags and STATE_INDEXED) <> 0 then
    Exit;

  if not IsInitialized(State) then
  begin
    OldMaskBits := 0;
    OldSetBits := 0;

    State^.MaskBits := 0;
    State^.SetBits := Symbol;
    State^.Flags := State^.Flags or STATE_INITIALIZED;

    State^.TransBase := AllocTransitionBlock(1);
    SetTransition(State, 0, INVALID_STATE_ID);
  end
  else
  begin
    OldMaskBits := State^.MaskBits;
    OldSetBits := State^.SetBits;
    // maskbits : bits are set if 0 is part of the symbol set.
    // setbits : bits are set if 1 is part of the symbol set.
    State^.MaskBits := State^.MaskBits or (State^.SetBits xor Symbol);
    State^.SetBits := State^.SetBits or Symbol;
  end;

  NewMaskBits := State^.MaskBits;
  TargetIndex := PACK_BITS[NewMaskBits, Symbol];

  if NewMaskBits <> OldMaskBits then
  begin
    OldCount := TransitionCount(OldMaskBits);
    NewCount := TransitionCount(NewMaskBits);
    OldBase := State^.TransBase;

    SetLength(OldTransitions, OldCount);
    for I := 0 to OldCount - 1 do
      OldTransitions[I] := FTransitions[OldBase + UInt32(I)];

    NewBase := AllocTransitionBlock(NewCount);

    FixedBits := OldSetBits and (not OldMaskBits and $FF);
    for I := 0 to OldCount - 1 do
    begin
      if OldTransitions[I] = INVALID_STATE_ID then
        Continue;
      OldSymbol := UNPACK_BITS[OldMaskBits, I] or FixedBits;
      FTransitions[NewBase + UInt32(PACK_BITS[NewMaskBits, OldSymbol])] := OldTransitions[I];
    end;

    FreeTransitionBlock(OldBase, OldCount);
    State^.TransBase := NewBase;
  end;

  Child := NewState;
  State := StatePtr(FCurrentState);
  if State = nil then
    Exit;
  SetTransition(State, TargetIndex, Child);
  FCurrentState := Child;
end;

function TTrieDictionary.TMaskNodeManager.Advance(Symbol: Byte): Boolean;
var
  State: PMaskState;
  Index: Integer;
  Child: TStateId;
begin
  State := StatePtr(FCurrentState);
  if not IsInitialized(State) then
    Exit(False);
  if (State^.Flags and STATE_INDEXED) <> 0 then
    Exit(False);

  if (Symbol or State^.MaskBits) <> State^.SetBits then
    Exit(False);

  Index := PACK_BITS[State^.MaskBits, Symbol];
  Child := GetTransition(State, Index);
  Result := Child <> INVALID_STATE_ID;
  if Result then
    FCurrentState := Child;
end;

function TTrieDictionary.TMaskNodeManager.CountCurrentSubtreeValues: SizeInt;
begin
  Result := CountSubtreeValues(FCurrentState);
end;

function TTrieDictionary.TMaskNodeManager.GetRootStateId: TStateId;
begin
  Result := FRootState;
end;

function TTrieDictionary.TMaskNodeManager.GetCurrentStateId: TStateId;
begin
  Result := FCurrentState;
end;

function TTrieDictionary.TMaskNodeManager.GetStateById(
  const StateId: TStateId): PMaskState;
begin
  Result := StatePtr(StateId);
end;

function TTrieDictionary.TMaskNodeManager.IsIndexedState(
  const StateId: TStateId): Boolean;
var
  State: PMaskState;
begin
  State := StatePtr(StateId);
  Result := (State <> nil) and ((State^.Flags and STATE_INDEXED) <> 0);
end;

function TTrieDictionary.TMaskNodeManager.MarkIndexedState(
  const StateId: TStateId;
  const InitialCapacity: Integer
): Boolean;
var
  State: PMaskState;
begin
  Result := False;
  State := StatePtr(StateId);
  if State = nil then
    Exit;

  if (State^.Flags and STATE_INDEXED) = 0 then
  begin
    // keep the MVP strict: do not convert an already initialized symbol state.
    if ((State^.Flags and STATE_INITIALIZED) <> 0) or
       ((State^.Flags and STATE_COMPRESSED) <> 0) then
      Exit;
    State^.Flags := State^.Flags or STATE_INDEXED or STATE_INITIALIZED;
    State^.SetBits := 0;
    State^.MaskBits := 0;
    State^.Reserved := 0;
    State^.TransBase := 0;
  end;

  if InitialCapacity > 0 then
    Result := EnsureIndexedCapacity(State, InitialCapacity)
  else
    Result := True;
end;

function TTrieDictionary.TMaskNodeManager.TryGetIndexedChild(
  const StateId: TStateId;
  const Index: Integer;
  out Child: TStateId
): Boolean;
var
  State: PMaskState;
begin
  Child := INVALID_STATE_ID;
  if Index < 0 then
    Exit(False);

  State := StatePtr(StateId);
  if (State = nil) or ((State^.Flags and STATE_INDEXED) = 0) then
    Exit(False);
  if Index >= State^.Reserved then
    Exit(False);

  Child := GetTransition(State, Index);
  Result := Child <> INVALID_STATE_ID;
end;

function TTrieDictionary.TMaskNodeManager.EnsureIndexedChild(
  const StateId: TStateId;
  const Index: Integer;
  out Child: TStateId
): Boolean;
var
  State: PMaskState;
begin
  Child := INVALID_STATE_ID;
  if Index < 0 then
    Exit(False);

  State := StatePtr(StateId);
  if (State = nil) or ((State^.Flags and STATE_INDEXED) = 0) then
    Exit(False);
  if not EnsureIndexedCapacity(State, Index + 1) then
    Exit(False);

  Child := GetTransition(State, Index);
  if Child = INVALID_STATE_ID then
  begin
    Child := NewState;
    State := StatePtr(StateId);
    if State = nil then
      Exit(False);
    SetTransition(State, Index, Child);
  end;
  Result := True;
end;

function TTrieDictionary.TMaskNodeManager.DetachSymbolChild(
  const StateId: TStateId;
  const Symbol: Byte;
  out Child: TStateId
): Boolean;
var
  State: PMaskState;
  TransitionIndex: Integer;
begin
  Child := INVALID_STATE_ID;
  State := StatePtr(StateId);
  if (State = nil) or (not IsInitialized(State)) then
    Exit(False);
  if (State^.Flags and STATE_INDEXED) <> 0 then
    Exit(False);
  if (Symbol or State^.MaskBits) <> State^.SetBits then
    Exit(False);

  TransitionIndex := PACK_BITS[State^.MaskBits, Symbol];
  Child := GetTransition(State, TransitionIndex);
  if Child = INVALID_STATE_ID then
    Exit(False);

  SetTransition(State, TransitionIndex, INVALID_STATE_ID);
  Result := True;
end;

function TTrieDictionary.TMaskNodeManager.DetachIndexedChild(
  const StateId: TStateId;
  const Index: Integer;
  out Child: TStateId
): Boolean;
var
  State: PMaskState;
begin
  Child := INVALID_STATE_ID;
  if Index < 0 then
    Exit(False);

  State := StatePtr(StateId);
  if (State = nil) or ((State^.Flags and STATE_INDEXED) = 0) then
    Exit(False);
  if Index >= State^.Reserved then
    Exit(False);

  Child := GetTransition(State, Index);
  if Child = INVALID_STATE_ID then
    Exit(False);

  SetTransition(State, Index, INVALID_STATE_ID);
  Result := True;
end;

function TTrieDictionary.TMaskNodeManager.ValuePtrAtState(
  const StateId: TStateId): Pointer;
var
  State: PMaskState;
begin
  State := StatePtr(StateId);
  if HasValue(State) then
    Result := @State^.Value
  else
    Result := nil;
end;

procedure TTrieDictionary.TMaskNodeManager.SetValueAtState(
  const StateId: TStateId;
  Value: Pointer
);
var
  State: PMaskState;
begin
  State := StatePtr(StateId);
  if State = nil then
    Exit;
  State^.Value := PValue(Value)^;
  State^.Flags := State^.Flags or STATE_HAS_VALUE;
end;

function TTrieDictionary.TMaskNodeManager.SetCurrentStateId(
  const StateId: TStateId
): Boolean;
begin
  Result := StatePtr(StateId) <> nil;
  if Result then
    FCurrentState := StateId;
end;

function TTrieDictionary.TMaskNodeManager.GetValue: Pointer;
var
  State: PMaskState;
begin
  State := StatePtr(FCurrentState);
  if HasValue(State) then
    Result := @State^.Value
  else
    Result := nil;
end;

procedure TTrieDictionary.TMaskNodeManager.SetValue(Value: Pointer);
var
  State: PMaskState;
begin
  State := StatePtr(FCurrentState);
  if State = nil then
    Exit;

  State^.Value := PValue(Value)^;
  State^.Flags := State^.Flags or STATE_HAS_VALUE;
end;

function TTrieDictionary.TMaskNodeManager.RemoveValue: Boolean;
var
  State: PMaskState;
begin
  State := StatePtr(FCurrentState);
  Result := HasValue(State);
  if not Result then
    Exit;

  State^.Value := 0;
  State^.Flags := State^.Flags and (not STATE_HAS_VALUE);
end;

{ TTrieDictionary }

constructor TTrieDictionary.Create;
begin
  inherited Create;
  FNodeManager := TMaskNodeManager.Create;
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
  SetLength(FCompressedLabels, 0);
  SetLength(FCompressedChildren, 0);
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

class function TTrieDictionary.IsBoundaryChar(const C: AnsiChar): Boolean;
begin
  Result := C in TRIE_BOUNDARY_CHARS;
end;

class function TTrieDictionary.PrefixEndsAtBoundary(const Prefix: ansistring): Boolean;
begin
  Result := (Prefix <> '') and IsBoundaryChar(Prefix[Length(Prefix)]);
end;

class function TTrieDictionary.TryParseIndexedToken(
  const Path: ansistring;
  var Position: SizeInt;
  out IndexZeroBased: Integer
): Boolean;
var
  StartPos: SizeInt;
  EndPos: SizeInt;
  Value64: Int64;
begin
  Result := False;
  IndexZeroBased := -1;

  if (Position > Length(Path)) or (Path[Position] <> '[') then
    Exit;

  StartPos := Position + 1;
  EndPos := StartPos;
  while (EndPos <= Length(Path)) and (Path[EndPos] in ['0'..'9']) do
    Inc(EndPos);

  if (EndPos = StartPos) or (EndPos > Length(Path)) or (Path[EndPos] <> ']') then
    Exit;

  Value64 := StrToInt64Def(Copy(Path, StartPos, EndPos - StartPos), -1);
  if (Value64 <= 0) or (Value64 > Int64(High(Integer)) + 1) then
    Exit;

  IndexZeroBased := Integer(Value64 - 1);
  Position := EndPos + 1;
  Result := True;
end;

function TTrieDictionary.ResolvePrefixForSubtree(
  const Prefix: ansistring;
  out Resolved: TPrefixResolveResult
): Boolean;
var
  CurrentState: TStateId;
  NextState: TStateId;
  Current: PMaskState;
  EdgeLabel: ansistring;
  EdgeChild: TStateId;
  MatchLen: SizeInt;
  RemainingLen: SizeInt;
  Position: SizeInt;
  IndexZeroBased: Integer;
begin
  Resolved.Kind := prNone;
  Resolved.State := TMaskNodeManager.INVALID_STATE_ID;
  Resolved.CompressedOwner := TMaskNodeManager.INVALID_STATE_ID;
  Resolved.CompressedChild := TMaskNodeManager.INVALID_STATE_ID;
  Resolved.CompressedNextChar := #0;
  Resolved.CompressedRemainder := '';

  CurrentState := FNodeManager.GetRootStateId;
  if CurrentState = TMaskNodeManager.INVALID_STATE_ID then
    Exit(False);

  if Prefix = '' then
  begin
    Resolved.Kind := prExactState;
    Resolved.State := CurrentState;
    Exit(True);
  end;

  Position := 1;
  while Position <= Length(Prefix) do
  begin
    Current := FNodeManager.GetStateById(CurrentState);
    if Current = nil then
      Exit(False);

    if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
    begin
      if not TryParseIndexedToken(Prefix, Position, IndexZeroBased) then
        Exit(False);
      if not FNodeManager.TryGetIndexedChild(CurrentState, IndexZeroBased, NextState) then
        Exit(False);
      CurrentState := NextState;
      Continue;
    end;

    if HasCompressedEdge(CurrentState, EdgeLabel, EdgeChild) then
    begin
      MatchLen := 0;
      while (MatchLen < Length(EdgeLabel)) and
            (Position + MatchLen <= Length(Prefix)) and
            (EdgeLabel[MatchLen + 1] = Prefix[Position + MatchLen]) do
        Inc(MatchLen);

      if MatchLen = 0 then
        Exit(False);

      RemainingLen := Length(Prefix) - Position + 1;
      if MatchLen = RemainingLen then
      begin
        if MatchLen = Length(EdgeLabel) then
        begin
          CurrentState := EdgeChild;
          Position := Length(Prefix) + 1;
          Continue;
        end;

        Resolved.Kind := prCompressedPrefix;
        Resolved.CompressedOwner := CurrentState;
        Resolved.CompressedChild := EdgeChild;
        Resolved.CompressedNextChar := EdgeLabel[MatchLen + 1];
        Resolved.CompressedRemainder := Copy(EdgeLabel, MatchLen + 1, MaxInt);
        Exit(True);
      end;

      if MatchLen < Length(EdgeLabel) then
        Exit(False);

      Inc(Position, Length(EdgeLabel));
      CurrentState := EdgeChild;
      Continue;
    end;

    if not TryGetSymbolChild(CurrentState, Byte(Prefix[Position]), NextState) then
      Exit(False);

    CurrentState := NextState;
    Inc(Position);
  end;

  Resolved.Kind := prExactState;
  Resolved.State := CurrentState;
  Result := True;
end;

function TTrieDictionary.VisitSubtreeValues(
  const State: TStateId;
  const ClearValues: Boolean
): SizeInt;
var
  Current: PMaskState;
  Child: TStateId;
  EdgeLabel: ansistring;
  EdgeChild: TStateId;
  I: Integer;
  N: Integer;
begin
  Result := 0;
  if State = TMaskNodeManager.INVALID_STATE_ID then
    Exit;

  Current := FNodeManager.GetStateById(State);
  if Current = nil then
    Exit;

  if (Current^.Flags and TMaskNodeManager.STATE_HAS_VALUE) <> 0 then
  begin
    if ClearValues then
    begin
      Current^.Value := 0;
      Current^.Flags := Current^.Flags and (not TMaskNodeManager.STATE_HAS_VALUE);
    end;
    Inc(Result);
  end;

  if HasCompressedEdge(State, EdgeLabel, EdgeChild) then
  begin
    if ClearValues then
      ClearCompressedEdge(State);
    Inc(Result, VisitSubtreeValues(EdgeChild, ClearValues));
  end;

  if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    Exit;

  if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
    N := Current^.Reserved
  else
    N := TMaskNodeManager.TransitionCount(Current^.MaskBits);

  for I := 0 to N - 1 do
  begin
    Child := FNodeManager.GetTransition(Current, I);
    if Child <> TMaskNodeManager.INVALID_STATE_ID then
      Inc(Result, VisitSubtreeValues(Child, ClearValues));
  end;
end;

function TTrieDictionary.CountSubtreeValuesWithCompressed(
  const State: TStateId
): SizeInt;
begin
  Result := VisitSubtreeValues(State, False);
end;

function TTrieDictionary.ClearSubtreeValuesWithCompressed(
  const State: TStateId
): SizeInt;
begin
  Result := VisitSubtreeValues(State, True);
end;

function TTrieDictionary.VisitDelimitedDescendants(
  const State: TStateId;
  const ClearValues: Boolean
): SizeInt;
var
  Current: PMaskState;
  Child: TStateId;
  EdgeLabel: ansistring;
  EdgeChild: TStateId;
  I: Integer;
  N: Integer;
  FixedBits: Integer;
  Symbol: Byte;
begin
  Result := 0;
  if State = TMaskNodeManager.INVALID_STATE_ID then
    Exit;

  Current := FNodeManager.GetStateById(State);
  if Current = nil then
    Exit;

  if HasCompressedEdge(State, EdgeLabel, EdgeChild) and
     (Length(EdgeLabel) > 0) and
     IsBoundaryChar(EdgeLabel[1]) then
  begin
    if ClearValues then
      ClearCompressedEdge(State);
    Inc(Result, VisitSubtreeValues(EdgeChild, ClearValues));
  end;

  if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    Exit;

  if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
  begin
    for I := 0 to Current^.Reserved - 1 do
    begin
      Child := FNodeManager.GetTransition(Current, I);
      if Child <> TMaskNodeManager.INVALID_STATE_ID then
      begin
        if ClearValues then
          FNodeManager.SetTransition(Current, I, TMaskNodeManager.INVALID_STATE_ID);
        Inc(Result, VisitSubtreeValues(Child, ClearValues));
      end;
    end;
    Exit;
  end;

  N := TMaskNodeManager.TransitionCount(Current^.MaskBits);
  FixedBits := Current^.SetBits and (not Current^.MaskBits and $FF);
  for I := 0 to N - 1 do
  begin
    Child := FNodeManager.GetTransition(Current, I);
    if Child = TMaskNodeManager.INVALID_STATE_ID then
      Continue;

    Symbol := Byte((TMaskNodeManager.UNPACK_BITS[Current^.MaskBits, I] or FixedBits) and $FF);
    if IsBoundaryChar(AnsiChar(Symbol)) then
    begin
      if ClearValues then
        FNodeManager.SetTransition(Current, I, TMaskNodeManager.INVALID_STATE_ID);
      Inc(Result, VisitSubtreeValues(Child, ClearValues));
    end;
  end;
end;

function TTrieDictionary.CountDelimitedDescendants(const State: TStateId): SizeInt;
begin
  Result := VisitDelimitedDescendants(State, False);
end;

function TTrieDictionary.ClearDelimitedDescendants(const State: TStateId): SizeInt;
begin
  Result := VisitDelimitedDescendants(State, True);
end;

function TTrieDictionary.ClearValueAtState(const State: TStateId): SizeInt;
var
  Current: PMaskState;
begin
  Result := 0;
  Current := FNodeManager.GetStateById(State);
  if (Current = nil) or ((Current^.Flags and TMaskNodeManager.STATE_HAS_VALUE) = 0) then
    Exit;

  Current^.Value := 0;
  Current^.Flags := Current^.Flags and (not TMaskNodeManager.STATE_HAS_VALUE);
  Result := 1;
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

class function TTrieDictionary.TryExtractImmediateChildPath(
  const Prefix: ansistring;
  const Key: ansistring;
  out ChildPath: ansistring
): Boolean;
var
  Suffix: ansistring;
  Segment: ansistring;
  PrefixLen: SizeInt;
  DelimiterPos: SizeInt;
  NextChar: ansichar;
begin
  Result := False;
  ChildPath := '';

  if Key = '' then
    Exit(False);

  if Prefix = '' then
  begin
    Suffix := Key;
  end
  else
  begin
    if Key = Prefix then
      Exit(False);
    PrefixLen := Length(Prefix);
    if (Length(Key) <= PrefixLen) or
       (Copy(Key, 1, PrefixLen) <> Prefix) then
      Exit(False);
    if not (Key[PrefixLen + 1] in ['.', '[']) then
      Exit(False);
    Suffix := Copy(Key, PrefixLen + 1, MaxInt);
    if Suffix = '' then
      Exit(False);
    NextChar := Suffix[1];
    if NextChar = '.' then
      System.Delete(Suffix, 1, 1)
    else if NextChar <> '[' then
      Exit(False);
  end;

  if Suffix = '' then
    Exit(False);
  if Suffix[1] = '[' then
  begin
    DelimiterPos := Pos(']', Suffix);
    if DelimiterPos <= 0 then
      Exit(False);
    Segment := Copy(Suffix, 1, DelimiterPos);
  end
  else
  begin
    DelimiterPos := 1;
    while (DelimiterPos <= Length(Suffix)) and
          (Suffix[DelimiterPos] <> '.') and
          (Suffix[DelimiterPos] <> '[') do
      Inc(DelimiterPos);
    Segment := Copy(Suffix, 1, DelimiterPos - 1);
  end;

  if Segment = '' then
    Exit(False);
  if Prefix = '' then
    ChildPath := Segment
  else if Segment[1] = '[' then
    ChildPath := Prefix + Segment
  else
    ChildPath := Prefix + '.' + Segment;
  Result := True;
end;

class function TTrieDictionary.IsSubtreeKey(
  const Key: ansistring;
  const Prefix: ansistring
): Boolean;
var
  PrefixLen: SizeInt;
begin
  if Prefix = '' then
    Exit(True);
  if Key = Prefix then
    Exit(True);

  PrefixLen := Length(Prefix);
  Result := (Length(Key) > PrefixLen) and
            (Copy(Key, 1, PrefixLen) = Prefix) and
            ((Key[PrefixLen + 1] = '.') or (Key[PrefixLen + 1] = '['));
end;

class function TTrieDictionary.RewriteSubtreeKey(
  const SrcKey: ansistring;
  const SrcPrefix: ansistring;
  const DstPrefix: ansistring
): ansistring;
var
  Suffix: ansistring;
begin
  Suffix := Copy(SrcKey, Length(SrcPrefix) + 1, MaxInt);
  Result := DstPrefix + Suffix;
end;

procedure TTrieDictionary.EnsureCompressedSlot(const State: TStateId);
var
  Needed: SizeInt;
begin
  Needed := SizeInt(State) + 1;
  if Needed <= Length(FCompressedLabels) then
    Exit;
  SetLength(FCompressedLabels, Needed);
  SetLength(FCompressedChildren, Needed);
end;

function TTrieDictionary.HasCompressedEdge(const State: TStateId): Boolean;
var
  DummyLabel: ansistring;
  DummyChild: TStateId;
begin
  Result := HasCompressedEdge(State, DummyLabel, DummyChild);
end;

function TTrieDictionary.HasCompressedEdge(
  const State: TStateId;
  out EdgeLabel: ansistring;
  out Child: TStateId
): Boolean;
var
  Current: PMaskState;
begin
  EdgeLabel := '';
  Child := TMaskNodeManager.INVALID_STATE_ID;
  Current := FNodeManager.GetStateById(State);
  if Current = nil then
    Exit(False);
  if (Current^.Flags and TMaskNodeManager.STATE_COMPRESSED) = 0 then
    Exit(False);
  if SizeInt(State) >= Length(FCompressedLabels) then
    Exit(False);

  EdgeLabel := FCompressedLabels[State];
  Child := FCompressedChildren[State];
  Result := (EdgeLabel <> '') and (Child <> TMaskNodeManager.INVALID_STATE_ID);
end;

procedure TTrieDictionary.ClearCompressedEdge(const State: TStateId);
var
  Current: PMaskState;
begin
  if SizeInt(State) < Length(FCompressedLabels) then
  begin
    FCompressedLabels[State] := '';
    FCompressedChildren[State] := TMaskNodeManager.INVALID_STATE_ID;
  end;

  Current := FNodeManager.GetStateById(State);
  if Current <> nil then
    Current^.Flags := Current^.Flags and (not TMaskNodeManager.STATE_COMPRESSED);
end;

procedure TTrieDictionary.SetCompressedEdge(
  const State: TStateId;
  const EdgeLabel: ansistring;
  const Child: TStateId
);
var
  Current: PMaskState;
begin
  if (EdgeLabel = '') or (Child = TMaskNodeManager.INVALID_STATE_ID) then
  begin
    ClearCompressedEdge(State);
    Exit;
  end;

  Current := FNodeManager.GetStateById(State);
  if Current = nil then
    Exit;
  if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
    Exit;
  if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) <> 0 then
    Exit;

  EnsureCompressedSlot(State);
  FCompressedLabels[State] := EdgeLabel;
  FCompressedChildren[State] := Child;
  Current^.Flags := Current^.Flags or TMaskNodeManager.STATE_COMPRESSED;
end;

function TTrieDictionary.TryGetSymbolChild(
  const State: TStateId;
  const Symbol: Byte;
  out Child: TStateId
): Boolean;
var
  Current: PMaskState;
  Index: Integer;
begin
  Child := TMaskNodeManager.INVALID_STATE_ID;
  Current := FNodeManager.GetStateById(State);
  if (Current = nil) or ((Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0) then
    Exit(False);
  if (Current^.Flags and TMaskNodeManager.STATE_COMPRESSED) <> 0 then
    Exit(False);
  if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    Exit(False);
  if (Symbol or Current^.MaskBits) <> Current^.SetBits then
    Exit(False);

  Index := TMaskNodeManager.PACK_BITS[Current^.MaskBits, Symbol];
  Child := FNodeManager.GetTransition(Current, Index);
  Result := Child <> TMaskNodeManager.INVALID_STATE_ID;
end;

function TTrieDictionary.EnsureSymbolChild(
  const State: TStateId;
  const Symbol: Byte;
  out Child: TStateId
): Boolean;
var
  SavedState: TStateId;
  PrevState: TStateId;
begin
  if TryGetSymbolChild(State, Symbol, Child) then
    Exit(True);

  Child := TMaskNodeManager.INVALID_STATE_ID;
  SavedState := FNodeManager.GetCurrentStateId;
  if not FNodeManager.SetCurrentStateId(State) then
    Exit(False);
  try
    PrevState := FNodeManager.GetCurrentStateId;
    FNodeManager.AddTransition(Symbol);
    Child := FNodeManager.GetCurrentStateId;
    Result := (Child <> TMaskNodeManager.INVALID_STATE_ID) and (Child <> PrevState);
  finally
    if not FNodeManager.SetCurrentStateId(SavedState) then
      FNodeManager.Reset;
  end;
end;

function TTrieDictionary.ExpandCompressedEdge(const State: TStateId): Boolean;
var
  EdgeLabel: ansistring;
  Child: TStateId;
  CurrentState: TStateId;
  NextState: TStateId;
  LastState: PMaskState;
  LastSymbol: Byte;
  TransitionIndex: Integer;
  I: SizeInt;
begin
  if not HasCompressedEdge(State, EdgeLabel, Child) then
    Exit(True);

  if EdgeLabel = '' then
  begin
    ClearCompressedEdge(State);
    Exit(True);
  end;

  CurrentState := State;
  for I := 1 to Length(EdgeLabel) - 1 do
  begin
    if not EnsureSymbolChild(CurrentState, Byte(EdgeLabel[I]), NextState) then
      Exit(False);
    CurrentState := NextState;
  end;

  LastSymbol := Byte(EdgeLabel[Length(EdgeLabel)]);
  if not EnsureSymbolChild(CurrentState, LastSymbol, NextState) then
    Exit(False);

  LastState := FNodeManager.GetStateById(CurrentState);
  if LastState = nil then
    Exit(False);
  if (LastState^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    Exit(False);
  if (LastSymbol or LastState^.MaskBits) <> LastState^.SetBits then
    Exit(False);

  TransitionIndex := TMaskNodeManager.PACK_BITS[LastState^.MaskBits, LastSymbol];
  FNodeManager.SetTransition(LastState, TransitionIndex, Child);
  ClearCompressedEdge(State);
  Result := True;
end;

function TTrieDictionary.TraverseFromState(
  const StartState: TStateId;
  const Key: ansistring;
  CreateMissing: Boolean;
  out State: TStateId
): Boolean;
var
  CurrentState: TStateId;
  NextState: TStateId;
  LeafState: TStateId;
  EdgeLabel: ansistring;
  Child: TStateId;
  Current: PMaskState;
  MatchLen: SizeInt;
  Position: SizeInt;
  IndexZeroBased: Integer;
begin
  State := TMaskNodeManager.INVALID_STATE_ID;
  CurrentState := StartState;
  if CurrentState = TMaskNodeManager.INVALID_STATE_ID then
    Exit(False);

  Position := 1;
  while Position <= Length(Key) do
  begin
    Current := FNodeManager.GetStateById(CurrentState);
    if Current = nil then
      Exit(False);
    if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
    begin
      if not TryParseIndexedToken(Key, Position, IndexZeroBased) then
        Exit(False);

      if CreateMissing then
      begin
        if not FNodeManager.EnsureIndexedChild(CurrentState, IndexZeroBased, NextState) then
          Exit(False);
      end
      else
      begin
        if not FNodeManager.TryGetIndexedChild(CurrentState, IndexZeroBased, NextState) then
          Exit(False);
      end;

      CurrentState := NextState;
      Continue;
    end;

    if HasCompressedEdge(CurrentState, EdgeLabel, Child) then
    begin
      MatchLen := 0;
      while (MatchLen < Length(EdgeLabel)) and
            (Position + MatchLen <= Length(Key)) and
            (EdgeLabel[MatchLen + 1] = Key[Position + MatchLen]) do
        Inc(MatchLen);

      if MatchLen = Length(EdgeLabel) then
      begin
        Inc(Position, MatchLen);
        CurrentState := Child;
        Continue;
      end;

      if not CreateMissing then
        Exit(False);
      if not ExpandCompressedEdge(CurrentState) then
        Exit(False);
      Continue;
    end;

    if TryGetSymbolChild(CurrentState, Byte(Key[Position]), NextState) then
    begin
      CurrentState := NextState;
      Inc(Position);
      Continue;
    end;

    if not CreateMissing then
      Exit(False);

    if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    begin
      LeafState := FNodeManager.NewState;
      SetCompressedEdge(CurrentState, Copy(Key, Position, MaxInt), LeafState);
      CurrentState := LeafState;
      Position := Length(Key) + 1;
      Continue;
    end;

    if not EnsureSymbolChild(CurrentState, Byte(Key[Position]), NextState) then
      Exit(False);
    CurrentState := NextState;
    Inc(Position);

    if Position <= Length(Key) then
    begin
      Current := FNodeManager.GetStateById(CurrentState);
      if (Current <> nil) and
         ((Current^.Flags and TMaskNodeManager.STATE_INDEXED) = 0) and
         ((Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0) and
         (not HasCompressedEdge(CurrentState)) then
      begin
        LeafState := FNodeManager.NewState;
        SetCompressedEdge(CurrentState, Copy(Key, Position, MaxInt), LeafState);
        CurrentState := LeafState;
        Position := Length(Key) + 1;
      end;
    end;
  end;

  State := CurrentState;
  Result := State <> TMaskNodeManager.INVALID_STATE_ID;
end;

procedure TTrieDictionary.ClearCompressedSubtree(const State: TStateId);
var
  Current: PMaskState;
  Child: TStateId;
  EdgeLabel: ansistring;
  I: Integer;
  N: Integer;
begin
  if State = TMaskNodeManager.INVALID_STATE_ID then
    Exit;

  if HasCompressedEdge(State, EdgeLabel, Child) then
  begin
    ClearCompressedEdge(State);
    ClearCompressedSubtree(Child);
  end;

  Current := FNodeManager.GetStateById(State);
  if Current = nil then
    Exit;
  if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    Exit;

  if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
    N := Current^.Reserved
  else
    N := TMaskNodeManager.TransitionCount(Current^.MaskBits);

  for I := 0 to N - 1 do
  begin
    Child := FNodeManager.GetTransition(Current, I);
    if Child <> TMaskNodeManager.INVALID_STATE_ID then
      ClearCompressedSubtree(Child);
  end;
end;

function TTrieDictionary.TryLocatePrefixState(
  const Prefix: ansistring;
  out State: TStateId
): Boolean;
begin
  if Prefix = '' then
  begin
    State := FNodeManager.GetRootStateId;
    Exit(State <> TMaskNodeManager.INVALID_STATE_ID);
  end;

  Result := TraverseFromState(FNodeManager.GetRootStateId, Prefix, False, State);
end;

function TTrieDictionary.ScanPatternFromState(
  State: TStateId;
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
  Current: PMaskState;
  I, N: Integer;
  Child: TStateId;
  CompressedChild: TStateId;
  CompressedLabel: ansistring;
  FixedBits: Integer;
  Symbol: Integer;
  PreviousLength: SizeInt;
  EmitContinue: Boolean;
  EmitValue: Integer;
begin
  Result := 0;
  Current := FNodeManager.GetStateById(State);
  if (Current = nil) or (not ContinueScan) then
    Exit;

  if (Current^.Flags and TMaskNodeManager.STATE_HAS_VALUE) <> 0 then
    if MatchPatternKey(KeyBuffer, Pattern) then
    begin
      Inc(Result);
      if Assigned(Callback) then
      begin
        EmitContinue := True;
        EmitValue := Current^.Value;
        Callback(KeyBuffer, EmitValue, EmitContinue);
        if not EmitContinue then
        begin
          ContinueScan := False;
          Exit;
        end;
      end;
    end;

  if HasCompressedEdge(State, CompressedLabel, CompressedChild) then
  begin
    PreviousLength := Length(KeyBuffer);
    KeyBuffer := KeyBuffer + CompressedLabel;
    Inc(Result, ScanPatternFromState(CompressedChild, Pattern, KeyBuffer, Callback, ContinueScan));
    SetLength(KeyBuffer, PreviousLength);
    if not ContinueScan then
      Exit;
  end;

  if (Current^.Flags and TMaskNodeManager.STATE_INITIALIZED) = 0 then
    Exit;

  if (Current^.Flags and TMaskNodeManager.STATE_INDEXED) <> 0 then
  begin
    for I := 0 to Current^.Reserved - 1 do
    begin
      if not ContinueScan then
        Break;
      Child := FNodeManager.GetTransition(Current, I);
      if Child = TMaskNodeManager.INVALID_STATE_ID then
        Continue;

      PreviousLength := Length(KeyBuffer);
      KeyBuffer := KeyBuffer + '[' + IntToStr(I + 1) + ']';
      Inc(Result, ScanPatternFromState(Child, Pattern, KeyBuffer, Callback, ContinueScan));
      SetLength(KeyBuffer, PreviousLength);
    end;
    Exit;
  end;

  N := TransitionCountFromMask(Current^.MaskBits);
  FixedBits := Current^.SetBits and (not Current^.MaskBits and $FF);

  for I := 0 to N - 1 do
  begin
    if not ContinueScan then
      Break;
    Child := FNodeManager.GetTransition(Current, I);
    if Child = TMaskNodeManager.INVALID_STATE_ID then
      Continue;

    Symbol := (TMaskNodeManager.UNPACK_BITS[Current^.MaskBits, I] or FixedBits) and $FF;
    PreviousLength := Length(KeyBuffer);
    SetLength(KeyBuffer, PreviousLength + 1);
    KeyBuffer[PreviousLength + 1] := AnsiChar(Byte(Symbol));
    Inc(Result, ScanPatternFromState(Child, Pattern, KeyBuffer, Callback, ContinueScan));
    SetLength(KeyBuffer, PreviousLength);
  end;
end;

function TTrieDictionary.TraverseToState(
  const Key: ansistring;
  CreateMissing: Boolean;
  out State: TStateId
): Boolean;
begin
  Result := TraverseFromState(FNodeManager.GetRootStateId, Key, CreateMissing, State);
  if Result then
    Result := FNodeManager.SetCurrentStateId(State);
end;

function TTrieDictionary.Traverse(const Key: ansistring;
  CreateMissing: Boolean): Boolean;
var
  DummyState: TStateId;
begin
  Result := TraverseToState(Key, CreateMissing, DummyState);
end;

procedure TTrieDictionary.Add(const Key: ansistring; const Value: Integer);
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

function TTrieDictionary.RemoveSubtree(const Path: ansistring): Boolean;
var
  Resolved: TPrefixResolveResult;
  RemovedCount: SizeInt;
begin
  Result := False;

  if Path = '' then
  begin
    Result := (FCount > 0) or (Length(FCompressedLabels) > 0);
    Clear;
    Exit;
  end;

  if not ResolvePrefixForSubtree(Path, Resolved) then
    Exit(False);

  RemovedCount := 0;
  case Resolved.Kind of
    prExactState:
      begin
        if PrefixEndsAtBoundary(Path) then
          Inc(RemovedCount, ClearSubtreeValuesWithCompressed(Resolved.State))
        else
        begin
          Inc(RemovedCount, ClearValueAtState(Resolved.State));
          Inc(RemovedCount, ClearDelimitedDescendants(Resolved.State));
        end;
      end;
    prCompressedPrefix:
      begin
        if IsBoundaryChar(Resolved.CompressedNextChar) or
           PrefixEndsAtBoundary(Path) then
        begin
          ClearCompressedEdge(Resolved.CompressedOwner);
          Inc(RemovedCount, ClearSubtreeValuesWithCompressed(Resolved.CompressedChild));
        end;
      end;
  end;

  if RemovedCount > 0 then
  begin
    Dec(FCount, RemovedCount);
    Result := True;
  end;
end;

function TTrieDictionary.CopySubtree(
  const SrcPrefix: ansistring;
  const DstPrefix: ansistring;
  const Mode: TCopyMode
): Boolean;
var
  Collector: TScanCollector;
  I: SizeInt;
  DstKey: ansistring;
  AddedAny: Boolean;
  ExistingValue: Integer;
  SourceItems: TScanItemArray;
  ItemCount: SizeInt;
begin
  Result := False;
  if (SrcPrefix = '') or (DstPrefix = '') then
    Exit(False);
  if SrcPrefix = DstPrefix then
    Exit(True);

  Collector := TScanCollector.Create;
  try
    Collector.Clear;
    ScanPattern('**', @Collector.HandleMatch);

    SetLength(SourceItems, 0);
    ItemCount := 0;
    for I := 0 to High(Collector.Items) do
    begin
      if not IsSubtreeKey(Collector.Items[I].Key, SrcPrefix) then
        Continue;

      SetLength(SourceItems, ItemCount + 1);
      SourceItems[ItemCount] := Collector.Items[I];
      Inc(ItemCount);
    end;

    if ItemCount = 0 then
      Exit(False);

    if Mode = cmFailOnConflict then
      for I := 0 to High(SourceItems) do
      begin
        DstKey := RewriteSubtreeKey(SourceItems[I].Key, SrcPrefix, DstPrefix);
        if (DstKey <> '') and TryGetValue(DstKey, ExistingValue) then
          Exit(False);
      end;

    AddedAny := False;
    if Mode = cmReplace then
      RemoveSubtree(DstPrefix);

    for I := 0 to High(SourceItems) do
    begin
      DstKey := RewriteSubtreeKey(SourceItems[I].Key, SrcPrefix, DstPrefix);
      if DstKey = '' then
        Continue;

      case Mode of
        cmMergeKeep:
          if TryGetValue(DstKey, ExistingValue) then
            Continue;
        cmFailOnConflict:
          if TryGetValue(DstKey, ExistingValue) then
            Exit(False);
      end;

      Add(DstKey, SourceItems[I].Value);
      AddedAny := True;
    end;

    Result := AddedAny;
  finally
    Collector.Free;
  end;
end;

function TTrieDictionary.TryGetValue(const Key: ansistring;
  out Value: Integer): Boolean;
var
  P: Pointer;
begin
  Value := Default(Integer);
  if not Traverse(Key, False) then
    Exit(False);

  P := FNodeManager.Value;
  Result := Assigned(P);
  if Result then
    Value := PValue(P)^;
end;

function TTrieDictionary.ContainsKey(const Key: ansistring): Boolean;
var
  Dummy: Integer;
begin
  Result := TryGetValue(Key, Dummy);
end;

function TTrieDictionary.PrefixCount(const Prefix: ansistring): SizeInt;
var
  Resolved: TPrefixResolveResult;
begin
  if Prefix = '' then
    Exit(FCount);

  Result := 0;
  if not ResolvePrefixForSubtree(Prefix, Resolved) then
    Exit(0);

  case Resolved.Kind of
    prExactState:
      begin
        if PrefixEndsAtBoundary(Prefix) then
          Inc(Result, CountSubtreeValuesWithCompressed(Resolved.State))
        else
        begin
          if FNodeManager.ValuePtrAtState(Resolved.State) <> nil then
            Inc(Result);
          Inc(Result, CountDelimitedDescendants(Resolved.State));
        end;
      end;
    prCompressedPrefix:
      begin
        if IsBoundaryChar(Resolved.CompressedNextChar) or
           PrefixEndsAtBoundary(Prefix) then
          Result := CountSubtreeValuesWithCompressed(Resolved.CompressedChild);
      end;
  end;
end;

function TTrieDictionary.ScanPattern(
  const Pattern: ansistring;
  const Callback: TPatternScanProc
): SizeInt;
var
  Prefix: ansistring;
  StartState: TStateId;
  KeyBuffer: ansistring;
  ContinueScan: Boolean;
begin
  if Pattern = '' then
    Exit(0);

  if (Pos('[', Pattern) > 0) or (Pos(']', Pattern) > 0) then
    Prefix := ''
  else
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

function TTrieDictionary.ScanImmediateChildren(
  const Prefix: ansistring;
  const Callback: TPathScanProc
): SizeInt;
var
  Resolved: TPrefixResolveResult;
  StartState: TStateId;
  KeyBuffer: ansistring;
  ContinueScan: Boolean;
  Collector: TScanCollector;
  Children: TStringList;
  I: SizeInt;
  ChildPath: ansistring;
  EmitContinue: Boolean;
begin
  Result := 0;

  if not ResolvePrefixForSubtree(Prefix, Resolved) then
    Exit(0);

  case Resolved.Kind of
    prExactState:
      begin
        StartState := Resolved.State;
        KeyBuffer := Prefix;
      end;
    prCompressedPrefix:
      begin
        StartState := Resolved.CompressedChild;
        if StartState = TMaskNodeManager.INVALID_STATE_ID then
          Exit(0);
        KeyBuffer := Prefix + Resolved.CompressedRemainder;
      end;
  else
    Exit(0);
  end;

  Collector := TScanCollector.Create;
  Children := TStringList.Create;
  try
    Collector.Clear;
    ContinueScan := True;
    ScanPatternFromState(StartState, '**', KeyBuffer, @Collector.HandleMatch, ContinueScan);

    Children.Sorted := True;
    Children.Duplicates := dupIgnore;
    for I := 0 to High(Collector.Items) do
      if TryExtractImmediateChildPath(Prefix, Collector.Items[I].Key, ChildPath) then
        Children.Add(ChildPath);

    Result := Children.Count;
    if not Assigned(Callback) then
      Exit(Result);

    for I := 0 to Children.Count - 1 do
    begin
      EmitContinue := True;
      Callback(Children[I], EmitContinue);
      if not EmitContinue then
        Break;
    end;
  finally
    Children.Free;
    Collector.Free;
  end;
end;

function TTrieDictionary.TryLocateState(
  const Prefix: ansistring;
  out State: TStateHandle
): Boolean;
var
  InternalState: TStateId;
begin
  Result := TryLocatePrefixState(Prefix, InternalState);
  if Result then
    State := InternalState
  else
    State := 0;
end;

function TTrieDictionary.EnsureState(
  const Prefix: ansistring;
  out State: TStateHandle
): Boolean;
var
  InternalState: TStateId;
begin
  Result := TraverseToState(Prefix, True, InternalState);
  if Result then
    State := InternalState
  else
    State := 0;
end;

function TTrieDictionary.EnsureSuffixState(
  const BaseState: TStateHandle;
  const Suffix: ansistring;
  out State: TStateHandle
): Boolean;
begin
  Result := TraverseFromState(BaseState, Suffix, True, State);
end;

function TTrieDictionary.AddAtState(
  const State: TStateHandle;
  const Value: Integer
): Boolean;
begin
  Result := FNodeManager.GetStateById(State) <> nil;
  if not Result then
    Exit(False);
  if FNodeManager.ValuePtrAtState(State) = nil then
    Inc(FCount);
  FNodeManager.SetValueAtState(State, @Value);
end;

function TTrieDictionary.GetRootState: TStateHandle;
begin
  Result := FNodeManager.GetRootStateId;
end;

function TTrieDictionary.IsIndexedState(const State: TStateHandle): Boolean;
begin
  Result := FNodeManager.IsIndexedState(State);
end;

function TTrieDictionary.MarkStateIndexed(
  const State: TStateHandle;
  const InitialCapacity: SizeInt
): Boolean;
begin
  Result := FNodeManager.MarkIndexedState(State, InitialCapacity);
end;

function TTrieDictionary.TryGetIndexedState(
  const State: TStateHandle;
  const Index: SizeInt;
  out ChildState: TStateHandle
): Boolean;
begin
  ChildState := 0;
  if Index > High(Integer) then
    Exit(False);
  Result := FNodeManager.TryGetIndexedChild(State, Integer(Index), ChildState);
end;

function TTrieDictionary.EnsureIndexedState(
  const State: TStateHandle;
  const Index: SizeInt;
  out ChildState: TStateHandle
): Boolean;
begin
  ChildState := 0;
  if Index > High(Integer) then
    Exit(False);
  Result := FNodeManager.EnsureIndexedChild(State, Integer(Index), ChildState);
end;

function TTrieDictionary.AddIndexed(
  const State: TStateHandle;
  const Index: SizeInt;
  const Value: Integer
): Boolean;
var
  ChildState: TStateHandle;
begin
  Result := EnsureIndexedState(State, Index, ChildState);
  if not Result then
    Exit;

  if FNodeManager.ValuePtrAtState(ChildState) = nil then
    Inc(FCount);
  FNodeManager.SetValueAtState(ChildState, @Value);
end;

function TTrieDictionary.TryGetIndexed(
  const State: TStateHandle;
  const Index: SizeInt;
  out Value: Integer
): Boolean;
var
  ChildState: TStateHandle;
  P: Pointer;
begin
  Value := Default(Integer);
  if not TryGetIndexedState(State, Index, ChildState) then
    Exit(False);

  P := FNodeManager.ValuePtrAtState(ChildState);
  Result := Assigned(P);
  if Result then
    Value := PValue(P)^;
end;

function TTrieDictionary.ResolveIndexedPattern(
  const Pattern: ansistring;
  out ResolvedPattern: ansistring
): Boolean;
  function ContainsWildcard(const S: ansistring): Boolean;
  begin
    Result := (Pos('*', S) > 0) or (Pos('?', S) > 0);
  end;

  function ParseIndexedSegment(
    const Segment: ansistring;
    out BasePattern: ansistring;
    out Index1Based: SizeInt
  ): Boolean;
  var
    LeftBracketPos: SizeInt;
    RightBracketPos: SizeInt;
    IndexText: ansistring;
    J: SizeInt;
  begin
    Result := False;
    BasePattern := '';
    Index1Based := 0;
    if Segment = '' then
      Exit;

    RightBracketPos := Length(Segment);
    if Segment[RightBracketPos] <> ']' then
      Exit;

    LeftBracketPos := RightBracketPos - 1;
    while (LeftBracketPos >= 1) and (Segment[LeftBracketPos] <> '[') do
      Dec(LeftBracketPos);
    if LeftBracketPos < 1 then
      Exit;

    IndexText := Copy(Segment, LeftBracketPos + 1, RightBracketPos - LeftBracketPos - 1);
    if IndexText = '' then
      Exit;
    for J := 1 to Length(IndexText) do
      if not (IndexText[J] in ['0'..'9']) then
        Exit;

    Index1Based := StrToIntDef(IndexText, 0);
    if Index1Based <= 0 then
      Exit;

    BasePattern := Copy(Segment, 1, LeftBracketPos - 1);
    Result := True;
  end;

  function TryResolveIndexedStateSegment(
    const Prefix, BasePattern: ansistring;
    const Index1Based: SizeInt;
    out ResolvedSegment: ansistring;
    out UsedIndexedState: Boolean
  ): Boolean;
  var
    ParentPrefix: ansistring;
    ParentState: TStateId;
    ChildState: TStateId;
  begin
    Result := True;
    UsedIndexedState := False;
    ResolvedSegment := '';
    if (Index1Based <= 0) or ContainsWildcard(BasePattern) then
      Exit;

    if BasePattern = '' then
      ParentPrefix := Prefix
    else if Prefix = '' then
      ParentPrefix := BasePattern
    else
      ParentPrefix := Prefix + '.' + BasePattern;

    if not TryLocatePrefixState(ParentPrefix, ParentState) then
      Exit;
    if not FNodeManager.IsIndexedState(ParentState) then
      Exit;

    // User-facing [n] syntax is 1-based; indexed-state slots are 0-based.
    if not FNodeManager.TryGetIndexedChild(ParentState, Integer(Index1Based - 1), ChildState) then
      Exit(False);

    if BasePattern = '' then
      ResolvedSegment := '[' + IntToStr(Index1Based) + ']'
    else
      ResolvedSegment := BasePattern + '[' + IntToStr(Index1Based) + ']';
    UsedIndexedState := True;
  end;

  procedure CollectImmediateSegments(const Prefix: ansistring; Candidates: TStringList);
  var
    Collector: TScanCollector;
    I: SizeInt;
    Key: ansistring;
    Suffix: ansistring;
    Segment: ansistring;
    DelimiterPos: SizeInt;

    procedure AddCandidate(const Segment: ansistring);
    begin
      if Segment <> '' then
        Candidates.Add(Segment);
    end;
  begin
    Collector := TScanCollector.Create;
    try
      Collector.Clear;
      ScanPattern('**', @Collector.HandleMatch);
      for I := 0 to High(Collector.Items) do
      begin
        Key := Collector.Items[I].Key;
        if Key = '' then
          Continue;

        if Prefix = '' then
          Suffix := Key
        else
        begin
          if not IsSubtreeKey(Key, Prefix) or (Key = Prefix) then
            Continue;

          Suffix := Copy(Key, Length(Prefix) + 1, MaxInt);
          if Suffix = '' then
            Continue;
          if Suffix[1] = '.' then
            Delete(Suffix, 1, 1)
          else if Suffix[1] <> '[' then
            Continue;
        end;

        if Suffix = '' then
          Continue;
        if Suffix[1] = '[' then
        begin
          DelimiterPos := Pos(']', Suffix);
          if DelimiterPos <= 0 then
            Continue;
          Segment := Copy(Suffix, 1, DelimiterPos);
        end
        else
        begin
          DelimiterPos := 1;
          while (DelimiterPos <= Length(Suffix)) and
                (Suffix[DelimiterPos] <> '.') and
                (Suffix[DelimiterPos] <> '[') do
            Inc(DelimiterPos);
          Segment := Copy(Suffix, 1, DelimiterPos - 1);
        end;
        AddCandidate(Segment);
      end;
    finally
      Collector.Free;
    end;
  end;

  function TrySelectIndexedSegment(
    const Prefix, SegmentPattern: ansistring;
    const Index1Based: SizeInt;
    out SelectedSegment: ansistring
  ): Boolean;
  var
    Candidates: TStringList;
    CandidatePattern: ansistring;
    Candidate: ansistring;
    I: SizeInt;
    MatchCount: SizeInt;
  begin
    Result := False;
    SelectedSegment := '';
    if Index1Based <= 0 then
      Exit(False);

    Candidates := TStringList.Create;
    try
      Candidates.Sorted := True;
      Candidates.Duplicates := dupIgnore;
      CollectImmediateSegments(Prefix, Candidates);

      if SegmentPattern = '' then
        CandidatePattern := '*'
      else if ContainsWildcard(SegmentPattern) then
        CandidatePattern := SegmentPattern
      else
        CandidatePattern := SegmentPattern + '*';

      MatchCount := 0;
      for I := 0 to Candidates.Count - 1 do
      begin
        Candidate := ansistring(Candidates[I]);
        if not GlobMatch(CandidatePattern, Candidate) then
          Continue;

        Inc(MatchCount);
        if MatchCount = Index1Based then
        begin
          SelectedSegment := Candidate;
          Exit(True);
        end;
      end;
    finally
      Candidates.Free;
    end;
  end;
var
  Segments: TSegmentArray;
  ResolvedSegments: TSegmentArray;
  I: SizeInt;
  CurrentPrefix: ansistring;
  PrefixDeterministic: Boolean;
  BasePattern: ansistring;
  SegmentIndex: SizeInt;
  UsedIndexedState: Boolean;
begin
  ResolvedPattern := Pattern;
  if (Pattern = '') or (Pos('[', Pattern) = 0) then
    Exit(True);

  SplitSegments(Pattern, Segments);
  SetLength(ResolvedSegments, Length(Segments));

  CurrentPrefix := '';
  PrefixDeterministic := True;
  for I := 0 to High(Segments) do
  begin
    if Pos('[', Segments[I]) > 0 then
    begin
      if not ParseIndexedSegment(Segments[I], BasePattern, SegmentIndex) then
        Exit(False);

      if PrefixDeterministic then
      begin
        if not TryResolveIndexedStateSegment(
          CurrentPrefix,
          BasePattern,
          SegmentIndex,
          ResolvedSegments[I],
          UsedIndexedState
        ) then
          Exit(False);
        if UsedIndexedState then
        begin
          // After an indexed-state edge we cannot use string-prefix shortcuts.
          PrefixDeterministic := False;
          Continue;
        end;
      end;

      if not PrefixDeterministic then
        Exit(False);
      if not TrySelectIndexedSegment(CurrentPrefix, BasePattern, SegmentIndex, ResolvedSegments[I]) then
        Exit(False);
    end
    else
      ResolvedSegments[I] := Segments[I];

    if PrefixDeterministic then
    begin
      if ContainsWildcard(ResolvedSegments[I]) then
        PrefixDeterministic := False
      else if CurrentPrefix = '' then
        CurrentPrefix := ResolvedSegments[I]
      else
        CurrentPrefix := CurrentPrefix + '.' + ResolvedSegments[I];
    end;
  end;

  ResolvedPattern := '';
  for I := 0 to High(ResolvedSegments) do
  begin
    if I > 0 then
      ResolvedPattern := ResolvedPattern + '.';
    ResolvedPattern := ResolvedPattern + ResolvedSegments[I];
  end;
  Result := True;
end;

end.
