#!/bin/bash
# run_all_tests.sh — Ejecuta unit + integration + implementation
set -e
cd "$(dirname "$0")/.."

FPC_FLAGS="-n -Mdelphi -O2 -vewnhi \
  -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl \
  -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl-objpas \
  -Fu/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src \
  -Fusrc/fpx \
  -Futests \
  -FEbuild/tests \
  -FUbuild/tests"

mkdir -p build/tests

echo "================================================================"
echo " FPXBASE — TEST SUITE"
echo "================================================================"

PASS=0
FAIL=0
TOTAL=0

run_test() {
    local bin=$1
    local name=$2
    TOTAL=$((TOTAL + 1))
    if ./$bin > /tmp/test_out.log 2>&1; then
        local p=$(grep -c "OK" /tmp/test_out.log || true)
        local f=$(grep -c "FAILED\|ERROR\|CRASHED" /tmp/test_out.log || true)
        PASS=$((PASS + 1))
        echo "[PASS] $name  (${p} OK)"
    else
        FAIL=$((FAIL + 1))
        echo "[FAIL] $name"
        sed 's/^/    /' /tmp/test_out.log | head -30
    fi
}

echo ""
echo "[1/3] Unit tests"
echo "----------------------------------------------------------------"
fpc $FPC_FLAGS -obin/test_tokens      tests/unit/test_tokens.pas
fpc $FPC_FLAGS -obin/test_lexer       tests/unit/test_lexer.pas
run_test bin/test_tokens  "fpx.tokens — unit"
run_test bin/test_lexer   "fpx.lexer  — unit"

echo ""
echo "[2/3] Integration tests"
echo "----------------------------------------------------------------"
fpc $FPC_FLAGS -obin/test_pipeline    tests/integration/test_pipeline.pas
run_test bin/test_pipeline "lexer+parser pipeline"

echo ""
echo "[3/3] Implementation tests"
echo "----------------------------------------------------------------"
fpc $FPC_FLAGS -obin/test_impl        tests/implementation/test_implementation.pas
run_test bin/test_impl     "fixtures reales"

echo ""
echo "================================================================"
echo " SUMMARY: $PASS passed / $FAIL failed / $TOTAL total"
echo "================================================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
