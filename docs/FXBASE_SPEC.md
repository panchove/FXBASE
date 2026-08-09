# FXBASE — Technical Specification (SPEC)

**Version:** 1.0.0-alpha  
**Date:** 2026-08-08  
**Source:** Derived from PRD v1.0.0, GRAMMAR v1.0.0, ARCH v1.0.0  

---

## 1. Scope and Conformance

### 1.1 Conformance Levels

| Level | Description | Required Features |
|-------|-------------|-------------------|
| **Core** | Minimal viable compiler | Lexer, Parser, Type Checker, C Backend, Core FXSTD |
| **Standard** | Production-ready | All Core + LLVM Backend, LSP, fxpkg, Testing, fmt, doc |
| **Full** | Complete ecosystem | All Standard + WASM, VM, UI Backends, Debugger, Transpilator |

### 1.2 Normative References

- PRD v1.0.0 (requirements)
- GRAMMAR v1.0.0 (syntax)
- ARCH v1.0.0 (architecture)
- IEEE 754-2008 (floating point)
- Unicode 15.0 (identifiers, strings)
- RFC 3986 (URIs in USE statements)
- SemVer 2.0.0 (versioning)

---

## 2. Language Semantics Specification

### 2.1 Type System

#### 2.1.1 Type Universe

```
Type ::= 
  | Primitive          // NIL, LOGICAL, INT, DECIMAL, FLOAT, STRING, DATE, DATETIME, POINTER
  | Variant            // Dynamic type (legacy compatibility)
  | Array<T>           // Homogeneous, dynamic size
  | Hash<K,V>          // Associative array
  | Object<T>          // Class instance
  | CodeBlock<Args..., Ret>  // Typed closure
  | Channel<T>         // CSP channel
  | Result<T,E>        // Ok(T) | Err(E)
  | Optional<T>        // T | NIL  (sugar: T?)
  | Function(Args...) -> Ret
  | UserDefined(name, args...)
  | TypeVar('a)        // For inference
  | Union(T1|T2|...)   // Anonymous sum
  | Intersection(T1&T2) // Anonymous product
```

#### 2.1.2 Subtyping Rules

```
S <: T  iff:
  - S = T
  - S = NIL, T = Optional<U>
  - S = Array<S1>, T = Array<T1>, S1 <: T1  (covariant)
  - S = Hash<K,S1>, T = Hash<K,T1>, S1 <: T1  (covariant in value)
  - S = CodeBlock<ArgsS..., RetS>, T = CodeBlock<ArgsT..., RetT>
        ArgsT <: ArgsS (contravariant), RetS <: RetT (covariant)
  - S = Channel<S1>, T = Channel<T1>, S1 = T1  (invariant)
  - S = Result<S1,E1>, T = Result<T1,E2>, S1 <: T1, E1 <: E2
  - S = Optional<S1>, T = Optional<T1>, S1 <: T1
  - S = UserDefined, T = UserDefined, S inherits T
  - S = Function(ArgsS...) -> RetS, T = Function(ArgsT...) -> RetT
        ArgsT <: ArgsS, RetS <: RetT
```

#### 2.1.3 Gradual Typing Semantics

| Mode | Behavior |
|------|----------|
| **Dynamic** (default) | All variables `VARIANT`, runtime checks, `NIL` assignable to any |
| **Strict** (`#STRICT`) | Explicit/ inferred types, `NIL` only to `T?`, no implicit coercions |
| **Legacy** (`--legacy`) | `PUBLIC`/`PRIVATE`, `VARIANT` default, `SET EXACT OFF`, untyped macros |

**Gradual Guarantee:** Adding type annotations never changes runtime behavior (except catching errors earlier).

#### 2.1.4 Type Inference Algorithm

```
1. Generate constraints from AST (Hindley-Milner style)
2. Unify with occurs-check
3. Generalize at let-bindings (not at lambda boundaries unless annotated)
4. Default unconstrained type vars:
   - Numeric context → INT
   - String context → STRING
   - Boolean context → LOGICAL
   - Collection element → VARIANT (dynamic) or element type (strict)
5. Report unsolved constraints as errors (strict) or VARIANT (dynamic)
```

### 2.2 Variable Semantics

#### 2.2.1 Storage Classes

| Keyword | Lifetime | Scope | Initialization |
|---------|----------|-------|----------------|
| `LOCAL` | Function activation | Block | Required (or `NIL`) |
| `STATIC` | Program | Block | Once, lazy on first entry |
| `MODULE` | Program | File (module) | At module load |
| `EXPORT MODULE` | Program | Cross-module | At module load |

#### 2.2.2 Initialization Rules

```
LOCAL x           // Error in strict, NIL in dynamic
LOCAL x := expr   // Type inferred from expr
LOCAL x AS T      // Error in strict (uninitialized), NIL in dynamic
LOCAL x AS T := e // e must be subtype of T
```

