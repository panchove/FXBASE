# FXBASE — Product Requirements Document (PRD)

**Versión:** 1.0.0-alpha  
**Fecha:** 2026-08-08  
**Estado:** Borrador para revisión técnica  
**Autor:** Especificación derivada de análisis de arquitectura de compiladores xBase modernos  

---

## 1. Visión y Alcance

### 1.1 Propósito
FXBASE es un compilador y ecosistema de lenguaje de programación de nueva generación, inspirado en la filosofía de productividad de xBase/Clipper/xHarbour, pero rediseñado desde cero para incorporar las mejores prácticas de lenguajes modernos (Rust, Go, TypeScript, Swift, C#).

### 1.2 Objetivo Principal
Proporcionar a los desarrolladores que mantienen sistemas heredados xBase una **ruta de migración viable, gradual y de bajo riesgo** hacia un lenguaje seguro, concurrente, multiplataforma y con tooling moderno, sin sacrificar la velocidad de desarrollo característica de la familia xBase.

### 1.3 Alcance (In-Scope)
- Lenguaje de programación FXBASE con sintaxis xBase modernizada.
- Compilador nativo multi-backend (C, LLVM, WASM, Bytecode).
- **Transpilador de migración xHarbour/Harbour/Clipper → FXBASE** (componente crítico para adopción).
- Biblioteca estándar (`FXSTD`) con soporte para bases de datos SQL/NoSQL, HTTP, JSON, concurrencia y UI.
- Sistema de módulos y gestor de paquetes (`fxpkg`).
- REPL interactivo y modo scripting.
- Soporte LSP (Language Server Protocol) para integración con IDEs.

### 1.4 Fuera de Alcance (Out-of-Scope) — Fase 1
- Compatibilidad binaria con xHarbour o CA-Clipper.
- Soporte nativo de archivos `.DBF` como motor de datos principal (se provee como RDD legacy).
- IDE gráfico propietario (se apunta a VS Code / Vim / Emacs vía LSP).

---

## 2. Requisitos Funcionales

### 2.1 Lenguaje FXBASE (Core Language)

#### 2.1.1 Tipos de Datos

| Categoría | Tipo | Descripción |
|-----------|------|-------------|
| **Escalares** | `NIL` | Valor nulo. |
| | `LOGICAL` | Booleano (`TRUE` / `FALSE`). |
| | `INT` | Entero con signo de 64 bits. |
| | `DECIMAL` | Decimal de precisión arbitraria (financiero). |
| | `FLOAT` | Punto flotante IEEE 754 de 64 bits. |
| | `STRING` | Cadena UTF-8 nativa, inmutable. |
| | `DATE` | Fecha sin zona horaria (proleptic Gregorian). |
| | `DATETIME` | Fecha y hora con zona horaria (ISO 8601). |
| | `POINTER` | Puntero opaco a memoria nativa (interop C). |
| **Complejos** | `ARRAY<T>` | Vector tipado de tamaño dinámico. |
| | `HASH<K,V>` | Array asociativo tipado. |
| | `OBJECT<T>` | Instancia de clase tipada. |
| | `CODEBLOCK<...>` | Closure tipado (lambda). |
| **Especiales** | `RESULT<T,E>` | Tipo suma para manejo de errores explícito. |
| | `OPTIONAL<T>` | Alias de `T?` (nullable explícito). |
| | `CHANNEL<T>` | Canal tipado para concurrencia CSP. |

#### 2.1.2 Sistema de Tipos — Gradual y Opt-In

```fxbase
// Modo dinámico (default, compatible con legado)
LOCAL x := 10
x := "ahora soy string"   // Válido

// Modo estricto (opt-in por archivo o módulo)
#STRICT

LOCAL nEdad AS INT := 30
LOCAL cNombre AS STRING := "Juan"
LOCAL aDatos AS ARRAY<INT> := {1, 2, 3}
LOCAL oCliente AS OBJECT<Cliente> := Cliente():NEW()

// Inferencia de tipos
LOCAL n := 10            // Infiere INT
LOCAL s := "hola"        // Infiere STRING
```

**Reglas:**
- `NIL` no es asignable a tipos no-nullable. `STRING?` permite `NIL`.
- Coerción numérica explícita: `AS INT`, `AS DECIMAL`, `AS FLOAT`.
- Sobrecarga de operadores permitida solo para tipos definidos por usuario.

#### 2.1.3 Variables y Alcance

| Alcance | Comportamiento | Equivalente Moderno |
|---------|---------------|---------------------|
| `LOCAL` | Visible solo en la rutina actual. Stack-allocated. | Variable local |
| `STATIC` | Visible en la rutina; persiste entre llamadas. | `static` en C |
| `MODULE` | Visible en todo el archivo fuente. | `private` en Go |
| `EXPORT` | Visible fuera del módulo si se importa. | `public` en Go |

**Eliminados:** `PUBLIC` y `PRIVATE` (espacio global implícito). El estado global debe declararse explícitamente en módulos exportados.

#### 2.1.4 Estructuras de Control

```fxbase
// Condicionales
IF nValor > 0
    ? "Positivo"
ELSEIF nValor < 0
    ? "Negativo"
ELSE
    ? "Cero"
ENDIF

// Switch con pattern matching
MATCH oResultado
    CASE OK(v)
        ? v
    CASE ERR("timeout")
        ? "Tiempo agotado"
    CASE ERR(msg)
        ? "Error: " + msg
    CASE _
        ? "Desconocido"
END

// Bucles
FOR i := 1 TO 10 STEP 2
    ? i
NEXT

FOREACH oItem IN aLista
    ? oItem:nombre
NEXT

DO WHILE nContador > 0
    nContador--
ENDDO

DO UNTIL bListo
    Procesar()
ENDDO

// Manejo de excepciones
TRY
    Riesgoso()
CATCH e AS FXException
    ? e:Message
FINALLY
    CerrarRecursos()
END
```

#### 2.1.5 Funciones y Procedimientos

```fxbase
// Función con tipado explícito
EXPORT FUNCTION CalcularIVA(nMonto AS DECIMAL) AS DECIMAL
    RETURN nMonto * 0.16
END

// Paso de parámetros
FUNCTION Actualizar(BYREF nContador AS INT, BYVAL cTexto AS STRING)
    nContador++           // Modifica el original
    cTexto := "cambio"    // No modifica el original
END

// Parámetros con valor por defecto
FUNCTION Conectar(cHost AS STRING := "localhost", nPuerto AS INT := 5432)
    // ...
END

// Variádicos
FUNCTION SumarTodos(...nNumeros AS ARRAY<INT>) AS INT
    LOCAL nTotal := 0
    FOREACH n IN nNumeros
        nTotal += n
    NEXT
    RETURN nTotal
END

// Atributos (metaprogramación)
[Deprecated("Usar CalcularIVA2")]
[Since("1.0.0")]
FUNCTION IVA_Viejo(nMonto AS DECIMAL) AS DECIMAL
    RETURN nMonto * 0.12
END
```

#### 2.1.6 Programación Orientada a Objetos

```fxbase
CLASS Persona
    // Campos privados por defecto
    PROPERTY cNombre AS STRING
    PROPERTY nEdad AS INT

    // Constructor
    CONSTRUCTOR(cNombre AS STRING, nEdad AS INT)
        SELF:cNombre := cNombre
        SELF:nEdad := nEdad
    END

    // Método
    METHOD Presentarse() AS STRING
        RETURN "Soy " + SELF:cNombre + ", tengo " + STR(SELF:nEdad) + " años"
    END

    // Propiedad computada
    ACCESS EsMayorDeEdad AS LOGICAL
        RETURN SELF:nEdad >= 18
    END
END

// Herencia
CLASS Empleado INHERIT Persona
    PROPERTY cDepartamento AS STRING
    PROPERTY nSalario AS DECIMAL

    CONSTRUCTOR(cNombre, nEdad, cDepto, nSalario)
        SUPER(cNombre, nEdad)
        SELF:cDepartamento := cDepto
        SELF:nSalario := nSalario
    END

    OVERRIDE METHOD Presentarse() AS STRING
        RETURN SUPER:Presentarse() + ". Trabajo en " + SELF:cDepartamento
    END
END

// Uso
LOCAL oEmp := Empleado("Ana", 30, "Sistemas", 2500.00)
? oEmp:Presentarse()
? oEmp:EsMayorDeEdad
```

#### 2.1.7 CodeBlocks (Closures Tipados)

```fxbase
// CodeBlock clásico (dinámico)
LOCAL bSuma := {|a, b| a + b}
? EVAL(bSuma, 5, 3)   // 8

// CodeBlock tipado (modo estricto)
LOCAL bCuadrado AS CODEBLOCK<INT, INT> := {|n AS INT| n * n}
? EVAL(bCuadrado, 4)   // 16

// Captura léxica
LOCAL nFactor := 10
LOCAL bMultiplicar := {|n| n * nFactor}
? EVAL(bMultiplicar, 5)   // 50
```

#### 2.1.8 Macros Compiladas (Seguras)

```fxbase
// Macro clásica limitada (solo resolución de símbolos)
LOCAL cCampo := "nombre"
? &cCampo              // Resuelve variable o campo de tabla activa

// Macro compilada con tipo seguro
LOCAL bFiltro AS CODEBLOCK<LOGICAL> := COMPILE<LOGICAL>(
    "edad > 18 AND activo = TRUE",
    { "edad" => INT, "activo" => LOGICAL }
)
? EVAL(bFiltro, 25, TRUE)   // TRUE
```

**Restricciones de seguridad:**
- Las macros no pueden acceder a variables `LOCAL` fuera de su contexto.
- En modo estricto, requieren firma de tipos explícita.
- No permiten llamadas a funciones arbitrarias del sistema (sandbox).

---

### 2.2 Sistema de Módulos (`MODULE` / `IMPORT` / `EXPORT`)

```fxbase
// Archivo: Facturacion.fx
MODULE Facturacion

IMPORT Database FROM "fxstd/db"
IMPORT { Calcular, Formatear } FROM "std/utils"
IMPORT * AS Math FROM "std/math"

// Visible solo dentro de este módulo
HIDDEN FUNCTION Auxiliar()
    // ...
END

// Visible para otros módulos que importen Facturacion
EXPORT CLASS Factura
    // ...
END

EXPORT FUNCTION EmitirFactura(oCliente AS OBJECT<Cliente>) AS RESULT<Factura, STRING>
    // ...
END
```

**Características:**
- Sin archivos de encabezado (`.ch`). La interfaz se extrae del AST.
- Resolución de importación: relativa, de biblioteca estándar, o de registro de paquetes.
- Sin ciclos de importación permitidos.
- Alias de módulos permitidos (`IMPORT * AS Alias`).

---

### 2.3 Concurrencia (Modelo CSP + Actores)

#### 2.3.1 Tareas Ligeras (Tasks)

```fxbase
// Ejecutar función de forma asíncrona
ASYNC FUNCTION ProcesarPedidos(aPedidos AS ARRAY<Pedido>)
    FOREACH oPed IN aPedidos
        SPAWN ProcesarUnPedido(oPed)   // No bloquea; retorna inmediatamente
    NEXT
    WAIT ALL                           // Espera a que todas terminen
    RETURN COUNT(aPedidos)
END

// Obtener resultado de tarea
LOCAL tarea := SPAWN CalcularTotal(oFactura)
LOCAL nTotal := AWAIT tarea            // Bloquea hasta obtener resultado
```

#### 2.3.2 Canales (Channels)

```fxbase
LOCAL chPedidos AS CHANNEL<Pedido> := CHANNEL<Pedido>(100)  // Buffer 100

// Productor
ASYNC FUNCTION RecibirPedidos()
    DO WHILE TRUE
        LOCAL oPed := RecibirDeRed()
        chPedidos <- oPed            // Enviar (bloquea si buffer lleno)
    ENDDO
END

// Consumidor
ASYNC FUNCTION AtenderPedidos()
    DO WHILE TRUE
        LOCAL oPed := <- chPedidos   // Recibir (bloquea si vacío)
        GuardarEnDB(oPed)
    ENDDO
END
```

#### 2.3.3 Select (Multiplexación)

```fxbase
SELECT
    CASE oPed := <- chPedidos
        Procesar(oPed)
    CASE <- chTimeout
        ? "Tiempo agotado"
        BREAK
    CASE chControl <- "pausa"
        Pausar()
END
```

**Garantías de seguridad:**
- Sin variables compartidas mutables entre tareas. La única forma de comunicación es vía canales o paso de mensajes.
- Variables `LOCAL` capturadas por closures en tareas se copian (no comparten referencia).

---

### 2.4 Manejo de Errores

#### 2.4.1 Excepciones (para errores excepcionales)

```fxbase
TRY
    AbrirArchivo("datos.txt")
CATCH e AS FileNotFoundError
    ? "Archivo no encontrado: " + e:Path
CATCH e AS FXException
    ? "Error inesperado: " + e:Message
    RAISE                          // Re-lanza
FINALLY
    CerrarRecursos()
END
```

#### 2.4.2 Resultados (para errores de dominio)

```fxbase
FUNCTION Dividir(nA AS DECIMAL, nB AS DECIMAL) AS RESULT<DECIMAL, STRING>
    IF nB == 0
        RETURN ERR("División por cero")
    ENDIF
    RETURN OK(nA / nB)
END

// Uso
LOCAL res := Dividir(10, 0)
MATCH res
    CASE OK(v)
        ? "Resultado: " + STR(v)
    CASE ERR(msg)
        ? "Fallo: " + msg
END

// Operador `?` para unwrap con valor por defecto
LOCAL nValor := Dividir(10, 0)?0   // Si ERR, usa 0
```

---

### 2.5 Bases de Datos (RDD 2.0)

#### 2.5.1 Conexiones y RDDs

```fxbase
// Conexión nativa a PostgreSQL
USE "postgres://user:pass@host/erp" VIA "PGSQL" ALIAS ventas

// SQLite en memoria (testing)
USE ":memory:" VIA "SQLITE" ALIAS test

// Conexión ODBC
USE "DSN=Contabilidad" VIA "ODBC" ALIAS contab
```

#### 2.5.2 Comandos xBase traducidos a SQL

```fxbase
// Navegación y búsqueda
USE ventas
SET INDEX TO "idx_fecha"            // Usa índice de la DB
SEEK CTOD("2026-01-01")             // Traduce a SQL parametrizado
LOCATE FOR ventas->monto > 1000 AND ventas->estado == "Pendiente"

// Actualización masiva
REPLACE ALL ventas->estado WITH "Procesado" ;
    WHERE ventas->fecha < DATE() - 30

// Relaciones
SET RELATION TO ventas->cliente_id INTO clientes
? clientes->nombre

// Agregaciones
COUNT TO nTotal FOR ventas->estado == "Pagado"
SUM ventas->monto TO nIngresos
AVERAGE ventas->monto TO nPromedio
```

**Traducción interna:**
- `LOCATE/SEEK` → `SELECT ... WHERE ... LIMIT 1`
- `REPLACE ALL` → `UPDATE ... WHERE ...`
- `SUM/AVERAGE` → `SELECT SUM(...)/AVG(...) FROM ...`
- Uso de prepared statements para prevenir inyección SQL.

#### 2.5.3 Tipos de Datos Extendidos

```fxbase
// JSON/JSONB como tipo nativo
LOCAL jConfig AS JSON := '{"host":"localhost","puerto":5432}'
? jConfig:host          // "localhost"

// Array de la DB mapeado a ARRAY<...>
LOCAL aTags AS ARRAY<STRING> := ventas->tags

// Fechas y timestamps con zona horaria
LOCAL tCreacion AS DATETIME := ventas->creado_en
? tCreacion:ISO8601()   // "2026-08-08T19:48:00-04:00"
```

---

### 2.6 Formularios y UI (GET/READ 2.0)

```fxbase
// Definición declarativa de formulario
FORM oDlg AS DIALOG TITLE "Registro de Cliente" WIDTH 400 HEIGHT 300

    @ 10, 10 SAY "Nombre:"
    @ 10, 80 GET oCliente:cNombre ;
        VALID !EMPTY(oCliente:cNombre) ;
        MESSAGE "Ingrese el nombre completo"

    @ 40, 10 SAY "Email:"
    @ 40, 80 GET oCliente:cEmail ;
        VALID IsEmail(oCliente:cEmail) ;
        PICTURE "@A"                    // Formato automático

    @ 70, 10 SAY "Fecha Nac."
    @ 70, 80 GET oCliente:dNacimiento ;
        VALID oCliente:dNacimiento <= DATE() - 18 * 365

    @ 100, 10 CHECKBOX oCliente:bActivo CAPTION "Activo"

    @ 130, 10 COMBOBOX oCliente:cTipo ;
        ITEMS {"Regular", "VIP", "Mayorista"}

    // Botones
    @ 200, 100 BUTTON "Guardar" ACTION Guardar(oCliente)
    @ 200, 200 BUTTON "Cancelar" ACTION oDlg:CLOSE()

    // Binding automático
    READ MODEL oCliente

ENDFORM
```

**Backends de UI:**
- **Terminal (TUI)**: Modo texto para servidores y SSH.
- **Desktop**: Qt6 / GTK4 via bindings nativos.
- **Web**: Compilación a WASM + DOM bindings.

---

### 2.7 Metaprogramación y Atributos

```fxbase
// Definición de atributo personalizado
ATTRIBUTE AuditLog(cTabla AS STRING)
    // Implementación en FXSTD o en biblioteca
END

// Uso
[Table("clientes"), PrimaryKey("id")]
[AuditLog("clientes")]
CLASS Cliente
    [Column("nombre", MaxLength := 100, Required)]
    PROPERTY cNombre AS STRING

    [Column("email", Unique)]
    PROPERTY cEmail AS STRING?

    [Column("saldo", Default := 0.00)]
    PROPERTY nSaldo AS DECIMAL
END

// Introspección en runtime
LOCAL oType := TYPEOF(Cliente)
FOREACH oProp IN oType:Properties
    ? oProp:Name, oProp:Type, oProp:Attributes
NEXT
```

---

### 2.8 Testing Integrado

```fxbase
/// Calcula el IVA según normativa vigente
/// @test 100.00, 16.00
/// @test 0.00, 0.00
/// @test -50.00, ERR  // Debe fallar con monto negativo
EXPORT FUNCTION IVA(nMonto AS DECIMAL) AS RESULT<DECIMAL, STRING>
    IF nMonto < 0
        RETURN ERR("Monto no puede ser negativo")
    ENDIF
    RETURN OK(nMonto * 0.16)
END

// Suite de pruebas explícita
SUITE "FacturacionTests"
    TEST "Total con IVA"
        LOCAL oFact := Factura():NEW(100.00)
        ASSERT oFact:Total() == 116.00
    END

    TEST "Factura sin items falla"
        LOCAL oFact := Factura():NEW()
        ASSERT RAISES(InvalidOperationError, {|| oFact:Total()})
    END
END
```

**Ejecución:**
```bash
fxbase test ./src          # Ejecuta todos los tests
fxbase test --coverage     # Genera reporte de cobertura
```

---

### 2.9 Interpolación y Formateo de Strings

```fxbase
LOCAL cNombre := "María"
LOCAL nSaldo := 1520.50

// Interpolación
? `Hola ${cNombre}, tu saldo es ${nSaldo}`
// → "Hola María, tu saldo es 1520.5"

// Formato numérico integrado
? `Total: ${nSaldo:N2}`     // "Total: 1,520.50"
? `ID: ${nId:D8}`           // "ID: 00000420"
? `Hex: ${nColor:X6}`       // "Hex: FF5733"

// Templates multilinea
LOCAL cSQL := `
    SELECT ${cCampos}
    FROM ${cTabla}
    WHERE fecha > ${dDesde:ISO}
`
```

---

### 2.10 Transpilador de Migración (xHarbour / Harbour / Clipper → FXBASE)

#### 2.10.1 Propósito y Justificación

El transpilador es un **componente crítico** (no opcional) que habilita la adopción de FXBASE en entornos con legado xBase. Sin él, la barrera de entrada (reescritura total de sistemas de 50k–500k LOC) haría inviable la migración.

**Principio rector:** FXBASE es un lenguaje **nuevo**, no un emulador. El transpilador es el **puente**, no la **prisión**. No busca compatibilidad binaria ni semántica al 100%, sino una **traducción mecánica seguida de revisión humana guiada**.

#### 2.10.2 Estrategia de Migración Gradual

```
Fase 1: Transpilar todo y compilar con --legacy
         ↓ (el código corre, aunque no usa features modernos)
Fase 2: Activar advertencias de modo estricto, arreglar por módulos
         ↓
Fase 3: Reescribir módulos críticos (facturación, seguridad) en FXBASE nativo
         ↓
Fase 4: Desactivar --legacy. El sistema ya es 100% FXBASE.
```

#### 2.10.3 Funcionalidades del Transpilador

**a) Traducción mecánica de sintaxis**

