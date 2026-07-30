program fpx;

{$mode delphi}
{$modeswitch advancedRecords}
{$modeswitch typeHelpers}
{$H+}

uses
  SysUtils,
  Classes,
  fpx.cli;

begin
  try
    RunFPXCLI;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FPX Error: ', E.Message);
      Halt(1);
    end;
  end;
end.
