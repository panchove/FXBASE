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

  TMethodDef = class(TFunctionDef)
  private
    FIsVirtual: Boolean;
    FIsOverride: Boolean;
    FIsAbstract: Boolean;
  public
    constructor Create(const AName: string; AIsStatic, AIsVirtual, AIsOverride, AIsAbstract: Boolean;
      ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
    property IsVirtual: Boolean read FIsVirtual;
    property IsOverride: Boolean read FIsOverride;
    property IsAbstract: Boolean read FIsAbstract;
  end;

  TConstructorDef = class(TFunctionDef)
  public
    constructor Create(ALine, ACol: Integer);
    function Dump(Indent: Integer = 0): string; override;
  end;

  TClassDef = class(TASTNode)
  private
    FName: string;
    FParentClasses: array of string;
    FTypeParams: array of string;
    FImplements: array of string;
    FMethods: array of TMethodDef;
    FConstructors: array of TConstructorDef;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddParent(const Name: string);
    procedure AddTypeParam(const Name: string);
    procedure AddImplements(const Name: string);
    procedure AddMethod(Method: TMethodDef);
    procedure AddConstructor(Ctor: TConstructorDef);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
    property ParentClasses: TStringArray read FParentClasses;
    function GetTypeParamCount: Integer;
    property TypeParamCount: Integer read GetTypeParamCount;
    function GetTypeParam(Index: Integer): string;
    function GetImplementsCount: Integer;
    property ImplementsCount: Integer read GetImplementsCount;
    function GetImplements(Index: Integer): string;
    function GetMethodCount: Integer;
    property MethodCount: Integer read GetMethodCount;
    function GetMethod(Index: Integer): TMethodDef;
    property Methods[Index: Integer]: TMethodDef read GetMethod;
    function GetConstructorCount: Integer;
    property ConstructorCount: Integer read GetConstructorCount;
    function GetConstructor(Index: Integer): TConstructorDef;
    property Constructors[Index: Integer]: TConstructorDef read GetConstructor;
  end;

  TInterfaceDef = class(TASTNode)
  private
    FName: string;
    FMethods: array of TMethodDef;
  public
    constructor Create(const AName: string; ALine, ACol: Integer);
    destructor Destroy; override;
    procedure AddMethod(Method: TMethodDef);
    function Dump(Indent: Integer = 0): string; override;
    property Name: string read FName;
    function GetMethodCount: Integer;
    property MethodCount: Integer read GetMethodCount;
    function GetMethod(Index: Integer): TMethodDef;
    property Methods[Index: Integer]: TMethodDef read GetMethod;
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
  if Stmt = nil then Exit;
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

constructor TMethodDef.Create(const AName: string; AIsStatic, AIsVirtual, AIsOverride, AIsAbstract: Boolean;
  ALine, ACol: Integer);
begin
  inherited Create(AName, AIsStatic, ALine, ACol);
  FIsVirtual := AIsVirtual;
  FIsOverride := AIsOverride;
  FIsAbstract := AIsAbstract;
end;

constructor TConstructorDef.Create(ALine, ACol: Integer);
begin
  inherited Create('CONSTRUCTOR', False, ALine, ACol);
end;

function TConstructorDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'CONSTRUCTOR';
  Result := Result + LineEnding;
  for i := 0 to High(FParams) do
  begin
    Result := Result + pad + '  param ' + FParams[i].Name;
    if FParams[i].Typ <> '' then Result := Result + ':' + FParams[i].Typ;
    Result := Result + LineEnding;
  end;
  for s in FBody do
    Result := Result + s.Dump(Indent + 1) + LineEnding;
  Result := Result + pad + 'END';
end;

function TMethodDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
  i: Integer;
  s: TASTNode;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'METHOD ' + FName;
  if FIsStatic then Result := Result + ' STATIC';
  if FIsVirtual then Result := Result + ' VIRTUAL';
  if FIsOverride then Result := Result + ' OVERRIDE';
  if FIsAbstract then Result := Result + ' ABSTRACT';
  Result := Result + LineEnding;
  for i := 0 to High(FParams) do
  begin
    Result := Result + pad + '  param ' + FParams[i].Name;
    if FParams[i].Typ <> '' then Result := Result + ':' + FParams[i].Typ;
    if FParams[i].IsRef then Result := Result + ' REF';
    Result := Result + LineEnding;
  end;
  if FReturnType <> '' then Result := Result + pad + '  returns ' + FReturnType + LineEnding;
  if Length(FBody) > 0 then
  begin
    for s in FBody do
      Result := Result + s.Dump(Indent + 1) + LineEnding;
    Result := Result + pad + 'ENDMETHOD';
  end;
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
  if Stmt = nil then Exit;
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
var
  m: TMethodDef;
  c: TConstructorDef;
begin
  for m in FMethods do m.Free;
  for c in FConstructors do c.Free;
  inherited;
end;

procedure TClassDef.AddParent(const Name: string);
begin
  SetLength(FParentClasses, Length(FParentClasses) + 1);
  FParentClasses[High(FParentClasses)] := Name;
end;

procedure TClassDef.AddTypeParam(const Name: string);
begin
  SetLength(FTypeParams, Length(FTypeParams) + 1);
  FTypeParams[High(FTypeParams)] := Name;
end;

procedure TClassDef.AddImplements(const Name: string);
begin
  SetLength(FImplements, Length(FImplements) + 1);
  FImplements[High(FImplements)] := Name;
end;

function TClassDef.GetTypeParamCount: Integer;
begin
  Result := Length(FTypeParams);
end;

function TClassDef.GetTypeParam(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FTypeParams)) then
    Result := FTypeParams[Index]
  else
    Result := '';