El transpilador analiza el AST de xHarbour y genera código FXBASE equivalente, aplicando las siguientes transformaciones:

| Patrón xHarbour | Transformación FXBASE | Notas |
|-----------------|----------------------|-------|
| `PRIVATE var` | `MODULE VARIABLE var AS VARIANT` | Estado global explícito |
| `PUBLIC var` | `EXPORT MODULE VARIABLE var AS VARIANT` | Visible para otros módulos |
| `LOCAL var := expr` | `LOCAL var AS VARIANT := expr` | Modo dinámico por defecto |
| `LOCAL var` | `LOCAL var AS VARIANT` | |
| `FUNCTION Foo(a, b)` | `FUNCTION Foo(a AS VARIANT, b AS VARIANT) AS VARIANT` | |
| `PROCEDURE Foo(...)` | `FUNCTION Foo(...) AS NIL` | |
| `&cExpr` | `COMPILE<VARIANT>(cExpr)` | Macro tipada con advertencia |
| `BEGIN SEQUENCE ... RECOVER` | `TRY ... CATCH` | Mapeo directo |
| `REQUEST Func` | `IMPORT Func FROM "legacy/func"` | Resolución heurística |
| `#include "file.ch"` | `IMPORT * FROM "file"` | Conversión de headers |
| `SET RELATION TO ...` | `SET RELATION TO ...` | Comando conservado (RDD 2.0) |
| `DBF/CDX/NTX` | `USE ... VIA "DBF"` | RDD legacy explícito |

