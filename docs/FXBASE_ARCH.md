# FXBASE — Architecture Specification (ARCH)

**Version:** 1.0.0-alpha  
**Date:** 2026-08-08  
**Source:** Derived from PRD v1.0.0 and GRAMMAR v1.0.0  

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FXBASE ECOSYSTEM                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   fxbase     │  │  fxbase      │  │  fxpkg       │  │  LSP Server  │   │
│  │   CLI        │  │  migrate     │  │  (pkg mgr)   │  │  (IDE)       │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                 │                 │           │
│         └─────────────────┼─────────────────┼─────────────────┘           │
│                           ▼                 ▼                             │
│                  ┌─────────────────────────────────────┐                 │
│                  │        FXBASE COMPILER CORE         │                 │
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
│                  │         FXSTD (Std Library)         │                 │
│                  │  core │ collections │ io │ db       │                 │
│                  │  net  │ concurrency │ ui │ crypto   │                 │
│                  │  json │ testing     │                  │                 │
│                  └─────────────────────────────────────┘                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Compiler Pipeline Architecture

### 2.1 Frontend (Language-Agnostic)

```
Source Code (.fx / .prg)
        │
        ▼
┌───────────────────┐
│   Lexer/Scanner   │  ← Hand-written (performance) or logos/text_scanner
│   - UTF-8         │
│   - Interpolation │
│   - Keywords      │
└─────────┬─────────┘
          │ Tokens
          ▼
┌───────────────────┐
│    Parser         │  ← Recursive Descent (LL(k)) with Pratt for expressions
│   - Error recovery│
│   - AST production│
└─────────┬─────────┘
          │ Untyped AST
          ▼
┌───────────────────┐
│  Name Resolver    │  ← Module/Import resolution, visibility, shadowing
│  - Module graph   │
│  - Symbol tables  │
└─────────┬─────────┘
          │ Resolved AST
          ▼
┌───────────────────┐
│  Type Checker     │  ← Hindley-Milner + extensions (gradual typing)
│  - Inference      │
│  - Unification    │
│  - Diagnostics    │
└─────────┬─────────┘
          │ Typed AST + Symbol Tables
          ▼
```

### 2.2 Middle End (Optimization)

```
Typed AST
    │
    ▼
┌───────────────────┐
│   FX-IR Lowering  │  ← SSA-based IR (FX-IR)
│   - Desugaring    │
│   - Closure conv. │
│   - Pattern match │
└─────────┬─────────┘
          │ FX-IR (High-level)
          ▼
┌───────────────────┐
│  Optimizer        │  ← Pass pipeline
│  - Const folding  │
│  - Inlining       │
│  - DCE            │
│  - Loop opts      │
│  - Escape analysis│
└─────────┬─────────┘
          │ Optimized FX-IR
          ▼
```

### 2.3 Backends (Code Generation)

```
Optimized FX-IR
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
  gcc/clang       Native bin         Browser/Node       FXVM
  /MSVC           (opt -O3)          (wasm-opt)         Interpreter
```

---

## 3. Transpilator Architecture (Migration Pipeline)

```
┌────────────────────────────────────────────────────────────────────────┐
│                    FXBASE MIGRATE PIPELINE                             │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Legacy Sources (.prg, .ch, .hbp)                                      │
│          │                                                              │
│          ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  xHarbour Lexer     │  ← Reused from xHarbour 1.2.x (GPL compat)    │
│  └─────────┬───────────┘                                                │
│            │ Tokens                                                      │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  xHarbour Parser    │  → Normalized xHarbour AST                    │
│  └─────────┬───────────┘                                                │
│            │ xHB-AST                                                     │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Semantic Analyzer  │  • Symbol resolution (PUBLIC/PRIVATE/LOCAL)   │
│  │  (xHarbour)         │  • Heuristic type inference (Hungarian prefix)│
│  └─────────┬───────────┘  • Dependency graph (#include, REQUEST)       │
│            │            • Risk pattern detection                        │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  FXBASE Transformer │  • AST mapping: xHB-AST → FX-AST             │
│  │                     │  • [FX-MIGRATE] annotation injection          │
│  │                     │  • Module grouping (.prg → .fx modules)       │
│  │                     │  • Import generation for REQUEST/#include     │
│  └─────────┬───────────┘                                                │
│            │ FX-AST                                                      │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  FX Source Emitter  │  • Pretty-print with annotations              │
│  └─────────┬───────────┘                                                │
│            │ .fx files                                                   │
│            ▼                                                              │
│  ┌─────────────────────┐                                                │
│  │  Report Generator   │  • Markdown/JSON/HTML migration report        │
│  │                     │  • Risk matrix, effort estimation             │
│  └─────────────────────┘                                                │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
         ┌─────────────────┐
         │ FX Compiler     │  (with --legacy flag)
         │ --legacy        │
         └─────────────────┘
```

