program test_ir;

{$mode delphi}{$H+}

uses
  SysUtils, Classes,
  fxb.tokens, fxb.lexer, fxb.parser, fxb.ast, fxb.errors, fxb.ir,
  fxb.test.framework;

function LoadSource(const APath: string): string;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.LoadFromFile(APath);
    Result := sl.Text;
  finally
    sl.Free;
  end;
end;

function Compile(const ASource, AName: string; out IR: TIRModule;
  out LexErrCount, ParseErrCount: Integer): TFXBIRGenerator;
var
  lex: TFXBLexer;
  par: TParser;
  rep: TErrorReporter;
  ast: TCompilationUnit;
begin
  LexErrCount := 0;
  ParseErrCount := 0;
  IR := nil;

  lex := TFXBLexer.Create;
  rep := TErrorReporter.Create(AName);
  par := TParser.Create(lex, rep);
  ast := nil;
  Result := TFXBIRGenerator.Create;
  try
    lex.Tokenize(ASource, AName);
    if lex.HasErrors then LexErrCount := 1;
    ast := par.ParseProgram;
    if rep.HasErrors then
      ParseErrCount := rep.ErrorCount;
    IR := Result.Generate(ast);
  finally
    if Assigned(ast) then ast.Free;
    par.Free;
    rep.Free;
    lex.Free;
  end;
end;

procedure TestIR_EmptyFunction;
var
  src, fnName: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'empty.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    AssertNotNil(ir, 'IR module non-nil');
    AssertEqualsI(1, ir.GetFunctionCount, 'exactly one function');
    fnName := ir.GetFunctionByIndex(0).Name;
    AssertEqualsI(Length(fnName), Length('Main'), 'function name length OK');
    AssertTrue(fnName = 'Main', 'function name is Main');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_FunctionWithLocals;
var
  src: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  fn: TIRFunction;
  dump: string;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    LOCAL x: INT' + sLineBreak +
    '    LOCAL y: INT' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'locals.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    fn := ir.GetFunctionByIndex(0);
    AssertEqualsI(2, Length(fn.Locals), '2 locals (x, y)');
    dump := ir.Dump;
    AssertTrue(Pos('%x = alloca', dump) > 0, 'alloca x present in dump');
    AssertTrue(Pos('%y = alloca', dump) > 0, 'alloca y present in dump');
    AssertTrue(Pos('entry:', dump) > 0, 'entry block in dump');
    AssertTrue(Pos('ikRet', dump) > 0, 'ret instruction in dump');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_Assignment;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    LOCAL x: INT' + sLineBreak +
    '    x := 42' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'assign.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    dump := ir.Dump;
    AssertTrue(Pos('ikStore', dump) > 0, 'store present in dump');
    AssertTrue(Pos('ikLoad', dump) = 0, 'no spurious load for direct store');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_IfElseBlocks;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  fn: TIRFunction;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    LOCAL x: INT' + sLineBreak +
    '    IF x > 0 THEN' + sLineBreak +
    '        x := 1' + sLineBreak +
    '    ELSE' + sLineBreak +
    '        x := 2' + sLineBreak +
    '    ENDIF' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'if.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    fn := ir.GetFunctionByIndex(0);
    AssertTrue(fn.GetBlockCount >= 4, 'at least 4 blocks (entry+then+else+merge)');
    dump := ir.Dump;
    AssertTrue(Pos('then', dump) > 0, 'then block in dump');
    AssertTrue(Pos('else', dump) > 0, 'else block in dump');
    AssertTrue(Pos('merge', dump) > 0, 'merge block in dump');
    AssertTrue(Pos('ikCondBr', dump) > 0, 'condbr present in dump');
    AssertTrue(Pos('ikICmp', dump) > 0, 'icmp present in dump');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_WhileBlocks;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    LOCAL x: INT := 0' + sLineBreak +
    '    WHILE x < 10' + sLineBreak +
    '        x := x + 1' + sLineBreak +
    '    END' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'while.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    dump := ir.Dump;
    AssertTrue(Pos('while.cond', dump) > 0, 'while.cond block in dump');
    AssertTrue(Pos('while.body', dump) > 0, 'while.body block in dump');
    AssertTrue(Pos('while.exit', dump) > 0, 'while.exit block in dump');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_ForBlocks;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    LOCAL i: INT' + sLineBreak +
    '    LOCAL a: INT' + sLineBreak +
    '    FOR i := 1 TO 10' + sLineBreak +
    '        a := i + 1' + sLineBreak +
    '    NEXT' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'for.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    dump := ir.Dump;
    AssertTrue(Pos('for.init', dump) > 0, 'for.init block in dump');
    AssertTrue(Pos('for.cond', dump) > 0, 'for.cond block in dump');
    AssertTrue(Pos('for.body', dump) > 0, 'for.body block in dump');
    AssertTrue(Pos('for.step', dump) > 0, 'for.step block in dump');
    AssertTrue(Pos('for.exit', dump) > 0, 'for.exit block in dump');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_Return;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    RETURN' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'ret.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    dump := ir.Dump;
    AssertTrue(Pos('ikRet', dump) > 0, 'ret present in dump');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_BinOpTypes;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    LOCAL a: INT' + sLineBreak +
    '    LOCAL b: INT' + sLineBreak +
    '    a := a + b' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'binop.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    dump := ir.Dump;
    AssertTrue(Pos('ikAdd', dump) > 0, 'add present in dump');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_Print;
