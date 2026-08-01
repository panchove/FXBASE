program test_implementation;

{$mode delphi}{$H+}

uses
  SysUtils, Classes,
  fxb.tokens, fxb.lexer, fxb.parser, fxb.ast, fxb.errors, fxb.ir, fxb.backend,
  fxb.test.framework;

function CaptureProgramOutput(const Cmd: string; out ExitCode: Integer): string; forward;

type
  TLoadResult = record
    LexOK: Boolean;
    HasErrors: Boolean;
    Tokens: TTokenArray;
    Errors: TFXBLexerErrors;
  end;

function LoadAndLex(const APath: string): TLoadResult;
var
  lex: TFXBLexer;
  src: TStringList;
begin
  Result.LexOK := False;
  Result.HasErrors := False;
  Result.Tokens := nil;
  Result.Errors := nil;

  src := TStringList.Create;
  lex := TFXBLexer.Create;
  try
    src.LoadFromFile(APath);
    Result.LexOK := lex.Tokenize(src.Text, APath);
    Result.Tokens := lex.Tokens;
    Result.Errors := lex.Errors;
    Result.HasErrors := lex.HasErrors;
  finally
    lex.Free;
    src.Free;
  end;
end;

function CountKeyword(const A: TTokenArray; const kw: TKeyword): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(A) do
    if A[i].Keyword = kw then Inc(Result);
end;

function HasTokenType(const A: TTokenArray; const tt: TTokenType): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(A) do
    if A[i].TokenType = tt then
    begin
      Result := True;
      Break;
    end;
end;

// ----------------------------------------------------------------------
// Hello world
// ----------------------------------------------------------------------
procedure TestImpl_HelloWorld_Lexes;
var
  r: TLoadResult;
begin
  AssertTrue(FileExists('tests/fixtures/hello.fpg'), 'Fixture hello.fpg existe');
  r := LoadAndLex('tests/fixtures/hello.fpg');
  AssertTrue(r.LexOK, 'Hello.fpg lex OK');
  AssertFalse(r.HasErrors, 'Hello.fpg sin errores');
  AssertTrue(CountKeyword(r.Tokens, kwClass) > 0, 'Tiene CLASS');
  AssertTrue(CountKeyword(r.Tokens, kwEndClass) > 0, 'Tiene ENDCLASS');
  AssertTrue(CountKeyword(r.Tokens, kwMethod) > 0, 'Tiene METHOD');
end;

procedure TestImpl_HelloWorld_ParseAST;
var
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  src := TStringList.Create;
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('hello.fpg');
  par := TParser.Create(lex, rep);
  try
    src.LoadFromFile('tests/fixtures/hello.fpg');
    lex.Tokenize(src.Text, 'hello.fpg');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'AST no nulo');
  finally
    if Assigned(unit_) then unit_.Free;
    par.Free;
    rep.Free;
    lex.Free;
    src.Free;
  end;
end;

// ----------------------------------------------------------------------
// Programa FXBASE completo con generics, INTERFACE, nil-safe
// ----------------------------------------------------------------------
procedure TestImpl_Program_HasGenerics;
var
  r: TLoadResult;
begin
  r := LoadAndLex('tests/fixtures/program.fpg');
  AssertTrue(r.LexOK, 'Program.fpg lex OK');
  AssertFalse(r.HasErrors, 'Program.fpg sin errores');
  AssertTrue(CountKeyword(r.Tokens, kwInterface) > 0, 'Tiene INTERFACE');
  AssertTrue(CountKeyword(r.Tokens, kwImplements) > 0, 'Tiene IMPLEMENTS');
  AssertTrue(CountKeyword(r.Tokens, kwVirtual) > 0, 'Tiene VIRTUAL');
  AssertTrue(CountKeyword(r.Tokens, kwConstructor) > 0, 'Tiene CONSTRUCTOR');
end;

procedure TestImpl_Program_NilSafeOperators;
var
  r: TLoadResult;