**b) Generación de anotaciones de migración (`[FX-MIGRATE]`)**

Cada patrón que no tiene traducción directa o que introduce riesgo semántico se marca con comentarios estructurados:

```fxbase
// === GENERADO POR FXBASE MIGRATE v1.0 ===
// Origen: Facturacion.prg:142

// [FX-MIGRATE: RIESGO-101] Uso de macro insegura detectado
// [FX-MIGRATE] Reemplazar por COMPILE<>() con firma de tipos explícita
// [FX-MIGRATE] Contexto: Filtro dinámico construido desde entrada de usuario
LOCAL bExpr := COMPILE<VARIANT>(cExpresion)

// [FX-MIGRATE: RIESGO-102] Variable PUBLIC detectada
// [FX-MIGRATE] Considerar encapsular en módulo o pasar por parámetro
// [FX-MIGRATE] Impacto: 47 archivos referencian esta variable
EXPORT MODULE VARIABLE nContadorGlobal AS VARIANT

// [FX-MIGRATE: RIESGO-201] Tipado implícito en función crítica
// [FX-MIGRATE] Recomendación: tipar como FUNCTION(..., ...) AS DECIMAL
FUNCTION CalcularTotal(nSubtotal, nImpuesto)
    RETURN nSubtotal + nImpuesto
END

// [FX-MIGRATE: RIESGO-202] Uso de SET EXACT OFF detectado
// [FX-MIGRATE] FXBASE usa comparación estricta por defecto
// [FX-MIGRATE] Revisar lógica de búsquedas y LOCATE

// [FX-MIGRATE: RIESGO-301] Manipulación cruda de POINTER detectada
// [FX-MIGRATE] Requiere bloque UNSAFE y revisión de seguridad
// [FX-MIGRATE] Contexto: Interop con biblioteca C legacy
UNSAFE {
    LOCAL p := malloc(1024)
    // ...
}

// [FX-MIGRATE: RIESGO-302] CodeBlock sin tipado detectado
// [FX-MIGRATE] Recomendación: añadir firma CODEBLOCK<...>
LOCAL bFiltrar := {|x| x.activo = TRUE}

// [FX-MIGRATE: RIESGO-401] Include circular detectado
// [FX-MIGRATE] Refactorizar para romper el ciclo
// [FX-MIGRATE] Archivos: Facturacion.prg ↔ Clientes.prg

// [FX-MIGRATE: RIESGO-402] REQUEST no resuelto
// [FX-MIGRATE] Función: FuncionExterna
// [FX-MIGRATE] Referenciada en: Modulo1.prg:10
```

