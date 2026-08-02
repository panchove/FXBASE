program test_pipeline;

{$mode delphi}{$H+}

uses
  SysUtils, Classes,
  fxb.tokens, fxb.lexer, fxb.parser, fxb.ast, fxb.errors,
  fxb.test.framework;

procedure TestPipeline_Empty;
var
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  unit_: TCompilationUnit;
begin
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('empty.fpg');
  par := TParser.Create(lex, rep);
  unit_ := nil;
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
  lex: TFXBLexer;
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

  lex := TFXBLexer.Create;
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

procedure TestPipeline_ClassMethods;
var
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
  cls: TClassDef;
begin
  AssertTrue(FileExists('tests/fixtures/hello.fpg'), 'Fixture hello.fpg existe');
  src := TStringList.Create;
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('hello.fpg');
  par := TParser.Create(lex, rep);
  unit_ := nil;
  try
    src.LoadFromFile('tests/fixtures/hello.fpg');
    lex.Tokenize(src.Text, 'hello.fpg');
    AssertFalse(lex.HasErrors, 'hello.fpg sin errores léxicos');
    unit_ := par.ParseProgram;
    AssertFalse(rep.HasErrors, 'hello.fpg parsea sin errores (METHOD/ENDMETHOD)');
    AssertTrue(unit_.Count = 1, 'hello.fpg produce 1 nodo raíz');
    AssertTrue(unit_.Nodes[0] is TClassDef, 'El nodo raíz es un CLASS');
    cls := TClassDef(unit_.Nodes[0]);
    AssertEqualsI(1, cls.MethodCount, 'La clase tiene 1 método');
    AssertEquals('Run', cls.Methods[0].Name, 'El método se llama Run');
  finally
    if Assigned(unit_) then unit_.Free;
    par.Free;
    rep.Free;
    lex.Free;
    src.Free;
  end;
end;

procedure TestPipeline_ReadFixture;
var
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  AssertTrue(FileExists('tests/fixtures/hello.fpg'), 'Fixture hello.fpg existe');
  src := TStringList.Create;
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('hello.fpg');
  par := TParser.Create(lex, rep);
  unit_ := nil;
  try
    src.LoadFromFile('tests/fixtures/hello.fpg');
    AssertTrue(lex.Tokenize(src.Text, 'hello.fpg'), 'Lex fixture OK');
    AssertFalse(lex.HasErrors, 'Fixture sin errores léxicos');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'ParseProgram fixture OK');
    AssertFalse(rep.HasErrors, 'Fixture sin errores de parseo');
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
  lex: TFXBLexer;
  src: string;
  hasDoubleColon, hasQColon, hasQDot: Boolean;
  i: Integer;
begin
  src := 'obj ?: default ; obj ?.field ; SUPER::method()';
  lex := TFXBLexer.Create;
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
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
  node: TASTNode;
  i: Integer;
begin
  AssertTrue(FileExists('tests/fixtures/program.fpg'), 'Fixture program.fpg existe');
  src := TStringList.Create;
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('program.fpg');
  par := TParser.Create(lex, rep);
  unit_ := nil;
  try
    src.LoadFromFile('tests/fixtures/program.fpg');
    lex.Tokenize(src.Text, 'program.fpg');
    AssertFalse(lex.HasErrors, 'Program.fpg sin errores léxicos');
    unit_ := par.ParseProgram;
    AssertNotNil(unit_, 'ParseProgram program.fpg OK');
    AssertFalse(rep.HasErrors, 'Program.fpg sin errores de parser');
    AssertEqualsI(4, unit_.Count, 'program.fpg produce 4 nodos raíz');

    node := unit_.Nodes[0];
    AssertTrue(node is TClassDef, 'Nodo 0 es CLASS');
    AssertEquals('Stack', TClassDef(node).Name, 'Nodo 0 clase Stack');
    AssertEqualsI(1, TClassDef(node).GetTypeParamCount, 'Stack con 1 type param');
    AssertEquals('T', TClassDef(node).GetTypeParam(0), 'Stack type param T');
    AssertEqualsI(1, TClassDef(node).GetConstructorCount, 'Stack con 1 constructor');
    AssertEqualsI(3, TClassDef(node).GetMethodCount, 'Stack con 3 métodos');

    node := unit_.Nodes[1];
    AssertTrue(node is TInterfaceDef, 'Nodo 1 es INTERFACE');
    AssertEquals('IPrintable', TInterfaceDef(node).Name, 'Nodo 1 interfaz IPrintable');
    AssertEqualsI(1, TInterfaceDef(node).GetMethodCount, 'IPrintable con 1 método');

    node := unit_.Nodes[2];
    AssertTrue(node is TClassDef, 'Nodo 2 es CLASS');
    AssertEquals('Logger', TClassDef(node).Name, 'Nodo 2 clase Logger');
    AssertEqualsI(1, TClassDef(node).GetImplementsCount, 'Logger implementa 1 interfaz');
    AssertEquals('IPrintable', TClassDef(node).GetImplements(0), 'Logger implementa IPrintable');
    AssertEqualsI(1, TClassDef(node).GetConstructorCount, 'Logger con 1 constructor');
    AssertEqualsI(1, TClassDef(node).GetMethodCount, 'Logger con 1 método');
    AssertTrue(TClassDef(node).GetMethod(0).IsVirtual, 'Logger.Print es VIRTUAL');

    node := unit_.Nodes[3];
    AssertTrue(node is TFunctionDef, 'Nodo 3 es FUNCTION');
    AssertEquals('Main', TFunctionDef(node).Name, 'Nodo 3 función Main');
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
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  src: TStringList;
  unit_: TCompilationUnit;
begin
  AssertTrue(FileExists('tests/fixtures/legacy.prg'), 'Fixture legacy.prg existe');
  src := TStringList.Create;
  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create('legacy.prg');
  par := TParser.Create(lex, rep);
  unit_ := nil;
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
  RegisterTest('Pipeline: class methods',         @TestPipeline_ClassMethods);
  RegisterTest('Pipeline: operators preservation',@TestPipeline_OperatorPreservation);
  RegisterTest('Pipeline: end-to-end program.fpg',@TestPipeline_EndToEndFile);
  RegisterTest('Pipeline: legacy.prg',            @TestPipeline_LegacyFixture);
  RunAllTests('INTEGRATION TESTS — lexer+parser pipeline');
end.
