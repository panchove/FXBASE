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
  protected
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
    FStringPool: TStringList;       // String literal -> .LstrN pool for .rodata
    FRealPool: TStringList;         // Double literal -> .LrealN pool for .rodata

    procedure Emit(const Line: string);
    procedure EmitCall(const Name: string);
    procedure EmitLabel(const Name: string);
    procedure EmitDirective(const Dir: string);
    function RegName(Size: Integer; Index: Integer): string;
    function IsX86_64: Boolean;
    function IsWindows: Boolean;
    function Deco(const Name: string): string;
    function PrintArgReg: string;
    function WordSize: Integer;
    function MovOp: string;
    function AddOp: string;
    function SubOp: string;
    function MulOp: string;
    function DivOp: string;
    function RemOp: string;
    function ShlOp: string;
    function ShrOp: string;
    function AndOp: string;
    function OrOp: string;
    function XorOp: string;
    function CmpOp: string;
    function BPReg: string;
    function SPReg: string;
    function AXReg: string;
    function DXReg: string;
    function CXReg: string;
    function RIP(const LabelName: string): string;
    function GetLocalOffset(Local: TIRLocal): Integer;
    procedure AssignLocalOffsets(Func: TIRFunction);
    function GetOperandReg(Val: TIRValue; ScratchReg: string): string;
    function GetOperandMemRef(Val: TIRValue; ScratchReg: string): string;
    function LoadFloatOperand(Val: TIRValue; const XmmReg: string): string;
    function GetStringLabel(const S: string): string;
    function GetRealLabel(const V: Double): string;
    procedure EmitStringPool;
    procedure EmitRealPool;
    procedure LoadPrintArg(Val: TIRValue);
    procedure LoadPrintArgFloat(Val: TIRValue);

    procedure GenerateFunction(Func: TIRFunction);
    procedure GenerateBlock(Block: TIRBlock);
    procedure GenerateInstr(Instr: TIRInstruction);
    procedure GeneratePrologue(Func: TIRFunction); virtual; abstract;
    procedure GenerateEpilogue(Func: TIRFunction);
    procedure GenerateAllFunctions(const IR: TIRModule);
    procedure EmitRuntimeHelpers;
    procedure EmitDBRuntime;
    procedure EmitRuntimeData;

    // Instruction generators
    procedure GenRet(Instr: TIRInstruction);
    procedure GenBr(Instr: TIRInstruction);
    procedure GenCondBr(Instr: TIRInstruction);
    procedure GenBinaryOp(Instr: TIRInstruction); virtual; abstract;
    procedure GenLoad(Instr: TIRInstruction);
    procedure GenStore(Instr: TIRInstruction);
    procedure GenAlloca(Instr: TIRInstruction);
    procedure GenCall(Instr: TIRInstruction); virtual; abstract;
    procedure GenCallDirect(Instr: TIRInstruction); virtual; abstract;
    procedure GenICmp(Instr: TIRInstruction); virtual; abstract;
    procedure GenPrint(Instr: TIRInstruction); virtual; abstract;
    procedure GenDBOp(Instr: TIRInstruction);

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

procedure TFXBBackend.EmitCall(const Name: string);
begin
  Emit(Format('call%s %s', [Copy(MovOp, 4, 3), Deco(Name)]));
end;

procedure TFXBBackend.EmitLabel(const Name: string);
begin
  // Decorate non-local symbols (functions/globals) for COFF 32-bit Windows.
  // Local labels (starting with '.') are left as-is.
  if (Name <> '') and (Name[1] <> '.') then
    FASM.Add(Deco(Name) + ':')
  else
    FASM.Add(Name + ':');
end;

procedure TFXBBackend.EmitDirective(const Dir: string);
var
  sp: Integer;
  name: string;
  d: string;
