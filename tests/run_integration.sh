#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source "$(dirname "$0")/run_common.sh"
mkdir -p build/tests bin

fpc $FPC_FLAGS -obin/test_pipeline tests/integration/test_pipeline.pas

echo "================================================================"
echo " INTEGRATION TESTS"
echo "================================================================"

./bin/test_pipeline
