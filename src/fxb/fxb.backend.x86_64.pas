unit fxb.backend.x86_64;

{$mode objfpc}{$H+}

// R2 refactor: x86_64 codegen extracted from TFXBBackend.
// TFXBBackendX86_64 overrides the architecture-specific instruction generators
// with the x86_64 (System V / MS x64) variants. Behaviour is unchanged.

interface

uses
  SysUtils,
  Classes,
  Generics.Collections,
  fxb.ir,
  fxb.ir.types,
  fxb.ir.instr,
  fxb.errors,
  fxb.backend;

type
  TFXBBackendX86_64 = class(TFXBBackend)
  public
    procedure GeneratePrologue(Func: TIRFunction); override;
    procedure GenBinaryOp(Instr: TIRInstruction); override;
    procedure GenCall(Instr: TIRInstruction); override;
    procedure GenCallDirect(Instr: TIRInstruction); override;
    procedure GenICmp(Instr: TIRInstruction); override;
    procedure GenPrint(Instr: TIRInstruction); override;
  end;

implementation

{ TFXBBackendX86_64 }

procedure TFXBBackendX86_64.GeneratePrologue(Func: TIRFunction);
var
  stackSize: Integer;
begin
  stackSize := Length(Func.Locals) * WordSize;
  stackSize := (stackSize + 15) and not 15;  // 16-byte align for x86_64 ABI
  Emit(Format('push%s %s', [Copy(MovOp, 4, 3), BPReg]));
  Emit(Format('%s %s, %s', [MovOp, SPReg, BPReg]));
  // x86_64 SysV does not need the extra 16-byte esp alignment done in x86_32.
  if stackSize > 0 then
    Emit(Format('%s $%d, %s', [SubOp, stackSize, SPReg]));
end;

procedure TFXBBackendX86_64.GenBinaryOp(Instr: TIRInstruction);
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
  destReg := AXReg;

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
          Emit('cqo');
          Emit(Format('%s %s', [DivOp, rightReg]));
        end;
      fxb.ir.instr.ikRem:
        begin
          Emit('cqo');
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

procedure TFXBBackendX86_64.GenCall(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  nArgs: Integer;
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));
  nArgs := Instr.OperandCount - 1;

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

  Emit(Format('call %s', [fn.Name]));

  if nArgs > 6 then
    Emit(Format('addq $%d, %%rsp', [(nArgs - 6) * 8]));
end;

procedure TFXBBackendX86_64.GenCallDirect(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  nArgs: Integer;
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));
  nArgs := Instr.OperandCount - 1;

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

  Emit(Format('call %s', [fn.Name]));

  if nArgs > 6 then
    Emit(Format('addq $%d, %%rsp', [(nArgs - 6) * 8]));
end;

procedure TFXBBackendX86_64.GenICmp(Instr: TIRInstruction);
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
  Emit('movzbq %al, %rax');
end;

procedure TFXBBackendX86_64.GenPrint(Instr: TIRInstruction);
var
  i: Integer;
  val: TIRValue;
  newline: Boolean;
  fmtLabel: string;
  FmtReg, ArgReg: string;
begin
  newline := Instr.Metadata.Values['newline'] = '1';

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
  begin
    Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align stack for the printf call
    Emit('callq printf');
  end;
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
    begin
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align stack for the printf call
      Emit('callq printf');
    end;
  end;
end;

end.
