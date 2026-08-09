# Especificación Lenguaje FXBASE

> **Versión:** 1.0.0-alpha  
> **Estado:** Borrador para revisión técnica  
> **Fecha:** 2026-08-08

Este repositorio contiene la **especificación formal completa** del lenguaje de programación FXBASE — un lenguaje moderno, compilado, inspirado en la productividad de xBase/Clipper/xHarbour, rediseñado con la seguridad y concurrencia de Rust/Go/TypeScript.

---

## Documentos (Leer en Orden)

| # | Documento | Propósito |
|---|-----------|-----------|
| 1 | [PRD](docs/FXBASE_PRD_v1.0.0.md) | Requisitos de Producto — features, alcance, roadmap |
| 2 | [GRAMMAR](docs/FXBASE_GRAMMAR.md) | Especificación formal sintaxis EBNF |
| 3 | [ARCH](docs/FXBASE_ARCH.md) | Arquitectura sistema: compilador, runtime, tooling |
| 4 | [SPEC](docs/FXBASE_SPEC.md) | Especificación técnica: semántica, APIs, CLI, conformidad |

**Empezar por el [PRD](docs/FXBASE_PRD_v1.0.0.md)** — es la fuente de verdad.

---

## Resumen del Lenguaje

- **Tipado gradual** — dinámico por defecto, modo estricto opt-in (`#STRICT`)
- **Concurrencia CSP** — tareas ligeras, canales tipados, `SELECT` multiplexación
- **Memory safe** — GC generacional, sin punteros crudos en código seguro
- **Migración xBase** — transpilador integrado (`fxbase migrate`) con salida anotada por riesgos
- **Multi-backend** — C, LLVM, WASM, bytecode VM
- **RDD 2.0** — Bases de datos SQL vía comandos estilo xBase (`USE`, `SEEK`, `LOCATE`, `REPLACE`)
- **Tooling moderno** — `fxbase` CLI, `fxpkg` gestor paquetes, LSP, formateador, REPL

---

## Ejemplo Rápido

```fxbase
#STRICT

MODULE Facturacion

IMPORT Database FROM "fxstd/db"
IMPORT { Result } FROM "fxstd/core"

EXPORT FUNCTION CalcularIVA(nMonto: DECIMAL) -> Result<DECIMAL, STRING> {
    SI nMonto < 0 { RETORNA Err("Monto no puede ser negativo") }
    RETORNA Ok(nMonto * 0.16)
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

    METODO AgregarItem(item: Item) {
        SELF.items.push(item)
        SELF.total += item.precio * item.cantidad
    }

    ACCESS ConIVA: DECIMAL {
        RETORNA SELF.total * 1.16
    }
}

// Concurrencia
ASYNC FUNCTION ProcesarLote(lotes: ARRAY<Lote>) {
    LOCAL ch := Channel<Lote>(100)
    
    // Productor
    SPAWN {
        FOREACH l EN lotes { ch <- l }
        CLOSE(ch)
    }
    
    // Consumidores
    PARA i := 1 HASTA 4 {
        SPAWN {
            MIENTRAS VERDADERO {
                MATCH <-ch {
                    CASO NONE => BREAK
                    CASO l: Lote => Guardar(l)
                }
            }
        }
    }
    
    WAIT ALL
}
```

---

## Convenciones Repositorio

- Los cuatro documentos de especificación comparten versión `1.0.0-alpha` (incrementar juntos)
- Fechas: ISO 8601 (`YYYY-MM-DD`)
- EBNF en GRAMMAR usa `::=`, `|`, `[ ]`, `{ }`, `( )`, `" "`
- Diagramas: bloques markdown compatibles Mermaid

---

## Proyectos Relacionados (No en Este Repo)

| Proyecto | Estado |
|----------|--------|
| Implementación compilador | Planeado (repo separado) |
| Biblioteca estándar (FXSTD) | Planeado (repo separado) |
| Registro paquetes | Planeado (servicio separado) |

---

## Licencia

MIT — ver [LICENSE](LICENSE) (por añadir)