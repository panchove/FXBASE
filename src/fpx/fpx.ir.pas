unit fpx.ir;

{$mode delphi}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes,
  fpx.ast,
  fpx.tokens,
  fpx.errors;

type
  TIRValue = class;
  TIRInstruction = class;
  TIRBlock = class;
  TIRFunction = class;
  TIRModule = class;
  TIRArgument = class;
  TIRLocal = class;

  TIRValueArray = array of TIRValue;
  TIRInstructionArray = array of TIRInstruction;
  TIRBlockArray = array of TIRBlock;
  TIRArgumentArray = array of TIRArgument;
  TIRLocalArray = array of TIRLocal;

  TIRValueKind = (
    vkConstant,
    vkArgument,
    vkLocal,
    vkGlobal,
    vkInstruction
  );

  TIRTypeKind = (
    tkVoid,
    tkBool,
    tkInt8, tkInt16, tkInt32, tkInt64,
    tkUInt8, tkUInt16, tkUInt32, tkUInt64,
    tkFloat32, tkFloat64,
    tkString,
    tkPointer,
    tkStruct,
    tkArray,
    tkAny
  );

  TIRType = record
    Kind: TIRTypeKind;
    StructName: string;
    ElementType: ^TIRType;
    IsRef: Boolean;
    function ToString: string;
    class function Void: TIRType; static;
    class function Bool: TIRType; static;
    class function Int(Signed: Boolean; Bits: Integer): TIRType; static;
    class function Float(Bits: Integer): TIRType; static;
    class function StringType: TIRType; static;
    class function Pointer(Element: TIRType): TIRType; static;
    class function Struct(const Name: string): TIRType; static;
    class function MakeArray(Element: TIRType): TIRType; static;
    class function AnyType: TIRType; static;
  end;

  TIRValue = class
  protected
    FKind: TIRValueKind;
    FType: TIRType;
    FName: string;
    FDefInstr: TIRInstruction;
    FUsers: TList;
  public
    constructor Create(AKind: TIRValueKind; const AType: TIRType; const AName: string = '');
    destructor Destroy; override;
    property Kind: TIRValueKind read FKind;
    property Type_: TIRType read FType write FType;
    property Name: string read FName write FName;
    property DefInstr: TIRInstruction read FDefInstr write FDefInstr;
    property Users: TList read FUsers;
    function Dump: string; virtual;
    function GetDefiningInstr: TIRInstruction;
    procedure AddUser(Instr: TIRInstruction);
    procedure RemoveUser(Instr: TIRInstruction);
    procedure ReplaceAllUsesWith(NewVal: TIRValue);
  end;

  TIRConstant = class(TIRValue)
  private
    FIntVal: Int64;
    FUIntVal: UInt64;
    FRealVal: Double;
    FStrVal: string;
    FBoolVal: Boolean;
    FIsNull: Boolean;
  public
    constructor CreateInt(const AType: TIRType; AVal: Int64; const AName: string = '');
    constructor CreateUInt(const AType: TIRType; AVal: UInt64; const AName: string = '');
    constructor CreateReal(const AType: TIRType; AVal: Double; const AName: string = '');
    constructor CreateString(const AType: TIRType; const AVal: string; const AName: string = '');
    constructor CreateBool(const AType: TIRType; AVal: Boolean; const AName: string = '');
    constructor CreateNull(const AType: TIRType; const AName: string = '');
    function Dump: string; override;
    property IntVal: Int64 read FIntVal;
    property UIntVal: UInt64 read FUIntVal;
    property RealVal: Double read FRealVal;
    property StrVal: string read FStrVal;
    property BoolVal: Boolean read FBoolVal;
    property IsNull: Boolean read FIsNull;
  end;

  TIRArgument = class(TIRValue)
  private
    FIndex: Integer;
  public
    constructor Create(const AType: TIRType; const AName: string; AIndex: Integer); reintroduce;
    function Dump: string; override;
    property Index: Integer read FIndex;
  end;

  TIRLocal = class(TIRValue)
  private
    FIsAddressTaken: Boolean;
  public
    constructor Create(const AType: TIRType; const AName: string = ''); reintroduce;
    function Dump: string; override;
    property IsAddressTaken: Boolean read FIsAddressTaken write FIsAddressTaken;
  end;

  TIRGlobal = class(TIRValue)
  private
    FIsExported: Boolean;
    FInitializer: TIRConstant;
  public
    constructor Create(const AType: TIRType; const AName: string; AExported: Boolean = False); reintroduce;
    function Dump: string; override;
    property IsExported: Boolean read FIsExported;
    property Initializer: TIRConstant read FInitializer write FInitializer;
  end;

  TIRInstructionKind = (
    ikInvalid,
    ikRet,
    ikBr,
    ikCondBr,
    ikSwitch,
    ikCall,
    ikCallDirect,
    ikLoad,
    ikStore,
    ikAlloca,
    ikGetElementPtr,
    ikBitCast,
    ikIntToPtr,
    ikPtrToInt,
    ikTrunc,
    ikZExt,
    ikSExt,
    ikFPTrunc,
    ikFPExt,
    ikFPToUI,
    ikFPToSI,
    ikUIToFP,
    ikSIToFP,
    ikAdd, ikSub, ikMul, ikDiv, ikRem,
    ikShl, ikShr,
    ikAnd, ikOr, ikXor,
    ikICmp, ikFCmp,
    ikSelect,
    ikPhi,
    ikYield,
    ikUnreachable,
    ikDbgValue,
    ikDbgLabel
  );

  TIRInstruction = class(TIRValue)
  private
    FInstrKind: TIRInstructionKind;
    FBlock: TIRBlock;
    FOperands: TList;
    FMetadata: TStringList;
    FDebugLoc: string;
  public
    constructor Create(AKind: TIRInstructionKind; const AType: TIRType; const AName: string = '');
    destructor Destroy; override;
    property Kind: TIRInstructionKind read FInstrKind;
    property Block: TIRBlock read FBlock write FBlock;
    property Operands: TList read FOperands;
    property Users: TList read FUsers;
    property Metadata: TStringList read FMetadata;
    property DebugLoc: string read FDebugLoc write FDebugLoc;
    function OperandCount: Integer;
    function GetOperand(Index: Integer): TIRValue;
    procedure SetOperand(Index: Integer; Val: TIRValue);
    procedure AddOperand(Val: TIRValue); overload;
    procedure AddOperand(Val: TIRBlock); overload;
    procedure AddOperand(Val: TIRFunction); overload;
    procedure InsertBefore(Instr: TIRInstruction);
    procedure InsertAfter(Instr: TIRInstruction);
    procedure RemoveFromBlock;
    procedure EraseFromBlock;
    function Dump: string; override;
    function IsTerminator: Boolean;
    function IsBinaryOp: Boolean;
    function IsCast: Boolean;
    function IsComparison: Boolean;
    procedure AddUser(Instr: TIRInstruction);
    procedure RemoveUser(Instr: TIRInstruction);
    procedure ReplaceOperand(Old, New: TIRValue);
  end;

  TIRBlock = class
  private
    FName: string;
    FFunction: TIRFunction;
    FInstructions: TList;
    FPredecessors: TList;
    FSuccessors: TList;
    FIsEntry: Boolean;
    FLabelEmitted: Boolean;
  public
    constructor Create(const AName: string; AFunction: TIRFunction);
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Function_: TIRFunction read FFunction;
    property Instructions: TList read FInstructions;
    property Predecessors: TList read FPredecessors;
    property Successors: TList read FSuccessors;
    property IsEntry: Boolean read FIsEntry write FIsEntry;
    property LabelEmitted: Boolean read FLabelEmitted write FLabelEmitted;
    function GetFirstInstr: TIRInstruction;
    function GetLastInstr: TIRInstruction;
    function GetInstrCount: Integer;
    function GetInstr(Index: Integer): TIRInstruction;
    procedure AddInstr(Instr: TIRInstruction);
    procedure InsertInstr(Index: Integer; Instr: TIRInstruction);
    procedure RemoveInstr(Instr: TIRInstruction);
    procedure AddPredecessor(Block: TIRBlock);
    procedure AddSuccessor(Block: TIRBlock);
    procedure RemovePredecessor(Block: TIRBlock);
    procedure RemoveSuccessor(Block: TIRBlock);
    function Dump: string;
    function IsTerminated: Boolean;
    procedure SplitAt(Instr: TIRInstruction; var NewBlock: TIRBlock);
  end;

  TIRFunction = class
  private
    FName: string;
    FModule: TIRModule;
    FReturnType: TIRType;
    FArguments: TIRArgumentArray;
    FLocals: TIRLocalArray;
    FBlocks: TList;
    FEntryBlock: TIRBlock;
    FIsExternal: Boolean;
    FIsVarArg: Boolean;
    FCallingConv: string;
    FAttributes: TStringList;
  public
    constructor Create(const AName: string; AModule: TIRModule; const ARetType: TIRType);
    destructor Destroy; override;
    property Name: string read FName;
    property Module: TIRModule read FModule;
    property ReturnType: TIRType read FReturnType;
    property Arguments: TIRArgumentArray read FArguments;
    property Locals: TIRLocalArray read FLocals;
    property Blocks: TList read FBlocks;
    property EntryBlock: TIRBlock read FEntryBlock;
    property IsExternal: Boolean read FIsExternal write FIsExternal;
    property IsVarArg: Boolean read FIsVarArg write FIsVarArg;
    property CallingConv: string read FCallingConv write FCallingConv;
    property Attributes: TStringList read FAttributes;
    function AddArgument(const AType: TIRType; const AName: string): TIRArgument;
    function AddLocal(const AType: TIRType; const AName: string = ''): TIRLocal;
    function CreateBlock(const AName: string = ''): TIRBlock;
    function GetBlockCount: Integer;
    function GetBlock(Index: Integer): TIRBlock;
    function Dump: string;
    procedure Verify;
  end;

  TIRModule = class
  private
    FName: string;
    FFunctions: TList;
    FGlobals: TList;
    FStructTypes: TStringList;
    FTargetTriple: string;
    FDataLayout: string;
    FSourceFileName: string;
  public
    constructor Create(const AName: string = '');
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Functions: TList read FFunctions;
    property Globals: TList read FGlobals;
    property StructTypes: TStringList read FStructTypes;
    property TargetTriple: string read FTargetTriple write FTargetTriple;
    property DataLayout: string read FDataLayout write FDataLayout;
    property SourceFileName: string read FSourceFileName write FSourceFileName;
    function AddFunction(const AName: string; const ARetType: TIRType): TIRFunction;
    function GetFunction(const AName: string): TIRFunction;
    function GetFunctionCount: Integer;
    function GetFunctionByIndex(Index: Integer): TIRFunction;
    function AddGlobal(const AType: TIRType; const AName: string; AExported: Boolean = False): TIRGlobal;
    function Dump: string; virtual;
    procedure Verify;
  end;

  TFPXIRGenerator = class
  private
    FTargetOS: string;
    FTargetCPU: string;
    FOptimizationLevel: Integer;
    FDebugInfo: Boolean;
    FErrors: TCompilerMessageArray;
    FModule: TIRModule;
    FCurrentFunction: TIRFunction;
    FCurrentBlock: TIRBlock;
    FValueStack: TIRValueArray;
    FBreakTargets: TIRBlockArray;
    FContinueTargets: TIRBlockArray;
    FReturnTargets: TIRBlockArray;
    FLoopDepth: Integer;
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

    // AST lowering
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

