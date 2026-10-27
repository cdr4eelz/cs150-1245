:::USER:::

There is a mysterious frequent imminent but "randomly" timed lock-up in prog6 execution when running on the FPGA. All visible activity freezes until the soft-CPU is reset. It seems most likely to be intertwined with interrupt handling. I have put in tests to eliminate a tight infinite loop while waiting for UART ISR transmit to become ready (doesn't specifically lock up there), HOWEVER, the lockup happens quickly (within a few seconds) when normal UART output of the ticking clock is enabled but can be postponed for 30+ seconds IF disabling the clock printing immediately upon launch of the prog6 code (at 0x60000000) with ISR at (0xC0000000). Make a deep scan for other potential culprits or overt bugs in either software or hardware (or their interaction). What simple tests can be performed to pin down the bug.

:::GROKBOT:::

I found a likely hardware cause and reproduced it in simulation. When an interrupt is taken in the same cycle that a DDR store enters the D-cache, the cache stall that starts on the next cycle overwrites the saved return address with the ISR's own address, `0xC0000180`. The ISR then "returns" into itself with interrupts enabled and never gets back to main. Timer, UART and other interrupts still get serviced, but nothing visible updates.

**Why it matches what you see:** every DDR store stalls, because the D-cache is write-through, and proj6 makes thousands of DDR stores each frame when it builds the GPU command list. Clock printing adds about 13 UART-transmit interrupts per second, compared with about 1 per second with printing off. More interrupts give more chances for an interrupt to land on a DDR store, which fits a freeze within seconds versus 30+ seconds. Your `proj6.c:32` comment that a smaller step freezes later fits too.

**The fix** is one line in `hardware/src/cpu/StageF.v:58`. Change it to `if (!stall) REG_PCNEXT <= MUX_PCNEXT;`. In an Icarus simulation of your real CPU modules with cache-like stalls, the original RTL saved a bad return address on 627 of 628 interrupt entries and main stopped. With the fix there were none and main kept running.

**Other findings, from most to least serious:**
- **An interrupt during an `mtc0` in main loses the saved return address the same way.** Today only the startup code is exposed, but any future critical section would be. The tested fix blocks interrupt dispatch while an `mtc0` is being fetched, at `CPUMIPS.v:112`.
- **The ISR's read-modify-write of Cause (`isr6.s:93-96`) can lose an interrupt edge** that arrives in that window. A lost timer tick stalls the clock, and a lost transmit edge strands bytes in the buffer. Writing the mask directly, without the `mfc0`, fixes it.
- **The UART send path in `shared6.c:59-66` has races, and `buff_data` isn't `volatile`.** These can garble or drop output but can't freeze it.
- **Checked and fine:** the ISR's register save and restore, branch delay slots, the timer reload, and stack and shared-memory overlap.

**Tests to pin it down, simplest first:**
1. **No rebuild:** press space right at launch to pause, which skips the DDR-heavy frame building, and leave clock printing on. If it never freezes, that points strongly at this bug.
2. **ISR-only change:** at the top of `_isr`, check whether the saved return address (EPC) is inside the ISR range (`0xC…`), and if so print `!` on the UART. A `!` at the freeze confirms the bug. I have the exact assembly ready.
3. **Software workaround test:** disable interrupts around `frame_gp_generate`. If the freezes stop, that confirms it.
4. **Hardware fix:** rebuild with the `StageF.v` change and the `mtc0` guard. ChipScope is already wired in at `CPUMIPS.v:263` if you want to trigger on the bad return address.

I didn't change any repo files. The simulation harness and the patched Verilog are in `/workspace/scratch/isrsim/` on DEB13. Want me to put the hardware fixes and the ISR detector into your UBU24 checkout, uncommitted, so you can build and test them?
