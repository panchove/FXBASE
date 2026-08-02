unit fxb.ast.expr;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fxb.ast.base,
  fxb.tokens,
  fxb.ast.expr.binary;

type

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

  // Re-export TBinaryExpr from dedicated unit
  TBinaryExpr = fxb.ast.expr.binary.TBinaryExpr;

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

  TIndexExpr = class(TExpr)
  private
    FTarget: TExpr;
    FIndex: TExpr;
  public
    constructor Create(ATarget, AIndex: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Target: TExpr read FTarget;
    property Index: TExpr read FIndex;
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
    property TypeName: string read FTypeName;
    property Args: TExprArray read FArgs;
  end;

  TMacroExpr = class(TExpr)
  private
    FName: string;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
  end;

implementation

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

constructor TIndexExpr.Create(ATarget, AIndex: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FTarget := ATarget;
  FIndex := AIndex;
end;

destructor TIndexExpr.Destroy;
begin
  FTarget.Free;
  FIndex.Free;
  inherited;
end;

function TIndexExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'INDEX [' + LineEnding;
  Result := Result + FTarget.Dump(Indent + 1) + LineEnding;
  Result := Result + FIndex.Dump(Indent + 1);
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

end.
