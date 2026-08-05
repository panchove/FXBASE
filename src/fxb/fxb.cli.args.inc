// fxb.cli.args.inc -- CLI argument parsing (SetDefaults/ParseArgs/ShowHelp/ShowVersion).
// Included into fxb.cli.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXCLI; behaviour unchanged.

procedure TFXCLI.SetDefaults;
begin
  FTarget := 'native';
  FTargetOS := 'linux';
  FTargetCPU := 'x86_64';
  FOutputType := 'exe';
  FOptimization := 2;
  FVerbose := False;
  FDebug := False;
  FLegacyMode := False;
  FStrictMode := False;
  FDBAnsi := False;
  FRunAfterBuild := False;
  FTestMode := False;
  FLintMode := False;
  FDumpAST := False;
  FDumpIR := False;
  FDumpASM := False;
  FDBDriver := 'sqlite';
  FGeneratePPO := False;
  FIncludeStdFph := True;
  FShowHelp := False;
  FShowVersion := False;
  FJobs := 0; // 0 = auto-detect
  FCacheDir := '.fxbcache';
  FTwoPass := False;
end;

procedure TFXCLI.ParseArgs;
var
  i: Integer;
  arg: string;
  spec: string;
  eq: Integer;
begin
  i := 1;
  while i <= ParamCount do
  begin
    arg := ParamStr(i);
    if (arg = '-h') or (arg = '--help') then
      FShowHelp := True
    else if (arg = '-v') or (arg = '--version') then
      FShowVersion := True
    else if (arg = '-o') or (arg = '--output') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FOutputFile := ParamStr(i);
      end;
    end
    else if (arg = '--target') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FTarget := ParamStr(i);
      end;
    end
    else if (arg = '--target-os') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FTargetOS := ParamStr(i);
      end;
    end
    else if (arg = '--target-cpu') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FTargetCPU := ParamStr(i);
      end;
    end
    else if (arg = '--output-type') or (arg = '-t') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FOutputType := ParamStr(i);
      end;
    end
    else if (arg = '-O') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FOptimization := StrToIntDef(ParamStr(i), 2);
      end
      else
        FOptimization := 2;
    end
    else if (arg = '-g') or (arg = '--debug') then
      FDebug := True
    else if (arg = '--verbose') or (arg = '-V') then
      FVerbose := True
    else if (arg = '--legacy') then
      FLegacyMode := True
    else if (arg = '--strict') then
      FStrictMode := True
    else if (arg = '--no-strict') then
      FStrictMode := False
    else if (arg = '--db-ansi') then
      FDBAnsi := True
    else if (arg = '--run') then
      FRunAfterBuild := True
    else if (arg = '--test') then
      FTestMode := True
    else if (arg = '--lint') then
      FLintMode := True
    else if (arg = '--dump-ast') then
      FDumpAST := True
    else if (arg = '--dump-ir') then
      FDumpIR := True
    else if (arg = '--dump-asm') then
      FDumpASM := True
    else if (arg = '--db-driver') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FDBDriver := ParamStr(i);
      end;
    end
    else if (arg = '--db-connection') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FDBConnection := ParamStr(i);
      end;
    end
    else if Copy(arg, 1, 5) = '--db:' then
    begin
      // Fase 2.7: compact flag form `--db:<driver>` or `--db:<driver>=<conn>`.
      // e.g. `--db:sqlite` or `--db:sqlite=/path/to/file.db`
      spec := Copy(arg, 6, Length(arg) - 5);   // strip '--db:'
      eq := Pos('=', spec);
      if eq > 0 then
      begin
        FDBDriver := Copy(spec, 1, eq - 1);
        FDBConnection := Copy(spec, eq + 1, Length(spec) - eq);
      end
      else
      begin
        FDBDriver := spec;
        // A bare `--db:sqlite` with no connection string: FDBConnection stays
        // as-is and the backend falls back to a default path.
      end;
    end
    else if (arg = '--ppo') then
      FGeneratePPO := True
    else if (arg = '--output-ppo') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FOutputPPO := ParamStr(i);
      end;
    end
    else if (arg = '--no-std-fph') then
      FIncludeStdFph := False
    else if (arg = '-I') or (arg = '--include') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FIncludePaths.Add(ParamStr(i));
      end;
    end
    else if (arg = '-D') or (arg = '--define') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FDefines.Add(ParamStr(i));
      end;
    end
    else if (arg = '-j') or (arg = '--jobs') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FJobs := StrToIntDef(ParamStr(i), 0);
      end
      else
        FJobs := 0;
    end
    else if (arg = '--cache-dir') then
    begin
      if i < ParamCount then
      begin
        Inc(i);
        FCacheDir := ParamStr(i);
      end;
    end
    else if (arg = '--two-pass') then
      FTwoPass := True
    else if not arg.StartsWith('-') then
    begin
      FSourceFiles.Add(arg);
      if FInputFile = '' then
        FInputFile := arg
      else if not FTwoPass then
        FArgs.Add(arg);
    end
    else
    begin
      WriteLn(StdErr, 'Warning: unknown option: ', arg);
    end;
    Inc(i);
  end;