uses
  typinfo;

{ TIRType }

class function TIRType.Void: TIRType;
begin
  Result.Kind := tkVoid;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.Bool: TIRType;
begin
  Result.Kind := tkBool;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.Int(Signed: Boolean; Bits: Integer): TIRType;
begin
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
  if Signed then
  begin
    if Bits = 8 then Result.Kind := tkInt8
    else if Bits = 16 then Result.Kind := tkInt16
    else if Bits = 32 then Result.Kind := tkInt32
    else if Bits = 64 then Result.Kind := tkInt64
    else Result.Kind := tkInt32;
  end
  else
  begin
    if Bits = 8 then Result.Kind := tkUInt8
    else if Bits = 16 then Result.Kind := tkUInt16
    else if Bits = 32 then Result.Kind := tkUInt32
    else if Bits = 64 then Result.Kind := tkUInt64
    else Result.Kind := tkUInt32;
  end;
end;

class function TIRType.Float(Bits: Integer): TIRType;
begin
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
  if Bits = 32 then Result.Kind := tkFloat32
  else Result.Kind := tkFloat64;
end;

class function TIRType.StringType: TIRType;
begin
  Result.Kind := tkString;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.Pointer(Element: TIRType): TIRType;
begin
  Result.Kind := tkPointer;
  Result.StructName := '';
  New(Result.ElementType);
  Result.ElementType^ := Element;
  Result.IsRef := False;
end;

class function TIRType.Struct(const Name: string): TIRType;
begin
  Result.Kind := tkStruct;
  Result.StructName := Name;
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.MakeArray(Element: TIRType): TIRType;
begin
  Result.Kind := tkArray;
  Result.StructName := '';
  New(Result.ElementType);
  Result.ElementType^ := Element;
  Result.IsRef := False;
end;

class function TIRType.AnyType: TIRType;
begin
  Result.Kind := tkAny;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

function TIRType.ToString: string;
begin
  case Kind of
    tkVoid: Result := 'void';
    tkBool: Result := 'bool';
    tkInt8: Result := 'i8';
    tkInt16: Result := 'i16';
    tkInt32: Result := 'i32';
    tkInt64: Result := 'i64';
    tkUInt8: Result := 'u8';
    tkUInt16: Result := 'u16';
    tkUInt32: Result := 'u32';
    tkUInt64: Result := 'u64';
    tkFloat32: Result := 'f32';
    tkFloat64: Result := 'f64';
    tkString: Result := 'string';
    tkPointer: Result := 'ptr ' + (ElementType^.ToString);
    tkStruct: Result := '%' + StructName;
    tkArray: Result := '[' + ElementType^.ToString + ']';
    tkAny: Result := 'any';
    else Result := 'unknown';
  end;
  if IsRef then Result := 'ref ' + Result;
end;

{ TIRValue }

constructor TIRValue.Create(AKind: TIRValueKind; const AType: TIRType; const AName: string = '');
begin
  inherited Create;
  FKind := AKind;
  FType := AType;
  FName := AName;
  FUsers := TList.Create;
end;

destructor TIRValue.Destroy;
begin
  FUsers.Free;
  inherited;
end;

function TIRValue.Dump: string;
begin
  Result := '%' + FName + ' : ' + FType.ToString;
end;

function TIRValue.GetDefiningInstr: TIRInstruction;
begin
  Result := FDefInstr;
end;

procedure TIRValue.AddUser(Instr: TIRInstruction);
begin
  if FUsers.IndexOf(Instr) = -1 then
    FUsers.Add(Instr);
end;

