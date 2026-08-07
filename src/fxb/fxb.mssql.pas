{
  fxb.mssql.pas - MSSQL ODBC wrapper for the FXBASE runtime.
  Uses Free Pascal's ODBC units (odbcsqldyn) to connect via ODBC.
  Requires tdsodbc + unixodbc system packages for MSSQL connectivity.
}
unit fxb.mssql;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  odbcsqldyn;

type
  // Opaque handles from ODBC
  PSQLHENV = PSQLHANDLE;
  PSQLHDBC = PSQLHANDLE;
  PSQLHSTMT = PSQLHANDLE;

  // Minimal OO wrapper around a single MSSQL/ODBC connection.
  TFXBMSSQL = class
  private
    FEnvHandle: SQLHENV;
    FDbcHandle: SQLHDBC;
    FStmtHandle: SQLHSTMT;
    FConnected: Boolean;
    FLastError: string;
    procedure CheckError(HandleType: SQLSMALLINT; Handle: SQLHANDLE; const Context: string);
  public
    constructor Create;
    destructor Destroy; override;

    // Connect to MSSQL via ODBC. Returns True on success.
    // ConnString: ODBC connection string, e.g.
    //   "Driver={ODBC Driver 17 for SQL Server};Server=localhost;Database=mydb;UID=sqlman;PWD=7767;"
    //   Or DSN-based: "DSN=MyMSSQL;UID=sqlman;PWD=7767;"
    function Connect(const ConnString: string): Boolean;
    procedure Disconnect;

    // Execute a statement that returns no rows (DDL/DML). Returns '' on
    // success, or the ODBC error message on failure.
    function Exec(const SQL: string): string;

    // Prepare a SQL statement for execution. Returns False on error (check
    // LastError). The caller must Finalize the returned statement.
    function Prepare(const SQL: string): Boolean;

    // Execute a prepared statement with parameters.
    // ParamValues: array of string values (empty string = NULL)
    function ExecPrepared(ParamValues: array of string): Boolean;

    // Fetch next row from a result. Returns True if row available.
    function Fetch: Boolean;

    // Column accessors for the current row.
    function FieldCount: Integer;
    function FieldIsNull(Col: Integer): Boolean;
    function FieldAsInt(Col: Integer): Int64;
    function FieldAsDouble(Col: Integer): Double;
    function FieldAsString(Col: Integer): string;
    function FieldType(Col: Integer): Integer;

    // Release a prepared statement.
    procedure Finalize;

    property LastError: string read FLastError;
    property Connected: Boolean read FConnected;
  end;

  // Connection string builder helper for common MSSQL scenarios.
  function BuildMSSQLConnInfo(const Server, Database, User, Password: string;
    const Driver: string = 'ODBC Driver 17 for SQL Server'; Port: Integer = 1433): string;
  function BuildMSSQLConnInfoDSN(const DSN, User, Password: string): string;

implementation

procedure TFXBMSSQL.CheckError(HandleType: SQLSMALLINT; Handle: SQLHANDLE; const Context: string);
var
  State: array[0..5] of SQLCHAR;
  NativeError: SQLINTEGER;
  Msg: array[0..SQL_MAX_MESSAGE_LENGTH] of SQLCHAR;
  MsgLen: SQLSMALLINT;
  Ret: SQLRETURN;
begin
  FLastError := Context;
  repeat
    Ret := SQLGetDiagRec(HandleType, Handle, 1, @State[0], @NativeError,
      @Msg[0], SizeOf(Msg), @MsgLen);
    if (Ret = SQL_SUCCESS) or (Ret = SQL_SUCCESS_WITH_INFO) then
      FLastError := FLastError + ' [' + PAnsiChar(@State[0]) + '] ' + PAnsiChar(@Msg[0]);
  until Ret = SQL_NO_DATA;
end;

constructor TFXBMSSQL.Create;
begin
  inherited Create;
  FEnvHandle := SQL_NULL_HENV;
  FDbcHandle := SQL_NULL_HDBC;
  FStmtHandle := SQL_NULL_HSTMT;
  FConnected := False;
  FLastError := '';
end;

