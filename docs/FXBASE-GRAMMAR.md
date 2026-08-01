# Gramática FPXBASE

**Norma de Referencia:** ISO/IEC/IEEE 29148:2018 / ISO/IEC 14977

**Versión:** 1.0  
**Trazabilidad ID:** REQ-GRM-001  
**Auditoría:** Control de Sintaxis Fase 0  
**Notación:** EBNF extendida  
`[...]` opcional, `{...}` cero o más, `(...)` agrupación, `|` alternancia, `'...'` literal

---

## 1. Convenciones Léxicas

### 1.1 Comentarios

```ebnf
Comment      ::= LineComment | BlockComment
LineComment  ::= ('//' | '&&' | '*') {any_character} NewLine
BlockComment ::= '/*' {any_character} '*/'
```

### 1.2 Identificadores

```ebnf
Identifier       ::= (Letter | '_') {Letter | Digit | '_'}
Letter           ::= 'A'..'Z' | 'a'..'z'
Digit            ::= '0'..'9'
```

### 1.3 Palabras Reservadas

```ebnf
ReservedWord ::=
    'ACTIVATE' | 'DEACTIVATE' | 'HIDE' | 'SHOW' |
    'AND' | 'OR' | 'NOT' | '.AND.' | '.OR.' | '.NOT.' |
    'ANNOUNCE' | 'REQUEST' | 'EXTERNAL' |
    'APPEND' | 'BLANK' | 'FROM' |
    'AS' | 'IS' | 'OF' | 'REF' | 'OUT' |
    'BEGIN' | 'SEQUENCE' | 'RECOVER' | 'BREAK' |
    'CAST' |
    'CLASS' | 'ENDCLASS' | 'METHOD' | 'DATA' | 'INLINE' |
    'CONSTRUCTOR' | 'DESTRUCTOR' |
    'COPY' | 'STRUCTURE' | 'TO' |
    'CREATE' | 'TABLE' | 'INDEX' | 'UNIQUE' |
    'DB' | 'SQL' | 'CONNECTION' | 'EXECUTE' | 'PREPARE' |
    'DECLARE' | 'DEFINE' | 'WINDOW' | 'MENU' | 'PROMPT' |
    'DO' | 'WHILE' | 'FOR' | 'TO' | 'STEP' | 'NEXT' |
    'FIELD' | 'MEMVAR' |
    'FOREACH' | 'IN' |
    'FUNCTION' | 'PROCEDURE' | 'RETURN' |
    'IF' | 'ELSE' | 'ELSEIF' | 'ENDIF' | 'END' |
    'IMPLEMENTS' | 'IMPLEMENTEDBY' |
    'INIT' | 'EXIT' | 'PROCEDURE' |
    'INSERT' | 'INTO' | 'VALUES' | 'UPDATE' |
    'INTERFACE' | 'ENDINTERFACE' |
    'KEYBOARD' | 'TYPE' | 'EJECT' | 'FLUSH' | 'COMMIT' |
    'LOCAL' | 'PRIVATE' | 'PUBLIC' | 'STATIC' | 'PARAMETERS' |
    'LOOP' | 'EXIT' |
    'NEW' | 'SELF' | 'SUPER' | 'THIS' |
    'NEWTYPE' | 'ENDNEWTYPE' |
    'NIL' | 'TRUE' | 'FALSE' | '.T.' | '.F.' |
    'OPEN' | 'CLOSE' | 'DATABASE' |
    'PROPERTY' | 'GETTER' | 'SETTER' |
    'REPLACE' | 'DELETE' | 'RECALL' | 'PACK' | 'ZAP' |
    'REPORT' | 'FORM' | 'LABEL' |
    'RUN' | 'CALL' | 'QUIT' | 'CANCEL' |
    'SAY' | 'GET' | 'READ' | 'INPUT' | 'ACCEPT' | 'WAIT' |
    'SEEK' | 'SKIP' | 'GO' | 'GOTO' | 'LOCATE' | 'CONTINUE' |
    'SORT' | 'AVERAGE' | 'SUM' | 'COUNT' | 'TOTAL' |
    'STRUCT' | 'ENDSTRUCT' |
    'SWITCH' | 'CASE' | 'OTHERWISE' | 'ENDSWITCH' |
    'TEXT' | 'ENDTEXT' |
    'TRY' | 'CATCH' | 'FINALLY' | 'ENDTRY' |
    'UNIQUE_PTR' | 'SHARED_PTR' | 'WEAK_PTR' |
    'USE' | 'SELECT' | 'SET' | 'INDEX' | 'ORDER' | 'TAG' |
    'VIRTUAL' | 'OVERRIDE' | 'ABSTRACT' | 'FINAL' | 'SEALED' |
    'WITH' | 'OBJECT' | 'ENDWITH' |
    'YIELD' |
    -- Concurrencia / Tasks (FPXBASE)
    'CHANNEL' | 'SEND' | 'RECEIVE' | 'SELECT' |
    'LOCK' | 'UNLOCK' | 'TRYLOCK' |
    'MUTEX' | 'SEMAPHORE' | 'ATOMIC' | 'THREAD_LOCAL' |
    'TASK' | 'ASYNC' | 'AWAIT' | 'SPAWN' | 'PARALLEL' |
    -- Memoria / GC
    'GC' | 'REFCOUNT' | 'GENERATIONAL' | 'MANUAL' |
    -- Red / Serial / Crypto (built-ins via std.fph)
    'AES' | 'CHACHA20' | 'BCRYPT' | 'JWT' | 'BASE64'
    'SERIAL' | 'RS232' | 'RS485' |
    'TCP' | 'UDP' | 'HTTP' | 'DNS' | 'TLS' |
```

> Los comandos xBASE no distinguen mayúsculas/minúsculas.  \
> `END` puede abreviarse como `END` + prefijo: `ENDIF`, `ENDFOR`, `ENDDO`.

### 1.4 Literales

```ebnf
Literal       ::= NumericLiteral | StringLiteral | DateLiteral |
                  LogicalLiteral | NIL

NumericLiteral  ::= IntegerLiteral | RealLiteral
IntegerLiteral  ::= Digit {Digit}
RealLiteral     ::= Digit {Digit} '.' Digit {Digit} [('E'|'e') ['+'|'-'] Digit {Digit}]

StringLiteral   ::= '"' {any_character_except_quote} '"'
                  | "'" {any_character_except_apostrophe} "'"
                  | '[' {any_character_except_bracket} ']'
                  -- UTF-8 explicit (FPXBASE)
                  | 'u' '"' {any_character_except_quote} '"'
                  | 'u8' '"' {any_character_except_quote} '"'
                  | 'U' '"' {any_character_except_quote} '"'

DateLiteral     ::= CToD(StringLiteral) | {StrictDateLiteral}
StrictDateLiteral ::= '0d' Digit Digit Digit Digit '-' Digit Digit '-' Digit Digit

LogicalLiteral  ::= '.T.' | '.F.' | 'TRUE' | 'FALSE'
NIL             ::= 'NIL'
```

