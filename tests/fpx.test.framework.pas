unit fpx.test.framework;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes;

type
  ETestFailure = class(Exception);

  TTestProc = procedure(const AName: string);

  TTestCase = record
    Name: string;
    Run: TTestProc;
  end;
  TTestCases = array of TTestCase;

  TTestStats = record
    Total: Integer;
    Passed: Integer;
    Failed: Integer;
    Skipped: Integer;
    Duration: Double; // seconds
  end;

procedure RegisterTest(const AName: string; const ARun: TTestProc);
procedure RunAllTests(const ATitle: string);
function GetStats: TTestStats;
procedure ResetStats;

// Assertions
procedure AssertTrue(const ACond: Boolean; const AMsg: string = '');
procedure AssertFalse(const ACond: Boolean; const AMsg: string = '');
procedure AssertEquals(const AExpected, AActual: string; const AMsg: string = '');
procedure AssertEqualsI(const AExpected, AActual: Int64; const AMsg: string = '');
procedure AssertNil(const AObj: Pointer; const AMsg: string = '');
procedure AssertNotNil(const AObj: Pointer; const AMsg: string = '');
procedure AssertSameStr(const AExpected, AActual: string; const AMsg: string = '');
procedure Fail(const AMsg: string);

// Helpers
function FormatFloatStr(const v: Double): string;
function StripCRLF(const s: string): string;

implementation

var
  GTests: TTestCases;
  GStats: TTestStats;

procedure RegisterTest(const AName: string; const ARun: TTestProc);
var
  n: Integer;
begin
  n := Length(GTests);
  SetLength(GTests, n + 1);
  GTests[n].Name := AName;
  GTests[n].Run := ARun;
end;

procedure ResetStats;
begin
  GStats.Total := 0;
  GStats.Passed := 0;
  GStats.Failed := 0;
  GStats.Skipped := 0;
  GStats.Duration := 0;
end;

function GetStats: TTestStats;
begin
  Result := GStats;
end;

procedure RunAllTests(const ATitle: string);
var
  i: Integer;
  startTick, endTick: QWord;
begin
  ResetStats;
  startTick := GetTickCount64;
  WriteLn('================================================================');
  WriteLn(' ', ATitle);
  WriteLn('================================================================');
  for i := 0 to High(GTests) do
  begin
    Inc(GStats.Total);
    try
      Write('  [ RUN     ] ', GTests[i].Name);
      try
        GTests[i].Run(GTests[i].Name);
        WriteLn('  [       OK ]');
        Inc(GStats.Passed);
      except
        on E: ETestFailure do
        begin
          WriteLn('  [  FAILED  ]');
          WriteLn('    ', E.Message);
          Inc(GStats.Failed);
        end;
        on E: Exception do
        begin
          WriteLn('  [  ERROR   ]');
          WriteLn('    ', E.ClassName, ': ', E.Message);
          Inc(GStats.Failed);
        end;
      end;
    except
      on E: Exception do
      begin
        WriteLn('  [ CRASHED  ] ', E.ClassName, ': ', E.Message);
        Inc(GStats.Failed);
      end;
    end;
  end;
  endTick := GetTickCount64;
  GStats.Duration := (endTick - startTick) / 1000.0;
  WriteLn('----------------------------------------------------------------');
  WriteLn(Format('  Total: %d  Passed: %d  Failed: %d  Skipped: %d  Time: %.3fs',
    [GStats.Total, GStats.Passed, GStats.Failed, GStats.Skipped, GStats.Duration]));
  WriteLn('================================================================');
  if GStats.Failed > 0 then
    Halt(1);
end;

procedure AssertTrue(const ACond: Boolean; const AMsg: string);
begin
  if not ACond then
    raise ETestFailure.Create('AssertTrue failed: ' + AMsg);
end;

procedure AssertFalse(const ACond: Boolean; const AMsg: string);
begin
  if ACond then
    raise ETestFailure.Create('AssertFalse failed: ' + AMsg);
end;

procedure AssertEquals(const AExpected, AActual: string; const AMsg: string);
begin
  if AExpected <> AActual then
    raise ETestFailure.CreateFmt(
      'AssertEquals failed: %s' + sLineBreak +
      '  expected: <%s>' + sLineBreak +
      '  actual:   <%s>',
      [AMsg, AExpected, AActual]);
end;

procedure AssertEqualsI(const AExpected, AActual: Int64; const AMsg: string);
begin
  if AExpected <> AActual then
    raise ETestFailure.CreateFmt(
      'AssertEqualsI failed: %s' + sLineBreak +
      '  expected: %d' + sLineBreak +
      '  actual:   %d',
      [AMsg, AExpected, AActual]);
end;

procedure AssertNil(const AObj: Pointer; const AMsg: string);
begin
  if AObj <> nil then
    raise ETestFailure.Create('AssertNil failed: ' + AMsg);
end;

procedure AssertNotNil(const AObj: Pointer; const AMsg: string);
begin
  if AObj = nil then
    raise ETestFailure.Create('AssertNotNil failed: ' + AMsg);
end;

procedure AssertSameStr(const AExpected, AActual: string; const AMsg: string);
begin
  AssertEquals(AExpected, AActual, AMsg);
end;

procedure Fail(const AMsg: string);
begin
  raise ETestFailure.Create(AMsg);
end;

function FormatFloatStr(const v: Double): string;
begin
  Result := Format('%.6f', [v]);
end;

function StripCRLF(const s: string): string;
begin
  Result := StringReplace(StringReplace(s, #13#10, '\n', [rfReplaceAll]),
                           #10, '\n', [rfReplaceAll]);
end;

initialization
  ResetStats;

end.