destructor TFXBMSSQL.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

function TFXBMSSQL.Connect(const ConnString: string): Boolean;
var
  Ret: SQLRETURN;
  OutConnStr: array[0..1023] of SQLCHAR;
  OutConnStrLen: SQLSMALLINT;
begin
  Result := False;
  FLastError := '';
  // Allocate environment
  Ret := SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HENV, @FEnvHandle);
  if Ret <> SQL_SUCCESS then
  begin
    FLastError := 'Failed to allocate ODBC environment';
    Exit;
  end;
  // Set ODBC version to 3.0
  Ret := SQLSetEnvAttr(FEnvHandle, SQL_ATTR_ODBC_VERSION, SQLPOINTER(SQL_OV_ODBC3), 0);
  if Ret <> SQL_SUCCESS then
  begin
    CheckError(SQL_HANDLE_ENV, FEnvHandle, 'SQLSetEnvAttr');
    SQLFreeHandle(SQL_HANDLE_ENV, FEnvHandle);
    FEnvHandle := SQL_NULL_HENV;
    Exit;
  end;
  // Allocate connection
  Ret := SQLAllocHandle(SQL_HANDLE_DBC, FEnvHandle, @FDbcHandle);
  if Ret <> SQL_SUCCESS then
  begin
    CheckError(SQL_HANDLE_ENV, FEnvHandle, 'SQLAllocHandle DBC');
    SQLFreeHandle(SQL_HANDLE_ENV, FEnvHandle);
    FEnvHandle := SQL_NULL_HENV;
    Exit;
  end;
  // Connect with connection string
  Ret := SQLDriverConnect(FDbcHandle, 0, PAnsiChar(AnsiString(ConnString)), SQL_NTS,
    @OutConnStr[0], SizeOf(OutConnStr), @OutConnStrLen, SQL_DRIVER_NOPROMPT);
  if (Ret <> SQL_SUCCESS) and (Ret <> SQL_SUCCESS_WITH_INFO) then
  begin
    CheckError(SQL_HANDLE_DBC, FDbcHandle, 'SQLDriverConnect');
    SQLFreeHandle(SQL_HANDLE_DBC, FDbcHandle);
    SQLFreeHandle(SQL_HANDLE_ENV, FEnvHandle);
    FDbcHandle := SQL_NULL_HDBC;
    FEnvHandle := SQL_NULL_HENV;
    Exit;
  end;
  FConnected := True;
  Result := True;
end;

procedure TFXBMSSQL.Disconnect;
begin
  if FStmtHandle <> SQL_NULL_HSTMT then
  begin
    SQLFreeHandle(SQL_HANDLE_STMT, FStmtHandle);
    FStmtHandle := SQL_NULL_HSTMT;
  end;
  if FDbcHandle <> SQL_NULL_HDBC then
  begin
    SQLDisconnect(FDbcHandle);
    SQLFreeHandle(SQL_HANDLE_DBC, FDbcHandle);
    FDbcHandle := SQL_NULL_HDBC;
  end;
  if FEnvHandle <> SQL_NULL_HENV then
  begin
    SQLFreeHandle(SQL_HANDLE_ENV, FEnvHandle);
    FEnvHandle := SQL_NULL_HENV;
  end;
  FConnected := False;
end;

function TFXBMSSQL.Exec(const SQL: string): string;
var
  Ret: SQLRETURN;
begin
  Result := '';
  if not FConnected then
  begin
    Result := 'Not connected';
    Exit;
  end;
  // Allocate statement handle
  Ret := SQLAllocHandle(SQL_HANDLE_STMT, FDbcHandle, @FStmtHandle);
  if Ret <> SQL_SUCCESS then
  begin
    CheckError(SQL_HANDLE_DBC, FDbcHandle, 'SQLAllocHandle STMT');
    Result := FLastError;
    Exit;
  end;
  // Execute directly
  Ret := SQLExecDirect(FStmtHandle, PAnsiChar(AnsiString(SQL)), SQL_NTS);
  if (Ret <> SQL_SUCCESS) and (Ret <> SQL_SUCCESS_WITH_INFO) then
  begin
    CheckError(SQL_HANDLE_STMT, FStmtHandle, 'SQLExecDirect');
    Result := FLastError;
    SQLFreeHandle(SQL_HANDLE_STMT, FStmtHandle);
    FStmtHandle := SQL_NULL_HSTMT;
    Exit;
  end;
  // Free statement handle
  SQLFreeHandle(SQL_HANDLE_STMT, FStmtHandle);
  FStmtHandle := SQL_NULL_HSTMT;
  Result := '';
