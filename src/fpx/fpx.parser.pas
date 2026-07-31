unit fpx.parser;

{$mode objfpc}{$H+}

interface

uses
  sysutils, classes, fpx.tokens, fpx.errors, fpx.ast, fpx.lexer;

type
  TParamInfo = record
    Name: string;
    Typ: string;
    IsRef: Boolean;
  end;

  TParamInfoArray = array of TParamInfo;

  TParser = class
  private
    FLexer: TLexer;
    FReporter: TErrorReporter;
    FCurrent: TToken;
    FPrevious: TToken;
    FLoopDepth: Integer;

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
    function ParseProgram: TCompilationUnit;
    property Current: TToken read FCurrent;
  end;

implementation

constructor TParser.Create(Lexer: TLexer; Reporter: TErrorReporter);
begin
  inherited Create;
  FLexer := Lexer;
  FReporter := Reporter;
  FLoopDepth := 0;
  FCurrent.TokenType := ttEof;
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
    ttInvalid, ttComment];
end;

procedure TParser.Match(TT: TTokenType);
begin
  if FCurrent.TokenType = TT then
    Advance
  else
      Error(FPX_UNEXPECTED_TOKEN, 'Expected ' + TokenTypeName(TT) + ' but got ' + DumpToken(FCurrent));
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
    Error(FPX_UNEXPECTED_TOKEN, Msg + ': expected ' + TokenTypeName(TT));
end;

procedure TParser.ConsumeKeyword(kw: TKeyword; const Msg: string);
begin
  if CheckKeyword(kw) then
    Advance
  else
    Error(FPX_UNEXPECTED_TOKEN, Msg + ': expected keyword ' + KeywordNames[kw]);
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

procedure TParser.Error(const Msg: string);
begin
  FReporter.ErrorFPX(FPX_SYNTAX_ERROR, Msg, FCurrent.Line, FCurrent.Col);
end;

procedure TParser.Error(Code: Integer; const Msg: string);
begin
  FReporter.ErrorFPX(Code, Msg, FCurrent.Line, FCurrent.Col);
end;

// Expression parsing (precedence climbing)

function TParser.ParseExpression: TExpr;
begin
  Result := ParseLogicalOr;
end;

function TParser.ParseLogicalOr: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseLogicalAnd;
  while (Peek in [ttDotOr]) or (Check(ttPipe) and (FCurrent.StrValue = '|')) do
  begin
    op := FCurrent.TokenType;
    Advance;
    left := TBinaryExpr.Create(left, op, ParseLogicalAnd, FCurrent.Line, FCurrent.Col);
  end;
  Result := left;
end;

function TParser.ParseLogicalAnd: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseNot;
  while Peek in [ttDotAnd] do
  begin
    op := FCurrent.TokenType;
    Advance;
    left := TBinaryExpr.Create(left, op, ParseNot, FCurrent.Line, FCurrent.Col);
  end;
  Result := left;
end;

function TParser.ParseNot: TExpr;
begin
  if Peek in [ttDotNot, ttNot] then
  begin
    Advance;
    Result := TUnaryExpr.Create(ttDotNot, ParseComparison, FCurrent.Line, FCurrent.Col);
  end
  else
    Result := ParseComparison;
end;

function TParser.ParseComparison: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseConcat;
  while Peek in [ttEq, ttNeq, ttNeq2, ttLt, ttLe, ttGt, ttGe, ttDollar, ttEqual] do
  begin
    op := FCurrent.TokenType;
    Advance;
    left := TBinaryExpr.Create(left, op, ParseConcat, FCurrent.Line, FCurrent.Col);
  end;
  Result := left;
end;

function TParser.ParseConcat: TExpr;
var
  left: TExpr;
begin
  left := ParseAddSub;
  while Check(ttPlus) or Check(ttMinus) do
  begin
    if (FCurrent.TokenType = ttPlus) and (FCurrent.StrValue = '+') then
    begin
      Advance;
      left := TBinaryExpr.Create(left, ttPlus, ParseAddSub, FCurrent.Line, FCurrent.Col);
    end
    else
      Break;
  end;
  Result := left;
end;

function TParser.ParseAddSub: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseMulDiv;
  while Peek in [ttPlus, ttMinus] do
  begin
    op := FCurrent.TokenType;
    Advance;
    left := TBinaryExpr.Create(left, op, ParseMulDiv, FCurrent.Line, FCurrent.Col);
  end;
  Result := left;
