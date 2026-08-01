program test_lexer;

{$mode delphi}{$H+}

uses
  SysUtils, fxb.tokens, fxb.lexer, fxb.test.framework;

function LexOne(const ASource: string; AIdx: Integer): TToken;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize(ASource, 'test.fpg');
    if AIdx < Length(lex.Tokens) then
      Result := lex.Tokens[AIdx]
    else
      raise Exception.CreateFmt('Index %d fuera de rango (len=%d)', [AIdx, Length(lex.Tokens)]);
  finally
    lex.Free;
  end;
end;

procedure TestLex_EmptySource;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    AssertTrue(lex.Tokenize('', 'empty.fpg'), 'Tokenize empty debe retornar True');
    AssertEqualsI(0, Length(lex.Tokens), 'Sin tokens');
    AssertFalse(lex.HasErrors, 'Sin errores');
  finally
    lex.Free;
  end;
end;

procedure TestLex_SingleIdentifier;
var
  t: TToken;
begin
  t := LexOne('foo', 0);
  AssertEqualsI(Ord(ttIdentifier), Ord(t.TokenType), 'Tipo identificador');
  AssertEquals('foo', t.StrValue, 'Valor identificador');
  AssertEqualsI(1, t.Line, 'Línea 1');
  AssertEqualsI(1, t.Col, 'Columna 1');
end;

procedure TestLex_KeywordMapping;
var
  t: TToken;
begin
  t := LexOne('CLASS', 0);
  AssertEqualsI(Ord(ttKeyword), Ord(t.TokenType), 'Tipo keyword');
  AssertEqualsI(Ord(kwClass), Ord(t.Keyword), 'kwClass');
end;

procedure TestLex_IntegerLiteral;
var
  t: TToken;
begin
  t := LexOne('12345', 0);
  AssertEqualsI(Ord(ttInteger), Ord(t.TokenType), 'Tipo integer');
  AssertEqualsI(12345, t.IntValue, 'Valor 12345');
end;

procedure TestLex_NegativeNumberIsUnary;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('-5', 't.fpg');
    AssertTrue(Length(lex.Tokens) >= 2, 'Debe haber 2 tokens: -, 5');
    AssertEqualsI(Ord(ttMinus), Ord(lex.Tokens[0].TokenType), 'Token 0 = minus');
    AssertEqualsI(Ord(ttInteger), Ord(lex.Tokens[1].TokenType), 'Token 1 = integer');
  finally
    lex.Free;
  end;
end;

procedure TestLex_RealLiteral;
var
  t: TToken;
begin
  t := LexOne('3.14', 0);
  AssertEqualsI(Ord(ttReal), Ord(t.TokenType), 'Tipo real');
  AssertTrue(Abs(t.RealValue - 3.14) < 0.001, 'Valor aprox 3.14');
end;

procedure TestLex_StringLiteral;
var
  t: TToken;
begin
  t := LexOne('"hello world"', 0);
  AssertEqualsI(Ord(ttString), Ord(t.TokenType), 'Tipo string');
  AssertEquals('hello world', t.StrValue, 'Valor string');
end;

procedure TestLex_SquareStringLiteral;
var
  t: TToken;
begin
  t := LexOne('[hello]', 0);
  AssertEqualsI(Ord(ttString), Ord(t.TokenType), 'Tipo string con corchetes');
  AssertEquals('hello', t.StrValue, 'Valor con corchetes');
end;

procedure TestLex_Operators_Basic;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('+-*/', 't.fpg');
    AssertEqualsI(4, Length(lex.Tokens), '4 operadores');
    AssertEqualsI(Ord(ttPlus), Ord(lex.Tokens[0].TokenType), '+');
    AssertEqualsI(Ord(ttMinus), Ord(lex.Tokens[1].TokenType), '-');
    AssertEqualsI(Ord(ttStar), Ord(lex.Tokens[2].TokenType), '*');
    AssertEqualsI(Ord(ttSlash), Ord(lex.Tokens[3].TokenType), '/');
  finally
    lex.Free;
  end;
