unit fxb.parser;

{$mode objfpc}{$H+}

interface

uses
  sysutils, classes, fxb.tokens, fxb.errors, fxb.ast, fxb.lexer, fxb.parser.types, fxb.parser.context, fxb.parser.expr, fxb.parser.stmt, fxb.parser.toplevel, fxb.parser.common;

type
  TParser = class(TObject, IParserContext)
  private
    FRefCount: Integer;
    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
    function _AddRef: LongInt; cdecl;
    function _Release: LongInt; cdecl;
  public
    FLexer: TLexer;
    FReporter: TErrorReporter;
    FCurrent: TToken;
    FPrevious: TToken;
    FLoopDepth: Integer;
    FExprParser: TExprParser;
    FTypeParser: TTypeParser;
    FStmtParser: TStmtParser;
    FTopLevelParser: TTopLevelParser;

    procedure Advance;
    procedure Match(TT: TTokenType);
    function Check(TT: TTokenType): Boolean;
    function CheckKeyword(kw: TKeyword): Boolean;
    function CheckAny(const TTs: array of TTokenType): Boolean;
    function PeekIsKeyword(kw: TKeyword): Boolean;
    procedure Consume(TT: TTokenType; const Msg: string);
    procedure ConsumeKeyword(kw: TKeyword; const Msg: string);
    function MatchAdvance(TT: TTokenType): Boolean;
    function MatchKeyword(kw: TKeyword): Boolean;
    procedure Error(const Msg: string); overload;
    procedure Error(Code: Integer; const Msg: string); overload;
    function Peek: TTokenType;
    function PeekToken(AOffset: Integer = 1): TToken;

    // IParserContext
    function GetLexer: TLexer;
    function GetReporter: TErrorReporter;
    function GetCurrent: TToken;
    function GetPrevious: TToken;
    procedure SetCurrent(const AToken: TToken);
    procedure SetPrevious(const AToken: TToken);

    // Expression parsing
    function ParseExpression: TExpr;
    function ParseLogicalOr: TExpr;
    function ParseLogicalAnd: TExpr;
    function ParseNot: TExpr;
    function ParseComparison: TExpr;
    function ParseConcat: TExpr;
    function ParseAddSub: TExpr;
    function ParseMulDiv: TExpr;
    function ParseUnary: TExpr;
    function ParsePower: TExpr;
    function ParsePrimary: TExpr;
    function ParseCallOrIdent: TExpr;
    function ParseArrayLiteral: TExpr;
    function ParseHashLiteral: TExpr;
    function ParseCodeBlock: TExpr;
    function ParseActualArgs: TExprArray;

    // Type parsing
    function ParseDataType: string;
    function ParseTypeRef: string;
    function ParseGenericArgs: TStringArray;
    function ParseParamList: TParamInfoArray;

    // Statement parsing
    function ParseStatement: TASTNode;
    function ParseVarDecl: TASTNode;
    function ParseAssignment(Target: TExpr): TASTNode;
    function ParseIf: TASTNode;
    function ParseDoWhile: TASTNode;
    function ParseWhile: TASTNode;
    function ParseFor: TASTNode;
    function ParseForEach: TASTNode;
    function ParseReturn: TASTNode;
    function ParseYield: TASTNode;
    function ParseLoopCtrl: TASTNode;
    function ParsePrint: TASTNode;
    function ParseMisc: TASTNode;

    // Top-level parsing
    function ParseFunctionDef: TFunctionDef;
    function ParseProcedureDef: TProcedureDef;
    function ParseClassDef: TClassDef;
    function ParseStructDef: TStructDef;
    function ParseNewTypeDef: TNewTypeDef;
    function ParseTopLevel: TASTNode;

  public
    constructor Create(Lexer: TLexer; Reporter: TErrorReporter);
    destructor Destroy; override;
    function ParseProgram: TCompilationUnit;
    property Current: TToken read FCurrent;
  end;

implementation


constructor TParser.Create(Lexer: TLexer; Reporter: TErrorReporter);
begin
  inherited Create;
  FRefCount := 0;
  FLexer := Lexer;
  FReporter := Reporter;
  FLoopDepth := 0;
  FCurrent.TokenType := ttEof;
  FExprParser := TExprParser.Create(Self);
  FTypeParser := TTypeParser.Create(Self);
  FStmtParser := TStmtParser.Create(Self);
  FTopLevelParser := TTopLevelParser.Create(Self);
end;

destructor TParser.Destroy;
begin
  FExprParser.Free;
  FTypeParser.Free;
  FStmtParser.Free;
  FTopLevelParser.Free;
  inherited;
end;

