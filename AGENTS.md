# FPXBASE — Project Status & Conventions

## Status

Greenfield project in **design/planning phase**. No code yet.

## Source of Truth

- `docs/PRD-FPXBASE.md` — product requirements, architecture, roadmap, migration strategy
- `docs/GRAMMAR-FXBASE.md` — complete EBNF grammar for xBASE (Clipper/Harbour/FoxPro) + FPXBASE extensions

## What FPXBASE Is

A modern xBASE compiler that **replaces .dbf/index files with SQL** (SQLite default, optional PostgreSQL/MSSQL). Generates native 32/64-bit EXE/DLL/SO/LIB/A for Windows and Linux.

## Planned Stack

| Layer        | Technology                                                  |
|--------------|-------------------------------------------------------------|
| Parser/Lexer | Free Pascal (recursive descent on DFA lexer)                |
| IR/Optimizer | Free Pascal (own IR tree/DAG)                               |
| Backend      | Free Pascal (native x86/x86_64 asm → PE/COFF / ELF)         |
| Data layer   | Free Pascal (SQLite, PostgreSQL, MSSQL via native wrappers) |
| Tooling      | LSP, DAP                                                    |

## CLI Tools (planned)

- `fpx` — compiler (build/run/test)
- `fpx-lsp` — language server
- `fpx-fmt` — formatter
- `fpx-pkg` — package manager
- `fpx-dbf` — DBF import/export (dBASE III/IV, FoxPro 2.x, memo, NTX/CDX)
- `fpx-dap` — debug adapter protocol server

## Key Design Decisions

- No .dbf or NTX/CDX/IDX support at runtime — all persistence is SQL
- DB commands translate at compile time: `USE`→`SELECT`/`CREATE TABLE`, `INDEX`→`CREATE INDEX`, `SET RELATION`→`JOIN`, `REPLACE`→`UPDATE`, `APPEND`→`INSERT`, `PACK/ZAP`→`DELETE`/`TRUNCATE`
- Tipado opcional y gradual (como TypeScript); variables sin tipo son dinámicas
- `--legacy` flag accepts 100% Clipper/Harbour syntax but emits warnings
- Cross-compilation via `--target win32|win64|linux32|linux64`
- `#strict on/off` controls type strictness per file
- Memory: refcount by default, optional generational GC or manual
- `STRUCT`: value type (copy semantic, stack, no inheritance), supports `ALIGN`/`PADDING` for C interop
- Smart pointers: `UNIQUE_PTR<T>`, `SHARED_PTR<T>`, `WEAK_PTR<T>` with `^` deref, `.Reset()`, `.Get()`, `MAKE_UNIQUE`/`MAKE_SHARED`
- Strings: UTF-8 by default; `--db-ansi` for legacy byte-wise mode
- Concurrency: mutex, semaphore, thread-local, atomic ops, channels
- Cipher: AES-256-GCM / ChaCha20-Poly1305; TLS sockets; JWT, bcrypt

## File Extensions

| Ext          | Purpose                            |
|--------------|------------------------------------|
| `.prg`       | xBASE source                       |
| `.fpx`       | FPXBASE source (modern extensions) |
| `.fph`       | Header (like Clipper `.ch`)        |
| `.ppo`       | Preprocessor output                |
| `.obj`       | Object file                        |
| `.lib`/`.a`  | Static library                     |
| `.dll`/`.so` | Dynamic library                    |
| `.exe`       | Native binary                      |

## Built-in Commands (from `std.fph`)

`?`, `??`, `@...SAY/GET`, `ACCEPT`, `WAIT`, `TEXT`, `KEYBOARD`, `RUN`, `QUIT`, `CANCEL`, and all FPXBASE extensions (network, tasks, ini, os, crypto, etc.) are wrapped as `#command` in `std.fph`, auto-included.

## Language Notes

- Case-insensitive keywords
- `END` can be suffixed: `ENDIF`, `ENDFOR`, `ENDDO`, `ENDCASE`, `ENDSWITCH`, etc.
- Preprocessor: `#command`/`#translate` / `#xcommand`/`#xtranslate` patterns
- FPXBASE extensions: embedded SQL (`EXECUTE SQL`), OOP, optional type annotations (`Identifier : DataType`)
- Standard header: `std.fph` (auto-included), user headers: `#include "file.fph"`

## Roadmap

See `docs/ROADMAP.md` for detailed phases, milestones, deliverables, and durations.

| Phase | Milestone                                       |
|-------|-------------------------------------------------|
| 0     | Parser + Lexer + AST (basic subset)             |
| 1     | IR gen + native backend (x86/x86_64, Win/Linux) |
| 2     | SQLite runtime driver                           |
| 3     | PostgreSQL + MSSQL drivers                      |
| 4     | LSP, formatter, full CLI, DAP debugger          |
| 5     | `fpx-dbf`, legacy mode, docs, package manager   |

## PRD Sections

The PRD (`docs/PRD-FPXBASE.md`) covers all features in detail:

- 5.1 Language, types, integers (8-128 bit signed/unsigned), arrays, hash, vector, stack, queue, set, range, MEMVAR, PICTURE, GET controls, STRUCT, smart pointers, generics, NEWTYPE, closures, yield, variadics, kwargs
- 5.2 What is NOT inherited from xBASE
- 5.3 DB drivers (SQLite default, PG/MSSQL optional)
- 5.4 DBF import/export
- 5.5 Platform targets
- 5.6 RTL (runtime library)
- 5.7 Network functions (TCP/UDP/HTTP/DNS)
- 5.8 Data formats (DBF, CSV, JSON, XML, XLSX, PDF, HTML, SDF, SQL)
- 5.9 Serial ports (RS-232/422/485)
- 5.10 Task system (TaskCreate, scheduler, thread pool, ParallelFor)
- 5.11 OS calls (processes, env, filesystem, ini/env files, registry)
- 5.12 Memory management (refcount, GC, manual)
- 5.13 Threads & concurrency (mutex, semaphore, channels, atomics)
- 5.14 Reports (compatible REPORT FORM + new engine)
- 5.15 Unicode & i18n (UTF-8, locales, gettext)
- 5.16 Extend system (C library calls via EXTERN)
- 5.17 Debugging (DAP + interactive, breakpoints, watches)
- 5.18 Profiling & optimization (-O0 to -O3, profile flags)
- 5.19 Unit testing (TestSuite, assertions)
- 5.20 Security (AES, ChaCha20, TLS, JWT, bcrypt, base64)
- 5.21 Event system (pub-sub)
- 5.22 Compiler error codes (FPX-nnnn)
- 5.23 Compiler warnings (FPW-nnnn, modernize suggestions)
- 5.24 Packaging (MSI, AppImage, zip, deploy)
- 5.25 Licensing (MIT)