end;

procedure TestLex_Operators_TwoChar;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('::?:?.', 't.fpg');
    AssertEqualsI(3, Length(lex.Tokens), '3 operadores de 2 chars');
    AssertEqualsI(Ord(ttDoubleColon), Ord(lex.Tokens[0].TokenType), '::');
    AssertEqualsI(Ord(ttQuestionColon), Ord(lex.Tokens[1].TokenType), '?:');
    AssertEqualsI(Ord(ttQuestionDot), Ord(lex.Tokens[2].TokenType), '?.');

    lex.Tokenize('++--', 't.fpg');
    AssertEqualsI(2, Length(lex.Tokens), '++/--');
    AssertEqualsI(Ord(ttInc), Ord(lex.Tokens[0].TokenType), '++');
    AssertEqualsI(Ord(ttDec), Ord(lex.Tokens[1].TokenType), '--');

    lex.Tokenize('>=<=', 't.fpg');
    AssertEqualsI(2, Length(lex.Tokens), '>=<=');
    AssertEqualsI(Ord(ttGe), Ord(lex.Tokens[0].TokenType), '>=');
    AssertEqualsI(Ord(ttLe), Ord(lex.Tokens[1].TokenType), '<=');
  finally
    lex.Free;
  end;
end;

procedure TestLex_Operators_Assigns;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('+=-=*=/=', 't.fpg');
    AssertEqualsI(4, Length(lex.Tokens), '4 assigns');
    AssertEqualsI(Ord(ttPlusAssign), Ord(lex.Tokens[0].TokenType), '+=');
    AssertEqualsI(Ord(ttMinusAssign), Ord(lex.Tokens[1].TokenType), '-=');
    AssertEqualsI(Ord(ttStarAssign), Ord(lex.Tokens[2].TokenType), '*=');
    AssertEqualsI(Ord(ttSlashAssign), Ord(lex.Tokens[3].TokenType), '/=');
  finally
    lex.Free;
  end;
end;

procedure TestLex_Operators_Logical;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('&&||', 't.fpg');
    AssertTrue(Length(lex.Tokens) >= 1, 'Operadores lógicos');

    lex.Tokenize('.AND. .OR. .NOT.', 't.fpg');
    AssertTrue(Length(lex.Tokens) >= 1, 'Operadores xBASE');
  finally
    lex.Free;
  end;
end;

procedure TestLex_CommentLine;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('// esto es comentario', 't.fpg');
    // Los comentarios pueden emitir token o no, pero no deben causar errores
    AssertFalse(lex.HasErrors, 'Sin errores con comentario de línea');
  finally
    lex.Free;
  end;
end;

procedure TestLex_CommentStar;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('* otro comentario', 't.fpg');
    AssertFalse(lex.HasErrors, 'Sin errores con comentario *');
  finally
    lex.Free;
  end;
end;

procedure TestLex_BlockComment;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('/* block comment */', 't.fpg');
    AssertFalse(lex.HasErrors, 'Sin errores con block comment');
  finally
    lex.Free;
  end;
end;

procedure TestLex_LogicalLiteral;
var
  t: TToken;
begin
  t := LexOne('.T.', 0);
  AssertEqualsI(Ord(ttLogical), Ord(t.TokenType), 'Tipo logical');

  t := LexOne('.F.', 0);
  AssertEqualsI(Ord(ttLogical), Ord(t.TokenType), '.F.');
end;

procedure TestLex_NilLiteral;
var
  t: TToken;
begin
  t := LexOne('NIL', 0);
  AssertEqualsI(Ord(ttNil), Ord(t.TokenType), 'Tipo nil');
end;

procedure TestLex_PreprocessorDirectives;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('#include "foo.fph"', 't.fpg');
    AssertFalse(lex.HasErrors, 'Sin errores en #include');

    lex.Tokenize('#define MAX 100', 't.fpg');
    AssertFalse(lex.HasErrors, 'Sin errores en #define');
  finally
    lex.Free;
  end;
