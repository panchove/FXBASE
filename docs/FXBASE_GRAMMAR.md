# FXBASE — Especificación Formal de Gramática (GRAMMAR)

**Versión:** 1.0.0-alpha  
**Fecha:** 2026-08-08  
**Estado:** Derivado de PRD v1.0.0  

---

## 1. Notación Gramatical

Esta gramática usa **EBNF (Forma Extendida de Backus-Naur)** con las siguientes convenciones:

| Símbolo | Significado |
|---------|-------------|
| `::=` | Definición |
| `|` | Alternativa |
| `[ ... ]` | Opcional (cero o uno) |
| `{ ... }` | Repetición (cero o más) |
| `( ... )` | Agrupación |
| `"..."` | Terminal literal (sensible a mayúsculas) |
| `'...'` | Terminal literal (insensible a mayúsculas) |
| `IDENTIFICADOR` | No-terminal (token léxico) |
| `PALABRA_CLAVE` | Palabra reservada token |

---

## 2. Estructura Léxica

### 2.1 Conjunto Caracteres
- Archivos fuente codificados en **UTF-8**
- Identificadores soportan letras Unicode (Lu, Ll, Lt, Lm, Lo, Nl) y guiones bajos
- Primer carácter: letra o guion bajo
- Subsecuentes: letra, dígito, guion bajo, o marca Unicode (Mn, Mc)

### 2.2 Tokens

```
token ::= PALABRA_CLAVE
        | IDENTIFICADOR
        | LITERAL
        | OPERADOR
        | PUNTUADOR
        | ANOTACION
        | COMENTARIO
```

### 2.3 Palabras Clave (Reservadas)

```
PALABRA_CLAVE ::= 'AND' | 'AS' | 'ASYNC' | 'AWAIT' | 'BREAK' | 'BYREF' | 'BYVAL'
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

**Nota:** Las palabras clave son insensibles a mayúsculas. Convención: MAYÚSCULAS en gramática, PascalCase en código.

### 2.4 Identificadores

```
IDENTIFICADOR ::= (LETRA | '_') { LETRA | DIGITO | '_' }
LETRA         ::= categorías Unicode letter (Lu, Ll, Lt, Lm, Lo, Nl)
DIGITO        ::= '0'..'9'
```

**Convenciones命名 (impuestas por linter, no gramática):**
- prefijo `n*` → INT/DECIMAL/FLOAT
- prefijo `c*` → STRING
- prefijo `d*` → DATE/DATETIME
- prefijo `l*` → LOGICAL
- prefijo `a*` → ARRAY
- prefijo `o*` → OBJECT
- prefijo `b*` → CODEBLOCK

### 2.5 Literales

```
LITERAL ::= ENTERO_LITERAL
          | FLOTANTE_LITERAL
          | DECIMAL_LITERAL
          | CADENA_LITERAL
          | PLANTILLA_CADENA
          | CADENA_VERBATIM
          | FECHA_LITERAL
          | FECHAHORA_LITERAL
          | LOGICO_LITERAL
          | ARRAY_LITERAL
          | HASH_LITERAL
          | CODEBLOCK_LITERAL
          | JSON_LITERAL
          | NIL_LITERAL
```

#### Literales Numéricos
```
ENTERO_LITERAL  ::= DIGITOS_DECIMALES
                  | '0x' DIGITOS_HEX
                  | '0b' DIGITOS_BINARIOS

FLOTANTE_LITERAL::= DIGITOS_DECIMALES '.' DIGITOS_DECIMALES [EXPONENTE]
                  | DIGITOS_DECIMALES EXPONENTE

DECIMAL_LITERAL ::= (DIGITOS_DECIMALES '.' DIGITOS_DECIMALES
                  | DIGITOS_DECIMALES) 'D'

EXPONENTE       ::= ('e' | 'E') ['+' | '-'] DIGITOS_DECIMALES
DIGITOS_DECIMALES ::= DIGITO {DIGITO}
DIGITOS_HEX     ::= DIGITO_HEX {DIGITO_HEX}
DIGITOS_BINARIOS::= '0' | '1' {'0' | '1'}
DIGITO_HEX      ::= DIGITO | 'A'..'F' | 'a'..'f'
```

#### Literales Cadenas
```
CADENA_LITERAL    ::= '"' { CHAR_CADENA | SECUENCIA_ESCAPE } '"'
PLANTILLA_CADENA  ::= '`' { CHAR_PLANTILLA | SECUENCIA_ESCAPE | INTERPOLACION } '`'
CADENA_VERBATIM   ::= '@"' { CHAR_VERBATIM | '""' } '"'

