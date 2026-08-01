# Contributing to FXBASE

Thank you for your interest in contributing to FXBASE! This document outlines the guidelines and processes for contributing to the project.

## Table of Contents

- [Contributing to FXBASE](#contributing-to-fxbase)
  - [Table of Contents](#table-of-contents)
  - [Code of Conduct](#code-of-conduct)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Fork and Clone](#fork-and-clone)
  - [Development Environment](#development-environment)
    - [Compiler Modes](#compiler-modes)
    - [Project Structure](#project-structure)
    - [Entry Point](#entry-point)
  - [Building the Project](#building-the-project)
    - [Non-Debian/Ubuntu Systems](#non-debianubuntu-systems)
  - [Running Tests](#running-tests)
    - [Test Framework](#test-framework)
    - [Coverage Thresholds (CI)](#coverage-thresholds-ci)
  - [Code Style and Conventions](#code-style-and-conventions)
    - [Pascal Coding Standards](#pascal-coding-standards)
    - [Language Conventions (FXBASE)](#language-conventions-fxbase)
    - [File Organization](#file-organization)
  - [Commit Guidelines](#commit-guidelines)
    - [Message Format](#message-format)
    - [Area Prefixes](#area-prefixes)
    - [Rules](#rules)
  - [Pull Request Process](#pull-request-process)
  - [Issue Reporting](#issue-reporting)
    - [Before Filing](#before-filing)
    - [Bug Reports](#bug-reports)
    - [Feature Requests](#feature-requests)
  - [Architecture Overview](#architecture-overview)
    - [Compiler Pipeline](#compiler-pipeline)
    - [Key Units](#key-units)
  - [Known Issues](#known-issues)
  - [Resources](#resources)
  - [License](#license)

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful and constructive in all interactions.

---

## Getting Started

### Prerequisites

- **Free Pascal Compiler (FPC)** ≥ 3.2.2
- **GNU Make**
- **Git**
- (Optional) SQL database server for testing generated SQL (SQLite works out-of-the-box)

### Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/fxbase.git
cd fxbase

# Add upstream remote
git remote add upstream https://github.com/ORIGINAL_OWNER/fxbase.git
```

---

## Development Environment

### Compiler Modes

- Most units: `{$mode objfpc}`
- `fxb.lexer.pas` and `fxb.ir.pas`: **must** use `{$mode objfpc}` + `advancedRecords` + `typeHelpers` (no `delphi` mode)

### Project Structure

```text
fxbase/
├── src/
│   └── fxb/                # Compiler source (fxb.*.pas, fxb.lpr)
├── tests/
│   ├── unit/               # Token and lexer tests
│   ├── integration/        # Lexer+parser pipeline tests
│   ├── implementation/     # Full program fixtures
│   └── ir/                 # AST→IR lowering tests
├── docs/                   # Design documents
├── Makefile
└── .github/workflows/      # CI configuration
```

### Entry Point

- Main program: `src/fxb/fxb.lpr` → `fxb.cli` → `RunFXCLI`

---

## Building the Project

```bash
# Build the compiler (output: bin/fxbc)
make fxbc          # or simply: make

# Clean build artifacts
make clean

# Quick development build
make dev

# Create distribution tarball
make dist

# Install to /usr/local/bin
sudo make install
```

> **Important**: Always rebuild after edits — stale `.o/.ppu` files in `src/fxb/` cause weird errors (they're git-ignored).

### Non-Debian/Ubuntu Systems

Adjust `FPCFLAGS` in the Makefile for your RTL and generics paths:

```makefile
FPCFLAGS := -n -Mobjfpc -O2 -gl -vewnhi \
  -Fu/path/to/rtl \
  -Fu/path/to/rtl-objpas \
  -Fu$(SRC_DIR)/fxb \
  -Fu/path/to/rtl-generics/src \
  -FEbin -FUbuild
```

---

## Running Tests

| Suite                      | Command                    | Binary                                                 |
|----------------------------|----------------------------|--------------------------------------------------------|
| Unit                       | `make test-unit`           | `bin/test_tokens`, `bin/test_lexer`, `bin/test_sqlite` |
| Integration                | `make test-integration`    | `bin/test_pipeline`                                    |
| Implementation             | `make test-implementation` | `bin/test_impl`                                        |
| IR                         | `make test-ir`             | `bin/test_ir`                                          |
| **All**                    | `make test`                | Stops on first failure                                 |
| Coverage (heuristic)       | `make test-coverage`       | `build/coverage_report.txt`                            |
| Coverage (real, gcov/lcov) | `make test-coverage-real`  | `coverage_html/`                                       |
| Quality metrics            | `make test-quality`        | —                                                      |

### Test Framework

- Custom test framework; non-zero exit = failure
- `make test-all` / `run_all_tests.sh` **deprecated** (skips IR suite)

### Coverage Thresholds (CI)

- Line coverage ≥ 85% (enforced in CI via `test-coverage-real`)
- Heuristic gate: line ratio ≥ 0.5, unit coverage ≥ 50%, function coverage ≥ 10%

---

## Code Style and Conventions

### Pascal Coding Standards

- Follow **Free Pascal coding conventions** (indentation, naming, English comments)
- Use explicit compilation mode at top of each unit: `{$mode objfpc}` or `{$mode delphi}`
- Prefer `advancedRecords` and `typeHelpers` with `{$mode objfpc}`
- Avoid `{$mode delphi}` in new units unless strictly required for compatibility
- Comments: explain complex logic, especially in **parser**, **codegen**, and **optimizer**
- Codebase is intentionally sparse on comments — add only when requested or for non-obvious logic

### Language Conventions (FXBASE)

- Keywords: case-insensitive; `END*` variants required for disambiguation
- Type annotations: `name: T` or `name AS T` (also `AS ARRAY OF T`)
- `FOR` loops close with `NEXT` or `ENDFOR`
- Source files: `.prg` (legacy xBASE) or `.fbg` (FXBASE); headers: `.ch` / `.fbh`
- DB commands (`USE`, `INDEX`, …) compile-time → SQL; no DBF runtime engine

### File Organization

- One unit per file (`fxb.*.pas`)
- Related types grouped in dedicated units (e.g., `fxb.ast.def.pas`, `fxb.ir.types.pas`)
- Keep units focused; avoid circular dependencies

---

## Commit Guidelines

### Message Format

```text
[Area] Brief description of change

Longer explanation if needed (why, not what).
```

### Area Prefixes

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
| `[Refactor]`     | Code restructuring without behavior change |
| `[Fix]`          | Bug fix                                    |
| `[Feat]`         | New feature                                |

### Rules

- **Atomic commits**: one logical change per commit
- **Descriptive messages** in English
- Reference issue numbers when applicable: `Fixes #123`
- No breaking changes without prior discussion and deprecation period

---

## Pull Request Process

1. **Create a feature branch** from `main`:

   ```bash
   git checkout -b feat/my-feature main
   ```

2. **Make your changes** following the code style guidelines

3. **Run the full test suite**:

   ```bash
   make test
   make test-coverage
   make test-quality
   ```

4. **Ensure CI passes** (GitHub Actions will run automatically)

5. **Update documentation** if needed (README, docs/, code comments)

6. **Push and open a PR** against `main`:

   ```bash
   git push origin feat/my-feature
   ```

7. **PR Requirements**:
   - Clear title and description
   - Links to related issues
   - All tests passing
   - No new compiler warnings
   - Coverage maintained or improved

8. **Review Process**:
   - At least one maintainer approval required
   - Parser/semantic changes require extra review
   - Address feedback promptly

9. **Merge**: Squash and merge after approval

---

## Issue Reporting

### Before Filing

- Search existing issues (open and closed)
- Check the [Roadmap](docs/FXBASE-ROADMAP.md) and [Known Issues](#known-issues)
- Try to reproduce with the latest `main`

### Bug Reports

Include:

- **FXBASE version** (`./bin/fxbc --version`)
- **OS / Architecture** (e.g., `Ubuntu 22.04 x86_64`)
- **FPC version** (`fpc -iV`)
- **Minimal reproduction case** (source file + command)
- **Expected vs actual behavior**
- **Stack trace / error output** if applicable

### Feature Requests

Include:

- **Motivation**: What problem does this solve?
- **Technical approach**: High-level implementation sketch
- **Usage examples**: Pascal/FXBASE code demonstrating the feature
- **Test cases**: Proposed test scenarios
- **Performance impact**: Expected effect on compilation/execution time

---

## Architecture Overview

### Compiler Pipeline

```text
Source (.prg/.fbg)
    │
    ▼
┌─────────────────┐
│  Preprocessor   │  (#include, #define, #command, #translate)
│ fxb.preprocessor│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Lexer       │  → Tokens (ttIdent, ttNumber, ttKeyword, …)
│  fxb.lexer.pas  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Parser      │  → AST (typed nodes: Expr, Stmt, Type, …)
│  fxb.parser.pas │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Semantic/IR    │  → Typed 3-address IR (SSA-ish)
│    fxb.ir.pas   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Backend      │  → Native code / SQL (stub: SQL at compile-time)
│ fxb.backend.pas │
└─────────────────┘
```

### Key Units

| Unit                                | Responsibility                                       |
|-------------------------------------|------------------------------------------------------|
| `fxb.lexer.pas`                     | DFA-based tokenizer, modern + legacy syntax          |
| `fxb.parser.pas`                    | Recursive descent, expression precedence, statements |
| `fxb.ast.*.pas`                     | AST node definitions (base, expr, stmt, def)         |
| `fxb.ir.pas` / `fxb.ir.builder.pas` | IR construction, types, instructions                 |
| `fxb.backend.pas`                   | Codegen backend interface (pluggable)                |
| `fxb.preprocessor.pas`              | File inclusion, macros, conditional compilation      |
| `fxb.cli.pas`                       | Command-line parsing, driver orchestration           |
| `fxb.sqlite.pas`                    | SQLite wrapper for DB command translation            |

---

## Known Issues

1. **Bare `RETURN` before keyword** (e.g., `ENDFUNC`): Lexer emits no `ttNewline`, causing `ParseReturn` failures.
   - *Workaround*: Treat `RETURN` as bare when next token can't start an expression.

2. **Parser loops checking `ttNewline`** are dead code (lexer never emits it).
   - *Note*: Do not add logic depending on this token.

3. See [Roadmap](docs/FXBASE-ROADMAP.md) for planned work and current phase status.

---

## Resources

- [Project Roadmap](docs/FXBASE-ROADMAP.md)
- [Grammar Specification](docs/FXBASE-GRAMMAR.md)
- [Compatibility Strategy](docs/FXBASE-COMPATIBILITY-STRATEGY.md)
- [Parallel Compiler Architecture](docs/FXBASE-PARALLEL-COMPILER-ARCHITECTURE.md)
- [Product Requirements](docs/FXBASE-PRD.md)
- [OpenCode Agent Rules](.opencode/rules.md)
- [AGENTS.md](AGENTS.md) — Quick reference for AI agents

---

## License

By contributing, you agree that your contributions will be licensed under the **MIT License** (see `LICENSE` file).

---

*Thank you for contributing to FXBASE!* 🚀
