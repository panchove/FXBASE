unit fxb.cache;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  MD5,
  fxb.tokens,
  fxb.ast,
  fxb.preprocessor,
  fxb.errors,
  fxb.ir,
  fxb.backend;

type
  TCacheEntryKind = (cekPPO, cekAST, cekIR, cekObject, cekSymbols);

  TCacheEntry = record
    Kind: TCacheEntryKind;
    SourceFile: string;
    ContentHash: string;
    ModTime: TDateTime;
    OutputFile: string;
    Dependencies: TStringArray;
    TargetOS: string;
    TargetCPU: string;
    Optimization: Integer;
    Debug: Boolean;
    EntryPoint: Boolean;
    Valid: Boolean;
  end;

  TCacheEntryArray = array of TCacheEntry;

  TFXBCache = class
  private
    FCacheDir: string;
    FEntries: TCacheEntryArray;
    FEntriesLock: TCriticalSection;
    FModified: Boolean;

    function GetCacheFileName(const ASourceFile: string; AKind: TCacheEntryKind): string;
    function ComputeHash(const AData: string): string;
    function ReadEntry(const ACacheFile: string; out AEntry: TCacheEntry): Boolean;
    procedure WriteEntry(const ACacheFile: string; const AEntry: TCacheEntry);
    function LoadDependencies(const ASourceFile: string): TStringArray;
    function ResolveInclude(const AName: string; const AIncludePaths: TStringList): string;
    // Key = hash(source text + include paths + defines + content of every
    // resolved #include dependency). Covers both source and dependency changes.
    function BuildKey(const ASourceFile: string; const AIncludePaths, ADefines: TStringList): string;
    function FindEntry(const ASourceFile: string; AKind: TCacheEntryKind): Integer;
  public
    constructor Create(const ACacheDir: string = '.fxbcache');
    destructor Destroy; override;

    // Keyed text snapshot cache (PPO, export-symbol snapshots). AKey is the
    // precomputed content key (see ComputeContentKey); when empty, BuildKey is
    // recomputed so callers can reuse a single read for multiple cache kinds.
    function GetCachedText(const ASourceFile: string; AKind: TCacheEntryKind;
      const AIncludePaths, ADefines: TStringList; const AKey: string; out AText: string): Boolean;
    procedure StoreCachedText(const ASourceFile: string; AKind: TCacheEntryKind;
      const AOutput: string; const AIncludePaths, ADefines: TStringList; const AKey: string);

    function GetPPO(const ASourceFile: string; var AOutput: string; const AIncludePaths: TStringList; const ADefines: TStringList): Boolean;
    function GetAST(const ASourceFile: string; var AAST: TCompilationUnit; const AIncludePaths: TStringList; const ADefines: TStringList): Boolean;
    function GetIR(const ASourceFile: string; var AIR: TIRModule; const AIncludePaths: TStringList; const ADefines: TStringList): Boolean;
    function GetObject(const ASourceFile: string; var AObjectFile: string; const AIncludePaths: TStringList; const ADefines: TStringList;
      const ATargetOS, ATargetCPU: string; AOptimization: Integer; ADebug: Boolean; AEntryPoint: Boolean;
      const AKey: string = ''): Boolean;

    procedure StorePPO(const ASourceFile: string; const AOutput: string; const AIncludePaths: TStringList; const ADefines: TStringList);
    procedure StoreAST(const ASourceFile: string; const AAST: TCompilationUnit; const AIncludePaths: TStringList; const ADefines: TStringList);
    procedure StoreIR(const ASourceFile: string; const AIR: TIRModule; const AIncludePaths: TStringList; const ADefines: TStringList);
    procedure StoreObject(const ASourceFile: string; const AObjectFile: string; const AIncludePaths: TStringList; const ADefines: TStringList;
      const ATargetOS, ATargetCPU: string; AOptimization: Integer; ADebug: Boolean; AEntryPoint: Boolean);

    procedure Invalidate(const ASourceFile: string);
    procedure InvalidateAll;
    procedure Save;
    procedure Load;
    // Public wrapper over BuildKey so pass 0 can compute each file's content
    // key once and reuse it for the symbol snapshot and object lookup.
    function ComputeContentKey(const ASourceFile: string; const AIncludePaths, ADefines: TStringList): string;

    property CacheDir: string read FCacheDir;
  end;

function FileHash(const AFileName: string): string;
function FileModTime(const AFileName: string): TDateTime;

implementation

function FileHash(const AFileName: string): string;
begin
  Result := MD5Print(MD5File(AFileName));
end;

