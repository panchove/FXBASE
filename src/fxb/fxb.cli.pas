unit fxb.cli;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  fxb.tokens,
  fxb.lexer,
  fxb.parser,
  fxb.ast,
  fxb.errors,
  fxb.ir,
  fxb.backend,
  fxb.backend.x86_64,
  fxb.backend.x86_32,
  fxb.ppo,
  fxb.threadpool,
  fxb.cache,
  fxb.symbols,
  fxb.preprocessor,
  fxb.process;

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
    FJobs: Integer;
    FCacheDir: string;
    FTwoPass: Boolean;
    FSourceFiles: TStringList;
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
    function CompileTwoPass: Boolean;
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
  FSourceFiles := TStringList.Create;
  SetDefaults;
end;

destructor TFXCLI.Destroy;
begin
  FArgs.Free;
  FIncludePaths.Free;
  FDefines.Free;
  FSourceFiles.Free;
  inherited Destroy;
end;

{$I 'fxb.cli.args.inc'}
{$I 'fxb.cli.driver.inc'}
end.
