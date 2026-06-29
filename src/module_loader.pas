unit module_loader;

{$I mantra.inc}

interface

type
  TResolvedSourceSegment = record
    Text: ansistring;
    FilePath: ansistring;
    StartLine: Integer;
  end;

  TResolvedSourceSegmentArray = array of TResolvedSourceSegment;

procedure ResetModuleLoaderState(const EntryPath: ansistring);
procedure SetModulePackageRoots(const PackageRoots: array of ansistring);
function ResolveIncludeDirectiveSource(
  const IncludePath: ansistring;
  const CallerPackage: ansistring
): ansistring;
function ResolveIncludeDirectiveSegments(
  const IncludePath: ansistring;
  const CallerPackage: ansistring
): TResolvedSourceSegmentArray;
function ResolveImportDirectiveSource(
  const PackagePath: ansistring;
  const CallerPackage: ansistring
): ansistring;
function ResolveImportDirectiveSegments(
  const PackagePath: ansistring;
  const CallerPackage: ansistring
): TResolvedSourceSegmentArray;
function ResolveModuleSource(const EntryPath: ansistring): ansistring;

implementation

uses
  Classes, SysUtils, StrUtils;

type
  TModuleResolver = class
  private
    FEntryDir: ansistring;
    FLoadedFiles: TStringList;
    FLoadingFiles: TStringList;
    FLoadedPackages: TStringList;
    FLoadingPackages: TStringList;
    FPackageRoots: TStringList;
    FOutput: TStringList;
    FOutputSourceFiles: TStringList;
    FOutputSourceLines: array of Integer;
    function TryParsePackageDirective(const Line: ansistring; out PackagePath: ansistring): Boolean;
    function TryParseIncludeDirective(const Line: ansistring; out IncludePath: ansistring): Boolean;
    function TryParseImportDirective(const Line: ansistring; out PackagePath: ansistring): Boolean;
    function ResolveIncludePath(const BaseDir, IncludePath: ansistring): ansistring;
    function NormalizePackagePath(const PackagePath: ansistring): ansistring;
    function ResolvePackageEntryFile(const BaseDir, PackagePath: ansistring): ansistring;
    function BuildCycleMessage(const Stack: TStringList; const CanonicalPath: ansistring): ansistring;
    procedure AppendOutputLine(
      const LineText: ansistring;
      const SourceFile: ansistring = '';
      SourceLine: Integer = 0
    );
    function DrainOutputFrom(const StartIndex: Integer): ansistring;
    function DrainOutputSegmentsFrom(const StartIndex: Integer): TResolvedSourceSegmentArray;
    procedure ResolvePackage(
      const PackagePath,
      BaseDir,
      CallerPackage: ansistring
    );
    procedure ResolveFile(
      const FilePath,
      CurrentPackage,
      ExpectedPackage: ansistring;
      RequirePackageMatch: Boolean
    );
  public
    constructor Create;
    destructor Destroy; override;
    procedure ResetState;
    procedure SetPackageRoots(const PackageRoots: array of ansistring);
    procedure BeginRuntime(const EntryPath: ansistring);
    function ResolveIncludeDirective(
      const IncludePath: ansistring;
      const CallerPackage: ansistring
    ): ansistring;
    function ResolveIncludeDirectiveToSegments(
      const IncludePath: ansistring;
      const CallerPackage: ansistring
    ): TResolvedSourceSegmentArray;
    function ResolveImportDirective(
      const PackagePath: ansistring;
      const CallerPackage: ansistring
    ): ansistring;
    function ResolveImportDirectiveToSegments(
      const PackagePath: ansistring;
      const CallerPackage: ansistring
    ): TResolvedSourceSegmentArray;
    function Resolve(const EntryPath: ansistring): ansistring;
  end;

constructor TModuleResolver.Create;
begin
  inherited Create;
  FLoadedFiles := TStringList.Create;
  FLoadedFiles.Sorted := False;
  FLoadedFiles.Duplicates := dupIgnore;

  FLoadingFiles := TStringList.Create;
  FLoadingFiles.Sorted := False;
  FLoadingFiles.Duplicates := dupIgnore;

  FLoadedPackages := TStringList.Create;
  FLoadedPackages.Sorted := False;
  FLoadedPackages.Duplicates := dupIgnore;

  FLoadingPackages := TStringList.Create;
  FLoadingPackages.Sorted := False;
  FLoadingPackages.Duplicates := dupIgnore;

  FPackageRoots := TStringList.Create;
  FPackageRoots.Sorted := False;
  FPackageRoots.Duplicates := dupIgnore;

  FOutput := TStringList.Create;
  FOutputSourceFiles := TStringList.Create;
  ResetState;