procedure TIRValue.RemoveUser(Instr: TIRInstruction);
begin
  FUsers.Remove(Instr);
end;

procedure TIRValue.ReplaceAllUsesWith(NewVal: TIRValue);
var
  i: Integer;
  User: TIRInstruction;
begin
  for i := 0 to FUsers.Count - 1 do
  begin
    User := TIRInstruction(FUsers[i]);
    User.ReplaceOperand(Self, NewVal);
  end;
  FUsers.Clear;
end;

{ TIRConstant }

constructor TIRConstant.CreateInt(const AType: TIRType; AVal: Int64; const AName: string = '');
begin
  inherited Create(vkConstant, AType, AName);
  FIntVal := AVal;
  FIsNull := False;
end;

constructor TIRConstant.CreateUInt(const AType: TIRType; AVal: UInt64; const AName: string = '');
begin
  inherited Create(vkConstant, AType, AName);
  FUIntVal := AVal;
  FIsNull := False;
end;

constructor TIRConstant.CreateReal(const AType: TIRType; AVal: Double; const AName: string = '');
begin
  inherited Create(vkConstant, AType, AName);
  FRealVal := AVal;
  FIsNull := False;
end;

constructor TIRConstant.CreateString(const AType: TIRType; const AVal: string; const AName: string = '');
begin
  inherited Create(vkConstant, AType, AName);
  FStrVal := AVal;
  FIsNull := False;
end;

constructor TIRConstant.CreateBool(const AType: TIRType; AVal: Boolean; const AName: string = '');
begin
  inherited Create(vkConstant, AType, AName);
  FBoolVal := AVal;
  FIsNull := False;
end;

constructor TIRConstant.CreateNull(const AType: TIRType; const AName: string = '');
begin
  inherited Create(vkConstant, AType, AName);
  FIsNull := True;
end;

function TIRConstant.Dump: string;
begin
  if FIsNull then
    Result := 'null'
  else case FType.Kind of
    tkInt8, tkInt16, tkInt32, tkInt64: Result := IntToStr(FIntVal);
    tkUInt8, tkUInt16, tkUInt32, tkUInt64: Result := IntToStr(FUIntVal);
    tkFloat32, tkFloat64: Result := FloatToStr(FRealVal);
    tkBool: begin
      if FBoolVal then Result := 'true' else Result := 'false';
    end;
    tkString: Result := '"' + FStrVal + '"';
    else Result := 'const';
  end;
  Result := '%' + FName + ' = constant ' + FType.ToString + ' ' + Result;
end;

{ TIRArgument }

constructor TIRArgument.Create(const AType: TIRType; const AName: string; AIndex: Integer);
begin
  inherited Create(vkArgument, AType, AName);
  FIndex := AIndex;
end;

function TIRArgument.Dump: string;
begin
  Result := '%' + FName + ' = arg ' + FType.ToString;
end;

{ TIRLocal }

constructor TIRLocal.Create(const AType: TIRType; const AName: string = '');
begin
  inherited Create(vkLocal, AType, AName);
  FIsAddressTaken := False;
end;

function TIRLocal.Dump: string;
begin
  Result := '%' + FName + ' = alloca ' + FType.ToString;
end;

{ TIRGlobal }

constructor TIRGlobal.Create(const AType: TIRType; const AName: string; AExported: Boolean = False);
begin
  inherited Create(vkGlobal, AType, AName);
  FIsExported := AExported;
  FInitializer := nil;
end;

function TIRGlobal.Dump: string;
var
  initStr: string;
begin
  if Assigned(FInitializer) then
    initStr := ' = ' + FInitializer.Dump
  else
    initStr := '';
  if FIsExported then
    Result := '@' + FName + ' = external global ' + FType.ToString + initStr
  else
    Result := '@' + FName + ' = internal global ' + FType.ToString + initStr;
end;

{ TIRInstruction }

constructor TIRInstruction.Create(AKind: TIRInstructionKind; const AType: TIRType; const AName: string = '');
begin
  inherited Create(vkInstruction, AType, AName);
  FInstrKind := AKind;
  FOperands := TList.Create;
  FMetadata := TStringList.Create;
end;

destructor TIRInstruction.Destroy;
var
  i: Integer;
  val: TIRValue;
begin
  for i := 0 to FOperands.Count - 1 do
  begin
    val := TIRValue(FOperands[i]);
    if Assigned(val) then val.RemoveUser(Self);
  end;
  FMetadata.Free;
  FOperands.Free;
  inherited;
end;

function TIRInstruction.OperandCount: Integer;
begin
  Result := FOperands.Count;
end;

function TIRInstruction.GetOperand(Index: Integer): TIRValue;
begin
  if (Index >= 0) and (Index < FOperands.Count) then
    Result := TIRValue(FOperands[Index])
  else
    Result := nil;
end;

procedure TIRInstruction.SetOperand(Index: Integer; Val: TIRValue);
var
  old: TIRValue;
begin
  if (Index >= 0) and (Index < FOperands.Count) then
  begin
    old := TIRValue(FOperands[Index]);
    if Assigned(old) then old.RemoveUser(Self);
    FOperands[Index] := Val;
    if Assigned(Val) then Val.AddUser(Self);
  end;
end;

procedure TIRInstruction.AddOperand(Val: TIRValue);
begin
  FOperands.Add(Val);
  if Assigned(Val) then Val.AddUser(Self);
end;

procedure TIRInstruction.AddOperand(Val: TIRBlock);
begin
  FOperands.Add(Val);
end;

procedure TIRInstruction.AddOperand(Val: TIRFunction);
begin
  FOperands.Add(Val);
end;

procedure TIRInstruction.InsertBefore(Instr: TIRInstruction);
begin
  if Assigned(FBlock) and Assigned(Instr) and (Instr.Block = FBlock) then
    FBlock.InsertInstr(FBlock.Instructions.IndexOf(Self), Instr);
end;

procedure TIRInstruction.InsertAfter(Instr: TIRInstruction);
begin
  if Assigned(FBlock) and Assigned(Instr) and (Instr.Block = FBlock) then
    FBlock.InsertInstr(FBlock.Instructions.IndexOf(Self) + 1, Instr);
end;

procedure TIRInstruction.RemoveFromBlock;
begin
  if Assigned(FBlock) then
    FBlock.RemoveInstr(Self);
end;

procedure TIRInstruction.EraseFromBlock;
begin
  RemoveFromBlock;
  Free;
end;

function TIRInstruction.Dump: string;
var
  i: Integer;
  opStr: string;
begin
  opStr := '';
  for i := 0 to FOperands.Count - 1 do
  begin
    if Assigned(TIRValue(FOperands[i])) then
    begin
      if opStr <> '' then opStr := opStr + ', ';
      opStr := opStr + '%' + TIRValue(FOperands[i]).Name;
    end;
  end;
  Result := '  %' + FName + ' = ' + GetEnumName(TypeInfo(TIRInstructionKind), Ord(FInstrKind)) + ' ' + FType.ToString + ' ' + opStr;
  if FDebugLoc <> '' then
    Result := Result + ' ; ' + FDebugLoc;
end;

function TIRInstruction.IsTerminator: Boolean;
begin
  case FInstrKind of
    ikRet, ikBr, ikCondBr, ikSwitch, ikUnreachable: Result := True;
    else Result := False;
  end;
end;

function TIRInstruction.IsBinaryOp: Boolean;
begin
  Result := FInstrKind in [ikAdd, ikSub, ikMul, ikDiv, ikRem,
    ikShl, ikShr, ikAnd, ikOr, ikXor];
end;