end;

function TParser.ParseMulDiv: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseUnary;
  while Peek in [ttStar, ttSlash, ttPercent] do
  begin
    op := FCurrent.TokenType;
    Advance;
    left := TBinaryExpr.Create(left, op, ParseUnary, FCurrent.Line, FCurrent.Col);
  end;
  Result := left;
end;

function TParser.ParseUnary: TExpr;
begin
  if Peek in [ttPlus, ttMinus] then
  begin
    Advance;
    Result := TUnaryExpr.Create(FPrevious.TokenType, ParsePower, FCurrent.Line, FCurrent.Col);
  end
  else
    Result := ParsePower;
end;

function TParser.ParsePower: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParsePrimary;
  while Peek in [ttStarStar, ttCaret] do
  begin
    op := FCurrent.TokenType;
    Advance;
    left := TBinaryExpr.Create(left, op, ParsePrimary, FCurrent.Line, FCurrent.Col);
  end;
  Result := left;
end;

function TParser.ParsePrimary: TExpr;
begin
  case Peek of
    ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil:
      begin
        Result := TLiteralExpr.Create(FCurrent);
        Advance;
      end;

    ttIdentifier:
      begin
        Result := TIdentifierExpr.Create(FCurrent.StrValue, FCurrent.Line, FCurrent.Col);
        Advance;

        // Struct literal or function call
        if Peek = ttLParen then
          Result := ParseCallOrIdent;

        // Member access
        while Peek = ttDot do
        begin
          Advance; // consume dot
          if Peek = ttIdentifier then
          begin
            Result := TMemberAccessExpr.Create(Result, FCurrent.StrValue,
              FCurrent.Line, FCurrent.Col);
            Advance;
          end
          else
            Error('Expected member name after dot');
        end;

        // Method call
        if Peek = ttColon then
        begin
          Advance; // consume ':'
          if Peek = ttIdentifier then
          begin
            Result := TMethodCallExpr.Create(Result, FCurrent.StrValue,
              FCurrent.Line, FCurrent.Col);
            Advance;

            // Handle '<' for generic args on methods
            if Peek = ttLParen then
            begin
              Advance; // consume '('
              while not Check(ttRParen) and not FLexer.EOF do
              begin
                TMethodCallExpr(Result).AddArg(ParseExpression);
                if Peek = ttComma then Advance;
              end;
              Consume(ttRParen, 'Expected ) after method arguments');
            end;
          end
          else
            Error('Expected method name after :');
        end;
      end;

    ttLParen:
      begin
        Advance;
        Result := ParseExpression;
        Consume(ttRParen, 'Expected ) after expression');
      end;

    ttLBrace:
      begin
        if Peek = ttPipe then
          Result := ParseCodeBlock
        else
        begin
          // Could be array literal or hash literal (or empty codeblock)
          Advance; // peek ahead
          if (Peek = ttRBrace) or (Peek = ttComma) or (Peek in [ttInteger, ttReal, ttString,
            ttKeyword, ttIdentifier, ttMinus, ttPlus, ttLBrace, ttLParen, ttAt, ttBitAnd,
            ttNot, ttDotNot]) then
            Result := ParseArrayLiteral
          else if Peek = ttPipe then
            Result := ParseCodeBlock
          else
          begin
            // Try hash
            if Peek in [ttInteger, ttString, ttIdentifier, ttKeyword] then
            begin
              // Check if it's hash by looking for '=>'
              // We'll try hash literal and fall back to array
              Result := ParseHashLiteral;
            end
            else
              Result := ParseArrayLiteral;
          end;
        end;
      end;

    ttMinus, ttPlus, ttNot, ttDotNot:
      begin
        Advance;
        Result := TUnaryExpr.Create(FPrevious.TokenType, ParsePrimary,
          FCurrent.Line, FCurrent.Col);
      end;

    ttBitAnd:
      begin
        Advance;
        if Peek = ttIdentifier then
        begin
          Result := TMacroExpr.Create(FCurrent.StrValue, FCurrent.Line, FCurrent.Col);
          Advance;
        end
        else if Peek = ttLParen then
        begin
          Advance; // '('
          Result := TMacroExpr.Create('', FCurrent.Line, FCurrent.Col);
          Consume(ttRParen, 'Expected ) after macro expression');
        end
        else
          Error('Expected identifier or (expr) after &');
      end;

    ttAt:
      begin
        Advance;
        if Peek = ttIdentifier then
        begin
          Result := TUnaryExpr.Create(ttAt,
            TIdentifierExpr.Create(FCurrent.StrValue, FCurrent.Line, FCurrent.Col),
            FCurrent.Line, FCurrent.Col);
          Advance;
        end
        else
          Error('Expected identifier after @');
      end;

    // Dereference: ^
    ttCaret:
      begin
        Advance;
        Result := TDerefExpr.Create(ParsePrimary, FCurrent.Line, FCurrent.Col);
      end;

    // Arrow
    ttArrow:
      begin
        Advance;
        if Peek = ttIdentifier then
        begin
          Result := TUnaryExpr.Create(ttArrow,
            TIdentifierExpr.Create('->' + FCurrent.StrValue, FCurrent.Line, FCurrent.Col),
            FCurrent.Line, FCurrent.Col);
          Advance;
        end;
      end;

    else
    begin
      Error(FPX_EXPECTED_EXPR, 'Expected expression, got ' + DumpToken(FCurrent));
      Result := TLiteralExpr.Create(FCurrent);
      Advance;
    end;
  end;