INTERPOLACION     ::= '${' EXPRESION [ ':' ESPECIFICADOR_FMT ] '}'

ESPECIFICADOR_FMT ::= 'N' DIGITOS        // Número con separador miles
                    | 'D' DIGITOS        // Decimal con relleno ceros
                    | 'X' DIGITOS        // Hexadecimal
                    | 'ISO'              // ISO 8601 para fechas
                    | FORMATO_PERSONALIZADO

SECUENCIA_ESCAPE  ::= '\' ('n' | 't' | 'r' | '"' | '\'' | '\\' | '0' | 'u' DIGITOS_HEX_4)

CHAR_CADENA       ::= cualquier char Unicode excepto '"', '\', salto línea
CHAR_PLANTILLA    ::= cualquier char Unicode excepto '`', '\', '$'
CHAR_VERBATIM     ::= cualquier char Unicode excepto '"'
```

#### Literales Fecha/Hora
```
FECHA_LITERAL     ::= 'DATE' '(' ENTERO ',' ENTERO ',' ENTERO ')'
FECHAHORA_LITERAL ::= 'DATETIME' '(' CADENA_LITERAL ')'  // ISO 8601
```

#### Literales Lógicos
```
LOGICO_LITERAL ::= 'TRUE' | 'FALSE'
NIL_LITERAL    ::= 'NIL'
```

#### Literales Colecciones
```
ARRAY_LITERAL ::= '{' [ EXPRESION { ',' EXPRESION } [ ',' ] ] '}'
                | 'ARRAY' '<' TIPO '>' '{' [ EXPRESION { ',' EXPRESION } ] '}'

HASH_LITERAL  ::= '{|' [ ENTRADA_HASH { ',' ENTRADA_HASH } [ ',' ] ] '|}'
                | 'HASH' '<' TIPO ',' TIPO '>' '{|' [ ENTRADA_HASH { ',' ENTRADA_HASH } ] '|}'

ENTRADA_HASH  ::= EXPRESION '=>' EXPRESION
```

#### Literales CodeBlock
```
CODEBLOCK_LITERAL ::= '{|' [ LISTA_PARAMETROS ] '|' BLOQUE_SENTENCIAS '}'
                    | '{|' [ LISTA_PARAMETROS_TIPADOS ] '|' BLOQUE_SENTENCIAS '}' 'AS' 'CODEBLOCK' '<' LISTA_TIPOS '>'

LISTA_PARAMETROS       ::= IDENTIFICADOR { ',' IDENTIFICADOR }
LISTA_PARAMETROS_TIPADOS ::= PARAMETRO_TIPADO { ',' PARAMETRO_TIPADO }
PARAMETRO_TIPADO       ::= IDENTIFICADOR 'AS' TIPO
LISTA_TIPOS            ::= TIPO { ',' TIPO }
```

#### Literales JSON
```
JSON_LITERAL  ::= OBJETO_JSON | ARRAY_JSON
OBJETO_JSON   ::= '{' [ CADENA_LITERAL ':' VALOR_JSON { ',' CADENA_LITERAL ':' VALOR_JSON } ] '}'
ARRAY_JSON    ::= '[' [ VALOR_JSON { ',' VALOR_JSON } ] ']'
VALOR_JSON    ::= CADENA_LITERAL | NUMERO_LITERAL | OBJETO_JSON | ARRAY_JSON | 'TRUE' | 'FALSE' | 'NULL'
```

### 2.6 Operadores y Puntuadores

```
OPERADOR ::= '::' | '->' | '++' | '--' | '+' | '-' | '*' | '/' | '%'
           | '<<' | '>>' | '<' | '<=' | '>' | '>=' | '==' | '!=' | '===' | '!=='
           | '&' | '^' | '|' | '&&' | '||' | '?' | ':' | ':='
           | '+=' | '-=' | '*=' | '/=' | '|=' | '&=' | '^=' | '<<=' | '>>='
           | '<-' | '->'  // Envío/recepción canal

PUNTUADOR ::= '(' | ')' | '[' | ']' | '{' | '}' | ',' | ';' | ':'
            | '.' | '...' | '@' | '#' | '|' | '=>'