function TIRInstruction.IsCast: Boolean;
begin
  Result := FInstrKind in [ikBitCast, ikIntToPtr, ikPtrToInt,
    ikTrunc, ikZExt, ikSExt, ikFPTrunc, ikFPExt,
    ikFPToUI, ikFPToSI, ikUIToFP, ikSIToFP];
end;

function TIRInstruction.IsComparison: Boolean;
begin
  Result := FInstrKind in [ikICmp, ikFCmp];
end;

procedure TIRInstruction.AddUser(Instr: TIRInstruction);
begin
  if FUsers.IndexOf(Instr) = -1 then
    FUsers.Add(Instr);
end;

procedure TIRInstruction.RemoveUser(Instr: TIRInstruction);
begin
  FUsers.Remove(Instr);
end;

procedure TIRInstruction.ReplaceOperand(Old, New: TIRValue);
var
  i: Integer;
begin
  for i := 0 to FOperands.Count - 1 do
    if TIRValue(FOperands[i]) = Old then
      SetOperand(i, New);
end;

{ TIRBlock }

constructor TIRBlock.Create(const AName: string; AFunction: TIRFunction);
begin
  inherited Create;
  FName := AName;
  FFunction := AFunction;
  FInstructions := TList.Create;
  FPredecessors := TList.Create;
  FSuccessors := TList.Create;
  FIsEntry := False;
  FLabelEmitted := False;
end;

destructor TIRBlock.Destroy;
var
  i: Integer;
  instr: TIRInstruction;
begin
  for i := 0 to FInstructions.Count - 1 do
  begin
    instr := TIRInstruction(FInstructions[i]);
    instr.FBlock := nil;
    instr.Free;
  end;
  FInstructions.Free;
  FPredecessors.Free;
  FSuccessors.Free;
  inherited;
end;

function TIRBlock.GetFirstInstr: TIRInstruction;
begin
  if FInstructions.Count > 0 then
    Result := TIRInstruction(FInstructions[0])
  else
    Result := nil;
end;

function TIRBlock.GetLastInstr: TIRInstruction;
begin
  if FInstructions.Count > 0 then
    Result := TIRInstruction(FInstructions[FInstructions.Count - 1])
  else
    Result := nil;
end;

function TIRBlock.GetInstrCount: Integer;
begin
  Result := FInstructions.Count;
end;

function TIRBlock.GetInstr(Index: Integer): TIRInstruction;
begin
  if (Index >= 0) and (Index < FInstructions.Count) then
    Result := TIRInstruction(FInstructions[Index])
  else
    Result := nil;
end;

procedure TIRBlock.AddInstr(Instr: TIRInstruction);
begin
  FInstructions.Add(Instr);
  Instr.FBlock := Self;
end;

procedure TIRBlock.InsertInstr(Index: Integer; Instr: TIRInstruction);
begin
  FInstructions.Insert(Index, Instr);
  Instr.FBlock := Self;
end;

procedure TIRBlock.RemoveInstr(Instr: TIRInstruction);
begin
  FInstructions.Remove(Instr);
  Instr.FBlock := nil;
end;

procedure TIRBlock.AddPredecessor(Block: TIRBlock);
begin
  if FPredecessors.IndexOf(Block) = -1 then
    FPredecessors.Add(Block);
end;

procedure TIRBlock.AddSuccessor(Block: TIRBlock);
begin
  if FSuccessors.IndexOf(Block) = -1 then
    FSuccessors.Add(Block);
end;

procedure TIRBlock.RemovePredecessor(Block: TIRBlock);
begin
  FPredecessors.Remove(Block);
end;

procedure TIRBlock.RemoveSuccessor(Block: TIRBlock);
begin
  FSuccessors.Remove(Block);
end;

function TIRBlock.Dump: string;
var
  i: Integer;
  instr: TIRInstruction;
begin
  Result := FName + ':' + LineEnding;
  for i := 0 to FInstructions.Count - 1 do
  begin
    instr := TIRInstruction(FInstructions[i]);
    Result := Result + '  ' + instr.Dump + LineEnding;
  end;
end;

function TIRBlock.IsTerminated: Boolean;
var
  last: TIRInstruction;
begin
  last := GetLastInstr;
  Result := Assigned(last) and last.IsTerminator;
end;

procedure TIRBlock.SplitAt(Instr: TIRInstruction; var NewBlock: TIRBlock);
var
  idx, i: Integer;
  splitInstr: TIRInstruction;
begin
  idx := FInstructions.IndexOf(Instr);
  if idx = -1 then Exit;
  NewBlock := FFunction.CreateBlock(FName + '.split');
  for i := idx + 1 to FInstructions.Count - 1 do
  begin
    splitInstr := TIRInstruction(FInstructions[i]);
    NewBlock.AddInstr(splitInstr);
  end;
  for i := FInstructions.Count - 1 downto idx + 1 do
    FInstructions.Delete(i);
end;

{ TIRFunction }

constructor TIRFunction.Create(const AName: string; AModule: TIRModule; const ARetType: TIRType);
begin
  inherited Create;
  FName := AName;
  FModule := AModule;
  FReturnType := ARetType;
  FBlocks := TList.Create;
  FAttributes := TStringList.Create;
  FEntryBlock := CreateBlock('entry');
  FEntryBlock.IsEntry := True;
  FIsExternal := False;
  FIsVarArg := False;
  FCallingConv := 'fastcc';
end;

destructor TIRFunction.Destroy;
var
  i: Integer;
  block: TIRBlock;
  arg: TIRArgument;
  local: TIRLocal;
begin
  for i := 0 to FBlocks.Count - 1 do
  begin
    block := TIRBlock(FBlocks[i]);
    block.Free;
  end;
  for i := 0 to High(FArguments) do
    FArguments[i].Free;
  for i := 0 to High(FLocals) do
    FLocals[i].Free;
  FBlocks.Free;
  FAttributes.Free;
  inherited;
end;

function TIRFunction.AddArgument(const AType: TIRType; const AName: string): TIRArgument;
var
  arg: TIRArgument;
  idx: Integer;
begin
  idx := Length(FArguments);
  arg := TIRArgument.Create(AType, AName, idx);
  SetLength(FArguments, idx + 1);
  FArguments[idx] := arg;
  Result := arg;
end;

function TIRFunction.AddLocal(const AType: TIRType; const AName: string = ''): TIRLocal;
var
  local: TIRLocal;
  idx: Integer;
begin
  idx := Length(FLocals);
  local := TIRLocal.Create(AType, AName);
  SetLength(FLocals, idx + 1);
  FLocals[idx] := local;
  Result := local;
end;

function TIRFunction.CreateBlock(const AName: string = ''): TIRBlock;
var
  block: TIRBlock;
  name: string;
begin
  if AName = '' then
    name := 'block' + IntToStr(FBlocks.Count)
  else
    name := AName;
  block := TIRBlock.Create(name, Self);
  FBlocks.Add(block);
  Result := block;
end;

function TIRFunction.GetBlockCount: Integer;
begin
  Result := FBlocks.Count;
end;

function TIRFunction.GetBlock(Index: Integer): TIRBlock;
begin
  if (Index >= 0) and (Index < FBlocks.Count) then
    Result := TIRBlock(FBlocks[Index])
  else
    Result := nil;
end;

function TIRFunction.Dump: string;
var
  i: Integer;
  block: TIRBlock;
  arg: TIRArgument;
  local: TIRLocal;
  argsStr: string;
