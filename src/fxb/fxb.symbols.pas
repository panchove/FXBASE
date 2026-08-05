unit fxb.symbols;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  fxb.ast,
  fxb.ast.def,
  fxb.cache;

type
  TSymbolKind = (skFunction, skProcedure, skMethod, skClass, skStruct, skInterface, skNewType, skVariable, skConstant);

  TSymbolVisibility = (svPublic, svPrivate, svProtected, svInternal);

  TSymbol = record
    Name: string;
    Kind: TSymbolKind;
    Visibility: TSymbolVisibility;
    SourceFile: string;
    Line, Col: Integer;
    TypeName: string;
    IsStatic: Boolean;
    IsExported: Boolean;
    ParentClass: string;
    Signature: string;
  end;

  TSymbolArray = array of TSymbol;

  TSymbolTable = class
  private
    FSymbols: TSymbolArray;
    FLock: TCriticalSection;
    FSourceFiles: TStringList;

    function FindIndex(const AName: string): Integer;
    function FindMethodIndex(const AClassName, AMethodName: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    // Pass 0: Collect exported symbols from a compilation unit
    procedure CollectExports(const AAST: TCompilationUnit; const ASourceFile: string);

    // Pass 1: Resolve symbols against global table
    function ResolveSymbol(const AName: string; out ASymbol: TSymbol): Boolean;
    function ResolveMethod(const AClassName, AMethodName: string; out ASymbol: TSymbol): Boolean;
    function IsSymbolExported(const AName: string): Boolean;

    // Lookup helpers
    function GetSymbol(const AName: string): TSymbol;
    function GetMethod(const AClassName, AMethodName: string): TSymbol;
    function HasSymbol(const AName: string): Boolean;
    function HasMethod(const AClassName, AMethodName: string): Boolean;

    // File tracking
    function HasSourceFile(const AFile: string): Boolean;
    procedure AddSourceFile(const AFile: string);

    // Export/Import
    procedure MergeFrom(const AOther: TSymbolTable);
    procedure Clear;

    property Symbols: TSymbolArray read FSymbols;
  end;

  // Two-pass compilation manager
  // Pass 0: sequential scan for exported symbols.
  // Pass 1: parallel per-unit compile against the read-only symbol table,
  //         with incremental PPO/object caching.
  TFXBTwoPassCompiler = class
  private
    FGlobalSymbols: TSymbolTable;
    FSourceFiles: TStringList;
    FIncludePaths: TStringList;
    FDefines: TStringList;
    FTargetOS, FTargetCPU: string;
    FOptimization: Integer;
    FDebug: Boolean;
    FOutputDir: string;
    FOutputFile: string;
    FJobs: Integer;
    FCache: TFXBCache;
    FObjectFiles: TStringList;
    FResultsLock: TCriticalSection;
    FErrorCount: Integer;
    FNeedSQLite: Boolean;
    FDBDriver: string;
    FDBConnection: string;
    FVerbose: Boolean;
    FEntryIndex: Integer;

    function ScanForExports(const AFile: string; AIndex: Integer): Boolean;
    function IsEntryUnit(const AFile: string): Boolean;
    function ObjectFileFor(const AFile: string): string;
    function AssembleUnit(const AAsmFile, AObjectFile: string): Boolean;
    function CompileUnit(const AFile: string; const AObjectFile: string): Boolean;
    class procedure CompileJobStatic(const AData: Pointer); static;
  public
    constructor Create(const AIncludePaths, ADefines: TStringList;
      const ATargetOS, ATargetCPU: string; AOptimization: Integer; ADebug: Boolean;
      const AOutputDir: string = ''; AJobs: Integer = 0; const ACacheDir: string = '');
    destructor Destroy; override;

    procedure AddFile(const AFile: string);
    function CompileAll: Boolean;
    function LinkAll: Boolean;

    property OutputFile: string read FOutputFile write FOutputFile;
    property OutputDir: string read FOutputDir write FOutputDir;
    property NeedSQLite: Boolean read FNeedSQLite write FNeedSQLite;
    property DBDriver: string read FDBDriver write FDBDriver;
    property DBConnection: string read FDBConnection write FDBConnection;
    property Verbose: Boolean read FVerbose write FVerbose;
  end;

implementation

uses
  fxb.lexer,
  fxb.parser,
  fxb.ir,
  fxb.backend,
  fxb.backend.x86_64,
  fxb.backend.x86_32,
  fxb.ppo,
  fxb.preprocessor,
  fxb.errors,
  fxb.threadpool,
  fxb.process;

type
  PTwoPassJobData = ^TTwoPassJobData;
  TTwoPassJobData = record
    Compiler: TFXBTwoPassCompiler;
    FileIndex: Integer;
    ObjectFile: string;
    Success: Boolean;
  end;

{ TSymbolTable }

constructor TSymbolTable.Create;
begin
  inherited Create;
  FSymbols := nil;
  FLock := TCriticalSection.Create;
  FSourceFiles := TStringList.Create;
end;

destructor TSymbolTable.Destroy;
begin
  FSourceFiles.Free;
  FLock.Free;
  inherited Destroy;
end;

function TSymbolTable.FindIndex(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FSymbols) do
    if SameText(FSymbols[i].Name, AName) then
    begin
      Result := i;
      Exit;
    end;
end;

function TSymbolTable.FindMethodIndex(const AClassName, AMethodName: string): Integer;
var
  i: Integer;
  fullName: string;
begin
  Result := -1;
  fullName := AClassName + '.' + AMethodName;
  for i := 0 to High(FSymbols) do
    if (FSymbols[i].Kind = skMethod) and SameText(FSymbols[i].Name, fullName) then
    begin
      Result := i;
      Exit;
    end;
end;

procedure TSymbolTable.CollectExports(const AAST: TCompilationUnit; const ASourceFile: string);
var
  i: Integer;
  methodIdx: Integer;
  node: TASTNode;
  func: TFunctionDef;
  proc: TProcedureDef;
  classDef: TClassDef;
  structDef: TStructDef;
  interfaceDef: TInterfaceDef;
  newTypeDef: TNewTypeDef;
  method: TMethodDef;
  symbol: TSymbol;
begin
  FLock.Enter;
  try
    // Track source file
    if FSourceFiles.IndexOf(ASourceFile) < 0 then
      FSourceFiles.Add(ASourceFile);

    for i := 0 to AAST.Count - 1 do
    begin
      node := AAST.Nodes[i];

      if node is TFunctionDef then
      begin
        func := TFunctionDef(node);
        if func.IsStatic then
        begin
          symbol.Name := func.Name;
          symbol.Kind := skFunction;
          symbol.Visibility := svPublic;
          symbol.SourceFile := ASourceFile;
          symbol.Line := func.Line;
          symbol.Col := func.Col;
          symbol.TypeName := func.ReturnType;
          symbol.IsStatic := True;
          symbol.IsExported := True;
          symbol.ParentClass := '';
          // Build signature
          symbol.Signature := func.Name + '(';
          // TODO: add params
          symbol.Signature := symbol.Signature + ')';
          if func.ReturnType <> '' then
            symbol.Signature := symbol.Signature + ':' + func.ReturnType;

          SetLength(FSymbols, Length(FSymbols) + 1);
          FSymbols[High(FSymbols)] := symbol;
        end;
      end
      else if node is TProcedureDef then
      begin
        proc := TProcedureDef(node);
        symbol.Name := proc.Name;
        symbol.Kind := skProcedure;
        symbol.Visibility := svPublic;
        symbol.SourceFile := ASourceFile;
        symbol.Line := proc.Line;
        symbol.Col := proc.Col;
        symbol.TypeName := '';
        symbol.IsStatic := True;
        symbol.IsExported := True;
        symbol.ParentClass := '';
        symbol.Signature := proc.Name + '()';

        SetLength(FSymbols, Length(FSymbols) + 1);
        FSymbols[High(FSymbols)] := symbol;
      end
      else if node is TClassDef then
      begin
        classDef := TClassDef(node);

        // Class itself
        symbol.Name := classDef.Name;
        symbol.Kind := skClass;
        symbol.Visibility := svPublic;
        symbol.SourceFile := ASourceFile;
        symbol.Line := classDef.Line;
        symbol.Col := classDef.Col;
        symbol.TypeName := '';
        symbol.IsStatic := False;
        symbol.IsExported := True;
        symbol.ParentClass := '';
        symbol.Signature := '';

        SetLength(FSymbols, Length(FSymbols) + 1);
        FSymbols[High(FSymbols)] := symbol;

        // Methods
        for methodIdx := 0 to classDef.MethodCount - 1 do
        begin
          method := classDef.Methods[methodIdx];
          symbol.Name := classDef.Name + '.' + method.Name;
          symbol.Kind := skMethod;
          symbol.Visibility := svPublic;
          symbol.SourceFile := ASourceFile;
          symbol.Line := method.Line;
          symbol.Col := method.Col;
          symbol.TypeName := method.ReturnType;
          symbol.IsStatic := method.IsStatic;
          symbol.IsExported := True;
          symbol.ParentClass := classDef.Name;
          symbol.Signature := method.Name + '(';
          // TODO: add params
          symbol.Signature := symbol.Signature + ')';
          if method.ReturnType <> '' then
            symbol.Signature := symbol.Signature + ':' + method.ReturnType;

          SetLength(FSymbols, Length(FSymbols) + 1);
          FSymbols[High(FSymbols)] := symbol;
        end;
      end
      else if node is TStructDef then
      begin
        structDef := TStructDef(node);
        symbol.Name := structDef.Name;
        symbol.Kind := skStruct;
        symbol.Visibility := svPublic;
        symbol.SourceFile := ASourceFile;
        symbol.Line := structDef.Line;
        symbol.Col := structDef.Col;
        symbol.TypeName := '';
        symbol.IsStatic := False;
        symbol.IsExported := True;
        symbol.ParentClass := '';
        symbol.Signature := '';

        SetLength(FSymbols, Length(FSymbols) + 1);
        FSymbols[High(FSymbols)] := symbol;
      end
      else if node is TInterfaceDef then
      begin
        interfaceDef := TInterfaceDef(node);
        symbol.Name := interfaceDef.Name;
        symbol.Kind := skInterface;
        symbol.Visibility := svPublic;
        symbol.SourceFile := ASourceFile;
        symbol.Line := interfaceDef.Line;
        symbol.Col := interfaceDef.Col;
        symbol.TypeName := '';
        symbol.IsStatic := False;
        symbol.IsExported := True;
        symbol.ParentClass := '';
        symbol.Signature := '';

        SetLength(FSymbols, Length(FSymbols) + 1);
        FSymbols[High(FSymbols)] := symbol;
      end
      else if node is TNewTypeDef then
      begin
        newTypeDef := TNewTypeDef(node);
        symbol.Name := newTypeDef.Name;
        symbol.Kind := skNewType;
        symbol.Visibility := svPublic;
        symbol.SourceFile := ASourceFile;
        symbol.Line := newTypeDef.Line;
        symbol.Col := newTypeDef.Col;
        symbol.TypeName := newTypeDef.BaseType;
        symbol.IsStatic := False;
        symbol.IsExported := True;
        symbol.ParentClass := '';
        symbol.Signature := 'newtype ' + newTypeDef.BaseType;

        SetLength(FSymbols, Length(FSymbols) + 1);
        FSymbols[High(FSymbols)] := symbol;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSymbolTable.ResolveSymbol(const AName: string; out ASymbol: TSymbol): Boolean;
var
  idx: Integer;
begin
  FLock.Enter;
  try
    idx := FindIndex(AName);
    Result := idx >= 0;
    if Result then
      ASymbol := FSymbols[idx];
  finally
    FLock.Leave;
  end;
end;

function TSymbolTable.ResolveMethod(const AClassName, AMethodName: string; out ASymbol: TSymbol): Boolean;
var
  idx: Integer;
begin
  FLock.Enter;
  try
    idx := FindMethodIndex(AClassName, AMethodName);
    Result := idx >= 0;
    if Result then
      ASymbol := FSymbols[idx];
  finally
    FLock.Leave;
  end;
end;

function TSymbolTable.IsSymbolExported(const AName: string): Boolean;
var
  idx: Integer;
begin
  FLock.Enter;
  try
    idx := FindIndex(AName);
    Result := (idx >= 0) and FSymbols[idx].IsExported;
  finally
    FLock.Leave;
  end;
end;

function TSymbolTable.GetSymbol(const AName: string): TSymbol;
var
  idx: Integer;
begin
  idx := FindIndex(AName);
  if idx >= 0 then
    Result := FSymbols[idx]
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TSymbolTable.GetMethod(const AClassName, AMethodName: string): TSymbol;
var
  idx: Integer;
begin
  idx := FindMethodIndex(AClassName, AMethodName);
  if idx >= 0 then
    Result := FSymbols[idx]
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TSymbolTable.HasSymbol(const AName: string): Boolean;
var
  idx: Integer;
begin
  idx := FindIndex(AName);
  Result := idx >= 0;
end;

function TSymbolTable.HasMethod(const AClassName, AMethodName: string): Boolean;
var
  idx: Integer;
begin
  idx := FindMethodIndex(AClassName, AMethodName);
  Result := idx >= 0;
end;

function TSymbolTable.HasSourceFile(const AFile: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FSourceFiles.IndexOf(AFile) >= 0;
  finally
    FLock.Leave;
  end;
end;

procedure TSymbolTable.AddSourceFile(const AFile: string);
begin
  FLock.Enter;
  try
    if FSourceFiles.IndexOf(AFile) < 0 then
      FSourceFiles.Add(AFile);
  finally
    FLock.Leave;
  end;
end;

procedure TSymbolTable.MergeFrom(const AOther: TSymbolTable);
var
  i: Integer;
  symbol: TSymbol;
begin
  FLock.Enter;
  try
    AOther.FLock.Enter;
    try
      for i := 0 to High(AOther.FSymbols) do
      begin
        symbol := AOther.FSymbols[i];
        // Only add if not already present
        if FindIndex(symbol.Name) < 0 then
        begin
          SetLength(FSymbols, Length(FSymbols) + 1);
          FSymbols[High(FSymbols)] := symbol;
        end;
      end;

      // Merge source files
      for i := 0 to AOther.FSourceFiles.Count - 1 do
        if FSourceFiles.IndexOf(AOther.FSourceFiles[i]) < 0 then
          FSourceFiles.Add(AOther.FSourceFiles[i]);
    finally
      AOther.FLock.Leave;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSymbolTable.Clear;
begin
  FLock.Enter;
  try
    FSymbols := nil;
    FSourceFiles.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TFXBTwoPassCompiler }

constructor TFXBTwoPassCompiler.Create(const AIncludePaths, ADefines: TStringList;
  const ATargetOS, ATargetCPU: string; AOptimization: Integer; ADebug: Boolean;
  const AOutputDir: string = ''; AJobs: Integer = 0; const ACacheDir: string = '');
begin
  inherited Create;
  FGlobalSymbols := TSymbolTable.Create;
  FSourceFiles := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FDefines := TStringList.Create;
  FIncludePaths.Assign(AIncludePaths);
  FDefines.Assign(ADefines);
  FTargetOS := ATargetOS;
  FTargetCPU := ATargetCPU;
  FOptimization := AOptimization;
  FDebug := ADebug;
  FOutputDir := AOutputDir;
  FOutputFile := '';
  FJobs := AJobs;
  FObjectFiles := TStringList.Create;
  FResultsLock := TCriticalSection.Create;
  FErrorCount := 0;
  FNeedSQLite := False;
  FDBDriver := '';
  FDBConnection := '';
  FVerbose := False;
  FEntryIndex := -1;

  if ACacheDir <> '' then
    FCache := TFXBCache.Create(ACacheDir)
  else
    FCache := TFXBCache.Create('.fxbcache');
end;

destructor TFXBTwoPassCompiler.Destroy;
begin
  FCache.Free;
  FResultsLock.Free;
  FObjectFiles.Free;
  FGlobalSymbols.Free;
  FSourceFiles.Free;
  FIncludePaths.Free;
  FDefines.Free;
  inherited Destroy;
end;

procedure TFXBTwoPassCompiler.AddFile(const AFile: string);
begin
  if FSourceFiles.IndexOf(AFile) < 0 then
    FSourceFiles.Add(AFile);
end;

function TFXBTwoPassCompiler.ObjectFileFor(const AFile: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(AFile), '.o');
  if FOutputDir <> '' then
    Result := IncludeTrailingPathDelimiter(FOutputDir) + Result;
end;

function TFXBTwoPassCompiler.AssembleUnit(const AAsmFile, AObjectFile: string): Boolean;
var
  exitCode: Integer;
begin
  if FTargetCPU = 'x86' then
    exitCode := RunProcess('/usr/bin/as', Format('--32 -o %s %s', [AObjectFile, AAsmFile]))
  else
    exitCode := RunProcess('/usr/bin/as', Format('-o %s %s', [AObjectFile, AAsmFile]));
  Result := exitCode = 0;
end;

function TFXBTwoPassCompiler.ScanForExports(const AFile: string; AIndex: Integer): Boolean;
var
  source: string;
  sl: TStringList;
  line: string;
  ppo: TFXBPPO;
  processedSource: string;
  lexer: TFXBLexer;
  reporter: TErrorReporter;
  parser: TParser;
  ast: TCompilationUnit;
  err: TFXBLexerError;
  i: Integer;
begin
  Result := False;

  if not FileExists(AFile) then
  begin
    WriteLn(StdErr, 'Error: file not found: ', AFile);
    Exit;
  end;

  sl := TStringList.Create;
  try
    sl.LoadFromFile(AFile);
    source := '';
    for line in sl do
      source := source + line + LineEnding;
  finally
    sl.Free;
  end;

  // Preprocess
  ppo := TFXBPPO.Create;
  try
    ppo.IncludePaths := FIncludePaths;
    ppo.Defines := FDefines;
    ppo.IncludeStdFph := True;
    processedSource := ppo.Process(source, AFile);
  finally
    ppo.Free;
  end;

  // Lex
  reporter := TErrorReporter.Create(AFile);
  lexer := TFXBLexer.Create;
  if not lexer.Tokenize(processedSource, AFile) then
  begin
    WriteLn(StdErr, 'Lexer errors in ', AFile, ':');
    for err in lexer.Errors do
      WriteLn(StdErr, '  ', err.ToString);
    lexer.Free;
    reporter.Free;
    Exit;
  end;

  // Parse
  parser := TParser.Create(lexer, reporter);
  ast := nil;
  try
    ast := parser.ParseProgram;
    if reporter.HasErrors then
    begin
      WriteLn(StdErr, 'Parser errors in ', AFile, ':');
      reporter.PrintAll;
      Exit;
    end;
  finally
    parser.Free;
    lexer.Free;
    reporter.Free;
  end;

  // Collect exports
  FGlobalSymbols.CollectExports(ast, AFile);

  // The entry unit is the one defining Main; it owns the runtime (_start,
  // __fx_argc/argv, DB helpers).
  if FEntryIndex < 0 then
  begin
    for i := 0 to ast.Count - 1 do
      if ((ast.Nodes[i] is TFunctionDef) and (UpperCase(TFunctionDef(ast.Nodes[i]).Name) = 'MAIN'))
        or ((ast.Nodes[i] is TProcedureDef) and (UpperCase(TProcedureDef(ast.Nodes[i]).Name) = 'MAIN')) then
      begin
        FEntryIndex := AIndex;
        Break;
      end;
  end;

  ast.Free;
  Result := True;
end;

function TFXBTwoPassCompiler.IsEntryUnit(const AFile: string): Boolean;
begin
  if (FEntryIndex < 0) or (FEntryIndex >= FSourceFiles.Count) then
    Result := False
  else
    Result := SameText(AFile, FSourceFiles[FEntryIndex]);
end;

function TFXBTwoPassCompiler.CompileUnit(const AFile: string; const AObjectFile: string): Boolean;
var
  source: string;
  processed: string;
  sl: TStringList;
  line: string;
  ppo: TFXBPPO;
  lexer: TFXBLexer;
  reporter: TErrorReporter;
  parser: TParser;
  ast: TCompilationUnit;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  backend: TFXBBackend;
  asmFile: string;
  objPath: string;
  err: TFXBLexerError;
  msg: TCompilerMessage;
begin
  Result := False;
  if not FileExists(AFile) then
  begin
    WriteLn(StdErr, 'Error: file not found: ', AFile);
    Exit;
  end;

  // Object cache: skip the whole frontend + backend when unchanged.
  objPath := AObjectFile;
  if FCache.GetObject(AFile, objPath, FIncludePaths, FDefines,
    FTargetOS, FTargetCPU, FOptimization, FDebug, IsEntryUnit(AFile)) then
  begin
    FResultsLock.Enter;
    try
      FObjectFiles.Add(objPath);
    finally
      FResultsLock.Leave;
    end;
    if FVerbose then
      WriteLn('Cache hit: ', AFile);
    Result := True;
    Exit;
  end;

  ast := nil;
  ir := nil;
  try
    sl := TStringList.Create;
    try
      sl.LoadFromFile(AFile);
      source := '';
      for line in sl do
        source := source + line + LineEnding;
    finally
      sl.Free;
    end;

    // PPO cache, else preprocess and store.
    processed := '';
    if not FCache.GetPPO(AFile, processed, FIncludePaths, FDefines) then
    begin
      ppo := TFXBPPO.Create;
      try
        ppo.IncludePaths := FIncludePaths;
        ppo.Defines := FDefines;
        ppo.IncludeStdFph := True;
        processed := ppo.Process(source, AFile);
      finally
        ppo.Free;
      end;
      FCache.StorePPO(AFile, processed, FIncludePaths, FDefines);
    end;

    // Lex
    reporter := TErrorReporter.Create(AFile);
    lexer := TFXBLexer.Create;
    if not lexer.Tokenize(processed, AFile) then
    begin
      WriteLn(StdErr, 'Lexer errors in ', AFile, ':');
      for err in lexer.Errors do
        WriteLn(StdErr, '  ', err.ToString);
      lexer.Free;
      reporter.Free;
      Exit;
    end;

    // Parse
    parser := TParser.Create(lexer, reporter);
    try
      ast := parser.ParseProgram;
      if reporter.HasErrors then
      begin
        WriteLn(StdErr, 'Parser errors in ', AFile, ':');
        reporter.PrintAll;
        Exit;
      end;
    finally
      parser.Free;
      lexer.Free;
      reporter.Free;
    end;

    // IR
    irGen := TFXBIRGenerator.Create;
    try
      irGen.TargetOS := FTargetOS;
      irGen.TargetCPU := FTargetCPU;
      irGen.OptimizationLevel := FOptimization;
      irGen.DebugInfo := FDebug;
      irGen.MultiUnit := FSourceFiles.Count > 1;
    ir := irGen.Generate(ast);
    if irGen.HasErrors then
    begin
        WriteLn(StdErr, 'IR generation errors in ', AFile, ':');
        for msg in irGen.Errors do
          WriteLn(StdErr, '  ', DumpMessage(msg));
        Exit;
      end;
    finally
      irGen.Free;
    end;

    // Backend
    if FTargetCPU = 'x86' then
      backend := TFXBBackendX86_32.Create
    else
      backend := TFXBBackendX86_64.Create;
    try
      backend.TargetOS := FTargetOS;
      backend.TargetCPU := FTargetCPU;
      backend.OutputType := 'obj';
      backend.OptimizationLevel := FOptimization;
      backend.DebugInfo := FDebug;
      backend.DBDriver := FDBDriver;
      backend.DBConnection := FDBConnection;
      backend.EmitEntryPoint := IsEntryUnit(AFile);

      asmFile := AObjectFile + '.s';
      if not backend.Generate(ir, asmFile) then
      begin
        WriteLn(StdErr, 'Backend errors in ', AFile, ':');
        for msg in backend.Errors do
          WriteLn(StdErr, '  ', DumpMessage(msg));
        Exit;
      end;

      if not AssembleUnit(asmFile, AObjectFile) then
      begin
        WriteLn(StdErr, 'Assembly failed for ', AFile);
        Exit;
      end;
    finally
      backend.Free;
    end;

    // Cache the object for the next incremental build.
    FCache.StoreObject(AFile, AObjectFile, FIncludePaths, FDefines,
      FTargetOS, FTargetCPU, FOptimization, FDebug, IsEntryUnit(AFile));

    FResultsLock.Enter;
    try
      FObjectFiles.Add(AObjectFile);
    finally
      FResultsLock.Leave;
    end;

    if FVerbose then
      WriteLn('Compiled: ', AFile);
    Result := True;
  finally
    ast.Free;
    ir.Free;
  end;
end;

class procedure TFXBTwoPassCompiler.CompileJobStatic(const AData: Pointer);
var
  job: PTwoPassJobData;
begin
  job := PTwoPassJobData(AData);
  job^.Success := job^.Compiler.CompileUnit(
    job^.Compiler.FSourceFiles[job^.FileIndex], job^.ObjectFile);
  if not job^.Success then
    InterLockedIncrement(job^.Compiler.FErrorCount);
  Dispose(job);
end;

function TFXBTwoPassCompiler.CompileAll: Boolean;
var
  pool: TThreadPool;
  job: PTwoPassJobData;
  i: Integer;
begin
  Result := False;

  if FSourceFiles.Count = 0 then
  begin
    WriteLn(StdErr, 'No source files to compile');
    Exit;
  end;

  // Pass 0: sequential scan for exports.
  if FVerbose then
    WriteLn('Pass 0: Collecting exported symbols...');
  for i := 0 to FSourceFiles.Count - 1 do
  begin
    if not ScanForExports(FSourceFiles[i], i) then
    begin
      WriteLn(StdErr, 'Failed to scan exports from ', FSourceFiles[i]);
      Exit;
    end;
  end;
  WriteLn('  Collected ', Length(FGlobalSymbols.Symbols), ' symbols from ', FSourceFiles.Count, ' files');

  // First unit is the entry when no unit defines Main.
  if FEntryIndex < 0 then
    FEntryIndex := 0;

  // Pass 1: parallel per-unit compilation.
  FObjectFiles.Clear;
  FErrorCount := 0;
  pool := TThreadPool.Create(FJobs);
  try
    for i := 0 to FSourceFiles.Count - 1 do
    begin
      New(job);
      job^.Compiler := Self;
      job^.FileIndex := i;
      job^.ObjectFile := ObjectFileFor(FSourceFiles[i]);
      job^.Success := False;
      pool.QueueJob(@CompileJobStatic, job);
    end;
    pool.WaitForCompletion;
  finally
    pool.Free;
  end;

  if FErrorCount > 0 then
  begin
    WriteLn(StdErr, FErrorCount, ' unit(s) failed to compile');
    Exit;
  end;

  Result := FObjectFiles.Count = FSourceFiles.Count;
end;

function TFXBTwoPassCompiler.LinkAll: Boolean;
var
  exitCode: Integer;
  objects: string;
  linkFlag: string;
  i: Integer;
  outFile: string;
begin
  Result := False;

  if FObjectFiles.Count = 0 then
  begin
    WriteLn(StdErr, 'No object files to link');
    Exit;
  end;

  objects := '';
  for i := 0 to FObjectFiles.Count - 1 do
  begin
    if objects <> '' then
      objects := objects + ' ';
    objects := objects + FObjectFiles[i];
  end;

  outFile := FOutputFile;
  if outFile = '' then
    outFile := ChangeFileExt(FSourceFiles[0], '.exe');

  linkFlag := '';
  if FNeedSQLite then
  begin
    if FTargetOS = 'windows' then
      linkFlag := ' -lsqlite3'
    else
      linkFlag := ' -Llib -lsqlite3';
  end;

  if FTargetOS = 'windows' then
  begin
    if FTargetCPU = 'x86' then
      exitCode := RunProcess('/usr/bin/i686-w64-mingw32-gcc', Format('-mconsole -o %s %s -static%s', [outFile, objects, linkFlag]))
    else
      exitCode := RunProcess('/usr/bin/x86_64-w64-mingw32-gcc', Format('-o %s %s -static%s', [outFile, objects, linkFlag]));
  end
  else if FTargetCPU = 'x86' then
    exitCode := RunProcess('/usr/bin/ld', Format('-m elf_i386 -o %s %s -lc -dynamic-linker /lib/ld-linux.so.2 -e _start%s', [outFile, objects, linkFlag]))
  else
    exitCode := RunProcess('/usr/bin/ld', Format('-o %s %s -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 -e _start%s', [outFile, objects, linkFlag]));

  if exitCode <> 0 then
  begin
    WriteLn(StdErr, 'Link failed with code: ', exitCode);
    Exit;
  end;

  WriteLn('Linked: ', outFile);
  Result := True;
end;

end.
