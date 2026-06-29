unit string_utils;

{$I mantra.inc}

interface

type
  TAnsiStringArray = array of ansistring;
  TAnsiCharArray = array of ansichar;

function UnquoteSingleChar(const S: ansistring; out C: Integer): Boolean;
function UnquoteStringLiteral(const S: ansistring; out Value: ansistring): Boolean;
function QuoteStringLiteral(const S: ansistring): ansistring;
procedure CollectPercentFormatVerbs(const Pattern: ansistring; out Verbs: TAnsiCharArray);
function ExpandPercentFormatTemplate(
  const Pattern: ansistring;
  const Replacements: TAnsiStringArray
): ansistring;

implementation

uses
  SysUtils;

function UnquoteSingleChar(const S: ansistring; out C: Integer): Boolean;
var
  Raw: ansistring;
begin
  Result := False;
  C := 0;
  Raw := Trim(S);
  if Length(Raw) >= 2 then
  begin
    if ((Raw[1] = '"') and (Raw[Length(Raw)] = '"')) or
       ((Raw[1] = #39) and (Raw[Length(Raw)] = #39)) then
      Raw := Copy(Raw, 2, Length(Raw) - 2);
  end;
  if Length(Raw) <> 1 then
    Exit(False);
  C := Ord(Raw[1]);
  Result := True;
end;

function UnquoteStringLiteral(const S: ansistring; out Value: ansistring): Boolean;
var
  Raw: ansistring;
  I: Integer;
  C: AnsiChar;
begin
  Result := False;
  Value := '';
  Raw := Trim(S);
  if Length(Raw) < 2 then
    Exit(False);
  if (Raw[1] <> '"') or (Raw[Length(Raw)] <> '"') then
    Exit(False);

  I := 2;
  while I < Length(Raw) do
  begin
    C := Raw[I];
    if C = '\' then
    begin
      Inc(I);
      if I >= Length(Raw) then
        Exit(False);
      case Raw[I] of
        '"': Value := Value + '"';
        '\': Value := Value + '\';
        'n': Value := Value + #10;
        'r': Value := Value + #13;
        't': Value := Value + #9;
      else
        Value := Value + Raw[I];
      end;
    end
    else
      Value := Value + C;
    Inc(I);
  end;
  Result := True;
end;

function QuoteStringLiteral(const S: ansistring): ansistring;
var
  I: Integer;
  C: AnsiChar;
begin
  Result := '"';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9: Result := Result + '\t';
    else
      Result := Result + C;
    end;
  end;
  Result := Result + '"';
end;

procedure CollectPercentFormatVerbs(const Pattern: ansistring; out Verbs: TAnsiCharArray);
var
  I: Integer;
  Count: Integer;
begin
  SetLength(Verbs, 0);
  I := 1;
  while I <= Length(Pattern) do
  begin
    if Pattern[I] <> '%' then
    begin
      Inc(I);
      Continue;
    end;

    Inc(I);
    if I > Length(Pattern) then
      raise Exception.Create('format template has a trailing "%"');

    if Pattern[I] <> '%' then
    begin
      Count := Length(Verbs);
      SetLength(Verbs, Count + 1);
      Verbs[Count] := Pattern[I];
    end;
    Inc(I);
  end;
end;

function ExpandPercentFormatTemplate(
  const Pattern: ansistring;
  const Replacements: TAnsiStringArray
): ansistring;
var
  I: Integer;
  ArgIndex: Integer;
begin
  Result := '';
  ArgIndex := 0;
  I := 1;
  while I <= Length(Pattern) do
  begin
    if Pattern[I] <> '%' then
    begin
      Result := Result + Pattern[I];
      Inc(I);
      Continue;
    end;

    Inc(I);
    if I > Length(Pattern) then
      raise Exception.Create('format template has a trailing "%"');

    if Pattern[I] = '%' then
      Result := Result + '%'
    else
    begin
      if ArgIndex >= Length(Replacements) then
        raise Exception.CreateFmt(
          'format template expected more replacements for %%%s',
          [ansistring(Pattern[I])]
        );
      Result := Result + Replacements[ArgIndex];
      Inc(ArgIndex);
    end;

    Inc(I);
  end;

  if ArgIndex <> Length(Replacements) then
    raise Exception.CreateFmt(
      'format template expected %d replacements but got %d',
      [ArgIndex, Length(Replacements)]
    );
end;

end.