### 2.3 Control Flow Semantics

#### 2.3.1 Loop Semantics

```
FOR i := start TO end [STEP step]
    // i is LOCAL to loop, immutable in body
    // start, end, step evaluated once before loop
    // step defaults to 1; if negative, loop counts down
    // Loop executes zero times if start > end (step>0) or start < end (step<0)
NEXT

FOREACH item IN collection
    // item is LOCAL, new binding each iteration
    // collection evaluated once
    // Modifications to item don't affect collection (copy semantics for values)
NEXT

DO WHILE condition
    // condition checked BEFORE body
ENDDO

DO UNTIL condition
    // condition checked AFTER body (at least once)
ENDDO
```

#### 2.3.2 Match Exhaustiveness

```
MATCH expr
    CASE pattern1 [IF guard] => body1
    CASE pattern2 => body2
    ...
    CASE _ => default
END

// Exhaustiveness required for:
// - Sealed types (all constructors covered)
// - LOGICAL (TRUE, FALSE)
// - RESULT (OK, ERR)
// - OPTIONAL (SOME, NONE)
// Non-exhaustive = compile error in strict, warning in dynamic
```

### 2.4 Function Semantics

#### 2.4.1 Parameter Passing

| Mode | Syntax | Semantics |
|------|--------|-----------|
| By Value | `x AS T` | Copy for value types, reference for objects |
| By Ref | `BYREF x AS T` | Alias to caller's variable |
| Default | `x AS T := default` | Evaluated at call site if omitted |
| Variadic | `...x AS ARRAY<T>` | Collected into array |

#### 2.4.2 Return Semantics

```
RETURN expr           // Returns from function, type must match
RETURN                // Returns NIL (only valid for NIL/Optional/Result return)
```

#### 2.4.3 Async Functions

```
ASYNC FUNCTION name(...) AS Task<T>
    // Returns immediately with Task<T>
    // Body executes on scheduler
    // AWAIT points are yield points
END

SPAWN expr            // expr: Function or CodeBlock → Task
AWAIT task            // Blocks task (not thread) until complete
WAIT ALL [tasks...]   // Blocks until all complete
```

### 2.5 Concurrency Semantics

#### 2.5.1 Channel Operations

```
ch := CHANNEL<T>(capacity)  // capacity=0 → unbuffered (rendezvous)

ch <- value      // Send: blocks if full (buffered) or no receiver (unbuffered)
value := <- ch   // Receive: blocks if empty
value := <- ch?  // Try receive: returns Optional<T> (NIL if empty)

// Select (multiplexing)
SELECT
    CASE v := <- ch1 => body1
    CASE <- ch2 => body2
    CASE ch3 <- val => body3
    CASE DEFAULT => body_default
END
```

**Channel Guarantees:**
- FIFO ordering per channel
- Send/receive are atomic wrt other ops on same channel
- Closing channel: `CLOSE(ch)` → subsequent sends panic, receives drain then return NIL
- No shared mutable state between tasks (enforced by type system)

#### 2.5.2 Task Model

- **Green threads** (M:N scheduling, work-stealing)
- Stack: segmented, grows on demand (min 8KB, max configurable)
- Preemption: at function calls, loop backedges, channel ops, AWAIT
- `SPAWN` inherits caller's lexical environment (copied, not shared)

### 2.6 Object Model

#### 2.6.1 Class Semantics

```
CLASS Name [INHERIT Base]
    PROPERTY name AS Type [:= default]   // Instance field
    ACCESS name AS Type                  // Computed property (getter)
    METHOD name(...) AS Ret ... END      // Virtual by default
    OVERRIDE METHOD name(...) ... END    // Must match base signature
    CONSTRUCTOR(...) ... END             // Must initialize all fields
    HIDDEN ...                           // Private to class
    STATIC ...                           // Per-class (not per-instance)
END
```

**Inheritance Rules:**
- Single inheritance only
- `SUPER(...)` must be first statement in derived constructor
- Fields not inherited (composition over inheritance for state)
- Methods virtual by default; `FINAL` prevents override (future)

#### 2.6.2 Interface/Protocol (Future)

```
// Not in v1.0 - planned for v1.1
PROTOCOL Name
    METHOD name(...) AS Ret
END

CLASS Name IMPLEMENTS Protocol
    ...
END
```

### 2.7 Error Handling Semantics

#### 2.7.1 Exceptions (Exceptional Errors)

```
TRY
    risky()
CATCH e AS SpecificError
    // Handle specific
CATCH e AS BaseError
    // Handle base
FINALLY
    cleanup()  // Always executes, even on panic/return
END
```

- Stack unwinding with destructors (RAII via `FINALLY`/`DROP` trait)
- `RAISE` re-throws current exception
- Uncaught exception → task panic → logged, task dies

#### 2.7.2 Result Type (Domain Errors)

