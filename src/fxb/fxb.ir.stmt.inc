// fxb.ir.stmt.inc -- statement lowering (LowerCompilationUnit..LowerLoopCtrl).
// Included into fxb.ir.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXBIRGenerator; behaviour unchanged.

procedure TFXBIRGenerator.LowerCompilationUnit(AST: TCompilationUnit);
var
  i: Integer;
  node: TASTNode;
  topLevel: array of TASTNode;
  hasMain: Boolean;
begin
  hasMain := False;
  for i := 0 to AST.Count - 1 do
  begin
    node := AST.Nodes[i];
    if (node is TFunctionDef) and (TFunctionDef(node).Name = 'Main') then
      hasMain := True
    else if (node is TProcedureDef) and (TProcedureDef(node).Name = 'Main') then
      hasMain := True
    else if (node is TClassDef) or (node is TStructDef) or (node is TNewTypeDef) then
      Continue
    else
    begin
      SetLength(topLevel, Length(topLevel) + 1);
      topLevel[High(topLevel)] := node;
    end;
  end;

  if hasMain then
    FPrependStmts := topLevel;

  for i := 0 to AST.Count - 1 do
  begin
    node := AST.Nodes[i];
    if node is TFunctionDef then
      LowerFunctionDef(TFunctionDef(node))
    else if node is TProcedureDef then
      LowerProcedureDef(TProcedureDef(node))
    else if node is TClassDef then
      LowerClassDef(TClassDef(node))
    else if node is TStructDef then
      LowerStructDef(TStructDef(node))
    else if node is TNewTypeDef then
      LowerNewTypeDef(TNewTypeDef(node))
  end;

  if (not hasMain) and (Length(topLevel) > 0) then
    LowerImplicitMain(topLevel);
  FPrependStmts := nil;
end;

procedure TFXBIRGenerator.LowerFunctionDef(Func: TFunctionDef);
var
  retType: TIRType;
  fn: TIRFunction;
  i, n: Integer;
  paramName, paramType: string;
begin
  retType := GetIRType(Func.ReturnType);
  fn := FModule.AddFunction(Func.Name, retType);
  FCurrentFunction := fn;
  FCurrentBlock := fn.EntryBlock;

  n := Func.ParamCount;
  for i := 0 to n - 1 do
  begin
    paramName := Func.GetParamName(i);
    paramType := Func.GetParamType(i);
    fn.AddArgument(GetIRType(paramType), paramName);
    FLocalVarMap.AddObject(paramName, fn.Arguments[i]);
  end;

  if (Func.Name = 'Main') and (Length(FPrependStmts) > 0) then
    for i := 0 to High(FPrependStmts) do
      LowerStatement(FPrependStmts[i]);

  for i := 0 to High(Func.Body) do
    LowerStatement(Func.Body[i]);

  if (FCurrentBlock <> nil) and not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));

  FCurrentFunction := nil;
  FCurrentBlock := nil;
end;

procedure TFXBIRGenerator.LowerProcedureDef(Proc: TProcedureDef);
var
  fn: TIRFunction;
  i, n: Integer;
  paramName, paramType: string;
begin
  fn := FModule.AddFunction(Proc.Name, TIRType.Void);
  FCurrentFunction := fn;
  FCurrentBlock := fn.EntryBlock;

  n := Proc.ParamCount;
  for i := 0 to n - 1 do
  begin
    paramName := Proc.GetParamName(i);
    paramType := Proc.GetParamType(i);
    fn.AddArgument(GetIRType(paramType), paramName);
    FLocalVarMap.AddObject(paramName, fn.Arguments[i]);
  end;

  if (Proc.Name = 'Main') and (Length(FPrependStmts) > 0) then
    for i := 0 to High(FPrependStmts) do
      LowerStatement(FPrependStmts[i]);

  for i := 0 to High(Proc.Body) do
    LowerStatement(Proc.Body[i]);

  if (FCurrentBlock <> nil) and not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));

  FCurrentFunction := nil;
  FCurrentBlock := nil;
end;

procedure TFXBIRGenerator.LowerImplicitMain(Statements: array of TASTNode);
var
  fn: TIRFunction;
  i: Integer;
begin
  fn := FModule.AddFunction('Main', TIRType.Int(True, 32));
  FCurrentFunction := fn;
  FCurrentBlock := fn.EntryBlock;

  for i := 0 to High(Statements) do
    LowerStatement(Statements[i]);

  if (FCurrentBlock <> nil) and not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));

  FCurrentFunction := nil;
  FCurrentBlock := nil;