**c) Reporte de migración**

```bash
$ fxbase migrate --report --source ./sistema-legacy/ --output ./sistema-fxbase/

╔══════════════════════════════════════════════════════════════════╗
║           FXBASE MIGRATE — Reporte de Conversión                 ║
╠══════════════════════════════════════════════════════════════════╣
║ Archivos procesados:              342                            ║
║ Líneas totales (origen):          89,420                         ║
║ Líneas generadas (FXBASE):        94,102                         ║
║                                                                  ║
║ Traducción automática:            78,301 líneas (87.6%)          ║
║ Requiere revisión manual:         11,119 líneas (12.4%)          ║
║                                                                  ║
║ RIESGOS DETECTADOS:                                              ║
║ ┌─────────────────────────────┬──────────┬──────────┬───────────┐ ║
║ │ Tipo                        │ Código   │ Cantidad │ Severidad │ ║
║ ├─────────────────────────────┼──────────┼──────────┼───────────┤ ║
║ │ Variables PUBLIC/PRIVATE    │ RIESGO-102 │ 234      │ ALTA      │ ║
║ │ Macros inseguras (&)        │ RIESGO-101 │ 45       │ ALTA      │ ║
║ │ Tipos implícitos críticos   │ RIESGO-201 │ 8,901    │ MEDIA     │ ║
║ │ SET EXACT / SET SOFTSEEK    │ RIESGO-202 │ 12       │ MEDIA     │ ║
║ │ Memoria cruda (POINTER)     │ RIESGO-301 │ 67       │ ALTA      │ ║
║ │ CodeBlocks sin contexto     │ RIESGO-302 │ 189      │ BAJA      │ ║
║ │ Headers circulares (#inc)   │ RIESGO-401 │ 23       │ MEDIA     │ ║
║ │ Funciones no resueltas      │ RIESGO-402 │ 8        │ ALTA      │ ║
║ └─────────────────────────────┴──────────┴──────────┴───────────┘ ║
║                                                                  ║
║ Tiempo estimado de revisión:      42 horas (1 desarrollador)     ║
║ Archivos listos para --legacy:    312 (91.2%)                    ║
╚══════════════════════════════════════════════════════════════════╝
```

