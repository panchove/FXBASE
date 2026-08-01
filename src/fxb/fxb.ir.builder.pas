unit fxb.ir.builder;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  fxb.ast,
  fxb.tokens,
  fxb.errors,
  fxb.ir.types,
  fxb.ir.instr;

type
  TIRBuilder = class
  public
    FModule: TIRModule;
    FCurrentFunction: TIRFunction;
    FCurrentBlock: TIRBlock;
    FBreakTargets: TIRBlockArray;
    FContinueTargets: TIRBlockArray;
    FReturnTargets: TIRBlockArray;
    FLoopDepth: Integer;
    FDebugInfo: Boolean;
    FLocalVarMap: TStringList;
    FNextValueId: Integer;
    FNextBlockId: Integer;
    FTypeCache: TStringList;

    function GetIRType(const TypeName: string): TIRType;
    function GetIRTypeFromToken(AToken: TToken): TIRType;
    function CreateTempName(const Prefix: string): string;
    function CreateBlockName(const Prefix: string): string;
    procedure PushBreakTarget(Block: TIRBlock);
    procedure PopBreakTarget;
    function CurrentBreakTarget: TIRBlock;
    procedure PushContinueTarget(Block: TIRBlock);
    procedure PopContinueTarget;
    function CurrentContinueTarget: TIRBlock;
    procedure PushReturnTarget(Block: TIRBlock);
    procedure PopReturnTarget;
    function CurrentReturnTarget: TIRBlock;

    procedure EmitInstr(Instr: TIRInstruction);
    function EmitBinOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
    function EmitCmpOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
    function EmitCast(OpKind: TIRInstructionKind; Val: TIRValue; DestType: TIRType; const Name: string = ''): TIRValue;
    function CreateAlloca(const AType: TIRType; const Name: string): TIRLocal;
    function CreateLoad(Ptr: TIRValue; const Name: string): TIRValue;
    function CreateStore(Val, Ptr: TIRValue): TIRInstruction;
    function CreateCall(Func: TIRFunction; Args: TIRValueArray; const Name: string = ''): TIRValue;
    function CreateCallDirect(const FuncName: string; const RetType: TIRType; Args: TIRValueArray; const Name: string = ''): TIRValue;

    // AST lowering helpers (may be moved later)
    procedure LowerCompilationUnit(AST: TCompilationUnit);
    procedure LowerFunctionDef(Func: TFunctionDef);
    procedure LowerProcedureDef(Proc: TProcedureDef);
    procedure LowerClassDef(ClassDef: TClassDef);
    procedure LowerStructDef(StructDef: TStructDef);
    procedure LowerNewTypeDef(NewTypeDef: TNewTypeDef);
    procedure LowerStatement(Stmt: TASTNode);
    procedure LowerExprStmt(Stmt: TExprStmt);
    procedure LowerVarDecl(Stmt: TVarDeclStmt);
    procedure LowerAssign(Stmt: TAssignStmt);
    procedure LowerIf(Stmt: TIfStmt);
    procedure LowerFor(Stmt: TForStmt);
    procedure LowerWhile(Stmt: TWhileStmt);
    procedure LowerReturn(Stmt: TReturnStmt);
    procedure LowerYield(Stmt: TYieldStmt);
    procedure LowerLoopCtrl(Stmt: TLoopCtrlStmt);
    function LowerExpression(Expr: TExpr): TIRValue;
    function LowerLiteral(Expr: TLiteralExpr): TIRValue;
    function LowerIdentifier(Expr: TIdentifierExpr): TIRValue;
    function LowerBinary(Expr: TBinaryExpr): TIRValue;
    function LowerUnary(Expr: TUnaryExpr): TIRValue;
    function LowerCall(Expr: TCallExpr): TIRValue;
    function LowerMethodCall(Expr: TMethodCallExpr): TIRValue;
    function LowerMemberAccess(Expr: TMemberAccessExpr): TIRValue;
    function LowerDeref(Expr: TDerefExpr): TIRValue;
    function LowerArrayLiteral(Expr: TArrayLiteralExpr): TIRValue;
    function LowerHashLiteral(Expr: THashLiteralExpr): TIRValue;
    function LowerCodeBlock(Expr: TCodeBlockExpr): TIRValue;
    function LowerStructLiteral(Expr: TStructLiteralExpr): TIRValue;
    function LowerMacro(Expr: TMacroExpr): TIRValue;

    function MapTokenTypeToBinOp(TT: TTokenType): TIRInstructionKind;
    function MapTokenTypeToCmpOp(TT: TTokenType): TIRInstructionKind;
    function MapTokenTypeToUnaryOp(TT: TTokenType): TIRInstructionKind;

    procedure ReportError(Code: Integer; const Msg: string; Line, Col: Integer);
    procedure ReportErrorNode(Node: TASTNode; Code: Integer; const Msg: string);

    constructor Create(AModule: TIRModule);
    destructor Destroy; override;
  end;