---

## 2. Sistema de Tipos

### 2.1 Tipos Primitivos

```ebnf
DataType ::=
    'ARRAY'    | ArrayOfType |
    'BLOB'     |
    'CODEBLOCK'| 'BLOCK' |
    'CURSOR'   | 'RECORDSET' |
    'DATE'     | 'DATETIME' |
    'HASH'     | 'MAP' |
    'ITERATOR' |
    'LOGICAL'  | 'BOOLEAN' | 'BOOL' |
    'MEMO'     |
    'NIL'      |
    'NUMERIC'  | 'INTEGER' | 'INT' | 'FLOAT' | 'DOUBLE' |
    'OBJECT'   | 'CLASS' |
    'POINTER'  | SmartPointerType |
    'STRING'   | 'CHARACTER' | 'CHAR' |
    'STRUCT'   |
    'SYMBOL'   |
    GenericInstantiation

SmartPointerType ::=
    'SHARED_PTR' '<' DataType '>' |
    'UNIQUE_PTR' '<' DataType '>' |
    'WEAK_PTR'   '<' DataType '>'
ArrayOfType ::= 'ARRAY' 'OF' DataType

GenericInstantiation ::= Identifier '<' DataType {',' DataType} '>'

GenericParamList ::= '<' GenericParam {',' GenericParam} '>'
GenericParam     ::= Identifier [':' DataType]
```

### 2.2 Declaración con Tipo (FPXBASE)

```ebnf
VarDecl ::= Identifier [':' DataType]
```

### 2.3 Operadores (FPXBASE)

```ebnf
-- Resolución de scope (OOP)
ScopeResolution ::= '::'

-- Acceso nil-safe (OOP moderno)
NilSafeAccess    ::= '?.'
NilCoalesce      ::= '?:'

-- Test de nulidad
NilCheck         ::= '?'

-- Definición de operador en clase
OperatorDecl     ::= 'OPERATOR' OperatorSymbol FormalParams Body 'ENDOPERATOR'
OperatorSymbol   ::= '+' | '-' | '*' | '/' | '%' | '**' |
                      '==' | '!=' | '<' | '<=' | '>' | '>=' |
                      '<<' | '>>' | '&' | '|' | '^' | '~' |
                      '[]' | '++' | '--'
```

Precedencia (de mayor a menor): unarios → `**` → `* / %` → `+ -` → `<< >>` → `< <= > >=` → `== !=` → `&` → `|` → `^` → `&& AND` → `|| OR`.

---

## 3. Estructura del Programa

El punto de entrada del programa sigue esta precedencia:

1. Directiva `#entry Identifier` (override explícito)
2. `FUNCTION Main` o `PROCEDURE Main` (convención moderna)
3. Primer `PROCEDURE` del archivo raíz (solo modo `--legacy`)

`Main` recibe los argumentos de línea de comandos como parámetros formales y retorna `INTEGER` (código de salida):

```ebnf
CompilationUnit ::= {TopLevelCommand}

TopLevelCommand ::=
    CommandStatement |
    FunctionDef |
    ProcedureDef |
    ClassDef |
    StructDef |
    NewTypeDef |
    Command ';'
```

### 3.1 Funciones y Procedimientos

```ebnf
FunctionDef ::= ['STATIC'] 'FUNCTION' Identifier [GenericParamList] '(' [FormalParamList] ')'
                    ['AS' DataType]
                    ['EXPORT' | 'HIDDEN']
                    Body
                ['RETURN' Expression]
                'ENDFUNC' | 'ENDFUNCTION'

ProcedureDef ::= ['STATIC'] 'PROCEDURE' Identifier [GenericParamList] '(' [FormalParamList] ')'
                    Body
                ['RETURN']
                'ENDPROC' | 'ENDPROCEDURE'

FormalParamList ::= FormalParam {',' FormalParam} [',' VariadicParam]
                  | VariadicParam
FormalParam     ::= ['REF'] Identifier [':' DataType] [':=' Expression]
VariadicParam   ::= '...' Identifier [':' DataType]

Body ::= {Statement}
```

### 3.2 Clases (OOP xBASE + FPXBASE)

```ebnf
ClassDef ::=
    'CLASS' Identifier [GenericParamList]
        ['FROM' Identifier {',' Identifier}]
        ['IMPLEMENTS' Identifier {',' Identifier}]
        [ClassClause]
        {ClassMember}
    'ENDCLASS'

ClassClause ::= 'EXPORT' | 'HIDDEN' | 'FRIEND' | 'ABSTRACT' | 'FINAL' | 'SEALED'

ClassMember ::=
    'DATA' Identifier [':' DataType] [Initializer] [AccessSpec] |
    'METHOD' [MethodQualifier] Identifier ['(' [FormalParamList] ')'] [AccessSpec] |
    'INLINE' 'METHOD' [MethodQualifier] Identifier ['(' [FormalParamList] ')'] Body |
    'CONSTRUCTOR' ['(' [FormalParamList] ')'] Body |
    'DESTRUCTOR' Body |
    'PROPERTY' Identifier [':' DataType] PropertyAccessors [Initializer] [AccessSpec] |
    'OPERATOR' OperatorSymbol FormalParams Body 'ENDOPERATOR'

MethodQualifier ::=
    'VIRTUAL' ['ABSTRACT' | 'FINAL' | 'OVERRIDE'] |
    'OVERRIDE' |
    'STATIC' |
    'ABSTRACT'

AccessSpec ::= 'EXPORT' | 'HIDDEN' | 'PROTECTED' | 'FRIEND'
Initializer ::= ':=' Expression

PropertyAccessors ::=
    'GETTER' Identifier |
    'GETTER' Identifier 'SETTER' Identifier |
    'SETTER' Identifier
```

**Semántica de despacho (vtable)**:

