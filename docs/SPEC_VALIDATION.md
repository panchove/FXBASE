# FXBASE — Lista de Validación de Especificaciones

**Versión:** 1.0.0-alpha  
**Fecha:** 2026-08-08  
**Propósito:** Validación manual de que los cuatro documentos de especificación son consistentes, completos y correctamente referenciados.

> Ejecutar esta lista tras cualquier cambio en las specs. Todos los ítems deben pasar antes de bump de versión.

---

## 1. Consistencia Versión y Metadatos

| Verificación | PRD | GRAMMAR | ARCH | SPEC | Pass |
|--------------|-----|---------|------|------|------|
| Versión = `1.0.0-alpha` | ☐ | ☐ | ☐ | ☐ | ☐ |
| Fecha = `2026-08-08` | ☐ | ☐ | ☐ | ☐ | ☐ |
| Formato cabecera versión coincide | ☐ | ☐ | ☐ | ☐ | ☐ |

---

## 2. Validación Orden Dependencias

| Dependencia | Verificación | Pass |
|-------------|--------------|------|
| GRAMMAR solo depende de PRD | Ninguna feature PRD falta en GRAMMAR | ☐ |
| ARCH depende de PRD + GRAMMAR | Ninguna sintaxis GRAMMAR no implementada en ARCH | ☐ |
| SPEC depende de PRD + GRAMMAR + ARCH | Ningún componente ARCH sin semántica SPEC | ☐ |

---

## 3. Cobertura Features Lenguaje (PRD ↔ GRAMMAR)

### 3.1 Lenguaje Core (PRD §2.1)

| Sección PRD | Feature | Producción GRAMMAR | Semántica SPEC | Pass |
|-------------|---------|-------------------|----------------|------|
| 2.1.1 | 13 tipos datos | §2.5 Literales, §3.11 Ref Tipos | §2.1.1 Universo Tipos | ☐ |
| 2.1.2 | Tipado gradual (`#STRICT`) | §5 Modo Estricto | §2.1.3 Semántica Gradual | ☐ |
| 2.1.3 | 4 clases almacenamiento | §3.11 Sentencias Var | §2.2 Clases Almacenamiento | ☐ |
| 2.1.4 | Estructuras control | §3.12 Sentencias | §2.3 Control Flujo | ☐ |
| 2.1.5 | Funciones/procedimientos | §3.6 Decl Función | §2.4 Semántica Funciones | ☐ |
| 2.1.6 | POO (CLASS/INHERIT) | §3.7 Decl Clase | §2.6 Modelo Objetos | ☐ |
| 2.1.7 | CodeBlocks | §2.5 Literales CodeBlock | §2.1.1 Universo Tipos | ☐ |
| 2.1.8 | Macros (`&` / `COMPILE<>`) | §2.5 Expr Macro/Compile | §2.9 Semántica Macros | ☐ |

### 3.2 Módulos y Concurrencia

| Sección PRD | Feature | GRAMMAR | SPEC | Pass |
|-------------|---------|---------|------|------|
| 2.2 | MODULE/IMPORT/EXPORT/HIDDEN | §3.2-3.3 | (implícito) | ☐ |
| 2.3 | CSP (SPAWN/AWAIT/CHANNEL/SELECT) | §3.12 Concurrencia | §2.5 Concurrencia | ☐ |

### 3.3 Base Datos y UI

| Sección PRD | Feature | GRAMMAR | SPEC | Pass |
|-------------|---------|---------|------|------|
| 2.5 | RDD 2.0 (USE/SEEK/LOCATE/REPLACE) | §3.12 Sentencias DB | §2.8 Semántica RDD | ☐ |
| 2.6 | FORM/GET/READ 2.0 | §3.12 Sentencias Form | (UI spec en SPEC §3.6) | ☐ |

### 3.4 Migración (PRD §2.10)

| Item PRD | GRAMMAR | ARCH | SPEC | Pass |
|----------|---------|------|------|------|
| Estrategia 4 fases | — | §3 Transpilador | §5 Transpilador | ☐ |
| Códigos riesgo (4 códigos) | §7.2 Anotaciones migración | §3.1 Detección Riesgos | §5.2-5.3 Reglas/Reporte | ☐ |
| Modo `--legacy` | §5 Extensiones Legacy | — | §4.1 CLI | ☐ |

---

## 4. Consistencia Palabras Clave y Tokens

| Verificación | Ubicación | Pass |
|--------------|-----------|------|
| 58 keywords coinciden exactamente | PRD §5.1 = GRAMMAR §2.3 | ☐ |
| Tabla precedencia operadores | PRD §5.2 = GRAMMAR §4 | ☐ |
| Formas literales cubiertas | PRD §5.3 = GRAMMAR §2.5 | ☐ |

---

## 5. Alineación Arquitectura ↔ Especificación

| Componente ARCH | Cobertura SPEC | Pass |
|-----------------|----------------|------|
| Frontend (lexer/parser/resolver/typechecker) | §4 Compiler CLI + §2 Semántica | ☐ |
| FX-IR + Optimizador | (interno) | ☐ |
| 4 Backends (C/LLVM/WASM/VM) | §4.1 `--target` | ☐ |
| GC Generacional | §6.2 Límites Memoria | ☐ |
| Planificador M:N + Canales | §2.5 Concurrencia | ☐ |
| RDD 2.0 trait + drivers | §2.8 + §3.4 APIs RDD | ☐ |
| FXSTD 12 módulos | §3 Especificación APIs FXSTD | ☐ |
| CLI (13 comandos) | §4.1 Comandos | ☐ |
| fxpkg (PubGrub) | §9 Gestor Paquetes | ☐ |
| LSP (10 capacidades) | §10 Especificación LSP | ☐ |