implementation

{ TIRBuilder }

constructor TIRBuilder.Create(AModule: TIRModule);
begin
  inherited Create;
  FModule := AModule;
  FNextValueId := 0;
  FNextBlockId := 0;
  FLoopDepth := 0;
  FLocalVarMap := TStringList.Create;
  FTypeCache := TStringList.Create;
end;

destructor TIRBuilder.Destroy;
begin
  FLocalVarMap.Free;
  FTypeCache.Free;
  inherited Destroy;
end;

function TIRBuilder.GetIRType(const TypeName: string): TIRType;
begin
  // stub: forward to original implementation later
  Result := TIRType.AnyType;
end;

function TIRBuilder.GetIRTypeFromToken(AToken: TToken): TIRType;
begin
  Result := TIRType.AnyType;
end;

function TIRBuilder.CreateTempName(const Prefix: string): string;
begin
  Inc(FNextValueId);
  Result := Prefix + IntToStr(FNextValueId);
end;

function TIRBuilder.CreateBlockName(const Prefix: string): string;
begin
  Inc(FNextBlockId);
  Result := Prefix + IntToStr(FNextBlockId);
end;

procedure TIRBuilder.PushBreakTarget(Block: TIRBlock);
begin
  SetLength(FBreakTargets, Length(FBreakTargets) + 1);
  FBreakTargets[High(FBreakTargets)] := Block;
end;

procedure TIRBuilder.PopBreakTarget;
begin
  if Length(FBreakTargets) > 0 then
    SetLength(FBreakTargets, Length(FBreakTargets) - 1);
end;

function TIRBuilder.CurrentBreakTarget: TIRBlock;
begin
  if Length(FBreakTargets) > 0 then
    Result := FBreakTargets[High(FBreakTargets)]
  else
    Result := nil;
end;

procedure TIRBuilder.PushContinueTarget(Block: TIRBlock);
begin
  SetLength(FContinueTargets, Length(FContinueTargets) + 1);
  FContinueTargets[High(FContinueTargets)] := Block;
end;

procedure TIRBuilder.PopContinueTarget;
begin
  if Length(FContinueTargets) > 0 then
    SetLength(FContinueTargets, Length(FContinueTargets) - 1);
end;

function TIRBuilder.CurrentContinueTarget: TIRBlock;
begin
  if Length(FContinueTargets) > 0 then
    Result := FContinueTargets[High(FContinueTargets)]
  else
    Result := nil;
end;

procedure TIRBuilder.PushReturnTarget(Block: TIRBlock);
begin
  SetLength(FReturnTargets, Length(FReturnTargets) + 1);
  FReturnTargets[High(FReturnTargets)] := Block;
end;

procedure TIRBuilder.PopReturnTarget;
begin
  if Length(FReturnTargets) > 0 then
    SetLength(FReturnTargets, Length(FReturnTargets) - 1);
end;

function TIRBuilder.CurrentReturnTarget: TIRBlock;
begin
  if Length(FReturnTargets) > 0 then
    Result := FReturnTargets[High(FReturnTargets)]
  else
    Result := nil;
end;

procedure TIRBuilder.EmitInstr(Instr: TIRInstruction);
begin
  if Assigned(FCurrentBlock) then
  begin
    FCurrentBlock.AddInstr(Instr);
    if FDebugInfo then
      Instr.DebugLoc := Format('line %d col %d', [0, 0]);
  end;
end;

function TIRBuilder.EmitBinOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
  resultType: TIRType;
begin
  resultType := Left.Type_;
  instr := TIRInstruction.Create(OpKind, resultType, Name);
  instr.AddOperand(Left);
  instr.AddOperand(Right);
  EmitInstr(instr);
  Result := instr;
end;

function TIRBuilder.EmitCmpOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.EmitCast(OpKind: TIRInstructionKind; Val: TIRValue; DestType: TIRType; const Name: string = ''): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.CreateAlloca(const AType: TIRType; const Name: string): TIRLocal;
var
  local: TIRLocal;
  instr: TIRInstruction;
begin
  local := FCurrentFunction.AddLocal(AType, Name);
  instr := TIRInstruction.Create(ikAlloca, TIRType.Pointer(AType), Name);
  instr.AddOperand(local);
  EmitInstr(instr);
  Result := local;