- `VIRTUAL` — declara método con despacho dinámico. Entrada en vtable del tipo.
- `ABSTRACT` — método sin cuerpo en la clase actual; las descendientes **deben** implementarlo. La clase que contiene un `ABSTRACT` debe marcarse `ABSTRACT` o `FINAL` no.
- `OVERRIDE` — reemplaza un método virtual de la clase base. Firma debe coincidir exactamente (nombre, parámetros, tipo de retorno). Error `FPX-0410` si no existe el virtual correspondiente.
- `FINAL` (calificador de método) — sella el virtual: las descendientes no pueden sobrescribirlo.
- `SEALED` (clase) — equivalente a `FINAL` aplicado a todos los miembros; no admite descendencia.
- `STATIC` — método de clase, sin `SELF`, no participa en vtable.

**Llamadas a métodos de clase base**:

```ebnf
SuperCall ::= 'SUPER' '::' Identifier ['(' [ArgumentList] ')']
SelfRef   ::= 'SELF' | 'THIS'
```

**Acceso nil-safe** (FPXBASE moderno):

```ebnf
NilSafeMember ::= Expression '?.' Identifier ['(' [ArgumentList] ')']
NilCoalesce   ::= Expression '?:' Expression
```

`obj?.field` retorna `NIL`/`0`/`""` si `obj` es `NIL` sin lanzar excepción.
`obj ?: default` retorna `obj` si no es `NIL`, si no `default`.

**Restricciones**:

- Una clase puede implementar múltiples `INTERFACE`s vía `IMPLEMENTS` (herencia múltiple de interfaz, no de implementación).
- Herencia de implementación es simple: `FROM BaseClass` (sin comas). Las comas son solo para `IMPLEMENTS`.
- `OVERRIDE` no puede cambiar la visibilidad para reducirla (de `EXPORT` a `HIDDEN` es error `FPX-0411`).

---

### 3.2.1 Interfaces (FPXBASE)

```ebnf
InterfaceDef ::=
    'INTERFACE' Identifier [GenericParamList]
        ['FROM' Identifier {',' Identifier}]
        {InterfaceMember}
    'ENDINTERFACE'

InterfaceMember ::=
    'METHOD' Identifier ['(' [FormalParamList] ')'] ['AS' DataType] |
    'PROPERTY' Identifier [':' DataType] ['AS' DataType] PropertyAccessors
```

- Una `INTERFACE` solo declara contratos (sin cuerpo, sin `DATA`).
- Una clase los cumple con `IMPLEMENTS IInterface1, IInterface2`.
- Las interfaces pueden heredar de otras interfaces con `FROM`.
- Las propiedades de interfaz solo declaran el contrato del getter/setter (sin cuerpo).

**Ejemplo**:

```xbase
INTERFACE IComparable
    METHOD Compare(other: OBJECT) AS INTEGER
ENDINTERFACE

INTERFACE ISerializable FROM IComparable
    METHOD Serialize() AS STRING
ENDINTERFACE

CLASS MyClass IMPLEMENTS ISerializable
    DATA Value: INTEGER

    METHOD Compare(other: OBJECT) AS INTEGER
        ...
    ENDMETHOD

    METHOD Serialize() AS STRING
        ...
    ENDMETHOD
ENDCLASS
```

### 3.3 Structs (FPXBASE)

```ebnf
StructDef ::=
    'STRUCT' Identifier [GenericParamList] [AlignSpec]
        {StructMember}
    'ENDSTRUCT'

AlignSpec ::= 'ALIGN' '(' NumericLiteral ')'

StructMember ::=
    Identifier ':' DataType [ArrayDim] [Initializer] |
    'PADDING' '(' Expression ')'

ArrayDim ::= '[' Expression ']'
```

Los `STRUCT` son tipos valor: se copian en asignación, se asignan en stack por defecto,
no tienen herencia ni refcount/GC. Pueden tener métodos (`METHOD`/`INLINE METHOD`)
como las clases, pero sin herencia ni polimorfismo.

Acceso a miembros: `Expression '.' Identifier`

Inicialización: `StructType '(' [ExpressionList] ')'`

### 3.4 Tipos Personalizados (FPXBASE)

`NEWTYPE` crea un tipo distinto (wrapping) sobre un tipo base — no intercambiable con este en asignaciones. Ideal para identificadores fuertes (`UserId`, `OrderId`, etc.).

```ebnf
NewTypeDef ::=
    'NEWTYPE' Identifier [GenericParamList] '=' DataType
    'ENDNEWTYPE'
```

Conversión explícita vía `CAST<BaseType>(newtypeVal)` y viceversa con `CAST<NewType>(baseVal)`.

---

## 4. Sentencias

### 4.1 Declaraciones de Variables

```ebnf
VariableDeclaration ::=
    ('LOCAL' | 'PRIVATE' | 'PUBLIC' | 'STATIC') VarDeclList

VarDeclList ::= VarDeclItem {',' VarDeclItem}
VarDeclItem ::= Identifier [':' DataType] [':=' Expression | ArrayLiteral | HashLiteral]

MemvarDecl ::= 'MEMVAR' Identifier {',' Identifier}
FieldDecl  ::= 'FIELD' Identifier {',' Identifier}
```

### 4.2 Asignación

```ebnf
AssignmentStatement ::=
    Variable '=' Expression |
    Variable ':=' Expression |
    Variable '+=' Expression |
    Variable '-=' Expression |
    Variable '*=' Expression |
    Variable '/=' Expression |
    Variable '%=' Expression |
    Variable '^=' Expression

Variable ::= Identifier [AliasAccess]
```

### 4.3 Control de Flujo (incluye extensiones modernas FPXBASE)