end;

destructor TModuleResolver.Destroy;
begin
  FOutputSourceFiles.Free;
  FOutput.Free;
  FPackageRoots.Free;
  FLoadingPackages.Free;
  FLoadedPackages.Free;
  FLoadingFiles.Free;
  FLoadedFiles.Free;
  inherited Destroy;
end;

procedure TModuleResolver.ResetState;
begin
  FEntryDir := '';
  FLoadedFiles.Clear;
  FLoadingFiles.Clear;
  FLoadedPackages.Clear;
  FLoadingPackages.Clear;
  FOutput.Clear;
  FOutputSourceFiles.Clear;
  SetLength(FOutputSourceLines, 0);
end;

procedure TModuleResolver.SetPackageRoots(const PackageRoots: array of ansistring);
var
  I: Integer;
  RootPath: ansistring;
begin
  FPackageRoots.Clear;
  for I := 0 to High(PackageRoots) do
  begin
    if Trim(PackageRoots[I]) = '' then
      raise Exception.Create('Package root must not be empty');
    RootPath := ExpandFileName(PackageRoots[I]);
    if not DirectoryExists(RootPath) then
      raise Exception.CreateFmt('Package root not found: %s', [RootPath]);
    if FPackageRoots.IndexOf(RootPath) < 0 then
      FPackageRoots.Add(RootPath);
  end;
end;

function IsStdinSource(const EntryPath: ansistring): Boolean;
begin
  Result := (EntryPath = '') or (EntryPath = '-') or (EntryPath = '/dev/stdin');
end;

function SegmentsToText(const Segments: TResolvedSourceSegmentArray): ansistring;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Segments) do
    Result := Result + Segments[I].Text;
end;

procedure TModuleResolver.BeginRuntime(const EntryPath: ansistring);
var
  CanonicalEntry: ansistring;
begin
  ResetState;
  if not IsStdinSource(EntryPath) then
  begin
    CanonicalEntry := ExpandFileName(EntryPath);
    FEntryDir := ExtractFileDir(CanonicalEntry);
    FLoadedFiles.Add(CanonicalEntry);
  end
  else
    FEntryDir := ExpandFileName(GetCurrentDir);
end;

function TModuleResolver.TryParsePackageDirective(
  const Line: ansistring;
  out PackagePath: ansistring
): Boolean;
var
  S, Token, Rest: ansistring;
  EndPos, I: Integer;
begin
  Result := False;
  PackagePath := '';
  S := Trim(Line);
  if not StartsText('package', S) then
    Exit;

  S := Trim(Copy(S, Length('package') + 1, MaxInt));
  if S = '' then
    Exit;

  if S[1] = '<' then
  begin
    EndPos := Pos('>', S);
    if EndPos <= 1 then
      Exit;
    Token := Copy(S, 2, EndPos - 2);
    Rest := Trim(Copy(S, EndPos + 1, MaxInt));
  end
  else
  begin
    I := 1;
    while (I <= Length(S)) and (S[I] > ' ') and (S[I] <> ';') do
      Inc(I);
    Token := Copy(S, 1, I - 1);
    Rest := Trim(Copy(S, I, MaxInt));
  end;

  Token := NormalizePackagePath(Token);
  if Token = '' then
    Exit;

  if Rest <> '' then
  begin
    if Rest[1] = ';' then
      Rest := Trim(Copy(Rest, 2, MaxInt));
    if (Rest <> '') and (not StartsText('//', Rest)) then
      Exit;
  end;

  PackagePath := Token;
  Result := True;
end;

function TModuleResolver.TryParseIncludeDirective(
  const Line: ansistring;
  out IncludePath: ansistring
): Boolean;
var
  S: ansistring;
  Quote: AnsiChar;
  EndPos: Integer;
  Rest: ansistring;
