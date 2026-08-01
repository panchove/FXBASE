unit fxb.preprocessor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fxb.tokens, fxb.errors;

function FileExists(const filename: string): Boolean;
function ExtractFilePath(const filename: string): string;
function IncludeTrailingPathDelimiter(const path: string): string;
function LowerCase(const s: string): string;
function TrimLeft(const s: string): string;
function StringReplace(const s, oldPattern, newPattern: string; flags: array of string): string;

type
  TPreprocessorFlag = (pfDefined, pfUndefined);
  TPreprocessorFlags = set of TPreprocessorFlag;

  TMacroDef = record
    Name: string;
    Params: array of string;
    Body: string;
    IsFunction: Boolean;
  end;

  TMacroDefArray = array of TMacroDef;

  TCommandPattern = record
    Pattern: string;
    Translation: string;
    IsXMode: Boolean; // #xcommand / #xtranslate
  end;

  TCommandPatternArray = array of TCommandPattern;

  TFXBStringList = class
  private
    FStrings: array of string;
    FText: string;
    function GetName(index: Integer): string;
    function GetItems(index: Integer): string;
    procedure SetItems(index: Integer; const value: string);
    procedure SetValue(const name, value: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const s: string);
    procedure AddPair(const name, value: string);
    function IndexOfName(const name: string): Integer;
    procedure Delete(index: Integer);
    function Count: Integer;
    procedure Clear;
    procedure LoadFromFile(const filename: string);
    procedure SaveToFile(const filename: string);
    function GetText: string;
    procedure SetText(const value: string);
    property Values[const name: string]: string write SetValue;
    property Names[index: Integer]: string read GetName;
    property Items[index: Integer]: string read GetItems write SetItems; default;
    function ValueFromIndex(index: Integer): string;
    property Text: string read GetText write SetText;
  end;

  TPreprocessor = class
  private
    FReporter: TErrorReporter;
    FDefines: TFXBStringList; // keys: define name, values: body
    FMacros: TMacroDefArray;
    FCommands: TCommandPatternArray;
    FSourceLines: TStringArray;
    FIncludes: TFXBStringList;
    FIfdefStack: array of record
      Kind: string; // 'ifdef', 'ifndef'
      Active: Boolean;
      ElseSeen: Boolean;
    end;
    FActive: Boolean; // currently active block (not skipped by #ifdef)
    FLine: Integer;
    FOutput: TFXBStringList;
    FIncludePaths: TFXBStringList;

    function IsDirective(const Line: string): Boolean;
    function GetDirectiveName(const Line: string): string;
    function GetDirectiveArg(const Line: string): string;
    function ExpandDefines(const S: string): string;
    function MatchPattern(const Line: string; const Pat: TCommandPattern;
      out Bindings: array of string): Boolean;

    procedure HandleInclude(const Arg: string);
    procedure HandleDefine(const Arg: string);
    procedure HandleUndef(const Arg: string);
    procedure HandleIfdef(const Arg: string);
    procedure HandleIfndef(const Arg: string);
    procedure HandleElse;
    procedure HandleEndif;
    procedure HandleError(const Arg: string);
    procedure HandleStdout(const Arg: string);
    procedure HandleCommand(const Line: string);
    procedure HandleTranslate(const Line: string);
    procedure HandleXCommand(const Line: string);
    procedure HandleXTranslate(const Line: string);
    procedure ProcessLine(const Line: string);

  public
    constructor Create(Reporter: TErrorReporter);
    destructor Destroy; override;

    procedure AddIncludePath(const Path: string);
    function Process(const Source: string; const SourceFile: string): string;

    property Defines: TFXBStringList read FDefines;
    property Output: TFXBStringList read FOutput;
  end;

  EPreprocessorError = class(Exception);

implementation

function FileExists(const filename: string): Boolean;
var
  f: file;
begin
  Assign(f, filename);
  {$I-}
  Reset(f);
  {$I+}
  Result := IOResult = 0;
  if Result then Close(f);
end;

function ExtractFilePath(const filename: string): string;
var
  i: Integer;