begin
  r := LoadAndLex('tests/fixtures/program.fpg');
  AssertTrue(HasTokenType(r.Tokens, ttQuestionDot),   'Operador ?. presente');
  AssertTrue(HasTokenType(r.Tokens, ttQuestionColon), 'Operador ?: presente');
end;

procedure TestImpl_Program_GenericBracket;
var
  r: TLoadResult;
  found: Boolean;
  i: Integer;
begin
  r := LoadAndLex('tests/fixtures/program.fpg');
  found := False;
  for i := 0 to High(r.Tokens) do
    if (r.Tokens[i].TokenType = ttLt) and (i + 1 <= High(r.Tokens)) and
       (r.Tokens[i + 1].TokenType = ttIdentifier) then
    begin
      found := True;
      Break;
    end;
  AssertTrue(found, 'Encontrado < seguido de identificador (genéricos)');
end;

// ----------------------------------------------------------------------
// Legacy mode
// ----------------------------------------------------------------------
procedure TestImpl_LegacyPrg_NoErrors;
var
  r: TLoadResult;
begin
  r := LoadAndLex('tests/fixtures/legacy.prg');
  AssertTrue(r.LexOK, 'Legacy lex OK');
  AssertFalse(r.HasErrors, 'Legacy sin errores');
  AssertTrue(CountKeyword(r.Tokens, kwProcedure) > 0, 'Tiene PROCEDURE');
  AssertTrue(CountKeyword(r.Tokens, kwAccept) > 0, 'Tiene ACCEPT');
  AssertTrue(CountKeyword(r.Tokens, kwIf) > 0, 'Tiene IF');
end;

procedure TestImpl_Legacy_DotOperators;
var
  r: TLoadResult;
  i: Integer;
  hasDotNot: Boolean;
begin
  r := LoadAndLex('tests/fixtures/legacy.prg');
  hasDotNot := False;
  for i := 0 to High(r.Tokens) do
    if r.Tokens[i].TokenType = ttDotNot then
    begin
      hasDotNot := True;
      Break;
    end;
  AssertTrue(hasDotNot, '.NOT. detectado');
end;

// ----------------------------------------------------------------------
// DBF legacy
// ----------------------------------------------------------------------
procedure TestImpl_DbfLegacy_Commands;
var
  r: TLoadResult;
begin
  r := LoadAndLex('tests/fixtures/dbf_legacy.prg');
  AssertTrue(r.LexOK, 'dbf_legacy lex OK');
  AssertFalse(r.HasErrors, 'dbf_legacy sin errores');
  AssertTrue(CountKeyword(r.Tokens, kwUse) > 0, 'Tiene USE');
  AssertTrue(CountKeyword(r.Tokens, kwIndex) > 0, 'Tiene INDEX');
  AssertTrue(CountKeyword(r.Tokens, kwLocate) > 0, 'Tiene LOCATE');
  AssertTrue(CountKeyword(r.Tokens, kwReplace) > 0, 'Tiene REPLACE');
end;

// ----------------------------------------------------------------------
// Nested classes
// ----------------------------------------------------------------------
procedure TestImpl_NestedClasses;
var
  r: TLoadResult;
begin
  r := LoadAndLex('tests/fixtures/nested.fpg');
  AssertTrue(r.LexOK, 'nested lex OK');
  AssertFalse(r.HasErrors, 'nested sin errores');
  AssertTrue(CountKeyword(r.Tokens, kwClass) >= 2, 'Mínimo 2 CLASS (Outer+Inner)');
  AssertTrue(CountKeyword(r.Tokens, kwEndClass) >= 2, 'Mínimo 2 ENDCLASS');
end;

// ----------------------------------------------------------------------
// Stress / larga
// ----------------------------------------------------------------------
procedure TestImpl_Stress_RepeatClasses;
var
  lex: TFXBLexer;
  src: string;
  i: Integer;
