#!/bin/bash
# quality.sh – basic quality metrics
set -e
echo "=== Code quality metrics ==="
# Lines of code
LOC=$(find src -name "*.pas" -exec cat {} + | wc -l)
echo "Total lines of Pascal code: $LOC"

# TODO count (simple grep)
TODO=$(grep -r -i "TODO\|FIXME" src/ | wc -l)
echo "TODO/FIXME count: $TODO"

# Simple complexity proxy: number of procedures/functions
FUNC=$(grep -hE '^\s*(procedure|function)\s+\w' src/fxb/*.pas | wc -l)
echo "Procedures/Functions: $FUNC"

# Exit non-zero if too many TODOs (example threshold)
if [ "$TODO" -gt 50 ]; then
  echo "Too many TODOs (>50)"
  exit 1
fi

echo "Quality checks passed."
