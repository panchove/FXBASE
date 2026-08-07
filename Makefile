# FXBASE - Fast xBASE Compiler
# Makefile for building the compiler and tools

SHELL := /bin/bash

FPC := fpc
SRC_DIR := src
FPCFLAGS := -n -Mobjfpc -O2 -gl -vewnhi -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl-objpas -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/fcl-base -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/hash -Fu$(SRC_DIR)/fxb -Fu/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src -FEbin -FUbuild
BUILD_DIR := build
BIN_DIR := bin

# Semantic version
VERSION := $(shell cat VERSION 2>/dev/null || echo 0.0.0)

# Main targets
.PHONY: all clean test fxbc install fxbc

all: fxbc

# Main compiler
fxbc: $(BUILD_DIR) $(BIN_DIR) lib/libsqlite3.so lib/libpq.so lib/libodbc.so
	@# FPC does not track {$I ...inc} dependencies for incremental builds, so an
	@# edited .inc leaves the including unit's .ppu/.o stale. Detect a newer .inc
	@# per including unit and force a clean rebuild so the edit always applies.
	@rm -f .fxb_inc_stale; \
	for pair in "fxb.backend.runtime.inc fxb.backend" "fxb.backend.db.inc fxb.backend" \
	            "fxb.backend.pg.inc fxb.backend" "fxb.backend.ms.inc fxb.backend" \
	            "fxb.cli.args.inc fxb.cli" "fxb.cli.driver.inc fxb.cli"; do \
	  set -- $$pair; inc=$$1; unit=$$2; \
	  if [ -f "$(BUILD_DIR)/$$unit.ppu" ] && [ -f "$(SRC_DIR)/fxb/$$inc" ] && \
	     [ "$(SRC_DIR)/fxb/$$inc" -nt "$(BUILD_DIR)/$$unit.ppu" ]; then \
	    echo "  $$inc newer than $$unit.ppu; forcing rebuild"; touch .fxb_inc_stale; \
	  fi; \
	done; \
	if [ -f .fxb_inc_stale ]; then rm -f $(BUILD_DIR)/*.o $(BUILD_DIR)/*.ppu; rm -f .fxb_inc_stale; fi
	$(FPC) $(FPCFLAGS) -Fllib -k-lsqlite3 -k-lpq -k-lodbc -k--dynamic-linker=/lib64/ld-linux-x86-64.so.2 -o$(BIN_DIR)/fxbc $(SRC_DIR)/fxb/fxb.lpr

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Testing
test: test-unit test-integration test-implementation test-ir
	@echo "All test suites passed."

# Local symlink so the linker finds libsqlite3 without libsqlite3-dev installed.
# Points at the system shared object (libsqlite3.so.0); the resulting binary still
# depends on the system libsqlite3 at runtime (local, no network).
lib/libsqlite3.so:
	@mkdir -p lib
	@ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 lib/libsqlite3.so

# Local symlink for libpq (PostgreSQL client library).
lib/libpq.so:
	@mkdir -p lib
	@ln -sf /usr/lib/x86_64-linux-gnu/libpq.so.5 lib/libpq.so

# Local symlink for libodbc (MSSQL ODBC driver).
lib/libodbc.so:
	@mkdir -p lib
	@ln -sf /usr/lib/x86_64-linux-gnu/libodbc.so.2 lib/libodbc.so

test-unit: fxbc lib/libsqlite3.so
	@bash tests/run_unit.sh

test-integration: fxbc
	@bash tests/run_integration.sh

test-implementation: fxbc
	@bash tests/run_implementation.sh

test-ir: fxbc
	@bash tests/run_ir.sh

test-all: fxbc
	@bash tests/run_all_tests.sh

test-coverage:
	@bash tests/metrics/coverage.sh

test-quality:
	@bash tests/metrics/quality.sh

# Fase 0.5 verification benchmark: clean <2s (100 files, 8 cores), incremental <150ms
bench: fxbc
	@bash tests/bench/fxbench.sh

# Clean
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)/fxbc*

# Install
install: all
	install -d /usr/local/bin
	install $(BIN_DIR)/fxbc /usr/local/bin/fxbc
	@echo "Installed to /usr/local/bin"

# Development
dev: fxbc
	@echo "Build complete. Run ./bin/fxbc --help"

# Documentation
docs:
	@echo "Generating docs..."
	@cd docs && make

# Package
dist: clean all
	tar -czf fxbase-$(VERSION).tar.gz --exclude=.git --exclude=build --exclude=bin/fxbc* .

# Real coverage (gcov/lcov via FPC -Fpg)
test-coverage-real:
	$(MAKE) clean
	$(MAKE) FPCFLAGS="$(FPCFLAGS) -pg -Fpg" all
	$(MAKE) test
	lcov --capture --directory $(BUILD_DIR) --output-file coverage.info
	genhtml coverage.info --output-directory coverage_html

# Strict heuristic coverage gate
test-coverage-strict:
	@bash tests/metrics/coverage.sh | tee /tmp/cov.txt; \
	LINE_RATIO=$$(grep "Test:Source line ratio" /tmp/cov.txt | awk '{print $$3}' | sed 's/:1//'); \
	UNIT_PCT=$$(grep "Unit usage coverage" /tmp/cov.txt | awk '{print $$3}' | sed 's/%//'); \
	FUNC_PCT=$$(grep "Estimated function coverage" /tmp/cov.txt | awk '{print $$3}' | sed 's/%//'); \
	echo "Ratios: line=$$LINE_RATIO unit=$$UNIT_PCT% func=$$FUNC_PCT%"; \
	if [ $$(echo "$$LINE_RATIO < 0.5" | bc -l) -eq 1 ]; then echo "Line ratio too low"; exit 1; fi; \
	if [ $$(echo "$$UNIT_PCT < 50" | bc -l) -eq 1 ]; then echo "Unit coverage too low"; exit 1; fi; \
	if [ $$(echo "$$FUNC_PCT < 10" | bc -l) -eq 1 ]; then echo "Function coverage too low"; exit 1; fi

# Help
help:
	@echo "FXBASE Makefile targets:"
	@echo "  all                 - Build main compiler (default)"
	@echo "  fxbc                - Build main compiler"
	@echo "  test                - Run all unit/integration/impl/IR tests"
	@echo "  test-unit           - Run unit tests only"
	@echo "  test-integration    - Run integration tests only"
	@echo "  test-implementation - Run implementation tests only"
	@echo "  test-ir             - Run IR lowering tests only"
	@echo "  test-all            - Run full suite (verbose)"
	@echo "  test-coverage       - Generate coverage report"
	@echo "  test-quality        - Generate quality metrics"
	@echo "  bench               - Fase 0.5 verification benchmark"
	@echo "  test-coverage-real  - Real gcov/lcov coverage"
	@echo "  test-coverage-strict- Strict heuristic coverage gate"
	@echo "  clean               - Clean build artifacts"
	@echo "  install             - Install to /usr/local/bin"
	@echo "  dev                 - Quick dev build"
	@echo "  docs                - Generate documentation"
	@echo "  dist                - Create distribution tarball"
	@echo "  help                - Show this help"

# Version management
bump-patch:
	@V=$$(cat VERSION); \
	IFS=. read -r major minor patch <<< "$$V"; \
	patch=$$((patch+1)); \
	echo "$$major.$$minor.$$patch" > VERSION; \
	echo "Bumped to $$(cat VERSION)"

bump-minor:
	@V=$$(cat VERSION); \
	IFS=. read -r major minor patch <<< "$$V"; \
	minor=$$((minor+1)); \
	patch=0; \
	echo "$$major.$$minor.$$patch" > VERSION; \
	echo "Bumped to $$(cat VERSION)"

bump-major:
	@V=$$(cat VERSION); \
	IFS=. read -r major minor patch <<< "$$V"; \
	major=$$((major+1)); \
	minor=0; \
	patch=0; \
	echo "$$major.$$minor.$$patch" > VERSION; \
	echo "Bumped to $$(cat VERSION)"

release: bump-patch
	@git add VERSION
	@git commit -m "chore: release $$(cat VERSION)"
	@git tag -a v$$(cat VERSION) -m "Release $$(cat VERSION)"
	@echo "Released version $$(cat VERSION). Push with: git push && git push --tags"
