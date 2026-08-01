unit fxb.ast.def;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fxb.ast.base,
  fxb.ast.expr,
  fxb.ast.stmt,
  fxb.tokens;

type

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
    property ReturnType: string read FReturnType;
    function GetParamCount: Integer;
    property ParamCount: Integer read GetParamCount;
    function GetParamName(Index: Integer): string;
    function GetParamType(Index: Integer): string;
    function GetParamDefault(Index: Integer): TExpr;
    function GetParamIsRef(Index: Integer): Boolean;
    property Body: TASTNodeArray read FBody;
    property HasExplicitReturn: Boolean read FHasExplicitReturn;
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
    property Name: string read FName;
    function GetParamCount: Integer;
    property ParamCount: Integer read GetParamCount;
    function GetParamName(Index: Integer): string;
    function GetParamType(Index: Integer): string;
    function GetParamDefault(Index: Integer): TExpr;
    function GetParamIsRef(Index: Integer): Boolean;
    property Body: TASTNodeArray read FBody;
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
    property Name: string read FName;
    property ParentClasses: TStringArray read FParentClasses;
  end;

  TStructDef = class(TASTNode)
  private
    FName: string;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
  end;

  TNewTypeDef = class(TASTNode)
  private
    FName, FBaseType: string;
  public
    constructor Create(const AName, ABaseType: string; ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
    property BaseType: string read FBaseType;
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

function TFunctionDef.GetParamCount: Integer;
begin
  Result := Length(FParams);
end;

function TFunctionDef.GetParamName(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].Name
  else
    Result := '';
end;

function TFunctionDef.GetParamType(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].Typ
  else
    Result := '';
end;

function TFunctionDef.GetParamDefault(Index: Integer): TExpr;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].Default
  else
    Result := nil;
end;

function TFunctionDef.GetParamIsRef(Index: Integer): Boolean;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].IsRef
  else
    Result := False;
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

function TProcedureDef.GetParamCount: Integer;
begin
  Result := Length(FParams);
end;

function TProcedureDef.GetParamName(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].Name
  else
    Result := '';
end;

function TProcedureDef.GetParamType(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].Typ
  else
    Result := '';
end;

function TProcedureDef.GetParamDefault(Index: Integer): TExpr;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].Default
  else
    Result := nil;
end;

function TProcedureDef.GetParamIsRef(Index: Integer): Boolean;
begin
  if (Index >= 0) and (Index < Length(FParams)) then
    Result := FParams[Index].IsRef
  else
    Result := False;
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