begin
  // COFF/PE (Windows, via MinGW) does not support ELF .type/.size directives; they
  // produce assembler errors. Skip them for Windows targets.
  if IsWindows and ((Copy(Dir, 1, 5) = '.type') or (Copy(Dir, 1, 5) = '.size')) then
    Exit;
  d := Dir;
  // Decorate the symbol in `.globl NAME` for COFF 32-bit Windows.
  if IsWindows and (not IsX86_64) and (Copy(d, 1, 6) = '.globl') then
  begin
    sp := Pos(' ', d);
    if sp > 0 then
    begin
      name := Trim(Copy(d, sp + 1, MaxInt));
      if (name <> '') and (name[1] <> '.') then
        d := '.globl ' + Deco(name);
    end;
  end;
  FASM.Add(#9 + d);
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

function TFXBBackend.IsX86_64: Boolean;
begin
  // Default (empty / 'x86_64' / 'native') is 64-bit; only explicit 'x86' is 32-bit.
  Result := FTargetCPU <> 'x86';
end;

function TFXBBackend.IsWindows: Boolean;
begin
  Result := (FTargetOS = 'windows') or (FTargetOS = 'win32') or (FTargetOS = 'win64');
end;

function TFXBBackend.Deco(const Name: string): string;
begin
  // COFF (32-bit Windows) decorates C symbols with a leading underscore.
  // Local labels (starting with '.') are left as-is.
  if IsWindows and (not IsX86_64) and ((Name = '') or (Name[1] <> '.')) then
    Result := '_' + Name
  else
    Result := Name;
end;

function TFXBBackend.PrintArgReg: string;
begin
  // 2nd varargs register for printf: System V x86_64 uses %rsi, MS x86_64 uses %rdx.
  if IsWindows then Result := '%rdx' else Result := '%rsi';
end;

function TFXBBackend.WordSize: Integer;
begin
  if IsX86_64 then Result := 8 else Result := 4;
end;

function TFXBBackend.MovOp: string;
begin if IsX86_64 then Result := 'movq' else Result := 'movl'; end;

function TFXBBackend.AddOp: string;
begin if IsX86_64 then Result := 'addq' else Result := 'addl'; end;

function TFXBBackend.SubOp: string;
begin if IsX86_64 then Result := 'subq' else Result := 'subl'; end;

function TFXBBackend.MulOp: string;
begin if IsX86_64 then Result := 'imulq' else Result := 'imull'; end;

function TFXBBackend.DivOp: string;
begin if IsX86_64 then Result := 'idivq' else Result := 'idivl'; end;

function TFXBBackend.RemOp: string;
begin if IsX86_64 then Result := 'idivq' else Result := 'idivl'; end;

function TFXBBackend.ShlOp: string;
begin if IsX86_64 then Result := 'shlq' else Result := 'shll'; end;

function TFXBBackend.ShrOp: string;
begin if IsX86_64 then Result := 'sarq' else Result := 'sarl'; end;

function TFXBBackend.AndOp: string;
begin if IsX86_64 then Result := 'andq' else Result := 'andl'; end;

function TFXBBackend.OrOp: string;
begin if IsX86_64 then Result := 'orq' else Result := 'orl'; end;

function TFXBBackend.XorOp: string;
begin if IsX86_64 then Result := 'xorq' else Result := 'xorl'; end;

function TFXBBackend.CmpOp: string;
begin if IsX86_64 then Result := 'cmpq' else Result := 'cmpl'; end;

function TFXBBackend.BPReg: string;
begin if IsX86_64 then Result := '%rbp' else Result := '%ebp'; end;

function TFXBBackend.SPReg: string;
begin if IsX86_64 then Result := '%rsp' else Result := '%esp'; end;

function TFXBBackend.AXReg: string;
begin if IsX86_64 then Result := '%rax' else Result := '%eax'; end;

function TFXBBackend.DXReg: string;
begin if IsX86_64 then Result := '%rdx' else Result := '%edx'; end;

function TFXBBackend.CXReg: string;
begin if IsX86_64 then Result := '%rcx' else Result := '%ecx'; end;

// RIP-relative addressing only exists in x86_64. In 32-bit we use absolute
// (non-PIE) references, which is what `as`/`ld` produce for ELF32 by default.
function TFXBBackend.RIP(const LabelName: string): string;
begin
  if IsX86_64 then
    Result := Deco(LabelName) + '(%rip)'
  else
    Result := Deco(LabelName);
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
    FNextLocalOffset := FNextLocalOffset + WordSize;
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
  inst: TIRInstruction;
  argSlot: Integer;
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
      Emit(Format('%s $%d, %s', [MovOp, c.IntVal, ScratchReg]))
    else if c.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64] then
      Emit(Format('movsd %s, %s', [RIP(GetRealLabel(c.RealVal)), ScratchReg])) // placeholder
    else if c.Type_.Kind = fxb.ir.types.tkBool then
    begin
      if c.BoolVal then
        Emit(Format('%s $1, %s', [MovOp, ScratchReg]))
      else
        Emit(Format('xor%s %s, %s', [Copy(MovOp, 1, 3), ScratchReg, ScratchReg]));
    end