```

### 2.7 Anotaciones (Atributos)

```
ANOTACION ::= '[' NOMBRE_ANOTACION [ '(' [ ARGS_ANOTACION ] ')' ] ']'
NOMBRE_ANOTACION ::= IDENTIFICADOR { '::' IDENTIFICADOR }
ARGS_ANOTACION   ::= ARG_ANOTACION { ',' ARG_ANOTACION }
ARG_ANOTACION    ::= IDENTIFICADOR ':=' EXPRESION
                   | EXPRESION
```

### 2.8 Comentarios

```
COMENTARIO ::= '//' { cualquier char excepto salto línea } salto línea
             | '/*' { cualquier char excepto '*/' } '*/'
             | '///' { cualquier char excepto salto línea } salto línea  // Comentario documentación
```

---

## 3. Gramática Sintáctica

### 3.1 Unidad Compilación

```
unidad_compilacion ::= [ DECLARACION_MODULO ] { DECLARACION_IMPORT } { DECLARACION_NIVEL_SUPERIOR }
```

### 3.2 Declaración Módulo

```
DECLARACION_MODULO ::= 'MODULE' NOMBRE_MODULO [ ANOTACION ] salto línea
NOMBRE_MODULO      ::= IDENTIFICADOR { '.' IDENTIFICADOR }
```

### 3.3 Declaraciones Import

```
DECLARACION_IMPORT ::= 'IMPORT' ESPEC_IMPORT 'FROM' CADENA_LITERAL [ ANOTACION ] salto línea

ESPEC_IMPORT ::= '*'
               | '* AS' IDENTIFICADOR
               | IDENTIFICADOR { ',' IDENTIFICADOR }
               | '{' IDENTIFICADOR { ',' IDENTIFICADOR } '}'
```

### 3.4 Declaraciones Nivel Superior

```
DECLARACION_NIVEL_SUPERIOR ::= DECLARACION_FUNCION
                             | DECLARACION_CLASE
                             | DECLARACION_STRUCT
                             | DECLARACION_ATRIBUTO
                             | DECLARACION_VAR_MODULO
                             | DECLARACION_EXPORT
                             | DECLARACION_SUITE_TEST
                             | DECLARACION_FORMULARIO
```

### 3.5 Declaración Export

```
DECLARACION_EXPORT ::= 'EXPORT' DECLARACION_NIVEL_SUPERIOR
                     | 'EXPORT' 'MODULE' 'VARIABLE' DECLARACION_VARIABLE
```

### 3.6 Declaración Función

```
DECLARACION_FUNCION ::= [ 'ASYNC' ] 'FUNCTION' IDENTIFICADOR
                        [ PARAMETROS_TIPO ]
                        '(' [ LISTA_PARAMETROS ] ')'
                        [ 'AS' TIPO_RETORNO ]
                        [ ANOTACION ] salto línea
                        BLOQUE_SENTENCIAS
                        'END' [ ANOTACION ] salto línea

PARAMETROS_TIPO ::= '<' PARAMETRO_TIPO { ',' PARAMETRO_TIPO } '>'
PARAMETRO_TIPO  ::= IDENTIFICADOR [ ':' RESTRICCION ]
RESTRICCION     ::= TIPO { '|' TIPO }

LISTA_PARAMETROS ::= PARAMETRO { ',' PARAMETRO }
PARAMETRO        ::= [ 'BYREF' | 'BYVAL' ] IDENTIFICADOR [ 'AS' TIPO ] [ ':=' EXP_DEFECTO ]
                   | '...' IDENTIFICADOR [ 'AS' TIPO ]  // Variádico

TIPO_RETORNO    ::= TIPO
                  | 'RESULT' '<' TIPO ',' TIPO '>'
                  | 'NIL'

EXP_DEFECTO     ::= EXPRESION
```

### 3.7 Declaración Clase

```
DECLARACION_CLASE ::= 'CLASS' IDENTIFICADOR [ PARAMETROS_TIPO ]
                      [ 'INHERIT' REFERENCIA_TIPO ]
                      [ ANOTACION ] salto línea
                      { MIEMBRO_CLASE }
                      'END' [ ANOTACION ] salto línea

MIEMBRO_CLASE ::= DECLARACION_PROPIEDAD
                | DECLARACION_METODO
                | DECLARACION_CONSTRUCTOR
                | DECLARACION_ACCESOR
                | DECLARACION_STATIC
                | DECLARACION_HIDDEN