// FPC RTL has no CopyFile helper; copy via streams.
function CopyFileData(const ASource, ADest: string): Boolean;
var
  inS, outS: TFileStream;
begin
  Result := False;
  try
    inS := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
    try
      if ExtractFilePath(ADest) <> '' then
        ForceDirectories(ExtractFilePath(ADest));
      outS := TFileStream.Create(ADest, fmCreate);
      try
        outS.CopyFrom(inS, 0);
      finally
        outS.Free;
      end;
    finally
      inS.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function FileModTime(const AFileName: string): TDateTime;
var
  info: TSearchRec;
begin
  Result := 0;
  if FindFirst(AFileName, faAnyFile, info) = 0 then
  begin
    Result := FileDateToDateTime(info.Time);
    FindClose(info);
  end;
end;

{ TFXBCache }

constructor TFXBCache.Create(const ACacheDir: string = '.fxbcache');
begin
  inherited Create;
  FCacheDir := ACacheDir;
  FEntries := nil;
  FEntriesLock := TCriticalSection.Create;
  FModified := False;

  if not DirectoryExists(FCacheDir) then
    ForceDirectories(FCacheDir);

  Load;
end;

destructor TFXBCache.Destroy;
begin
  if FModified then
    Save;
  FEntriesLock.Free;
  inherited Destroy;
end;

function TFXBCache.GetCacheFileName(const ASourceFile: string; AKind: TCacheEntryKind): string;
var
  kindStr: string;
  hash: string;
begin
  case AKind of
    cekPPO: kindStr := 'ppo';
    cekAST: kindStr := 'ast';
    cekIR: kindStr := 'ir';
    cekObject: kindStr := 'o';
    cekSymbols: kindStr := 's';
  end;

  hash := ComputeHash(ASourceFile);
  Result := FCacheDir + '/' + hash + '.' + kindStr + '.cache';
end;

function TFXBCache.ComputeHash(const AData: string): string;
begin
  Result := MD5Print(MD5String(AData));
end;

function TFXBCache.FindEntry(const ASourceFile: string; AKind: TCacheEntryKind): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FEntries) do
    if (FEntries[i].SourceFile = ASourceFile) and (FEntries[i].Kind = AKind) then
    begin
      Result := i;
      Exit;
    end;
end;

function TFXBCache.ReadEntry(const ACacheFile: string; out AEntry: TCacheEntry): Boolean;
var
  stream: TFileStream;
  reader: TReader;
  i: Integer;
  kindByte: Byte;
begin
  Result := False;
  if not FileExists(ACacheFile) then Exit;

  stream := TFileStream.Create(ACacheFile, fmOpenRead or fmShareDenyWrite);
  try
    reader := TReader.Create(stream, 4096);
    try
      try
        reader.Read(kindByte, 1);
        AEntry.Kind := TCacheEntryKind(kindByte);
        AEntry.SourceFile := reader.ReadString;
        AEntry.ContentHash := reader.ReadString;
        AEntry.ModTime := reader.ReadFloat;  // TDateTime is Double
        AEntry.OutputFile := reader.ReadString;

        SetLength(AEntry.Dependencies, reader.ReadInteger);
        for i := 0 to High(AEntry.Dependencies) do
          AEntry.Dependencies[i] := reader.ReadString;

        AEntry.TargetOS := reader.ReadString;
        AEntry.TargetCPU := reader.ReadString;
        AEntry.Optimization := reader.ReadInteger;
        AEntry.Debug := reader.ReadBoolean;
        // EntryPoint is a trailing field. Entries written before it existed
        // (or corrupted) raise below; they degrade to a cache miss instead
        // of crashing the build.
        AEntry.EntryPoint := reader.ReadBoolean;
        AEntry.Valid := reader.ReadBoolean;
        Result := True;
      except
        Result := False;
      end;
    finally
      reader.Free;
    end;
  finally
    stream.Free;
  end;
end;

procedure TFXBCache.WriteEntry(const ACacheFile: string; const AEntry: TCacheEntry);
var
  stream: TFileStream;
  writer: TWriter;
  i: Integer;
  kindByte: Byte;
begin
  stream := TFileStream.Create(ACacheFile, fmCreate);
  try
    writer := TWriter.Create(stream, 4096);
    try
      kindByte := Byte(AEntry.Kind);
      writer.Write(kindByte, 1);
      writer.WriteString(AEntry.SourceFile);
      writer.WriteString(AEntry.ContentHash);
      writer.WriteFloat(AEntry.ModTime);  // TDateTime is Double
      writer.WriteString(AEntry.OutputFile);

      writer.WriteInteger(Length(AEntry.Dependencies));
      for i := 0 to High(AEntry.Dependencies) do
        writer.WriteString(AEntry.Dependencies[i]);

      writer.WriteString(AEntry.TargetOS);
      writer.WriteString(AEntry.TargetCPU);
      writer.WriteInteger(AEntry.Optimization);
      writer.WriteBoolean(AEntry.Debug);
      writer.WriteBoolean(AEntry.EntryPoint);
      writer.WriteBoolean(AEntry.Valid);
    finally
      writer.Free;
    end;
  finally
    stream.Free;
  end;