**d) Modo `--legacy` del compilador**

El compilador FXBASE acepta un flag `--legacy` que:
- Habilita variables `PUBLIC`/`PRIVATE` emuladas (via módulo implícito).
- Permite tipado dinámico global sin advertencias.
- Emula comportamientos de xHarbour como `SET EXACT OFF`.
- Permite macros sin firma de tipos.

**Objetivo:** Que el código transpilado compile y ejecute **inmediatamente**, sin requerir modificaciones. Luego, el equipo migra módulo por módulo hacia FXBASE nativo.

#### 2.10.4 Limitaciones y Casos No Soportados

El transpilador **no garantiza** traducción en los siguientes casos, y emitirá errores bloqueantes:

| Caso | Razón | Acción requerida |
|------|-------|------------------|
| Código ensamblador inline (`ASM`) | No portable | Reescribir en C vía FFI o eliminar |
| Uso directo de estructuras internas de RDD | Acoplamiento profundo | Refactorizar a API pública del RDD |
| DLLs de terceros sin headers | Imposible inferir interfaz | Crear bindings FXBASE manualmente |
| Macros que generan código con efectos secundarios | Sandbox violado | Reescribir lógica explícitamente |

#### 2.10.5 Arquitectura del Transpilador

```
Código Fuente xHarbour (.prg, .ch)
    │
    ▼
[Lexer xHarbour] ──► Tokens xHarbour
    │
    ▼
[Parser xHarbour] ──► AST xHarbour (formato intermedio normalizado)
    │
    ▼
[Analizador Semántico xHarbour]
    ├──► Resolución de símbolos (PUBLIC/PRIVATE/LOCAL)
    ├──► Inferencia heurística de tipos (números vs strings vs fechas)
    ├──► Detección de dependencias entre archivos
    └──► Detección de patrones de riesgo
    │
    ▼
[Transformador FXBASE]
    ├──► Mapeo de AST xHarbour → AST FXBASE
    ├──► Inserción de anotaciones [FX-MIGRATE]
    ├──► Generación de módulos (agrupación de .prg en .fx)
    └──► Generación de imports para funciones REQUEST
    │
    ▼
[Código Fuente FXBASE (.fx)]
    │
    ▼
[Compilador FXBASE --legacy] ──► Binario ejecutable
```

