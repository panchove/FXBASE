# FXBASE Roadmap

**Norma de Referencia:** ISO/IEC/IEEE 29148:2018 / ISO/IEC 12207:2017

**Actualizado:** 2026-07-30
**Versión:** 1.0  
**Trazabilidad ID:** REQ-RDM-001  
**Auditoría:** Control de Versiones y Hitos  

---

## Fase 0 — Parser + Lexer + AST (basic subset) — 3 meses

| Subfase | Hito                     | Entregable                                                                                                      |
|---------|--------------------------|-----------------------------------------------------------------------------------------------------------------|
| 0.1     | DFA Lexer                | Tokens completos: identificadores, literales, palabras reservadas, operadores, comentarios, directivas `#`      |
| 0.2     | Recursive Descent Parser | Parsing de expresiones, statements, funciones, procedimientos, clases, structs                                  |
| 0.3     | AST construction         | Árbol sintáctico tipado con `DataType`, `FormalParam`, `GenericParam`, etc.                                     |
| 0.4     | Preprocessor             | `#command`/`#translate`/`#xcommand`/`#xtranslate`, `#define`/`#undef`, `#ifdef`/`#ifndef`, `#include`, `#error` |
| 0.5     | Grammar features         | Genéricos, `STRUCT`, `NEWTYPE`, smart pointers, `CAST`, `YIELD`, variádicos, kwargs, closures multi-statement   |
| 0.6     | Error reporting          | Códigos FPX-nnnn, FPW-nnnn, directivas `#line`                                                                  |

**Verificación:** Test suite con 100+ snippets xBASE + 50+ extensiones FXBASE.

---

## Fase 0.5 — Arquitectura de Compilación Paralela y Caché Incremental — 1.5 meses

| Subfase | Hito                                  | Entregable                                                                                                                               |
|---------|---------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| 0.5.1   | Pool de workers + job queue           | `TThreadPool` configurable (`--jobs N`), detección automática de núcleos                                                                 |
| 0.5.2   | Preprocesamiento paralelo por archivo | Cada `.prg`/`.fpg` se preprocesa en hilo independiente; generación de `.ppo`                                                             |
| 0.5.3   | Caché incremental (copy-on-write)     | `.ppo`, `.ast`, `.ir`, `.o` cacheados por hash de contenido + mtime; invalidación por dependencias `#include`                            |
| 0.5.4   | Tabla de símbolos global en 2 pasadas | Pase 0 secuencial: recolectar símbolos exportados (funciones, clases, PUBLIC). Pase 1 paralelo: resolver contra tabla global (read-only) |
| 0.5.5   | LTO diferido y codegen paralelo       | Backend nativo genera `.o` por unidad; link final en hilo principal                                                                      |

**Verificación:** Compilación limpia (100 archivos, 10k LOC) < 2s en 8 cores; incremental (1 archivo) < 150ms.

---

## Fase 1 — IR + Optimizer + Native Backend — 4 meses

| Subfase | Hito                   | Entregable                                          |
|---------|------------------------|-----------------------------------------------------|
| 1.1     | IR tree/DAG            | Representación intermedia en memoria (tipada)       |
| 1.2     | Constant folding + DCE | Plegado de constantes, eliminación de código muerto |
| 1.3     | x86 asm generation     | Generación de código nativo x86 (32-bit)            |
| 1.4     | x86_64 asm generation  | Generación de código nativo x86-64 (64-bit)         |
| 1.5     | PE/COFF output         | Windows: EXE, DLL, LIB                              |
| 1.6     | ELF output             | Linux: EXE, SO, A                                   |
| 1.7     | Entry point resolution | `#entry`, `Main`, legacy `PROCEDURE` order          |
| 1.8     | CLI args               | `ArgC()`, `ArgV(n)`, `Command()`, `Main(...params)` |
| 1.9     | Optimization levels    | `-O0` a `-O3`, profile-guided hints                 |

**Verificación:** Compilar y ejecutar Hola Mundo, Fibonacci, CRUD básico en Win/Linux 32/64.

---

## Fase 2 — SQLite Runtime Driver — 2 meses

| Subfase | Hito                        | Entregable                                                                         |
|---------|-----------------------------|------------------------------------------------------------------------------------|
| 2.1     | SQLite native wrapper       | API directa desde Free Pascal (sin C API)                                          |
| 2.2     | Compile-time DB translation | `USE` → `CREATE TABLE`/`SELECT`, `INDEX` → `CREATE INDEX`, `SET RELATION` → `JOIN` |
| 2.3     | DML translation             | `REPLACE` → `UPDATE`, `APPEND` → `INSERT`, `PACK` → `DELETE`, `ZAP` → `TRUNCATE`   |
| 2.4     | Scope/For/While clauses     | `ALL`, `REST`, `NEXT n`, `FOR cond`, `WHILE cond` traducidos a WHERE               |
| 2.5     | `CURSOR` / `RECORDSET`      | Tipo nativo para resultados SQL, compatible con SKIP/GO/SEEK                       |
| 2.6     | Embedded SQL                | `EXECUTE SQL` / `PREPARE` / `DECLARE CURSOR`                                       |
| 2.7     | `--db:sqlite` flag          | Connection string, auto-create tables                                              |

