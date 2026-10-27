User: There is a mysterious frequent imminent but "randomly" timed lock-up in prog6 execution when running on the FPGA. All visible activity freezes until the soft-CPU is reset. It seems most likely to be intertwined with interrupt handling. I have put in tests to eliminate a tight infinite loop while waiting for UART ISR transmit to become ready (doesn't specifically lock up there), HOWEVER, the lockup happens quickly (within a few seconds) when normal UART output of the ticking clock is enabled but can be postponed for 30+ seconds IF disabling the clock printing immediately upon launch of the prog6 code (at 0x60000000) with ISR at (0xC0000000). Make a deep scan for other potential culprits or overt bugs in either software or hardware (or their interaction). What simple tests can be performed to pin down the bug.

Copilot: I'll start with the tagged COP0 file and the surrounding CPU and software code.

Read 
Completed with input: {
  "path": "/home/ejr/shared/cs150/hardware/src/cpu/COP0150.v"
}

Ran terminal command: cd /home/ejr/shared/cs150; ls hardware/src hardware/src/cpu software/proj_app6 software/proj_isr software/common; grep -rIl -i "cop0\|COP0150" hardware/src | head -20

Ran terminal command: cd /home/ejr/shared/cs150/software/proj_app6; wc -l *; cat isr6.s shared6.s.inc shared6.h; cat ../common/mmio_intr_cop0.s.inc ../common/mmio_intr_cop0.h

Read , lines 30 to 379
Completed with input: {
  "path": "/home/ejr/shared/cs150/software/proj_app6/isr6.s",
  "view_range": [
    30,
    379
  ]
}

Read 
Completed with input: {
  "path": "/home/ejr/shared/cs150/software/proj_app6/shared6.s.inc"
}

Read , lines 296 to 379
Completed with input: {
  "path": "/home/ejr/shared/cs150/software/proj_app6/isr6.s",
  "view_range": [
    296,
    379
  ]
}

Ran terminal command: cd /home/ejr/shared/cs150/software; cat proj_app6/proj6.c proj_app6/shared6.c; cat common/mmio_intr_cop0.s.inc | head -80; cat proj_app6/Makefile

Ran terminal command: cd /home/ejr/shared/cs150/software; sed -n 1,200p proj_app6/proj6.c | sed -n 20,175p; 

Ran terminal command: cd /home/ejr/shared/cs150/software; cat proj_app6/shared6.c; cat proj_app6/shared6.h | sed -n 1,98p

Ran terminal command: cd /home/ejr/shared/cs150/hardware/src; wc -l cpu/*.v MIPS150.v innerds/*.v base_io/*.v | tail -50; grep -n -i "intr\|irq\|cop0" cpu/CPUMIPS.v cpu/StageDX.v cpu/StageF.v cpu/StageMW.v MIPS150.v | head -120

Read , lines 60 to 372
Completed with input: {
  "path": "/home/ejr/shared/cs150/hardware/src/cpu/CPUMIPS.v",
  "view_range": [
    60,
    372
  ]
}

Read 
Completed with input: {
  "path": "/home/ejr/shared/cs150/hardware/src/cpu/StageF.v"
}

Ran terminal command: cd /home/ejr/shared/cs150/hardware/src; sed -n 1,58p cpu/CPUMIPS.v; grep -n "stall" cpu/*.v MIPS150.v ml505top.v | grep -v "^cpu/CPUMIPS.v\|StageF" | head -30; cat innerds/InstructionPreview.v

Ran terminal command: cd /home/ejr/shared/cs150/hardware/src; sed -n 20,162p MIPS150.v; grep -n "stall\|cpu_stall\|CPU_STALL" ml505top.v Memory150.v | head -30

Ran terminal command: cd /home/ejr/shared/cs150; grep -n "IM_\|COP0_" software/common/mmio_intr_cop0.s.inc | head -30; grep -n "ISR_STATUS\|ISR_COMPARE\|define" software/common/mmio_intr_cop0.h | head -40; grep -n -i "irq\|ready\|UATX\|UARX" hardware/src/cpu/MemBank.v hardware/src/cpu/MemMapIO.v | head -60

Ran terminal command: cd /home/ejr/shared/cs150/hardware/src; cat base_io/UART.v; sed -n 75,198p cpu/MemMapIO.v; sed -n 80,200p cpu/MemBank.v

Read tool output
Completed with input: {
  "path": "/tmp/1793127214542-copilot-tool-output-19022-57a1fdfd-3087-4ff9-a225-d78b5e3982b5.txt",
  "view_range": [
    60,
    330
  ]
}

Ran terminal command: cd /home/ejr/shared/cs150/hardware/src; sed -n 1,75p cpu/MemMapIO.v | grep -n "isRead\|isWrite\|stall\|input\|we\b" ; sed -n 200,272p cpu/MemBank.v; sed -n 1,80p cpu/MemBank.v | grep -n "hot\|ISR" ; grep -n "IRQ" -B2 -A8 base_io/UART.v | head -60

Ran terminal command: cd /home/ejr/shared/cs150/hardware/src; cat base_io/UARTRVA.v; sed -n 1,61p base_io/UATransmit.v

Ran terminal command: cd /home/ejr/shared/cs150/software; sed -n 36,68p common/mmio_intr_cop0.h; grep -n "UTRAN\|GP_WAIT\|PF_WAIT" -A6 common/uart.h common/graphics.h | head -60; cd ..; git log --oneline | head -5; git status --short | head

The most likely cause is a hardware bug in `StageF.v`: a stall in the cycle right after an interrupt is taken makes EPC come out as the ISR's own start address. I haven't run or simulated anything. This comes from reading the RTL and the prog6 software.

## Most likely cause: stall right after interrupt entry saves the wrong EPC

- **Normal entry:** At cycle T, `DO_ISR` makes `IMEM_ADDR = PC_ISR` and `REG_PCNEXT <= MUX_PCNEXT`, which is the PC that was replaced. At T+1, `intr_handled = !stall && WAS_ISR` makes COP0 latch `epc <= intr_pc = REG_PCNEXT`.
- **The bug:** `REG_PCNEXT <= MUX_PCNEXT` has no stall gate. If `stall` is high at T+1, `MUX_PCNEXT` is `REG_PC`, which is already `0xC0000180`. So `REG_PCNEXT` is overwritten with the ISR address. `WAS_ISR` holds during the stall, so when the stall ends EPC is latched as `0xC0000180`.
- **The lock-up:** The ISR runs and ends with `jr $k0`, which jumps back to `0xC0000180`. It re-enables IE, finds nothing pending, and returns to EPC again, forever. The CPU is alive but spinning in the ISR, so everything visible freezes until reset.
- **Why it matches your symptoms:** The stall comes from the icache/dcache DDR stalls (`stall_top = stall_dip || stall_icache || stall_dcache`). Graphics code generation and GPU traffic cause these constantly. The chance of a stall landing on that one cycle is per interrupt entry, and every UATX interrupt is an entry. Clock printing triggers about 17 or more UATX entries per second, plus the timer entry. With printing off you get about 1 entry per second, hence 30+ seconds. A "random" lock-up with a rate that scales with the number of interrupts is the signature of this bug.

**Fix** (one line, in the `_REG_PCNEXT_` block):
```verilog
always @(posedge clk) if (!stall) REG_PCNEXT <= MUX_PCNEXT;
```

## Second hardware bug: mtc0 colliding with interrupt entry

In `COP0150.v`, `if (COP0_we) … else if (intr_handled)` means a concurrent `mtc0` wins. If the instruction that was in fetch when the interrupt fired is an `mtc0` (it is in DX at T+1), EPC is not saved and IE is not cleared. A second, nested entry then fires and saves EPC inside the ISR, which is the same permanent loop.

This is rare in prog6, because the only main-code `mtc0` instructions are the startup `ISR_STATUS` and `ISR_COMPARE` macros. It would hit during startup, or in any code that uses `DO_ENABLE`/`DO_DISABLE`. Fix: always do `epc <= intr_pc` when `intr_handled` is set, and force `status[0]` to 0 even when Status is being written.

## Lower-severity problems found (none freeze the CPU)

1. **Lost interrupt pulses in COP0.** `IRQ_TX`, `IRQ_RX` and the timer match are 1-cycle pulses. Writing Cause as `next_ip & COP0_wd[15:10]` drops any pulse that arrives between the ISR's `mfc0 Cause` and `mtc0 Cause`. Clearing should be `next_ip & ~clear_mask`. A lost timer pulse means no tick for about 86 seconds, because the match is `count == compare`.
2. **UATX lost wake-up in the software.**
   - **Race:** In `uwrite_int8s_ISR` in `shared6.c`, main sees TX busy. The ready pulse fires and the ISR runs on an empty ring. Then main enqueues a character, and no further edge arrives to drain it.
   - **Related issues:** Main also bypasses the ring when TX is ready but the ring is non-empty, which reorders output. The ISR's `sw` to the UART data register can also run after main has already sent, and `MemMapIO` loses a byte in that case.
   - **Fix:** In the main-code path, either disable IE around the check-and-enqueue, or have main kick the ring itself when the UART is idle.
3. **Unbounded polls in the main loop.** `GP_WAIT`, `PF_WAIT` and `_tran_wait` have no timeout. A GPU or pixel-feeder hang would also freeze the video while the CPU keeps running. The tests below separate this from the ISR loop.
4. **`ISR_COMPARE` comment.** Its comment says it implicitly resets Count, but the hardware only resets Count on a write to register 9. If Count is already past the new Compare value, the first tick is about 86 seconds late.

I checked the delay-slot and branch interplay in `DO_ISR`. The `CouldBranch`/`WAS_Branch` gating and the "branch target saved as EPC" behaviour look correct, and I found no ISR register-clobber problem.

## Simple tests to pin it down

1. **Simulation (definitive, fastest).** In the existing testbench, run a loop with an IRQ pending and IE set. Assert `stall` for one cycle immediately after `DO_ISR` goes high, then check `cop0.epc`. It should be the interrupted PC+4 but will read `0xC0000180`.
2. **ILA/scope on the hung board.** Trace already exports `PC_DX`. After the hang, if `PC_DX` cycles through the `0xC0000180`–`0xC00001xx` range, it's the EPC loop. If it sits in a main-code poll loop, it's a GPU or pixel-feeder wait instead. Trigger on `PC_DX == C0000180` with `stall` high in the following cycle.
3. **LED or UART heartbeat.** Have the ISR toggle an LED or a counter in `SM`. If the ISR counter keeps incrementing while the video is frozen, the ISR loop is confirmed.
4. **Directly provoke it.** Disable the clock print but make `ISR_TIMER` fire at about 1 kHz (set `K_TIMER_CYC` to 50000). This should lock up within seconds while the rest stays unchanged. Also try a tight loop that stores to DDR (to force dcache stalls) with a fast timer ISR.
5. **Test the fix.** After adding the `if (!stall)` gate, repeat tests 4 and 1. A fast timer should then run for hours.
6. **Check the second bug.** Add a hardware assert that `COP0_we && intr_handled` never occurs. It should fire at startup, which confirms the `mtc0` collision.

I haven't edited any files. Say so if you want me to apply the two hardware fixes and add the simulation test.
