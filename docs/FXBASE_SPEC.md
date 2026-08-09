# FXBASE — Especificación Técnica (SPEC)

**Versión:** 1.0.0-alpha  
**Fecha:** 2026-08-08  
**Fuente:** Derivado de PRD v1.0.0, GRAMMAR v1.0.0, ARCH v1.0.0  

---

## 1. Alcance y Conformidad

### 1.1 Niveles Conformidad

| Nivel | Descripción | Características Requeridas |
|-------|-------------|----------------------------|
| **Core** | Compilador mínimo viable | Lexer, Parser, Type Checker, Backend C, FXSTD Core |
| **Standard** | Listo para producción | Todo Core + Backend LLVM, LSP, fxpkg, Testing, fmt, doc |
| **Full** | Ecosistema completo | Todo Standard + WASM, VM, UI Backends, Debugger, Transpilador |

### 1.2 Referencias Normativas

- PRD v1.0.0 (requisitos)
- GRAMMAR v1.0.0 (sintaxis)
- ARCH v1.0.0 (arquitectura)
- IEEE 754-2008 (punto flotante)
- Unicode 15.0 (identificadores, cadenas)
- RFC 3986 (URIs en sentencias USE)
- SemVer 2.0.0 (versionado)

---

## 2. Especificación Semántica del Lenguaje

### 2.1 Sistema de Tipos

#### 2.1.1 Universo Tipos

```
Tipo ::= 
  | Primitivo          // NIL, LOGICAL, INT, DECIMAL, FLOAT, STRING, DATE, DATETIME, POINTER
  | Variant            // Tipo dinámico (compatibilidad legacy)
  | Array<T>           // Homogéneo, tamaño dinámico
  | Hash<K,V>          // Array asociativo
  | Object<T>          // Instancia clase
  | CodeBlock<Args..., Ret>  // Closure tipado
  | Channel<T>         // Canal CSP
  | Result<T,E>        // Ok(T) | Err(E)
  | Optional<T>        // T | NIL  (azúcar: T?)
  | Function(Args...) -> Ret
  | UserDefined(nombre, args...)
  | TypeVar('a)        // Para inferencia
  | Union(T1|T2|...)   // Suma anónima
  | Intersection(T1&T2) // Producto anónimo
```

#### 2.1.2 Reglas Subtipado

```
S <: T  sii:
  - S = T
  - S = NIL, T = Optional<U>
  - S = Array<S1>, T = Array<T1>, S1 <: T1  (covariante)
  - S = Hash<K,S1>, T = Hash<K,T1>, S1 <: T1  (covariante en valor)
  - S = CodeBlock<ArgsS..., RetS>, T = CodeBlock<ArgsT..., RetT>
        ArgsT <: ArgsS (contravariante), RetS <: RetT (covariante)
  - S = Channel<S1>, T = Channel<T1>, S1 = T1  (invariante)
  - S = Result<S1,E1>, T = Result<T1,E2>, S1 <: T1, E1 <: E2
  - S = Optional<S1>, T = Optional<T1>, S1 <: T1
  - S = UserDefined, T = UserDefined, S hereda T
  - S = Function(ArgsS...) -> RetS, T = Function(ArgsT...) -> RetT
        ArgsT <: ArgsS, RetS <: RetT
```

#### 2.1.3 Semántica Tipado Gradual

| Modo | Comportamiento |
|------|----------------|
| **Dinámico** (default) | Todas variables `VARIANT`, checks runtime, `NIL` asignable a cualquier |
| **Estricto** (`#STRICT`) | Tipos explícitos/inferidos, `NIL` solo a `T?`, sin coerciones implícitas |
| **Legacy** (`--legacy`) | `PUBLIC`/`PRIVATE`, `VARIANT` default, `SET EXACT OFF`, macros sin tipar |

**Garantía Gradual:** Añadir anotaciones tipo nunca cambia comportamiento runtime (salvo detectar errores antes).

#### 2.1.4 Algoritmo Inferencia Tipos

```
1. Generar restricciones desde AST (estilo Hindley-Milner)
2. Unificar con occurs-check
3. Generalizar en let-bindings (no en lambdas salvo anotadas)
4. Default type vars sin restringir:
   - Contexto numérico → INT
   - Contexto cadena → STRING
   - Contexto booleano → LOGICAL
   - Elemento colección → VARIANT (dinámico) o tipo elemento (estricto)
5. Reportar restricciones sin resolver como error (estricto) o VARIANT (dinámico)
```

### 2.2 Semántica Variables

#### 2.2.1 Clases Almacenamiento

| Palabra | Vida | Alcance | Inicialización |
|---------|------|---------|----------------|
| `LOCAL` | Activación función | Bloque | Requerida (o `NIL`) |
| `STATIC` | Programa | Bloque | Una vez, perezosa primera entrada |
| `MODULE` | Programa | Archivo (módulo) | Al cargar módulo |
| `EXPORT MODULE` | Programa | Cross-módulo | Al cargar módulo |

#### 2.2.2 Reglas Inicialización