else if c.IsNull then
      Emit(Format('xor%s %s, %s', [Copy(MovOp, 1, 3), ScratchReg, ScratchReg]))
    else if c.Type_.Kind = fxb.ir.types.tkString then
      Emit(Format('leaq %s, %s', [RIP(GetStringLabel(c.StrVal)), ScratchReg]))
  end
  else if Val is TIRArgument then
  begin
    a := TIRArgument(Val);
    if IsX86_64 then
    begin
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
    else
    begin
      // x86_32 cdecl: arg i at [ebp + 8 + 4*i] (skip saved ebp + return addr)
      argSlot := 8 + WordSize * a.Index;
      Result := ScratchReg;
      Emit(Format('%s %d(%%ebp), %s', [MovOp, argSlot, ScratchReg]));
    end;
  end
  else if Val is TIRLocal then
  begin
    l := TIRLocal(Val);
    Result := ScratchReg;
    // Load from stack: movq [rbp - offset], reg
    Emit(Format('%s %s, %s', [MovOp, GetOperandMemRef(l, ScratchReg), ScratchReg]));
  end
  else if Val is TIRInstruction then
  begin
    inst := TIRInstruction(Val);
    if (inst.Kind = fxb.ir.instr.ikLoad) and (inst.OperandCount > 0) then
      Result := GetOperandReg(inst.GetOperand(0), ScratchReg);
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
    Result := Format('%d(%s)', [-GetLocalOffset(l), BPReg]);
  end
  else
    Result := ScratchReg;
end;

// Load a floating-point value into an XMM register and return the register name.
// Handles real constants (via .rodata pool), locals (stack) and instruction-defined values.
function TFXBBackend.LoadFloatOperand(Val: TIRValue; const XmmReg: string): string;
var
  c: TIRConstant;
  l: TIRLocal;
  inst: TIRInstruction;
begin
  Result := XmmReg;
  if Val is TIRConstant then
  begin
    c := TIRConstant(Val);
    if c.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64] then
      Emit(Format('movsd %s, %s', [RIP(GetRealLabel(c.RealVal)), XmmReg]))
    else
      // Non-float constant promoted to 0.0 (should not happen for float ops)
      Emit(Format('xorps %s, %s', [XmmReg, XmmReg]));
  end
  else if Val is TIRLocal then
  begin
    l := TIRLocal(Val);
    Emit(Format('movsd %s, %s', [GetOperandMemRef(l, XmmReg), XmmReg]));
  end
  else if Val is TIRInstruction then
  begin
    inst := TIRInstruction(Val);
    if (inst.Kind = fxb.ir.instr.ikLoad) and (inst.OperandCount > 0) then
      Result := LoadFloatOperand(inst.GetOperand(0), XmmReg)
    else
      // Value defined by another instruction (e.g. a previous float op):
      // it was materialized to its stack slot by GenBinaryOp, so reload it.
      Emit(Format('movsd %s, %s', [GetOperandMemRef(inst, XmmReg), XmmReg]));
  end
  else
    Emit(Format('xorps %s, %s', [XmmReg, XmmReg]));
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


procedure TFXBBackend.GenerateEpilogue(Func: TIRFunction);
begin
  Emit(Format('%s %s, %s', [MovOp, BPReg, SPReg]));
  Emit(Format('pop%s %s', [Copy(MovOp, 4, 3), BPReg]));
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
    fxb.ir.instr.ikPrint: GenPrint(Instr);
    fxb.ir.instr.ikDBOp: GenDBOp(Instr);
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
    reg := GetOperandReg(val, AXReg);
    if (reg <> AXReg) and not (val is TIRConstant) then
      Emit(Format('%s %s, %s', [MovOp, reg, AXReg]));
  end
  else
    Emit(Format('xor%s %s, %s', [Copy(MovOp, 4, 3), AXReg, AXReg]));
  // Emit epilogue directly
  Emit(Format('%s %s, %s', [MovOp, BPReg, SPReg]));
  Emit(Format('pop%s %s', [Copy(MovOp, 4, 3), BPReg]));
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

    condReg := GetOperandReg(cond, AXReg);
    Emit(Format('test%s %s, %s', [Copy(MovOp, 4, 3), condReg, condReg]));
    Emit(Format('jne %s', [thenTarget.Name]));
    Emit(Format('jmp %s', [elseTarget.Name]));
  end;
end;


procedure TFXBBackend.GenLoad(Instr: TIRInstruction);
begin
  if Instr.OperandCount < 1 then Exit;
  Emit(Format('%s %s, %s', [MovOp, GetOperandMemRef(Instr.GetOperand(0), AXReg), AXReg]));
end;

procedure TFXBBackend.GenStore(Instr: TIRInstruction);
var
  val, ptr: TIRValue;