end;

function TFXBCache.LoadDependencies(const ASourceFile: string): TStringArray;
var
  sl: TStringList;
  line: string;
  deps: TStringList;
  i: Integer;
begin
  Result := nil;
  deps := TStringList.Create;
  try
    sl := TStringList.Create;
    try
      sl.LoadFromFile(ASourceFile);
      for i := 0 to sl.Count - 1 do
      begin
        line := Trim(sl[i]);
        if (Length(line) >= 9) and (Copy(LowerCase(line), 1, 8) = '#include') then
        begin
          line := Trim(Copy(line, 9, Length(line)));
          if (line <> '') then
          begin
            if (line[1] = '"') or (line[1] = '<') then
              line := Copy(line, 2, Length(line) - 2);
            deps.Add(line);
          end;
        end;
      end;
    finally
      sl.Free;
    end;

    SetLength(Result, deps.Count);
    for i := 0 to deps.Count - 1 do
      Result[i] := deps[i];
  finally
    deps.Free;
  end;
end;

function TFXBCache.ResolveInclude(const AName: string; const AIncludePaths: TStringList): string;
var
  i: Integer;
begin
  Result := '';
  if FileExists(AName) then
  begin
    Result := AName;
    Exit;
  end;
  for i := 0 to AIncludePaths.Count - 1 do
  begin
    if FileExists(IncludeTrailingPathDelimiter(AIncludePaths[i]) + AName) then
    begin
      Result := IncludeTrailingPathDelimiter(AIncludePaths[i]) + AName;
      Exit;
    end;
  end;
end;

function TFXBCache.BuildKey(const ASourceFile: string; const AIncludePaths, ADefines: TStringList): string;
var
  sl: TStringList;
  deps: TStringArray;
  dep: string;
  depPath: string;
  i: Integer;
  hashData: string;
begin
  hashData := '';
  sl := TStringList.Create;
  try
    sl.LoadFromFile(ASourceFile);
    hashData := sl.Text;
  finally
    sl.Free;
  end;

  for i := 0 to AIncludePaths.Count - 1 do
    hashData := hashData + 'I:' + AIncludePaths[i];
  for i := 0 to ADefines.Count - 1 do
    hashData := hashData + 'D:' + ADefines.Names[i] + '=' + ADefines.ValueFromIndex[i];

  // Include the content of every resolved dependency so changes to headers
  // invalidate the entry even when the source file itself is unchanged.
  deps := LoadDependencies(ASourceFile);
  for dep in deps do
  begin
    depPath := ResolveInclude(dep, AIncludePaths);
    if depPath <> '' then
    begin
      hashData := hashData + 'F:' + depPath;
      sl := TStringList.Create;
      try
        sl.LoadFromFile(depPath);
        hashData := hashData + sl.Text;
      finally
        sl.Free;
      end;
    end;
  end;

  Result := ComputeHash(hashData);
end;

procedure TFXBCache.Load;
var
  sr: TSearchRec;
  entry: TCacheEntry;
begin
  if not DirectoryExists(FCacheDir) then Exit;

  FEntriesLock.Enter;
  try
    if FindFirst(FCacheDir + '/*.cache', faAnyFile, sr) = 0 then
    begin
      repeat
        if ReadEntry(FCacheDir + '/' + sr.Name, entry) then
        begin
          SetLength(FEntries, Length(FEntries) + 1);
          FEntries[High(FEntries)] := entry;
        end;
      until FindNext(sr) <> 0;
      FindClose(sr);
    end;
  finally
    FEntriesLock.Leave;
  end;
end;

procedure TFXBCache.Save;
var
  entry: TCacheEntry;
  cacheFile: string;
begin
  if not FModified then Exit;

  FEntriesLock.Enter;
  try
    for entry in FEntries do
    begin
      cacheFile := GetCacheFileName(entry.SourceFile, entry.Kind);
      WriteEntry(cacheFile, entry);
    end;
    FModified := False;
  finally
    FEntriesLock.Leave;
  end;
end;

function TFXBCache.ComputeContentKey(const ASourceFile: string; const AIncludePaths, ADefines: TStringList): string;
begin
  Result := BuildKey(ASourceFile, AIncludePaths, ADefines);
