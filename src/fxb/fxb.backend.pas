unit fxb.backend;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  Unix,
  BaseUnix,
  Generics.Collections,
  fxb.ir,
  fxb.ir.types,
  fxb.ir.instr,
  fxb.errors;

type
  TLocalOffsetMap = specialize TDictionary<TIRLocal, Integer>;

type
  TFXBBackend = class
  private
    FTargetOS: string;
    FTargetCPU: string;
    FOutputType: string;
    FOptimizationLevel: Integer;
    FDebugInfo: Boolean;
    FDBDriver: string;
    FDBConnection: string;
    FErrors: TCompilerMessageArray;
    FLastASM: string;
    FASM: TStringList;
    FModule: TIRModule;
    FIndent: string;
    FLocalOffsets: TLocalOffsetMap; // Local variable -> stack offset from rbp
    FNextLocalOffset: Integer;

    procedure Emit(const Line: string);
    procedure EmitLabel(const Name: string);
    procedure EmitDirective(const Dir: string);
    function RegName(Size: Integer; Index: Integer): string;
    function GetLocalOffset(Local: TIRLocal): Integer;
    procedure AssignLocalOffsets(Func: TIRFunction);
    function GetOperandReg(Val: TIRValue; ScratchReg: string): string;
    function GetOperandMemRef(Val: TIRValue; ScratchReg: string): string;

    procedure GenerateFunction(Func: TIRFunction);
    procedure GenerateBlock(Block: TIRBlock);
    procedure GenerateInstr(Instr: TIRInstruction);
    procedure GeneratePrologue(Func: TIRFunction);
    procedure GenerateEpilogue(Func: TIRFunction);
    procedure GenerateAllFunctions(const IR: TIRModule);

    // Instruction generators
    procedure GenRet(Instr: TIRInstruction);
    procedure GenBr(Instr: TIRInstruction);
    procedure GenCondBr(Instr: TIRInstruction);
    procedure GenBinaryOp(Instr: TIRInstruction);
    procedure GenLoad(Instr: TIRInstruction);
    procedure GenStore(Instr: TIRInstruction);
    procedure GenAlloca(Instr: TIRInstruction);
    procedure GenCall(Instr: TIRInstruction);
    procedure GenCallDirect(Instr: TIRInstruction);
    procedure GenICmp(Instr: TIRInstruction);

    function MapInstrKindToAsm(Kind: TIRInstructionKind): string;
    function IsCommutative(Kind: TIRInstructionKind): Boolean;
    function InstrKindToStr(Kind: TIRInstructionKind): string;

    procedure ReportError(const Msg: string; Node: TObject = nil);
  public
    property TargetOS: string read FTargetOS write FTargetOS;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property OutputType: string read FOutputType write FOutputType;
    property OptimizationLevel: Integer read FOptimizationLevel write FOptimizationLevel;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    property DBDriver: string read FDBDriver write FDBDriver;
    property DBConnection: string read FDBConnection write FDBConnection;
    function Generate(const IR: TIRModule; const OutputFile: string): Boolean;
    function HasErrors: Boolean;
    property Errors: TCompilerMessageArray read FErrors;
    property LastASM: string read FLastASM;
  end;

implementation

{ TFXBBackend }

procedure TFXBBackend.Emit(const Line: string);
begin
  FASM.Add(FIndent + Line);
end;

procedure TFXBBackend.EmitLabel(const Name: string);
begin
  FASM.Add(Name + ':');
end;

