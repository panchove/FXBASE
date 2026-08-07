// fxb.backend.ms.inc -- MSSQL ODBC DB runtime emission + DB instruction lowering for MSSQL.
// Included into fxb.backend.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXBBackend; behaviour unchanged.

procedure TFXBBackend.GenMSOp(Instr: TIRInstruction);
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
        if c.BoolVal then Result := '1' else Result := '0'
      else
        Result := IntToStr(c.IntVal);
    end
    else
      Result := 'NULL';
  end;
  procedure EmitMSCall(const Sql: string; const Fn: string);
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
  // MSSQL bind kind byte stored before each value in fxb_ms_args:
  // 0 = text (nul-terminated), 1 = int64, 2 = double.
  function MSKindOf(Val: TIRValue): Byte;
  begin
    case Val.Type_.Kind of
      fxb.ir.types.tkString: Result := 0;
      fxb.ir.types.tkFloat32, fxb.ir.types.tkFloat64: Result := 2;
      else Result := 1;
    end;
  end;
  // Load one runtime value into fxb_ms_args slot SlotIdx (16 bytes: kind + value).
  procedure EmitMSBindSlot(Val: TIRValue; SlotIdx: Integer);
  var
    off: Integer;
    inst: TIRInstruction;
  begin
    off := SlotIdx * 16;
    Emit(Format('%s $%d, %d(%%r10)', [MovOp, MSKindOf(Val), off]));
    if MSKindOf(Val) = 2 then
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
  procedure EmitMSParamCall(const Sql: string; NArgs: Integer);
  begin
    Emit(Format('leaq %s, %%rdi', [RIP(GetStringLabel(Sql))]));
    Emit(Format('movq $%d, %%rsi', [NArgs]));
    Emit(Format('leaq %s, %%rdx', [RIP('fxb_ms_args')]));
    EmitCall('fxb_ms_execv');
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
    if path = '' then path := 'DSN=fxbase;UID=sa;PWD=;';
    EmitMSCall(path, 'fxb_ms_connect');
  end
  else if op = 'append' then
  begin
    table := Instr.Metadata.Values['table'];
    fields := Instr.Metadata.Values['fields'];
    sql := 'CREATE TABLE IF NOT EXISTS ' + table + ' (' + fields + ')';
    EmitMSCall(sql, 'fxb_ms_exec');
    if IsX86_64 and (not IsWindows) then
    begin
      nVals := Instr.OperandCount;
      if (Instr.Metadata.Values['scope_for'] = '1') or
         (Instr.Metadata.Values['scope_while'] = '1') then
        Dec(nVals);
      vals := '';
      for i := 1 to nVals do
      begin
        if i > 1 then vals := vals + ', ';
        vals := vals + '?';
      end;
      sql := 'INSERT INTO ' + table + ' (' + fields + ') VALUES (' + vals + ')';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_ms_args')]));
      for i := 0 to nVals - 1 do
        EmitMSBindSlot(Instr.GetOperand(i), i);
      EmitMSParamCall(sql, nVals);
    end
    else
    begin
      vals := '';
      for i := 0 to Instr.OperandCount - 1 do
      begin
        if i > 0 then vals := vals + ', ';
        vals := vals + ConstToSQL(Instr.GetOperand(i));
      end;
      sql := 'INSERT INTO ' + table + ' (' + fields + ') VALUES (' + vals + ')';
      EmitMSCall(sql, 'fxb_ms_exec');
    end;
  end
  else if op = 'replace' then
  begin
    table := Instr.Metadata.Values['table'];
    field := Instr.Metadata.Values['field'];
    hasCond := (Instr.Metadata.Values['scope_for'] = '1') or
               (Instr.Metadata.Values['scope_while'] = '1');
    condExpr := '';
    if Instr.Metadata.Values['scope_for_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_for_expr']
    else if Instr.Metadata.Values['scope_while_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_while_expr'];
    if hasCond and (condExpr <> '') then
      sql := 'UPDATE ' + table + ' SET ' + field + ' = ? WHERE (' + condExpr + ')'
    else if hasCond then
      sql := 'UPDATE ' + table + ' SET ' + field + ' = ? WHERE (?)'
    else
      sql := 'UPDATE ' + table + ' SET ' + field + ' = ?' +
             ' WHERE ctid = (SELECT ctid FROM ' + table + ' ORDER BY ctid DESC LIMIT 1)';
    if IsX86_64 and (not IsWindows) then
    begin
      nVals := 1;
      if hasCond and (condExpr = '') then Inc(nVals);
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_ms_args')]));
      EmitMSBindSlot(Instr.GetOperand(0), 0);
      if hasCond and (condExpr = '') then
        EmitMSBindSlot(Instr.GetOperand(Instr.OperandCount - 1), 1);
      EmitMSParamCall(sql, nVals);
    end
    else
    begin
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
      EmitMSCall(sql, 'fxb_ms_exec');
    end;
  end
  else if (op = 'pack') or (op = 'zap') then
  begin
    table := Instr.Metadata.Values['table'];
    hasCond := (Instr.Metadata.Values['scope_for'] = '1') or
               (Instr.Metadata.Values['scope_while'] = '1');
    condExpr := '';
    if Instr.Metadata.Values['scope_for_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_for_expr']
    else if Instr.Metadata.Values['scope_while_expr'] <> '' then
      condExpr := Instr.Metadata.Values['scope_while_expr'];
    if IsX86_64 and (not IsWindows) then
    begin
      nVals := 0;
      if hasCond and (condExpr = '') then Inc(nVals);
      sql := 'DELETE FROM ' + table;
      if hasCond and (condExpr <> '') then
        sql := sql + ' WHERE (' + condExpr + ')'
      else if hasCond then
        sql := sql + ' WHERE (?)';
      if Instr.Metadata.Values['scope_next'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_next'];
      if Instr.Metadata.Values['scope_rest'] <> '' then
        sql := sql + ' LIMIT ' + Instr.Metadata.Values['scope_rest'] + ' OFFSET 1';
      Emit(Format('leaq %s, %%r10', [RIP('fxb_ms_args')]));
      if hasCond and (condExpr = '') then
        EmitMSBindSlot(Instr.GetOperand(Instr.OperandCount - 1), 0);
      EmitMSParamCall(sql, nVals);
    end
    else
    begin
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
      EmitMSCall(sql, 'fxb_ms_exec');
    end;
  end;
end;


procedure TFXBBackend.EmitMSRuntime;
begin
  if (FDBDriver <> 'mssql') and (FDBConnection = '') then
    Exit;
  if IsWindows and (not IsX86_64) then
  begin
    Exit;
  end;

  EmitDirective('.section .bss');
  EmitDirective('.globl fxb_ms_env');
  EmitDirective('.type fxb_ms_env, @object');
  if IsX86_64 then EmitDirective('.size fxb_ms_env, 8')
  else EmitDirective('.size fxb_ms_env, 4');
  EmitLabel('fxb_ms_env');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');

  EmitDirective('.globl fxb_ms_dbc');
  EmitDirective('.type fxb_ms_dbc, @object');
  if IsX86_64 then EmitDirective('.size fxb_ms_dbc, 8')
  else EmitDirective('.size fxb_ms_dbc, 4');
  EmitLabel('fxb_ms_dbc');
  if IsX86_64 then EmitDirective('.quad 0') else EmitDirective('.long 0');

  EmitDirective('.type fxb_ms_args, @object');
  EmitDirective('.size fxb_ms_args, 256');
  EmitLabel('fxb_ms_args');
  if IsX86_64 then EmitDirective('.skip 256') else EmitDirective('.skip 128');

  EmitDirective('.section .text');

  EmitDirective('.globl fxb_ms_connect');
  EmitDirective('.type fxb_ms_connect, @function');
  EmitLabel('fxb_ms_connect');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('leaq fxb_ms_env(%rip), %rdx');
      Emit('leaq fxb_ms_dbc(%rip), %r8');
      EmitCall('SQLAllocHandle');
      EmitCall('SQLConnect');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('leaq fxb_ms_env(%rip), %rsi');
      Emit('leaq fxb_ms_dbc(%rip), %rdx');
      EmitCall('SQLAllocHandle');
      EmitCall('SQLConnect');
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');
    Emit('pushl %eax');
    Emit('leal fxb_ms_env, %eax');
    Emit('pushl %eax');
    EmitCall('SQLAllocHandle');
    EmitCall('SQLConnect');
    Emit('addl $8, %esp');
  end;

  EmitDirective('.globl fxb_ms_exec');
  EmitDirective('.type fxb_ms_exec, @function');
  EmitLabel('fxb_ms_exec');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      EmitCall('SQLExecDirect');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('movq fxb_ms_dbc(%rip), %rdi');
      EmitCall('SQLExecDirect');
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');
    Emit('pushl %eax');
    Emit('movl fxb_ms_dbc, %eax');
    Emit('pushl %eax');
    EmitCall('SQLExecDirect');
    Emit('addl $8, %esp');
  end;

  EmitDirective('.globl fxb_ms_execv');
  EmitDirective('.type fxb_ms_execv, @function');
  EmitLabel('fxb_ms_execv');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      EmitCall('SQLExecDirect');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('movq fxb_ms_dbc(%rip), %rdi');
      EmitCall('SQLExecDirect');
    end;
  end
  else
  begin
    Emit('movl 4(%esp), %eax');
    Emit('pushl %eax');
    Emit('movl 8(%esp), %eax');
    Emit('pushl %eax');
    Emit('movl 12(%esp), %eax');
    Emit('pushl %eax');
    Emit('pushl fxb_ms_dbc');
    EmitCall('SQLExecDirect');
    Emit('addl $16, %esp');
  end;

  EmitDirective('.globl fxb_ms_disconnect');
  EmitDirective('.type fxb_ms_disconnect, @function');
  EmitLabel('fxb_ms_disconnect');
  if IsX86_64 then
  begin
    if IsWindows then
    begin
      Emit('movq fxb_ms_dbc(%rip), %rcx');
      Emit('call SQLDisconnect');
      Emit('movq fxb_ms_dbc(%rip), %rcx');
      Emit('call SQLFreeHandle');
      Emit('movq fxb_ms_env(%rip), %rcx');
      Emit('call SQLFreeHandle');
    end
    else
    begin
      Emit('pushq %rbp');
      Emit('movq %rsp, %rbp');
      Emit('andq $0xFFFFFFFFFFFFFFF0, %rsp');
      Emit('movq fxb_ms_dbc(%rip), %rdi');
      Emit('call SQLDisconnect');
      Emit('movq fxb_ms_dbc(%rip), %rdi');
      Emit('call SQLFreeHandle');
      Emit('movq fxb_ms_env(%rip), %rdi');
      Emit('call SQLFreeHandle');
    end;
  end
  else
  begin
    Emit('pushl fxb_ms_dbc');
    Emit('call SQLDisconnect');
    Emit('pushl fxb_ms_dbc');
    Emit('call SQLFreeHandle');
    Emit('pushl fxb_ms_env');
    Emit('call SQLFreeHandle');
    Emit('addl $12, %esp');
  end;
end;