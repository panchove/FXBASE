unit fxb.ir;

{$mode objfpc}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

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
  TIRTypeKind = fxb.ir.types.TIRTypeKind;
  TIRValueKind = fxb.ir.types.TIRValueKind;
  TIRType = fxb.ir.types.TIRType;
  TIRValue = fxb.ir.instr.TIRValue;
  TIRConstant = fxb.ir.instr.TIRConstant;
  TIRArgument = fxb.ir.instr.TIRArgument;
  TIRLocal = fxb.ir.instr.TIRLocal;
  TIRGlobal = fxb.ir.instr.TIRGlobal;
  TIRInstruction = fxb.ir.instr.TIRInstruction;
  TIRInstructionKind = fxb.ir.instr.TIRInstructionKind;
  TIRBlock = fxb.ir.instr.TIRBlock;
  TIRFunction = fxb.ir.instr.TIRFunction;
  TIRModule = fxb.ir.instr.TIRModule;
  TIRValueArray = fxb.ir.instr.TIRValueArray;
  TIRInstructionArray = fxb.ir.instr.TIRInstructionArray;
  TIRArgumentArray = fxb.ir.instr.TIRArgumentArray;
  TIRLocalArray = fxb.ir.instr.TIRLocalArray;
  TIRBlockArray = fxb.ir.instr.TIRBlockArray;

  TFXBIRGenerator = class
  private
    FTargetOS: string;
    FTargetCPU: string;
    FOptimizationLevel: Integer;
    FDebugInfo: Boolean;
    FErrors: TCompilerMessageArray;
    FModule: TIRModule;
    FCurrentFunction: TIRFunction;
    FCurrentBlock: TIRBlock;
    FBreakTargets: TIRBlockArray;
    FContinueTargets: TIRBlockArray;
    FReturnTargets: TIRBlockArray;
    FLoopDepth: Integer;
    FLocalVarMap: TStringList;
    FNextValueId: Integer;
    FNextBlockId: Integer;
    FTypeCache: TStringList;
    FPendingPredicate: string;
    FPrependStmts: array of TASTNode;
    FCurrentDBTable: string;

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

    // AST lowering
    procedure LowerCompilationUnit(AST: TCompilationUnit);
    procedure LowerFunctionDef(Func: TFunctionDef);
    procedure LowerProcedureDef(Proc: TProcedureDef);
    procedure LowerClassDef(ClassDef: TClassDef);
    procedure LowerStructDef(StructDef: TStructDef);
    procedure LowerNewTypeDef(NewTypeDef: TNewTypeDef);
    procedure LowerStatement(Stmt: TASTNode);
    procedure LowerExprStmt(Stmt: TExprStmt);
    procedure LowerPrint(Stmt: TPrintStmt);
    procedure LowerDBStmt(Stmt: TASTDBStmt);
    procedure LowerVarDecl(Stmt: TVarDeclStmt);
    procedure LowerAssign(Stmt: TAssignStmt);
    procedure LowerIf(Stmt: TIfStmt);
    procedure LowerFor(Stmt: TForStmt);
    procedure LowerWhile(Stmt: TWhileStmt);
    procedure LowerReturn(Stmt: TReturnStmt);
    procedure LowerYield(Stmt: TYieldStmt);
    procedure LowerLoopCtrl(Stmt: TLoopCtrlStmt);
    procedure LowerImplicitMain(Statements: array of TASTNode);
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

    // Optimization passes
    procedure RunConstantFolding;
    function FoldBinaryOp(Kind: TIRInstructionKind; Left, Right: TIRConstant; ResultType: TIRType): TIRConstant;
    procedure RunDeadCodeElimination;

  public
    property TargetOS: string read FTargetOS write FTargetOS;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property OptimizationLevel: Integer read FOptimizationLevel write FOptimizationLevel;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    function Generate(const AST: TCompilationUnit): TIRModule;
    function HasErrors: Boolean;
    property Errors: TCompilerMessageArray read FErrors;
  end;

implementation

{ TFXBIRGenerator }

function TFXBIRGenerator.Generate(const AST: TCompilationUnit): TIRModule;
begin
  FModule := TIRModule.Create('fx_module');
  FModule.TargetTriple := FTargetOS + '-' + FTargetCPU + '-none';
  FModule.SourceFileName := '';
  FNextValueId := 0;
  FNextBlockId := 0;
  FLoopDepth := 0;
  FLocalVarMap := TStringList.Create;
  FTypeCache := TStringList.Create;
  try
    LowerCompilationUnit(AST);
    if FOptimizationLevel > 0 then
    begin
      RunConstantFolding;
      RunDeadCodeElimination;
    end;
    FModule.Verify;
    Result := FModule;
  finally
    FLocalVarMap.Free;
    FTypeCache.Free;
  end;
