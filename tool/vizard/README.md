# Vizard

Vizard provides a fast graphical preview of the current final-project
application, App 5 (`software/proj_app5/proj5.c`). Its purpose is to make the
application's appearance and interactive behavior easy to review before
building and testing it in situ on the FPGA, which takes longer.

The Vizard target compiles the app's C control flow for the Linux host with
`VIZARD` defined. It is **not an instruction-level MIPS or FPGA emulator**: it
does not execute MIPS instructions, run the app's assembly ISR, or reproduce
cycle-accurate hardware timing. Host-specific graphics and UART implementations
live in `sw_common/*_vizard.c`; shared interfaces and portable sources come
from `software/common`.

## Artificial Intelligence Declaration

Vizard is almost entirely implemented using A.I. generation and modification. This is an exception compared to the rest of the CS150 project. Any use of A.I. elsewhere is explicitly documented with an exception... Vizard A.I. development occasionally touches a few files that are shared with the larger CS150 project, notably the "common" software declarations/headers and implementations in "C" source code. Compiler macros are used to distinguish each of these but there may be minimal adjustments to truly shared code. Another exception is that debugging of Vizard had a couple very minor crossovers with bugs in the main project and the A.I. recommendation was used if it was essentially trivial.

The addition of "Vizard" represents a "time acceleration" to project work. The time limits of the project were already significantly violated by extended manual work. Additionally, the original project premise involves working with a partner however no partner was available to assist with development, debugging, design, planning, etc. Use of A.I. can be seen as a virtual partner.

## Requirements

- GCC with AddressSanitizer and UndefinedBehaviorSanitizer support. The Vizard
  Makefile enables both sanitizers by default. Clang or other compilers may
  work, but have not been tested.
- Raylib development files and `pkg-config` metadata for the graphical app.
- GNU Make and a Linux desktop session for running the graphical app.

The tests do not open a Raylib window. The Vizard build is separate from the
Xilinx ISE and ModelSim flows.

## Build and run

With the requirements installed, run:

```sh
make
./vizard
```

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
frame number or the hardware frame address encoding.

## UART model

UART accesses use the MIPS memory map: TX ready at `0x80000000`, RX valid at
`0x80000004`, TX data at `0x80000008`, and RX data at `0x8000000c`. Raylib
character events enter the RX FIFO; the common `uread_int8()` API blocks while
pumping the event loop and echoes input like the hardware library. Both the
proj5 ISR-style output and common UART writes print to the Vizard launch
terminal. The host timer emulates the paired `isr5.s` 1 Hz seconds/BCD clock
update; Escape exits the app.

`proj5.c` demonstrates the timer, UART output, and common GPU command helpers.
Vizard is synchronous at GPU submission and approximates ISR timing; it does
not model MIPS instruction execution or cycle-accurate hardware timing.

## Runtime integration

On the FPGA, the final app is closely paired with its `projN` assembly ISR
(currently `isr5.s`), which handles interrupt-driven state updates. Vizard does
not execute that ISR. It substitutes host callbacks and a polled timer to keep
the app's visible seconds/BCD clock behavior moving, while approximating rather
than reproducing interrupt timing and scheduling.

The source of MMIO-like behavior also differs: native code accesses FPGA
registers, while Vizard maps selected registers to host variables and callbacks.
For example, a `GP_GCODE` write stores the command pointer; Vizard notices it
on a later main-loop poll and processes the stream. This keeps the app-facing
behavior and interfaces sufficiently correlated for a useful preview, often in
a literal-looking way, but does not simulate live FPGA CPU/GPU execution.

There is no physical UART or serial-port emulation. Raylib keypress events feed
the app's host-side receive queue; common `uread_int8()` reads from that queue
while pumping the event loop. UART output is written to the Vizard launch
terminal. Press Escape to close the app.
