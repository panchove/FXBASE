unit fxb.cli;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  BaseUnix,
  fxb.tokens,
  fxb.lexer,
  fxb.parser,
  fxb.ast,
  fxb.errors,
  fxb.ir,
  fxb.backend,
  fxb.backend.x86_64,
  fxb.backend.x86_32,
  fxb.ppo;

type
  TFXCLI = class
  private
    FArgs: TStringList;
    FInputFile: string;
    FOutputFile: string;
    FTarget: string;
    FVerbose: Boolean;
    FDebug: Boolean;
    FOptimization: Integer;
    FTargetArch: string;
    FOutputType: string;
    FIncludePaths: TStringList;
    FDefines: TStringList;
    FLegacyMode: Boolean;
    FStrictMode: Boolean;
    FDBAnsi: Boolean;
    FShowHelp: Boolean;
    FShowVersion: Boolean;
    FRunAfterBuild: Boolean;
    FTestMode: Boolean;
    FLintMode: Boolean;
    FDumpAST: Boolean;
    FDumpIR: Boolean;
    FDumpASM: Boolean;
    FTargetOS: string;
    FTargetCPU: string;
    FDBDriver: string;
    FDBConnection: string;
    FGeneratePPO: Boolean;
    FOutputPPO: string;
    FIncludeStdFph: Boolean;
    procedure ParseArgs;
    procedure ShowHelp;
    procedure ShowVersion;
    function CompileFile(const AFileName: string): Boolean;
    function AssembleAndLink(const AsmFile, OutputFile: string): Boolean;
    procedure RunExecutable;
    procedure RunTests;
    procedure LintFile;
    procedure DumpAST(const AAST: TCompilationUnit);
    procedure DumpIR(const AIR: TIRModule);
    procedure DumpASM(const AASM: string);
    function DetermineOutputFile(const AInputFile: string): string;
    procedure SetDefaults;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
    class procedure RunClass; static;
  end;

procedure RunFXCLI;

implementation

constructor TFXCLI.Create;
begin
  inherited Create;
  FArgs := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FDefines := TStringList.Create;
  SetDefaults;
end;

destructor TFXCLI.Destroy;
begin
  FArgs.Free;
  FIncludePaths.Free;
  FDefines.Free;
  inherited Destroy;
end;

function ExecuteProcess(const Program_: string; const Args: string): Integer;
var
  argList: TStringList;
  argv: array of PChar;
  pArgv: PPChar;
  i: Integer;
  pid: TPid;
  status: cInt;
begin
  Result := -1;
  argList := TStringList.Create;
  try
    argList.Delimiter := ' ';
    argList.StrictDelimiter := True;
    argList.DelimitedText := Args;
    SetLength(argv, argList.Count + 2);
    argv[0] := PChar(Program_);
    for i := 0 to argList.Count - 1 do
      argv[i + 1] := PChar(argList[i]);
    argv[argList.Count + 1] := nil;
    pArgv := @argv[0];

    pid := FpFork;
    case pid of
      -1:
        Exit; // fork failed
      0:
        begin
          // Child: exec, then exit with error if it fails
          FpExecV(PChar(Program_), pArgv);
          FpExit(127);
        end;
      else
        // Parent: wait for child
        if FpWaitPid(pid, status, 0) = pid then
          Result := WEXITSTATUS(status);
    end;
  finally
    argList.Free;
  end;
end;


{$I 'fxb.cli.args.inc'}
{$I 'fxb.cli.driver.inc'}
end.
