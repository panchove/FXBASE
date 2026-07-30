#!/bin/bash
# coverage.sh — Estimación de cobertura basada en uso de funciones
set -e
cd "$(dirname "$0")/.."

echo "================================================================"
echo " CODE COVERAGE REPORT (heurístico)"
echo "================================================================"
echo ""

REPORT="build/coverage_report.txt"
mkdir -p build
> $REPORT

# Total de procedures/functions en src/fpx
TOTAL_DEFS=$(grep -hE '^\s*(procedure|function)\s+\w+\s*[<(]' src/fpx/*.pas | wc -l)

# Total de líneas src/fpx
TOTAL_LINES=$(wc -l src/fpx/*.pas | tail -1 | awk '{print $1}')

# Líneas cubiertas por tests (heurística: líneas referenciadas)
COVERED=0
for test in tests/unit/*.pas tests/integration/*.pas tests/implementation/*.pas; do
    LINES=$(wc -l < $test)
    COVERED=$((COVERED + LINES))
done

# Functions referenciadas en tests
COVERED_DEFS=0
for sym in $(grep -hEo '\b(TFPXLexer|TParser|TKeyword|TKeyword|KeywordFromString|IsKeyword|TokenTypeName|DumpToken|ScanIdentifier|ScanNumber|ScanString|ScanRawString|ScanOperator|Tokenize|NextToken)' tests/*.pas tests/**/*.pas 2>/dev/null | sort -u); do
    EXIST=$(grep -l "\b$sym\b" src/fpx/*.pas 2>/dev/null | wc -l)
    if [ "$EXIST" -gt 0 ]; then
        COVERED_DEFS=$((COVERED_DEFS + 1))
    fi
done

echo "Source code (src/fpx/):"                         | tee -a $REPORT
echo "  Total lines:           $TOTAL_LINES"           | tee -a $REPORT
echo "  Procedures+functions:  $TOTAL_DEFS"            | tee -a $REPORT
echo ""                                                | tee -a $REPORT
echo "Test code:"                                       | tee -a $REPORT
echo "  Test files:            $(ls tests/unit/*.pas tests/integration/*.pas tests/implementation/*.pas | wc -l)" | tee -a $REPORT
echo "  Test code lines:       $COVERED"               | tee -a $REPORT
echo "  Symbols exercised:     $COVERED_DEFS"           | tee -a $REPORT
echo ""                                                | tee -a $REPORT

# Ratio test/source
if [ "$TOTAL_LINES" -gt 0 ]; then
    RATIO=$(awk "BEGIN{printf \"%.2f\", $COVERED/$TOTAL_LINES}")
    echo "Test:Source line ratio: ${RATIO}:1"           | tee -a $REPORT
fi

echo ""                                                | tee -a $REPORT
echo "Report: $REPORT"                                 | tee -a $REPORT
