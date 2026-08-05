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
    function ToSQL: string; override;
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

function TBinaryExpr.ToSQL: string;
var
  leftSQL, rightSQL, opSQL: string;
begin
  leftSQL := FLeft.ToSQL();
  rightSQL := FRight.ToSQL();
  if (FOp = ttEq) or (FOp = ttEqual) then opSQL := '='
  else if (FOp = ttNeq) or (FOp = ttNeq2) then opSQL := '<>'
  else if FOp = ttLt then opSQL := '<'
  else if FOp = ttLe then opSQL := '<='
  else if FOp = ttGt then opSQL := '>'
  else if FOp = ttGe then opSQL := '>='
  else if FOp = ttPlus then opSQL := '+'
  else if FOp = ttMinus then opSQL := '-'
  else if FOp = ttStar then opSQL := '*'
  else if FOp = ttSlash then opSQL := '/'
  else if FOp = ttPercent then opSQL := '%'
  else if (FOp = ttDotAnd) or (FOp = ttAnd) then opSQL := 'AND'
  else if (FOp = ttDotOr) or (FOp = ttOr) then opSQL := 'OR'
  else opSQL := '?';
  Result := leftSQL + ' ' + opSQL + ' ' + rightSQL;
end;

end.