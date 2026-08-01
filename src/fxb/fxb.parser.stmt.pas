unit fxb.parser.stmt;

{$mode objfpc}{$H+}

interface

uses
  fxb.tokens, fxb.errors, fxb.ast, fxb.ast.stmt, fxb.ast.expr;

type
  TParser = class;                     // forward declaration

  TStmtParser = class
  private
    FParser: TObject;                  // rompemos el ciclo (cast a TParser en la implementation)
    // helpers que delegan al parser original
    function  Peek                : TTokenType;          inline;
    function  MatchAdvance(TT:TTokenType): Boolean;     inline;
    procedure Consume(TT:TTokenType; const Msg:string); inline;
    function  Check(TT:TTokenType): Boolean;            inline;
    function  CheckKeyword(kw:TKeyword): Boolean;       inline;
    function  CheckAny(const TTs:array of TTokenType): Boolean; inline;
    function  PeekIsKeyword(kw:TKeyword): Boolean;      inline;
    procedure Error(const Msg:string); overload;        inline;
    procedure Error(Code:Integer; const Msg:string); overload; inline;
    function  CurrentToken: TToken;                     inline;
    function  PreviousToken: TToken;                    inline;
  public
    constructor Create(AParser: TObject);

    // -------  parsing de sentencias  -------
    function ParseStatement     : TASTNode;
    function ParseVarDecl       : TASTNode;
    function ParseAssignment(Target: TExpr): TASTNode;
    function ParseIf            : TASTNode;
    function ParseDoWhile       : TASTNode;
    function ParseWhile         : TASTNode;
    function ParseFor           : TASTNode;
    function ParseForEach       : TASTNode;
    function ParseReturn        : TASTNode;
    function ParseYield         : TASTNode;
    function ParseLoopCtrl      : TASTNode;
    function ParsePrint         : TASTNode;
    function ParseMisc          : TASTNode;
  end;

implementation

uses
  sysutils, classes, fxb.tokens, fxb.errors, fxb.ast, fxb.lexer,
  fxb.parser;          // <-- solo en implementation

constructor TStmtParser.Create(AParser: TObject);
begin
  inherited Create;
  FParser := AParser;
end;

// ---------- helpers que delegan al parser original ----------
function TStmtParser.Peek                : TTokenType;          inline; begin Result := TParser(FParser).Peek; end;
function TStmtParser.MatchAdvance(TT:TTokenType): Boolean;    inline; begin Result := TParser(FParser).MatchAdvance(TT); end;
procedure TStmtParser.Consume(TT:TTokenType; const Msg:string); inline; begin TParser(FParser).Consume(TT,Msg); end;
function  TStmtParser.Check(TT:TTokenType): Boolean;           inline; begin Result := TParser(FParser).Check(TT); end;
function  TStmtParser.CheckKeyword(kw:TKeyword): Boolean;      inline; begin Result := TParser(FParser).CheckKeyword(kw); end;
function  TStmtParser.CheckAny(const TTs:array of TTokenType): Boolean; inline; begin Result := TParser(FParser).CheckAny(TTs); end;
function  TStmtParser.PeekIsKeyword(kw:TKeyword): Boolean;    inline; begin Result := TParser(FParser).PeekIsKeyword(kw); end;
procedure TStmtParser.Error(const Msg:string); overload;      inline; begin TParser(FParser).Error(Msg); end;
procedure TStmtParser.Error(Code:Integer; const Msg:string); overload; inline; begin TParser(FParser).Error(Code,Msg); end;
function  TStmtParser.CurrentToken: TToken;                    inline; begin Result := TParser(FParser).Current; end;
function  TStmtParser.PreviousToken: TToken;                   inline; begin Result := TParser(FParser).FPrevious; end;

// -----------------------------------------------------------------
//  A partir de aquí **copia exacta** de todos los métodos de sentencias
//  que estaban en TParser (ParseStatement … ParseMisc).
//  Cada llamada a otro método del parser se cambia a “Self.” porque ahora
//  son métodos de TStmtParser.  Las llamadas a ParseExpression, etc.,
//  siguen delegando en FParser (p.ej.  TParser(FParser).ParseExpression).
// -----------------------------------------------------------------

