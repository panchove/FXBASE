// fxb.ir.expr.inc -- expression lowering (LowerExpression..LowerMacro).
// Included into fxb.ir.pas via {$I}. NOT a standalone unit.
// Method declarations remain in TFXBIRGenerator; behaviour unchanged.

function TFXBIRGenerator.LowerExpression(Expr: TExpr): TIRValue;
begin
  if Expr is TLiteralExpr then Result := LowerLiteral(TLiteralExpr(Expr))
  else if Expr is TIdentifierExpr then Result := LowerIdentifier(TIdentifierExpr(Expr))
  else if Expr is TBinaryExpr then Result := LowerBinary(TBinaryExpr(Expr))
  else if Expr is TUnaryExpr then Result := LowerUnary(TUnaryExpr(Expr))
  else if Expr is TCallExpr then Result := LowerCall(TCallExpr(Expr))
  else if Expr is TMethodCallExpr then Result := LowerMethodCall(TMethodCallExpr(Expr))
  else if Expr is TMemberAccessExpr then Result := LowerMemberAccess(TMemberAccessExpr(Expr))
  else if Expr is TDerefExpr then Result := LowerDeref(TDerefExpr(Expr))
  else if Expr is TArrayLiteralExpr then Result := LowerArrayLiteral(TArrayLiteralExpr(Expr))
  else if Expr is THashLiteralExpr then Result := LowerHashLiteral(THashLiteralExpr(Expr))
  else if Expr is TCodeBlockExpr then Result := LowerCodeBlock(TCodeBlockExpr(Expr))
  else if Expr is TStructLiteralExpr then Result := LowerStructLiteral(TStructLiteralExpr(Expr))
  else if Expr is TMacroExpr then Result := LowerMacro(TMacroExpr(Expr))
  else
  begin
    ReportErrorNode(Expr, FXB_UNSUPPORTED_FEATURE, 'Expression type not supported');
    Result := TIRConstant.CreateInt(TIRType.Int(True, 32), 0, 'error');
  end;
end;

function TFXBIRGenerator.LowerLiteral(Expr: TLiteralExpr): TIRValue;
var
  tok: TToken;
  irType: TIRType;
begin
  tok := Expr.Token;
  case tok.TokenType of
    ttInteger:
    begin
      irType := TIRType.Int(True, 64);
      Result := TIRConstant.CreateInt(irType, tok.IntValue, CreateTempName('const'));
    end;
    ttReal:
    begin
      irType := TIRType.Float(64);
      Result := TIRConstant.CreateReal(irType, tok.RealValue, CreateTempName('const'));
    end;
    ttString:
    begin
      irType := TIRType.StringType;
      Result := TIRConstant.CreateString(irType, tok.StrValue, CreateTempName('const'));
    end;
    ttLogical:
    begin
      irType := TIRType.Bool;
      Result := TIRConstant.CreateBool(irType, tok.IntValue = 1, CreateTempName('const'));
    end;
    ttNil:
    begin
      irType := TIRType.Pointer(TIRType.Void);
      Result := TIRConstant.CreateNull(irType, CreateTempName('nil'));
    end;
    ttDate:
    begin
      irType := TIRType.Int(True, 64);
      Result := TIRConstant.CreateInt(irType, tok.IntValue, CreateTempName('const'));
    end;
    else
    begin
      irType := TIRType.Int(True, 32);
      Result := TIRConstant.CreateInt(irType, 0, 'const');
    end;
  end;
end;

function TFXBIRGenerator.LowerIdentifier(Expr: TIdentifierExpr): TIRValue;
var
  local: TIRValue;
  nm: string;
begin
  nm := Expr.Name;
  if FLocalVarMap.IndexOf(nm) >= 0 then
  begin
    local := TIRValue(FLocalVarMap.Objects[FLocalVarMap.IndexOf(nm)]);
    Result := CreateLoad(local, nm);
    if local is TIRLocal then
      TIRLocal(local).IsAddressTaken := True;
  end
  else
  begin
    Result := TIRConstant.CreateNull(TIRType.Pointer(TIRType.Void), CreateTempName('global.' + nm));
  end;
end;

function TFXBIRGenerator.LowerBinary(Expr: TBinaryExpr): TIRValue;
var
  left, right: TIRValue;
  opKind: TIRInstructionKind;
begin
  left := LowerExpression(Expr.Left);
  right := LowerExpression(Expr.Right);
  opKind := MapTokenTypeToBinOp(Expr.Op);
  if opKind <> ikInvalid then
    Result := EmitBinOp(opKind, left, right, CreateTempName('bin'))
  else
  begin
    opKind := MapTokenTypeToCmpOp(Expr.Op);
    if opKind <> ikInvalid then
    begin
      case Expr.Op of
        ttEq, ttEqual: FPendingPredicate := 'eq';
        ttNeq, ttNeq2: FPendingPredicate := 'ne';
        ttLt: FPendingPredicate := 'lt';
        ttGt: FPendingPredicate := 'gt';
        ttLe: FPendingPredicate := 'le';
        ttGe: FPendingPredicate := 'ge';
      end;
      Result := EmitCmpOp(opKind, left, right, CreateTempName('cmp'))
    end
    else
    begin
      ReportErrorNode(Expr, FXB_UNSUPPORTED_FEATURE, 'Binary operator not supported: ' + TokenTypeName(Expr.Op));
      Result := TIRConstant.CreateInt(TIRType.Int(True, 32), 0, 'error');
    end;
  end;
