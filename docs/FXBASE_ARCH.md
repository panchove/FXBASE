# FXBASE — Especificación de Arquitectura (ARCH)

**Versión:** 1.0.0-alpha  
**Fecha:** 2026-08-08  
**Fuente:** Derivado de PRD v1.0.0 y GRAMMAR v1.0.0  

---

## 1. Visión General del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ECOSISTEMA FXBASE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   fxbase     │  │  fxbase      │  │  fxpkg       │  │  LSP Server  │   │
│  │   CLI        │  │  migrate     │  │  (gestor pkg)│  │  (IDE)       │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                 │                 │           │
│         └─────────────────┼─────────────────┼─────────────────┘           │
│                           ▼                 ▼                             │
│                  ┌─────────────────────────────────────┐                 │
│                  │         NÚCLEO COMPILADOR FXBASE    │                 │
│                  ├─────────────────────────────────────┤                 │
│                  │  ┌─────────┐ ┌─────────┐ ┌───────┐  │                 │
│                  │  │ Frontend│ │ Middle  │ │ Backend│  │                 │
│                  │  │         │ │ End     │ │s       │  │                 │
│                  │  └─────────┘ └─────────┘ └───────┘  │                 │
│                  └─────────────────────────────────────┘                 │
│                           │                 │                             │
│         ┌─────────────────┼─────────────────┼─────────────────┐           │
│         ▼                 ▼                 ▼                 ▼           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐         │
│  │   Backend   │ │   Backend   │ │   Backend   │ │   Backend   │         │
│  │     C       │ │    LLVM     │ │    WASM     │ │    VM       │         │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘         │
│         │                 │                 │                 │           │
│         └─────────────────┼─────────────────┼─────────────────┘           │
│                           ▼                 ▼                             │
│                  ┌─────────────────────────────────────┐                 │
│                  │         FXSTD (Biblioteca Estándar) │                 │
│                  │  core │ collections │ io │ db       │                 │
│                  │  net  │ concurrencia │ ui │ crypto  │                 │
│                  │  json │ testing     │                  │                 │
│                  └─────────────────────────────────────┘                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Arquitectura del Pipeline del Compilador

### 2.1 Frontend (Independiente del Lenguaje)

```
Código Fuente (.fx / .prg)
        │
        ▼
┌───────────────────┐
│   Lexer/Scanner   │  ← Escrito a mano (rendimiento) o logos/text_scanner
│   - UTF-8         │
│   - Interpolación │
│   - Palabras clave│
└─────────┬─────────┘
          │ Tokens
          ▼
┌───────────────────┐
│    Parser         │  ← Descenso recursivo (LL(k)) con Pratt para expresiones
│   - Recuperación  │
│     de errores    │
│   - Producción AST│
└─────────┬─────────┘
          │ AST sin tipar
          ▼
┌───────────────────┐
│  Resolvedor       │  ← Resolución de módulos/imports, visibilidad, shadowing
│  de Nombres       │
│  - Grafo módulos  │
│  - Tablas símbolos│
└─────────┬─────────┘
          │ AST resuelto
          ▼
┌───────────────────┐
│  Comprobador      │  ← Hindley-Milner + extensiones (tipado gradual)
│  de Tipos         │
│  - Inferencia     │
│  - Unificación    │
│  - Diagnósticos   │
└─────────┬─────────┘
          │ AST tipado + Tablas de símbolos
          ▼
```

### 2.2 Middle End (Optimización)

```
AST Tipado
    │
    ▼
┌───────────────────┐
│   Lowering FX-IR  │  ← IR basado en SSA (FX-IR)
│   - Desazucarado  │
│   - Conversión    │
│     closures      │
│   - Pattern match │
└─────────┬─────────┘
          │ FX-IR (alto nivel)
          ▼
┌───────────────────┐
│  Optimizador      │  ← Pipeline de pasadas
│  - Plegado ctes   │
│  - Inlining       │
│  - DCE            │
│  - Opt. bucles    │
│  - Análisis escape│
└─────────┬─────────┘
          │ FX-IR optimizado
          ▼
```

### 2.3 Backends (Generación de Código)