DECLARACION_PROPIEDAD ::= [ 'PROPERTY' ] IDENTIFICADOR [ 'AS' TIPO ] [ ':=' EXPRESION ]
                        [ ANOTACION ] salto línea

DECLARACION_METODO ::= [ 'OVERRIDE' ] 'METHOD' IDENTIFICADOR
                       [ PARAMETROS_TIPO ]
                       '(' [ LISTA_PARAMETROS ] ')'
                       [ 'AS' TIPO_RETORNO ]
                       [ ANOTACION ] salto línea
                       BLOQUE_SENTENCIAS
                       'END' [ ANOTACION ] salto línea

DECLARACION_CONSTRUCTOR ::= 'CONSTRUCTOR' '(' [ LISTA_PARAMETROS ] ')'
                            [ ANOTACION ] salto línea
                            BLOQUE_SENTENCIAS
                            'END' [ ANOTACION ] salto línea

DECLARACION_ACCESOR ::= 'ACCESS' IDENTIFICADOR 'AS' TIPO
                        [ ANOTACION ] salto línea
                        BLOQUE_SENTENCIAS
                        'END' [ ANOTACION ] salto línea

DECLARACION_STATIC ::= 'STATIC' ( DECLARACION_FUNCION | DECLARACION_VARIABLE )
DECLARACION_HIDDEN ::= 'HIDDEN' ( DECLARACION_FUNCION | DECLARACION_VARIABLE )
```

### 3.8 Declaración Struct

```
DECLARACION_STRUCT ::= 'STRUCT' IDENTIFICADOR [ PARAMETROS_TIPO ]
                       [ ANOTACION ] salto línea
                       { CAMPO_STRUCT }
                       'END' [ ANOTACION ] salto línea

CAMPO_STRUCT ::= IDENTIFICADOR 'AS' TIPO [ ANOTACION ] salto línea
```

### 3.9 Declaración Atributo

```
DECLARACION_ATRIBUTO ::= 'ATTRIBUTE' IDENTIFICADOR '(' [ LISTA_PARAMETROS ] ')'
                         [ ANOTACION ] salto línea
                         BLOQUE_SENTENCIAS
                         'END' [ ANOTACION ] salto línea
```

### 3.10 Declaración Variable Módulo

```
DECLARACION_VAR_MODULO ::= [ 'HIDDEN' | 'EXPORT' ] 'VAR' DECLARACION_VARIABLE
DECLARACION_VARIABLE   ::= IDENTIFICADOR [ 'AS' TIPO ] [ ':=' EXPRESION ] [ ANOTACION ] salto línea
```

### 3.11 Referencias Tipo

```
REFERENCIA_TIPO ::= TIPO_SIMPLE
                  | TIPO_GENERICO
                  | TIPO_FUNCION
                  | TIPO_CANAL
                  | TIPO_CODEBLOCK
                  | TIPO_OPCIONAL
                  | TIPO_RESULTADO
                  | TIPO_UNION
                  | TIPO_INTERSECCION

TIPO_SIMPLE     ::= 'NIL' | 'LOGICAL' | 'INT' | 'DECIMAL' | 'FLOAT'
                  | 'STRING' | 'DATE' | 'DATETIME' | 'POINTER'
                  | 'JSON' | 'OBJECT' | 'VARIANT' | IDENTIFICADOR

TIPO_GENERICO   ::= IDENTIFICADOR '<' LISTA_TIPOS '>'

TIPO_FUNCION    ::= 'FUNCTION' '(' [ LISTA_TIPOS ] ')' [ 'AS' TIPO ]

TIPO_CANAL      ::= 'CHANNEL' '<' TIPO '>'

TIPO_CODEBLOCK  ::= 'CODEBLOCK' '<' [ LISTA_TIPOS ] '>'

TIPO_OPCIONAL   ::= TIPO '?'

TIPO_RESULTADO  ::= 'RESULT' '<' TIPO ',' TIPO '>'

TIPO_UNION      ::= TIPO '|' TIPO { '|' TIPO }

TIPO_INTERSECCION ::= TIPO '&' TIPO { '&' TIPO }
```

### 3.12 Sentencias

```
BLOQUE_SENTENCIAS ::= { SENTENCIA }