**Componentes internos:**
- **Lexer/Parser xHarbour:** Reutiliza gramática de xHarbour 1.2.x (licencia GPL compatible).
- **Inferencia de tipos heurística:** Analiza usos de variables (ej: `n*` prefijo → numérico, `c*` → string, `d*` → date, `l*` → logical, `a*` → array, `o*` → object).
- **Detector de dependencias:** Construye grafo de `#include` y `REQUEST` para generar módulos coherentes.
- **Generador de FX-IR:** Produce representación intermedia que alimenta tanto el transpilador como el compilador FXBASE.

---

## 3. Requisitos No Funcionales

### 3.1 Rendimiento

| Métrica | Objetivo | Notas |
|---------|----------|-------|
| Tiempo de compilación | < 5s para 100k LOC | Comparable a Go |
| Tiempo de inicio (binario) | < 50ms | Sin runtime pesado |
| Overhead de GC | < 10% en benchmarks estándar | GC generacional con write barrier optimizado |
| Latencia de canales | < 100ns | Para paso de mensajes entre tareas |
| Throughput de RDD SQL | Traducción < 1ms por query | Cache de prepared statements |
| Velocidad de transpilación | > 10k LOC/s | Procesamiento batch de legado |

### 3.2 Portabilidad

| Plataforma | Backend | Prioridad |
|------------|---------|-----------|
| Linux x86_64 | LLVM nativo | P0 |
| Linux ARM64 | LLVM nativo | P0 |
| Windows x86_64 | LLVM nativo / MSVC | P0 |
| macOS x86_64 / ARM64 | LLVM nativo | P1 |
| Web (WASM) | LLVM → WASM | P1 |
| iOS / Android | LLVM cruzado | P2 |

### 3.3 Seguridad

- **Memory safety:** Sin punteros crudos accesibles al usuario (salvo bloque `UNSAFE` para interop C).
- **Type safety:** Null safety en modo estricto. Sin coerción implícita peligrosa.
- **Macro safety:** Sandbox de macros. Sin acceso a filesystem o red desde `COMPILE()`.
- **SQL safety:** Todas las operaciones RDD usan prepared statements. Sin concatenación de strings en queries.
- **Transpilador safety:** El código generado no debe introducir vulnerabilidades nuevas (ej: no convertir macros inseguras en `EVAL` sin sandbox).

### 3.4 Compatibilidad y Migración

- **Modo Legacy:** Compilador con flag `--legacy` que acepta sintaxis xHarbour pura con advertencias.
- **Transpilador:** Herramienta `fxbase migrate` que convierte `.prg`/`.ch` a `.fx` con anotaciones de riesgo y reporte de migración.
- **Interop C:** FFI nativo para enlazar con bibliotecas existentes (libpq, SQLite, OpenSSL, etc.).
- **Coexistencia:** Permite mezclar módulos FXBASE nativos y módulos `--legacy` en el mismo ejecutable durante la transición.

### 3.5 Tooling

| Herramienta | Descripción |
|-------------|-------------|
| `fxbase` | CLI principal: build, test, run, fmt, doc, migrate |
| `fxbase migrate` | Transpilador xHarbour/Harbour/Clipper → FXBASE con reporte de riesgos |
| `fxpkg` | Gestor de paquetes. Registro central y privado. Semver. Lockfile. |
| `fxbase fmt` | Formateador automático (opiniated, como `gofmt`) |
| `fxbase doc` | Generador de documentación HTML/Markdown desde comentarios `///` |
| LSP Server | Autocompletado, goto-definition, refactor, diagnostics en tiempo real |
| REPL | `fxbase repl` para pruebas interactivas |
| Debugger | GDB/LLDB compatible + DAP (Debug Adapter Protocol) |

---

## 4. Arquitectura del Compilador y Transpilador

### 4.1 Pipeline de Compilación FXBASE

```
Fuente FXBASE (.fx)
    │
    ▼
[Lexer] ──► Tokens
    │
    ▼
[Parser] ──► AST (Abstract Syntax Tree)
    │
    ▼
[Analyzer Semántico] ──► AST Tipado + Tabla de Símbolos
    │
    ▼
[Optimizador IR] ──► FX-IR (Representación Intermedia propia)
    │
    ├──► [Backend C] ──► .c ──► GCC/Clang/MSVC ──► Binario
    ├──► [Backend LLVM] ──► .ll / .bc ──► lli / llc ──► Binario
    ├──► [Backend WASM] ──► .wasm + .js (glue)
    └──► [Backend VM] ──► Bytecode ──► FXVM (Runtime scripting)
```

### 4.2 Pipeline del Transpilador de Migración

```
Fuente xHarbour (.prg, .ch)
    │
    ▼
[Lexer xHarbour] ──► Tokens xHarbour
    │
    ▼
[Parser xHarbour] ──► AST xHarbour
    │
    ▼
[Analizador Semántico xHarbour]
    ├──► Resolución de símbolos globales (PUBLIC/PRIVATE)
    ├──► Inferencia heurística de tipos
    ├──► Detección de dependencias (#include, REQUEST)
    └──► Detección de patrones de riesgo
    │
    ▼
[Transformador FXBASE]
    ├──► Mapeo AST xHarbour → AST FXBASE
    ├──► Inserción de anotaciones [FX-MIGRATE]
    ├──► Generación de módulos (.fx)
    └──► Generación de imports
    │
    ▼
[Código Fuente FXBASE (.fx)] ──► [Compilador FXBASE --legacy]
```

### 4.3 Componentes Clave