```ebnf
IfStatement ::=
    'IF' Expression
        {Statement}
    {'ELSEIF' Expression
        {Statement}}
    ['ELSE'
        {Statement}]
    'ENDIF'

DoWhileStatement ::=
    'DO' 'WHILE' Expression
        {Statement}
        ['LOOP']
        ['EXIT']
    'ENDDO'

WhileStatement ::=
    'WHILE' Expression
        {Statement}
        ['LOOP']
        ['EXIT']
    'END'
    | 'WHILE' Expression
        {Statement}
        ['LOOP']
        ['EXIT']
      'ELSE'                    -- se ejecuta si nunca hubo EXIT
        {Statement}
      'END'

DoUntilStatement ::=            -- FPXBASE: post-condition loop
    'DO' {Statement} 'UNTIL' Expression

InfiniteLoopStatement ::=       -- FPXBASE: bucle infinito
    'LOOP'
        {Statement}
        ['BREAK']
    'ENDLOOP'

ForStatement ::=
    'FOR' Identifier ':=' Expression 'TO' Expression ['STEP' Expression]
        {Statement}
        ['LOOP']
        ['EXIT']
    'NEXT'
    | 'FOR' Identifier ':=' Expression 'DOWNTO' Expression ['STEP' Expression]
        {Statement}
        ['LOOP']
        ['EXIT']
      'NEXT'

ForEachStatement ::=
    'FOREACH' Identifier 'IN' Expression
        {Statement}
        ['LOOP']
        ['EXIT']
    'NEXT'
    | 'FOREACH' Identifier 'IN' Expression
        {Statement}
        ['LOOP']
        ['EXIT']
      'ELSE'                    -- se ejecuta si la colección está vacía
        {Statement}
      'NEXT'
    | 'FOREACH' Identifier ',' Identifier 'IN' Expression  -- key, value para hash
        {Statement}
        ['LOOP']
        ['EXIT']
      'NEXT'

SwitchStatement ::=
    'SWITCH' Expression
        {'CASE' Expression
            {Statement}
            ['EXIT']}
        ['OTHERWISE'
            {Statement}]
    'ENDSWITCH'

DoCaseStatement ::=
    'DO' 'CASE'
        {'CASE' Expression
            {Statement}}
        ['OTHERWISE'
            {Statement}]
    'ENDCASE'

BeginSequenceStatement ::=
    'BEGIN' 'SEQUENCE'
        {Statement}
        ['BREAK' [Expression]]
    ['RECOVER' ['USING' Identifier]]
        {Statement}
    'END' ['SEQUENCE']

WithObjectStatement ::=
    'WITH' 'OBJECT' Expression
        {Statement}
    'ENDWITH'
```

### 4.4 Manejo de Excepciones

```ebnf
TryStatement ::=
    'TRY'
        {Statement}
    {'CATCH' [Identifier]
        {Statement}}
    ['FINALLY'
        {Statement}]
    'ENDTRY'
```

### 4.5 Database Commands (FPXBASE)

```ebnf
DatabaseStatement ::=
    AppendStatement |
    AverageSumCountStatement |
    CloseStatement |
    CommitFlushStatement |
    CopyStatement |
    CreateStatement |
    DeleteRecallStatement |
    EraseFileStatement
    IndexStatement |
    LocateContinueStatement |
    PackZapStatement |
    RenameFileStatement |
    ReplaceStatement |
    ReportLabelStatement |
    SeekFindStatement |
    SelectStatement |
    SetFilterStatement |
    SetOrderStatement |
    SetRelationStatement |
    SkipGoStatement |
    SortStatement |
    TotalStatement |
    UseStatement |

UseStatement ::=
    'USE' StringLiteral
        ['ALIAS' Identifier]
        ['NEW']
        ['READONLY']
        ['EXCLUSIVE']
        ['SHARED']
        ['VIA' StringLiteral]
        ['DB' ':' Identifier]

SelectStatement ::=
    'SELECT' (Identifier | NumericLiteral)
    | 'SELECT' 'TOP' Expression ['PERCENT']
      IdentifierList
      'FROM' Identifier
      ['WHERE' Expression]
      ['ORDER' 'BY' Identifier ['ASC'|'DESC'] {',' Identifier ['ASC'|'DESC']}]
      ['GROUP' 'BY' Identifier {',' Identifier}]
      ['HAVING' Expression]

CloseStatement ::=
    'CLOSE' ('DATABASES' | 'ALL' | Identifier)

AppendStatement ::=
    'APPEND' 'BLANK'
    | 'APPEND' 'FROM' StringLiteral
        ['FIELDS' IdentifierList]
        ['DB' ':' Identifier]
        ['SDF' | 'DELIMITED' ['WITH' (Identifier | StringLiteral)]]

ReplaceStatement ::=
    'REPLACE' Identifier 'WITH' Expression
        {',' Identifier 'WITH' Expression}
        [ScopeClause]
        [ForWhileClause]

DeleteRecallStatement ::=
    ('DELETE' | 'RECALL') [ScopeClause] [ForWhileClause]

PackZapStatement ::=
    'PACK' | 'ZAP'

SeekFindStatement ::=
    'SEEK' Expression
    | 'FIND' StringLiteral

SkipGoStatement ::=
    'SKIP' [Expression]
    | ('GO' | 'GOTO') ('TOP' | 'BOTTOM' | Expression)

LocateContinueStatement ::=
    'LOCATE' [ScopeClause] ForWhileClause
    | 'CONTINUE'

IndexStatement ::=
    'INDEX' 'ON' Expression
        'TAG' Identifier
        ['UNIQUE']
        ['DESCENDING']
        ['FOR' Expression]
        ['DB' ':' Identifier]

    | 'INDEX' 'ON' Expression
        'TO' Identifier
        ['UNIQUE']
        ['FOR' Expression]

SetOrderStatement ::=
    'SET' 'ORDER' 'TO' [NumericLiteral | Identifier]

SetFilterStatement ::=
    'SET' 'FILTER' 'TO' Expression
    | 'SET' 'FILTER' 'TO'

SetRelationStatement ::=
    'SET' 'RELATION' 'TO' [Expression] 'INTO' Identifier
    | 'SET' 'RELATION' 'TO'

CommitFlushStatement ::=
    'COMMIT' | 'FLUSH'

SortStatement ::=
    'SORT' 'TO' Identifier
        'ON' Identifier ['/' ('A'|'D'|'C')]
        {',' Identifier ['/' ('A'|'D'|'C')]}
        [ScopeClause]
        [ForWhileClause]

AverageSumCountStatement ::=
    ('AVERAGE' | 'SUM' | 'COUNT')
        [ExpressionList]
        'TO' IdentifierList
        [ScopeClause]
        [ForWhileClause]

TotalStatement ::=
    'TOTAL' 'ON' IdentifierList
        'TO' Identifier
        ['FIELDS' IdentifierList]
        [ScopeClause]
        [ForWhileClause]

CopyStatement ::=
    'COPY' 'TO' Identifier
        ['FIELDS' IdentifierList]
        [ScopeClause]
        [ForWhileClause]
        ['DB' ':' Identifier]

    | 'COPY' 'STRUCTURE' 'TO' Identifier
        ['FIELDS' IdentifierList]

    | 'COPY' 'STRUCTURE' 'EXTENDED' 'TO' Identifier

ReportLabelStatement ::=
    ('REPORT' | 'LABEL') 'FORM' Identifier
        [ScopeClause]
        [ForWhileClause]
        ['TO' 'PRINT']
        ['TO' 'FILE' Identifier]

CreateStatement ::=
    'CREATE' Identifier
    | 'CREATE' Identifier 'FROM' Identifier

```

### 4.6 SET Commands

