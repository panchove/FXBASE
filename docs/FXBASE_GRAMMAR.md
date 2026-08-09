# FXBASE — Formal Grammar Specification (GRAMMAR.PRD)

**Version:** 1.0.0-alpha  
**Date:** 2026-08-08  
**Status:** Derived from PRD v1.0.0  

---

## 1. Grammar Notation

This grammar uses **EBNF (Extended Backus-Naur Form)** with the following conventions:

| Symbol | Meaning |
|--------|---------|
| `::=` | Definition |
| `|` | Alternative |
| `[ ... ]` | Optional (zero or one) |
| `{ ... }` | Repetition (zero or more) |
| `( ... )` | Grouping |
| `"..."` | Terminal literal (case-sensitive) |
| `'...'` | Terminal literal (case-insensitive) |
| `IDENTIFIER` | Non-terminal (lexical token) |
| `KEYWORD` | Reserved word token |

---

## 2. Lexical Structure

### 2.1 Character Set
- Source files encoded in **UTF-8**
- Identifiers support Unicode letters (Lu, Ll, Lt, Lm, Lo, Nl) and underscores
- First character: letter or underscore
- Subsequent: letter, digit, underscore, or Unicode mark (Mn, Mc)

### 2.2 Tokens

```
token ::= KEYWORD
        | IDENTIFIER
        | LITERAL
        | OPERATOR
        | PUNCTUATOR
        | ANNOTATION
        | COMMENT
```

### 2.3 Keywords (Reserved Words)

```
KEYWORD ::= 'AND' | 'AS' | 'ASYNC' | 'AWAIT' | 'BREAK' | 'BYREF' | 'BYVAL'
          | 'CASE' | 'CATCH' | 'CLASS' | 'CONSTRUCTOR' | 'CONTINUE' | 'DECIMAL'
          | 'DEFAULT' | 'DO' | 'ELSE' | 'ELSEIF' | 'END' | 'ENDCASE' | 'ENDDO'
          | 'ENDFOR' | 'ENDIF' | 'ENDMATCH' | 'EXIT' | 'EXPORT' | 'FALSE'
          | 'FINALLY' | 'FOR' | 'FOREACH' | 'FROM' | 'FUNCTION' | 'GLOBAL'
          | 'HIDDEN' | 'IF' | 'IMPORT' | 'IN' | 'INHERIT' | 'INT' | 'IS'
          | 'LOCAL' | 'LOGICAL' | 'MATCH' | 'METHOD' | 'MODULE' | 'NEXT'
          | 'NIL' | 'NOT' | 'OBJECT' | 'OPTIONAL' | 'OR' | 'OVERRIDE'
          | 'PRIVATE' | 'PROPERTY' | 'PROTECTED' | 'PUBLIC' | 'RAISE'
          | 'RETURN' | 'SELECT' | 'SELF' | 'SPAWN' | 'STATIC' | 'STEP'
          | 'STRING' | 'STRUCT' | 'SUPER' | 'THEN' | 'THIS' | 'TO' | 'TRUE'
          | 'TRY' | 'TYPEOF' | 'UNTIL' | 'USE' | 'VALID' | 'VAR' | 'WAIT'
          | 'WHERE' | 'WHILE' | 'WITH'
```

**Note:** Keywords are case-insensitive. Convention: UPPER_CASE in grammar, PascalCase in code.

### 2.4 Identifiers

```
IDENTIFIER ::= (LETTER | '_') { LETTER | DIGIT | '_' }
LETTER     ::= Unicode letter categories (Lu, Ll, Lt, Lm, Lo, Nl)
DIGIT      ::= '0'..'9'
```

**Special naming conventions (enforced by linter, not grammar):**
- `n*` prefix → INT/DECIMAL/FLOAT
- `c*` prefix → STRING
- `d*` prefix → DATE/DATETIME
- `l*` prefix → LOGICAL
- `a*` prefix → ARRAY
- `o*` prefix → OBJECT
- `b*` prefix → CODEBLOCK

### 2.5 Literals

```
LITERAL ::= INTEGER_LITERAL
          | FLOAT_LITERAL
          | DECIMAL_LITERAL
          | STRING_LITERAL
          | TEMPLATE_STRING
          | VERBATIM_STRING
          | DATE_LITERAL
          | DATETIME_LITERAL
          | LOGICAL_LITERAL
          | ARRAY_LITERAL
          | HASH_LITERAL
          | CODEBLOCK_LITERAL
          | JSON_LITERAL
          | NIL_LITERAL
```