```
FUNCTION op() AS RESULT<T, E>
    IF error_condition
        RETURN ERR(error_value)
    ENDIF
    RETURN OK(success_value)
END

// Pattern matching
MATCH op()
    CASE OK(v) => use(v)
    CASE ERR(e) => handle(e)
END

// Unwrap with default
val := op() ? default_val
```

### 2.8 Database (RDD 2.0) Semantics

#### 2.8.1 Connection

```
USE "postgres://user:pass@host/db" VIA "PGSQL" ALIAS name
// Opens connection pool (default 10 connections)
// ALIAS becomes default workarea
```

#### 2.8.2 Navigation Commands → SQL Translation

| FXBASE Command | SQL Translation |
|----------------|-----------------|
| `USE alias` | `SET workarea = alias` |
| `SEEK key` | `SELECT * FROM table WHERE pk = ? LIMIT 1` |
| `LOCATE FOR cond` | `SELECT * FROM table WHERE cond LIMIT 1` |
| `SKIP n` | `OFFSET n` (cursor-based) |
| `REPLACE field WITH val` | `UPDATE table SET field = ? WHERE pk = ?` |
| `REPLACE ALL ... WHERE cond` | `UPDATE table SET ... WHERE cond` |
| `DELETE` | `UPDATE table SET deleted = true WHERE pk = ?` (soft delete) |
| `PACK` | `DELETE FROM table WHERE deleted = true` |
| `COUNT TO var FOR cond` | `SELECT COUNT(*) FROM table WHERE cond` |
| `SUM field TO var` | `SELECT SUM(field) FROM table` |

**Prepared Statement Cache:** LRU cache (100 statements per connection).

#### 2.8.3 Transactions

```
BEGIN TRANSACTION
    // ... operations ...
COMMIT
// or
ROLLBACK

// Nested: savepoints
SAVEPOINT name
ROLLBACK TO name
```

### 2.9 Macro & Metaprogramming Semantics

#### 2.9.1 Legacy Macro (`&`)

```
&identifier        // Resolves variable/field at runtime (dynamic)
&(expression)      // Evaluates expression string at runtime
// Only allowed in --legacy mode or dynamic mode
// Security: sandboxed, no filesystem/network access
```

#### 2.9.2 Safe Macro (`COMPILE`)

```
COMPILE<RetType>(source_string, [context_hash])
// source_string: FXBASE expression/source
// context_hash: { "var_name" => TYPE, ... } for type checking
// Compiles at runtime, returns typed CodeBlock
// Sandbox: no FFI, no filesystem, no network, resource limits
```

#### 2.9.3 Compile-Time Metaprogramming

```
ATTRIBUTE Name(params)
    // Executes at compile time during attribute processing
    // Access to AST of decorated item
    // Can emit diagnostics, modify AST (future)
END

// Usage
[Name("value")]
CLASS Foo ... END
```

---

## 3. Standard Library (FXSTD) Specification

### 3.1 Core Types

#### 3.1.1 `RESULT<T, E>`

```
ENUM RESULT<T, E>
    OK(T)
    ERR(E)
END

METHODS:
    map<U>(f: Fn(T) -> U) -> RESULT<U, E>
    map_err<F>(f: Fn(E) -> F) -> RESULT<T, F>
    and_then<U>(f: Fn(T) -> RESULT<U, E>) -> RESULT<U, E>
    or_else<F>(f: Fn(E) -> RESULT<T, F>) -> RESULT<T, F>
    unwrap() -> T  // Panics on ERR
    unwrap_or(default: T) -> T
    expect(msg: STRING) -> T  // Panics with msg on ERR
    is_ok() -> LOGICAL
    is_err() -> LOGICAL
```

#### 3.1.2 `OPTIONAL<T>` (alias `T?`)

```
ENUM OPTIONAL<T>
    SOME(T)
    NONE
END

METHODS:
    map<U>(f: Fn(T) -> U) -> OPTIONAL<U>
    and_then<U>(f: Fn(T) -> OPTIONAL<U>) -> OPTIONAL<U>
    or_else(f: Fn() -> OPTIONAL<T>) -> OPTIONAL<T>
    unwrap() -> T
    unwrap_or(default: T) -> T
    expect(msg: STRING) -> T
    is_some() -> LOGICAL
    is_none() -> LOGICAL
```

#### 3.1.3 `CHANNEL<T>`

```
CLASS CHANNEL<T>
    CONSTRUCTOR(capacity: INT := 0)
    METHOD send(value: T)           // Blocks
    METHOD try_send(value: T) -> LOGICAL  // Returns FALSE if full
    METHOD recv() -> T              // Blocks
    METHOD try_recv() -> OPTIONAL<T>
    METHOD close()
    METHOD is_closed() -> LOGICAL
    METHOD len() -> INT             // Buffered only
    METHOD cap() -> INT
END
```

### 3.2 Collections

