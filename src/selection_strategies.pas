unit selection_strategies;

{$I mantra.inc}

interface

uses
  SysUtils;

type
  TSelectionStrategyKind = (
    sskFirst,
    sskRandom,
    sskShrink,
    sskFirstRule,
    sskRandomRule
  );

  TSelectionIndexArray = array of Integer;

function DefaultSelectionStrategy: TSelectionStrategyKind;
function SelectionStrategyName(Strategy: TSelectionStrategyKind): ansistring;
function TryParseSelectionStrategy(
  const RawValue: ansistring;
  out Strategy: TSelectionStrategyKind
): Boolean;
procedure BuildRuleSelectionOrder(
  const RuleNodes: TSelectionIndexArray;
  Strategy: TSelectionStrategyKind;
  out OrderedRuleNodes: TSelectionIndexArray
);

implementation

uses
  string_utils;

var
  RandomSeedInitialized: Boolean = False;

function DefaultSelectionStrategy: TSelectionStrategyKind;
begin
  Result := sskFirst;
end;

function SelectionStrategyName(Strategy: TSelectionStrategyKind): ansistring;
begin
  case Strategy of
    sskFirst: Result := 'first';
    sskRandom: Result := 'random';
    sskShrink: Result := 'shrink';
    sskFirstRule: Result := 'first-rule';
    sskRandomRule: Result := 'random-rule';
  else
    Result := 'first';
  end;
end;

function NormalizeStrategyValue(const RawValue: ansistring): ansistring;
var
  Unquoted: ansistring;
begin
  Result := Trim(RawValue);
  if UnquoteStringLiteral(Result, Unquoted) then
    Result := Unquoted;
  Result := LowerCase(Trim(Result));
end;

function TryParseSelectionStrategy(
  const RawValue: ansistring;
  out Strategy: TSelectionStrategyKind
): Boolean;
var
  Value: ansistring;
begin
  Value := NormalizeStrategyValue(RawValue);
  if (Value = '') or
     (Value = 'first') or
     (Value = 'default') or
     (Value = 'sequential') then
  begin
    Strategy := sskFirst;
    Exit(True);
  end;

  if (Value = 'random') or
     (Value = 'rand') then
  begin
    Strategy := sskRandom;
    Exit(True);
  end;

  if (Value = 'shrink') or
     (Value = 'reduce') or
     (Value = 'simplify') or
     (Value = 'minnodes') then
  begin
    Strategy := sskShrink;
    Exit(True);
  end;

  if (Value = 'first-rule') or
     (Value = 'firstrule') or
     (Value = 'rule-first') or
     (Value = 'rulefirst') then
  begin
    Strategy := sskFirstRule;
    Exit(True);
  end;

  if (Value = 'random-rule') or
     (Value = 'randomrule') or
     (Value = 'rule-random') or
     (Value = 'rulerandom') then
  begin
    Strategy := sskRandomRule;
    Exit(True);
  end;

  Strategy := DefaultSelectionStrategy;
  Result := False;
end;

procedure EnsureRandomSeed;
begin
  if RandomSeedInitialized then
    Exit;
  Randomize;
  RandomSeedInitialized := True;
end;

procedure BuildRuleSelectionOrder(
  const RuleNodes: TSelectionIndexArray;
  Strategy: TSelectionStrategyKind;
  out OrderedRuleNodes: TSelectionIndexArray
);
var
  I: Integer;
  J: Integer;
  Tmp: Integer;
begin
  OrderedRuleNodes := Copy(RuleNodes);
  if Length(OrderedRuleNodes) <= 1 then
    Exit;

  case Strategy of
    sskRandom:
      begin
        EnsureRandomSeed;
        for I := High(OrderedRuleNodes) downto 1 do
        begin
          J := Random(I + 1);
          if I = J then
            Continue;
          Tmp := OrderedRuleNodes[I];
          OrderedRuleNodes[I] := OrderedRuleNodes[J];
          OrderedRuleNodes[J] := Tmp;
        end;
      end;
    sskFirst, sskShrink, sskFirstRule, sskRandomRule:
      ; // keep declared order
  end;
end;

end.