end;

procedure TFXBIRGenerator.RunConstantFolding;
var
  fn: TIRFunction;
  blk: TIRBlock;
  fnIdx, blkIdx, instrIdx: Integer;
  instr: TIRInstruction;
  left, right: TIRValue;
  constLeft, constRight: TIRConstant;
  newConst: TIRConstant;
  resultVal: TIRValue;
begin
  for fnIdx := 0 to FModule.Functions.Count - 1 do
  begin
    fn := TIRFunction(FModule.Functions[fnIdx]);
    for blkIdx := 0 to fn.Blocks.Count - 1 do
    begin
      blk := TIRBlock(fn.Blocks[blkIdx]);
      instrIdx := 0;
      while instrIdx < blk.Instructions.Count do
      begin
        instr := TIRInstruction(blk.Instructions[instrIdx]);
        // Only fold binary operations with constant operands
        if instr.IsBinaryOp and (instr.OperandCount >= 2) then
        begin
          left := instr.GetOperand(0);
          right := instr.GetOperand(1);
          if (left is TIRConstant) and (right is TIRConstant) then
          begin
            constLeft := TIRConstant(left);
            constRight := TIRConstant(right);
            newConst := FoldBinaryOp(instr.Kind, constLeft, constRight, instr.Type_);
            if Assigned(newConst) then
            begin
              // Replace the instruction with the constant
              resultVal := newConst;
              instr.ReplaceAllUsesWith(resultVal);
              instr.EraseFromBlock;
              Dec(instrIdx); // Re-check this index since we removed an instruction
            end;
          end;
        end;
        Inc(instrIdx);
      end;
    end;
  end;
end;

function TFXBIRGenerator.FoldBinaryOp(Kind: TIRInstructionKind; Left, Right: TIRConstant; ResultType: TIRType): TIRConstant;
var
  lInt, rInt: Int64;
  lUInt, rUInt: UInt64;
  lReal, rReal: Double;
  lBool, rBool: Boolean;
  resInt: Int64;
  resUInt: UInt64;
  resReal: Double;
  resBool: Boolean;
  overflow: Boolean;
begin
  Result := nil;
  overflow := False;

  // Handle integer constants
  if (Left.Type_.Kind in [tkInt8, tkInt16, tkInt32, tkInt64, tkUInt8, tkUInt16, tkUInt32, tkUInt64]) and
     (Right.Type_.Kind in [tkInt8, tkInt16, tkInt32, tkInt64, tkUInt8, tkUInt16, tkUInt32, tkUInt64]) then
  begin
    lInt := Left.IntVal;
    rInt := Right.IntVal;
    lUInt := Left.UIntVal;
    rUInt := Right.UIntVal;

    case Kind of
      ikAdd: resInt := lInt + rInt;
      ikSub: resInt := lInt - rInt;
      ikMul: resInt := lInt * rInt;
      ikDiv:
        if rInt <> 0 then resInt := lInt div rInt else Exit(nil);
      ikRem:
        if rInt <> 0 then resInt := lInt mod rInt else Exit(nil);
      ikShl: resInt := lInt shl rInt;
      ikShr: resInt := lInt shr rInt;
      ikAnd: resInt := lInt and rInt;
      ikOr:  resInt := lInt or rInt;
      ikXor: resInt := lInt xor rInt;
      else Exit(nil);
    end;

    Result := TIRConstant.CreateInt(ResultType, resInt, 'const.folded');
    Exit;
  end;

  // Handle float constants
  if (Left.Type_.Kind in [tkFloat32, tkFloat64]) and (Right.Type_.Kind in [tkFloat32, tkFloat64]) then
  begin
    lReal := Left.RealVal;
    rReal := Right.RealVal;

    case Kind of
      ikAdd: resReal := lReal + rReal;
      ikSub: resReal := lReal - rReal;
      ikMul: resReal := lReal * rReal;
      ikDiv:
        if rReal <> 0.0 then resReal := lReal / rReal else Exit(nil);
      else Exit(nil);
    end;

    Result := TIRConstant.CreateReal(ResultType, resReal, 'const.folded');
    Exit;
  end;

  // Handle boolean/logical constants
  if (Left.Type_.Kind = tkBool) and (Right.Type_.Kind = tkBool) then
  begin
    lBool := Left.BoolVal;
    rBool := Right.BoolVal;

    case Kind of
      ikAnd: resBool := lBool and rBool;
      ikOr:  resBool := lBool or rBool;
      ikXor: resBool := lBool xor rBool;
      else Exit(nil);
    end;

    Result := TIRConstant.CreateBool(ResultType, resBool, 'const.folded');
    Exit;
  end;
end;

