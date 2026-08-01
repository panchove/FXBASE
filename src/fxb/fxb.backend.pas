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
    procedure GeneratePrologue(Func: TIRFunction);
    procedure GenerateEpilogue(Func: TIRFunction);
    procedure GenerateAllFunctions(const IR: TIRModule);
    procedure EmitRuntimeHelpers;
    procedure EmitRuntimeData;

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
    procedure GenPrint(Instr: TIRInstruction);

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
      Emit(Format('xor%s %s, %s', [Copy(MovOp, 1, 3), ScratchReg, ScratchReg]));
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

function TFXBBackend.GetStringLabel(const S: string): string;
var
  idx: Integer;
begin
  idx := FStringPool.IndexOf(S);
  if idx < 0 then
  begin
    idx := FStringPool.Add(S);
    Result := Format('.Lstr%d', [idx]);
  end
  else
    Result := Format('.Lstr%d', [idx]);
end;

procedure TFXBBackend.EmitStringPool;
var
  i: Integer;
  s: string;
begin
  if FStringPool.Count = 0 then Exit;
  if IsWindows then EmitDirective('.section .rdata') else EmitDirective('.section .rodata');
  for i := 0 to FStringPool.Count - 1 do
  begin
    s := FStringPool[i];
    s := StringReplace(s, '\', '\\', [rfReplaceAll]);
    s := StringReplace(s, '"', '\"', [rfReplaceAll]);
    s := StringReplace(s, #10, '\n', [rfReplaceAll]);
    s := StringReplace(s, #13, '\r', [rfReplaceAll]);
    EmitLabel(Format('.Lstr%d', [i]));
    Emit(Format('.string "%s"', [s]));
  end;
end;

function TFXBBackend.GetRealLabel(const V: Double): string;
var
  idx: Integer;
  s: string;
begin
  s := FloatToStr(V);
  idx := FRealPool.IndexOf(s);
  if idx < 0 then
    idx := FRealPool.Add(s);
  Result := Format('.Lreal%d', [idx]);
end;

procedure TFXBBackend.EmitRealPool;
var
  i: Integer;
begin
  if FRealPool.Count = 0 then Exit;
  if IsWindows then EmitDirective('.section .rdata') else EmitDirective('.section .rodata');
  for i := 0 to FRealPool.Count - 1 do
  begin
    EmitLabel(Format('.Lreal%d', [i]));
    Emit(Format('.double %s', [FRealPool[i]]));
  end;
end;

procedure TFXBBackend.LoadPrintArgFloat(Val: TIRValue);
var
  c: TIRConstant;
begin
  if Val is TIRConstant then
  begin
    c := TIRConstant(Val);
    Emit(Format('movsd %s, %%xmm0', [RIP(GetRealLabel(c.RealVal))]));
  end
  else if Val is TIRLocal then
    Emit(Format('movsd %s, %%xmm0', [GetOperandMemRef(Val, '%xmm0')]))
  else if Val is TIRArgument then
    // x86_32 cdecl passes float args on the stack, same slot as integer args
    Emit(Format('movsd %s, %%xmm0', [GetOperandReg(Val, '%xmm0')]))
  else
    Emit('xorps %xmm0, %xmm0');
  // MS x64 ABI for varargs: the floating-point argument must also be present in the
  // corresponding integer register (here %rdx, since the format occupies %rcx).
  // xmm <-> GPR requires a stack bridge (movsd can't move between them directly).
  if IsWindows and IsX86_64 then
  begin
    Emit('subq $8, %rsp');
    Emit('movsd %xmm0, (%rsp)');
    Emit('movq (%rsp), %rdx');
    Emit('addq $8, %rsp');
  end;
end;

procedure TFXBBackend.LoadPrintArg(Val: TIRValue);
var
  c: TIRConstant;
  reg: string;
begin
  if IsX86_64 then
  begin
    // x86_64: 2nd printf arg. Linux (System V): %rsi. Windows (MS): %rdx.
    reg := PrintArgReg;
    if Val is TIRConstant then
    begin
      c := TIRConstant(Val);
      case c.Type_.Kind of
        fxb.ir.types.tkString:
          Emit(Format('leaq %s, %s', [RIP(GetStringLabel(c.StrVal)), reg]));
        fxb.ir.types.tkBool:
          if c.BoolVal then Emit(Format('movq $1, %s', [reg])) else Emit(Format('xorq %s, %s', [reg, reg]));
        fxb.ir.types.tkInt8, fxb.ir.types.tkInt16, fxb.ir.types.tkInt32, fxb.ir.types.tkInt64,
        fxb.ir.types.tkUInt8, fxb.ir.types.tkUInt16, fxb.ir.types.tkUInt32, fxb.ir.types.tkUInt64:
          Emit(Format('movq $%d, %s', [c.IntVal, reg]));
        else
          Emit(Format('xorq %s, %s', [reg, reg]));
      end;
    end
    else if Val is TIRArgument then
    begin
      case TIRArgument(Val).Index of
        0: Emit(Format('movq %%rdi, %s', [reg]));
        1: Emit(Format('movq %%rsi, %s', [reg]));
        2: Emit(Format('movq %%rdx, %s', [reg]));
        3: Emit(Format('movq %%rcx, %s', [reg]));
        4: Emit(Format('movq %%r8, %s', [reg]));
        5: Emit(Format('movq %%r9, %s', [reg]));
        else Emit(Format('xorq %s, %s', [reg, reg]));
      end;
    end
    else if Val is TIRLocal then
      Emit(Format('movq %s, %s', [GetOperandMemRef(Val, 'rsi'), reg]))
    else
      Emit(Format('movq %%rax, %s', [reg]));
  end
  else
  begin
    // x86_32 cdecl: print arg in %esi (loaded from stack).
    if Val is TIRConstant then
    begin
      c := TIRConstant(Val);
      case c.Type_.Kind of
        fxb.ir.types.tkString:
          Emit(Format('movl %s, %%esi', [RIP(GetStringLabel(c.StrVal))]));
        fxb.ir.types.tkBool:
          if c.BoolVal then Emit('movl $1, %esi') else Emit('xorl %esi, %esi');
        fxb.ir.types.tkInt8, fxb.ir.types.tkInt16, fxb.ir.types.tkInt32, fxb.ir.types.tkInt64,
        fxb.ir.types.tkUInt8, fxb.ir.types.tkUInt16, fxb.ir.types.tkUInt32, fxb.ir.types.tkUInt64:
          Emit(Format('movl $%d, %%esi', [c.IntVal]));
        else
          Emit('xorl %esi, %esi');
      end;
    end
    else
    begin
      // Arguments and locals live on the stack; reuse GetOperandReg.
      if Val is TIRArgument then
        reg := GetOperandReg(Val, '%esi')
      else if Val is TIRLocal then
        reg := GetOperandReg(Val, '%esi')
      else
        reg := GetOperandReg(Val, '%eax');
    end;
  end;
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
  stackSize := Length(Func.Locals) * WordSize;
  if IsX86_64 then
    stackSize := (stackSize + 15) and not 15  // 16-byte align for x86_64 ABI
  else
    stackSize := (stackSize + 3) and not 3;   // 4-byte align for x86_32

  Emit(Format('push%s %s', [Copy(MovOp, 4, 3), BPReg]));
  Emit(Format('%s %s, %s', [MovOp, SPReg, BPReg]));
  if not IsX86_64 then
    Emit('andl $0xFFFFFFF0, %esp');   // align stack to 16 for cdecl varargs (printf)
  if stackSize > 0 then
    Emit(Format('%s $%d, %s', [SubOp, stackSize, SPReg]));
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

  if left.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64] then
  begin
    // SSE2 floating point (operate in XMM registers)
    leftReg := LoadFloatOperand(left, '%xmm0');
    rightReg := LoadFloatOperand(right, '%xmm1');
    case Instr.Kind of
      fxb.ir.instr.ikAdd: Emit('addsd %xmm1, %xmm0');
      fxb.ir.instr.ikSub: Emit('subsd %xmm1, %xmm0');
      fxb.ir.instr.ikMul: Emit('mulsd %xmm1, %xmm0');
      fxb.ir.instr.ikDiv: Emit('divsd %xmm1, %xmm0');
      // Shift/bitwise ops are undefined for floats; report and skip.
      else
      begin
        ReportError('Operador no válido para flotantes: ' + InstrKindToStr(Instr.Kind));
        Exit;
      end;
    end;
    // Materialize result into the destination slot (the instruction itself acts
    // as the defining value). Subsequent users reload it via LoadFloatOperand.
    Emit(Format('movsd %%xmm0, %s', [GetOperandMemRef(Instr, '%xmm0')]));
    Exit;
  end;

  leftReg := GetOperandReg(left, AXReg);
  rightReg := GetOperandReg(right, CXReg);
  destReg := 'rax';

  begin
    // Integer operations - result in rax/eax
    if leftReg <> AXReg then
      Emit(Format('%s %s, %s', [MovOp, leftReg, AXReg]));

    case Instr.Kind of
      fxb.ir.instr.ikAdd: Emit(Format('%s %s, %s', [AddOp, rightReg, AXReg]));
      fxb.ir.instr.ikSub: Emit(Format('%s %s, %s', [SubOp, rightReg, AXReg]));
      fxb.ir.instr.ikMul: Emit(Format('%s %s, %s', [MulOp, rightReg, AXReg]));
      fxb.ir.instr.ikDiv:
        begin
          if IsX86_64 then Emit('cqo') else Emit('cdq');
          Emit(Format('%s %s', [DivOp, rightReg]));
        end;
      fxb.ir.instr.ikRem:
        begin
          if IsX86_64 then Emit('cqo') else Emit('cdq');
          Emit(Format('%s %s', [RemOp, rightReg]));
          Emit(Format('%s %s, %s', [MovOp, DXReg, AXReg]));
        end;
      fxb.ir.instr.ikShl: Emit(Format('%s %%cl, %s', [ShlOp, AXReg]));
      fxb.ir.instr.ikShr: Emit(Format('%s %%cl, %s', [ShrOp, AXReg]));
      fxb.ir.instr.ikAnd: Emit(Format('%s %s, %s', [AndOp, rightReg, AXReg]));
      fxb.ir.instr.ikOr:  Emit(Format('%s %s, %s', [OrOp, rightReg, AXReg]));
      fxb.ir.instr.ikXor: Emit(Format('%s %s, %s', [XorOp, rightReg, AXReg]));
    end;
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

procedure TFXBBackend.GenCall(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  nArgs: Integer;
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));
  nArgs := Instr.OperandCount - 1;

  if IsX86_64 then
  begin
    // x86_64: first 6 args in rdi,rsi,rdx,rcx,r8,r9; rest on stack.
    for i := 1 to nArgs do
    begin
      if i - 1 <= 5 then
        GetOperandReg(Instr.GetOperand(i), (['%rdi','%rsi','%rdx','%rcx','%r8','%r9'])[i - 1])
      else
      begin
        GetOperandReg(Instr.GetOperand(i), '%rax');
        Emit('pushq %rax');
      end;
    end;
  end
  else
  begin
    // x86_32 cdecl: push args right-to-left (last arg pushed first).
    for i := nArgs downto 1 do
    begin
      GetOperandReg(Instr.GetOperand(i), '%eax');
      Emit('pushl %eax');
    end;
  end;

  Emit(Format('call %s', [fn.Name]));

  if IsX86_64 then
  begin
    if nArgs > 6 then
      Emit(Format('addq $%d, %%rsp', [(nArgs - 6) * 8]));
  end
  else
  begin
    if nArgs > 0 then
      Emit(Format('addl $%d, %%esp', [nArgs * 4])); // cdecl: caller cleans up
  end;
end;

procedure TFXBBackend.GenCallDirect(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  nArgs: Integer;
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));
  nArgs := Instr.OperandCount - 1;

  if IsX86_64 then
  begin
    for i := 1 to nArgs do
    begin
      if i - 1 <= 5 then
        GetOperandReg(Instr.GetOperand(i), (['%rdi','%rsi','%rdx','%rcx','%r8','%r9'])[i - 1])
      else
      begin
        GetOperandReg(Instr.GetOperand(i), '%rax');
        Emit('pushq %rax');
      end;
    end;
  end
  else
  begin
    for i := nArgs downto 1 do
    begin
      GetOperandReg(Instr.GetOperand(i), '%eax');
      Emit('pushl %eax');
    end;
  end;

  Emit(Format('call %s', [fn.Name]));

  if IsX86_64 then
  begin
    if nArgs > 6 then
      Emit(Format('addq $%d, %%rsp', [(nArgs - 6) * 8]));
  end
  else
  begin
    if nArgs > 0 then
      Emit(Format('addl $%d, %%esp', [nArgs * 4]));
  end;