```
FX-IR Optimizado
    │
    ├──────────────────┬──────────────────┬──────────────────┬──────────────────┐
    ▼                  ▼                  ▼                  ▼
┌─────────┐      ┌─────────┐        ┌─────────┐        ┌─────────┐
│ Backend │      │ Backend │        │ Backend │        │ Backend │
│    C    │      │  LLVM   │        │  WASM   │        │   VM    │
└────┬────┘      └────┬────┘        └────┬────┘        └────┬────┘
     │                │                  │                  │
     ▼                ▼                  ▼                  ▼
  .c files        .ll/.bc            .wasm +           Bytecode
                 llc/lli              .js glue            (.fxbc)
     │                │                  │                  │
     ▼                ▼                  ▼                  ▼
  gcc/clang       Binarios           Navegador/Node       FXVM
  /MSVC           nativos            (wasm-opt)          Intérprete
                 (opt -O3)
```

---

## 3. Arquitectura del Transpilador (Pipeline de Migración)

```
┌────────────────────────────────────────────────────────────────────────┐
│                    PIPELINE FXBASE MIGRATE                             │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Fuentes Legacy (.prg, .ch, .hbp)                                      │
│          │                                                              │
│          ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Lexer xHarbour     │  ← Reutilizado de xHarbour 1.2.x (GPL compat) │
│  └─────────┬───────────┘                                                │
│            │ Tokens                                                      │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Parser xHarbour    │  → AST xHarbour normalizado                    │
│  └─────────┬───────────┘                                                │
│            │ AST-xHB                                                     │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Analizador         │  • Resolución símbolos (PUBLIC/PRIVATE/LOCAL)  │
│  │  Semántico xHarbour │  • Inferencia heurística tipos (prefijo húngaro)│
│  └─────────┬───────────┘  • Grafo dependencias (#include, REQUEST)      │
│            │            • Detección patrones de riesgo                  │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Transformador      │  • Mapeo AST: xHB-AST → FX-AST                │
│  │  FXBASE             │  • Inyección anotaciones [FX-MIGRATE]         │
│  │                     │  • Agrupación módulos (.prg → .fx módulos)     │
│  │                     │  • Generación imports para REQUEST/#include    │
│  └─────────┬───────────┘                                                │
│            │ AST-FX                                                      │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Emisor Fuente FX   │  • Pretty-print con anotaciones               │
│  └─────────┬───────────┘                                                │
│            │ Archivos .fx                                                │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Generador Reportes │  • Reporte migración Markdown/JSON/HTML       │
│  │                     │  • Matriz riesgos, estimación esfuerzo         │
│  └─────────────────────┘                                                │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
         ┌─────────────────┐
         │ Compilador FX   │  (con flag --legacy)
         │ --legacy        │
         └─────────────────┘
```

### 3.1 Reglas de Detección de Riesgos (Implementadas en Analizador Semántico)

| Código Riesgo | Patrón | Severidad |
|---------------|--------|-----------|
| RIESGO-101 | `&macro` sin firma de tipos | ALTA |
| RIESGO-202 | Variables `PUBLIC`/`PRIVATE` | ALTA |
| RIESGO-303 | Tipado implícito en rutas críticas | MEDIA |
| RIESGO-404 | `SET EXACT OFF` / `SET SOFTSEEK` | MEDIA |

---

## 4. Arquitectura del Runtime

### 4.1 Gestión de Memoria

