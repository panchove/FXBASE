// fxb.backend.runtime.inc -- runtime helpers + string/real pools.
// Included into fxb.backend.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXBBackend (fxb.backend.pas); behaviour unchanged.

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
  inst: TIRInstruction;
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
    else if Val is TIRInstruction then
    begin
      inst := TIRInstruction(Val);
      if inst.Kind = fxb.ir.instr.ikLoad then
      begin
        // Load instruction: the operand is the pointer, we need to load from it
        Emit(Format('movq %s, %s', [GetOperandMemRef(inst.GetOperand(0), 'rsi'), reg]))
      end
      else
        Emit(Format('movq %%rax, %s', [reg])); // fallback: assume value in RAX
    end
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
      else if Val is TIRInstruction then
      begin
        inst := TIRInstruction(Val);
        if inst.Kind = fxb.ir.instr.ikLoad then
          reg := GetOperandReg(inst.GetOperand(0), '%esi')
        else
          reg := GetOperandReg(Val, '%eax');
      end
      else
        reg := GetOperandReg(Val, '%eax');
    end;
  end;
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

// Fase 2: emit the SQLite runtime helpers directly into the generated assembly.
// These are plain C-callable functions (no Pascal RTL needed) that wrap the
// libsqlite3 entry points, keeping a single global connection handle. The
// generated code calls them via `call fxb_sqlite_open` / `call fxb_sqlite_exec`.

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