end;

function TClassDef.GetImplementsCount: Integer;
begin
  Result := Length(FImplements);
end;

function TClassDef.GetImplements(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FImplements)) then
    Result := FImplements[Index]
  else
    Result := '';
end;

procedure TClassDef.AddMethod(Method: TMethodDef);
begin
  if Method = nil then Exit;
  SetLength(FMethods, Length(FMethods) + 1);
  FMethods[High(FMethods)] := Method;
end;

procedure TClassDef.AddConstructor(Ctor: TConstructorDef);
begin
  if Ctor = nil then Exit;
  SetLength(FConstructors, Length(FConstructors) + 1);
  FConstructors[High(FConstructors)] := Ctor;
end;

function TClassDef.GetMethodCount: Integer;
begin
  Result := Length(FMethods);
end;

function TClassDef.GetMethod(Index: Integer): TMethodDef;
begin
  if (Index >= 0) and (Index < Length(FMethods)) then
    Result := FMethods[Index]
  else
    Result := nil;
end;

function TClassDef.GetConstructorCount: Integer;
begin
  Result := Length(FConstructors);
end;

function TClassDef.GetConstructor(Index: Integer): TConstructorDef;
begin
  if (Index >= 0) and (Index < Length(FConstructors)) then
    Result := FConstructors[Index]
  else
    Result := nil;
end;

function TClassDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
  m: TMethodDef;
  c: TConstructorDef;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'CLASS ' + FName;
  if Length(FTypeParams) > 0 then
    Result := Result + '<' + String.Join(', ', FTypeParams) + '>';
  if Length(FParentClasses) > 0 then
    Result := Result + ' FROM ' + String.Join(', ', FParentClasses);
  if Length(FImplements) > 0 then
    Result := Result + ' IMPLEMENTS ' + String.Join(', ', FImplements);
  Result := Result + LineEnding;
  for c in FConstructors do
    Result := Result + c.Dump(Indent + 1) + LineEnding;
  for m in FMethods do
    Result := Result + m.Dump(Indent + 1) + LineEnding;
  Result := Result + pad + 'ENDCLASS';
end;

constructor TInterfaceDef.Create(const AName: string; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FName := AName;
end;

destructor TInterfaceDef.Destroy;
var
  m: TMethodDef;
begin
  for m in FMethods do m.Free;
  inherited;
end;

procedure TInterfaceDef.AddMethod(Method: TMethodDef);
begin
  if Method = nil then Exit;
  SetLength(FMethods, Length(FMethods) + 1);
  FMethods[High(FMethods)] := Method;
end;

function TInterfaceDef.GetMethodCount: Integer;
begin
  Result := Length(FMethods);
end;

function TInterfaceDef.GetMethod(Index: Integer): TMethodDef;
begin
  if (Index >= 0) and (Index < Length(FMethods)) then
    Result := FMethods[Index]
  else
    Result := nil;
end;

function TInterfaceDef.Dump(Indent: Integer = 0): string;
var
  pad: string;
  m: TMethodDef;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'INTERFACE ' + FName + LineEnding;
  for m in FMethods do
    Result := Result + m.Dump(Indent + 1) + LineEnding;
  Result := Result + pad + 'ENDINTERFACE';
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
