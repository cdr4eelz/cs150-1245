# Presentation Notes

## Artificial Intelligence Declaration

TODO: Fill in with details of where/how AI was utilized and the justification for doing so.

## Demonstration Goals

- Compare GPU hardware rendering with software rendering. Decide whether to report cycle counts, elapsed time, or both.
- Demonstrate GIOS (graphics commands added to the BIOS), a `dump` command, and XOR calculation while uploading or in a block-copy command.
- Demonstrate UARX interrupts responding to keyboard commands and triggering different benchmarks.

## Display and Graphics

- Use `imem` and `dmem` for accelerated live/shared data, as well as for the stack pointer (`sp`). Consider `gp` or `fp` if other code does not use them.
- The DVI pixel clock was reduced from 50 MHz to 40 MHz to slightly reduce DDR2 load. The display remains 800x600. Driving the monitor at 60 FPS instead of 72 FPS is unlikely to matter; the app may not reach 60 FPS.
- Explain the SLR and its benefits: a simplified interface for each graphics engine, plus edge-versus-fill handling while sweeping x/column values aligned with DDR2 memory chunks.
- **Done:** The `RECT` command supports separate edge and fill colors.

## Ideas to Explore

- Characters and fonts: could they be aligned to 256-bit chunks? How should rendering synchronize with SDRAM results rather than fetching coordinates?
- Sprites, stamps, or overlays.

## Speed Comparison

```text
========================================================
Speed comparison between SW, SW-SLR, HW-indi, HW-GP sequence.
Highlite HW-GP ability to free up CPU for other work.
========================================================
> jal 10000000 [Each frame is repeated 16 times x 3 ways]

1. +++[Software only rendering]+++
    Result: 00000000 (software busy entire time)
    Cycle Count:        05d9a641   ( 98,149,953 )
    Instruction Count:  03b2f906   ( 62,060,806 )

2. +++[Each shape individually rendered in hw]+++
    Result: 00000000 (wait after EACH GPU command)
    Cycle Count:        004d32f0    ( 5,059,312 )
    Instruction Count:  004d19d3    ( 5,052,883 )

3. +++[Frame specified & rendered in hw at once]+++
    RESULT:         (*) 004cdc92    ( 5,037,202 )
    Cycle Count:        004d525a    ( 5,067,354 )
    Instruction Count:  004d343f    ( 5,059,647 )
      CPU Instructions not-waiting: 22,445

(*) WAITING Instruction Count during hw rendering.
    As one can see, nearly the entire Instruction Count
    is spent waiting for the hardware to perform the
    drawing! This means that the CPU can be working on
    other tasks, such as managing game characters or
    physics, while the hardware performs all of the
    visual rendering.  A double win: Not only is there
    massive speedup of hardware drawing, the CPU is
    free'd up to almost entirely. Note that there is
    still contention for DDR2RAM memory IF the software
    is manipulating it significantly while hardware is
    rendering.
========================================================
```

## Other Hardware Acceleration Ideas

- Multiplication and division operators or related side functionality.
- Floating-point operations, in the CPU or as a coprocessor.
- Make the SLR accessible to software rendering algorithms, with background SLR activity after a trigger and a FIFO queue of SLR actions with a wait/synchronization feature.
- Avoid DDR2 except for large data such as video frames. Store GPU operations in block RAM or a FIFO, or queue command words fetched as 128-bit values.
- Lookup tables or CORDIC operations for trigonometry.
- Variable substitution and simple calculations within GPU operations.
- A simple mini/microcontroller for basic game logic and calculations, perhaps as enhanced GPU operations with branches and loops.

## LFSR Random Number Example

A 16-bit LFSR cycles through 65,535 nonzero states before repeating:

```systemverilog
reg [15:0] lfsr;
always_ff @(posedge clk) begin
    if (reset)
        lfsr <= 16'hACE1;  // nonzero seed
    else
        lfsr <= {lfsr[14:0],
                 lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
end
```
