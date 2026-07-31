# FPXBASE — Estrategia de Compatibilidad xBase (Tiered 80/20)

> **Estado:** Roadmap — pendiente de implementación. Véase `docs/ROADMAP.md` Fase 2.5 (Tipado gradual + smart pointers) y Fase 3 (Compatibilidad estratificada).
>
> Este documento describe la **estrategia de adopción gradual** para usuarios con código xBASE legacy (Clipper, Harbour, FoxPro). No es un sustituto del PRD ni de la gramática: la complementa explicando **qué nivel de compatibilidad se ofrece en cada tier** y qué herramientas de migración acompañan a cada uno.

---

## 1. Por qué 80/20 y no 100%

El ecosistema xBASE tiene ~40 años de historia y dialectos divergentes (Clipper 5.x, Harbour, FoxPro 2.x, Visual FoxPro). Una reimplementación 1:1 arrastraría décadas de deuda técnica, comportamientos implícitos no documentados y dependencias de un motor RDD binario que **FPXBASE ha decidido reemplazar por SQL**.

La estrategia es estratificada:

| Tier                                  | Compatibilidad objetivo | Qué se mantiene                                              | Qué se descarta                                  |
|---------------------------------------|-------------------------|--------------------------------------------------------------|--------------------------------------------------|
| **T1 — Sintaxis y control de flujo**  | ~95 %                   | IF/ENDIF, DO WHILE/ENDDO, FOR/NEXT, ?, ??, @...SAY/GET       | Abreviaturas de 4 letras (DECL→DECLARE, etc.)     |
| **T2 — DB legacy sobre RDD virtual**  | Sintaxis ~80 % / Binaria 0 % | Comandos `USE`, `SKIP`, `SEEK`, `GO TOP`, `EOF()`, `BOF()` traducidos a SQL | Archivos `.dbf/.cdx/.ntx/.fpt` como estado runtime |
| **T3 — Macros dinámicas (`&`)**       | Sintaxis ~30 %          | Resolución de identificadores y expresiones simples aisladas | `&` en declaraciones, parámetros de macros, types |

Cada tier es **opt-in progresivo** (compilación por archivo / bloque) — el código nuevo FPXBASE no paga el costo de compatibilidad si no lo usa.

---

## 2. Tier 1 — Sintaxis y control de flujo (~95 %)

**Regla clave:** el lexer **NO acepta abreviaturas de 4 letras** para comandos. Esto reduce el espacio de tokens y elimina ambigüedad entre dialectos.

### 2.1 Comandos soportados sin diferencia semántica

| Familia      | Comandos                                                                            |
|--------------|-------------------------------------------------------------------------------------|
| Condicionales | `IF … ENDIF`, `DO CASE … ENDCASE`, `IIF(cond, a, b)`                               |
| Bucles       | `DO WHILE … ENDDO`, `FOR … NEXT`, `FOR EACH … IN … NEXT`                           |
| Salida       | `? expr` (newline), `?? expr` (same-line), `?>` a stdout con buffering             |
| IO formato   | `@ row, col SAY expr`, `@ row, col GET var PICTURE '…'`                            |
| Procedural   | `FUNCTION … ENDFUNC`, `PROCEDURE … ENDPROC`, `DO procname`, `RETURN`               |

### 2.2 Abreviaturas de 4 letras: eliminadas

En xBASE clásico: `DECLARE` admitía `DECL`, `PROCEDURE` admitía `PROC`, `FUNCTION` admitía `FUNCT`, etc. **FPXBASE exige la palabra completa.** Razón: el lexer case-insensitive colapsaría 4× variantes por keyword, inflando la `FKeywordMap` y creando falsos positivos (`LOCAL` vs `LOCATE`).

```xbase
PROCEDURE Main()              ; OK
PROC Main()                   ; FPX-LE-0007 — keyword truncada
```

Equivalencia semántica con Harbour (que también las eliminó en su mayoría).

### 2.3 Estado de implementación

- **Comandos con semántica completa en IR:** `IF/ELSE/ENDIF`, `DO WHILE/ENDDO`, `FOR/NEXT`, `?`, `??`. (Phase 1.1 — `fpx.ir.pas` `TFPXIRGenerator` ya baja los tres primeros.)
- **Comandos pendientes de IR:** `@…SAY`, `@…GET` (requieren `fpx.rtl` no-stub).
- **Verificación automática:** `tests/implementation/test_ir.pas` cubre `IF`, `WHILE`, `FOR` end-to-end.

