#!/bin/bash
# Fase 0.5 verification benchmark (FXBASE-ROADMAP).
#
# Generates a synthetic 100-file / ~10k LOC multi-unit FXBASE project and
# measures the two-pass parallel compiler against the roadmap acceptance
# criteria:
#   - clean build (cold cache, 100 files): < 2s on 8 cores
#   - incremental rebuild after touching 1 file: < 150ms
#
# Usage: tests/bench/fxbench.sh [--keep]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FXBC="$ROOT/bin/fxbc"
JOBS="${JOBS:-$(nproc)}"
FILES=100
FUNCS_PER_UNIT=9
TARGET_DIR="${TMPDIR:-/tmp}/fxbench"
CACHE_DIR="$TARGET_DIR/.cache"
EXE="$TARGET_DIR/prog"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

if [ ! -x "$FXBC" ]; then
  echo "error: $FXBC not found (run 'make fxbc' first)" >&2
  exit 1
fi

cleanup() {
  if [ "$KEEP" -eq 0 ]; then
    rm -rf "$TARGET_DIR"
  fi
}
trap cleanup EXIT

now_ms() {
  echo $(( $(date +%s%N) / 1000000 ))
}

# Generate one library unit (~108 LOC).
gen_lib() {
  local idx=$1
  local file="$TARGET_DIR/src/lib_$idx.fpg"
  {
    printf '// lib_%02d.fpg -- FXBENCH generated unit %d/%d\n\n' "$idx" "$idx" "$FILES"
    local i
    for ((i = 0; i < FUNCS_PER_UNIT; i++)); do
      printf 'STATIC FUNCTION f_%02d_%02d(x AS INTEGER) AS INTEGER\n' "$idx" "$i"
      printf '    LOCAL a AS INTEGER\n'
      printf '    LOCAL b AS INTEGER\n'
      printf '    a := x + %d\n' "$((idx + i))"
      printf '    b := a * 2\n'
      printf '    IF b > 100\n'
      printf '        b := b - 100\n'
      printf '    ENDIF\n'
      printf '    RETURN b - %d\n' "$i"
      printf 'ENDFUNC\n\n'
    done
    printf 'PROCEDURE p_%02d()\n' "$idx"
    printf '    LOCAL i AS INTEGER\n'
    printf '    FOR i := 1 TO 3\n'
    printf '        ? "lib_%02d"\n' "$idx"
    printf '    NEXT\n'
    printf 'ENDPROC\n'
  } > "$file"
}

# Entry unit calling into several library units.
gen_main() {
  local file="$TARGET_DIR/src/main.fpg"
  {
    printf '// main.fpg -- FXBENCH entry unit\n\n'
    printf 'FUNCTION Main() AS INTEGER\n'
    printf '    LOCAL acc AS INTEGER\n'
    printf '    acc := 0\n'
    for idx in 01 25 50 75 99; do
      printf '    acc := acc + f_%s_%02d(acc)\n' "$idx" $((10#$idx % FUNCS_PER_UNIT))
    done
    printf '    ? acc\n'
    printf '    ? "fxbench ok"\n'
    printf '    RETURN 0\n'
    printf 'ENDFUNC\n'
  } > "$file"
}

echo "FXBASE Fase 0.5 verification benchmark"
echo "  files: $FILES, funcs/unit: $FUNCS_PER_UNIT, jobs: $JOBS"

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR/src"

for ((i = 1; i <= FILES; i++)); do
  gen_lib "$i"
done
gen_main

LOC=$(wc -l "$TARGET_DIR"/src/*.fpg | tail -1 | awk '{print $1}')
echo "  generated: $LOC LOC in $(ls "$TARGET_DIR/src" | wc -l) units"
echo

# ---- Clean build (cold cache) ----
rm -rf "$CACHE_DIR"
t0=$(now_ms)
"$FXBC" --two-pass --jobs "$JOBS" --cache-dir "$CACHE_DIR" -o "$EXE" \
  "$TARGET_DIR"/src/*.fpg >/dev/null 2>&1
t1=$(now_ms)
CLEAN_MS=$((t1 - t0))

# ---- Incremental build (one file changed, warm cache) ----
# Rewrite one constant inside lib_25 so its content hash changes.
sed -i 's/^    a := x + 25$/    a := x + 251/' "$TARGET_DIR/src/lib_25.fpg"
t0=$(now_ms)
"$FXBC" --two-pass --jobs "$JOBS" --cache-dir "$CACHE_DIR" -o "$EXE" \
  "$TARGET_DIR"/src/*.fpg >/dev/null 2>&1
t1=$(now_ms)
INCR_MS=$((t1 - t0))

# ---- Binary smoke test ----
RUN_OK=0
if "$EXE" 2>/dev/null | grep -q 'fxbench ok'; then
  RUN_OK=1
fi

echo "  clean build:      ${CLEAN_MS} ms   (criterion < 2000 ms)"
echo "  incremental:      ${INCR_MS} ms   (criterion < 150 ms)"
echo "  binary smoke:     $([ $RUN_OK -eq 1 ] && echo OK || echo FAIL)"
echo

PASS=1
if [ "$CLEAN_MS" -ge 2000 ]; then
  echo "FAIL: clean build ${CLEAN_MS}ms exceeds 2s criterion"
  PASS=0
fi
if [ "$INCR_MS" -ge 150 ]; then
  echo "FAIL: incremental ${INCR_MS}ms exceeds 150ms criterion"
  PASS=0
fi
if [ "$RUN_OK" -ne 1 ]; then
  echo "FAIL: produced binary does not print 'fxbench ok'"
  PASS=0
fi

if [ "$KEEP" -eq 1 ]; then
  echo "artifacts kept in $TARGET_DIR"
fi

if [ "$PASS" -eq 1 ]; then
  echo "BENCHMARK PASSED"
  exit 0
fi
exit 1
