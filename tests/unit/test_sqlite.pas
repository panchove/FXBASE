program test_sqlite;

{$mode delphi}{$H+}

uses
  SysUtils, fxb.sqlite, fxb.test.framework;

// Fase 2.1: verify the native SQLite wrapper actually links against libsqlite3
// and can create a database, insert rows, and read them back. This exercises the
// real C library (not a mock) so a broken link or ABI mismatch fails here.
procedure TestSQLite_CRUD;
var
  db: TFXBSQLite;
  stmt: PStmt;
  rc: Integer;
  rows: string;
begin
  db := TFXBSQLite.Create;
  try
    if FileExists('/tmp/fxbase_sqlite_test.db') then DeleteFile('/tmp/fxbase_sqlite_test.db');
    AssertTrue(db.Open('/tmp/fxbase_sqlite_test.db'), 'abre/crea la base');
    AssertTrue(db.IsOpen, 'IsOpen tras Open');
    AssertEqualsI(0, Length(db.Exec('CREATE TABLE t(id INTEGER, name TEXT)')), 'CREATE TABLE sin error');
    AssertEqualsI(0, Length(db.Exec('INSERT INTO t VALUES(1, ''alice'')')), 'INSERT 1');
    AssertEqualsI(0, Length(db.Exec('INSERT INTO t VALUES(2, ''bob'')')), 'INSERT 2');

    stmt := db.Prepare('SELECT id, name FROM t ORDER BY id');
    AssertTrue(stmt <> nil, 'prepare SELECT');
    try
      rows := '';
      repeat
        rc := db.Step(stmt);
        if rc = SQLITE_ROW then
          rows := rows + IntToStr(db.ColumnInt(stmt, 0)) + ':' + db.ColumnText(stmt, 1) + ';';
      until rc <> SQLITE_ROW;
      AssertTrue(Pos('1:alice', rows) > 0, 'lee fila 1:alice');
      AssertTrue(Pos('2:bob', rows) > 0, 'lee fila 2:bob');
    finally
      db.Finalize(stmt);
    end;

    // Column type sanity: id is INTEGER, name is TEXT.
    stmt := db.Prepare('SELECT id, name FROM t WHERE id = 1');
    AssertTrue(stmt <> nil, 'prepare lookup');
    try
      rc := db.Step(stmt);
      AssertEqualsI(SQLITE_ROW, rc, 'step devuelve ROW');
      AssertEqualsI(SQLITE_INTEGER, db.ColumnType(stmt, 0), 'columna 0 es INTEGER');
      AssertEqualsI(SQLITE_TEXT, db.ColumnType(stmt, 1), 'columna 1 es TEXT');
      AssertEqualsI(1, db.ColumnInt(stmt, 0), 'id=1');
    finally
      db.Finalize(stmt);
    end;

    db.Close;
    AssertTrue(not db.IsOpen, 'cerrado');
  finally
    db.Free;
    if FileExists('/tmp/fxbase_sqlite_test.db') then DeleteFile('/tmp/fxbase_sqlite_test.db');
  end;
end;

begin
  RegisterTest('SQLite: CRUD via libsqlite3', @TestSQLite_CRUD);
  RunAllTests('SQLITE WRAPPER TESTS');
end.
