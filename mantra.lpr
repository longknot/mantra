program mantra;

{$I mantra.inc}

uses
  SysUtils, BaseUnix, exp_tokenizer, mathparser, nodes, matcher_ir, context,
  debugger_types, debugger_api, debugger_state, debugger_postmortem,
  debugger_inspect, debugger_cli, debugger_runtime;

procedure ShowHelp;
begin
  WriteLn(#$1B'[38;5;42m    ___  ___     ___     ___  ___________________     ___');
  WriteLn(#$1B'[38;5;78m .:|   \/   |:::/   \:::|   \|   ___    ___      \:::/   \::::.');
  WriteLn(#$1B'[38;5;114m:::|        |::/  .  \::|       |:::|  |:::|  .  /::/  .  \:::::');
  WriteLn(#$1B'[38;5;150m:::|  |\/|  |:/   _   \:|  |\   |:::|  |:::|     \:/   _   \::::');
  WriteLn(#$1B'[38;5;186m:::|__|::|_______/:\_______|:\__|:::|__|:::|__|\______/:\___\:::');
  WriteLn(#$1B'[0m');
  WriteLn('Usage: mantra [options] [file]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  --raw          Print unformatted TreeValue output');
  WriteLn('  --interactive, -i');
  WriteLn('                 Start REPL mode (process input incrementally)');
  WriteLn('  --debug, -d    Print every statement output (debug mode)');
  WriteLn('  --debug-ir     Print parser-friendly IR for each non-output statement');
  WriteLn('  --debugger     Attach debugger event recorder (experimental)');
  WriteLn('  --debugger-cli');
  WriteLn('                 Enter debugger command loop on exceptions');
  WriteLn('  --break-callable NAME');
  WriteLn('                 Break when callable NAME is about to dispatch');
  WriteLn('  --break-statement TEXT');
  WriteLn('                 Break when a statement matching TEXT is about to execute');
  WriteLn('  --break-source SPEC');
  WriteLn('                 Break on source location (SPEC = LINE | FILE:LINE | FILE:LINE:COL)');
  WriteLn('  --break-rule TEXT');
  WriteLn('                 Break when a rule matching TEXT probes successfully');
  WriteLn('  --break-inference TEXT');
  WriteLn('                 Break when an inference state matching TEXT is entered');
  WriteLn('  --debugger-postmortem');
  WriteLn('                 Print debugger stack/events on exceptions');
  WriteLn('  --eval, -e     Evaluate output before printing');
  WriteLn('  --eval=EXPR    Append and run: print { EXPR }');
  WriteLn('  --head-dispatch');
  WriteLn('                 Enable implicit rule dispatch for { head ... } forms (default)');
  WriteLn('  --no-head-dispatch');
  WriteLn('                 Disable implicit rule dispatch for { head ... } forms');
  WriteLn('  --backtracking');
  WriteLn('                 Enable matcher backtracking for infix -- patterns');
  WriteLn('  --show-input   Show input line(s) prefixed with ">"');
  WriteLn('  --show-tokens  Show tokenizer output during compile');
  WriteLn('  --event-log[=diag|trace|json|text|diag,json|trace,json]');
  WriteLn('                 Emit matcher events to stdout (diag,text by default)');
  WriteLn('  --congruence-budget N');
  WriteLn('                 Max sub-expression rewrites in |= (default: unlimited)');
  WriteLn('  --beam-width N');
  WriteLn('                 Beam width for |= proof search (default: 1)');
  WriteLn('  --no-guards    Disable matcher rule guards (experimental)');
  WriteLn('  --set NAME=EXPR');
  WriteLn('                 Predefine a variable before execution (repeatable)');
  WriteLn('  --package-root PATH');
  WriteLn('                 Add an external package search root (repeatable)');
  WriteLn('  --help         Show this help');
end;

function HasRedirectedStdin: Boolean;
var
  St: Stat;
begin
  Result := False;
  if fpFStat(TextRec(Input).Handle, St) <> 0 then
    Exit(False);
  Result := not FPS_ISCHR(St.st_mode);
end;

procedure Bootstrap;
var
  inputPath: ansistring;
  options: TRunOptions;
  setSpec: ansistring;
  arg: ansistring;
  i: Integer;
  eqPos: Integer;
  printDeprecatedWarned: Boolean;
  debuggerBreakSpec: ansistring;
  function IsSetArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--set=', S) = 1;
  end;
  function IsEvalExprArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--eval=', S) = 1;
  end;
  function IsEventLogArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--event-log=', S) = 1;
  end;
  function IsCongruenceBudgetArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--congruence-budget=', S) = 1;
  end;
  function IsBeamWidthArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--beam-width=', S) = 1;
  end;
  function IsPackageRootArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--package-root=', S) = 1;
  end;
  function IsBreakCallableArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--break-callable=', S) = 1;
  end;
  function IsBreakStatementArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--break-statement=', S) = 1;
  end;
  function IsBreakSourceArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--break-source=', S) = 1;
  end;
  function IsBreakRuleArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--break-rule=', S) = 1;
  end;
  function IsBreakInferenceArg(const S: ansistring): Boolean;
  begin
    Result := Pos('--break-inference=', S) = 1;
  end;
  function ParseEventLogSpec(
    const S: ansistring;
    out Level: TEventLogLevel;
    out LogFormat: TEventLogFormat
  ): Boolean;
  var
    Spec: ansistring;
    Token: ansistring;
    P: Integer;
    LevelSet: Boolean;
    FormatSet: Boolean;
  begin
    Spec := LowerCase(Trim(S));
    LevelSet := False;
    FormatSet := False;
    Level := ellDiag;
    LogFormat := elfText;

    while Spec <> '' do
    begin
      P := Pos(',', Spec);
      if P > 0 then
      begin
        Token := Trim(Copy(Spec, 1, P - 1));
        Delete(Spec, 1, P);
      end
      else
      begin
        Token := Trim(Spec);
        Spec := '';
      end;

      if Token = '' then
        Continue;

      if Token = 'diag' then
      begin
        Level := ellDiag;
        LevelSet := True;
      end
      else if Token = 'trace' then
      begin
        Level := ellTrace;
        LevelSet := True;
      end
      else if Token = 'json' then
      begin
        LogFormat := elfJson;
        FormatSet := True;
      end
      else if Token = 'text' then
      begin
        LogFormat := elfText;
        FormatSet := True;
      end
      else
        Exit(False);
    end;

    if not LevelSet then
      Level := ellDiag;
    if not FormatSet then
      LogFormat := elfText;
    Result := True;
  end;
  procedure AddSetAssignment(const Spec: ansistring);
  var
    Name: ansistring;
    N: Integer;
  begin
    eqPos := Pos('=', Spec);
    if eqPos <= 1 then
      raise Exception.CreateFmt('Invalid --set argument: %s (expected NAME=EXPR)', [Spec]);
    Name := Trim(Copy(Spec, 1, eqPos - 1));
    if Name = '' then
      raise Exception.CreateFmt('Invalid --set argument: %s (missing variable name)', [Spec]);
    N := Length(options.SetAssignments);
    SetLength(options.SetAssignments, N + 1);
    options.SetAssignments[N] := Spec;
  end;
  procedure AddEvalExpression(const Spec: ansistring);
  var
    ExprText: ansistring;
    N: Integer;
  begin
    ExprText := Trim(Spec);
    if ExprText = '' then
      raise Exception.Create('Invalid --eval=EXPR argument: missing expression');
    N := Length(options.EvalExpressions);
    SetLength(options.EvalExpressions, N + 1);
    options.EvalExpressions[N] := ExprText;
  end;
  procedure AddPackageRoot(const Spec: ansistring);
  var
    RootPath: ansistring;
    N: Integer;
  begin
    RootPath := Trim(Spec);
    if RootPath = '' then
      raise Exception.Create('Invalid --package-root argument: missing path');
    N := Length(options.PackageRoots);
    SetLength(options.PackageRoots, N + 1);
    options.PackageRoots[N] := RootPath;
  end;
  procedure AddDebuggerBreakpoint(
    AKind: TDebuggerBreakpointKind;
    const Pattern: ansistring
  );
  var
    N: Integer;
    TrimmedPattern: ansistring;
  begin
    TrimmedPattern := Trim(Pattern);
    if TrimmedPattern = '' then
      raise Exception.CreateFmt('Invalid debugger breakpoint pattern for %s', [DebuggerBreakpointKindName(AKind)]);
    N := Length(options.DebuggerBreakpoints);
    SetLength(options.DebuggerBreakpoints, N + 1);
    options.DebuggerBreakpoints[N] := TDebuggerBreakpoint.Create(AKind, TrimmedPattern);
    options.DebuggerEnabled := True;
    options.DebuggerCLI := True;
  end;
  procedure AddSourceDebuggerBreakpoint(const Spec: ansistring);
  var
    N: Integer;
    Breakpoint: TDebuggerBreakpoint;
  begin
    Breakpoint := TDebuggerBreakpoint.Create(dbkSource, '');
    if not TryParseDebuggerSourceSpec(Spec, Breakpoint.Source) then
      raise Exception.CreateFmt(
        'Invalid --break-source spec: %s (expected LINE | FILE:LINE | FILE:LINE:COL)',
        [Spec]
      );
    N := Length(options.DebuggerBreakpoints);
    SetLength(options.DebuggerBreakpoints, N + 1);
    options.DebuggerBreakpoints[N] := Breakpoint;
    options.DebuggerEnabled := True;
    options.DebuggerCLI := True;
  end;
begin
  options := DefaultRunOptions;
  inputPath := '';
  printDeprecatedWarned := False;
  MatcherGuardsEnabled := True;

  i := 1;
  while i <= ParamCount do
  begin
    arg := ParamStr(i);
    if arg = '--raw' then
      options.Raw := True
    else if (arg = '--interactive') or (arg = '-i') then
      options.Interactive := True
    else if (arg = '--debug') or (arg = '-d') then
      options.DebugOutput := True
    else if arg = '--debug-ir' then
      options.DebugIR := True
    else if arg = '--debugger' then
      options.DebuggerEnabled := True
    else if arg = '--debugger-cli' then
    begin
      options.DebuggerEnabled := True;
      options.DebuggerCLI := True;
    end
    else if arg = '--break-callable' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --break-callable');
      Inc(i);
      debuggerBreakSpec := ParamStr(i);
      AddDebuggerBreakpoint(dbkCallable, debuggerBreakSpec);
    end
    else if IsBreakCallableArg(arg) then
    begin
      debuggerBreakSpec := Copy(arg, Length('--break-callable=') + 1, MaxInt);
      AddDebuggerBreakpoint(dbkCallable, debuggerBreakSpec);
    end
    else if arg = '--break-statement' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --break-statement');
      Inc(i);
      debuggerBreakSpec := ParamStr(i);
      AddDebuggerBreakpoint(dbkStatement, debuggerBreakSpec);
    end
    else if IsBreakStatementArg(arg) then
    begin
      debuggerBreakSpec := Copy(arg, Length('--break-statement=') + 1, MaxInt);
      AddDebuggerBreakpoint(dbkStatement, debuggerBreakSpec);
    end
    else if arg = '--break-source' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --break-source');
      Inc(i);
      debuggerBreakSpec := ParamStr(i);
      AddSourceDebuggerBreakpoint(debuggerBreakSpec);
    end
    else if IsBreakSourceArg(arg) then
    begin
      debuggerBreakSpec := Copy(arg, Length('--break-source=') + 1, MaxInt);
      AddSourceDebuggerBreakpoint(debuggerBreakSpec);
    end
    else if arg = '--break-rule' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --break-rule');
      Inc(i);
      debuggerBreakSpec := ParamStr(i);
      AddDebuggerBreakpoint(dbkRule, debuggerBreakSpec);
    end
    else if IsBreakRuleArg(arg) then
    begin
      debuggerBreakSpec := Copy(arg, Length('--break-rule=') + 1, MaxInt);
      AddDebuggerBreakpoint(dbkRule, debuggerBreakSpec);
    end
    else if arg = '--break-inference' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --break-inference');
      Inc(i);
      debuggerBreakSpec := ParamStr(i);
      AddDebuggerBreakpoint(dbkInference, debuggerBreakSpec);
    end
    else if IsBreakInferenceArg(arg) then
    begin
      debuggerBreakSpec := Copy(arg, Length('--break-inference=') + 1, MaxInt);
      AddDebuggerBreakpoint(dbkInference, debuggerBreakSpec);
    end
    else if arg = '--debugger-postmortem' then
    begin
      options.DebuggerEnabled := True;
      options.DebuggerPostmortem := True;
    end
    else if (arg = '--print') or (arg = '-p') then
    begin
      options.DebugOutput := True;
      if not printDeprecatedWarned then
      begin
        WriteLn(ErrOutput, 'Warning: --print/-p is deprecated; use --debug/-d.');
        printDeprecatedWarned := True;
      end;
    end
    else if IsEvalExprArg(arg) then
      AddEvalExpression(Copy(arg, Length('--eval=') + 1, MaxInt))
    else if (arg = '--eval') or (arg = '-e') then
      options.EvalOutput := True
    else if arg = '--head-dispatch' then
      options.HeadDispatch := True
    else if arg = '--no-head-dispatch' then
      options.HeadDispatch := False
    else if arg = '--backtracking' then
      options.Backtracking := True
    else if (arg = '--show-input') or (arg = '--input') then
      options.ShowInput := True
    else if arg = '--show-tokens' then
      options.ShowTokens := True
    else if arg = '--event-log' then
    begin
      options.EventLogLevel := ellDiag;
      options.EventLogStdout := True;
      options.EventLogFormat := elfText;
    end
    else if IsEventLogArg(arg) then
    begin
      if not ParseEventLogSpec(
               Copy(arg, Length('--event-log=') + 1, MaxInt),
               options.EventLogLevel,
               options.EventLogFormat
             ) then
        raise Exception.CreateFmt(
          'Invalid --event-log mode: %s (expected diag|trace|json|text and comma combos)',
          [arg]
        );
      options.EventLogStdout := True;
    end
    else if arg = '--congruence-budget' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --congruence-budget');
      Inc(i);
      options.InferenceCongruenceBudget := StrToIntDef(Trim(ParamStr(i)), MaxInt);
      if options.InferenceCongruenceBudget < -1 then
        raise Exception.CreateFmt('Invalid --congruence-budget: %s (expected -1 or >= 0)', [ParamStr(i)]);
      if options.InferenceCongruenceBudget = MaxInt then
        raise Exception.CreateFmt('Invalid --congruence-budget: %s', [ParamStr(i)]);
      options.InferenceCongruenceBudgetExplicit := True;
    end
    else if IsCongruenceBudgetArg(arg) then
    begin
      options.InferenceCongruenceBudget := StrToIntDef(
        Trim(Copy(arg, Length('--congruence-budget=') + 1, MaxInt)),
        MaxInt
      );
      if options.InferenceCongruenceBudget < -1 then
        raise Exception.CreateFmt('Invalid --congruence-budget: %s (expected -1 or >= 0)', [arg]);
      if options.InferenceCongruenceBudget = MaxInt then
        raise Exception.CreateFmt('Invalid --congruence-budget: %s', [arg]);
      options.InferenceCongruenceBudgetExplicit := True;
    end
    else if arg = '--beam-width' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --beam-width');
      Inc(i);
      options.InferenceBeamWidth := StrToIntDef(Trim(ParamStr(i)), 0);
      if options.InferenceBeamWidth < 1 then
        raise Exception.CreateFmt('Invalid --beam-width: %s (expected >= 1)', [ParamStr(i)]);
      options.InferenceBeamWidthExplicit := True;
    end
    else if IsBeamWidthArg(arg) then
    begin
      options.InferenceBeamWidth := StrToIntDef(
        Trim(Copy(arg, Length('--beam-width=') + 1, MaxInt)),
        0
      );
      if options.InferenceBeamWidth < 1 then
        raise Exception.CreateFmt('Invalid --beam-width: %s (expected >= 1)', [arg]);
      options.InferenceBeamWidthExplicit := True;
    end
    else if arg = '--no-guards' then
      MatcherGuardsEnabled := False
    else if arg = '--set' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --set (expected NAME=EXPR)');
      Inc(i);
      setSpec := ParamStr(i);
      AddSetAssignment(setSpec);
    end
    else if IsSetArg(arg) then
    begin
      setSpec := Copy(arg, Length('--set=') + 1, MaxInt);
      AddSetAssignment(setSpec);
    end
    else if arg = '--package-root' then
    begin
      if i = ParamCount then
        raise Exception.Create('Missing value for --package-root');
      Inc(i);
      AddPackageRoot(ParamStr(i));
    end
    else if IsPackageRootArg(arg) then
      AddPackageRoot(Copy(arg, Length('--package-root=') + 1, MaxInt))
    else if arg = '--help' then
    begin
      ShowHelp;
      Exit;
    end
    else if arg = '-' then
    begin
      if inputPath = '' then
        inputPath := '-'
      else
        raise Exception.CreateFmt('Unexpected argument: %s', [arg]);
    end
    else if (arg <> '') and (arg[1] = '-') then
      raise Exception.CreateFmt('Unknown option: %s', [arg])
    else if inputPath = '' then
      inputPath := arg
    else
      raise Exception.CreateFmt('Unexpected argument: %s', [arg]);

    Inc(i);
  end;

  if inputPath = '' then
  begin
    if options.Interactive then
      inputPath := '-'
    else if HasRedirectedStdin then
      inputPath := '/dev/stdin'
    else
    begin
      ShowHelp;
      Exit;
    end;
  end;

  RegisterObjects;
  Execute(inputPath, options);
end;

begin
  try
    Bootstrap;
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.Message);
      Halt(1);
    end;
  end;
end.
