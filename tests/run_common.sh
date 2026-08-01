#!/bin/bash
# Shared FPC flags for the test suites (run_*.sh source this file).
# Keep the three -Fu paths in sync with the main Makefile.
FPC_FLAGS="-n -Mdelphi -O2 -vewnhi \
  -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl \
  -Fu/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/rtl-objpas \
  -Fu/usr/share/fpcsrc/3.2.2/packages/rtl-generics/src \
  -Fusrc/fxb \
  -Futests \
  -Fllib \
  -FEbuild/tests \
  -FUbuild/tests"