procedure TFXBBackend.EmitDirective(const Dir: string);
begin
  FASM.Add(#9 + Dir);
end;

function TFXBBackend.RegName(Size: Integer; Index: Integer): string;
const
  Regs64: array[0..15] of string = (
    'rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi',
    'r8',  'r9',  'r10', 'r11', 'r12', 'r13', 'r14', 'r15'
  );
  Regs32: array[0..15] of string = (
    'eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi',
    'r8d', 'r9d', 'r10d', 'r11d', 'r12d', 'r13d', 'r14d', 'r15d'
  );
begin
  case Size of
    8: Result := Regs64[Index];
    4: Result := Regs32[Index];
    else Result := Regs64[Index];
  end;
end;

procedure TFXBBackend.AssignLocalOffsets(Func: TIRFunction);
var
  i: Integer;
  local: TIRLocal;
begin
  FLocalOffsets.Clear;
  FNextLocalOffset := 0;
  for i := 0 to High(Func.Locals) do
  begin
    local := Func.Locals[i];
    FNextLocalOffset := FNextLocalOffset + 8;
    FLocalOffsets.Add(local, FNextLocalOffset);
  end;
end;

function TFXBBackend.GetLocalOffset(Local: TIRLocal): Integer;
begin
  if FLocalOffsets.TryGetValue(Local, Result) then
    Exit;
  Result := 0;
end;

function TFXBBackend.GetOperandReg(Val: TIRValue; ScratchReg: string): string;
var
  c: TIRConstant;
  a: TIRArgument;
  l: TIRLocal;
begin
  // Ensure ScratchReg has % prefix for AT&T syntax
  if (Length(ScratchReg) > 0) and (ScratchReg[1] <> '%') then
    ScratchReg := '%' + ScratchReg;
  Result := ScratchReg;
  if Val is TIRConstant then
  begin
    c := TIRConstant(Val);
    if c.Type_.Kind in [fxb.ir.types.tkInt8, fxb.ir.types.tkInt16, fxb.ir.types.tkInt32, fxb.ir.types.tkInt64,
                       fxb.ir.types.tkUInt8, fxb.ir.types.tkUInt16, fxb.ir.types.tkUInt32, fxb.ir.types.tkUInt64] then
      Emit(Format('movq $%d, %s', [c.IntVal, ScratchReg]))
    else if c.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64] then
      Emit(Format('movq $%f, %s', [c.RealVal, ScratchReg])) // placeholder
    else if c.Type_.Kind = fxb.ir.types.tkBool then
    begin
      if c.BoolVal then
        Emit(Format('movq $1, %s', [ScratchReg]))
      else
        Emit(Format('xorq %s, %s', [ScratchReg, ScratchReg]));
    end
    else if c.IsNull then
      Emit(Format('xorq %s, %s', [ScratchReg, ScratchReg]));
  end
  else if Val is TIRArgument then
  begin
    a := TIRArgument(Val);
    // x86_64 ABI: rdi, rsi, rdx, rcx, r8, r9
case a.Index of
      0: Result := '%rdi';
      1: Result := '%rsi';
      2: Result := '%rdx';
      3: Result := '%rcx';
      4: Result := '%r8';
      5: Result := '%r9';
      else Result := ScratchReg;
    end;
  end
  else if Val is TIRLocal then
  begin
    l := TIRLocal(Val);
    Result := ScratchReg;
    // Load from stack: movq [rbp - offset], reg
    Emit(Format('movq %s, %s', [GetOperandMemRef(l, ScratchReg), ScratchReg]));
  end;
end;

function TFXBBackend.GetOperandMemRef(Val: TIRValue; ScratchReg: string): string;
var
  l: TIRLocal;
begin
  Result := ScratchReg;
  if Val is TIRLocal then
  begin
    l := TIRLocal(Val);
    Result := Format('%d(%%rbp)', [-GetLocalOffset(l)]);
  end
  else
    Result := ScratchReg;
end;

procedure TFXBBackend.GenerateFunction(Func: TIRFunction);
var
  blk: TIRBlock;
  i: Integer;
begin
  if Func.IsExternal then Exit;

  FASM.Add('');
  EmitDirective(Format('.globl %s', [Func.Name]));
  EmitDirective(Format('.type %s, @function', [Func.Name]));
  EmitLabel(Func.Name);

  AssignLocalOffsets(Func);
  GeneratePrologue(Func);

  for i := 0 to Func.Blocks.Count - 1 do
  begin
    blk := TIRBlock(Func.Blocks[i]);
    GenerateBlock(blk);
  end;

  EmitDirective(Format('.size %s, .-%s', [Func.Name, Func.Name]));