end;

procedure TFXBIRGenerator.LowerClassDef(ClassDef: TClassDef);
begin
end;

procedure TFXBIRGenerator.LowerStructDef(StructDef: TStructDef);
begin
  FTypeCache.AddObject(StructDef.Name, nil);
end;

procedure TFXBIRGenerator.LowerNewTypeDef(NewTypeDef: TNewTypeDef);
begin
  FTypeCache.AddObject(NewTypeDef.Name, nil);
end;

procedure TFXBIRGenerator.LowerStatement(Stmt: TASTNode);
begin
  if Stmt is TExprStmt then LowerExprStmt(TExprStmt(Stmt))
  else if Stmt is TPrintStmt then LowerPrint(TPrintStmt(Stmt))
  else if Stmt is TVarDeclStmt then LowerVarDecl(TVarDeclStmt(Stmt))
  else if Stmt is TAssignStmt then LowerAssign(TAssignStmt(Stmt))
  else if Stmt is TIfStmt then LowerIf(TIfStmt(Stmt))
  else if Stmt is TForStmt then LowerFor(TForStmt(Stmt))
  else if Stmt is TWhileStmt then LowerWhile(TWhileStmt(Stmt))
  else if Stmt is TReturnStmt then LowerReturn(TReturnStmt(Stmt))
  else if Stmt is TYieldStmt then LowerYield(TYieldStmt(Stmt))
  else if Stmt is TLoopCtrlStmt then LowerLoopCtrl(TLoopCtrlStmt(Stmt))
  else if Stmt is TASTDBStmt then LowerDBStmt(TASTDBStmt(Stmt));
end;

procedure TFXBIRGenerator.LowerExprStmt(Stmt: TExprStmt);
begin
  LowerExpression(Stmt.Expr);
end;

procedure TFXBIRGenerator.LowerPrint(Stmt: TPrintStmt);
var
  instr: TIRInstruction;
  i: Integer;
  val: TIRValue;
begin
  instr := TIRInstruction.Create(ikPrint, TIRType.Void, '');
  for i := 0 to High(Stmt.Expressions) do
  begin
    val := LowerExpression(Stmt.Expressions[i]);
    instr.AddOperand(val);
  end;
  instr.Metadata.Add(Format('newline=%s', [BoolToStr(Stmt.NewLine, '1', '0')]));
  EmitInstr(instr);
end;

procedure TFXBIRGenerator.LowerDBStmt(Stmt: TASTDBStmt);
var
  instr: TIRInstruction;
  i: Integer;
  val: TIRValue;
  table: string;
begin
  instr := TIRInstruction.Create(ikDBOp, TIRType.Void, '');
  instr.Metadata.Values['op'] := Stmt.Op;
  if Stmt.Op = 'use' then
  begin
    FCurrentDBTable := Stmt.TableName;
    instr.Metadata.Values['table'] := Stmt.TableName;
  end
  else
  begin
    // append / replace use the currently-open table.
    table := FCurrentDBTable;
    if table = '' then
      ReportErrorNode(Stmt, FXB_TYPE_MISMATCH, 'DB operation outside of USE')
    else
      instr.Metadata.Values['table'] := table;
    if Stmt.Op = 'append' then
    begin
      // Field names travel in metadata; values as operands (folded to constants).
      table := '';
      for i := 0 to High(Stmt.FieldNames) do
      begin
        if i > 0 then table := table + ',';
        table := table + Stmt.FieldNames[i];
      end;
      instr.Metadata.Values['fields'] := table;
    end
    else if Stmt.Op = 'replace' then
      instr.Metadata.Values['field'] := Stmt.Field;
    // Lower the value expressions (expected to fold to constants).
    for i := 0 to High(Stmt.Exprs) do
    begin
      val := LowerExpression(Stmt.Exprs[i]);
      instr.AddOperand(val);
    end;
  end;
  EmitInstr(instr);
end;

procedure TFXBIRGenerator.LowerVarDecl(Stmt: TVarDeclStmt);
var
  i: Integer;
  varName, varType: string;
  initVal: TExpr;
  irType: TIRType;
  local: TIRLocal;
  val: TIRValue;
