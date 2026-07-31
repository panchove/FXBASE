# FPXBASE — Agent Notes

xBASE-to-SQL compiler in Free Pascal. **Phase 0** complete (lexer, parser, AST, preprocessor). **Phase 1.1** in progress (IR generation). End-to-end compile → run is not wired: `fpx.ir`, `fpx.backend`, `fpx.rtl`, `fpx.ppo` are either empty stubs or, in the case of `fpx.ir`, the work-in-progress file.

## Source layout

Compiler source lives in **`src/fpx/`** only. The other `src/` subdirs (`ast/`, `lexer/`, `parser/`, `ir/`, `backend/`, `rtl/`, `std/`) and most of `src/tools/*` are empty placeholders — **do not add files there**.

Units in `src/fpx/`:
- `fpx.tokens.pas` — `TTokenType`, `TKeyword` (~200 entries), `TToken`, `KeywordFromString`. Single source of truth for tokens. **Mode: objfpc.**
- `fpx.lexer.pas` — `TFPXLexer`; `TLexer = TFPXLexer` alias. Exposes `Tokenize()` (bulk) and `NextToken` (streaming). **Mode: delphi.**
- `fpx.parser.pas` — `TParser.Create(Lexer: TLexer; Reporter: TErrorReporter)`; `ParseProgram` (no args, reads from constructor lexer). **Mode: objfpc.**
- `fpx.ast.pas` — AST node hierarchy; `TCompilationUnit.Dump`. **Mode: objfpc.**
- `fpx.preprocessor.pas`, `fpx.errors.pas`, `fpx.cli.pas`. **Mode: delphi** (with `advancedRecords`+`typeHelpers`).
- `fpx.ir.pas`, `fpx.backend.pas`, `fpx.rtl.pas`, `fpx.ppo.pas` — referenced by `fpx.cli`; `fpx.ir` is being filled in (Phase 1.1), the other three are empty stubs.
- `fpx.lpr` — single canonical entry point at `src/fpx/fpx.lpr`. Uses only `fpx.cli`; everything else transitive.

**Match the existing unit's mode when editing** — `{$mode delphi}` + `advancedRecords`/`typeHelpers` for most, `{$mode objfpc}` for `fpx.tokens` and `fpx.parser`.

## Build

```bash
make fpx               # bin/fpx from src/fpx/fpx.lpr
make all               # also fpx-fmt, fpx-dbf (fpx-lsp/dap/pkg have no .lpr yet)
make clean             # rm -rf build bin/fpx*
```

- Compiler: **Free Pascal 3.2.2**. `fpc.cfg.bak` is a reference; no active `fpc.cfg`.
- `Makefile` hardcodes `/usr/lib/x86_64-linux-gnu/fpc/3.2.2/...` (rtl) and `/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src` (for `Generics.Collections` used in lexer/IR). On other distros adjust `FPCFLAGS` or symlink.
- A stray `fpc-source-3.2.2_3.2.2+dfsg-46_all.deb` sits in repo root (install artifact, not source).
- After editing `src/fpx/fpx.lpr` or any `fpx.*.pas`, **always rebuild** — `.ppu/.o` in `src/fpx/` are checked-in byproducts; FPC will overwrite them, but stale units in `build/` can mask real errors.

## Test

Three suites, each a separate FPC build that emits `bin/test_*`. FPC stderr is **not** redirected — compile failures are visible.

```bash
make test-unit            # bin/test_tokens + bin/test_lexer
make test-integration     # bin/test_pipeline  (lexer+parser)
make test-implementation  # bin/test_impl      (real fixtures)
make test                 # all three above (aborts on first failed suite)
make test-all             # verbose pass/fail summary
make test-coverage        # tests/metrics/coverage.sh (heuristic)
make test-quality         # tests/metrics/quality.sh (LOC / density / branch count)
```

Test binaries call `Halt(1)` if `GStats.Failed > 0`, so a non-zero exit from any `bin/test_*` means failure. Test framework is **custom** (`tests/fpx.test.framework.pas`, no FPCUnit). Use `AssertEquals`/`AssertTrue`/`AssertEqualsI`/`AssertSameStr` and `RegisterTest`. Failures raise `ETestFailure`; the framework catches them so all tests run regardless of any single failure.

Fixtures in `tests/fixtures/`: `hello.fpg`, `program.fpg`, `nested.fpg`, `legacy.prg`, `dbf_legacy.prg`. Empty placeholder dirs that may confuse you: `tests/ast/`, `tests/lexer/`, `tests/parser/`, plus `test/hello.prg` and `test.prg`/`test2.prg` at repo root (hand-written lexer/parser inputs, not executable).

**Current state:** 52 tests pass across 4 binaries (tokens=13, lexer=21, pipeline=6, implementation=12).

## Conventions

