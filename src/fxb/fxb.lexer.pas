unit fxb.lexer;

{$mode objfpc}
{$modeSwitch advancedRecords}
{$modeSwitch typeHelpers}
{$H+}

interface

uses
  SysUtils,
  Classes,
  Generics.Collections,
  fxb.tokens;

type
  TKeywordMap = specialize TDictionary<string, TKeyword>;

  TFXBLexerError = record
    Message: string;
    Line: Integer;
    Column: Integer;
    FileName: string;
    Code: Integer;
    function ToString: string;
  end;

  TFXBLexerErrors = array of TFXBLexerError;

  TFXBLexer = class
  protected
    FSource: string;
    FFileName: string;
    FPos: Integer;
    FLine: Integer;
    FColumn: Integer;
    FTokens: TTokenArray;
    FNextIndex: Integer;
    FErrors: TFXBLexerErrors;
    FKeywordMap: TKeywordMap;
    FLegacyMode: Boolean;
    FStrictMode: Boolean;
    FDBAnsiMode: Boolean;
    procedure AddToken(const AType: TTokenType; const AValue: string);
    procedure AddTokenCopy(const Tok: TToken);
    procedure AddTokenFull(const AType: TTokenType; const AValue: string;
      IntVal: Int64; UIntVal: UInt64; RealVal: Double; const StrVal: string; Kw: TKeyword);
    procedure AddError(const AMsg: string; ACode: Integer = 1001);
    function CurrentChar: Char;
    function PeekChar(AOffset: Integer = 1): Char;
    procedure Advance;
    procedure SkipWhitespace;
    procedure SkipLineComment;
    procedure SkipBlockComment;
    function ScanIdentifier: TToken;
    function ScanNumber: TToken;
    function ScanString: TToken;
    function ScanRawString: TToken;
    function ScanOperator: TToken;
    function ScanDotOperator: TToken;
    function ScanTwoCharOperator: TToken;
    function ScanSingleCharOperator(const c: Char): TToken;
    function ScanPreprocessor: TToken;
    function ClassifyKeyword(const AIdent: string): TKeyword;
    procedure InitKeywords;
  public
    constructor Create;
    destructor Destroy; override;
    function Tokenize(const ASource, AFileName: string): Boolean;
    function NextToken: TToken;
    function PeekToken(AOffset: Integer = 1): TToken;
    function HasMoreTokens: Boolean;
    function EOF: Boolean;
    property Tokens: TTokenArray read FTokens;
    property Errors: TFXBLexerErrors read FErrors;
    function HasErrors: Boolean;
    property LegacyMode: Boolean read FLegacyMode write FLegacyMode;
    property StrictMode: Boolean read FStrictMode write FStrictMode;
    property DBAnsiMode: Boolean read FDBAnsiMode write FDBAnsiMode;
  end;

  TLexer = TFXBLexer;

implementation

function TFXBLexerError.ToString: string;
begin
  Result := Format('FXB-%0.4d [%s:%d:%d] %s', [Code, FileName, Line, Column, Message]);
end;

constructor TFXBLexer.Create;
begin
  inherited Create;
  FTokens := nil;
  FErrors := nil;
  FNextIndex := 0;
  FKeywordMap := TKeywordMap.Create;
  InitKeywords;
end;

destructor TFXBLexer.Destroy;
begin
  FKeywordMap.Free;
  inherited Destroy;
end;

