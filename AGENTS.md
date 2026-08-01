# FXBASE Agent Guide

## Source Layout

- Compiler: `src/fxb/` (units `fxb.*.pas`)
- Entry: `src/fxb/fxb.lpr` → `fxb.cli` → `RunFXCLI`
- Most units: `{$mode objfpc}`
- `fxb.lexer.pas` and `fxb.ir.pas`: **must** use `{$mode objfpc}` + `advancedRecords` + `typeHelpers` (no `delphi` mode)

## Build

- `make fxbc` (or `make all`) → `bin/fxbc`
- `make clean` → removes `build/` and `bin/fxbc*`
- **Always rebuild after edits** — stale `.o/.ppu` in `src/fxb/` cause weird errors (git-ignored)
- Non-Debian/Ubuntu: adjust `FPCFLAGS` in Makefile (RTL + generics paths)

## Tests

| Suite | Command | Binary |
|-------|---------|--------|
| Unit | `make test-unit` | `bin/test_tokens`, `bin/test_lexer` |
| Integration | `make test-integration` | `bin/test_pipeline` |
| Implementation | `make test-implementation` | `bin/test_impl` |
| IR | `make test-ir` | `bin/test_ir` |
| All | `make test` | stops on first failure |
| Coverage | `make test-coverage` | `build/coverage_report.txt` |
| Quality | `make test-quality` | — |

- Custom test framework; non-zero exit = failure
- `make test-all` / `run_all_tests.sh` **deprecated** (skip IR suite)

## Known Issues

- Bare `RETURN` before keyword (e.g. `ENDFUNC`) mis-parsed: lexer emits no `ttNewline`. Fix: treat `RETURN` as bare when next token can't start an expression.
- Parser loops checking `ttNewline` are dead code (lexer never emits it).

## Conventions

- Keywords case-insensitive; `END*` variants required for disambiguation
- Type annotations: `name: T` or `name AS T` (also `AS ARRAY OF T`)
- `FOR` loops close with `NEXT` or `ENDFOR`
- Source: `.prg` (legacy xBASE) or `.fbg` (FXBASE); headers `.ch` / `.fbh`
- Comments discouraged unless requested (codebase intentionally sparse)

## Misc

- DB commands (`USE`, `INDEX`, …) compile-time → SQL; no DBF runtime engine
- `make install` → `/usr/local/bin/fxbc`
- `make dist` → tarball (excludes `build/` and `bin/`)
- See `docs/FXBASE-RULES.md` for mandatory style/contribution rules
- See `.opencode/rules.md` for OpenCode agent behavior rules