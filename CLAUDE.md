---
name: compiler-rules-local
description: Reglas de comportamiento para el desarrollo del compilador Free Pascal con Hermes Agent en modo local.
version: 1.0.0
tags: [rules, compiler, free-pascal, hermes, local, offline]
---

# Reglas del Proyecto — Compilador Free Pascal (Local / Hermes)

> Guía de comportamiento para el agente Hermes (y desarrolladores humanos) cuando se
> trabaje en el desarrollo, optimización y mantenimiento del compilador Free Pascal (FPC)
> en un entorno 100% local, sin dependencias de APIs externas.
>
> Nota: este archivo es auto-detectado por Hermes Agent si se nombra `AGENTS.md`,
> `.hermes.md` o `CLAUDE.md` en la raíz del proyecto[reference:8]. Si tu repo ya tiene
> un `AGENTS.md` propio (p. ej. la guía de FXBASE de este repositorio), NO lo sobrescribas:
> mantén ambos y reconcília diferencias, o fusiona el contenido.

## 1. Contexto del Proyecto

- Este proyecto consiste en un compilador Free Pascal (FPC) que será utilizado y potenciado
  por el agente Hermes en un entorno completamente local.
- El objetivo es mantener, optimizar y extender el compilador, garantizando alta calidad,
  rendimiento y compatibilidad multiplataforma, **sin dependencia de APIs externas**.
- Todo el ciclo de vida (análisis, edición, compilación, pruebas, revisión) ocurre en la
  máquina del usuario. No se envía código ni telemetría a servicios remotos.

## 2. Stack Tecnológico y Herramientas (Local-First)

- **Lenguaje principal:** Object Pascal (Free Pascal / FPC).
- **Backend / codegen:** generación de código para `x86`, `x86_64`, `ARM` y `AArch64`.
- **Pruebas:** testsuite oficial de FPC (`make tests` en un checkout de FPC) o la suite de
  pruebas del proyecto anfitrión. Para ESTE repo consulta `AGENTS.md` (usa `make test`).
- **Control de versiones:** Git.
- **Sistema de construcción:** `make` / `fpcmake` (y `fpmake` donde aplique).
- **Modelo local:** Ollama con modelos como `gemma4` (~16 GB VRAM) o `qwen3.6` (~24 GB VRAM)
  para asistencia de codificación[reference:5][reference:6]. No se requieren API keys[reference:13].

## 3. Estándares de Código

- Seguir las convenciones de codificación de Free Pascal: indentación consistente (2 o 3
  espacios, sin tabs mezclados), nombres de variables/tipos claros y comentarios en **inglés**.
- Usar siempre el modo de compilación explícito al inicio de cada unidad:
  `{$mode objfpc}` o `{$mode delphi}`, según corresponda al módulo.
- Incluir comentarios que expliquen la lógica compleja, **especialmente** en el parser, el
  generador de código (codegen) y el optimizador.
- No introducir cambios que rompan la compatibilidad con versiones anteriores del compilador
  sin una discusión previa y un periodo de aviso (`deprecated`).
- Mantener la portabilidad: evitar directivas o RTL ligadas a una sola plataforma salvo que
  estén correctamente protegidas con `{$ifdef}`.

## 4. Workflow de Desarrollo (basado en Loops Locales)

Todo cambio significativo debe seguir un bucle iterativo, aprovechando que Hermes puede
ejecutar comandos y editar archivos localmente[reference:7]:

1. **Análisis y diseño** — Comprender el problema y proponer una solución (incluir el "por qué").
2. **Implementación** — Escribir el código siguiendo los estándares de la sección 3.
3. **Pruebas** — Ejecutar la testsuite (`make tests` en FPC, o `make test` en este repo) y,
   si es posible, agregar casos de prueba para la nueva funcionalidad.
4. **Evaluación** — Si las pruebas fallan, diagnosticar y corregir. Si pasan, continuar a revisión.
5. **Revisión y refinamiento** — Obtener feedback (humano o mediante herramientas locales) y
   realizar mejoras.
