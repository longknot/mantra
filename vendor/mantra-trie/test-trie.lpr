program test_trie;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  MaskTrieDictionary3;

type
  TIntTrie = TTrieDictionary;
  TPatternCollector = class
  public
    Count: Integer;
    ValueSum: Integer;
    StopAfterOne: Boolean;
    procedure Reset;
    procedure HandleMatch(const Key: ansistring; const Value: Integer; var Continue: Boolean);
  end;

var
  Trie: TIntTrie;
  Collector: TPatternCollector;
  V: Integer;
  Resolved: ansistring;
  RootState: TIntTrie.TStateHandle;
  ChildState: TIntTrie.TStateHandle;
  GrandChildState: TIntTrie.TStateHandle;
  Passed, Failed: Integer;

procedure TPatternCollector.Reset;
begin
  Count := 0;
  ValueSum := 0;
  StopAfterOne := False;
end;

procedure TPatternCollector.HandleMatch(
  const Key: ansistring;
  const Value: Integer;
  var Continue: Boolean
);
begin
  Inc(Count);
  Inc(ValueSum, Value);
  Continue := not StopAfterOne;
  if Key = '' then
    Continue := False;
end;

function LoadKeyValueFile(const FileName: string; ATrie: TIntTrie): Integer;
var
  Lines: TStringList;
  I, SepPos, Loaded: Integer;
  Line, Key, ValuePart: string;
begin
  Result := 0;
  if not FileExists(FileName) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    Loaded := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if (Line = '') or (Line[1] = '#') then
        Continue;

      SepPos := Pos('=', Line);
      if SepPos <= 1 then
        Continue;

      Key := Trim(Copy(Line, 1, SepPos - 1));
      ValuePart := Trim(Copy(Line, SepPos + 1, MaxInt));
      if Key = '' then
        Continue;

      ATrie.Add(RawByteString(Key), StrToIntDef(ValuePart, Loaded + 1));
      Inc(Loaded);
    end;
    Result := Loaded;
  finally
    Lines.Free;
  end;
end;

procedure Check(Condition: Boolean; const Msg: string);
begin
  if Condition then
  begin
    Inc(Passed);
    Writeln('[PASS] ', Msg);
  end
  else
  begin
    Inc(Failed);
    Writeln('[FAIL] ', Msg);
  end;
end;

