# FXBASE Mandatory Style & Contribution Rules

This document is the authoritative source for the style, contribution, and
review rules referenced from `AGENTS.md`. It consolidates the binding rules
from `CLAUDE.md`, `CONTRIBUTING.md`, and `AGENTS.md` so they live in one place.

> These rules are **mandatory**. Changes to the compiler, tests, or build
> system must comply. When in doubt, follow the strictest rule stated here.

---

## 1. Build & Test Invariants

- **Always rebuild after editing any `.pas` file.** Stale `.o`/`.ppu` files in
  `src/fxb/` cause confusing errors. Run `make clean` then `make fxbc`, or at
  minimum `make fxbc`, before testing.
- **The test command is `make test`.** It runs unit + integration +
  implementation + IR suites and **stops on the first failure** (non-zero exit
  = failure). All four suites must be green before a push.
- **Do not commit build artifacts.** `.o`, `.ppu`, `.so`, `bin/`, `build/`,
  `*.s` dumps, and `.hermes/` are git-ignored. Generated assembly dumps
  (`*.s`) are NOT source — keep them out of the tree.
- **Non-Debian/Ubuntu systems:** adjust `FPCFLAGS` in the Makefile (RTL and
  generics paths).

Build targets:
| Command            | Result                          |
|--------------------|---------------------------------|
| `make fxbc`/`make` | `bin/fxbc`                      |
| `make clean`       | remove `build/` and `bin/fxbc*` |
| `make install`     | `/usr/local/bin/fxbc`           |
| `make dist`        | tarball (excludes build & bin)  |

---

## 2. Pascal Coding Standards

- Follow Free Pascal conventions: consistent indentation (2–3 spaces, no mixed
  tabs), clear names, **English comments**.
- **Explicit compilation mode at the top of every unit**: `{$mode objfpc}` or
  `{$mode delphi}` as the module requires.
  - **`fxb.lexer.pas` and `fxb.ir.pas` MUST use `{$mode objfpc}` + `advancedRecords` + `typeHelpers` (never `delphi` mode).**
- Prefer `advancedRecords` and `typeHelpers` with `{$mode objfpc}`.
- Avoid `{$mode delphi}` in new units unless strictly required for compatibility.
- **Comments are intentionally sparse in this codebase.** Add comments only
  when requested, or for non-obvious logic — especially in the **parser**,
  **codegen**, and **optimizer**.
- No breaking changes to the compiler without prior discussion and a
  `deprecated` notice period.
- Keep portability: no platform-locked directives/RTL unless guarded by
  `{$ifdef}`.

---

## 3. Language Conventions (FXBASE)

- Keywords are **case-insensitive**; `END*` variants are **required** for
  disambiguation.
- Type annotations: `name: T` or `name AS T` (also `AS ARRAY OF T`).
- `FOR` loops close with `NEXT` or `ENDFOR`.
- Source files: `.prg` (legacy xBASE) or `.fbg` (FXBASE); headers `.ch` / `.fbh`.
- **DB commands (`USE`, `INDEX`, …) are translated to SQL at compile time;
  there is no DBF runtime engine.**
- The real IR lives in `fxb.ir.pas` (`TFXBIRGenerator`); `fxb.ir.builder.pas`
  is a stub and must not be used as the IR source of truth.

---

## 4. File Organization

- One unit per file, named `fxb.*.pas`.
- Related types grouped in dedicated units (`fxb.ast.def.pas`,
  `fxb.ir.types.pas`, …).
- Keep units focused; avoid circular dependencies.
- Entry point: `src/fxb/fxb.lpr` → `fxb.cli` → `RunFXCLI`.

---

## 5. Commit Rules (Mandatory)

- **Atomic commits:** one logical change per commit. Do **not** bundle
  unrelated areas into a single giant commit.
