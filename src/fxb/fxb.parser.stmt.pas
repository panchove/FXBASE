unit fxb.parser.stmt;

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
  fxb.parser.context,
  fxb.parser.db;

type
  TStmtParser = class
  private
    FCtx: IParserContext;
    FDBParser: TDBParser;
  public
    constructor Create(const ACtx: IParserContext);
    destructor Destroy; override;
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
    function ParseDBCommand: TASTNode;
  end;

implementation

constructor TStmtParser.Create(const ACtx: IParserContext);
begin
  inherited Create;
  FCtx := ACtx;
  FDBParser := TDBParser.Create(ACtx);
end;

destructor TStmtParser.Destroy;
begin
  FDBParser.Free;
  inherited;
end;

function TStmtParser.ParseStatement: TASTNode;
begin
  case FCtx.Peek of
    ttKeyword:
      begin
        case FCtx.GetCurrent.Keyword of
          kwLocal, kwPrivate, kwPublic, kwStatic, kwData: Exit(ParseVarDecl);
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
          kwUse, kwSelect, kwSeek, kwSkip, kwGo, kwGoto: Exit(ParseDBCommand);
          kwLocate, kwContinue, kwAppend, kwReplace: Exit(ParseDBCommand);
          kwDelete, kwRecall, kwPack, kwZap, kwSort: Exit(ParseDBCommand);
          kwAverage, kwSum, kwCount, kwTotal: Exit(ParseDBCommand);
          kwCopy, kwReport, kwLabel, kwCreate: Exit(ParseDBCommand);
          kwOpen, kwClose, kwSet: Exit(ParseDBCommand);
          kwCommit, kwFlush, kwRun, kwCall: Exit(ParseDBCommand);
          kwQuit, kwCancel, kwAnnounce: Exit(ParseDBCommand);
          kwRequest, kwExternal, kwStore: Exit(ParseDBCommand);
          kwDeclare, kwDefine, kwKeyboard, kwType: Exit(ParseDBCommand);
          kwEject, kwInput, kwAccept, kwWait: Exit(ParseDBCommand);
          kwSay, kwGet, kwRead: Exit(ParseDBCommand);
          kwActivate, kwDeactivate, kwHide, kwShow: Exit(ParseDBCommand);
          kwMenu, kwPrompt: Exit(ParseDBCommand);
          kwClass, kwFunction, kwProcedure: Exit(nil); // top-level handled elsewhere
          kwStruct: Exit(nil);
          kwMethod: Exit(ParseMisc);
          kwNewType: Exit(nil);
          kwEndIf, kwEndDo, kwEndFunc, kwEndFunction,
          kwEndProc, kwEndProcedure, kwEndClass, kwEndStruct,
          kwEndNewType, kwEndFor, kwNext, kwEndForEach,
          kwEndSwitch, kwEndCase, kwEndTry, kwEndWith:
            Exit(nil);
          else
            begin
              FCtx.Error('Unexpected keyword ' + KeywordNames[FCtx.GetCurrent.Keyword]);
              FCtx.Advance;
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
        FCtx.Advance;
      end;

    ttEof:
      Result := nil;

    else
    begin
      FCtx.Error('Unexpected token in statement: ' + DumpToken(FCtx.GetCurrent));
      Result := nil;
      FCtx.Advance;
    end;
  end;

  // Skip trailing newlines
end;

function TStmtParser.ParseVarDecl: TASTNode;
var
  scope: string;
  decl: TVarDeclStmt;
  name, typ: string;
  initVal: TExpr;
