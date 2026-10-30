# sim-icarus: Icarus Verilog tests

Small self-checking testbenches run with [Icarus Verilog](https://steveicarus.github.io/iverilog/).
The ModelSim tests in `../sim` are separate and unchanged.

Needs `iverilog`/`vvp` 11 or newer (developed with 12.0; 13.0 works too), GNU make (3.81 or
newer), bash (3.2 or newer), perl, python3 and `timeout` (GNU coreutils).
On Debian/Ubuntu: `sudo apt install iverilog`.

On macOS (tested on Apple Silicon): `brew install icarus-verilog coreutils` (coreutils provides
`gtimeout`, which the rig uses when there is no `timeout`). The stock `/usr/bin/make` (3.81),
`/bin/bash` (3.2) and BSD `awk`/`sed`/`stat`/`od` are fine: the scripts avoid GNU-only options.
For the `mips` tests put a MIPS cross toolchain (`mips-linux-gnu-gcc` etc.) on `PATH`. The
Xilinx and CoreGen requirements below need files from a machine with ISE 14.7 (ISE does not
run natively on macOS); copy them as described there.

## Usage

```
make                 # same as `make all`: run the default group, print a summary, exit nonzero on any FAIL/XPASS
make slow            # run the slow group (DDR2 model, whole-system sims; minutes)
make everything      # both groups
make env             # show the detected XILINX_SRC and available requirements
make prng32lfsr      # run one test by name
make list            # list tests (name, top module, testbench; [XFAIL]/[SKIP] marks)
make clean           # remove build/
make hex             # rebuild tb/data/*.hex from tb/data/*.s (needs mips-linux-gnu-as/objcopy)
make WAVES=1 memmapio_prng            # also write build/memmapio_prng/memmapio_prng.vcd
make prng32lfsr PLUSARGS=+n=1000000   # extra vvp plusargs (here: 1M cycles instead of 100k)
make DEFINES=FORCE_FAIL               # extra `define`s; FORCE_FAIL makes the tb/ tests fail on purpose
make RUN_SKIPPED=1                    # also run tests marked SKIP
make slow XILINX_SRC=/path/to/ISE_DS/ISE/verilog/src   # use a specific Xilinx install
```

### Xilinx simulation sources (`XILINX_SRC`)

Tests that need Xilinx primitives (`BUFG`, `PLL_BASE`, ...) or CoreGen cores (block RAMs,
FIFOs) declare `<name>.NEEDS := xilinx`. They compile against the ISE 14.7 sources in
`XILINX_SRC` (`-y $XILINX_SRC/unisims -y $XILINX_SRC/XilinxCoreLib` plus `glbl.v`; `-y`
means only the modules a test uses get compiled, about a second). These sources are under the
Xilinx license and are **never copied into the repo**. `XILINX_SRC` is taken from the
environment / command line, else the first of these that exists:

1. `$XILINX/verilog/src` (an ISE settings script sets `XILINX=.../ISE_DS/ISE`)
2. `$ISE_DOCKER_DIR/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src`
3. `/tmp/vmfs/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src`
4. `~/ise-docker/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src` (the install bind-mounted into the ISE docker image)
5. `/workspace/ise-docker/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src`
6. `/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src`
7. `~/opt/xilinx-verilog/src` (a plain copy of an ISE install's `verilog/src`, e.g. on a Mac)

A test whose `NEEDS` are missing is reported as **SKIP** with the reason (e.g. `needs Xilinx sim
sources: set XILINX_SRC=<ISE>/verilog/src`) and does not fail the run. The other requirement
is `mips` (the `mips-linux-gnu-` toolchain, prefix `M_PRE`), for tests that build programs from
`../../software`.

### CoreGen outputs (`coregen`)

The whole-system tests (`sys_*`, `memory150_ddr`, `cache_tb`, ...) and `pixel_feeder*` also
need the CoreGen wrappers of the block RAM / FIFO cores, `../src/core_ip/{brams,base_mem}/<core>/<core>.v`
and `../src/core_ip/gpu/pixel_fifo/pixel_fifo.v`, and for `brams/` the initial contents
`<core>.mif`. Only the `.xco`/`.coe` inputs are in git (`../src/core_ip/.gitignore`);
the outputs are made by ISE's `coregen` (`make -C ../src/core_ip`, e.g. in the ISE docker
image). Without them these tests are **SKIP** (`needs CoreGen outputs ...`; `make env` lists
`COREGEN_MISSING`). On a machine without ISE (macOS), copy them from one that has run
coregen, into the same paths (they stay git-ignored; never commit them):

```
# on the ISE machine, from hardware/src/core_ip:
tar czf /tmp/coregen-outputs.tgz $(ls */*/*.v */*/*.mif)
# on the other machine, from hardware/src/core_ip:
tar xzf coregen-outputs.tgz
```

Re-copy them after changing a `.xco`/`.coe`.

Everything generated goes under `build/`:

- `build/<test>.log`: simulation output (also shown on the terminal); `build/<test>.status`: PASS/FAIL/XFAIL/XPASS
- `build/<test>/`: the sim's working dir: `<test>.vvp`, `compile.log`, copied input files, `<test>.vcd` (with `WAVES=1`)

A test **passes** when `vvp` exits 0 (within `TIMEOUT` seconds), the log has a line matching the
test's `PASS_RE` (default `^PASS`), and nothing matches its `FAIL_RE` (default `ERRORS: [1-9]|FAIL`).
Compile errors also fail the test. A test with missing `NEEDS` is **SKIP** (not a failure). A test marked `XFAIL` (known bug) is reported as **XFAIL** and
does not break `make all`; if it starts passing it is reported as **XPASS** and *does* fail, as a
reminder to remove the marker.

## Tests

| Name | Testbench | Checks |
|---|---|---|
| `alu`, `alu_vectors` | `../src/testbench/ALU*Testbench.v` | ALU directed tests; ALU test vectors (`../sim/tests/testvectors.input`) |
| `regfile`, `stage_dx`, `stage_mw`, `byte_access4x` | `../src/testbench/` | RegFile; StageDX decode/execute; StageMW (elaboration smoke only); ByteAccess4 (legacy bench): store masks/lanes and zero-extended loads for the 7 valid MemShift/SubIndex pairs, one data word, `IsSigned` tied to 0 |
| `byte_access4` | `tb/ByteAccess4_tb.v` | `innerds/ByteAccess4.v` exhaustively vs. a behavioral big-endian MIPS model: every MemShift x SubIndex x IsSigned for 246 data patterns (7872 vectors); `ByteMask`, `WordMasked` (sb/sh/sw), `ValExtract` (lb/lh sign-extend, lbu/lhu zero-extend, lw), all-zero outputs for unsupported/misaligned combos |
| `counter_boundary`, `debouncer`, `graphics_processor` | `../src/testbench/` | Counter wrap; Debouncer modes; GraphicsProcessor with fake memory/engines |
| `prng32lfsr` | `tb/PRNG32LFSR_tb.v` | `base_util/PRNG32LFSR.v`: model match (100k cycles), never zero, bit balance, seeding |
| `memmapio_prng` | `tb/MemMapIO_prng_tb.v` | PRNG at MMIO `0x80000080` through `cpu/MemMapIO.v` |
| `memmapio_uart` | `tb/MemMapIO_uart_tb.v` | MMIO UART regs + serial loopback via UARTRVA/UART, IRQ pulses, cycle/instr counters |
| `cop0` | `tb/COP0150_tb.v` | COP0150: Status/Cause/EPC/Count/Compare, interrupt request, timer |
| `isr_epc_*`, `isr_mtc0_collision` | `tb/ISR_EPC_tb.v` | Periodic interrupts vs. stalls / mtc0: EPC must point into main code (regression for 5cba58a) |
| `cpu_isa`, `cpu_isa_ddr` | `tb/CPU_prog_tb.v` + `tb/data/cpu_isa.s` | Self-checking MIPS program: ALU, shifts, forwarding, loads/stores, branches, jumps/links, COP0 (`_ddr`: stalls on every store) |
| `line_engine` | `tb/LineEngine_check_tb.v` | `gpu/LineEngine.v`: each line's pixels vs. the ideal line (count, one per major step, <= 1/2 pixel off, connected), SLR fields, random back-pressure; 228 lines |
| `frame_filler` | `tb/FrameFiller_check_tb.v` | `gpu/FrameFiller.v`: one SLR request per row 0..599 spanning 0..799, frame clipping, colors, `FF_ready` |
| `gpu_raster_lw1`, `gpu_raster_lw0` | `tb/GpuRaster_tb.v` | FrameFiller + LineEngine -> ScanLineRunner (2 clients) -> DDR write-FIFO model with back-pressure; whole 1024x1024 frame vs. a reference (fill edges/interior, `swline` C model from `LineEngine.v`), for `LITTLEWORDIAN` 1 and 0 |
| `sys_bios` (xilinx, mips) | `tb/SysUART_tb.v` | Whole `MIPS150` (CPU, BIOS/ISR/IMEM/DMEM BRAMs, MemMapIO, UART) running the real BIOS (`software/bios150v3`) over its serial port: sw/sh/sb/lw/lhu/lbu on DMEM and cache-side memory, code stored to IMEM and run with `jal`, PRNG reads at `0x80000080` |
| `sys_echo`, `sys_math`, `sys_mmult` (xilinx, mips) | `tb/SysUART_tb.v` | BIOS `jal`s to `software/echo_c` / `math` / `mmult` loaded at `0x10000000`; UART transcript vs. `tb/data/sys/*.golden` |
| `sys_ddr_bios` (slow, xilinx, mips) | `tb/SysUART_tb.v` with `SYS_DDR` | As on the board (`ml505top`): MIPS150 + `Memory150` (caches, MIG) + Micron DDR2 model; BIOS boots with its stack in DDR, then `sw`/`lw` through the dcache to DDR |
| `memory150_ddr` (slow, xilinx) | `tb/Memory150_ddr_tb.v` | `Memory150` caches + MIG + Micron DDR2 model: write-through, read-miss fills, hits, byte masks, same-index eviction, icache fill from DDR, 100 random ops vs. a shadow memory |
| `pixel_feeder` (xilinx, coregen) | `tb/PixelFeeder_check_tb.v` | `gpu/PixelFeeder.v` + CoreGen `pixel_fifo` vs. a RequestController/MIG read model (random grants, latency, beat gaps; known data per address) and a random-ready sink: request addresses, frame wrap and `pf_vframe`/`pf_wframe` frame select, `irq_frame`, `pf_status`, every pixel of a displayed frame + 2 rows of the next, FIFO under/overflow |
| `pixel_feeder_dvi`, `pixel_feeder_stress` (slow) | `tb/PixelFeeder_check_tb.v` | As `pixel_feeder` for 2 frames + 2 rows: with the real `base_vid/DVIData` (800x600@60, 1040x666 raster: `video_ready`, `DVI_DE/H/V`, `DVI_D`); with a slow bursty memory, long stalls, 40 vs. 42.5 MHz clocks and a 60%-ready sink |
| `cache_tb`, `cache_tb_sv`, `memory150_tb` (slow) | `../src/testbench/CacheTestBench.v`, `Memory150TestBench.v` | The original cache benches on `Memory150` + MIG + DDR2 model (`_sv`: compiled with `-g2012`, see below) |
| `pixel_feeder_fwft` | `tb/PixelFeeder_check_tb.v` | Strict first-row check that `pixel_fifo` is First_Word_Fall_Through, as PixelFeeder expects (a Standard FIFO shows every pixel one position late) |
| `cpu_lb_lh_sign`, `cpu_jalr_rd` | `tb/CPU_prog_tb.v` | Regression tests for fixed CPU bugs: lb/lh sign-extend (lbu/lhu zero-extend); jalr links to rd (not always `$31`) |
| `cpu_bal_untaken_link` | `tb/CPU_prog_tb.v` | **XFAIL**: known deviation (untaken bltzal/bgezal do not link; MIPS32 always links) |

The CPU tests run `CPUMIPS` + `RegFile` + `COP0150` on `tb/CoreHarness.v` (behavioral memories:
code at `0x60000000`, ISR at `0xC0000180`, scratch RAM at `0x5xxxxxxx`, stalling "DDR" at
`0x1xxxxxxx`), so they need no Xilinx libraries. Programs in `tb/data/*.s` use `check.inc`:
`CHECK reg, expected` records a pair that the testbench compares; a failure prints
`check #N` = the N-th `CHECK` (from 0) in the program. Remember the MIPS-I load delay slot
(the instruction right after a load must not use it). The `.hex` images are checked in;
run `make hex` after editing a `.s`.

### Whole-system tests (`sys_*`)

`tb/SysUART_tb.v` instantiates `MIPS150` as on the board, minus `Memory150`: the cache ports
go to a behavioral 1 MB memory (synchronous read, no stalls; addresses alias modulo 1 MB)
that holds the BIOS stack (`0x1F000000`) and programs linked at `0x10000000`
(`LDSTYLE=inject_cache`). `scripts/build-sw.sh` builds the BIOS and the program from
`../../software` into `build/<test>/sw/` (the software tree is not touched) and stages
`bios_mem.mif` (BIOS) and `ddr.hex` (program); the other BRAMs get their CoreGen `.mif`.

The testbench talks to the CPU through the course `UART` at 16 clocks per bit
(`CPU_FREQ = 16 * 115200`, so the CPU's UART divider shrinks the same way). It sends
`<test>.in` line by line (waiting for the BIOS prompt `2>`; `+prompt_lines=1` stops waiting
after the first line, for programs without a prompt) and compares every byte the CPU sends
with `<test>.golden`, where `~` matches any byte (cycle counts, PRNG values). On a mismatch
it reports the offset; the full transcript is in `build/<test>/uart_out.txt`. Input bytes
are spaced 3 character times apart: the BIOS echoes each character and the UARTs have no
FIFO, so back-to-back characters get dropped (as they would on the board).

With `` `define SYS_DDR `` (test `sys_ddr_bios`) the testbench instead uses the real memory
system from `../src/testbench/base_clock.vh` + `base_mem.vh` (PLL, `Memory150`, DDR2 model),
wired like `ml505top.v`, and 8 clocks per serial bit (`SYS_BIT_CLKS`).

### DDR2 model

The Micron model `../src/base_mem/mig_v3_61/ddr2_model.v` declares some ports as
`input x; reg [n:0] x;`, which Icarus rejects. `scripts/patch-ddr2-model.sh` writes a patched
copy to `build/_ddr2/ddr2_model.v` (`input [n:0] x;`, 10 lines) at build time; the original is
not modified. DDR tests are slow: the MIG calibration alone takes ~83 us of sim time (~30 s
wall), and the whole `memory150_ddr` test about 70 s.

Both DDR tests filter (and count) `blk_mem_gen_v7_3 collision detected` warnings: the cache's
data/tag BRAMs are written on port A (`index_hold`) while port B reads the next request's
`index` in the same cycle, often the same row. The behavioral model only warns; on real
Virtex-5 block RAM a same-clock read of a row being written on the other port (WRITE_FIRST)
is not guaranteed to return valid data, so this is worth a look.

The original benches `../src/testbench/CacheTestBench.v` and `Memory150TestBench.v` run
unmodified as `cache_tb` and `memory150_tb` (slow). Two things used to break them under Icarus:

- before fb00126, `cachetesttasks.vh` cleared the request right at `@(posedge cpu_clk_g)`,
  racing the cache's posedge sampling, so the cache never saw a request (all reads 0, no
  stalls); it now clears it on the falling edge.
- compiled with `-g2012` (SystemVerilog), the first read miss never completes, whatever the
  stall limit. Icarus in SystemVerilog mode applies a variable's declaration initializer
  (`reg x = 0;`) before time 0 without a value-change event, and the CoreGen
  `FIFO_GENERATOR_V9_3` behavioral model passes every input through
  `always @* x_delayed <= #TCQ X;`. An input that holds its initial value from time 0 never
  wakes that block, so the model sees X forever. In `Memory150` that input is the MIG command
  and write-data FIFOs' `rd_en = !app_af_afull` / `!app_wdf_afull`, constant 1 from time 0:
  the cache's write and fetch commands sit in `mig_caf`, the MIG never gets them, no read data
  comes back and the cache waits in `READ1`. Minimal case:
  `reg a = 1; reg d; always @* d <= #1 a;` gives `d = x` with `-g2012` and `d = 1` with `-g2005`.
  The rig compiles with `-g2005`, so it was never affected. `../src/testbench/base_mem.vh` now
  pulses those two nets once in the first board-clock cycle under Icarus (`` `ifdef __ICARUS__ ``)
  so `-g2012` works too; `cache_tb_sv` (`<name>.STD := -g2012`) checks that.

## Adding a test

1. Put a testbench in `tb/` (or reuse one in `../src/testbench`). It should print `PASS: <name>`
   when everything checks out and `FAIL: ...` / `ERRORS: <n>` otherwise, then call `$finish`.
   Optional conventions: `+vcd=<file>` plusarg for waves (`WAVES=1` passes it), and
   `ifdef FORCE_FAIL` to inject an error.
2. Add `tests/<name>.mk`, where `<name>` becomes the make target:

```make
<name>.TOP      := MyThing_tb                       # top module (iverilog -s)
<name>.TB       := tb/MyThing_tb.v
<name>.SRCS     := $(SRC)/base_util/MyThing.v       # explicit sources, referenced in ../src (not copied)
<name>.YDIRS    := $(SRC_YDIRS)                     # or: let iverilog find modules by file name
<name>.INCS     := $(SRC)                           # -I dirs for `include
<name>.DEFS     :=                                  # -D defines
<name>.PLUSARGS :=                                  # vvp plusargs
# optional: RUNFILES (copied into the sim's working dir), PASS_RE, FAIL_RE,
#           QUIET_RE (drop known-noise log lines), XFAIL/SKIP (reason text), TIMEOUT, WFLAGS,
#           NEEDS (xilinx/mips/coregen: SKIP when missing), GROUP (slow: only `make slow`),
#           PREREQS, STD (language flag for this test, e.g. -g2012)
```

Whole-system tests can use `$(SYS_YDIRS)` (all source dirs, `mig_v3_61` and the CoreGen
wrappers in `../src/core_ip`) with `NEEDS := xilinx`; Xilinx tests default to the quieter
`$(XILINX_WFLAGS)`.

`make all` picks it up automatically. Compiles use `-g2005 -grelative-include -Wall -Wno-timescale`
(most sources in `../src` have no `` `timescale ``). Override with `STD=`, `WFLAGS=`, `IFLAGS=`.
Sources using the GateLib `base_util` counters (`CountRegion`, `CountCompare`; e.g. `base_vid/DVIData`)
need `MACROSAFE` (or `MODELSIM`) in `DEFS`: `base_util/Const.v` only defines it for ModelSim,
synthesis or when another file happened to define it first, and without it `CountRegion`
silently uses the wrong region logic (the DVI's active area never opens).
Modules whose file name differs from the module name (`BUS_RVA_tap/tun` in `TunTap.v`) or that
do not parse as `-y` library files (`MemMapIO.v`, `UARTRVA.v`) must be listed in `SRCS`.
