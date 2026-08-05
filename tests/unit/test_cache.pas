program test_cache;

{$mode delphi}{$H+}

// Unit tests for fxb.cache: PPO/object round-trips, content-key invalidation
// (source and #include dependencies), flag sensitivity (target/optimization/
// debug/EntryPoint), explicit invalidation and on-disk persistence.

uses
  SysUtils,
  Classes,
  fxb.cache,
  fxb.test.framework;

const
  TEST_DIR = '/tmp/fxbase_cache_test';

function WriteFile(const ARelPath, AContent: string): string;
var
  full: string;
  sl: TStringList;
begin
  full := TEST_DIR + '/' + ARelPath;
  ForceDirectories(ExtractFilePath(full));
  sl := TStringList.Create;
  try
    sl.Text := AContent;
    sl.SaveToFile(full);
  finally
    sl.Free;
  end;
  Result := full;
end;

procedure DeleteDirRecursive(const ADir: string);
var
  sr: TSearchRec;
  path: string;
begin
  if not DirectoryExists(ADir) then Exit;
  if FindFirst(ADir + '/*', faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Name = '.') or (sr.Name = '..') then Continue;
      path := ADir + '/' + sr.Name;
      if (sr.Attr and faDirectory) <> 0 then
        DeleteDirRecursive(path)
      else
        DeleteFile(path);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  RemoveDir(ADir);
end;

procedure TestCache_PPO_RoundTrip;
var
  cache: TFXBCache;
  src: string;
  opts, defs: TStringList;
  outText: string;
begin
  src := WriteFile('main.fpg',
    'FUNCTION Main()' + LineEnding + '  ? "hi"' + LineEnding + 'ENDFUNC');
  opts := TStringList.Create;
  defs := TStringList.Create;
  cache := TFXBCache.Create(TEST_DIR + '/cache_ppo');
  try
    cache.StorePPO(src, 'PPO-CONTENT-' + LineEnding + 'PRINT "hi"', opts, defs);
    cache.Save; // Get* reads from disk, so the entry must be persisted first
    AssertTrue(cache.GetPPO(src, outText, opts, defs), 'PPO hit after store');
    AssertTrue(Pos('PRINT "hi"', outText) > 0, 'PPO content restored');
  finally
    cache.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_PPO_InvalidatesOnSourceChange;
var
  cache: TFXBCache;
  src: string;
  opts, defs: TStringList;
  outText: string;
begin
  src := WriteFile('main.fpg',
    'FUNCTION Main()' + LineEnding + '  ? "a"' + LineEnding + 'ENDFUNC');
  opts := TStringList.Create;
  defs := TStringList.Create;
  cache := TFXBCache.Create(TEST_DIR + '/cache_src');
  try
    cache.StorePPO(src, 'PPO-A', opts, defs);
    cache.Save;
    AssertTrue(cache.GetPPO(src, outText, opts, defs), 'hit before change');
    WriteFile('main.fpg',
      'FUNCTION Main()' + LineEnding + '  ? "b"' + LineEnding + 'ENDFUNC');
    AssertTrue(not cache.GetPPO(src, outText, opts, defs), 'miss after source change');
  finally
    cache.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_PPO_InvalidatesOnIncludeChange;
var
  cache: TFXBCache;
  src: string;
  opts, defs: TStringList;
  outText: string;
begin
  opts := TStringList.Create;
  opts.Add(TEST_DIR + '/inc');
  defs := TStringList.Create;
  WriteFile('inc/def.fbh', '#define X 1');
  src := WriteFile('main.fpg',
    '#include "def.fbh"' + LineEnding + 'FUNCTION Main()' + LineEnding + 'ENDFUNC');
  cache := TFXBCache.Create(TEST_DIR + '/cache_inc');
  try
    cache.StorePPO(src, 'PPO-1', opts, defs);
    cache.Save;
    AssertTrue(cache.GetPPO(src, outText, opts, defs), 'hit before header change');
    WriteFile('inc/def.fbh', '#define X 2');
    AssertTrue(not cache.GetPPO(src, outText, opts, defs), 'miss after header change');
  finally
    cache.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_Object_EntryPoint;
var
  cache: TFXBCache;
  src, obj: string;
  opts, defs: TStringList;
  outObj: string;