```
LOCAL x           // Error en estricto, NIL en dinámico
LOCAL x := expr   // Tipo inferido de expr
LOCAL x AS T      // Error en estricto (sin inicializar), NIL en dinámico
LOCAL x AS T := e // e debe ser subtipo de T
```

### 2.3 Semántica Control Flujo

#### 2.3.1 Semántica Bucles

```
FOR i := inicio TO fin [STEP paso]
    // i es LOCAL al bucle, inmutable en cuerpo
    // inicio, fin, paso evaluados una vez antes del bucle
    // paso default 1; si negativo, cuenta regresivo
    // Bucle ejecuta cero veces si inicio > fin (paso>0) o inicio < fin (paso<0)
NEXT

FOREACH item IN coleccion
    // item es LOCAL, nuevo binding cada iteración
    // coleccion evaluada una vez
    // Modificaciones a item no afectan coleccion (semántica copia para valores)
NEXT

DO WHILE condicion
    // condicion verificada ANTES del cuerpo
ENDDO

DO UNTIL condicion
    // condicion verificada DESPUÉS cuerpo (al menos una vez)
ENDDO
```

#### 2.3.2 Exhaustividad Match

```
MATCH expr
    CASE patron1 [IF guarda] => cuerpo1
    CASE patron2 => cuerpo2
    ...
    CASE _ => default
END

// Exhaustividad requerida para:
// - Tipos sellados (todos constructores cubiertos)
// - LOGICAL (TRUE, FALSE)
// - RESULT (OK, ERR)
// - OPTIONAL (SOME, NONE)
// No exhaustivo = error compilación en estricto, warning en dinámico
```

### 2.4 Semántica Funciones

#### 2.4.1 Paso Parámetros

| Modo | Sintaxis | Semántica |
|------|----------|-----------|
| Por Valor | `x AS T` | Copia para tipos valor, referencia para objetos |
| Por Ref | `BYREF x AS T` | Alias a variable llamador |
| Default | `x AS T := default` | Evaluado en sitio llamada si omitido |
| Variádico | `...x AS ARRAY<T>` | Recolectado en array |

#### 2.4.2 Semántica Retorno

```
RETURN expr           // Retorna de función, tipo debe coincidir
RETURN                // Retorna NIL (solo válido para retorno NIL/Optional/Result)
```

#### 2.4.3 Funciones Async

```
ASYNC FUNCTION nombre(...) AS Task<T>
    // Retorna inmediatamente con Task<T>
    // Cuerpo ejecuta en planificador
    // Puntos AWAIT son puntos de yield
END

SPAWN expr            // expr: Función o CodeBlock → Task
AWAIT tarea           // Bloquea tarea (no hilo) hasta completar
WAIT ALL [tareas...]  // Bloquea hasta que todas completen
```

### 2.5 Semántica Concurrencia

#### 2.5.1 Operaciones Canales

```
ch := CHANNEL<T>(capacidad)  // capacidad=0 → sin buffer (rendezvous)

ch <- valor       // Envía: bloquea si lleno (buffer) o sin receptor (sin buffer)
valor := <- ch    // Recibe: bloquea si vacío
valor := <- ch?   // Intento recepción: retorna Optional<T> (NIL si vacío)

// Select (multiplexación)
SELECT
    CASE v := <- ch1 => cuerpo1
    CASE <- ch2 => cuerpo2
    CASE ch3 <- val => cuerpo3
    CASE DEFAULT => cuerpo_default
END
```

**Garantías Canales:**
- Orden FIFO por canal
- Envío/recepción atómicas respecto a otras ops mismo canal
- Cerrar canal: `CLOSE(ch)` → envíos posteriores pánico, recepciones drenan y retornan NIL
- Sin estado mutable compartido entre tareas (forzado por sistema tipos)

#### 2.5.2 Modelo Tareas

- **Hilos verdes** (planificación M:N, work-stealing)
- Stack: segmentado, crece bajo demanda (mín 8KB, máx configurable)
- Preemptión: en llamadas función, backedges bucles, ops canales, AWAIT
- `SPAWN` hereda entorno léxico llamador (copiado, no compartido)

### 2.6 Modelo Objetos

#### 2.6.1 Semántica Clases

```
CLASS Nombre [INHERIT Base]
    PROPERTY nombre AS Tipo [:= default]   // Campo instancia
    ACCESS nombre AS Tipo                  // Propiedad computada (getter)
    METHOD nombre(...) AS Ret ... END      // Virtual por default
    OVERRIDE METHOD nombre(...) ... END    // Debe coincidir firma base
    CONSTRUCTOR(...) ... END               // Debe inicializar todos campos
    HIDDEN ...                             // Privado a clase
    STATIC ...                             // Por-clase (no por-instancia)
END
```

**Reglas Herencia:**
- Herencia simple solamente
- `SUPER(...)` debe ser primera sentencia en constructor derivado
- Campos no heredados (composición sobre herencia para estado)
- Métodos virtuales por default; `FINAL` previene override (futuro)

#### 2.6.2 Interfaz/Protocolo (Futuro)