#### 3.2.1 `ARRAY<T>`

```
CLASS ARRAY<T>
    CONSTRUCTOR()                    // Empty
    CONSTRUCTOR(capacity: INT)       // Pre-allocated
    CONSTRUCTOR(items: ARRAY<T>)     // Copy
    
    METHOD push(item: T)
    METHOD pop() -> OPTIONAL<T>
    METHOD get(index: INT) -> OPTIONAL<T>
    METHOD set(index: INT, item: T) -> LOGICAL  // FALSE if OOB
    METHOD len() -> INT
    METHOD cap() -> INT
    METHOD reserve(additional: INT)
    METHOD clear()
    METHOD contains(item: T) -> LOGICAL  // Requires Eq
    METHOD index_of(item: T) -> OPTIONAL<INT>
    METHOD slice(start: INT, end: INT) -> ARRAY<T>
    METHOD map<U>(f: Fn(T) -> U) -> ARRAY<U>
    METHOD filter(f: Fn(T) -> LOGICAL) -> ARRAY<T>
    METHOD reduce<U>(init: U, f: Fn(U, T) -> U) -> U
    METHOD sort()  // Requires Ord
    METHOD sort_by(f: Fn(T) -> COMPARABLE)
    METHOD iter() -> ITERATOR<T>
END
```

#### 3.2.2 `HASH<K, V>`

```
CLASS HASH<K, V>  // K: Hash + Eq
    CONSTRUCTOR()
    CONSTRUCTOR(capacity: INT)
    
    METHOD get(key: K) -> OPTIONAL<V>
    METHOD set(key: K, value: V) -> OPTIONAL<V>  // Returns old
    METHOD remove(key: K) -> OPTIONAL<V>
    METHOD has(key: K) -> LOGICAL
    METHOD len() -> INT
    METHOD clear()
    METHOD keys() -> ARRAY<K>
    METHOD values() -> ARRAY<V>
    METHOD entries() -> ARRAY<{key: K, value: V}>
    METHOD iter() -> ITERATOR<{key: K, value: V}>
END
```

### 3.3 I/O

```
CLASS FILE
    STATIC open(path: PATH, opts: OPEN_OPTIONS) -> RESULT<FILE, IO_ERROR>
    METHOD read(buf: ARRAY<BYTE>) -> RESULT<INT, IO_ERROR>
    METHOD write(buf: ARRAY<BYTE>) -> RESULT<INT, IO_ERROR>
    METHOD seek(pos: SEEK_FROM) -> RESULT<INT64, IO_ERROR>
    METHOD flush() -> RESULT<NIL, IO_ERROR>
    METHOD metadata() -> RESULT<METADATA, IO_ERROR>
    METHOD close() -> RESULT<NIL, IO_ERROR>
END

CLASS PATH
    STATIC new(path: STRING) -> PATH
    METHOD join(other: PATH) -> PATH
    METHOD parent() -> OPTIONAL<PATH>
    METHOD filename() -> OPTIONAL<STRING>
    METHOD extension() -> OPTIONAL<STRING>
    METHOD exists() -> LOGICAL
    METHOD is_file() -> LOGICAL
    METHOD is_dir() -> LOGICAL
    METHOD read_dir() -> RESULT<ARRAY<DIR_ENTRY>, IO_ERROR>
END
```

### 3.4 Database (RDD)

```
INTERFACE RDD
    METHOD connect(dsn: STRING, opts: HASH<STRING, VARIANT>) -> RESULT<CONNECTION, DB_ERROR>
END

CLASS CONNECTION
    METHOD execute(sql: STRING, params: ARRAY<VARIANT>) -> RESULT<EXEC_RESULT, DB_ERROR>
    METHOD query(sql: STRING, params: ARRAY<VARIANT>) -> RESULT<CURSOR, DB_ERROR>
    METHOD begin() -> RESULT<TRANSACTION, DB_ERROR>
    METHOD close() -> RESULT<NIL, DB_ERROR>
END

CLASS CURSOR
    METHOD next() -> RESULT<OPTIONAL<ROW>, DB_ERROR>
    METHOD columns() -> ARRAY<COLUMN_INFO>
    METHOD close() -> RESULT<NIL, DB_ERROR>
END

CLASS TRANSACTION
    METHOD commit() -> RESULT<NIL, DB_ERROR>
    METHOD rollback() -> RESULT<NIL, DB_ERROR>
    METHOD savepoint(name: STRING) -> RESULT<NIL, DB_ERROR>
    METHOD rollback_to(name: STRING) -> RESULT<NIL, DB_ERROR>
END
```

### 3.5 Concurrency Primitives