end;

function TIRBuilder.CreateLoad(Ptr: TIRValue; const Name: string): TIRValue;
var
  instr: TIRInstruction;
  elemType: TIRType;
begin
  if (Ptr.Type_.Kind = tkPointer) and Assigned(Ptr.Type_.ElementType) then
    elemType := Ptr.Type_.ElementType^
  else
    elemType := TIRType.AnyType;
  instr := TIRInstruction.Create(ikLoad, elemType, Name);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TIRBuilder.CreateStore(Val, Ptr: TIRValue): TIRInstruction;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(ikStore, TIRType.Void, '');
  instr.AddOperand(Val);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TIRBuilder.CreateCall(Func: TIRFunction; Args: TIRValueArray; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
  i: Integer;
begin
  instr := TIRInstruction.Create(ikCall, Func.ReturnType, Name);
  instr.AddOperand(Func);
  for i := 0 to High(Args) do
    instr.AddOperand(Args[i]);
  EmitInstr(instr);
  Result := instr;
end;

function TIRBuilder.CreateCallDirect(const FuncName: string; const RetType: TIRType; Args: TIRValueArray; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
  i: Integer;
  fn: TIRFunction;
begin
  fn := FModule.GetFunction(FuncName);
  if not Assigned(fn) then
    fn := FModule.AddFunction(FuncName, RetType);
  instr := TIRInstruction.Create(ikCallDirect, RetType, Name);
  instr.AddOperand(fn);
  for i := 0 to High(Args) do
    instr.AddOperand(Args[i]);
  EmitInstr(instr);
  Result := instr;
end;

// The lowering methods are stubs here; actual implementation remains in TFXBIRGenerator
procedure TIRBuilder.LowerCompilationUnit(AST: TCompilationUnit);
begin
end;

procedure TIRBuilder.LowerFunctionDef(Func: TFunctionDef);
begin
end;

procedure TIRBuilder.LowerProcedureDef(Proc: TProcedureDef);
begin
end;

procedure TIRBuilder.LowerClassDef(ClassDef: TClassDef);
begin
end;

procedure TIRBuilder.LowerStructDef(StructDef: TStructDef);
begin
end;

procedure TIRBuilder.LowerNewTypeDef(NewTypeDef: TNewTypeDef);
begin
end;

procedure TIRBuilder.LowerStatement(Stmt: TASTNode);
begin
  if Stmt is TExprStmt then Self.LowerExprStmt(TExprStmt(Stmt))
  else if Stmt is TVarDeclStmt then Self.LowerVarDecl(TVarDeclStmt(Stmt))
  else if Stmt is TAssignStmt then Self.LowerAssign(TAssignStmt(Stmt))
  else if Stmt is TIfStmt then Self.LowerIf(TIfStmt(Stmt))
  else if Stmt is TForStmt then Self.LowerFor(TForStmt(Stmt))
  else if Stmt is TWhileStmt then Self.LowerWhile(TWhileStmt(Stmt))
  else if Stmt is TReturnStmt then Self.LowerReturn(TReturnStmt(Stmt))
  else if Stmt is TYieldStmt then Self.LowerYield(TYieldStmt(Stmt))
  else if Stmt is TLoopCtrlStmt then Self.LowerLoopCtrl(TLoopCtrlStmt(Stmt));
end;

procedure TIRBuilder.LowerExprStmt(Stmt: TExprStmt);
begin
  Self.LowerExpression(Stmt.Expr);
end;

procedure TIRBuilder.LowerVarDecl(Stmt: TVarDeclStmt);
var
  i: Integer;
  varName, varType: string;
  initVal: TExpr;
  irType: TIRType;
  local: TIRLocal;
  val: TIRValue;
begin
  for i := 0 to Stmt.VarCount - 1 do
  begin
    varName := Stmt.Names[i];
    varType := Stmt.GetType(i);
    initVal := Stmt.GetInitVal(i);
    if varType <> '' then
      irType := Self.GetIRType(varType)
    else
      irType := TIRType.AnyType;
    local := FCurrentFunction.AddLocal(irType, varName);
    FLocalVarMap.AddObject(varName, local);
    if Assigned(initVal) then
    begin
      val := Self.LowerExpression(initVal);
      Self.CreateStore(val, local);
    end;
  end;
end;

procedure TIRBuilder.LowerAssign(Stmt: TAssignStmt);
var
  target, value: TIRValue;
begin
  target := Self.LowerExpression(Stmt.Target);
  value := Self.LowerExpression(Stmt.Value);
  Self.CreateStore(value, target);
end;

procedure TIRBuilder.LowerIf(Stmt: TIfStmt);
var
  condVal: TIRValue;
  thenBlock, elseBlock, mergeBlock: TIRBlock;
  i, j: Integer;
  hasElseIf: Boolean;
  innerBody: array of TASTNode;
begin
  condVal := Self.LowerExpression(Stmt.Condition);
  thenBlock := FCurrentFunction.CreateBlock(Self.CreateBlockName('then'));
  elseBlock := FCurrentFunction.CreateBlock(Self.CreateBlockName('else'));
  mergeBlock := FCurrentFunction.CreateBlock(Self.CreateBlockName('merge'));

  Self.EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condVal);
  FCurrentBlock.GetLastInstr.AddOperand(thenBlock);
  FCurrentBlock.GetLastInstr.AddOperand(elseBlock);

  FCurrentBlock := thenBlock;
  for i := 0 to High(Stmt.ThenBody) do
    Self.LowerStatement(Stmt.ThenBody[i]);
  if not FCurrentBlock.IsTerminated then
    Self.EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);

  hasElseIf := Length(Stmt.ElseIfConds) > 0;
  if hasElseIf or Stmt.HasElse then
  begin
    FCurrentBlock := elseBlock;
    if hasElseIf then
    begin
      for i := 0 to High(Stmt.ElseIfConds) do
      begin
        condVal := Self.LowerExpression(Stmt.ElseIfConds[i]);
        thenBlock := FCurrentFunction.CreateBlock(Self.CreateBlockName('elseif.then'));
        elseBlock := FCurrentFunction.CreateBlock(Self.CreateBlockName('elseif.else'));
        Self.EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
        FCurrentBlock.GetLastInstr.AddOperand(condVal);
        FCurrentBlock.GetLastInstr.AddOperand(thenBlock);
        FCurrentBlock.GetLastInstr.AddOperand(elseBlock);
        FCurrentBlock := thenBlock;
        innerBody := Stmt.ElseIfBodies[i];
        for j := 0 to High(innerBody) do
          Self.LowerStatement(innerBody[j]);
        if not FCurrentBlock.IsTerminated then
          Self.EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
        FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
        FCurrentBlock := elseBlock;
      end;
    end;
    if Stmt.HasElse then
    begin
      for i := 0 to High(Stmt.ElseBody) do
        Self.LowerStatement(Stmt.ElseBody[i]);
    end;
    if not FCurrentBlock.IsTerminated then
      Self.EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
  end
  else
  begin
    Self.EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
  end;
  FCurrentBlock := mergeBlock;
