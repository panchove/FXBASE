# FPXBASE - Free Pascal xBASE Compiler
# Makefile for building the compiler and tools

FPC := fpc
SRC_DIR := src
FPCFLAGS := -n -Mobjfpc -O2 -gl -vewnhi -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl-objpas -Fu$(SRC_DIR)/fpx -Fu/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src -FEbin -FUbuild
BUILD_DIR := build
BIN_DIR := bin

# Main targets
.PHONY: all clean test fpx fpx-lsp fpx-fmt fpx-pkg fpx-dbf fpx-dap install

all: fpx fpx-fmt fpx-dbf

# Main compiler
fpx: $(BUILD_DIR) $(BIN_DIR)
	$(FPC) $(FPCFLAGS) -o$(BIN_DIR)/fpx $(SRC_DIR)/fpx/fpx.lpr

fpx-lsp: $(BUILD_DIR) $(BIN_DIR)
	$(FPC) $(FPCFLAGS) -o$(BIN_DIR)/fpx-lsp $(SRC_DIR)/tools/fpx-lsp/fpx-lsp.lpr

fpx-fmt: $(BUILD_DIR) $(BIN_DIR)
	$(FPC) $(FPCFLAGS) -o$(BIN_DIR)/fpx-fmt $(SRC_DIR)/tools/fpx-fmt/fpx-fmt.lpr

fpx-pkg: $(BUILD_DIR) $(BIN_DIR)
	$(FPC) $(FPCFLAGS) -o$(BIN_DIR)/fpx-pkg $(SRC_DIR)/tools/fpx-pkg/fpx-pkg.lpr

fpx-dbf: $(BUILD_DIR) $(BIN_DIR)
	$(FPC) $(FPCFLAGS) -o$(BIN_DIR)/fpx-dbf $(SRC_DIR)/tools/fpx-dbf/fpx-dbf.lpr

fpx-dap: $(BUILD_DIR) $(BIN_DIR)
	$(FPC) $(FPCFLAGS) -o$(BIN_DIR)/fpx-dap $(SRC_DIR)/tools/fpx-dap/fpx-dap.lpr

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Testing
test: test-unit test-integration test-implementation
	@echo "All test suites passed."

test-unit: fpx
	@bash tests/run_unit.sh

test-integration: fpx
	@bash tests/run_integration.sh

test-implementation: fpx
	@bash tests/run_implementation.sh

test-all: fpx
	@bash tests/run_all_tests.sh

test-coverage:
	@bash tests/metrics/coverage.sh

test-quality:
	@bash tests/metrics/quality.sh

# Clean
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)/fpx*

# Install
install: all
	install -d /usr/local/bin
	install $(BIN_DIR)/fpx /usr/local/bin/fpx
	install $(BIN_DIR)/fpx-fmt /usr/local/bin/fpx-fmt
	install $(BIN_DIR)/fpx-dbf /usr/local/bin/fpx-dbf
	@echo "Installed to /usr/local/bin"

# Development
dev: fpx
	@echo "Build complete. Run ./bin/fpx --help"

# Documentation
docs:
	@echo "Generating docs..."
	@cd docs && make

# Package
dist: clean all
	tar -czf fpxbase-$(VERSION).tar.gz --exclude=.git --exclude=build --exclude=bin/fpx* .

# Help
help:
	@echo "FPXBASE Makefile targets:"
	@echo "  all                 - Build all tools (default)"
	@echo "  fpx                 - Build main compiler"
	@echo "  fpx-lsp             - Build LSP server"
	@echo "  fpx-fmt             - Build formatter"
	@echo "  fpx-pkg             - Build package manager"
	@echo "  fpx-dbf             - Build DBF import/export tool"
	@echo "  fpx-dap             - Build DAP debugger"
	@echo "  test                - Run all unit/integration/impl tests"
	@echo "  test-unit           - Run unit tests only"
	@echo "  test-integration    - Run integration tests only"
	@echo "  test-implementation - Run implementation tests only"
	@echo "  test-all            - Run full suite (verbose)"
	@echo "  test-coverage       - Generate coverage report"
	@echo "  test-quality        - Generate quality metrics"
	@echo "  clean               - Clean build artifacts"
	@echo "  install             - Install to /usr/local/bin"
	@echo "  dev                 - Quick dev build"
	@echo "  docs                - Generate documentation"
	@echo "  dist                - Create distribution tarball"
	@echo "  help                - Show this help"