var
  src, dump: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    '    ? 1 + 2' + sLineBreak +
    '    ?? "hi"' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'print.fpg', ir, lexErr, parseErr);
  try
    AssertEqualsI(0, lexErr, 'no lexer errors');
    AssertEqualsI(0, parseErr, 'no parser errors');
    AssertNotNil(ir, 'IR produced');
    dump := ir.Dump;
    AssertTrue(Pos('ikPrint', dump) > 0, 'ikPrint present in dump');
    AssertTrue(Pos('newline=1', dump) > 0, 'newline metadata for ?');
    AssertTrue(Pos('newline=0', dump) > 0, 'no-newline metadata for ??');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

procedure TestIR_TargetTriple;
var
  src: string;
  irGen: TFXBIRGenerator;
  ir: TIRModule;
  lexErr, parseErr: Integer;
begin
  src :=
    'FUNCTION Main()' + sLineBreak +
    'ENDFUNC';
  irGen := Compile(src, 'tt.fpg', ir, lexErr, parseErr);
  try
    AssertNotNil(ir, 'IR produced');
    AssertTrue(Length(ir.TargetTriple) > 0, 'target triple non-empty');
    AssertTrue(Length(ir.DataLayout) > 0, 'data layout non-empty');
  finally
    ir.Free;
    irGen.Free;
  end;
end;

begin
  RegisterTest('IR: empty function produces Main with entry block', @TestIR_EmptyFunction);
  RegisterTest('IR: function with 2 locals', @TestIR_FunctionWithLocals);
  RegisterTest('IR: assignment emits load+store', @TestIR_Assignment);
  RegisterTest('IR: IF/ELSE/ENDIF produces then/else/merge blocks', @TestIR_IfElseBlocks);
  RegisterTest('IR: WHILE produces cond/body/exit blocks', @TestIR_WhileBlocks);
  RegisterTest('IR: FOR produces init/cond/body/step/exit blocks', @TestIR_ForBlocks);
  RegisterTest('IR: RETURN emits ikRet', @TestIR_Return);
  RegisterTest('IR: binary op emits corresponding instruction', @TestIR_BinOpTypes);
  RegisterTest('IR: ?/?? emit ikPrint with newline metadata', @TestIR_Print);
  RegisterTest('IR: target triple reflects TargetOS/TargetCPU', @TestIR_TargetTriple);
  RunAllTests('IR TESTS — AST-driven lowering');
end.
