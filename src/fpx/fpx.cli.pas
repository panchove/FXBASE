unit fpx.cli;

{$mode delphi}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes,
  fpx.tokens,
  fpx.lexer,
  fpx.parser,
  fpx.ast,
  fpx.errors,
  fpx.ir,
  fpx.backend,
  fpx.ppo;

type
  TFPXCLI = class
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

procedure RunFPXCLI;

implementation

constructor TFPXCLI.Create;
begin
  inherited Create;
  FArgs := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FDefines := TStringList.Create;
  SetDefaults;
end;

destructor TFPXCLI.Destroy;
begin
  FArgs.Free;
  FIncludePaths.Free;
  FDefines.Free;
  inherited Destroy;
end;

procedure TFPXCLI.SetDefaults;
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

procedure TFPXCLI.ParseArgs;
var
  i: Integer;
  arg: string;
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

procedure TFPXCLI.ShowHelp;
begin
  WriteLn('FPXBASE Compiler (fpx) - Modern xBASE Compiler');
  WriteLn('Usage: fpx [options] <input.prg|.fpg> [args...]');
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
  WriteLn('  .fpg  - FPXBASE source (modern extensions)');
  WriteLn('  .fph  - Header file (like .ch)');
  WriteLn('  .ppo  - Preprocessor output');
  WriteLn('');
  WriteLn('Examples:');
  WriteLn('  fpx hello.prg                    # Compile to hello.exe');
  WriteLn('  fpx -o myapp.exe main.fpg        # Compile to myapp.exe');
  WriteLn('  fpx --target win64 app.prg       # Cross-compile to Windows x64');
  WriteLn('  fpx --target-os linux --target-cpu arm64 app.prg');
  WriteLn('  fpx --db-driver postgres --db-connection "host=localhost dbname=mydb" app.prg');
  WriteLn('  fpx --legacy --db-ansi legacy.prg # Legacy Clipper mode');
  WriteLn('  fpx --dump-ast hello.prg         # Dump AST');
  WriteLn('  fpx --lint hello.prg             # Lint only');
  WriteLn('');
  WriteLn('FPXBASE - Modern xBASE Compiler - MIT License');
end;

procedure TFPXCLI.ShowVersion;
begin
  WriteLn('FPXBASE Compiler (fpx) 0.1.0-dev');
  WriteLn('Target: ', FTargetOS, '-', FTargetCPU);
  WriteLn('License: MIT');
end;

procedure TFPXCLI.Run;
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
    Halt(1);

  if FRunAfterBuild and (FOutputType = 'exe') then
    RunExecutable;
end;

class procedure TFPXCLI.RunClass;
var
  cli: TFPXCLI;
begin
  cli := TFPXCLI.Create;
  try
    cli.Run;
  finally
    cli.Free;
  end;
end;

function TFPXCLI.CompileFile(const AFileName: string): Boolean;
var
  lexer: TFPXLexer;
  reporter: TErrorReporter;
  parser: TParser;
  ast: TCompilationUnit;
  irGen: TFPXIRGenerator;
  ir: TIRModule;
  backend: TFPXBackend;
  ppo: TFPXPPO;
  source: string;
  outputFile: string;
  sl: TStringList;
  line: string;
  err: TFPXLexerError;
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

  ppo := TFPXPPO.Create;
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
  lexer := TFPXLexer.Create;
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

  irGen := TFPXIRGenerator.Create;
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
    DumpIR(ir);

  backend := TFPXBackend.Create;
  try
    backend.TargetOS := FTargetOS;
    backend.TargetCPU := FTargetCPU;
    backend.OutputType := FOutputType;
    backend.OptimizationLevel := FOptimization;
    backend.DebugInfo := FDebug;
    backend.DBDriver := FDBDriver;
    backend.DBConnection := FDBConnection;
    outputFile := DetermineOutputFile(AFileName);
    if not backend.Generate(ir, outputFile) then
    begin
      WriteLn(StdErr, 'Backend errors:');
      for msg in backend.Errors do
        WriteLn(StdErr, '  ', DumpMessage(msg));
      Exit;
    end;
  finally
    backend.Free;
  end;

  if FDumpASM then
    DumpASM(backend.LastASM);

  if FVerbose then
    WriteLn('Output: ', outputFile);

  Result := True;
end;

function TFPXCLI.DetermineOutputFile(const AInputFile: string): string;
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

procedure TFPXCLI.RunExecutable;
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

procedure TFPXCLI.RunTests;
begin
  WriteLn('Running FPXBASE tests...');
  WriteLn('Test runner not yet implemented');
end;

procedure TFPXCLI.LintFile;
var
  lexer: TFPXLexer;
  reporter: TErrorReporter;
  parser: TParser;
  ast: TCompilationUnit;
  source: string;
  err2: TFPXLexerError;
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

  lexer := TFPXLexer.Create;
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

procedure TFPXCLI.DumpAST(const AAST: TCompilationUnit);
begin
  WriteLn(AAST.Dump);
end;

procedure TFPXCLI.DumpIR(const AIR: TIRModule);
begin
  WriteLn(AIR.Dump);
end;

procedure TFPXCLI.DumpASM(const AASM: string);
begin
  WriteLn(AASM);
end;

procedure RunFPXCLI;
begin
  TFPXCLI.RunClass;
end;

end.
