# FPGA Prog6 UART ISR Random Freeze Debug
## User

There is a mysterious frequent imminent but "randomly" timed lock-up in prog6 execution when running on the FPGA. All visible activity freezes until the soft-CPU is reset. It seems most likely to be intertwined with interrupt handling. I have put in tests to eliminate a tight infinite loop while waiting for UART ISR transmit to become ready (doesn't specifically lock up there), HOWEVER, the lockup happens quickly (within a few seconds) when normal UART output of the ticking clock is enabled but can be postponed for 30+ seconds IF disabling the clock printing immediately upon launch of the prog6 code (at 0x60000000) with ISR at (0xC0000000). Make a deep scan for other potential culprits or overt bugs in either software or hardware (or their interaction). What simple tests can be performed to pin down the bug.
Attached: hardware/src/cpu/COP0150.v

## Assistant (Grok 4.7)

The lockup tracks with UART traffic and interrupt handling, so I will scan prog6, the ISR path, and the CPU interrupt hardware together for a stall that only shows up under real timing.A prior note already points at EPC capture in the fetch stage. I will read that against the current RTL and the prog6 interrupt path before treating it as the cause.Two earlier writeups name the same EPC stall. I am checking the current fetch, COP0, and ISR sources myself so the conclusion is from the RTL, not from those notes.The fetch-stage return-PC path is unguarded against stall. Next I will check when a cache stall actually rises relative to interrupt entry, and whether the ISR software can turn a bad EPC into a permanent spin.

- List `/home/ejr/shared/cs150`
- prog6|0xC0000000|0x60000000

```
found 15 matches
```
- List `/home/ejr/shared/cs150/hardware`
- List `/home/ejr/shared/cs150/software`
- Read `/home/ejr/shared/cs150/tool/resources/DebugLockupCoPilot.md`

```
1→User: There is a mysterious frequent imminent but "randomly" timed lock-up in prog6 execution when running on the FPGA. All visible activity freezes until the soft-CPU is reset. It seems most likely to be intertwined with interrupt handling. I have put in tests to eliminate a tight infinite loop while waiting for UART ISR transmit to become ready (doesn't specifically lock up there), HOWEVER, the lockup happens quickly (within a few seconds) when normal UART output of the ticking clock is enabled but can be postponed for 30+ seconds IF disabling the clock printing immediately upon launch of the prog6 code (at 0x60000000) with ISR at (0xC0000000). Make a deep scan for other potential culprits or overt bugs in either software or hardware (or their interaction). What simple tests can be performed to pin down the bug.

Copilot: I'll start with the tagged COP0 file and the surrounding CPU and software code.

Read 
Completed with input: {
  "path": "/home/ejr/shared/cs150/hardware/src/cpu/COP0150.v"
}
…
```
- Read `/home/ejr/shared/cs150/todo_master.txt`

```
1→### This is an incomplete list that focuses specifically on completion of the final project:

===========================================================================
===========================================================================

Ensure data-hazard (load from memory into register that is used in next instruction)
is handled in all manual assembly code.
…
```
- Read `/home/ejr/shared/cs150/tool/resources/DebugLockupGrokBot.md`

```
1→:::USER:::

There is a mysterious frequent imminent but "randomly" timed lock-up in prog6 execution when running on the FPGA. All visible activity freezes until the soft-CPU is reset. It seems most likely to be intertwined with interrupt handling. I have put in tests to eliminate a tight infinite loop while waiting for UART ISR transmit to become ready (doesn't specifically lock up there), HOWEVER, the lockup happens quickly (within a few seconds) when normal UART output of the ticking clock is enabled but can be postponed for 30+ seconds IF disabling the clock printing immediately upon launch of the prog6 code (at 0x60000000) with ISR at (0xC0000000). Make a deep scan for other potential culprits or overt bugs in either software or hardware (or their interaction). What simple tests can be performed to pin down the bug.

:::GROKBOT:::

I found a likely hardware cause and reproduced it in simulation. When an interrupt is taken in the same cycle that a DDR store enters the D-cache, the cache stall that starts on the next cycle overwrites the saved return address with the ISR's own address, `0xC0000180`. The ISR then "returns" into itself with interrupts enabled and never gets back to main. Timer, UART and other interrupts still get serviced, but nothing visible updates.
…
```
- List `/home/ejr/shared/cs150/hardware/src`
- List `/home/ejr/shared/cs150/software/proj_app6`
- List `/home/ejr/shared/cs150/hardware/src/cpu`
- Read `/home/ejr/shared/cs150/hardware/src/cpu/StageF.v`

```
1→`timescale 1ns/1ps

`include "../cpuglobal.vh"

//TODO: Check for misalignment (PC-FAULT) or just formally eliminate lower 2 bits
//TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
//TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)
//TODO: Watch for undesired circumstances such as missing delay-slots or back-to-back ISR
…
```
- Read `/home/ejr/shared/cs150/hardware/src/cpu/COP0150.v`

```
1→`timescale 1ns/1ps

module COP0150 (
    input               clk, //Clock
    input               ena, //Enable
    input               rst, //Reset

    input               COP0_we, //DataInEnable
…
```
- Read `/home/ejr/shared/cs150/software/proj_app6/isr6.s`

```
1→.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _isr

.include "mmio_intr_cop0.s.inc"
.include "shared6.s.inc"
…
```
- Read `/home/ejr/shared/cs150/hardware/src/cpu/CPUMIPS.v`

```
1→`timescale 1ns/1ps

`include "../cpuglobal.vh"

module CPUMIPS #(
    parameter PC_BOOT=32'h4000_0000, PC_ISR=32'hC000_0180,
    parameter COLT45_SCOPE=0, COLT45_BRK=0,
    parameter COLT45_PC=0, COLT45_REGREAD=0, COLT45_CONTROL=0, COLT45_STEPMAX=0 //48
…
```
- intr_handled|intr_pc|DoISR|_DoISR|stall|WAS_ISR|PCNEXT

```
found 200 matches
```
- Read `/home/ejr/shared/cs150/hardware/src/cpu/MemBank.v`

```
1→`timescale 1ns/1ps

`include "../cpuglobal.vh"
`include "../tuntap.vh"

module MemBank #(
    parameter CPU_FREQ = 50_000_000,
    parameter [31:0] DEAD_DMEM = 32'd0, DEAD_IMEM = 32'd0,
…
```
- Read `/home/ejr/shared/cs150/hardware/src/base_mem/Cache.v`

```
1→//NOTE:COLT45: LITTLEWORDIAN allows natural ordering of 32-bit words within 256-bit DDR chunks

//----------------------------------------------------------------------------
// Module: Cache
// Inputs:
//    clk     : clock signal, same as CPU
//    rst     : system reset signal
//    address : 32-bit memory address
…
```
- K_TIMER|IM_|COP0_|PC_ISR|0xC0000180|stall_icache|hot_IC|hot_ISR

```
found 60 matches
```

## User

Ignore the prior rightups and work through the bug on your own separately

## Assistant

The prior notes are set aside. I am tracing interrupt entry, cache stall, and the prog6 store path from the current sources.The freeze is a bad return address from the interrupt hardware. A DDR store in the execute stage when an interrupt is accepted makes the cache stall land on the one cycle that commits EPC (exception program counter), and the saved PC is overwritten with the ISR entry point `0xC0000180`. The ISR then jumps to itself forever. The CPU is still fetching. The screen and the UART just stop getting new work from `main`.

## What the hardware does

An interrupt is accepted only on a cycle where `stall` is low. `DO_ISR` in `CPUMIPS.v` requires that, and it also waits out branches and the delay slot:

```112:112:hardware/src/cpu/CPUMIPS.v
    assign DO_ISR = BRA_IRQPending_DX2F_ && ~|{stall,INST_CouldBranch_F_,WAS_Branch,WAS_ISR};
```

On that accept cycle, `StageF` fetches `0xC0000180` and parks the PC that was replaced in `REG_PCNEXT`. That register is the value COP0 later writes into EPC (`intr_pc` is `PCNEXT_F_`). The commit happens one cycle later, when `WAS_ISR` is set:

```145:146:hardware/src/cpu/CPUMIPS.v
    assign intr_pc = PCNEXT_F_;
    assign intr_handled = !stall && WAS_ISR;
```

`REG_PCNEXT` is updated on every clock, including stalls:

```45:63:hardware/src/cpu/StageF.v
    always @(*) begin:_MUX_PCNEXT_
        casex ({rst,stall,_DoBranch})
            3'b1xx: MUX_PCNEXT = PC_BOOT;
            3'b01x: MUX_PCNEXT = REG_PC; //Stall
            3'b001: MUX_PCNEXT = _PCBranch;
            3'b000: MUX_PCNEXT = PC4;
        endcase
    end
    always @(posedge clk) begin:_REG_PCNEXT_
        REG_PCNEXT <= MUX_PCNEXT; //After DoISR, remembers the "replaced" PC
    end
    assign IMEM_ADDR = (_DoISR) ? PC_ISR : MUX_PCNEXT;
```

`REG_PC` has already become `0xC0000180` at the end of the accept cycle. A stall on the next cycle makes `MUX_PCNEXT` equal `REG_PC`, so `REG_PCNEXT` is replaced with `0xC0000180` before `intr_handled` can sample it. `WAS_ISR` stays 1 through the stall because its update is the line that is stall-gated. When the stall ends, COP0 commits EPC as `0xC0000180` and clears the global interrupt enable.

The D-cache makes that next-cycle stall inevitable for a DDR store. A write is accepted only while the cache is idle, and the stall starts the following cycle, for the whole write-through burst (`Cache.v`: `stall = (ns != IDLE)`, and a held write leaves `IDLE` for `WRITE1`). Prog6's code, ISR, stack spills, and the UART ring are in block RAM (`0x6…`, `0xC…`, `0x5…`). Those do not stall. The GPU command list is not. `hwq_line` / `hwq_pixl` store into the frame tail at `0x10xxxxxx`, which is the D-cache.

So the failing cycle is specific:

| Cycle | Execute stage | Fetch | `REG_PCNEXT` | Stall |
|---|---|---|---|---|
| Accept | DDR `sw` | redirected to `0xC0000180` | correct resume PC is captured | low, so the interrupt is allowed |
| Next | that same `sw` now in the cache | first ISR instruction waiting | overwritten with `0xC0000180` | high, because the store just entered `WRITE1` |
| Stall ends | ISR entry | — | COP0 writes that value to EPC and clears IE | low |

The two instructions already in the pipe still retire. The resume PC was the one that never got fetched. After the stall, that resume PC is gone.

`isr6.s` then does this with interrupts turned back on in the delay slot:

```106:110:software/proj_app6/isr6.s
    mfc0    $k1, COP0_Status
    ori     $k1, $k1, IM_GLOBAL
    mfc0    $k0, COP0_EPC
    jr      $k0
    mtc0    $k1, COP0_Status
```

`jr` lands on `_isr` again. Nothing in that loop returns to `main`. Timer and UART interrupts can still be taken inside the spin, which is why a reset is required to get the picture back. A soft CPU reset reloads the PC and COP0, so it clears this. It would not clear a stuck DDR controller.

## Why the timing matches what you see

Once an interrupt is pending, it cannot be taken during the stall cycles that follow a store. The next legal cycle in a store burst often is the next store. Every such entry saves `0xC0000180`.

- Clock printing queues about a dozen bytes per tick (`"\n\rCLK: mm:ss\n\r"`). Each byte completion is a one-cycle `IRQ_TX` pulse (`UARTRVA.v`), and those pulses fall in the millisecond right after `uwrite_clock_ISR`, which is immediately followed by `frame_gp_generate`.
- With printing off, the only regular interrupt is the 1 Hz timer. It is uniform across the frame. Most of a frame is `GP_WAIT` / `PF_WAIT`, which poll the MMIO block at `0x8…` and do not stall.
- The sweeper comment is the same knob on the other axis. `y += 16` emits more `hwq_pixl` stores than `y += 24`, so a larger fraction of each second is a fatal window.

Hazard rate is interrupt entries times DDR-store issue cycles. Both of your observations move that product.

## Other real bugs

These are in the sources. They do not produce a freeze that gets faster when the clock print is on and slower when the sweeper step gets larger.

**`mtc0` cancels the interrupt commit.** In `COP0150.v` the write path is `if (COP0_we) … else if (intr_handled)`. The instruction that was in fetch on the accept cycle is in execute on the commit cycle. If that instruction is `mtc0`, EPC is left unchanged and IE is not cleared. Prog6 only executes `mtc0` in `main` during startup (`ISR_STATUS`, `ISR_COMPARE`) and inside the ISR while IE is already 0. A startup hit is possible. It is not the steady freeze.

**The Cause read-modify-write drops edges.** A Cause write stores `next_ip & COP0_wd[15:10]`. `_isr` does `mfc0` / mask / `mtc0` at `done_cause`. `IRQ_TX`, `IRQ_RX`, the timer match, and the RTC match are single-cycle pulses. A pulse that arrives inside that window is cleared by the AND. A lost timer match stays lost until `count` wraps, about 86 seconds at 50 MHz. A lost TX edge leaves a ring byte sitting until the next edge. The sweeper would keep moving.

**The UART ring can skip a wakeup.** `IRQ_TX` is the rising edge of TX-ready, not the level. `uwrite_int8s_ISR` either pokes the UART directly when ready, or enqueues. If the ISR runs on that edge while the ring is still empty, and `main` enqueues afterward, no later edge occurs until something else transmits. The direct poke also jumps the queue when the ring is already nonempty. `DBG_UWAIT_MAX` is `0x0F`, so `uwait_ISR` gives up quickly. That matches the wait-loop test you already ran. `buff_data` is also the one shared field that is not `volatile`; with `-Os` the byte store is allowed to move relative to the volatile head update.

**`GP_WAIT` and `PF_WAIT` have no timeout** (`graphics.h`, `pf_wait`). A GPU or pixel-feeder stall spins in `main` at `0x6…`. The timer ISR would still be entered for real. Raising the timer rate would not make a GPU hang arrive sooner. The timer ISR only touches the block RAM mailbox and COP0.

**The stack symbol is the absolute address `0x4000`.** In `as_scratchpair.ld`, `_sp = 0x0004000` is an absolute assignment, and `_start_imem` loads it with `%hi/%lo`. Address `0x00004000` matches no bank in `MemBank.v`, so a spilled `$ra` comes back as 0 and the CPU walks `nop`s at address 0. The intended top of the 16 KB scratchpad is `0x50004000`. A bad return would show up on the first non-leaf call, the same way every run, so it is a separate footgun. `SMA_state` in `shared6.s.inc` is also pointed at `SMO_flags` rather than `SMO_state`. Nothing in `isr6.s` reads that symbol today.

Branch gating in `DO_ISR` is consistent. `CouldBranch` covers the branch while it is still in fetch, and `WAS_Branch` covers the delay slot after it executes. The ISR's own `t0`/`t1` stash and the load-delay `nop`s line up with this pipeline.

## Tests

1. **No rebuild.** During the freeze, look at `GPIO_LED[2]`. That bit is `stall_top`. `GPIO_LED[1]` is `pll_lock` and `GPIO_LED[0]` is `init_done`. A dark stall LED, with lock and init still on, means fetch is still running and the cache is idle. A solid stall LED means the cache never finished and this EPC bug is the wrong explanation.

2. **No rebuild.** Press space as soon as prog6 starts. That sets `SMM_flags_pause` and skips `frame_gp_generate`. Leave the clock print on. Pause removes the DDR stores and leaves the UART interrupts. Survival for many minutes points at the store-plus-interrupt window.

3. **Software rebuild only.** Set `K_TIMER_HZ` to 100 or 1000 and leave the sweeper running, with printing off. Time-to-freeze should shrink by about that factor. Then do the same run paused. The paused run should keep printing. A GPU hang would not track the timer rate. The ISR only writes the mailbox and COP0.

4. **A few instructions in `_isr`, no bitstream change.** After the existing `t0`/`t1` stash, read EPC. If bits 31:28 are `0xC`, store a marker at a fixed scratchpad word and write `'!'` to the UART once, without waiting on ready. A `'!'` at the moment the screen stops is the bad EPC. A correct entry saves a `0x6…` address, because prog6's code is in that bank.

5. **The hardware check.** In `StageF.v`, change the `REG_PCNEXT` update to `if (!stall) REG_PCNEXT <= MUX_PCNEXT;`. Repeat test 3. The fast timer should then keep the sweeper running. The same hold also covers a D-cache read miss in execute on the accept cycle. Writes are the common case because every DDR store misses the idle state.

6. **Separate the secondary COP0 hole.** A one-shot counter of cycles where `COP0_we && intr_handled` tells you whether startup `mtc0` ever collides with entry. Fix that path by still writing `epc <= intr_pc` and forcing `status[0]` to 0 when `intr_handled` is set, even if the execute stage is also writing COP0.

- Read `/home/ejr/shared/cs150/software/common/mmio_intr_cop0.h`

```
1→#ifndef COP0_INTR_MMIO_H_
#define COP0_INTR_MMIO_H_

#ifdef VIZARD
#include <stdbool.h>
#endif

// C HEADER file for Coprocessor, Interrupts & MMIO
…
```
- Read `/home/ejr/shared/cs150/software/proj_app6/proj6.c`

```
1→#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "graphics.h"

#include "shared6.h"
…
```
- Read `/home/ejr/shared/cs150/software/proj_app6/shared6.c`

```
1→#include "uart.h"
#include "shared6.h"
#ifdef VIZARD
#include "vizard_host.h"
#endif

#define SM_CHECK_OFFSET(member, expected) \
    typedef char sm_offset_check_##member[ \
…
```
- Read `/home/ejr/shared/cs150/software/proj_app6/shared6.h`

```
1→#ifndef PROJ_SHARED6_H_
#define PROJ_SHARED6_H_

#include "types.h"

////// Shared C/ISR constants.
//WARN: MUST keep offsets SYNCHRONIZED with sharedN.s.inc constants:
//    :   Alternative is to use C preprocessor in GAS by calling "as"
…
```
- IRQ_TX|IRQ_RX|DataInReady|assign irq

```
found 52 matches
```
- GP_WAIT|PF_WAIT|UTRAN_CTRL|UTRAN_DATA|FRAME_EXTRA|FRAME_PTR|hwq_pixl|hwq_stop

```
found 117 matches
```
- Read `/home/ejr/shared/cs150/software/proj_app6/shared6.s.inc`

```
1→#### Shared C/ISR constants.
#WARN: MUST keep offsets SYNCHRONIZED with "sharedN.h" struct & constants.
#    :   Can consider using GNU C Preprocessor on "sharedN.h"

#NOTE: Don't surround const values with parentheses in GAS...

## Basic constants:
.equiv  K_MAJOR_VERSION,    6
…
```
- Read `/home/ejr/shared/cs150/hardware/src/innerds/InstructionPreview.v`

```
1→`timescale 1ns/1ps

`include "../cpuglobal.vh"

module InstructionPreview #(
    parameter USE_DECODER=1
)(
    // Inputs to decode (PC to pin down branch/jump)
…
```
- Read `/home/ejr/shared/cs150/hardware/src/base_io/UARTRVA.v`

```
1→`timescale 1ns/1ps

`include "../cpuglobal.vh"
`include "../tuntap.vh"

/*
    UARTRVA patches a pair of RVA SHAKE busses through UART() for io serial lines
*/
…
```
- Read `/home/ejr/shared/cs150/software/common/graphics.h`

```
90→        unsigned filler_ready:1;
        unsigned gp_ready:1;        //End Byte#4
};
typedef union gstate_u {
    uint32_t u32;
    struct gstate_s f;
} gstate_tp, *gstate_pp;
typedef gstate_tp volatile gstate_tv, *gstate_pv;
…
```
- BRAM_XTRA|PC_BOOT|PC_ISR

```
found 21 matches
```
- Deviant|couldBranch

```
found 9 matches
```
- Read `/home/ejr/shared/cs150/software/common/graphics.c`

```
1→#include "graphics.h"

#include "mutmath.h"

// *** HARDWARE IMPLEMENTATION ***

// If bINST is NULL, put a single operation in GPTEMP_PTR and trigger:
gpcode_p hw_OpRGB_PP_S(
…
```
- SMA_state|PF_WAIT|pf_wait

```
found 8 matches
```
- Read `/home/ejr/shared/cs150/hardware/src/base_io/UATransmit.v`

```
1→`timescale 1ns/1ps

`ifndef MACROSAFE
`define MACROSAFE
`endif // required to get this to compile...
`include "../base_util/Const.v"

module UATransmit(
…
```
- Read `/home/ejr/shared/cs150/software/common/graphics.h`

```
1→#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"
#include "mmio_intr_cop0.h"

//MEMORY MAPPED CONTROLS (defined here because structs are unique to graphics.h)
#ifdef VIZARD
…
```
- Read `/home/ejr/shared/cs150/software/proj_app6/Makefile`

```
1→TARGET := proj6
ISR_TARGET := isr6
ISR_SHARED := shared6
LDSTYLE := as_scratchpair
FIXED_ELF ?= ../gios/gios.elf
SSRCS = $(START) #Don't include ISR assembly here, it builds separately

include ../makefile.pre
…
```
- stack|0x1000|0x7|0x5|0x6

```
found 22 matches
```
- _stack|sp

```
found 40 matches
```
- Read `/home/ejr/shared/cs150/software/link/as_scratchpair.ld`

```
1→PHDRS {
    imem PT_LOAD ;
    dmem PT_LOAD ;
}

ENTRY (_start_imem);

SECTIONS
…
```
- Read `/home/ejr/shared/cs150/hardware/src/cpu/StageDX.v`

```
1→`timescale 1ns/1ps

`include "../cpuglobal.vh"

module StageDX(
//NOTE:Currently just asynchronous "control" logic!
//    input clk, rst, stall,
…
```
- assign DOBranch|PCBranch|isBranch|isJump

```
found 16 matches
```
- _sp|0x5000

```
found 33 matches
```
- DOBranch_

```
found 5 matches
```
- Read `/home/ejr/shared/cs150/software/link/as_scratchpair.s`

```
1→.section    .start_imem
.global     _start_imem

_start_imem:
    lui     $v0, 0
    lui     $v1, 0
    lui     $a0, 0
    lui     $a1, 0
…
```
- Read `/home/ejr/shared/cs150/software/link/bios.s`

```
1→.section    .start_bios
.global     _start_bios
.extern     _gp
.extern     _sp
.extern     _fp
.extern     main_bios

_start_bios:
…
```
- CFLAGS|OPT|O2|O0|mips

```
found 48 matches
```
- Read `/home/ejr/shared/cs150/software/link/as_bioscratch.ld`

```
1→SECTIONS
{
  . = 0x50000000; /* Don't bother with .data. unless you have initialized globals */
  .data : { *(.dss .data) }
  . = 0x40000000;
  .text : { /* Use the .inst. portion as BIOS BRAM */
    *(.start); *(.text);
    . = ALIGN(4); *(.rodata.*)
…
```
- _sp|4000|50004000

```
found 0 matches
```
- List `/home/ejr/shared/cs150/software/proj_app6`
- COLT45_SCOPE|MIPS150

```
found 1 matches
```
- Read `/home/ejr/shared/cs150/hardware/src/MIPS150.v`

```
1→`timescale 1ns/1ps

// Simple adapter to house MemoryBank <=> MIPS150 interface

module MIPS150 #(
    parameter CPU_FREQ = 50_000_000,
    parameter PC_BOOT=32'h4000_0000, //NOTE: h6000_0000 for SCRATCH_IMEM
    parameter CPU_CORE = "" //Defaults to "MIPS" (MIPS.core)
…
```
- Read `/home/ejr/shared/cs150/software/link/as_scratchpair.s`

```
20→    lui     $k1, 0

    lui     $gp, %hi(_gp)
    addiu   $gp, $gp, %lo(_gp)
    lui     $fp, %hi(_fp)
    addiu   $fp, $fp, %lo(_fp)
    lui     $sp, %hi(_sp)
    addiu   $sp, $sp, %lo(_sp)
…
```
- Read `/home/ejr/shared/cs150/hardware/src/ml505top.v`

```
370→      .SRAM_CLK_FB  (SRAM_CLK_FB),
      .SRAM_CLK     (SRAM_CLK),
      .SRAM_CS_L    (SRAM_CS_B),
      .SRAM_WE_L    (SRAM_WE_B),
      .SRAM_MODE    (SRAM_MODE),
      .SRAM_ADV_LD_L(SRAM_ADV_LD_B),
      .SRAM_OE_L    (SRAM_OE_B),
      .SRAM_DATA    (SRAM_D[35:0]), //Tack on Parity
…
```
- GPIO_LED

```
found 13 matches
```