```ebnf
SetStatement ::=
    'SET' SetSubject ['TO' SetValue]

SetSubject ::=
    'ALTERNATE' | 'BELL' | 'CENTURY' | 'COLOR' | 'CONFIRM' |
    'CONSOLE' | 'CURSOR' | 'DATE' | 'DECIMALS' | 'DEFAULT' |
    'DB' | 'CONNECTION'
    'DELETED' | 'DELIMITERS' | 'DESCENDING' | 'DEVICE' |
    'EPOCH' | 'ESCAPE' | 'EVENTMASK' | 'EXACT' | 'EXCLUSIVE' |
    'FILTER' | 'FIXED' | 'FORMAT' | 'FUNCTION' |
    'INDEX' | 'INTENSITY' | 'KEY' | 'MARGIN' |
    'MEMOBLOCK' | 'MESSAGE' | 'OPTIMIZE' | 'ORDER' |
    'PATH' | 'PRINTER' | 'PROCEDURE' | 'RELATION' |
    'SCOPE' | 'SCOPEBOTTOM' | 'SCOPETOP' | 'SCOREBOARD' |
    'SOFTSEEK' | 'TYPEAHEAD' | 'UNIQUE' | 'VIDEOMODE' | 'WRAP' |
```

### 4.7 I/O Commands

```ebnf
InputOutputStatement ::=
    SayCommand |
    GetCommand |
    ReadCommand |
    InputCommand |
    AcceptCommand |
    WaitCommand |
    TextCommand |
    ClearCommand |
    EjectCommand

SayCommand ::=
    '@' Expression ',' Expression
        'SAY' Expression
        ['PICTURE' StringLiteral]
        ['COLOR' StringLiteral]

GetCommand ::=
    '@' Expression ',' Expression
        'GET' Variable
        ['PICTURE' StringLiteral]
        ['COLOR' StringLiteral]
        ['RANGE' Expression ',' Expression]
        ['VALID' Expression]
        ['WHEN' Expression]
    | '@' Expression ',' Expression 'GET' 'CHECKBOX' Variable
        ['MESSAGE' StringLiteral]
    | '@' Expression ',' Expression 'GET' 'LISTBOX' Variable
        'ITEMS' ArrayLiteral
        ['SIZE' Expression ',' Expression]
    | '@' Expression ',' Expression 'GET' 'PUSHBUTTON' Variable
        'PROMPT' StringLiteral
        ['SIZE' Expression ',' Expression]
        ['MESSAGE' StringLiteral]
    | '@' Expression ',' Expression 'GET' 'RADIOGROUP' Variable
        'ITEMS' ArrayLiteral
        ['SIZE' Expression ',' Expression]
    | '@' Expression ',' Expression 'GET' 'TBROWSE' Variable
        'SIZE' Expression ',' Expression
        ['DATABASE' Identifier]

ReadCommand ::= 'READ' ['SAVE']

InputCommand ::=
    'INPUT' [StringLiteral] 'TO' Identifier

AcceptCommand ::=
    'ACCEPT' [StringLiteral] 'TO' Identifier

WaitCommand ::=
    'WAIT' [StringLiteral] ['TO' Identifier]

TextCommand ::= 'TEXT' ['TO' Identifier] ['TO' 'PRINT'] Body 'ENDTEXT'

ClearCommand ::=
    'CLEAR' ('SCREEN' | 'GETS' | 'MEMORY' | 'TYPEAHEAD' | 'ALL')
    | '@' Expression ',' Expression 'CLEAR' ['TO' Expression ',' Expression]

EjectCommand ::= 'EJECT'
```

### 4.8 Menú y Ventana

```ebnf
MenuWindowStatement ::=
    MenuCommand |
    PromptCommand |
    ActivateMenuCommand |
    DefineWindowCommand |
    ActivateWindowCommand

MenuCommand ::=
    '@' Expression ',' Expression 'PROMPT' Expression
    ['MESSAGE' Expression]

    | 'MENU' 'TO' Identifier

DefineWindowCommand ::=
    'DEFINE' 'WINDOW' Identifier
    'FROM' Expression ',' Expression
    'TO' Expression ',' Expression
    ['TITLE' StringLiteral]
    ['DOUBLE' | 'PANEL' | 'NONE']

ActivateWindowCommand ::=
    'ACTIVATE' 'WINDOW' Identifier
    | 'DEACTIVATE' 'WINDOW' Identifier
    | 'HIDE' 'WINDOW' Identifier
    | 'SHOW' 'WINDOW' Identifier
```

### 4.10 Concurrencia y Tasks (FPXBASE)

```ebnf
ConcurrencyStatement ::=
    TaskStatement |
    AsyncStatement |
    AwaitStatement |
    ChannelStatement |
    MutexStatement |
    SemaphoreStatement |
    AtomicStatement |
    ThreadLocalDecl |
    LockStatement |
    GCStatement

TaskStatement ::=
    'TASK' 'CREATE' '(' Expression ')' [Identifier]  -- TaskCreate(func)
    | 'TASK' 'WAIT' Expression                        -- TaskWait(task)
    | 'TASK' 'YIELD'                                  -- TaskYield()
    | 'SPAWN' Expression                              -- spawn func()

AsyncStatement ::=
    'ASYNC' FunctionDef                               -- async function

AwaitStatement ::=
    'AWAIT' Expression                                -- await future

ChannelStatement ::=
    'CHANNEL' Identifier [':' DataType]               -- decl
    | 'SEND' Expression 'TO' Identifier               -- send val to chan
    | 'RECEIVE' Identifier [Identifier ':=' ]         -- receive from chan
    | 'SELECT' '{' SelectCase {SelectCase} '}'        -- select on channels

SelectCase ::=
    'CASE' 'RECEIVE' Identifier [Identifier ':=' ] '=>' {Statement}
    | 'CASE' 'SEND' Expression 'TO' Identifier '=>' {Statement}
    | 'CASE' 'DEFAULT' '=>' {Statement}

MutexStatement ::=
    'MUTEX' Identifier                                -- decl
    | 'LOCK' Identifier                               -- lock mutex
    | 'UNLOCK' Identifier                             -- unlock mutex
    | 'TRYLOCK' Identifier [ 'THEN' {Statement} ]     -- try lock

SemaphoreStatement ::=
    'SEMAPHORE' Identifier [':' Expression]           -- decl with count
    | 'WAIT' Identifier                               -- sem_wait
    | 'SIGNAL' Identifier                             -- sem_post

AtomicStatement ::=
    'ATOMIC' '{' {Statement} '}'                      -- atomic block
    | 'ATOMIC' Identifier ':=' Expression             -- atomic assign
    | 'ATOMIC' 'INC' Identifier                       -- atomic inc
    | 'ATOMIC' 'DEC' Identifier                       -- atomic dec
    | 'ATOMIC' 'CAS' Identifier ',' Expression ',' Expression  -- compare-and-swap

ThreadLocalDecl ::=
    'THREAD_LOCAL' Identifier [':' DataType] [':=' Expression]

LockStatement ::=
    'LOCK' Identifier                                 -- lock (mutex/semaphore)
    | 'UNLOCK' Identifier                             -- unlock
    | 'TRYLOCK' Identifier [ 'THEN' {Statement} ]     -- try lock

GCStatement ::=
    '#pragma' 'gc' '(' ('refcount' | 'generational' | 'manual' ) ')'
    | '#pragma' 'gc' 'off'

ScopeClause ::=
    'ALL' | 'REST' | 'NEXT' Expression | 'RECORD' Expression

ForWhileClause ::=
    'FOR' Expression | 'WHILE' Expression

IdentifierList ::= Identifier {',' Identifier}
ExpressionList ::= Expression {',' Expression}
ActualParamList ::= ActualParam {',' ActualParam}
ActualParam ::= Expression | Identifier ':=' Expression

CommandLine ::= {any_character}
```