SENTENCIA ::= SENTENCIA_DECL_VAR
            | SENTENCIA_ASIGNACION
            | SENTENCIA_EXPRESION
            | SENTENCIA_IF
            | SENTENCIA_MATCH
            | SENTENCIA_FOR
            | SENTENCIA_FOREACH
            | SENTENCIA_WHILE
            | SENTENCIA_DO_WHILE
            | SENTENCIA_DO_UNTIL
            | SENTENCIA_TRY
            | SENTENCIA_RETURN
            | SENTENCIA_BREAK
            | SENTENCIA_CONTINUE
            | SENTENCIA_EXIT
            | SENTENCIA_SPAWN
            | SENTENCIA_AWAIT
            | SENTENCIA_WAIT
            | SENTENCIA_SELECT
            | SENTENCIA_ENVIO_CANAL
            | SENTENCIA_RECEPCION_CANAL
            | SENTENCIA_USE
            | SENTENCIA_SET
            | SENTENCIA_FORM
            | SENTENCIA_BLOQUE

SENTENCIA_BLOQUE ::= '{' BLOQUE_SENTENCIAS '}'
```

#### Sentencia Declaración Variable
```
SENTENCIA_DECL_VAR ::= [ 'LOCAL' | 'STATIC' | 'MODULE' ] DECLARACION_VARIABLE
```

#### Sentencia Asignación
```
SENTENCIA_ASIGNACION ::= LHS ':=' EXPRESION
                       | LHS OP_ASIG EXPRESION

LHS ::= IDENTIFICADOR
      | LHS '.' IDENTIFICADOR
      | LHS '->' IDENTIFICADOR
      | LHS '[' EXPRESION ']'
      | '(' LHS ')'

OP_ASIG ::= '+=' | '-=' | '*=' | '/=' | '|=' | '&=' | '^=' | '<<=' | '>>='
```

#### Sentencia Expresión
```
SENTENCIA_EXPRESION ::= EXPRESION
```

#### Sentencia If
```
SENTENCIA_IF ::= 'IF' EXPRESION salto línea
                 BLOQUE_SENTENCIAS
                 { 'ELSEIF' EXPRESION salto línea BLOQUE_SENTENCIAS }
                 [ 'ELSE' salto línea BLOQUE_SENTENCIAS ]
                 'ENDIF'
```

#### Sentencia Match (Pattern Matching)
```
SENTENCIA_MATCH ::= 'MATCH' EXPRESION salto línea
                    { CASO_MATCH }
                    'END'

CASO_MATCH ::= 'CASE' PATRON [ 'IF' EXPRESION ] salto línea
               BLOQUE_SENTENCIAS

PATRON ::= '_'
         | LITERAL
         | IDENTIFICADOR
         | PATRON_CONSTRUCTOR
         | PATRON_TUPLA
         | PATRON_OR

PATRON_CONSTRUCTOR ::= IDENTIFICADOR '(' [ PATRON { ',' PATRON } ] ')'
PATRON_TUPLA       ::= '(' [ PATRON { ',' PATRON } ] ')'
PATRON_OR          ::= PATRON '|' PATRON { '|' PATRON }
```

#### Sentencia For
```
SENTENCIA_FOR ::= 'FOR' IDENTIFICADOR ':=' EXPRESION 'TO' EXPRESION [ 'STEP' EXPRESION ] salto línea
                  BLOQUE_SENTENCIAS
                  'NEXT'
```

#### Sentencia Foreach
```
SENTENCIA_FOREACH ::= 'FOREACH' IDENTIFICADOR 'IN' EXPRESION salto línea
                      BLOQUE_SENTENCIAS
                      'NEXT'
```

#### Sentencia While
```
SENTENCIA_WHILE ::= 'DO' 'WHILE' EXPRESION salto línea
                    BLOQUE_SENTENCIAS
                    'ENDDO'
```

#### Sentencia Do-Until
```
SENTENCIA_DO_UNTIL ::= 'DO' 'UNTIL' EXPRESION salto línea
                       BLOQUE_SENTENCIAS
                       'ENDDO'
```

#### Sentencia Try
```
SENTENCIA_TRY ::= 'TRY' salto línea
                  BLOQUE_SENTENCIAS
                  { CLAUSULA_CATCH }
                  [ 'FINALLY' salto línea BLOQUE_SENTENCIAS ]
                  'END'

CLAUSULA_CATCH ::= 'CATCH' [ IDENTIFICADOR [ 'AS' REFERENCIA_TIPO ] ] salto línea
                   BLOQUE_SENTENCIAS