```
// No en v1.0 - planeado para v1.1
PROTOCOL Nombre
    METHOD nombre(...) AS Ret
END

CLASS Nombre IMPLEMENTS Protocolo
    ...
END
```

### 2.7 Semántica Manejo Errores

#### 2.7.1 Excepciones (Errores Excepcionales)

```
TRY
    arriesgado()
CATCH e AS ErrorEspecifico
    // Manejar específico
CATCH e AS ErrorBase
    // Manejar base
FINALLY
    limpieza()  // Siempre ejecuta, incluso en pánico/return
END
```

- Desenrollado stack con destructores (RAII via `FINALLY`/`DROP` trait)
- `RAISE` re-lanza excepción actual
- Excepción no capturada → pánico tarea → logueado, tarea muere

#### 2.7.2 Tipo Resultado (Errores Dominio)

```
FUNCTION op() AS RESULT<T, E>
    SI condicion_error
        RETORNA ERR(valor_error)
    FIN_SI
    RETORNA OK(valor_exito)
END

// Pattern matching
MATCH op()
    CASE OK(v) => usar(v)
    CASE ERR(e) => manejar(e)
END

// Unwrap con default
val := op() ? valor_defecto
```

### 2.8 Base Datos (RDD 2.0) Semántica

#### 2.8.1 Conexión

```
USE "postgres://user:pass@host/db" VIA "PGSQL" ALIAS nombre
// Abre pool conexiones (default 10)
// ALIAS se convierte workarea default
```

#### 2.8.2 Comandos Navegación → Traducción SQL

| Comando FXBASE | Traducción SQL |
|----------------|----------------|
| `USE alias` | `SET workarea = alias` |
| `SEEK clave` | `SELECT * FROM tabla WHERE pk = ? LIMIT 1` |
| `LOCATE FOR cond` | `SELECT * FROM tabla WHERE cond LIMIT 1` |
| `SKIP n` | `OFFSET n` (basado en cursor) |
| `REPLACE campo WITH val` | `UPDATE tabla SET campo = ? WHERE pk = ?` |
| `REPLACE ALL ... WHERE cond` | `UPDATE tabla SET ... WHERE cond` |
| `DELETE` | `UPDATE tabla SET deleted = true WHERE pk = ?` (soft delete) |
| `PACK` | `DELETE FROM tabla WHERE deleted = true` |
| `COUNT TO var FOR cond` | `SELECT COUNT(*) FROM tabla WHERE cond` |
| `SUM campo TO var` | `SELECT SUM(campo) FROM tabla` |

**Cache Prepared Statements:** LRU cache (100 statements por conexión).

#### 2.8.3 Transacciones

```
BEGIN TRANSACTION
    // ... operaciones ...
COMMIT
// o
ROLLBACK

// Anidadas: savepoints
SAVEPOINT nombre
ROLLBACK TO nombre
```

### 2.9 Semántica Macros y Metaprogramación

#### 2.9.1 Macro Legacy (`&`)

```
&identificador        // Resuelve variable/campo en runtime (dinámico)
&(expresion)          // Evalúa cadena expresión en runtime
// Solo permitido en modo --legacy o dinámico
// Seguridad: sandbox, sin acceso filesystem/red
```

#### 2.9.2 Macro Segura (`COMPILE`)

```
COMPILE<TipoRet>(cadena_fuente, [hash_contexto])
// cadena_fuente: expresión/fuente FXBASE
// hash_contexto: { "nombre_var" => TIPO, ... } para type checking
// Compila en runtime, retorna CodeBlock tipado
// Sandbox: sin FFI, sin filesystem, sin red, límites recursos
```

#### 2.9.3 Metaprogramación Compile-Time

```
ATTRIBUTE Nombre(params)
    // Ejecuta en compile-time durante procesamiento atributo
    // Acceso a AST elemento decorado
    // Puede emitir diagnósticos, modificar AST (futuro)
END

// Uso
[Nombre("valor")]
CLASS Foo ... END
```

---

## 3. Especificación Biblioteca Estándar (FXSTD)

### 3.1 Tipos Core

#### 3.1.1 `RESULT<T, E>`

```
ENUM RESULT<T, E>
    OK(T)
    ERR(E)
END

METODOS:
    map<U>(f: Fn(T) -> U) -> RESULT<U, E>
    map_err<F>(f: Fn(E) -> F) -> RESULT<T, F>
    and_then<U>(f: Fn(T) -> RESULT<U, E>) -> RESULT<U, E>
    or_else<F>(f: Fn(E) -> RESULT<T, F>) -> RESULT<T, F>
    unwrap() -> T  // Pánico si ERR
    unwrap_or(default: T) -> T
    expect(msg: STRING) -> T  // Pánico con msg si ERR
    is_ok() -> LOGICAL
    is_err() -> LOGICAL
```

#### 3.1.2 `OPTIONAL<T>` (alias `T?`)