---

### 4.11 Misceláneos

```ebnf
MiscStatement ::=
    'KEYBOARD' StringLiteral |
    'TYPE' StringLiteral ['TO' 'PRINT'] |
    'RUN' | '!' CommandLine |
    'CALL' Identifier ['(' [ExpressionList] ')'] |
    'QUIT' |
    'CANCEL' |
    'ANNOUNCE' Identifier |
    'REQUEST' IdentifierList |
    'EXTERNAL' IdentifierList |
    'INIT' 'PROCEDURE' Identifier |
    'EXIT' 'PROCEDURE' Identifier |
    'STORE' Expression 'TO' IdentifierList |
    'DECLARE' Identifier '[' Expression ']' [':' DataType] |
    'YIELD' Expression
```

---

## 5. Expresiones

### 5.1 Jerarquía de Operadores

```ebnf
Expression        ::= LogicalOrExpr

LogicalOrExpr     ::= LogicalAndExpr { ('.OR.' | '||') LogicalAndExpr }
LogicalAndExpr    ::= NotExpr { ('.AND.' | '&&') NotExpr }
NotExpr           ::= ['.NOT.' | '!'] ComparisonExpr

ComparisonExpr    ::= ConcatExpr
                      [ ('=' | '==' | '!=' | '<>' | '#' | '<' | '<=' | '>' | '>=' | '$')
                        ConcatExpr ]

ConcatExpr        ::= AddExpr { ('+' | '-') AddExpr }
AddExpr           ::= MulExpr { ('+' | '-') MulExpr }
MulExpr           ::= UnaryExpr { ('*' | '/' | '%') UnaryExpr }
UnaryExpr         ::= ('+' | '-') PowerExpr | PowerExpr
PowerExpr         ::= PrimaryExpr { ('**' | '^') PrimaryExpr }
PrimaryExpr ::=
    Literal |
    Variable |
    '(' Expression ')' |
    FunctionCall |
    CastExpr |
    CodeBlock |
    ArrayLiteral |
    HashLiteral |
    StructLiteral |
    ObjectMethodCall |
    StructMemberAccess |
    DerefExpr |
    AliasAccess |
    MacroExpression |
    MacroVariable |
    IIFExpression |
    'SELF' |
    'SUPER' |
    -- FPXBASE: Concurrencia
    'AWAIT' Expression |
    'SPAWN' Expression |
    'SEND' '(' Expression ',' Expression ')' |
    'RECEIVE' '(' Expression ')' |
    'SELECT' '{' {SelectCase} '}' |
    'NEW' 'MUTEX' |
    'NEW' 'SEMAPHORE' '(' Expression ')' |
    'ATOMIC' '(' Expression ')' |
    'LOCK' '(' Expression ')' |
    'UNLOCK' '(' Expression ')' |
    'TRYLOCK' '(' Expression ')'

SelectCase ::=
    'CASE' 'SEND' '(' Expression ',' Expression ')' ':' {Statement} |
    'CASE' 'RECEIVE' '(' Expression ')' ':' {Statement} |
    'CASE' 'DEFAULT' ':' {Statement}

FunctionCall ::=
    Identifier '(' [ActualParamList] ')' |
    'MAKE_UNIQUE' '<' DataType '>' '(' [ActualParamList] ')' |
    'MAKE_SHARED' '<' DataType '>' '(' [ActualParamList] ')'

CastExpr ::=
    'CAST' '<' DataType '>' '(' Expression ')' |
    Expression 'AS' DataType

ObjectMethodCall ::=
    Expression ':' Identifier ['(' [ActualParamList] ')']

StructLiteral ::=
    Identifier '(' [ActualParamList] ')'

StructMemberAccess ::=
    Expression '.' Identifier

DerefExpr ::= Expression '^'

AliasAccess ::=
    ('->' | '.') Identifier |
    '(' Expression ')' '->' Identifier

CodeBlock ::=
    '{' ['|' FormalParamList '|'] {Statement} '}'

ArrayLiteral ::=
    '{' [ExpressionList] '}'

HashLiteral ::=
    '{' HashPair {',' HashPair} '}'

HashPair ::= Expression '=>' Expression

MacroExpression ::= '&' '(' Expression ')'
MacroVariable   ::= '&' Identifier

IIFExpression ::=
    'IIF' '(' Expression ',' Expression ',' Expression ')'
```

---

## 6. Preprocesador

```ebnf
PreprocessorDirective ::=
    IncludeDirective |
    DefineDirective |
    UndefDirective |
    IfDefDirective |
    IfNDefDirective |
    ErrorDirective |
    StdOutDirective |
    CommandTranslateDirective |
    XCommandTranslateDirective

IncludeDirective ::=
    '#include' StringLiteral
    | '#include' '<' Identifier '>'

DefineDirective ::=
    '#define' Identifier [ReplaceList]

ReplaceList ::= '[' FormalParamList ']' Text

UndefDirective ::= '#undef' Identifier

IfDefDirective ::= '#ifdef' Identifier TextBlock ['#else' TextBlock] '#endif'
IfNDefDirective ::= '#ifndef' Identifier TextBlock ['#else' TextBlock] '#endif'

ErrorDirective ::= '#error' StringLiteral

StdOutDirective ::= '#stdout' StringLiteral

CommandTranslateDirective ::=
    '#command' Pattern '=>' Translation
    | '#translate' Pattern '=>' Translation

XCommandTranslateDirective ::=
    '#xcommand' Pattern '=>' Translation
    | '#xtranslate' Pattern '=>' Translation

Pattern ::= '[' PatternArg ']' {PatternArg}
PatternArg ::= '<' Identifier ['(' ... ')' ] '>' | Identifier | StringLiteral
Translation ::= {any_character}

TextBlock ::= {any_character}
```

