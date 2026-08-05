#!/bin/bash
set -e

echo "============================================"
echo "FXBASE End-to-End Test Script"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
cd "$PROJECT_ROOT"

# Step 1: Build the compiler
echo ""
echo "Step 1: Building FXBASE compiler..."
make clean > /dev/null 2>&1
make fxbc 2>&1 | tail -5
if [ ! -f "$PROJECT_ROOT/bin/fxbc" ]; then
    echo "FAIL: Compiler binary not found"
    exit 1
fi
echo "OK: Compiler built at bin/fxbc"

# Step 2: Test simple Hello World
echo ""
echo "Step 2: Testing simple Hello World..."
cat > /tmp/test_hello.fpg << 'HELLO_EOF'
FUNCTION Main() : INTEGER
    ? "Hello World"
    RETURN 0
ENDFUNC
HELLO_EOF

$PROJECT_ROOT/bin/fxbc /tmp/test_hello.fpg 2>&1
if [ ! -f "/tmp/test_hello.exe" ]; then
    echo "FAIL: Executable not generated"
    exit 1
fi

OUTPUT=$(/tmp/test_hello.exe)
if [ "$OUTPUT" != "Hello World" ]; then
    echo "FAIL: Expected 'Hello World', got '$OUTPUT'"
    exit 1
fi
echo "OK: Hello World executes correctly"

# Step 3: Test string variable
echo ""
echo "Step 3: Testing string variable..."
cat > /tmp/test_str.fpg << 'STR_EOF'
FUNCTION Main() : INTEGER
    LOCAL msg
    msg := "Hello from variable"
    ? msg
    RETURN 0
ENDFUNC
STR_EOF

$PROJECT_ROOT/bin/fxbc /tmp/test_str.fpg 2>&1
if [ ! -f "/tmp/test_str.exe" ]; then
    echo "FAIL: Executable not generated for string test"
    exit 1
fi

OUTPUT=$(/tmp/test_str.exe)
if [[ "$OUTPUT" != *"Hello from variable"* ]]; then
    echo "FAIL: Expected string output, got '$OUTPUT'"
    exit 1
fi
echo "OK: String variable works"

# Step 4: Test IF/ELSE control flow
echo ""
echo "Step 4: Testing IF/ELSE control flow..."
cat > /tmp/test_if.fpg << 'IF_EOF'
FUNCTION Main() : INTEGER
    LOCAL x
    x := 42
    IF x > 10
        ? "x is greater than 10"
    ELSE
        ? "x is not greater than 10"
    ENDIF
    RETURN 0
ENDFUNC
IF_EOF

$PROJECT_ROOT/bin/fxbc /tmp/test_if.fpg 2>&1
if [ ! -f "/tmp/test_if.exe" ]; then
    echo "FAIL: Executable not generated for IF test"
    exit 1
fi

OUTPUT=$(/tmp/test_if.exe)
if [[ "$OUTPUT" != *"greater than 10"* ]]; then
    echo "FAIL: Expected 'greater than 10', got '$OUTPUT'"
    exit 1
fi
echo "OK: IF/ELSE control flow works"

# Step 5: Test WHILE loop (without string concatenation)
echo ""
echo "Step 5: Testing WHILE loop..."
cat > /tmp/test_while.fpg << 'WHILE_EOF'
FUNCTION Main() : INTEGER
    LOCAL i
    i := 0
    WHILE i < 3
        ? "Iteration"
        ? i
        i := i + 1
    END
    RETURN 0
ENDFUNC
WHILE_EOF

$PROJECT_ROOT/bin/fxbc /tmp/test_while.fpg 2>&1
if [ ! -f "/tmp/test_while.exe" ]; then
    echo "FAIL: Executable not generated for WHILE test"
    exit 1
fi

OUTPUT=$(/tmp/test_while.exe)
if [[ "$OUTPUT" != *"Iteration"* ]] || [[ "$OUTPUT" != *"2"* ]]; then
    echo "FAIL: WHILE loop didn't execute correctly, got '$OUTPUT'"
    exit 1
fi
echo "OK: WHILE loop works"

# Step 6: Test FOR loop
echo ""
echo "Step 6: Testing FOR loop..."
cat > /tmp/test_for.fpg << 'FOR_EOF'
FUNCTION Main() : INTEGER
    LOCAL i
    LOCAL s
    s := 0
    FOR i := 1 TO 5
        s := s + i
    NEXT
    ? "Sum = "
    ? s
    RETURN 0
ENDFUNC
FOR_EOF

$PROJECT_ROOT/bin/fxbc /tmp/test_for.fpg 2>&1
if [ ! -f "/tmp/test_for.exe" ]; then
    echo "FAIL: Executable not generated for FOR test"
    exit 1
fi

OUTPUT=$(/tmp/test_for.exe)
if [[ "$OUTPUT" != *"Sum"* ]] || [[ "$OUTPUT" != *"15"* ]]; then
    echo "FAIL: FOR loop didn't execute correctly, got '$OUTPUT'"
    exit 1
fi
echo "OK: FOR loop works (sum = 15)"

# Step 7: Test SQLite DB operations
echo ""
echo "Step 7: Testing SQLite DB operations..."
cat > /tmp/test_db.fpg << 'DB_EOF'
FUNCTION Main() : INTEGER
    USE clientes
    APPEND id=1, nombre="Test Record"
    REPLACE nombre WITH "Updated Record"
    ? "Opened database"
    RETURN 0
ENDFUNC
DB_EOF

rm -f /tmp/test_fxbase.db
$PROJECT_ROOT/bin/fxbc --db:sqlite=/tmp/test_fxbase.db /tmp/test_db.fpg -o /tmp/test_db.exe 2>&1
if [ ! -f "/tmp/test_db.exe" ]; then
    echo "FAIL: Executable not generated for DB test"
    exit 1
fi

OUTPUT=$(/tmp/test_db.exe)
echo "DB Output:"
echo "$OUTPUT"
if [[ "$OUTPUT" != *"Opened database"* ]]; then
    echo "FAIL: DB test didn't run correctly, got '$OUTPUT'"
    exit 1
fi
if [ ! -f "/tmp/test_fxbase.db" ]; then
    echo "FAIL: SQLite database file not created"
    exit 1
fi
echo "OK: DB test compiled, ran and created the SQLite database"
rm -f /tmp/test_fxbase.db

# Step 8: Verify assembly output
echo ""
echo "Step 8: Verifying assembly output..."
$PROJECT_ROOT/bin/fxbc --dump-asm /tmp/test_hello.fpg > /tmp/test_hello.asm 2>&1
if [ ! -s /tmp/test_hello.asm ]; then
    echo "FAIL: No assembly output generated"
    exit 1
fi
if ! grep -q "Main:" /tmp/test_hello.asm; then
    echo "FAIL: Main function not in assembly"
    exit 1
fi
echo "OK: Assembly output contains Main function"

echo ""
echo "============================================"
echo "ALL TESTS PASSED!"
echo "============================================"
echo ""
echo "Summary:"
echo "  - Compiler builds successfully"
echo "  - Hello World works"
echo "  - String variables and printing work"
echo "  - Control flow works (IF, WHILE, FOR)"
echo "  - SQLite DB operations compile and run"
echo "  - Assembly output is valid"