```
CLASS TASK<T>
    METHOD await() -> T  // Blocks task
    METHOD try_await() -> OPTIONAL<T>
    METHOD cancel() -> LOGICAL
    METHOD is_done() -> LOGICAL
END

FUNCTION SPAWN<F, R>(f: F) -> TASK<R>  // F: Fn() -> R

FUNCTION SELECT(cases: ARRAY<SELECT_CASE>) -> SELECT_RESULT

// Time
FUNCTION sleep(duration: DURATION)
FUNCTION timeout<T>(duration: DURATION, f: Fn() -> T) -> RESULT<T, TIMEOUT_ERROR>
```

### 3.6 UI (GET/READ 2.0)

```
CLASS FORM
    CONSTRUCTOR(title: STRING, width: INT, height: INT)
    METHOD add_say(row: INT, col: INT, text: STRING)
    METHOD add_get(row: INT, col: INT, model: ANY, field: STRING, 
                   valid: Fn() -> LOGICAL := {|| TRUE},
                   message: STRING := "",
                   picture: STRING := "")
    METHOD add_checkbox(row: INT, col: INT, model: ANY, field: STRING, caption: STRING)
    METHOD add_combobox(row: INT, col: INT, model: ANY, field: STRING, items: ARRAY<STRING>)
    METHOD add_button(row: INT, col: INT, text: STRING, action: Fn())
    METHOD read(model: ANY)  // Binds form to model, runs event loop
    METHOD close()
END
```

---

## 4. Compiler Specification

### 4.1 Command Line Interface

```
fxbase [OPTIONS] <COMMAND> [ARGS]

COMMANDS:
    build [--release] [--target TRIPLE] [--legacy] [--strict]
    run [--release] [-- ARGS...]
    test [--coverage] [--bench] [FILTER]
    check [--strict]
    fmt [--check] [FILES...]
    doc [--html] [--md] [--output DIR]
    migrate [--source DIR] [--output DIR] [--report FORMAT]
    new [--lib|--bin] NAME
    add <PKG>[@VERSION] [--dev]
    update [PKG...]
    publish [--dry-run] [--token TOKEN]
    repl
    lint [--fix]
    doctor

GLOBAL OPTIONS:
    -v, --verbose          Increase verbosity
    -q, --quiet            Suppress non-error output
    --color auto|always|never
    --config FILE          Config file (default: fxpkg.toml)
    --cache-dir DIR        Build cache directory
    -j, --jobs N           Parallel jobs (default: CPU count)
```

### 4.2 Configuration (`fxpkg.toml`)

```toml
[package]
name = "my_app"
version = "1.0.0"
authors = ["Name <email>"]
edition = "2026"
description = "..."
license = "MIT"
repository = "https://..."
homepage = "https://..."
keywords = ["tag1", "tag2"]
categories = ["cat1"]

[dependencies]
fxstd = "1.0"
serde = { version = "1.0", features = ["derive"] }
mypkg = { path = "../local_dep" }
other = { git = "https://...", rev = "abc123" }

[dev-dependencies]
test_harness = "1.0"

[features]
default = ["std"]
std = ["fxstd"]
web = ["fxstd/web"]

[profile.release]
opt_level = 3
lto = true
debug = false
panic = "abort"

[profile.dev]
opt_level = 0
debug = true
overflow_checks = true

[build]
target = "x86_64-unknown-linux-gnu"
rustflags = ["-C", "target-cpu=native"]

[lsp]
enable = true
check_on_save = true

[migrate]
legacy_mode = true
risk_threshold = "medium"
```

### 4.3 Diagnostics Format

```json
{
  "diagnostics": [
    {
      "code": "E0308",
      "level": "error",
      "message": "mismatched types",
      "spans": [
        {
          "file_id": 1,
          "start": 42,
          "end": 48,
          "line": 10,
          "column": 15,
          "label": "expected `INT`, found `STRING`"
        }
      ],
      "children": [
        {
          "level": "note",
          "message": "expected enum `RESULT<INT, STRING>`",
          "spans": [...]
        }
      ],
      "suggestions": [
        {
          "action": "replace",
          "span": {"file_id": 1, "start": 42, "end": 48},
          "text": "AS INT"
        }
      ]
    }
  ],
  "files": {
    "1": "src/main.fx"
  }
}
```

### 4.4 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Compilation error |
| 2 | Invalid arguments |
| 3 | Internal compiler error (ICE) |
| 4 | Dependency resolution failed |
| 5 | Package not found |
| 6 | Test failures |
| 7 | Lint/formatting errors (--check) |
| 8 | Migration errors |
| 127 | Command not found |

---

## 5. Transpilator Specification (`fxbase migrate`)

### 5.1 Invocation

```
fxbase migrate [OPTIONS] --source <DIR> --output <DIR>

OPTIONS:
    --legacy              Emit --legacy compatible code
    --strict              Emit #STRICT code (requires manual fixes)
    --report FORMAT       md|json|html (default: md)
    --risk-threshold      low|medium|high (default: low)
    --preserve-comments   Keep original comments
    --module-strategy     file|directory|heuristic (default: heuristic)
    --include-pattern     Glob for .prg files (default: **/*.prg)
    --exclude-pattern     Glob to exclude
    --dry-run             Analyze only, no output
```