```

#### Sentencia Return
```
SENTENCIA_RETURN ::= 'RETURN' [ EXPRESION ]
```

#### Break / Continue / Exit
```
SENTENCIA_BREAK    ::= 'BREAK'
SENTENCIA_CONTINUE ::= 'CONTINUE'
SENTENCIA_EXIT     ::= 'EXIT' [ EXPRESION ]
```

#### Sentencias Concurrencia
```
SENTENCIA_SPAWN ::= 'SPAWN' EXPRESION
SENTENCIA_AWAIT ::= 'AWAIT' EXPRESION
SENTENCIA_WAIT  ::= 'WAIT' 'ALL' [ EXPRESION ]

SENTENCIA_SELECT ::= 'SELECT' salto línea
                     { CASO_SELECT }
                     'END'

CASO_SELECT ::= 'CASE' PATRON_RECEPCION_CANAL salto línea BLOQUE_SENTENCIAS
              | 'CASE' PATRON_ENVIO_CANAL salto línea BLOQUE_SENTENCIAS
              | 'CASE' 'DEFAULT' salto línea BLOQUE_SENTENCIAS

PATRON_RECEPCION_CANAL ::= IDENTIFICADOR ':=' '<-' EXPRESION
                         | '<-' EXPRESION

PATRON_ENVIO_CANAL     ::= EXPRESION '<-' EXPRESION

SENTENCIA_ENVIO_CANAL  ::= EXPRESION '<-' EXPRESION
SENTENCIA_RECEPCION_CANAL ::= IDENTIFICADOR ':=' '<-' EXPRESION
                            | '<-' EXPRESION  // Descartar
```

#### Sentencias Base Datos
```
SENTENCIA_USE ::= 'USE' CADENA_LITERAL [ 'VIA' CADENA_LITERAL ] [ 'ALIAS' IDENTIFICADOR ]

SENTENCIA_SET ::= 'SET' OPCION_SET

OPCION_SET ::= 'INDEX' 'TO' CADENA_LITERAL
             | 'RELATION' 'TO' EXPRESION 'INTO' IDENTIFICADOR
             | 'EXACT' ( 'ON' | 'OFF' )
             | 'SOFTSEEK' ( 'ON' | 'OFF' )
             | 'DELETED' ( 'ON' | 'OFF' )
             | 'FILTER' 'TO' EXPRESION
             | 'ORDER' 'TO' CADENA_LITERAL
```

#### Sentencias Formulario/UI
```
SENTENCIA_FORM ::= 'FORM' IDENTIFICADOR [ 'AS' IDENTIFICADOR ] [ 'TITLE' CADENA_LITERAL ]
                   [ 'WIDTH' EXPRESION ] [ 'HEIGHT' EXPRESION ] salto línea
                   { ELEMENTO_FORM }
                   'ENDFORM'

ELEMENTO_FORM ::= POSICION_SAY
                | POSICION_GET
                | POSICION_CHECKBOX
                | POSICION_COMBOBOX
                | POSICION_BUTTON
                | SENTENCIA_READ

POSICION_SAY ::= '@' EXPRESION ',' EXPRESION 'SAY' EXPRESION

POSICION_GET ::= '@' EXPRESION ',' EXPRESION 'GET' LHS
                 [ 'VALID' EXPRESION ]
                 [ 'MESSAGE' CADENA_LITERAL ]
                 [ 'PICTURE' CADENA_LITERAL ]
                 [ 'WHEN' EXPRESION ]

POSICION_CHECKBOX ::= '@' EXPRESION ',' EXPRESION 'CHECKBOX' LHS [ 'CAPTION' CADENA_LITERAL ]

POSICION_COMBOBOX ::= '@' EXPRESION ',' EXPRESION 'COMBOBOX' LHS 'ITEMS' ARRAY_LITERAL

POSICION_BUTTON ::= '@' EXPRESION ',' EXPRESION 'BUTTON' CADENA_LITERAL 'ACTION' EXPRESION

SENTENCIA_READ ::= 'READ' [ 'MODEL' EXPRESION ]
```

### 3.13 Expresiones

```
EXPRESION ::= EXP_ASIGNACION

EXP_ASIGNACION ::= EXP_OR_LOGICO [ ':=' EXP_ASIGNACION ]
                 | LHS OP_ASIG EXP_ASIGNACION