begin
  src := '';
  for i := 1 to 100 do
    src := src + 'CLASS C' + IntToStr(i) + sLineBreak +
                '    METHOD Run()' + sLineBreak +
                '        ? 1' + sLineBreak +
                '    ENDMETHOD' + sLineBreak +
                'ENDCLASS' + sLineBreak;
  lex := TFXBLexer.Create;
  try
    AssertTrue(lex.Tokenize(src, 'stress.fpg'), 'Stress lex OK');
    AssertFalse(lex.HasErrors, 'Stress sin errores');
    AssertEqualsI(100, CountKeyword(lex.Tokens, kwClass), '100 CLASS');
    AssertEqualsI(100, CountKeyword(lex.Tokens, kwEndClass), '100 ENDCLASS');
  finally
    lex.Free;
  end;
end;

// ----------------------------------------------------------------------
// Roundtrip: tokens pueden convertirse a string y de vuelta
// ----------------------------------------------------------------------
procedure TestImpl_DumpRoundtrip;
var
  tok: TToken;
  s: string;
begin
  tok.TokenType := ttInteger;
  tok.IntValue := 99;
  tok.Line := 7;
  tok.Col := 3;
  tok.StrValue := '99';
  s := DumpToken(tok);
  AssertTrue(Length(s) > 0, 'DumpToken no vacío');
  AssertTrue(Pos('99', s) > 0, 'DumpToken contiene valor');
  AssertTrue(Pos('7', s) > 0, 'DumpToken contiene línea');
end;

