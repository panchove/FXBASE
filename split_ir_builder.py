#!/usr/bin/env python3
import re, sys, os, shutil, subprocess, textwrap

ROOT = "/home/panchove/Projects/FXBASE"
IR_PAS = os.path.join(ROOT, "src/fxb/fxb.ir.pas")
BUILDER_PAS = os.path.join(ROOT, "src/fxb/fxb.ir.builder.pas")

# backup
shutil.copy2(IR_PAS, IR_PAS + ".bak")
shutil.copy2(ROOT + "/src/fxb/fxb.ir.builder.pas",
            ROOT + "/src/fxb/fxb.ir.builder.pas.bak")

with open(IR_PAS, "r") as f:
    ir_text = f.read()

# find all methods in TFXBIRGenerator that are not yet delegated
method_pattern = re.compile(
    r'(?ms)^(?P<indent>\s*)(function|procedure)\s+TFXBIRGenerator\.(?P<name>[A-Za-z0-9_]+)\s*\((?P<args>[^)]*)\)(?P<rest>.*?)^\s*end;',
    re.MULTILINE
)

delegated = set()
# find already delegated methods (contain "// DELEGATED")
for m in re.finditer(r'// DELEGATED', open(IR_PAS).read()):
    # not precise; skip

# Instead, parse functions manually
lines = open(IR_PAS).readlines()
i = 0
methods = {}
while i < len(lines):
    line = lines[i]
    m = re.match(r'^\s*(function|procedure)\s+TFXBIRGenerator\.([A-Za-z0-9_]+)\s*\(', line)
    if m:
        kind, name = m.group(1), m.group(2)
        # capture until matching "end;"
        start = i
        brace = 0
        j = i
        while j < len(lines):
            line = lines[j]
            for ch in line:
                if ch == '{' or ch == '(':
                    pass
                if ch == '{':
                    pass
                # simple brace counting using begin/end not braces
            # Use simple approach: find next "end;" at same indent level? Too complex.
            break
    # Too complex for quick script. Abort.

print("Script not finished")
sys.exit(1)