end;

procedure TFXCLI.ShowHelp;
begin
  WriteLn('FXBASE Compiler (fxbc) - Modern xBASE Compiler');
  WriteLn('Usage: fxbc [options] <input.prg|.fpg> [args...]');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  -h, --help              Show this help');
  WriteLn('  -v, --version           Show version');
  WriteLn('  -o, --output <file>     Output file (default: input.exe/input.dll)');
  WriteLn('  -t, --output-type <type> Output type: exe, dll, so, lib, a (default: exe)');
  WriteLn('  --target <target>       Target: native, win32, win64, linux32, linux64 (default: native)');
  WriteLn('  --target-os <os>        Target OS: windows, linux (default: linux)');
  WriteLn('  --target-cpu <cpu>      Target CPU: x86, x86_64, arm64 (default: x86_64)');
  WriteLn('  -O<level>               Optimization level: 0, 1, 2, 3 (default: 2)');
  WriteLn('  -g, --debug             Generate debug info');
  WriteLn('  -V, --verbose           Verbose output');
  WriteLn('  --legacy                Legacy Clipper/Harbour mode (warns on legacy syntax)');
  WriteLn('  --strict                Strict type checking (default: off)');
  WriteLn('  --no-strict             Disable strict type checking');
  WriteLn('  --db-ansi               Legacy byte-wise string mode (default: UTF-8)');
  WriteLn('  --db-driver <driver>    Database driver: sqlite, postgres, mssql (default: sqlite)');
  WriteLn('  --db-connection <conn>  Database connection string');
  WriteLn('  --run                   Run executable after build');
  WriteLn('  --test                  Run tests');
  WriteLn('  --lint                  Lint mode (check only, no output)');
  WriteLn('  --dump-ast              Dump AST to stdout');
  WriteLn('  --dump-ir               Dump IR to stdout');
  WriteLn('  --dump-asm              Dump assembly to stdout');
  WriteLn('  --ppo                   Generate preprocessor output (.ppo)');
  WriteLn('  --output-ppo <file>     Output .ppo to specific file');
  WriteLn('  --no-std-fph            Do not auto-include std.fph');
  WriteLn('  -I, --include <path>    Add include path');
  WriteLn('  -D, --define <macro>    Define preprocessor macro');
  WriteLn('  -j, --jobs <n>          Parallel jobs (0 = auto-detect cores, default: 0)');
  WriteLn('  --cache-dir <dir>       Cache directory (default: .fxbcache)');
  WriteLn('  --two-pass              Enable two-pass compilation (symbol collection + parallel compile)');
  WriteLn('');
  WriteLn('File extensions:');
  WriteLn('  .prg  - xBASE source (Clipper/Harbour compatible)');
  WriteLn('  .fbg  - FXBASE source (modern extensions)');
  WriteLn('  .fbh  - Header file (like .ch)');
  WriteLn('  .ppo  - Preprocessor output');
  WriteLn('');
  WriteLn('Examples:');
  WriteLn('  fxb hello.prg                    # Compile to hello.exe');
  WriteLn('  fxb -o myapp.exe main.fpg        # Compile to myapp.exe');
  WriteLn('  fxb --target win64 app.prg       # Cross-compile to Windows x64');
  WriteLn('  fxb --target-os linux --target-cpu arm64 app.prg');
  WriteLn('  fxb --db-driver postgres --db-connection "host=localhost dbname=mydb" app.prg');
  WriteLn('  fxb --legacy --db-ansi legacy.prg # Legacy Clipper mode');
  WriteLn('  fxb --dump-ast hello.prg         # Dump AST');
  WriteLn('  fxb --lint hello.prg             # Lint only');
  WriteLn('');
  WriteLn('FXBASE - Modern xBASE Compiler - MIT License');
end;

procedure TFXCLI.ShowVersion;
begin
  WriteLn('FXBASE Compiler (fxbc) 0.1.0-dev');
  WriteLn('Target: ', FTargetOS, '-', FTargetCPU);
  WriteLn('License: MIT');
end;