```
ENUM OPTIONAL<T>
    SOME(T)
    NONE
END

METODOS:
    map<U>(f: Fn(T) -> U) -> OPTIONAL<U>
    and_then<U>(f: Fn(T) -> OPTIONAL<U>) -> OPTIONAL<U>
    or_else(f: Fn() -> OPTIONAL<T>) -> OPTIONAL<T>
    unwrap() -> T
    unwrap_or(default: T) -> T
    expect(msg: STRING) -> T
    is_some() -> LOGICAL
    is_none() -> LOGICAL
```

#### 3.1.3 `CHANNEL<T>`

```
CLASS CHANNEL<T>
    CONSTRUCTOR(capacidad: INT := 0)
    METODO send(valor: T)           // Bloquea
    METODO try_send(valor: T) -> LOGICAL  // Retorna FALSE si lleno
    METODO recv() -> T              // Bloquea
    METODO try_recv() -> OPTIONAL<T>
    METODO close()
    METODO is_closed() -> LOGICAL
    METODO len() -> INT             // Solo buffered
    METODO cap() -> INT
END
```

### 3.2 Colecciones

#### 3.2.1 `ARRAY<T>`

```
CLASS ARRAY<T>
    CONSTRUCTOR()                    // Vacío
    CONSTRUCTOR(capacidad: INT)      // Pre-asignado
    CONSTRUCTOR(items: ARRAY<T>)     // Copia
    
    METODO push(item: T)
    METODO pop() -> OPTIONAL<T>
    METODO get(indice: INT) -> OPTIONAL<T>
    METODO set(indice: INT, item: T) -> LOGICAL  // FALSE si FUERA_RANGO
    METODO len() -> INT
    METODO cap() -> INT
    METODO reserve(adicional: INT)
    METODO clear()
    METODO contains(item: T) -> LOGICAL  // Requiere Eq
    METODO index_of(item: T) -> OPTIONAL<INT>
    METODO slice(inicio: INT, fin: INT) -> ARRAY<T>
    METODO map<U>(f: Fn(T) -> U) -> ARRAY<U>
    METODO filter(f: Fn(T) -> LOGICAL) -> ARRAY<T>
    METODO reduce<U>(init: U, f: Fn(U, T) -> U) -> U
    METODO sort()  // Requiere Ord
    METODO sort_by(f: Fn(T) -> COMPARABLE)
    METODO iter() -> ITERATOR<T>
END
```

#### 3.2.2 `HASH<K, V>`

```
CLASS HASH<K, V>  // K: Hash + Eq
    CONSTRUCTOR()
    CONSTRUCTOR(capacidad: INT)
    
    METODO get(clave: K) -> OPTIONAL<V>
    METODO set(clave: K, valor: V) -> OPTIONAL<V>  // Retorna anterior
    METODO remove(clave: K) -> OPTIONAL<V>
    METODO has(clave: K) -> LOGICAL
    METODO len() -> INT
    METODO clear()
    METODO keys() -> ARRAY<K>
    METODO values() -> ARRAY<V>
    METODO entries() -> ARRAY<{clave: K, valor: V}>
    METODO iter() -> ITERATOR<{clave: K, valor: V}>
END
```

### 3.3 E/S

```
CLASS FILE
    ESTATICO open(ruta: PATH, opts: OPEN_OPTIONS) -> RESULT<FILE, IO_ERROR>
    METODO read(buf: ARRAY<BYTE>) -> RESULT<INT, IO_ERROR>
    METODO write(buf: ARRAY<BYTE>) -> RESULT<INT, IO_ERROR>
    METODO seek(pos: SEEK_FROM) -> RESULT<INT64, IO_ERROR>
    METODO flush() -> RESULT<NIL, IO_ERROR>
    METODO metadata() -> RESULT<METADATA, IO_ERROR>
    METODO close() -> RESULT<NIL, IO_ERROR>
END

CLASS PATH
    ESTATICO new(ruta: STRING) -> PATH
    METODO join(otro: PATH) -> PATH
    METODO parent() -> OPTIONAL<PATH>
    METODO filename() -> OPTIONAL<STRING>
    METODO extension() -> OPTIONAL<STRING>
    METODO exists() -> LOGICAL
    METODO is_file() -> LOGICAL
    METODO is_dir() -> LOGICAL
    METODO read_dir() -> RESULT<ARRAY<DIR_ENTRY>, IO_ERROR>
END
```

### 3.4 Base Datos (RDD)

```
INTERFAZ RDD
    METODO connect(dsn: STRING, opts: HASH<STRING, VARIANT>) -> RESULT<CONEXION, DB_ERROR>
END

CLASS CONEXION
    METODO execute(sql: STRING, params: ARRAY<VARIANT>) -> RESULT<EXEC_RESULT, DB_ERROR>
    METODO query(sql: STRING, params: ARRAY<VARIANT>) -> RESULT<CURSOR, DB_ERROR>
    METODO begin() -> RESULT<TRANSACCION, DB_ERROR>
    METODO close() -> RESULT<NIL, DB_ERROR>
END

CLASS CURSOR
    METODO next() -> RESULT<OPTIONAL<FILA>, DB_ERROR>
    METODO columns() -> ARRAY<COLUMN_INFO>
    METODO close() -> RESULT<NIL, DB_ERROR>
END

CLASS TRANSACCION
    METODO commit() -> RESULT<NIL, DB_ERROR>
    METODO rollback() -> RESULT<NIL, DB_ERROR>
    METODO savepoint(nombre: STRING) -> RESULT<NIL, DB_ERROR>
    METODO rollback_to(nombre: STRING) -> RESULT<NIL, DB_ERROR>
END
```