end;

function TFXBMSSQL.Prepare(const SQL: string): Boolean;
var
  Ret: SQLRETURN;
begin
  Result := False;
  FLastError := '';
  if not FConnected then
  begin
    FLastError := 'Not connected';
    Exit;
  end;
  // Free any existing statement
  if FStmtHandle <> SQL_NULL_HSTMT then
  begin
    SQLFreeHandle(SQL_HANDLE_STMT, FStmtHandle);
    FStmtHandle := SQL_NULL_HSTMT;
  end;
  Ret := SQLAllocHandle(SQL_HANDLE_STMT, FDbcHandle, @FStmtHandle);
  if Ret <> SQL_SUCCESS then
  begin
    CheckError(SQL_HANDLE_DBC, FDbcHandle, 'SQLAllocHandle STMT');
    Exit;
  end;
  Ret := SQLPrepare(FStmtHandle, PAnsiChar(AnsiString(SQL)), SQL_NTS);
  if (Ret <> SQL_SUCCESS) and (Ret <> SQL_SUCCESS_WITH_INFO) then
  begin
    CheckError(SQL_HANDLE_STMT, FStmtHandle, 'SQLPrepare');
    SQLFreeHandle(SQL_HANDLE_STMT, FStmtHandle);
    FStmtHandle := SQL_NULL_HSTMT;
    Exit;
  end;
  Result := True;
end;

function TFXBMSSQL.ExecPrepared(ParamValues: array of string): Boolean;
var
  Ret: SQLRETURN;
  i: Integer;
  Param: PAnsiChar;
  StrLen: SQLLEN;
begin
  Result := False;
  FLastError := '';
  if FStmtHandle = SQL_NULL_HSTMT then
  begin
    FLastError := 'No prepared statement';
    Exit;
  end;
  // Bind parameters
  for i := 0 to High(ParamValues) do
  begin
    if ParamValues[i] = '' then
    begin
      // NULL parameter
      Ret := SQLBindParameter(FStmtHandle, i + 1, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_VARCHAR, 0, 0, nil, 0, @StrLen);
    end
    else
    begin
      Param := PAnsiChar(AnsiString(ParamValues[i]));
      StrLen := Length(ParamValues[i]);
      Ret := SQLBindParameter(FStmtHandle, i + 1, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_VARCHAR, Length(ParamValues[i]), 0, Param, 0, @StrLen);
    end;
    if (Ret <> SQL_SUCCESS) and (Ret <> SQL_SUCCESS_WITH_INFO) then
    begin
      CheckError(SQL_HANDLE_STMT, FStmtHandle, Format('SQLBindParameter %d', [i + 1]));
      Exit;
    end;
  end;
  // Execute
  Ret := SQLExecute(FStmtHandle);
  if (Ret <> SQL_SUCCESS) and (Ret <> SQL_SUCCESS_WITH_INFO) then
  begin
    CheckError(SQL_HANDLE_STMT, FStmtHandle, 'SQLExecute');
    Exit;
  end;
  Result := True;
end;

function TFXBMSSQL.Fetch: Boolean;
var
  Ret: SQLRETURN;
begin
  Result := False;
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  Ret := SQLFetch(FStmtHandle);
  if Ret = SQL_SUCCESS then
    Result := True
  else if Ret = SQL_SUCCESS_WITH_INFO then
    Result := True
  else if Ret = SQL_NO_DATA then
    Result := False
  else
    CheckError(SQL_HANDLE_STMT, FStmtHandle, 'SQLFetch');
end;

function TFXBMSSQL.FieldCount: Integer;
var
  Count: SQLSMALLINT;
  Ret: SQLRETURN;