| Componente | Tecnología / Enfoque | Responsabilidad |
|------------|----------------------|-----------------|
| **Lexer** | Hand-written o via `logos` (Rust) / `text_scanner` (Go) | Tokenización UTF-8, interpolación de strings |
| **Parser** | Recursive descent (LL(k)) o Pratt | AST sin tipos, manejo de errores recoverable |
| **Name Resolver** | Walk del AST | Resolución de módulos, imports, visibilidad |
| **Type Checker** | Hindley-Milner + extensiones | Inferencia, unificación, reporte de errores claros |
| **FX-IR** | SSA-like (Static Single Assignment) | Optimizaciones: constant folding, inlining, DCE |
| **Backend C** | Generador de código C99 | Bootstrap rápido, portabilidad máxima |
| **Backend LLVM** | LLVM C-API / Inkwell (Rust) | Optimizaciones agresivas, codegen nativo |
| **FXVM** | Stack-based VM con GC | Ejecución de scripts, REPL, hot-reload |
| **Lexer xHarbour** | Reutilizado/limpio de xHarbour 1.2.x | Tokenización de código fuente legado |
| **Parser xHarbour** | AST normalizado de xHarbour | Representación intermedia del legado |
| **Inferencia Heurística** | Análisis de patrones de nombre | `n*`=INT, `c*`=STRING, `d*`=DATE, etc. |
| **Transformador** | Walk del AST xHarbour + reglas | Generación de AST FXBASE con anotaciones |
| **Report Generator** | Markdown/JSON/HTML | Reporte de migración con métricas y riesgos |

### 4.4 Biblioteca Estándar (FXSTD)

```
fxstd/
├── core/
│   ├── types.fx        // Result, Optional, Channel
│   ├── errors.fx       // FXException, FileNotFoundError, etc.
│   └── memory.fx       // GC hints, unsafe blocks
├── collections/
│   ├── array.fx
│   ├── hash.fx
│   ├── set.fx
│   └── iterator.fx
├── io/
│   ├── file.fx
│   ├── path.fx
│   └── stream.fx
├── db/
│   ├── connection.fx   // Abstracción RDD 2.0
│   ├── rdd_pgsql.fx
│   ├── rdd_sqlite.fx
│   ├── rdd_mysql.fx
│   └── rdd_dbf.fx      // Legacy
├── net/
│   ├── http.fx
│   ├── tcp.fx
│   └── websocket.fx
├── concurrency/
│   ├── task.fx
│   ├── channel.fx
│   └── select.fx
├── ui/
│   ├── form.fx         // GET/READ 2.0
│   ├── dialog.fx
│   └── bindings/       // Qt, GTK, DOM
├── crypto/
│   ├── hash.fx
│   └── cipher.fx
├── json/
│   └── json.fx
└── testing/
    ├── assert.fx
    └── runner.fx
```

---

## 5. Especificación de Sintaxis (Resumen)

### 5.1 Palabras Reservadas

```
AND        AS         ASYNC      AWAIT      BREAK      BYREF
BYVAL      CASE       CATCH      CLASS      CONSTRUCTOR
CONTINUE   DECIMAL    DEFAULT    DO         ELSE       ELSEIF
END        ENDCASE    ENDDO      ENDFOR     ENDIF      ENDMATCH
EXIT       EXPORT     FALSE      FINALLY    FOR        FOREACH
FROM       FUNCTION   GLOBAL     HIDDEN     IF         IMPORT
IN         INHERIT    INT        IS         LOCAL      LOGICAL
MATCH      METHOD     MODULE     NEXT       NIL        NOT
OBJECT     OPTIONAL   OR         OVERRIDE   PRIVATE    PROPERTY
PROTECTED  PUBLIC     RAISE      RETURN     SELECT     SELF
SPAWN      STATIC     STEP       STRING     STRUCT     SUPER
THEN       THIS       TO         TRUE       TRY        TYPEOF
UNTIL      USE        VALID      VAR        WAIT       WHERE
WHILE      WITH
```

### 5.2 Operadores

| Precedencia | Operador | Descripción |
|-------------|----------|-------------|
| 1 (alta) | `::` | Resolución de método/namespace |
| 2 | `()` `[]` `->` | Llamada, índice, acceso campo |
| 3 | `++` `--` (post) | Incremento/decremento |
| 4 | `++` `--` (pre) `+` `-` `!` `~` | Unarios |
| 5 | `*` `/` `%` | Multiplicativos |
| 6 | `+` `-` | Aditivos |
| 7 | `<<` `>>` | Bit shift |
| 8 | `<` `<=` `>` `>=` | Relacionales |
| 9 | `==` `!=` `===` `!==` | Igualdad (estricta y coerciva) |
| 10 | `&` | AND bit |
| 11 | `^` | XOR bit |
| 12 | `\|` | OR bit |
| 13 | `&&` | AND lógico |
| 14 | `\|\|` | OR lógico |
| 15 | `?:` | Ternario |
| 16 | `:=` `+=` `-=` `*=` `/=` | Asignación |
| 17 (baja) | `,` | Secuencia |

### 5.3 Literales

```fxbase
// Números
42          // INT
3.14159     // FLOAT
3.14e-10    // FLOAT científico
0xFF        // Hexadecimal
0b1010      // Binario
100.50D     // DECIMAL explícito

// Strings
"Hola"                      // String simple
`Interpolado: ${nValor}`    // Template string
"Línea 1\nLínea 2"         // Escapes estándar
@"C:\path\to\file"       // Verbatim string (sin escapes)

// Fechas
DATE(2026, 8, 8)            // Constructor
CTOD("08/08/2026")          // String a fecha
DATETIME("2026-08-08T19:48:00-04:00")  // ISO 8601

// Lógicos
TRUE
FALSE

// Arrays
{1, 2, 3}                           // ARRAY<INT> (inferido)
ARRAY<STRING>{"a", "b", "c"}        // ARRAY<STRING> explícito

// Hashes
{| "clave" => "valor", 1 => 100 |}              // HASH<VARIANT, VARIANT>
HASH<STRING, INT>{| "a" => 1, "b" => 2 |}       // Tipado

// CodeBlocks
{|a, b| a + b}                                      // Dinámico
{|a AS INT, b AS INT| a + b} AS CODEBLOCK<INT,INT>  // Tipado

// JSON
{"host": "localhost", "puerto": 5432}              // JSON literal
```

