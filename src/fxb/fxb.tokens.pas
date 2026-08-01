unit fxb.tokens;

{$mode objfpc}{$H+}

interface

type
  TStringArray = array of string;

  TTokenType = (
    ttAnd,
    ttArrow,
    ttArrow2,
    ttAs,
    ttAssign,
    ttAt,
    ttAtAt,
    ttAtAtField,
    ttAtGet,
    ttAtSay,
    ttBackslash,
    ttBitAnd,
    ttBitNot,
    ttBitOr,
    ttBitXor,
    ttBlockComment,
    ttCaret,
    ttCaretAssign,
    ttColon,
    ttComma,
    ttCommand,
    ttComment,
    ttConcat,
    ttConcat2,
    ttCurrency,
    ttDate,
    ttDateTime,
    ttDec,
    ttDefine,
    ttDeref,
    ttDirective,
    ttDollar,
    ttDot,
    ttDotAnd,
    ttDotNot,
    ttDotOr,
    ttDoubleColon,
    ttDoublePipe,
    ttDoubleSlash,
    ttElif,
    ttEllipsis,
    ttElse,
    ttEndif,
    ttEof,
    ttEq,
    ttEqual,
    ttExactEqual,
    ttGe,
    ttGt,
    ttHash,
    ttHashHash,
    ttIdentifier,
    ttIfdef,
    ttIfndef,
    ttIn,
    ttInc,
    ttInclude,
    ttInteger,
    ttInvalid,
    ttIs,
    ttKeyword,
    ttLBrace,
    ttLBracket,
    ttLe,
    ttLineComment,
    ttLogical,
    ttLParen,
    ttLt,
    ttMemo,
    ttMinus,
    ttMinusAssign,
    ttNeq,
    ttNeq2,
    ttNewline,
    ttNil,
    ttNot,
    ttNotExactEqual,
    ttOf,
    ttOr,
    ttPercent,
    ttPercentAssign,
    ttPipe,
    ttPlus,
    ttPlusAssign,
    ttPPDirective,
    ttPragma,
    ttQuestionColon,
    ttQuestionDot,
    ttRange,
    ttRawString,
    ttRBrace,
    ttRBracket,
    ttReal,
    ttRParen,
    ttSemicolon,
    ttShl,
    ttShr,
    ttSlash,
    ttSlashAssign,
    ttStar,
    ttStarAssign,
    ttStarStar,
    ttString,
    ttTranslate,
    ttUInt64,
    ttUndef,
    ttWhitespace,
    ttXCommand,
    ttXor,
    ttXTranslate

  );

  TKeyword = (
    kwNone,

    // xBASE commands
    kwUse, kwSelect, kwClose, kwGoto, kwGo, kwSkip,
    kwLocate, kwContinue, kwSeek, kwFind,
    kwReplace, kwAppend, kwInsert, kwDelete, kwRecall,
    kwPack, kwZap, kwIndex, kwSet,
    kwSetIndex, kwSetOrder, kwSetRelation, kwSetFilter,
    kwSetDeleted, kwSetExact, kwSetSoftSeek, kwSetUnique,
    kwClear, kwClearAll, kwClearGets, kwClearMemory, kwClearScreen,
    kwClearTypeAhead,

    // Control flow
    kwIf, kwElseIf, kwElse, kwEndIf,
    kwDo, kwWhile, kwEndDo,
    kwFor, kwTo, kwStep, kwEndFor, kwNext,
    kwForEach, kwIn, kwEndForEach,
    kwSwitch, kwCase, kwDefault, kwEndSwitch, kwEndCase,
    kwExit, kwLoop, kwReturn, kwBreak, kwYield,

    // Functions/Procedures
    kwFunction, kwProcedure, kwEndFunc, kwEndFunction,
    kwEndProc, kwEndProcedure,
    kwLocal, kwStatic, kwPublic, kwPrivate, kwMemvar,
    kwParameters, kwParam, kwVar, kwOut, kwRef,

    // OOP
    kwClass, kwEndClass, kwMethod, kwProperty,
    kwNew, kwThis, kwSuper, kwInherit,
    kwInterface, kwImplements,
    kwVirtual, kwOverride, kwAbstract,
    kwConst, kwReadOnly, kwConstructor, kwDestructor,
    kwOperator,

    // Types
    kwType, kwStruct, kwEndStruct, kwEnum, kwUnion,
    kwTypedef, kwAlias,
    kwArray, kwHash, kwVector, kwStack, kwQueue,
    kwRange, kwPointer,
    kwUniquePtr, kwSharedPtr, kwWeakPtr,
    kwOptional, kwResult,
    kwNewType, kwEndNewType,
    kwGeneric, kwOf, kwIterator,

    // Basic types
    kwVoid, kwBool, kwLogical,
    kwByte, kwUByte, kwShort, kwUShort,
    kwInt, kwUInt, kwLong, kwULong,
    kwInt64, kwUInt64, kwInt128, kwUInt128,
    kwFloat, kwDouble, kwCurrency, kwNumeric,
    kwString, kwMemo,
    kwDate, kwDateTime, kwTime,
    kwPointerType, kwVariant, kwAny, kwAuto,

    // Database
    kwSql, kwExecute, kwExecuteSql,
    kwBeginTransaction, kwCommit, kwRollback,
    kwSavepoint, kwPrepare, kwExecuteImmediate,
    kwFetch, kwCursor, kwConnect, kwDisconnect,
    kwDatabase, kwTable, kwCreate, kwDrop, kwAlter,
    kwFrom, kwWhere, kwJoin,
    kwInner, kwLeft, kwRight, kwFull, kwOn,
    kwGroupBy, kwHaving, kwOrderBy,
    kwLimit, kwOffset, kwDistinct,
    kwUpdate, kwInto, kwValues,

    // FXBASE extensions
    kwTask, kwAsync, kwAwait, kwParallel,
    kwChannel, kwSend, kwReceive,
    kwMutex, kwSemaphore, kwAtomic, kwThreadLocal,
    kwSpawn,
    kwTry, kwCatch, kwFinally, kwEndTry,
    kwThrow, kwRaise,
    kwWith, kwUsing, kwDefer,
    kwMatch, kwWhen,
    kwLet, kwConstLet, kwVarLet,

    // Preprocessor
    kwDefine, kwInclude, kwIfdefPP, kwIfndefPP,
    kwElifPP, kwUndef, kwPragma,
    kwCommand, kwTranslate, kwXCommand, kwXTranslate,

    // Literals
    kwTrue, kwFalse, kwNull, kwNil, kwEmpty,

    // Operator keywords
    kwAnd, kwOr, kwNot, kwXor,
    kwEq, kwNe, kwLt, kwLe, kwGt, kwGe,
    kwInOp, kwBetween, kwLike, kwMatches,

    // Built-in functions
    kwEof, kwBof, kwFound, kwRecno, kwRecCount,
    kwFieldGet, kwFieldPut, kwFieldName, kwFieldCount,
    kwDeleted,

    // FXBASE built-ins
    kwTaskCreate, kwTaskWait, kwTaskYield, kwSleep,
    kwNow, kwToday, kwSeconds, kwMilliseconds,

    // Other
    kwAs, kwIs, kwAlign, kwPadding,
    kwStore, kwAccept, kwWait, kwText, kwEndText,
    kwInput, kwRead, kwSay, kwGet,
    kwKeyboard, kwRun, kwCall, kwQuit, kwCancel,
    kwOpen, kwCloseDb, kwFlush, kwEject,
    kwReport, kwForm, kwLabel,
    kwSort, kwAverage, kwSum, kwCount, kwTotal,
    kwCopy, kwStructure,
    kwAnnounce, kwRequest, kwExternal,
    kwInit,
    kwDeclare, kwDefineCmd, kwWindow, kwMenu, kwPrompt,
    kwActivate, kwDeactivate, kwHide, kwShow,
    kwTypeCmd, kwObject, kwEndWith,
    kwBegin, kwSequence, kwRecover,
    kwEnd,
    kwField,
    kwStrict,
    kwDownTo
  );