#### Numeric Literals
```
INTEGER_LITERAL ::= DECIMAL_DIGITS
                  | '0x' HEX_DIGITS
                  | '0b' BINARY_DIGITS

FLOAT_LITERAL   ::= DECIMAL_DIGITS '.' DECIMAL_DIGITS [EXPONENT]
                  | DECIMAL_DIGITS EXPONENT

DECIMAL_LITERAL ::= (DECIMAL_DIGITS '.' DECIMAL_DIGITS
                  | DECIMAL_DIGITS) 'D'

EXPONENT        ::= ('e' | 'E') ['+' | '-'] DECIMAL_DIGITS
DECIMAL_DIGITS  ::= DIGIT {DIGIT}
HEX_DIGITS      ::= HEX_DIGIT {HEX_DIGIT}
BINARY_DIGITS   ::= '0' | '1' {'0' | '1'}
HEX_DIGIT       ::= DIGIT | 'A'..'F' | 'a'..'f'
```

#### String Literals
```
STRING_LITERAL      ::= '"' { STRING_CHAR | ESCAPE_SEQUENCE } '"'
TEMPLATE_STRING     ::= '`' { TEMPLATE_CHAR | ESCAPE_SEQUENCE | INTERPOLATION } '`'
VERBATIM_STRING     ::= '@"' { VERBATIM_CHAR | '""' } '"'

INTERPOLATION       ::= '${' EXPRESSION [ ':' FORMAT_SPEC ] '}'

FORMAT_SPEC         ::= 'N' DIGITS        // Number with thousands separator
                      | 'D' DIGITS        // Decimal with zero padding
                      | 'X' DIGITS        // Hexadecimal
                      | 'ISO'             // ISO 8601 for dates
                      | CUSTOM_FORMAT

ESCAPE_SEQUENCE     ::= '\' ('n' | 't' | 'r' | '"' | '\'' | '\\' | '0' | 'u' HEX_DIGITS_4)

STRING_CHAR         ::= any Unicode char except '"', '\', newline
TEMPLATE_CHAR       ::= any Unicode char except '`', '\', '$'
VERBATIM_CHAR       ::= any Unicode char except '"'
```

#### Date/Time Literals
```
DATE_LITERAL    ::= 'DATE' '(' INTEGER ',' INTEGER ',' INTEGER ')'
DATETIME_LITERAL::= 'DATETIME' '(' STRING_LITERAL ')'  // ISO 8601
```

#### Logical Literals
```
LOGICAL_LITERAL ::= 'TRUE' | 'FALSE'
NIL_LITERAL     ::= 'NIL'
```

#### Collection Literals
```
ARRAY_LITERAL   ::= '{' [ EXPRESSION { ',' EXPRESSION } [ ',' ] ] '}'
                  | 'ARRAY' '<' TYPE '>' '{' [ EXPRESSION { ',' EXPRESSION } ] '}'

HASH_LITERAL    ::= '{|' [ HASH_ENTRY { ',' HASH_ENTRY } [ ',' ] ] '|}'
                  | 'HASH' '<' TYPE ',' TYPE '>' '{|' [ HASH_ENTRY { ',' HASH_ENTRY } ] '|}'

HASH_ENTRY      ::= EXPRESSION '=>' EXPRESSION
```

#### CodeBlock Literals
```
CODEBLOCK_LITERAL ::= '{|' [ PARAMETER_LIST ] '|' STATEMENT_BLOCK '}'
                    | '{|' [ TYPED_PARAMETER_LIST ] '|' STATEMENT_BLOCK '}' 'AS' 'CODEBLOCK' '<' TYPE_LIST '>'

