# FXBASE Language Specification

> **Version:** 1.0.0-alpha  
> **Status:** Draft for technical review  
> **Date:** 2026-08-08

This repository contains the **complete formal specification** for the FXBASE programming language — a modern, compiled language inspired by xBase/Clipper/xHarbour productivity, redesigned with Rust/Go/TypeScript safety and concurrency.

---

## Documents (Read in Order)

| # | Document | Purpose |
|---|----------|---------|
| 1 | [PRD](docs/FXBASE_PRD_v1.0.0.md) | Product Requirements — features, scope, roadmap |
| 2 | [GRAMMAR](docs/FXBASE_GRAMMAR.md) | Formal EBNF syntax specification |
| 3 | [ARCH](docs/FXBASE_ARCH.md) | System architecture: compiler, runtime, tooling |
| 4 | [SPEC](docs/FXBASE_SPEC.md) | Technical spec: semantics, APIs, CLI, conformance |

**Start with the [PRD](docs/FXBASE_PRD_v1.0.0.md)** — it's the source of truth.

---

## Language Highlights

- **Gradual typing** — dynamic by default, opt-in strict mode (`#STRICT`)
- **CSP concurrency** — lightweight tasks, typed channels, `SELECT` multiplexing
- **Memory safe** — generational GC, no raw pointers in safe code
- **xBase migration** — built-in transpilator (`fxbase migrate`) with risk-annotated output
- **Multi-backend** — C, LLVM, WASM, bytecode VM
- **RDD 2.0** — SQL databases via xBase-style commands (`USE`, `SEEK`, `LOCATE`, `REPLACE`)
- **Modern tooling** — `fxbase` CLI, `fxpkg` package manager, LSP, formatter, REPL

---

## Quick Example

```fxbase
#STRICT

MODULE Facturacion

IMPORT Database FROM "fxstd/db"
IMPORT { Result } FROM "fxstd/core"

EXPORT FUNCTION CalcularIVA(nMonto: DECIMAL) -> Result<DECIMAL, STRING> {
    IF nMonto < 0 { RETURN Err("Monto no puede ser negativo") }
    RETURN Ok(nMonto * 0.16)
}

CLASS Factura {
    PROPERTY cliente: STRING
    PROPERTY items: ARRAY<Item>
    PROPERTY total: DECIMAL

    CONSTRUCTOR(cliente: STRING) {
        SELF.cliente = cliente
        SELF.items = []
        SELF.total = 0
    }

    METHOD AgregarItem(item: Item) {
        SELF.items.push(item)
        SELF.total += item.precio * item.cantidad
    }

    ACCESS ConIVA: DECIMAL {
        RETURN SELF.total * 1.16
    }
}

// Concurrency
ASYNC FUNCTION ProcesarLote(lotes: ARRAY<Lote>) {
    LOCAL ch := Channel<Lote>(100)
    
    // Producer
    SPAWN {
        FOREACH l IN lotes { ch <- l }
        CLOSE(ch)
    }
    
    // Consumers
    FOR i := 1 TO 4 {
        SPAWN {
            WHILE TRUE {
                MATCH <-ch {
                    CASE NONE => BREAK
                    CASE l: Lote => Guardar(l)
                }
            }
        }
    }
    
    WAIT ALL
}
```

---

## Repository Conventions

- All four spec documents share version `1.0.0-alpha` (increment together)
- Dates: ISO 8601 (`YYYY-MM-DD`)
- EBNF in GRAMMAR uses `::=`, `|`, `[ ]`, `{ }`, `( )`, `" "`
- Diagrams: Mermaid-compatible markdown fenced blocks

---

## Related Projects (Not in This Repo)

| Project | Status |
|---------|--------|
| Compiler implementation | Planned (separate repo) |
| Standard library (FXSTD) | Planned (separate repo) |
| Package registry | Planned (separate service) |

---

## License

MIT — see [LICENSE](LICENSE) (to be added)