end;

procedure TFXBBackend.GeneratePrologue(Func: TIRFunction);
var
  stackSize: Integer;
begin
  stackSize := Length(Func.Locals) * 8;
  stackSize := (stackSize + 15) and not 15;

  Emit('pushq %rbp');
  Emit('movq %rsp, %rbp');
  if stackSize > 0 then
    Emit(Format('subq $%d, %%rsp', [stackSize]));
end;

procedure TFXBBackend.GenerateEpilogue(Func: TIRFunction);
begin
  Emit('movq %rbp, %rsp');
  Emit('popq %rbp');
  Emit('ret');
end;

procedure TFXBBackend.GenerateBlock(Block: TIRBlock);
var
  i: Integer;
  instr: TIRInstruction;
begin
  if not Block.IsEntry then
    EmitLabel(Block.Name);

  for i := 0 to Block.Instructions.Count - 1 do
  begin
    instr := TIRInstruction(Block.Instructions[i]);
    GenerateInstr(instr);
  end;
end;

procedure TFXBBackend.GenerateInstr(Instr: TIRInstruction);
begin
  case Instr.Kind of
    fxb.ir.instr.ikRet: GenRet(Instr);
    fxb.ir.instr.ikBr: GenBr(Instr);
    fxb.ir.instr.ikCondBr: GenCondBr(Instr);
    fxb.ir.instr.ikAdd, fxb.ir.instr.ikSub, fxb.ir.instr.ikMul, fxb.ir.instr.ikDiv, fxb.ir.instr.ikRem,
    fxb.ir.instr.ikShl, fxb.ir.instr.ikShr, fxb.ir.instr.ikAnd, fxb.ir.instr.ikOr, fxb.ir.instr.ikXor: GenBinaryOp(Instr);
    fxb.ir.instr.ikLoad: GenLoad(Instr);
    fxb.ir.instr.ikStore: GenStore(Instr);
    fxb.ir.instr.ikAlloca: GenAlloca(Instr);
    fxb.ir.instr.ikCall: GenCall(Instr);
    fxb.ir.instr.ikCallDirect: GenCallDirect(Instr);
    fxb.ir.instr.ikICmp: GenICmp(Instr);
    else
      Emit(Format('# Unimplemented: %s', [InstrKindToStr(Instr.Kind)]));
  end;
end;

procedure TFXBBackend.GenRet(Instr: TIRInstruction);
var
  val: TIRValue;
  reg: string;
begin
  if Instr.OperandCount > 0 then
  begin
    val := Instr.GetOperand(0);
    reg := GetOperandReg(val, '%rax');
    if (reg <> '%rax') and not (val is TIRConstant) then
      Emit(Format('movq %s, %%rax', [reg]));
  end
  else
    Emit('xorq %%rax, %%rax');
  // Emit epilogue directly
  Emit('movq %rbp, %rsp');
  Emit('popq %rbp');
  Emit('ret');
end;

procedure TFXBBackend.GenBr(Instr: TIRInstruction);
var
  target: TIRBlock;
begin
  if Instr.OperandCount > 0 then
  begin
    target := TIRBlock(Instr.GetOperand(0));
    Emit(Format('jmp %s', [target.Name]));
  end;
end;

procedure TFXBBackend.GenCondBr(Instr: TIRInstruction);
var
  cond: TIRValue;
  thenTarget, elseTarget: TIRBlock;
  condReg: string;
begin
  if Instr.OperandCount >= 3 then
  begin
    cond := Instr.GetOperand(0);
    thenTarget := TIRBlock(Instr.GetOperand(1));
    elseTarget := TIRBlock(Instr.GetOperand(2));

    condReg := GetOperandReg(cond, '%rax');
    Emit(Format('testq %s, %s', [condReg, condReg]));
    Emit(Format('jne %s', [thenTarget.Name]));
    Emit(Format('jmp %s', [elseTarget.Name]));
  end;
