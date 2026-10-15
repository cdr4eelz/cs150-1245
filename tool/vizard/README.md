# Vizard

Vizard is a Linux preview for the project application selected by
`APP_PROJ_VERSION` in `Makefile` (App 6 by default). It compiles the app's C
sources with `VIZARD` defined and runs them against host-side graphics and UART
implementations.

Vizard also loads the paired ISR binary and executes its instructions with a
small MIPS interpreter. The interpreter supports the instructions used by the
ISR; it is not a complete MIPS CPU or FPGA simulator and does not reproduce
cycle-accurate timing. The host supplies timer and UART events, while the GPU
command stream is rendered synchronously in software. Shared interfaces and
portable sources remain in `software/common`.

## AI Assistance

Vizard was developed substantially with AI assistance. Vizard-specific changes
to shared software are guarded with `VIZARD` where practical; shared headers
and implementations should still be reviewed for effects on non-Vizard builds.
The rest of the CS150 project was developed without AI assistance except for
separately documented exceptions. AI assistance was used here to support
implementation, debugging, design, and planning in the absence of a project
partner.

## Requirements

- GCC with AddressSanitizer and UndefinedBehaviorSanitizer support. The Vizard
  Makefile enables both sanitizers by default. Clang or other compilers may
  work, but have not been tested.
- Raylib development files and `pkg-config` metadata for the graphical app.
- GNU Make and a Linux desktop session for running the graphical app.

The tests do not open a Raylib window. The Vizard build is separate from the
Xilinx ISE and ModelSim flows.

## Build and run

If the selected ISR source has changed, rebuild its binary first. For the
default App 6 configuration:

```sh
make -C ../../software/proj_app6 isr
```

Then build and run Vizard from `tool/vizard`:

```sh
make
./vizard
```

Vizard warns when the selected ISR binary is older than its assembly sources;
it does not rebuild the application ISR automatically.

The GPU command interpreter, UART model, common graphics bridge, and expected
ASan overflow tests do not require a Raylib window. Run them with:

```sh
make check
```

## Rendering fidelity

Pixel-level rendering fidelity is a primary Vizard goal. The host consumes the
same hardware-format graphics command stream as the FPGA project and aims to
produce a pixel-for-pixel match for supported shapes. This is a functional
rendering preview, not a simulation of the CPU or GPU hardware timing.

The Vizard ellipse rasterizer follows the integer scanline recurrence used by
the shared software implementation and FPGA `ElipseEngine`; its edge color is
limited to the leftmost and rightmost pixel of each generated row. The line
rasterizer uses Bresenham stepping, rectangle rendering uses filled spans with
a one-pixel outline, and fill covers the selected frame. The `hwq_pixl` helper
encodes a pixel as a zero-length line.

Tests check representative output pixels for fill, line, rectangle, ellipse,
and pixel commands. They also check the ellipse's center-row edge thickness,
the packed `hwq_pixl` command, malformed command streams, and an intentional
out-of-bounds frame-tail write detected by ASan. These are targeted regression
checks, not an exhaustive proof for every coordinate, clipping case, or color.

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
frame number or the hardware frame address encoding. Vizard currently stores
16 frames, numbered 0 through 15.

## UART model

UART accesses use the MIPS memory map: TX ready at `0x80000000`, RX valid at
`0x80000004`, TX data at `0x80000008`, and RX data at `0x8000000c`. Raylib
character events enter the RX FIFO; the common `uread_int8()` API blocks while
pumping the event loop and echoes input like the hardware library. Both the
projN ISR-style output and common UART writes print to the Vizard launch
terminal. The host timer emulates the paired `isrN.s` 1 Hz seconds/BCD clock
update; Escape exits the app.

`projN.c` exercises the timer, UART output, common GPU command helpers, and the
paired ISR. Vizard executes that ISR through its limited MIPS interpreter;
timer scheduling and GPU submission remain host-driven and are not
cycle-accurate.

## Runtime integration

On the FPGA, the app is paired with `isrN.s` for interrupt-driven state
updates. Vizard loads the selected `isrN.bin` and runs its supported MIPS
instructions for timer and UART interrupts. Its interrupt schedule is driven
by the host event loop, so timing and scheduling only approximate the FPGA.

The source of MMIO-like behavior also differs: native code accesses FPGA
registers, while Vizard maps selected registers to host variables and callbacks.
For example, a `GP_GCODE` write stores the command pointer; Vizard notices it
on a later main-loop poll and processes the stream. MIPS shared-memory accesses
are mapped to the app's complete `SM_DATA` object so ISR updates are visible to
the C application. This provides a useful behavioral preview, not live FPGA
CPU/GPU execution.

There is no physical UART or serial-port emulation. Raylib keypress events feed
the app's host-side receive queue; common `uread_int8()` reads from that queue
while pumping the event loop. UART output is written to the Vizard launch
terminal. Press Escape to close the app.
