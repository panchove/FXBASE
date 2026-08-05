unit fxb.ast.base;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fxb.tokens;

type

  TASTNode = class
  protected
    FLine: Integer;
    FCol: Integer;
    FNodeId: Integer;
  public
    constructor Create(ALine, ACol: Integer); virtual;
    function Dump(Indent: Integer = 0): string; virtual; abstract;
    property Line: Integer read FLine;
    property Col: Integer read FCol;
  end;

  TExpr = class(TASTNode)
  public
    function Dump(Indent: Integer = 0): string; override;
  end;

  TStmt = class(TASTNode)
  public
    function Dump(Indent: Integer = 0): string; override;
  end;

  TExprArray = array of TExpr;
  TASTNodeArray = array of TASTNode;
  TASTNodeArrayArray = array of TASTNodeArray;

implementation

uses
  classes;

var
  NextNodeId: Integer = 1;

constructor TASTNode.Create(ALine, ACol: Integer);
begin
  inherited Create;
  FLine := ALine;
  FCol := ACol;
  // Thread-safe: parallel parsing assigns node ids from worker threads.
  FNodeId := InterLockedIncrement(NextNodeId);
end;

function TExpr.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'EXPR';
end;

function TStmt.Dump(Indent: Integer = 0): string;
begin
  Result := StringOfChar(' ', Indent * 2) + 'STMT';
end;

end.
