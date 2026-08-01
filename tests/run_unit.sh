#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source "$(dirname "$0")/run_common.sh"
mkdir -p build/tests bin

fpc $FPC_FLAGS -obin/test_tokens tests/unit/test_tokens.pas
fpc $FPC_FLAGS -obin/test_lexer  tests/unit/test_lexer.pas
fpc $FPC_FLAGS -obin/test_sqlite tests/unit/test_sqlite.pas

echo "================================================================"
echo " UNIT TESTS"
echo "================================================================"

./bin/test_tokens
./bin/test_lexer
./bin/test_sqlite
