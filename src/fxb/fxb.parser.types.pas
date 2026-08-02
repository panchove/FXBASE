unit fxb.parser.types;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}

interface

uses
  SysUtils,
  Classes,
  fxb.tokens,
  fxb.errors,
  fxb.lexer,
  fxb.parser.context,
  fxb.parser.common;

type
  TTypeParser = class
  private
    FCtx: IParserContext;
  public
    constructor Create(const ACtx: IParserContext);
    function ParseDataType: string;
    function ParseTypeRef: string;
    function ParseParamList: TParamInfoArray;
    function ParseGenericArgs: TStringArray;
  end;

implementation

constructor TTypeParser.Create(const ACtx: IParserContext);
begin
  inherited Create;
  FCtx := ACtx;
end;

function TTypeParser.ParseDataType: string;
var
  inner: string;
begin
  if FCtx.Peek in [ttIdentifier, ttKeyword] then
  begin
    if FCtx.Peek = ttKeyword then
      Result := KeywordNames[FCtx.GetCurrent.Keyword]
    else
      Result := FCtx.GetCurrent.StrValue;
    FCtx.Advance;

    // Generic args: Type<T, U>
    if FCtx.Peek = ttLt then
    begin
      Result := Result + '<';
      FCtx.Advance;
      inner := ParseDataType();
      Result := Result + inner;
      while FCtx.Peek = ttComma do
      begin
        Result := Result + ',';
        FCtx.Advance;
        inner := ParseDataType();
        Result := Result + inner;
      end;
      if FCtx.Peek = ttGt then
      begin
        Result := Result + '>';
        FCtx.Advance;
      end;
    end;
  end
  else
    Result := '';
end;

function TTypeParser.ParseTypeRef: string;
begin
  Result := '';
  if FCtx.MatchKeyword(kwArray) then
  begin
    if FCtx.MatchKeyword(kwOf) then
      Result := 'ARRAY OF ' + ParseDataType
    else
      Result := 'ARRAY';
  end
  else
    Result := ParseDataType;
end;

function TTypeParser.ParseParamList: TParamInfoArray;
begin
  Result := nil;
  if FCtx.Peek <> ttLParen then Exit;
  FCtx.Advance; // '('
  if FCtx.Peek = ttRParen then
  begin
    FCtx.Advance;
    Exit;
  end;
  repeat
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].IsRef := False;
    if FCtx.MatchKeyword(kwRef) then
      Result[High(Result)].IsRef := True;
    if FCtx.Peek = ttIdentifier then
    begin
      Result[High(Result)].Name := FCtx.GetCurrent.StrValue;
      FCtx.Advance;
      if FCtx.Peek = ttColon then
      begin
        FCtx.Advance; // ':'
        Result[High(Result)].Typ := ParseTypeRef;
      end
      else if FCtx.MatchKeyword(kwAs) then
        Result[High(Result)].Typ := ParseTypeRef;
      if FCtx.Peek = ttComma then FCtx.Advance;
    end
    else
      FCtx.Error(FXB_EXPECTED_IDENT, 'Expected parameter name');
  until FCtx.Peek = ttRParen;
  FCtx.Consume(ttRParen, 'Expected ) after parameters');
end;

function TTypeParser.ParseGenericArgs: TStringArray;
begin
  Result := nil;
  if FCtx.Peek = ttLt then
  begin
    FCtx.Advance;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ParseDataType;
    while FCtx.Peek = ttComma do
    begin
      FCtx.Advance;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := ParseDataType;
    end;
    if FCtx.Peek = ttGt then FCtx.Advance;
  end;
end;

end.