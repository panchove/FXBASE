# AGENTS.md — FXBASE Specification Repository

## Repository Purpose
This repo contains **only the specification documents** for the FXBASE programming language. No implementation code exists here.

## Document Structure (load order matters)

| File | Role | Depends On |
|------|------|------------|
| `FXBASE_PRD_v1.0.0.md` | Product Requirements — source of truth for features | — |
| `FXBASE_GRAMMAR.md` | Formal EBNF syntax specification | PRD |
| `FXBASE_ARCH.md` | System architecture (compiler, runtime, tooling) | PRD, GRAMMAR |
| `FXBASE_SPEC.md` | Technical specification (semantics, APIs, CLI, conformance) | PRD, GRAMMAR, ARCH |

**Rule:** When updating one document, verify consistency with its dependencies.

## Working with This Repo

### Edit workflow
1. Read the dependent documents first (see table above)
2. Make changes to the target document
3. Cross-check affected sections in dependent documents
4. Update version/date in modified file headers

### Validation
No automated validation exists. Manual checks:
- Grammar productions match PRD language features
- Architecture components cover all SPEC subsystems
- SPEC CLI matches ARCH tooling design
- Version numbers consistent across all four files

### Versioning
All four documents share the same version (currently `1.0.0-alpha`). Increment together.

## Conventions
- Dates: ISO 8601 (`YYYY-MM-DD`)
- RFC 2119 keywords (MUST/SHOULD/MAY) in SPEC only
- EBNF in GRAMMAR uses `::=`, `|`, `[ ]`, `{ }`, `( )`, `" "`
- Diagrams: Mermaid-compatible markdown fenced blocks

## What Not to Do
- Don't add implementation code here
- Don't create subdirectories under `docs/`
- Don't commit generated artifacts

## Related Repositories (not in this repo)
- Compiler implementation: separate repo (TBD)
- Standard library (FXSTD): separate repo (TBD)
- Package registry: separate service