end;

function TParser.ParseCallOrIdent: TExpr;
var
  name: string;
  args: TExprArray;
  a: TExpr;
  savedLine, savedCol: Integer;
begin
  savedLine := FPrevious.Line;
  savedCol := FPrevious.Col;
  name := FPrevious.StrValue;

  // Check if it's a generic instantiation (Identifier '<' DataType '>')
  if Peek = ttLt then
  begin
    // Could be generic args or comparison operator
    // Simple heuristic: if followed by a type name, it's generic
    // For now, treat as comparison <
    Result := TIdentifierExpr.Create(name, savedLine, savedCol);
    Exit;
  end;

  // It's a function call
  if Peek <> ttLParen then
  begin
    // Not a call — it's just an identifier
    Result := TIdentifierExpr.Create(name, savedLine, savedCol);
    Exit;
  end;

  Advance; // consume '('
  args := ParseActualArgs;
  Consume(ttRParen, 'Expected ) after function arguments');

  Result := TCallExpr.Create(name, savedLine, savedCol);
  for a in args do
    TCallExpr(Result).AddArg(a);
end;

function TParser.ParseActualArgs: TExprArray;
var
  expr: TExpr;
begin
  Result := nil;
  if Peek = ttRParen then Exit;

  expr := ParseExpression;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := expr;

  while MatchAdvance(ttComma) do
  begin
    expr := ParseExpression;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := expr;
  end;
end;

function TParser.ParseArrayLiteral: TExpr;
var
  arr: TArrayLiteralExpr;
begin
  arr := TArrayLiteralExpr.Create(FCurrent.Line, FCurrent.Col);
  // FCurrent should be past '{' from the caller's advance
  // Actually, ParsePrimary handles the initial '{'
  // Let's rework: when we see '{', we peek forward

  // Simplified: consume '{' if not already consumed
  if Peek = ttLBrace then Advance;

  if Peek <> ttRBrace then
  begin
    arr.AddItem(ParseExpression);
    while MatchAdvance(ttComma) do
      arr.AddItem(ParseExpression);
  end;
  Consume(ttRBrace, 'Expected } in array literal');
  Result := arr;
end;

function TParser.ParseHashLiteral: TExpr;
var
  hash: THashLiteralExpr;
begin
  hash := THashLiteralExpr.Create(FCurrent.Line, FCurrent.Col);
  if Peek = ttLBrace then Advance; // consume '{'

  while Peek <> ttRBrace do
  begin
    // Try to parse key => value
    // For now, simplified
    Break;
  end;

  // Skip to '}' or error
  while (Peek <> ttRBrace) and (Peek <> ttEof) do Advance;
  if Peek = ttRBrace then Advance;
  Result := hash;
end;

function TParser.ParseCodeBlock: TExpr;
var
  cb: TCodeBlockExpr;