begin
  scope := KeywordNames[FCtx.GetCurrent.Keyword];
  FCtx.Advance; // consume LOCAL/PRIVATE/PUBLIC/STATIC
  decl := TVarDeclStmt.Create(scope, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  repeat
    if FCtx.Peek <> ttIdentifier then
    begin
      FCtx.Error(FXB_EXPECTED_IDENT, 'Expected variable name in ' + scope + ' declaration');
      Break;
    end;

    name := FCtx.GetCurrent.StrValue;
    FCtx.Advance; // consume identifier

    typ := '';
    if FCtx.Peek = ttColon then
    begin
      FCtx.Advance; // consume ':'
      typ := FCtx.ParseTypeRef;
    end
    else if FCtx.MatchKeyword(kwAs) then
      typ := FCtx.ParseTypeRef;

    initVal := nil;
    if FCtx.Peek = ttAssign then
    begin
      FCtx.Advance; // consume ':='
      initVal := FCtx.ParseExpression;
    end;

    decl.AddVar(name, typ, initVal);

    if FCtx.Peek <> ttComma then Break;
    FCtx.Advance; // consume ','
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
    expr := FCtx.ParseExpression;
    Target := expr;
  end
  else
    Target := FCtx.ParseExpression;

  // Check for assignment operator
  if FCtx.Peek in [ttAssign, ttPlusAssign, ttMinusAssign, ttStarAssign,
    ttSlashAssign, ttPercentAssign, ttCaretAssign] then
  begin
    op := FCtx.GetCurrent.TokenType;
    FCtx.Advance;
    Result := TAssignStmt.Create(Target, op, FCtx.ParseExpression, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  end
  else
    Result := TExprStmt.Create(Target, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
end;

function TStmtParser.ParseIf: TASTNode;
var
  stmt: TIfStmt;
  cond: TExpr;
begin
  FCtx.ConsumeKeyword(kwIf, 'Expected IF');
  cond := FCtx.ParseExpression;
  stmt := TIfStmt.Create(cond, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  // Then body
  while not FCtx.CheckKeyword(kwElseIf) and not FCtx.CheckKeyword(kwElse)
    and not FCtx.CheckKeyword(kwEndIf) and not FCtx.CheckKeyword(kwEnd)
    and (FCtx.Peek <> ttEof) do
  begin
    stmt.AddThenStmt(ParseStatement);
  end;

  // ElseIf branches
  while FCtx.CheckKeyword(kwElseIf) do
  begin
    FCtx.Advance; // ELSEIF
    cond := FCtx.ParseExpression;
    stmt.AddElseIf(cond);
    while not FCtx.CheckKeyword(kwElseIf) and not FCtx.CheckKeyword(kwElse)
      and not FCtx.CheckKeyword(kwEndIf) and not FCtx.CheckKeyword(kwEnd)
      and (FCtx.Peek <> ttEof) do
    begin
      stmt.AddElseIfStmt(ParseStatement);
    end;
  end;

  // Else
  if FCtx.CheckKeyword(kwElse) then
  begin
    FCtx.Advance; // ELSE
    while not FCtx.CheckKeyword(kwEndIf) and not FCtx.CheckKeyword(kwEnd)
      and (FCtx.Peek <> ttEof) do
    begin
      stmt.AddElseStmt(ParseStatement);
    end;
  end;

  // ENDIF or END
  if FCtx.CheckKeyword(kwEndIf) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDIF or END to close IF');

  Result := stmt;
end;

function TStmtParser.ParseDoWhile: TASTNode;
var
  whileStmt: TWhileStmt;
  cond: TExpr;
begin
  FCtx.ConsumeKeyword(kwDo, 'Expected DO');
  FCtx.ConsumeKeyword(kwWhile, 'Expected WHILE after DO');
  cond := FCtx.ParseExpression;
  whileStmt := TWhileStmt.Create(cond, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  while not FCtx.CheckKeyword(kwEndDo) and not FCtx.CheckKeyword(kwEnd)
    and not FCtx.CheckKeyword(kwLoop) and (FCtx.Peek <> ttEof) do
  begin
    whileStmt.AddStmt(ParseStatement);
  end;

  // Consume LOOP/EXIT handled in parse loop ctrl

  if FCtx.CheckKeyword(kwEndDo) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDDO or END to close DO WHILE');

  Result := whileStmt;
end;

function TStmtParser.ParseWhile: TASTNode;
var
  whileStmt: TWhileStmt;
  cond: TExpr;
begin
  FCtx.ConsumeKeyword(kwWhile, 'Expected WHILE');
  cond := FCtx.ParseExpression;
  whileStmt := TWhileStmt.Create(cond, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  while not FCtx.CheckKeyword(kwEnd) and not FCtx.CheckKeyword(kwElse)
    and (FCtx.Peek <> ttEof) do
  begin
    if FCtx.CheckKeyword(kwLoop) or FCtx.CheckKeyword(kwExit) then
    begin
      whileStmt.AddStmt(ParseLoopCtrl);
      Continue;
    end;
    whileStmt.AddStmt(ParseStatement);
  end;

  if FCtx.CheckKeyword(kwElse) then
  begin
    FCtx.Advance;
    while not FCtx.CheckKeyword(kwEnd) and (FCtx.Peek <> ttEof) do
      whileStmt.AddElseStmt(ParseStatement);
  end;

  if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected END to close WHILE');

  Result := whileStmt;
end;

function TStmtParser.ParseFor: TASTNode;
var
  forStmt: TForStmt;
  varName: string;
  start, finish: TExpr;
  down: Boolean;
begin
  down := False;
  FCtx.ConsumeKeyword(kwFor, 'Expected FOR');
  if FCtx.Peek = ttIdentifier then
    varName := FCtx.GetCurrent.StrValue
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected loop variable after FOR');
    Exit(TForStmt.Create('', nil, nil, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col));
  end;
  FCtx.Advance;

  FCtx.Consume(ttAssign, 'Expected := after loop variable');

  start := FCtx.ParseExpression;

  if FCtx.CheckKeyword(kwTo) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwDownTo) then
  begin
    FCtx.Advance;
    down := True;
  end
  else
  begin
    FCtx.Error('Expected TO or DOWNTO in FOR loop');
    Exit(TForStmt.Create(varName, start, nil, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col));
  end;

  finish := FCtx.ParseExpression;
  forStmt := TForStmt.Create(varName, start, finish, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  if down then
    forStmt.SetDownTo(True);

  if FCtx.CheckKeyword(kwStep) then
  begin
    FCtx.Advance;
    forStmt.SetStep(FCtx.ParseExpression);
  end;

  // FLoopDepth is in main parser; we can't access directly. We'll rely on main parser to manage.
  // For simplicity, we omit depth handling here.

  while not FCtx.CheckKeyword(kwNext) and not FCtx.CheckKeyword(kwEnd)
    and (FCtx.Peek <> ttEof) do
  begin
    if FCtx.CheckKeyword(kwLoop) or FCtx.CheckKeyword(kwExit) then
      forStmt.AddStmt(ParseLoopCtrl)
    else
      forStmt.AddStmt(ParseStatement);
  end;

  if FCtx.CheckKeyword(kwNext) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected NEXT or END to close FOR');

  Result := forStmt;
end;

function TStmtParser.ParseForEach: TASTNode;
begin
  // Stub
  FCtx.ConsumeKeyword(kwForEach, 'Expected FOREACH');
  // Skip to NEXT
  while not FCtx.CheckKeyword(kwNext) and not FCtx.CheckKeyword(kwEnd)
    and (FCtx.Peek <> ttEof) do
    ParseStatement;
  if FCtx.CheckKeyword(kwNext) then FCtx.Advance;
  Result := nil;
end;

function TStmtParser.ParseReturn: TASTNode;
begin
  FCtx.ConsumeKeyword(kwReturn, 'Expected RETURN');
  // Bare RETURN if next token cannot start an expression
  if not (FCtx.Peek in [ttIdentifier, ttInteger, ttReal, ttString, ttDate, ttLogical, ttNil,
       ttLParen, ttLBrace, ttPlus, ttMinus, ttNot, ttDotNot, ttBitAnd, ttAt, ttCaret]) then
    Result := TReturnStmt.Create(FCtx.GetPrevious.Line, FCtx.GetPrevious.Col)
  else
    Result := TReturnStmt.CreateWithValue(FCtx.ParseExpression, FCtx.GetPrevious.Line, FCtx.GetPrevious.Col);
end;

function TStmtParser.ParseYield: TASTNode;
begin
  FCtx.ConsumeKeyword(kwYield, 'Expected YIELD');
  Result := TYieldStmt.Create(FCtx.ParseExpression, FCtx.GetPrevious.Line, FCtx.GetPrevious.Col);
end;

function TStmtParser.ParseLoopCtrl: TASTNode;
var
  kind: string;
begin
  kind := KeywordNames[FCtx.GetCurrent.Keyword];
  FCtx.Advance;
  // FLoopDepth check omitted; main parser can warn if needed
  Result := TLoopCtrlStmt.Create(kind, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
end;

function TStmtParser.ParsePrint: TASTNode;
var
  newLine: Boolean;
  stmt: TPrintStmt;
begin
  newLine := (FCtx.GetCurrent.TokenType = ttQuestion);
  stmt := TPrintStmt.Create(FCtx.GetCurrent.Line, FCtx.GetCurrent.Col, newLine);
  FCtx.Advance; // consume ? or ??
  while True do
  begin
    stmt.AddExpr(FCtx.ParseExpression);
    if FCtx.Peek <> ttComma then Break;
    FCtx.Advance; // consume ','
  end;
  Result := stmt;
end;

function TStmtParser.ParseMisc: TASTNode;
begin
  // Stub implementation: skip to end of statement
  while not (FCtx.Peek in [ttNewline, ttEof, ttSemicolon]) do
    FCtx.Advance;
  if FCtx.Peek in [ttNewline, ttSemicolon] then FCtx.Advance;
  Result := nil;
end;

function TStmtParser.ParseDBCommand: TASTNode;
begin
  Result := FDBParser.ParseDBStmt;
end;

end.