```
┌─────────────────────────────────────────────────────────────┐
│                    SUBSISTEMA MEMORIA                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           RECOLECTOR BASURA GENERACIONAL            │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │ Nursery │→ │ Young   │→ │ Old     │             │    │
│  │  │ (Eden)  │  │ Gen     │  │ Gen     │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  │        │           │           │                    │    │
│  │        ▼           ▼           ▼                    │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │          BARRERA ESCRITURA (Dijkstra)       │    │    │
│  │  │          + CONJUNTOS RECORDADOS             │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│         ┌────────────────┼────────────────┐                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Stack       │  │ Heap        │  │ UNSAFE      │          │
│  │ (LOCAL,     │  │ (OBJECT,    │  │ blocks      │          │
│  │  params)    │  │  ARRAY,     │  │ (interop C) │          │
│  │             │  │  HASH,      │  │             │          │
│  │             │  │  CHANNEL)   │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Configuración GC:**
- Nursery: 4MB (configurable)
- Young gen: 16MB
- Old gen: crece hasta límite heap
- Barrera escritura: card marking (tarjetas 512 bytes)
- Disparadores colección: nursery lleno, tasa asignación, `GC()` explícito

### 4.2 Runtime de Concurrencia (CSP + Actores)

```
┌─────────────────────────────────────────────────────────────┐
│                  RUNTIME CONCURRENCIA                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              PLANIFICADOR TAREAS (Work-stealing)    │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │    │
│  │  │Worker 0 │ │Worker 1 │ │Worker 2 │ │Worker N │   │    │
│  │  │ (P-thread)          ...        (P-thread)      │    │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │    │
│  │       │           │           │           │          │    │
│  │       └───────────┼───────────┼───────────┘          │    │
│  │                   ▼           ▼                      │    │
│  │            ┌─────────────────────┐                   │    │
│  │            │   COLA GLOBAL       │                   │    │
│  │            │   (MPSC sin locks)  │                   │    │
│  │            └─────────────────────┘                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│         ┌────────────────┼────────────────┐                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  CANALES    │  │   SELECT    │  │   TAREAS    │          │
│  │  (MPSC,     │  │  (Park/     │  │  (Hilos     │          │
│  │   buffer,   │  │   unpark)   │  │   verdes)   │          │
│  │   sin buff) │  │             │  │  + futures  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                              │
│  Garantías:                                                │
│  • Sin estado mutable compartido entre tareas              │
│  • Ops canales atómicas + ordenadas                        │
│  • Capturas léxicas copiadas (no compartidas)              │
│  • Stack crece bajo demanda (mín 8KB)                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 Abstracción Base de Datos (RDD 2.0)

```
┌─────────────────────────────────────────────────────────────┐
│                      CAPA RDD 2.0                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Código FXBASE                                               │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              INTERFAZ RDD (Traits)                   │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐  │    │
│  │  │ Conectar │ │ Consultar│ │ Ejecutar │ │ Cursor │  │    │
│  │  │ Begin/   │ │ (SELECT, │ │ (INSERT, │ │ (Nave- │  │    │
│  │  │ Commit/  │ │  INSERT, │ │  UPDATE, │ │  gate, │  │    │
│  │  │ Rollback)│ │  UPDATE) │ │  DELETE) │ │  Seek) │  │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                    │                    │            │
│       ▼                    ▼                    ▼            │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐        │
│  │ PGSQL   │         │ SQLite  │         │ MySQL   │  ...   │
│  │ Driver  │         │ Driver  │         │ Driver  │        │
│  │(libpq)  │         │ (C API) │         │ (C API) │        │
│  └─────────┘         └─────────┘         └─────────┘        │
│                                                              │
│  Capa Traducción:                                           │
│  • LOCATE/SEEK        →  SELECT parametrizado ... LIMIT 1    │
│  • REPLACE ALL        →  UPDATE ... WHERE                   │
│  • SUM/AVERAGE/COUNT  →  SELECT AGG(...)                    │
│  • SET RELATION       →  JOIN o consultas N+1 (configurable)│
│  • Cache prepared statements (por conexión)                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Arquitectura Biblioteca Estándar (FXSTD)

```
fxstd/
├── core/
│   ├── types.fx          # Result, Optional, Channel, Variant
│   ├── errors.fx         # FXException, FileNotFoundError, etc.
│   ├── memory.fx         # Hints GC, bloques UNSAFE, POINTER
│   └── prelude.fx        # Tipos core auto-importados
│
├── collections/
│   ├── array.fx          # ARRAY<T>: push, pop, map, filter, reduce, sort
│   ├── hash.fx           # HASH<K,V>: get, set, remove, keys, values
│   ├── set.fx            # SET<T>: unión, intersección, diferencia
│   ├── list.fx           # Lista enlazada (persistente)
│   └── iterator.fx       # Trait ITERATOR<T>, para FOREACH
│
├── io/
│   ├── file.fx           # File, Path, OpenOptions, metadata
│   ├── path.fx           # Manipulación paths (multiplataforma)
│   ├── stream.fx         # Read, Write, Seek, BufReader, BufWriter
│   └── console.fx        # STDIN/STDOUT/STDERR, color, progreso
│
├── db/
│   ├── connection.fx     # Connection, Pool, Transaction
│   ├── rdd.fx            # Trait RDD + impl default
│   ├── rdd_pgsql.fx      # Driver PostgreSQL (libpq)
│   ├── rdd_sqlite.fx     # Driver SQLite (incluido)
│   ├── rdd_mysql.fx      # Driver MySQL/MariaDB
│   ├── rdd_dbf.fx        # Legacy DBF/CDX/NTX (solo --legacy)
│   └── migrate.fx        # Migraciones esquema
│
├── net/
│   ├── http.fx           # Cliente (async), Servidor, Router, Middleware
│   ├── tcp.fx            # TcpListener, TcpStream, TLS
│   ├── websocket.fx      # WS cliente/servidor
│   └── dns.fx            # Resolución async
│
├── concurrencia/
│   ├── task.fx           # SPAWN, AWAIT, WAIT, Task<T>, JoinHandle
│   ├── channel.fx        # CHANNEL<T>, send, recv, try_send, try_recv
│   ├── select.fx         # Macro SELECT, select! {}
│   ├── sync.fx           # Mutex, RwLock, Condvar, Once, Barrera
│   └── time.fx           # Sleep, timeout, interval, Instant, Duration
│
├── ui/
│   ├── form.fx           # FORM, GET, READ 2.0 (declarativo)
│   ├── dialog.fx         # MessageBox, FileDialog, ProgressDialog
│   ├── widgets.fx        # Button, Label, Edit, ComboBox, Grid, Tree
│   ├── layout.fx         # Flex, Grid, Stack, Anchor layouts
│   ├── binding.fx        # Binding Modelo-Vista, validación
│   └── backends/
│       ├── tui.fx        # Terminal UI (crossterm/ratatui)
│       ├── desktop.fx    # Bindings Qt6 / GTK4
│       └── web.fx        # WASM + DOM (web-sys)
│
├── crypto/
│   ├── hash.fx           # SHA2, SHA3, BLAKE3, HMAC
│   ├── cipher.fx         # AES-GCM, ChaCha20-Poly1305, X25519
│   ├── kdf.fx            # Argon2, PBKDF2, HKDF
│   └── random.fx         # CSPRNG, tokens seguros
│
├── json/
│   └── json.fx           # Parser JSON, serializador, JSONPath, patch
│
├── testing/
│   ├── assert.fx         # ASSERT, ASSERT_EQ, ASSERT_THROWS
│   ├── runner.fx         # Descubrimiento tests, ejecución paralela, cobertura
│   ├── mock.fx           # Framework mocking
│   └── property.fx       # Property-based testing (estilo QuickCheck)
│
└── text/
    ├── regex.fx          # Regex compatible PCRE2
    ├── format.fx         # printf-style, string templates
    └── encoding.fx       # UTF-8/16/32, Latin1, Base64, Hex
