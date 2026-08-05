{
  fxb.postgresql.pas - Native PostgreSQL wrapper for the FXBASE runtime.

  Links directly against libpq (the PostgreSQL C library) via the system
  shared object (libpq.so.5 on Linux, libpq.dll on Windows). We declare
  the C entry points we need.

  For a fully-embedded standalone binary, link libpq statically
  (Fase 3.3); until then the runtime depends on the system
  libpq shared object, which is local (no network).

  Threading: libpq connections are not thread-safe; FXBASE runtime
  is single-threaded so this is sufficient.
}
unit fxb.postgresql;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // Opaque handles (PostgreSQL uses PGconn* and PGresult* in C).
  PPGconn = Pointer;
  PPGresult = Pointer;

  // Result status codes (subset we care about).
  TExecStatusType = Integer;
const
  PGRES_EMPTY_QUERY    = 0;
  PGRES_COMMAND_OK     = 1;
  PGRES_TUPLES_OK      = 2;
  PGRES_COPY_OUT       = 3;
  PGRES_COPY_IN        = 4;
  PGRES_BAD_RESPONSE   = 5;
  PGRES_NONFATAL_ERROR = 6;
  PGRES_FATAL_ERROR    = 7;
  PGRES_COPY_BOTH      = 8;
  PGRES_SINGLE_TUPLE   = 9;

  // Column type OIDs (common ones)
  PG_INT2   = 21;   // int2
  PG_INT4   = 23;   // int4
  PG_INT8   = 20;   // int8
  PG_FLOAT4 = 700;  // float4
  PG_FLOAT8 = 701;  // float8
  PG_TEXT   = 25;   // text
  PG_BOOL   = 16;   // bool
  PG_VARCHAR = 1043; // varchar
  PG_TIMESTAMP = 1114; // timestamp

type
  // Minimal OO wrapper around a single PostgreSQL connection.
  TFXBPostgreSQL = class
  private
    FConn: PPGconn;
    FOpen: Boolean;
    FLastError: string;
    function GetErrMsg: string;
  public
    constructor Create;
    destructor Destroy; override;

    // Connect to a database. Returns True on success.
    // ConnInfo: PostgreSQL connection string, e.g.
    //   "host=localhost port=5432 dbname=mydb user=myuser password=mypass"
    function Connect(const ConnInfo: string): Boolean;
    // Close the connection. Safe to call when not open.
    procedure Disconnect;

    // Execute a statement that returns no rows (DDL/DML). Returns '' on
    // success, or the PostgreSQL error message on failure.
    function Exec(const SQL: string): string;

    // Prepare a SQL statement for execution. Returns nil on error (check
    // LastError). The caller must Clear the returned result.
    function Prepare(const SQL: string): PPGresult;

    // Execute a prepared statement with parameters.
    // ParamValues: array of string values (NULL = nil)
    // Returns result or nil on error.
    function ExecPrepared(StmtName: string; ParamValues: array of string): PPGresult;

    // Fetch next row from a result. Returns True if row available.
    function Fetch(Res: PPGresult): Boolean;

    // Column accessors for the current row of Res.
    function FieldCount(Res: PPGresult): Integer;
    function FieldIsNull(Res: PPGresult; Col: Integer): Boolean;
    function FieldAsInt(Res: PPGresult; Col: Integer): Int64;
    function FieldAsDouble(Res: PPGresult; Col: Integer): Double;
    function FieldAsString(Res: PPGresult; Col: Integer): string;
    function FieldType(Res: PPGresult; Col: Integer): Integer;

    // Release a result.
    procedure Clear(Res: PPGresult);

    property LastError: string read FLastError;
    property IsConnected: Boolean read FOpen;
  end;

  // Connection string builder helper.
  function BuildPGConnInfo(const Host: string; Port: Integer; const DBName, User, Password: string): string;

implementation

