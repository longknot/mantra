unit system_commands;

{$I mantra.inc}

interface

uses
  context;

type
  TCommandArgs = array of ansistring;

  TSystemCommand = function(
    Context: TContext;
    const DestPrefix: ansistring;
    const Args: TCommandArgs;
    out ResultHandle: ansistring
  ): Integer;

procedure RegisterSystemCommand(
  const Name: ansistring;
  MinArgs: Integer;
  MaxArgs: Integer;
  Command: TSystemCommand
);

function ExecuteSystemCommand(
  Context: TContext;
  const Name: ansistring;
  const DestPrefix: ansistring;
  const Args: TCommandArgs;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Boolean;

procedure RegisterBuiltinSystemCommands;

var
  SystemCommandsRegistered: Boolean = False;

implementation

uses
  SysUtils, Classes, value_node_helpers, external_operations, http_operation;

type
  TSystemCommandEntry = record
    Name: ansistring;
    MinArgs: Integer;
    MaxArgs: Integer;
    Command: TSystemCommand;
  end;

  TDirectoryEntry = class
  public
    Attr: LongInt;
    Size: Int64;
    Time: LongInt;
  end;

var
  SystemCommandEntries: array of TSystemCommandEntry;

procedure RegisterSystemCommand(
  const Name: ansistring;
  MinArgs: Integer;
  MaxArgs: Integer;
  Command: TSystemCommand
);
var
  Entry: TSystemCommandEntry;
  I: Integer;
begin
  if (Name = '') or (not Assigned(Command)) then
    Exit;
  if MinArgs < 0 then
    MinArgs := 0;
  if (MaxArgs >= 0) and (MaxArgs < MinArgs) then
    MaxArgs := MinArgs;

  for I := 0 to High(SystemCommandEntries) do
    if SameText(SystemCommandEntries[I].Name, Name) then
    begin
      SystemCommandEntries[I].MinArgs := MinArgs;
      SystemCommandEntries[I].MaxArgs := MaxArgs;
      SystemCommandEntries[I].Command := Command;
      Exit;
    end;

  Entry.Name := Name;
  Entry.MinArgs := MinArgs;
  Entry.MaxArgs := MaxArgs;
  Entry.Command := Command;

  I := Length(SystemCommandEntries);
  SetLength(SystemCommandEntries, I + 1);
  SystemCommandEntries[I] := Entry;
end;

function ExecuteSystemCommand(
  Context: TContext;
  const Name: ansistring;
  const DestPrefix: ansistring;
  const Args: TCommandArgs;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Boolean;
var
  I: Integer;
  Arity: Integer;
  Status: Integer;
begin
  Result := False;
  ResultHandle := '';
  ErrorText := '';

  Arity := Length(Args);
  for I := 0 to High(SystemCommandEntries) do
  begin
    if not SameText(SystemCommandEntries[I].Name, Name) then
      Continue;

    if Arity < SystemCommandEntries[I].MinArgs then
    begin
      ErrorText := Format(
        'system command "%s" expects at least %d argument(s), got %d',
        [Name, SystemCommandEntries[I].MinArgs, Arity]
      );
      Exit(False);
    end;
    if (SystemCommandEntries[I].MaxArgs >= 0) and
       (Arity > SystemCommandEntries[I].MaxArgs) then
    begin
      ErrorText := Format(
        'system command "%s" expects at most %d argument(s), got %d',
        [Name, SystemCommandEntries[I].MaxArgs, Arity]
      );
      Exit(False);
    end;

    Status := SystemCommandEntries[I].Command(Context, DestPrefix, Args, ResultHandle);
    if Status <> 0 then
    begin
      ErrorText := Format(
        'system command "%s" failed with status %d',
        [Name, Status]
      );
      Exit(False);
    end;
    if ResultHandle = '' then
      ResultHandle := DestPrefix;
    Exit(True);
  end;

  ErrorText := Format('unknown system command: %s', [Name]);
end;


function JoinPath(const BasePath, Name: ansistring): ansistring;
begin
  if BasePath = '' then
    Result := Name
  else
    Result := IncludeTrailingPathDelimiter(BasePath) + Name;
end;

procedure AddStringField(
  Context: TContext;
  const BasePath: ansistring;
  const FieldName: ansistring;
  const FieldValue: ansistring
);
begin
  Context.AddVariable(
    BasePath + '.' + FieldName,
    CreateStringNodeFromText(FieldValue)
  );
end;

procedure AddIntegerField(
  Context: TContext;
  const BasePath: ansistring;
  const FieldName: ansistring;
  const FieldValue: Int64
);
begin
  Context.AddVariable(
    BasePath + '.' + FieldName,
    CreateIntegerNodeFromText(IntToStr(FieldValue))
  );
end;

function FileDateTimeIso(const FileDate: LongInt): ansistring;
var
  DateTimeValue: TDateTime;
begin
  Result := '';
  if FileDate <= 0 then
    Exit;
  DateTimeValue := FileDateToDateTime(FileDate);
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', DateTimeValue);
end;

function FileKindFromAttr(const Attr: LongInt): ansistring;
begin
  if (Attr and faDirectory) <> 0 then
    Result := 'directory'
  else
    Result := 'file';
end;

function SystemCommandCat(
  Context: TContext;
  const DestPrefix: ansistring;
  const Args: TCommandArgs;
  out ResultHandle: ansistring
): Integer;
var
  SourcePath: ansistring;
  Content: ansistring;
  HandlePrefix: ansistring;
  ValueNode: Integer;
  Stream: TFileStream;
  ByteCount: SizeInt;
begin
  Result := 1;
  ResultHandle := '';

  if not Assigned(Context) then
    Exit(1);
  if DestPrefix = '' then
    Exit(2);
  if Length(Args) <> 1 then
    Exit(3);

  SourcePath := Trim(Args[0]);
  if SourcePath = '' then
    Exit(4);
  if not FileExists(SourcePath) then
    Exit(5);

  Content := '';
  Stream := TFileStream.Create(SourcePath, fmOpenRead or fmShareDenyNone);
  try
    if Stream.Size > High(SizeInt) then
      Exit(6);
    ByteCount := SizeInt(Stream.Size);
    if ByteCount > 0 then
    begin
      SetLength(Content, ByteCount);
      Stream.ReadBuffer(Content[1], ByteCount);
    end;
  finally
    Stream.Free;
  end;

  HandlePrefix := Context.NewHandle(DestPrefix, 'handle');
  ValueNode := CreateStringNodeFromText(Content);
  Context.AddVariable(HandlePrefix, ValueNode);
  Context.AddVariable(DestPrefix, CreateStringNodeFromText(HandlePrefix));

  ResultHandle := HandlePrefix;
  Result := 0;
end;

function SystemCommandLs(
  Context: TContext;
  const DestPrefix: ansistring;
  const Args: TCommandArgs;
  out ResultHandle: ansistring
): Integer;
var
  SourcePath: ansistring;
  SearchPattern: ansistring;
  HandlePrefix: ansistring;
  EntryBase: ansistring;
  EntryPath: ansistring;
  Entries: TStringList;
  Entry: TDirectoryEntry;
  SearchRec: TSearchRec;
  SearchStatus: LongInt;
  I: Integer;
begin
  Result := 1;
  ResultHandle := '';

  if not Assigned(Context) then
    Exit(1);
  if DestPrefix = '' then
    Exit(2);
  if Length(Args) <> 1 then
    Exit(3);

  SourcePath := Trim(Args[0]);
  if SourcePath = '' then
    Exit(4);
  if not DirectoryExists(SourcePath) then
    Exit(5);

  Entries := TStringList.Create;
  try
    Entries.Sorted := True;
    Entries.Duplicates := dupIgnore;
    Entries.CaseSensitive := True;

    SearchPattern := IncludeTrailingPathDelimiter(SourcePath) + '*';
    SearchStatus := FindFirst(SearchPattern, faAnyFile, SearchRec);
    try
      while SearchStatus = 0 do
      begin
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          Entry := TDirectoryEntry.Create;
          Entry.Attr := SearchRec.Attr;
          Entry.Size := SearchRec.Size;
          Entry.Time := SearchRec.Time;
          Entries.AddObject(SearchRec.Name, Entry);
        end;
        SearchStatus := FindNext(SearchRec);
      end;
    finally
      FindClose(SearchRec);
    end;

    HandlePrefix := Context.NewHandle(DestPrefix, 'handle');
    Context.AddVariable(DestPrefix, CreateStringNodeFromText(HandlePrefix));
    AddStringField(Context, HandlePrefix, 'path', SourcePath);
    AddIntegerField(Context, HandlePrefix, 'count', Entries.Count);

    for I := 0 to Entries.Count - 1 do
    begin
      EntryBase := Format('%s.items[%d]', [HandlePrefix, I + 1]);
      EntryPath := JoinPath(SourcePath, Entries[I]);
      AddStringField(Context, EntryBase, 'name', Entries[I]);
      AddStringField(Context, EntryBase, 'path', EntryPath);
      AddStringField(
        Context,
        EntryBase,
        'kind',
        FileKindFromAttr(TDirectoryEntry(Entries.Objects[I]).Attr)
      );
      if FileExists(EntryPath) then
        AddIntegerField(Context, EntryBase, 'size', TDirectoryEntry(Entries.Objects[I]).Size)
      else
        AddIntegerField(Context, EntryBase, 'size', 0);
      AddStringField(
        Context,
        EntryBase,
        'changed',
        FileDateTimeIso(TDirectoryEntry(Entries.Objects[I]).Time)
      );
    end;

    ResultHandle := HandlePrefix;
    Result := 0;
  finally
    for I := 0 to Entries.Count - 1 do
      Entries.Objects[I].Free;
    Entries.Free;
  end;
end;

function SystemCommandHttp(
  Context: TContext;
  const DestPrefix: ansistring;
  const Args: TCommandArgs;
  out ResultHandle: ansistring
): Integer;
var
  ErrorText: ansistring;
begin
  ResultHandle := '';
  if Length(Args) <> 1 then
    Exit(3);
  if ExecuteExternalOperation(
    Context,
    'http.request',
    DestPrefix,
    Args[0],
    ResultHandle,
    ErrorText
  ) then
    Result := 0
  else
    Result := 1;
end;

procedure RegisterBuiltinSystemCommands;
begin
  if SystemCommandsRegistered then
    Exit;
  RegisterHttpOperation;
  RegisterSystemCommand('cat', 1, 1, @SystemCommandCat);
  RegisterSystemCommand('ls', 1, 1, @SystemCommandLs);
  RegisterSystemCommand('http', 1, 1, @SystemCommandHttp);
  SystemCommandsRegistered := True;
end;

end.
