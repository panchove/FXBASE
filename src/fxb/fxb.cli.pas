unit fxb.cli;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  BaseUnix,
  fxb.tokens,
  fxb.lexer,
  fxb.parser,
  fxb.ast,
  fxb.errors,
  fxb.ir,
  fxb.backend,
  fxb.ppo;

type
  TFXCLI = class
  private
    FArgs: TStringList;
    FInputFile: string;
    FOutputFile: string;
    FTarget: string;
    FVerbose: Boolean;
    FDebug: Boolean;
    FOptimization: Integer;
    FTargetArch: string;
    FOutputType: string;
    FIncludePaths: TStringList;
    FDefines: TStringList;
    FLegacyMode: Boolean;
    FStrictMode: Boolean;
    FDBAnsi: Boolean;
    FShowHelp: Boolean;
    FShowVersion: Boolean;
    FRunAfterBuild: Boolean;
    FTestMode: Boolean;
    FLintMode: Boolean;
    FDumpAST: Boolean;
    FDumpIR: Boolean;
    FDumpASM: Boolean;
    FTargetOS: string;
    FTargetCPU: string;
    FDBDriver: string;
    FDBConnection: string;
    FGeneratePPO: Boolean;
    FOutputPPO: string;
    FIncludeStdFph: Boolean;
    procedure ParseArgs;
    procedure ShowHelp;
    procedure ShowVersion;
    function CompileFile(const AFileName: string): Boolean;
    function AssembleAndLink(const AsmFile, OutputFile: string): Boolean;
    procedure RunExecutable;
    procedure RunTests;
    procedure LintFile;
    procedure DumpAST(const AAST: TCompilationUnit);
    procedure DumpIR(const AIR: TIRModule);
    procedure DumpASM(const AASM: string);
    function DetermineOutputFile(const AInputFile: string): string;
    procedure SetDefaults;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
    class procedure RunClass; static;
  end;

procedure RunFXCLI;

implementation

constructor TFXCLI.Create;
begin
  inherited Create;
  FArgs := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FDefines := TStringList.Create;
  SetDefaults;
end;

destructor TFXCLI.Destroy;
begin
  FArgs.Free;
  FIncludePaths.Free;
  FDefines.Free;
  inherited Destroy;
end;

function ExecuteProcess(const Program_: string; const Args: string): Integer;
var
  argList: TStringList;
  argv: array of PChar;
  pArgv: PPChar;
  i: Integer;
  pid: TPid;
  status: cInt;
begin
  Result := -1;
  argList := TStringList.Create;
  try
    argList.Delimiter := ' ';
    argList.StrictDelimiter := True;
    argList.DelimitedText := Args;
    SetLength(argv, argList.Count + 2);
    argv[0] := PChar(Program_);
    for i := 0 to argList.Count - 1 do
      argv[i + 1] := PChar(argList[i]);
    argv[argList.Count + 1] := nil;
    pArgv := @argv[0];

    pid := FpFork;
    case pid of
      -1:
        Exit; // fork failed
      0:
        begin
          // Child: exec, then exit with error if it fails
          FpExecV(PChar(Program_), pArgv);
          FpExit(127);
        end;
      else
        // Parent: wait for child
        if FpWaitPid(pid, status, 0) = pid then
          Result := WEXITSTATUS(status);
    end;
  finally
    argList.Free;
  end;
end;

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
    else if not arg.StartsWith('-') then
    begin
      if FInputFile = '' then
        FInputFile := arg
      else
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

procedure TFXCLI.Run;
begin
  ParseArgs;

  if FShowHelp then
  begin
    ShowHelp;
    Exit;
  end;

  if FShowVersion then
  begin
    ShowVersion;
    Exit;
  end;

  if FInputFile = '' then
  begin
    WriteLn(StdErr, 'Error: no input file specified');
    WriteLn(StdErr, 'Use -h or --help for help');
    Halt(1);
  end;

  if FTestMode then
  begin
    RunTests;
    Exit;
  end;

  if FLintMode then
  begin
    LintFile;
    Exit;
  end;

  if not CompileFile(FInputFile) then
  begin
    Halt(1);
  end;

  if FRunAfterBuild and (FOutputType = 'exe') then
    RunExecutable;
end;

class procedure TFXCLI.RunClass;
var
  cli: TFXCLI;
begin
  cli := TFXCLI.Create;
  try
    cli.Run;
  finally
    cli.Free;
  end;
end;

function TFXCLI.CompileFile(const AFileName: string): Boolean;
var
  lexer: TFXBLexer;
  reporter: TErrorReporter;
  parser: TParser;
  ast: TCompilationUnit;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  backend: TFXBBackend;
  ppo: TFXBPPO;
  source: string;
  outputFile: string;
  asmFile: string;
  sl: TStringList;
  line: string;
  err: TFXBLexerError;
  msg: TCompilerMessage;
begin
  Result := False;

  if not FileExists(AFileName) then
  begin
    WriteLn(StdErr, 'Error: file not found: ', AFileName);
    Exit;
  end;

  if FVerbose then
    WriteLn('Compiling: ', AFileName);

