unit fxb.parser.common;

{$mode objfpc}{$H+}

interface

type
  TParamInfo = record
    Name: string;
    Typ: string;
    IsRef: Boolean;
  end;

  TParamInfoArray = array of TParamInfo;
  TStringArray = array of string;

implementation

end.