begin
  Passed := 0;
  Failed := 0;

  Writeln('Running MaskTrieDictionary basic tests...');
  Trie := TIntTrie.Create;
  Collector := TPatternCollector.Create;
  try
    Trie.Add('alpha', 10);
    Trie.Add('beta', 20);
    Trie.Add('alphabet', 30);

    Check(Trie.TryGetValue('alpha', V) and (V = 10), 'lookup alpha');
    Check(Trie.TryGetValue('beta', V) and (V = 20), 'lookup beta');
    Check(Trie.TryGetValue('alphabet', V) and (V = 30), 'lookup alphabet');
    Check(not Trie.TryGetValue('alp', V), 'lookup missing prefix');
    Check(Trie.ContainsKey('alpha'), 'contains alpha');
    Check(not Trie.ContainsKey('gamma'), 'missing gamma');
    Check(Trie.Count = 3, 'count after inserts = 3');

    Trie.Add('alpha', 99);
    Check(Trie.TryGetValue('alpha', V) and (V = 99), 'overwrite alpha');
    Check(Trie.Count = 3, 'count unchanged after overwrite');
    Check(Trie.Remove('alpha'), 'remove alpha');
    Check(not Trie.TryGetValue('alpha', V), 'lookup removed alpha');
    Check(not Trie.Remove('alpha'), 'remove alpha again (missing)');
    Check(not Trie.Remove('missing'), 'remove missing key');
    Check(Trie.Count = 2, 'count after removals = 2');

    Trie.Clear;
    Trie.Add('root.a', 1);
    Trie.Add('root.a.x', 2);
    Trie.Add('root.b', 3);
    Check(Trie.Count = 3, 'subtree setup count = 3');
    Check(Trie.RemoveSubtree('root.a'), 'remove subtree root.a');
    Check(not Trie.TryGetValue('root.a', V), 'subtree removed root.a');
    Check(not Trie.TryGetValue('root.a.x', V), 'subtree removed root.a.x');
    Check(Trie.TryGetValue('root.b', V) and (V = 3), 'subtree keeps sibling root.b');
    Check(Trie.Count = 1, 'subtree count after removing root.a');
    Check(not Trie.RemoveSubtree('root.missing'), 'remove subtree missing');
    Check(Trie.RemoveSubtree('root'), 'remove subtree root');
    Check(Trie.Count = 0, 'subtree count after removing root');

    Trie.Clear;
    Trie.Add('dict.obj1', 10);
    Trie.Add('dict.obj1.a', 11);
    Trie.Add('dict.obj1[1]', 12);
    Trie.Add('dict.obj2', 20);
    Trie.Add('dict.obj2.a', 21);
    Check(Trie.CopySubtree('dict.obj1', 'dict.obj2', cmMergeKeep), 'copy subtree merge-keep');
    Check(Trie.TryGetValue('dict.obj2', V) and (V = 20), 'copy merge-keep keeps root collision');
    Check(Trie.TryGetValue('dict.obj2.a', V) and (V = 21), 'copy merge-keep keeps child collision');
    Check(Trie.TryGetValue('dict.obj2[1]', V) and (V = 12), 'copy merge-keep adds missing indexed key');
    Check(Trie.Count = 6, 'copy merge-keep count');

    Check(Trie.CopySubtree('dict.obj1', 'dict.obj2', cmMergeOverwrite), 'copy subtree merge-overwrite');
    Check(Trie.TryGetValue('dict.obj2', V) and (V = 10), 'copy merge-overwrite root');
    Check(Trie.TryGetValue('dict.obj2.a', V) and (V = 11), 'copy merge-overwrite child');
    Check(Trie.TryGetValue('dict.obj2[1]', V) and (V = 12), 'copy merge-overwrite indexed child');
    Check(Trie.Count = 6, 'copy merge-overwrite count unchanged');

    Trie.Add('dict.obj3.a', 999);
    Check(not Trie.CopySubtree('dict.obj1', 'dict.obj3', cmFailOnConflict), 'copy subtree fail-on-conflict');
    Check(Trie.TryGetValue('dict.obj3.a', V) and (V = 999), 'copy fail-on-conflict keeps existing');
    Check(not Trie.TryGetValue('dict.obj3', V), 'copy fail-on-conflict no partial root write');
    Check(not Trie.TryGetValue('dict.obj3[1]', V), 'copy fail-on-conflict no partial indexed write');

    Trie.Add('dict.obj4.old', 400);
    Trie.Add('dict.obj4.a', 401);
    Check(Trie.CopySubtree('dict.obj1', 'dict.obj4', cmReplace), 'copy subtree replace');
    Check(not Trie.TryGetValue('dict.obj4.old', V), 'copy replace removes stale key');
    Check(Trie.TryGetValue('dict.obj4', V) and (V = 10), 'copy replace root');
    Check(Trie.TryGetValue('dict.obj4.a', V) and (V = 11), 'copy replace child');
    Check(Trie.TryGetValue('dict.obj4[1]', V) and (V = 12), 'copy replace indexed child');

    Trie.Clear;
    Check(Trie.Count = 0, 'count after clear = 0');
    Check(not Trie.TryGetValue('alpha', V), 'lookup after clear');

    if LoadKeyValueFile('vendor/mantra-trie/test-prefix-data.txt', Trie) > 0 then
    begin
      Check(Trie.PrefixCount('user:') = 4, 'prefix count user:');
      Check(Trie.PrefixCount('user:1.') = 2, 'prefix count user:1.');
      Check(Trie.PrefixCount('order:') = 2, 'prefix count order:');
      Check(Trie.PrefixCount('order:7.') = 1, 'prefix count order:7.');
      Check(Trie.PrefixCount('missing:') = 0, 'prefix count missing:');
    end
    else
      Writeln('[INFO] skipped prefix-file tests (file not found)');

    Trie.Clear;
    if LoadKeyValueFile('vendor/mantra-trie/test-pattern-data.txt', Trie) > 0 then
    begin
      Check(Trie.PatternCount('x.*.y.*') = 3, 'pattern count x.*.y.*');
      Check(Trie.PatternCount('x.*.z.*') = 1, 'pattern count x.*.z.*');
      Check(Trie.PatternCount('*.a.y.b') = 2, 'pattern count *.a.y.b');
      Check(Trie.PatternCount('x.*.*.*') = 4, 'pattern count x.*.*.*');
      Check(Trie.PatternCount('x.a*.y.*') = 2, 'pattern count x.a*.y.*');
      Check(Trie.PatternCount('x.?.z.d') = 1, 'pattern count x.?.z.d');
      Check(Trie.PatternCount('x.a.y.b') = 1, 'pattern count x.a.y.b');
      Check(Trie.PatternCount('missing.*.y.*') = 0, 'pattern count missing.*.y.*');

      Collector.Reset;
      Check(
        Trie.ScanPattern('x.*.y.*', @Collector.HandleMatch) = 3,
        'scan pattern x.*.y.* count'
      );
      Check(Collector.Count = 3, 'scan callback x.*.y.* invoked 3 times');
      Check(Collector.ValueSum = 7, 'scan callback x.*.y.* value sum = 7');

      Collector.Reset;
      Check(
        Trie.ScanPattern('x.a*.y.*', @Collector.HandleMatch) = 2,
        'scan pattern x.a*.y.* count'
      );
      Check(Collector.Count = 2, 'scan callback x.a*.y.* invoked 2 times');
      Check(Collector.ValueSum = 5, 'scan callback x.a*.y.* value sum = 5');

      Collector.Reset;
      Check(
        Trie.ScanPattern('missing.*.y.*', @Collector.HandleMatch) = 0,
        'scan pattern missing.*.y.* count'
      );
      Check(Collector.Count = 0, 'scan callback missing.*.y.* not invoked');

      Collector.Reset;
      Collector.StopAfterOne := True;
      Check(
        Trie.ScanPattern('x.*.y.*', @Collector.HandleMatch) = 1,
        'scan pattern x.*.y.* early-stop count'
      );
      Check(Collector.Count = 1, 'scan callback early-stop invoked once');
    end
    else
      Writeln('[INFO] skipped pattern-file tests (file not found)');

    Trie.Clear;
    RootState := Trie.GetRootState;
    Check(Trie.MarkStateIndexed(RootState, 2), 'indexed state mark root');
    Check(Trie.IsIndexedState(RootState), 'indexed state flag root');

    Check(Trie.AddIndexed(RootState, 0, 11), 'indexed add root[0]');
    Check(Trie.AddIndexed(RootState, 3, 44), 'indexed add root[3] auto-grow');
    Check(Trie.TryGetIndexed(RootState, 0, V) and (V = 11), 'indexed lookup root[0]');
    Check(Trie.TryGetIndexed(RootState, 3, V) and (V = 44), 'indexed lookup root[3]');
    Check(not Trie.TryGetIndexed(RootState, 1, V), 'indexed lookup missing root[1]');
    Check(Trie.Count = 2, 'indexed count after root inserts');

    Check(Trie.EnsureIndexedState(RootState, 1, ChildState), 'indexed ensure child root[1]');
    Check(Trie.MarkStateIndexed(ChildState, 0), 'indexed mark child state');
    Check(Trie.AddIndexed(ChildState, 2, 222), 'indexed add child[2]');
    Check(Trie.TryGetIndexed(ChildState, 2, V) and (V = 222), 'indexed lookup child[2]');
    Check(Trie.Count = 3, 'indexed count after nested insert');

    Check(Trie.EnsureIndexedState(ChildState, 2, GrandChildState), 'indexed ensure grandchild state');
    Check(GrandChildState <> 0, 'indexed grandchild state id');
    Check(Trie.RemoveSubtree('[2]'), 'indexed remove subtree [2]');
    Check(not Trie.TryGetIndexed(RootState, 1, V), 'indexed removed root[2]');
    Check(Trie.TryGetIndexed(RootState, 0, V) and (V = 11), 'indexed keep root[1]');
    Check(Trie.TryGetIndexed(RootState, 3, V) and (V = 44), 'indexed keep root[4]');
    Check(Trie.Count = 2, 'indexed count after removing subtree [2]');

    Trie.Clear;
    Trie.Add('dict.obj', 500);
    Check(Trie.TryLocateState('dict.obj', ChildState), 'locate state dict.obj');
    Check(Trie.MarkStateIndexed(ChildState, 2), 'mark dict.obj indexed');
    Check(Trie.AddIndexed(ChildState, 0, 111), 'indexed add dict.obj[1]');
    Check(Trie.AddIndexed(ChildState, 1, 222), 'indexed add dict.obj[2]');

    Check(
      Trie.ResolveIndexedPattern('dict.obj[1]', Resolved) and (Resolved = 'dict.obj[1]'),
      'resolve indexed state segment dict.obj[1]'
    );
    Check(
      Trie.ResolveIndexedPattern('dict.obj[2]', Resolved) and (Resolved = 'dict.obj[2]'),
      'resolve indexed state segment dict.obj[2]'
    );
    Check(
      not Trie.ResolveIndexedPattern('dict.obj[3]', Resolved),
      'resolve indexed state segment missing dict.obj[3]'
    );

    Collector.Reset;
    Check(
      Trie.ScanPattern('dict.obj[2]', @Collector.HandleMatch) = 1,
      'scan indexed bracket pattern count'
    );
    Check(Collector.Count = 1, 'scan indexed bracket callback count');
    Check(Collector.ValueSum = 222, 'scan indexed bracket value sum');

    Trie.Clear;
    Trie.Add('dict.obj1.attr.x', 10);
    Trie.Add('dict.obj2.attr.x', 20);
    Trie.Add('dict.obj3.attr.x', 30);
    Trie.Add('dict.other.attr.x', 99);

    Check(
      Trie.PatternCount('dict.obj*.attr.x') = 3,
      'lexical indexed baseline dict.obj*.attr.x'
    );

    Check(
      Trie.ResolveIndexedPattern('dict.obj[1].attr.x', Resolved) and
      (Resolved = 'dict.obj1.attr.x'),
      'resolve lexical indexed segment dict.obj[1].attr.x'
    );
    Check(
      Trie.ResolveIndexedPattern('dict.obj[2].attr.x', Resolved) and
      (Resolved = 'dict.obj2.attr.x'),
      'resolve lexical indexed segment dict.obj[2].attr.x'
    );
    Check(
      Trie.ResolveIndexedPattern('dict.obj[3].attr.x', Resolved) and
      (Resolved = 'dict.obj3.attr.x'),
      'resolve lexical indexed segment dict.obj[3].attr.x'
    );
    Check(
      not Trie.ResolveIndexedPattern('dict.obj[4].attr.x', Resolved),
      'resolve lexical indexed segment missing dict.obj[4].attr.x'
    );

    Check(
      Trie.ResolveIndexedPattern('dict.obj[1].attr.x', Resolved) and
      (Trie.PatternCount(Resolved) = 1),
      'scan lexical indexed dict.obj[1].attr.x'
    );
    Check(
      Trie.ResolveIndexedPattern('dict.obj[2].attr.x', Resolved) and
      (Trie.PatternCount(Resolved) = 1),
      'scan lexical indexed dict.obj[2].attr.x'
    );
    Check(
      Trie.ResolveIndexedPattern('dict.obj[3].attr.x', Resolved) and
      (Trie.PatternCount(Resolved) = 1),
      'scan lexical indexed dict.obj[3].attr.x'
    );
    Check(
      Trie.PatternCount('dict.obj[4].attr.x') = 0,
      'pattern lexical indexed missing dict.obj[4].attr.x'
    );
  finally
    Collector.Free;
    Trie.Free;
  end;

  Writeln;
  Writeln('Summary: ', Passed, ' passed, ', Failed, ' failed.');
  if Failed <> 0 then
    Halt(1);
end.
