unit repl_input;

{$I mantra.inc}

interface

function ReadInteractiveLine(const Prompt: ansistring; out Line: ansistring): Boolean;

implementation

uses
  SysUtils, BaseUnix, Termio;

type
  THistory = array of ansistring;

var
  History: THistory;

function StdinHandle: cint;
begin
  Result := TextRec(Input).Handle;
end;

function StdinIsTTY: Boolean;
begin
  Result := IsATTY(StdinHandle) <> 0;
end;

procedure AddHistory(const Line: ansistring);
var
  N: Integer;
begin
  if Trim(Line) = '' then
    Exit;
  N := Length(History);
  if (N > 0) and (History[N - 1] = Line) then
    Exit;
  SetLength(History, N + 1);
  History[N] := Line;
end;

procedure RedrawLine(const Prompt, Line: ansistring; CursorPos: Integer);
var
  MoveBack: Integer;
begin
  Write(#13, Prompt, Line, #27'[K');
  MoveBack := Length(Line) - CursorPos;
  if MoveBack > 0 then
    Write(#27'[', MoveBack, 'D');
  Flush(Output);
end;

function ReadByte(out C: AnsiChar): Boolean;
var
  B: Byte;
  Count: TSsize;
begin
  C := #0;
  Count := fpRead(StdinHandle, B, 1);
  Result := Count = 1;
  if Result then
    C := AnsiChar(B);
end;

procedure MoveCursorHome(
  const Prompt: ansistring;
  const Line: ansistring;
  var CursorPos: Integer
);
begin
  CursorPos := 0;
  RedrawLine(Prompt, Line, CursorPos);
end;

procedure MoveCursorEnd(
  const Prompt: ansistring;
  const Line: ansistring;
  var CursorPos: Integer
);
begin
  CursorPos := Length(Line);
  RedrawLine(Prompt, Line, CursorPos);
end;

procedure DeleteAtCursor(
  const Prompt: ansistring;
  var Line: ansistring;
  CursorPos: Integer
);
begin
  if CursorPos < Length(Line) then
  begin
    Delete(Line, CursorPos + 1, 1);
    RedrawLine(Prompt, Line, CursorPos);
  end;
end;

procedure ApplyRawMode(out OldTerm: Termios; out Applied: Boolean);
var
  NewTerm: Termios;
begin
  Applied := False;
  if TCGetAttr(StdinHandle, OldTerm) <> 0 then
    Exit;
  NewTerm := OldTerm;
  NewTerm.c_lflag := NewTerm.c_lflag and not (ICANON or ECHO);
  NewTerm.c_cc[VMIN] := 1;
  NewTerm.c_cc[VTIME] := 0;
  if TCSetAttr(StdinHandle, TCSANOW, NewTerm) = 0 then
    Applied := True;
end;

procedure RestoreTerminal(const OldTerm: Termios; Applied: Boolean);
begin
  if Applied then
    TCSetAttr(StdinHandle, TCSANOW, OldTerm);
end;

procedure MoveHistory(
  Direction: Integer;
  var HistoryIndex: Integer;
  var DraftLine: ansistring;
  var Line: ansistring;
  var CursorPos: Integer
);
var
  N: Integer;
begin
  N := Length(History);
  if N = 0 then
    Exit;
  if HistoryIndex = N then
    DraftLine := Line;

  Inc(HistoryIndex, Direction);
  if HistoryIndex < 0 then
    HistoryIndex := 0;
  if HistoryIndex > N then
    HistoryIndex := N;

  if HistoryIndex = N then
    Line := DraftLine
  else
    Line := History[HistoryIndex];
  CursorPos := Length(Line);
end;

function ReadTTYLine(const Prompt: ansistring; out Line: ansistring): Boolean;
var
  OldTerm: Termios;
  RawApplied: Boolean;
  C: AnsiChar;
  Esc1: AnsiChar;
  Esc2: AnsiChar;
  HistoryIndex: Integer;
  DraftLine: ansistring;
  CursorPos: Integer;
begin
  Result := False;
  Line := '';
  DraftLine := '';
  CursorPos := 0;
  HistoryIndex := Length(History);

  Write(Prompt);
  Flush(Output);
  ApplyRawMode(OldTerm, RawApplied);
  try
    while ReadByte(C) do
    begin
      case C of
        #3:
          begin
            WriteLn('^C');
            Line := '';
            Exit(True);
          end;
        #4:
          begin
            if Line = '' then
              Exit(False);
          end;
        #8, #127:
          begin
            if CursorPos > 0 then
            begin
              Delete(Line, CursorPos, 1);
              Dec(CursorPos);
              RedrawLine(Prompt, Line, CursorPos);
            end;
          end;
        #10, #13:
          begin
            WriteLn;
            AddHistory(Line);
            Exit(True);
          end;
        #27:
          begin
            if not ReadByte(Esc1) then
              Continue;
            if not ReadByte(Esc2) then
              Continue;
            if Esc1 = '[' then
            begin
              case Esc2 of
                'A':
                  begin
                    MoveHistory(-1, HistoryIndex, DraftLine, Line, CursorPos);
                    RedrawLine(Prompt, Line, CursorPos);
                  end;
                'B':
                  begin
                    MoveHistory(1, HistoryIndex, DraftLine, Line, CursorPos);
                    RedrawLine(Prompt, Line, CursorPos);
                  end;
                'C':
                  begin
                    if CursorPos < Length(Line) then
                    begin
                      Inc(CursorPos);
                      Write(#27'[C');
                      Flush(Output);
                    end;
                  end;
                'D':
                  begin
                    if CursorPos > 0 then
                    begin
                      Dec(CursorPos);
                      Write(#27'[D');
                      Flush(Output);
                    end;
                  end;

                // Home: ESC [ H
                'H':
                  MoveCursorHome(Prompt, Line, CursorPos);

                // End: ESC [ F
                'F':
                  MoveCursorEnd(Prompt, Line, CursorPos);

                // Delete: ESC [ 3 ~
                '3':
                  begin
                    if ReadByte(Esc2) and (Esc2 = '~') then
                      DeleteAtCursor(Prompt, Line, CursorPos);
                  end;
              end;
            end;
          end;
      else
        if C >= ' ' then
        begin
          Insert(C, Line, CursorPos + 1);
          Inc(CursorPos);
          RedrawLine(Prompt, Line, CursorPos);
          HistoryIndex := Length(History);
        end;
      end;
    end;
  finally
    RestoreTerminal(OldTerm, RawApplied);
  end;
end;

function ReadPlainLine(const Prompt: ansistring; out Line: ansistring): Boolean;
begin
  Result := False;
  Line := '';
  Write(Prompt);
  Flush(Output);
  if EOF(Input) then
    Exit(False);
  ReadLn(Input, Line);
  Result := True;
  AddHistory(Line);
end;

function ReadInteractiveLine(const Prompt: ansistring; out Line: ansistring): Boolean;
begin
  if StdinIsTTY then
    Result := ReadTTYLine(Prompt, Line)
  else
    Result := ReadPlainLine(Prompt, Line);
end;

end.
