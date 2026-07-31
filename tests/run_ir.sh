#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source "$(dirname "$0")/run_common.sh"
mkdir -p build/tests bin

fpc $FPC_FLAGS -obin/test_ir tests/implementation/test_ir.pas

echo "================================================================"
echo " IR TESTS"
echo "================================================================"

./bin/test_ir