const
  KeywordNames: array[TKeyword] of string = (
    '',
    // xBASE commands
    'USE', 'SELECT', 'CLOSE', 'GOTO', 'GO', 'SKIP',
    'LOCATE', 'CONTINUE', 'SEEK', 'FIND',
    'REPLACE', 'APPEND', 'INSERT', 'DELETE', 'RECALL',
    'PACK', 'ZAP', 'INDEX', 'SET',
    'SET INDEX', 'SET ORDER', 'SET RELATION', 'SET FILTER',
    'SET DELETED', 'SET EXACT', 'SET SOFTSEEK', 'SET UNIQUE',
    'CLEAR', 'CLEAR ALL', 'CLEAR GETS', 'CLEAR MEMORY', 'CLEAR SCREEN',
    'CLEAR TYPEAHEAD',

    // Control flow
    'IF', 'ELSEIF', 'ELSE', 'ENDIF',
    'DO', 'WHILE', 'ENDDO',
    'FOR', 'TO', 'STEP', 'ENDFOR', 'NEXT',
    'FOREACH', 'IN', 'ENDFOREACH',
    'SWITCH', 'CASE', 'DEFAULT', 'ENDSWITCH', 'ENDCASE',
    'EXIT', 'LOOP', 'RETURN', 'BREAK', 'YIELD',

    // Functions/Procedures
    'FUNCTION', 'PROCEDURE', 'ENDFUNC', 'ENDFUNCTION',
    'ENDPROC', 'ENDPROCEDURE',
    'LOCAL', 'STATIC', 'PUBLIC', 'PRIVATE', 'MEMVAR',
    'PARAMETERS', 'PARAM', 'VAR', 'OUT', 'REF',

    // OOP
    'CLASS', 'ENDCLASS', 'METHOD', 'PROPERTY',
    'NEW', 'THIS', 'SUPER', 'INHERIT',
    'INTERFACE', 'IMPLEMENTS',
    'VIRTUAL', 'OVERRIDE', 'ABSTRACT',
    'CONST', 'READONLY', 'CONSTRUCTOR', 'DESTRUCTOR',
    'OPERATOR',

    // Types
    'TYPE', 'STRUCT', 'ENDSTRUCT', 'ENUM', 'UNION',
    'TYPEDEF', 'ALIAS',
    'ARRAY', 'HASH', 'VECTOR', 'STACK', 'QUEUE',
    'RANGE', 'POINTER',
    'UNIQUE_PTR', 'SHARED_PTR', 'WEAK_PTR',
    'OPTIONAL', 'RESULT',
    'NEWTYPE', 'ENDNEWTYPE',
    'GENERIC', 'OF', 'ITERATOR',

    // Basic types
    'VOID', 'BOOL', 'LOGICAL',
    'BYTE', 'UBYTE', 'SHORT', 'USHORT',
    'INT', 'UINT', 'LONG', 'ULONG',
    'INT64', 'UINT64', 'INT128', 'UINT128',
    'FLOAT', 'DOUBLE', 'CURRENCY', 'NUMERIC',
    'STRING', 'MEMO',
    'DATE', 'DATETIME', 'TIME',
    'POINTER', 'VARIANT', 'ANY', 'AUTO',

    // Database
    'SQL', 'EXECUTE', 'EXECUTE SQL',
    'BEGIN TRANSACTION', 'COMMIT', 'ROLLBACK',
    'SAVEPOINT', 'PREPARE', 'EXECUTE IMMEDIATE',
    'FETCH', 'CURSOR', 'CONNECT', 'DISCONNECT',
    'DATABASE', 'TABLE', 'CREATE', 'DROP', 'ALTER',
    'FROM', 'WHERE', 'JOIN',
    'INNER', 'LEFT', 'RIGHT', 'FULL', 'ON',
    'GROUP BY', 'HAVING', 'ORDER BY',
    'LIMIT', 'OFFSET', 'DISTINCT',
    'UPDATE', 'INTO', 'VALUES',

    // FXBASE extensions
    'TASK', 'ASYNC', 'AWAIT', 'PARALLEL',
    'CHANNEL', 'SEND', 'RECEIVE',
    'MUTEX', 'SEMAPHORE', 'ATOMIC', 'THREAD_LOCAL',
    'SPAWN',
    'TRY', 'CATCH', 'FINALLY', 'ENDTRY',
    'THROW', 'RAISE',
    'WITH', 'USING', 'DEFER',
    'MATCH', 'WHEN',
    'LET', 'CONST', 'VAR',

    // Preprocessor
    'DEFINE', 'INCLUDE', 'IFDEF', 'IFNDEF',
    'ELIF', 'UNDEF', 'PRAGMA',
    'COMMAND', 'TRANSLATE', 'XCOMMAND', 'XTRANSLATE',

    // Literals
    'TRUE', 'FALSE', 'NULL', 'NIL', 'EMPTY',

    // Operator keywords
    '.AND.', '.OR.', '.NOT.', '.XOR.',
    '.EQ.', '.NE.', '.LT.', '.LE.', '.GT.', '.GE.',
    '.IN.', '.BETWEEN.', '.LIKE.', '.MATCHES.',

    // Built-in functions
    'EOF', 'BOF', 'FOUND', 'RECNO', 'RECCOUNT',
    'FIELDGET', 'FIELDPUT', 'FIELDNAME', 'FIELDCOUNT',
    'DELETED',

    // FXBASE built-ins
    'TASKCREATE', 'TASKWAIT', 'TASKYIELD', 'SLEEP',
    'NOW', 'TODAY', 'SECONDS', 'MILLISECONDS',

    // Other
    'AS', 'IS', 'ALIGN', 'PADDING',
    'STORE', 'ACCEPT', 'WAIT', 'TEXT', 'ENDTEXT',
    'INPUT', 'READ', 'SAY', 'GET',
    'KEYBOARD', 'RUN', 'CALL', 'QUIT', 'CANCEL',
    'OPEN', 'CLOSE', 'FLUSH', 'EJECT',
    'REPORT', 'FORM', 'LABEL',
    'SORT', 'AVERAGE', 'SUM', 'COUNT', 'TOTAL',
    'COPY', 'STRUCTURE',
    'ANNOUNCE', 'REQUEST', 'EXTERNAL',
    'INIT',
    'DECLARE', 'DEFINE', 'WINDOW', 'MENU', 'PROMPT',
    'ACTIVATE', 'DEACTIVATE', 'HIDE', 'SHOW',
    'TYPE', 'OBJECT', 'ENDWITH',
    'BEGIN', 'SEQUENCE', 'RECOVER',
    'END',
    'FIELD',
    'STRICT',
    'DOWNTO'
  );