### 3.1 Risk Detection Rules (Implemented in Semantic Analyzer)

| Risk Code | Pattern | Severity |
|-----------|---------|----------|
| RIESGO-101 | `&macro` without type signature | HIGH |
| RIESGO-102 | `PUBLIC`/`PRIVATE` variables | HIGH |
| RIESGO-201 | Implicit typing in critical paths | MEDIUM |
| RIESGO-202 | `SET EXACT OFF` / `SET SOFTSEEK` | MEDIUM |
| RIESGO-301 | Raw `POINTER` manipulation | HIGH |
| RIESGO-302 | Untyped `CodeBlock` capture | LOW |
| RIESGO-401 | Circular `#include` | MEDIUM |
| RIESGO-402 | Unresolved `REQUEST` function | HIGH |

---

## 4. Runtime Architecture

### 4.1 Memory Management

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY SUBSYSTEM                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           GENERATIONAL GARBAGE COLLECTOR            │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │
│  │  │ Nursery │→ │ Young   │→ │ Old     │             │    │
│  │  │ (Eden)  │  │ Gen     │  │ Gen     │             │    │
│  │  └─────────┘  └─────────┘  └─────────┘             │    │
│  │        │           │           │                    │    │
│  │        ▼           ▼           ▼                    │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │          WRITE BARRIER (Dijkstra)           │    │    │
│  │  │          + REMEMBERED SETS                  │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│         ┌────────────────┼────────────────┐                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Stack       │  │ Heap        │  │ UNSAFE      │          │
│  │ (LOCAL,     │  │ (OBJECT,    │  │ blocks      │          │
│  │  params)    │  │  ARRAY,     │  │ (C interop) │          │
│  │             │  │  HASH,      │  │             │          │
│  │             │  │  CHANNEL)   │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**GC Configuration:**
- Nursery: 4MB (configurable)
- Young gen: 16MB
- Old gen: grows to heap limit
- Write barrier: card marking (512-byte cards)
- Collection triggers: nursery full, allocation rate, explicit `GC()`

### 4.2 Concurrency Runtime (CSP + Actors)