begin
  Result := False;
  IncludePath := '';
  S := Trim(Line);
  if not StartsText('include', S) then
    Exit;

  S := Trim(Copy(S, Length('include') + 1, MaxInt));
  if S = '' then
    Exit;

  Quote := S[1];
  if not (Quote in ['"', #39]) then
    Exit;

  Delete(S, 1, 1);
  EndPos := Pos(Quote, S);
  if EndPos <= 0 then
    Exit;

  IncludePath := Copy(S, 1, EndPos - 1);
  Rest := Trim(Copy(S, EndPos + 1, MaxInt));
  if Rest = '' then
    Exit(True);
  if Rest[1] = ';' then
    Rest := Trim(Copy(Rest, 2, MaxInt));

  Result := (Rest = '') or StartsText('//', Rest);
end;

function TModuleResolver.TryParseImportDirective(
  const Line: ansistring;
  out PackagePath: ansistring
): Boolean;
var
  S, Token, Rest: ansistring;
  EndPos, I: Integer;
begin
  Result := False;
  PackagePath := '';
  S := Trim(Line);
  if not StartsText('import', S) then
    Exit;

  S := Trim(Copy(S, Length('import') + 1, MaxInt));
  if S = '' then
    Exit;

  if S[1] = '<' then
  begin
    EndPos := Pos('>', S);
    if EndPos <= 1 then
      Exit;
    Token := Copy(S, 2, EndPos - 2);
    Rest := Trim(Copy(S, EndPos + 1, MaxInt));
  end
  else
  begin
    I := 1;
    while (I <= Length(S)) and (S[I] > ' ') and (S[I] <> ';') do
      Inc(I);
    Token := Copy(S, 1, I - 1);
    Rest := Trim(Copy(S, I, MaxInt));
  end;

  Token := NormalizePackagePath(Token);
  if Token = '' then
    Exit;

  if Rest <> '' then
  begin
    if Rest[1] = ';' then
      Rest := Trim(Copy(Rest, 2, MaxInt));
    if (Rest <> '') and (not StartsText('//', Rest)) then
      Exit;
  end;

  PackagePath := Token;
  Result := True;
end;

function TModuleResolver.ResolveIncludePath(
  const BaseDir,
  IncludePath: ansistring
): ansistring;
begin
  if ExtractFileDrive(IncludePath) <> '' then
    Exit(ExpandFileName(IncludePath));
  if (IncludePath <> '') and (IncludePath[1] = PathDelim) then
    Exit(ExpandFileName(IncludePath));
  Result := ExpandFileName(IncludeTrailingPathDelimiter(BaseDir) + IncludePath);
end;

function TModuleResolver.NormalizePackagePath(const PackagePath: ansistring): ansistring;
var
  S, Segment: ansistring;
  SegmentStart, SeparatorPos: Integer;
begin
  S := Trim(PackagePath);
  S := StringReplace(S, ' ', '', [rfReplaceAll]);
  S := StringReplace(S, '\', '/', [rfReplaceAll]);
  while (S <> '') and (S[1] = '/') do
    Delete(S, 1, 1);
  while (S <> '') and (S[Length(S)] = '/') do
    Delete(S, Length(S), 1);

  SegmentStart := 1;
  while SegmentStart <= Length(S) do
  begin
    SeparatorPos := PosEx('/', S, SegmentStart);
    if SeparatorPos = 0 then
      SeparatorPos := Length(S) + 1;
    Segment := Copy(S, SegmentStart, SeparatorPos - SegmentStart);
    if (Segment = '') or (Segment = '.') or (Segment = '..') then
      raise Exception.CreateFmt('Invalid package path: %s', [PackagePath]);
    SegmentStart := SeparatorPos + 1;
  end;
  Result := S;
end;

function TModuleResolver.ResolvePackageEntryFile(
  const BaseDir,
  PackagePath: ansistring
): ansistring;
var
  CurDir, ParentDir, Candidate, RelativePackagePath: ansistring;
  I: Integer;
  function TryResolveFromPackagesDir(
    const PackagesDir: ansistring;
    out FoundPath: ansistring
  ): Boolean;
  begin
    Result := False;
    FoundPath := '';

    Candidate := ExpandFileName(
      IncludeTrailingPathDelimiter(PackagesDir) + RelativePackagePath + '.m'
    );
    if FileExists(Candidate) then
    begin
      FoundPath := Candidate;
      Exit(True);
    end;

    Candidate := ExpandFileName(
      IncludeTrailingPathDelimiter(PackagesDir) +
      RelativePackagePath + PathDelim + 'package.m'
    );
    if FileExists(Candidate) then
    begin
      FoundPath := Candidate;
      Exit(True);
    end;
  end;
  function TryResolveFromRoot(const RootDir: ansistring; out FoundPath: ansistring): Boolean;
  var
    PackagesDir: ansistring;
  begin
    PackagesDir := ExpandFileName(
      IncludeTrailingPathDelimiter(RootDir) + 'packages' + PathDelim
    );
    Result := TryResolveFromPackagesDir(PackagesDir, FoundPath);
  end;
begin
  RelativePackagePath := StringReplace(
    PackagePath,
    '/',
    PathDelim,
    [rfReplaceAll]
  );
  CurDir := ExpandFileName(BaseDir);
  while CurDir <> '' do
  begin
    if TryResolveFromRoot(CurDir, Result) then
      Exit;

    ParentDir := ExpandFileName(ExtractFileDir(CurDir));
    if ParentDir = CurDir then
      Break;
    CurDir := ParentDir;
  end;

  if TryResolveFromRoot(GetCurrentDir, Result) then
    Exit;

  for I := 0 to FPackageRoots.Count - 1 do
    if TryResolveFromPackagesDir(FPackageRoots[I], Result) then
      Exit;

  raise Exception.CreateFmt(
    'Package not found: %s (expected packages/%s.m, packages/%s/package.m, or a configured package root)',
    [PackagePath, PackagePath, PackagePath]
  );
end;

function TModuleResolver.BuildCycleMessage(
  const Stack: TStringList;
  const CanonicalPath: ansistring
): ansistring;
var
  StartIndex, I: Integer;
begin
  StartIndex := Stack.IndexOf(CanonicalPath);
  if StartIndex < 0 then
    Exit(CanonicalPath);

  Result := '';
  for I := StartIndex to Stack.Count - 1 do
  begin
    if Result <> '' then
      Result := Result + ' -> ';
    Result := Result + Stack[I];
  end;
  if Result <> '' then
    Result := Result + ' -> ' + CanonicalPath
  else
    Result := CanonicalPath;
end;

procedure TModuleResolver.AppendOutputLine(
  const LineText: ansistring;
  const SourceFile: ansistring;
  SourceLine: Integer
);
var
  L: Integer;
begin
  FOutput.Add(LineText);
  FOutputSourceFiles.Add(SourceFile);
  L := Length(FOutputSourceLines);
  SetLength(FOutputSourceLines, L + 1);
  FOutputSourceLines[L] := SourceLine;
end;

function TModuleResolver.DrainOutputFrom(const StartIndex: Integer): ansistring;
var
  I: Integer;
  OutputLines: TStringList;
begin
  if StartIndex >= FOutput.Count then
    Exit('');

  OutputLines := TStringList.Create;
  try
    for I := StartIndex to FOutput.Count - 1 do
      OutputLines.Add(FOutput[I]);
    Result := OutputLines.Text;
  finally
    OutputLines.Free;
  end;
end;

function TModuleResolver.DrainOutputSegmentsFrom(
  const StartIndex: Integer
): TResolvedSourceSegmentArray;
var
  I: Integer;
  CurFile: ansistring;
  CurStartLine: Integer;
  CurNextLine: Integer;
  SegmentsCount: Integer;
  LineSourceFile: ansistring;
  LineSourceLine: Integer;
  Lines: TStringList;
  ContinuesSegment: Boolean;

  procedure FlushSegment;
  begin
    if Lines.Count = 0 then
      Exit;
    SegmentsCount := Length(Result);
    SetLength(Result, SegmentsCount + 1);
    Result[SegmentsCount].Text := Lines.Text;
    Result[SegmentsCount].FilePath := CurFile;
    Result[SegmentsCount].StartLine := CurStartLine;
    Lines.Clear;
  end;
begin
  SetLength(Result, 0);
  if StartIndex >= FOutput.Count then
    Exit;

  Lines := TStringList.Create;
  try
    CurFile := '';
    CurStartLine := 0;
    CurNextLine := 0;

    for I := StartIndex to FOutput.Count - 1 do
    begin
      if I < FOutputSourceFiles.Count then
        LineSourceFile := FOutputSourceFiles[I]
      else
        LineSourceFile := '';
      if I < Length(FOutputSourceLines) then
        LineSourceLine := FOutputSourceLines[I]
      else
        LineSourceLine := 0;

      if Lines.Count = 0 then
      begin
        CurFile := LineSourceFile;
        CurStartLine := LineSourceLine;
        Lines.Add(FOutput[I]);
        if LineSourceLine > 0 then
          CurNextLine := LineSourceLine + 1
        else
          CurNextLine := 0;
        Continue;
      end;

      ContinuesSegment := (LineSourceFile = CurFile);
      if ContinuesSegment then
      begin
        if CurNextLine > 0 then
          ContinuesSegment := (LineSourceLine = CurNextLine)
        else
          ContinuesSegment := (LineSourceLine <= 0);
      end;

      if not ContinuesSegment then
      begin
        FlushSegment;
        CurFile := LineSourceFile;
        CurStartLine := LineSourceLine;
      end;

      Lines.Add(FOutput[I]);
      if LineSourceLine > 0 then
        CurNextLine := LineSourceLine + 1
      else
        CurNextLine := 0;
    end;

    FlushSegment;
  finally
    Lines.Free;
  end;
end;

procedure TModuleResolver.ResolvePackage(
  const PackagePath,
  BaseDir,
  CallerPackage: ansistring
);
var
  CanonicalPackage, ModuleFile: ansistring;
begin
  CanonicalPackage := NormalizePackagePath(PackagePath);
  if CanonicalPackage = '' then
    Exit;
  if FLoadedPackages.IndexOf(CanonicalPackage) >= 0 then
    Exit;
  if FLoadingPackages.IndexOf(CanonicalPackage) >= 0 then
    raise Exception.CreateFmt(
      'Import cycle detected: %s', [BuildCycleMessage(FLoadingPackages, CanonicalPackage)]
    );

  FLoadingPackages.Add(CanonicalPackage);
  try
    ModuleFile := ResolvePackageEntryFile(BaseDir, CanonicalPackage);
    ResolveFile(ModuleFile, CallerPackage, CanonicalPackage, True);
    if CallerPackage <> '' then
      AppendOutputLine('package ' + CallerPackage + ';');
  finally
    FLoadingPackages.Delete(FLoadingPackages.Count - 1);
  end;

  FLoadedPackages.Add(CanonicalPackage);
end;

procedure TModuleResolver.ResolveFile(
  const FilePath,
  CurrentPackage,
  ExpectedPackage: ansistring;
  RequirePackageMatch: Boolean
);
var
  CanonicalPath: ansistring;
  ModuleLines: TStringList;
  I: Integer;
  Line, IncludePath, PackagePath, DeclaredPackage, EffectivePackage: ansistring;
  BaseDir: ansistring;
begin
  CanonicalPath := ExpandFileName(FilePath);
  if FLoadedFiles.IndexOf(CanonicalPath) >= 0 then
    Exit;

  if FLoadingFiles.IndexOf(CanonicalPath) >= 0 then
    raise Exception.CreateFmt(
      'Import cycle detected: %s', [BuildCycleMessage(FLoadingFiles, CanonicalPath)]
    );

  if not FileExists(CanonicalPath) then
    raise Exception.CreateFmt('Import file not found: %s', [CanonicalPath]);

  FLoadingFiles.Add(CanonicalPath);
  ModuleLines := TStringList.Create;
  try
    BaseDir := ExtractFileDir(CanonicalPath);
    ModuleLines.LoadFromFile(CanonicalPath);
    DeclaredPackage := '';
    for I := 0 to ModuleLines.Count - 1 do
      if TryParsePackageDirective(ModuleLines[I], DeclaredPackage) then
        Break;

    EffectivePackage := CurrentPackage;
    if RequirePackageMatch then
    begin
      if DeclaredPackage = '' then
        raise Exception.CreateFmt(
          'Imported module missing package declaration: %s',
          [CanonicalPath]
        );
      if NormalizePackagePath(DeclaredPackage) <> NormalizePackagePath(ExpectedPackage) then
        raise Exception.CreateFmt(
          'Imported module package mismatch: expected %s but found %s in %s',
          [ExpectedPackage, DeclaredPackage, CanonicalPath]
        );
      EffectivePackage := NormalizePackagePath(DeclaredPackage);
      AppendOutputLine('package ' + EffectivePackage + ';');
    end;

    for I := 0 to ModuleLines.Count - 1 do
    begin
      Line := ModuleLines[I];
      if TryParsePackageDirective(Line, PackagePath) then
        Continue;
      if TryParseIncludeDirective(Line, IncludePath) then
      begin
        ResolveFile(ResolveIncludePath(BaseDir, IncludePath), EffectivePackage, '', False);
        Continue;
      end;
      if TryParseImportDirective(Line, PackagePath) then
      begin
        ResolvePackage(PackagePath, BaseDir, EffectivePackage);
        Continue;
      end;
      AppendOutputLine(Line, CanonicalPath, I + 1);
    end;
    AppendOutputLine('');
  finally
    ModuleLines.Free;
    FLoadingFiles.Delete(FLoadingFiles.Count - 1);
  end;

  FLoadedFiles.Add(CanonicalPath);
end;

function TModuleResolver.ResolveIncludeDirective(
  const IncludePath: ansistring;
  const CallerPackage: ansistring
): ansistring;
begin
  Result := SegmentsToText(ResolveIncludeDirectiveToSegments(IncludePath, CallerPackage));
end;

function TModuleResolver.ResolveIncludeDirectiveToSegments(
  const IncludePath: ansistring;
  const CallerPackage: ansistring
): TResolvedSourceSegmentArray;
var
  BaseDir: ansistring;
  StartIndex: Integer;
begin
  if FEntryDir = '' then
    BaseDir := ExpandFileName(GetCurrentDir)
  else
    BaseDir := FEntryDir;

  StartIndex := FOutput.Count;
  ResolveFile(
    ResolveIncludePath(BaseDir, IncludePath),
    NormalizePackagePath(CallerPackage),
    '',
    False
  );
  Result := DrainOutputSegmentsFrom(StartIndex);
end;

function TModuleResolver.ResolveImportDirective(
  const PackagePath: ansistring;
  const CallerPackage: ansistring
): ansistring;
begin
  Result := SegmentsToText(ResolveImportDirectiveToSegments(PackagePath, CallerPackage));
end;

function TModuleResolver.ResolveImportDirectiveToSegments(
  const PackagePath: ansistring;
  const CallerPackage: ansistring
): TResolvedSourceSegmentArray;
var
  BaseDir: ansistring;
  StartIndex: Integer;
begin
  if FEntryDir = '' then
    BaseDir := ExpandFileName(GetCurrentDir)
  else
    BaseDir := FEntryDir;

  StartIndex := FOutput.Count;
  ResolvePackage(PackagePath, BaseDir, NormalizePackagePath(CallerPackage));
  Result := DrainOutputSegmentsFrom(StartIndex);
end;

function TModuleResolver.Resolve(const EntryPath: ansistring): ansistring;
begin
  ResetState;
  if EntryPath <> '' then
    FEntryDir := ExtractFileDir(ExpandFileName(EntryPath));
  ResolveFile(EntryPath, '', '', False);
  Result := FOutput.Text;
end;

function ResolveModuleSource(const EntryPath: ansistring): ansistring;
var
  Resolver: TModuleResolver;
begin
  Resolver := TModuleResolver.Create;
  try
    Result := Resolver.Resolve(EntryPath);
  finally
    Resolver.Free;
  end;
end;

var
  RuntimeResolver: TModuleResolver = nil;

function GetRuntimeResolver: TModuleResolver;
begin
  if not Assigned(RuntimeResolver) then
    RuntimeResolver := TModuleResolver.Create;
  Result := RuntimeResolver;
end;

procedure ResetModuleLoaderState(const EntryPath: ansistring);
begin
  GetRuntimeResolver.BeginRuntime(EntryPath);
end;

procedure SetModulePackageRoots(const PackageRoots: array of ansistring);
begin
  GetRuntimeResolver.SetPackageRoots(PackageRoots);
end;

function ResolveIncludeDirectiveSource(
  const IncludePath: ansistring;
  const CallerPackage: ansistring
): ansistring;
begin
  Result := GetRuntimeResolver.ResolveIncludeDirective(IncludePath, CallerPackage);
end;

function ResolveIncludeDirectiveSegments(
  const IncludePath: ansistring;
  const CallerPackage: ansistring
): TResolvedSourceSegmentArray;
begin
  Result := GetRuntimeResolver.ResolveIncludeDirectiveToSegments(IncludePath, CallerPackage);
end;

function ResolveImportDirectiveSource(
  const PackagePath: ansistring;
  const CallerPackage: ansistring
): ansistring;
begin
  Result := GetRuntimeResolver.ResolveImportDirective(PackagePath, CallerPackage);
end;

function ResolveImportDirectiveSegments(
  const PackagePath: ansistring;
  const CallerPackage: ansistring
): TResolvedSourceSegmentArray;
begin
  Result := GetRuntimeResolver.ResolveImportDirectiveToSegments(PackagePath, CallerPackage);
end;

finalization
  RuntimeResolver.Free;
  RuntimeResolver := nil;

end.
