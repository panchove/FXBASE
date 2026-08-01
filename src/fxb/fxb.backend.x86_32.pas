unit fxb.backend.x86_32;

{$mode objfpc}{$H+}

// R2 refactor: x86_32 (i386) codegen extracted from TFXBBackend.
// TFXBBackendX86_32 overrides the architecture-specific instruction generators
// with the x86_32 (cdecl / Linux ELF) variants. Behaviour is unchanged.
// (Windows PE32 codegen is deferred; x86_32 here assumes the SysV-i386 ABI.)

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
  TFXBBackendX86_32 = class(TFXBBackend)
  public
    procedure GeneratePrologue(Func: TIRFunction); override;
    procedure GenBinaryOp(Instr: TIRInstruction); override;
    procedure GenCall(Instr: TIRInstruction); override;
    procedure GenCallDirect(Instr: TIRInstruction); override;
    procedure GenICmp(Instr: TIRInstruction); override;
    procedure GenPrint(Instr: TIRInstruction); override;
  end;

implementation

{ TFXBBackendX86_32 }

procedure TFXBBackendX86_32.GeneratePrologue(Func: TIRFunction);
var
  stackSize: Integer;
begin
  stackSize := Length(Func.Locals) * WordSize;
  stackSize := (stackSize + 3) and not 3;   // 4-byte align for x86_32
  Emit(Format('push%s %s', [Copy(MovOp, 4, 3), BPReg]));
  Emit(Format('%s %s, %s', [MovOp, SPReg, BPReg]));
  Emit('andl $0xFFFFFFF0, %esp');   // align stack to 16 for cdecl varargs (printf)
  if stackSize > 0 then
    Emit(Format('%s $%d, %s', [SubOp, stackSize, SPReg]));
end;

procedure TFXBBackendX86_32.GenBinaryOp(Instr: TIRInstruction);
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
    // Integer operations - result in eax
    if leftReg <> AXReg then
      Emit(Format('%s %s, %s', [MovOp, leftReg, AXReg]));

    case Instr.Kind of
      fxb.ir.instr.ikAdd: Emit(Format('%s %s, %s', [AddOp, rightReg, AXReg]));
      fxb.ir.instr.ikSub: Emit(Format('%s %s, %s', [SubOp, rightReg, AXReg]));
      fxb.ir.instr.ikMul: Emit(Format('%s %s, %s', [MulOp, rightReg, AXReg]));
      fxb.ir.instr.ikDiv:
        begin
          Emit('cdq');
          Emit(Format('%s %s', [DivOp, rightReg]));
        end;
      fxb.ir.instr.ikRem:
        begin
          Emit('cdq');
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

procedure TFXBBackendX86_32.GenCall(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  nArgs: Integer;
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));
  nArgs := Instr.OperandCount - 1;

  // x86_32 cdecl: push args right-to-left (last arg pushed first).
  for i := nArgs downto 1 do
  begin
    GetOperandReg(Instr.GetOperand(i), '%eax');
    Emit('pushl %eax');
  end;

  Emit(Format('call %s', [fn.Name]));

  if nArgs > 0 then
    Emit(Format('addl $%d, %%esp', [nArgs * 4])); // cdecl: caller cleans up
end;

procedure TFXBBackendX86_32.GenCallDirect(Instr: TIRInstruction);
var
  fn: TIRFunction;
  i: Integer;
  nArgs: Integer;
begin
  if Instr.OperandCount < 1 then Exit;
  fn := TIRFunction(Instr.GetOperand(0));
  nArgs := Instr.OperandCount - 1;

  // x86_32 cdecl: push args right-to-left (last arg pushed first).
  for i := nArgs downto 1 do
  begin
    GetOperandReg(Instr.GetOperand(i), '%eax');
    Emit('pushl %eax');
  end;

  Emit(Format('call %s', [fn.Name]));

  if nArgs > 0 then
    Emit(Format('addl $%d, %%esp', [nArgs * 4])); // cdecl: caller cleans up
end;

procedure TFXBBackendX86_32.GenICmp(Instr: TIRInstruction);
var
  left, right: TIRValue;
  pred: string;
  isFloat: Boolean;
begin
  if Instr.OperandCount < 2 then Exit;
  left := Instr.GetOperand(0);
  right := Instr.GetOperand(1);

  isFloat := (left.Type_.Kind in [fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64]) or
             (right.Type_.Kind in [fxb.ir.types.tkFloat64, fxb.ir.types.tkFloat32]);

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
  Emit('movzbl %al, %eax');
end;

procedure TFXBBackendX86_32.GenPrint(Instr: TIRInstruction);
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
          // Enteros: el IR los representa como int64, asi que el formato es %lld
          // (8 bytes). Cargamos la parte baja en %eax y extendemos el signo a %edx,
          // luego empujamos los 8 bytes en la pila (parte alta + parte baja).
          GetOperandReg(val, '%eax');
          Emit('movl %eax, %edx');
          Emit('sarl $31, %edx');
          Emit(Format('movl %%eax, %d(%%esp)', [4 * (i + 1)]));
          Emit(Format('movl %%edx, %d(%%esp)', [4 * (i + 1) + 4]));
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

end.