end;

function TFXBCache.GetCachedText(const ASourceFile: string; AKind: TCacheEntryKind;
  const AIncludePaths, ADefines: TStringList; const AKey: string; out AText: string): Boolean;
var
  cacheFile: string;
  entry: TCacheEntry;
  sl: TStringList;
  key: string;
begin
  Result := False;
  key := AKey;
  if key = '' then
    key := BuildKey(ASourceFile, AIncludePaths, ADefines);
  cacheFile := GetCacheFileName(ASourceFile, AKind);

  if not ReadEntry(cacheFile, entry) then Exit;
  if not entry.Valid then Exit;

  // Quick source modtime pre-check, then the authoritative content key.
  if entry.ModTime <> FileModTime(ASourceFile) then Exit;
  if entry.ContentHash <> key then Exit;

  if FileExists(entry.OutputFile) then
  begin
    sl := TStringList.Create;
    try
      sl.LoadFromFile(entry.OutputFile);
      AText := sl.Text;
      Result := True;
    finally
      sl.Free;
    end;
  end;
end;

procedure TFXBCache.StoreCachedText(const ASourceFile: string; AKind: TCacheEntryKind;
  const AOutput: string; const AIncludePaths, ADefines: TStringList; const AKey: string);
var
  entry: TCacheEntry;
  cacheFile: string;
  outputFile: string;
  sl: TStringList;
  deps: TStringArray;
  i: Integer;
  depPath: string;
  idx: Integer;
begin
  cacheFile := GetCacheFileName(ASourceFile, AKind);
  outputFile := cacheFile + '.out';

  FillChar(entry, SizeOf(entry), 0);

  sl := TStringList.Create;
  try
    sl.Text := AOutput;
    sl.SaveToFile(outputFile);
  finally
    sl.Free;
  end;

  // Store resolved dependency paths for diagnostics.
  deps := LoadDependencies(ASourceFile);
  SetLength(entry.Dependencies, Length(deps));
  for i := 0 to High(deps) do
  begin
    depPath := ResolveInclude(deps[i], AIncludePaths);
    if depPath <> '' then
      entry.Dependencies[i] := depPath
    else
      entry.Dependencies[i] := deps[i];
  end;

  entry.Kind := AKind;
  entry.SourceFile := ASourceFile;
  entry.ContentHash := AKey;
  entry.ModTime := FileModTime(ASourceFile);
  entry.OutputFile := outputFile;
  entry.TargetOS := '';
  entry.TargetCPU := '';
  entry.Optimization := 0;
  entry.Debug := False;
  entry.Valid := True;

  FEntriesLock.Enter;
  try
    idx := FindEntry(ASourceFile, AKind);
    if idx >= 0 then
      FEntries[idx] := entry
    else
    begin
      SetLength(FEntries, Length(FEntries) + 1);
      FEntries[High(FEntries)] := entry;
    end;
    FModified := True;
  finally
    FEntriesLock.Leave;
  end;
end;

function TFXBCache.GetPPO(const ASourceFile: string; var AOutput: string; const AIncludePaths: TStringList; const ADefines: TStringList): Boolean;
begin
  Result := GetCachedText(ASourceFile, cekPPO, AIncludePaths, ADefines,
    BuildKey(ASourceFile, AIncludePaths, ADefines), AOutput);
end;

procedure TFXBCache.StorePPO(const ASourceFile: string; const AOutput: string; const AIncludePaths: TStringList; const ADefines: TStringList);
begin
  StoreCachedText(ASourceFile, cekPPO, AOutput, AIncludePaths, ADefines,
    BuildKey(ASourceFile, AIncludePaths, ADefines));
end;

// AST/IR snapshots are intentionally not cached: GetObject short-circuits the
// whole frontend on the warm incremental path, so serializing .ast/.ir would add
// format surface without helping the Fase 0.5 criteria. Revisit for Fase 4.5
// (.fbu partial recompiles).
function TFXBCache.GetAST(const ASourceFile: string; var AAST: TCompilationUnit; const AIncludePaths: TStringList; const ADefines: TStringList): Boolean;
begin
  Result := False; // TODO: implement AST serialization
end;

procedure TFXBCache.StoreAST(const ASourceFile: string; const AAST: TCompilationUnit; const AIncludePaths: TStringList; const ADefines: TStringList);
begin
  // TODO: implement AST serialization
end;

function TFXBCache.GetIR(const ASourceFile: string; var AIR: TIRModule; const AIncludePaths: TStringList; const ADefines: TStringList): Boolean;
begin
  Result := False; // TODO: implement IR serialization