```

---

## 6. Arquitectura de Herramientas

### 6.1 CLI (`fxbase`)

```
fxbase
├── build          # Compilar proyecto (debug/release)
├── run            # Build + ejecutar
├── test           # Ejecutar tests (--coverage, --bench)
├── fmt            # Formatear fuente (opinionado, como gofmt)
├── doc            # Generar docs desde comentarios /// (HTML/MD)
├── migrate        # Transpilar xHarbour → FXBASE
├── new            # Scaffold proyecto (lib/bin)
├── add            # Añadir dependencia (fxpkg)
├── update         # Actualizar dependencias
├── publish        # Publicar paquete en registro
├── repl           # REPL interactivo
├── check          # Solo type-check (sin codegen)
├── lint           # Lint + checks estilo
└── doctor         # Diagnósticos entorno
```

### 6.2 Gestor Paquetes (`fxpkg`)

```
┌─────────────────────────────────────────────────────────────┐
│                      ARQUITECTURA fxpkg                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  fxpkg.toml (manifiesto)                                     │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              RESOLVEDOR (PubGrub)                    │    │
│  │  • Resolución SemVer                                 │    │
│  │  • Unificación features                              │    │
│  │  • Detección conflictos                              │    │
│  │  • Generación lockfile (fxpkg.lock)                  │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              FETCHER                                 │    │
│  │  • API registro (estilo crates.io)                  │    │
│  │  • Dependencias git (rev/tag/rama)                  │    │
│  │  • Dependencias path                                 │    │
│  │  • Cache direccionable por contenido (~/.fxpkg/cache)│    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              ORQUESTADOR BUILD                       │    │
│  │  • Orden build topológico                           │    │
│  │  • Compilación paralela                             │    │
│  │  • Builds incrementales (cache fxbc)                │    │
│  │  • Soporte cross-compilation                        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 Servidor de Lenguaje (LSP)