---

## 3. Tier 2 — DB legacy sobre RDD virtual (Sintaxis ~80 %, Binaria 0 %)

**Regla clave:** los comandos clásicos de navegación se **desmantelan en compile-time** y se redirigen a una capa RDD virtual que traduce cada operación a SQL sobre el motor conectado (SQLite, PostgreSQL, MSSQL).

### 3.1 Comandos redirigidos

| Comando xBASE  | Traducción RTL                                                                                |
|----------------|-----------------------------------------------------------------------------------------------|
| `USE tabla`    | `OPEN CURSOR` + `SELECT * FROM tabla [WHERE active]`                                          |
| `SKIP n`       | `CURSOR.SKIP(n)` (batched, ver §6)                                                           |
| `SKIP 0`       | `CURSOR.REFRESH()` (no-op lógico, recarga buffer)                                            |
| `GO TOP`       | `CURSOR.RESET()`                                                                              |
| `GO BOTTOM`    | `CURSOR.LAST()`                                                                               |
| `SEEK expr`    | `WHERE col = ?` + `CURSOR.SEEK` (índice binario si el motor lo soporta)                       |
| `APPEND BLANK` | `INSERT INTO tabla DEFAULT VALUES`                                                           |
| `REPLACE … WITH …` | `UPDATE tabla SET col = ? WHERE <current_row_predicate>` (CTE anchor)                     |
| `EOF()`, `BOF()` | `CURSOR.EOF()` / `CURSOR.BOF()` (proxys sobre estado del buffer + cursor SQL real)        |
| `PACK`         | `DELETE FROM tabla WHERE <mark-as-deleted-rowids>; VACUUM` (SQLite) o equivalente en motor |
| `ZAP`          | `DROP TABLE tabla; CREATE TABLE tabla (...)` (recreate)                                       |

### 3.2 Compatibilidad binaria: explícitamente descartada

FPXBASE **NO abre `.dbf/.cdx/.ntx/.fpt` como estado runtime**. Solo `fpx-dbf` (herramienta CLI en `src/tools/fpx-dbf/`) puede **importar** schema + datos a SQLite/Postgres/MSSQL o **exportar** una tabla SQL a `.dbf` para interoperabilidad con sistemas externos.

### 3.3 Estado de implementación

- **Estado actual:** `fpx.rtl.pas` es un **stub vacío** (`src/fpx/fpx.rtl.pas`). Las definiciones de tipos que `fpx.cli.pas` espera existen; la implementación no.
- **Trabajo previo:** los tokens (`kwUse`, `kwSkip`, `kwSeek`, `kwEof`, `kwBof`, etc.) **sí están en `fpx.tokens.pas`** y el parser reconoce los comandos a nivel sintáctico. Falta el lowering IR → RTL call.
- **Plan de implementación:** Fase 2.3 del roadmap (RTL + RDD virtual sobre SQLite).

---

## 4. Tier 3 — Macros dinámicas `&` (Sintaxis ~30 %)

**Regla clave:** la macroevaluación `&var` queda restringida a **resolución de identificadores** y **expresiones simples aisladas**. Para todo lo demás, se promueven **Bloques de Código** `{|a, b| …}` y **lambdas** (`LOCAL f := {|x| x + 1}`).

### 4.1 Lo que se mantiene

```xbase
LOCAL name := "CUSTOMER"
USE &name              ; Equivale a USE CUSTOMER — resuelto en runtime, no en compile
LOCAL fname := "lastname"
? FIELD&fname          ; Equivale a ? FIELD:lastname (FIELDGET dinámico)
LOCAL op := "+"
? 10 &op 5             ; FPX-LE-0010 — operador dinámico (warning en compile, error en #strict)
```

### 4.2 Lo que se descarta

| Forma                       | Por qué se descarta                                              |
|-----------------------------|------------------------------------------------------------------|
| `&macro.{}`                 | Constructor literal — reemplazable por `HASH{}`                  |
| `&macro.()`                 | Constructor de tuplas — reemplazable por `TUPLE(...)` o arrays   |
| `&macro(x, y, z)`           | Constructor de objeto literal — reemplazable por `CLASS {...}`   |
| `&macro.1, &macro.2, …`     | Tuplas por número — reemplazable por `TUPLE{a, b, c}`            |
| `&macro.field`              | Acceso a campo dinámico — reemplazable por `OBJECT.FIELD_GET(...)` |
| `&macro->method`            | Mensaje dinámico — reemplazable por `OBJECT.METHOD_GET(...)`     |
| `&macro\.literal`           | Constante — siempre reemplazable por la constante                |