- **Descriptive messages in English.**
- **Area prefix required**, in brackets, before the summary. Prefer the
  English area prefixes from `CONTRIBUTING.md`:

  | Prefix           | Area                                       |
  |------------------|--------------------------------------------|
  | `[Lexer]`        | Tokenizer / lexical analysis               |
  | `[Parser]`       | Syntax analysis / AST construction         |
  | `[AST]`          | Abstract syntax tree nodes                 |
  | `[IR]`           | Intermediate representation / lowering     |
  | `[Backend]`      | Code generation / native backend           |
  | `[Preprocessor]` | `#include`, `#define`, `#command`, etc.    |
  | `[CLI]`          | Command-line interface                     |
  | `[Tests]`        | Test suite changes                         |
  | `[Docs]`         | Documentation updates                      |
  | `[Build]`        | Makefile / build system                    |
  | `[Infra]`        | CI, tooling, scripts                       |
  | `[Refactor]`     | Restructuring without behavior change      |
  | `[Fix]`          | Bug fix                                    |
  | `[Feat]`         | New feature                                |

  > Note: `AGENTS.md` examples use bilingual prefixes (e.g. `[Parser]`,
  > `[Backend]`, `[Misc]`). English area prefixes (above) are the canonical
  > form; `[Misc]` / `[CLAUDE]` are accepted for cross-cutting or meta changes.

- Message format:
  ```text
  [Area] Brief description of change

  Longer explanation if needed (the why, not the what).
  ```
- Reference issue numbers when applicable: `Fixes #123`.
- **Never commit `.o`/`.ppu`/`.s`/build artifacts** (git-ignored).
- **`git push` only when the user asks.** Commits are local until then.

---

## 6. Pull Request Process

1. Branch from `main`: `git checkout -b feat/my-feature main`.
2. Make changes following the style rules above.
3. Run `make test` (and `make test-coverage`, `make test-quality` if CI gates apply).
4. Ensure CI passes (GitHub Actions).
5. Update documentation if needed (README, `docs/`, code comments).
6. Push and open a PR against `main`.
7. PR requirements: clear title/description, linked issues, all tests passing,
   no new compiler warnings, coverage maintained or improved.
8. Review: at least one maintainer approval. **Parser/semantic changes require
   extra review.**
9. Merge via squash after approval.

---

## 7. Security & Quality Gates (Local-First)

- No external APIs / telemetry: the whole lifecycle runs locally. Do not send
  code or metrics to remote services.
- Do not emit assembly (inline or codegen) without validating performance and
  target-architecture compatibility.
- Optimizations touching codegen must be tested on the supported target
  architectures (x86_64 at minimum; ARM/AArch64 when applicable) before merge.
- Any change to the parser or semantic analyzer needs review by a second
  developer, or a second regression pass.
- Generated files must not contain **absolute paths** that break portability;
  use relative paths / environment variables.

---

## 8. Known Issues (Hard Constraints)

These are live constraints, not just bugs — respect them:

1. **Bare `RETURN` before a keyword** (e.g. `ENDFUNC`): the lexer emits no
   `ttNewline`, which breaks `ParseReturn`. Treat `RETURN` as bare when the
   next token cannot start an expression.
2. **Parser loops checking `ttNewline` are dead code** — the lexer never emits
   it. Do not add logic depending on `ttNewline`.
3. See `docs/FXBASE-ROADMAP.md` for phase status and planned work.

---

## 9. Resources

- `AGENTS.md` — quick reference for AI agents
- `CLAUDE.md` — local Free Pascal compiler rules
- `CONTRIBUTING.md` — full contribution guide
- `docs/FXBASE-GRAMMAR.md` — grammar specification
- `docs/FXBASE-ROADMAP.md` — roadmap and phase status
- `docs/FXBASE-COMPATIBILITY-STRATEGY.md`
- `docs/FXBASE-PARALLEL-COMPILER-ARCHITECTURE.md`
- `docs/FXBASE-PRD.md`
- `.opencode/rules.md` — OpenCode agent behavior rules