---

## 7. Sentencias SQL Embebido (FPXBASE)

```ebnf
SQLStatement ::=
    SQLExecuteStatement |
    SQLPrepareStatement |
    SQLCursorStatement |
    SQLOpenStatement |
    SQLCloseStatement

SQLExecuteStatement ::=
    'EXECUTE' 'SQL' StringLiteral
    ['INTO' IdentifierList]
    ['USING' ExpressionList]

SQLPrepareStatement ::=
    'PREPARE' Identifier 'FROM' StringLiteral

SQLCursorStatement ::=
    'DECLARE' Identifier 'CURSOR' 'FOR' StringLiteral

SQLOpenStatement ::=
    'OPEN' Identifier
    ['USING' ExpressionList]
    ['INTO' IdentifierList]

SQLCloseStatement ::=
    'CLOSE' Identifier

```

---

## 8. Expresiones DB (FPXBASE)

```ebnf
DBExpression ::=
    'DB' ':' Identifier        -- cambio de base de datos activa
    | 'DB' '->' Identifier     -- acceso a cursor de otra DB

ConnectionString ::=
    'CONNECTION' StringLiteral

DBOptions ::=
    'SQLITE' |
    'POSTGRESQL' |
    'MSSQL' |
    'MYSQL'
```

---

## 9. Gramática de Directivas de Compilación

```ebnf
CompilerDirective ::=
    '-n' | '-a' | '-m' | '-o' Path |
    '-p' | '-i' Path | '-D' Identifier ['=' Value] |
    '--target' ('win32' | 'win64' | 'linux32' | 'linux64') |
    '--db' ('sqlite' | 'postgresql' | 'mssql') |
    '--connection' StringLiteral |
    '--legacy' |
    '--strict' | '--no-strict' |
    '--db-ansi' |
    '--gc' ('refcount' | 'generational' | 'manual' | 'none') |
    '--jobs' IntegerLiteral |
    '--output-type' ('exe' | 'dll' | 'so' | 'lib' | 'a') |
    '--optimize' ('0' | '1' | '2' | '3')

PragmaDirective ::=
    '#pragma' 'gc' '(' ('refcount' | 'generational' | 'manual' | 'none') ')'
    | '#pragma' 'gc' 'off'
    | '#pragma' 'strict' '(' ('on' | 'off') ')'
    | '#pragma' 'strict' ('on' | 'off')
    | '#pragma' 'db_ansi' ('on' | 'off')
    | '#pragma' 'legacy' ('on' | 'off')

LegacyStrictDirective ::=
    '#strict' ('on' | 'off')           (* forma abreviada, equivalente a '#pragma strict' *)
    | '#strict' '(' ('on' | 'off') ')'  (* forma canónica con paréntesis *)

EntryDirective ::=
    '#entry' Identifier
```

- Si no hay `#entry`, el entry point se resuelve como: `FUNCTION Main` / `PROCEDURE Main` → primer `PROCEDURE` del archivo raíz (solo `--legacy`)
- `FUNCTION Main` puede ser `Main(...)` (variádico) o `Main(p1 : STRING, p2 : STRING, ...)`
- `Main` retorna `INTEGER` (código de salida, 0 = éxito por defecto)
- `#pragma gc` controla el modo de gestión de memoria por archivo/bloque
- `#pragma strict` controla tipado estricto por archivo/bloque
- `--gc` flag CLI establece el default global

**Implementación:**

| Directiva                                 | Estado                                                              |
|-------------------------------------------|---------------------------------------------------------------------|
| `-n`, `-a`, `-m`, `-o`, `-p`, `-i`, `-D`  | Implementadas en `fx.cli.pas`                                      |
| `--target`, `--db`, `--connection`        | Implementadas en `fx.cli.pas`                                      |
| `--legacy`, `--strict`, `--no-strict`     | **Flags CLI** reconocidos en `fx.cli.pas`; procesamiento semántico pendiente |
| `--gc`, `--jobs`, `--output-type`, `--optimize` | Flags CLI reconocidas; efectos pendientes (`fx.backend`/`fx.rtl` son stubs) |
| `#pragma strict` / `#strict`              | **Roadmap:** directiva léxica documentada, sin efecto en `fx.preprocessor.pas` |
| `#pragma gc`                              | **Roadmap:** directiva léxica documentada, sin efecto                |
| `#entry`                                  | **Roadmap:** directiva léxica documentada, sin efecto                |

---

## 10. Apéndice: Comandos Obsoletos (Modo Legacy)

Los siguientes comandos se aceptan solo en modo `--legacy` y emiten un warning:

```ebnf
LegacyCommand ::=
    'ACCEPT' StringLiteral 'TO' Identifier |
    'CALL' Identifier |
    'CLEAR' 'ALL' |
    'DECLARE' IdentifierList |
    'DIR' [StringLiteral] |
    'DISPLAY' 'MEMORY' |
    'DISPLAY' 'STRUCTURE' |
    'FIND' StringLiteral |
    'INPUT' StringLiteral 'TO' Identifier |
    'LIST' 'MEMORY' |
    'LIST' 'STRUCTURE' |
    'RESTORE' 'FROM' Identifier |
    'RESTORE' 'SCREEN' |
    'SAVE' 'SCREEN' 'TO' Identifier |
    'SAVE' 'TO' Identifier |
    'SET' 'COLOR' 'TO' StringLiteral |
    'SET' 'FORMAT' 'TO' Identifier |
    'SET' 'PROCEDURE'
    'SET' 'PROCEDURE' 'TO' Identifier |
    'SET' 'UNIQUE' ('ON' | 'OFF') |
    'TEXT' 'TO' Identifier |
```

---

## 11. Roadmap — Tipado Gradual y Smart Pointers

> **Estado:** Roadmap — pendiente de implementación. Los tokens léxicos (`kwStruct`, `kwClass`, `kwUnique_ptr`, `kwShared_ptr`, `kwWeak_ptr`) **existen en** `src/fx/fx.tokens.pas`/`fx.lexer.pas`, pero el parser no los trata como modificadores semánticos: no hay distinción stack/heap en el IR, ni ownership tracking, ni verificación de `#pragma strict`. El detalle estratégico (tiers, prefetching, ejemplos) está en `docs/COMPATIBILITY-STRATEGY.md` y `docs/PRD-FPXBASE.md` §5.A–5.C.

