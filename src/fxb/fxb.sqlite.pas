{
  fxb.sqlite.pas - Native SQLite wrapper for the FXBASE runtime.

  Links directly against libsqlite3 (the C library) via the system shared
  object (libsqlite3.so.0 on Linux, sqlite3.dll on Windows). No C API is
  reimplemented in Pascal; we only declare the C entry points we need.

  For a fully-embedded standalone binary, link the SQLite amalgamation
  statically (Fase 2.7); until then the runtime depends on the system
  libsqlite3 shared object, which is local (no network).

  Threading: SQLite is opened in serialized mode by default (threadsafe=1),
  which is sufficient for the single-threaded FXBASE runtime.
}
unit fxb.sqlite;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // Opaque handles (SQLite uses void* in C).
  PSqlite3 = Pointer;
  PStmt = Pointer;

  // Result codes (subset we care about).
  TSqliteCode = Integer;
const
  SQLITE_OK = 0;
  SQLITE_ERROR = 1;
  SQLITE_ROW = 100;
  SQLITE_DONE = 101;

  // Column type codes (sqlite3_column_type).
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT = 2;
  SQLITE_TEXT = 3;
  SQLITE_NULL = 5;

type
  // Minimal OO wrapper around a single SQLite database connection.
  TFXBSQLite = class
  private
    FDB: PSqlite3;
    FOpen: Boolean;
    FLastError: string;
    function GetErrMsg: string;
  public
    constructor Create;
    destructor Destroy; override;

    // Open (or create) a database file. Returns True on success.
    function Open(const FileName: string): Boolean;
    // Close the connection. Safe to call when not open.
    procedure Close;

    // Execute a statement that returns no rows (DDL/DML). Returns '' on
    // success, or the SQLite error message on failure.
    function Exec(const SQL: string): string;

    // Prepare a SQL statement for stepping. Returns nil on error (check
    // LastError). The caller must Finalize the returned statement.
    function Prepare(const SQL: string): PStmt;

    // Advance a prepared statement. Returns SQLITE_ROW / SQLITE_DONE /
    // or an error code.
    function Step(Stmt: PStmt): TSqliteCode;

    // Column accessors for the current row of Stmt.
    function ColumnCount(Stmt: PStmt): Integer;
    function ColumnInt(Stmt: PStmt; Col: Integer): Int64;
    function ColumnDouble(Stmt: PStmt; Col: Integer): Double;
    function ColumnText(Stmt: PStmt; Col: Integer): string;
    function ColumnType(Stmt: PStmt; Col: Integer): Integer;

    // Release a prepared statement.
    function Finalize(Stmt: PStmt): TSqliteCode;

    property IsOpen: Boolean read FOpen;
    property LastError: string read FLastError;
  end;

// Low-level C bindings (declared here so the backend can use them directly).
function sqlite3_open(filename: PChar; out db: PSqlite3): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_close(db: PSqlite3): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_exec(db: PSqlite3; sql: PChar; callback: Pointer; arg: Pointer;
  out errmsg: PChar): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_prepare_v2(db: PSqlite3; sql: PChar; nbytes: Integer;
  out stmt: PStmt; out tail: PChar): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_step(stmt: PStmt): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_column_count(stmt: PStmt): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_column_int(stmt: PStmt; col: Integer): Int64; cdecl; external 'libsqlite3.so.0';
function sqlite3_column_double(stmt: PStmt; col: Integer): Double; cdecl; external 'libsqlite3.so.0';
function sqlite3_column_text(stmt: PStmt; col: Integer): PChar; cdecl; external 'libsqlite3.so.0';
function sqlite3_column_type(stmt: PStmt; col: Integer): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_finalize(stmt: PStmt): Integer; cdecl; external 'libsqlite3.so.0';
function sqlite3_errmsg(db: PSqlite3): PChar; cdecl; external 'libsqlite3.so.0';
procedure sqlite3_free(ptr: PChar); cdecl; external 'libsqlite3.so.0';

implementation

constructor TFXBSQLite.Create;
begin
  inherited Create;
  FDB := nil;
  FOpen := False;
  FLastError := '';
end;

destructor TFXBSQLite.Destroy;
begin
  if FOpen then Close;
  inherited Destroy;
end;

function TFXBSQLite.GetErrMsg: string;
var
  p: PChar;
