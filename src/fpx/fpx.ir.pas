unit fpx.ir;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpx.ast,
  fpx.errors;

type
  TIRModule = class
  public
    function Dump: string;
  end;

  TFPXIRGenerator = class
  private
    FTargetOS: string;
    FTargetCPU: string;
    FOptimizationLevel: Integer;
    FDebugInfo: Boolean;
    FErrors: TCompilerMessageArray;
  public
    property TargetOS: string read FTargetOS write FTargetOS;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property OptimizationLevel: Integer read FOptimizationLevel write FOptimizationLevel;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    function Generate(const AST: TCompilationUnit): TIRModule;
    function HasErrors: Boolean;
    property Errors: TCompilerMessageArray read FErrors;
  end;

implementation

function TIRModule.Dump: string;
begin
  Result := 'IR Module (stub)';
end;

function TFPXIRGenerator.Generate(const AST: TCompilationUnit): TIRModule;
begin
  Result := TIRModule.Create;
end;

function TFPXIRGenerator.HasErrors: Boolean;
begin
  Result := False;
end;

end.