begin
  argsStr := '';
  for i := 0 to High(FArguments) do
  begin
    arg := FArguments[i];
    if argsStr <> '' then argsStr := argsStr + ', ';
    argsStr := argsStr + arg.Type_.ToString + ' %' + arg.Name;
  end;
  Result := 'define ' + FReturnType.ToString + ' @' + FName + '(' + argsStr + ') {' + LineEnding;
  if Length(FLocals) > 0 then
  begin
    Result := Result + '  ; locals' + LineEnding;
    for i := 0 to High(FLocals) do
    begin
      local := FLocals[i];
      Result := Result + '  ' + local.Dump + LineEnding;
    end;
  end;
  for i := 0 to FBlocks.Count - 1 do
  begin
    block := TIRBlock(FBlocks[i]);
    Result := Result + block.Dump;
  end;
  Result := Result + '}' + LineEnding;
end;

procedure TIRFunction.Verify;
var
  i: Integer;
  block: TIRBlock;
begin
  for i := 0 to FBlocks.Count - 1 do
  begin
    block := TIRBlock(FBlocks[i]);
    if not block.IsTerminated and (i <> FBlocks.Count - 1) then
      ; // Warning: block not terminated
  end;
end;

{ TIRModule }

constructor TIRModule.Create(const AName: string = '');
begin
  inherited Create;
  FName := AName;
  FFunctions := TList.Create;
  FGlobals := TList.Create;
  FStructTypes := TStringList.Create;
  FTargetTriple := 'x86_64-pc-linux-gnu';
  FDataLayout := 'e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128';
  FSourceFileName := '';
end;

destructor TIRModule.Destroy;
var
  i: Integer;
  fn: TIRFunction;
  gl: TIRGlobal;
begin
  for i := 0 to FFunctions.Count - 1 do
  begin
    fn := TIRFunction(FFunctions[i]);
    fn.Free;
  end;
  for i := 0 to FGlobals.Count - 1 do
  begin
    gl := TIRGlobal(FGlobals[i]);
    gl.Free;
  end;
  FFunctions.Free;
  FGlobals.Free;
  FStructTypes.Free;
  inherited;
end;

function TIRModule.AddFunction(const AName: string; const ARetType: TIRType): TIRFunction;
var
  fn: TIRFunction;
begin
  fn := TIRFunction.Create(AName, Self, ARetType);
  FFunctions.Add(fn);
  Result := fn;
end;

function TIRModule.GetFunction(const AName: string): TIRFunction;
var
  i: Integer;
  fn: TIRFunction;
begin
  for i := 0 to FFunctions.Count - 1 do
  begin
    fn := TIRFunction(FFunctions[i]);
    if fn.Name = AName then Exit(fn);
  end;
  Result := nil;
end;

function TIRModule.GetFunctionCount: Integer;
begin
  Result := FFunctions.Count;
end;

function TIRModule.GetFunctionByIndex(Index: Integer): TIRFunction;
begin
  if (Index >= 0) and (Index < FFunctions.Count) then
    Result := TIRFunction(FFunctions[Index])
  else
    Result := nil;
end;

function TIRModule.AddGlobal(const AType: TIRType; const AName: string; AExported: Boolean = False): TIRGlobal;
var
  gl: TIRGlobal;
begin
  gl := TIRGlobal.Create(AType, AName, AExported);
  FGlobals.Add(gl);
  Result := gl;
end;

function TIRModule.Dump: string;
var
  i: Integer;
  fn: TIRFunction;
  gl: TIRGlobal;
