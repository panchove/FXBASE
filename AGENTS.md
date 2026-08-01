# Guía para Agentes de FXBASE

## Fuente

- El compilador vive en `src/fxb/` (unidades: `fxb.*.pas`).
- La mayoría de las unidades se compilan con modo `objfpc`.
- `fxb.lexer.pas` y `fxb.ir.pas` **no deben** usar `{$mode delphi}`; deben usar `{$mode objfpc}` con los switches `advancedRecords` y `typeHelpers`.
- Punto de entrada: `src/fxb/fxb.lpr` → usa `fxb.cli` → `RunFXCLI`.

## Construcción

- `make fxbc` (o `make all`) → construye `bin/fxbc`.
- `make clean` → elimina `build/` y `bin/fxbc*`.
- Siempre reconstruya después de editar; los archivos `.o/.ppu` obsoletos en `src/fxb/` pueden causar errores extraños (son ignorados por git).
- En sistemas no Debian/Ubuntu, ajuste `FPCFLAGS` en el Makefile (rutas de RTL y generics).

## Pruebas

- Unidad: `make test-unit` → `bin/test_tokens`, `bin/test_lexer`.
- Integración: `make test-integration` → `bin/test_pipeline`.
- Implementación: `make test-implementation` → `bin/test_impl`.
- IR: `make test-ir` → `bin/test_ir`.
- Todas las cuatro: `make test` (se detiene ante el primer conjunto fallido).
- Cobertura: `make test-coverage`.
- Calidad: `make test-quality`.
- Binarios individuales: `./bin/test_<nombre>`.
- El marco de pruebas es personalizado; una salida diferente de cero indica fallo.
- NOTA: `make test-all` / `run_all_tests.sh` están obsoletos (omiten el conjunto IR).

## Problemas Conocidos

- Un `RETURN` desnudo antes de una palabra clave (p. ej., `ENDFUNC`) se interpreta mal porque el lexer no emite token `ttNewline`. Esto hace que falle `TestIR_Return` (2 errores de parser). Solución: hacer que `ParseReturn` trate `RETURN` como desnudo cuando el siguiente token no puede iniciar una expresión, o agregar tokens de nueva línea reales.
- Los bucles del parser que verifican `ttNewline` son código muerto (el lexer nunca lo emite).

## Convenciones

- Las palabras clave no distinguen mayúsculas/minúsculas; se requieren variantes `END*` para desambiguar.
- Anotaciones de tipo: `name: T` o `name AS T` (también `AS ARRAY OF T`).
- Los bucles `FOR` se cierran con `NEXT` o `ENDFOR`.
- Archivos de fuente: `.prg` (xBASE legado) o `.fbg` (FXBASE); encabezados `.ch` o `.fbh`.
- Los comentarios están desalentados salvo que se soliciten (la base de código intencionalmente tiene pocos comentarios).

## Misceláneo

- Los comandos DB (`USE`, `INDEX`, etc.) se traducen en tiempo de compilación a SQL; no hay motor DBF en tiempo de ejecución.
- `make install` → `/usr/local/bin/fxbc`.
- `make dist` → crea un tarball (excluye `build/` y `bin/`).
- Consulte `docs/FXBASE-RULES.md` para las reglas obligatorias de estilo y contribución.

## Cobertura

- `make test-coverage` → genera `build/coverage_report.txt` (heurístico).
