unit fpx.ast;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpx.tokens;

type
  TASTNode = class;
  TExpr = class;

  TExprArray = array of TExpr;
  TASTNodeArray = array of TASTNode;
  TKeywordArray = array of TKeyword;

  TASTNodeClass = class of TASTNode;

  TASTNode = class
  protected
    FLine: Integer;
    FCol: Integer;
    FNodeId: Integer;
  public
    constructor Create(ALine, ACol: Integer); virtual;
    function Dump(Indent: Integer = 0): string; virtual; abstract;
    property Line: Integer read FLine;
    property Col: Integer read FCol;
  end;

  // Expressions
  TExpr = class(TASTNode)
  public
    function Dump(Indent: Integer = 0): string; override;
  end;

  TLiteralExpr = class(TExpr)
  private
    FToken: TToken;
  public
    constructor Create(constref AToken: TToken);
    function Dump(Indent: Integer = 0): string; override;
    property Token: TToken read FToken;
  end;

  TIdentifierExpr = class(TExpr)
  private
    FName: string;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
  end;

  TBinaryExpr = class(TExpr)
  private
    FLeft: TExpr;
    FOp: TTokenType;
    FRight: TExpr;
  public
    constructor Create(ALeft: TExpr; AOp: TTokenType; ARight: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Left: TExpr read FLeft;
    property Op: TTokenType read FOp;
    property Right: TExpr read FRight;
  end;

  TUnaryExpr = class(TExpr)
  private
    FOp: TTokenType;
    FOperand: TExpr;
  public
    constructor Create(AOp: TTokenType; AOperand: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Op: TTokenType read FOp;
    property Operand: TExpr read FOperand;
  end;

  TCallExpr = class(TExpr)
  private
    FName: string;
    FArgs: TExprArray;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddArg(Arg: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
    property Args: TExprArray read FArgs;
    function ArgCount: Integer;
  end;

  TMethodCallExpr = class(TExpr)
  private
    FTarget: TExpr;
    FMethod: string;
    FArgs: TExprArray;
  public
    constructor Create(ATarget: TExpr; const AMethod: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddArg(Arg: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Target: TExpr read FTarget;
    property Method: string read FMethod;
    property Args: TExprArray read FArgs;
    function ArgCount: Integer;
  end;

  TMemberAccessExpr = class(TExpr)
  private
    FTarget: TExpr;
    FMember: string;
  public
    constructor Create(ATarget: TExpr; const AMember: string; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Target: TExpr read FTarget;
    property Member: string read FMember;
  end;

  TDerefExpr = class(TExpr)
  private
    FTarget: TExpr;
  public
    constructor Create(ATarget: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Target: TExpr read FTarget;
  end;

  TArrayLiteralExpr = class(TExpr)
  private
    FItems: TExprArray;
  public
    constructor Create(ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddItem(Item: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Items: TExprArray read FItems;
    function Count: Integer;
  end;

  THashLiteralExpr = class(TExpr)
  private
    FKeys: TExprArray;
    FValues: TExprArray;
  public
    constructor Create(ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddPair(AKey, AValue: TExpr);
    function Dump(Indent: Integer = 0): string; override;
    property Keys: TExprArray read FKeys;
    property Values: TExprArray read FValues;
  end;

  TCodeBlockExpr = class(TExpr)
  private
    FParams: TStringArray;
    FStatements: TASTNodeArray;
  public
    constructor Create(ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddParam(const Name: string);
    procedure AddStatement(Stmt: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
    property Params: TStringArray read FParams;
    property Statements: TASTNodeArray read FStatements;
  end;

  TStructLiteralExpr = class(TExpr)
  private
    FTypeName: string;
    FArgs: TExprArray; // positional + named
  public
    constructor Create(const ATypeName: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddArg(Arg: TExpr);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TMacroExpr = class(TExpr)
  private
    FName: string;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
  end;

  // Statements
  TStmt = class(TASTNode)
  public
    function Dump(Indent: Integer = 0): string; override;
  end;

  TExprStmt = class(TStmt)
  private
    FExpr: TExpr;
  public
    constructor Create(AExpr: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Expr: TExpr read FExpr;
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
  end;

  TLoopCtrlStmt = class(TStmt)
  private
    FKind: string; // LOOP, EXIT, BREAK
  public
    constructor Create(const AKind: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
  end;

  // Top-level declarations

  TFunctionDef = class(TASTNode)
  private
    FName: string;
    FIsStatic: Boolean;
    FParams: array of record
      Name, Typ: string;
      Default: TExpr;
      IsRef: Boolean;
    end;
    FReturnType: string;
    FBody: array of TASTNode;
    FHasExplicitReturn: Boolean;
  public
    constructor Create(const AName: string; AIsStatic: Boolean; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddParam(const Name, Typ: string; Default: TExpr; IsRef: Boolean);
    procedure SetReturnType(const Typ: string);
    procedure AddStmt(Stmt: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
    property IsStatic: Boolean read FIsStatic;
  end;

  TProcedureDef = class(TASTNode)
  private
    FName: string;
    FIsStatic: Boolean;
    FParams: array of record
      Name, Typ: string;
      Default: TExpr;
      IsRef: Boolean;
    end;
    FBody: array of TASTNode;
  public
    constructor Create(const AName: string; AIsStatic: Boolean; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddParam(const Name, Typ: string; Default: TExpr; IsRef: Boolean);
    procedure AddStmt(Stmt: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TClassDef = class(TASTNode)
  private
    FName: string;
    FParentClasses: array of string;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddParent(const Name: string);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TStructDef = class(TASTNode)
  private
    FName: string;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TNewTypeDef = class(TASTNode)
  private
    FName, FBaseType: string;
  public
    constructor Create(const AName, ABaseType: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TCompilationUnit = class(TASTNode)
  private
    FNodes: array of TASTNode;
  public
    constructor Create(ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddNode(Node: TASTNode);
    function Dump(Indent: Integer = 0): string; override;
    function GetNode(Index: Integer): TASTNode;
    function GetNodeCount: Integer;
    property Nodes[Index: Integer]: TASTNode read GetNode;
    property Count: Integer read GetNodeCount;
  end;

implementation

uses
  classes;

var
  NextNodeId: Integer = 1;

constructor TASTNode.Create(ALine, ACol: Integer);
begin
  inherited Create;
  FLine := ALine;
  FCol := ACol;
  FNodeId := NextNodeId;
  Inc(NextNodeId);
end;

function TStmt.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'STMT';
end;

function TExpr.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'EXPR';
end;

constructor TLiteralExpr.Create(constref AToken: TToken);
begin
  inherited Create(AToken.Line, AToken.Col);
  FToken := AToken;
end;

function TLiteralExpr.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'LITERAL ' + DumpToken(FToken);
end;

constructor TIdentifierExpr.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
end;

function TIdentifierExpr.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'ID "' + FName + '"';
end;

constructor TBinaryExpr.Create(ALeft: TExpr; AOp: TTokenType; ARight: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FLeft := ALeft;
  FOp := AOp;
  FRight := ARight;
end;

destructor TBinaryExpr.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

function TBinaryExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'BINARY ' + TokenTypeName(FOp) + LineEnding;
  Result := Result + FLeft.Dump(Indent + 1) + LineEnding;
  Result := Result + FRight.Dump(Indent + 1);
end;

constructor TUnaryExpr.Create(AOp: TTokenType; AOperand: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FOp := AOp;
  FOperand := AOperand;
end;

destructor TUnaryExpr.Destroy;
begin
  FOperand.Free;
  inherited;
end;

function TUnaryExpr.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'UNARY ' + TokenTypeName(FOp) + LineEnding;
  Result := Result + FOperand.Dump(Indent + 1);
end;

constructor TCallExpr.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
end;

destructor TCallExpr.Destroy;
var
  a: TExpr;
begin
  for a in FArgs do a.Free;
  inherited;
end;

procedure TCallExpr.AddArg(Arg: TExpr);
begin
  SetLength(FArgs, Length(FArgs) + 1);
  FArgs[High(FArgs)] := Arg;
end;

function TCallExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'CALL "' + FName + '" args=' + IntToStr(Length(FArgs)) + LineEnding;
  for i := 0 to High(FArgs) do
    Result := Result + FArgs[i].Dump(Indent + 1) + LineEnding;
end;

function TCallExpr.ArgCount: Integer;
begin
  Result := Length(FArgs);
end;

constructor TMethodCallExpr.Create(ATarget: TExpr; const AMethod: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FTarget := ATarget;
  FMethod := AMethod;
end;

destructor TMethodCallExpr.Destroy;
var
  a: TExpr;
begin
  for a in FArgs do a.Free;
  inherited;
end;

procedure TMethodCallExpr.AddArg(Arg: TExpr);
begin
  SetLength(FArgs, Length(FArgs) + 1);
  FArgs[High(FArgs)] := Arg;
end;

function TMethodCallExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'METHOD CALL ' + FMethod + LineEnding;
  Result := Result + FTarget.Dump(Indent + 1) + LineEnding;
  for i := 0 to High(FArgs) do
    Result := Result + FArgs[i].Dump(Indent + 1) + LineEnding;
end;

function TMethodCallExpr.ArgCount: Integer;
begin
  Result := Length(FArgs);
end;

constructor TMemberAccessExpr.Create(ATarget: TExpr; const AMember: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FTarget := ATarget;
  FMember := AMember;
end;

destructor TMemberAccessExpr.Destroy;
begin
  FTarget.Free;
  inherited;
end;

function TMemberAccessExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'MEMBER .' + FMember + LineEnding;
  Result := Result + FTarget.Dump(Indent + 1);
end;

constructor TDerefExpr.Create(ATarget: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FTarget := ATarget;
end;

destructor TDerefExpr.Destroy;
begin
  FTarget.Free;
  inherited;
end;

function TDerefExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'DEREF ^' + LineEnding;
  Result := Result + FTarget.Dump(Indent + 1);
end;

constructor TArrayLiteralExpr.Create(ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
end;

destructor TArrayLiteralExpr.Destroy;
var
  a: TExpr;
begin
  for a in FItems do a.Free;
  inherited;
end;

procedure TArrayLiteralExpr.AddItem(Item: TExpr);
begin
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := Item;
end;

function TArrayLiteralExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'ARRAY [' + IntToStr(Length(FItems)) + ']' + LineEnding;
  for i := 0 to High(FItems) do
    Result := Result + FItems[i].Dump(Indent + 1) + LineEnding;
end;

function TArrayLiteralExpr.Count: Integer;
begin
  Result := Length(FItems);
end;

constructor THashLiteralExpr.Create(ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
end;

destructor THashLiteralExpr.Destroy;
var
  a: TExpr;
begin
  for a in FKeys do a.Free;
  for a in FValues do a.Free;
  inherited;
end;

procedure THashLiteralExpr.AddPair(AKey, AValue: TExpr);
begin
  SetLength(FKeys, Length(FKeys) + 1);
  FKeys[High(FKeys)] := AKey;
  SetLength(FValues, Length(FValues) + 1);
  FValues[High(FValues)] := AValue;
end;

function THashLiteralExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'HASH [' + IntToStr(Length(FKeys)) + ']' + LineEnding;
  for i := 0 to High(FKeys) do
  begin
    Result := Result + FKeys[i].Dump(Indent + 1) + LineEnding;
    Result := Result + FValues[i].Dump(Indent + 1) + LineEnding;
  end;
end;

constructor TCodeBlockExpr.Create(ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
end;

destructor TCodeBlockExpr.Destroy;
var
  s: TASTNode;
begin
  for s in FStatements do s.Free;
  inherited;
end;

procedure TCodeBlockExpr.AddParam(const Name: string);
begin
  SetLength(FParams, Length(FParams) + 1);
  FParams[High(FParams)] := Name;
end;

procedure TCodeBlockExpr.AddStatement(Stmt: TASTNode);
begin
  SetLength(FStatements, Length(FStatements) + 1);
  FStatements[High(FStatements)] := Stmt;
end;

function TCodeBlockExpr.Dump(Indent: Integer = 0): string;
var
  pad, p: string;
  i: Integer;
begin
  pad := StringOfChar(' ', Indent * 2);
  p := '';
  for i := 0 to High(FParams) do
  begin
    if p <> '' then p := p + ',';
    p := p + FParams[i];
  end;
  Result := pad + 'CODEBLOCK params=[' + p + ']' + LineEnding;
  for i := 0 to High(FStatements) do
    Result := Result + FStatements[i].Dump(Indent + 1) + LineEnding;
end;

constructor TStructLiteralExpr.Create(const ATypeName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FTypeName := ATypeName;
end;

destructor TStructLiteralExpr.Destroy;
var
  a: TExpr;
begin
  for a in FArgs do a.Free;
  inherited;
end;

procedure TStructLiteralExpr.AddArg(Arg: TExpr);
begin
  SetLength(FArgs, Length(FArgs) + 1);
  FArgs[High(FArgs)] := Arg;
end;

function TStructLiteralExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'STRUCT ' + FTypeName + '(...)';
end;

constructor TMacroExpr.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
end;

function TMacroExpr.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'MACRO &' + FName;
end;

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
  arr := FElseIfBodies[High(FElseIfBodies)];
  SetLength(arr, Length(arr) + 1);
  arr[High(arr)] := Stmt;
  FElseIfBodies[High(FElseIfBodies)] := arr;
end;

procedure TIfStmt.AddElseStmt(Stmt: TASTNode);
begin
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
  SetLength(FBody, Length(FBody) + 1);
  FBody[High(FBody)] := Stmt;
end;

procedure TWhileStmt.AddElseStmt(Stmt: TASTNode);
begin
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

constructor TFunctionDef.Create(const AName: string; AIsStatic: Boolean; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
  FIsStatic := AIsStatic;
end;

destructor TFunctionDef.Destroy;
var
  s: TASTNode;
begin
  for s in FBody do s.Free;
  inherited;
end;

procedure TFunctionDef.AddParam(const Name, Typ: string; Default: TExpr; IsRef: Boolean);
begin
  SetLength(FParams, Length(FParams) + 1);
  FParams[High(FParams)].Name := Name;
  FParams[High(FParams)].Typ := Typ;
  FParams[High(FParams)].Default := Default;
  FParams[High(FParams)].IsRef := IsRef;
end;

procedure TFunctionDef.SetReturnType(const Typ: string);
begin
  FReturnType := Typ;
end;

procedure TFunctionDef.AddStmt(Stmt: TASTNode);
begin
  SetLength(FBody, Length(FBody) + 1);
  FBody[High(FBody)] := Stmt;
end;

function TFunctionDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'FUNCTION ' + FName;
  if FIsStatic then Result := Result + ' STATIC';
  Result := Result + LineEnding;
  for i := 0 to High(FParams) do
  begin
    Result := Result + pad + '  param ' + FParams[i].Name;
    if FParams[i].Typ <> '' then Result := Result + ':' + FParams[i].Typ;
    if FParams[i].IsRef then Result := Result + ' REF';
    Result := Result + LineEnding;
  end;
  if FReturnType <> '' then Result := Result + pad + '  returns ' + FReturnType + LineEnding;
  for s in FBody do
    Result := Result + s.Dump(Indent + 1) + LineEnding;
  Result := Result + pad + 'ENDFUNC';
end;

constructor TProcedureDef.Create(const AName: string; AIsStatic: Boolean; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
  FIsStatic := AIsStatic;
end;

destructor TProcedureDef.Destroy;
var
  s: TASTNode;
begin
  for s in FBody do s.Free;
  inherited;
end;

procedure TProcedureDef.AddParam(const Name, Typ: string; Default: TExpr; IsRef: Boolean);
begin
  SetLength(FParams, Length(FParams) + 1);
  FParams[High(FParams)].Name := Name;
  FParams[High(FParams)].Typ := Typ;
  FParams[High(FParams)].Default := Default;
  FParams[High(FParams)].IsRef := IsRef;
end;

procedure TProcedureDef.AddStmt(Stmt: TASTNode);
begin
  SetLength(FBody, Length(FBody) + 1);
  FBody[High(FBody)] := Stmt;
end;

function TProcedureDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'PROCEDURE ' + FName;
  if FIsStatic then Result := Result + ' STATIC';
  Result := Result + LineEnding;
  for i := 0 to High(FParams) do
  begin
    Result := Result + pad + '  param ' + FParams[i].Name;
    if FParams[i].Typ <> '' then Result := Result + ':' + FParams[i].Typ;
    if FParams[i].IsRef then Result := Result + ' REF';
    Result := Result + LineEnding;
  end;
  for s in FBody do
    Result := Result + s.Dump(Indent + 1) + LineEnding;
  Result := Result + pad + 'ENDPROC';
end;

constructor TClassDef.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
end;

destructor TClassDef.Destroy;
begin
  inherited;
end;

procedure TClassDef.AddParent(const Name: string);
begin
  SetLength(FParentClasses, Length(FParentClasses) + 1);
  FParentClasses[High(FParentClasses)] := Name;
end;

function TClassDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'CLASS ' + FName;
  if Length(FParentClasses) > 0 then
    Result := Result + ' FROM ' + String.Join(', ', FParentClasses);
  Result := Result + LineEnding + pad + 'ENDCLASS';
end;

constructor TStructDef.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
end;

function TStructDef.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'STRUCT ' + FName;
end;

constructor TNewTypeDef.Create(const AName, ABaseType: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
  FBaseType := ABaseType;
end;

function TNewTypeDef.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'NEWTYPE ' + FName + ' = ' + FBaseType;
end;

constructor TCompilationUnit.Create(ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
end;

destructor TCompilationUnit.Destroy;
var
  n: TASTNode;
begin
  for n in FNodes do n.Free;
  inherited;
end;

procedure TCompilationUnit.AddNode(Node: TASTNode);
begin
  SetLength(FNodes, Length(FNodes) + 1);
  FNodes[High(FNodes)] := Node;
end;

function TCompilationUnit.Dump(Indent: Integer = 0): string;
var
  pad: string;
  n: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'COMPILATION_UNIT' + LineEnding;
  for n in FNodes do
    Result := Result + n.Dump(Indent + 1) + LineEnding;
end;

function TCompilationUnit.GetNode(Index: Integer): TASTNode;
begin
  if (Index >= 0) and (Index < Length(FNodes)) then
    Result := FNodes[Index]
  else
    Result := nil;
end;

function TCompilationUnit.GetNodeCount: Integer;
begin
  Result := Length(FNodes);
end;

end.