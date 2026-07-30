#!/bin/bash
set -e
cd "$(dirname "$0")/.."
mkdir -p build/tests bin

FPC_FLAGS="-n -Mdelphi -O2 -vewnhi \
  -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl \
  -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl-objpas \
  -Fu/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src \
  -Fusrc/fpx \
  -Futests \
  -FEbuild/tests \
  -FUbuild/tests"

fpc $FPC_FLAGS -obin/test_tokens tests/unit/test_tokens.pas
fpc $FPC_FLAGS -obin/test_lexer  tests/unit/test_lexer.pas

echo "================================================================"
echo " UNIT TESTS"
echo "================================================================"

./bin/test_tokens
./bin/test_lexer