end;

procedure TFXBBackend.GenICmp(Instr: TIRInstruction);
var
  left, right: TIRValue;
  pred: string;
  isFloat: Boolean;
begin
  if Instr.OperandCount < 2 then Exit;
  left := Instr.GetOperand(0);
  right := Instr.GetOperand(1);

  isFloat := (left.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64]) or
             (right.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64]);

  if isFloat then
  begin
    // SSE2 ordered compare: xmm0 = left, xmm1 = right, then test flags.
    LoadFloatOperand(left, '%xmm0');
    LoadFloatOperand(right, '%xmm1');
    Emit('ucomisd %xmm1, %xmm0');
    pred := Instr.Metadata.Values['pred'];
    if pred = '' then pred := 'eq';
    case pred of
      'eq': Emit('sete %al');   // ZF=1
      'ne': Emit('setne %al');  // ZF=0
      'lt': Emit('setb %al');   // CF=1  (left < right)
      'gt': Emit('seta %al');   // CF=0 and ZF=0 (left > right)
      'le': Emit('setbe %al');  // CF=1 or ZF=1
      'ge': Emit('setae %al');  // CF=0
      else Emit('sete %al');
    end;
    Emit('movzbq %al, %rax');
    Exit;
  end;

  Emit(Format('%s %s, %s', [CmpOp, GetOperandReg(right, AXReg), GetOperandReg(left, CXReg)]));
  pred := Instr.Metadata.Values['pred'];
  if pred = '' then pred := 'eq';
  case pred of
    'eq': Emit('sete %al');
    'ne': Emit('setne %al');
    'lt': Emit('setl %al');
    'gt': Emit('setg %al');
    'le': Emit('setle %al');
    'ge': Emit('setge %al');
  end;
  if IsX86_64 then
    Emit('movzbq %al, %rax')
  else
    Emit('movzbl %al, %eax');