end;

procedure TIRBuilder.LowerFor(Stmt: TForStmt);
begin
end;

procedure TIRBuilder.LowerWhile(Stmt: TWhileStmt);
begin
end;

procedure TIRBuilder.LowerReturn(Stmt: TReturnStmt);
begin
end;

procedure TIRBuilder.LowerYield(Stmt: TYieldStmt);
begin
end;

procedure TIRBuilder.LowerLoopCtrl(Stmt: TLoopCtrlStmt);
begin
end;

function TIRBuilder.LowerExpression(Expr: TExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerLiteral(Expr: TLiteralExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerIdentifier(Expr: TIdentifierExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerBinary(Expr: TBinaryExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerUnary(Expr: TUnaryExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerCall(Expr: TCallExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerMethodCall(Expr: TMethodCallExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerMemberAccess(Expr: TMemberAccessExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerDeref(Expr: TDerefExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerArrayLiteral(Expr: TArrayLiteralExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerHashLiteral(Expr: THashLiteralExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerCodeBlock(Expr: TCodeBlockExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerStructLiteral(Expr: TStructLiteralExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.LowerMacro(Expr: TMacroExpr): TIRValue;
begin
  Result := nil;
end;

function TIRBuilder.MapTokenTypeToBinOp(TT: TTokenType): TIRInstructionKind;
begin
  Result := ikInvalid;
end;

function TIRBuilder.MapTokenTypeToCmpOp(TT: TTokenType): TIRInstructionKind;
begin
  Result := ikInvalid;
end;

function TIRBuilder.MapTokenTypeToUnaryOp(TT: TTokenType): TIRInstructionKind;
begin
  Result := ikInvalid;
end;

procedure TIRBuilder.ReportError(Code: Integer; const Msg: string; Line, Col: Integer);
begin
  // placeholder
end;

procedure TIRBuilder.ReportErrorNode(Node: TASTNode; Code: Integer; const Msg: string);
begin
  // placeholder
end;

end.