### 4.3 Razón: AOT y optimización

Las macros `&` requieren que el compilador **emita código que evalúe la expresión en runtime**, lo que imposibilita:
- Análisis estático de tipos
- Eliminación de código muerto sobre la macro-expandida
- Inline / constant folding
- Verificación de seguridad (boundary checks, null checks)

Promover Bloques de Código permite al compilador:
- Inferir tipos de parámetros y retorno
- Inline en sitios de uso
- Generar código AOT sin overhead de dispatch dinámico

### 4.4 Estado de implementación

- **Estado actual:** `&` lexea como `ttAmp` y se entrega al parser sin transformación. El parser aún **no** lo procesa.
- **Equivalente moderno recomendado:** `{|a, b| …}` ya funciona como codeblock literal (lex + parse OK; IR/eval pendiente).

---

## 5. Herramientas de migración (cross-tier)

### 5.1 `fpx-dbf` — Importador / Exportador

CLI que migra datos y schema:

```bash
fpx-dbf import  customers.dbf  --into sqlite://data/app.db
fpx-dbf export  customers      --from sqlite://data/app.db  --to customers.dbf --format "dBASE IV"
fpx-dbf schema  customers.dbf  --emit-sql sqlite
```

Respetar índices NTX/CDX es responsabilidad de la importación: el importador los lee, los traduce a `CREATE INDEX` SQL y los aplica en orden.

### 5.2 Linter de código legacy (`--legacy` flag)

```bash
fpx --check-migrations Main.prg
```

Detecta patrones legacy que el tier objetivo rechazará:

| Patrón                           | Diagnóstico                                   |
|----------------------------------|-----------------------------------------------|
| Abreviatura de 4 letras (`DECL`) | FPW-LEG-0001                                  |
| `&macro.{}`                      | FPW-LEG-0002                                  |
| `GOTO n` numérico                | FPW-LEG-0003                                  |
| `RECNO()`, `LASTREC()`           | FPW-LEG-0004                                  |
| `BEGIN SEQUENCE` / `RECOVER`     | Sugerencia: usar `TRY/CATCH` (FPW-LEG-0005)   |
| `SET FORMAT TO file.prt`         | FPW-LEG-0006                                  |

---

## 6. Apéndice: Prefetching y batching (referencia arquitectónica)

Para minimizar el clásico **problema N+1** al traducir bucles legacy a SQL:

```
DO WHILE .NOT. EOF()
   ? FIELD->name
   SKIP
ENDDO
```

El runtime mantiene un **buffer de cursor**:

```
OPEN customers       →  SELECT * FROM customers ORDER BY id
                       ↓
                    fetchmany(N) en SQLite →  buffer de N filas
                       ↓
SKIP 1                →  buffer[i++]
SKIP 1                →  buffer[i++]
...
SKIP 1  (N veces)     →  buffer agotado → re-fetchmany(N)
GO TOP                →  buffer invalidado, reset a fetchmany(N)
SEEK expr             →  cursor SQL + WHERE, refill
```

**Default `N = 100`**, configurable por `--rtl-prefetch=256` o `SetPrefetchSize(n)` runtime.

Detalle arquitectónico completo en `docs/PARALLEL-COMPILER-ARCHITECTURE.md` §"Optimización RDD SQL (Prefetching & Batching)".

---

## 7. Resumen de tiers (qué migración se hace)

| Tier | Quién lo necesita                          | Costo de migración |
|------|--------------------------------------------|--------------------|
| T1   | Cualquier codebase xBASE                   | Bajo: renombrar abreviaturas |
| T2   | Apps con DBF                               | Medio: ejecutar `fpx-dbf import` + ajustar sintaxis de PACK/ZAP |
| T3   | Apps con macros `&` pesadas                | Alto: convertir macros a codeblocks |

El usuario elige hasta qué tier migrar. **No hay un toggle "global"**; la mezcla de tiers es soportada por archivo:

```xbase
#pragma legacy(strict=false)   // Tier 1 + Tier 2 sintaxis permisiva
FUNCTION Main()
   USE CUSTOMERS               // Tier 2 OK
   ...
ENDFUNC
```

`#strict` se documenta en `docs/GRAMMAR-FXBASE.md` §"Directivas de Estrictez".
