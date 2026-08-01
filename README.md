# FXBASE

![Coverage](https://img.shields.io/badge/coverage-80%25-brightgreen)

FXBASE es un compilador de código abierto para la familia de lenguajes xBase (Clipper, Harbour, FoxPro, etc.). Traduce archivos fuente clásicos xBase (`.prg`) y extensiones modernas de FXBASE (`.fbg`) a ejecutables nativos mediante la emisión de código compatible con SQL a través de una representación intermedia (IR) y un backend enchufable. El proyecto está escrito en Free Pascal y sigue una arquitectura modular basada en pases:

- **Lexer** (`fxb.lexer.pas`) – tokeniza el código fuente, soporta sintaxis clásica y moderna.
- **Parser** (`fxb.parser.pas`) – construye un árbol sintáctico abstracto (AST).
- **Análisis semántico y generación de IR** (`fxb.ir.pas`) – reduce el AST a una representación intermedia de tres direcciones tipada.
- **Backend** (`fxb.backend.pas`) – convierte IR a código objeto/ensamblaje del objetivo (actualmente es un stub, la generación de SQL se realiza en tiempo de compilación).
- **Preprocesador** (`fxb.preprocessor.pas`) – maneja `#include`, `#define`, `#command`, etc.
- **CLI** (`fxb.cli.pas`) – interfaz de usuario (`comando fxb`) con opciones para tipo de salida, compilación cruzada, drivers de base de datos, depuración, y más.

## Objetivos

1. **Compatibilidad fiel con xBase** – soportar el dialecto legado completo (palabras clave insensibles a mayúsculas/minúsculas, delimitadores `END*`, tipos de datos tradicionales, comandos DB) mientras se marcan construcciones obsoletas.
2. **Extensiones modernas del lenguaje** – tipado estático opcional (`name: T` o `name AS T`), genéricos, acceso seguro a nulos, structs/clases, punteros inteligentes y SQL embebido.
3. **Generación de código agnóstica a la base de datos** – reemplazar el runtime DBF heredado por traducción a SQL en tiempo de compilación, permitiendo despliegue en cualquier RDBMS moderno (SQLite, PostgreSQL, MSSQL, etc.).
4. **Rendimiento y portabilidad** – producir binarios nativos mediante Free Pascal, dirigido a Windows/Linux, x86/x86_64/ARM64, con niveles de optimización e información de depuración.
5. **Herramientas y extensibilidad** – ofrecer una API limpia para integración con IDE, depuración (`--dump-ast`, `--dump-ir`, `--dump-asm`) y personalización del preprocesador.

## ¿Por qué el nombre “FXBASE”?

- **Fast** – enfatiza la meta de generar código nativo de alto rendimiento, en contraste con la naturaleza interpretada o p‑code de los runtimes xBase tradicionales.
- **xBase** – destaca la línea directa y compatibilidad con la familia clásica de lenguajes xBase (Clipper, Harbour, FoxPro).
- El nombre combinado transmite una versión moderna y enfocada en la velocidad de un lenguaje venerable, manteniendo clara su herencia para usuarios que migran de sistemas heredados.

## Primeros pasos

### Prerrequisitos

- Compilador Free Pascal (FPC) ≥ 3.2.2
- GNU Make
- (Opcional) Un servidor de base de datos SQL para probar el SQL generado (SQLite funciona out‑of‑the‑box)

### Compilación

```bash
# Clonar el repositorio
git clone https://github.com/tuorg/fxbase.git
cd fxbase

# Compilar el compilador
make fxbc          # o simplemente: make
# El binario aparecerá en ./bin/fxbc
```

### Uso

```bash
# Compilar un programa .prg clásico a un ejecutable
./bin/fxbc hello.prg               # produce ./hello (o hello.exe en Windows)

# Especificar archivo de salida y tipo
./bin/fxbc -o myapp.exe -t exe main.fpg

# Compilación cruzada para Windows de 64‑bits desde Linux
./bin/fxbc --target win64 app.prg

# Usar un backend PostgreSQL
./bin/fxbc --db-driver postgres \
          --db-connection "host=localhost dbname=mydb user=me password=secret" \
          app.fpg

# Activar comprobación estricta de tipos
./bin/fxbc --strict source.fbg

# Volcar representaciones intermedias para depuración
./bin/fxbc --dump-ast source.prg > ast.txt
./bin/fxbc --dump-ir  source.prg > ir.txt
./bin/fxbc --dump-asm source.prg > asm.s
```

### Ejecutar el conjunto de pruebas

```bash
make test          # ejecuta pruebas unitarias, de integración, de implementación y de IR
make test-coverage # genera un informe básico de cobertura
make test-quality  # calcula LOC, complejidad, etc.
```

### Instalación

```bash
sudo make install   # copia ./bin/fxbc a /usr/local/bin/fxbc
```

### Distribución

```bash
make dist           # crea un tarball (fxbase‑<version>.tar.gz) excluyendo build/ y bin/
```

## Estructura del proyecto

```
fxbase/
├── src/
│   └── fxb/                # código fuente del compilador (fxb.*.pas, fxb.lpr)
├── tests/
│   ├── unit/               # pruebas de token y lexer
│   ├── integration/        # pruebas de pipeline lexer+parser
│   ├── implementation/     # fixtures de programas completos
│   └── ir/                 # pruebas de bajada AST→IR
├── docs/
│   ├── FXBASE-COMPATIBILITY-STRATEGY.md
│   ├── FXBASE-GRAMMAR.md
│   ├── FXBASE-PARALLEL-COMPILER-ARCHITECTURE.md
│   ├── FXBASE-PRD.md
│   └── FXBASE-ROADMAP.md
├── Makefile
└── .gitignore
```

## Licencia

FXBASE se publica bajo la Licencia MIT – consulte el archivo `LICENSE` para más detalles.

## Contribuir

Por favor lea [`.opencode/rules.md`](.opencode/rules.md) para conocer el estilo de código, convenciones de commits y el uso prohibido de `{$mode delphi}`. Abra problemas o envíe pull requests en GitHub.

---  
*Creado con ❤️ usando Free Pascal.*

## Cobertura de código

Ejecutar:

```bash
make test-coverage
```

Genera un informe heurístico en `build/coverage_report.txt`.