### 3.5 Primitivas Concurrencia

```
CLASS TAREA<T>
    METODO await() -> T  // Bloquea tarea
    METODO try_await() -> OPTIONAL<T>
    METODO cancel() -> LOGICAL
    METODO is_done() -> LOGICAL
END

FUNCION SPAWN<F, R>(f: F) -> TAREA<R>  // F: Fn() -> R

FUNCION SELECT(casos: ARRAY<SELECT_CASE>) -> SELECT_RESULT

// Tiempo
FUNCION sleep(duracion: DURACION)
FUNCION timeout<T>(duracion: DURACION, f: Fn() -> T) -> RESULT<T, TIMEOUT_ERROR>
```

### 3.6 UI (GET/READ 2.0)

```
CLASS FORMULARIO
    CONSTRUCTOR(titulo: STRING, ancho: INT, alto: INT)
    METODO add_say(fila: INT, col: INT, texto: STRING)
    METODO add_get(fila: INT, col: INT, modelo: ANY, campo: STRING, 
                   valid: Fn() -> LOGICAL := {|| TRUE},
                   mensaje: STRING := "",
                   picture: STRING := "")
    METODO add_checkbox(fila: INT, col: INT, modelo: ANY, campo: STRING, caption: STRING)
    METODO add_combobox(fila: INT, col: INT, modelo: ANY, campo: STRING, items: ARRAY<STRING>)
    METODO add_button(fila: INT, col: INT, texto: STRING, accion: Fn())
    METODO read(modelo: ANY)  // Vincula formulario a modelo, ejecuta bucle eventos
    METODO close()
END
```

---

## 4. Especificación Compilador

### 4.1 Interfaz Línea Comandos

```
fxbase [OPCIONES] <COMANDO> [ARGS]

COMANDOS:
    build [--release] [--target TRIPLE] [--legacy] [--strict]
    run [--release] [-- ARGS...]
    test [--coverage] [--bench] [FILTRO]
    check [--strict]
    fmt [--check] [ARCHIVOS...]
    doc [--html] [--md] [--output DIR]
    migrate [--source DIR] [--output DIR] [--report FORMAT]
    new [--lib|--bin] NOMBRE
    add <PKG>[@VERSION] [--dev]
    update [PKG...]
    publish [--dry-run] [--token TOKEN]
    repl
    lint [--fix]
    doctor

OPCIONES GLOBALES:
    -v, --verbose          Incrementa verbosidad
    -q, --quiet            Suprime salida no-error
    --color auto|always|never
    --config ARCHIVO       Archivo config (default: fxpkg.toml)
    --cache-dir DIR        Directorio cache build
    -j, --jobs N           Jobs paralelos (default: CPU count)
```

### 4.2 Configuración (`fxpkg.toml`)

```toml
[package]
name = "mi_app"
version = "1.0.0"
authors = ["Nombre <email>"]
edition = "2026"
description = "..."
license = "MIT"
repository = "https://..."
homepage = "https://..."
keywords = ["tag1", "tag2"]
categories = ["cat1"]

[dependencies]
fxstd = "1.0"
serde = { version = "1.0", features = ["derive"] }
mipkg = { path = "../dep_local" }
otro = { git = "https://...", rev = "abc123" }

[dev-dependencies]
test_harness = "1.0"

[features]
default = ["std"]
std = ["fxstd"]
web = ["fxstd/web"]

[profile.release]
opt_level = 3
lto = true
debug = false
panic = "abort"

[profile.dev]
opt_level = 0
debug = true
overflow_checks = true

[build]
target = "x86_64-unknown-linux-gnu"
rustflags = ["-C", "target-cpu=native"]

[lsp]
enable = true
check_on_save = true

[migrate]
legacy_mode = true
risk_threshold = "medium"
```

### 4.3 Formato Diagnósticos

```json
{
  "diagnostics": [
    {
      "code": "E0308",
      "level": "error",
      "message": "tipos incompatibles",
      "spans": [
        {
          "file_id": 1,
          "start": 42,
          "end": 48,
          "line": 10,
          "column": 15,
          "label": "se esperaba `INT`, se encontró `STRING`"
        }
      ],
      "children": [
        {
          "level": "note",
          "message": "se esperaba enum `RESULT<INT, STRING>`",
          "spans": [...]
        }
      ],
      "suggestions": [
        {
          "action": "replace",
          "span": {"file_id": 1, "start": 42, "end": 48},
          "text": "AS INT"
        }
      ]
    }
  ],
  "files": {
    "1": "src/main.fx"
  }
}
```

