unit fxb.parser.context;

{$mode objfpc}{$H+}

interface

uses
  fxb.tokens,
  fxb.lexer,
  fxb.errors,
  fxb.ast,
  fxb.parser.common;

type
  IParserContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetLexer: TLexer;
    function GetReporter: TErrorReporter;
    function GetCurrent: TToken;
    function GetPrevious: TToken;
    procedure SetCurrent(const AToken: TToken);
    procedure SetPrevious(const AToken: TToken);
    function Peek: TTokenType;
    function PeekToken(AOffset: Integer = 1): TToken;
    function Check(TT: TTokenType): Boolean;
    function CheckKeyword(kw: TKeyword): Boolean;
    function CheckAny(const TTs: array of TTokenType): Boolean;
    procedure Advance;
    procedure Match(TT: TTokenType);
    procedure Consume(TT: TTokenType; const Msg: string);
    procedure ConsumeKeyword(kw: TKeyword; const Msg: string);
    function MatchAdvance(TT: TTokenType): Boolean;
    function MatchKeyword(kw: TKeyword): Boolean;
    procedure Error(const Msg: string); overload;
    procedure Error(Code: Integer; const Msg: string); overload;
    // Delegated parsing helpers
    function ParseExpression: TExpr;
    function ParseTypeRef: string;
    function ParseGenericArgs: TStringArray;
    function ParseParamList: TParamInfoArray;
    function ParseDataType: string;
    function ParseStatement: TASTNode;
  end;

implementation

end.