PARAMETER_LIST     ::= IDENTIFIER { ',' IDENTIFIER }
TYPED_PARAMETER_LIST ::= TYPED_PARAMETER { ',' TYPED_PARAMETER }
TYPED_PARAMETER    ::= IDENTIFIER 'AS' TYPE
TYPE_LIST          ::= TYPE { ',' TYPE }
```

#### JSON Literals
```
JSON_LITERAL    ::= JSON_OBJECT | JSON_ARRAY
JSON_OBJECT     ::= '{' [ STRING_LITERAL ':' JSON_VALUE { ',' STRING_LITERAL ':' JSON_VALUE } ] '}'
JSON_ARRAY      ::= '[' [ JSON_VALUE { ',' JSON_VALUE } ] ']'
JSON_VALUE      ::= STRING_LITERAL | NUMBER_LITERAL | JSON_OBJECT | JSON_ARRAY | 'TRUE' | 'FALSE' | 'NULL'
```

### 2.6 Operators and Punctuators

```
OPERATOR ::= '::' | '->' | '++' | '--' | '+' | '-' | '*' | '/' | '%'
           | '<<' | '>>' | '<' | '<=' | '>' | '>=' | '==' | '!=' | '===' | '!=='
           | '&' | '^' | '|' | '&&' | '||' | '?' | ':' | ':='
           | '+=' | '-=' | '*=' | '/=' | '|=' | '&=' | '^=' | '<<=' | '>>='
           | '<-' | '->'  // Channel send/receive

PUNCTUATOR ::= '(' | ')' | '[' | ']' | '{' | '}' | ',' | ';' | ':'
             | '.' | '...' | '@' | '#' | '|' | '=>'
```

### 2.7 Annotations (Attributes)

```
ANNOTATION ::= '[' ANNOTATION_NAME [ '(' [ ANNOTATION_ARGS ] ')' ] ']'
ANNOTATION_NAME ::= IDENTIFIER { '::' IDENTIFIER }
ANNOTATION_ARGS  ::= ANNOTATION_ARG { ',' ANNOTATION_ARG }
ANNOTATION_ARG   ::= IDENTIFIER ':=' EXPRESSION
                   | EXPRESSION
```

### 2.8 Comments

```
COMMENT ::= '//' { any char except newline } newline
          | '/*' { any char except '*/' } '*/'
          | '///' { any char except newline } newline  // Documentation comment
```

---

## 3. Syntax Grammar

### 3.1 Compilation Unit

```
compilation_unit ::= [ MODULE_DECLARATION ] { IMPORT_DECLARATION } { TOP_LEVEL_DECLARATION }
```

### 3.2 Module Declaration

```
MODULE_DECLARATION ::= 'MODULE' MODULE_NAME [ ANNOTATION ] newline
MODULE_NAME        ::= IDENTIFIER { '.' IDENTIFIER }
```

### 3.3 Import Declarations

```
IMPORT_DECLARATION ::= 'IMPORT' IMPORT_SPEC 'FROM' STRING_LITERAL [ ANNOTATION ] newline

IMPORT_SPEC ::= '*'
              | '* AS' IDENTIFIER
              | IDENTIFIER { ',' IDENTIFIER }
              | '{' IDENTIFIER { ',' IDENTIFIER } '}'
```

### 3.4 Top-Level Declarations

```
TOP_LEVEL_DECLARATION ::= FUNCTION_DECLARATION
                        | CLASS_DECLARATION
                        | STRUCT_DECLARATION
                        | ATTRIBUTE_DECLARATION
                        | MODULE_VARIABLE_DECLARATION
                        | EXPORT_DECLARATION
                        | TEST_SUITE_DECLARATION
                        | FORM_DECLARATION
```

### 3.5 Export Declaration

```
EXPORT_DECLARATION ::= 'EXPORT' TOP_LEVEL_DECLARATION
                     | 'EXPORT' 'MODULE' 'VARIABLE' VARIABLE_DECLARATION
```

### 3.6 Function Declaration

```
FUNCTION_DECLARATION ::= [ 'ASYNC' ] 'FUNCTION' IDENTIFIER
                         [ TYPE_PARAMETERS ]
                         '(' [ PARAMETER_LIST ] ')'
                         [ 'AS' RETURN_TYPE ]
                         [ ANNOTATION ] newline
                         STATEMENT_BLOCK
                         'END' [ ANNOTATION ] newline

TYPE_PARAMETERS ::= '<' TYPE_PARAMETER { ',' TYPE_PARAMETER } '>'
TYPE_PARAMETER  ::= IDENTIFIER [ ':' CONSTRAINT ]
CONSTRAINT      ::= TYPE { '|' TYPE }