```
┌─────────────────────────────────────────────────────────────┐
│                  CONCURRENCY RUNTIME                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              TASK SCHEDULER (Work-stealing)         │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │    │
│  │  │Worker 0 │ │Worker 1 │ │Worker 2 │ │Worker N │   │    │
│  │  │ (P-thread)          ...        (P-thread)      │    │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │    │
│  │       │           │           │           │          │    │
│  │       └───────────┼───────────┼───────────┘          │    │
│  │                   ▼           ▼                      │    │
│  │            ┌─────────────────────┐                   │    │
│  │            │   GLOBAL QUEUE      │                   │    │
│  │            │   (Lock-free MPSC)  │                   │    │
│  │            └─────────────────────┘                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                    │
│         ┌────────────────┼────────────────┐                  │
│         ▼                ▼                ▼                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  CHANNELS   │  │   SELECT    │  │   TASKS     │          │
│  │  (MPSC,     │  │  (Park/     │  │  (Green     │          │
│  │   buffered, │  │   unpark)   │  │   threads)  │          │
│  │   unbuffered)            │  │  + futures  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                              │
│  Guarantees:                                                │
│  • No shared mutable state between tasks                    │
│  • Channel ops are atomic + ordered                         │
│  • Lexical captures copied (not shared)                     │
│  • Stack grows on demand (min 8KB)                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 Database Abstraction (RDD 2.0)

```
┌─────────────────────────────────────────────────────────────┐
│                      RDD 2.0 LAYER                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  FXBASE Code                                                 │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              RDD INTERFACE (Traits)                  │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐  │    │
│  │  │ Connect  │ │ Query    │ │ Execute  │ │ Cursor │  │    │
│  │  │ Begin/   │ │ (SELECT, │ │ (INSERT, │ │ (Navi- │  │    │
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
│  Translation Layer:                                          │
│  • LOCATE/SEEK        →  Parameterized SELECT ... LIMIT 1    │
│  • REPLACE ALL        →  UPDATE ... WHERE                   │
│  • SUM/AVERAGE/COUNT  →  SELECT AGG(...)                    │
│  • SET RELATION       →  JOIN or N+1 queries (configurable) │
│  • Prepared statement cache (per connection)                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Standard Library (FXSTD) Architecture

```
fxstd/
├── core/
│   ├── types.fx          # Result<T,E>, Optional<T>, Channel<T>, Variant
│   ├── errors.fx         # FXException hierarchy, error codes
│   ├── memory.fx         # GC hints, UNSAFE blocks, POINTER
│   └── prelude.fx        # Auto-imported core types
│
├── collections/
│   ├── array.fx          # ARRAY<T>: push, pop, map, filter, reduce, sort
│   ├── hash.fx           # HASH<K,V>: get, set, remove, keys, values
│   ├── set.fx            # SET<T>: union, intersection, difference
│   ├── list.fx           # Linked list (persistent)
│   └── iterator.fx       # ITERATOR<T> trait, for FOREACH
│
├── io/
│   ├── file.fx           # File, Path, OpenOptions, metadata
│   ├── path.fx           # Path manipulation (cross-platform)
│   ├── stream.fx         # Read, Write, Seek, BufReader, BufWriter
│   └── console.fx        # STDIN/STDOUT/STDERR, color, progress
│
├── db/
│   ├── connection.fx     # Connection, Pool, Transaction
│   ├── rdd.fx            # RDD trait + default impl
│   ├── rdd_pgsql.fx      # PostgreSQL driver (libpq)
│   ├── rdd_sqlite.fx     # SQLite driver (bundled)
│   ├── rdd_mysql.fx      # MySQL/MariaDB driver
│   ├── rdd_dbf.fx        # Legacy DBF/CDX/NTX (--legacy only)
│   └── migrate.fx        # Schema migrations
│
├── net/
│   ├── http.fx           # Client (async), Server, Router, Middleware
│   ├── tcp.fx            # TcpListener, TcpStream, TLS
│   ├── websocket.fx      # WS client/server
│   └── dns.fx            # Async resolution
│
├── concurrency/
│   ├── task.fx           # SPAWN, AWAIT, WAIT, Task<T>, JoinHandle
│   ├── channel.fx        # CHANNEL<T>, send, recv, try_send, try_recv
│   ├── select.fx         # SELECT macro, select! {}
│   ├── sync.fx           # Mutex, RwLock, Condvar, Once, Barrier
│   └── time.fx           # Sleep, timeout, interval, Instant, Duration
│
├── ui/
│   ├── form.fx           # FORM, GET, READ 2.0 (declarative)
│   ├── dialog.fx         # MessageBox, FileDialog, ProgressDialog
│   ├── widgets.fx        # Button, Label, Edit, ComboBox, Grid, Tree
│   ├── layout.fx         # Flex, Grid, Stack, Anchor layouts
│   ├── binding.fx        # Model-View binding, validation
│   └── backends/
│       ├── tui.fx        # Terminal UI (crossterm/ratatui)
│       ├── desktop.fx    # Qt6 / GTK4 bindings
│       └── web.fx        # WASM + DOM (web-sys)
│
├── crypto/
│   ├── hash.fx           # SHA2, SHA3, BLAKE3, HMAC
│   ├── cipher.fx         # AES-GCM, ChaCha20-Poly1305, X25519
│   ├── kdf.fx            # Argon2, PBKDF2, HKDF
│   └── random.fx         # CSPRNG, secure tokens
│
├── json/
│   └── json.fx           # JSON parser, serializer, JSONPath, patch
│
├── testing/
│   ├── assert.fx         # ASSERT, ASSERT_EQ, ASSERT_THROWS
│   ├── runner.fx         # Test discovery, parallel execution, coverage
│   ├── mock.fx           # Mocking framework
│   └── property.fx       # Property-based testing (QuickCheck-style)
│
└── text/
    ├── regex.fx          # PCRE2-compatible regex
    ├── format.fx         # printf-style, string templates
    └── encoding.fx       # UTF-8/16/32, Latin1, Base64, Hex
```

---

## 6. Tooling Architecture

### 6.1 CLI (`fxbase`)

```
fxbase
├── build          # Compile project (debug/release)
├── run            # Build + execute
├── test           # Run tests (--coverage, --bench)
├── fmt            # Format source (opinionated, like gofmt)
├── doc            # Generate docs from /// comments (HTML/MD)
├── migrate        # Transpile xHarbour → FXBASE
├── new            # Scaffold project (lib/bin)
├── add            # Add dependency (fxpkg)
├── update         # Update dependencies
├── publish        # Publish package to registry
├── repl           # Interactive REPL
├── check          # Type-check only (no codegen)
├── lint           # Lint + style checks
└── doctor         # Environment diagnostics
```

### 6.2 Package Manager (`fxpkg`)

```
┌─────────────────────────────────────────────────────────────┐
│                      fxpkg ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  fxpkg.toml (manifest)                                       │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              RESOLVER (PubGrub)                      │    │
│  │  • SemVer resolution                                 │    │
│  │  • Feature unification                               │    │
│  │  • Conflict detection                                │    │
│  │  • Lockfile generation (fxpkg.lock)                  │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              FETCHER                                 │    │
│  │  • Registry API (crates.io style)                   │    │
│  │  • Git dependencies (rev/tag/branch)                │    │
│  │  • Path dependencies                                 │    │
│  │  • Content-addressable cache (~/.fxpkg/cache)       │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              BUILD ORCHESTRATOR                      │    │
│  │  • Topological build order                          │    │
│  │  • Parallel compilation                             │    │
│  │  • Incremental builds (fxbc cache)                  │    │
│  │  • Cross-compilation support                        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 Language Server (LSP)

```
┌─────────────────────────────────────────────────────────────┐
│                      LSP SERVER                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Editor (VS Code, Vim, Emacs)                               │
│       │ JSON-RPC 2.0                                        │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              LSP HANDLERS                            │    │
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
│  │           INCREMENTAL COMPILER FRONTEND              │    │
│  │  • Persistent AST + Symbol tables                   │    │
│  │  • Incremental re-type-check on change              │    │
│  │  • Salsa/Redex-style query engine                   │    │
│  │  • Cancellation support                             │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Cross-Cutting Concerns

### 7.1 Error Handling Strategy

| Layer | Mechanism | Example |
|-------|-----------|---------|
| Lexer | Error tokens + recovery | Invalid char → `ERROR_TOKEN`, continue |
| Parser | Panic mode + sync points | Missing `END` → sync at `FUNCTION`/`CLASS`/`END` |
| Type Checker | Accumulated diagnostics | All type errors reported in single pass |
| Codegen | Trap unreachable | `unreachable!()` in match arms |
| Runtime | `RESULT<T,E>` + exceptions | Domain errors = Result; Panics = bugs |
| FFI | `UNSAFE` blocks + contracts | C calls validated at boundary |

### 7.2 Diagnostics Format

```json
{
  "code": "E0308",
  "level": "error",
  "message": "mismatched types",
  "spans": [
    {
      "file": "src/main.fx",
      "start": {"line": 42, "column": 15},
      "end": {"line": 42, "column": 25},
      "label": "expected `INT`, found `STRING`"
    }
  ],
  "notes": [
    "help: add explicit conversion: `AS INT`",
    "note: this error originates in the macro `$crate::format_args`"
  ],
  "suggestions": [
    {"action": "replace", "span": "...", "text": "AS INT"}
  ]
}
```

### 7.3 Incremental Compilation

```
┌─────────────────────────────────────────────────────────────┐
│                 INCREMENTAL BUILD GRAPH                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Source Change (.fx)                                         │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              QUERY ENGINE (Salsa-style)              │    │
│  │  Inputs:  File contents, config, deps                │    │
│  │  Queries:                                            │    │
│  │    parse(file) → AST                                 │    │
│  │    type_check(ast) → TypedAST + Diagnostics         │    │
│  │    codegen(typed_ast, backend) → Artifact           │    │
│  │    link(artifacts) → Binary                          │    │
│  │  Invalidation: hash-based, fine-grained             │    │
│  └─────────────────────────────────────────────────────┘    │
│       │                                                      │
│       ▼                                                      │
│  Only affected queries re-executed                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 7.4 Security Model

```
┌─────────────────────────────────────────────────────────────┐
│                      SECURITY LAYERS                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. LANGUAGE LEVEL                                           │
│     • Memory safety (no raw pointers in safe code)          │
│     • Null safety (strict mode)                             │
│     • No implicit coercions                                 │
│     • Macro sandbox (COMPILE<> only)                        │
│     • SQL injection prevention (prepared statements)        │
│                                                              │
│  2. RUNTIME LEVEL                                            │
│     • Capability-based FFI (explicit UNSAFE blocks)         │
│     • Channel ownership (linear types for endpoints)        │
│     • Resource limits (stack, heap, file handles)           │
│     • WASM sandbox (if targeting browser)                   │
│                                                              │
│  3. SUPPLY CHAIN                                             │
│     • Signed packages (fxpkg verify)                        │
│     • Lockfile integrity (SHA256)                           │
│     • Reproducible builds                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Deployment Architectures

### 8.1 Native Binary (Default)

```
fxbase build --release
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  Single statically-linked binary (or dynamic with glibc)    │
│  • No runtime dependency                                    │
│  • < 50ms startup                                           │
│  • Optimized via LLVM -O3 + LTO                             │
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
│  • fxstd/ui/web → DOM bindings                              │
│  • fxstd/concurrency → Web Workers + MessageChannel         │
│  • fxstd/db → IndexedDB / WebSQL (SQLite WASM)              │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Scripting / REPL (FXVM)

```
fxbase run script.fx          # Interpreted (bytecode)
fxbase repl                   # Interactive
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  FXVM Stack-based VM                                        │
│  • Hot-reload on file change                                │
│  • JIT tier (future)                                        │
│  • Same GC as native                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Project Structure (Reference Layout)

```
fxbase-project/
├── fxpkg.toml              # Package manifest
├── fxpkg.lock              # Locked dependencies
├── .fxbase/                # Build cache, incremental data
├── src/
│   ├── main.fx             # Binary entry (fn main())
│   ├── lib.fx              # Library root (MODULE name)
│   ├── **/*.fx             # Source modules
│   └── **/*.fx.h           # Generated C headers (for FFI)
├── tests/
│   ├── integration/        # Integration tests
│   ├── unit/               # Unit tests (co-located or here)
│   └── fixtures/           # Test data
├── examples/               # Example binaries
├── benches/                # Benchmarks
├── scripts/                # Build/migration scripts
├── docs/                   # Documentation source
├── fxstd/                  # Local std overrides (rare)
└── target/                 # Build artifacts (gitignored)
    ├── debug/
    ├── release/
    ├── wasm/
    └── fxbc/               # Bytecode cache
```

---

## 10. Integration Points

| System | Interface | Direction |
|--------|-----------|-----------|
| C Libraries | FFI (`UNSAFE` + `extern "C"`) | Bidirectional |
| OS APIs | `fxstd::os` (platform-specific) | Outbound |
| Databases | RDD 2.0 trait + drivers | Outbound |
| Message Brokers | `fxstd::net` (Redis, RabbitMQ, Kafka) | Outbound |
| Monitoring | `fxstd::telemetry` (OpenTelemetry) | Outbound |
| IDEs | LSP (JSON-RPC 2.0) | Bidirectional |
| CI/CD | `fxbase` CLI exit codes + JSON output | Outbound |
| Package Registry | `fxpkg` HTTP API (crates.io compatible) | Bidirectional |

---

## 11. Future Extension Points

1. **Plugin System** - Compiler plugins for custom attributes/lints
2. **Multiple Frontends** - TypeScript→FXBASE, Python→FXBASE transpilers
3. **Distributed Compilation** - Build farms via gRPC
4. **Cloud IDE** - WASM-compiled compiler running in browser
5. **AI-Assisted Migration** - LLM-powered risk resolution suggestions
6. **Hot Reload** - Runtime code swap for long-running services
7. **GPU Compute** - `fxstd::gpu` (WGPU/CUDA) backend

---

## 12. Version Compatibility Matrix

| FXBASE Version | Grammar Spec | FXSTD API | fxpkg Registry | LSP Protocol |
|----------------|--------------|-----------|----------------|--------------|
| 1.0.x          | 1.0          | 1.0       | v1             | 3.17         |
| 1.1.x          | 1.0+         | 1.1 (compat) | v1           | 3.17+        |
| 2.0.x          | 2.0          | 2.0       | v2             | 3.18+        |

**Policy:** SemVer for language + stdlib. Grammar changes = major version.

---

*End of ARCH Specification*