procedure TFXBLexer.InitKeywords;
begin
  FKeywordMap.Add('USE', kwUse);
  FKeywordMap.Add('SELECT', kwSelect);
  FKeywordMap.Add('CLOSE', kwClose);
  FKeywordMap.Add('GOTO', kwGoto);
  FKeywordMap.Add('GO', kwGo);
  FKeywordMap.Add('SKIP', kwSkip);
  FKeywordMap.Add('LOCATE', kwLocate);
  FKeywordMap.Add('CONTINUE', kwContinue);
  FKeywordMap.Add('SEEK', kwSeek);
  FKeywordMap.Add('FIND', kwFind);
  FKeywordMap.Add('REPLACE', kwReplace);
  FKeywordMap.Add('APPEND', kwAppend);
  FKeywordMap.Add('INSERT', kwInsert);
  FKeywordMap.Add('DELETE', kwDelete);
  FKeywordMap.Add('RECALL', kwRecall);
  FKeywordMap.Add('PACK', kwPack);
  FKeywordMap.Add('ZAP', kwZap);
  FKeywordMap.Add('INDEX', kwIndex);
  FKeywordMap.Add('SET', kwSet);
  FKeywordMap.Add('SET INDEX', kwSetIndex);
  FKeywordMap.Add('SET ORDER', kwSetOrder);
  FKeywordMap.Add('SET RELATION', kwSetRelation);
  FKeywordMap.Add('SET FILTER', kwSetFilter);
  FKeywordMap.Add('SET DELETED', kwSetDeleted);
  FKeywordMap.Add('SET EXACT', kwSetExact);
  FKeywordMap.Add('SET SOFTSEEK', kwSetSoftSeek);
  FKeywordMap.Add('SET UNIQUE', kwSetUnique);
  FKeywordMap.Add('CLEAR', kwClear);
  FKeywordMap.Add('CLEAR ALL', kwClearAll);
  FKeywordMap.Add('CLEAR GETS', kwClearGets);
  FKeywordMap.Add('CLEAR MEMORY', kwClearMemory);
  FKeywordMap.Add('CLEAR SCREEN', kwClearScreen);
  FKeywordMap.Add('CLEAR TYPEAHEAD', kwClearTypeAhead);

  // Scope clauses (Fase 2.4)
  FKeywordMap.Add('ALL', kwAll);
  FKeywordMap.Add('REST', kwRest);

  FKeywordMap.Add('IF', kwIf);
  FKeywordMap.Add('ELSEIF', kwElseIf);
  FKeywordMap.Add('ELSE', kwElse);
  FKeywordMap.Add('ENDIF', kwEndIf);
  FKeywordMap.Add('DO', kwDo);
  FKeywordMap.Add('WHILE', kwWhile);
  FKeywordMap.Add('ENDDO', kwEndDo);
  FKeywordMap.Add('FOR', kwFor);
  FKeywordMap.Add('TO', kwTo);
  FKeywordMap.Add('STEP', kwStep);
  FKeywordMap.Add('ENDFOR', kwEndFor);
  FKeywordMap.Add('NEXT', kwNext);
  FKeywordMap.Add('FOREACH', kwForEach);
  FKeywordMap.Add('IN', kwIn);
  FKeywordMap.Add('ENDFOREACH', kwEndForEach);
  FKeywordMap.Add('SWITCH', kwSwitch);
  FKeywordMap.Add('CASE', kwCase);
  FKeywordMap.Add('DEFAULT', kwDefault);
  FKeywordMap.Add('ENDSWITCH', kwEndSwitch);
  FKeywordMap.Add('ENDCASE', kwEndCase);
  FKeywordMap.Add('EXIT', kwExit);
  FKeywordMap.Add('LOOP', kwLoop);
  FKeywordMap.Add('RETURN', kwReturn);
  FKeywordMap.Add('BREAK', kwBreak);
  FKeywordMap.Add('YIELD', kwYield);

  FKeywordMap.Add('FUNCTION', kwFunction);
  FKeywordMap.Add('PROCEDURE', kwProcedure);
  FKeywordMap.Add('ENDFUNC', kwEndFunc);
  FKeywordMap.Add('ENDFUNCTION', kwEndFunction);
  FKeywordMap.Add('ENDPROC', kwEndProc);
  FKeywordMap.Add('ENDPROCEDURE', kwEndProcedure);
  FKeywordMap.Add('LOCAL', kwLocal);
  FKeywordMap.Add('STATIC', kwStatic);
  FKeywordMap.Add('PUBLIC', kwPublic);
  FKeywordMap.Add('PRIVATE', kwPrivate);
  FKeywordMap.Add('MEMVAR', kwMemvar);
  FKeywordMap.Add('DATA', kwData);
  FKeywordMap.Add('PARAMETERS', kwParameters);
  FKeywordMap.Add('PARAM', kwParam);
  FKeywordMap.Add('VAR', kwVar);
  FKeywordMap.Add('OUT', kwOut);
  FKeywordMap.Add('REF', kwRef);

  FKeywordMap.Add('CLASS', kwClass);
  FKeywordMap.Add('ENDCLASS', kwEndClass);
  FKeywordMap.Add('METHOD', kwMethod);
  FKeywordMap.Add('ENDMETHOD', kwEndMethod);
  FKeywordMap.Add('PROPERTY', kwProperty);
  FKeywordMap.Add('NEW', kwNew);
  FKeywordMap.Add('THIS', kwThis);
  FKeywordMap.Add('SELF', kwThis);
  FKeywordMap.Add('SUPER', kwSuper);
  FKeywordMap.Add('INHERIT', kwInherit);
  FKeywordMap.Add('INTERFACE', kwInterface);
  FKeywordMap.Add('IMPLEMENTS', kwImplements);
  FKeywordMap.Add('ENDINTERFACE', kwEndInterface);
  FKeywordMap.Add('VIRTUAL', kwVirtual);
  FKeywordMap.Add('OVERRIDE', kwOverride);
  FKeywordMap.Add('ABSTRACT', kwAbstract);
  FKeywordMap.Add('CONST', kwConst);
  FKeywordMap.Add('READONLY', kwReadOnly);
  FKeywordMap.Add('CONSTRUCTOR', kwConstructor);
  FKeywordMap.Add('DESTRUCTOR', kwDestructor);
  FKeywordMap.Add('OPERATOR', kwOperator);

  FKeywordMap.Add('TYPE', kwType);
  FKeywordMap.Add('STRUCT', kwStruct);
  FKeywordMap.Add('ENDSTRUCT', kwEndStruct);
  FKeywordMap.Add('ENUM', kwEnum);
  FKeywordMap.Add('UNION', kwUnion);
  FKeywordMap.Add('TYPEDEF', kwTypedef);
  FKeywordMap.Add('ALIAS', kwAlias);
  FKeywordMap.Add('ARRAY', kwArray);
  FKeywordMap.Add('HASH', kwHash);
  FKeywordMap.Add('VECTOR', kwVector);
  FKeywordMap.Add('STACK', kwStack);
  FKeywordMap.Add('QUEUE', kwQueue);
  FKeywordMap.Add('RANGE', kwRange);
  FKeywordMap.Add('POINTER', kwPointer);
  FKeywordMap.Add('UNIQUE_PTR', kwUniquePtr);
  FKeywordMap.Add('SHARED_PTR', kwSharedPtr);
  FKeywordMap.Add('WEAK_PTR', kwWeakPtr);
  FKeywordMap.Add('OPTIONAL', kwOptional);
  FKeywordMap.Add('RESULT', kwResult);
  FKeywordMap.Add('NEWTYPE', kwNewType);
  FKeywordMap.Add('ENDNEWTYPE', kwEndNewType);
  FKeywordMap.Add('GENERIC', kwGeneric);
  FKeywordMap.Add('OF', kwOf);

  FKeywordMap.Add('VOID', kwVoid);
  FKeywordMap.Add('BOOL', kwBool);
  FKeywordMap.Add('LOGICAL', kwLogical);
  FKeywordMap.Add('BYTE', kwByte);
  FKeywordMap.Add('UBYTE', kwUByte);
  FKeywordMap.Add('SHORT', kwShort);
  FKeywordMap.Add('USHORT', kwUShort);
  FKeywordMap.Add('INT', kwInt);
  FKeywordMap.Add('UINT', kwUInt);
  FKeywordMap.Add('LONG', kwLong);
  FKeywordMap.Add('ULONG', kwULong);
  FKeywordMap.Add('INT64', kwInt64);
  FKeywordMap.Add('UINT64', kwUInt64);
  FKeywordMap.Add('INT128', kwInt128);
  FKeywordMap.Add('UINT128', kwUInt128);
  FKeywordMap.Add('FLOAT', kwFloat);
  FKeywordMap.Add('DOUBLE', kwDouble);
  FKeywordMap.Add('CURRENCY', kwCurrency);
  FKeywordMap.Add('NUMERIC', kwNumeric);
  FKeywordMap.Add('STRING', kwString);
  FKeywordMap.Add('MEMO', kwMemo);
  FKeywordMap.Add('DATE', kwDate);
  FKeywordMap.Add('DATETIME', kwDateTime);
  FKeywordMap.Add('TIME', kwTime);
  FKeywordMap.Add('VARIANT', kwVariant);
  FKeywordMap.Add('ANY', kwAny);
  FKeywordMap.Add('AUTO', kwAuto);

  FKeywordMap.Add('SQL', kwSql);
  FKeywordMap.Add('EXECUTE', kwExecute);
  FKeywordMap.Add('EXECUTE SQL', kwExecuteSql);
  FKeywordMap.Add('BEGIN TRANSACTION', kwBeginTransaction);
  FKeywordMap.Add('COMMIT', kwCommit);
  FKeywordMap.Add('ROLLBACK', kwRollback);
  FKeywordMap.Add('SAVEPOINT', kwSavepoint);
  FKeywordMap.Add('PREPARE', kwPrepare);
  FKeywordMap.Add('EXECUTE IMMEDIATE', kwExecuteImmediate);
  FKeywordMap.Add('FETCH', kwFetch);
  FKeywordMap.Add('CURSOR', kwCursor);
  FKeywordMap.Add('CONNECT', kwConnect);
  FKeywordMap.Add('DISCONNECT', kwDisconnect);
  FKeywordMap.Add('DATABASE', kwDatabase);
  FKeywordMap.Add('TABLE', kwTable);
  FKeywordMap.Add('CREATE', kwCreate);
  FKeywordMap.Add('DROP', kwDrop);
  FKeywordMap.Add('ALTER', kwAlter);
  FKeywordMap.Add('FROM', kwFrom);
  FKeywordMap.Add('WHERE', kwWhere);
  FKeywordMap.Add('JOIN', kwJoin);
  FKeywordMap.Add('INNER', kwInner);
  FKeywordMap.Add('LEFT', kwLeft);
  FKeywordMap.Add('RIGHT', kwRight);
  FKeywordMap.Add('FULL', kwFull);
  FKeywordMap.Add('ON', kwOn);
  FKeywordMap.Add('GROUP BY', kwGroupBy);
  FKeywordMap.Add('HAVING', kwHaving);
  FKeywordMap.Add('ORDER BY', kwOrderBy);
  FKeywordMap.Add('LIMIT', kwLimit);
  FKeywordMap.Add('OFFSET', kwOffset);
  FKeywordMap.Add('DISTINCT', kwDistinct);

  FKeywordMap.Add('TASK', kwTask);
  FKeywordMap.Add('ASYNC', kwAsync);
  FKeywordMap.Add('AWAIT', kwAwait);
  FKeywordMap.Add('PARALLEL', kwParallel);
  FKeywordMap.Add('CHANNEL', kwChannel);
  FKeywordMap.Add('SEND', kwSend);
  FKeywordMap.Add('RECEIVE', kwReceive);
  FKeywordMap.Add('MUTEX', kwMutex);
  FKeywordMap.Add('SEMAPHORE', kwSemaphore);
  FKeywordMap.Add('ATOMIC', kwAtomic);
  FKeywordMap.Add('THREAD_LOCAL', kwThreadLocal);
  FKeywordMap.Add('SPAWN', kwSpawn);
  FKeywordMap.Add('TRY', kwTry);
  FKeywordMap.Add('CATCH', kwCatch);
  FKeywordMap.Add('FINALLY', kwFinally);
  FKeywordMap.Add('ENDTRY', kwEndTry);
  FKeywordMap.Add('THROW', kwThrow);
  FKeywordMap.Add('RAISE', kwRaise);
  FKeywordMap.Add('WITH', kwWith);
  FKeywordMap.Add('USING', kwUsing);
  FKeywordMap.Add('DEFER', kwDefer);
  FKeywordMap.Add('MATCH', kwMatch);
  FKeywordMap.Add('WHEN', kwWhen);
  FKeywordMap.Add('LET', kwLet);

  FKeywordMap.Add('DEFINE', kwDefine);
  FKeywordMap.Add('INCLUDE', kwInclude);
  FKeywordMap.Add('IFDEF', kwIfdefPP);
  FKeywordMap.Add('IFNDEF', kwIfndefPP);
  FKeywordMap.Add('ELIF', kwElifPP);
  FKeywordMap.Add('UNDEF', kwUndef);
  FKeywordMap.Add('PRAGMA', kwPragma);
  FKeywordMap.Add('COMMAND', kwCommand);
  FKeywordMap.Add('TRANSLATE', kwTranslate);
  FKeywordMap.Add('XCOMMAND', kwXCommand);
  FKeywordMap.Add('XTRANSLATE', kwXTranslate);

  FKeywordMap.Add('TRUE', kwTrue);
  FKeywordMap.Add('FALSE', kwFalse);
  FKeywordMap.Add('NULL', kwNull);
  FKeywordMap.Add('NIL', kwNil);
  FKeywordMap.Add('EMPTY', kwEmpty);

  FKeywordMap.Add('.AND.', kwAnd);
  FKeywordMap.Add('.OR.', kwOr);
  FKeywordMap.Add('.NOT.', kwNot);
  FKeywordMap.Add('.XOR.', kwXor);
  FKeywordMap.Add('.EQ.', kwEq);
  FKeywordMap.Add('.NE.', kwNe);
  FKeywordMap.Add('.LT.', kwLt);
  FKeywordMap.Add('.LE.', kwLe);
  FKeywordMap.Add('.GT.', kwGt);
  FKeywordMap.Add('.GE.', kwGe);
  FKeywordMap.Add('.IN.', kwInOp);
  FKeywordMap.Add('.BETWEEN.', kwBetween);
  FKeywordMap.Add('.LIKE.', kwLike);
  FKeywordMap.Add('.MATCHES.', kwMatches);

  FKeywordMap.Add('EOF', kwEof);
  FKeywordMap.Add('BOF', kwBof);
  FKeywordMap.Add('FOUND', kwFound);
  FKeywordMap.Add('RECNO', kwRecno);
  FKeywordMap.Add('RECCOUNT', kwRecCount);
  FKeywordMap.Add('FIELDGET', kwFieldGet);
  FKeywordMap.Add('FIELDPUT', kwFieldPut);
  FKeywordMap.Add('FIELDNAME', kwFieldName);
  FKeywordMap.Add('FIELDCOUNT', kwFieldCount);
  FKeywordMap.Add('DELETED', kwDeleted);

  FKeywordMap.Add('TASKCREATE', kwTaskCreate);
  FKeywordMap.Add('TASKWAIT', kwTaskWait);
  FKeywordMap.Add('TASKYIELD', kwTaskYield);
  FKeywordMap.Add('SLEEP', kwSleep);
  FKeywordMap.Add('NOW', kwNow);
  FKeywordMap.Add('TODAY', kwToday);
  FKeywordMap.Add('SECONDS', kwSeconds);
  FKeywordMap.Add('MILLISECONDS', kwMilliseconds);

  FKeywordMap.Add('AS', kwAs);
  FKeywordMap.Add('IS', kwIs);
  FKeywordMap.Add('ALIGN', kwAlign);
  FKeywordMap.Add('PADDING', kwPadding);
  FKeywordMap.Add('STORE', kwStore);
  FKeywordMap.Add('ACCEPT', kwAccept);
  FKeywordMap.Add('WAIT', kwWait);
  FKeywordMap.Add('TEXT', kwText);
  FKeywordMap.Add('ENDTEXT', kwEndText);
  FKeywordMap.Add('INPUT', kwInput);
  FKeywordMap.Add('READ', kwRead);
  FKeywordMap.Add('SAY', kwSay);
  FKeywordMap.Add('GET', kwGet);
  FKeywordMap.Add('KEYBOARD', kwKeyboard);
  FKeywordMap.Add('RUN', kwRun);
  FKeywordMap.Add('CALL', kwCall);
  FKeywordMap.Add('QUIT', kwQuit);
  FKeywordMap.Add('CANCEL', kwCancel);
  FKeywordMap.Add('OPEN', kwOpen);
  FKeywordMap.Add('FLUSH', kwFlush);
  FKeywordMap.Add('EJECT', kwEject);
  FKeywordMap.Add('REPORT', kwReport);
  FKeywordMap.Add('FORM', kwForm);
  FKeywordMap.Add('LABEL', kwLabel);
  FKeywordMap.Add('SORT', kwSort);
  FKeywordMap.Add('AVERAGE', kwAverage);
  FKeywordMap.Add('SUM', kwSum);
  FKeywordMap.Add('COUNT', kwCount);
  FKeywordMap.Add('TOTAL', kwTotal);
  FKeywordMap.Add('COPY', kwCopy);
  FKeywordMap.Add('STRUCTURE', kwStructure);
  FKeywordMap.Add('ANNOUNCE', kwAnnounce);
  FKeywordMap.Add('REQUEST', kwRequest);
  FKeywordMap.Add('EXTERNAL', kwExternal);
  FKeywordMap.Add('INIT', kwInit);
  FKeywordMap.Add('DECLARE', kwDeclare);
  FKeywordMap.Add('WINDOW', kwWindow);
  FKeywordMap.Add('MENU', kwMenu);
  FKeywordMap.Add('PROMPT', kwPrompt);
  FKeywordMap.Add('ACTIVATE', kwActivate);
  FKeywordMap.Add('DEACTIVATE', kwDeactivate);
  FKeywordMap.Add('HIDE', kwHide);
  FKeywordMap.Add('SHOW', kwShow);
  FKeywordMap.Add('OBJECT', kwObject);
  FKeywordMap.Add('ENDWITH', kwEndWith);
  FKeywordMap.Add('BEGIN', kwBegin);
  FKeywordMap.Add('SEQUENCE', kwSequence);
  FKeywordMap.Add('RECOVER', kwRecover);
  FKeywordMap.Add('END', kwEnd);
  FKeywordMap.Add('FIELD', kwField);
  FKeywordMap.Add('STRICT', kwStrict);
  FKeywordMap.Add('DOWNTO', kwDownTo);