PARAMETER_LIST  ::= PARAMETER { ',' PARAMETER }
PARAMETER       ::= [ 'BYREF' | 'BYVAL' ] IDENTIFIER [ 'AS' TYPE ] [ ':=' DEFAULT_EXPR ]
                  | '...' IDENTIFIER [ 'AS' TYPE ]  // Variadic

RETURN_TYPE     ::= TYPE
                  | 'RESULT' '<' TYPE ',' TYPE '>'
                  | 'NIL'

DEFAULT_EXPR    ::= EXPRESSION
```

### 3.7 Class Declaration

```
CLASS_DECLARATION ::= 'CLASS' IDENTIFIER [ TYPE_PARAMETERS ]
                      [ 'INHERIT' TYPE_REFERENCE ]
                      [ ANNOTATION ] newline
                      { CLASS_MEMBER }
                      'END' [ ANNOTATION ] newline

CLASS_MEMBER ::= PROPERTY_DECLARATION
               | METHOD_DECLARATION
               | CONSTRUCTOR_DECLARATION
               | ACCESSOR_DECLARATION
               | STATIC_DECLARATION
               | HIDDEN_DECLARATION

PROPERTY_DECLARATION ::= [ 'PROPERTY' ] IDENTIFIER [ 'AS' TYPE ] [ ':=' EXPRESSION ]
                       [ ANNOTATION ] newline

METHOD_DECLARATION ::= [ 'OVERRIDE' ] 'METHOD' IDENTIFIER
                       [ TYPE_PARAMETERS ]
                       '(' [ PARAMETER_LIST ] ')'
                       [ 'AS' RETURN_TYPE ]
                       [ ANNOTATION ] newline
                       STATEMENT_BLOCK
                       'END' [ ANNOTATION ] newline

CONSTRUCTOR_DECLARATION ::= 'CONSTRUCTOR' '(' [ PARAMETER_LIST ] ')'
                            [ ANNOTATION ] newline
                            STATEMENT_BLOCK
                            'END' [ ANNOTATION ] newline

ACCESSOR_DECLARATION ::= 'ACCESS' IDENTIFIER 'AS' TYPE
                         [ ANNOTATION ] newline
                         STATEMENT_BLOCK
                         'END' [ ANNOTATION ] newline

STATIC_DECLARATION ::= 'STATIC' ( FUNCTION_DECLARATION | VARIABLE_DECLARATION )
HIDDEN_DECLARATION ::= 'HIDDEN' ( FUNCTION_DECLARATION | VARIABLE_DECLARATION )
```

### 3.8 Struct Declaration

```
STRUCT_DECLARATION ::= 'STRUCT' IDENTIFIER [ TYPE_PARAMETERS ]
                       [ ANNOTATION ] newline
                       { STRUCT_FIELD }
                       'END' [ ANNOTATION ] newline

STRUCT_FIELD ::= IDENTIFIER 'AS' TYPE [ ANNOTATION ] newline
```

### 3.9 Attribute Declaration

```
ATTRIBUTE_DECLARATION ::= 'ATTRIBUTE' IDENTIFIER '(' [ PARAMETER_LIST ] ')'
                          [ ANNOTATION ] newline
                          STATEMENT_BLOCK
                          'END' [ ANNOTATION ] newline
```

### 3.10 Module Variable Declaration

```
MODULE_VARIABLE_DECLARATION ::= [ 'HIDDEN' | 'EXPORT' ] 'VAR' VARIABLE_DECLARATION
VARIABLE_DECLARATION        ::= IDENTIFIER [ 'AS' TYPE ] [ ':=' EXPRESSION ] [ ANNOTATION ] newline
```

### 3.11 Type References

```
TYPE_REFERENCE ::= SIMPLE_TYPE
                 | GENERIC_TYPE
                 | FUNCTION_TYPE
                 | CHANNEL_TYPE
                 | CODEBLOCK_TYPE
                 | OPTIONAL_TYPE
                 | RESULT_TYPE
                 | UNION_TYPE
                 | INTERSECTION_TYPE

SIMPLE_TYPE    ::= 'NIL' | 'LOGICAL' | 'INT' | 'DECIMAL' | 'FLOAT'
                 | 'STRING' | 'DATE' | 'DATETIME' | 'POINTER'
                 | 'JSON' | 'OBJECT' | 'VARIANT' | IDENTIFIER

