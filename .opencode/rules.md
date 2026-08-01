---
name: compiler-rules
description: Reglas de comportamiento para el desarrollo del compilador Free Pascal y su integración con OpenCode.
version: 1.0.0
tags: [rules, compiler, free-pascal, opencode, workflow]
---

# Reglas de Desarrollo para el Compilador Free Pascal (FPC) + OpenCode

## 1. Contexto del Proyecto

Este proyecto consiste en un compilador Free Pascal (FPC) que será utilizado y potenciado por el agente OpenCode.
El objetivo es mantener, optimizar y extender el compilador, garantizando alta calidad, rendimiento y compatibilidad multiplataforma.

## 2. Stack Tecnológico y Herramientas

- **Lenguaje principal**: Object Pascal (Free Pascal)
- **Backend**: Generación de código para x86, x86_64, ARM, AArch64
- **Pruebas**: Suites de pruebas oficiales de FPC (testsuite)
- **Control de versiones**: Git
- **Sistema de construcción**: make / fpcmake

## 3. Estándares de Código

- El código debe seguir las **convenciones de codificación de Free Pascal** (estilo de indentación, nombres de variables, comentarios en inglés).
- Usar siempre el modo `{$mode objfpc}` o `{$mode delphi}` según el módulo.
- Incluir comentarios que expliquen la lógica compleja, especialmente en el **parser**, **generador de código** y **optimizador**.
- No introducir cambios que rompan la compatibilidad con versiones anteriores del compilador sin una discusión previa.
- Preferir `advancedRecords` y `typeHelpers` cuando se use `{$mode objfpc}`.
- Evitar `{$mode delphi}` en unidades nuevas salvo compatibilidad estricta.

## 4. Workflow de Desarrollo (basado en Loops)

Todo cambio significativo debe seguir un bucle iterativo:

1. **Análisis y diseño**: Comprender el problema y proponer una solución.
2. **Implementación**: Escribir el código siguiendo los estándares.
3. **Pruebas**: Ejecutar el testsuite completo y, si es posible, agregar casos de prueba para la nueva funcionalidad.
4. **Evaluación**: Si las pruebas fallan, diagnosticar y corregir. Si pasan, proceder a la revisión.
5. **Revisión y refinamiento**: Obtener feedback (humano o automatizado) y realizar mejoras.
6. **Integración**: Fusionar los cambios en la rama principal después de una aprobación.

## 5. Reglas de Seguridad y Calidad

- No se debe generar código ensamblador sin validación previa del impacto en rendimiento y compatibilidad.
- Las optimizaciones deben ser probadas en múltiples arquitecturas antes de ser integradas.
- Cualquier cambio en el **parser** o el **analizador semántico** debe ser revisado por al menos otro desarrollador.
- Antes de modificar el parser, **ejecutar siempre el testsuite completo**.
- Priorizar la compatibilidad con el estándar **Object Pascal** sobre nuevas características experimentales.
- Proporcionar ejemplos de código en ensamblador junto con el Pascal equivalente para validar la optimización.

## 6. Integración con OpenCode

- El agente OpenCode debe usar este archivo de reglas como **guía principal** para todas las interacciones.
- Antes de generar código, debe consultar estas reglas para asegurar que cumple con los estándares.
- Puede utilizar el skill **"Senior-Compiler-Developer-FreePascal"** como complemento, pero **las reglas aquí definidas tienen prioridad** en caso de conflicto.

## 7. Comandos Útiles y Ejecución

| Acción                     | Comando                    |
|----------------------------|----------------------------|
| Construir el compilador    | `make clean all`           |
| Ejecutar todas las pruebas | `make test`                |
| Pruebas unitarias          | `make test-unit`           |
| Pruebas de integración     | `make test-integration`    |
| Pruebas de implementación  | `make test-implementation` |
| Pruebas IR                 | `make test-ir`             |
| Cobertura heurística       | `make test-coverage`       |
| Métricas de calidad        | `make test-quality`        |
| Instalar                   | `make install`             |
| Crear distribución         | `make dist`                |

## 8. Reglas de Commits y Mensajes

- Usar mensajes descriptivos en **inglés**.
- Incluir el **prefijo del área afectada** (ej: `[Parser]`, `[Optimizer]`, `[Backend]`, `[IR]`, `[Lexer]`, `[AST]`).
- Cada commit debe ser **atómico** (un cambio lógico por commit).
- Formato recomendado: `[Área] Breve descripción del cambio`

## 9. Plantilla para Nuevas Features

Al proponer o implementar una nueva funcionalidad:

1. **Motivación**: Describe el problema que resuelve.
2. **Enfoque técnico**: Explica la solución a alto nivel.
3. **Ejemplos de uso**: Incluye fragmentos de código Pascal que demuestren la feature.
4. **Casos de prueba**: Asegura que se agreguen pruebas unitarias y/o de integración.
5. **Impacto en rendimiento**: Documenta cualquier efecto esperado en tiempo de compilación o ejecución.

## 10. Problemas Conocidos y Workarounds

- **RETURN desnudo antes de palabra clave** (ej: `ENDFUNC`): El lexer no emite `ttNewline`, causando fallos en `ParseReturn`. Solución: tratar `RETURN` como desnudo cuando el siguiente token no puede iniciar una expresión.
- **Bucles del parser que verifican `ttNewline`** son código muerto (el lexer nunca lo emite). No agregar lógica que dependa de este token.

## 11. Referencias

- `docs/FXBASE-RULES.md` — Reglas obligatorias de estilo y contribución del proyecto
- `docs/FXBASE-GRAMMAR.md` — Especificación gramatical del lenguaje
- `src/fxb/` — Código fuente del compilador (unidades: `fxb.*.pas`)
- Punto de entrada: `src/fxb/fxb.lpr` → `fxb.cli` → `RunFXCLI`
- 