- xBASE keywords: case-insensitive. `END` suffix variants (`ENDIF`, `ENDDO`, `ENDCASE`, `ENDSWITCH`, `ENDCLASS`, …) are required for parser disambiguation.
- Lexer aliases `SELF` → `kwThis` (canonical spelling in `KeywordNames` is `THIS`).
- xBASE `.AND.`/`.OR.`/`.NOT.`/`.XOR.` emit `ttDotAnd`/`ttDotOr`/`ttDotNot`/`ttXor` (single tokens, not three).
- Square-bracket string literals `[hello]` via `ScanString` with terminator remap.
- Preprocessor: `#command`/`#translate` / `#xcommand`/`#xtranslate`. `std.fph` auto-included; user headers via `#include "file.fph"`.
- DB commands (`USE`, `INDEX`, `SET RELATION`, `REPLACE`, `APPEND`, `PACK`, `ZAP`) translate at compile time to SQL — no runtime DBF.
- File extensions: `.prg` (legacy xBASE), `.fpg` (FPXBASE), `.fph` (header), `.ppo` (preprocessor output).
- Source strings are UTF-8 unless `--db-ansi`.
- **Comments are off by convention** — do not add code comments unless the user asks. The codebase is intentionally comment-light.
- Follow the AST/IR/parser style: objfpc classes with `Create(...)`, `Destroy; override;`, virtual `Dump(Indent: Integer = 0): string;`. Anonymous methods for test bodies use `@Name` syntax.

## Known integration gaps (in-progress)

- `fpx.backend`, `fpx.rtl`, `fpx.ppo` are empty stubs referenced by `fpx.cli`. The CLI compiles because the stubs define the type/function signatures the CLI expects; actual codegen (compile → run) is not wired.
- `fpx.ir.pas` is being built up incrementally (Phase 1.1). `TFPXIRGenerator.Generate(AST)` lowers AST → `TIRModule` for: empty functions, locals, assignments, IF/ELSE/ENDIF (then/else/merge blocks), WHILE (cond/body/exit), FOR (init/cond/body/step/exit), binary ops, RETURN. Not yet: classes, generics, codeblocks, lambdas, macros `&`, `@...SAY/GET`.
- Sample programs at repo root (`test.prg`, `test2.prg`, `test/hello.prg`) are hand-written test inputs for the lexer/parser, not yet executable.
- Docs marked `[Roadmap]` (`PRD §5.A/5.B/5.C`, `GRAMMAR §11`, `PARALLEL-COMPILER-ARCHITECTURE §🧬/🧪/🚄`) describe features that are **specified but not implemented** — tokens exist in the lexer but the parser/IR/RTL don't enforce semantics. Treat those sections as aspirational, not authoritative.

## Key references

- `docs/PRD-FPXBASE.md` — product spec, language features, error codes (FPX-nnnn / FPW-nnnn). Includes §5.A/5.B/5.C Roadmap sections (compatibilidad xBase estratificada, tipado gradual, smart pointers — todos pendientes de implementación).
- `docs/GRAMMAR-FXBASE.md` — EBNF grammar (xBASE + FPXBASE extensions). §9 directive grammar is partially implemented (CLI flags recognized; `#pragma strict`/`#pragma gc`/`#entry` documented but no effect). §11 Roadmap backs STRUCT/CLASS distinction and smart pointers.
- `docs/ROADMAP.md` — phases 0–6 milestones.
- `docs/PARALLEL-COMPILER-ARCHITECTURE.md` — phase 0.5 design. Sections "🧬 RTL memory manager", "🧪 preprocessor cache key with global state", "🚄 RDD SQL prefetching" are Roadmap (stubs in `fpx.rtl.pas`/`fpx.ppo.pas`).
- `docs/COMPATIBILITY-STRATEGY.md` — tiered 80/20 strategy for xBASE legacy adoption (T1 syntax, T2 DB→SQL, T3 macros). Source of truth for migration tiers and `#pragma strict`.

## Session log

### 2026-07-30 — Token type unification
Two incompatible token systems merged into `fpx.tokens.pas`. `fpx.lexer.pas` rewritten to use it; exposes both `Tokenize()` (bulk) and `NextToken` (streaming).

### 2026-07-30 — Test infrastructure + lexer fixes
**Test scripts (`run_unit.sh`, `run_integration.sh`, `run_implementation.sh`, `run_all_tests.sh`):** added `-Fu/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src` (main `Makefile` already had it; test scripts didn't, so `fpx.lexer` couldn't resolve `Generics.Collections`). Removed `2>/dev/null` from all `fpc` invocations so compile errors are now visible.

**`tests/fpx.test.framework.pas`:** `RunAllTests` now calls `Halt(1)` if `GStats.Failed > 0`. Previously test binaries exited 0 regardless of failed assertions, so `make test` reported "All test suites passed" even with failures.

