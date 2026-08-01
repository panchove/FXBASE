unit fxb.parser.types;

{$mode objfpc}{$H+}

interface

type
  TParamInfo = record
    Name: string;
    Typ: string;
    IsRef: Boolean;
  end;

  TParamInfoArray = array of TParamInfo;

implementation

end.