### 4.4 Códigos Salida

| Código | Significado |
|--------|-------------|
| 0 | Éxito |
| 1 | Error compilación |
| 2 | Argumentos inválidos |
| 3 | Error interno compilador (ICE) |
| 4 | Fallo resolución dependencias |
| 5 | Paquete no encontrado |
| 6 | Fallos tests |
| 7 | Errores lint/formato (--check) |
| 8 | Errores migración |
| 127 | Comando no encontrado |

---

## 5. Especificación Transpilador (`fxbase migrate`)

### 5.1 Invocación

```
fxbase migrate [OPCIONES] --source <DIR> --output <DIR>

OPCIONES:
    --legacy              Emitir código compatible --legacy
    --strict              Emitir código #STRICT (requiere fixes manuales)
    --report FORMAT       md|json|html (default: md)
    --risk-threshold      low|medium|high (default: low)
    --preserve-comments   Mantener comentarios originales
    --module-strategy     file|directory|heuristic (default: heuristic)
    --include-pattern     Glob para .prg (default: **/*.prg)
    --exclude-pattern     Glob para excluir
    --dry-run             Solo analizar, sin salida
```

### 5.2 Reglas Transformación (Normativas)

| Patrón xHarbour | Salida FXBASE | Anotación |
|-----------------|---------------|-----------|
| `PUBLIC var` | `EXPORT MODULE VARIABLE var AS VARIANT` | RIESGO-202 |
| `PRIVATE var` | `MODULE VARIABLE var AS VARIANT` | RIESGO-202 |
| `LOCAL var` | `LOCAL var AS VARIANT` | (ninguna) |
| `LOCAL var := expr` | `LOCAL var AS VARIANT := expr` | (ninguna) |
| `FUNCTION f(p1, p2)` | `FUNCTION f(p1 AS VARIANT, p2 AS VARIANT) AS VARIANT` | RIESGO-303 si crítico |
| `&macro` | `COMPILE<VARIANT>("macro")` | RIESGO-101 |
| `#include "x.ch"` | `IMPORT * FROM "x"` | (heurístico) |
| `REQUEST func` | `IMPORT func FROM "legacy/func"` | (sin resolver → RIESGO-404) |
| `BEGIN SEQUENCE ... RECOVER ... END` | `TRY ... CATCH ... END` | (directo) |
| `SET EXACT OFF` / `SET SOFTSEEK ON` | (emitido, requiere revisión) | RIESGO-404 |
| `USE file.dbf` | `USE "file.dbf" VIA "DBF"` | (RDD legacy) |

### 5.3 Schema Reporte Riesgos (JSON)

```json
{
  "summary": {
    "files_processed": 342,
    "total_lines": 89420,
    "generated_lines": 94102,
    "auto_translated_pct": 87.6,
    "manual_review_pct": 12.4,
    "estimated_hours": 42
  },
  "risks": [
    {
      "code": "RIESGO-101",
      "description": "Uso macro inseguro detectado",
      "severity": "HIGH",
      "count": 45,
      "locations": [
        {"file": "Facturacion.prg", "line": 142, "context": "&cExpr"}
      ]
    },
    {
      "code": "RIESGO-202",
      "description": "Variables PUBLIC/PRIVATE detectadas",
      "severity": "HIGH",
      "count": 234,
      "locations": [
        {"file": "Globales.prg", "line": 10, "context": "PUBLIC nContador"}
      ]
    },
    {
      "code": "RIESGO-303",
      "description": "Tipado implícito en funciones críticas",
      "severity": "MEDIUM",
      "count": 8901,
      "locations": [
        {"file": "Facturacion.prg", "line": 500, "context": "FUNCTION CalcularTotal(nSubtotal, nImpuesto)"}
      ]
    },
    {
      "code": "RIESGO-404",
      "description": "SET EXACT OFF / SET SOFTSEEK ON detectado",
      "severity": "MEDIUM",
      "count": 12,
      "locations": [
        {"file": "Config.prg", "line": 5, "context": "SET EXACT OFF"}
      ]
    }
  ],
  "unresolved": [
    {"symbol": "FuncionExterna", "referenced_in": ["Modulo1.prg:10"]}
  ],
  "recommendations": [
    "Iniciar con modo --legacy, activar estricto por módulo",
    "Priorizar RIESGO-101 y RIESGO-202 (severidad ALTA)",
    "Abordar RIESGO-303 y RIESGO-404 (MEDIA) en módulos críticos"
  ]
}
```

---

## 6. Especificación Comportamiento Runtime

### 6.1 Secuencia Arranque

```
1. Entrada proceso (main o bootstrap FXVM)
2. Inicializar GC (nursery, heaps, barrera escritura)
3. Inicializar planificador (hilos workers = cores CPU)
4. Inicializar FXSTD (intern strings, metadata tipos)
5. Ejecutar inicializadores módulos (orden topológico)
   - Inicializadores VARIABLE MÓDULO
   - Inicializadores STATIC
6. Llamar main() usuario / entry script
7. Al salir: ejecutar FINALIZADORES (orden inverso)
8. Apagar planificador, volcar stats GC (si habilitado)
```