begin
  if FDB = nil then
    Result := 'database not open'
  else
  begin
    p := sqlite3_errmsg(FDB);
    if p <> nil then Result := StrPas(p) else Result := '';
  end;
end;

function TFXBSQLite.Open(const FileName: string): Boolean;
var
  rc: Integer;
begin
  FLastError := '';
  if FOpen then Close;
  rc := sqlite3_open(PChar(FileName), FDB);
  if rc <> SQLITE_OK then
  begin
    FLastError := GetErrMsg;
    FDB := nil;
    Result := False;
    Exit;
  end;
  FOpen := True;
  Result := True;
end;

procedure TFXBSQLite.Close;
begin
  if FDB <> nil then
  begin
    sqlite3_close(FDB);
    FDB := nil;
  end;
  FOpen := False;
end;

function TFXBSQLite.Exec(const SQL: string): string;
var
  rc: Integer;
  errmsg: PChar;
begin
  FLastError := '';
  errmsg := nil;
  if not FOpen then
  begin
    Result := 'database not open';
    FLastError := Result;
    Exit;
  end;
  rc := sqlite3_exec(FDB, PChar(SQL), nil, nil, errmsg);
  if rc <> SQLITE_OK then
  begin
    if errmsg <> nil then
    begin
      Result := StrPas(errmsg);
      sqlite3_free(errmsg);
    end
    else
      Result := ErrMsg;
    FLastError := Result;
    Exit;
  end;
  Result := '';
end;

function TFXBSQLite.Prepare(const SQL: string): PStmt;
var
  rc: Integer;
  stmt: PStmt;
  tail: PChar;
begin
  FLastError := '';
  Result := nil;
  if not FOpen then
  begin
    FLastError := 'database not open';
    Exit;
  end;
  rc := sqlite3_prepare_v2(FDB, PChar(SQL), Length(SQL) + 1, stmt, tail);
  if rc <> SQLITE_OK then
  begin
    FLastError := GetErrMsg;
    Exit;
  end;
  Result := stmt;
end;

function TFXBSQLite.Step(Stmt: PStmt): TSqliteCode;
begin
  Result := sqlite3_step(Stmt);
end;

function TFXBSQLite.ColumnCount(Stmt: PStmt): Integer;
begin
  Result := sqlite3_column_count(Stmt);
end;

function TFXBSQLite.ColumnInt(Stmt: PStmt; Col: Integer): Int64;
begin
  Result := sqlite3_column_int(Stmt, Col);
end;

function TFXBSQLite.ColumnDouble(Stmt: PStmt; Col: Integer): Double;
begin
  Result := sqlite3_column_double(Stmt, Col);
end;

function TFXBSQLite.ColumnText(Stmt: PStmt; Col: Integer): string;
var
  p: PChar;
begin
  p := sqlite3_column_text(Stmt, Col);
  if p <> nil then Result := StrPas(p) else Result := '';
end;

function TFXBSQLite.ColumnType(Stmt: PStmt; Col: Integer): Integer;
begin
  Result := sqlite3_column_type(Stmt, Col);
end;

function TFXBSQLite.Finalize(Stmt: PStmt): TSqliteCode;
begin
  Result := sqlite3_finalize(Stmt);
end;

// ---------------------------------------------------------------------------
// Runtime entry points called by generated code (emitted by the backend as
// `call fxb_sqlite_open` / `call fxb_sqlite_exec`). A single global connection
// is kept open for the lifetime of the program; the .db path comes from the
// compiler's --db-connection flag (embedded in the binary by the backend).
// ---------------------------------------------------------------------------
var
  GFXBDB: TFXBSQLite = nil;

function fxb_sqlite_open(const path: PChar): Integer; cdecl;
begin
  if GFXBDB = nil then
    GFXBDB := TFXBSQLite.Create;
  if GFXBDB.Open(StrPas(path)) then
    Result := 0
  else
    Result := 1;
end;

function fxb_sqlite_exec(const sql: PChar): Integer; cdecl;
begin
  if GFXBDB = nil then
  begin
    Result := 1;
    Exit;
  end;
  if GFXBDB.Exec(StrPas(sql)) = '' then
    Result := 0
  else
    Result := 1;
end;

procedure fxb_sqlite_close; cdecl;
begin
  if GFXBDB <> nil then
  begin
    GFXBDB.Close;
    GFXBDB.Free;
    GFXBDB := nil;
  end;
end;

end.