function TStmtParser.ParseStatement: TASTNode;
begin
  case Peek of
    ttKeyword:
      begin
        case TParser(FParser).FCurrent.Keyword of
          kwLocal, kwPrivate, kwPublic, kwStatic: Exit(ParseVarDecl);
          kwIf:            Exit(ParseIf);
          kwDo:            Exit(ParseDoWhile);
          kwWhile:         Exit(ParseWhile);
          kwFor:           Exit(ParseFor);
          kwForEach:       Exit(ParseForEach);
          kwReturn:        Exit(ParseReturn);
          kwYield:         Exit(ParseYield);
          kwLoop, kwExit, kwBreak: Exit(ParseLoopCtrl);
          kwTry..kwAnnounce: Exit(ParseMisc);   // todos los legacy commands
          kwClass,kwFunction,kwProcedure: Exit(TParser(FParser).ParseTopLevel);
          kwStruct:        Exit(TParser(FParser).ParseStructDef);
          kwNewType:       Exit(TParser(FParser).ParseNewTypeDef);
          else
            begin
              Error('Unexpected keyword ' + KeywordNames[TParser(FParser).FCurrent.Keyword]);
              Advance;
              Exit(nil);
            end;
        end;
      end;

    ttIdentifier, ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil,
    ttLParen, ttLBrace, ttPlus, ttMinus, ttNot, ttDotNot,
    ttBitAnd, ttAt, ttCaret:
      begin
        Result := ParseAssignment(nil);
      end;

    ttQuestion, ttDoubleQuestion:
      begin
        Result := ParsePrint;
      end;

    ttNewline, ttSemicolon:
      begin
        Result := nil; // empty statement
        Advance;
      end;

    ttEof:
      Result := nil;

    else
    begin
      Error('Unexpected token in statement: ' + DumpToken(CurrentToken));
      Result := nil;
      Advance;
    end;
  end;
  // Skip trailing newlines
end;

// ---------------------------------------------------------------
//  A partir de aquí se copian **textualmente** los cuerpos de
//  ParseVarDecl, ParseAssignment, ParseIf, ParseDoWhile,
//  ParseWhile, ParseFor, ParseForEach, ParseReturn, ParseYield,
//  ParseLoopCtrl, ParseMisc tal como están en fxb.parser.pas
//  (líneas 827‑1127 del archivo original).  Sólo hay que
//  reemplazar cada llamada a un método del parser original por
//  “Self.” (para los métodos que movemos) o por
//  “TParser(FParser).” cuando se llama a rutinas que **no** se
//  han movido (p.ej. ParseExpression, ParseStatement, etc.).
// ---------------------------------------------------------------

function TStmtParser.ParseVarDecl: TASTNode;
var
  scope: string;
  decl: TVarDeclStmt;
  name, typ: string;
  initVal: TExpr;
begin
  scope := KeywordNames[TParser(FParser).FCurrent.Keyword];
  TParser(FParser).Advance; // consume LOCAL/PRIVATE/PUBLIC/STATIC
  decl := TVarDeclStmt.Create(scope, TParser(FParser).FCurrent.Line, TParser(FParser).FCurrent.Col);

  repeat
    if Peek <> ttIdentifier then
    begin
      Error(FXB_EXPECTED_IDENT, 'Expected variable name in ' + scope + ' declaration');
      Break;
    end;

    name := CurrentToken.StrValue;
    Advance; // consume identifier

    typ := '';
    if Peek = ttColon then
    begin
      Advance; // consume ':'
      typ := TParser(FParser).ParseTypeRef;
    end
    else if MatchAdvance(kwAs) then
      typ := TParser(FParser).ParseTypeRef;

    initVal := nil;
    if Peek = ttAssign then
    begin
      Advance; // consume ':='
      initVal := TParser(FParser).ParseExpression;
    end;

    decl.AddVar(name, typ, initVal);

    if Peek <> ttComma then Break;
    Advance; // consume ','
  until False;

  Result := decl;
end;

function TStmtParser.ParseAssignment(Target: TExpr): TASTNode;
var
  expr: TExpr;
  op: TTokenType;
