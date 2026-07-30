program test_pipeline;

{$mode delphi}{$H+}

uses
  SysUtils, Classes,
  fpx.tokens, fpx.lexer, fpx.parser, fpx.ast, fpx.errors,
  fpx.test.framework;

procedure TestPipeline_Empty;
var
  lex: TFPXLexer;
  par: TParser;
  rep: TErrorReporter;
  unit_: TCompilationUnit;
begin
  lex := TFPXLexer.Create;
  rep := TErrorReporter.Create('empty.fpg');
  par := TParser.Create(lex, rep);
  try
    AssertTrue(lex.Tokenize('', 'empty.fpg'), 'Lex empty OK');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'ParseProgram no debe retornar nil');
  finally
    if Assigned(unit_) then unit_.Free;
    par.Free;
    rep.Free;
    lex.Free;
  end;
end;

procedure TestPipeline_HelloWorldTokens;
var
  lex: TFPXLexer;
  src: string;
  hasClass: Boolean;
  hasEndClass: Boolean;
  hasMethod: Boolean;
  i: Integer;
begin
  src :=
    'CLASS HelloWorld' + sLineBreak +
    '    METHOD Run()' + sLineBreak +
    '        ? "Hello, World!"' + sLineBreak +
    '    ENDMETHOD' + sLineBreak +
    'ENDCLASS';

  lex := TFPXLexer.Create;
  try
    AssertTrue(lex.Tokenize(src, 'hello.fpg'), 'Lex hello OK');
    hasClass := False; hasEndClass := False; hasMethod := False;
    for i := 0 to High(lex.Tokens) do
    begin
      case lex.Tokens[i].Keyword of
        kwClass:    hasClass := True;
        kwEndClass: hasEndClass := True;
        kwMethod:   hasMethod := True;
      end;
    end;
    AssertTrue(hasClass, 'Token CLASS presente');
    AssertTrue(hasEndClass, 'Token ENDCLASS presente');
    AssertTrue(hasMethod, 'Token METHOD presente');
    AssertFalse(lex.HasErrors, 'Sin errores léxicos');
  finally
    lex.Free;
  end;
end;

procedure TestPipeline_ReadFixture;
var
  lex: TFPXLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  AssertTrue(FileExists('tests/fixtures/hello.fpg'), 'Fixture hello.fpg existe');
  src := TStringList.Create;
  lex := TFPXLexer.Create;
  rep := TErrorReporter.Create('hello.fpg');
  par := TParser.Create(lex, rep);
  try
    src.LoadFromFile('tests/fixtures/hello.fpg');
    AssertTrue(lex.Tokenize(src.Text, 'hello.fpg'), 'Lex fixture OK');
    AssertFalse(lex.HasErrors, 'Fixture sin errores léxicos');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'ParseProgram fixture OK');
  finally
    if Assigned(unit_) then unit_.Free;
    par.Free;
    rep.Free;
    lex.Free;
    src.Free;
  end;
end;

procedure TestPipeline_OperatorPreservation;
var
  lex: TFPXLexer;
  src: string;
  hasDoubleColon, hasQColon, hasQDot: Boolean;
  i: Integer;
begin
  src := 'obj ?: default ; obj ?.field ; SUPER::method()';
  lex := TFPXLexer.Create;
  try
    AssertTrue(lex.Tokenize(src, 'ops.fpg'), 'Lex ops OK');
    hasDoubleColon := False; hasQColon := False; hasQDot := False;
    for i := 0 to High(lex.Tokens) do
    begin
      case lex.Tokens[i].TokenType of
        ttDoubleColon:   hasDoubleColon := True;
        ttQuestionColon: hasQColon := True;
        ttQuestionDot:   hasQDot := True;
      end;
    end;
    AssertTrue(hasDoubleColon, 'Operador :: preservado');
    AssertTrue(hasQColon, 'Operador ?: preservado');
    AssertTrue(hasQDot, 'Operador ?. preservado');
  finally
    lex.Free;
  end;
end;

procedure TestPipeline_EndToEndFile;
var
  lex: TFPXLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  AssertTrue(FileExists('tests/fixtures/program.fpg'), 'Fixture program.fpg existe');
  src := TStringList.Create;
  lex := TFPXLexer.Create;
  rep := TErrorReporter.Create('program.fpg');
  par := TParser.Create(lex, rep);
  try
    src.LoadFromFile('tests/fixtures/program.fpg');
    lex.Tokenize(src.Text, 'program.fpg');
    AssertFalse(lex.HasErrors, 'Program.fpg sin errores léxicos');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'ParseProgram program.fpg OK');
  finally
    if Assigned(unit_) then unit_.Free;
    par.Free;
    rep.Free;
    lex.Free;
    src.Free;
  end;
end;

procedure TestPipeline_LegacyFixture;
var
  lex: TFPXLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  AssertTrue(FileExists('tests/fixtures/legacy.prg'), 'Fixture legacy.prg existe');
  src := TStringList.Create;
  lex := TFPXLexer.Create;
  rep := TErrorReporter.Create('legacy.prg');
  par := TParser.Create(lex, rep);
  try
    lex.LegacyMode := True;
    src.LoadFromFile('tests/fixtures/legacy.prg');
    lex.Tokenize(src.Text, 'legacy.prg');
    AssertFalse(lex.HasErrors, 'legacy.prg sin errores en LegacyMode');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'ParseProgram legacy OK');
  finally
    if Assigned(unit_) then unit_.Free;
    par.Free;
    rep.Free;
    lex.Free;
    src.Free;
  end;
end;

begin
  RegisterTest('Pipeline: empty source',          @TestPipeline_Empty);
  RegisterTest('Pipeline: HelloWorld tokens',     @TestPipeline_HelloWorldTokens);
  RegisterTest('Pipeline: read fixture hello.fpg',@TestPipeline_ReadFixture);
  RegisterTest('Pipeline: operators preservation',@TestPipeline_OperatorPreservation);
  RegisterTest('Pipeline: end-to-end program.fpg',@TestPipeline_EndToEndFile);
  RegisterTest('Pipeline: legacy.prg',            @TestPipeline_LegacyFixture);
  RunAllTests('INTEGRATION TESTS — lexer+parser pipeline');
end.
