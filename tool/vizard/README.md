# Vizard

Vizard is an X86 Linux host for small MIPS150 graphics and UART programs. It is
separate from the Xilinx ISE and ModelSim build environments. Its initial app
target compiles `software/proj_app5/proj5.c` with `VIZARD` defined, preserving
the app's C control flow while replacing its MMIO and COP0 boundaries with a
Raylib host runtime. No MIPS instruction emulation is involved.

The project's `software/common` sources are mirrored in `sw_common/`; Vizard
builds against that local copy so host-specific adaptations do not alter the
FPGA software library.

## Build and run

Install Raylib and its `pkg-config` metadata, then run:

```sh
make
./vizard
```

The GPU command interpreter, UART model, and common graphics bridge tests do
not require a Raylib window. Run them with:

```sh
make check
```

## GPU stream

The existing common `hw_*` and `hwq_*` graphics helpers build words using the
opcode and fields defined in `hardware/src/gpu/gpcommands.vh`. One-shot helper
calls submit immediately; assigning `GP_GCODE` submits a queued stream on the
next host poll. `GP_FRAME` selects the render target and `PF_FRAME` selects
the displayed frame. Under Vizard, existing software drawing helpers dispatch
through the same software GPU rather than dereferencing FPGA framebuffer
addresses.

Words use the hardware opcode and field layout:

- `0x1RGB...`: fill the selected frame with the low 24-bit RGB color.
- `0x2RGB...`, then two point words: draw a line from `(x0, y0)` to `(x1, y1)`.
- `0x3RGB...`, two point words, then an XRGB32 word: draw an ellipse using
  `(xc, yc)` and radii `(a, b)`, with edge and interior colors.
- `0x4RGB...`, two point words, then an XRGB32 word: draw a rectangle using
  `(left, top)` and `(right, bottom)`, with edge and interior colors.
- A zero word stops the stream. Malformed or unterminated streams set GPU fault.

Each point packs X in bits 25:16 and Y in bits 9:0. Frames accept either a
frame number or the hardware frame address encoding.

## UART model

UART accesses use the MIPS memory map: TX ready at `0x80000000`, RX valid at
`0x80000004`, TX data at `0x80000008`, and RX data at `0x8000000c`. Raylib
character events enter the RX FIFO; the common `uread_int8()` API blocks while
pumping the event loop and echoes input like the hardware library. Both the
proj5 ISR-style output and common UART writes print to the Vizard launch
terminal. The host timer emulates the paired `isr5.s` 1 Hz seconds/BCD clock
update; Escape exits the app.

`proj5.c` currently demonstrates the timer and UART output path and does not
submit GPU commands, so its graphics area remains blank until the app invokes
the common rendering helpers. Vizard is synchronous at GPU submission and
approximates ISR timing; it does not model MIPS instruction execution or
cycle-accurate hardware timing.