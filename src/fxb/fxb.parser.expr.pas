unit fxb.parser.expr;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}

interface

uses
  SysUtils,
  Classes,
  fxb.tokens,
  fxb.errors,
  fxb.ast,
  fxb.lexer,
  fxb.parser.context,
  fxb.parser.types;

type
  TExprParser = class
  private
    FCtx: IParserContext;
    function LooksLikeGenericArgs: Boolean;
    function ConsumeGenericArgsString: string;
    function ParseStructLiteral(const ATypeName: string; ALine, ACol: Integer): TExpr;
  public
    constructor Create(const ACtx: IParserContext);
    // Expression parsing (precedence climbing)
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
    function ParseActualArgs: TExprArray;
    function ParseArrayLiteral: TExpr;
    function ParseHashLiteral: TExpr;
    function ParseCodeBlock: TExpr;
  end;

implementation

constructor TExprParser.Create(const ACtx: IParserContext);
begin
  inherited Create;
  FCtx := ACtx;
end;

{ Expression parsing (precedence climbing) }

function TExprParser.ParseExpression: TExpr;
var
  left: TExpr;
begin
  left := ParseLogicalOr;
  while FCtx.Peek = ttQuestionColon do
  begin
    FCtx.Advance;
    left := TBinaryExpr.Create(left, ttQuestionColon, ParseLogicalOr,
      FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParseLogicalOr: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseLogicalAnd;
  while (FCtx.Peek in [ttDotOr]) or (FCtx.Check(ttPipe) and (FCtx.GetCurrent.StrValue = '|')) do
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    left := TBinaryExpr.Create(left, op, ParseLogicalAnd, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParseLogicalAnd: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseNot;
  while FCtx.Peek in [ttDotAnd] do
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    left := TBinaryExpr.Create(left, op, ParseNot, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParseNot: TExpr;
begin
  if FCtx.Peek in [ttDotNot, ttNot] then
  begin
    FCtx.Advance;
    Result := TUnaryExpr.Create(ttDotNot, ParseComparison, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end
  else if FCtx.CheckKeyword(kwNot) then
  begin
    FCtx.Advance;
    Result := TUnaryExpr.Create(ttDotNot, ParseComparison, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end
  else
    Result := ParseComparison;
end;

function TExprParser.ParseComparison: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseConcat;
  while FCtx.Peek in [ttEq, ttNeq, ttNeq2, ttLt, ttLe, ttGt, ttGe, ttDollar, ttEqual] do
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    left := TBinaryExpr.Create(left, op, ParseConcat, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParseConcat: TExpr;
var
  left: TExpr;
begin
  left := ParseAddSub;
  while FCtx.Check(ttPlus) or FCtx.Check(ttMinus) do
  begin
    if (FCtx.GetCurrent.TokenType = ttPlus) and (FCtx.GetCurrent.StrValue = '+') then
    begin
      FCtx.Advance;
      left := TBinaryExpr.Create(left, ttPlus, ParseAddSub, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
    end
    else
      Break;
  end;
  Result := left;
end;

function TExprParser.ParseAddSub: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseMulDiv;
  while FCtx.Peek in [ttPlus, ttMinus] do
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    left := TBinaryExpr.Create(left, op, ParseMulDiv, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParseMulDiv: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParseUnary;
  while FCtx.Peek in [ttStar, ttSlash, ttPercent] do
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    left := TBinaryExpr.Create(left, op, ParseUnary, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParseUnary: TExpr;
begin
  if FCtx.Peek in [ttPlus, ttMinus] then
  begin
    FCtx.Advance;
    Result := TUnaryExpr.Create(FCtx.GetPrevious.TokenType, ParsePower, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end
  else
    Result := ParsePower;
end;

function TExprParser.ParsePower: TExpr;
var
  left: TExpr;
  op: TTokenType;
begin
  left := ParsePrimary;
  while FCtx.Peek in [ttStarStar, ttCaret] do
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    left := TBinaryExpr.Create(left, op, ParsePrimary, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end;
  Result := left;
end;

function TExprParser.ParsePrimary: TExpr;
var
  savedName: string;
  savedLine, savedCol: Integer;
  isKeywordIdent: Boolean;
begin
  case FCtx.Peek of
    ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil:
      begin
        Result := TLiteralExpr.Create(FCtx.GetCurrent);
        FCtx.Advance;
      end;

    ttIdentifier, ttKeyword:
      begin
        // Keyword literals: TRUE / FALSE / NULL / NIL
        if FCtx.GetCurrent.Keyword in [kwTrue, kwFalse, kwNull, kwNil] then
        begin
          Result := TLiteralExpr.Create(FCtx.GetCurrent);
          FCtx.Advance;
          Exit;
        end;

        savedName := FCtx.GetCurrent.StrValue;
        savedLine := FCtx.GetCurrent.Line;
        savedCol := FCtx.GetCurrent.Col;
        isKeywordIdent := (FCtx.Peek = ttKeyword);
        FCtx.Advance;

        // Generic type args: Ident<T, U>
        if FCtx.Peek = ttLt then
        begin
          if isKeywordIdent or LooksLikeGenericArgs then
            savedName := savedName + ConsumeGenericArgsString;
        end;

        // Struct/class literal: Ident{...} or Ident<T>{...}
        if FCtx.Peek = ttLBrace then
        begin
          Result := ParseStructLiteral(savedName, savedLine, savedCol);
          Exit;
        end;

        Result := TIdentifierExpr.Create(savedName, savedLine, savedCol);

        // Function call: Ident(...)
        if FCtx.Peek = ttLParen then
          Result := ParseCallOrIdent;

        // Postfix chain: [index], .member, ?.member, :method
        while True do
        begin
          case FCtx.Peek of
            ttLBracket:
              begin
                FCtx.Advance;
                Result := TIndexExpr.Create(Result, ParseExpression,
                  FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
                FCtx.Consume(ttRBracket, 'Expected ] after index');
              end;

            ttDot, ttQuestionDot:
              begin
                FCtx.Advance;
                if FCtx.Peek in [ttIdentifier, ttKeyword] then
                begin
                  savedName := FCtx.GetCurrent.StrValue;
                  savedLine := FCtx.GetCurrent.Line;
                  savedCol := FCtx.GetCurrent.Col;
                  FCtx.Advance;
                  if FCtx.Peek = ttLParen then
                  begin
                    FCtx.Advance;
                    Result := TMethodCallExpr.Create(Result, savedName, savedLine, savedCol);
                    while not FCtx.Check(ttRParen) and not FCtx.GetLexer.EOF do
                    begin
                      TMethodCallExpr(Result).AddArg(ParseExpression);
                      if FCtx.Peek = ttComma then FCtx.Advance;
                    end;
                    FCtx.Consume(ttRParen, 'Expected ) after method arguments');
                  end
                  else
                    Result := TMemberAccessExpr.Create(Result, savedName, savedLine, savedCol);
                end
                else
                  FCtx.Error('Expected member name after .');
              end;

            ttColon:
              begin
                FCtx.Advance; // consume ':'
                if FCtx.Peek in [ttIdentifier, ttKeyword] then
                begin
                  savedName := FCtx.GetCurrent.StrValue;
                  savedLine := FCtx.GetCurrent.Line;
                  savedCol := FCtx.GetCurrent.Col;
                  FCtx.Advance;
                  Result := TMethodCallExpr.Create(Result, savedName, savedLine, savedCol);
                  if FCtx.Peek = ttLParen then
                  begin
                    FCtx.Advance;
                    while not FCtx.Check(ttRParen) and not FCtx.GetLexer.EOF do
                    begin
                      TMethodCallExpr(Result).AddArg(ParseExpression);
                      if FCtx.Peek = ttComma then FCtx.Advance;
                    end;
                    FCtx.Consume(ttRParen, 'Expected ) after method arguments');
                  end;
                end
                else
                  FCtx.Error('Expected method name after :');
              end;

            else
              Break;
          end;
        end;
      end;

    ttLParen:
      begin
        FCtx.Advance;
        Result := ParseExpression;
        FCtx.Consume(ttRParen, 'Expected ) after expression');
      end;

    ttLBrace:
      begin
        if FCtx.Peek = ttPipe then
          Result := ParseCodeBlock
        else
        begin
          // Could be array literal or hash literal (or empty codeblock)
          FCtx.Advance; // peek ahead
          if (FCtx.Peek = ttRBrace) or (FCtx.Peek = ttComma) or (FCtx.Peek in [ttInteger, ttReal, ttString,
            ttKeyword, ttIdentifier, ttMinus, ttPlus, ttLBrace, ttLParen, ttAt, ttBitAnd,
            ttNot, ttDotNot]) then
            Result := ParseArrayLiteral
          else if FCtx.Peek = ttPipe then
            Result := ParseCodeBlock
          else
          begin
            // Try hash
            if FCtx.Peek in [ttInteger, ttString, ttIdentifier, ttKeyword] then
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
        FCtx.Advance;
        Result := TUnaryExpr.Create(FCtx.GetPrevious.TokenType, ParsePrimary,
          FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
      end;

    ttBitAnd:
      begin
        FCtx.Advance;
        if FCtx.Peek = ttIdentifier then
        begin
          Result := TMacroExpr.Create(FCtx.GetCurrent.StrValue, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
          FCtx.Advance;
        end
        else if FCtx.Peek = ttLParen then
        begin
          FCtx.Advance; // '('
          Result := TMacroExpr.Create('', FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
          FCtx.Consume(ttRParen, 'Expected ) after macro expression');
        end
        else
          FCtx.Error('Expected identifier or (expr) after &');
      end;

    ttAt:
      begin
        FCtx.Advance;
        if FCtx.Peek = ttIdentifier then
        begin
          Result := TUnaryExpr.Create(ttAt,
            TIdentifierExpr.Create(FCtx.GetCurrent.StrValue, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col),
            FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
          FCtx.Advance;
        end
        else
          FCtx.Error('Expected identifier after @');
      end;

    // Dereference: ^
    ttCaret:
      begin
        FCtx.Advance;
        Result := TDerefExpr.Create(ParsePrimary, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
      end;

    // Arrow
    ttArrow:
      begin
        FCtx.Advance;
        if FCtx.Peek = ttIdentifier then
        begin
          Result := TUnaryExpr.Create(ttArrow,
            TIdentifierExpr.Create('->' + FCtx.GetCurrent.StrValue, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col),
            FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
          FCtx.Advance;
        end;
      end;

    else
    begin
      FCtx.Error(FXB_EXPECTED_EXPR, 'Expected expression, got ' + DumpToken(FCtx.GetCurrent));
      Result := TLiteralExpr.Create(FCtx.GetCurrent);
      FCtx.Advance;
    end;
  end;
end;

function TExprParser.LooksLikeGenericArgs: Boolean;
var
  depth: Integer;
  i: Integer;
begin
  Result := False;
  i := 1;
  depth := 1;
  while depth > 0 do
  begin
    case FCtx.PeekToken(i).TokenType of
      ttLt: Inc(depth);
      ttGt: Dec(depth);
      ttEOF: Exit;
      ttComma: ;
    end;
    Inc(i);
  end;
  Result := (FCtx.PeekToken(i).TokenType in [ttIdentifier, ttKeyword]);
end;

function TExprParser.ConsumeGenericArgsString: string;
var
  depth: Integer;
  part: string;
begin
  Result := '';
  FCtx.Advance; // consume '<'
  Result := Result + '<';
  depth := 1;
  while depth > 0 do
  begin
    if FCtx.Peek in [ttLt, ttGt] then
    begin
      if FCtx.Peek = ttLt then Inc(depth) else Dec(depth);
      if FCtx.Peek = ttGt then Result := Result + '>' else Result := Result + '<';
      FCtx.Advance;
    end
    else if FCtx.Peek in [ttIdentifier, ttKeyword] then
    begin
      part := FCtx.GetCurrent.StrValue;
      FCtx.Advance;
      if FCtx.Peek = ttDot then
      begin
        FCtx.Advance;
        part := part + '.' + FCtx.GetCurrent.StrValue;
        FCtx.Advance;
      end;
      Result := Result + part;
    end
    else if FCtx.Peek = ttComma then
    begin
      Result := Result + ',';
      FCtx.Advance;
    end
    else
    begin
      FCtx.Error(FXB_UNEXPECTED_TOKEN, 'Expected type inside < >');
      FCtx.Advance;
    end;
  end;
end;

function TExprParser.ParseStructLiteral(const ATypeName: string; ALine, ACol: Integer): TExpr;
begin
  Result := TStructLiteralExpr.Create(ATypeName, ALine, ACol);
  FCtx.Advance; // consume '{'
  if FCtx.Peek <> ttRBrace then
  begin
    repeat
      TStructLiteralExpr(Result).AddArg(ParseExpression);
      if FCtx.Peek = ttComma then FCtx.Advance;
    until FCtx.Peek = ttRBrace;
  end;
  FCtx.Consume(ttRBrace, 'Expected } after struct literal');
end;

function TExprParser.ParseCallOrIdent: TExpr;
var
  name: string;
  args: TExprArray;
  a: TExpr;
  savedLine, savedCol: Integer;
begin
  savedLine := FCtx.GetPrevious.Line;
  savedCol := FCtx.GetPrevious.Col;
  name := FCtx.GetPrevious.StrValue;
  // It's a function call
  if FCtx.Peek <> ttLParen then
  begin
    // Not a call — it's just an identifier
    Result := TIdentifierExpr.Create(name, savedLine, savedCol);
    Exit;
  end;

  FCtx.Advance; // consume '('
  args := ParseActualArgs;
  FCtx.Consume(ttRParen, 'Expected ) after function arguments');

  Result := TCallExpr.Create(name, savedLine, savedCol);
  for a in args do
    TCallExpr(Result).AddArg(a);
end;

function TExprParser.ParseActualArgs: TExprArray;
var
  expr: TExpr;
begin
  Result := nil;
  if FCtx.Peek = ttRParen then Exit;

  expr := ParseExpression;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := expr;

  while FCtx.MatchAdvance(ttComma) do
  begin
    expr := ParseExpression;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := expr;
  end;
end;

function TExprParser.ParseArrayLiteral: TExpr;
var
  arr: TArrayLiteralExpr;
begin
  arr := TArrayLiteralExpr.Create(FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  // FCurrent should be past '{' from the caller's advance
  // Actually, ParsePrimary handles the initial '{'
  // Let's rework: when we see '{', we peek forward

  // Simplified: consume '{' if not already consumed
  if FCtx.Peek = ttLBrace then FCtx.Advance;

  if FCtx.Peek <> ttRBrace then
  begin
    arr.AddItem(ParseExpression);
    while FCtx.MatchAdvance(ttComma) do
      arr.AddItem(ParseExpression);
  end;
  FCtx.Consume(ttRBrace, 'Expected } in array literal');
  Result := arr;
end;

function TExprParser.ParseHashLiteral: TExpr;
var
  hash: THashLiteralExpr;
begin
  hash := THashLiteralExpr.Create(FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  if FCtx.Peek = ttLBrace then FCtx.Advance; // consume '{'

  while FCtx.Peek <> ttRBrace do
  begin
    // Try to parse key => value
    // For now, simplified
    Break;
  end;

  // Skip to '}' or error
  while (FCtx.Peek <> ttRBrace) and (FCtx.Peek <> ttEof) do FCtx.Advance;
  if FCtx.Peek = ttRBrace then FCtx.Advance;
  Result := hash;
end;

function TExprParser.ParseCodeBlock: TExpr;
var
  cb: TCodeBlockExpr;
begin
  cb := TCodeBlockExpr.Create(FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  if FCtx.Peek = ttLBrace then FCtx.Advance; // consume '{'

  if FCtx.Peek = ttPipe then
  begin
    FCtx.Advance; // consume '|'
    while FCtx.Peek <> ttPipe do
    begin
      if FCtx.Peek = ttIdentifier then
      begin
        cb.AddParam(FCtx.GetCurrent.StrValue);
        FCtx.Advance;
        if FCtx.Peek = ttComma then FCtx.Advance;
      end
      else
        Break;
    end;
    if FCtx.Peek = ttPipe then FCtx.Advance; // consume '|'
  end;

  // Parse statements (simplified — just expression)
  while (FCtx.Peek <> ttRBrace) and (FCtx.Peek <> ttEof) do
  begin
    if FCtx.Peek in [ttNewline, ttSemicolon] then
      FCtx.Advance
    else
    begin
      // Need statement parsing - delegate back to main parser? For now parse expression as statement
      cb.AddStatement(ParseExpression);
      if FCtx.Peek in [ttNewline, ttSemicolon] then FCtx.Advance;
    end;
  end;

  if FCtx.Peek = ttRBrace then FCtx.Advance; // consume '}'
  Result := cb;
end;

end.