### 5.2 Transformation Rules (Normative)

| xHarbour Pattern | FXBASE Output | Annotation |
|------------------|---------------|------------|
| `PUBLIC var` | `EXPORT MODULE VARIABLE var AS VARIANT` | RIESGO-102 |
| `PRIVATE var` | `MODULE VARIABLE var AS VARIANT` | RIESGO-102 |
| `LOCAL var` | `LOCAL var AS VARIANT` | (none) |
| `LOCAL var := expr` | `LOCAL var AS VARIANT := expr` | (none) |
| `FUNCTION f(p1, p2)` | `FUNCTION f(p1 AS VARIANT, p2 AS VARIANT) AS VARIANT` | RIESGO-201 if critical |
| `&macro` | `COMPILE<VARIANT>("macro")` | RIESGO-101 |
| `#include "x.ch"` | `IMPORT * FROM "x"` | RIESGO-401 if circular |
| `REQUEST func` | `IMPORT func FROM "legacy/func"` | RIESGO-402 if unresolved |
| `BEGIN SEQUENCE ... RECOVER ... END` | `TRY ... CATCH ... END` | (direct) |
| `SET EXACT OFF` / `SET SOFTSEEK ON` | (emitted, requires review) | RIESGO-202 |
| `USE file.dbf` | `USE "file.dbf" VIA "DBF"` | (legacy RDD) |
| Raw `POINTER` arithmetic | `UNSAFE { ... }` | RIESGO-301 |
| Untyped `CodeBlock` literal | Typed `CODEBLOCK<...>` | RIESGO-302 |

### 5.3 Risk Report Schema (JSON)

```json
{
  "summary": {
    "files_processed": 342,
    "total_lines": 89420,
    "generated_lines": 94102,
    "auto_translated_pct": 87.6,
    "manual_review_pct": 12.4,
    "estimated_hours": 42
  },
  "risks": [
    {
      "code": "RIESGO-101",
      "description": "Unsafe macro usage detected",
      "severity": "HIGH",
      "count": 45,
      "locations": [
        {"file": "Facturacion.prg", "line": 142, "context": "&cExpr"}
      ]
    },
    {
      "code": "RIESGO-102",
      "description": "PUBLIC/PRIVATE variables detected",
      "severity": "HIGH",
      "count": 234,
      "locations": [
        {"file": "Globales.prg", "line": 10, "context": "PUBLIC nContador"}
      ]
    },
    {
      "code": "RIESGO-201",
      "description": "Implicit typing in critical paths",
      "severity": "MEDIUM",
      "count": 8901,
      "locations": [
        {"file": "Facturacion.prg", "line": 500, "context": "FUNCTION CalcularTotal(nSubtotal, nImpuesto)"}
      ]
    },
    {
      "code": "RIESGO-202",
      "description": "SET EXACT OFF / SET SOFTSEEK ON detected",
      "severity": "MEDIUM",
      "count": 12,
      "locations": [
        {"file": "Config.prg", "line": 5, "context": "SET EXACT OFF"}
      ]
    },
    {
      "code": "RIESGO-301",
      "description": "Raw POINTER manipulation",
      "severity": "HIGH",
      "count": 67,
      "locations": [
        {"file": "Interop.prg", "line": 200, "context": "p := malloc(1024)"}
      ]
    },
    {
      "code": "RIESGO-302",
      "description": "Untyped CodeBlock capture",
      "severity": "LOW",
      "count": 189,
      "locations": [
        {"file": "Filtros.prg", "line": 50, "context": "{|x| x.activo = TRUE}"}
      ]
    },
    {
      "code": "RIESGO-401",
      "description": "Circular #include detected",
      "severity": "MEDIUM",
      "count": 23,
      "locations": [
        {"file": "Facturacion.prg", "line": 1, "context": "#include \"Clientes.ch\""},
        {"file": "Clientes.prg", "line": 1, "context": "#include \"Facturacion.ch\""}
      ]
    },
    {
      "code": "RIESGO-402",
      "description": "Unresolved REQUEST function",
      "severity": "HIGH",
      "count": 8,
      "locations": [
        {"file": "Modulo1.prg", "line": 10, "context": "REQUEST FuncionExterna"}
      ]
    }
  ],
  "unresolved": [
    {"symbol": "FuncionExterna", "referenced_in": ["Modulo1.prg:10"]}
  ],
  "recommendations": [
    "Start with --legacy mode, enable strict per-module",
    "Prioritize RIESGO-101, RIESGO-102, RIESGO-301, RIESGO-402 fixes (HIGH severity)",
    "Address RIESGO-201, RIESGO-202, RIESGO-401 (MEDIUM) in critical modules",
    "Review RIESGO-302 (LOW) during code cleanup phase"
  ]
}
```