begin
  if Instr.OperandCount < 2 then Exit;
  val := Instr.GetOperand(0);
  ptr := Instr.GetOperand(1);
  Emit(Format('%s %s, %s', [MovOp, GetOperandReg(val, AXReg), AXReg]));
  Emit(Format('%s %s, %s', [MovOp, AXReg, GetOperandMemRef(ptr, CXReg)]));
end;

procedure TFXBBackend.GenAlloca(Instr: TIRInstruction);
begin
  // Stack allocation handled in prologue
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
  blk: TIRBlock;
  instr: TIRInstruction;
  val: TIRValue;
  fnIdx, blkIdx, instrIdx, opIdx: Integer;
  i: Integer;
begin
  FModule := IR;
  FASM := TStringList.Create;
  FIndent := #9;
  FErrors := nil;
  FLastASM := '';
  FLocalOffsets := TLocalOffsetMap.Create;
  FStringPool := TStringList.Create;
  FRealPool := TStringList.Create;

  try
    EmitDirective('.file "fxbase_output"');
    if IsX86_64 then
      EmitDirective('.code64')
    else
      EmitDirective('.code32');
    EmitDirective('.text');

    // Pre-scan IR to collect all string constants for the string pool
    // Walk all functions, blocks, and instructions to find string constants
    for fnIdx := 0 to IR.Functions.Count - 1 do
    begin
      fn := TIRFunction(IR.Functions[fnIdx]);
      for blkIdx := 0 to fn.Blocks.Count - 1 do
      begin
        blk := TIRBlock(fn.Blocks[blkIdx]);
        for instrIdx := 0 to blk.Instructions.Count - 1 do
        begin
          instr := TIRInstruction(blk.Instructions[instrIdx]);
          // Check operands for string constants
          for opIdx := 0 to instr.OperandCount - 1 do
          begin
            val := instr.GetOperand(opIdx);
            if (val is TIRConstant) and (TIRConstant(val).Type_.Kind = fxb.ir.types.tkString) then
              GetStringLabel(TIRConstant(val).StrVal); // Register in string pool
          end;
        end;
      end;
    end;
    // Also scan globals
    for fnIdx := 0 to IR.Globals.Count - 1 do
    begin
      val := TIRValue(IR.Globals[fnIdx]);
      if (val is TIRConstant) and (TIRConstant(val).Type_.Kind = fxb.ir.types.tkString) then
        GetStringLabel(TIRConstant(val).StrVal);
    end;

    GenerateAllFunctions(IR);
    EmitStringPool;
    EmitRealPool;

    FASM.SaveToFile(OutputFile);
    FLastASM := FASM.Text;
    Result := Length(FErrors) = 0;
  finally
    FASM.Free;
    FLocalOffsets.Free;
    FStringPool.Free;
    FRealPool.Free;
  end;
end;

procedure TFXBBackend.GenerateAllFunctions(const IR: TIRModule);
var
  fn: TIRFunction;
  i: Integer;