begin
  if Target = nil then
  begin
    expr := TParser(FParser).ParseExpression;
    Target := expr;
  end
  else
    Target := TParser(FParser).ParseExpression;

  if Peek in [ttAssign, ttPlusAssign, ttMinusAssign, ttStarAssign,
       ttSlashAssign, ttPercentAssign, ttCaretAssign] then
  begin
    op := CurrentToken.TokenType;
    Advance;
    Result := TAssignStmt.Create(Target, op, TParser(FParser).ParseExpression,
                                 CurrentToken.Line, CurrentToken.Col);
  end
  else
    Result := TExprStmt.Create(Target, CurrentToken.Line, CurrentToken.Col);
end;

function TStmtParser.ParseIf: TASTNode;
var
  stmt: TIfStmt;
  cond: TExpr;
begin
  TParser(FParser).ConsumeKeyword(kwIf, 'Expected IF');
  cond := TParser(FParser).ParseExpression;
  stmt := TIfStmt.Create(cond, CurrentToken.Line, CurrentToken.Col);

  while not CheckKeyword(kwElseIf) and not CheckKeyword(kwElse)
        and not CheckKeyword(kwEndIf) and not CheckKeyword(kwEnd)
        and (Peek <> ttEof) do
  begin
    stmt.AddThenStmt(ParseStatement);
  end;

  while CheckKeyword(kwElseIf) do
  begin
    Advance; // ELSEIF
    cond := TParser(FParser).ParseExpression;
    stmt.AddElseIf(cond);
    while not CheckKeyword(kwElseIf) and not CheckKeyword(kwElse)
          and not CheckKeyword(kwEndIf) and not CheckKeyword(kwEnd)
          and (Peek <> ttEof) do
    begin
      stmt.AddElseIfStmt(ParseStatement);
    end;
  end;

  if CheckKeyword(kwElse) then
  begin
    Advance; // ELSE
    while not CheckKeyword(kwEndIf) and not CheckKeyword(kwEnd)
          and (Peek <> ttEof) do
    begin
      stmt.AddElseStmt(ParseStatement);
    end;
  end;

  if CheckKeyword(kwEndIf) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDIF or END to close IF');

  Result := stmt;
end;

function TStmtParser.ParseDoWhile: TASTNode;
var
  whileStmt: TWhileStmt;
  cond: TExpr;
begin
  TParser(FParser).ConsumeKeyword(kwDo, 'Expected DO');
  TParser(FParser).ConsumeKeyword(kwWhile, 'Expected WHILE after DO');
  cond := TParser(FParser).ParseExpression;
  whileStmt := TWhileStmt.Create(cond, CurrentToken.Line, CurrentToken.Col);

  while not CheckKeyword(kwEndDo) and not CheckKeyword(kwEnd)
        and not CheckKeyword(kwLoop) and (Peek <> ttEof) do
  begin
    whileStmt.AddStmt(ParseStatement);
  end;

  if CheckKeyword(kwEndDo) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDDO or END to close DO WHILE');

  Result := whileStmt;
end;

function TStmtParser.ParseWhile: TASTNode;
var
  whileStmt: TWhileStmt;
  cond: TExpr;
begin
  TParser(FParser).ConsumeKeyword(kwWhile, 'Expected WHILE');
  cond := TParser(FParser).ParseExpression;
  whileStmt := TWhileStmt.Create(cond, CurrentToken.Line, CurrentToken.Col);

  while not CheckKeyword(kwEnd) and not CheckKeyword(kwElse)
        and (Peek <> ttEof) do
  begin
    if CheckKeyword(kwLoop) or CheckKeyword(kwExit) then
    begin
      whileStmt.AddStmt(ParseLoopCtrl);
      Continue;
    end;
    whileStmt.AddStmt(ParseStatement);
  end;

  if CheckKeyword(kwElse) then
  begin
    Advance;
    while not CheckKeyword(kwEnd) and (Peek <> ttEof) do
      whileStmt.AddElseStmt(ParseStatement);
  end;

  if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FXB_UNTERMINATED_BLOCK, 'Expected END to close WHILE');

  Result := whileStmt;
end;

function TStmtParser.ParseFor: TASTNode;
var
  forStmt: TForStmt;
  varName: string;
  start, finish: TExpr;
