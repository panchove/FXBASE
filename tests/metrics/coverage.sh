#!/bin/bash
# coverage.sh — Estimación de cobertura basada en uso de unidades y funciones
set -e
cd "$(dirname "$0")/../.."

echo "================================================================"
echo " CODE COVERAGE REPORT (heurístico)"
echo "================================================================"
echo ""

REPORT="build/coverage_report.txt"
mkdir -p build
> $REPORT

# Total de procedures/functions en src/fxb
TOTAL_DEFS=$(grep -hE '^\s*(procedure|function)\s+\w+\s*[<(]' src/fxb/*.pas | wc -l)

# Total de líneas src/fxb
TOTAL_LINES=$(wc -l src/fxb/*.pas | tail -1 | awk '{print $1}')

# Líneas cubiertas por tests (heurística: líneas referenciadas)
COVERED=0
for test in tests/unit/*.pas tests/integration/*.pas tests/implementation/*.pas; do
    if [ -f "$test" ]; then
        LINES=$(wc -l < $test)
        COVERED=$((COVERED + LINES))
    fi
done

# Units used in tests
UNITS_SRC=$(ls src/fxb/fxb.*.pas | sed 's/.*\/fxb\.//' | sed 's/\.pas//' | sort -u)
USED_UNITS=0
for unit in $UNITS_SRC; do
    if grep -r "fxb\.$unit" tests/ 2>/dev/null | grep -q .; then
        USED_UNITS=$((USED_UNITS + 1))
    fi
done
TOTAL_UNITS=$(echo "$UNITS_SRC" | wc -w)

# Functions referenciadas en tests (lista de símbolos comunes)
COVERED_DEFS=0
for sym in $(grep -hEo '\b(TFXBLexer|TFXBParser|TFBTokenizer|TKeyword|KeywordFromString|IsKeyword|TokenTypeName|DumpToken|ScanIdentifier|ScanNumber|ScanString|ScanRawString|ScanOperator|Tokenize|NextToken|TFXBCompiler|TFBParser)\b' tests/*.pas tests/**/*.pas 2>/dev/null | sort -u); do
    EXIST=$(grep -l "\b$sym\b" src/fxb/*.pas 2>/dev/null | wc -l)
    if [ "$EXIST" -gt 0 ]; then
        COVERED_DEFS=$((COVERED_DEFS + 1))
    fi
done

echo "Source code (src/fxb/):"                         | tee -a $REPORT
echo "  Total lines:           $TOTAL_LINES"           | tee -a $REPORT
echo "  Procedures+functions:  $TOTAL_DEFS"            | tee -a $REPORT
echo "  Units:                 $TOTAL_UNITS"           | tee -a $REPORT
echo ""                                                | tee -a $REPORT
echo "Test code:"                                       | tee -a $REPORT
echo "  Test files:            $(find tests -name '*.pas' | wc -l)" | tee -a $REPORT
echo "  Test code lines:       $COVERED"               | tee -a $REPORT
echo "  Units used in tests:   $USED_UNITS/$TOTAL_UNITS" | tee -a $REPORT
echo "  Symbols exercised:     $COVERED_DEFS"           | tee -a $REPORT
echo ""                                                | tee -a $REPORT

# Ratio test/source
if [ "$TOTAL_LINES" -gt 0 ]; then
    RATIO=$(awk "BEGIN{printf \"%.2f\", $COVERED/$TOTAL_LINES}")
    echo "Test:Source line ratio: ${RATIO}:1"           | tee -a $REPORT
fi

# Unit usage percentage
if [ "$TOTAL_UNITS" -gt 0 ]; then
    UNIT_PCT=$(awk "BEGIN{printf \"%.1f\", ($USED_UNITS * 100.0) / $TOTAL_UNITS}")
    echo "Unit usage coverage:   ${UNIT_PCT}%"         | tee -a $REPORT
fi

# Estimación de cobertura de funciones (heurística muy aproximada)
if [ "$TOTAL_DEFS" -gt 0 ]; then
    COVERAGE_PCT=$(awk "BEGIN{printf \"%.1f\", ($COVERED_DEFS * 100.0) / $TOTAL_DEFS}")
    echo "Estimated function coverage: ${COVERAGE_PCT}%" | tee -a $REPORT
else
    echo "No functions found in source"                 | tee -a $REPORT
fi

echo ""                                                | tee -a $REPORT
echo "Report: $REPORT"                                 | tee -a $REPORT
echo ""
echo "NOTA: Esta es una estimación heurística muy aproximada."
echo "Para una cobertura real, se necesitaría gcov/lcov."
echo "================================================================"