---

## 6. Roadmap

### Fase 0: Fundamentos y Transpilador (Meses 1–6)
- [ ] Especificación del lenguaje v1.0 (este documento)
- [ ] Lexer y Parser funcionales (prototipo en Go/Rust)
- [ ] AST y pretty-printer
- [ ] REPL básico (modo dinámico)
- [ ] Backend C funcional (compilación a ejecutable)
- [ ] **Lexer y Parser xHarbour (reutilizado/limpio)**
- [ ] **Analizador semántico xHarbour (resolución de símbolos, inferencia heurística)**
- [ ] **Transformador básico xHarbour → FXBASE (traducción mecánica)**
- [ ] **Generador de reportes de migración**
- [ ] FXSTD mínima: tipos core, I/O básico, arrays, hashes
- [ ] **Prueba piloto: transpilar y compilar (con --legacy) un sistema real de 10k LOC**

### Fase 1: Lenguaje Completo y Migración (Meses 7–12)
- [ ] Type checker con inferencia
- [ ] Sistema de módulos (`MODULE`/`IMPORT`/`EXPORT`)
- [ ] POO completa (herencia, polimorfismo, interfaces)
- [ ] CodeBlocks tipados
- [ ] Macros seguras (`COMPILE`)
- [ ] Backend LLVM
- [ ] Testing integrado (`fxbase test`)
- [ ] Formateador (`fxbase fmt`)
- [ ] Documentador (`fxbase doc`)
- [ ] **Transpilador completo con anotaciones [FX-MIGRATE]**
- [ ] **Modo `--legacy` del compilador**
- [ ] **Prueba de migración real: sistema de 50k+ LOC transpilado y funcional**

### Fase 2: Runtime y DB (Meses 13–18)
- [ ] GC generacional
- [ ] Concurrencia: tasks, channels, select
- [ ] RDD 2.0: PostgreSQL, SQLite, MySQL
- [ ] JSON nativo
- [ ] HTTP client/server
- [ ] FFI e interop C
- [ ] **Mejoras al transpilador: soporte de Harbour y CA-Clipper 5.3**

### Fase 3: Tooling y Ecosistema (Meses 19–24)
- [ ] LSP Server
- [ ] Package manager (`fxpkg`) con registro público
- [ ] Debugger (DAP)
- [ ] Backend WASM
- [ ] UI: TUI y Desktop (Qt bindings)
- [ ] **Transpilador con modo "asistido": sugerencias automáticas de refactorización**

### Fase 4: Producción (Meses 25–36)
- [ ] Optimizaciones agresivas (LTO, PGO)
- [ ] UI Web (WASM + DOM)
- [ ] Mobile (iOS/Android)
- [ ] IDE plugins (VS Code, Vim, Emacs)
- [ ] Benchmarks y ajuste de rendimiento
- [ ] Certificación y documentación completa
- [ ] **Transpilador de producción: migración de sistemas > 200k LOC documentada**

---

## 7. Criterios de Aceptación (Definition of Done)

1. **Compilación exitosa:** Todo código de ejemplo en este PRD compila sin errores en modo estricto.
2. **Tests pasan:** Suite de pruebas del compilador > 90% de cobertura.
3. **Sin fugas de memoria:** Valgrind/ASAN limpio en benchmarks de 24h.
4. **Performance:** Compilación de 10k LOC en < 1s en hardware de referencia (Ryzen 5 / 16GB RAM).
5. **Migración real:** Al menos una aplicación xHarbour de 50k LOC se transpila a FXBASE, compila con `--legacy` y ejecuta con modificaciones menores (< 5% de líneas).
6. **Reporte de migración preciso:** El transpilador genera reportes con > 95% de precisión en la detección de riesgos (validado contra revisión manual de expertos).
7. **Documentación:** Toda función pública de FXSTD tiene comentarios `///` y ejemplos.

---

## 8. Glosario

| Término | Definición |
|---------|------------|
| **xBase** | Familia de lenguajes derivados de dBASE (Clipper, Harbour, xHarbour, FoxPro). |
| **RDD** | Replaceable Database Driver. Arquitectura de abstracción de acceso a datos. |
| **CodeBlock** | Closure anónima, característica distintiva de xBase. |
| **Macro** | Compilación de expresiones en tiempo de ejecución. |
| **FX-IR** | Representación intermedia propia de FXBASE, previa a generación de código. |
| **FXVM** | Máquina virtual de FXBASE para ejecución de bytecode. |
| **FXSTD** | Biblioteca estándar de FXBASE. |
| **GC** | Garbage Collector (recolector de basura). |
| **CSP** | Communicating Sequential Processes. Modelo de concurrencia. |
| **LSP** | Language Server Protocol. |
| **FFI** | Foreign Function Interface. Interoperabilidad con C. |
| **WASM** | WebAssembly. |
| **Transpilador** | Herramienta que traduce código fuente xHarbour/Harbour/Clipper a código fuente FXBASE. |
| **Modo `--legacy`** | Flag del compilador FXBASE que emula comportamientos de xHarbour para facilitar la migración gradual. |
| **Anotación `[FX-MIGRATE]`** | Comentario estructurado insertado por el transpilador que señala código que requiere revisión humana. |

---

## 9. Referencias

1. xHarbour Project. *xHarbour Documentation*. [http://xharbour.org](http://xharbour.org)
2. Harbour Project. *Harbour Reference Guide*. [https://harbour.github.io](https://harbour.github.io)
3. CA-Clipper 5.3. *Language Reference*.
4. The Go Programming Language Specification. [https://golang.org/ref/spec](https://golang.org/ref/spec)
5. The Rust Programming Language. [https://doc.rust-lang.org](https://doc.rust-lang.org)
6. TypeScript Language Specification. [https://www.typescriptlang.org](https://www.typescriptlang.org)
7. LLVM Language Reference Manual. [https://llvm.org/docs/LangRef.html](https://llvm.org/docs/LangRef.html)

---

*Fin del Documento*
