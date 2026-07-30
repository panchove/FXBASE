program test_implementation;

{$mode delphi}{$H+}

uses
  SysUtils, Classes,
  fpx.tokens, fpx.lexer, fpx.parser, fpx.ast, fpx.errors,
  fpx.test.framework;

type
  TLoadResult = record
    LexOK: Boolean;
    HasErrors: Boolean;
    Tokens: TTokenArray;
    Errors: TFPXLexerErrors;
  end;

function LoadAndLex(const APath: string): TLoadResult;
var
  lex: TFPXLexer;
  src: TStringList;
begin
  Result.LexOK := False;
  Result.HasErrors := False;
  Result.Tokens := nil;
  Result.Errors := nil;

  src := TStringList.Create;
  lex := TFPXLexer.Create;
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
  lex: TFPXLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  src := TStringList.Create;
  lex := TFPXLexer.Create;
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
// Programa FPXBASE completo con generics, INTERFACE, nil-safe
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
  lex: TFPXLexer;
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
  lex := TFPXLexer.Create;
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
  RunAllTests('IMPLEMENTATION TESTS — fixtures reales');
end.