begin
  cb := TCodeBlockExpr.Create(FCurrent.Line, FCurrent.Col);
  if Peek = ttLBrace then Advance; // consume '{'

  if Peek = ttPipe then
  begin
    Advance; // consume '|'
    while Peek <> ttPipe do
    begin
      if Peek = ttIdentifier then
      begin
        cb.AddParam(FCurrent.StrValue);
        Advance;
        if Peek = ttComma then Advance;
      end
      else
        Break;
    end;
    if Peek = ttPipe then Advance; // consume '|'
  end;

  // Parse statements (simplified — just expression)
  while (Peek <> ttRBrace) and (Peek <> ttEof) do
  begin
    if Peek in [ttNewline, ttSemicolon] then
      Advance
    else
    begin
      cb.AddStatement(ParseStatement);
      if Peek in [ttNewline, ttSemicolon] then Advance;
    end;
  end;

  if Peek = ttRBrace then Advance; // consume '}'
  Result := cb;
end;

function TParser.ParseDataType: string;
begin
  if Peek in [ttIdentifier, ttKeyword] then
  begin
    if Peek = ttKeyword then
      Result := KeywordNames[FCurrent.Keyword]
    else
      Result := FCurrent.StrValue;
    Advance;

    // Generic args: Type<T, U>
    if Peek = ttLt then
    begin
      Result := Result + '<';
      Advance;
      Result := Result + ParseDataType;
      while Peek = ttComma do
      begin
        Result := Result + ',';
        Advance;
        Result := Result + ParseDataType;
      end;
      if Peek = ttGt then
      begin
        Result := Result + '>';
        Advance;
      end;
    end;
  end
  else
    Result := '';
end;

function TParser.ParseTypeRef: string;
begin
  Result := '';
  if MatchKeyword(kwArray) then
  begin
    if MatchKeyword(kwOf) then
      Result := 'ARRAY OF ' + ParseDataType
    else
      Result := 'ARRAY';
  end
  else
    Result := ParseDataType;
end;

function TParser.ParseParamList: TParamInfoArray;
begin
  Result := nil;
  if Peek <> ttLParen then Exit;
  Advance; // '('
  if Peek = ttRParen then
  begin
    Advance;
    Exit;
  end;
  repeat
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].IsRef := False;
    if MatchKeyword(kwRef) then
      Result[High(Result)].IsRef := True;
    if Peek = ttIdentifier then
    begin
      Result[High(Result)].Name := FCurrent.StrValue;
      Advance;
      if Peek = ttColon then
      begin
        Advance; // ':'
        Result[High(Result)].Typ := ParseTypeRef;
      end
      else if MatchKeyword(kwAs) then
        Result[High(Result)].Typ := ParseTypeRef;
      if Peek = ttComma then Advance;
    end
    else
      Error(FPX_EXPECTED_IDENT, 'Expected parameter name');
  until Peek = ttRParen;
  Consume(ttRParen, 'Expected ) after parameters');
end;

function TParser.ParseGenericArgs: TStringArray;
begin
  Result := nil;
  if Peek = ttLt then
  begin
    Advance;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ParseDataType;
    while Peek = ttComma do
    begin
      Advance;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := ParseDataType;
    end;
    if Peek = ttGt then Advance;
  end;
end;

// Statement parsing

function TParser.ParseStatement: TASTNode;
begin
  case Peek of
    ttKeyword:
      begin
        case FCurrent.Keyword of
          kwLocal, kwPrivate, kwPublic, kwStatic: Exit(ParseVarDecl);
          kwIf: Exit(ParseIf);
          kwDo: Exit(ParseDoWhile);
          kwWhile: Exit(ParseWhile);
          kwFor: Exit(ParseFor);
          kwForEach: Exit(ParseForEach);
          kwReturn: Exit(ParseReturn);
          kwYield: Exit(ParseYield);
          kwLoop, kwExit, kwBreak: Exit(ParseLoopCtrl);
          kwTry: ;
          kwSwitch: ;
          kwWith: ;
          kwBegin: ;
          kwText: ;
          kwUse, kwSelect, kwSeek, kwSkip, kwGo, kwGoto: Exit(ParseMisc);
          kwLocate, kwContinue, kwAppend, kwReplace: Exit(ParseMisc);
          kwDelete, kwRecall, kwPack, kwZap, kwSort: Exit(ParseMisc);
          kwAverage, kwSum, kwCount, kwTotal: Exit(ParseMisc);
          kwCopy, kwReport, kwLabel, kwCreate: Exit(ParseMisc);
          kwOpen, kwClose, kwSet: Exit(ParseMisc);
          kwCommit, kwFlush, kwRun, kwCall: Exit(ParseMisc);
          kwQuit, kwCancel, kwAnnounce: Exit(ParseMisc);
          kwRequest, kwExternal, kwStore: Exit(ParseMisc);
          kwDeclare, kwDefine, kwKeyboard, kwType: Exit(ParseMisc);
          kwEject, kwInput, kwAccept, kwWait: Exit(ParseMisc);
          kwSay, kwGet, kwRead: Exit(ParseMisc);
          kwActivate, kwDeactivate, kwHide, kwShow: Exit(ParseMisc);
          kwMenu, kwPrompt: Exit(ParseMisc);
          kwClass, kwFunction, kwProcedure: Exit(ParseTopLevel);
          kwStruct: Exit(ParseStructDef);
          kwNewType: Exit(ParseNewTypeDef);
          else
            Error('Unexpected keyword ' + KeywordNames[FCurrent.Keyword]);
            Advance;
            Exit(nil);
        end;
      end;

    ttIdentifier, ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil,
    ttLParen, ttLBrace, ttPlus, ttMinus, ttNot, ttDotNot,
    ttBitAnd, ttAt, ttCaret:
      begin
        Result := ParseAssignment(nil);
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
      Error('Unexpected token in statement: ' + DumpToken(FCurrent));
      Result := nil;
      Advance;
    end;
  end;

  // Skip trailing newlines