function TParser.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TParser._AddRef: LongInt; cdecl;
begin
  Result := InterlockedIncrement(FRefCount);
end;

function TParser._Release: LongInt; cdecl;
begin
  Result := InterlockedDecrement(FRefCount);
end;

procedure TParser.Advance;
begin
  FPrevious := FCurrent;
  repeat
    FCurrent := FLexer.NextToken;
  until FCurrent.TokenType in [ttNewline, ttEof, ttKeyword, ttIdentifier,
    ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil,
    ttPlus, ttMinus, ttStar, ttSlash, ttPercent,
    ttStarStar, ttCaret,
    ttEqual, ttAssign, ttPlusAssign, ttMinusAssign,
    ttStarAssign, ttSlashAssign, ttPercentAssign, ttCaretAssign,
    ttEq, ttNeq, ttNeq2, ttLt, ttLe, ttGt, ttGe, ttDollar,
    ttDot, ttArrow, ttColon, ttSemicolon, ttComma,
    ttLParen, ttRParen, ttLBracket, ttRBracket,
    ttLBrace, ttRBrace, ttPipe,
    ttAt, ttBitAnd, ttNot, ttHash,
    ttDotAnd, ttDotOr, ttDotNot,
    ttQuestion, ttDoubleQuestion, ttQuestionColon, ttQuestionDot,
    ttInvalid, ttComment];
end;

procedure TParser.Match(TT: TTokenType);
begin
  if FCurrent.TokenType = TT then
    Advance
  else
      Error(FXB_UNEXPECTED_TOKEN, 'Expected ' + TokenTypeName(TT) + ' but got ' + DumpToken(FCurrent));
end;

function TParser.Check(TT: TTokenType): Boolean;
begin
  Result := FCurrent.TokenType = TT;
end;

function TParser.CheckKeyword(kw: TKeyword): Boolean;
begin
  Result := (FCurrent.TokenType = ttKeyword) and (FCurrent.Keyword = kw);
end;

function TParser.CheckAny(const TTs: array of TTokenType): Boolean;
var
  tt: TTokenType;
begin
  for tt in TTs do
    if FCurrent.TokenType = tt then Exit(True);
  Result := False;
end;

function TParser.PeekIsKeyword(kw: TKeyword): Boolean;
begin
  Result := CheckKeyword(kw);
end;

procedure TParser.Consume(TT: TTokenType; const Msg: string);
begin
  if FCurrent.TokenType = TT then
    Advance
  else
    Error(FXB_UNEXPECTED_TOKEN, Msg + ': expected ' + TokenTypeName(TT));
end;

procedure TParser.ConsumeKeyword(kw: TKeyword; const Msg: string);
begin
  if CheckKeyword(kw) then
    Advance
  else
    Error(FXB_UNEXPECTED_TOKEN, Msg + ': expected keyword ' + KeywordNames[kw]);
end;

function TParser.MatchAdvance(TT: TTokenType): Boolean;
begin
  if Check(TT) then
  begin
    Advance;
    Result := True;
  end
  else
    Result := False;
end;

function TParser.MatchKeyword(kw: TKeyword): Boolean;
begin
  if CheckKeyword(kw) then
  begin
    Advance;
    Result := True;
  end
  else
    Result := False;
end;

function TParser.Peek: TTokenType;
begin
  Result := FCurrent.TokenType;
end;

function TParser.PeekToken(AOffset: Integer = 1): TToken;
begin
  Result := FLexer.PeekToken(AOffset);
end;

procedure TParser.Error(const Msg: string);
begin
  FReporter.ErrorFXB(FXB_SYNTAX_ERROR, Msg, FCurrent.Line, FCurrent.Col);
end;

procedure TParser.Error(Code: Integer; const Msg: string);
begin
  FReporter.ErrorFXB(Code, Msg, FCurrent.Line, FCurrent.Col);
end;

// IParserContext implementation
function TParser.GetLexer: TLexer;
begin
  Result := FLexer;
end;

function TParser.GetReporter: TErrorReporter;
begin
  Result := FReporter;
end;

function TParser.GetCurrent: TToken;
begin
  Result := FCurrent;
end;

function TParser.GetPrevious: TToken;
begin
  Result := FPrevious;
end;

procedure TParser.SetCurrent(const AToken: TToken);
begin
  FCurrent := AToken;
end;

procedure TParser.SetPrevious(const AToken: TToken);
begin
  FPrevious := AToken;
end;

// Expression parsing delegated to FExprParser

function TParser.ParseExpression: TExpr;
begin
  Result := FExprParser.ParseExpression;
end;

function TParser.ParseTypeRef: string;
begin
  Result := FTypeParser.ParseTypeRef;
