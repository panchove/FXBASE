unit fxb.ir;

{$mode objfpc}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes,
  fxb.ast,
  fxb.tokens,
  fxb.errors,
  fxb.ir.types,
  fxb.ir.instr,
  fxb.ir.builder;

type
  TIRTypeKind = fxb.ir.types.TIRTypeKind;
  TIRValueKind = fxb.ir.types.TIRValueKind;
  TIRType = fxb.ir.types.TIRType;
  TIRValue = fxb.ir.instr.TIRValue;
  TIRConstant = fxb.ir.instr.TIRConstant;
  TIRArgument = fxb.ir.instr.TIRArgument;
  TIRLocal = fxb.ir.instr.TIRLocal;
  TIRGlobal = fxb.ir.instr.TIRGlobal;
  TIRInstruction = fxb.ir.instr.TIRInstruction;
  TIRInstructionKind = fxb.ir.instr.TIRInstructionKind;
  TIRBlock = fxb.ir.instr.TIRBlock;
  TIRFunction = fxb.ir.instr.TIRFunction;
  TIRModule = fxb.ir.instr.TIRModule;
  TIRValueArray = fxb.ir.instr.TIRValueArray;
  TIRInstructionArray = fxb.ir.instr.TIRInstructionArray;
  TIRArgumentArray = fxb.ir.instr.TIRArgumentArray;
  TIRLocalArray = fxb.ir.instr.TIRLocalArray;
  TIRBlockArray = fxb.ir.instr.TIRBlockArray;

  TFXBIRGenerator = class
  private
    FTargetOS: string;
    FTargetCPU: string;
    FOptimizationLevel: Integer;
    FDebugInfo: Boolean;
    FMultiUnit: Boolean;
    FErrors: TCompilerMessageArray;
    FModule: TIRModule;
    FBuilder: TIRBuilder;

  public
    property TargetOS: string read FTargetOS write FTargetOS;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property OptimizationLevel: Integer read FOptimizationLevel write FOptimizationLevel;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    // When True, unresolved calls are emitted as external references resolved
    // at the final link; when False, empty stub functions are emitted instead.
    property MultiUnit: Boolean read FMultiUnit write FMultiUnit;
    function Generate(const AST: TCompilationUnit): TIRModule;
    function HasErrors: Boolean;
    property Errors: TCompilerMessageArray read FErrors;
  end;

implementation

{ TFXBIRGenerator }

function TFXBIRGenerator.Generate(const AST: TCompilationUnit): TIRModule;
begin
  FModule := TIRModule.Create('fx_module');
  FModule.TargetTriple := FTargetOS + '-' + FTargetCPU + '-none';
  FModule.SourceFileName := '';
  FBuilder := TIRBuilder.Create(FModule);
  FBuilder.FOptimizationLevel := FOptimizationLevel;
  FBuilder.FDebugInfo := FDebugInfo;
  FBuilder.FMultiUnit := FMultiUnit;
  try
    FBuilder.LowerCompilationUnit(AST);
    if FOptimizationLevel > 0 then
    begin
      FBuilder.RunConstantFolding;
      FBuilder.RunDeadCodeElimination;
    end;
    FModule.Verify;
    Result := FModule;
  finally
    FBuilder.Free;
  end;
end;

function TFXBIRGenerator.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

end.