end;

function TParser.ParseVarDecl: TASTNode;
var
  scope: string;
  decl: TVarDeclStmt;
  name, typ: string;
  initVal: TExpr;
begin
  scope := KeywordNames[FCurrent.Keyword];
  Advance; // consume LOCAL/PRIVATE/PUBLIC/STATIC
  decl := TVarDeclStmt.Create(scope, FCurrent.Line, FCurrent.Col);

  repeat
    if Peek <> ttIdentifier then
    begin
      Error(FPX_EXPECTED_IDENT, 'Expected variable name in ' + scope + ' declaration');
      Break;
    end;

    name := FCurrent.StrValue;
    Advance; // consume identifier

    typ := '';
    if Peek = ttColon then
    begin
      Advance; // consume ':'
      typ := ParseTypeRef;
    end
    else if MatchKeyword(kwAs) then
      typ := ParseTypeRef;

    initVal := nil;
    if Peek = ttAssign then
    begin
      Advance; // consume ':='
      initVal := ParseExpression;
    end;

    decl.AddVar(name, typ, initVal);

    if Peek <> ttComma then Break;
    Advance; // consume ','
  until False;

  Result := decl;
end;

function TParser.ParseAssignment(Target: TExpr): TASTNode;
var
  expr: TExpr;
  op: TTokenType;
begin
  if Target = nil then
  begin
    expr := ParseExpression;
    Target := expr;
  end
  else
    Target := ParseExpression;

  // Check for assignment operator
  if Peek in [ttAssign, ttPlusAssign, ttMinusAssign, ttStarAssign,
    ttSlashAssign, ttPercentAssign, ttCaretAssign] then
  begin
    op := FCurrent.TokenType;
    Advance;
    Result := TAssignStmt.Create(Target, op, ParseExpression, FCurrent.Line, FCurrent.Col);
  end
  else
    Result := TExprStmt.Create(Target, FCurrent.Line, FCurrent.Col);
end;

function TParser.ParseIf: TASTNode;
var
  stmt: TIfStmt;
  cond: TExpr;
begin
  ConsumeKeyword(kwIf, 'Expected IF');
  cond := ParseExpression;
  stmt := TIfStmt.Create(cond, FCurrent.Line, FCurrent.Col);

  // Skip to statement body
   // Then body
  while not CheckKeyword(kwElseIf) and not CheckKeyword(kwElse)
    and not CheckKeyword(kwEndIf) and not CheckKeyword(kwEnd)
    and (Peek <> ttEof) do
  begin
    stmt.AddThenStmt(ParseStatement);
  end;

  // ElseIf branches
  while CheckKeyword(kwElseIf) do
  begin
    Advance; // ELSEIF
    cond := ParseExpression;
stmt.AddElseIf(cond);
     while not CheckKeyword(kwElseIf) and not CheckKeyword(kwElse)
       and not CheckKeyword(kwEndIf) and not CheckKeyword(kwEnd)
       and (Peek <> ttEof) do
    begin
      stmt.AddElseIfStmt(ParseStatement);
    end;
  end;

  // Else
  if CheckKeyword(kwElse) then
  begin
    Advance; // ELSE
    while not CheckKeyword(kwEndIf) and not CheckKeyword(kwEnd)
      and (Peek <> ttEof) do
    begin
      stmt.AddElseStmt(ParseStatement);
    end;
  end;

  // ENDIF or END
  if CheckKeyword(kwEndIf) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FPX_UNTERMINATED_BLOCK, 'Expected ENDIF or END to close IF');

  Result := stmt;