end;

procedure TFXBBackend.GenPrint(Instr: TIRInstruction);
var
  i: Integer;
  val: TIRValue;
  newline: Boolean;
  fmtLabel: string;
  slotBytes: Integer;
  FmtReg, ArgReg: string;
  // 32-bit helpers: format-label resolver (cdecl)
  function FmtLabelFor(Kind: TIRTypeKind): string;
  begin
    if Kind = fxb.ir.types.tkString then Result := '%s'
    else if Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64] then Result := '%g'
    else if Kind = fxb.ir.types.tkBool then Result := '%d'
    else Result := '%lld';
  end;
begin
  newline := Instr.Metadata.Values['newline'] = '1';

  if IsX86_64 then
  begin
    // x86_64 calling convention for printf:
    //  - Linux (System V): format in %rdi, args in %rsi/%xmm0, varargs count in %al.
    //  - Windows (MS): format in %rcx, args in %rdx/%xmm0, no %al; 32-byte shadow space.
    if IsWindows then
    begin
      FmtReg := '%rcx';
      ArgReg := '%rdx';
    end
    else
    begin
      FmtReg := '%rdi';
      ArgReg := '%rsi';
    end;
    for i := 0 to Instr.OperandCount - 1 do
    begin
      val := Instr.GetOperand(i);
      case val.Type_.Kind of
        fxb.ir.types.tkString:
        begin
          fmtLabel := GetStringLabel('%s');
          Emit(Format('leaq %s(%%rip), %s', [fmtLabel, FmtReg]));
          LoadPrintArg(val);
          if not IsWindows then Emit('xorl %eax, %eax');
        end;
        fxb.ir.types.tkBool:
        begin
          fmtLabel := GetStringLabel('%d');
          Emit(Format('leaq %s(%%rip), %s', [fmtLabel, FmtReg]));
          LoadPrintArg(val);
          if not IsWindows then Emit('xorl %eax, %eax');
        end;
        fxb.ir.types.tkInt8, fxb.ir.types.tkInt16, fxb.ir.types.tkInt32, fxb.ir.types.tkInt64,
        fxb.ir.types.tkUInt8, fxb.ir.types.tkUInt16, fxb.ir.types.tkUInt32, fxb.ir.types.tkUInt64:
        begin
          fmtLabel := GetStringLabel('%lld');
          Emit(Format('leaq %s(%%rip), %s', [fmtLabel, FmtReg]));
          LoadPrintArg(val);
          if not IsWindows then Emit('xorl %eax, %eax');
        end;
        fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64:
        begin
          fmtLabel := GetStringLabel('%g');
          Emit(Format('leaq %s(%%rip), %s', [fmtLabel, FmtReg]));
          LoadPrintArgFloat(val);
          Emit('movl $1, %eax');   // 1 vector (XMM) arg for varargs (both ABIs)
        end;
        else
        begin
          fmtLabel := GetStringLabel('%s');
          Emit(Format('leaq %s(%%rip), %s', [fmtLabel, FmtReg]));
          LoadPrintArg(val);
          if not IsWindows then Emit('xorl %eax, %eax');
        end;
      end;
    end;
    if IsWindows then
    begin
      Emit('subq $32, %rsp');   // shadow space for MS x64 ABI
      EmitCall('printf');
      Emit('addq $32, %rsp');
    end
    else
      Emit('callq printf');
    if newline then
    begin
      fmtLabel := GetStringLabel('%s' + #10);
      Emit(Format('leaq %s(%%rip), %s', [fmtLabel, FmtReg]));
      Emit(Format('leaq %s(%%rip), %s', [GetStringLabel(''), ArgReg]));
      if not IsWindows then Emit('xorl %eax, %eax');
      if IsWindows then
      begin
        Emit('subq $32, %rsp');
        EmitCall('printf');
        Emit('addq $32, %rsp');
      end
      else
        Emit('callq printf');
    end;
  end
  else
  begin
    // x86_32 cdecl: glibc i386 varargs (printf) require the stack to be
    // 16-byte aligned at the call and arguments naturally aligned. We reserve a
    // 16-byte-multiple slot with subl and store args with movl/movsd (like gcc),
    // avoiding push which would break alignment. Format string goes at [esp].
    slotBytes := ((Instr.OperandCount + 1) * 4 + 15) and not 15;
    Emit(Format('subl $%d, %%esp', [slotBytes]));
    for i := 0 to Instr.OperandCount - 1 do
    begin
      val := Instr.GetOperand(i);
      if i = 0 then
        fmtLabel := FmtLabelFor(val.Type_.Kind)
      else
        fmtLabel := '%s';
      // Each operand: write its value at [esp + 4*(i+1)] (slot 0 = format).
      case val.Type_.Kind of
        fxb.ir.types.tkString:
          Emit(Format('movl $%s, %d(%%esp)', [GetStringLabel(TIRConstant(val).StrVal), 4 * (i + 1)]));
        fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64:
          begin
            LoadPrintArgFloat(val);
            // 8-byte value at the same slot as an integer arg (cdecl packs it
            // contiguously at [esp + 4*(i+1)]); esp is 16-aligned so this is 4-aligned.
            Emit(Format('movsd %%xmm0, %d(%%esp)', [4 * (i + 1)]));
          end;
        else
          begin
            GetOperandReg(val, '%eax');
            Emit(Format('movl %%eax, %d(%%esp)', [4 * (i + 1)]));
          end;
      end;
    end;
    if Instr.OperandCount > 0 then
      Emit(Format('movl $%s, (%%esp)', [GetStringLabel(fmtLabel)]));
    EmitCall('printf');
    // Clean up the reserved slot.
    Emit(Format('addl $%d, %%esp', [slotBytes]));
    if newline then
    begin
      Emit('subl $16, %esp');
      Emit(Format('movl $%s, (%%esp)', [GetStringLabel('%s' + #10)]));
      Emit(Format('movl $%s, 4(%%esp)', [GetStringLabel('')]));
      EmitCall('printf');
      Emit('addl $16, %esp');
    end;
  end;
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
  FStringPool := TStringList.Create;
  FRealPool := TStringList.Create;

  try
    EmitDirective('.file "fxbase_output"');
    if IsX86_64 then
      EmitDirective('.code64')
    else
      EmitDirective('.code32');
    EmitDirective('.text');

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
      Emit('andl $0xFFFFFFF0, %esp');
      Emit(Format('pushl %s', [RIP('__fx_argv_g')]));
      Emit(Format('pushl %s', [RIP('__fx_argc_g')]));
      EmitCall('Main');
      Emit('addl $8, %esp');
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
  EmitRuntimeData;
end;

procedure TFXBBackend.EmitRuntimeHelpers;
begin
  // ArgC(): return saved argc
  EmitDirective('.globl __fx_argc');
  EmitDirective('.type __fx_argc, @function');
  EmitLabel('__fx_argc');
  if IsX86_64 then
  begin
    Emit(Format('movq %s, %%rax', [RIP('__fx_argc_g')]));
    Emit('ret');
  end
  else
  begin
    Emit(Format('movl %s, %%eax', [RIP('__fx_argc_g')]));
    Emit('ret');
  end;
  EmitDirective('.size __fx_argc, .-__fx_argc');
  Emit('');

  // ArgV(n): return argv[n] (n in %rdi/%eax)
  EmitDirective('.globl __fx_argv');
  EmitDirective('.type __fx_argv, @function');
  EmitLabel('__fx_argv');
  if IsX86_64 then
  begin
    Emit(Format('movq %s, %%rax', [RIP('__fx_argv_g')]));
    Emit('movq (%rax, %rdi, 8), %rax');
  end
  else
  begin
    // index in [ebp+8] (first cdecl argument); element size 4 bytes
    Emit('movl 8(%ebp), %eax');
    Emit(Format('movl %s, %%edx', [RIP('__fx_argv_g')]));
    Emit('movl (%edx, %eax, 4), %eax');
  end;
  Emit('ret');
  EmitDirective('.size __fx_argv, .-__fx_argv');
  Emit('');

  // Command(): build full command line "argv[0] argv[1] ..." into a buffer
  EmitDirective('.globl __fx_command');
  EmitDirective('.type __fx_command, @function');
  EmitLabel('__fx_command');
  if IsX86_64 then
  begin
    Emit('pushq %rbp');
    Emit('movq %rsp, %rbp');
    Emit('pushq %rbx');
    Emit('pushq %r12');
    Emit(Format('leaq %s, %%rdi', [RIP('__fx_cmd_buf')]));   // dest buffer
    Emit(Format('movq %s, %%rsi', [RIP('__fx_argv_g')]));    // argv
    Emit(Format('movq %s, %%rcx', [RIP('__fx_argc_g')]));    // argc
    Emit('xorl %edx, %edx');                  // i = 0
    Emit('.Lcmd_loop:');
    Emit('cmpl %edx, %ecx');
    Emit('jle .Lcmd_done');
    Emit('testl %edx, %edx');
    Emit('je .Lcmd_copy');
    Emit('movb $32, (%rdi)');                 // space separator
    Emit('incq %rdi');
    Emit('.Lcmd_copy:');
    Emit('movq (%rsi, %rdx, 8), %r12');       // argv[i]
    Emit('.Lcmd_copyloop:');
    Emit('movb (%r12), %al');
    Emit('testb %al, %al');
    Emit('je .Lcmd_next');
    Emit('movb %al, (%rdi)');
    Emit('incq %rdi');
    Emit('incq %r12');
    Emit('jmp .Lcmd_copyloop');
    Emit('.Lcmd_next:');
    Emit('incq %rdx');
    Emit('jmp .Lcmd_loop');
    Emit('.Lcmd_done:');
    Emit('movb $0, (%rdi)');                  // null-terminate
    Emit(Format('leaq %s, %%rax', [RIP('__fx_cmd_buf')]));
    Emit('popq %r12');
    Emit('popq %rbx');
    Emit('popq %rbp');
    Emit('ret');
  end
  else
  begin
    Emit('pushl %ebp');
    Emit('movl %esp, %ebp');
    Emit('pushl %ebx');
    Emit('pushl %ecx');
    Emit('pushl %edx');
    Emit(Format('leal %s, %%edi', [RIP('__fx_cmd_buf')]));   // dest buffer
    Emit(Format('movl %s, %%esi', [RIP('__fx_argv_g')]));    // argv
    Emit(Format('movl %s, %%ecx', [RIP('__fx_argc_g')]));    // argc
    Emit('xorl %edx, %edx');                  // i = 0
    Emit('.Lcmd_loop:');
    Emit('cmpl %edx, %ecx');
    Emit('jle .Lcmd_done');
    Emit('testl %edx, %edx');
    Emit('je .Lcmd_copy');
    Emit('movb $32, (%edi)');                 // space separator
    Emit('incl %edi');
    Emit('.Lcmd_copy:');
    Emit('movl (%esi, %edx, 4), %ebx');       // argv[i]
    Emit('.Lcmd_copyloop:');
    Emit('movb (%ebx), %al');
    Emit('testb %al, %al');
    Emit('je .Lcmd_next');
    Emit('movb %al, (%edi)');
    Emit('incl %edi');
    Emit('incl %ebx');
    Emit('jmp .Lcmd_copyloop');
    Emit('.Lcmd_next:');
    Emit('incl %edx');
    Emit('jmp .Lcmd_loop');
    Emit('.Lcmd_done:');
    Emit('movb $0, (%edi)');                  // null-terminate
    Emit(Format('leal %s, %%eax', [RIP('__fx_cmd_buf')]));
    Emit('popl %edx');
    Emit('popl %ecx');
    Emit('popl %ebx');
    Emit('popl %ebp');
    Emit('ret');
  end;
  EmitDirective('.size __fx_command, .-__fx_command');
end;

procedure TFXBBackend.EmitRuntimeData;
begin
  EmitDirective('.section .data');
  EmitDirective('.globl __fx_argc_g');
  EmitDirective('.type __fx_argc_g, @object');
  if IsX86_64 then EmitDirective('.size __fx_argc_g, 8')
  else EmitDirective('.size __fx_argc_g, 4');
  EmitLabel('__fx_argc_g');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');
  EmitDirective('.globl __fx_argv_g');
  EmitDirective('.type __fx_argv_g, @object');
  if IsX86_64 then EmitDirective('.size __fx_argv_g, 8')
  else EmitDirective('.size __fx_argv_g, 4');
  EmitLabel('__fx_argv_g');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');
  EmitDirective('.section .bss');
  EmitDirective('.globl __fx_cmd_buf');
  EmitDirective('.type __fx_cmd_buf, @object');
  EmitDirective('.size __fx_cmd_buf, 4096');
  EmitLabel('__fx_cmd_buf');
  EmitDirective('.zero 4096');
end;

function TFXBBackend.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

end.