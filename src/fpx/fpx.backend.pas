unit fpx.backend;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  fpx.ir,
  fpx.errors;

type
  TFPXBackend = class
  private
    FTargetOS: string;
    FTargetCPU: string;
    FOutputType: string;
    FOptimizationLevel: Integer;
    FDebugInfo: Boolean;
    FDBDriver: string;
    FDBConnection: string;
    FErrors: TCompilerMessageArray;
    FLastASM: string;
  public
    property TargetOS: string read FTargetOS write FTargetOS;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property OutputType: string read FOutputType write FOutputType;
    property OptimizationLevel: Integer read FOptimizationLevel write FOptimizationLevel;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    property DBDriver: string read FDBDriver write FDBDriver;
    property DBConnection: string read FDBConnection write FDBConnection;
    function Generate(const IR: TIRModule; const OutputFile: string): Boolean;
    function HasErrors: Boolean;
    property Errors: TCompilerMessageArray read FErrors;
    property LastASM: string read FLastASM;
  end;

implementation

function TFPXBackend.Generate(const IR: TIRModule; const OutputFile: string): Boolean;
begin
  Result := True;
end;

function TFPXBackend.HasErrors: Boolean;
begin
  Result := False;
end;

end.
