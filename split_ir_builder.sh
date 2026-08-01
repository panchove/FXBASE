#!/usr/bin/env bash
# --------------------------------------------------------------
# split_ir_builder.sh
# Moves the remaining TFXBIRGenerator helper / lowering bodies
# into fxb.ir.builder.pas and turns the originals into one‑line
# delegations.  Run once from the repository root.
# --------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IR_PAS="$ROOT/src/fxb/fxb.ir.pas"
BUILDER_PAS="$ROOT/src/fxb/fxb.ir.builder.pas"

# --------------------------------------------------------------
# safety copies
cp "$IR_PAS"    "${IR_PAS}.bak"
cp "$BUILDER_PAS" "${BUILDER_PAS}.bak"

# ------------------------------------------------------------------
# 1️⃣  Extract every non‑delegated method (function / procedure)
# ------------------------------------------------------------------
awk '
  BEGIN {
    in_decl = 0
    name = ""
    sig = ""
    body = ""
    brace = 0
  }

  # Detect start of a TFXBIRGenerator method (function / procedure)
  /^[[:space:]]*(function|procedure)[[:space:]]+TFXBIRGenerator\./ {
    if (in_decl) { print "WARNING: nested declaration?" > "/dev/stderr" }
    in_decl = 1
    # capture the whole signature up to the first ';'
    match($0, /(function|procedure)[[:space:]]+TFXBIRGenerator\.[^(]+\([^)]*\)/)
    sig = substr($0, RSTART, RLENGTH)
    name = sig
    sub(/^[[:space:]]*(function|procedure)[[:space:]]+TFXBIRGenerator\./, "", name)
    sub(/\(.*$/, "", name)          # method name only
    body = $0 "\n"
    brace = 0
    # count braces in the first line
    for (i=1;i<=length($0);i++) {
      c = substr($0,i,1)
      if (c == "{" || c == "(") brace++
      else if (c == "}" || c == ")") brace--
    }
    next
  }

  # Inside a method body
  in_decl {
    body = body $0 "\n"
    for (i=1;i<=length($0);i++) {
      c = substr($0,i,1)
      if (c == "{" || c == "(") brace++
      else if (c == "}" || c == ")") brace--
    }
    # end of method when we see the closing ';' after the final 'end'
    if (brace == 0 && $0 ~ /^[[:space:]]*end;/) {
      # check if already delegated
      if (body ~ /\/\/ DELEGATED/) {
        delegated[name] = 1
      } else {
        sigs[name] = sig
        bodies[name] = body
      }
      in_decl = 0
    }
    next
  }

  END {
    for (n in sigs) {
      if (!(n in delegated)) {
        print n RS sigs[n] RS bodies[n]
      }
    }
  }
' "$IR_PAS" > /tmp/ir_methods.txt

# ------------------------------------------------------------------
# 2️⃣  Append the real bodies to the builder implementation
# ------------------------------------------------------------------
# First, strip the trailing "end." from builder file, we will re‑append later
head -n -1 "$BUILDER_PAS" > "${BUILDER_PAS}.tmp"
mv "${BUILDER_PAS}.tmp" "$BUILDER_PAS"

# Append the collected bodies (with TFXBIRGenerator -> TIRBuilder)
awk '
  BEGIN { RS=""; FS="\n" }
  {
    method = $1
    sig = $2
    # replace TFXBIRGenerator with TIRBuilder in signature
    gsub(/TFXBIRGenerator/, "TIRBuilder", sig)
    # replace F... with FBuilder.F... in body
    body = ""
    for (i=3;i<=NF;i++) {
      line = $i
      gsub(/F[A-Z][a-zA-Z]+/, "FBuilder.&", line)
      body = body line "\n"
    }
    # output
    print sig
    print body
    print "end;"
  }
' /tmp/ir_methods.txt >> "$BUILDER_PAS"

# put back the final "end."
echo "end." >> "$BUILDER_PAS"

# ------------------------------------------------------------------
# 3️⃣  Rewrite fxb.ir.pas – replace each collected method body with a delegation
# ------------------------------------------------------------------
awk -v methods_file="/tmp/ir_methods.txt" '
  BEGIN {
    while ((getline line < methods_file) > 0) {
      name = line
      getline sig < methods_file
      # read the whole body until a blank line (our extractor uses blank line as separator)
      body = ""
      while ((getline line < methods_file) > 0 && line != "") {
        body = body $0 "\n"
      }
      # build delegation line
      # extract return type / proc from signature
      if (match(sig, /^function[[:space:]]+TFXBIRGenerator\.([^(]+)\(/)) {
        mname = substr(sig, RSTART+20, RLENGTH-20)   # skip "function TFXBIRGenerator."
        sub(/\(.*$/, "", mname)
        is_func = 1
      } else if (match(sig, /^procedure[[:space:]]+TFXBIRGenerator\.([^(]+)\(/)) {
        mname = substr(sig, RSTART+21, RLENGTH-21)
        is_func = 0
      } else { mname = "" }
      deleg[mname] = 1
      if (is_func) {
        # extract arguments list
        if (match(sig, /\((.*)\)/)) {
          args = substr(sig, RSTART+1, RLENGTH-2)
          # split by ';' keep only names
          n = split(args, a, ";")
          arg_names = ""
          for (i=1;i<=n;i++) {
            split(a[i], b, ":")
            if (arg_names != "") arg_names = arg_names ", "
            arg_names = arg_names b[1]
          }
        } else args = ""
        deleg_body[mname] = "Result := FBuilder." mname "(" arg_names ");"
      } else {
        # procedure
        if (match(sig, /\((.*)\)/)) {
          args = substr(sig, RSTART+1, RLENGTH-2)
          n = split(args, a, ";")
          arg_names = ""
          for (i=1;i<=n;i++) {
            split(a[i], b, ":")
            if (arg_names != "") arg_names = arg_names ", "
            arg_names = arg_names b[1]
          }
        } else args = ""
        deleg_body[mname] = "FBuilder." mname "(" arg_names ");"
      }
    }
    close(methods_file)
  }

  # Now process the original file
  {
    # Detect start of a method we know
    if (match($0, /^[[:space:]]*(function|procedure)[[:space:]]+TFXBIRGenerator\.([^(]+)\(/)) {
      mname = substr($0, RSTART+RLENGTH-1)
      sub(/\(.*$/, "", mname)
      sub(/^[[:space:]]*(function|procedure)[[:space:]]+TFXBIRGenerator\./, "", mname)
      sub(/\(.*$/, "", mname)
      if (mname in deleg_body) {
        # print delegation line + comment
        print "  " deleg_body[mname] " // DELEGATED"
        # skip until the matching "end;" line
        in_skip = 1
        brace = 0
        next
      }
    }
    if (in_skip) {
      # count braces to find the matching end;
      for (i=1;i<=length($0);i++) {
        c = substr($0,i,1)
        if (c=="{") brace++
        else if (c=="}") brace--
      }
      if (brace==0 && $0 ~ /^[[:space:]]*end;/) {
        in_skip = 0
      }
      next
    }
    print
  }
' "$IR_PAS" > "${IR_PAS}.tmp"
mv "${IR_PAS}.tmp" "$IR_PAS"

echo "✅  Refactoring done.  Backup files: ${IR_PAS}.bak  ${BUILDER_PAS}.bak"
echo "Run:  make clean && make all && make test"