// C declarations for libpq
function PQconnectdb(conninfo: PChar): PPGconn; cdecl; external 'libpq.so.5';
function PQfinish(conn: PPGconn): Pointer; cdecl; external 'libpq.so.5';
function PQstatus(conn: PPGconn): Integer; cdecl; external 'libpq.so.5';
function PQerrorMessage(conn: PPGconn): PChar; cdecl; external 'libpq.so.5';
function PQexec(conn: PPGconn; query: PChar): PPGresult; cdecl; external 'libpq.so.5';
function PQresultStatus(res: PPGresult): TExecStatusType; cdecl; external 'libpq.so.5';
function PQresultErrorMessage(res: PPGresult): PChar; cdecl; external 'libpq.so.5';
function PQntuples(res: PPGresult): Integer; cdecl; external 'libpq.so.5';
function PQnfields(res: PPGresult): Integer; cdecl; external 'libpq.so.5';
function PQfname(res: PPGresult; field_num: Integer): PChar; cdecl; external 'libpq.so.5';
function PQftype(res: PPGresult; field_num: Integer): Integer; cdecl; external 'libpq.so.5';
function PQgetvalue(res: PPGresult; row, field: Integer): PChar; cdecl; external 'libpq.so.5';
function PQgetisnull(res: PPGresult; row, field: Integer): Integer; cdecl; external 'libpq.so.5';
function PQclear(res: PPGresult): Pointer; cdecl; external 'libpq.so.5';
function PQprepare(conn: PPGconn; stmtName, query: PChar; nParams: Integer; paramTypes: Pointer): PPGresult; cdecl; external 'libpq.so.5';
function PQexecPrepared(conn: PPGconn; stmtName: PChar; nParams: Integer; paramValues: PPChar; paramLengths, paramFormats: Pointer; resultFormat: Integer): PPGresult; cdecl; external 'libpq.so.5';

constructor TFXBPostgreSQL.Create;
begin
  inherited Create;
  FConn := nil;
  FOpen := False;
  FLastError := '';
end;

destructor TFXBPostgreSQL.Destroy;
begin
  if FOpen then Disconnect;
  inherited Destroy;
end;

function TFXBPostgreSQL.GetErrMsg: string;
begin
  if FConn <> nil then
    Result := PQerrorMessage(FConn)
  else
    Result := FLastError;
end;

function TFXBPostgreSQL.Connect(const ConnInfo: string): Boolean;
begin
  FConn := PQconnectdb(PChar(ConnInfo));
  if FConn = nil then
  begin
    FLastError := 'Out of memory creating connection';
    FOpen := False;
    Exit(False);
  end;
  if PQstatus(FConn) <> 0 then // CONNECTION_OK = 0
  begin
    FLastError := 'Connection failed: ' + PQerrorMessage(FConn);
    PQfinish(FConn);
    FConn := nil;
    FOpen := False;
    Exit(False);
  end;
  FOpen := True;
  FLastError := '';
  Result := True;
end;

procedure TFXBPostgreSQL.Disconnect;
begin
  if FConn <> nil then
  begin
    PQfinish(FConn);
    FConn := nil;
    FOpen := False;
  end;
end;

function TFXBPostgreSQL.Exec(const SQL: string): string;
var
  res: PPGresult;
  status: TExecStatusType;
begin
  Result := '';
  if not FOpen then
  begin
    Result := 'Not connected';
    Exit;
  end;
  res := PQexec(FConn, PChar(SQL));
  if res = nil then
  begin
    Result := 'Out of memory executing query';
    Exit;
  end;
  status := PQresultStatus(res);
  if (status <> PGRES_COMMAND_OK) and (status <> PGRES_TUPLES_OK) then
  begin
    Result := PQresultErrorMessage(res);
    PQclear(res);
    Exit;
  end;
  PQclear(res);
  Result := '';
end;

function TFXBPostgreSQL.Prepare(const SQL: string): PPGresult;
var
  res: PPGresult;