end;

procedure TFXBBackend.GenBinaryOp(Instr: TIRInstruction);
var
  left, right, dest: TIRValue;
  leftReg, rightReg, destReg: string;
  asmOp: string;
  isFloat: Boolean;
begin
  if Instr.OperandCount < 2 then Exit;

  left := Instr.GetOperand(0);
  right := Instr.GetOperand(1);
  dest := Instr; // Result is the instruction itself

  isFloat := (left.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64]) or
             (right.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64]);

  leftReg := GetOperandReg(left, '%rax');
  rightReg := GetOperandReg(right, '%rcx');
  destReg := 'rax';

  if left.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64] then
  begin
    // SSE2 floating point
    case Instr.Kind of
      fxb.ir.instr.ikAdd: Emit(Format('movsd xmm0, [%s]', [GetOperandMemRef(left, 'rax')]));
      // ... floating point ops need proper implementation
    end;
  end
  else
  begin
    // Integer operations - result in rax
    if leftReg <> 'rax' then
      Emit(Format('mov rax, %s', [leftReg]));

    case Instr.Kind of
      fxb.ir.instr.ikAdd: Emit(Format('addq %s, %%rax', [rightReg]));
      fxb.ir.instr.ikSub: Emit(Format('subq %s, %%rax', [rightReg]));
      fxb.ir.instr.ikMul: Emit(Format('imulq %s, %%rax', [rightReg]));
      fxb.ir.instr.ikDiv:
        begin
          Emit('cqo');
          Emit(Format('idivq %s', [rightReg]));
        end;
      fxb.ir.instr.ikRem:
        begin
          Emit('cqo');
          Emit(Format('idivq %s', [rightReg]));
          Emit('movq %%rdx, %%rax');
        end;
      fxb.ir.instr.ikShl: Emit('shlq %%cl, %%rax');
      fxb.ir.instr.ikShr: Emit('sarq %%cl, %%rax');
      fxb.ir.instr.ikAnd: Emit(Format('andq %s, %%rax', [rightReg]));
      fxb.ir.instr.ikOr:  Emit(Format('orq %s, %%rax', [rightReg]));
      fxb.ir.instr.ikXor: Emit(Format('xorq %s, %%rax', [rightReg]));
    end;
  end;
end;

procedure TFXBBackend.GenLoad(Instr: TIRInstruction);
begin
  if Instr.OperandCount < 1 then Exit;
  Emit(Format('movq %s, %%rax', [GetOperandMemRef(Instr.GetOperand(0), 'rax')]));
end;

procedure TFXBBackend.GenStore(Instr: TIRInstruction);
var
  val, ptr: TIRValue;
begin
  if Instr.OperandCount < 2 then Exit;
  val := Instr.GetOperand(0);
  ptr := Instr.GetOperand(1);
  Emit(Format('movq %%rax, %s', [GetOperandMemRef(ptr, 'rcx')]));
  Emit(Format('movq %s, %%rax', [GetOperandReg(val, 'rax')]));
end;

procedure TFXBBackend.GenAlloca(Instr: TIRInstruction);
begin
  // Stack allocation handled in prologue
end;

procedure TFXBBackend.GenCall(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  argRegs: array[0..5] of string = ('%rdi', '%rsi', '%rdx', '%rcx', '%r8', '%r9');
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));

  for i := 1 to Instr.OperandCount - 1 do
  begin
    if i - 1 <= High(argRegs) then
      GetOperandReg(Instr.GetOperand(i), argRegs[i - 1])
    else
    begin
      GetOperandReg(Instr.GetOperand(i), '%rax');
      Emit('pushq %rax');
    end;
  end;

  Emit(Format('call %s', [fn.Name]));

  if Instr.OperandCount - 1 > 6 then
    Emit(Format('addq $%d, %%rsp', [(Instr.OperandCount - 7) * 8]));
