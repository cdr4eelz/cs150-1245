#!/usr/bin/env bash
# Build MIPS programs from ../../software into a scratch copy and stage the memory images a
# whole-system test (tb/SysUART_tb.v) loads. The software tree itself is not touched.
#
#   build-sw.sh <software-dir> <scratch-dir> <run-dir> <bios-prog> [<ddr-prog> [make args...]]
#
#   <bios-prog>  built normally; its .inst image becomes bios_mem.mif (boots at 0x40000000)
#   <ddr-prog>   optional; its .inst image becomes ddr.hex for the behavioral cache-side memory
#                (linked at 0x10000000, e.g. LDSTYLE inject_cache), and a non-empty .data image
#                becomes dmem_blk_ram.mif
# isr_mem.mif / imem_blk_ram.mif (and dmem_blk_ram.mif otherwise) are the CoreGen defaults.
# Needs the MIPS toolchain (M_PRE, default mips-linux-gnu) and python3.
set -euo pipefail
sw=$1; scratch=$2; run=$3; bios=$4; prog=${5:-}; shift 5 2>/dev/null || shift $#
here=$(cd "$(dirname "$0")" && pwd)
src=$here/../../src
mkdir -p "$scratch" "$run"

bin2mif() { python3 -c '
import sys, struct
d = open(sys.argv[1], "rb").read()
d += b"\0" * (-len(d) % 4)
for i in range(0, len(d), 4): print(format(struct.unpack(">L", d[i:i+4])[0], "032b"))
' "$1"; }
bin2hex() { python3 -c '
import sys, struct
d = open(sys.argv[1], "rb").read()
d += b"\0" * (-len(d) % 4)
print("@%x" % int(sys.argv[2], 0))
for i in range(0, len(d), 4): print("%08x" % struct.unpack(">L", d[i:i+4]))
' "$1" "$2"; }

build() {  # build <prog> [make args] -> $scratch/<prog>/<prog>.{inst,data}.bin
  local p=$1; shift
  # fresh copies (sources only: drop any objects/images that came along)
  rm -rf "${scratch:?}/$p"
  cp -r "$sw/$p" "$scratch/$p"
  for d in common link; do [ -d "$scratch/$d" ] || cp -r "$sw/$d" "$scratch/$d"; done
  cp -f "$sw"/makefile.* "$scratch/"
  find "$scratch/$p" "$scratch/common" -name '*.o' -delete
  make -s -C "$scratch/$p" "$@" "$p.inst.bin" "$p.data.bin" >"$scratch/$p.build.log" 2>&1 \
    || { cat "$scratch/$p.build.log"; echo "build-sw: building $p failed"; exit 1; }
  echo "build-sw: built $p ($(stat -c %s "$scratch/$p/$p.inst.bin") bytes code, $(stat -c %s "$scratch/$p/$p.data.bin") bytes data)"
}

for m in isr_mem imem_blk_ram dmem_blk_ram; do cp -f "$src/core_ip/brams/$m/$m.mif" "$run/"; done
rm -rf "$scratch/common" "$scratch/link"
build "$bios"
bin2mif "$scratch/$bios/$bios.inst.bin" > "$run/bios_mem.mif"
rm -f "$run/ddr.hex"
if [ -n "$prog" ]; then
  build "$prog" "$@"
  bin2hex "$scratch/$prog/$prog.inst.bin" 0 > "$run/ddr.hex"
  [ -s "$scratch/$prog/$prog.data.bin" ] && bin2mif "$scratch/$prog/$prog.data.bin" > "$run/dmem_blk_ram.mif"
fi
exit 0