---

## 6. Runtime Behavior Specification

### 6.1 Startup Sequence

```
1. Process entry (main or FXVM bootstrap)
2. Initialize GC (nursery, heaps, write barrier)
3. Initialize scheduler (worker threads = CPU cores)
4. Initialize FXSTD (intern strings, type metadata)
5. Run module initializers (topological order)
   - MODULE VARIABLE initializers
   - STATIC initializers
6. Call user main() / script entry
7. On exit: run FINALIZERS (reverse order)
8. Shutdown scheduler, GC stats dump (if enabled)
```

### 6.2 Memory Limits

| Resource | Default Limit | Configurable Via |
|----------|---------------|------------------|
| Max heap | 80% physical RAM | `FXBASE_MAX_HEAP` env |
| Max stack per task | 8MB | `FXBASE_MAX_STACK` |
| Channel buffer | Unlimited | `CHANNEL<T>(cap)` |
| Task count | 100,000 | `FXBASE_MAX_TASKS` |
| Open files | OS limit | `ulimit -n` |

### 6.3 Signal Handling

| Signal | Behavior |
|--------|----------|
| SIGINT (Ctrl-C) | Raises `InterruptException` in main task |
| SIGTERM | Initiates graceful shutdown (runs finalizers) |
| SIGSEGV | Prints stack trace, aborts (unless custom handler) |
| SIGHUP | Reloads config (if daemon mode) |

---

## 7. Interoperability Specification

### 7.1 C FFI

```fxbase
// Declaration
[Link("pq")]
UNSAFE FUNCTION PQconnectdb(conninfo: POINTER) AS POINTER
END

// Usage
UNSAFE {
    LOCAL cStr := "host=localhost dbname=test" AS POINTER
    LOCAL conn := PQconnectdb(cStr)
    // ...
}
```

**ABI Rules:**
- `STRING` → `const char*` (UTF-8, null-terminated)
- `ARRAY<T>` → `{ T* data; size_t len; size_t cap; }`
- `HASH<K,V>` → opaque handle, accessor functions
- `OBJECT` → opaque pointer
- `RESULT<T,E>` → `{ int tag; union { T ok; E err; } }`
- Calling convention: platform C ABI (System V AMD64, Windows x64)

### 7.2 WASM Imports/Exports

```fxbase
// Import from JS
[Import("js", "console.log")]
FUNCTION js_log(msg: STRING)
END

// Export to JS
[Export("calculate")]
EXPORT FUNCTION calculate(x: INT, y: INT) AS INT
    RETURN x + y
END
```

---

## 8. Testing Specification

### 8.1 Test Syntax

```fxbase
/// @test 2, 3 -> 5
/// @test 0, 0 -> 0
/// @test -1, 1 -> ERR
EXPORT FUNCTION add(a: INT, b: INT) AS RESULT<INT, STRING>
    IF a < 0 OR b < 0
        RETURN ERR("negatives not allowed")
    ENDIF
    RETURN OK(a + b)
END

SUITE "MathTests"
    TEST "Addition"
        ASSERT add(2, 3) == OK(5)
        ASSERT add(0, 0) == OK(0)
    END

    TEST "Negative rejected"
        ASSERT IS_ERR(add(-1, 1))
    END
END
```

### 8.2 Test Runner Options

```
fxbase test [OPTIONS] [PATTERN]

OPTIONS:
    --coverage          Generate coverage report (lcov/html)
    --bench             Run benchmarks
    --jobs N            Parallel test threads
    --filter EXPR       Run tests matching expr
    --list              List tests without running
    --no-run            Compile only
    --shuffle           Randomize order
    --timeout SECS      Per-test timeout (default: 60)
```

### 8.3 Assertions

| Macro | Description |
|-------|-------------|
| `ASSERT(expr)` | Panic if false |
| `ASSERT_EQ(a, b)` | Panic if a != b (requires Eq) |
| `ASSERT_NE(a, b)` | Panic if a == b |
| `ASSERT_OK(result)` | Panic if Err, unwrap Ok |
| `ASSERT_ERR(result)` | Panic if Ok, unwrap Err |
| `ASSERT_THROWS(expr, Type)` | Panic if no exception of Type |
| `ASSERT_PANICS(expr)` | Panic if no panic |

---

## 9. Package Manager Specification (`fxpkg`)

### 9.1 Registry API

```
GET  /api/v1/crates              # Search
GET  /api/v1/crates/{name}       # Package metadata
GET  /api/v1/crates/{name}/{ver}/download  # Download .fxpkg
PUT  /api/v1/crates/new          # Publish (auth required)
DELETE /api/v1/crates/{name}/{ver}/yank    # Yank version
```

### 9.2 Package Format (`.fxpkg`)