### 6.2 Límites Memoria

| Recurso | Límite Default | Configurable Via |
|---------|----------------|------------------|
| Max heap | 80% RAM física | `FXBASE_MAX_HEAP` env |
| Max stack por tarea | 8MB | `FXBASE_MAX_STACK` |
| Buffer canal | Ilimitado | `CHANNEL<T>(cap)` |
| Cuenta tareas | 100,000 | `FXBASE_MAX_TASKS` |
| Archivos abiertos | Límite SO | `ulimit -n` |

### 6.3 Manejo Señales

| Señal | Comportamiento |
|-------|----------------|
| SIGINT (Ctrl-C) | Lanza `InterruptException` en tarea principal |
| SIGTERM | Inicia apagado graceful (ejecuta finalizadores) |
| SIGSEGV | Imprime stack trace, aborta (salvo handler custom) |
| SIGHUP | Recarga config (si modo daemon) |

---

## 7. Especificación Interoperabilidad

### 7.1 FFI C

```fxbase
// Declaración
[Link("pq")]
UNSAFE FUNCTION PQconnectdb(conninfo: POINTER) AS POINTER
END

// Uso
UNSAFE {
    LOCAL cStr := "host=localhost dbname=test" AS POINTER
    LOCAL conn := PQconnectdb(cStr)
    // ...
}
```

**Reglas ABI:**
- `STRING` → `const char*` (UTF-8, null-terminated)
- `ARRAY<T>` → `{ T* data; size_t len; size_t cap; }`
- `HASH<K,V>` → handle opaco, funciones accesoras
- `OBJECT` → puntero opaco
- `RESULT<T,E>` → `{ int tag; union { T ok; E err; } }`
- Convención llamada: ABI C plataforma (System V AMD64, Windows x64)

### 7.2 Imports/Exports WASM

```fxbase
// Import desde JS
[Import("js", "console.log")]
FUNCTION js_log(msg: STRING)
END

// Export a JS
[Export("calculate")]
EXPORT FUNCTION calculate(x: INT, y: INT) AS INT
    RETORNA x + y
END
```

---

## 8. Especificación Testing

### 8.1 Sintaxis Tests

```fxbase
/// @test 2, 3 -> 5
/// @test 0, 0 -> 0
/// @test -1, 1 -> ERR
EXPORT FUNCTION sumar(a: INT, b: INT) AS RESULT<INT, STRING>
    SI a < 0 O b < 0
        RETORNA ERR("negativos no permitidos")
    FIN_SI
    RETORNA OK(a + b)
END

SUITE "TestsMatematicos"
    TEST "Suma"
        ASSERT sumar(2, 3) == OK(5)
        ASSERT sumar(0, 0) == OK(0)
    END

    TEST "Negativo rechazado"
        ASSERT ES_ERR(sumar(-1, 1))
    END
END
```

### 8.2 Opciones Test Runner

```
fxbase test [OPCIONES] [PATRON]

OPCIONES:
    --coverage          Generar reporte cobertura (lcov/html)
    --bench             Ejecutar benchmarks
    --jobs N            Hilos tests paralelos
    --filter EXPR       Ejecutar tests matching expr
    --list              Listar tests sin ejecutar
    --no-run            Solo compilar
    --shuffle           Aleatorizar orden
    --timeout SEGS      Timeout por test (default: 60)
```

### 8.3 Assertions

| Macro | Descripción |
|-------|-------------|
| `ASSERT(expr)` | Pánico si falso |
| `ASSERT_EQ(a, b)` | Pánico si a != b (requiere Eq) |
| `ASSERT_NE(a, b)` | Pánico si a == b |
| `ASSERT_OK(result)` | Pánico si Err, desempaqueta Ok |
| `ASSERT_ERR(result)` | Pánico si Ok, desempaqueta Err |
| `ASSERT_THROWS(expr, Tipo)` | Pánico si no excepción de Tipo |
| `ASSERT_PANICS(expr)` | Pánico si no pánico |

---

## 9. Especificación Gestor Paquetes (`fxpkg`)

### 9.1 API Registro

```
GET  /api/v1/crates              # Buscar
GET  /api/v1/crates/{name}       # Metadatos paquete
GET  /api/v1/crates/{name}/{ver}/download  # Descargar .fxpkg
PUT  /api/v1/crates/new          # Publicar (auth requerido)
DELETE /api/v1/crates/{name}/{ver}/yank    # Retirar versión
```

### 9.2 Formato Paquete (`.fxpkg`)

```
package.fxpkg (tar.zst)
├── fxpkg.toml          # Manifiesto (igual que fuente)
├── src/                # Archivos fuente (.fx)
├── include/            # Headers C generados (para FFI)
├── lib/                # Artefactos precompilados (por target)
│   ├── x86_64-linux/
│   │   ├── libname.a
│   │   └── libname.fxbc
│   └── wasm32-unknown/
│       ├── libname.wasm
│       └── libname.fxbc
└── CHECKSUM            # SHA256 de contenidos
```