end;

function TParser.ParseDoWhile: TASTNode;
var
  whileStmt: TWhileStmt;
  cond: TExpr;
begin
  ConsumeKeyword(kwDo, 'Expected DO');
  ConsumeKeyword(kwWhile, 'Expected WHILE after DO');
  cond := ParseExpression;
  whileStmt := TWhileStmt.Create(cond, FCurrent.Line, FCurrent.Col);

  while not CheckKeyword(kwEndDo) and not CheckKeyword(kwEnd)
    and not CheckKeyword(kwLoop) and (Peek <> ttEof) do
  begin
    whileStmt.AddStmt(ParseStatement);
  end;

  // Consume LOOP/EXIT handled in parse loop ctrl

  if CheckKeyword(kwEndDo) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FPX_UNTERMINATED_BLOCK, 'Expected ENDDO or END to close DO WHILE');

  Result := whileStmt;
end;

function TParser.ParseWhile: TASTNode;
var
  whileStmt: TWhileStmt;
  cond: TExpr;
begin
  ConsumeKeyword(kwWhile, 'Expected WHILE');
  cond := ParseExpression;
  whileStmt := TWhileStmt.Create(cond, FCurrent.Line, FCurrent.Col);

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
    Error(FPX_UNTERMINATED_BLOCK, 'Expected END to close WHILE');

  Result := whileStmt;
end;

function TParser.ParseFor: TASTNode;
var
  forStmt: TForStmt;
  varName: string;
  start, finish: TExpr;
begin
  ConsumeKeyword(kwFor, 'Expected FOR');
  if Peek = ttIdentifier then
    varName := FCurrent.StrValue
  else
  begin
    Error(FPX_EXPECTED_IDENT, 'Expected loop variable after FOR');
    Exit(TForStmt.Create('', nil, nil, FCurrent.Line, FCurrent.Col));
  end;
  Advance;

  Consume(ttAssign, 'Expected := after loop variable');

  start := ParseExpression;

  if CheckKeyword(kwTo) then
    Advance
  else if CheckKeyword(kwDownTo) then
    Advance
  else
  begin
    Error('Expected TO or DOWNTO in FOR loop');
    Exit(TForStmt.Create(varName, start, nil, FCurrent.Line, FCurrent.Col));
  end;

  finish := ParseExpression;
  forStmt := TForStmt.Create(varName, start, finish, FCurrent.Line, FCurrent.Col);

  if CheckKeyword(kwStep) then
  begin
    Advance;
    forStmt.SetStep(ParseExpression);
  end;

  Inc(FLoopDepth);
  while not CheckKeyword(kwNext) and not CheckKeyword(kwEnd)
    and (Peek <> ttEof) do
  begin
    if CheckKeyword(kwLoop) or CheckKeyword(kwExit) then
      forStmt.AddStmt(ParseLoopCtrl)
    else
      forStmt.AddStmt(ParseStatement);
  end;
  Dec(FLoopDepth);

  if CheckKeyword(kwNext) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FPX_UNTERMINATED_BLOCK, 'Expected NEXT or END to close FOR');

  Result := forStmt;
end;

function TParser.ParseForEach: TASTNode;
begin
  // Stub
  ConsumeKeyword(kwForEach, 'Expected FOREACH');
  // Skip to NEXT
  while not CheckKeyword(kwNext) and not CheckKeyword(kwEnd)
    and (Peek <> ttEof) do
    ParseStatement;
  if CheckKeyword(kwNext) then Advance;
  Result := nil;
end;

function TParser.ParseReturn: TASTNode;
begin
  ConsumeKeyword(kwReturn, 'Expected RETURN');
  // Bare RETURN if next token cannot start an expression
  if not (Peek in [ttIdentifier, ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil,
       ttLParen, ttLBrace, ttPlus, ttMinus, ttNot, ttDotNot, ttBitAnd, ttAt, ttCaret]) then
    Result := TReturnStmt.Create(FPrevious.Line, FPrevious.Col)
  else
    Result := TReturnStmt.CreateWithValue(ParseExpression, FPrevious.Line, FPrevious.Col);
end;

