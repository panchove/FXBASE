unit fxb.parser.db;

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
  fxb.parser.context;

type
  TDBParser = class
  private
    FCtx: IParserContext;
  public
    constructor Create(const ACtx: IParserContext);
    procedure ParseScopeClauses(Stmt: TASTDBStmt);
    function ParseDBStmt: TASTNode;
  end;

implementation

constructor TDBParser.Create(const ACtx: IParserContext);
begin
  inherited Create;
  FCtx := ACtx;
end;

procedure TDBParser.ParseScopeClauses(Stmt: TASTDBStmt);
var
  n: Integer;
begin
  while True do
  begin
    if FCtx.MatchKeyword(kwAll) then
      Stmt.ScopeAll := True
    else if FCtx.MatchKeyword(kwRest) then
    begin
      if FCtx.Peek = ttInteger then
      begin
        n := StrToInt(FCtx.GetCurrent.StrValue);
        FCtx.Advance;
        Stmt.ScopeRest := n;
      end
      else
        FCtx.Error(FXB_SYNTAX_ERROR, 'Expected number after REST');
    end
    else if FCtx.MatchKeyword(kwNext) then
    begin
      if FCtx.Peek = ttInteger then
      begin
        n := StrToInt(FCtx.GetCurrent.StrValue);
        FCtx.Advance;
        Stmt.ScopeNext := n;
      end
      else
        FCtx.Error(FXB_SYNTAX_ERROR, 'Expected number after NEXT');
    end
    else if FCtx.MatchKeyword(kwFor) then
    begin
      Stmt.ScopeForCond := FCtx.ParseExpression;
    end
    else if FCtx.MatchKeyword(kwWhile) then
    begin
      Stmt.ScopeWhileCond := FCtx.ParseExpression;
    end
    else
      Break;
  end;
end;

function TDBParser.ParseDBStmt: TASTNode;
var
  kw: TKeyword;
  tableName, fieldName: string;
  dbStmt: TASTDBStmt;
  val: TExpr;
  n: Integer;
begin
  kw := FCtx.GetCurrent.Keyword;
  FCtx.Advance; // consume the DB keyword

  // Fase 2: real database statements -> SQLite.
  if kw = kwUse then
  begin
    if FCtx.Peek = ttIdentifier then
    begin
      tableName := FCtx.GetCurrent.StrValue;
      FCtx.Advance;
    end
    else
    begin
      FCtx.Error(FXB_EXPECTED_IDENT, 'Expected table name after USE');
      tableName := '__missing__';
    end;
    // Optional ALIAS name is ignored in the MVP.
    if FCtx.Peek = ttIdentifier then FCtx.Advance;
    Result := TASTDBStmt.Create('use', tableName, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
    Exit;
  end
  else if kw = kwAppend then
  begin
    // APPEND [BLANK] [field = expr, ...]
    if (FCtx.Peek = ttIdentifier) and (UpperCase(FCtx.GetCurrent.StrValue) = 'BLANK') then
      FCtx.Advance;
    dbStmt := TASTDBStmt.Create('append', '', FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
    // Parse optional field = expr pairs.
    while FCtx.Peek = ttIdentifier do
    begin
      fieldName := FCtx.GetCurrent.StrValue;
      FCtx.Advance;
      if FCtx.Peek in [ttEqual, ttAssign] then FCtx.Advance
      else FCtx.Error(FXB_SYNTAX_ERROR, 'Expected = after APPEND field');
      val := FCtx.ParseExpression;
      dbStmt.AddPair(fieldName, val);
      if FCtx.Peek = ttComma then FCtx.Advance else Break;
    end;
    Result := dbStmt;
    Exit;
  end
  else if kw = kwReplace then
  begin
    if FCtx.Peek = ttIdentifier then
    begin
      fieldName := FCtx.GetCurrent.StrValue;
      FCtx.Advance;
    end
    else
    begin
      FCtx.Error(FXB_EXPECTED_IDENT, 'Expected field name after REPLACE');
      fieldName := '__missing__';
    end;
    if not FCtx.MatchKeyword(kwWith) then
      FCtx.Error(FXB_SYNTAX_ERROR, 'Expected WITH after REPLACE field');
    val := FCtx.ParseExpression;
    dbStmt := TASTDBStmt.Create('replace', '', FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
    dbStmt.SetReplace(fieldName, val);
    ParseScopeClauses(dbStmt);
    Result := dbStmt;
    Exit;
  end
  else if kw = kwPack then
  begin
    // PACK: clear the active table (SQLite has no deleted-flag; equivalent to
    // DELETE FROM). Scope/WHILE/NEXT clauses (Fase 2.4) would add a WHERE.
    // The active table is resolved by the IR generator from the preceding USE.
    Result := TASTDBStmt.Create('pack', '', FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
    ParseScopeClauses(TASTDBStmt(Result));
    Exit;
  end
  else if kw = kwZap then
  begin
    // ZAP: truncate the active table, keep the schema.
    Result := TASTDBStmt.Create('zap', '', FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
    ParseScopeClauses(TASTDBStmt(Result));
    Exit;
  end;

  // For all other DB commands (SELECT, SEEK, SKIP, etc.) just skip to end of statement
  while not (FCtx.Peek in [ttNewline, ttEof, ttSemicolon]) do
    FCtx.Advance;
  if FCtx.Peek in [ttNewline, ttSemicolon] then FCtx.Advance;
  Result := nil;
end;

end.