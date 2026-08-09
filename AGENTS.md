# AGENTS.md — Repositorio Especificaciones FXBASE

## Propósito del Repositorio
Este repo contiene **únicamente los documentos de especificación** del lenguaje de programación FXBASE. No existe código de implementación aquí.

## Estructura Documentos (el orden de carga importa)

| Archivo | Rol | Depende De |
|---------|-----|------------|
| `FXBASE_PRD_v1.0.0.md` | Requisitos de Producto — fuente de verdad para features | — |
| `FXBASE_GRAMMAR.md` | Especificación formal sintaxis EBNF | PRD |
| `FXBASE_ARCH.md` | Arquitectura sistema (compilador, runtime, tooling) | PRD, GRAMMAR |
| `FXBASE_SPEC.md` | Especificación técnica (semántica, APIs, CLI, conformidad) | PRD, GRAMMAR, ARCH |

**Regla:** Al actualizar un documento, verificar consistencia con sus dependencias.

## Trabajo con Este Repo

### Flujo Edición
1. Leer los documentos dependientes primero (ver tabla arriba)
2. Hacer cambios al documento objetivo
3. Verificar secciones afectadas en documentos dependientes
4. Actualizar versión/fecha en cabeceras del archivo modificado

### Validación
No existe validación automatizada. Verificaciones manuales:
- Producciones gramaticales coinciden con features del lenguaje en PRD
- Componentes arquitectura cubren todos subsistemas SPEC
- CLI SPEC coincide con diseño tooling ARCH
- Números de versión consistentes en los cuatro archivos

### Versionado
Los cuatro documentos comparten la misma versión (actualmente `1.0.0-alpha`). Incrementar juntos.

## Convenciones
- Fechas: ISO 8601 (`YYYY-MM-DD`)
- Palabras clave RFC 2119 (MUST/SHOULD/MAY) solo en SPEC
- EBNF en GRAMMAR usa `::=`, `|`, `[ ]`, `{ }`, `( )`, `" "`
- Diagramas: bloques markdown compatibles Mermaid

## Qué NO Hacer
- No añadir código de implementación aquí
- No crear subdirectorios bajo `docs/`
- No commitear artefactos generados

## Repositorios Relacionados (no en este repo)
- Implementación compilador: repo separado (TBD)
- Biblioteca estándar (FXSTD): repo separado (TBD)
- Registro paquetes: servicio separado