program poc;

{$I mantra.inc}

uses
  compute, tokens, strutils, sysutils;

const
  // Q: Use combinations of ops here as well?
  OPS: array [0..3] of Integer = (TK_PLUS, TK_MINUS, TK_MULTIPLY, TK_DIVIDE);

function AppendOps(const Op: Integer): string;
var
  S: string;

  procedure AppendOp(OpFlag: Integer; const OpStr: string);
  begin
    if Op and OpFlag <> 0 then
      S := S + OpStr + ' ';
  end;

begin
  AppendOp(TK_PLUS, '+');
  AppendOp(TK_MINUS, '-');
  AppendOp(TK_MULTIPLY, '*');
  AppendOp(TK_DIVIDE, '/');
  Result := S;
end;

function FmtVar(const Op: Integer; const V: Double): string;
begin
  Result := AppendOps(Op) + Format('%f', [V]);
end;

procedure TestFolding;
var
  OpX, OpY, OpW: Integer;
  X: Double;
  sx, sw: string;
begin
  WriteLn('Testing folding:');
  for OpX in OPS do
    for OpY in OPS do
    begin
      X := 1.5;

      sx := FmtVar(OpX, X);

      OpW := CombineLHS(OpY, OpX);

      sw := FmtVar(OpW, X);

      WriteLn(Format('%s ( %s ) -> %s', [AppendOps(OpY), sx, sw]));
    end;
end;


procedure TestFloatOps;
var
  OpX, OpY, OpW: Integer;
  X, Y, W: Double;
  sx, sy, sw: string;
begin
  WriteLn('Testing binary combine:');
  for OpX in OPS do
    for OpY in OPS do
    begin
      X := 1.5;
      Y := 2.5;

      sx := FmtVar(OpX, X);
      sy := FmtVar(OpY, Y);

      CombineBinaryOp(OpX, OpY, OPS_PROCS_FLOAT, X, Y, W);
      OpW := OpX and OpY and (TK_PLUS or TK_MULTIPLY);

      sw := FmtVar(OpW, W);

      WriteLn(Format('%s %s -> %s', [sx, sy, sw]));
    end;
end;

begin
  TestFolding;
  TestFloatOps;

end.
