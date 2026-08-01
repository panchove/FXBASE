# Plan de Implementación — Codegen de Punto Flotante SSE2 (x86_64)

**Proyecto:** FXBASE (`/home/panchove/Projects/FXBASE`)
**Feature:** Completar la generación de código de punto flotante en `fxb.backend.pas` (target x86_64, AT&T asm, SSE2).
**Estado actual del código (verificado):** los flotantes ya fluyen lexer→IR→print, pero `GenBinaryOp` deja `addsd/subsd/mulsd/divsd` como stubs.
**Reglas base:** `AGENTS.md` (FXBASE) + `CLAUDE.md` (compiler-rules-local) + `docs/FXBASE-ROADMAP.md` Fase 1.3/1.4.
**Alcance:** Backend x86_64 únicamente. No toca x86 (32-bit), ni ARM/AArch64, ni el parser/IR (salvo los 4 helper de carga de operandos).
**Estimación:** ~1-2 días de ingeniería + revisión.

---

## 1. Contexto y Diagnóstico

Evidencia en el código actual (`src/fxb/fxb.backend.pas`):

- `GenBinaryOp` (línea ~468): rama `if left.Type_.Kind in [tkFloat32, tkFloat64] then` hace `case` con **solo** `ikAdd` y emite un comentario `# movsd ...` sin implementar (líneas 488-495). `ikSub`, `ikMul`, `ikDiv` flotantes NO están cubiertos → emiten `# Unimplemented`.
- `GenPrint` (línea 657): **YA** maneja `tkFloat32/tkFloat64` con `movsd`, label `.LrealN` y formato `%g`. Es decir, imprimir un float ya funciona (el pool de reales `EmitRealPool` existe).
- `GetOperandMemRef`/`GetOperandReg` solo contemplan enteros; para flotantes usan `ScratchReg` sin `%` y no mueven a XMM.
- El IR ya soporta flotantes: `TIRConstant.CreateReal`, tipo `tkFloat64`/`tkFloat32`, tokens `RealValue`/`RealVal`. No se requiere cambio en lexer/parser/IR.

Conclusión: el hueco es **estrictamente en el backend**, en el path aritmético de flotantes. No hay que tocar el frontend.

## 2. Objetivo

Que un programa FXBASE con aritmética de punto flotante:

```
FUNCTION Main() AS INTEGER
    ? 1.5 + 2.5
    ? 10.0 - 3.0
    ? 4.0 * 2.0
    ? 7.0 / 2.0
    RETURN 0
ENDFUNC
```

produzca asm SSE2 válido, ensamble, linkee y ejecute imprimiendo `4 7 8 3.5` (o equivalente), sin errores.

## 3. Diseño Técnico

### 3.1 Registro de trabajo flotante
Usar XMM0–XMM5 (SSE2). Convención: el operando izquierdo va a `%xmm0`, el derecho a `%xmm1`, el resultado queda en `%xmm0`. Esto es coherente con que `GenPrint` ya carga floats en `%xmm0` para `printf`.

### 3.2 Funciones helper nuevas (en `TFXBBackend`)
- `LoadFloatOperand(Val: TIRValue; const XmmReg: string): string;`
  - Si `Val` es `TIRConstant` (real): emitir `movsd .LrealN(%rip), %xmmN` usando `GetRealLabel(c.RealVal)` (ya existe el pool).
  - Si `Val` es `TIRLocal`: emitir `movsd <offset>(%rbp), %xmmN` (reusa `GetOperandMemRef`).
  - Si `Val` es `TIRArgument`: cargar del registro XMM correspondiente al índice (mismos 6 regs que enteros pero en xmm: rdi→xmm0? **OJO:** en x86_64 System V ABI los args flotantes van en **xmm0..xmm7**, no en GPR; ver sección 5 Riesgos).
  - Si `Val` es `TIRInstruction` (definido por un load/otra op): recursión sobre el def instr para traerlo a XMM.
  - Retorna el nombre del registro XMM usado.

### 3.3 Reescritura de `GenBinaryOp` (rama flotante)
Sustituir el `case` stub (líneas 488-495) por:

```pascal
if isFloat then
begin
  leftReg := LoadFloatOperand(left, '%xmm0');
  rightReg := LoadFloatOperand(right, '%xmm1');
  case Instr.Kind of
    ikAdd: Emit('addsd %xmm1, %xmm0');
    ikSub: Emit('subsd %xmm1, %xmm0');
    ikMul: Emit('mulsd %xmm1, %xmm0');
    ikDiv: Emit('divsd %xmm1, %xmm0');
    // Shl/Shr/And/Or/Xor no aplican a flotantes -> error BE-0002
    else ReportError('Operador no válido para flotantes: ' + InstrKindToStr(Instr.Kind));
  end;
  // El resultado es la instrucción misma (definida en xmm0); quien lo use
  // (GenPrint / otro GenBinaryOp) debe volver a cargarlo desde xmm0 o memoria.
  Exit;
end;
```

### 3.4 Propagación del resultado entre instrucciones
Hoy `GetOperandReg` asume enteros. Para que una cadena `a = b + c; d = a * 2.0` funcione, el resultado de `GenBinaryOp` (en `%xmm0`) debe ser "materializado" en la local de destino o leído por el siguiente usuario.
- Enfoque simple y correcto: tras cada `GenBinaryOp` flotante, **escribir el resultado de vuelta a la pila** (`movsd %xmm0, <offset>(%rbp)`) asociado a la local `dest` (la propia instrucción `Instr` es un `TIRLocal`/value con offset). Así los usuarios siguientes lo recargan con `LoadFloatOperand` desde memoria. Esto evita跟踪 de registros vivos y es robusto para -O0.
- Confirmar que `AssignLocalOffsets` ya reserva 8 bytes por local (línea 144); un float cabe en 8 bytes (double). Para `tkFloat32` también (se promueve a double en SSE2, aceptable para -O0).