end;

procedure TFXBCache.StoreIR(const ASourceFile: string; const AIR: TIRModule; const AIncludePaths: TStringList; const ADefines: TStringList);
begin
  // TODO: implement IR serialization
end;

function TFXBCache.GetObject(const ASourceFile: string; var AObjectFile: string; const AIncludePaths: TStringList; const ADefines: TStringList;
  const ATargetOS, ATargetCPU: string; AOptimization: Integer; ADebug: Boolean; AEntryPoint: Boolean;
  const AKey: string): Boolean;
var
  idx: Integer;
  entry: TCacheEntry;
  key: string;
begin
  Result := False;
  key := AKey;
  if key = '' then
    key := BuildKey(ASourceFile, AIncludePaths, ADefines);

  // Look the entry up in the in-memory table (populated by Load on startup)
  // instead of re-reading the metadata file. Only the array access is under
  // the lock; the stat + key compare run outside it so parallel pass-1 cache
  // hits do not serialize on disk I/O.
  FEntriesLock.Enter;
  try
    idx := FindEntry(ASourceFile, cekObject);
    if idx < 0 then Exit;
    entry := FEntries[idx];
  finally
    FEntriesLock.Leave;
  end;

  if not entry.Valid then Exit;

  // The object entry must match flags AND the same content key as PPO.
  if entry.TargetOS <> ATargetOS then Exit;
  if entry.TargetCPU <> ATargetCPU then Exit;
  if entry.Optimization <> AOptimization then Exit;
  if entry.Debug <> ADebug then Exit;
  if entry.EntryPoint <> AEntryPoint then Exit;
  if entry.ModTime <> FileModTime(ASourceFile) then Exit;
  if entry.ContentHash <> key then Exit;

  if not FileExists(entry.OutputFile) then Exit;

  // Link against the cached object in place; the pipeline never copies it.
  AObjectFile := entry.OutputFile;
  Result := True;
end;

procedure TFXBCache.StoreObject(const ASourceFile: string; const AObjectFile: string; const AIncludePaths: TStringList; const ADefines: TStringList;
  const ATargetOS, ATargetCPU: string; AOptimization: Integer; ADebug: Boolean; AEntryPoint: Boolean);
var
  entry: TCacheEntry;
  cacheFile: string;
  outputFile: string;
  deps: TStringArray;
  i: Integer;
  depPath: string;
  idx: Integer;
begin
  if not FileExists(AObjectFile) then Exit;

  cacheFile := GetCacheFileName(ASourceFile, cekObject);
  outputFile := cacheFile + '.out';
  CopyFileData(AObjectFile, outputFile);

  FillChar(entry, SizeOf(entry), 0);

  deps := LoadDependencies(ASourceFile);
  SetLength(entry.Dependencies, Length(deps));
  for i := 0 to High(deps) do
  begin
    depPath := ResolveInclude(deps[i], AIncludePaths);
    if depPath <> '' then
      entry.Dependencies[i] := depPath
    else
      entry.Dependencies[i] := deps[i];
  end;

  entry.Kind := cekObject;
  entry.SourceFile := ASourceFile;
  entry.ContentHash := BuildKey(ASourceFile, AIncludePaths, ADefines);
  entry.ModTime := FileModTime(ASourceFile);
  entry.OutputFile := outputFile;
  entry.TargetOS := ATargetOS;
  entry.TargetCPU := ATargetCPU;
  entry.Optimization := AOptimization;
  entry.Debug := ADebug;
  entry.EntryPoint := AEntryPoint;
  entry.Valid := True;

  FEntriesLock.Enter;
  try
    idx := FindEntry(ASourceFile, cekObject);
    if idx >= 0 then
      FEntries[idx] := entry
    else
    begin
      SetLength(FEntries, Length(FEntries) + 1);
      FEntries[High(FEntries)] := entry;
    end;
    FModified := True;
  finally
    FEntriesLock.Leave;
  end;
end;

procedure TFXBCache.Invalidate(const ASourceFile: string);
var
  i: Integer;
begin
  FEntriesLock.Enter;
  try
    for i := High(FEntries) downto 0 do
      if FEntries[i].SourceFile = ASourceFile then
      begin
        FEntries[i].Valid := False;
        FModified := True;
      end;
  finally
    FEntriesLock.Leave;
  end;
end;

procedure TFXBCache.InvalidateAll;
var
  i: Integer;
begin
  FEntriesLock.Enter;
  try
    for i := 0 to High(FEntries) do
      FEntries[i].Valid := False;
    FModified := True;
  finally
    FEntriesLock.Leave;
  end;
end;

end.
