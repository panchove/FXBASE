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

fpc $FPC_FLAGS -obin/test_impl tests/implementation/test_implementation.pas

echo "================================================================"
echo " IMPLEMENTATION TESTS"
echo "================================================================"

./bin/test_impl