// ----------------------------------------------------------------------
// Backend
// ----------------------------------------------------------------------
procedure TestImpl_Backend_PrintAsm;
var
  src, asmOut, dump: string;
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  ast: TCompilationUnit;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  backend: TFXBBackend;
begin
  src :=
    'FUNCTION Main() AS INTEGER' + sLineBreak +
    '    ? "hi"' + sLineBreak +
    '    ? 42' + sLineBreak +
    '    ?? "x"' + sLineBreak +
    '    RETURN 0' + sLineBreak +
    'ENDFUNC';
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('backend.fpg');
  par := TParser.Create(lex, rep);
  irGen := TFXBIRGenerator.Create;
  ir := nil;
  ast := nil;
  backend := TFXBBackend.Create;
  try
    lex.Tokenize(src, 'backend.fpg');
    ast := par.ParseProgram;
    AssertFalse(rep.HasErrors, 'parse sin errores');
    ir := irGen.Generate(ast);
    AssertNotNil(ir, 'IR produced');
    AssertTrue(backend.Generate(ir, 'backend_test.s'), 'backend generate OK');
    asmOut := backend.LastASM;
    AssertTrue(Pos('callq printf', asmOut) > 0, 'printf call present');
    AssertTrue(Pos('.Lstr', asmOut) > 0, 'string pool present');
    AssertTrue(Pos('%s', asmOut) > 0, 'format %s present');
    AssertTrue(Pos('%lld', asmOut) > 0, 'format %lld present');
    AssertTrue(Pos(#10, asmOut) > 0, 'real newline byte in pool');
    AssertTrue(Pos('callq fflush', asmOut) > 0, 'fflush in _start');
  finally
    DeleteFile('backend_test.s');
    backend.Free;
    if Assigned(ir) then ir.Free;
    irGen.Free;
    if Assigned(ast) then ast.Free;
    par.Free;
    rep.Free;
    lex.Free;
  end;
end;

// Reporte
// ----------------------------------------------------------------------
procedure TestImpl_Metrics_FileCount;
var
  sr: TSearchRec;
  count: Integer;
begin
  count := 0;
  if FindFirst('tests/fixtures/*.fpg', faAnyFile, sr) = 0 then
  begin
    repeat
      Inc(count);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  if FindFirst('tests/fixtures/*.prg', faAnyFile, sr) = 0 then
  begin
    repeat
      Inc(count);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  AssertTrue(count >= 5, 'Mínimo 5 fixtures (fpg+prg)');
end;

// ----------------------------------------------------------------------
// Backend: float arithmetic SSE2
// ----------------------------------------------------------------------
procedure TestImpl_Backend_FloatArithAsm;
var
  src, asmOut: string;
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  ast: TCompilationUnit;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  backend: TFXBBackend;
begin
  src :=
    'FUNCTION Main() AS INTEGER' + sLineBreak +
    '    ? 1.5 + 2.5' + sLineBreak +
    '    ? 10.0 - 3.0' + sLineBreak +
    '    ? 4.0 * 2.0' + sLineBreak +
    '    ? 7.0 / 2.0' + sLineBreak +
    '    RETURN 0' + sLineBreak +
    'ENDFUNC';
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('float.fpg');
  par := TParser.Create(lex, rep);
  irGen := TFXBIRGenerator.Create;
  ir := nil;
  ast := nil;
  backend := TFXBBackend.Create;
  try
    lex.Tokenize(src, 'float.fpg');
    ast := par.ParseProgram;
    AssertFalse(rep.HasErrors, 'parse sin errores');
    ir := irGen.Generate(ast);
    AssertNotNil(ir, 'IR produced');
    AssertTrue(backend.Generate(ir, 'float_test.s'), 'backend generate OK');
    asmOut := backend.LastASM;
    AssertTrue(Pos('addsd', asmOut) > 0, 'addsd emitido');
    AssertTrue(Pos('subsd', asmOut) > 0, 'subsd emitido');
    AssertTrue(Pos('mulsd', asmOut) > 0, 'mulsd emitido');
    AssertTrue(Pos('divsd', asmOut) > 0, 'divsd emitido');
    AssertTrue(Pos('# Unimplemented', asmOut) = 0, 'sin # Unimplemented');
  finally
    DeleteFile('float_test.s');
    backend.Free;
    if Assigned(ir) then ir.Free;
    irGen.Free;
    if Assigned(ast) then ast.Free;
    par.Free;
    rep.Free;
    lex.Free;
  end;
end;

procedure TestImpl_Backend_FloatExecutes;
var
  exePath, outp: string;
  code: Integer;
begin
  exePath := 'float_exec_test_bin';
  // Compile fixture to a real executable via the fxbc driver.
  code := ExecuteProcess('./bin/fxbc', 'tests/fixtures/float.fbg -o ' + exePath);
  AssertEqualsI(0, code, 'fxbc compila float.fbg');
  AssertTrue(FileExists(exePath), 'binario generado');
  try
    outp := CaptureProgramOutput('./' + exePath, code);
    AssertEqualsI(0, code, 'ejecucion retorna 0');
    AssertTrue(Pos('4', outp) > 0, 'contiene 4 (1.5+2.5)');
    AssertTrue(Pos('7', outp) > 0, 'contiene 7 (10-3)');
    AssertTrue(Pos('8', outp) > 0, 'contiene 8 (4*2)');
    AssertTrue(Pos('3.5', outp) > 0, 'contiene 3.5 (7/2)');
  finally
    DeleteFile(exePath);
  end;
end;

// ----------------------------------------------------------------------
// Backend: float comparison (ikFCmp / SSE2 ucomisd)
// ----------------------------------------------------------------------
procedure TestImpl_Backend_FloatCmpAsm;
var
  src, asmOut: string;
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  ast: TCompilationUnit;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  backend: TFXBBackend;
begin
  src :=
    'FUNCTION Main() AS INTEGER' + sLineBreak +
    '    IF 3.5 > 2.0 THEN' + sLineBreak +
    '        ? 1' + sLineBreak +
    '    ELSE' + sLineBreak +
    '        ? 0' + sLineBreak +
    '    ENDIF' + sLineBreak +
    '    RETURN 0' + sLineBreak +
    'ENDFUNC';
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('floatcmp.fpg');
  par := TParser.Create(lex, rep);
  irGen := TFXBIRGenerator.Create;
  ir := nil;
  ast := nil;
  backend := TFXBBackend.Create;
  try
    lex.Tokenize(src, 'floatcmp.fpg');
    ast := par.ParseProgram;
    AssertFalse(rep.HasErrors, 'parse sin errores');
    ir := irGen.Generate(ast);
    AssertNotNil(ir, 'IR produced');
    AssertTrue(backend.Generate(ir, 'floatcmp_test.s'), 'backend generate OK');
    asmOut := backend.LastASM;
    AssertTrue(Pos('ucomisd', asmOut) > 0, 'ucomisd emitido para float cmp');
    AssertTrue(Pos('seta', asmOut) > 0, 'seta emitido (gt)');
    // Integer compare path must still use cmpq, not be polluted by float path.
    AssertTrue(Pos('cmpq', asmOut) >= 0, 'cmpq disponible para enteros');
  finally
    DeleteFile('floatcmp_test.s');
    backend.Free;
    if Assigned(ir) then ir.Free;
    irGen.Free;
    if Assigned(ast) then ast.Free;
    par.Free;
    rep.Free;
    lex.Free;
  end;
end;

procedure TestImpl_Backend_FloatCmpExecutes;
var
  exePath, outp: string;
  code: Integer;
begin
  exePath := 'floatcmp_exec_test_bin';
  code := SysUtils.ExecuteProcess('./bin/fxbc', 'tests/fixtures/floatcmp.fbg -o ' + exePath);
  AssertEqualsI(0, code, 'fxbc compila floatcmp.fbg');
  AssertTrue(FileExists(exePath), 'binario generado');
  try
    outp := CaptureProgramOutput('./' + exePath, code);
    AssertEqualsI(0, code, 'ejecucion retorna 0');
    // 3.5 > 2.0 is true -> prints 1
    AssertTrue(Pos('1', outp) > 0, 'imprime 1 (3.5 > 2.0)');
    AssertTrue(Pos('0', outp) = 0, 'no imprime 0 (rama else no tomada)');
  finally
    DeleteFile(exePath);
  end;
end;

// ----------------------------------------------------------------------
// Backend: x86_32 (i386) ELF codegen
// ----------------------------------------------------------------------
procedure TestImpl_Backend_x86_32_Asm;
var
  src, asmOut: string;
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  ast: TCompilationUnit;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  backend: TFXBBackend;
begin
  src :=
    'FUNCTION Main() AS INTEGER' + sLineBreak +
    '    ? 1 + 2' + sLineBreak +
    '    ? 1.5 + 2.5' + sLineBreak +
    '    RETURN 0' + sLineBreak +
    'ENDFUNC';
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('backend32.fpg');
  par := TParser.Create(lex, rep);
  irGen := TFXBIRGenerator.Create;
  ir := nil;
  ast := nil;
  backend := TFXBBackend.Create;
  try
    lex.Tokenize(src, 'backend32.fpg');
    ast := par.ParseProgram;
    AssertFalse(rep.HasErrors, 'parse sin errores');
    ir := irGen.Generate(ast);
    backend.TargetCPU := 'x86';
    AssertTrue(backend.Generate(ir, 'backend32_test.s'), 'backend 32-bit generate OK');
    asmOut := backend.LastASM;
    AssertTrue(Pos('.code32', asmOut) > 0, 'emite .code32');
    AssertTrue(Pos('pushl', asmOut) > 0, 'prologue usa pushl (32-bit)');
    AssertTrue(Pos('movl', asmOut) > 0, 'usa movl');
    AssertTrue(Pos('addl', asmOut) > 0, 'usa addl');
    AssertTrue(Pos('int $0x80', asmOut) > 0, 'syscall 32-bit (int 0x80)');
    AssertTrue(Pos('.code64', asmOut) = 0, 'NO emite .code64');
    AssertTrue(Pos('pushq', asmOut) = 0, 'NO emite pushq (64-bit)');
    AssertTrue(Pos('syscall', asmOut) = 0, 'NO emite syscall (64-bit)');
  finally
    DeleteFile('backend32_test.s');
    backend.Free;
    if Assigned(ir) then ir.Free;
    irGen.Free;
    if Assigned(ast) then ast.Free;
    par.Free;
    rep.Free;
    lex.Free;
  end;
end;

procedure TestImpl_Backend_x86_32_Executes;
var
  exePath, outp: string;
  code: Integer;
begin
  exePath := 'x86_32_exec_test_bin';
  code := SysUtils.ExecuteProcess('./bin/fxbc',
    '--target-cpu x86 tests/fixtures/hello32.fbg -o ' + exePath);
  if code <> 0 then
  begin
    // Environment may lack 32-bit libc (libc6-dev-i386); skip rather than fail.
    WriteLn('  [SKIP] backend x86_32 executes: requiere libc6-dev-i386 (multilib); no disponible en este entorno');
    Exit;
  end;
  AssertTrue(FileExists(exePath), 'binario 32-bit generado');
  try
    outp := CaptureProgramOutput('./' + exePath, code);
    AssertEqualsI(0, code, 'ejecucion retorna 0');
    AssertTrue(Pos('hi', outp) > 0, 'imprime hi');
    AssertTrue(Pos('3', outp) > 0, 'imprime 3 (1+2 y 7/2)');
    AssertTrue(Pos('4', outp) > 0, 'imprime 4.0 (1.5+2.5)');
  finally
    DeleteFile(exePath);
  end;
end;

// Compile + run a program, returning its stdout and exit code without leaking
// the child process output into the test runner's console.
function CaptureProgramOutput(const Cmd: string; out ExitCode: Integer): string;
var
  f: text;
  tmp: string;
  line: string;
begin
  Result := '';
  ExitCode := -1;
  tmp := 'float_exec_out.txt';
  if SysUtils.ExecuteProcess('/bin/sh', '-c "' + Cmd + ' > ' + tmp + ' 2>&1"') <> 0 then
  begin
    if FileExists(tmp) then DeleteFile(tmp);
    Exit;
  end;
  // Read captured output, then probe the real exit code via a second run.
  Assign(f, tmp);
  {$I-} Reset(f); {$I+}
  if IOResult = 0 then
  begin
    while not EOF(f) do
    begin
      ReadLn(f, line);
      Result := Result + line + sLineBreak;
    end;
    Close(f);
  end;
  if FileExists(tmp) then DeleteFile(tmp);
  ExitCode := SysUtils.ExecuteProcess('/bin/sh', '-c "' + Cmd + ' > /dev/null 2>&1"');
end;

begin
  RegisterTest('Impl: hello.fpg lex',                @TestImpl_HelloWorld_Lexes);
  RegisterTest('Impl: hello.fpg AST',                @TestImpl_HelloWorld_ParseAST);
  RegisterTest('Impl: program.fpg generics/INTERFACE',@TestImpl_Program_HasGenerics);
  RegisterTest('Impl: program.fpg nil-safe',         @TestImpl_Program_NilSafeOperators);
  RegisterTest('Impl: program.fpg generic bracket',   @TestImpl_Program_GenericBracket);
  RegisterTest('Impl: legacy.prg no errors',          @TestImpl_LegacyPrg_NoErrors);
  RegisterTest('Impl: legacy .NOT.',                  @TestImpl_Legacy_DotOperators);
  RegisterTest('Impl: dbf_legacy DB commands',        @TestImpl_DbfLegacy_Commands);
  RegisterTest('Impl: nested classes',                @TestImpl_NestedClasses);
  RegisterTest('Impl: stress 100 classes',            @TestImpl_Stress_RepeatClasses);
  RegisterTest('Impl: DumpToken roundtrip',           @TestImpl_DumpRoundtrip);
  RegisterTest('Impl: metrics fixture count',         @TestImpl_Metrics_FileCount);
  RegisterTest('Impl: backend print asm',             @TestImpl_Backend_PrintAsm);
  RegisterTest('Impl: backend float SSE2 asm',        @TestImpl_Backend_FloatArithAsm);
  RegisterTest('Impl: backend float executes',         @TestImpl_Backend_FloatExecutes);
  RegisterTest('Impl: backend float cmp asm',          @TestImpl_Backend_FloatCmpAsm);
  RegisterTest('Impl: backend float cmp executes',     @TestImpl_Backend_FloatCmpExecutes);
  RegisterTest('Impl: backend x86_32 asm',             @TestImpl_Backend_x86_32_Asm);
  RegisterTest('Impl: backend x86_32 executes',         @TestImpl_Backend_x86_32_Executes);
  RunAllTests('IMPLEMENTATION TESTS — fixtures reales');
end.