6. **Integración** — Fusionar los cambios en la rama principal tras aprobación.

> Regla práctica: tras cada edición de unidades Pascal, **reconstruir antes de probar**.
> Los `.o`/`.ppu` obsoletos generan errores confusos (ver guía de FXBASE en `AGENTS.md`).

## 5. Reglas de Seguridad y Calidad (Entorno Local)

- No generar código ensamblador (`asm` inline o emitido por el codegen) sin validación previa
  del impacto en rendimiento y compatibilidad de la arquitectura objetivo.
- Las optimizaciones deben probarse en **múltiples arquitecturas** (al menos x86_64 y ARM/AArch64)
  antes de integrarse.
- Cualquier cambio en el parser o en el analizador semántico debe ser revisado por al menos otro
  desarrollador (o validado por una segunda pasada de pruebas/regresión).
- Asegurar que los archivos generados no contengan **rutas absolutas** que rompan la portabilidad
  (usar rutas relativas y variables de entorno).

## 6. Integración con Hermes Agent

- Hermes debe usar este archivo de reglas como guía principal para todas las interacciones. Lo
  descubre automáticamente si se llama `AGENTS.md`, `.hermes.md` o `CLAUDE.md`[reference:8].
- Antes de generar código, Hermes debe consultar estas reglas para asegurar el cumplimiento.
- Hermes puede usar sus skills incorporados para edición de archivos, ejecución de comandos y
  navegación, siempre respetando estas reglas[reference:9].
- La memoria persistente de Hermes (`MEMORY.md` / `USER.md`) puede usarse para recordar
  preferencias específicas del proyecto entre sesiones[reference:10].

## 7. Comandos Útiles y Ejecución Local

**Para un checkout de FPC (proyecto genérico):**
- Construir el compilador: `make clean all`
- Ejecutar pruebas: `make tests`
- Ejecutar una prueba específica: `make test TEST=<nombre_del_test>`
- Generar documentación: `make docs`

**Para ESTE repo (FXBASE) — ver `AGENTS.md`:**
- Construir: `make fxbc` (o `make all`) → `bin/fxbc`
- Pruebas completas: `make test` (unit + integration + implementation + IR)
- Limpiar: `make clean`
- Instalar: `make install` → `/usr/local/bin/fxbc`

**Lanzar Hermes con modelo local (Ollama):**
- `hermes chat --provider ollama --model gemma4`[reference:11]
- Hermes auto-detecta los modelos descargados en Ollama[reference:14].

## 8. Reglas de Commits y Mensajes

- Mensajes descriptivos en **inglés**.
- Incluir el prefijo del área afectada: `[Parser]`, `[Optimizer]`, `[Backend]`, `[RTL]`, etc.
- Cada commit debe ser **atómico** (un cambio lógico por commit).
- Mencionar el número de issue/regression cuando aplique.

## 9. Plantilla para Nuevas Features

Toda nueva funcionalidad debe documentarse con:

- **Motivación:** por qué se necesita y qué problema resuelve.
- **Enfoque técnico:** descripción de la implementación y puntos de extensión.
- **Ejemplos de uso:** fragmento de código Pascal que ejercite la feature.
- **Pruebas:** casos de prueba agregados a la suite correspondiente.

## 10. Consideraciones para el Entorno Local

- Hermes no recopila telemetría; todas las conversaciones, memoria y skills se almacenan
  localmente en `~/.hermes/`[reference:12].
- No se requieren API keys para modelos locales con Ollama[reference:13].
- Hermes auto-detecta los modelos descargados en Ollama[reference:14]; verifica con
  `ollama list` antes de lanzar el agente.
- Mantén el proyecto reproducible sin red: todas las dependencias (FPC, Ollama, modelos)
  deben resolverse localmente.

---

### Referencias
Las marcas `[reference:N]` corresponden a la documentación de Hermes Agent del documento
fuente proporcionado por el usuario (detección de archivos de contexto, skills, memoria y
modelos locales con Ollama).
