unit fpx.ppo;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  fpx.preprocessor,
  fpx.errors;

type
  TFPXPPO = class
  private
    FIncludePaths: TStringList;
    FDefines: TStringList;
    FIncludeStdFph: Boolean;
    FLegacyMode: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Process(const Source, FileName: string): string;
    property IncludePaths: TStringList read FIncludePaths write FIncludePaths;
    property Defines: TStringList read FDefines write FDefines;
    property IncludeStdFph: Boolean read FIncludeStdFph write FIncludeStdFph;
    property LegacyMode: Boolean read FLegacyMode write FLegacyMode;
  end;

implementation

constructor TFPXPPO.Create;
begin
  inherited Create;
  FIncludePaths := TStringList.Create;
  FDefines := TStringList.Create;
end;

destructor TFPXPPO.Destroy;
begin
  // Don't free FIncludePaths and FDefines - they are owned by the caller (CLI)
  inherited;
end;

function TFPXPPO.Process(const Source, FileName: string): string;
begin
  Result := Source;
end;

end.
