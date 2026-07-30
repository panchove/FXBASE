#!/bin/bash
# quality.sh — Métricas de calidad del código fuente
set -e
cd "$(dirname "$0")/.."

echo "================================================================"
echo " CODE QUALITY METRICS"
echo "================================================================"

REPORT="build/quality_report.txt"
mkdir -p build
> $REPORT

echo "" | tee -a $REPORT
echo "## Lines of Code (LOC) por archivo" | tee -a $REPORT
echo "" | tee -a $REPORT
wc -l src/fpx/*.pas | sort -n | tee -a $REPORT

echo "" | tee -a $REPORT
echo "## Total LOC (src/fpx/)" | tee -a $REPORT
TOTAL=$(wc -l src/fpx/*.pas | tail -1 | awk '{print $1}')
echo "  $TOTAL líneas" | tee -a $REPORT

echo "" | tee -a $REPORT
echo "## Comentarios y blancos (densidad de código)" | tee -a $REPORT
COMMENT=0; BLANK=0; CODE=0
for f in src/fpx/*.pas; do
    C=$(grep -cE '^\s*(//|\{|\*|\')' $f 2>/dev/null || echo 0)
    B=$(grep -cE '^\s*$' $f 2>/dev/null || echo 0)
    L=$(wc -l < $f)
    COMMENT=$((COMMENT + C))
    BLANK=$((BLANK + B))
    CODE=$((CODE + L - C - B))
done
echo "  Líneas de código:    $CODE" | tee -a $REPORT
echo "  Comentarios:         $COMMENT" | tee -a $REPORT
echo "  Blancas:             $BLANK" | tee -a $REPORT

echo "" | tee -a $REPORT
echo "## Complejidad ciclomática (heurística: keywords de control)" | tee -a $REPORT
echo "" | tee -a $REPORT
printf "%-40s %s\n" "Archivo" "Branches" | tee -a $REPORT
printf "%.0s-" {1..50} | tee -a $REPORT
echo "" | tee -a $REPORT
for f in src/fpx/*.pas; do
    B=$(grep -ciE '\b(if|else|case|while|for|repeat|and|or)\b' $f)
    NAME=$(basename $f)
    printf "%-40s %s\n" "$NAME" "$B" | tee -a $REPORT
done

echo "" | tee -a $REPORT
echo "## Funciones/procedures por archivo" | tee -a $REPORT
for f in src/fpx/*.pas; do
    N=$(grep -cE '^\s*(procedure|function)\s+\w+' $f)
    NAME=$(basename $f)
    printf "%-40s %s\n" "$NAME" "$N" | tee -a $REPORT
done

echo "" | tee -a $REPORT
echo "## Ratio tests/fixtures vs código" | tee -a $REPORT
TEST_FILES=$(ls tests/unit/*.pas tests/integration/*.pas tests/implementation/*.pas 2>/dev/null | wc -l)
TEST_LINES=$(cat tests/unit/*.pas tests/integration/*.pas tests/implementation/*.pas 2>/dev/null | wc -l)
FIXTURES=$(ls tests/fixtures/*.fpg tests/fixtures/*.prg 2>/dev/null | wc -l)
echo "  Test files:    $TEST_FILES" | tee -a $REPORT
echo "  Test lines:    $TEST_LINES" | tee -a $REPORT
echo "  Fixtures:      $FIXTURES" | tee -a $REPORT

echo "" | tee -a $REPORT
echo "Report: $REPORT" | tee -a $REPORT