```
┌─────────────────────────────────────────────────────────────┐
│                      SERVIDOR LSP                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Editor (VS Code, Vim, Emacs)                               │
│       │ JSON-RPC 2.0                                        │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              MANEJADORES LSP                         │    │
│  │  • initialize / shutdown / exit                     │    │
│  │  • textDocument/didOpen / didChange / didClose      │    │
│  │  • textDocument/completion                          │    │
│  │  • textDocument/hover                               │    │
│  │  • textDocument/definition                          │    │
│  │  • textDocument/references                          │    │
│  │  • textDocument/rename                              │    │
│  │  • textDocument/formatting                          │    │
│  │  • textDocument/codeAction                          │    │
│  │  • textDocument/diagnostic (push)                   │    │
│  │  • workspace/symbol                                 │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           FRONTEND COMPILADOR INCREMENTAL            │    │
│  │  • AST persistente + Tablas símbolos                │    │
│  │  • Re-type-check incremental ante cambios           │    │
│  │  • Motor consultas estilo Salsa/Redex               │    │
│  │  • Soporte cancelación                              │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Aspectos Transversales

### 7.1 Estrategia Manejo Errores

| Capa | Mecanismo | Ejemplo |
|------|-----------|---------|
| Lexer | Tokens error + recuperación | Char inválido → `ERROR_TOKEN`, continuar |
| Parser | Modo pánico + puntos sincronización | Falta `END` → sincronizar en `FUNCTION`/`CLASS`/`END` |
| Type Checker | Diagnósticos acumulados | Todos errores tipo en una pasada |
| Codegen | Trap unreachable | `unreachable!()` en brazos match |
| Runtime | `RESULT<T,E>` + excepciones | Errores dominio = Result; Pánicos = bugs |
| FFI | Bloques `UNSAFE` + contratos | Llamadas C validadas en frontera |

### 7.2 Formato Diagnósticos

```json
{
  "code": "E0308",
  "level": "error",
  "message": "tipos incompatibles",
  "spans": [
    {
      "file": "src/main.fx",
      "start": {"line": 42, "column": 15},
      "end": {"line": 42, "column": 25},
      "label": "se esperaba `INT`, se encontró `STRING`"
    }
  ],
  "notes": [
    "help: añadir conversión explícita: `AS INT`",
    "note: este error origina en macro `$crate::format_args`"
  ],
  "suggestions": [
    {"action": "replace", "span": "...", "text": "AS INT"}
  ]
}
```

### 7.3 Compilación Incremental

```
┌─────────────────────────────────────────────────────────────┐
│                 GRAFO BUILD INCREMENTAL                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Cambio Fuente (.fx)                                         │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              MOTOR CONSULTAS (estilo Salsa)          │    │
│  │  Entradas:  Contenido archivos, config, deps         │    │
│  │  Consultas:                                          │    │
│  │    parse(file) → AST                                 │    │
│  │    type_check(ast) → TypedAST + Diagnostics         │    │
│  │    codegen(typed_ast, backend) → Artefacto          │    │
│  │    link(artefactos) → Binario                        │    │
│  │  Invalidación: basada en hash, granularidad fina    │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  Solo consultas afectadas se re-ejecutan                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 7.4 Modelo de Seguridad

```
┌─────────────────────────────────────────────────────────────┐
│                      CAPAS SEGURIDAD                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. NIVEL LENGUAJE                                           │
│     • Seguridad memoria (sin punteros crudos en código seguro)│
│     • Seguridad nulos (modo estricto: `T?` para nullable)   │
│     • Sin coerciones implícitas peligrosas                  │
│     • Sandbox macros (solo `COMPILE<>`)                     │
│     • Prevención inyección SQL (prepared statements)        │
│     • Seguridad transpilador: código generado no introduce  │
│       vulnerabilidades nuevas (ej: no convertir macros      │
│       inseguras en `EVAL` sin sandbox)                      │
│                                                              │
│  2. NIVEL RUNTIME                                            │
│     • FFI basado en capacidades (bloques UNSAFE explícitos) │
│     • Propiedad canales (tipos lineales para endpoints)     │
│     • Límites recursos (stack, heap, file handles)          │
│     • Sandbox WASM (si target navegador)                    │
│                                                              │
│  3. CADENA SUMINISTRO                                        │
│     • Paquetes firmados (fxpkg verify)                      │
│     • Integridad lockfile (SHA256)                          │
│     • Builds reproducibles                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Arquitecturas Despliegue

### 8.1 Binario Nativo (Default)

```
fxbase build --release
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  Binario único estáticamente linkeado (o dinámico glibc)    │
│  • Sin dependencia runtime                                  │
│  • < 50ms arranque                                          │
│  • Optimizado via LLVM -O3 + LTO                            │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 WebAssembly

