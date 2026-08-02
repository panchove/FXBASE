unit fxb.ast.stmt;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fxb.ast.base,
  fxb.tokens;

type

  TExprStmt = class(TStmt)
  private
    FExpr: TExpr;
  public
    constructor Create(AExpr: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Expr: TExpr read FExpr;
  end;

  TPrintStmt = class(TStmt)
  private
    FExpressions: TExprArray;
    FNewLine: Boolean;
  public
    constructor Create(ALine, ACol: Integer; ANewLine: Boolean = True);
    destructor Destroy; override;
    procedure AddExpr(Expr: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Expressions: TExprArray read FExpressions;
    property NewLine: Boolean read FNewLine;
  end;

  TVarDeclStmt = class(TStmt)
  private
    FScope: string; // LOCAL, PRIVATE, PUBLIC, STATIC
    FNames: TStringArray;
    FTypes: TStringArray; // empty if untyped
    FInitVals: array of TExpr;
  public
    constructor Create(const AScope: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddVar(const Name: string; const Typ: string; InitVal: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Scope: string read FScope;
    property Names: TStringArray read FNames;
    function GetType(Index: Integer): string;
    function GetInitVal(Index: Integer): TExpr;
    function GetVarCount: Integer;
    property VarCount: Integer read GetVarCount;
  end;

  TAssignStmt = class(TStmt)
  private
    FTarget: TExpr;
    FOp: TTokenType;
    FValue: TExpr;
  public
    constructor Create(ATarget: TExpr; AOp: TTokenType; AValue: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Target: TExpr read FTarget;
    property Op: TTokenType read FOp;
    property Value: TExpr read FValue;
  end;

  TIfStmt = class(TStmt)
  private
    FCondition: TExpr;
    FThenBody: array of TASTNode;
    FElseIfConds: array of TExpr;
    FElseIfBodies: array of array of TASTNode;
    FElseBody: array of TASTNode;
    FHasElse: Boolean;
  public
    constructor Create(ACondition: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddThenStmt(Stmt: TASTNode);
    procedure AddElseIf(ACond: TExpr);
    procedure AddElseIfStmt(Stmt: TASTNode);
    procedure AddElseStmt(Stmt: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
    property Condition: TExpr read FCondition;
    property ThenBody: TASTNodeArray read FThenBody;
    property ElseIfConds: TExprArray read FElseIfConds;
    property ElseIfBodies: TASTNodeArrayArray read FElseIfBodies;
    property ElseBody: TASTNodeArray read FElseBody;
    property HasElse: Boolean read FHasElse;
  end;

  TForStmt = class(TStmt)
  private
    FVarName: string;
    FStart: TExpr;
    FEnd: TExpr;
    FStep: TExpr;
    FBody: array of TASTNode;
    FDownTo: Boolean;
  public
    constructor Create(const AVar: string; AStart, AEnd: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure SetStep(AStep: TExpr);
    procedure SetDownTo(Down: Boolean);
    procedure AddStmt(Stmt: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
    property VarName: string read FVarName;
    property StartExpr: TExpr read FStart;
    property EndExpr: TExpr read FEnd;
    property StepExpr: TExpr read FStep;
    property IsDownTo: Boolean read FDownTo;
    property Body: TASTNodeArray read FBody;
  end;

  TWhileStmt = class(TStmt)
  private
    FCondition: TExpr;
    FBody: array of TASTNode;
    FHasElse: Boolean;
    FElseBody: array of TASTNode;
  public
    constructor Create(ACondition: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddStmt(Stmt: TASTNode);
    procedure AddElseStmt(Stmt: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
    property Condition: TExpr read FCondition;
    property Body: TASTNodeArray read FBody;
    property HasElse: Boolean read FHasElse;
    property ElseBody: TASTNodeArray read FElseBody;
  end;

  TReturnStmt = class(TStmt)
  private
    FValue: TExpr;
    FHasValue: Boolean;
  public
    constructor Create(ALine, ACol: Integer);
    constructor CreateWithValue(AValue: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Value: TExpr read FValue;
    property HasValue: Boolean read FHasValue;
  end;

  TYieldStmt = class(TStmt)
  private
    FValue: TExpr;
  public
    constructor Create(AValue: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Value: TExpr read FValue;
  end;

  TLoopCtrlStmt = class(TStmt)
  private
    FKind: string; // LOOP, EXIT, BREAK
  public
    constructor Create(const AKind: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
    property Kind: string read FKind;
  end;

  // Fase 2: database statements (USE / APPEND / REPLACE / PACK / ZAP) lowered to SQLite calls.
  // Op is one of: 'use', 'append', 'replace', 'pack', 'zap'.
  //  - use:     TableName set; opens/creates the table (schema inferred at compile time).
  //  - append:  FieldNames + Exprs (parallel arrays, the column/value pairs to insert).
  //  - replace: Field + Expr (single column assignment; MVP emits UPDATE over all rows).
  //  - pack/zap: clear/truncate the active table.
  // Scope clauses (Fase 2.4): ALL, REST n, NEXT n, FOR cond, WHILE cond → translated to WHERE/LIMIT/OFFSET.
  TASTDBStmt = class(TStmt)
  private
    FOp: string;
    FTableName: string;
    FField: string;
    FFieldNames: TStringArray;
    FExprs: TExprArray;
    FScopeAll: Boolean;
    FScopeRest: Integer;        // REST n
    FScopeNext: Integer;        // NEXT n
    FScopeForCond: TExpr;       // FOR cond
    FScopeWhileCond: TExpr;     // WHILE cond
  public
    constructor Create(const AOp, ATableName: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddPair(const FieldName: string; Expr: TExpr);
    procedure SetReplace(const FieldName: string; Expr: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Op: string read FOp;
    property TableName: string read FTableName;
    property Field: string read FField;
    property FieldNames: TStringArray read FFieldNames;
    property Exprs: TExprArray read FExprs;
    property ScopeAll: Boolean read FScopeAll write FScopeAll;
    property ScopeRest: Integer read FScopeRest write FScopeRest;
    property ScopeNext: Integer read FScopeNext write FScopeNext;
    property ScopeForCond: TExpr read FScopeForCond write FScopeForCond;
    property ScopeWhileCond: TExpr read FScopeWhileCond write FScopeWhileCond;
  end;

implementation

constructor TExprStmt.Create(AExpr: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FExpr := AExpr;
end;

destructor TExprStmt.Destroy;
begin
  FExpr.Free;
  inherited;
end;

function TExprStmt.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'EXPR_STMT' + LineEnding;
  Result := Result + FExpr.Dump(Indent + 1);
end;

constructor TPrintStmt.Create(ALine, ACol: Integer; ANewLine: Boolean = True);
begin
  inherited Create(ALine, ACol);
  FNewLine := ANewLine;
end;

destructor TPrintStmt.Destroy;
var
  e: TExpr;
begin
  for e in FExpressions do e.Free;
  inherited;
end;

procedure TPrintStmt.AddExpr(Expr: TExpr);
begin
  SetLength(FExpressions, Length(FExpressions) + 1);
  FExpressions[High(FExpressions)] := Expr;
end;

function TPrintStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
  e: TExpr;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'PRINT';
  if FNewLine then Result := Result + ' ?'
  else Result := Result + ' ??';
  Result := Result + LineEnding;
  for e in FExpressions do
    Result := Result + e.Dump(Indent + 1) + LineEnding;
end;

constructor TVarDeclStmt.Create(const AScope: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FScope := AScope;
end;

destructor TVarDeclStmt.Destroy;
var
  a: TExpr;
begin
  for a in FInitVals do a.Free;
  inherited;
end;

procedure TVarDeclStmt.AddVar(const Name: string; const Typ: string; InitVal: TExpr);
begin
  SetLength(FNames, Length(FNames) + 1);
  FNames[High(FNames)] := Name;
  SetLength(FTypes, Length(FTypes) + 1);
  FTypes[High(FTypes)] := Typ;
  SetLength(FInitVals, Length(FInitVals) + 1);
  FInitVals[High(FInitVals)] := InitVal;
end;

function TVarDeclStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'VARDECL ' + FScope + LineEnding;
  for i := 0 to High(FNames) do
  begin
    Result := Result + pad + '  ' + FNames[i];
    if FTypes[i] <> '' then Result := Result + ':' + FTypes[i];
    if Assigned(FInitVals[i]) then
    begin
      Result := Result + ' := ' + LineEnding;
      Result := Result + FInitVals[i].Dump(Indent + 2);
    end
    else
      Result := Result + LineEnding;
  end;
end;

function TVarDeclStmt.GetType(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FTypes)) then
    Result := FTypes[Index]
  else
    Result := '';
end;

function TVarDeclStmt.GetInitVal(Index: Integer): TExpr;
begin
  if (Index >= 0) and (Index < Length(FInitVals)) then
    Result := FInitVals[Index]
  else
    Result := nil;
end;

function TVarDeclStmt.GetVarCount: Integer;
begin
  Result := Length(FNames);
end;

constructor TAssignStmt.Create(ATarget: TExpr; AOp: TTokenType; AValue: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FTarget := ATarget;
  FOp := AOp;
  FValue := AValue;
end;

destructor TAssignStmt.Destroy;
begin
  FTarget.Free;
  FValue.Free;
  inherited;
end;

function TAssignStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'ASSIGN ' + TokenTypeName(FOp) + LineEnding;
  Result := Result + FTarget.Dump(Indent + 1) + LineEnding;
  Result := Result + FValue.Dump(Indent + 1);
end;

constructor TIfStmt.Create(ACondition: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FCondition := ACondition;
end;

destructor TIfStmt.Destroy;
var
  s: TASTNode;
  arr: array of TASTNode;
  i: Integer;
begin
  FCondition.Free;
  for s in FThenBody do s.Free;
  for arr in FElseIfBodies do
    for s in arr do s.Free;
  for s in FElseBody do s.Free;
  inherited;
end;

procedure TIfStmt.AddThenStmt(Stmt: TASTNode);
begin
  if Stmt = nil then Exit;
  SetLength(FThenBody, Length(FThenBody) + 1);
  FThenBody[High(FThenBody)] := Stmt;
end;

procedure TIfStmt.AddElseIf(ACond: TExpr);
begin
  SetLength(FElseIfConds, Length(FElseIfConds) + 1);
  FElseIfConds[High(FElseIfConds)] := ACond;
  SetLength(FElseIfBodies, Length(FElseIfBodies) + 1);
  FElseIfBodies[High(FElseIfBodies)] := nil;
end;

procedure TIfStmt.AddElseIfStmt(Stmt: TASTNode);
var
  arr: array of TASTNode;
begin
  if Length(FElseIfBodies) = 0 then Exit;
  if Stmt = nil then Exit;
  arr := FElseIfBodies[High(FElseIfBodies)];
  SetLength(arr, Length(arr) + 1);
  arr[High(arr)] := Stmt;
  FElseIfBodies[High(FElseIfBodies)] := arr;
end;

procedure TIfStmt.AddElseStmt(Stmt: TASTNode);
begin
  if Stmt = nil then Exit;
  FHasElse := True;
  SetLength(FElseBody, Length(FElseBody) + 1);
  FElseBody[High(FElseBody)] := Stmt;
end;

function TIfStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'IF' + LineEnding;
  Result := Result + FCondition.Dump(Indent + 1) + LineEnding;
  for s in FThenBody do
    Result := Result + s.Dump(Indent + 1) + LineEnding;
  for i := 0 to High(FElseIfConds) do
  begin
    Result := Result + pad + 'ELSEIF' + LineEnding;
    Result := Result + FElseIfConds[i].Dump(Indent + 1) + LineEnding;
    for s in FElseIfBodies[i] do
      Result := Result + s.Dump(Indent + 1) + LineEnding;
  end;
  if FHasElse then
  begin
    Result := Result + pad + 'ELSE' + LineEnding;
    for s in FElseBody do
      Result := Result + s.Dump(Indent + 1) + LineEnding;
  end;
  Result := Result + pad + 'ENDIF';
end;

constructor TForStmt.Create(const AVar: string; AStart, AEnd: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FVarName := AVar;
  FStart := AStart;
  FEnd := AEnd;
end;

destructor TForStmt.Destroy;
var
  s: TASTNode;
begin
  FStart.Free;
  FEnd.Free;
  if Assigned(FStep) then FStep.Free;
  for s in FBody do s.Free;
  inherited;
end;

procedure TForStmt.SetStep(AStep: TExpr);
begin
  FStep := AStep;
end;

procedure TForStmt.SetDownTo(Down: Boolean);
begin
  FDownTo := Down;
end;

procedure TForStmt.AddStmt(Stmt: TASTNode);
begin
  if Stmt = nil then Exit;
  SetLength(FBody, Length(FBody) + 1);
  FBody[High(FBody)] := Stmt;
end;

function TForStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  if FDownTo then
    Result := pad + 'FOR ' + FVarName + ' DOWNTO' + LineEnding
  else
    Result := pad + 'FOR ' + FVarName + ' TO' + LineEnding;
  Result := Result + FStart.Dump(Indent + 1) + LineEnding;
  Result := Result + FEnd.Dump(Indent + 1) + LineEnding;
  if Assigned(FStep) then Result := Result + FStep.Dump(Indent + 1) + LineEnding;
  for s in FBody do
    Result := Result + s.Dump(Indent + 1) + LineEnding;
  Result := Result + pad + 'NEXT';
end;

constructor TWhileStmt.Create(ACondition: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FCondition := ACondition;
end;

destructor TWhileStmt.Destroy;
var
  s: TASTNode;
begin
  FCondition.Free;
  for s in FBody do s.Free;
  for s in FElseBody do s.Free;
  inherited;
end;

procedure TWhileStmt.AddStmt(Stmt: TASTNode);
begin
  if Stmt = nil then Exit;
  SetLength(FBody, Length(FBody) + 1);
  FBody[High(FBody)] := Stmt;
end;

procedure TWhileStmt.AddElseStmt(Stmt: TASTNode);
begin
  if Stmt = nil then Exit;
  FHasElse := True;
  SetLength(FElseBody, Length(FElseBody) + 1);
  FElseBody[High(FElseBody)] := Stmt;
end;

function TWhileStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'WHILE' + LineEnding;
  Result := Result + FCondition.Dump(Indent + 1) + LineEnding;
  for s in FBody do
    Result := Result + s.Dump(Indent + 1) + LineEnding;
  if FHasElse then
  begin
    Result := Result + pad + 'ELSE' + LineEnding;
    for s in FElseBody do
      Result := Result + s.Dump(Indent + 1) + LineEnding;
  end;
  Result := Result + pad + 'END';
end;

constructor TReturnStmt.Create(ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FHasValue := False;
end;

constructor TReturnStmt.CreateWithValue(AValue: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FValue := AValue;
  FHasValue := True;
end;

destructor TReturnStmt.Destroy;
begin
  if FHasValue then FValue.Free;
  inherited;
end;

function TReturnStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'RETURN';
  if FHasValue then
  begin
    Result := Result + LineEnding;
    Result := Result + FValue.Dump(Indent + 1);
  end;
end;

constructor TYieldStmt.Create(AValue: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FValue := AValue;
end;

destructor TYieldStmt.Destroy;
begin
  FValue.Free;
  inherited;
end;

function TYieldStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'YIELD' + LineEnding;
  Result := Result + FValue.Dump(Indent + 1);
end;

constructor TLoopCtrlStmt.Create(const AKind: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FKind := AKind;
end;

function TLoopCtrlStmt.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + FKind;
end;

{ TASTDBStmt }

constructor TASTDBStmt.Create(const AOp, ATableName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FOp := AOp;
  FTableName := ATableName;
  FField := '';
  SetLength(FFieldNames, 0);
  SetLength(FExprs, 0);
  FScopeAll := False;
  FScopeRest := 0;
  FScopeNext := 0;
  FScopeForCond := nil;
  FScopeWhileCond := nil;
end;

destructor TASTDBStmt.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FExprs) do FExprs[i].Free;
  if Assigned(FScopeForCond) then FScopeForCond.Free;
  if Assigned(FScopeWhileCond) then FScopeWhileCond.Free;
  inherited;
end;

procedure TASTDBStmt.AddPair(const FieldName: string; Expr: TExpr);
begin
  SetLength(FFieldNames, Length(FFieldNames) + 1);
  FFieldNames[High(FFieldNames)] := FieldName;
  SetLength(FExprs, Length(FExprs) + 1);
  FExprs[High(FExprs)] := Expr;
end;

procedure TASTDBStmt.SetReplace(const FieldName: string; Expr: TExpr);
begin
  FField := FieldName;
  SetLength(FExprs, 1);
  FExprs[0] := Expr;
end;

function TASTDBStmt.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'DB.' + UpperCase(FOp) + ' ' + FTableName;
  if FOp = 'append' then
  begin
    for i := 0 to High(FFieldNames) do
      Result := Result + LineEnding + pad + '  ' + FFieldNames[i] + ' = ' + FExprs[i].Dump(0);
  end
  else if FOp = 'replace' then
    Result := Result + LineEnding + pad + '  ' + FField + ' = ' + FExprs[0].Dump(0);
  // Scope clauses (Fase 2.4)
  if FScopeAll then Result := Result + LineEnding + pad + '  ALL';
  if FScopeRest > 0 then Result := Result + LineEnding + pad + '  REST ' + IntToStr(FScopeRest);
  if FScopeNext > 0 then Result := Result + LineEnding + pad + '  NEXT ' + IntToStr(FScopeNext);
  if Assigned(FScopeForCond) then Result := Result + LineEnding + pad + '  FOR ' + FScopeForCond.Dump(0);
  if Assigned(FScopeWhileCond) then Result := Result + LineEnding + pad + '  WHILE ' + FScopeWhileCond.Dump(0);
end;

end.