```
package.fxpkg (tar.zst)
├── fxpkg.toml          # Manifest (same as source)
├── src/                # Source files (.fx)
├── include/            # Generated C headers (for FFI)
├── lib/                # Precompiled artifacts (per target)
│   ├── x86_64-linux/
│   │   ├── libname.a
│   │   └── libname.fxbc
│   └── wasm32-unknown/
│       ├── libname.wasm
│       └── libname.fxbc
└── CHECKSUM            # SHA256 of contents
```

### 9.3 Lockfile (`fxpkg.lock`)

```toml
[package]
name = "my_app"
version = "1.0.0"

[[dependencies]]
name = "fxstd"
version = "1.0.3"
source = "registry+https://fxbase.dev"
checksum = "sha256:abc123..."
dependencies = []

[[dependencies]]
name = "local_dep"
version = "0.1.0"
source = "path+../local_dep"
```

---

## 10. LSP Specification

### 10.1 Supported Capabilities

| Capability | Supported | Notes |
|------------|-----------|-------|
| textDocument/completion | ✅ | Snippets, auto-import |
| textDocument/hover | ✅ | Type info, docs |
| textDocument/definition | ✅ | Go to definition |
| textDocument/references | ✅ | Find all references |
| textDocument/rename | ✅ | Cross-file |
| textDocument/formatting | ✅ | Uses `fxbase fmt` |
| textDocument/codeAction | ✅ | Fix imports, add missing match arms |
| textDocument/diagnostic | ✅ | Push diagnostics |
| workspace/symbol | ✅ | Fuzzy search |
| workspace/didChangeConfiguration | ✅ | Config reload |
| textDocument/inlayHint | 🔄 | Type hints (planned) |
| textDocument/semanticTokens | 🔄 | Syntax highlighting (planned) |

### 10.2 Initialization Options

```json
{
  "initializationOptions": {
    "checkOnSave": true,
    "strictMode": false,
    "legacyMode": false,
    "formatOnSave": true,
    "completionDetail": "full",
    "maxDiagnostics": 100
  }
}
```

---

## 11. Versioning and Compatibility

### 11.1 Language Versioning

```
Edition 2026 (current)
  - Baseline syntax and semantics
  - Gradual typing
  - CSP concurrency

Edition 2027 (planned)
  - Protocols/Interfaces
  - Const generics
  - Async destructors
  - Pattern matching improvements
```

**Migration:** `fxbase migrate --edition 2027` (automated where possible)

### 11.2 FXSTD Stability Tiers

| Tier | Stability | Examples |
|------|-----------|----------|
| **Stable** | No breaking changes in major version | `core::types`, `collections::array`, `io::file` |
| **Preview** | May change with warning | `ui::web`, `net::websocket` |
| **Experimental** | No guarantees | `gpu::*`, `ai::*` |

### 11.3 Deprecation Policy

1. Mark with `[Deprecated("use X instead", since = "1.2")]`
2. Compiler warning on use
3. Remove after 2 minor versions (6 months minimum)
4. Document in CHANGELOG.md

---

## 12. Performance Benchmarks (Target)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cold compile 10k LOC | < 1s | `fxbase build` on Ryzen 5 5600X |
| Incremental compile (1 file) | < 200ms | Change one function |
| REPL startup | < 50ms | `fxbase repl` |
| Binary startup (hello world) | < 10ms | Native, stripped |
| Channel latency (ping-pong) | < 100ns | 1M ops/sec |
| Task spawn + await | < 1µs | No work |
| GC pause (100MB heap) | < 5ms | P99 |
| RDD query overhead | < 1ms | Prepared statement cache hit |
| Transpilator speed | > 10k LOC/s | `fxbase migrate` |

---

## 13. Security Requirements

| Requirement | Implementation |
|-------------|----------------|
| Memory safety | No raw pointers in safe code; `UNSAFE` blocks audited |
| Null safety | Strict mode: `T?` required for nullable |
| SQL injection | All RDD ops use prepared statements |
| Macro sandbox | `COMPILE<>`: no FFI, no I/O, fuel-limited |
| Supply chain | `fxpkg` verifies checksums, signed index |
| Reproducible builds | Deterministic output, timestamps stripped |
| Capability-based FFI | Each `UNSAFE` block declares required capabilities |

---

## 14. Conformance Test Suite

The reference implementation must pass:

1. **Syntax Tests** - All GRAMMAR productions parse correctly
2. **Type System Tests** - Subtyping, inference, gradual guarantee
3. **Runtime Tests** - GC, scheduler, channels, tasks
4. **FXSTD Tests** - All stdlib functions behave per spec
5. **Migration Tests** - xHarbour corpus transpiles and runs
6. **Interop Tests** - C FFI, WASM imports/exports
7. **Tooling Tests** - CLI, LSP, fmt, doc, test runner
8. **Performance Tests** - Benchmarks within targets

---

*End of SPEC v1.0.0*