end;

procedure TFXBBackend.GenCallDirect(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  argRegs: array[0..5] of string = ('%rdi', '%rsi', '%rdx', '%rcx', '%r8', '%r9');
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));

  for i := 1 to Instr.OperandCount - 1 do
  begin
    if i - 1 <= High(argRegs) then
      GetOperandReg(Instr.GetOperand(i), argRegs[i - 1])
    else
    begin
      GetOperandReg(Instr.GetOperand(i), '%rax');
      Emit('pushq %rax');
    end;
  end;

  Emit(Format('call %s', [fn.Name]));

  if Instr.OperandCount - 1 > 6 then
    Emit(Format('addq $%d, %%rsp', [(Instr.OperandCount - 7) * 8]));
end;

procedure TFXBBackend.GenICmp(Instr: TIRInstruction);
var
  left, right: TIRValue;
  leftReg, rightReg: string;
begin
  if Instr.OperandCount < 2 then Exit;
  left := Instr.GetOperand(0);
  right := Instr.GetOperand(1);

  Emit(Format('cmpq %s, %s', [GetOperandReg(left, '%rax'), GetOperandReg(right, '%rcx')]));
  Emit('sete %al');
  Emit('movzbq %al, %%rax');
end;

function TFXBBackend.MapInstrKindToAsm(Kind: TIRInstructionKind): string;
begin
  case Kind of
    fxb.ir.instr.ikAdd: Result := 'add';
    fxb.ir.instr.ikSub: Result := 'sub';
    fxb.ir.instr.ikMul: Result := 'imul';
    fxb.ir.instr.ikDiv: Result := 'idiv';
    fxb.ir.instr.ikRem: Result := 'idiv';
    fxb.ir.instr.ikShl: Result := 'shl';
    fxb.ir.instr.ikShr: Result := 'sar';
    fxb.ir.instr.ikAnd: Result := 'and';
    fxb.ir.instr.ikOr:  Result := 'or';
    fxb.ir.instr.ikXor: Result := 'xor';
    else Result := 'add';
  end;
end;

function TFXBBackend.IsCommutative(Kind: TIRInstructionKind): Boolean;
begin
  Result := Kind in [fxb.ir.instr.ikAdd, fxb.ir.instr.ikMul, fxb.ir.instr.ikAnd, fxb.ir.instr.ikOr, fxb.ir.instr.ikXor];
end;