function TParser.ParseYield: TASTNode;
begin
  ConsumeKeyword(kwYield, 'Expected YIELD');
  Result := TYieldStmt.Create(ParseExpression, FPrevious.Line, FPrevious.Col);
end;

function TParser.ParseLoopCtrl: TASTNode;
var
  kind: string;
begin
  kind := KeywordNames[FCurrent.Keyword];
  Advance;
    if FLoopDepth = 0 then
      FReporter.WarningFPW(FPW_LEGACY_COMMAND, kind + ' outside a loop', FCurrent.Line, FCurrent.Col);
  Result := TLoopCtrlStmt.Create(kind, FCurrent.Line, FCurrent.Col);
end;

function TParser.ParseMisc: TASTNode;
var
  kw: TKeyword;
begin
  kw := FCurrent.Keyword;
  Advance; // consume the keyword
  // Skip to end of statement (newline or semicolon or EOF)
  while not (Peek in [ttNewline, ttEof, ttSemicolon]) do
    Advance;
  // Skip the terminating char
  if Peek in [ttNewline, ttSemicolon] then Advance;
  Result := nil;
end;

// Top-level parsing

function TParser.ParseFunctionDef: TFunctionDef;
var
  isStatic: Boolean;
  name: string;
  func: TFunctionDef;
  typ: string;
  p: TParamInfo;
begin
  isStatic := False;
  if MatchKeyword(kwStatic) then isStatic := True;
  ConsumeKeyword(kwFunction, 'Expected FUNCTION');

  if Peek = ttIdentifier then
    name := FCurrent.StrValue
  else
  begin
    Error(FPX_EXPECTED_IDENT, 'Expected function name');
    name := '__missing__';
  end;
  Advance;

  func := TFunctionDef.Create(name, isStatic, FCurrent.Line, FCurrent.Col);

  // Generic params
  if Peek = ttLt then
    ParseGenericArgs;

  // Formal params
  if Peek = ttLParen then
  begin
    for p in ParseParamList do
      func.AddParam(p.Name, p.Typ, nil, p.IsRef);
  end;

  // Return type
  if MatchKeyword(kwAs) then
  begin
    typ := ParseDataType;
    func.SetReturnType(typ);
  end;

  // Body
  while not CheckKeyword(kwEndFunc) and not CheckKeyword(kwEndFunction)
    and not CheckKeyword(kwEnd) and (Peek <> ttEof) do
  begin
    func.AddStmt(ParseStatement);
  end;

  if CheckKeyword(kwEndFunc) or CheckKeyword(kwEndFunction) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FPX_UNTERMINATED_BLOCK, 'Expected ENDFUNC to close FUNCTION');

  Result := func;
end;

function TParser.ParseProcedureDef: TProcedureDef;
var
  isStatic: Boolean;
  name: string;
  proc: TProcedureDef;
  p: TParamInfo;
begin
  isStatic := False;
  if MatchKeyword(kwStatic) then isStatic := True;
  ConsumeKeyword(kwProcedure, 'Expected PROCEDURE');

  if Peek = ttIdentifier then
    name := FCurrent.StrValue
  else
  begin
    Error(FPX_EXPECTED_IDENT, 'Expected procedure name');
    name := '__missing__';
  end;
  Advance;

  proc := TProcedureDef.Create(name, isStatic, FCurrent.Line, FCurrent.Col);

  if Peek = ttLt then
    ParseGenericArgs;

  if Peek = ttLParen then
  begin
    for p in ParseParamList do
      proc.AddParam(p.Name, p.Typ, nil, p.IsRef);
  end;

  while not CheckKeyword(kwEndProc) and not CheckKeyword(kwEndProcedure)
    and not CheckKeyword(kwEnd) and (Peek <> ttEof) do
  begin
    proc.AddStmt(ParseStatement);
  end;

  if CheckKeyword(kwEndProc) or CheckKeyword(kwEndProcedure) then
    Advance
  else if CheckKeyword(kwEnd) then
    Advance
  else
    Error(FPX_UNTERMINATED_BLOCK, 'Expected ENDPROC to close PROCEDURE');

  Result := proc;
end;

function TParser.ParseClassDef: TClassDef;
var
  name: string;
  cls: TClassDef;