begin
  // Generate startup code that captures argv/argc and calls Main
  if IsWindows then
  begin
    // Windows: entry is `main`, linked via the MinGW CRT (msvcrt). The CRT sets up
    // the process and calls our `main(int argc, char** argv)`. We stash argc/argv in
    // globals, call Main, and return (msvcrt performs the exit).
    EmitDirective('.globl main');
    EmitDirective('.type main, @function');
    EmitLabel('main');
    Emit(Format('push%s %s', [Copy(MovOp, 4, 3), BPReg]));
    Emit(Format('%s %s, %s', [MovOp, SPReg, BPReg]));
    if IsX86_64 then
    begin
      // MS x64 ABI: argc in %rcx, argv in %rdx.
      Emit(Format('movq %%rcx, %s', [RIP('__fx_argc_g')]));
      Emit(Format('movq %%rdx, %s', [RIP('__fx_argv_g')]));
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');            // 16-byte align before call
      Emit(Format('movq %s, %%rcx', [RIP('__fx_argc_g')]));  // argc -> 1st Main param (MS ABI)
      Emit(Format('movq %s, %%rdx', [RIP('__fx_argv_g')]));  // argv -> 2nd Main param (MS ABI)
      EmitCall('Main');
    end
    else
    begin
      // cdecl: argc at [ebp+8], argv at [ebp+12] (after our pushl %ebp).
      Emit(Format('movl 8(%s), %%eax', [BPReg]));
      Emit(Format('movl %%eax, %s', [RIP('__fx_argc_g')]));
      Emit(Format('movl 12(%s), %%eax', [BPReg]));
      Emit(Format('movl %%eax, %s', [RIP('__fx_argv_g')]));
      // Align the stack to 16 bytes before the call WITHOUT clobbering %ebp's frame:
      // after pushl %ebp, %esp is 16k-8; subl $8 makes it 16k-16 (aligned). The CRT
      // must `ret` from main, so we must not `andl` %esp (that corrupts the return).
      Emit('subl $8, %esp');
      Emit(Format('pushl %s', [RIP('__fx_argv_g')]));
      Emit(Format('pushl %s', [RIP('__fx_argc_g')]));
      EmitCall('Main');
      Emit('addl $16, %esp');   // pop args (8) + undo subl $8 (8)
    end;
    Emit(Format('pop%s %s', [Copy(MovOp, 4, 3), BPReg]));
    Emit('ret');
    EmitDirective('.size main, .-main');
    Emit('');
  end
  else
  begin
  EmitDirective('.globl _start');
  EmitDirective('.type _start, @function');
  EmitLabel('_start');

  if IsX86_64 then
  begin
    Emit('movq (%rsp), %rax');             // argc (top of stack at entry)
    Emit(Format('movq %%rax, %s', [RIP('__fx_argc_g')]));  // save argc for ArgC()/ArgV()/Command()
    Emit('leaq 8(%rsp), %rax');            // argv
    Emit(Format('movq %%rax, %s', [RIP('__fx_argv_g')]));
    // Align the stack to 16 bytes BEFORE building any frame. The x86_64
    // System V ABI requires %rsp % 16 == 0 at every call site; without this,
    // library calls (e.g. sqlite3_open) fault inside SSE code paths.
    Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
    Emit('pushq %rbp');
    Emit('movq %rsp, %rbp');
    Emit('subq $8, %rsp');  // Align stack to 16 bytes before call
    Emit(Format('movq %s, %%rdi', [RIP('__fx_argc_g')]));  // argc -> first Main param
    Emit(Format('movq %s, %%rsi', [RIP('__fx_argv_g')]));  // argv -> second Main param
    EmitCall('Main');
    Emit('movq %rax, %rbx');     // Preserve exit code (rbx is callee-saved)
    Emit('xorq %rdi, %rdi');     // fflush(NULL): flush all stdio buffers
    EmitCall('fflush');
    Emit('addq $8, %rsp');       // Restore stack
    // Close the SQLite connection if the DB runtime was linked in (no-op when nil).
    if (FDBDriver = 'sqlite') or (FDBConnection <> '') then
    begin
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align before the runtime call
      EmitCall('fxb_sqlite_close');
    end;
    Emit('movq %rbx, %rdi');
    Emit('movq $60, %rax');
    Emit('syscall');
  end
  else
  begin
    // x86_32: argc at [esp]; argv at [esp+4]. cdecl: push argv, push argc, call Main.
    Emit('movl (%esp), %eax');                     // argc
    Emit(Format('movl %%eax, %s', [RIP('__fx_argc_g')]));
    Emit('leal 4(%esp), %eax');                    // argv
    Emit(Format('movl %%eax, %s', [RIP('__fx_argv_g')]));
    Emit('pushl %ebp');
    Emit('movl %esp, %ebp');
    Emit('pushl %ebx');                            // callee-saved, holds exit code
    Emit(Format('pushl %s', [RIP('__fx_argv_g')]));   // argv -> 2nd Main param
    Emit(Format('pushl %s', [RIP('__fx_argc_g')]));   // argc -> 1st Main param
    Emit('andl $0xFFFFFFF0, %esp');                   // align stack to 16 before call
    EmitCall('Main');
    Emit('movl %eax, %ebx');                       // preserve exit code
    Emit('movl $0, %eax');                        // fflush(NULL)
    Emit('pushl %eax');
    EmitCall('fflush');
    Emit('addl $4, %esp');
    if (FDBDriver = 'sqlite') or (FDBConnection <> '') then
    begin
      Emit('call fxb_sqlite_close');
    end;
    Emit('movl %ebx, %eax');                      // exit code
    Emit('movl $1, %eax');                        // __NR_exit
    Emit('int $0x80');
  end;
  EmitDirective('.size _start, .-_start');
  Emit('');
  end;

  // Generate user functions
  for i := 0 to IR.Functions.Count - 1 do
  begin
    fn := TIRFunction(IR.Functions[i]);
    GenerateFunction(fn);
  end;

  EmitRuntimeHelpers;
  EmitDBRuntime;
  EmitRuntimeData;
end;

function TFXBBackend.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;


{$I 'fxb.backend.runtime.inc'}
{$I 'fxb.backend.db.inc'}
end.