begin
  src := WriteFile('main.fpg', 'FUNCTION Main()' + LineEnding + 'ENDFUNC');
  obj := WriteFile('main.o', #1#2#3#4);
  opts := TStringList.Create;
  defs := TStringList.Create;
  cache := TFXBCache.Create(TEST_DIR + '/cache_entry');
  try
    cache.StoreObject(src, obj, opts, defs, 'linux', 'x86_64', 2, False, True);
    cache.Save;
    outObj := '';
    AssertTrue(cache.GetObject(src, outObj, opts, defs, 'linux', 'x86_64', 2, False, True),
      'object hit when EntryPoint matches');
    AssertTrue(FileExists(outObj), 'cached object restored to a file');
    AssertTrue(not cache.GetObject(src, outObj, opts, defs, 'linux', 'x86_64', 2, False, False),
      'object miss when EntryPoint differs');
  finally
    cache.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_Object_FlagSensitivity;
var
  cache: TFXBCache;
  src, obj: string;
  opts, defs: TStringList;
  outObj: string;
begin
  src := WriteFile('main.fpg', 'FUNCTION Main()' + LineEnding + 'ENDFUNC');
  obj := WriteFile('main.o', #9#8#7);
  opts := TStringList.Create;
  defs := TStringList.Create;
  cache := TFXBCache.Create(TEST_DIR + '/cache_flags');
  try
    cache.StoreObject(src, obj, opts, defs, 'linux', 'x86_64', 2, False, False);
    cache.Save;
    AssertTrue(not cache.GetObject(src, outObj, opts, defs, 'linux', 'x86_64', 3, False, False),
      'miss when optimization differs');
    AssertTrue(not cache.GetObject(src, outObj, opts, defs, 'linux', 'x86_64', 2, True, False),
      'miss when debug differs');
    AssertTrue(not cache.GetObject(src, outObj, opts, defs, 'windows', 'x86_64', 2, False, False),
      'miss when target OS differs');
    AssertTrue(not cache.GetObject(src, outObj, opts, defs, 'linux', 'x86', 2, False, False),
      'miss when target CPU differs');
  finally
    cache.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_Invalidate;
var
  cache: TFXBCache;
  src: string;
  opts, defs: TStringList;
  outText: string;
begin
  src := WriteFile('main.fpg', 'FUNCTION Main()' + LineEnding + 'ENDFUNC');
  opts := TStringList.Create;
  defs := TStringList.Create;
  cache := TFXBCache.Create(TEST_DIR + '/cache_inv');
  try
    cache.StorePPO(src, 'PPO-INV', opts, defs);
    cache.Save;
    AssertTrue(cache.GetPPO(src, outText, opts, defs), 'hit before Invalidate');
    cache.Invalidate(src);
    cache.Save;
    AssertTrue(not cache.GetPPO(src, outText, opts, defs), 'miss after Invalidate');
  finally
    cache.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_Persistence;
var
  cache1, cache2: TFXBCache;
  src: string;
  opts, defs: TStringList;
  outText: string;
begin
  src := WriteFile('main.fpg', 'FUNCTION Main()' + LineEnding + 'ENDFUNC');
  opts := TStringList.Create;
  defs := TStringList.Create;
  cache1 := TFXBCache.Create(TEST_DIR + '/cache_persist');
  try
    cache1.StorePPO(src, 'PPO-PERSIST', opts, defs);
    cache1.Free;
    cache1 := nil;

    cache2 := TFXBCache.Create(TEST_DIR + '/cache_persist');
    try
      AssertTrue(cache2.GetPPO(src, outText, opts, defs), 'PPO survives cache instance');
      AssertTrue(Pos('PPO-PERSIST', outText) > 0, 'content survives reload');
    finally
      cache2.Free;
    end;
  finally
    cache1.Free;
    opts.Free;
    defs.Free;
  end;
end;

procedure TestCache_FileHelpers;
var
  f: string;
begin
  f := WriteFile('blob.bin', 'some binary-ish content');
  AssertEqualsI(32, Length(FileHash(f)), 'FileHash is a 32-char MD5 hex');
  AssertTrue(FileModTime(f) > 0, 'FileModTime returns a real date');
end;

begin
  DeleteDirRecursive(TEST_DIR);
  try
    RegisterTest('Cache: PPO store/get round-trip', @TestCache_PPO_RoundTrip);
    RegisterTest('Cache: PPO invalidated on source change', @TestCache_PPO_InvalidatesOnSourceChange);
    RegisterTest('Cache: PPO invalidated on #include change', @TestCache_PPO_InvalidatesOnIncludeChange);
    RegisterTest('Cache: object EntryPoint round-trip', @TestCache_Object_EntryPoint);
    RegisterTest('Cache: object flag sensitivity', @TestCache_Object_FlagSensitivity);
    RegisterTest('Cache: Invalidate()', @TestCache_Invalidate);
    RegisterTest('Cache: persistence across instances', @TestCache_Persistence);
    RegisterTest('Cache: FileHash/FileModTime helpers', @TestCache_FileHelpers);
    RunAllTests('CACHE TESTS');
  finally
    DeleteDirRecursive(TEST_DIR);
  end;
end.
