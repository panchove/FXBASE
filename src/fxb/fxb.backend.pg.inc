// fxb.backend.pg.inc -- PostgreSQL DB runtime emission + DB instruction lowering for PostgreSQL.
// Included into fxb.backend.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXBBackend; behaviour unchanged.

procedure TFXBBackend.GenPGOp(Instr: TIRInstruction);
  function ConstToSQL(v: TIRValue): string;
  var c: TIRConstant; s: string;
  begin
    if v is TIRConstant then
    begin
      c := TIRConstant(v);
      if c.Type_.Kind = fxb.ir.types.tkString then
      begin
        s := c.StrVal;
        s := StringReplace(s, '''', '''''', [rfReplaceAll]);
        Result := '''' + s + '''';
      end
      else if (c.Type_.Kind = fxb.ir.types.tkFloat32) or (c.Type_.Kind = fxb.ir.types.tkFloat64) then
        Result := FloatToStr(c.RealVal)
      else if c.Type_.Kind = fxb.ir.types.tkBool then
        if c.BoolVal then Result := 'TRUE' else Result := 'FALSE'
      else
        Result := IntToStr(c.IntVal);
    end
    else
      Result := 'NULL';
  end;
  procedure EmitPGCall(const Sql: string; const Fn: string);
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
  // PostgreSQL bind kind byte stored before each value in fxb_pg_args:
  // 0 = text (nul-terminated), 1 = int64, 2 = double.
  function PGKindOf(Val: TIRValue): Byte;
  begin
    case Val.Type_.Kind of
      fxb.ir.types.tkString: Result := 0;
      fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64: Result := 2;
      else Result := 1;
    end;
  end;
  // Load one runtime value into fxb_pg_args slot SlotIdx (16 bytes: kind + value).
  procedure EmitPGBindSlot(Val: TIRValue; SlotIdx: Integer);
  var
    off: Integer;
    inst: TIRInstruction;
  begin
    off := SlotIdx * 16;
    Emit(Format('%s $%d, %d(%%r10)', [MovOp, PGKindOf(Val), off]));
    if PGKindOf(Val) = 2 then
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
  procedure EmitPGParamCall(const Sql: string; NArgs: Integer);
  begin
    Emit(Format('leaq %s, %%rdi', [RIP(GetStringLabel(Sql))]));
    Emit(Format('movq $%d, %%rsi', [NArgs]));
    Emit(Format('leaq %s, %%rdx', [RIP('fxb_pg_args')]));
    EmitCall('fxb_pg_execv');
  end;
var
  op, table, field, fields, sql, path, vals: string;
  i, nVals: Integer;
  hasCond: Boolean;
  condExpr: string;
begin
  op := Instr.Metadata.Values['op'];
  if op = 'use' then
  begin
    path := FDBConnection;
    if path = '' then path := 'host=localhost port=5432 dbname=fxbase';
    EmitPGCall(path, 'fxb_pg_connect');
  end
  else if op = 'append' then
  begin
    table := Instr.Metadata.Values['table'];
    fields := Instr.Metadata.Values['fields'];
    // CREATE TABLE IF NOT EXISTS (idempotent schema inference from the columns).
    sql := 'CREATE TABLE IF NOT EXISTS ' + table + ' (' + fields + ')';
    EmitPGCall(sql, 'fxb_pg_exec');
    if IsX86_64 and (not IsWindows) then
    begin
      // Parameterized path: runtime (non-constant) values bind through
      // fxb_pg_execv. A trailing FOR/WHILE condition operand is not part
      // of the INSERT column list and is ignored (xBASE APPEND has no scope).
      nVals := Instr.OperandCount;
      if (Instr.Metadata.Values['scope_for'] = '1') or
         (Instr.Metadata.Values['scope_while'] = '1') then
        Dec(nVals);
      vals := '';
      for i := 1 to nVals do
      begin
        if i > 1 then vals := vals + ', ';
        vals := vals + '$' + IntToStr(i);
      end;
      sql := 'INSERT INTO ' + table + ' (' + fields + ') VALUES (' + vals + ')';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_pg_args')]));
      for i := 0 to nVals - 1 do
        EmitPGBindSlot(Instr.GetOperand(i), i);
      EmitPGParamCall(sql, nVals);
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
      EmitPGCall(sql, 'fxb_pg_exec');
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
    // Use the stored AST expression for the WHERE clause (converted to SQL)
    condExpr := '';
    if Instr.Metadata.Values['scope_for_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_for_expr']
    else if Instr.Metadata.Values['scope_while_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_while_expr'];
    if hasCond and (condExpr <> '') then
      sql := 'UPDATE ' + table + ' SET ' + field + ' = $1 WHERE (' + condExpr + ')'
    else if hasCond then
      sql := 'UPDATE ' + table + ' SET ' + field + ' = $1 WHERE ($2)'
    else
      sql := 'UPDATE ' + table + ' SET ' + field + ' = $1' +
             ' WHERE ctid = (SELECT ctid FROM ' + table + ' ORDER BY ctid DESC LIMIT 1)';
    if IsX86_64 and (not IsWindows) then
    begin
      // Parameterized path; the value and any FOR/WHILE condition bind by index.
      nVals := 1;
      // If we have a stored expression, we don't need to bind the condition as a parameter
      if hasCond and (condExpr = '') then Inc(nVals);
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_pg_args')]));
      EmitPGBindSlot(Instr.GetOperand(0), 0);
      if hasCond and (condExpr = '') then
        EmitPGBindSlot(Instr.GetOperand(Instr.OperandCount - 1), 1);
      EmitPGParamCall(sql, nVals);
    end
    else
    begin
      // Fallback (x86_32 / Windows): compile-time SQL, runtime values become NULL.
      if hasCond and (condExpr <> '') then
        sql := 'UPDATE ' + table + ' SET ' + field + ' = ' + ConstToSQL(Instr.GetOperand(0)) +
               ' WHERE (' + condExpr + ')'
      else if hasCond then
        sql := 'UPDATE ' + table + ' SET ' + field + ' = ' + ConstToSQL(Instr.GetOperand(0)) +
               ' WHERE (' + ConstToSQL(Instr.GetOperand(Instr.OperandCount - 1)) + ')'
      else
        sql := 'UPDATE ' + table + ' SET ' + field + ' = ' + ConstToSQL(Instr.GetOperand(0)) +
               ' WHERE ctid = (SELECT ctid FROM ' + table + ' ORDER BY ctid DESC LIMIT 1)';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      EmitPGCall(sql, 'fxb_pg_exec');
    end;
  end
  else if (op = 'pack') or (op = 'zap') then
  begin
    // PACK/ZAP both clear the active table; PostgreSQL has no TRUNCATE with WHERE,
    // so DELETE FROM keeps the schema. Scope clauses add WHERE/LIMIT.
    table := Instr.Metadata.Values['table'];
    hasCond := (Instr.Metadata.Values['scope_for'] = '1') or
               (Instr.Metadata.Values['scope_while'] = '1');
    // Use the stored AST expression for the WHERE clause (converted to SQL)
    condExpr := '';
    if Instr.Metadata.Values['scope_for_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_for_expr']
    else if Instr.Metadata.Values['scope_while_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_while_expr'];
    if IsX86_64 and (not IsWindows) then
    begin
      // Parameterized path: bind runtime condition via fxb_pg_execv.
      nVals := 0;
      if hasCond and (condExpr = '') then Inc(nVals);
      sql := 'DELETE FROM ' + table;
      if hasCond and (condExpr <> '') then
        sql := sql + ' WHERE (' + condExpr + ')'
      else if hasCond then
        sql := sql + ' WHERE ($1)';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_pg_args')]));
      if hasCond and (condExpr = '') then
        EmitPGBindSlot(Instr.GetOperand(Instr.OperandCount - 1), 0);
      EmitPGParamCall(sql, nVals);
    end
    else
    begin
      // Fallback (x86_32 / Windows): compile-time SQL, runtime values become NULL.
      sql := 'DELETE FROM ' + table;
      if hasCond and (condExpr <> '') then
        sql := sql + ' WHERE (' + condExpr + ')'
      else if Instr.Metadata.Values['scope_for'] = '1' then
        sql := sql + ' WHERE (' + ConstToSQL(Instr.GetOperand(Instr.OperandCount - 1)) + ')'
      else if Instr.Metadata.Values['scope_while'] = '1' then
        sql := sql + ' WHERE (' + ConstToSQL(Instr.GetOperand(Instr.OperandCount - 1)) + ')';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      EmitPGCall(sql, 'fxb_pg_exec');
    end;
  end;
end;


procedure TFXBBackend.EmitPGRuntime;
begin
  if (FDBDriver <> 'postgresql') and (FDBConnection = '') then
    Exit;
  if IsWindows and (not IsX86_64) then
  begin
    // 32-bit COFF/PE: not emitting the PostgreSQL runtime here.
    Exit;
  end;

  // Global connection handle in .bss.
  EmitDirective('.section .bss');
  EmitDirective('.globl fxb_pg_conn');
  EmitDirective('.type fxb_pg_conn, @object');
  if IsX86_64 then EmitDirective('.size fxb_pg_conn, 8')
  else EmitDirective('.size fxb_pg_conn, 4');
  EmitLabel('fxb_pg_conn');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');

  // Prepared-statement slot + shared bind-args buffer (16 slots * 16 bytes).
  EmitDirective('.type fxb_pg_args, @object');
  EmitDirective('.size fxb_pg_args, 256');
  EmitLabel('fxb_pg_args');
  if IsX86_64 then EmitDirective('.skip 256') else EmitDirective('.skip 128');

  EmitDirective('.section .text');

  // fxb_pg_connect(conninfo): PQconnectdb
  EmitDirective('.globl fxb_pg_connect');
  EmitDirective('.type fxb_pg_connect, @function');
  EmitLabel('fxb_pg_connect');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('leaq fxb_pg_conn(%rip), %rdx');
      Emit('call PQconnectdb');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('leaq fxb_pg_conn(%rip), %rsi');
      Emit('call PQconnectdb');
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');
    Emit('pushl %eax');
    Emit('leal fxb_pg_conn, %eax');
    Emit('pushl %eax');
    Emit('call PQconnectdb');
    Emit('addl $8, %esp');
  end;

  // fxb_pg_exec(sql): PQexec
  EmitDirective('.globl fxb_pg_exec');
  EmitDirective('.type fxb_pg_exec, @function');
  EmitLabel('fxb_pg_exec');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('call PQexec');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('movq fxb_pg_conn(%rip), %rdi');
      Emit('call PQexec');
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');
    Emit('pushl %eax');
    Emit('movl fxb_pg_conn, %eax');
    Emit('pushl %eax');
    Emit('call PQexec');
    Emit('addl $8, %esp');
  end;

  // fxb_pg_execv(sql, nparams, params): PQexecParams
  EmitDirective('.globl fxb_pg_execv');
  EmitDirective('.type fxb_pg_execv, @function');
  EmitLabel('fxb_pg_execv');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      // rcx = sql, rdx = nparams, r8 = paramValues
      Emit('movq %rdx, %rax');
      Emit('movq %r8, %rcx');
      Emit('xorq %rdx, %rdx'); // paramLengths = NULL
      Emit('xorq %r8, %r8');   // paramFormats = NULL
      Emit('movq $0, %r9');    // resultFormat = 0 (text)
      Emit('movq fxb_pg_conn(%rip), %rdi');
      Emit('call PQexecParams');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      // rdi = sql, rsi = nparams, rdx = paramValues
      Emit('movq fxb_pg_conn(%rip), %rcx');
      Emit('movq %rdx, %r8');
      Emit('movq %rsi, %rdx');
      Emit('movq %rdi, %rsi');
      Emit('movq %rcx, %rdi');
      Emit('xorq %r10, %r10'); // paramLengths
      Emit('xorq %r11, %r11'); // paramFormats
      Emit('movq $0, %rcx');   // resultFormat
      Emit('call PQexecParams');
    end;
  end
  else
  begin
    // 32-bit cdecl: sql, nparams, paramValues on stack
    Emit('movl 4(%esp), %eax');     // sql
    Emit('pushl %eax');
    Emit('movl 8(%esp), %eax');     // nparams
    Emit('pushl %eax');
    Emit('movl 12(%esp), %eax');    // paramValues
    Emit('pushl %eax');
    Emit('pushl fxb_pg_conn');
    Emit('call PQexecParams');
    Emit('addl $16, %esp');
  end;

  // fxb_pg_disconnect: PQfinish
  EmitDirective('.globl fxb_pg_disconnect');
  EmitDirective('.type fxb_pg_disconnect, @function');
  EmitLabel('fxb_pg_disconnect');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('movq fxb_pg_conn(%rip), %rcx');
      Emit('call PQfinish');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('movq fxb_pg_conn(%rip), %rdi');
      Emit('call PQfinish');
    end;
  end
  else
  begin
    Emit('pushl fxb_pg_conn');
    Emit('call PQfinish');
    Emit('addl $4, %esp');
  end;
end;