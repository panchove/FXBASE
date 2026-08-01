unit fxb.ir.types;

{$mode objfpc}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes;

type
  TIRValueKind = (
    vkConstant,
    vkArgument,
    vkLocal,
    vkGlobal,
    vkInstruction
  );

  TIRTypeKind = (
    tkVoid,
    tkBool,
    tkInt8, tkInt16, tkInt32, tkInt64,
    tkUInt8, tkUInt16, tkUInt32, tkUInt64,
    tkFloat32, tkFloat64,
    tkString,
    tkPointer,
    tkStruct,
    tkArray,
    tkAny
  );

  TIRType = record
    Kind: TIRTypeKind;
    StructName: string;
    ElementType: ^TIRType;
    IsRef: Boolean;
    function ToString: string;
    class function Void: TIRType; static;
    class function Bool: TIRType; static;
    class function Int(Signed: Boolean; Bits: Integer): TIRType; static;
    class function Float(Bits: Integer): TIRType; static;
    class function StringType: TIRType; static;
    class function Pointer(Element: TIRType): TIRType; static;
    class function Struct(const Name: string): TIRType; static;
    class function MakeArray(Element: TIRType): TIRType; static;
    class function AnyType: TIRType; static;
  end;

implementation

{ TIRType }

class function TIRType.Void: TIRType;
begin
  Result.Kind := tkVoid;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.Bool: TIRType;
begin
  Result.Kind := tkBool;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.Int(Signed: Boolean; Bits: Integer): TIRType;
begin
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
  if Signed then
  begin
    if Bits = 8 then Result.Kind := tkInt8
    else if Bits = 16 then Result.Kind := tkInt16
    else if Bits = 32 then Result.Kind := tkInt32
    else if Bits = 64 then Result.Kind := tkInt64
    else Result.Kind := tkInt32;
  end
  else
  begin
    if Bits = 8 then Result.Kind := tkUInt8
    else if Bits = 16 then Result.Kind := tkUInt16
    else if Bits = 32 then Result.Kind := tkUInt32
    else if Bits = 64 then Result.Kind := tkUInt64
    else Result.Kind := tkUInt32;
  end;
end;

class function TIRType.Float(Bits: Integer): TIRType;
begin
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
  if Bits = 32 then Result.Kind := tkFloat32
  else Result.Kind := tkFloat64;
end;

class function TIRType.StringType: TIRType;
begin
  Result.Kind := tkString;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.Pointer(Element: TIRType): TIRType;
begin
  Result.Kind := tkPointer;
  Result.StructName := '';
  New(Result.ElementType);
  Result.ElementType^ := Element;
  Result.IsRef := False;
end;

class function TIRType.Struct(const Name: string): TIRType;
begin
  Result.Kind := tkStruct;
  Result.StructName := Name;
  Result.ElementType := nil;
  Result.IsRef := False;
end;

class function TIRType.MakeArray(Element: TIRType): TIRType;
begin
  Result.Kind := tkArray;
  Result.StructName := '';
  New(Result.ElementType);
  Result.ElementType^ := Element;
  Result.IsRef := False;
end;

class function TIRType.AnyType: TIRType;
begin
  Result.Kind := tkAny;
  Result.StructName := '';
  Result.ElementType := nil;
  Result.IsRef := False;
end;

function TIRType.ToString: string;
begin
  case Kind of
    tkVoid: Result := 'void';
    tkBool: Result := 'bool';
    tkInt8: Result := 'i8';
    tkInt16: Result := 'i16';
    tkInt32: Result := 'i32';
    tkInt64: Result := 'i64';
    tkUInt8: Result := 'u8';
    tkUInt16: Result := 'u16';
    tkUInt32: Result := 'u32';
    tkUInt64: Result := 'u64';
    tkFloat32: Result := 'f32';
    tkFloat64: Result := 'f64';
    tkString: Result := 'string';
    tkPointer: Result := 'ptr ' + (ElementType^.ToString);
    tkStruct: Result := '%' + StructName;
    tkArray: Result := '[' + ElementType^.ToString + ']';
    tkAny: Result := 'any';
    else Result := 'unknown';
  end;
  if IsRef then Result := 'ref ' + Result;
end;

end.
