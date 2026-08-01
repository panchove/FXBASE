program test_tokens;

{$mode delphi}{$H+}

uses
  SysUtils, fxb.tokens, fxb.test.framework;

procedure TestKeywordFromString_Class;
begin
  AssertEqualsI(Ord(kwClass), Ord(KeywordFromString('CLASS')),
    'CLASS debe mapear a kwClass');
end;

procedure TestKeywordFromString_EndClass;
begin
  AssertEqualsI(Ord(kwEndClass), Ord(KeywordFromString('ENDCLASS')),
    'ENDCLASS debe mapear a kwEndClass');
end;

procedure TestKeywordFromString_CaseInsensitive;
begin
  AssertTrue(KeywordFromString('class') = kwClass, 'class en minúsculas');
  AssertTrue(KeywordFromString('ClAsS') = kwClass, 'ClAsS mixto');
end;

procedure TestKeywordFromString_UnknownIdentifier;
begin
  AssertTrue(KeywordFromString('foo') = kwNone, 'identificador no-keyword');
  AssertTrue(KeywordFromString('myVar') = kwNone, 'identificador no-keyword 2');
end;

procedure TestKeywordFromString_AllOOPKeywords;
begin
  AssertEqualsI(Ord(kwInterface), Ord(KeywordFromString('INTERFACE')),
    'INTERFACE keyword');
  AssertEqualsI(Ord(kwImplements), Ord(KeywordFromString('IMPLEMENTS')),
    'IMPLEMENTS keyword');
  AssertEqualsI(Ord(kwVirtual), Ord(KeywordFromString('VIRTUAL')),
    'VIRTUAL keyword');
  AssertEqualsI(Ord(kwOverride), Ord(KeywordFromString('OVERRIDE')),
    'OVERRIDE keyword');
  AssertEqualsI(Ord(kwAbstract), Ord(KeywordFromString('ABSTRACT')),
    'ABSTRACT keyword');
  AssertEqualsI(Ord(kwConstructor), Ord(KeywordFromString('CONSTRUCTOR')),
    'CONSTRUCTOR keyword');
  AssertEqualsI(Ord(kwDestructor), Ord(KeywordFromString('DESTRUCTOR')),
    'DESTRUCTOR keyword');
  AssertEqualsI(Ord(kwOperator), Ord(KeywordFromString('OPERATOR')),
    'OPERATOR keyword');
end;

procedure TestIsKeyword_True;
begin
  AssertTrue(IsKeyword('FUNCTION'), 'FUNCTION');
  AssertTrue(IsKeyword('PROCEDURE'), 'PROCEDURE');
  AssertTrue(IsKeyword('CLASS'), 'CLASS');
  AssertTrue(IsKeyword('ENDCLASS'), 'ENDCLASS');
  AssertTrue(IsKeyword('IF'), 'IF');
end;

procedure TestIsKeyword_False;
begin
  AssertFalse(IsKeyword('foo'), 'foo');
  AssertFalse(IsKeyword('BarBaz'), 'BarBaz');
  AssertFalse(IsKeyword(''), 'empty string');
end;

procedure TestTokenTypeName_KnownTypes;
begin
  AssertEquals('::', TokenTypeName(ttDoubleColon), 'ttDoubleColon');
  AssertEquals('?:', TokenTypeName(ttQuestionColon), 'ttQuestionColon');
  AssertEquals('?.', TokenTypeName(ttQuestionDot), 'ttQuestionDot');
  AssertEquals('+=', TokenTypeName(ttPlusAssign), 'ttPlusAssign');
  AssertEquals('==', TokenTypeName(ttEq), 'ttEq');
end;

procedure TestTokenTypeName_AllReturnsNonEmpty;
var
  tt: TTokenType;
begin
  for tt := Low(TTokenType) to High(TTokenType) do
  begin
    AssertTrue(TokenTypeName(tt) <> '',
      'TokenTypeName(' + TokenTypeName(tt) + ') debe retornar algo');
  end;
end;

procedure TestDumpToken_Integer;
var
  tok: TToken;
begin
  tok.TokenType := ttInteger;
  tok.IntValue := 42;
  tok.Line := 1;
  tok.Col := 5;
  AssertTrue(DumpToken(tok) <> '', 'DumpToken integer no debe ser vacío');
  AssertTrue(Pos('42', DumpToken(tok)) > 0, 'DumpToken debe incluir valor');
end;

procedure TestDumpToken_String;
var
  tok: TToken;
begin
  tok.TokenType := ttString;
  tok.StrValue := 'hello';
  AssertTrue(DumpToken(tok) <> '', 'DumpToken string no vacío');
  AssertTrue(Pos('hello', DumpToken(tok)) > 0, 'DumpToken debe incluir str');
end;

procedure TestTokenFlags_Empty;
var
  f: TTokenFlags;
begin
  f := [];
  AssertFalse(tfNewline in f, 'tfNewline ausente');
  AssertFalse(tfStartOfLine in f, 'tfStartOfLine ausente');
end;

procedure TestTokenFlags_Set;
var
  f: TTokenFlags;
begin
  f := [tfNewline, tfStartOfLine];
  AssertTrue(tfNewline in f, 'tfNewline presente');
  AssertTrue(tfStartOfLine in f, 'tfStartOfLine presente');
end;

procedure TestKeywordFromString_NilSafeKeywords;
begin
  AssertEqualsI(Ord(kwNew), Ord(KeywordFromString('NEW')), 'NEW');
  AssertEqualsI(Ord(kwThis), Ord(KeywordFromString('THIS')), 'THIS');
  AssertEqualsI(Ord(kwSuper), Ord(KeywordFromString('SUPER')), 'SUPER');
end;

begin
  RegisterTest('KeywordFromString: CLASS',          @TestKeywordFromString_Class);
  RegisterTest('KeywordFromString: ENDCLASS',       @TestKeywordFromString_EndClass);
  RegisterTest('KeywordFromString: case-insensitive',@TestKeywordFromString_CaseInsensitive);
  RegisterTest('KeywordFromString: unknown→kwNone',  @TestKeywordFromString_UnknownIdentifier);
  RegisterTest('KeywordFromString: full OOP set',    @TestKeywordFromString_AllOOPKeywords);
  RegisterTest('KeywordFromString: nil-safe/SELF/SUPER',@TestKeywordFromString_NilSafeKeywords);
  RegisterTest('IsKeyword: true cases',              @TestIsKeyword_True);
  RegisterTest('IsKeyword: false cases',             @TestIsKeyword_False);
  RegisterTest('TokenTypeName: known values',        @TestTokenTypeName_KnownTypes);
  RegisterTest('TokenTypeName: all non-empty',       @TestTokenTypeName_AllReturnsNonEmpty);
  RegisterTest('DumpToken: integer',                 @TestDumpToken_Integer);
  RegisterTest('DumpToken: string',                  @TestDumpToken_String);
  RegisterTest('TokenFlags: empty set',              @TestTokenFlags_Empty);
  RegisterTest('TokenFlags: set members',            @TestTokenFlags_Set);
  RunAllTests('UNIT TESTS — fxb.tokens');
end.
