program test_symbols;

{$mode delphi}{$H+}

// Unit tests for fxb.symbols (two-pass compilation symbol table): export
// collection from a parsed unit, resolution, method lookup, source-file
// tracking, merge/dedupe and clear.

uses
  SysUtils,
  Classes,
  fxb.ast,
  fxb.lexer,
  fxb.parser,
  fxb.errors,
  fxb.symbols,
  fxb.test.framework;

function ParseProgram(const ASource: string; out AST: TCompilationUnit): Boolean;
var
  lexer: TFXBLexer;
  reporter: TErrorReporter;
  parser: TParser;
begin
  Result := False;
  AST := nil;
  reporter := TErrorReporter.Create('mem.fpg');
  lexer := TFXBLexer.Create;
  try
    if not lexer.Tokenize(ASource, 'mem.fpg') then
      Exit;
    parser := TParser.Create(lexer, reporter);
    try
      AST := parser.ParseProgram;
      Result := (AST <> nil) and (not reporter.HasErrors);
    finally
      parser.Free;
    end;
  finally
    lexer.Free;
    reporter.Free;
  end;
end;

procedure TestSymbols_CollectExports;
var
  table: TSymbolTable;
  ast: TCompilationUnit;
  sym: TSymbol;
begin
  AssertTrue(ParseProgram(
    'FUNCTION Main()' + LineEnding +
    '  ? "hi"' + LineEnding +
    'ENDFUNC' + LineEnding +
    'STATIC FUNCTION Helper(n AS INTEGER) AS INTEGER' + LineEnding +
    '  RETURN n + 1' + LineEnding +
    'ENDFUNC' + LineEnding +
    'PROCEDURE DoWork()' + LineEnding +
    '  ? "work"' + LineEnding +
    'ENDPROC', ast), 'parse mixed declarations');
  try
    table := TSymbolTable.Create;
    try
      table.CollectExports(ast, 'lib.fpg');

      AssertTrue(table.HasSourceFile('lib.fpg'), 'source file tracked');
      AssertTrue(table.HasSymbol('Helper'), 'STATIC FUNCTION exported');
      AssertTrue(table.IsSymbolExported('Helper'), 'static fn flagged exported');
      AssertTrue(table.ResolveSymbol('Helper', sym), 'ResolveSymbol finds Helper');
      AssertEquals('lib.fpg', sym.SourceFile, 'Helper source file');
      AssertTrue(sym.Kind = skFunction, 'Helper kind is skFunction');
      AssertTrue(sym.IsStatic, 'Helper marked static');
      AssertEquals('INTEGER', sym.TypeName, 'Helper return type recorded');

      AssertTrue(table.HasSymbol('DoWork'), 'PROCEDURE exported');
      AssertTrue(not table.HasSymbol('Main'), 'non-static FUNCTION not exported');
    finally
      table.Free;
    end;
  finally
    ast.Free;
  end;
end;

procedure TestSymbols_ResolveUnknown;
var
  table: TSymbolTable;
  sym: TSymbol;
begin
  table := TSymbolTable.Create;
  try
    AssertTrue(not table.ResolveSymbol('Nope', sym), 'unknown name does not resolve');
    AssertTrue(not table.IsSymbolExported('Nope'), 'unknown name not exported');
    sym := table.GetSymbol('Nope');
    AssertEquals('', sym.Name, 'GetSymbol of unknown returns zeroed record');
  finally
    table.Free;
  end;
end;

procedure TestSymbols_ClassMethods;
var
  table: TSymbolTable;
  ast: TCompilationUnit;
  sym: TSymbol;
begin
  AssertTrue(ParseProgram(
    'CLASS Point' + LineEnding +
    '  METHOD Translate(dx AS INTEGER)' + LineEnding +
    '    ? dx' + LineEnding +
    '  ENDMETHOD' + LineEnding +
    '  STATIC METHOD Origin()' + LineEnding +
    '    ? "o"' + LineEnding +
    '  ENDMETHOD' + LineEnding +
    'ENDCLASS', ast), 'parse class with methods');
  try
    table := TSymbolTable.Create;
    try
      table.CollectExports(ast, 'point.fpg');

      AssertTrue(table.HasSymbol('Point'), 'class symbol exported');
      AssertTrue(table.HasMethod('Point', 'Translate'), 'instance method registered');
      AssertTrue(table.HasMethod('Point', 'Origin'), 'static method registered');
      AssertTrue(table.ResolveMethod('Point', 'Translate', sym), 'ResolveMethod finds Translate');
      AssertEquals('Point.Translate', sym.Name, 'method stored under Class.Method');
      AssertEquals('Point', sym.ParentClass, 'method ParentClass recorded');
      AssertTrue(not sym.IsStatic, 'Translate is an instance method');
    finally
      table.Free;
    end;
  finally
    ast.Free;
  end;
end;

procedure TestSymbols_MergeAndClear;
var
  tableA, tableB: TSymbolTable;
  astA, astB: TCompilationUnit;
begin
  AssertTrue(ParseProgram(
    'STATIC FUNCTION Helper() AS INTEGER' + LineEnding +
    '  RETURN 42' + LineEnding +
    'ENDFUNC', astA), 'parse unit A');
  AssertTrue(ParseProgram(
    'PROCEDURE DoWork()' + LineEnding +
    '  ? "x"' + LineEnding +
    'ENDPROC' + LineEnding +
    'STATIC FUNCTION Helper() AS INTEGER' + LineEnding +
    '  RETURN 7' + LineEnding +
    'ENDFUNC', astB), 'parse unit B');
  try
    tableA := TSymbolTable.Create;
    tableB := TSymbolTable.Create;
    try
      tableA.CollectExports(astA, 'a.fpg');
      tableB.CollectExports(astB, 'b.fpg');
      AssertEqualsI(1, Length(tableA.Symbols), 'unit A exports one symbol');
      AssertEqualsI(2, Length(tableB.Symbols), 'unit B exports two symbols');

      tableA.MergeFrom(tableB);
      AssertEqualsI(2, Length(tableA.Symbols), 'merge dedupes overlapping names');
      AssertTrue(tableA.HasSymbol('Helper'), 'Helper survives merge');
      AssertTrue(tableA.HasSymbol('DoWork'), 'DoWork merged in');
      AssertTrue(tableA.HasSourceFile('a.fpg'), 'file a tracked');
      AssertTrue(tableA.HasSourceFile('b.fpg'), 'file b tracked after merge');

      tableA.Clear;
      AssertEqualsI(0, Length(tableA.Symbols), 'Clear empties the table');
      AssertTrue(not tableA.HasSymbol('Helper'), 'no symbols after Clear');
    finally
      tableA.Free;
      tableB.Free;
    end;
  finally
    astA.Free;
    astB.Free;
  end;
end;

begin
  RegisterTest('Symbols: CollectExports (static fn / proc / skip)', @TestSymbols_CollectExports);
  RegisterTest('Symbols: unknown name resolution', @TestSymbols_ResolveUnknown);
  RegisterTest('Symbols: class method registration', @TestSymbols_ClassMethods);
  RegisterTest('Symbols: MergeFrom dedupe + Clear', @TestSymbols_MergeAndClear);
  RunAllTests('SYMBOL TABLE TESTS');
end.