begin
  Result := nil;
  if not FOpen then
  begin
    FLastError := 'Not connected';
    Exit;
  end;
  // Anonymous prepared statement (empty name = auto-generated)
  res := PQprepare(FConn, '', PChar(SQL), 0, nil);
  if res = nil then
  begin
    FLastError := 'Out of memory preparing statement';
    Exit;
  end;
  if PQresultStatus(res) <> PGRES_COMMAND_OK then
  begin
    FLastError := PQresultErrorMessage(res);
    PQclear(res);
    Exit;
  end;
  Result := res;
end;

function TFXBPostgreSQL.ExecPrepared(StmtName: string; ParamValues: array of string): PPGresult;
var
  res: PPGresult;
  i: Integer;
  paramValuesArr: array of PChar;
  paramLengthsArr: array of Integer;
  paramFormatsArr: array of Integer;
begin
  Result := nil;
  if not FOpen then
  begin
    FLastError := 'Not connected';
    Exit;
  end;
  SetLength(paramValuesArr, Length(ParamValues));
  SetLength(paramLengthsArr, Length(ParamValues));
  SetLength(paramFormatsArr, Length(ParamValues));
  for i := 0 to High(ParamValues) do
  begin
    if ParamValues[i] = '' then
    begin
      paramValuesArr[i] := nil;
      paramLengthsArr[i] := 0;
      paramFormatsArr[i] := 0; // text format
    end
    else
    begin
      paramValuesArr[i] := PChar(ParamValues[i]);
      paramLengthsArr[i] := Length(ParamValues[i]);
      paramFormatsArr[i] := 0; // text format
    end;
  end;
  res := PQexecPrepared(FConn, PChar(StmtName), Length(ParamValues),
    @paramValuesArr[0], @paramLengthsArr[0], @paramFormatsArr[0], 0);
  if res = nil then
  begin
    FLastError := 'Out of memory executing prepared statement';
    Exit;
  end;
  Result := res;
end;

function TFXBPostgreSQL.Fetch(Res: PPGresult): Boolean;
var
  status: TExecStatusType;
begin
  if Res = nil then Exit(False);
  status := PQresultStatus(Res);
  Result := (status = PGRES_TUPLES_OK);
end;

function TFXBPostgreSQL.FieldCount(Res: PPGresult): Integer;
begin
  if Res = nil then Exit(0);
  Result := PQnfields(Res);
end;

function TFXBPostgreSQL.FieldIsNull(Res: PPGresult; Col: Integer): Boolean;
begin
  if Res = nil then Exit(True);
  Result := PQgetisnull(Res, 0, Col) = 1;
end;

function TFXBPostgreSQL.FieldAsInt(Res: PPGresult; Col: Integer): Int64;
var
  val: PChar;
begin
  Result := 0;
  if Res = nil then Exit;
  if FieldIsNull(Res, Col) then Exit;
  val := PQgetvalue(Res, 0, Col);
  if val <> nil then Result := StrToInt64(val);
end;

function TFXBPostgreSQL.FieldAsDouble(Res: PPGresult; Col: Integer): Double;
var
  val: PChar;
begin
  Result := 0.0;
  if Res = nil then Exit;
  if FieldIsNull(Res, Col) then Exit;
  val := PQgetvalue(Res, 0, Col);
  if val <> nil then Result := StrToFloat(val);
end;

function TFXBPostgreSQL.FieldAsString(Res: PPGresult; Col: Integer): string;
var
  val: PChar;
begin
  Result := '';
  if Res = nil then Exit;
  if FieldIsNull(Res, Col) then Exit;
  val := PQgetvalue(Res, 0, Col);
  if val <> nil then Result := val;
end;

function TFXBPostgreSQL.FieldType(Res: PPGresult; Col: Integer): Integer;
begin
  if Res = nil then Exit(0);
  Result := PQftype(Res, Col);
end;

procedure TFXBPostgreSQL.Clear(Res: PPGresult);
begin
  if Res <> nil then PQclear(Res);
end;

function BuildPGConnInfo(const Host: string; Port: Integer; const DBName, User, Password: string): string;
begin
  Result := Format('host=%s port=%d dbname=%s user=%s password=%s',
    [Host, Port, DBName, User, Password]);
end;

end.