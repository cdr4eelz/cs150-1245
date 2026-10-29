#!/usr/bin/env bash
# Make a copy of the Micron DDR2 model (../src/base_mem/mig_v3_61/ddr2_model.v) that Icarus
# Verilog 12 accepts, without touching the original.
#   patch-ddr2-model.sh <in ddr2_model.v> <out ddr2_model.v>
# Fix applied: tasks declare a scalar input and then re-declare it as a vector reg
#     input i;
#     reg [4:0] i;
# (old Verilog-1995 style that ModelSim tolerates; Icarus errors "Scalar port ``i'' has a
# vectored net declaration"). Rewritten to the equivalent "input [4:0] i;".
set -euo pipefail
in=$1; out=$2
mkdir -p "$(dirname "$out")"
perl -0pe 's/^(\s*)input\s+(\w+)\s*;\s*\n\s*reg\s*(\[[^\]]+\])\s*\2\s*;/$1input $3 $2;/mg' "$in" > "$out.tmp"
n=$(diff "$in" "$out.tmp" | grep -c '^<' || true)
mv -f "$out.tmp" "$out"
echo "patch-ddr2-model: $out ($n lines rewritten)"