begin
  Result := 0;
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  Ret := SQLNumResultCols(FStmtHandle, @Count);
  if Ret = SQL_SUCCESS then
    Result := Count
  else
    CheckError(SQL_HANDLE_STMT, FStmtHandle, 'SQLNumResultCols');
end;

function TFXBMSSQL.FieldIsNull(Col: Integer): Boolean;
var
  Ind: SQLLEN;
  Ret: SQLRETURN;
  Buf: array[0..4095] of SQLCHAR;
begin
  Result := True;
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  Ret := SQLGetData(FStmtHandle, Col, SQL_C_CHAR, @Buf[0], SizeOf(Buf), @Ind);
  if Ret = SQL_SUCCESS then
    Result := (Ind = SQL_NULL_DATA)
  else if Ret = SQL_SUCCESS_WITH_INFO then
    Result := (Ind = SQL_NULL_DATA)
  else
    Result := True;
end;

function TFXBMSSQL.FieldAsInt(Col: Integer): Int64;
var
  Ind: SQLLEN;
  Ret: SQLRETURN;
  Buf: array[0..63] of SQLCHAR;
begin
  Result := 0;
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  if FieldIsNull(Col) then Exit;
  Ret := SQLGetData(FStmtHandle, Col, SQL_C_CHAR, @Buf[0], SizeOf(Buf), @Ind);
  if (Ret = SQL_SUCCESS) or (Ret = SQL_SUCCESS_WITH_INFO) then
    Result := StrToInt64Def(PAnsiChar(@Buf[0]), 0);
end;

function TFXBMSSQL.FieldAsDouble(Col: Integer): Double;
var
  Ind: SQLLEN;
  Ret: SQLRETURN;
  Buf: array[0..63] of SQLCHAR;
begin
  Result := 0.0;
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  if FieldIsNull(Col) then Exit;
  Ret := SQLGetData(FStmtHandle, Col, SQL_C_CHAR, @Buf[0], SizeOf(Buf), @Ind);
  if (Ret = SQL_SUCCESS) or (Ret = SQL_SUCCESS_WITH_INFO) then
    Result := StrToFloatDef(PAnsiChar(@Buf[0]), 0.0);
end;

function TFXBMSSQL.FieldAsString(Col: Integer): string;
var
  Ind: SQLLEN;
  Ret: SQLRETURN;
  Buf: array[0..4095] of SQLCHAR;
begin
  Result := '';
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  if FieldIsNull(Col) then Exit;
  Ret := SQLGetData(FStmtHandle, Col, SQL_C_CHAR, @Buf[0], SizeOf(Buf), @Ind);
  if (Ret = SQL_SUCCESS) or (Ret = SQL_SUCCESS_WITH_INFO) then
    Result := PAnsiChar(@Buf[0]);
end;

function TFXBMSSQL.FieldType(Col: Integer): Integer;
var
  DataType: SQLSMALLINT;
  Ret: SQLRETURN;
begin
  Result := 0;
  if FStmtHandle = SQL_NULL_HSTMT then Exit;
  Ret := SQLDescribeCol(FStmtHandle, Col, nil, 0, nil, @DataType, nil, nil, nil);
  if Ret = SQL_SUCCESS then
    Result := DataType;
end;

procedure TFXBMSSQL.Finalize;
begin
  if FStmtHandle <> SQL_NULL_HSTMT then
  begin
    SQLFreeHandle(SQL_HANDLE_STMT, FStmtHandle);
    FStmtHandle := SQL_NULL_HSTMT;
  end;
end;

function BuildMSSQLConnInfo(const Server, Database, User, Password: string;
  const Driver: string = 'ODBC Driver 17 for SQL Server'; Port: Integer = 1433): string;
begin
  Result := Format('Driver={%s};Server=%s,%d;Database=%s;UID=%s;PWD=%s;',
    [Driver, Server, Port, Database, User, Password]);
end;

function BuildMSSQLConnInfoDSN(const DSN, User, Password: string): string;
begin
  Result := Format('DSN=%s;UID=%s;PWD=%s;', [DSN, User, Password]);
end;

end.