end;

function TFXBIRGenerator.LowerUnary(Expr: TUnaryExpr): TIRValue;
var
  operand: TIRValue;
  opKind: TIRInstructionKind;
begin
  operand := LowerExpression(Expr.Operand);
  opKind := MapTokenTypeToUnaryOp(Expr.Op);
  if opKind <> ikInvalid then
    Result := EmitCast(opKind, operand, operand.Type_, CreateTempName('unary'))
  else
  begin
    ReportErrorNode(Expr, FXB_UNSUPPORTED_FEATURE, 'Unary operator not supported: ' + TokenTypeName(Expr.Op));
    Result := operand;
  end;
end;

function TFXBIRGenerator.LowerCall(Expr: TCallExpr): TIRValue;
var
  fn: TIRFunction;
  args: TIRValueArray;
  i: Integer;
begin
  if UpperCase(Expr.Name) = 'ARGC' then
  begin
    Result := CreateCallDirect('__fx_argc', TIRType.Int(True, 32), [], CreateTempName('argc'));
    FModule.GetFunction('__fx_argc').IsExternal := True;
    Exit;
  end;
  if UpperCase(Expr.Name) = 'ARGV' then
  begin
    SetLength(args, Expr.ArgCount);
    for i := 0 to Expr.ArgCount - 1 do
      args[i] := LowerExpression(Expr.Args[i]);
    Result := CreateCallDirect('__fx_argv', TIRType.StringType, args, CreateTempName('argv'));
    FModule.GetFunction('__fx_argv').IsExternal := True;
    Exit;
  end;
  if UpperCase(Expr.Name) = 'COMMAND' then
  begin
    Result := CreateCallDirect('__fx_command', TIRType.StringType, [], CreateTempName('cmd'));
    FModule.GetFunction('__fx_command').IsExternal := True;
    Exit;
  end;

  fn := FModule.GetFunction(Expr.Name);
  if not Assigned(fn) then
    fn := FModule.AddFunction(Expr.Name, TIRType.AnyType);
  SetLength(args, Expr.ArgCount);
  for i := 0 to Expr.ArgCount - 1 do
    args[i] := LowerExpression(Expr.Args[i]);
  Result := CreateCallDirect(Expr.Name, fn.ReturnType, args, CreateTempName('call'));
end;

function TFXBIRGenerator.LowerMethodCall(Expr: TMethodCallExpr): TIRValue;
var
  target: TIRValue;
  args: TIRValueArray;
  i: Integer;
begin
  target := LowerExpression(Expr.Target);
  SetLength(args, Expr.ArgCount);
  for i := 0 to Expr.ArgCount - 1 do
    args[i] := LowerExpression(Expr.Args[i]);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('method.' + Expr.Method));
end;

function TFXBIRGenerator.LowerMemberAccess(Expr: TMemberAccessExpr): TIRValue;
var
  target: TIRValue;
begin
  target := LowerExpression(Expr.Target);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('member.' + Expr.Member));
end;

function TFXBIRGenerator.LowerDeref(Expr: TDerefExpr): TIRValue;
var
  target: TIRValue;
begin
  target := LowerExpression(Expr.Target);
  Result := CreateLoad(target, CreateTempName('deref'));
end;

function TFXBIRGenerator.LowerArrayLiteral(Expr: TArrayLiteralExpr): TIRValue;
var
  arrType: TIRType;
  i: Integer;
begin
  arrType := TIRType.MakeArray(TIRType.AnyType);
  Result := TIRGlobal.Create(arrType, CreateTempName('arr'));
  for i := 0 to Expr.Count - 1 do
    LowerExpression(Expr.Items[i]);
end;

function TFXBIRGenerator.LowerHashLiteral(Expr: THashLiteralExpr): TIRValue;
var
  i: Integer;
begin
  Result := TIRGlobal.Create(TIRType.AnyType, CreateTempName('hash'));
  for i := 0 to Length(Expr.Keys) - 1 do
  begin
    LowerExpression(Expr.Keys[i]);
    LowerExpression(Expr.Values[i]);
  end;
end;

function TFXBIRGenerator.LowerCodeBlock(Expr: TCodeBlockExpr): TIRValue;
var
  i: Integer;
begin
  for i := 0 to Length(Expr.Statements) - 1 do
    LowerStatement(Expr.Statements[i]);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('codeblock'));
end;

function TFXBIRGenerator.LowerStructLiteral(Expr: TStructLiteralExpr): TIRValue;
var
  i: Integer;
begin
  for i := 0 to Length(Expr.Args) - 1 do
    LowerExpression(Expr.Args[i]);
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('struct.' + Expr.TypeName));
end;

function TFXBIRGenerator.LowerMacro(Expr: TMacroExpr): TIRValue;
begin
  Result := TIRConstant.CreateNull(TIRType.AnyType, CreateTempName('macro.' + Expr.Name));
end;