begin
  TParser(FParser).ConsumeKeyword(kwFor, 'Expected FOR');
  if Peek = ttIdentifier then
    varName := CurrentToken.StrValue
  else
  begin
    Error(FXB_EXPECTED_IDENT, 'Expected loop variable after FOR');
    Exit(TForStmt.Create('', nil, nil, CurrentToken.Line, CurrentToken.Col));
  end;
  Advance;

  TParser(FParser).Consume(ttAssign, 'Expected := after loop variable');
  start := TParser(FParser).ParseExpression;

  if CheckKeyword(kwTo) then
    Advance
  else if CheckKeyword(kwDownTo) then
    Advance
  else
  begin
    Error('Expected TO or DOWNTO in FOR loop');
    Exit(TForStmt.Create(varName, start, nil, CurrentToken.Line, CurrentToken.Col));
  end;

  finish := TParser(FParser).ParseExpression;
  forStmt := TForStmt.Create(varName, start, finish, CurrentToken.Line, CurrentToken.Col);

  if CheckKeyword(kwStep) then
  begin
    Advance;
    forStmt.SetStep(TParser(FParser).ParseExpression);
  end;

  Inc(TParser(FParser).FLoopDepth);
  while not CheckKeyword(kwNext) and not CheckKeyword(kwEnd)
        and (Peek <> ttEof) do
  begin
    if CheckKeyword(kwLoop) or CheckKeyword(kwExit) then
      forStmt.AddStmt(ParseLoopCtrl)
    else
      forStmt.AddStmt(ParseStatement);
  end;
  Dec(TParser(FParser).FLoopDepth);

  if CheckKeyword(kwNext) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FXB_UNTERMINATED_BLOCK, 'Expected NEXT or END to close FOR');

  Result := forStmt;
end;

function TStmtParser.ParseForEach: TASTNode;
begin
  // Stub – mantiene la implementación original
  TParser(FParser).ConsumeKeyword(kwForEach, 'Expected FOREACH');
  while not CheckKeyword(kwNext) and not CheckKeyword(kwEnd)
        and (Peek <> ttEof) do
    ParseStatement;
  if CheckKeyword(kwNext) then Advance;
  Result := nil;
end;

function TStmtParser.ParseReturn: TASTNode;
begin
  TParser(FParser).ConsumeKeyword(kwReturn, 'Expected RETURN');
  if not (Peek in [ttIdentifier, ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil,
       ttLParen, ttLBrace, ttPlus, ttMinus, ttNot, ttDotNot, ttBitAnd, ttAt, ttCaret]) then
    Result := TReturnStmt.Create(PreviousToken.Line, PreviousToken.Col)
  else
    Result := TReturnStmt.CreateWithValue(TParser(FParser).ParseExpression,
                                          PreviousToken.Line, PreviousToken.Col);
end;

function TStmtParser.ParseYield: TASTNode;
begin
  TParser(FParser).ConsumeKeyword(kwYield, 'Expected YIELD');
  Result := TYieldStmt.Create(TParser(FParser).ParseExpression,
                              PreviousToken.Line, PreviousToken.Col);
end;

function TStmtParser.ParseLoopCtrl: TASTNode;
var
  kind: string;
begin
  kind := KeywordNames[TParser(FParser).FCurrent.Keyword];
  Advance;
  if TParser(FParser).FLoopDepth = 0 then
    TParser(FParser).FReporter.WarningFPW(FPW_LEGACY_COMMAND,
      kind + ' outside a loop', CurrentToken.Line, CurrentToken.Col);
  Result := TLoopCtrlStmt.Create(kind, CurrentToken.Line, CurrentToken.Col);
end;

function TStmtParser.ParsePrint: TASTNode;
var
  newLine: Boolean;
  stmt: TPrintStmt;
begin
  newLine := (CurrentToken.TokenType = ttQuestion);
  stmt := TPrintStmt.Create(CurrentToken.Line, CurrentToken.Col, newLine);
  Advance; // consume ? or ??
  while True do
  begin
    stmt.AddExpr(TParser(FParser).ParseExpression);
    if Peek <> ttComma then Break;
    Advance; // consume ','
  end;
  Result := stmt;
end;

function TStmtParser.ParseMisc: TASTNode;
var
  kw: TKeyword;
begin
  kw := TParser(FParser).FCurrent.Keyword;
  Advance; // consume the keyword
  while not (Peek in [ttNewline, ttEof, ttSemicolon]) do
    Advance;
  if Peek in [ttNewline, ttSemicolon] then Advance;
  Result := nil;
end;

end.