unit fxb.parser.toplevel;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}

interface

uses
  SysUtils,
  Classes,
  fxb.tokens,
  fxb.errors,
  fxb.ast,
  fxb.parser.context,
  fxb.parser.types,
  fxb.parser.common;

type
  TTopLevelParser = class
  private
    FCtx: IParserContext;
  public
    constructor Create(const ACtx: IParserContext);
    function ParseFunctionDef: TFunctionDef;
    function ParseProcedureDef: TProcedureDef;
    function ParseClassDef: TClassDef;
    function ParseMethodDef: TMethodDef;
    function ParseConstructorDef: TConstructorDef;
    function ParseInterfaceDef: TInterfaceDef;
    function ParseStructDef: TStructDef;
    function ParseNewTypeDef: TNewTypeDef;
    function ParseTopLevel: TASTNode;
    function ParseProgram: TCompilationUnit;
  end;

implementation

constructor TTopLevelParser.Create(const ACtx: IParserContext);
begin
  inherited Create;
  FCtx := ACtx;
end;

function TTopLevelParser.ParseFunctionDef: TFunctionDef;
var
  isStatic: Boolean;
  name: string;
  func: TFunctionDef;
  typ: string;
  p: TParamInfo;
begin
  isStatic := False;
  if FCtx.MatchKeyword(kwStatic) then isStatic := True;
  FCtx.ConsumeKeyword(kwFunction, 'Expected FUNCTION');

  if FCtx.Peek = ttIdentifier then
    name := FCtx.GetCurrent.StrValue
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected function name');
    name := '__missing__';
  end;
  FCtx.Advance;

  func := TFunctionDef.Create(name, isStatic, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  // Generic params
  if FCtx.Peek = ttLt then
    FCtx.ParseGenericArgs;

  // Formal params
  if FCtx.Peek = ttLParen then
  begin
    for p in FCtx.ParseParamList do
      func.AddParam(p.Name, p.Typ, nil, p.IsRef);
  end;

  // Return type
  if FCtx.MatchKeyword(kwAs) then
  begin
    typ := FCtx.ParseDataType;
    func.SetReturnType(typ);
  end
  else if FCtx.Peek = ttColon then
  begin
    FCtx.Advance;
    typ := FCtx.ParseTypeRef;
    func.SetReturnType(typ);
  end;

  // Body
  while not FCtx.CheckKeyword(kwEndFunc) and not FCtx.CheckKeyword(kwEndFunction)
    and not FCtx.CheckKeyword(kwEnd) and (FCtx.Peek <> ttEof) do
  begin
    func.AddStmt(FCtx.ParseStatement);
  end;

  if FCtx.CheckKeyword(kwEndFunc) or FCtx.CheckKeyword(kwEndFunction) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDFUNC to close FUNCTION');

  Result := func;
end;

function TTopLevelParser.ParseProcedureDef: TProcedureDef;
var
  isStatic: Boolean;
  name: string;
  proc: TProcedureDef;
  p: TParamInfo;
begin
  isStatic := False;
  if FCtx.MatchKeyword(kwStatic) then isStatic := True;
  FCtx.ConsumeKeyword(kwProcedure, 'Expected PROCEDURE');

  if FCtx.Peek = ttIdentifier then
    name := FCtx.GetCurrent.StrValue
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected procedure name');
    name := '__missing__';
  end;
  FCtx.Advance;

  proc := TProcedureDef.Create(name, isStatic, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  if FCtx.Peek = ttLt then
    FCtx.ParseGenericArgs;

  if FCtx.Peek = ttLParen then
  begin
    for p in FCtx.ParseParamList do
      proc.AddParam(p.Name, p.Typ, nil, p.IsRef);
  end;

  while not FCtx.CheckKeyword(kwEndProc) and not FCtx.CheckKeyword(kwEndProcedure)
    and not FCtx.CheckKeyword(kwEnd) and (FCtx.Peek <> ttEof) do
  begin
    proc.AddStmt(FCtx.ParseStatement);
  end;

  if FCtx.CheckKeyword(kwEndProc) or FCtx.CheckKeyword(kwEndProcedure) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDPROC to close PROCEDURE');

  Result := proc;
end;

function TTopLevelParser.ParseClassDef: TClassDef;
var
  name, s: string;
  cls: TClassDef;
  typeArgs: TStringArray;
begin
  FCtx.ConsumeKeyword(kwClass, 'Expected CLASS');
  if FCtx.Peek in [ttIdentifier, ttKeyword] then
  begin
    name := FCtx.GetCurrent.StrValue;
    FCtx.Advance;
  end
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected class name');
    name := '__missing__';
  end;

  cls := TClassDef.Create(name, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  if FCtx.Peek = ttLt then
  begin
    typeArgs := FCtx.ParseGenericArgs;
    for s in typeArgs do
      cls.AddTypeParam(s);
  end;

  if FCtx.MatchKeyword(kwFrom) then
  begin
    while FCtx.Peek = ttIdentifier do
    begin
      cls.AddParent(FCtx.GetCurrent.StrValue);
      FCtx.Advance;
      if FCtx.Peek = ttComma then FCtx.Advance else Break;
    end;
  end;

  if FCtx.MatchKeyword(kwImplements) then
  begin
    while FCtx.Peek = ttIdentifier do
    begin
      cls.AddImplements(FCtx.GetCurrent.StrValue);
      FCtx.Advance;
      if FCtx.Peek = ttComma then FCtx.Advance else Break;
    end;
  end;

  // Members: METHOD...ENDMETHOD, CONSTRUCTOR...END, DATA fields, or declarations.
  while not FCtx.CheckKeyword(kwEndClass) and (FCtx.Peek <> ttEof) do
  begin
    if FCtx.CheckKeyword(kwMethod) or
       ((FCtx.Peek = ttKeyword) and
         (FCtx.GetCurrent.Keyword in [kwVirtual, kwStatic, kwOverride, kwAbstract])) then
      cls.AddMethod(ParseMethodDef)
    else if FCtx.CheckKeyword(kwConstructor) then
      cls.AddConstructor(ParseConstructorDef)
    else if FCtx.CheckKeyword(kwEndMethod) then
    begin
      FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Unexpected ENDMETHOD outside METHOD');
      FCtx.Advance;
    end
    else
      FCtx.ParseStatement;
  end;

  FCtx.ConsumeKeyword(kwEndClass, 'Expected ENDCLASS');
  Result := cls;
end;

function TTopLevelParser.ParseMethodDef: TMethodDef;
var
  name: string;
  isStatic, isVirtual, isOverride, isAbstract: Boolean;
  typ: string;
  p: TParamInfo;
  meth: TMethodDef;
begin
  isStatic := False; isVirtual := False; isOverride := False; isAbstract := False;
  
  // Handle qualifiers BEFORE METHOD keyword (e.g., VIRTUAL METHOD)
  while (FCtx.Peek = ttKeyword) and
    (FCtx.GetCurrent.Keyword in [kwStatic, kwVirtual, kwOverride, kwAbstract]) do
  begin
    if FCtx.MatchKeyword(kwStatic) then isStatic := True;
    if FCtx.MatchKeyword(kwVirtual) then isVirtual := True;
    if FCtx.MatchKeyword(kwOverride) then isOverride := True;
    if FCtx.MatchKeyword(kwAbstract) then isAbstract := True;
  end;
  
  FCtx.ConsumeKeyword(kwMethod, 'Expected METHOD');

  if (FCtx.Peek in [ttIdentifier, ttKeyword])
     and not FCtx.CheckKeyword(kwEndClass)
     and not FCtx.CheckKeyword(kwEndMethod) then
    name := FCtx.GetCurrent.StrValue
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected method name');
    name := '__missing__';
  end;
  FCtx.Advance;

  meth := TMethodDef.Create(name, isStatic, isVirtual, isOverride, isAbstract,
    FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  // Generic params
  if FCtx.Peek = ttLt then
    FCtx.ParseGenericArgs;

  // Formal params
  if FCtx.Peek = ttLParen then
  begin
    for p in FCtx.ParseParamList do
      meth.AddParam(p.Name, p.Typ, nil, p.IsRef);
  end;

  // Return type: AS T or : T
  if FCtx.MatchKeyword(kwAs) then
  begin
    typ := FCtx.ParseDataType;
    meth.SetReturnType(typ);
  end
  else if FCtx.Peek = ttColon then
  begin
    FCtx.Advance;
    typ := FCtx.ParseTypeRef;
    meth.SetReturnType(typ);
  end;

  // Skip newlines between header and body/terminator.
  while FCtx.Peek = ttNewline do FCtx.Advance;

  // Declaration-only (no body): the header is directly followed by another
  // class member or ENDCLASS / ENDINTERFACE. Otherwise parse the body up to ENDMETHOD.
  if (not isAbstract)
     and not FCtx.CheckKeyword(kwEndClass)
     and not FCtx.CheckKeyword(kwMethod)
     and not FCtx.CheckKeyword(kwEndInterface)
     and not FCtx.CheckKeyword(kwEndMethod) then
  begin
    while not FCtx.CheckKeyword(kwEndMethod) and not FCtx.CheckKeyword(kwEndClass)
      and not FCtx.CheckKeyword(kwEndInterface)
      and (FCtx.Peek <> ttEof) do
      meth.AddStmt(FCtx.ParseStatement);
  end;

  if FCtx.CheckKeyword(kwEndMethod) then
    FCtx.Advance
  else if FCtx.CheckKeyword(kwEndClass) or FCtx.CheckKeyword(kwMethod)
    or FCtx.CheckKeyword(kwEndInterface) then
    begin end // declaration-only method (no body); closed by ENDCLASS / next member / ENDINTERFACE
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected ENDMETHOD to close METHOD');

  Result := meth;
end;

function TTopLevelParser.ParseConstructorDef: TConstructorDef;
var
  ctor: TConstructorDef;
  p: TParamInfo;
begin
  FCtx.ConsumeKeyword(kwConstructor, 'Expected CONSTRUCTOR');
  ctor := TConstructorDef.Create(FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  if FCtx.Peek = ttLParen then
  begin
    for p in FCtx.ParseParamList do
      ctor.AddParam(p.Name, p.Typ, nil, p.IsRef);
  end;

  while FCtx.Peek = ttNewline do FCtx.Advance;

  while not FCtx.CheckKeyword(kwEnd) and not FCtx.CheckKeyword(kwEndClass)
    and (FCtx.Peek <> ttEof) do
    ctor.AddStmt(FCtx.ParseStatement);

  if FCtx.CheckKeyword(kwEnd) then
    FCtx.Advance
  else
    FCtx.Error(FXB_UNTERMINATED_BLOCK, 'Expected END to close CONSTRUCTOR');

  Result := ctor;
end;

function TTopLevelParser.ParseInterfaceDef: TInterfaceDef;
var
  name: string;
  iface: TInterfaceDef;
begin
  FCtx.ConsumeKeyword(kwInterface, 'Expected INTERFACE');
  if FCtx.Peek in [ttIdentifier, ttKeyword] then
  begin
    name := FCtx.GetCurrent.StrValue;
    FCtx.Advance;
  end
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected interface name');
    name := '__missing__';
  end;

  iface := TInterfaceDef.Create(name, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);

  while not FCtx.CheckKeyword(kwEndInterface) and (FCtx.Peek <> ttEof) do
  begin
    while FCtx.Peek = ttNewline do FCtx.Advance;
    if FCtx.CheckKeyword(kwEndInterface) then Break;
    if FCtx.CheckKeyword(kwMethod) then
      iface.AddMethod(ParseMethodDef)
    else
    begin
      FCtx.Error(FXB_UNEXPECTED_TOKEN, 'Only METHOD declarations allowed in INTERFACE');
      FCtx.Advance;
    end;
  end;

  FCtx.ConsumeKeyword(kwEndInterface, 'Expected ENDINTERFACE');
  Result := iface;
end;

function TTopLevelParser.ParseStructDef: TStructDef;
var
  name: string;
  struct: TStructDef;
begin
  FCtx.ConsumeKeyword(kwStruct, 'Expected STRUCT');
  if FCtx.Peek = ttIdentifier then
  begin
    name := FCtx.GetCurrent.StrValue;
    FCtx.Advance;
  end
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected struct name');
    name := '__missing__';
  end;

  struct := TStructDef.Create(name, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
  if FCtx.Peek = ttLt then FCtx.ParseGenericArgs;

  // ALIGN(n)
  if FCtx.MatchKeyword(kwAlign) then
  begin
    if FCtx.Peek = ttLParen then
    begin
      FCtx.Advance;
      if FCtx.Peek = ttInteger then FCtx.Advance;
      if FCtx.Peek = ttRParen then FCtx.Advance;
    end;
  end;

  // Skip members
  while not FCtx.CheckKeyword(kwEndStruct) and (FCtx.Peek <> ttEof) do
  begin
    if FCtx.Peek = ttIdentifier then
    begin
      // member name
      FCtx.Advance;
      if FCtx.Peek = ttColon then
      begin
        FCtx.Advance;
        FCtx.ParseDataType; // consume type
      end;
      // Skip until newline
      while not (FCtx.Peek in [ttNewline, ttSemicolon, ttEof]) do FCtx.Advance;
    end
    else if FCtx.Peek = ttNewline then
      FCtx.Advance
    else
      FCtx.Advance;
  end;

  FCtx.ConsumeKeyword(kwEndStruct, 'Expected ENDSTRUCT');
  Result := struct;
end;

function TTopLevelParser.ParseNewTypeDef: TNewTypeDef;
var
  name, baseType: string;
begin
  FCtx.ConsumeKeyword(kwNewType, 'Expected NEWTYPE');
  if FCtx.Peek = ttIdentifier then
  begin
    name := FCtx.GetCurrent.StrValue;
    FCtx.Advance;
  end
  else
  begin
    FCtx.Error(FXB_EXPECTED_IDENT, 'Expected type name');
    name := '__missing__';
  end;

  if FCtx.Peek = ttLt then FCtx.ParseGenericArgs;
  FCtx.Consume(ttEqual, 'Expected = after NEWTYPE name');

  baseType := FCtx.ParseDataType;
  if baseType = '' then
    FCtx.Error('Expected base type in NEWTYPE');

  FCtx.ConsumeKeyword(kwEndNewType, 'Expected ENDNEWTYPE');
  Result := TNewTypeDef.Create(name, baseType, FCtx.GetCurrent.Line, FCtx.GetCurrent.Col);
end;

function TTopLevelParser.ParseTopLevel: TASTNode;
begin
  case FCtx.Peek of
    ttKeyword:
      case FCtx.GetCurrent.Keyword of
        kwFunction: Result := ParseFunctionDef;
        kwProcedure: Result := ParseProcedureDef;
        kwClass: Result := ParseClassDef;
        kwInterface: Result := ParseInterfaceDef;
        kwStruct: Result := ParseStructDef;
        kwNewType: Result := ParseNewTypeDef;
        kwStatic:
          begin
            FCtx.Advance;
            if FCtx.CheckKeyword(kwFunction) then
              Result := ParseFunctionDef
            else if FCtx.CheckKeyword(kwProcedure) then
              Result := ParseProcedureDef
            else
            begin
              FCtx.Error('Expected FUNCTION or PROCEDURE after STATIC');
              Result := nil;
            end;
          end;
        else
        begin
          Result := FCtx.ParseStatement;
        end;
      end;
    else
    begin
      Result := FCtx.ParseStatement;
    end;
  end;
end;

function TTopLevelParser.ParseProgram: TCompilationUnit;
var
  prog: TCompilationUnit;
  node: TASTNode;
begin
  prog := TCompilationUnit.Create(1, 1);

  if FCtx.GetCurrent.TokenType = ttEof then
    FCtx.Advance;

  while FCtx.Peek <> ttEof do
  begin
    // Skip leading newlines
    while FCtx.Peek = ttNewline do FCtx.Advance;

    if FCtx.Peek = ttEof then Break;

    node := ParseTopLevel;
    if node <> nil then
      prog.AddNode(node);

    // Skip trailing newlines
    while FCtx.Peek = ttNewline do FCtx.Advance;
  end;

  Result := prog;
end;

end.