```
fxbase build --target wasm32-unknown-unknown
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  .wasm + .js glue                                           │
│  • fxstd/net/http → fetch API                               │
│  • fxstd/ui/web → bindings DOM                              │
│  • fxstd/concurrencia → Web Workers + MessageChannel        │
│  • fxstd/db → IndexedDB / WebSQL (SQLite WASM)              │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Scripting / REPL (FXVM)

```
fxbase run script.fx          # Interpretado (bytecode)
fxbase repl                   # Interactivo
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  FXVM Máquina virtual stack-based                           │
│  • Hot-reload ante cambio archivo                           │
│  • JIT tier (futuro)                                        │
│  • Mismo GC que nativo                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Estructura Proyecto (Layout Referencia)

```
fxbase-proyecto/
├── fxpkg.toml              # Manifiesto paquete
├── fxpkg.lock              # Dependencias bloqueadas
├── .fxbase/                # Cache build, datos incrementales
├── src/
│   ├── main.fx             # Entry binario (fn main())
│   ├── lib.fx              # Raíz librería (MODULE nombre)
│   ├── **/*.fx             # Módulos fuente
│   └── **/*.fx.h           # Headers C generados (para FFI)
├── tests/
│   ├── integration/        # Tests integración
│   ├── unit/               # Tests unitarios (co-localizados o aquí)
│   └── fixtures/           # Datos test
├── examples/               # Binarios ejemplo
├── benches/                # Benchmarks
├── scripts/                # Scripts build/migración
├── docs/                   # Documentación fuente
├── fxstd/                  # Overrides std locales (raro)
└── target/                 # Artefactos build (gitignored)
    ├── debug/
    ├── release/
    ├── wasm/
    └── fxbc/               # Cache bytecode
```

---

## 10. Puntos Integración

| Sistema | Interfaz | Dirección |
|---------|----------|-----------|
| Librerías C | FFI (`UNSAFE` + `extern "C"`) | Bidireccional |
| APIs SO | `fxstd::os` (específicas plataforma) | Salida |
| Bases datos | RDD 2.0 trait + drivers | Salida |
| Message Brokers | `fxstd::net` (Redis, RabbitMQ, Kafka) | Salida |
| Monitorización | `fxstd::telemetry` (OpenTelemetry) | Salida |
| IDEs | LSP (JSON-RPC 2.0) | Bidireccional |
| CI/CD | `fxbase` CLI códigos salida + JSON | Salida |
| Registro Paquetes | `fxpkg` API HTTP (compat crates.io) | Bidireccional |

---

## 11. Puntos Extensión Futuros

1. **Sistema Plugins** - Plugins compilador para atributos/lints personalizados
2. **Múltiples Frontends** - Transpiladores TypeScript→FXBASE, Python→FXBASE
3. **Compilación Distribuida** - Build farms via gRPC
4. **IDE Cloud** - Compilador compilado a WASM ejecutándose en navegador
5. **Migración Asistida IA** - LLM para sugerencias resolución riesgos
6. **Hot Reload** - Swap código runtime para servicios larga duración
7. **GPU Compute** - `fxstd::gpu` (WGPU/CUDA) backend

---

## 12. Matriz Compatibilidad Versiones

| Versión FXBASE | Spec Gramática | API FXSTD | Registro fxpkg | Protocolo LSP |
|----------------|----------------|-----------|----------------|---------------|
| 1.0.x          | 1.0            | 1.0       | v1             | 3.17          |
| 1.1.x          | 1.0+           | 1.1 (compat) | v1           | 3.17+         |
| 2.0.x          | 2.0            | 2.0       | v2             | 3.18+         |

**Política:** SemVer para lenguaje + stdlib. Cambios gramática = versión mayor.

---

*Fin Especificación ARCH*