begin
  Result := filename;
  for i := Length(filename) downto 1 do
    if filename[i] in ['/', '\'] then
    begin
      Result := Copy(filename, 1, i);
      Exit;
    end;
  Result := '';
end;

function IncludeTrailingPathDelimiter(const path: string): string;
begin
  Result := path;
  if (Result <> '') and not (Result[Length(Result)] in ['/', '\']) then
    Result := Result + '/';
end;

function LowerCase(const s: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := s;
  for i := 1 to Length(Result) do
  begin
    c := Result[i];
    if (c >= 'A') and (c <= 'Z') then
      Result[i] := Chr(Ord(c) + 32);
  end;
end;

function TrimLeft(const s: string): string;
var
  i: Integer;
begin
  i := 1;
  while (i <= Length(s)) and (s[i] in [#9, ' ']) do
    Inc(i);
  Result := Copy(s, i, MaxInt);
end;

function StringReplace(const s, oldPattern, newPattern: string; flags: array of string): string;
var
  i, idx: Integer;
  replaceAll, ignoreCase: Boolean;
  searchStr, targetStr: string;
begin
  replaceAll := False;
  ignoreCase := False;
  for idx := 0 to High(flags) do
  begin
    if flags[idx] = 'rfReplaceAll' then replaceAll := True;
    if flags[idx] = 'rfIgnoreCase' then ignoreCase := True;
  end;

  Result := s;
  if oldPattern = '' then Exit;

  if ignoreCase then
  begin
    searchStr := LowerCase(Result);
    targetStr := LowerCase(oldPattern);
  end
  else
  begin
    searchStr := Result;
    targetStr := oldPattern;
  end;

  i := 1;
  while True do
  begin
    idx := Pos(targetStr, Copy(searchStr, i, MaxInt));
    if idx = 0 then Break;
    idx := idx + i - 1;
    Delete(Result, idx, Length(oldPattern));
    Insert(newPattern, Result, idx);
    if ignoreCase then
      searchStr := LowerCase(Result);
    if not replaceAll then Break;
    i := idx + Length(newPattern);
    if i > Length(searchStr) then Break;
  end;
end;

{ TFXBStringList }

constructor TFXBStringList.Create;
begin
  inherited Create;
  FStrings := nil;
  FText := '';
end;

destructor TFXBStringList.Destroy;
begin
  FStrings := nil;
  inherited Destroy;
end;

procedure TFXBStringList.Add(const s: string);
begin
  SetLength(FStrings, Length(FStrings) + 1);
  FStrings[High(FStrings)] := s;
end;

procedure TFXBStringList.AddPair(const name, value: string);
begin
  SetLength(FStrings, Length(FStrings) + 1);
  FStrings[High(FStrings)] := name + '=' + value;
end;

function TFXBStringList.IndexOfName(const name: string): Integer;
var
  i: Integer;
  s: string;
begin
  Result := -1;
  for i := 0 to High(FStrings) do
  begin
    s := FStrings[i];
    if Copy(s, 1, Pos('=', s) - 1) = name then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TFXBStringList.Delete(index: Integer);
var
  i: Integer;
begin
  if (index < 0) or (index > High(FStrings)) then Exit;
  for i := index to High(FStrings) - 1 do
    FStrings[i] := FStrings[i + 1];
  SetLength(FStrings, Length(FStrings) - 1);
end;

function TFXBStringList.Count: Integer;
begin
  Result := Length(FStrings);
end;

function TFXBStringList.GetName(index: Integer): string;
var
  s: string;
  p: Integer;
begin
  if (index < 0) or (index > High(FStrings)) then Exit('');
  s := FStrings[index];
  p := Pos('=', s);
  if p > 0 then
    Result := Copy(s, 1, p - 1)
  else
    Result := s;
end;

procedure TFXBStringList.SetValue(const name, value: string);
var
  i: Integer;
begin
  i := IndexOfName(name);
  if i >= 0 then
    FStrings[i] := name + '=' + value
  else
    AddPair(name, value);
end;

function TFXBStringList.GetItems(index: Integer): string;
begin
  if (index < 0) or (index > High(FStrings)) then Exit('');
  Result := FStrings[index];
end;

procedure TFXBStringList.SetItems(index: Integer; const value: string);
begin
  if (index < 0) or (index > High(FStrings)) then Exit;
  FStrings[index] := value;
end;

procedure TFXBStringList.Clear;
begin
  SetLength(FStrings, 0);
  FText := '';
end;

function TFXBStringList.ValueFromIndex(index: Integer): string;
var
  s: string;
  p: Integer;
begin
  if (index < 0) or (index > High(FStrings)) then Exit('');
  s := FStrings[index];
  p := Pos('=', s);
  if p > 0 then
    Result := Copy(s, p + 1, MaxInt)
  else
    Result := '';
end;

constructor TPreprocessor.Create(Reporter: TErrorReporter);
begin
  inherited Create;
  FReporter := Reporter;
  FDefines := TFXBStringList.Create;
  FDefines.AddPair('__FXBASE__', '1');
  FDefines.AddPair('__FXBASE_VER__', '100');
  FDefines.AddPair('__LINE__', '0');
  FDefines.AddPair('__FILE__', '');
  FMacros := nil;
  FCommands := nil;
  FIncludes := TFXBStringList.Create;
  FIncludePaths := TFXBStringList.Create;
  FOutput := TFXBStringList.Create;
  FActive := True;
end;

destructor TPreprocessor.Destroy;
begin
  FDefines.Free;
  FIncludes.Free;
  FIncludePaths.Free;
  FOutput.Free;
  inherited;
end;

procedure TPreprocessor.AddIncludePath(const Path: string);
begin
  FIncludePaths.Add(Path);
end;

function TPreprocessor.IsDirective(const Line: string): Boolean;
var
  t: string;
begin
  t := TrimLeft(Line);
  Result := (t <> '') and (t[1] = '#');
end;

function TPreprocessor.GetDirectiveName(const Line: string): string;
var
  t: string;
  p: Integer;
begin
  t := TrimLeft(Line);
  if (t = '') or (t[1] <> '#') then Exit('');
  t := Trim(Copy(t, 2, Length(t)));
  p := Pos(' ', t);
  if p > 0 then
    Result := LowerCase(Copy(t, 1, p - 1))
  else
    Result := LowerCase(t);
end;

function TPreprocessor.GetDirectiveArg(const Line: string): string;
var
  t: string;
  p: Integer;
begin
  t := TrimLeft(Line);
  if (t = '') or (t[1] <> '#') then Exit('');
  t := Trim(Copy(t, 2, Length(t)));
  p := Pos(' ', t);
  if p > 0 then
    Result := Trim(Copy(t, p + 1, Length(t)))
  else
    Result := '';
end;

function TPreprocessor.ExpandDefines(const S: string): string;
var
  i: Integer;
  d: string;
begin
  Result := S;
  for i := 0 to FDefines.Count - 1 do
  begin
    d := FDefines.Names[i];
    if d <> '' then
    begin
      // Simple token replacement (word boundaries)
      Result := StringReplace(Result, d, FDefines.ValueFromIndex(i),
        ['rfReplaceAll', 'rfIgnoreCase']);
    end;
  end;
end;

function TPreprocessor.MatchPattern(const Line: string;
  const Pat: TCommandPattern; out Bindings: array of string): Boolean;
begin
  Result := False;
  // Stub — full pattern matching with markers <...>, [...] etc.
end;

procedure TPreprocessor.HandleInclude(const Arg: string);
var
  fn: string;
  s: string;
  fullPath: string;
  i: Integer;
  sl: TFXBStringList;
  j: Integer;
begin
  fn := Trim(Arg);
  if fn = '' then
  begin
    FReporter.ErrorFXB(FXB_INCLUDE_NESTING, 'Empty #include', FLine, 1);
    Exit;
  end;

  // Remove quotes if present
  if (fn[1] = '"') and (fn[Length(fn)] = '"') then
    fn := Copy(fn, 2, Length(fn) - 2)
  else if (fn[1] = '<') and (fn[Length(fn)] = '>') then
    fn := Copy(fn, 2, Length(fn) - 2);

  // Search in include paths
  fullPath := fn;
  for i := 0 to FIncludePaths.Count - 1 do
  begin
    if FileExists(IncludeTrailingPathDelimiter(FIncludePaths[i]) + fn) then
    begin
      fullPath := IncludeTrailingPathDelimiter(FIncludePaths[i]) + fn;
      Break;
    end;
  end;

  if not FileExists(fullPath) then
  begin
    FReporter.ErrorFXB(FXB_INCLUDE_NESTING, 'Include file not found: ' + fn, FLine, 1);
    Exit;
  end;

  sl := TFXBStringList.Create;
  try
    sl.LoadFromFile(fullPath);
    for j := 0 to sl.Count - 1 do
      ProcessLine(sl[j]);
  finally
    sl.Free;
  end;
end;

procedure TPreprocessor.HandleDefine(const Arg: string);
var
  name: string;
  body: string;
  p: Integer;
begin
  p := Pos(' ', Arg);
  if p > 0 then
  begin
    name := Trim(Copy(Arg, 1, p - 1));
    body := Trim(Copy(Arg, p + 1, Length(Arg)));
  end
  else
  begin
    name := Trim(Arg);
    body := '';
  end;
  FDefines.Values[name] := body;
end;

procedure TPreprocessor.HandleUndef(const Arg: string);
var
  i: Integer;
begin
  i := FDefines.IndexOfName(Trim(Arg));
  if i >= 0 then FDefines.Delete(i);
end;

procedure TPreprocessor.HandleIfdef(const Arg: string);
var
  defined: Boolean;
begin
  SetLength(FIfdefStack, Length(FIfdefStack) + 1);
  defined := FDefines.IndexOfName(Trim(Arg)) >= 0;
  FIfdefStack[High(FIfdefStack)].Kind := 'ifdef';
  FIfdefStack[High(FIfdefStack)].Active := FActive;
  FIfdefStack[High(FIfdefStack)].ElseSeen := False;
  if not FActive then
    FActive := False
  else
    FActive := defined;
end;

procedure TPreprocessor.HandleIfndef(const Arg: string);
var
  defined: Boolean;
begin
  SetLength(FIfdefStack, Length(FIfdefStack) + 1);
  defined := FDefines.IndexOfName(Trim(Arg)) >= 0;
  FIfdefStack[High(FIfdefStack)].Kind := 'ifndef';
  FIfdefStack[High(FIfdefStack)].Active := FActive;
  FIfdefStack[High(FIfdefStack)].ElseSeen := False;
  if not FActive then
    FActive := False
  else
    FActive := not defined;
end;

procedure TPreprocessor.HandleElse;
begin
  if Length(FIfdefStack) = 0 then
  begin
    FReporter.ErrorFXB(FXB_INVALID_DIRECTIVE, '#else without #ifdef', FLine, 1);
    Exit;
  end;
  with FIfdefStack[High(FIfdefStack)] do
  begin
    if ElseSeen then
    begin
      FReporter.ErrorFXB(FXB_INVALID_DIRECTIVE, 'Duplicate #else', FLine, 1);
      Exit;
    end;
    ElseSeen := True;
    FActive := (Kind = 'ifdef') and not Active;
  end;
end;

procedure TPreprocessor.HandleEndif;
begin
  if Length(FIfdefStack) = 0 then
  begin
    FReporter.ErrorFXB(FXB_INVALID_DIRECTIVE, '#endif without #ifdef', FLine, 1);
    Exit;
  end;
  with FIfdefStack[High(FIfdefStack)] do
    FActive := Active;
  SetLength(FIfdefStack, Length(FIfdefStack) - 1);
end;

procedure TPreprocessor.HandleError(const Arg: string);
begin
  FReporter.ErrorFXB(FXB_SYNTAX_ERROR, '#error: ' + Arg, FLine, 1);
end;

procedure TPreprocessor.HandleStdout(const Arg: string);
begin
  Writeln(Trim(Arg));
end;

procedure TPreprocessor.HandleCommand(const Line: string);
begin
  // Stub — #command pattern => translation
end;

procedure TPreprocessor.HandleTranslate(const Line: string);
begin
  // Stub — #translate pattern => translation
end;

procedure TPreprocessor.HandleXCommand(const Line: string);
begin
  // Stub — #xcommand pattern => translation
end;

procedure TPreprocessor.HandleXTranslate(const Line: string);
begin
  // Stub — #xtranslate pattern => translation
end;

procedure TPreprocessor.ProcessLine(const Line: string);
var
  dir: string;
  arg: string;
begin
  Inc(FLine);

  if not IsDirective(Line) then
  begin
    if FActive then
    begin
      FOutput.Add(ExpandDefines(Line));
    end;
    Exit;
  end;

  dir := GetDirectiveName(Line);
  arg := GetDirectiveArg(Line);

  if dir = 'include' then
    HandleInclude(arg)
  else if dir = 'define' then
    HandleDefine(arg)
  else if dir = 'undef' then
    HandleUndef(arg)
  else if dir = 'ifdef' then
    HandleIfdef(arg)
  else if dir = 'ifndef' then
    HandleIfndef(arg)
  else if dir = 'else' then
    HandleElse
  else if dir = 'endif' then
    HandleEndif
  else if dir = 'error' then
    HandleError(arg)
  else if dir = 'stdout' then
    HandleStdout(arg)
  else if dir = 'command' then
    HandleCommand(Line)
  else if dir = 'translate' then
    HandleTranslate(Line)
  else if dir = 'xcommand' then
    HandleXCommand(Line)
  else if dir = 'xtranslate' then
    HandleXTranslate(Line)
  else
  begin
    if FActive then
      FOutput.Add(Line); // pass through unknown directives
  end;
end;

function TPreprocessor.Process(const Source: string; const SourceFile: string): string;
var
  lines: TStringArray;
  line: string;
begin
  FOutput.Clear;
  FLine := 0;
  FActive := True;
  FDefines.Values['__FILE__'] := SourceFile;

  lines := Source.Split(LineEnding, TStringSplitOptions.None);
  for line in lines do
    ProcessLine(line);

  Result := FOutput.Text;
end;

{ TFXBStringList }

procedure TFXBStringList.LoadFromFile(const filename: string);
var
  f: TextFile;
  line: string;
begin
  Assign(f, filename);
  {$I-}
  Reset(f);
  {$I+}
  if IOResult <> 0 then Exit;
  FStrings := nil;
  FText := '';
  while not EOF(f) do
  begin
    Readln(f, line);
    SetLength(FStrings, Length(FStrings) + 1);
    FStrings[High(FStrings)] := line;
  end;
  Close(f);
  FText := '';
  for line in FStrings do
    FText := FText + line + LineEnding;
end;

procedure TFXBStringList.SaveToFile(const filename: string);
var
  f: TextFile;
  line: string;
begin
  Assign(f, filename);
  {$I-}
  Rewrite(f);
  {$I+}
  if IOResult <> 0 then Exit;
  for line in FStrings do
    Writeln(f, line);
  Close(f);
end;

function TFXBStringList.GetText: string;
begin
  Result := FText;
end;

procedure TFXBStringList.SetText(const value: string);
var
  lines: array of string;
  start, i, len: Integer;
  s: string;
begin
  FText := value;
  lines := nil;
  s := value;
  len := Length(s);
  start := 1;
  i := 1;
  while i <= len do
  begin
    if (s[i] = #10) or ((s[i] = #13) and (i < len) and (s[i+1] = #10)) then
    begin
      SetLength(lines, Length(lines) + 1);
      lines[High(lines)] := Copy(s, start, i - start);
      if (s[i] = #13) and (i < len) and (s[i+1] = #10) then
        Inc(i);
      start := i + 1;
    end
    else if (s[i] = #13) and ((i = len) or (s[i+1] <> #10)) then
    begin
      SetLength(lines, Length(lines) + 1);
      lines[High(lines)] := Copy(s, start, i - start);
      start := i + 1;
    end;
    Inc(i);
  end;
  if start <= len then
  begin
    SetLength(lines, Length(lines) + 1);
    lines[High(lines)] := Copy(s, start, len - start + 1);
  end;
  FStrings := lines;
end;

end.