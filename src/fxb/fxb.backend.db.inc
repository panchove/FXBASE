// fxb.backend.db.inc -- SQLite DB runtime emission + DB instruction lowering.
// Included into fxb.backend.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXBBackend; behaviour unchanged.

procedure TFXBBackend.GenDBOp(Instr: TIRInstruction);
  function ConstToSQL(v: TIRValue): string;
  var c: TIRConstant; s: string;
  begin
    if v is TIRConstant then
    begin
      c := TIRConstant(v);
      case c.Type_.Kind of
        fxb.ir.types.tkString:
          begin
            s := c.StrVal;
            s := StringReplace(s, '''', '''''', [rfReplaceAll]);
            Result := '''' + s + '''';
          end;
        fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64:
          Result := FloatToStr(c.RealVal);
        fxb.ir.types.tkBool:
          if c.BoolVal then Result := '1' else Result := '0';
        else
          Result := IntToStr(c.IntVal);
      end;
    end
    else
      Result := 'NULL';
  end;
  procedure EmitDBCall(const Sql: string; const Fn: string);
  var argReg: string;
  begin
    if IsX86_64 then
    begin
      if IsWindows then argReg := '%rcx' else argReg := '%rdi';
      Emit(Format('leaq %s, %s', [RIP(GetStringLabel(Sql)), argReg]));
      EmitCall(Fn);
    end
    else
    begin
      Emit(Format('movl %s, %%eax', [RIP(GetStringLabel(Sql))]));
      Emit('pushl %eax');
      EmitCall(Fn);
      Emit('addl $4, %esp');
    end;
  end;
  // SQLite bind kind byte stored before each value in fxb_db_args:
  // 0 = text (nul-terminated), 1 = int64, 2 = double.
  function DBKindOf(Val: TIRValue): Byte;
  begin
    case Val.Type_.Kind of
      fxb.ir.types.tkString: Result := 0;
      fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64: Result := 2;
      else Result := 1;
    end;
  end;
  // Load one runtime value into fxb_db_args slot SlotIdx (16 bytes: kind + value).
  procedure EmitBindSlot(Val: TIRValue; SlotIdx: Integer);
  var
    off: Integer;
    inst: TIRInstruction;
  begin
    off := SlotIdx * 16;
    Emit(Format('%s $%d, %d(%%r10)', [MovOp, DBKindOf(Val), off]));
    if DBKindOf(Val) = 2 then
    begin
      LoadFloatOperand(Val, '%xmm1');
      Emit(Format('movsd %%xmm1, %d(%%r10)', [off + 8]));
      Exit;
    end;
    if Val is TIRConstant then
    begin
      case Val.Type_.Kind of
        fxb.ir.types.tkString, fxb.ir.types.tkBool,
        fxb.ir.types.tkInt8, fxb.ir.types.tkInt16, fxb.ir.types.tkInt32, fxb.ir.types.tkInt64,
        fxb.ir.types.tkUInt8, fxb.ir.types.tkUInt16, fxb.ir.types.tkUInt32, fxb.ir.types.tkUInt64:
          GetOperandReg(Val, '%rsi');
        else
          Emit(Format('xor%s %s, %s', [Copy(MovOp, 4, 3), '%rsi', '%rsi']));
      end;
      Emit(Format('%s %s, %d(%%r10)', [MovOp, '%rsi', off + 8]));
    end
    else if Val is TIRArgument then
      Emit(Format('%s %s, %d(%%r10)', [MovOp, GetOperandReg(Val, '%rsi'), off + 8]))
    else if Val is TIRLocal then
    begin
      Emit(Format('%s %s, %s', [MovOp, GetOperandMemRef(Val, '%rsi'), '%rsi']));
      Emit(Format('%s %s, %d(%%r10)', [MovOp, '%rsi', off + 8]));
    end
    else if Val is TIRInstruction then
    begin
      inst := TIRInstruction(Val);
      if inst.Kind = fxb.ir.instr.ikLoad then
      begin
        Emit(Format('%s %s, %s', [MovOp, GetOperandMemRef(inst.GetOperand(0), '%rsi'), '%rsi']));
        Emit(Format('%s %s, %d(%%r10)', [MovOp, '%rsi', off + 8]));
      end
      else
        Emit(Format('%s %s, %d(%%r10)', [MovOp, '%rax', off + 8]));
    end
    else
    begin
      Emit(Format('xor%s %s, %s', [Copy(MovOp, 4, 3), '%rsi', '%rsi']));
      Emit(Format('%s %s, %d(%%r10)', [MovOp, '%rsi', off + 8]));
    end;
  end;
  procedure EmitParamCall(const Sql: string; NArgs: Integer);
  begin
    Emit(Format('leaq %s, %%rdi', [RIP(GetStringLabel(Sql))]));
    Emit(Format('movq $%d, %%rsi', [NArgs]));
    Emit(Format('leaq %s, %%rdx', [RIP('fxb_db_args')]));
    EmitCall('fxb_sqlite_execv');
  end;
var
  op, table, field, fields, sql, path, vals: string;
  i, nVals: Integer;
  hasCond: Boolean;
begin
  op := Instr.Metadata.Values['op'];
  if op = 'use' then
  begin
    path := FDBConnection;
    if path = '' then path := '/tmp/fxbase.db';
    EmitDBCall(path, 'fxb_sqlite_open');
  end
  else if op = 'append' then
  begin
    table := Instr.Metadata.Values['table'];
    fields := Instr.Metadata.Values['fields'];
    // CREATE TABLE IF NOT EXISTS (idempotent schema inference from the columns).
    sql := 'CREATE TABLE IF NOT EXISTS ' + table + ' (' + fields + ')';
    EmitDBCall(sql, 'fxb_sqlite_exec');
    if IsX86_64 and (not IsWindows) then
    begin
      // Parameterized path: runtime (non-constant) values bind through
      // fxb_sqlite_execv. A trailing FOR/WHILE condition operand is not part
      // of the INSERT column list and is ignored (xBASE APPEND has no scope).
      nVals := Instr.OperandCount;
      if (Instr.Metadata.Values['scope_for'] = '1') or
         (Instr.Metadata.Values['scope_while'] = '1') then
        Dec(nVals);
      vals := '';
      for i := 1 to nVals do
      begin
        if i > 1 then vals := vals + ', ';
        vals := vals + '?' + IntToStr(i);
      end;
      sql := 'INSERT INTO ' + table + ' (' + fields + ') VALUES (' + vals + ')';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_db_args')]));
      for i := 0 to nVals - 1 do
        EmitBindSlot(Instr.GetOperand(i), i);
      EmitParamCall(sql, nVals);
    end
    else
    begin
      // Fallback (x86_32 / Windows): compile-time SQL, runtime values become NULL.
      vals := '';
      for i := 0 to Instr.OperandCount - 1 do
      begin
        if i > 0 then vals := vals + ', ';
        vals := vals + ConstToSQL(Instr.GetOperand(i));
      end;
      sql := 'INSERT INTO ' + table + ' (' + fields + ') VALUES (' + vals + ')';
      EmitDBCall(sql, 'fxb_sqlite_exec');
    end;
  end
  else if op = 'replace' then
  begin
    table := Instr.Metadata.Values['table'];
    field := Instr.Metadata.Values['field'];
    hasCond := (Instr.Metadata.Values['scope_for'] = '1') or
               (Instr.Metadata.Values['scope_while'] = '1');
    // If a FOR/WHILE condition is present, REPLACE applies to all matching rows.
    // Otherwise it updates only the last inserted row (legacy xBASE behaviour).
    if hasCond then
      sql := 'UPDATE ' + table + ' SET ' + field + ' = ?1 WHERE (?)'
    else
      sql := 'UPDATE ' + table + ' SET ' + field + ' = ?1' +
             ' WHERE rowid = (SELECT last_insert_rowid())';
    if IsX86_64 and (not IsWindows) then
    begin
      // Parameterized path; the value and any FOR/WHILE condition bind by index.
      nVals := 1;
      if hasCond then Inc(nVals);
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_db_args')]));
      EmitBindSlot(Instr.GetOperand(0), 0);
      if hasCond then
        EmitBindSlot(Instr.GetOperand(Instr.OperandCount - 1), 1);
      EmitParamCall(sql, nVals);
    end
    else
    begin
      // Fallback (x86_32 / Windows): compile-time SQL, runtime values become NULL.
      if hasCond then
        sql := 'UPDATE ' + table + ' SET ' + field + ' = ' + ConstToSQL(Instr.GetOperand(0)) +
               ' WHERE (' + ConstToSQL(Instr.GetOperand(Instr.OperandCount - 1)) + ')'
      else
        sql := 'UPDATE ' + table + ' SET ' + field + ' = ' + ConstToSQL(Instr.GetOperand(0)) +
               ' WHERE rowid = (SELECT last_insert_rowid())';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      EmitDBCall(sql, 'fxb_sqlite_exec');
    end;
  end
  else if (op = 'pack') or (op = 'zap') then
  begin
    // PACK/ZAP both clear the active table; SQLite has no deleted-flag or
    // TRUNCATE, so DELETE FROM keeps the schema. Scope clauses add WHERE/LIMIT.
    table := Instr.Metadata.Values['table'];
    hasCond := (Instr.Metadata.Values['scope_for'] = '1') or
               (Instr.Metadata.Values['scope_while'] = '1');
    if IsX86_64 and (not IsWindows) then
    begin
      // Parameterized path: bind runtime condition via fxb_sqlite_execv.
      nVals := 0;
      if hasCond then Inc(nVals);
      sql := 'DELETE FROM ' + table;
      if hasCond then sql := sql + ' WHERE (?)';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_db_args')]));
      if hasCond then
        EmitBindSlot(Instr.GetOperand(Instr.OperandCount - 1), 0);
      EmitParamCall(sql, nVals);
    end
    else
    begin
      // Fallback (x86_32 / Windows): compile-time SQL, runtime values become NULL.
      sql := 'DELETE FROM ' + table;
      if Instr.Metadata.Values['scope_for'] = '1' then
        sql := sql + ' WHERE (' + ConstToSQL(Instr.GetOperand(Instr.OperandCount - 1)) + ')'
      else if Instr.Metadata.Values['scope_while'] = '1' then
        sql := sql + ' WHERE (' + ConstToSQL(Instr.GetOperand(Instr.OperandCount - 1)) + ')';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      EmitDBCall(sql, 'fxb_sqlite_exec');
    end;
  end;
end;


procedure TFXBBackend.EmitDBRuntime;
begin
  if (FDBDriver <> 'sqlite') and (FDBConnection = '') then
    Exit;
  if IsWindows and (not IsX86_64) then
  begin
    // 32-bit COFF/PE: not emitting the SQLite runtime here (Fase 2.7 static link).
    Exit;
  end;

  // Global connection handle in .bss.
  EmitDirective('.section .bss');
  EmitDirective('.globl fxb_db_handle');
  EmitDirective('.type fxb_db_handle, @object');
  if IsX86_64 then EmitDirective('.size fxb_db_handle, 8')
  else EmitDirective('.size fxb_db_handle, 4');
  EmitLabel('fxb_db_handle');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');

  // Prepared-statement slot + shared bind-args buffer (16 slots * 16 bytes).
  EmitDirective('.type fxb_db_stmt, @object');
  if IsX86_64 then EmitDirective('.size fxb_db_stmt, 8')
  else EmitDirective('.size fxb_db_stmt, 4');
  EmitLabel('fxb_db_stmt');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');

  EmitDirective('.type fxb_db_args, @object');
  EmitDirective('.size fxb_db_args, 256');
  EmitLabel('fxb_db_args');
  if IsX86_64 then EmitDirective('.skip 256') else EmitDirective('.skip 128');

  EmitDirective('.section .text');

  // fxb_sqlite_open(path): sqlite3_open(path, &handle)
  EmitDirective('.globl fxb_sqlite_open');
  EmitDirective('.type fxb_sqlite_open, @function');
  EmitLabel('fxb_sqlite_open');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('leaq fxb_db_handle(%rip), %rdx');   // 2nd arg: &handle
      Emit('call sqlite3_open');                 // path in %rcx (1st)
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align stack for the sqlite3 call
      Emit('leaq fxb_db_handle(%rip), %rsi');    // 2nd arg: &handle
      Emit('call sqlite3_open');                 // path in %rdi (1st)
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');                  // path (cdecl 1st arg)
    Emit('pushl %eax');
    Emit('leal fxb_db_handle, %eax');
    Emit('pushl %eax');                          // &handle
    Emit('call sqlite3_open');
    Emit('addl $8, %esp');
  end;
  if IsX86_64 then
  begin
    Emit('movq %rbp, %rsp');
    Emit('popq %rbp');
  end
  else
  begin
    Emit('movl %ebp, %esp');
    Emit('popl %ebp');
  end;
  Emit('ret');
  EmitDirective('.size fxb_sqlite_open, .-fxb_sqlite_open');
  Emit('');

  // fxb_sqlite_exec(sql): sqlite3_exec(handle, sql, 0, 0, 0)
  EmitDirective('.globl fxb_sqlite_exec');
  EmitDirective('.type fxb_sqlite_exec, @function');
  EmitLabel('fxb_sqlite_exec');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('movq %rcx, %rdx');                   // sql (was 1st) -> 2nd arg
      Emit('movq fxb_db_handle(%rip), %rcx');    // db -> 1st arg
      Emit('xorl %r8d, %r8d');                   // callback = 0
      Emit('xorl %r9d, %r9d');                   // arg = 0
      Emit('subq $40, %rsp');                    // shadow + 5th arg (errmsg)
      Emit('movq $0, 32(%rsp)');
      Emit('call sqlite3_exec');
      Emit('addq $40, %rsp');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align stack for the sqlite3 call
      Emit('movq %rdi, %rsi');                   // sql (was 1st) -> 2nd arg
      Emit('movq fxb_db_handle(%rip), %rdi');    // db -> 1st arg
      Emit('xorl %edx, %edx');                   // callback = 0
      Emit('xorl %ecx, %ecx');                   // arg = 0
      Emit('xorl %r8d, %r8d');                   // errmsg = 0
      Emit('call sqlite3_exec');
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');                  // sql (cdecl 1st arg)
    Emit('pushl $0');                            // errmsg
    Emit('pushl $0');                            // arg
    Emit('pushl $0');                            // callback
    Emit('pushl %eax');                          // sql
    Emit('pushl fxb_db_handle');                 // db
    Emit('call sqlite3_exec');
    Emit('addl $20, %esp');
  end;
  if IsX86_64 then
  begin
    Emit('movq %rbp, %rsp');
    Emit('popq %rbp');
  end
  else
  begin
    Emit('movl %ebp, %esp');
    Emit('popl %ebp');
  end;
  Emit('ret');
  EmitDirective('.size fxb_sqlite_exec, .-fxb_sqlite_exec');
  Emit('');

  // fxb_sqlite_close(): sqlite3_close(handle)
  EmitDirective('.globl fxb_sqlite_close');
  EmitDirective('.type fxb_sqlite_close, @function');
  EmitLabel('fxb_sqlite_close');
  if IsX86_64 then
  begin
    if IsWindows then
      Emit('movq fxb_db_handle(%rip), %rcx')
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align stack for the sqlite3 call
      Emit('movq fxb_db_handle(%rip), %rdi');
    end;
    Emit('call sqlite3_close');
  end
  else
  begin
    Emit('pushl fxb_db_handle');
    Emit('call sqlite3_close');
    Emit('addl $4, %esp');
  end;
  if IsX86_64 then
  begin
    if not IsWindows then
    begin
      Emit('movq %rbp, %rsp');
      Emit('popq %rbp');
    end;
  end
  else
  begin
    Emit('movl %ebp, %esp');
    Emit('popl %ebp');
  end;
  Emit('ret');
  EmitDirective('.size fxb_sqlite_close, .-fxb_sqlite_close');
  Emit('');

  // fxb_sqlite_execv(sql, nargs, args): prepare a statement, bind each of the
  // nargs slots in args (16 bytes: kind byte + 8-byte value bits), step and
  // finalize. Kind: 0 = text (nul-terminated), 1 = int64, 2 = double.
  // SysV x86_64 only; other targets keep the compile-time-SQL path.
  if IsX86_64 and (not IsWindows) then
  begin
    EmitDirective('.globl fxb_sqlite_execv');
    EmitDirective('.type fxb_sqlite_execv, @function');
    EmitLabel('fxb_sqlite_execv');
    Emit('pushq %rbp');
    Emit('movq %rsp, %rbp');
    Emit('pushq %rbx');
    Emit('pushq %r12');
    Emit('pushq %r13');
    Emit('pushq %r14');
    Emit('pushq %r15');
    Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');  // align stack for the sqlite3 calls
    Emit('movq %rdi, %r12');                 // sql
    Emit('movq %rsi, %r13');                 // nargs
    Emit('movq %rdx, %r14');                 // args
    // sqlite3_prepare_v2(handle, sql, -1, &stmt, 0)
    Emit('movq fxb_db_handle(%rip), %rdi');
    Emit('movq %r12, %rsi');
    Emit('movl $-1, %edx');
    Emit('leaq fxb_db_stmt(%rip), %rcx');
    Emit('xorl %r8d, %r8d');
    Emit('call sqlite3_prepare_v2');
    Emit('testl %eax, %eax');
    Emit('jnz .Ldbv_done');
    Emit('xorl %ebx, %ebx');                 // i = 0
    EmitLabel('.Ldbv_loop');
    Emit('cmpq %r13, %rbx');
    Emit('jge .Ldbv_step');
    Emit('movq %rbx, %r15');
    Emit('imulq $16, %r15');                 // offset = i * 16
    Emit('movq fxb_db_stmt(%rip), %rdi');    // stmt
    Emit('leal 1(%rbx), %esi');              // bind index = i + 1
    Emit('movzbl (%r14,%r15), %eax');        // kind
    Emit('movq 8(%r14,%r15), %rdx');         // value bits
    Emit('cmpb $1, %al');
    Emit('je .Ldbv_int');
    Emit('cmpb $2, %al');
    Emit('je .Ldbv_dbl');
    // text: sqlite3_bind_text(stmt, idx, text, -1, SQLITE_TRANSIENT)
    Emit('movq %rdx, %rcx');
    Emit('movl $-1, %edx');                  // length = -1 (nul-terminated)
    Emit('movq $-1, %r8');                   // SQLITE_TRANSIENT destructor
    Emit('xchgq %rcx, %rdx');                // rdx = text, rcx = length
    Emit('call sqlite3_bind_text');
    Emit('jmp .Ldbv_next');
    EmitLabel('.Ldbv_int');
    Emit('call sqlite3_bind_int64');
    Emit('jmp .Ldbv_next');
    EmitLabel('.Ldbv_dbl');
    Emit('movq %rdx, %xmm0');
    Emit('call sqlite3_bind_double');
    EmitLabel('.Ldbv_next');
    Emit('incq %rbx');
    Emit('jmp .Ldbv_loop');
    EmitLabel('.Ldbv_step');
    Emit('movq fxb_db_stmt(%rip), %rdi');
    Emit('call sqlite3_step');
    Emit('movq fxb_db_stmt(%rip), %rdi');
    Emit('call sqlite3_finalize');
    EmitLabel('.Ldbv_done');
    Emit('leaq -40(%rbp), %rsp');  // saved r15 slot (5 regs pushed after rbp)
    Emit('popq %r15');
    Emit('popq %r14');
    Emit('popq %r13');
    Emit('popq %r12');
    Emit('popq %rbx');
    Emit('popq %rbp');
    Emit('ret');
    EmitDirective('.size fxb_sqlite_execv, .-fxb_sqlite_execv');
    Emit('');
  end;
end;

