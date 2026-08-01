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
var
  op, table, field, fields, sql, path, vals: string;
  i: Integer;
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
    // INSERT INTO table (fields) VALUES (v1, v2, ...)
    vals := '';
    for i := 0 to Instr.OperandCount - 1 do
    begin
      if i > 0 then vals := vals + ', ';
      vals := vals + ConstToSQL(Instr.GetOperand(i));
    end;
    sql := 'INSERT INTO ' + table + ' (' + fields + ') VALUES (' + vals + ')';
    EmitDBCall(sql, 'fxb_sqlite_exec');
  end
  else if op = 'replace' then
  begin
    table := Instr.Metadata.Values['table'];
    field := Instr.Metadata.Values['field'];
    vals := ConstToSQL(Instr.GetOperand(0));
    // Scope the UPDATE to the row most recently inserted by the preceding
    // APPEND (xBASE REPLACE acts on the current record). Without a cursor we
    // key on rowid = last_insert_rowid() for the open connection.
    sql := 'UPDATE ' + table + ' SET ' + field + ' = ' + vals +
           ' WHERE rowid = (SELECT last_insert_rowid())';
    EmitDBCall(sql, 'fxb_sqlite_exec');
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
  Emit('movq %rbp, %rsp');
  Emit('popq %rbp');
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
  Emit('movq %rbp, %rsp');
  Emit('popq %rbp');
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
  if IsX86_64 and (not IsWindows) then
  begin
    Emit('movq %rbp, %rsp');
    Emit('popq %rbp');
  end;
  Emit('ret');
  EmitDirective('.size fxb_sqlite_close, .-fxb_sqlite_close');
  Emit('');
end;

