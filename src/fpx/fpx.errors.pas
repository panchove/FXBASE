unit fpx.errors;

{$mode objfpc}{$H+}

interface

type
  TErrorLevel = (elInfo, elWarning, elError, elFatal);

  TCompilerMessage = record
    Code: string;
    Level: TErrorLevel;
    Text: string;
    Line: Integer;
    Col: Integer;
    FileName: string;
  end;

  TCompilerMessageArray = array of TCompilerMessage;

function DumpMessage(constref M: TCompilerMessage): string;

type
  TErrorReporter = class
  private
    FMessages: TCompilerMessageArray;
    FErrorCount: Integer;
    FWarningCount: Integer;
    FSourceFile: string;
    procedure Add(Code: string; Level: TErrorLevel; const Text: string;
      Line, Col: Integer);
  public
    constructor Create(const SourceFile: string);
    procedure ErrorFPX(Code: Integer; const Text: string; Line, Col: Integer);
    procedure WarningFPW(Code: Integer; const Text: string; Line, Col: Integer);
    procedure Info(const Text: string; Line, Col: Integer);
    procedure Fatal(const Text: string; Line, Col: Integer);
    property ErrorCount: Integer read FErrorCount;
    property WarningCount: Integer read FWarningCount;
    property Messages: TCompilerMessageArray read FMessages;
    function HasErrors: Boolean;
    procedure PrintAll;
  end;

// FPX error codes (FPX-nnnn)
const
  FPX_SYNTAX_ERROR     = 1;
  FPX_UNEXPECTED_TOKEN = 2;
  FPX_UNTERMINATED_STR = 3;
  FPX_INVALID_CHAR     = 4;
  FPX_EXPECTED_IDENT   = 5;
  FPX_EXPECTED_EXPR    = 6;
  FPX_UNDEFINED_VAR    = 7;
  FPX_TYPE_MISMATCH    = 8;
  FPX_DUPLICATE_DEF    = 9;
  FPX_INVALID_OP       = 10;
  FPX_UNTERMINATED_BLOCK = 11;
  FPX_INVALID_DIRECTIVE = 12;
  FPX_MACRO_RECURSION  = 13;
  FPX_INCLUDE_NESTING  = 14;
  FPX_NO_ENTRY_POINT   = 15;
  FPX_UNSUPPORTED_FEATURE = 16;

  FPX_DESCRIPTIONS: array[1..16] of string = (
    'Syntax error',
    'Unexpected token',
    'Unterminated string literal',
    'Invalid character in source',
    'Expected identifier',
    'Expected expression',
    'Undefined variable',
    'Type mismatch',
    'Duplicate definition',
    'Invalid operator',
    'Unterminated block',
    'Invalid preprocessor directive',
    'Macro recursion limit exceeded',
    'Include nesting limit exceeded',
    'No entry point found',
    'Unsupported feature'
  );

// FPW warning codes (FPW-nnnn)
const
  FPW_LEGACY_COMMAND   = 1;
  FPW_IMPLICIT_VAR     = 2;
  FPW_IMPLICIT_PUBLIC  = 3;
  FPW_DEPRECATED       = 4;
  FPW_MODERNIZE        = 5;
  FPW_UNUSED_VAR       = 6;
  FPW_COMPARISON_TYPES = 7;

  FPW_DESCRIPTIONS: array[1..7] of string = (
    'Legacy command',
    'Implicit variable declaration',
    'Implicit PUBLIC variable',
    'Deprecated feature',
    'Suggestion: use modern syntax',
    'Unused variable',
    'Comparison between different types'
  );

implementation



constructor TErrorReporter.Create(const SourceFile: string);
begin
  inherited Create;
  FSourceFile := SourceFile;
  FErrorCount := 0;
  FWarningCount := 0;
end;

procedure TErrorReporter.Add(Code: string; Level: TErrorLevel;
  const Text: string; Line, Col: Integer);
var
  msg: TCompilerMessage;
begin
  msg.Code := Code;
  msg.Level := Level;
  msg.Text := Text;
  msg.Line := Line;
  msg.Col := Col;
  msg.FileName := FSourceFile;
  SetLength(FMessages, Length(FMessages) + 1);
  FMessages[High(FMessages)] := msg;

  case Level of
    elError, elFatal: Inc(FErrorCount);
    elWarning: Inc(FWarningCount);
  end;
end;

procedure TErrorReporter.ErrorFPX(Code: Integer; const Text: string;
  Line, Col: Integer);
var
  codeStr: string;
  desc: string;
begin
  if (Code >= Low(FPX_DESCRIPTIONS)) and (Code <= High(FPX_DESCRIPTIONS)) then
    desc := FPX_DESCRIPTIONS[Code]
  else
    desc := 'Unknown error';
  Str(Code, codeStr);
  while Length(codeStr) < 4 do
    codeStr := '0' + codeStr;
  codeStr := 'FPX-' + codeStr;
  Add(codeStr, elError, desc + ': ' + Text, Line, Col);
end;

procedure TErrorReporter.WarningFPW(Code: Integer; const Text: string;
  Line, Col: Integer);
var
  codeStr: string;
  desc: string;
begin
  if (Code >= Low(FPW_DESCRIPTIONS)) and (Code <= High(FPW_DESCRIPTIONS)) then
    desc := FPW_DESCRIPTIONS[Code]
  else
    desc := 'Unknown warning';
  Str(Code, codeStr);
  while Length(codeStr) < 4 do
    codeStr := '0' + codeStr;
  codeStr := 'FPW-' + codeStr;
  Add(codeStr, elWarning, desc + ': ' + Text, Line, Col);
end;

procedure TErrorReporter.Info(const Text: string; Line, Col: Integer);
begin
  Add('INFO', elInfo, Text, Line, Col);
end;

procedure TErrorReporter.Fatal(const Text: string; Line, Col: Integer);
begin
  Add('FATAL', elFatal, Text, Line, Col);
end;

function TErrorReporter.HasErrors: Boolean;
begin
  Result := FErrorCount > 0;
end;

procedure TErrorReporter.PrintAll;
var
  m: TCompilerMessage;
begin
  for m in FMessages do
    Writeln(StdErr, DumpMessage(m));
end;

function DumpMessage(constref M: TCompilerMessage): string;
const
  LevelNames: array[TErrorLevel] of string = ('INFO', 'WARN', 'ERROR', 'FATAL');
var
  lineStr, colStr, s: string;
begin
  if (M.Line > 0) and (M.Col > 0) then
  begin
    Str(M.Line, lineStr);
    Str(M.Col, colStr);
    s := M.FileName + '(' + lineStr + ',' + colStr + '): ';
  end
  else
    s := M.FileName + ': ';
  Result := s + LevelNames[M.Level] + ' ' + M.Code + ': ' + M.Text;
end;

end.