function TFXBBackend.InstrKindToStr(Kind: TIRInstructionKind): string;
begin
  case Kind of
    fxb.ir.instr.ikInvalid: Result := 'ikInvalid';
    fxb.ir.instr.ikRet: Result := 'ikRet';
    fxb.ir.instr.ikBr: Result := 'ikBr';
    fxb.ir.instr.ikCondBr: Result := 'ikCondBr';
    fxb.ir.instr.ikSwitch: Result := 'ikSwitch';
    fxb.ir.instr.ikCall: Result := 'ikCall';
    fxb.ir.instr.ikCallDirect: Result := 'ikCallDirect';
    fxb.ir.instr.ikLoad: Result := 'ikLoad';
    fxb.ir.instr.ikStore: Result := 'ikStore';
    fxb.ir.instr.ikAlloca: Result := 'ikAlloca';
    fxb.ir.instr.ikGetElementPtr: Result := 'ikGetElementPtr';
    fxb.ir.instr.ikBitCast: Result := 'ikBitCast';
    fxb.ir.instr.ikIntToPtr: Result := 'ikIntToPtr';
    fxb.ir.instr.ikPtrToInt: Result := 'ikPtrToInt';
    fxb.ir.instr.ikTrunc: Result := 'ikTrunc';
    fxb.ir.instr.ikZExt: Result := 'ikZExt';
    fxb.ir.instr.ikSExt: Result := 'ikSExt';
    fxb.ir.instr.ikFPTrunc: Result := 'ikFPTrunc';
    fxb.ir.instr.ikFPExt: Result := 'ikFPExt';
    fxb.ir.instr.ikFPToUI: Result := 'ikFPToUI';
    fxb.ir.instr.ikFPToSI: Result := 'ikFPToSI';
    fxb.ir.instr.ikUIToFP: Result := 'ikUIToFP';
    fxb.ir.instr.ikSIToFP: Result := 'ikSIToFP';
    fxb.ir.instr.ikAdd: Result := 'ikAdd';
    fxb.ir.instr.ikSub: Result := 'ikSub';
    fxb.ir.instr.ikMul: Result := 'ikMul';
    fxb.ir.instr.ikDiv: Result := 'ikDiv';
    fxb.ir.instr.ikRem: Result := 'ikRem';
    fxb.ir.instr.ikShl: Result := 'ikShl';
    fxb.ir.instr.ikShr: Result := 'ikShr';
    fxb.ir.instr.ikAnd: Result := 'ikAnd';
    fxb.ir.instr.ikOr: Result := 'ikOr';
    fxb.ir.instr.ikXor: Result := 'ikXor';
    fxb.ir.instr.ikICmp: Result := 'ikICmp';
    fxb.ir.instr.ikFCmp: Result := 'ikFCmp';
    fxb.ir.instr.ikSelect: Result := 'ikSelect';
    fxb.ir.instr.ikPhi: Result := 'ikPhi';
    fxb.ir.instr.ikYield: Result := 'ikYield';
    fxb.ir.instr.ikUnreachable: Result := 'ikUnreachable';
    fxb.ir.instr.ikDbgValue: Result := 'ikDbgValue';
    fxb.ir.instr.ikDbgLabel: Result := 'ikDbgLabel';
    else Result := 'unknown';
  end;
end;

procedure TFXBBackend.ReportError(const Msg: string; Node: TObject = nil);
var
  m: fxb.errors.TCompilerMessage;
begin
  m.Code := 'BE-0001';
  m.Level := fxb.errors.elError;
  m.Text := Msg;
  m.Line := 0;
  m.Col := 0;
  m.FileName := '';
  SetLength(FErrors, Length(FErrors) + 1);
  FErrors[High(FErrors)] := m;
end;

function TFXBBackend.Generate(const IR: TIRModule; const OutputFile: string): Boolean;
var
  fn: TIRFunction;
  i: Integer;
begin
  FModule := IR;
  FASM := TStringList.Create;
  FIndent := #9;
  FErrors := nil;
  FLastASM := '';
  FLocalOffsets := TLocalOffsetMap.Create;

  try
    EmitDirective('.file "fxbase_output"');
    EmitDirective('.code64');
    EmitDirective('.text');

    GenerateAllFunctions(IR);

    FASM.SaveToFile(OutputFile);
    FLastASM := FASM.Text;
    Result := Length(FErrors) = 0;
  finally
    FASM.Free;
    FLocalOffsets.Free;
  end;
end;

procedure TFXBBackend.GenerateAllFunctions(const IR: TIRModule);
var
  fn: TIRFunction;
  i: Integer;
begin
  // Generate startup code that calls Main
  EmitDirective('.globl _start');
  EmitDirective('.type _start, @function');
  EmitLabel('_start');
  Emit('pushq %rbp');
  Emit('movq %rsp, %rbp');
  Emit('subq $8, %rsp');  // Align stack to 16 bytes before call
  Emit('callq Main');
  Emit('addq $8, %rsp');  // Restore stack
  Emit('movq %rax, %rdi');
  Emit('movq $60, %rax');
  Emit('syscall');
  EmitDirective('.size _start, .-_start');
  Emit('');

  // Generate user functions
  for i := 0 to IR.Functions.Count - 1 do
  begin
    fn := TIRFunction(IR.Functions[i]);
    GenerateFunction(fn);
  end;
end;

function TFXBBackend.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

end.