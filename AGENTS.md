# FXBASE Agent Guide

## Source Layout
- Compiler: `src/fxb/` (units `fxb.*.pas`)
- Entry: `src/fxb/fxb.lpr` → `fxb.cli` → `RunFXCLI`
- Most units: `{$mode objfpc}`
- **`fxb.lexer.pas` and `fxb.ir.pas` MUST use `{$mode objfpc}` + `advancedRecords` + `typeHelpers` (no `delphi` mode)**

## Build
- `make fxbc` (or `make all`) → `bin/fxbc`
- `make clean` → removes `build/` and `bin/fxbc*`
- **Always rebuild after edits** — stale `.o/.ppu` in `src/fxb/` cause weird errors (git-ignored)
- Non-Debian/Ubuntu: adjust `FPCFLAGS` in Makefile (RTL + generics paths)
- `make install` → `/usr/local/bin/fxbc`
- `make dist` → tarball (excludes `build/` and `bin/`)

## Tests
| Suite | Command | Binary |
|-------|---------|--------|
| Unit | `make test-unit` | `bin/test_tokens`, `bin/test_lexer`, `bin/test_sqlite` |
| Integration | `make test-integration` | `bin/test_pipeline` |
| Implementation | `make test-implementation` | `bin/test_impl` |
| IR | `make test-ir` | `bin/test_ir` |
| All | `make test` | **stops on first failure** |
| Coverage | `make test-coverage` | `build/coverage_report.txt` |
| Quality | `make test-quality` | — |

- Custom test framework (`tests/fxb.test.framework.pas`); non-zero exit = failure
- `make test-all` / `run_all_tests.sh` **deprecated** (skips IR suite)
- Test binaries built from `tests/unit/`, `tests/integration/`, `tests/implementation/`
- Test FPC flags in `tests/run_common.sh` (uses `{$mode delphi}`)
- End-to-end tests: `./test_e2e.sh` (includes DB runtime and scope-clause tests)

## Known Issues (Hard Constraints)
1. **Bare `RETURN` before keyword** (e.g. `ENDFUNC`): lexer emits no `ttNewline`. Fix: treat `RETURN` as bare when next token can't start an expression.
2. **Parser loops checking `ttNewline` are dead code** — lexer never emits it. Do not add logic depending on `ttNewline`.

## Conventions
- Keywords case-insensitive; `END*` variants required for disambiguation
- Type annotations: `name: T` or `name AS T` (also `AS ARRAY OF T`)
- `FOR` loops close with `NEXT` or `ENDFOR`
- Source: `.prg` (legacy xBASE) or `.fbg` (FXBASE); headers `.ch` / `.fbh`
- **DB commands (`USE`, `INDEX`, …) compile-time → SQL; runtime parameters bind via SQLite `?` placeholders (SysV x86_64 only; other targets fall back to compile-time SQL)**
- Comments discouraged unless requested (codebase intentionally sparse)
- English comments required in new/modified code

## File Organization
- One unit per file: `fxb.*.pas`
- Related types grouped in dedicated units (`fxb.ast.def.pas`, `fxb.ir.types.pas`, …)
- **IR lowering lives in `fxb.ir.builder.pas` (`TIRBuilder`)**; `fxb.ir.pas` is `TFXBIRGenerator` (front-end wrapper that drives the builder). `fxb.ir.expr.inc` / `fxb.ir.stmt.inc` are DEAD (included nowhere) — do not edit or build on them
- `.inc` files are NOT tracked by FPC as dependencies of `{$I}`; after editing an `.inc`, run `make clean && make fxbc` (the Makefile also force-rebuilds for the backend/cli `.inc` pairs)
- Explicit compilation mode at top of every unit: `{$mode objfpc}` or `{$mode delphi}`

## Commit Rules (Mandatory)
- **Atomic commits:** one logical change per commit
- **Descriptive messages in English**
- **Area prefix required** (in brackets): `[Lexer]`, `[Parser]`, `[AST]`, `[IR]`, `[Backend]`, `[Preprocessor]`, `[CLI]`, `[Tests]`, `[Docs]`, `[Build]`, `[Infra]`, `[Refactor]`, `[Fix]`, `[Feat]`
- Format:
  ```
  [Area] Brief description of change

  Longer explanation if needed (the why, not the what).
  ```
- Reference issues: `Fixes #123`
- Never commit build artifacts (`.o`, `.ppu`, `.s`, `bin/`, `build/`)
- `git push` only when user asks

## References
- `docs/FXBASE-RULES.md` — mandatory style/contribution rules (authoritative)
- `docs/FXBASE-GRAMMAR.md` — grammar spec
- `docs/FXBASE-ROADMAP.md` — phase status
- `.opencode/rules.md` — OpenCode agent behavior rules
- `CONTRIBUTING.md` — full contribution guide