GENERIC_TYPE   ::= IDENTIFIER '<' TYPE_LIST '>'

FUNCTION_TYPE  ::= 'FUNCTION' '(' [ TYPE_LIST ] ')' [ 'AS' TYPE ]

CHANNEL_TYPE   ::= 'CHANNEL' '<' TYPE '>'

CODEBLOCK_TYPE ::= 'CODEBLOCK' '<' [ TYPE_LIST ] '>'

OPTIONAL_TYPE  ::= TYPE '?'

RESULT_TYPE    ::= 'RESULT' '<' TYPE ',' TYPE '>'

UNION_TYPE     ::= TYPE '|' TYPE { '|' TYPE }

INTERSECTION_TYPE ::= TYPE '&' TYPE { '&' TYPE }
```

### 3.12 Statements

```
STATEMENT_BLOCK ::= { STATEMENT }

STATEMENT ::= VARIABLE_DECLARATION_STMT
            | ASSIGNMENT_STMT
            | EXPRESSION_STMT
            | IF_STMT
            | MATCH_STMT
            | FOR_STMT
            | FOREACH_STMT
            | WHILE_STMT
            | DO_WHILE_STMT
            | DO_UNTIL_STMT
            | TRY_STMT
            | RETURN_STMT
            | BREAK_STMT
            | CONTINUE_STMT
            | EXIT_STMT
            | SPAWN_STMT
            | AWAIT_STMT
            | WAIT_STMT
            | SELECT_STMT
            | CHANNEL_SEND_STMT
            | CHANNEL_RECV_STMT
            | USE_STMT
            | SET_STMT
            | FORM_STMT
            | BLOCK_STMT

BLOCK_STMT ::= '{' STATEMENT_BLOCK '}'
```

#### Variable Declaration Statement
```
VARIABLE_DECLARATION_STMT ::= [ 'LOCAL' | 'STATIC' | 'MODULE' ] VARIABLE_DECLARATION
```

#### Assignment Statement
```
ASSIGNMENT_STMT ::= LHS ':=' EXPRESSION
                  | LHS OP_ASSIGN EXPRESSION

LHS ::= IDENTIFIER
      | LHS '.' IDENTIFIER
      | LHS '->' IDENTIFIER
      | LHS '[' EXPRESSION ']'
      | '(' LHS ')'

OP_ASSIGN ::= '+=' | '-=' | '*=' | '/=' | '|=' | '&=' | '^=' | '<<=' | '>>='
```

#### Expression Statement
```
EXPRESSION_STMT ::= EXPRESSION
```

#### If Statement
```
IF_STMT ::= 'IF' EXPRESSION newline
            STATEMENT_BLOCK
            { 'ELSEIF' EXPRESSION newline STATEMENT_BLOCK }
            [ 'ELSE' newline STATEMENT_BLOCK ]
            'ENDIF'
```

#### Match Statement (Pattern Matching)
```
MATCH_STMT ::= 'MATCH' EXPRESSION newline
               { MATCH_CASE }
               'END'

MATCH_CASE ::= 'CASE' PATTERN [ 'IF' EXPRESSION ] newline
               STATEMENT_BLOCK

PATTERN ::= '_'
          | LITERAL
          | IDENTIFIER
          | CONSTRUCTOR_PATTERN
          | TUPLE_PATTERN
          | OR_PATTERN

CONSTRUCTOR_PATTERN ::= IDENTIFIER '(' [ PATTERN { ',' PATTERN } ] ')'
TUPLE_PATTERN       ::= '(' [ PATTERN { ',' PATTERN } ] ')'
OR_PATTERN          ::= PATTERN '|' PATTERN { '|' PATTERN }
```

#### For Statement
```
FOR_STMT ::= 'FOR' IDENTIFIER ':=' EXPRESSION 'TO' EXPRESSION [ 'STEP' EXPRESSION ] newline
             STATEMENT_BLOCK
             'NEXT'
```

#### Foreach Statement
```
FOREACH_STMT ::= 'FOREACH' IDENTIFIER 'IN' EXPRESSION newline
                 STATEMENT_BLOCK
                 'NEXT'
```

#### While Statement
```
WHILE_STMT ::= 'DO' 'WHILE' EXPRESSION newline
               STATEMENT_BLOCK
               'ENDDO'