sl := TStringList.Create;
  try
    sl.LoadFromFile(AFileName);
    source := '';
    for line in sl do
      source := source + line + LineEnding;
  finally
    sl.Free;
  end;

  outputFile := DetermineOutputFile(AFileName);

  ppo := TFXBPPO.Create;
  try
    ppo.IncludePaths := FIncludePaths;
    ppo.Defines := FDefines;
    ppo.IncludeStdFph := FIncludeStdFph;
    ppo.LegacyMode := FLegacyMode;
    source := ppo.Process(source, AFileName);
    if FOutputPPO <> '' then
    begin
      sl := TStringList.Create;
      try
        sl.Text := source;
        sl.SaveToFile(FOutputPPO);
      finally
        sl.Free;
      end;
    end
    else if FGeneratePPO then
    begin
      sl := TStringList.Create;
      try
        sl.Text := source;
        sl.SaveToFile(ChangeFileExt(AFileName, '.ppo'));
      finally
        sl.Free;
      end;
    end;
  finally
    ppo.Free;
  end;

  reporter := TErrorReporter.Create(AFileName);
  lexer := TFXBLexer.Create;
  lexer.LegacyMode := FLegacyMode;
  lexer.StrictMode := FStrictMode;
  lexer.DBAnsiMode := FDBAnsi;
  if not lexer.Tokenize(source, AFileName) then
  begin
    WriteLn(StdErr, 'Lexer errors:');
    for err in lexer.Errors do
      WriteLn(StdErr, '  ', err.ToString);
    lexer.Free;
    reporter.Free;
    Exit;
  end;

  parser := TParser.Create(lexer, reporter);
  try
    ast := parser.ParseProgram;
    if reporter.HasErrors then
    begin
      WriteLn(StdErr, 'Parser errors:');
      reporter.PrintAll;
      Exit;
    end;
  finally
    parser.Free;
    lexer.Free;
    reporter.Free;
  end;

  if FDumpAST then
    DumpAST(ast);

  // If only dumping AST, don't continue to IR/Backend
  if FDumpAST and not FDumpIR and not FDumpASM then
  begin
    Result := True;
    Exit;
  end;

  irGen := TFXBIRGenerator.Create;
  try
    irGen.TargetOS := FTargetOS;
    irGen.TargetCPU := FTargetCPU;
    irGen.OptimizationLevel := FOptimization;
    irGen.DebugInfo := FDebug;
    ir := irGen.Generate(ast);
    if irGen.HasErrors then
    begin
      WriteLn(StdErr, 'IR generation errors:');
      for msg in irGen.Errors do
        WriteLn(StdErr, '  ', DumpMessage(msg));
      Exit;
    end;
  finally
    irGen.Free;
  end;

  if FDumpIR then
  begin
    DumpIR(ir);
  end;

  backend := TFXBBackend.Create;
  try
    backend.TargetOS := FTargetOS;
    backend.TargetCPU := FTargetCPU;
    backend.OutputType := FOutputType;
    backend.OptimizationLevel := FOptimization;
    backend.DebugInfo := FDebug;
    backend.DBDriver := FDBDriver;
    backend.DBConnection := FDBConnection;
    // Generate assembly to temp file
    asmFile := outputFile + '.s';
    if not backend.Generate(ir, asmFile) then
    begin
      WriteLn(StdErr, 'Backend errors:');
      for msg in backend.Errors do
        WriteLn(StdErr, '  ', DumpMessage(msg));
      Exit;
    end;
    // Assemble and link
    if not AssembleAndLink(asmFile, outputFile) then
    begin
      WriteLn(StdErr, 'Assembly/Link failed');
      Exit;
    end;
  finally
    backend.Free;
  end;

  if FDumpASM then
    begin
      sl := TStringList.Create;
      try
        sl.LoadFromFile(asmFile);
        DumpASM(sl.Text);
      finally
        sl.Free;
      end;
    end;

  if FVerbose then
    WriteLn('Output: ', outputFile);

  Result := True;
end;

function TFXCLI.DetermineOutputFile(const AInputFile: string): string;
begin
  if FOutputFile <> '' then
    Result := FOutputFile
  else
  begin
    Result := ChangeFileExt(AInputFile, '');
    if FOutputType = 'exe' then
      Result := Result + '.exe'
    else if FOutputType = 'dll' then
      Result := Result + '.dll'
    else if FOutputType = 'so' then
      Result := Result + '.so'
    else if FOutputType = 'lib' then
      Result := Result + '.lib'
    else if FOutputType = 'a' then
      Result := Result + '.a'
    else
      Result := Result + '.exe';
  end;
end;

function TFXCLI.AssembleAndLink(const AsmFile, OutputFile: string): Boolean;
var
  exitCode: Integer;
  NeedSQLite: Boolean;
  LinkFlag: string;