end;

function TFXBLexer.Tokenize(const ASource, AFileName: string): Boolean;
var
  c: Char;
  tok: TToken;
begin
  FSource := ASource;
  FFileName := AFileName;
  FPos := 1;
  FLine := 1;
  FColumn := 1;
  SetLength(FTokens, 0);
  SetLength(FErrors, 0);
  FNextIndex := 0;

  while FPos <= Length(FSource) do
  begin
    SkipWhitespace;

    if FPos > Length(FSource) then
      Break;
    if (FSource[FPos] = #10) or (FSource[FPos] = #13) then
    begin
      AddToken(ttNewline, #10);
      // consume all consecutive CR/LF
      while (FPos <= Length(FSource)) and ((FSource[FPos] = #10) or (FSource[FPos] = #13)) do
        Advance;
      Continue;
    end;
    if (FColumn = 1) and (FSource[FPos] = '#') then
    begin
      tok := ScanPreprocessor;
      AddTokenFull(tok.TokenType, '', 0, 0, 0.0, '', tok.Keyword);
      Continue;
    end;

    if (FPos + 1 <= Length(FSource)) then
    begin
      if (FSource[FPos] = '/') and (FSource[FPos + 1] = '/') then
      begin
        SkipLineComment;
        Continue;
      end
      else if (FSource[FPos] = '*') and (FColumn = 1) then
      begin
        SkipLineComment;
        Continue;
      end;
    end;

    if (FPos + 1 <= Length(FSource)) and (FSource[FPos] = '/') and (FSource[FPos + 1] = '*') then
    begin
      SkipBlockComment;
      Continue;
    end;

    c := CurrentChar;
    case c of
      '0'..'9':
      begin
        tok := ScanNumber;
        AddTokenCopy(tok);
      end;
      '"', '''', '[':
      begin
        if (c = '[') and (FPos + 1 <= Length(FSource)) and (FSource[FPos + 1] <> ']') then
        begin
          tok := ScanString;
          AddTokenCopy(tok);
        end
        else if c = '[' then
          AddToken(ttLBracket, '[')
        else
        begin
          tok := ScanString;
          AddTokenCopy(tok);
        end;
      end;
      'a'..'z', 'A'..'Z', '_':
      begin
        if ((c = 'r') or (c = 'R')) and (FPos + 1 <= Length(FSource))
          and ((FSource[FPos + 1] = '"') or (FSource[FPos + 1] = '''')) then
        begin
          tok := ScanRawString;
          AddTokenFull(tok.TokenType, '', 0, 0, 0.0, tok.StrValue, kwNone);
        end
        else
        begin
          tok := ScanIdentifier;
          if tok.Keyword = kwNil then
          begin
            tok.TokenType := ttNil;
            AddTokenCopy(tok);
          end
          else
            AddTokenCopy(tok);
        end;
      end;
      '@':
        AddToken(ttAt, '@');
      '.', ',', ';', ':', '(', ')', ']', '{', '}', '?',
      '+', '-', '*', '/', '\', '%', '^', '=', '<', '>', '!',
      '&', '|', '~', '#', '$':
      begin
        tok := ScanOperator;
        AddTokenCopy(tok);
      end;
      else
      begin
        AddError(Format('Unexpected character: %s', [c]), 1002);
        Advance;
      end;
    end;
  end;

  Result := Length(FErrors) = 0;
end;

function TFXBLexer.NextToken: TToken;
begin
  if FNextIndex < Length(FTokens) then
  begin
    Result := FTokens[FNextIndex];
    Inc(FNextIndex);
  end
  else
  begin
    Result.TokenType := ttEof;
    Result.Keyword := kwNone;
    Result.IntValue := 0;
    Result.RealValue := 0.0;
    Result.StrValue := '';
    Result.Line := FLine;
    Result.Col := FColumn;
    Result.FileName := FFileName;
    Result.Flags := [];
  end;
end;

function TFXBLexer.PeekToken(AOffset: Integer = 1): TToken;
begin
  if FNextIndex + AOffset < Length(FTokens) then
    Result := FTokens[FNextIndex + AOffset]
  else
  begin
    Result.TokenType := ttEof;
    Result.Keyword := kwNone;
    Result.IntValue := 0;
    Result.RealValue := 0.0;
    Result.StrValue := '';
    Result.Line := FLine;
    Result.Col := FColumn;
    Result.FileName := FFileName;
    Result.Flags := [];
  end;
end;

function TFXBLexer.HasMoreTokens: Boolean;
begin
  Result := FNextIndex < Length(FTokens);
end;

function TFXBLexer.EOF: Boolean;
begin
  Result := (FNextIndex >= Length(FTokens)) or
    ((Length(FTokens) > 0) and (FTokens[High(FTokens)].TokenType = ttEof) and
     (FNextIndex > High(FTokens)));
end;

procedure TFXBLexer.AddToken(const AType: TTokenType; const AValue: string);
var
  token: TToken;
begin
  token.TokenType := AType;
  token.Keyword := kwNone;
  token.IntValue := 0;
  token.UIntValue := 0;
  token.RealValue := 0.0;
  token.StrValue := AValue;
  token.Line := FLine;
  token.Col := FColumn - Length(AValue);
  token.FileName := FFileName;
  token.Flags := [];
  SetLength(FTokens, Length(FTokens) + 1);
  FTokens[High(FTokens)] := token;
end;

procedure TFXBLexer.AddTokenCopy(const Tok: TToken);
var
  token: TToken;
begin
  token.TokenType := Tok.TokenType;
  token.Keyword := Tok.Keyword;
  token.IntValue := Tok.IntValue;
  token.UIntValue := Tok.UIntValue;
  token.RealValue := Tok.RealValue;
  token.StrValue := Tok.StrValue;
  token.Line := FLine;
  token.Col := FColumn - Length(Tok.StrValue);
  token.FileName := FFileName;
  token.Flags := [];
  SetLength(FTokens, Length(FTokens) + 1);
  FTokens[High(FTokens)] := token;
end;

procedure TFXBLexer.AddTokenFull(const AType: TTokenType; const AValue: string;
  IntVal: Int64; UIntVal: UInt64; RealVal: Double; const StrVal: string; Kw: TKeyword);
var
  token: TToken;
begin
  token.TokenType := AType;
  token.Keyword := Kw;
  token.IntValue := IntVal;
  token.UIntValue := UIntVal;
  token.RealValue := RealVal;
  token.StrValue := StrVal;
  token.Line := FLine;
  token.Col := FColumn - Length(AValue);
  token.FileName := FFileName;
  token.Flags := [];
  SetLength(FTokens, Length(FTokens) + 1);
  FTokens[High(FTokens)] := token;
end;

procedure TFXBLexer.AddError(const AMsg: string; ACode: Integer);
var
  err: TFXBLexerError;
begin
  err.Message := AMsg;
  err.Line := FLine;
  err.Column := FColumn;
  err.FileName := FFileName;
  err.Code := ACode;
  SetLength(FErrors, Length(FErrors) + 1);
  FErrors[High(FErrors)] := err;
end;

function TFXBLexer.CurrentChar: Char;
begin
  if FPos <= Length(FSource) then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TFXBLexer.PeekChar(AOffset: Integer): Char;
var
  p: Integer;
begin
  p := FPos + AOffset;
  if p <= Length(FSource) then
    Result := FSource[p]
  else
    Result := #0;
end;

procedure TFXBLexer.Advance;
begin
  if FPos <= Length(FSource) then
  begin
    if FSource[FPos] = #10 then
    begin
      Inc(FLine);
      FColumn := 1;
    end
    else
      Inc(FColumn);
    Inc(FPos);
  end;
end;

procedure TFXBLexer.SkipWhitespace;
begin
  while (FPos <= Length(FSource)) and (FSource[FPos] in [#9, #32]) do
    Advance;
end;

procedure TFXBLexer.SkipLineComment;
begin
  while (FPos <= Length(FSource)) and (FSource[FPos] <> #10) and (FSource[FPos] <> #13) do
    Advance;
end;

procedure TFXBLexer.SkipBlockComment;
begin
  Advance;
  Advance;
  while (FPos + 1 <= Length(FSource)) do
  begin
    if (FSource[FPos] = '*') and (FSource[FPos + 1] = '/') then
    begin
      Advance;
      Advance;
      Break;
    end;
    Advance;
  end;
end;

function TFXBLexer.ClassifyKeyword(const AIdent: string): TKeyword;
begin
  if FKeywordMap.TryGetValue(AIdent, Result) then
    Exit;
  Result := kwNone;
end;

function TFXBLexer.ScanIdentifier: TToken;
var
  startPos, startLine, startCol: Integer;
  value: string;
  c: Char;
  kw: TKeyword;
begin
  startPos := FPos;
  startLine := FLine;
  startCol := FColumn;
  value := '';

  while FPos <= Length(FSource) do
  begin
    c := CurrentChar;
    if (c >= 'a') and (c <= 'z') or (c >= 'A') and (c <= 'Z') or (c >= '0') and (c <= '9') or (c = '_') or (c = '@') then
    begin
      value := value + c;
      Advance;
    end
    else
      Break;
  end;

  Result.TokenType := ttIdentifier;
  Result.Keyword := kwNone;
  Result.IntValue := 0;
  Result.UIntValue := 0;
  Result.RealValue := 0.0;
  Result.StrValue := value;
  Result.Line := startLine;
  Result.Col := startCol;
  Result.FileName := FFileName;
  Result.Flags := [];

  kw := ClassifyKeyword(UpperCase(value));
  if kw <> kwNone then
  begin
    Result.TokenType := ttKeyword;
    Result.Keyword := kw;
  end;
end;

function TFXBLexer.ScanNumber: TToken;
var
  startPos, startLine, startCol: Integer;
  value: string;
  c: Char;
  hasDot, hasExp, isFloat: Boolean;
  intVal: Int64;
begin
  startPos := FPos;
  startLine := FLine;
  startCol := FColumn;
  value := '';
  hasDot := False;
  hasExp := False;
  isFloat := False;

  while FPos <= Length(FSource) do
  begin
    c := CurrentChar;
    if (c >= '0') and (c <= '9') then
      value := value + c
    else if (c = '.') and not hasDot and not hasExp then
    begin
      if (FPos + 1 <= Length(FSource)) and (FSource[FPos + 1] >= '0') and (FSource[FPos + 1] <= '9') then
      begin
        hasDot := True;
        isFloat := True;
        value := value + c;
      end
      else
        Break;
    end
    else if (c = 'e') or (c = 'E') then
    begin
      if not hasExp then
      begin
        hasExp := True;
        isFloat := True;
        value := value + c;
        Advance;
        if (FPos <= Length(FSource)) and ((FSource[FPos] = '+') or (FSource[FPos] = '-')) then
        begin
          value := value + FSource[FPos];
          Advance;
        end;
        Continue;
      end
      else
        Break;
    end
    else if (c = 'u') or (c = 'U') or (c = 'l') or (c = 'L') or (c = 'f') or (c = 'F') or (c = 'd') or (c = 'D') then
    begin
      value := value + c;
      Advance;
      if (FPos <= Length(FSource)) and ((FSource[FPos] = 'l') or (FSource[FPos] = 'L') or (FSource[FPos] = 'u') or (FSource[FPos] = 'U')) then
      begin
        value := value + FSource[FPos];
        Advance;
      end;
      Break;
    end
    else
      Break;
    Advance;
  end;

  Result.TokenType := ttInteger;
  Result.Keyword := kwNone;
  Result.StrValue := value;
  Result.Line := startLine;
  Result.Col := startCol;
  Result.FileName := FFileName;
  Result.Flags := [];

  if isFloat then
  begin
    Result.TokenType := ttReal;
    Result.RealValue := StrToFloatDef(value, 0.0);
  end
  else
  begin
    intVal := StrToInt64Def(value, 0);
    if intVal >= 0 then
    begin
      Result.UIntValue := UInt64(intVal);
      if intVal > High(Int64) then
      begin
        Result.TokenType := ttUInt64;
        Result.UIntValue := UInt64(intVal);
      end
      else
      begin
        Result.IntValue := intVal;
        Result.TokenType := ttInteger;
      end;
    end
    else
    begin
      Result.IntValue := intVal;
      Result.TokenType := ttInteger;
    end;
  end;
end;

function TFXBLexer.ScanString: TToken;
var
  startPos, startLine, startCol: Integer;
  value: string;
  quoteChar: Char;
  c: Char;
  escaped: Boolean;
begin
  startPos := FPos;
  startLine := FLine;
  startCol := FColumn;
  quoteChar := CurrentChar;
  value := '';
  escaped := False;
  if quoteChar = '[' then
    quoteChar := ']';

  Advance;

  while FPos <= Length(FSource) do
  begin
    c := CurrentChar;
    if escaped then
    begin
      case c of
        'n': value := value + #10;
        'r': value := value + #13;
        't': value := value + #9;
        '\': value := value + '\';
        '"': value := value + '"';
        '''': value := value + '''';
        '0': value := value + #0;
      else
        value := value + c;
      end;
      escaped := False;
    end
    else if c = '\' then
      escaped := True
    else if c = quoteChar then
    begin
      Advance;
      Break;
    end
    else if c = #10 then
    begin
      AddError('Unterminated string literal', 1003);
      Break;
    end
    else
      value := value + c;
    Advance;
  end;

  Result.TokenType := ttString;
  Result.Keyword := kwNone;
  Result.IntValue := 0;
  Result.UIntValue := 0;
  Result.RealValue := 0.0;
  Result.StrValue := value;
  Result.Line := startLine;
  Result.Col := startCol;
  Result.FileName := FFileName;
  Result.Flags := [];
end;

function TFXBLexer.ScanRawString: TToken;
var
  startPos, startLine, startCol: Integer;
  value: string;
  quoteChar: Char;
  c: Char;
  hashCount: Integer;
  match: Boolean;
  i: Integer;
begin
  startPos := FPos;
  startLine := FLine;
  startCol := FColumn;
  value := '';

  Advance;
  hashCount := 0;
  while (FPos <= Length(FSource)) and (FSource[FPos] = '#') do
  begin
    Inc(hashCount);
    Advance;
  end;

  quoteChar := CurrentChar;
  Advance;

  while FPos <= Length(FSource) do
  begin
    c := CurrentChar;
    if (c = quoteChar) then
    begin
      match := True;
      for i := 1 to hashCount do
      begin
        if (FPos + i > Length(FSource)) or (FSource[FPos + i] <> '#') then
        begin
          match := False;
          Break;
        end;
      end;
      if match then
      begin
        Advance;
        for i := 1 to hashCount do
          Advance;
        Break;
      end;
    end;
    value := value + c;
    Advance;
  end;

  Result.TokenType := ttRawString;
  Result.Keyword := kwNone;
  Result.IntValue := 0;
  Result.UIntValue := 0;
  Result.RealValue := 0.0;
  Result.StrValue := value;
  Result.Line := startLine;
  Result.Col := startCol;
  Result.FileName := FFileName;
  Result.Flags := [];
end;

function TFXBLexer.ScanOperator: TToken;
var
  startLine, startCol: Integer;
  c, next: Char;
begin
  startLine := FLine;
  startCol := FColumn;
  c := CurrentChar;
  next := PeekChar;

  FillChar(Result, SizeOf(Result), 0);

  // Handle dot-prefixed operators first (.T., .F., .WORD., .., ...)
  if c = '.' then
  begin
    Result := ScanDotOperator;
    Result.Line := startLine;
    Result.Col := startCol;
    Exit;
  end;

  // Try two-char operators
  Result := ScanTwoCharOperator;
  if Result.TokenType <> ttInvalid then
  begin
    Result.Line := startLine;
    Result.Col := startCol;
    Exit;
  end;

  // Fallback to single-char operators
  Result := ScanSingleCharOperator(c);
  Result.Line := startLine;
  Result.Col := startCol;
end;

function TFXBLexer.ScanDotOperator: TToken;
var
  value: string;
  j: Integer;
  next: Char;
begin
  FillChar(Result, SizeOf(Result), 0);
  next := PeekChar;

  // .T. and .F. logical literals
  if (next = 'T') and (PeekChar(2) = '.') then
  begin
    value := '.T.'; Advance; Advance; Advance;
    Result.TokenType := ttLogical;
    Result.IntValue := 1;
    Result.StrValue := value;
    Exit;
  end
  else if (next = 'F') and (PeekChar(2) = '.') then
  begin
    value := '.F.'; Advance; Advance; Advance;
    Result.TokenType := ttLogical;
    Result.IntValue := 0;
    Result.StrValue := value;
    Exit;
  end
  // .WORD. forms (dot operators like .AND., .OR., .NOT., .XOR.)
  else if ((next >= 'A') and (next <= 'Z')) or ((next >= 'a') and (next <= 'z')) then
  begin
    j := 2;
    while ((PeekChar(j) >= 'A') and (PeekChar(j) <= 'Z'))
       or ((PeekChar(j) >= 'a') and (PeekChar(j) <= 'z')) do
      Inc(j);
    if PeekChar(j) = '.' then
    begin
      value := '.';
      Advance;
      while (FPos <= Length(FSource)) and (((FSource[FPos] >= 'A') and (FSource[FPos] <= 'Z')) or ((FSource[FPos] >= 'a') and (FSource[FPos] <= 'z'))) do
      begin
        value := value + FSource[FPos];
        Advance;
      end;
      value := value + '.';
      Advance;
      Result.StrValue := value;
      if UpperCase(Copy(value, 2, Length(value) - 2)) = 'AND' then
      begin
        Result.TokenType := ttDotAnd;
        Result.Keyword := kwAnd;
      end
      else if UpperCase(Copy(value, 2, Length(value) - 2)) = 'OR' then
      begin
        Result.TokenType := ttDotOr;
        Result.Keyword := kwOr;
      end
      else if UpperCase(Copy(value, 2, Length(value) - 2)) = 'NOT' then
      begin
        Result.TokenType := ttDotNot;
        Result.Keyword := kwNot;
      end
      else if UpperCase(Copy(value, 2, Length(value) - 2)) = 'XOR' then
      begin
        Result.TokenType := ttXor;
        Result.Keyword := kwXor;
      end
      else
        Result.TokenType := ttIdentifier;
      Exit;
    end
    else
    begin
      // Member-access dot: emit ttDot and let the identifier be scanned next.
      value := '.';
      Advance;
      Result.TokenType := ttDot;
      Result.StrValue := value;
      Exit;
    end;
  end
  // .. and ...
  else if (next = '.') and (PeekChar(2) = '.') then
  begin
    value := '...'; Advance; Advance; Advance;
    Result.TokenType := ttEllipsis;
    Result.StrValue := value;
    Exit;
  end
  else if (next = '.') then
  begin
    value := '..'; Advance; Advance;
    Result.TokenType := ttRange;
    Result.StrValue := value;
    Exit;
  end
  else
  begin
    // Just a single dot
    value := '.';
    Advance;
    Result.TokenType := ttDot;
    Result.StrValue := value;
    Exit;
  end;
end;

function TFXBLexer.ScanTwoCharOperator: TToken;
var
  c, next: Char;
  value: string;
  matched: Boolean;
begin
  FillChar(Result, SizeOf(Result), 0);
  c := CurrentChar;
  next := PeekChar;
  value := '';
  matched := False;

  // Two-character operators (ordered by first char for efficiency)
  case c of
    ':':
      if next = ':' then begin value := '::'; Advance; Advance; Result.TokenType := ttDoubleColon; matched := True; end
      else if next = '=' then begin value := ':='; Advance; Advance; Result.TokenType := ttAssign; matched := True; end;
    '?':
      if next = '?' then begin value := '??'; Advance; Advance; Result.TokenType := ttDoubleQuestion; matched := True; end
      else if next = '.' then begin value := '?.'; Advance; Advance; Result.TokenType := ttQuestionDot; matched := True; end
      else if next = ':' then begin value := '?:'; Advance; Advance; Result.TokenType := ttQuestionColon; matched := True; end;
    '+':
      if next = '+' then begin value := '++'; Advance; Advance; Result.TokenType := ttInc; matched := True; end
      else if next = '=' then begin value := '+='; Advance; Advance; Result.TokenType := ttPlusAssign; matched := True; end;
    '-':
      if next = '-' then begin value := '--'; Advance; Advance; Result.TokenType := ttDec; matched := True; end
      else if next = '>' then begin value := '->'; Advance; Advance; Result.TokenType := ttArrow; matched := True; end
      else if next = '=' then begin value := '-='; Advance; Advance; Result.TokenType := ttMinusAssign; matched := True; end;
    '=':
      if next = '=' then
      begin
        value := '=='; Advance; Advance;
        if (FPos <= Length(FSource)) and (FSource[FPos] = '=') then
        begin
          value := '==='; Advance;
          Result.TokenType := ttExactEqual;
        end
        else
          Result.TokenType := ttEq;
        matched := True;
      end
      else if next = '>' then begin value := '=>'; Advance; Advance; Result.TokenType := ttArrow2; matched := True; end;
    '!':
      if next = '=' then
      begin
        value := '!='; Advance; Advance;
        if (FPos <= Length(FSource)) and (FSource[FPos] = '=') then
        begin
          value := '!=='; Advance;
          Result.TokenType := ttNotExactEqual;
        end
        else
          Result.TokenType := ttNeq;
        matched := True;
      end;
    '<':
      if next = '=' then begin value := '<='; Advance; Advance; Result.TokenType := ttLe; matched := True; end
      else if next = '>' then begin value := '<>'; Advance; Advance; Result.TokenType := ttNeq2; matched := True; end
      else if next = '<' then begin value := '<<'; Advance; Advance; Result.TokenType := ttShl; matched := True; end;
    '>':
      if next = '=' then begin value := '>='; Advance; Advance; Result.TokenType := ttGe; matched := True; end
      else if next = '>' then begin value := '>>'; Advance; Advance; Result.TokenType := ttShr; matched := True; end;
    '*':
      if next = '=' then begin value := '*='; Advance; Advance; Result.TokenType := ttStarAssign; matched := True; end
      else if next = '*' then begin value := '**'; Advance; Advance; Result.TokenType := ttStarStar; matched := True; end;
    '/':
      if next = '=' then begin value := '/='; Advance; Advance; Result.TokenType := ttSlashAssign; matched := True; end
      else if next = '/' then begin value := '//'; Advance; Advance; Result.TokenType := ttDoubleSlash; matched := True; end;
    '%':
      if next = '=' then begin value := '%='; Advance; Advance; Result.TokenType := ttPercentAssign; matched := True; end;
    '&':
      if next = '&' then begin value := '&&'; Advance; Advance; Result.TokenType := ttAnd; matched := True; end;
    '|':
      if next = '|' then begin value := '||'; Advance; Advance; Result.TokenType := ttOr; matched := True; end;
    '@':
      if next = '@' then begin value := '@@'; Advance; Advance; Result.TokenType := ttAtAt; matched := True; end;
  else
    // No two-char operator for this character
  end;

  if not matched then
  begin
    Result.TokenType := ttInvalid;
    Exit;
  end;

  Result.StrValue := value;
  Result.Keyword := kwNone;
  Result.IntValue := 0;
  Result.UIntValue := 0;
  Result.RealValue := 0.0;
  Result.Flags := [];
end;

function TFXBLexer.ScanSingleCharOperator(const c: Char): TToken;
var
  value: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  value := c;
  Advance;

  case c of
    '+': Result.TokenType := ttPlus;
    '-': Result.TokenType := ttMinus;
    '*': Result.TokenType := ttStar;
    '/': Result.TokenType := ttSlash;
    '\': Result.TokenType := ttBackslash;
    '%': Result.TokenType := ttPercent;
    '^': Result.TokenType := ttCaret;
    '=': Result.TokenType := ttEqual;
    '<': Result.TokenType := ttLt;
    '>': Result.TokenType := ttGt;
    '!': Result.TokenType := ttNot;
    '&': Result.TokenType := ttBitAnd;
    '|': Result.TokenType := ttBitOr;
    '~': Result.TokenType := ttBitNot;
    '.': Result.TokenType := ttDot;
    ',': Result.TokenType := ttComma;
    ';': Result.TokenType := ttSemicolon;
    ':': Result.TokenType := ttColon;
    '(': Result.TokenType := ttLParen;
    ')': Result.TokenType := ttRParen;
    '[': Result.TokenType := ttLBracket;
    ']': Result.TokenType := ttRBracket;
    '{': Result.TokenType := ttLBrace;
    '}': Result.TokenType := ttRBrace;
    '?': begin Result.TokenType := ttQuestion; value := '?'; end;
    '@': Result.TokenType := ttAt;
    '#': Result.TokenType := ttHash;
    '$': begin Result.TokenType := ttIdentifier; value := '$'; end;
  else
    Result.TokenType := ttInvalid;
  end;

  Result.StrValue := value;
  Result.Keyword := kwNone;
  Result.IntValue := 0;
  Result.UIntValue := 0;
  Result.RealValue := 0.0;
  Result.Flags := [];
end;

function TFXBLexer.ScanPreprocessor: TToken;
var
  startLine, startCol: Integer;
  value: string;
  c: Char;
  upperVal: string;
  tokenType: TTokenType;
  kw: TKeyword;
begin
  startLine := FLine;
  startCol := FColumn;
  value := '';

  while FPos <= Length(FSource) do
  begin
    c := CurrentChar;
    if (c = #10) or (c = #13) then
      Break;
    value := value + c;
    Advance;
  end;

  upperVal := UpperCase(Trim(value));
  tokenType := ttPPDirective;
  kw := kwNone;

  if upperVal.StartsWith('#DEFINE') then tokenType := ttDefine
  else if upperVal.StartsWith('#INCLUDE') then tokenType := ttInclude
  else if upperVal.StartsWith('#IFDEF') then tokenType := ttIfdef
  else if upperVal.StartsWith('#IFNDEF') then tokenType := ttIfndef
  else if upperVal.StartsWith('#ELIF') then tokenType := ttElif
  else if upperVal.StartsWith('#ELSE') then tokenType := ttElse
  else if upperVal.StartsWith('#ENDIF') then tokenType := ttEndif
  else if upperVal.StartsWith('#UNDEF') then tokenType := ttUndef
  else if upperVal.StartsWith('#PRAGMA') then tokenType := ttPragma
  else if upperVal.StartsWith('#COMMAND') then tokenType := ttCommand
  else if upperVal.StartsWith('#TRANSLATE') then tokenType := ttTranslate
  else if upperVal.StartsWith('#XCOMMAND') then tokenType := ttXCommand
  else if upperVal.StartsWith('#XTRANSLATE') then tokenType := ttXTranslate;

  Result.TokenType := tokenType;
  Result.Keyword := kw;
  Result.IntValue := 0;
  Result.UIntValue := 0;
  Result.RealValue := 0.0;
  Result.StrValue := value;
  Result.Line := startLine;
  Result.Col := startCol;
  Result.FileName := FFileName;
  Result.Flags := [];
end;

function TFXBLexer.HasErrors: Boolean;
begin
  Result := Length(FErrors) > 0;
end;

end.