```

#### Do-Until Statement
```
DO_UNTIL_STMT ::= 'DO' 'UNTIL' EXPRESSION newline
                  STATEMENT_BLOCK
                  'ENDDO'
```

#### Try Statement
```
TRY_STMT ::= 'TRY' newline
             STATEMENT_BLOCK
             { CATCH_CLAUSE }
             [ 'FINALLY' newline STATEMENT_BLOCK ]
             'END'

CATCH_CLAUSE ::= 'CATCH' [ IDENTIFIER [ 'AS' TYPE_REFERENCE ] ] newline
                 STATEMENT_BLOCK
```

#### Return Statement
```
RETURN_STMT ::= 'RETURN' [ EXPRESSION ]
```

#### Break / Continue / Exit
```
BREAK_STMT    ::= 'BREAK'
CONTINUE_STMT ::= 'CONTINUE'
EXIT_STMT     ::= 'EXIT' [ EXPRESSION ]
```

#### Concurrency Statements
```
SPAWN_STMT  ::= 'SPAWN' EXPRESSION
AWAIT_STMT  ::= 'AWAIT' EXPRESSION
WAIT_STMT   ::= 'WAIT' 'ALL' [ EXPRESSION ]

SELECT_STMT ::= 'SELECT' newline
                { SELECT_CASE }
                'END'

SELECT_CASE ::= 'CASE' CHANNEL_RECV_PATTERN newline STATEMENT_BLOCK
              | 'CASE' CHANNEL_SEND_PATTERN newline STATEMENT_BLOCK
              | 'CASE' 'DEFAULT' newline STATEMENT_BLOCK

CHANNEL_RECV_PATTERN ::= IDENTIFIER ':=' '<-' EXPRESSION
                       | '<-' EXPRESSION

CHANNEL_SEND_PATTERN ::= EXPRESSION '<-' EXPRESSION

CHANNEL_SEND_STMT ::= EXPRESSION '<-' EXPRESSION
CHANNEL_RECV_STMT ::= IDENTIFIER ':=' '<-' EXPRESSION
                    | '<-' EXPRESSION  // Discard
```

#### Database Statements
```
USE_STMT ::= 'USE' STRING_LITERAL [ 'VIA' STRING_LITERAL ] [ 'ALIAS' IDENTIFIER ]

SET_STMT ::= 'SET' SET_OPTION

SET_OPTION ::= 'INDEX' 'TO' STRING_LITERAL
             | 'RELATION' 'TO' EXPRESSION 'INTO' IDENTIFIER
             | 'EXACT' ( 'ON' | 'OFF' )
             | 'SOFTSEEK' ( 'ON' | 'OFF' )
             | 'DELETED' ( 'ON' | 'OFF' )
             | 'FILTER' 'TO' EXPRESSION
             | 'ORDER' 'TO' STRING_LITERAL
```

#### Form/UI Statements
```
FORM_STMT ::= 'FORM' IDENTIFIER [ 'AS' IDENTIFIER ] [ 'TITLE' STRING_LITERAL ]
              [ 'WIDTH' EXPRESSION ] [ 'HEIGHT' EXPRESSION ] newline
              { FORM_ELEMENT }
              'ENDFORM'

FORM_ELEMENT ::= POSITION_SAY
               | POSITION_GET
               | POSITION_CHECKBOX
               | POSITION_COMBOBOX
               | POSITION_BUTTON
               | READ_STMT

POSITION_SAY ::= '@' EXPRESSION ',' EXPRESSION 'SAY' EXPRESSION

POSITION_GET ::= '@' EXPRESSION ',' EXPRESSION 'GET' LHS
                 [ 'VALID' EXPRESSION ]
                 [ 'MESSAGE' STRING_LITERAL ]
                 [ 'PICTURE' STRING_LITERAL ]
                 [ 'WHEN' EXPRESSION ]

POSITION_CHECKBOX ::= '@' EXPRESSION ',' EXPRESSION 'CHECKBOX' LHS [ 'CAPTION' STRING_LITERAL ]

POSITION_COMBOBOX ::= '@' EXPRESSION ',' EXPRESSION 'COMBOBOX' LHS 'ITEMS' ARRAY_LITERAL

POSITION_BUTTON ::= '@' EXPRESSION ',' EXPRESSION 'BUTTON' STRING_LITERAL 'ACTION' EXPRESSION