begin
  Result := False;
  // Assemble
  if FVerbose then
    WriteLn('Assembling: /usr/bin/as -o ', ChangeFileExt(OutputFile, '.o'), ' ', AsmFile);
  if FTargetCPU = 'x86' then
    exitCode := ExecuteProcess('/usr/bin/as', Format('--32 -o %s.o %s', [ChangeFileExt(OutputFile, ''), AsmFile]))
  else
    exitCode := ExecuteProcess('/usr/bin/as', Format('-o %s.o %s', [ChangeFileExt(OutputFile, ''), AsmFile]));
  if exitCode <> 0 then
  begin
    WriteLn(StdErr, 'Assembly failed with code: ', exitCode);
    Exit;
  end;

  // Link
  // Fase 2: when targeting SQLite, link the runtime against libsqlite3.
  // On Linux we point the linker at our local symlink (lib/libsqlite3.so).
  NeedSQLite := (FDBDriver = 'sqlite') or (FDBConnection <> '');
  if NeedSQLite then
  begin
    if FTargetOS = 'windows' then
      LinkFlag := ' -lsqlite3'
    else
      LinkFlag := ' -Llib -lsqlite3';
  end
  else
    LinkFlag := '';
  if FTargetOS = 'windows' then
  begin
    // Cross-compile to PE via the MinGW toolchain. The gcc driver emits COFF and
    // links msvcrt + the CRT (which provides the real entry and calls our `main`).
    if FTargetCPU = 'x86' then
      exitCode := ExecuteProcess('/usr/bin/i686-w64-mingw32-gcc', Format('-mconsole -o %s %s -static%s', [OutputFile, AsmFile, LinkFlag]))
    else
      exitCode := ExecuteProcess('/usr/bin/x86_64-w64-mingw32-gcc', Format('-o %s %s -static%s', [OutputFile, AsmFile, LinkFlag]));
  end
  else if FTargetCPU = 'x86' then
    exitCode := ExecuteProcess('/usr/bin/ld', Format('-m elf_i386 -o %s %s.o -lc -dynamic-linker /lib/ld-linux.so.2 -e _start%s', [OutputFile, ChangeFileExt(OutputFile, ''), LinkFlag]))
  else
    exitCode := ExecuteProcess('/usr/bin/ld', Format('-o %s %s.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 -e _start%s', [OutputFile, ChangeFileExt(OutputFile, ''), LinkFlag]));
  if exitCode <> 0 then
  begin
    WriteLn(StdErr, 'Link failed with code: ', exitCode);
    Exit;
  end;

  // Clean up object file
  DeleteFile(ChangeFileExt(OutputFile, '.o'));
  Result := True;
end;

procedure TFXCLI.RunExecutable;
var
  outputFile: string;
  exitCode: Integer;
begin
  outputFile := DetermineOutputFile(FInputFile);
  if not FileExists(outputFile) then
  begin
    WriteLn(StdErr, 'Error: executable not found: ', outputFile);
    Exit;
  end;

  if FVerbose then
    WriteLn('Running: ', outputFile);

  exitCode := ExecuteProcess(outputFile, FArgs.CommaText);
  if exitCode <> 0 then
    WriteLn(StdErr, 'Program exited with code: ', exitCode);
end;

procedure TFXCLI.RunTests;
begin
  WriteLn('Running FXBASE tests...');
  WriteLn('Test runner not yet implemented');
end;

procedure TFXCLI.LintFile;
var
  lexer: TFXBLexer;
  reporter: TErrorReporter;
  parser: TParser;
  ast: TCompilationUnit;
  source: string;
  err2: TFXBLexerError;
  sl: TStringList;
  line: string;
begin
  if not FileExists(FInputFile) then
  begin
    WriteLn(StdErr, 'Error: file not found: ', FInputFile);
    Exit;
  end;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(FInputFile);
    source := '';
    for line in sl do
      source := source + line + LineEnding;
  finally
    sl.Free;
  end;

  lexer := TFXBLexer.Create;
  lexer.LegacyMode := FLegacyMode;
  lexer.StrictMode := FStrictMode;
  lexer.DBAnsiMode := FDBAnsi;
  if not lexer.Tokenize(source, FInputFile) then
  begin
    WriteLn(StdErr, 'Lexer errors:');
    for err2 in lexer.Errors do
      WriteLn(StdErr, '  ', err2.ToString);
    lexer.Free;
    Exit;
  end;

  reporter := TErrorReporter.Create(FInputFile);
  parser := TParser.Create(lexer, reporter);
  try
    ast := parser.ParseProgram;
    if reporter.HasErrors then
    begin
      WriteLn(StdErr, 'Lint errors:');
      reporter.PrintAll;
    end
    else
      WriteLn('Lint passed: ', FInputFile);
  finally
    parser.Free;
    lexer.Free;
    reporter.Free;
  end;
end;

procedure TFXCLI.DumpAST(const AAST: TCompilationUnit);
begin
  WriteLn(AAST.Dump);
end;

procedure TFXCLI.DumpIR(const AIR: TIRModule);
begin
  WriteLn(AIR.Dump);
end;

procedure TFXCLI.DumpASM(const AASM: string);
begin
  WriteLn(AASM);
end;

procedure RunFXCLI;
begin
  TFXCLI.RunClass;
end;

end.