end;

function TParser.ParseLogicalOr: TExpr;
begin
  Result := FExprParser.ParseLogicalOr;
end;

function TParser.ParseLogicalAnd: TExpr;
begin
  Result := FExprParser.ParseLogicalAnd;
end;

function TParser.ParseNot: TExpr;
begin
  Result := FExprParser.ParseNot;
end;

function TParser.ParseComparison: TExpr;
begin
  Result := FExprParser.ParseComparison;
end;

function TParser.ParseConcat: TExpr;
begin
  Result := FExprParser.ParseConcat;
end;

function TParser.ParseAddSub: TExpr;
begin
  Result := FExprParser.ParseAddSub;
end;

function TParser.ParseMulDiv: TExpr;
begin
  Result := FExprParser.ParseMulDiv;
end;

function TParser.ParseUnary: TExpr;
begin
  Result := FExprParser.ParseUnary;
end;

function TParser.ParsePower: TExpr;
begin
  Result := FExprParser.ParsePower;
end;

function TParser.ParsePrimary: TExpr;
begin
  Result := FExprParser.ParsePrimary;
end;

function TParser.ParseCallOrIdent: TExpr;
begin
  Result := FExprParser.ParseCallOrIdent;
end;

function TParser.ParseActualArgs: TExprArray;
begin
  Result := FExprParser.ParseActualArgs;
end;

function TParser.ParseArrayLiteral: TExpr;
begin
  Result := FExprParser.ParseArrayLiteral;
end;

function TParser.ParseHashLiteral: TExpr;
begin
  Result := FExprParser.ParseHashLiteral;
end;

function TParser.ParseCodeBlock: TExpr;
begin
  Result := FExprParser.ParseCodeBlock;
end;

function TParser.ParseDataType: string;
begin
  Result := FTypeParser.ParseDataType;
end;

function TParser.ParseParamList: TParamInfoArray;
begin
  Result := FTypeParser.ParseParamList;
end;

function TParser.ParseGenericArgs: TStringArray;
begin
  Result := FTypeParser.ParseGenericArgs;
end;

 // Statement parsing delegated to FStmtParser

function TParser.ParseStatement: TASTNode;
begin
  Result := FStmtParser.ParseStatement;
end;

function TParser.ParseVarDecl: TASTNode;
begin
  Result := FStmtParser.ParseVarDecl;
end;

function TParser.ParseAssignment(Target: TExpr): TASTNode;
begin
  Result := FStmtParser.ParseAssignment(Target);
end;

function TParser.ParseIf: TASTNode;
begin
  Result := FStmtParser.ParseIf;
end;

function TParser.ParseDoWhile: TASTNode;
begin
  Result := FStmtParser.ParseDoWhile;
end;

function TParser.ParseWhile: TASTNode;
begin
  Result := FStmtParser.ParseWhile;
end;

function TParser.ParseFor: TASTNode;
begin
  Result := FStmtParser.ParseFor;
end;

function TParser.ParseForEach: TASTNode;
begin
  Result := FStmtParser.ParseForEach;
end;

function TParser.ParseReturn: TASTNode;
begin
  Result := FStmtParser.ParseReturn;
end;

function TParser.ParseYield: TASTNode;
begin
  Result := FStmtParser.ParseYield;
end;

function TParser.ParseLoopCtrl: TASTNode;
begin
  Result := FStmtParser.ParseLoopCtrl;
end;

function TParser.ParsePrint: TASTNode;
begin
  Result := FStmtParser.ParsePrint;
end;

function TParser.ParseMisc: TASTNode;
begin
  Result := FStmtParser.ParseMisc;
end;

// Top-level parsing delegated to FTopLevelParser

function TParser.ParseFunctionDef: TFunctionDef;
begin
  Result := FTopLevelParser.ParseFunctionDef;
end;

function TParser.ParseProcedureDef: TProcedureDef;
begin
  Result := FTopLevelParser.ParseProcedureDef;
end;

function TParser.ParseClassDef: TClassDef;
begin
  Result := FTopLevelParser.ParseClassDef;
end;

function TParser.ParseStructDef: TStructDef;
begin
  Result := FTopLevelParser.ParseStructDef;
end;

function TParser.ParseNewTypeDef: TNewTypeDef;
begin
  Result := FTopLevelParser.ParseNewTypeDef;
end;

function TParser.ParseTopLevel: TASTNode;
begin
  Result := FTopLevelParser.ParseTopLevel;
end;

function TParser.ParseProgram: TCompilationUnit;
begin
  Result := FTopLevelParser.ParseProgram;
end;

end.