READ_STMT ::= 'READ' [ 'MODEL' EXPRESSION ]
```

### 3.13 Expressions

```
EXPRESSION ::= ASSIGNMENT_EXPR

ASSIGNMENT_EXPR ::= LOGICAL_OR_EXPR [ ':=' ASSIGNMENT_EXPR ]
                  | LHS OP_ASSIGN ASSIGNMENT_EXPR

LOGICAL_OR_EXPR  ::= LOGICAL_AND_EXPR { '||' LOGICAL_AND_EXPR }
LOGICAL_AND_EXPR ::= BITWISE_OR_EXPR { '&&' BITWISE_OR_EXPR }
BITWISE_OR_EXPR  ::= BITWISE_XOR_EXPR { '|' BITWISE_XOR_EXPR }
BITWISE_XOR_EXPR ::= BITWISE_AND_EXPR { '^' BITWISE_AND_EXPR }
BITWISE_AND_EXPR ::= EQUALITY_EXPR { '&' EQUALITY_EXPR }
EQUALITY_EXPR    ::= RELATIONAL_EXPR { ( '==' | '!=' | '===' | '!==' ) RELATIONAL_EXPR }
RELATIONAL_EXPR  ::= SHIFT_EXPR { ( '<' | '<=' | '>' | '>=' ) SHIFT_EXPR }
SHIFT_EXPR       ::= ADDITIVE_EXPR { ( '<<' | '>>' ) ADDITIVE_EXPR }
ADDITIVE_EXPR    ::= MULTIPLICATIVE_EXPR { ( '+' | '-' ) MULTIPLICATIVE_EXPR }
MULTIPLICATIVE_EXPR ::= UNARY_EXPR { ( '*' | '/' | '%' ) UNARY_EXPR }
UNARY_EXPR       ::= ( '+' | '-' | '!' | '~' | '++' | '--' ) UNARY_EXPR
                   | POSTFIX_EXPR
POSTFIX_EXPR     ::= PRIMARY_EXPR { POSTFIX_OP }
POSTFIX_OP       ::= '++' | '--'
                   | '(' [ ARGUMENT_LIST ] ')'
                   | '[' EXPRESSION ']'
                   | '.' IDENTIFIER
                   | '->' IDENTIFIER
                   | '::' IDENTIFIER
                   | '?'  // Optional chaining

PRIMARY_EXPR     ::= LITERAL
                   | IDENTIFIER
                   | '(' EXPRESSION ')'
                   | 'SELF'
                   | 'SUPER'
                   | 'THIS'
                   | OBJECT_CREATION
                   | ARRAY_CREATION
                   | HASH_CREATION
                   | CODEBLOCK_LITERAL
                   | MACRO_EXPR
                   | COMPILE_EXPR
                   | TYPEOF_EXPR
                   | INTERPOLATED_STRING

OBJECT_CREATION  ::= TYPE_REFERENCE '(' [ ARGUMENT_LIST ] ')'
ARRAY_CREATION   ::= 'ARRAY' '<' TYPE '>' '(' EXPRESSION [ ',' EXPRESSION ] ')'
                   | '{' [ EXPRESSION { ',' EXPRESSION } ] '}'
HASH_CREATION    ::= 'HASH' '<' TYPE ',' TYPE '>' '(' ')'
                   | '{|' [ HASH_ENTRY { ',' HASH_ENTRY } ] '|}'

MACRO_EXPR       ::= '&' IDENTIFIER
                   | '&' '(' EXPRESSION ')'

COMPILE_EXPR     ::= 'COMPILE' '<' TYPE '>' '(' STRING_LITERAL [ ',' HASH_LITERAL ] ')'

TYPEOF_EXPR      ::= 'TYPEOF' '(' EXPRESSION ')'

INTERPOLATED_STRING ::= TEMPLATE_STRING