begin
  for i := 0 to Stmt.VarCount - 1 do
  begin
    varName := Stmt.Names[i];
    varType := Stmt.GetType(i);
    initVal := Stmt.GetInitVal(i);
    if varType <> '' then
      irType := GetIRType(varType)
    else
    begin
      irType := TIRType.AnyType;
      if Assigned(initVal) then
      begin
        val := LowerExpression(initVal);
        if val.Type_.Kind <> tkAny then
          irType := val.Type_;
      end
      else
        val := TIRValue(nil);
    end;
    local := FCurrentFunction.AddLocal(irType, varName);
    FLocalVarMap.AddObject(varName, local);
    if Assigned(initVal) then
    begin
      if not Assigned(val) then
        val := LowerExpression(initVal);
      CreateStore(val, local);
    end;
  end;
end;

procedure TFXBIRGenerator.LowerAssign(Stmt: TAssignStmt);
var
  target, value: TIRValue;
  nm: string;
  idx: Integer;
begin
  if (Stmt.Target is TIdentifierExpr) and (FLocalVarMap.IndexOf(TIdentifierExpr(Stmt.Target).Name) >= 0) then
  begin
    nm := TIdentifierExpr(Stmt.Target).Name;
    idx := FLocalVarMap.IndexOf(nm);
    target := TIRValue(FLocalVarMap.Objects[idx]);
  end
  else
    target := LowerExpression(Stmt.Target);
  value := LowerExpression(Stmt.Value);
  CreateStore(value, target);
end;

procedure TFXBIRGenerator.LowerIf(Stmt: TIfStmt);
var
  condVal: TIRValue;
  thenBlock, elseBlock, mergeBlock: TIRBlock;
  i, j: Integer;
  hasElseIf: Boolean;
  innerBody: array of TASTNode;
begin
  condVal := LowerExpression(Stmt.Condition);
  thenBlock := FCurrentFunction.CreateBlock(CreateBlockName('then'));
  elseBlock := FCurrentFunction.CreateBlock(CreateBlockName('else'));
  mergeBlock := FCurrentFunction.CreateBlock(CreateBlockName('merge'));

  EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condVal);
  FCurrentBlock.GetLastInstr.AddOperand(thenBlock);
  FCurrentBlock.GetLastInstr.AddOperand(elseBlock);

  FCurrentBlock := thenBlock;
  for i := 0 to High(Stmt.ThenBody) do
    LowerStatement(Stmt.ThenBody[i]);
  if not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);

  hasElseIf := Length(Stmt.ElseIfConds) > 0;
  if hasElseIf or Stmt.HasElse then
  begin
    FCurrentBlock := elseBlock;
    if hasElseIf then
    begin
      for i := 0 to High(Stmt.ElseIfConds) do
      begin
        condVal := LowerExpression(Stmt.ElseIfConds[i]);
        thenBlock := FCurrentFunction.CreateBlock(CreateBlockName('elseif.then'));
        elseBlock := FCurrentFunction.CreateBlock(CreateBlockName('elseif.else'));
        EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
        FCurrentBlock.GetLastInstr.AddOperand(condVal);
        FCurrentBlock.GetLastInstr.AddOperand(thenBlock);
        FCurrentBlock.GetLastInstr.AddOperand(elseBlock);
        FCurrentBlock := thenBlock;
        innerBody := Stmt.ElseIfBodies[i];
        for j := 0 to High(innerBody) do
          LowerStatement(innerBody[j]);
        if not FCurrentBlock.IsTerminated then
          EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
        FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
        FCurrentBlock := elseBlock;
      end;
    end;
    if Stmt.HasElse then
    begin
      for i := 0 to High(Stmt.ElseBody) do
        LowerStatement(Stmt.ElseBody[i]);
    end;
    if not FCurrentBlock.IsTerminated then
      EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
  end
  else
  begin
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(mergeBlock);
  end;
  FCurrentBlock := mergeBlock;
end;

procedure TFXBIRGenerator.LowerFor(Stmt: TForStmt);
var
  initBlock, condBlock, bodyBlock, stepBlock, exitBlock: TIRBlock;
  varPtr: TIRValue;
  startVal, endVal, stepVal: TIRValue;
  condInstr: TIRInstruction;
  varType: TIRType;
  varName: string;
  i: Integer;