**Verificación:** Migrar base .dBF de prueba (5 tablas, 10k registros) a SQLite, ejecutar queries legacy.

---

## Fase 3 — PostgreSQL + MSSQL Drivers — 2 meses

| Subfase | Hito                      | Entregable                                                    |
|---------|---------------------------|---------------------------------------------------------------|
| 3.1     | PostgreSQL native wrapper | Conexión, queries, prepared statements, transactions          |
| 3.2     | MSSQL native wrapper      | Conexión, queries, prepared statements, transactions          |
| 3.3     | Connection config         | `--db:postgresql` / `--db:mssql`, connection strings, pooling |
| 3.4     | Type mapping              | xBASE ↔ SQL types para cada driver                            |
| 3.5     | Multi-DB `USE`            | Sintaxis `DB:identifier` para cambiar entre bases activas     |

**Verificación:** Misma suite de Fase 2 corriendo contra PG y MSSQL.

---

## Fase 4 — Tooling — 3 meses

| Subfase | Hito              | Entregable                                                                       |
|---------|-------------------|----------------------------------------------------------------------------------|
| 4.1     | `fx` CLI full    | `build`, `run`, `test`, `--target`, `--entry`, `--gc`, `-O`, `-D`                |
| 4.2     | `fx-lsp`         | Language Server Protocol: diagnostics, completions, hover, go-to-def, references |
| 4.3     | `fx-fmt`         | Formateador con reglas configurables (indent, spacing, case)                     |
| 4.4     | `fx-pkg`         | Package manager: `install`, `uninstall`, `update`, `list`                        |
| 4.5     | `fx-dap`         | Debug Adapter Protocol: breakpoints, watches, step, call stack                   |
| 4.6     | Cross-compilation | `--target win32/win64/linux32/linux64`, sysroot management                       |

**Verificación:** Editor LSP integration (VS Code), debug session, package publish/install cycle.

---

## Fase 5 — Legacy Mode, DBF Import/Export, Docs — 2 meses

| Subfase | Hito                            | Entregable                                                      |
|---------|---------------------------------|-----------------------------------------------------------------|
| 5.1     | `fx-dbf` tool                  | Import DBF (dBASE III/IV, FoxPro 2.x) + memo + NTX/CDX → SQL    |
| 5.2     | Export SQL → DBF                | Round-trip sin pérdida de tipos                                 |
| 5.3     | `--legacy` mode                 | Aceptar 100% sintaxis Clipper/Harbour con warnings FPW          |
| 5.4     | Legacy PARAMETERS/PCount/PValue | Soporte para entry point legacy                                 |
| 5.5     | Documentation                   | PRD final, grammar reference, migration guide                   |
| 5.6     | Packaging                       | MSI (Windows), AppImage/DEB (Linux), zip bundles                |
| 5.7     | Std library (`std.fph`)         | All built-in commands, network, crypto, OS, tasks, serial, etc. |
| 5.8     | Licensing                       | MIT license file, contribution guide                            |

**Verificación:** Migrar proyecto Harbour real (10k+ LOC) a FXBASE sin cambios manuales.

---

## Fase 6 — Testing Integrado y Profiling — 1.5 meses

| Subfase | Hito                      | Entregable                                                                 |
|---------|---------------------------|----------------------------------------------------------------------------|
| 6.1     | `TestSuite` / `TestCase`  | Framework de testing integrado (assertions, setup/teardown, fixtures)      |
| 6.2     | `fx test` CLI            | Descubrimiento automático, filtrado, reporter JUnit/TAP, coverage básico   |
| 6.3     | Profiling integrado       | `--profile` genera `.prof`; `fx-prof` viewer (flamegraph, call counts)    |
| 6.4     | Benchmarks de rendimiento | Suite de microbenchmarks (parser, codegen, DB roundtrip) con CI regression |

**Verificación:** `fx test` pasa suite completa; profiling muestra hotspots esperados.

---

## Post-Fase 6 (Futuro)

| Feature            | Descripción                               |
|--------------------|-------------------------------------------|
| Generational GC    | `--gc:generational` con compactación      |
| JIT mode           | Compilación JIT para desarrollo iterativo |
| WebAssembly target | `--target wasm32`                         |
| Android/iOS        | Targets móviles                           |
| GUI framework      | Bindings nativos o integración Qt/GTK     |