### 11.1 Directivas de Estrictez y Tipado Gradual

```ebnf
StrictDirective ::=
      '#pragma' 'strict' '(' ('on' | 'off') ')'
    | '#pragma' 'strict' ('on' | 'off')
    | '#strict' ('on' | 'off')                       (* legacy alias *)
    | '#strict' '(' ('on' | 'off') ')'

TypeAnnotation ::=
      Identifier ':' DataType                       (* forma canónica FPXBASE *)
    | Identifier 'AS' DataType                      (* forma xBASE heredada *)
```

**Semántica:**

| Modo          | `LOCAL x` sin tipo    | `LOCAL x : INTEGER`        | Cast runtime                |
|---------------|-----------------------|----------------------------|-----------------------------|
| `#strict OFF` | `VARIANT` / `ANY`     | Validado, free reasignable | Implícito (coerción)        |
| `#strict ON`  | **Error: FPX-T-0103** | Validado en compile-time   | Requiere `AS` o `CAST<T>()` |

```xbase
#pragma strict(off)              // legacy, variantes dinámicas
LOCAL n := 42                    // n : VARIANT

#pragma strict(on)               // strict, requiere anotación
LOCAL n : INTEGER := 42          // OK
LOCAL m := 42                    // Error: FPX-T-0103 — tipo requerido
LOCAL m : INTEGER := "hola"      // Error: FPX-T-0104 — tipo incompatible
```

### 11.2 STRUCT (tipo valor) vs CLASS (tipo referencia)

```ebnf
StructDef ::=
    'STRUCT' Identifier [GenericParamList] [AlignSpec]
        {StructMember}
    'ENDSTRUCT'

ClassDef ::=
    'CLASS' Identifier [GenericParamList]
        ['WITH' ClassModifier]
        ['FROM' ParentClassList]
        ['IMPLEMENTS' InterfaceList]
        {ClassMember}
    'ENDCLASS'

ClassModifier ::=
    'NO' 'GC'                                         (* manual / RAII *)

GenericParamList ::=
    '<' Identifier [',' Identifier]* '>'

StructMember ::=
      Identifier ':' DataType [ArrayDim] [Initializer]
    | 'METHOD' Identifier '(' [FormalParamList] ')' [':' DataType] MethodBody
    | 'INLINE' 'METHOD' ...
    | 'PADDING' '(' Expression ')'

ClassMember ::=
      Identifier [':' DataType] ['=>' Initializer]     (* propiedad auto *)
    | 'METHOD' ...
    | 'INLINE' 'METHOD' ...
    | 'CONSTRUCTOR' ...
    | 'DESTRUCTOR' ...
```

| Forma                       | Asignación | Lifetime                          |
|-----------------------------|------------|-----------------------------------|
| `STRUCT Foo … ENDSTRUCT`    | **Stack**  | Léxico (RAII) — copia por asignación |
| `CLASS Foo … ENDCLASS`      | **Heap**   | RefCount + cycle detection (default) |
| `CLASS Foo WITH NO GC …`    | **Heap**   | Manual (`DISPOSE`, `FREE`)          |

### 11.3 Smart Pointers

```ebnf
SmartPointerType ::=
      'UNIQUE_PTR'  '<' DataType '>'
    | 'SHARED_PTR'  '<' DataType '>'
    | 'WEAK_PTR'    '<' DataType '>'

SmartPtrDecl ::=
    Identifier ':' SmartPointerType [':=' SmartPtrInitializer]

SmartPtrInitializer ::=
      'UniquePtr' '<' DataType ',' Expression '>'     (* UNIQUE_PTR<T> con recurso *)
    | 'SharedPtr' '<' DataType ['(' Expression ')'] '>'
    | 'WeakPtr'   '<' DataType ['(' Expression ')'] '>'
    | 'NIL'
```

| Modificador     | Modelo de ownership   | Uso típico                                |
|-----------------|-----------------------|-------------------------------------------|
| `UNIQUE_PTR<T>` | Exclusivo, transferible (`MOVE()`) | Recursos críticos (archivos, sockets, locks) |
| `SHARED_PTR<T>` | Compartido, refcount   | Recursos compartidos entre hilos/módulos  |
| `WEAK_PTR<T>`   | Observador no-propietario | Cache, callbacks, romper ciclos         |

**Operaciones:**

```xbase
LOCAL file : UNIQUE_PTR<HANDLE> := UniquePtr<HANDLE, OpenFile("data.bin")>
LOCAL cache : SHARED_PTR<HashTable> := SharedPtr{HashTable}
LOCAL weak  : WEAK_PTR<HashTable> := WeakPtr{cache}

LOCAL locked := weak.LOCK()           (* devuelve SHARED_PTR o NIL si expiró *)
IF locked != NIL THEN
   ? locked["key"]
ENDIF

LOCAL other : UNIQUE_PTR<HANDLE> := MOVE(file)    (* transferencia explícita *)
file := NIL                                       (* tras MOVE, source queda NIL *)
```

### 11.4 Estado de implementación (resumen)

| Elemento                                          | Estado                                                         |
|---------------------------------------------------|----------------------------------------------------------------|
| `STRUCT Foo … ENDSTRUCT`                          | Sintaxis parseada; semántica valor (stack) pendiente de IR/RTL |
| `CLASS Foo … ENDCLASS`                            | Sintaxis parseada; semántica heap pendiente                    |
| `UNIQUE_PTR<T>` / `SHARED_PTR<T>` / `WEAK_PTR<T>` | Tokens en `fx.tokens.pas`; ningún uso semántico aún           |
| `#pragma strict` / `#strict`                      | Directiva léxica documentada; sin efecto en preprocesador      |
| `Identifier AS DataType` (forma legacy xBASE)     | Soportado en `fx.parser.pas` desde Phase 1.1                  |
| `Identifier : DataType` (forma FPXBASE canónica)  | Soportado en `fx.parser.pas` desde Phase 1.1                  |
| Validación strict en IR                           | **Pendiente** (Fase 2.5)                                       |

---

> **Nota:** Esta gramática cubre el subconjunto completo del lenguaje xBASE (Clipper 5.x, Harbour, FoxPro) necesario para la compatibilidad con FPXBASE. Las extensiones modernas (tipado, SQL embebido, OOP) son específicas de FPXBASE. Todos los comandos xBASE tradicionales que operaban sobre .dbf e índices nativos se traducen a SQL en tiempo de compilación según la especificación del PRD.