### 9.3 Lockfile (`fxpkg.lock`)

```toml
[package]
name = "mi_app"
version = "1.0.0"

[[dependencies]]
name = "fxstd"
version = "1.0.3"
source = "registry+https://fxbase.dev"
checksum = "sha256:abc123..."
dependencies = []

[[dependencies]]
name = "dep_local"
version = "0.1.0"
source = "path+../dep_local"
```

---

## 10. Especificación LSP

### 10.1 Capacidades Soportadas

| Capacidad | Soportada | Notas |
|-----------|-----------|-------|
| textDocument/completion | ✅ | Snippets, auto-import |
| textDocument/hover | ✅ | Info tipos, docs |
| textDocument/definition | ✅ | Ir a definición |
| textDocument/references | ✅ | Encontrar todas referencias |
| textDocument/rename | ✅ | Cross-file |
| textDocument/formatting | ✅ | Usa `fxbase fmt` |
| textDocument/codeAction | ✅ | Fix imports, añadir brazos match faltantes |
| textDocument/diagnostic | ✅ | Push diagnósticos |
| workspace/symbol | ✅ | Búsqueda fuzzy |
| workspace/didChangeConfiguration | ✅ | Recarga config |
| textDocument/inlayHint | 🔄 | Type hints (planeado) |
| textDocument/semanticTokens | 🔄 | Syntax highlighting (planeado) |

### 10.2 Opciones Inicialización

```json
{
  "initializationOptions": {
    "checkOnSave": true,
    "strictMode": false,
    "legacyMode": false,
    "formatOnSave": true,
    "completionDetail": "full",
    "maxDiagnostics": 100
  }
}
```

---

## 11. Versionado y Compatibilidad

### 11.1 Versionado Lenguaje

```
Edición 2026 (actual)
  - Sintaxis y semántica baseline
  - Tipado gradual
  - Concurrencia CSP

Edición 2027 (planeado)
  - Protocolos/Interfaces
  - Const generics
  - Destructores async
  - Mejoras pattern matching
```

**Migración:** `fxbase migrate --edition 2027` (automatizado donde posible)

### 11.2 Niveles Estabilidad FXSTD

| Nivel | Estabilidad | Ejemplos |
|-------|-------------|----------|
| **Stable** | Sin breaking changes en versión mayor | `core::types`, `collections::array`, `io::file` |
| **Preview** | Puede cambiar con aviso | `ui::web`, `net::websocket` |
| **Experimental** | Sin garantías | `gpu::*`, `ai::*` |

### 11.3 Política Deprecación

1. Marcar con `[Deprecated("usar X en su lugar", since = "1.2")]`
2. Warning compilador al usar
3. Eliminar tras 2 versiones menores (mínimo 6 meses)
4. Documentar en CHANGELOG.md

---

## 12. Benchmarks Rendimiento (Objetivos)

| Métrica | Objetivo | Medición |
|---------|----------|----------|
| Compilación fría 10k LOC | < 1s | `fxbase build` en Ryzen 5 5600X |
| Compilación incremental (1 archivo) | < 200ms | Cambiar una función |
| Arranque REPL | < 50ms | `fxbase repl` |
| Arranque binario (hello world) | < 10ms | Nativo, stripped |
| Latencia canal (ping-pong) | < 100ns | 1M ops/seg |
| Spawn tarea + await | < 1µs | Sin trabajo |
| Pausa GC (heap 100MB) | < 5ms | P99 |
| Overhead consulta RDD | < 1ms | Prepared statement cache hit |
| Velocidad transpilador | > 10k LOC/s | `fxbase migrate` |

---

## 13. Requisitos Seguridad

| Requisito | Implementación |
|-----------|----------------|
| Seguridad memoria | Sin punteros crudos en código seguro; bloques `UNSAFE` auditados |
| Seguridad nulos | Modo estricto: `T?` requerido para nullable |
| Inyección SQL | Todas ops RDD usan prepared statements |
| Sandbox macros | `COMPILE<>`: sin FFI, sin E/S, fuel-limitado |
| Cadena suministro | `fxpkg` verifica checksums, índice firmado |
| Builds reproducibles | Salida determinista, timestamps eliminados |
| FFI basado capacidades | Cada bloque `UNSAFE` declara capacidades requeridas |

---

## 14. Suite Tests Conformidad

La implementación referencia debe pasar:

1. **Tests Sintaxis** - Todas producciones GRAMMAR parsean correctamente
2. **Tests Sistema Tipos** - Subtipado, inferencia, garantía gradual
3. **Tests Runtime** - GC, planificador, canales, tareas
4. **Tests FXSTD** - Todas funciones stdlib comportan per spec
5. **Tests Migración** - Corpus xHarbour transpila y ejecuta
6. **Tests Interop** - C FFI, WASM imports/exports
7. **Tests Herramientas** - CLI, LSP, fmt, doc, test runner
8. **Tests Rendimiento** - Benchmarks dentro de objetivos

---

*Fin SPEC v1.0.0*