EXP_OR_LOGICO  ::= EXP_AND_LOGICO { '||' EXP_AND_LOGICO }
EXP_AND_LOGICO ::= EXP_OR_BITWISE { '&&' EXP_OR_BITWISE }
EXP_OR_BITWISE ::= EXP_XOR_BITWISE { '|' EXP_XOR_BITWISE }
EXP_XOR_BITWISE::= EXP_AND_BITWISE { '^' EXP_AND_BITWISE }
EXP_AND_BITWISE::= EXP_IGUALDAD { '&' EXP_IGUALDAD }
EXP_IGUALDAD   ::= EXP_RELACIONAL { ( '==' | '!=' | '===' | '!==' ) EXP_RELACIONAL }
EXP_RELACIONAL ::= EXP_DESPLAZAMIENTO { ( '<' | '<=' | '>' | '>=' ) EXP_DESPLAZAMIENTO }
EXP_DESPLAZAMIENTO ::= EXP_ADITIVA { ( '<<' | '>>' ) EXP_ADITIVA }
EXP_ADITIVA    ::= EXP_MULTIPLICATIVA { ( '+' | '-' ) EXP_MULTIPLICATIVA }
EXP_MULTIPLICATIVA ::= EXP_UNARIA { ( '*' | '/' | '%' ) EXP_UNARIA }
EXP_UNARIA     ::= ( '+' | '-' | '!' | '~' | '++' | '--' ) EXP_UNARIA
                 | EXP_POSTFIJO
EXP_POSTFIJO   ::= EXP_PRIMARIA { OP_POSTFIJO }
OP_POSTFIJO    ::= '++' | '--'
                 | '(' [ LISTA_ARGUMENTOS ] ')'
                 | '[' EXPRESION ']'
                 | '.' IDENTIFICADOR
                 | '->' IDENTIFICADOR
                 | '::' IDENTIFICADOR
                 | '?'  // Encadenamiento opcional

EXP_PRIMARIA   ::= LITERAL
                 | IDENTIFICADOR
                 | '(' EXPRESION ')'
                 | 'SELF'
                 | 'SUPER'
                 | 'THIS'
                 | CREACION_OBJETO
                 | CREACION_ARRAY
                 | CREACION_HASH
                 | CODEBLOCK_LITERAL
                 | EXP_MACRO
                 | EXP_COMPILE
                 | EXP_TYPEOF
                 | CADENA_INTERPOLADA

CREACION_OBJETO ::= REFERENCIA_TIPO '(' [ LISTA_ARGUMENTOS ] ')'
CREACION_ARRAY  ::= 'ARRAY' '<' TIPO '>' '(' EXPRESION [ ',' EXPRESION ] ')'
                  | '{' [ EXPRESION { ',' EXPRESION } ] '}'
CREACION_HASH   ::= 'HASH' '<' TIPO ',' TIPO '>' '(' ')'
                  | '{|' [ ENTRADA_HASH { ',' ENTRADA_HASH } ] '|}'

EXP_MACRO      ::= '&' IDENTIFICADOR
                 | '&' '(' EXPRESION ')'

EXP_COMPILE    ::= 'COMPILE' '<' TIPO '>' '(' CADENA_LITERAL [ ',' HASH_LITERAL ] ')'

EXP_TYPEOF     ::= 'TYPEOF' '(' EXPRESION ')'

CADENA_INTERPOLADA ::= PLANTILLA_CADENA

LISTA_ARGUMENTOS ::= ARGUMENTO { ',' ARGUMENTO }
ARGUMENTO        ::= [ IDENTIFICADOR ':=' ] EXPRESION
```

---

## 4. Resumen Precedencia (Mayor a Menor)

| Nivel | Operadores | Asociatividad |
|-------|------------|---------------|
| 1 | `::` `()` `[]` `->` `.` `?` | Izquierda |
| 2 | `++` `--` (postfijo) | Izquierda |
| 3 | `++` `--` `+` `-` `!` `~` (prefijo) | Derecha |
| 4 | `*` `/` `%` | Izquierda |
| 5 | `+` `-` | Izquierda |
| 6 | `<<` `>>` | Izquierda |
| 7 | `<` `<=` `>` `>=` | Izquierda |
| 8 | `==` `!=` `===` `!==` | Izquierda |
| 9 | `&` | Izquierda |
| 10 | `^` | Izquierda |
| 11 | `|` | Izquierda |
| 12 | `&&` | Izquierda |
| 13 | `||` | Izquierda |
| 14 | `?:` (ternario) | Derecha |
| 15 | `:=` `+=` `-=` `*=` `/=` etc. | Derecha |
| 16 | `,` (secuencia) | Izquierda |
| 17 | `<-` (envío canal) | Derecha |
| 18 | `<-` (recepción canal) | Derecha |

---

## 5. Extensiones Gramaticales Modo Estricto

Cuando la directiva `#STRICT` está presente al inicio del archivo:

```
REQUISITOS_MODO_ESTRICTO ::= 
  // Todas las variables deben tener tipo explícito o inicializador inferible
  // NIL no asignable a tipos no-opcionales
  // Sin PUBLIC/PRIVATE implícitos
  // Macros requieren COMPILE<> con firma tipos
  // Todos parámetros función tipados
  // Todos tipos retorno explícitos
  // Sin CodeBlock dinámico sin anotación tipo
```

---

## 6. Extensiones Gramaticales Modo Legacy

Cuando flag `--legacy` está activo:

```
EXTENSIONES_LEGACY ::= 
  // Declaraciones variables PUBLIC/PRIVATE
  // Variables sin tipo default VARIANT
  // SET EXACT OFF / SET SOFTSEEK ON
  // &macro sin COMPILE<>
  // Módulo implícito para estado global
  // DBF/CDX/NTX via USE ... VIA "DBF"
  // BEGIN SEQUENCE ... RECOVER ... END
  // REQUEST nombre_funcion
  // #include "archivo.ch"
```

---

## 7. Reglas Validación Gramatical

### 7.1 Restricciones Semánticas (Post-Parsing)

1. **Sin ciclos import** en grafo dependencias módulos
2. **Todos símbolos EXPORT** deben estar definidos en módulo
3. **Sin declaraciones duplicadas** en mismo ámbito
4. **Constructor debe llamar SUPER** si clase base tiene parámetros requeridos
5. **Métodos OVERRIDE** deben coincidir firma base
6. **Argumentos tipo genérico** deben satisfacer restricciones
6. **Operaciones canales** solo en tipos CHANNEL
7. **AWAIT solo** en resultados TAREA/FUNCIÓN_ASYNC
8. **SPAWN solo** en FUNCIÓN/CODEBLOCK
9. **Exhaustividad MATCH** para tipos sellados
10. **Inicialización variables** antes de uso (modo estricto)

### 7.2 Anotaciones Migración

La gramática soporta anotaciones especiales basadas en comentarios insertadas por transpilador:

```
ANOTACION_MIGRACION ::= '//' '[FX-MIGRATE' ':' CODIGO_RIESGO ']' TEXTO
                      | '//' '[FX-MIGRATE' ']' TEXTO
CODIGO_RIESGO ::= 'RIESGO-' DIGITOS
```

---

## 8. Máquina Estados Tokenizer (Transiciones Clave)

```
ESTADO_INICIAL:
  - Letra/GuionBajo → IDENTIFICADOR/PALABRA_CLAVE
  - Dígito → NUMERO
  - '"' → CADENA_LITERAL
  - '`' → PLANTILLA_CADENA
  - '@"' → CADENA_VERBATIM
  - '{' → ARRAY_LITERAL o SENTENCIA_BLOQUE (depende contexto)
  - '{|' → HASH_LITERAL
  - '{|' '|' ... '|}' → CODEBLOCK_LITERAL
  - '[' → ANOTACION o ACCESO_ARRAY (depende contexto)
  - '/' → COMENTARIO u OP_DIV
  - '#' → DIRECTIVA (#STRICT, #IF, etc.)
  - Chars operador → OPERADOR (match más largo)
  - Espacio blanco → saltar
  - Salto línea → token NUEVA_LINEA (significativo para terminación sentencias)
```

---

## 9. Estrategias Recuperación Errores

1. **Modo pánico** en token inesperado: saltar a límite sentencia (`;`, `NUEVA_LINEA`, `END`, `NEXT`, `ENDIF`, `ENDDO`, `ENDFOR`)
2. **Insertar tokens faltantes** para omisiones comunes (`:=`, `THEN`, `DO`, `END`)
3. **Recuperación error tipo**: sustituir `VARIANT` y continuar
4. **Error import**: tratar como módulo `ANY`, reportar diagnóstico

---

## 10. Historial Versiones

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0.0-alpha | 2026-08-08 | Gramática inicial derivada de PRD v1.0.0 |

---

*Fin GRAMMAR*