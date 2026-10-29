# sim-icarus: Icarus Verilog tests

Small self-checking testbenches run with [Icarus Verilog](https://steveicarus.github.io/iverilog/).
The ModelSim tests in `../sim` are separate and unchanged.

Needs `iverilog`/`vvp` 11 or newer (developed with 12.0), GNU make and bash.
On Debian/Ubuntu: `sudo apt install iverilog`.

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

A test whose `NEEDS` are missing is reported as **SKIP** with the reason (e.g. `needs Xilinx sim
sources: set XILINX_SRC=<ISE>/verilog/src`) and does not fail the run. The other requirement
is `mips` (the `mips-linux-gnu-` toolchain, prefix `M_PRE`), for tests that build programs from
`../../software`.

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
| `regfile`, `stage_dx`, `stage_mw`, `byteaccess4` | `../src/testbench/` | RegFile; StageDX decode/execute; StageMW (elaboration smoke only); ByteAccess4 store masks |
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
| `memory150_ddr` (slow, xilinx) | `tb/Memory150_ddr_tb.v` | `Memory150` caches + MIG + Micron DDR2 model: write-through, read-miss fills, hits, byte masks, same-index eviction, icache fill from DDR, 100 random ops vs. a shadow memory |
| `cpu_lb_lh_sign`, `cpu_jalr_rd`, `cpu_bal_untaken_link` | `tb/CPU_prog_tb.v` | **XFAIL**: known CPU bugs/deviations (lb/lh sign extension, jalr rd, untaken bltzal/bgezal link) |

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

### DDR2 model

The Micron model `../src/base_mem/mig_v3_61/ddr2_model.v` declares some ports as
`input x; reg [n:0] x;`, which Icarus rejects. `scripts/patch-ddr2-model.sh` writes a patched
copy to `build/_ddr2/ddr2_model.v` (`input [n:0] x;`, 10 lines) at build time; the original is
not modified. DDR tests are slow: the MIG calibration alone takes ~83 us of sim time (~30 s
wall), and the whole `memory150_ddr` test about 70 s.

`../src/testbench/Memory150TestBench.v` itself does not work under Icarus: `cachetesttasks.vh`
clears the request right at `@(posedge cpu_clk_g)`, racing with the cache's posedge sampling,
so the cache never sees a request (all reads return 0, no stalls). `tb/Memory150_ddr_tb.v`
drives requests on the negedge and holds them while stalled, as the CPU does.

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
#           NEEDS (xilinx/mips: SKIP when missing), GROUP (slow: only `make slow`), PREREQS
```

Whole-system tests can use `$(SYS_YDIRS)` (all source dirs, `mig_v3_61` and the CoreGen
wrappers in `../src/core_ip`) with `NEEDS := xilinx`; Xilinx tests default to the quieter
`$(XILINX_WFLAGS)`.

`make all` picks it up automatically. Compiles use `-g2005 -grelative-include -Wall -Wno-timescale`
(most sources in `../src` have no `` `timescale ``). Override with `STD=`, `WFLAGS=`, `IFLAGS=`.
Modules whose file name differs from the module name (`BUS_RVA_tap/tun` in `TunTap.v`) or that
do not parse as `-y` library files (`MemMapIO.v`, `UARTRVA.v`) must be listed in `SRCS`.