procedure TFXBIRGenerator.RunDeadCodeElimination;
var
  fn: TIRFunction;
  blk: TIRBlock;
  fnIdx, blkIdx, instrIdx: Integer;
  instr: TIRInstruction;
  hasTerminator: Boolean;
begin
  for fnIdx := 0 to FModule.Functions.Count - 1 do
  begin
    fn := TIRFunction(FModule.Functions[fnIdx]);
    for blkIdx := 0 to fn.Blocks.Count - 1 do
    begin
      blk := TIRBlock(fn.Blocks[blkIdx]);
      hasTerminator := False;
      instrIdx := 0;
      while instrIdx < blk.Instructions.Count do
      begin
        instr := TIRInstruction(blk.Instructions[instrIdx]);
        if instr.IsTerminator then
        begin
          hasTerminator := True;
          // Remove all instructions after terminator
          while (instrIdx + 1) < blk.Instructions.Count do
          begin
            TIRInstruction(blk.Instructions[instrIdx + 1]).EraseFromBlock;
          end;
          Break;
        end;
        Inc(instrIdx);
      end;
      // Remove empty blocks that are not entry and have no predecessors (optional)
    end;
  end;
end;

function TFXBIRGenerator.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

function TFXBIRGenerator.CreateTempName(const Prefix: string): string;
begin
  Inc(FNextValueId);
  Result := Prefix + IntToStr(FNextValueId);
end;

function TFXBIRGenerator.CreateBlockName(const Prefix: string): string;
begin
  Inc(FNextBlockId);
  Result := Prefix + IntToStr(FNextBlockId);
end;

procedure TFXBIRGenerator.PushBreakTarget(Block: TIRBlock);
begin
  SetLength(FBreakTargets, Length(FBreakTargets) + 1);
  FBreakTargets[High(FBreakTargets)] := Block;
end;

procedure TFXBIRGenerator.PopBreakTarget;
begin
  if Length(FBreakTargets) > 0 then
    SetLength(FBreakTargets, Length(FBreakTargets) - 1);
end;

function TFXBIRGenerator.CurrentBreakTarget: TIRBlock;
begin
  if Length(FBreakTargets) > 0 then
    Result := FBreakTargets[High(FBreakTargets)]
  else
    Result := nil;
end;

procedure TFXBIRGenerator.PushContinueTarget(Block: TIRBlock);
begin
  SetLength(FContinueTargets, Length(FContinueTargets) + 1);
  FContinueTargets[High(FContinueTargets)] := Block;
end;

procedure TFXBIRGenerator.PopContinueTarget;
begin
  if Length(FContinueTargets) > 0 then
    SetLength(FContinueTargets, Length(FContinueTargets) - 1);
end;

function TFXBIRGenerator.CurrentContinueTarget: TIRBlock;
begin
  if Length(FContinueTargets) > 0 then
    Result := FContinueTargets[High(FContinueTargets)]
  else
    Result := nil;
end;

procedure TFXBIRGenerator.PushReturnTarget(Block: TIRBlock);
begin
  SetLength(FReturnTargets, Length(FReturnTargets) + 1);
  FReturnTargets[High(FReturnTargets)] := Block;
end;

procedure TFXBIRGenerator.PopReturnTarget;
begin
  if Length(FReturnTargets) > 0 then
    SetLength(FReturnTargets, Length(FReturnTargets) - 1);
end;

function TFXBIRGenerator.CurrentReturnTarget: TIRBlock;
begin
  if Length(FReturnTargets) > 0 then
    Result := FReturnTargets[High(FReturnTargets)]
  else
    Result := nil;
end;

procedure TFXBIRGenerator.EmitInstr(Instr: TIRInstruction);
begin
  if Assigned(FCurrentBlock) then
  begin
    FCurrentBlock.AddInstr(Instr);
    if FDebugInfo then
      Instr.DebugLoc := Format('line %d col %d', [0, 0]);
  end;
end;

function TFXBIRGenerator.EmitBinOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
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

function TFXBIRGenerator.EmitCmpOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(OpKind, TIRType.Bool, Name);
  instr.AddOperand(Left);
  instr.AddOperand(Right);
  instr.Metadata.Values['pred'] := FPendingPredicate;
  EmitInstr(instr);
  Result := instr;
end;

