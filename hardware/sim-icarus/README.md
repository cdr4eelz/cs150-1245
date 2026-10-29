# sim-icarus: Icarus Verilog tests

Small self-checking testbenches run with [Icarus Verilog](https://steveicarus.github.io/iverilog/).
The ModelSim tests in `../sim` are separate and unchanged.

Needs `iverilog`/`vvp` 11 or newer (developed with 12.0), GNU make and bash.
On Debian/Ubuntu: `sudo apt install iverilog`.

## Usage

```
make                 # same as `make all`: run every test, print a summary, exit nonzero on any failure
make prng32lfsr      # run one test by name
make list            # list tests (name, top module, testbench)
make clean           # remove build/
make WAVES=1 memmapio_prng            # also write build/memmapio_prng/memmapio_prng.vcd
make prng32lfsr PLUSARGS=+n=1000000   # extra vvp plusargs (here: 1M cycles instead of 100k)
make DEFINES=FORCE_FAIL               # extra `define`s; FORCE_FAIL makes each test fail on purpose
```

Everything generated goes under `build/`:

- `build/<test>.log`: simulation output (also shown on the terminal)
- `build/<test>/<test>.vvp`, `compile.log`, `<test>.vcd` (with `WAVES=1`)

A test **passes** when `vvp` exits 0, the log has a line starting with `PASS`,
and nothing in the log matches `ERRORS: [1-9]` or `FAIL`. Compile errors also fail the test.

## Tests

| Name | Testbench | Checks |
|---|---|---|
| `prng32lfsr` | `tb/PRNG32LFSR_tb.v` | `base_util/PRNG32LFSR.v`: reset value, every step against a reference model (100k cycles by default), never zero, bit balance, seed load incl. 0 -> 1, repeatable reseed |
| `memmapio_prng` | `tb/MemMapIO_prng_tb.v` | PRNG at MMIO `0x80000080` through `cpu/MemMapIO.v`: reads change, stores reseed, other MMIO stores don't, cycle counter still works |

## Adding a test

1. Put a testbench in `tb/`. It should print `PASS: <name>` when everything checks out
   and `FAIL: ...` / `ERRORS: <n>` otherwise, then call `$finish`. Optional conventions:
   `+vcd=<file>` plusarg for waves (`WAVES=1` passes it), and `ifdef FORCE_FAIL` to inject an error.
2. Add `tests/<name>.mk`, where `<name>` becomes the make target:

```make
<name>.TOP      := MyThing_tb                       # top module (iverilog -s)
<name>.TB       := tb/MyThing_tb.v
<name>.SRCS     := $(SRC)/base_util/MyThing.v       # design files, referenced in ../src (not copied)
<name>.INCS     := $(SRC)                           # -I dirs for `include
<name>.DEFS     :=                                  # -D defines
<name>.PLUSARGS :=                                  # vvp plusargs
```

`make all` picks it up automatically. Compiles use `-g2005 -grelative-include -Wall -Wno-timescale`
(most sources in `../src` have no `` `timescale ``). Override with `STD=`, `WFLAGS=`, `IFLAGS=`.
