unit fxb.ir.instr;

{$mode objfpc}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes,
  typinfo,
  fxb.ir.types;

type
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
    ikPrint,
    ikDBOp,        // Fase 2: USE/APPEND/REPLACE -> SQLite runtime call
    ikPGOp,        // Fase 3: USE/APPEND/REPLACE -> PostgreSQL runtime call
    ikYield,
    ikUnreachable,
    ikDbgValue,
    ikDbgLabel
  );

  TIRBlock = class;
  TIRFunction = class;
  TIRModule = class;
  TIRInstruction = class;
  TIRArgument = class;
  TIRLocal = class;

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

  TIRValueArray = array of TIRValue;
  TIRInstructionArray = array of TIRInstruction;
  TIRArgumentArray = array of TIRArgument;
  TIRLocalArray = array of TIRLocal;

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

  TIRBlockArray = array of TIRBlock;

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

implementation

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
begin
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
  if FMetadata.Count > 0 then
    Result := Result + ' { ' + FMetadata.CommaText + ' }';
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
  blockName: string;
begin
  if AName = '' then
    blockName := 'block' + IntToStr(FBlocks.Count)
  else
    blockName := AName;
  block := TIRBlock.Create(blockName, Self);
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


end.