function TFXBIRGenerator.EmitCast(OpKind: TIRInstructionKind; Val: TIRValue; DestType: TIRType; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(OpKind, DestType, Name);
  instr.AddOperand(Val);
  EmitInstr(instr);
  Result := instr;
end;

function TFXBIRGenerator.CreateAlloca(const AType: TIRType; const Name: string): TIRLocal;
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

function TFXBIRGenerator.CreateLoad(Ptr: TIRValue; const Name: string): TIRValue;
var
  instr: TIRInstruction;
  elemType: TIRType;
begin
  if Ptr is TIRLocal then
    elemType := TIRLocal(Ptr).Type_
  else if (Ptr.Type_.Kind = tkPointer) and Assigned(Ptr.Type_.ElementType) then
    elemType := Ptr.Type_.ElementType^
  else
    elemType := TIRType.AnyType;
  instr := TIRInstruction.Create(ikLoad, elemType, Name);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TFXBIRGenerator.CreateStore(Val, Ptr: TIRValue): TIRInstruction;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(ikStore, TIRType.Void, '');
  instr.AddOperand(Val);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TFXBIRGenerator.CreateCall(Func: TIRFunction; Args: TIRValueArray; const Name: string = ''): TIRValue;
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

function TFXBIRGenerator.CreateCallDirect(const FuncName: string; const RetType: TIRType; Args: TIRValueArray; const Name: string = ''): TIRValue;
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

function TFXBIRGenerator.GetIRType(const TypeName: string): TIRType;
var
  upper: string;
begin
  upper := UpperCase(TypeName);
  if upper = 'VOID' then Exit(TIRType.Void)
  else if upper = 'LOGIC' then Exit(TIRType.Bool)
  else if upper = 'BOOL' then Exit(TIRType.Bool)
  else if upper = 'STRING' then Exit(TIRType.StringType)
  else if upper = 'INT' then Exit(TIRType.Int(True, 32))
  else if upper = 'INTEGER' then Exit(TIRType.Int(True, 32))
  else if upper = 'INT8' then Exit(TIRType.Int(True, 8))
  else if upper = 'INT16' then Exit(TIRType.Int(True, 16))
  else if upper = 'INT32' then Exit(TIRType.Int(True, 32))
  else if upper = 'INT64' then Exit(TIRType.Int(True, 64))
  else if upper = 'UINT' then Exit(TIRType.Int(False, 32))
  else if upper = 'UINT8' then Exit(TIRType.Int(False, 8))
  else if upper = 'UINT16' then Exit(TIRType.Int(False, 16))
  else if upper = 'UINT32' then Exit(TIRType.Int(False, 32))
  else if upper = 'UINT64' then Exit(TIRType.Int(False, 64))
  else if upper = 'REAL' then Exit(TIRType.Float(64))
  else if upper = 'FLOAT' then Exit(TIRType.Float(32))
  else if upper = 'DOUBLE' then Exit(TIRType.Float(64))
  else if upper = 'FLOAT32' then Exit(TIRType.Float(32))
  else if upper = 'FLOAT64' then Exit(TIRType.Float(64))
  else if upper = 'NIL' then Exit(TIRType.Pointer(TIRType.Void))
  else
    Exit(TIRType.AnyType);
end;

function TFXBIRGenerator.MapTokenTypeToBinOp(TT: TTokenType): TIRInstructionKind;
begin
  case TT of
    ttPlus: Result := ikAdd;
    ttMinus: Result := ikSub;
    ttStar: Result := ikMul;
    ttSlash: Result := ikDiv;
    ttPercent: Result := ikRem;
    ttShl: Result := ikShl;
    ttShr: Result := ikShr;
    ttAnd: Result := ikAnd;
    ttOr: Result := ikOr;
    ttXor: Result := ikXor;
    ttDotAnd: Result := ikAnd;
    ttDotOr: Result := ikOr;
    ttDotNot: Result := ikXor;
    else Result := ikInvalid;
  end;
end;

function TFXBIRGenerator.MapTokenTypeToCmpOp(TT: TTokenType): TIRInstructionKind;
begin
  case TT of
    ttEq, ttEqual: Result := ikICmp;
    ttNeq, ttNeq2: Result := ikICmp;
    ttLt: Result := ikICmp;
    ttGt: Result := ikICmp;
    ttLe: Result := ikICmp;
    ttGe: Result := ikICmp;
    else Result := ikInvalid;
  end;
end;

function TFXBIRGenerator.MapTokenTypeToUnaryOp(TT: TTokenType): TIRInstructionKind;
begin
  case TT of
    ttMinus: Result := ikSub;
    ttPlus: Result := ikAdd;
    ttDotNot: Result := ikXor;
    ttNot: Result := ikXor;
    ttAt: Result := ikPtrToInt;
    ttCaret: Result := ikIntToPtr;
    else Result := ikInvalid;
  end;
end;

procedure TFXBIRGenerator.ReportError(Code: Integer; const Msg: string; Line, Col: Integer);
begin
end;

procedure TFXBIRGenerator.ReportErrorNode(Node: TASTNode; Code: Integer; const Msg: string);
begin
end;

function TFXBIRGenerator.GetIRTypeFromToken(AToken: TToken): TIRType;
begin
  Result := TIRType.AnyType;
end;



{$I 'fxb.ir.stmt.inc'}
{$I 'fxb.ir.expr.inc'}
end.