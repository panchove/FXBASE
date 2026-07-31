unit fpx.ir.builder;

{$mode delphi}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes,
  fpx.ir.types,
  fpx.ir.instr;

type
  TFPXIRBuilder = class
  private
    FCurrentFunction: TIRFunction;
    FCurrentBlock: TIRBlock;
    FDebugInfo: Boolean;
    FBreakTargets: TIRBlockArray;
    FContinueTargets: TIRBlockArray;
    FReturnTargets: TIRBlockArray;
    FNextValueId: Integer;
    FNextBlockId: Integer;
  public
    constructor Create;
    property CurrentFunction: TIRFunction read FCurrentFunction write FCurrentFunction;
    property CurrentBlock: TIRBlock read FCurrentBlock write FCurrentBlock;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;

    function CreateTempName(const Prefix: string): string;
    function CreateBlockName(const Prefix: string): string;

    procedure PushBreakTarget(Block: TIRBlock);
    procedure PopBreakTarget;
    function CurrentBreakTarget: TIRBlock;
    procedure PushContinueTarget(Block: TIRBlock);
    procedure PopContinueTarget;
    function CurrentContinueTarget: TIRBlock;
    procedure PushReturnTarget(Block: TIRBlock);
    procedure PopReturnTarget;
    function CurrentReturnTarget: TIRBlock;

    procedure EmitInstr(Instr: TIRInstruction);
    function EmitBinOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
    function EmitCmpOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
    function EmitCast(OpKind: TIRInstructionKind; Val: TIRValue; DestType: TIRType; const Name: string = ''): TIRValue;
    function CreateAlloca(const AType: TIRType; const Name: string): TIRLocal;
    function CreateLoad(Ptr: TIRValue; const Name: string): TIRValue;
    function CreateStore(Val, Ptr: TIRValue): TIRInstruction;
    function CreateCall(Func: TIRFunction; Args: TIRValueArray; const Name: string = ''): TIRValue;
    function CreateCallDirect(const FuncName: string; const RetType: TIRType; Args: TIRValueArray; const Name: string = ''): TIRValue;
  end;

implementation

{ TFPXIRBuilder }

constructor TFPXIRBuilder.Create;
begin
  inherited Create;
  FNextValueId := 0;
  FNextBlockId := 0;
  FDebugInfo := False;
end;

function TFPXIRBuilder.CreateTempName(const Prefix: string): string;
begin
  Inc(FNextValueId);
  Result := Prefix + IntToStr(FNextValueId);
end;

function TFPXIRBuilder.CreateBlockName(const Prefix: string): string;
begin
  Inc(FNextBlockId);
  Result := Prefix + IntToStr(FNextBlockId);
end;

procedure TFPXIRBuilder.PushBreakTarget(Block: TIRBlock);
begin
  SetLength(FBreakTargets, Length(FBreakTargets) + 1);
  FBreakTargets[High(FBreakTargets)] := Block;
end;

procedure TFPXIRBuilder.PopBreakTarget;
begin
  if Length(FBreakTargets) > 0 then
    SetLength(FBreakTargets, Length(FBreakTargets) - 1);
end;

function TFPXIRBuilder.CurrentBreakTarget: TIRBlock;
begin
  if Length(FBreakTargets) > 0 then
    Result := FBreakTargets[High(FBreakTargets)]
  else
    Result := nil;
end;

procedure TFPXIRBuilder.PushContinueTarget(Block: TIRBlock);
begin
  SetLength(FContinueTargets, Length(FContinueTargets) + 1);
  FContinueTargets[High(FContinueTargets)] := Block;
end;

procedure TFPXIRBuilder.PopContinueTarget;
begin
  if Length(FContinueTargets) > 0 then
    SetLength(FContinueTargets, Length(FContinueTargets) - 1);
end;

function TFPXIRBuilder.CurrentContinueTarget: TIRBlock;
begin
  if Length(FContinueTargets) > 0 then
    Result := FContinueTargets[High(FContinueTargets)]
  else
    Result := nil;
end;

procedure TFPXIRBuilder.PushReturnTarget(Block: TIRBlock);
begin
  SetLength(FReturnTargets, Length(FReturnTargets) + 1);
  FReturnTargets[High(FReturnTargets)] := Block;
end;

procedure TFPXIRBuilder.PopReturnTarget;
begin
  if Length(FReturnTargets) > 0 then
    SetLength(FReturnTargets, Length(FReturnTargets) - 1);
end;

function TFPXIRBuilder.CurrentReturnTarget: TIRBlock;
begin
  if Length(FReturnTargets) > 0 then
    Result := FReturnTargets[High(FReturnTargets)]
  else
    Result := nil;
end;

procedure TFPXIRBuilder.EmitInstr(Instr: TIRInstruction);
begin
  if Assigned(FCurrentBlock) then
  begin
    FCurrentBlock.AddInstr(Instr);
    if FDebugInfo then
      Instr.DebugLoc := Format('line %d col %d', [0, 0]);
  end;
end;

function TFPXIRBuilder.EmitBinOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
  resultType: TIRType;
begin
  resultType := Left.Type_;
  instr := TIRInstruction.Create(OpKind, resultType, Name);
  instr.AddOperand(Left);
  instr.AddOperand(Right);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRBuilder.EmitCmpOp(OpKind: TIRInstructionKind; Left, Right: TIRValue; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(OpKind, TIRType.Bool, Name);
  instr.AddOperand(Left);
  instr.AddOperand(Right);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRBuilder.EmitCast(OpKind: TIRInstructionKind; Val: TIRValue; DestType: TIRType; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(OpKind, DestType, Name);
  instr.AddOperand(Val);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRBuilder.CreateAlloca(const AType: TIRType; const Name: string): TIRLocal;
var
  local: TIRLocal;
  instr: TIRInstruction;
begin
  local := FCurrentFunction.AddLocal(AType, Name);
  instr := TIRInstruction.Create(ikAlloca, TIRType.Pointer(AType), Name);
  instr.AddOperand(local);
  EmitInstr(instr);
  Result := local;
end;

function TFPXIRBuilder.CreateLoad(Ptr: TIRValue; const Name: string): TIRValue;
var
  instr: TIRInstruction;
  elemType: TIRType;
begin
  if (Ptr.Type_.Kind = tkPointer) and Assigned(Ptr.Type_.ElementType) then
    elemType := Ptr.Type_.ElementType^
  else
    elemType := TIRType.AnyType;
  instr := TIRInstruction.Create(ikLoad, elemType, Name);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRBuilder.CreateStore(Val, Ptr: TIRValue): TIRInstruction;
var
  instr: TIRInstruction;
begin
  instr := TIRInstruction.Create(ikStore, TIRType.Void, '');
  instr.AddOperand(Val);
  instr.AddOperand(Ptr);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRBuilder.CreateCall(Func: TIRFunction; Args: TIRValueArray; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
  i: Integer;
begin
  instr := TIRInstruction.Create(ikCall, Func.ReturnType, Name);
  instr.AddOperand(Func);
  for i := 0 to High(Args) do
    instr.AddOperand(Args[i]);
  EmitInstr(instr);
  Result := instr;
end;

function TFPXIRBuilder.CreateCallDirect(const FuncName: string; const RetType: TIRType; Args: TIRValueArray; const Name: string = ''): TIRValue;
var
  instr: TIRInstruction;
  i: Integer;
begin
  instr := TIRInstruction.Create(ikCallDirect, RetType, Name);
  for i := 0 to High(Args) do
    instr.AddOperand(Args[i]);
  EmitInstr(instr);
  Result := instr;
end;

end.