### 3.5 `GetOperandReg` / `GetOperandMemRef` para flotantes
Añadir rama `if Val.Type_.Kind in [tkFloat32, tkFloat64] then` que redirija a `LoadFloatOperand` (en vez de tratarlo como entero). Esto cubre el caso en que un float se use como argumento de `printf` o de otra op sin pasar por `GenBinaryOp` primero.

## 4. Workflow (loops locales, según `CLAUDE.md` §4)

1. **Análisis/diseño:** (este plan).
2. **Implementación:** editar `fxb.backend.pas` (helpers + `GenBinaryOp` + `GetOperandReg`). Mantener `{$mode objfpc}{$H+}`.
3. **Pruebas:**
   - `make fxbc` (rebuild obligatorio tras editar unidades Pascal — ver `AGENTS.md`).
   - `make test` (debe seguir verde: unit + integration + implementation + IR).
   - Nuevo fixture `tests/fixtures/float.fbg` + test en `tests/implementation/test_implementation.pas`:
     - `TestImpl_Backend_FloatArith`: compila fuente con `+ - * /` flotantes, verifica que el ASM contiene `addsd`/`subsd`/`mulsd`/`divsd` y NO contiene `# Unimplemented`.
     - `TestImpl_Backend_FloatExecutes` (opcional end-to-end): invoca `fxbc` sobre `float.fbg` → `AssembleAndLink` (ya existe en `fxb.cli.pas`) → ejecuta el binario y compara stdout con `4 7 8 3.5`.
4. **Evaluación:** si el test de ejecución falla, inspeccionar el `.s` emitido (`fxbc ... --dump-asm` / `FDumpASM`) y corregir.
5. **Revisión:** otro desarrollador revisa el diff (`[Backend]` prefix). No romper compatibilidad (regla `CLAUDE.md` §3).
6. **Integración:** commit atómico, mensaje `[Backend] Implement x86_64 SSE2 float arithmetic (addsd/subsd/mulsd/divsd)`.

## 5. Riesgos y Mitigaciones

- **ABI args flotantes:** en x86_64 System V, los argumentos flotantes de función van en `xmm0..xmm7`, NO en `rdi/rsi/...`. Si una función FXBASE recibe un float por parámetro, `LoadFloatOperand` para `TIRArgument` debe leer de `xmmN` según índice de arg flotante, no de GPR. Mitigación: implementar un mapeo `argIndex -> xmmN` separado (contador de args flotantes) en la prologue/carga de argumentos. Para -O0 y casos comunes (Main no recibe floats; funciones locales usan locales en pila) esto es suficiente; dejar nota de limitación para ABI completa.
- **Comparaciones flotantes (`ikFCmp`):** fuera de alcance de este plan, pero `GenBinaryOp` debe `ReportError` si alguien aplica `ikICmp` a floats (hoy `GenICmp` usa `cmpq`, incorrecto para reals). Registrar como follow-up (Fase 1.9 / optimizador).
- **Codegen x86 32-bit y ARM:** NO se tocan aquí. El backend ya distingue por `TargetCPU`; este plan es x86_64-only. Las otras arquitecturas seguirán sin soporte de float (sin regresión, ya no lo tenían).
- **Double vs float32:** se opera siempre en double (SSE2 `sd`); `float32` se promueve. Aceptable para -O0; documentar.

## 6. Criterios de Aceptación

- [ ] `make test` pasa íntegro tras los cambios.
- [ ] `fxbc` sobre `float.fbg` emite ASM con `addsd`/`subsd`/`mulsd`/`divsd`, sin `# Unimplemented`.
- [ ] El binario resultante imprime resultados flotantes correctos.
- [ ] Ningún cambio en lexer/parser/IR (solo backend + tests).
- [ ] Commit con prefijo `[Backend]` y mensaje en inglés (regla `CLAUDE.md` §8).

## 7. Entorno Local

- Build/test 100% local: `make fxbc`, `make test`.
- Modelo local (Ollama) puede asistir en la edición, pero el diff final lo revisa humano (regla `CLAUDE.md` §5: cambios en backend de codegen requieren validación de arquitectura).
- No se requieren API keys ni red.

---

### Referencias de código
- `src/fxb/fxb.backend.pas` — `GenBinaryOp` (≈468), `GenPrint` float (≈657), `GetOperandReg` (≈156), `GetOperandMemRef` (≈214), `EmitRealPool` (≈273), `AssignLocalOffsets` (≈134).
- `src/fxb/fxb.ir.instr.pas` — `TIRInstructionKind` (`ikAdd..ikDiv`), `TIRConstant.CreateReal`.
- `src/fxb/fxb.ir.types.pas` — `tkFloat32/tkFloat64`.
- `src/fxb/fxb.cli.pas` — `AssembleAndLink` (≈56) para test end-to-end.
- `tests/implementation/test_implementation.pas` — `TestImpl_Backend_PrintAsm` (≈260) como patrón de test de backend.
- `AGENTS.md`, `CLAUDE.md`, `docs/FXBASE-ROADMAP.md` (Fase 1.3/1.4).
