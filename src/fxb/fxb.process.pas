unit fxb.process;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  BaseUnix;

// Runs an external program with space-delimited arguments and waits for it.
// Returns the process exit code, or -1 if fork/exec failed.
function RunProcess(const Program_, Args: string): Integer;

implementation

function RunProcess(const Program_, Args: string): Integer;
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

end.