ARGUMENT_LIST    ::= ARGUMENT { ',' ARGUMENT }
ARGUMENT         ::= [ IDENTIFIER ':=' ] EXPRESSION
```

---

## 4. Precedence Summary (Highest to Lowest)

| Level | Operators | Associativity |
|-------|-----------|---------------|
| 1 | `::` `()` `[]` `->` `.` `?` | Left |
| 2 | `++` `--` (postfix) | Left |
| 3 | `++` `--` `+` `-` `!` `~` (prefix) | Right |
| 4 | `*` `/` `%` | Left |
| 5 | `+` `-` | Left |
| 6 | `<<` `>>` | Left |
| 7 | `<` `<=` `>` `>=` | Left |
| 8 | `==` `!=` `===` `!==` | Left |
| 9 | `&` | Left |
| 10 | `^` | Left |
| 11 | `\|` | Left |
| 12 | `&&` | Left |
| 13 | `\|\|` | Left |
| 14 | `?:` (ternary) | Right |
| 15 | `:=` `+=` `-=` `*=` `/=` etc. | Right |
| 16 | `,` (sequence) | Left |
| 17 | `<-` (channel send) | Right |
| 18 | `<-` (channel receive) | Right |

---

## 5. Strict Mode Grammar Extensions

When `#STRICT` directive is present at file top:

```
STRICT_MODE_REQUIREMENTS ::= 
  // All variables must have explicit type or inferrable initializer
  // NIL not assignable to non-optional types
  // No implicit PUBLIC/PRIVATE
  // Macros require COMPILE<> with type signature
  // All function parameters typed
  // All return types explicit
  // No dynamic CodeBlock without type annotation
```

---

## 6. Legacy Mode Grammar Extensions

When `--legacy` flag is active:

```
LEGACY_EXTENSIONS ::= 
  // PUBLIC / PRIVATE variable declarations
  // Untyped variables default to VARIANT
  // SET EXACT OFF / SET SOFTSEEK ON
  // &macro without COMPILE<>
  // Implicit module for global state
  // DBF/CDX/NTX via USE ... VIA "DBF"
  // BEGIN SEQUENCE ... RECOVER ... END
  // REQUEST function_name
  // #include "file.ch"
```

---

## 7. Grammar Validation Rules

### 7.1 Semantic Constraints (Post-Parsing)

1. **No import cycles** in module dependency graph
2. **All EXPORT symbols** must be defined in module
3. **No duplicate declarations** in same scope
4. **Constructor must call SUPER** if base class has required parameters
5. **OVERRIDE methods** must match base signature
6. **Generic type arguments** must satisfy constraints
6. **Channel operations** only on CHANNEL types
7. **AWAIT only** on TASK/ASYNC FUNCTION results
8. **SPAWN only** on FUNCTION/CODEBLOCK
9. **MATCH exhaustiveness** for sealed types
10. **Variable initialization** before use (strict mode)

### 7.2 Migration Annotations

The grammar supports special comment-based annotations inserted by transpiler:

```
MIGRATION_ANNOTATION ::= '//' '[FX-MIGRATE' ':' RISK_CODE ']' TEXT
                       | '//' '[FX-MIGRATE' ']' TEXT
RISK_CODE ::= 'RIESGO-' DIGITS
```

---

## 8. Tokenizer State Machine (Key Transitions)

```
INITIAL_STATE:
  - Letter/Underscore → IDENTIFIER/KEYWORD
  - Digit → NUMBER
  - '"' → STRING_LITERAL
  - '`' → TEMPLATE_STRING
  - '@"' → VERBATIM_STRING
  - '{' → ARRAY_LITERAL or BLOCK_STMT (context-dependent)
  - '{|' → HASH_LITERAL
  - '{|' '|' ... '|}' → CODEBLOCK_LITERAL
  - '[' → ANNOTATION or ARRAY_ACCESS (context-dependent)
  - '/' → COMMENT or DIV_OP
  - '#' → DIRECTIVE (#STRICT, #IF, etc.)
  - Operator chars → OPERATOR (longest match)
  - Whitespace → skip
  - Newline → NEWLINE token (significant for statement termination)
```

---

## 9. Error Recovery Strategies

1. **Panic mode** on unexpected token: skip to statement boundary (`;`, `NEWLINE`, `END`, `NEXT`, `ENDIF`, `ENDDO`, `ENDFOR`)
2. **Insert missing tokens** for common omissions (`:=`, `THEN`, `DO`, `END`)
3. **Type error recovery**: substitute `VARIANT` and continue
4. **Import error**: treat as `ANY` module, report diagnostic

---

## 10. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0-alpha | 2026-08-08 | Initial grammar derived from PRD v1.0.0 |

---

*End of GRAMMAR.PRD*