end;

procedure TestLex_MultiLinePositions;
var
  lex: TFXBLexer;
  i: Integer;
  tokLine2: Integer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('foo' + sLineBreak + 'bar' + sLineBreak + 'baz', 't.fpg');
    tokLine2 := -1;
    for i := 0 to High(lex.Tokens) do
      if lex.Tokens[i].Line = 2 then
      begin
        tokLine2 := i;
        Break;
      end;
    AssertTrue(tokLine2 >= 0, 'Debe haber un token en línea 2');
    AssertEquals('bar', lex.Tokens[tokLine2].StrValue, 'Token línea 2 = bar');
  finally
    lex.Free;
  end;
end;

procedure TestLex_StreamInterface_NextToken;
var
  lex: TFXBLexer;
  tok: TToken;
  count: Integer;
begin
  lex := TFXBLexer.Create;
  try
    lex.Tokenize('a b c', 't.fpg');
    count := 0;
    while not lex.EOF do
    begin
      tok := lex.NextToken;
      Inc(count);
      AssertTrue(count <= 3, 'No más de 3 tokens significativos');
    end;
    AssertTrue(count >= 3, 'Al menos 3 tokens consumidos');
  finally
    lex.Free;
  end;
end;

procedure TestLex_LegacyMode;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.LegacyMode := True;
    lex.Tokenize('FUNCTION Test()', 'legacy.fpg');
    AssertFalse(lex.HasErrors, 'Legacy mode: FUNCTION reconocido');
  finally
    lex.Free;
  end;
end;

procedure TestLex_StrictMode;
var
  lex: TFXBLexer;
begin
  lex := TFXBLexer.Create;
  try
    lex.StrictMode := True;
    lex.Tokenize('myVar := 42', 'strict.fpg');
    AssertFalse(lex.HasErrors, 'Strict mode: asignación reconocida');
  finally
    lex.Free;
  end;
end;

begin
  RegisterTest('Lex: empty source',               @TestLex_EmptySource);
  RegisterTest('Lex: single identifier',           @TestLex_SingleIdentifier);
  RegisterTest('Lex: keyword mapping',             @TestLex_KeywordMapping);
  RegisterTest('Lex: integer literal',             @TestLex_IntegerLiteral);
  RegisterTest('Lex: negative = unary+int',        @TestLex_NegativeNumberIsUnary);
  RegisterTest('Lex: real literal',                @TestLex_RealLiteral);
  RegisterTest('Lex: string literal "..."',        @TestLex_StringLiteral);
  RegisterTest('Lex: string literal [...]',        @TestLex_SquareStringLiteral);
  RegisterTest('Lex: +/-/*//',                     @TestLex_Operators_Basic);
  RegisterTest('Lex: :: / ?: / ?. / ++ / -- / >= <=',@TestLex_Operators_TwoChar);
  RegisterTest('Lex: += -= *= /=',                 @TestLex_Operators_Assigns);
  RegisterTest('Lex: && || .AND. .OR.',             @TestLex_Operators_Logical);
  RegisterTest('Lex: // comment',                  @TestLex_CommentLine);
  RegisterTest('Lex: * comment',                   @TestLex_CommentStar);
  RegisterTest('Lex: /* ... */ comment',           @TestLex_BlockComment);
  RegisterTest('Lex: .T. .F.',                     @TestLex_LogicalLiteral);
  RegisterTest('Lex: NIL',                         @TestLex_NilLiteral);
  RegisterTest('Lex: #include #define',            @TestLex_PreprocessorDirectives);
  RegisterTest('Lex: multi-line positions',        @TestLex_MultiLinePositions);
  RegisterTest('Lex: NextToken stream interface',  @TestLex_StreamInterface_NextToken);
  RegisterTest('Lex: LegacyMode flag',             @TestLex_LegacyMode);
  RegisterTest('Lex: StrictMode flag',             @TestLex_StrictMode);
  RunAllTests('UNIT TESTS — fxb.lexer');
end.