begin
  varName := Stmt.VarName;
  varType := GetIRType('INT');

  initBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.init'));
  condBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.cond'));
  bodyBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.body'));
  stepBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.step'));
  exitBlock := FCurrentFunction.CreateBlock(CreateBlockName('for.exit'));

  PushBreakTarget(exitBlock);
  PushContinueTarget(stepBlock);

  if FLocalVarMap.IndexOf(varName) >= 0 then
    varPtr := TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(varName)])
  else
  begin
    varPtr := FCurrentFunction.AddLocal(varType, varName);
    FLocalVarMap.AddObject(varName, varPtr);
  end;

  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(initBlock);

  FCurrentBlock := initBlock;
  startVal := LowerExpression(Stmt.StartExpr);
  CreateStore(startVal, varPtr);
  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  FCurrentBlock := condBlock;
  endVal := LowerExpression(Stmt.EndExpr);
  varPtr := CreateLoad(varPtr, 'for.var');
  condInstr := TIRInstruction.Create(ikICmp, TIRType.Bool, 'for.cond');
  condInstr.AddOperand(varPtr);
  condInstr.AddOperand(endVal);
  EmitInstr(condInstr);
  EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condInstr);
  FCurrentBlock.GetLastInstr.AddOperand(bodyBlock);
  FCurrentBlock.GetLastInstr.AddOperand(exitBlock);

  FCurrentBlock := bodyBlock;
  for i := 0 to High(Stmt.Body) do
    LowerStatement(Stmt.Body[i]);
  if not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(stepBlock);

  FCurrentBlock := stepBlock;
  stepVal := LowerExpression(Stmt.StepExpr);
  varPtr := TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(varName)]);
  varPtr := CreateLoad(varPtr, 'for.var');
  EmitInstr(TIRInstruction.Create(ikAdd, varType, 'for.next'));
  FCurrentBlock.GetLastInstr.AddOperand(varPtr);
  FCurrentBlock.GetLastInstr.AddOperand(stepVal);
  CreateStore(FCurrentBlock.GetLastInstr, TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(varName)]));
  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  FCurrentBlock := exitBlock;
  PopContinueTarget;
  PopBreakTarget;
  FLocalVarMap.Delete(FLocalVarMap.IndexOf(varName));
end;

procedure TFXBIRGenerator.LowerWhile(Stmt: TWhileStmt);
var
  condBlock, bodyBlock, exitBlock: TIRBlock;
  condVal: TIRValue;
  i: Integer;
begin
  condBlock := FCurrentFunction.CreateBlock(CreateBlockName('while.cond'));
  bodyBlock := FCurrentFunction.CreateBlock(CreateBlockName('while.body'));
  exitBlock := FCurrentFunction.CreateBlock(CreateBlockName('while.exit'));

  PushBreakTarget(exitBlock);
  PushContinueTarget(condBlock);

  EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  FCurrentBlock := condBlock;
  condVal := LowerExpression(Stmt.Condition);
  EmitInstr(TIRInstruction.Create(ikCondBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condVal);
  FCurrentBlock.GetLastInstr.AddOperand(bodyBlock);
  FCurrentBlock.GetLastInstr.AddOperand(exitBlock);

  FCurrentBlock := bodyBlock;
  for i := 0 to High(Stmt.Body) do
    LowerStatement(Stmt.Body[i]);
  if not FCurrentBlock.IsTerminated then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(condBlock);

  if Stmt.HasElse then
  begin
  end;

  FCurrentBlock := exitBlock;
  PopContinueTarget;
  PopBreakTarget;
end;

procedure TFXBIRGenerator.LowerReturn(Stmt: TReturnStmt);
var
  retVal: TIRValue;
begin
  if Stmt.HasValue then
  begin
    retVal := LowerExpression(Stmt.Value);
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));
    FCurrentBlock.GetLastInstr.AddOperand(retVal);
  end
  else
    EmitInstr(TIRInstruction.Create(ikRet, TIRType.Void, ''));
end;


procedure TFXBIRGenerator.LowerYield(Stmt: TYieldStmt);
var
  val: TIRValue;
begin
  val := LowerExpression(Stmt.Value);
  EmitInstr(TIRInstruction.Create(ikYield, TIRType.Void, ''));
  FCurrentBlock.GetLastInstr.AddOperand(val);
end;


procedure TFXBIRGenerator.LowerLoopCtrl(Stmt: TLoopCtrlStmt);
var
  target: TIRBlock;
  kind: string;
begin
  kind := Stmt.Kind;
  if kind = 'BREAK' then
    target := CurrentBreakTarget
  else if kind = 'LOOP' then
    target := CurrentContinueTarget
  else
    target := CurrentBreakTarget;
  if Assigned(target) then
    EmitInstr(TIRInstruction.Create(ikBr, TIRType.Void, ''))
  else
    EmitInstr(TIRInstruction.Create(ikUnreachable, TIRType.Void, ''));
  if Assigned(target) then
    FCurrentBlock.GetLastInstr.AddOperand(target);
end;