begin
  ConsumeKeyword(kwClass, 'Expected CLASS');
  if Peek = ttIdentifier then
  begin
    name := FCurrent.StrValue;
    Advance;
  end
  else
  begin
    Error(FPX_EXPECTED_IDENT, 'Expected class name');
    name := '__missing__';
  end;

  cls := TClassDef.Create(name, FCurrent.Line, FCurrent.Col);

  if Peek = ttLt then
    ParseGenericArgs;

  if MatchKeyword(kwFrom) then
  begin
    while Peek = ttIdentifier do
    begin
      cls.AddParent(FCurrent.StrValue);
      Advance;
      if Peek = ttComma then Advance else Break;
    end;
  end;

  // Skip until ENDCLASS
  while not CheckKeyword(kwEndClass) and (Peek <> ttEof) do
    ParseStatement;

  ConsumeKeyword(kwEndClass, 'Expected ENDCLASS');
  Result := cls;
end;

function TParser.ParseStructDef: TStructDef;
var
  name: string;
  struct: TStructDef;
begin
  ConsumeKeyword(kwStruct, 'Expected STRUCT');
  if Peek = ttIdentifier then
  begin
    name := FCurrent.StrValue;
    Advance;
  end
  else
  begin
    Error(FPX_EXPECTED_IDENT, 'Expected struct name');
    name := '__missing__';
  end;

  struct := TStructDef.Create(name, FCurrent.Line, FCurrent.Col);
  if Peek = ttLt then ParseGenericArgs;

  // ALIGN(n)
  if MatchKeyword(kwAlign) then
  begin
    if Peek = ttLParen then
    begin
      Advance;
      if Peek = ttInteger then Advance;
      if Peek = ttRParen then Advance;
    end;
  end;

  // Skip members
  while not CheckKeyword(kwEndStruct) and (Peek <> ttEof) do
  begin
    if Peek = ttIdentifier then
    begin
      // member name
      Advance;
      if Peek = ttColon then
      begin
        Advance;
        ParseDataType; // consume type
      end;
      // Skip until newline
      while not (Peek in [ttNewline, ttSemicolon, ttEof]) do Advance;
    end
    else if Peek = ttNewline then
      Advance
    else
      Advance;
  end;

  ConsumeKeyword(kwEndStruct, 'Expected ENDSTRUCT');
  Result := struct;
end;

function TParser.ParseNewTypeDef: TNewTypeDef;
var
  name, baseType: string;
begin
  ConsumeKeyword(kwNewType, 'Expected NEWTYPE');
  if Peek = ttIdentifier then
  begin
    name := FCurrent.StrValue;
    Advance;
  end
  else
  begin
    Error(FPX_EXPECTED_IDENT, 'Expected type name');
    name := '__missing__';
  end;

  if Peek = ttLt then ParseGenericArgs;
  Consume(ttEqual, 'Expected = after NEWTYPE name');

  baseType := ParseDataType;
  if baseType = '' then
    Error('Expected base type in NEWTYPE');

  ConsumeKeyword(kwEndNewType, 'Expected ENDNEWTYPE');
  Result := TNewTypeDef.Create(name, baseType, FCurrent.Line, FCurrent.Col);
end;

function TParser.ParseTopLevel: TASTNode;
begin
  case Peek of
    ttKeyword:
      case FCurrent.Keyword of
        kwFunction: Result := ParseFunctionDef;
        kwProcedure: Result := ParseProcedureDef;
        kwClass: Result := ParseClassDef;
        kwStruct: Result := ParseStructDef;
        kwNewType: Result := ParseNewTypeDef;
        kwStatic:
          begin
            Advance;
            if CheckKeyword(kwFunction) then
              Result := ParseFunctionDef
            else if CheckKeyword(kwProcedure) then
              Result := ParseProcedureDef
            else
            begin
              Error('Expected FUNCTION or PROCEDURE after STATIC');
              Result := nil;
            end;
          end;
        else
        begin
          Result := ParseStatement;
        end;
      end;
    else
    begin
      Result := ParseStatement;
    end;
  end;
end;

function TParser.ParseProgram: TCompilationUnit;
var
  prog: TCompilationUnit;
  node: TASTNode;
begin
  prog := TCompilationUnit.Create(1, 1);

  if FCurrent.TokenType = ttEof then
    Advance;

  while Peek <> ttEof do
  begin
    // Skip leading newlines
    while Peek = ttNewline do Advance;

    if Peek = ttEof then Break;

    node := ParseTopLevel;
    if node <> nil then
      prog.AddNode(node);

    // Skip trailing newlines
    while Peek = ttNewline do Advance;
  end;

  Result := prog;
end;

end.