type
  TTokenFlag = (tfNewline, tfStartOfLine);
  TTokenFlags = set of TTokenFlag;

  TToken = record
    TokenType: TTokenType;
    Keyword: TKeyword;
    IntValue: Int64;
    UIntValue: UInt64;
    RealValue: Double;
    StrValue: string;
    Line: Integer;
    Col: Integer;
    FileName: string;
    Flags: TTokenFlags;
  end;

  TTokenArray = array of TToken;
  PToken = ^TToken;
  TTokenCallback = procedure(constref Token: TToken) of object;

function KeywordFromString(const s: string): TKeyword;
function IsKeyword(const s: string): boolean;
function TokenTypeName(tt: TTokenType): string;
function DumpToken(constref T: TToken): string;

implementation

function StrUp(const s: string): string;
var i: Integer; c: Char;
begin
  Result := s;
  for i := 1 to Length(Result) do
  begin
    c := Result[i];
    if (c >= 'a') and (c <= 'z') then
      Result[i] := Chr(Ord(c) - 32);
  end;
end;

function KeywordFromString(const s: string): TKeyword;
var
  upper: string;
  i: TKeyword;
begin
  upper := StrUp(s);
  for i := Succ(kwNone) to High(TKeyword) do
  begin
    if KeywordNames[i] = upper then
    begin
      Result := i;
      Exit;
    end;
  end;
  Result := kwNone;
