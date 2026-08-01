# Reglas de desarrollo de FXBASE

Estas reglas deben cumplirse en todo momento al trabajar en el repositorio de FXBASE.

## 1. Conducta general

- **Sé conciso y directo** – Proporciona la cantidad mínima de información necesaria para responder la pregunta o completar la tarea.
- **No añadas comentarios no solicitados** – Solo agrega comentarios de código cuando el usuario lo solicite explícitamente.
- **Mantente enfocado en la tarea** – No introduzcas cambios o reestructuraciones no relacionados a menos que formen parte del trabajo solicitado.

## 2. Estilo y convenciones de código

- **Coincide con el modo de la unidad existente** – La mayoría de las unidades usan {$mode objfpc}{$H+}. Actualmente, fxb.lexer.pas y fxb.ir.pas utilizan {$mode delphi} como legado, pero están sujetos a la regla 4 que prohíbe su uso en nuevo código y planea migrarlos a {$mode objfpc} con los switches apropiados.
- **Sigue las convenciones de nombres** – Usa el estilo de denominación existente (p. ej., `TTokenType`, `TKeyword`, `TToken`, `KeywordFromString`).
- **Preserva el formato** – Mantén la indentación, el espacio y los finales de línea consistentes con el código circundante.
- **No cambies los encabezados de archivo** – Mantén los comentarios de licencia/cabezal existentes sin tocar, a menos que se indique lo contrario.

## 3. Dependencias y exportaciones de unidades

- **Usa la cláusula `uses` exactamente como se muestra en las unidades existentes** – No agregues ni elimines unidades a menos que sea necesario para el cambio.
- **Al volver a exportar tipos de sub-unidades, usa alias de tipo directos** (por ejemplo, `TASTNode = fpx.ast.base.TASTNode;`). No inventes prefijos como `TS_` a menos que ya existan en la base de código.
- **Mantén la sección de interfaz mínima** – Expón solo los tipos, constantes, variables y procedimientos/funciones que realmente sean necesarios para otras unidades.

## 4. Compilación y compilación

- **Siempre ejecuta `make clean` antes de compilar** al diagnosticar errores de construcción extraños para evitar archivos `.o`/`.ppu` obsoletos.
- **Nunca confirmes objetos compilados** (`*.o`, `*.ppu`) ni ejecutables en el repositorio. Pertenecen únicamente a los directorios `build/` y `bin/`.
- **Los binarios generados por `make fpx` y similares se colocan en la carpeta `bin/`; no los muevas ni los copies fuera de allí a menos que sea para pruebas externas.**
- **Respeta los objetivos de Makefile** – Usa `make fpx`, `make test`, `make clean`, etc., según se define.

## 5. Pruebas

- **Todos los cambios**
  - Ejecuta el conjunto completo de pruebas con `make test` después de cualquier cambio.
  - Si una prueba falla, corrige el código antes de continuar; no confirmes código roto.
  - Al agregar nueva funcionalidad, agrega pruebas unitarias correspondientes en el conjunto de pruebas adecuado (`tests/unit/`, `tests/integration/`, `tests/implementation/`, `tests/ir/`).
- **Afirmaciones de prueba** – Usa el marco de pruebas proporcionado (`AssertEquals`, `AssertTrue`, etc.) y evita `assert` o manejo de errores personalizado a menos que se especifique.

## 6. Documentación

- **Actualiza la documentación solo cuando se solicite** – No agregues ni modifiques archivos `.md` a menos que la tarea lo pida explícitamente.
- **Cuando se actualice la documentación, sigue el estilo existente** – Utiliza encabezados de sección claros, cercados de código para ejemplos y mantén el lenguaje conciso.
- **Mantén el archivo `AGENTS.md` actualizado** – Es la única fuente de verdad para las instrucciones específicas del agente.

## 7. Control de versiones

- **Los mensajes de confirmación deben ser claros e imperativos** – Por ejemplo, "Corregir exportación de tipo AST duplicada palabra clave tipo" en lugar de "Se corrigió algo".
- **Nunca confirmes secretos, claves o contraseñas** – Si agregas accidentalmente estos datos, modifica la confirmación inmediatamente.
- **Extrae antes de empujar** – Asegúrate de que tu rama local esté actualizada con `origin/main` para evitar conflictos de fusión innecesarios.
- **No crear ramas innecesarias** – Trabaja directamente en `main` a menos que se solicite explícitamente una rama de característica.

## 8. Reglas específicas del lenguaje (Free Pascal)

- **Usa `Advance`/`Peek` correctamente** – El lexer **no** emite tokens `ttNewline`; confía en el reconocimiento de palabras clave para los límites de las sentencias.
- **Maneja las anotaciones de tipo `AS`** – Ambos formularios `: T` y `AS T` son válidos en declaraciones de variables y parámetros de rutina.
- **Recuerda que los sufijos `END` son obligatorios** – `ENDIF`, `ENDDO`, `ENDCASE`, `ENDSWITCH`, `ENDCLASS`, etc., para desambiguar el analizador.
- **Los bucles `FOR` se cierran con `NEXT` así como con `ENDFOR`** – Trata `NEXT` como `kwNext`.
- **La palabra clave `NIL` emite `ttNil`** – No `ttKeyword + kwNil`.
- **Los literales lógicos `.T.`/`.F.` emiten `ttLogical`** con `IntValue` 1/0.
- **Las cadenas entre corchetes `[texto]` son compatibles** – Manejadas mediante `ScanString` con reasignación de delimitador.
- **Los operadores `.AND.`, `.OR.`, `.NOT.`, `.XOR.` son tokens únicos** (`ttDotAnd`, `ttDotOr`, `ttDotNot`, `ttXor`).

## 9. Acciones prohibidas

- ❌ Añadir comentarios sin que se lo pidan.
- ❌ Cambiar el encabezado de licencia.
- ❌ Modificar archivos fuera del directorio `src/fpx/` a menos que la tarea lo requiera explícitamente.
- ❌ Introducir bibliotecas de terceros sin verificar primero su uso existente.
- ❌ Usar los patrones `cd <dir> && <command>` – siempre usa el parámetro `workdir` de la herramienta `bash` en su lugar.
- ❌ Suponer que una biblioteca está disponible – verifica su uso en la base de código antes de depender de ella.
- ❌ Generar archivos ejecutables u objetos dentro de src/ o sus subcarpetas; todos los compilados deben ir a build/ o bin/.

## 10. En caso de duda

- Pide aclaraciones utilizando la herramienta `question` antes de continuar.
- Consulta el código existente como referencia principal para estilo y patrones.
- Si una regla entra en conflicto con otra, sigue la regla más específica (por ejemplo, el modo específico de una unidad anula la regla general de modo).

Cumplir estas reglas garantiza una base de código limpia, consistente y mantenible para FXBASE.

## 4. Modo del compilador

- **Prohibido usar `{$mode delphi}`** – Todas las unidades deben usar `{$mode objfpc}` excepto cuando sea absolutamente necesario utilizar características del lenguaje Delphi. En esos casos, se deben utilizar los modificadores `{$modeSwitch advancedRecords}` y `{$modeSwitch typeHandlers}` en conjunto con `{$mode objfpc}`. Actualmente, `fxb.lexer.pas` y `fxb.ir.pas` utilizan `{$mode delphi}` como legado, pero se planea migrarlos a `objfpc` con los switches apropiados en futuras versiones.