**`src/fpx/fpx.lexer.pas` — 7 bugs fixed:**
1. `AddTokenFull` calls for digit/string dispatch discarded literal values (`IntValue=0`, `StrValue=''`). Now propagate `tok.*Value`.
2. Trailing `AddToken(ttEof, '')` removed — `NextToken` already returns `ttEof` past the end; the extra EOF inflated `Length(FTokens)` by 1.
3. `ScanOperator` now detects `.AND.`/`.OR.`/`.NOT.`/`.XOR.` and emits `ttDotAnd`/`ttDotOr`/`ttDotNot`/`ttXor` with corresponding `kw*`. Previously these collapsed to three tokens (`.` + identifier + `.`).
4. `.T.`/`.F.` now emit `ttLogical` with `IntValue` 1/0.
5. `NIL` keyword now emits `ttNil` (was `ttKeyword + kwNil`).
6. `[hello]` square-bracket string literals supported — `[` dispatched to `ScanString`; `ScanString` remaps `[` → `]` so the terminator works.
7. `&&` no longer swallowed as line comment — the operator path emits `ttAnd`.

**`src/fpx/fpx.tokens.pas`:** `TokenTypeName` no longer wraps `ttDoubleColon`/`ttQuestionColon`/`ttQuestionDot`/`ttPlusAssign`/`ttEq` in single quotes (matches raw symbol convention).

**`src/fpx/fpx.lexer.pas`:** added `SELF → kwThis` to `FKeywordMap` (canonical spelling remains `THIS`).

**`src/fpx/fpx.lpr` + `Makefile`:** reconciled the duplicate `fpx.lpr` files. `src/tools/fpx/fpx.lpr` (and its directory) removed; `src/fpx/fpx.lpr` is the single entry point with full `uses` clause, calls `RunFPXCLI`. `Makefile` `fpx` target now points to `src/fpx/fpx.lpr`. Removed bogus `{$R *.res}` (no `.res` exists).

**`tests/integration/test_pipeline.pas`, `tests/implementation/test_implementation.pas`:** updated `TParser.Create` calls from no-arg to `TParser.Create(lex, reporter)` and `ParseProgram` calls from `ParseProgram(tokens, name)` to `ParseProgram` (no args, reads from constructor lexer). Matches unified parser API.

**`tests/unit/test_lexer.pas`, `tests/implementation/test_implementation.pas`:** fixed two pre-existing test bugs revealed by full rebuild — `TestImpl_Program_GenericBracket` searched for `ttLt` + `kwEndClass` (never adjacent in `program.fpg`); corrected to `ttLt` + `ttIdentifier` (matches `Stack<T>`, `Stack<INTEGER>`).

**Final state at end of session:** `make fpx` + `make test` → 52/52 tests passing across 4 binaries (corrected from 54 — original count was off by two). `make test` exits 0 on success and aborts on any failure.

### 2026-07-30 — Docs alignment + compatibility strategy

User asked to verify doc/code alignment and add the tiered 80/20 compatibility strategy for xBASE legacy adoption. Investigation revealed `PRD`, `GRAMMAR`, `PARALLEL-COMPILER-ARCHITECTURE` (and `ROADMAP`) all had uncommitted edits describing features that are not implemented (`#pragma strict`, smart pointers `UNIQUE_PTR/SHARED_PTR/WEAK_PTR`, RTL multi-model memory manager, preprocessor cache key with global state, RDD SQL prefetching). Reverted the four docs to the last committed state, then re-added the requested sections with explicit `[Roadmap]` banners and implementation status tables.

**New doc:** `docs/COMPATIBILITY-STRATEGY.md` — tiered 80/20 strategy (T1 syntax ~95%, T2 DB legacy ~80%/binary 0%, T3 macros ~30%) with rationale, `fpx-dbf` import/export, linter patterns, prefetching reference. Source of truth for migration tiers and `#pragma strict`.

**`docs/PRD-FPXBASE.md`:** added §5.A Roadmap (Compatibilidad xBase Estratificada), §5.B Roadmap (Tipado Gradual & Directivas de Estrictez), §5.C Roadmap (Tipos Valor vs Referencia + Smart Pointers). Each section: status table by tier, rationale, examples, cross-references.

**`docs/GRAMMAR-FXBASE.md`:** §9 expanded with `StrictDirective` + `LegacyStrictDirective` EBNF and an implementation status table for each directive. Added new §11 (Roadmap) with full EBNF for `#pragma strict`, type annotations `:`, STRUCT vs CLASS, smart pointers `UNIQUE_PTR<T>`/`SHARED_PTR<T>`/`WEAK_PTR<T>`, syntax examples, and a status table (which tokens are in `fpx.tokens.pas`, which directives have no effect, what is pending for Fase 2.5).

**`docs/PARALLEL-COMPILER-ARCHITECTURE.md`:** added §🧬 (RTL memory manager multi-modelo: RefCount+cycle, Generational/Region, RAII), §🧪 (cache key compuesto con estado global del preprocesador, formato conceptual), §🚄 (RDD SQL prefetching & batching, default N=100, `DISABLE PREFETCH` pragma, interacción con `#pragma strict` e iteradores).

**All four docs now use a consistent `[Roadmap]` banner:** status table at the top of each new section, "implemented vs pending" callouts, cross-references between PRD/GRAMMAR/ARCHITECTURE/COMPATIBILITY-STRATEGY. No code changes — docs only.
