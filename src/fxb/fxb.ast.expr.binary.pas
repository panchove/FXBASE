unit fxb.ast.expr.binary;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fxb.ast.base,
  fxb.tokens;

type
  TBinaryExpr = class(TExpr)
  private
    FLeft: TExpr;
    FOp: TTokenType;
    FRight: TExpr;
  public
    constructor Create(ALeft: TExpr; AOp: TTokenType; ARight: TExpr; ALine, ACol: Integer);
    destructor Destroy; override;
    function Dump(Indent: Integer = 0): string; override;
    property Left: TExpr read FLeft;
    property Op: TTokenType read FOp;
    property Right: TExpr read FRight;
  end;

implementation

constructor TBinaryExpr.Create(ALeft: TExpr; AOp: TTokenType; ARight: TExpr; ALine, ACol: Integer);
begin
  inherited Create(ALine, ACol);
  FLeft := ALeft;
  FOp := AOp;
  FRight := ARight;
end;

destructor TBinaryExpr.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

function TBinaryExpr.Dump(Indent: Integer = 0): string;
var
  pad: string;
begin
  pad := StringOfChar(' ', Indent * 2);
  Result := pad + 'BINARY ' + TokenTypeName(FOp) + LineEnding;
  Result := Result + FLeft.Dump(Indent + 1) + LineEnding;
  Result := Result + FRight.Dump(Indent + 1);
end;

end.