begin
  Result := '; ModuleID = ''' + FName + '''' + LineEnding;
  Result := Result + 'target triple = "' + FTargetTriple + '"' + LineEnding;
  Result := Result + 'target datalayout = "' + FDataLayout + '"' + LineEnding + LineEnding;
  for i := 0 to FGlobals.Count - 1 do
  begin
    gl := TIRGlobal(FGlobals[i]);
    Result := Result + gl.Dump + LineEnding;
  end;
  if FGlobals.Count > 0 then Result := Result + LineEnding;
  for i := 0 to FFunctions.Count - 1 do
  begin
    fn := TIRFunction(FFunctions[i]);
    Result := Result + fn.Dump + LineEnding;
  end;
end;

procedure TIRModule.Verify;
var
  i: Integer;
  fn: TIRFunction;
begin
  for i := 0 to FFunctions.Count - 1 do
  begin
    fn := TIRFunction(FFunctions[i]);
    fn.Verify;
  end;
end;

{ TFPXIRGenerator }

function TFPXIRGenerator.Generate(const AST: TCompilationUnit): TIRModule;
begin
  FModule := TIRModule.Create('fpx_module');
  FModule.TargetTriple := FTargetOS + '-' + FTargetCPU + '-none';
  FModule.SourceFileName := '';
  FNextValueId := 0;
  FNextBlockId := 0;
  FLoopDepth := 0;
  FLocalVarMap := TStringList.Create;
  FTypeCache := TStringList.Create;
  try
    LowerCompilationUnit(AST);
    FModule.Verify;
    Result := FModule;
  finally
    FLocalVarMap.Free;
    FTypeCache.Free;
  end;
end;

function TFPXIRGenerator.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

function TFPXIRGenerator.CreateTempName(const Prefix: string): string;
begin
  Inc(FNextValueId);
  Result := Prefix + IntToStr(FNextValueId);
end;

function TFPXIRGenerator.CreateBlockName(const Prefix: string): string;
begin
  Inc(FNextBlockId);
  Result := Prefix + IntToStr(FNextBlockId);
end;

procedure TFPXIRGenerator.PushBreakTarget(Block: TIRBlock);
begin
  SetLength(FBreakTargets, Length(FBreakTargets) + 1);
  FBreakTargets[High(FBreakTargets)] := Block;
end;

procedure TFPXIRGenerator.PopBreakTarget;
begin
  if Length(FBreakTargets) > 0 then
    SetLength(FBreakTargets, Length(FBreakTargets) - 1);
end;

function TFPXIRGenerator.CurrentBreakTarget: TIRBlock;
begin
  if Length(FBreakTargets) > 0 then
    Result := FBreakTargets[High(FBreakTargets)]
  else
    Result := nil;
end;

procedure TFPXIRGenerator.PushContinueTarget(Block: TIRBlock);
begin
  SetLength(FContinueTargets, Length(FContinueTargets) + 1);
  FContinueTargets[High(FContinueTargets)] := Block;
end;

procedure TFPXIRGenerator.PopContinueTarget;
begin
  if Length(FContinueTargets) > 0 then
    SetLength(FContinueTargets, Length(FContinueTargets) - 1);
end;

function TFPXIRGenerator.CurrentContinueTarget: TIRBlock;
begin
  if Length(FContinueTargets) > 0 then
    Result := FContinueTargets[High(FContinueTargets)]
  else
    Result := nil;
end;

procedure TFPXIRGenerator.PushReturnTarget(Block: TIRBlock);
begin
  SetLength(FReturnTargets, Length(FReturnTargets) + 1);
  FReturnTargets[High(FReturnTargets)] := Block;
end;

procedure TFPXIRGenerator.PopReturnTarget;
begin
  if Length(FReturnTargets) > 0 then
    SetLength(FReturnTargets, Length(FReturnTargets) - 1);
end;

function TFPXIRGenerator.CurrentReturnTarget: TIRBlock;
begin
  if Length(FReturnTargets) > 0 then
    Result := FReturnTargets[High(FReturnTargets)]
  else
    Result := nil;
end;

procedure TFPXIRGenerator.EmitInstr(Instr: TIRInstruction);
begin
  if Assigned(FCurrentBlock) then
  begin
    FCurrentBlock.AddInstr(Instr);
    if FDebugInfo then
      Instr.DebugLoc := Format('line %d col %d', [0, 0]);
  end;
end;

function TFPXIRGenerator.EmitBinOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
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

function TFPXIRGenerator.EmitCmpOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(OpKind, TIRType.Bool, Name);
  instr.AddOperand(Left);
  instr.AddOperand(Right);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRGenerator.EmitCast(OpKind: TIRInstructionKind; Val: TIRValue; DestType: TIRType; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(OpKind, DestType, Name);
  instr.AddOperand(Val);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRGenerator.CreateAlloca(const AType: TIRType; const Name: string): TIRLocal;
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

function TFPXIRGenerator.CreateLoad(Ptr: TIRValue; const Name: string): TIRValue;
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

function TFPXIRGenerator.CreateStore(Val, Ptr: TIRValue): TIRInstruction;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(ikStore, TIRType.Void, '');
  instr.AddOperand(Val);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRGenerator.CreateCall(Func: TIRFunction; Args: TIRValueArray; const Name: string = ''): TIRValue;
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

function TFPXIRGenerator.CreateCallDirect(const FuncName: string; const RetType: TIRType; Args: TIRValueArray; const Name: string = ''): TIRValue;
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

procedure TFPXIRGenerator.LowerCompilationUnit(AST: TCompilationUnit);
var
  i: Integer;
  node: TASTNode;
begin
  for i := 0 to AST.Count - 1 do
  begin
    node := AST.Nodes[i];
    if node is TFunctionDef then
      LowerFunctionDef(TFunctionDef(node))
    else if node is TProcedureDef then
      LowerProcedureDef(TProcedureDef(node))
    else if node is TClassDef then
      LowerClassDef(TClassDef(node))
    else if node is TStructDef then
      LowerStructDef(TStructDef(node))
    else if node is TNewTypeDef then
      LowerNewTypeDef(TNewTypeDef(node))
    else
      LowerStatement(node);
  end;
end;

procedure TFPXIRGenerator.LowerFunctionDef(Func: TFunctionDef);
var
  retType: TIRType;
  fn: TIRFunction;
  i, n: Integer;
  paramName, paramType: string;
begin
  retType := GetIRType(Func.ReturnType);
  fn := FModule.AddFunction(Func.Name, retType);
  FCurrentFunction := fn;
  FCurrentBlock := fn.EntryBlock;

  n := Func.ParamCount;
  for i := 0 to n - 1 do
  begin
    paramName := Func.GetParamName(i);
    paramType := Func.GetParamType(i);
    fn.AddArgument(GetIRType(paramType), paramName);
    FLocalVarMap.AddObject(paramName, fn.Arguments[i]);
  end;

  for i := 0 to High(Func.Body) do
    LowerStatement(Func.Body[i]);

  if (FCurrentBlock <> nil) and not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));

  FCurrentFunction := nil;
  FCurrentBlock := nil;
end;

procedure TFPXIRGenerator.LowerProcedureDef(Proc: TProcedureDef);
var
  fn: TIRFunction;
  i, n: Integer;
  paramName, paramType: string;
begin
  fn := FModule.AddFunction(Proc.Name, TIRType.Void);
  FCurrentFunction := fn;
  FCurrentBlock := fn.EntryBlock;

  n := Proc.ParamCount;
  for i := 0 to n - 1 do
  begin
    paramName := Proc.GetParamName(i);
    paramType := Proc.GetParamType(i);
    fn.AddArgument(GetIRType(paramType), paramName);
    FLocalVarMap.AddObject(paramName, fn.Arguments[i]);
  end;

  for i := 0 to High(Proc.Body) do
    LowerStatement(Proc.Body[i]);

  if (FCurrentBlock <> nil) and not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));

  FCurrentFunction := nil;
  FCurrentBlock := nil;
end;

procedure TFPXIRGenerator.LowerClassDef(ClassDef: TClassDef);
begin
end;

procedure TFPXIRGenerator.LowerStructDef(StructDef: TStructDef);
begin
  FTypeCache.AddObject(StructDef.Name, nil);
end;

procedure TFPXIRGenerator.LowerNewTypeDef(NewTypeDef: TNewTypeDef);
begin
  FTypeCache.AddObject(NewTypeDef.Name, nil);
end;

procedure TFPXIRGenerator.LowerStatement(Stmt: TASTNode);
begin
  if Stmt is TExprStmt then LowerExprStmt(TExprStmt(Stmt))
  else if Stmt is TVarDeclStmt then LowerVarDecl(TVarDeclStmt(Stmt))
  else if Stmt is TAssignStmt then LowerAssign(TAssignStmt(Stmt))
  else if Stmt is TIfStmt then LowerIf(TIfStmt(Stmt))
  else if Stmt is TForStmt then LowerFor(TForStmt(Stmt))
  else if Stmt is TWhileStmt then LowerWhile(TWhileStmt(Stmt))
  else if Stmt is TReturnStmt then LowerReturn(TReturnStmt(Stmt))
  else if Stmt is TYieldStmt then LowerYield(TYieldStmt(Stmt))
  else if Stmt is TLoopCtrlStmt then LowerLoopCtrl(TLoopCtrlStmt(Stmt));
end;

procedure TFPXIRGenerator.LowerExprStmt(Stmt: TExprStmt);
begin
  LowerExpression(Stmt.Expr);
end;

procedure TFPXIRGenerator.LowerVarDecl(Stmt: TVarDeclStmt);
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
      irType := GetIRType(varType)
    else
      irType := TIRType.AnyType;
    local := FCurrentFunction.AddLocal(irType, varName);
    FLocalVarMap.AddObject(varName, local);
    if Assigned(initVal) then
    begin
      val := LowerExpression(initVal);
      CreateStore(val, local);
    end;
  end;
end;

procedure TFPXIRGenerator.LowerAssign(Stmt: TAssignStmt);
var
  target, value: TIRValue;
begin
  target := LowerExpression(Stmt.Target);
  value := LowerExpression(Stmt.Value);
  CreateStore(value, target);
end;

procedure TFPXIRGenerator.LowerIf(Stmt: TIfStmt);
var
  condVal: TIRValue;
  thenBlock, elseBlock, mergeBlock: TIRBlock;
  i, j: Integer;
  hasElseIf: Boolean;
  innerBody: array of TASTNode;
begin
  condVal := LowerExpression(Stmt.Condition);
  thenBlock := FCurrentFunction.CreateBlock(CreateBlockName('then'));
  elseBlock := FCurrentFunction.CreateBlock(CreateBlockName('else'));
  mergeBlock := FCurrentFunction.CreateBlock(CreateBlockName('merge'));

  EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condVal);
  FCurrentBlock.GetLastInstr.AddOperand(thenBlock);
  FCurrentBlock.GetLastInstr.AddOperand(elseBlock);

  FCurrentBlock := thenBlock;
  for i := 0 to High(Stmt.ThenBody) do
    LowerStatement(Stmt.ThenBody[i]);
  if not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);

  hasElseIf := Length(Stmt.ElseIfConds) > 0;
  if hasElseIf or Stmt.HasElse then
  begin
    FCurrentBlock := elseBlock;
    if hasElseIf then
    begin
      for i := 0 to High(Stmt.ElseIfConds) do
      begin
        condVal := LowerExpression(Stmt.ElseIfConds[i]);
        thenBlock := FCurrentFunction.CreateBlock(CreateBlockName('elseif.then'));
        elseBlock := FCurrentFunction.CreateBlock(CreateBlockName('elseif.else'));
        EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
        FCurrentBlock.GetLastInstr.AddOperand(condVal);
        FCurrentBlock.GetLastInstr.AddOperand(thenBlock);
        FCurrentBlock.GetLastInstr.AddOperand(elseBlock);
        FCurrentBlock := thenBlock;
        innerBody := Stmt.ElseIfBodies[i];
        for j := 0 to High(innerBody) do
          LowerStatement(innerBody[j]);
        if not FCurrentBlock.IsTerminated then
          EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
        FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
        FCurrentBlock := elseBlock;
      end;
    end;
    if Stmt.HasElse then
    begin
      for i := 0 to High(Stmt.ElseBody) do
        LowerStatement(Stmt.ElseBody[i]);
    end;
    if not FCurrentBlock.IsTerminated then
      EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
  end
  else
  begin
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
  end;
  FCurrentBlock := mergeBlock;
end;

procedure TFPXIRGenerator.LowerFor(Stmt: TForStmt);
var
  initBlock, condBlock, bodyBlock, stepBlock, exitBlock: TIRBlock;
  varPtr: TIRValue;
  startVal, endVal, stepVal: TIRValue;
  condInstr: TIRInstruction;
  varType: TIRType;
  varName: string;
  i: Integer;
begin
  varName := Stmt.VarName;
  varType := GetIRType('INT');

  initBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.init'));
  condBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.cond'));
  bodyBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.body'));
  stepBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.step'));
  exitBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.exit'));

  PushBreakTarget(exitBlock);
  PushContinueTarget(stepBlock);

  varPtr := FCurrentFunction.AddLocal(varType, varName);
  FLocalVarMap.AddObject(varName, varPtr);

  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(initBlock);

  FCurrentBlock := initBlock;
  startVal := LowerExpression(Stmt.StartExpr);
  CreateStore(startVal, varPtr);
  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  FCurrentBlock := condBlock;
  endVal := LowerExpression(Stmt.EndExpr);
  varPtr := TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(varName)]);
  varPtr := CreateLoad(varPtr, 'for.var');
  condInstr := TIRInstruction.Create(ikICmp, TIRType.Bool, 'for.cond');
  condInstr.AddOperand(varPtr);
  condInstr.AddOperand(endVal);
  EmitInstr(condInstr);
  EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condInstr);
  FCurrentBlock.GetLastInstr.AddOperand(bodyBlock);
  FCurrentBlock.GetLastInstr.AddOperand(exitBlock);

  FCurrentBlock := bodyBlock;
  for i := 0 to High(Stmt.Body) do
    LowerStatement(Stmt.Body[i]);
  if not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(stepBlock);

  FCurrentBlock := stepBlock;
  if Assigned(Stmt.StepExpr) then
    stepVal := LowerExpression(Stmt.StepExpr)
  else if Stmt.IsDownTo then
    stepVal := TIRConstant.CreateInt(varType, -1, 'for.step')
  else
    stepVal := TIRConstant.CreateInt(varType, 1, 'for.step');
  varPtr := TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(varName)]);
  varPtr := CreateLoad(varPtr, 'for.var');
  EmitInstr(TIRInstruction.Create(ikAdd, varType, 'for.next'));
  FCurrentBlock.GetLastInstr.AddOperand(varPtr);
  FCurrentBlock.GetLastInstr.AddOperand(stepVal);
  CreateStore(FCurrentBlock.GetLastInstr, TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(varName)]));
  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  FCurrentBlock := exitBlock;
  PopContinueTarget;
  PopBreakTarget;
  FLocalVarMap.Delete(FLocalVarMap.IndexOf(varName));
end;

procedure TFPXIRGenerator.LowerWhile(Stmt: TWhileStmt);
var
  condBlock, bodyBlock, exitBlock: TIRBlock;
  condVal: TIRValue;
  i: Integer;
begin
  condBlock := FCurrentFunction.CreateBlock(CreateBlockName('while.cond'));
  bodyBlock := FCurrentFunction.CreateBlock(CreateBlockName('while.body'));
  exitBlock := FCurrentFunction.CreateBlock(CreateBlockName('while.exit'));

  PushBreakTarget(exitBlock);
  PushContinueTarget(condBlock);

  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  FCurrentBlock := condBlock;
  condVal := LowerExpression(Stmt.Condition);
  EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condVal);
  FCurrentBlock.GetLastInstr.AddOperand(bodyBlock);
  FCurrentBlock.GetLastInstr.AddOperand(exitBlock);

  FCurrentBlock := bodyBlock;
  for i := 0 to High(Stmt.Body) do
    LowerStatement(Stmt.Body[i]);
  if not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  if Stmt.HasElse then
  begin
  end;

  FCurrentBlock := exitBlock;
  PopContinueTarget;
  PopBreakTarget;
end;

procedure TFPXIRGenerator.LowerReturn(Stmt: TReturnStmt);
var
  retVal: TIRValue;
begin
  if Stmt.HasValue then
  begin
    retVal := LowerExpression(Stmt.Value);
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(retVal);
  end
  else
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));
end;

procedure TFPXIRGenerator.LowerYield(Stmt: TYieldStmt);
var
  val: TIRValue;
begin
  val := LowerExpression(Stmt.Value);
  EmitInstr(TIRInstruction.Create(ikYield, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(val);
end;

function TFPXIRGenerator.GetIRType(const TypeName: string): TIRType;
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

function TFPXIRGenerator.MapTokenTypeToBinOp(TT: TTokenType): TIRInstructionKind;
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

function TFPXIRGenerator.MapTokenTypeToCmpOp(TT: TTokenType): TIRInstructionKind;
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

function TFPXIRGenerator.MapTokenTypeToUnaryOp(TT: TTokenType): TIRInstructionKind;
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

procedure TFPXIRGenerator.ReportError(Code: Integer; const Msg: string; Line, Col: Integer);
begin
end;

procedure TFPXIRGenerator.ReportErrorNode(Node: TASTNode; Code: Integer; const Msg: string);
begin
end;

function TFPXIRGenerator.GetIRTypeFromToken(AToken: TToken): TIRType;
begin
  Result := TIRType.AnyType;
end;

procedure TFPXIRGenerator.LowerLoopCtrl(Stmt: TLoopCtrlStmt);
var
  target: TIRBlock;
  kind: string;
begin
  kind := Stmt.Kind;
  if kind = 'BREAK' then
    target := CurrentBreakTarget
  else if kind = 'LOOP' then
    target := CurrentContinueTarget
  else
    target := CurrentBreakTarget;
  if Assigned(target) then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''))
  else
    EmitInstr(TIRInstruction.Create(ikUnreachable, TIRType.Void, ''));
  if Assigned(target) then
    FCurrentBlock.GetLastInstr.AddOperand(target);
end;

function TFPXIRGenerator.LowerExpression(Expr: TExpr): TIRValue;
begin
  if Expr is TLiteralExpr then Result := LowerLiteral(TLiteralExpr(Expr))
  else if Expr is TIdentifierExpr then Result := LowerIdentifier(TIdentifierExpr(Expr))
  else if Expr is TBinaryExpr then Result := LowerBinary(TBinaryExpr(Expr))
  else if Expr is TUnaryExpr then Result := LowerUnary(TUnaryExpr(Expr))
  else if Expr is TCallExpr then Result := LowerCall(TCallExpr(Expr))
  else if Expr is TMethodCallExpr then Result := LowerMethodCall(TMethodCallExpr(Expr))
  else if Expr is TMemberAccessExpr then Result := LowerMemberAccess(TMemberAccessExpr(Expr))
  else if Expr is TDerefExpr then Result := LowerDeref(TDerefExpr(Expr))
  else if Expr is TArrayLiteralExpr then Result := LowerArrayLiteral(TArrayLiteralExpr(Expr))
  else if Expr is THashLiteralExpr then Result := LowerHashLiteral(THashLiteralExpr(Expr))
  else if Expr is TCodeBlockExpr then Result := LowerCodeBlock(TCodeBlockExpr(Expr))
  else if Expr is TStructLiteralExpr then Result := LowerStructLiteral(TStructLiteralExpr(Expr))
  else if Expr is TMacroExpr then Result := LowerMacro(TMacroExpr(Expr))
  else
  begin
    ReportErrorNode(Expr, FPX_UNSUPPORTED_FEATURE, 'Expression type not supported');
    Result := TIRConstant.CreateInt(TIRType.Int(True, 32), 0, 'error');
  end;
end;

function TFPXIRGenerator.LowerLiteral(Expr: TLiteralExpr): TIRValue;
var
  tok: TToken;
  irType: TIRType;
begin
  tok := Expr.Token;
  case tok.TokenType of
    ttInteger:
    begin
      irType := TIRType.Int(True, 64);
      Result := TIRConstant.CreateInt(irType, tok.IntValue, CreateTempName('const'));
    end;
    ttReal:
    begin
      irType := TIRType.Float(64);
      Result := TIRConstant.CreateReal(irType, tok.RealValue, CreateTempName('const'));
    end;
    ttString:
    begin
      irType := TIRType.StringType;
      Result := TIRConstant.CreateString(irType, tok.StrValue, CreateTempName('const'));
    end;
    ttLogical:
    begin
      irType := TIRType.Bool;
      Result := TIRConstant.CreateBool(irType, tok.IntValue = 1, CreateTempName('const'));
    end;
    ttNil:
    begin
      irType := TIRType.Pointer(TIRType.Void);
      Result := TIRConstant.CreateNull(irType, CreateTempName('nil'));
    end;
    ttDate:
    begin
      irType := TIRType.Int(True, 64);
      Result := TIRConstant.CreateInt(irType, tok.IntValue, CreateTempName('const'));
    end;
    else
    begin
      irType := TIRType.Int(True, 32);
      Result := TIRConstant.CreateInt(irType, 0, 'const');
    end;
  end;
end;

function TFPXIRGenerator.LowerIdentifier(Expr: TIdentifierExpr): TIRValue;
var
  local: TIRValue;
  nm: string;
begin
  nm := Expr.Name;
  if FLocalVarMap.IndexOf(nm) >= 0 then
  begin
    local := TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(nm)]);
    Result := CreateLoad(local, nm);
    if local is TIRLocal then
      TIRLocal(local).IsAddressTaken := True;
  end
  else
  begin
    Result := TIRConstant.CreateNull(TIRType.Pointer(TIRType.Void), CreateTempName('global.' + nm));
  end;
end;

function TFPXIRGenerator.LowerBinary(Expr: TBinaryExpr): TIRValue;
var
  left, right: TIRValue;
  opKind: TIRInstructionKind;
begin
  left := LowerExpression(Expr.Left);
  right := LowerExpression(Expr.Right);
  opKind := MapTokenTypeToBinOp(Expr.Op);
  if opKind <> ikInvalid then
    Result := EmitBinOp(opKind, left, right, CreateTempName('bin'))
  else
  begin
    opKind := MapTokenTypeToCmpOp(Expr.Op);
    if opKind <> ikInvalid then
      Result := EmitCmpOp(opKind, left, right, CreateTempName('cmp'))
    else
    begin
      ReportErrorNode(Expr, FPX_UNSUPPORTED_FEATURE, 'Binary operator not supported: ' + TokenTypeName(Expr.Op));
      Result := TIRConstant.CreateInt(TIRType.Int(True, 32), 0, 'error');
    end;
  end;
end;

function TFPXIRGenerator.LowerUnary(Expr: TUnaryExpr): TIRValue;
var
  operand: TIRValue;
  opKind: TIRInstructionKind;
begin
  operand := LowerExpression(Expr.Operand);
  opKind := MapTokenTypeToUnaryOp(Expr.Op);
  if opKind <> ikInvalid then
    Result := EmitCast(opKind, operand, operand.Type_, CreateTempName('unary'))
  else
  begin
    ReportErrorNode(Expr, FPX_UNSUPPORTED_FEATURE, 'Unary operator not supported: ' + TokenTypeName(Expr.Op));
    Result := operand;
  end;
end;

function TFPXIRGenerator.LowerCall(Expr: TCallExpr): TIRValue;
var
  fn: TIRFunction;
  args: TIRValueArray;
  i: Integer;
begin
  fn := FModule.GetFunction(Expr.Name);
  if not Assigned(fn) then
    fn := FModule.AddFunction(Expr.Name, TIRType.AnyType);
  SetLength(args, Expr.ArgCount);
  for i := 0 to Expr.ArgCount - 1 do
    args[i] := LowerExpression(Expr.Args[i]);
  Result := CreateCallDirect(Expr.Name, fn.ReturnType, args, CreateTempName('call'));
end;

function TFPXIRGenerator.LowerMethodCall(Expr: TMethodCallExpr): TIRValue;
var
  target: TIRValue;
  args: TIRValueArray;
  i: Integer;
begin
  target := LowerExpression(Expr.Target);
  SetLength(args, Expr.ArgCount);
  for i := 0 to Expr.ArgCount - 1 do
    args[i] := LowerExpression(Expr.Args[i]);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('method.' + Expr.Method));
end;

function TFPXIRGenerator.LowerMemberAccess(Expr: TMemberAccessExpr): TIRValue;
var
  target: TIRValue;
begin
  target := LowerExpression(Expr.Target);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('member.' + Expr.Member));
end;

function TFPXIRGenerator.LowerDeref(Expr: TDerefExpr): TIRValue;
var
  target: TIRValue;
begin
  target := LowerExpression(Expr.Target);
  Result := CreateLoad(target, CreateTempName('deref'));
end;

function TFPXIRGenerator.LowerArrayLiteral(Expr: TArrayLiteralExpr): TIRValue;
var
  arrType: TIRType;
  i: Integer;
begin
  arrType := TIRType.MakeArray(TIRType.AnyType);
  Result := TIRGlobal.Create(arrType, CreateTempName('arr'));
  for i := 0 to Expr.Count - 1 do
    LowerExpression(Expr.Items[i]);
end;

function TFPXIRGenerator.LowerHashLiteral(Expr: THashLiteralExpr): TIRValue;
var
  i: Integer;
begin
  Result := TIRGlobal.Create(TIRType.AnyType, CreateTempName('hash'));
  for i := 0 to Length(Expr.Keys) - 1 do
  begin
    LowerExpression(Expr.Keys[i]);
    LowerExpression(Expr.Values[i]);
  end;
end;

function TFPXIRGenerator.LowerCodeBlock(Expr: TCodeBlockExpr): TIRValue;
var
  i: Integer;
begin
  for i := 0 to Length(Expr.Statements) - 1 do
    LowerStatement(Expr.Statements[i]);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('codeblock'));
end;

function TFPXIRGenerator.LowerStructLiteral(Expr: TStructLiteralExpr): TIRValue;
var
  i: Integer;
begin
  for i := 0 to Length(Expr.Args) - 1 do
    LowerExpression(Expr.Args[i]);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('struct.' + Expr.TypeName));
end;

function TFPXIRGenerator.LowerMacro(Expr: TMacroExpr): TIRValue;
begin
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('macro.' + Expr.Name));
end;

end.