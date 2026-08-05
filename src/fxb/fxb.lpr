program fxb;

{$mode objfpc}
{$modeswitch advancedRecords}
{$modeswitch typeHelpers}
{$H+}

uses
  cthreads,
  SysUtils,
  Classes,
  fxb.cli;

begin
  try
    RunFXCLI;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FXB Error: ', E.Message);
      Halt(1);
    end;
  end;
end.
