// fxb.cli.driver.inc -- CLI build pipeline + dumps + run (Run/CompileFile/
// AssembleAndLink/RunExecutable/RunTests/LintFile/Dump*).
// Included into fxb.cli.pas via {$I}. NOT a standalone unit.
// The file must NOT end with a unit terminator: fxb.cli.pas supplies the
// final `end.` after the include.

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

  if (FInputFile = '') and (FSourceFiles.Count = 0) then
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

  // Two-pass compilation for multiple files
  if FTwoPass then
  begin
    if not CompileTwoPass then
      Halt(1);
    Exit;
  end;

  // Single file compilation (original behavior)
  if not CompileFile(FInputFile) then
    Halt(1);

  if FRunAfterBuild and (FOutputType = 'exe') then
    RunExecutable;
end;

function TFXCLI.CompileTwoPass: Boolean;
var
  compiler: TFXBTwoPassCompiler;
  i: Integer;
begin
  Result := False;

  compiler := TFXBTwoPassCompiler.Create(FIncludePaths, FDefines,
    FTargetOS, FTargetCPU, FOptimization, FDebug, '', FJobs, FCacheDir);
  try
    compiler.OutputFile := DetermineOutputFile(FSourceFiles[0]);
    compiler.OutputDir := ExtractFilePath(compiler.OutputFile);
    compiler.NeedSQLite := (FDBDriver = 'sqlite') or (FDBConnection <> '');
    compiler.DBDriver := FDBDriver;
    compiler.DBConnection := FDBConnection;
    compiler.Verbose := FVerbose;
    for i := 0 to FSourceFiles.Count - 1 do
      compiler.AddFile(FSourceFiles[i]);

    if not compiler.CompileAll then
      Exit;

    // Two-pass mode builds a linked executable from all units.
    if not compiler.LinkAll then
      Exit;
  finally
    compiler.Free;
  end;

  if FRunAfterBuild and (FOutputType = 'exe') then
    RunExecutable;

  Result := True;
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
    ast.Free;
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
    DumpIR(ir);

  // R2: instantiate the architecture-specific backend subclass.
  if FTargetCPU = 'x86' then
    backend := TFXBBackendX86_32.Create
  else
    backend := TFXBBackendX86_64.Create;
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

  ast.Free;

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
    exitCode := RunProcess('/usr/bin/as', Format('--32 -o %s.o %s', [ChangeFileExt(OutputFile, ''), AsmFile]))
  else
    exitCode := RunProcess('/usr/bin/as', Format('-o %s.o %s', [ChangeFileExt(OutputFile, ''), AsmFile]));
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
      exitCode := RunProcess('/usr/bin/i686-w64-mingw32-gcc', Format('-mconsole -o %s %s -static%s', [OutputFile, AsmFile, LinkFlag]))
    else
      exitCode := RunProcess('/usr/bin/x86_64-w64-mingw32-gcc', Format('-o %s %s -static%s', [OutputFile, AsmFile, LinkFlag]));
  end
  else if FTargetCPU = 'x86' then
    exitCode := RunProcess('/usr/bin/ld', Format('-m elf_i386 -o %s %s.o -lc -dynamic-linker /lib/ld-linux.so.2 -e _start%s', [OutputFile, ChangeFileExt(OutputFile, ''), LinkFlag]))
  else
    exitCode := RunProcess('/usr/bin/ld', Format('-o %s %s.o -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 -e _start%s', [OutputFile, ChangeFileExt(OutputFile, ''), LinkFlag]));
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

  exitCode := RunProcess(outputFile, FArgs.CommaText);
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
    parser.ParseProgram;
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

procedure RunFXCLI;
begin
  TFXCLI.RunClass;
end;