end;

function IsKeyword(const s: string): boolean;
begin
  Result := KeywordFromString(s) <> kwNone;
end;

function TokenTypeName(tt: TTokenType): string;
begin
  case tt of
    
    ttAnd: Result := '''&&''';
    ttArrow: Result := '''->''';
    ttArrow2: Result := '''=>''';
    ttAs: Result := 'AS';
    ttAssign: Result := ''':=''';
    ttAt: Result := '''@''';
    ttAtAt: Result := '@@';
    ttAtAtField: Result := 'FIELDREF';
    ttAtGet: Result := '@...GET';
    ttAtSay: Result := '@...SAY';
    ttBackslash: Result := '''\''';
    ttBitAnd: Result := '''&''';
    ttBitNot: Result := '''~''';
    ttBitOr: Result := '''|''';
    ttBitXor: Result := 'BITXOR';
    ttBlockComment: Result := 'BLOCKCOMMENT';
    ttCaret: Result := '''^''';
    ttCaretAssign: Result := '''^=''';
    ttColon: Result := ''':''';
    ttComma: Result := ''',''';
    ttCommand: Result := '#COMMAND';
    ttComment: Result := 'COMMENT';
    ttConcat: Result := 'CONCAT+';
    ttConcat2: Result := 'CONCAT-';
    ttCurrency: Result := 'CURRENCY';
    ttDate: Result := 'DATE';
    ttDateTime: Result := 'DATETIME';
    ttDec: Result := '''--''';
    ttDefine: Result := '#DEFINE';
    ttDeref: Result := 'DEREF';
    ttDirective: Result := 'DIRECTIVE';
    ttDollar: Result := '''$''';
    ttDot: Result := '''.''';
    ttDotAnd: Result := '''.AND.''';
    ttDotNot: Result := '''.NOT.''';
    ttDotOr: Result := '''.OR.''';
    ttDoubleColon: Result := '::';
    ttDoublePipe: Result := '''||''';
    ttDoubleSlash: Result := '''//''';
    ttElif: Result := '#ELIF';
    ttEllipsis: Result := '...';
    ttElse: Result := '#ELSE';
    ttEndif: Result := '#ENDIF';
    ttEof: Result := 'EOF';
    ttEq: Result := '==';
    ttEqual: Result := '''=''';
    ttExactEqual: Result := '''===''';
    ttGe: Result := '''>=''';
    ttGt: Result := '''>''';
    ttHash: Result := '''#''';
    ttHashHash: Result := '##';
    ttIdentifier: Result := 'IDENTIFIER';
    ttIfdef: Result := '#IFDEF';
    ttIfndef: Result := '#IFNDEF';
    ttIn: Result := 'IN';
    ttInc: Result := '''++''';
    ttInclude: Result := '#INCLUDE';
    ttInteger: Result := 'INTEGER';
    ttInvalid: Result := 'INVALID';
    ttIs: Result := 'IS';
    ttKeyword: Result := 'KEYWORD';
    ttLBrace: Result := '''{''';
    ttLBracket: Result := '''[''';
    ttLe: Result := '''<=''';
    ttLineComment: Result := 'LINECOMMENT';
    ttLogical: Result := 'LOGICAL';
    ttLParen: Result := '''(''';
    ttLt: Result := '''<''';
    ttMemo: Result := 'MEMO';
    ttMinus: Result := '''-''';
    ttMinusAssign: Result := '''-=''';
    ttNeq: Result := '''!=''';
    ttNeq2: Result := '''<>''';
    ttNewline: Result := 'NEWLINE';
    ttNil: Result := 'NIL';
    ttNot: Result := '''!''';
    ttNotExactEqual: Result := '''!==''';
    ttOf: Result := 'OF';
    ttOr: Result := '''||''';
    ttPercent: Result := '''%''';
    ttPercentAssign: Result := '''%=''';
    ttPipe: Result := '''|''';
    ttPlus: Result := '''+''';
    ttPlusAssign: Result := '+=';
    ttPPDirective: Result := 'PPDIRECTIVE';
    ttPragma: Result := '#PRAGMA';
    ttQuestionColon: Result := '?:';
    ttQuestionDot: Result := '?.';
    ttRange: Result := '..';
    ttRawString: Result := 'RAWSTRING';
    ttRBrace: Result := '''}''';
    ttRBracket: Result := ''']''';
    ttReal: Result := 'REAL';
    ttRParen: Result := ''')''';
    ttSemicolon: Result := ''':''';
    ttShl: Result := '''<<''';
    ttShr: Result := '''>>''';
    ttSlash: Result := '''/''';
    ttSlashAssign: Result := '''/=''';
    ttStar: Result := '''*''';
    ttStarAssign: Result := '''*=''';
    ttStarStar: Result := '''**''';
    ttString: Result := 'STRING';
    ttTranslate: Result := '#TRANSLATE';
    ttUInt64: Result := 'UINT64';
    ttUndef: Result := '#UNDEF';
    ttWhitespace: Result := 'WS';
    ttXCommand: Result := '#XCOMMAND';
    ttXor: Result := '.XOR.';
    ttXTranslate: Result := '#XTRANSLATE';

  end;
end;

function DumpToken(constref T: TToken): string;
var
  lineStr, colStr, intStr: string;
begin
  Str(T.Line, lineStr);
  Str(T.Col, colStr);
  Result := '[' + lineStr + ':' + colStr + '] ' + TokenTypeName(T.TokenType);
  case T.TokenType of
    ttInteger, ttUInt64:
    begin
      Str(T.IntValue, intStr);
      Result := Result + '=' + intStr;
    end;
    ttReal: Result := Result + '=REAL';
    ttString, ttRawString: Result := Result + '="' + T.StrValue + '"';
    ttIdentifier: Result := Result + '=' + T.StrValue;
    ttKeyword: Result := Result + '=' + KeywordNames[T.Keyword];
    else
      if T.StrValue <> '' then
        Result := Result + '=' + T.StrValue;
  end;
end;

end.