---

## 6. Alineación Códigos Riesgo (Canónico: PRD)

| Código | Patrón | PRD | GRAMMAR | ARCH | SPEC | Pass |
|--------|--------|-----|---------|------|------|------|
| RIESGO-101 | `&macro` sin tipos | ☐ | ☐ | ☐ | ☐ | ☐ |
| RIESGO-202 | Variables PUBLIC/PRIVATE | ☐ | ☐ | ☐ | ☐ | ☐ |
| RIESGO-303 | Tipado implícito crítico | ☐ | ☐ | ☐ | ☐ | ☐ |
| RIESGO-404 | SET EXACT/SOFTSEEK OFF | ☐ | ☐ | ☐ | ☐ | ☐ |

---

## 7. Completitud APIs FXSTD (ARCH §5 ↔ SPEC §3)

| Módulo ARCH | Sección SPEC | Pass |
|-------------|--------------|------|
| core/types (Result, Optional, Channel, Variant) | §3.1.1-3.1.3 | ☐ |
| core/errors | (implícito) | ☐ |
| core/memory (UNSAFE) | §2.9.3 | ☐ |
| collections/array | §3.2.1 | ☐ |
| collections/hash | §3.2.2 | ☐ |
| io/file + path + stream | §3.3 | ☐ |
| db/connection + rdd_* | §3.4 | ☐ |
| net/http + tcp + ws | (no fully spec'd) | ☐ |
| concurrencia/task + channel + select | §3.5 | ☐ |
| ui/form + backends | §3.6 | ☐ |
| crypto/hash + cipher | (no spec'd) | ☐ |
| json/json | (no spec'd) | ☐ |
| testing/assert + runner | §8 Testing | ☐ |

---

## 8. Integridad Referencias Cruzadas

| Referencia | Objetivo Existe | Pass |
|------------|-----------------|------|
| Cada `fxstd/xxx` en ARCH §5 tiene API SPEC §3 | | ☐ |
| Cada comando CLI en SPEC §4.1 tiene ARCH §6.1 | | ☐ |
| Cada comando RDD en PRD §2.5.2 tiene SPEC §2.8.2 | | ☐ |
| Cada no-terminal GRAMMAR usado en ejemplos | | ☐ |
| Cada regla semántica SPEC tiene sintaxis GRAMMAR | | ☐ |

---

## 9. Formato y Convenciones

| Convención | Verificación | Pass |
|------------|--------------|------|
| Fechas ISO 8601 (`YYYY-MM-DD`) | Todas cabeceras + tablas | ☐ |
| RFC 2119 (MUST/SHOULD/MAY) solo en SPEC | Sin RFC keywords en PRD/GRAMMAR/ARCH | ☐ |
| Sintaxis EBNF: `::=` `|` `[ ]` `{ }` `( )` `" "` | GRAMMAR consistente | ☐ |
| Diagramas Mermaid renderizan | Diagramas ARCH válidos | ☐ |
| Bloques código con language-tag | `fxbase`, `bash`, `json`, `toml`, `fxbase` | ☐ |

---

## 10. Estructura Documentos

| Doc | Secciones Requeridas Presentes | Pass |
|-----|-------------------------------|------|
| PRD | Visión, Reqs (Func/No-Func), Resumen Arch, Resumen Sintaxis, Roadmap, DoD, Glosario, Refs | ☐ |
| GRAMMAR | Notación, Léxico, Sintaxis, Precedencia, Strict/Legacy, Validación, Errores, Historial Versiones | ☐ |
| ARCH | Visión, Pipeline Compilador, Transpilador, Runtime, FXSTD, Herramientas, Transversales, Despliegue, Estructura, Integración, Extensiones, Matriz Versiones | ☐ |
| SPEC | Alcance/Conformidad, Semántica, APIs FXSTD, CLI Compilador, Transpilador, Runtime, Interop, Testing, fxpkg, LSP, Versionado, Rendimiento, Seguridad, Suite Conformidad | ☐ |

---

## 11. Firma

| Rol | Nombre | Fecha | Firma |
|-----|--------|-------|-------|
| Autor Spec | | | |
| Revisión Arquitectura | | | |
| Revisión Diseño Lenguaje | | | |

---

## Notas Automatización (Futuro)

Cuando exista tooling, estas verificaciones pueden automatizarse:

```bash
# Consistencia versión
grep -h "Versión:" docs/*.md | sort -u  # debe retornar 1 línea

# Conteo keywords
grep -A 30 "Palabras Reservadas" docs/FXBASE_PRD_v1.0.0.md | grep -o '[A-Z_][A-Z_]*' | sort | uniq -c
grep "PALABRA_CLAVE ::" docs/FXBASE_GRAMMAR.md | sed 's/.*::= //' | tr '|' '\n' | tr -d "' " | sort | uniq -c

# Códigos riesgo
grep -o "RIESGO-[0-9]*" docs/*.md | sort -u

# Cross-ref: cada módulo fxstd en ARCH tiene API SPEC
grep -o "fxstd/[a-z_]*" docs/FXBASE_ARCH.md | sort -u | while read m; do
  grep -q "$m" docs/FXBASE_SPEC.md || echo "FALTANTE: $m"
done
```

---

*Fin Lista Validación Especificaciones*