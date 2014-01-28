.set noat
.set noreorder

# The location of these entries is forced below
.global _JUMPTABLE_, _ISR0180_

# Misc constants
.equiv  K_MAGICB,       0xE3        #Arbitrary indicator value
.equiv  K_CPU_HZ,       (50000000)  #50 MHz
.equiv  K_TIMER_HZ,     (1)         # 1 Hz
.equiv  K_TIMER_CYC,    (K_TIMER_HZ * K_CPU_HZ)

# COP0 register names (also c0_sr, c0_cause, etc.)
.equiv  Count,      $9
.equiv  Compare,    $11
.equiv  Status,     $12
.equiv  Cause,      $13
.equiv  EPC,        $14

# COP0 interrupt BIT-offsets
.equiv  B_GLOBAL,   0
.equiv  B_UARX,     10
.equiv  B_UATX,     11
.equiv  B_RTC,      14
.equiv  B_TIMER,    15              #WARN: High bit of a short

# COP0 interrupt MASKs
.equiv  M_GLOBAL,   (1 << B_GLOBAL)
.equiv  M_UARX,     (1 << B_UARX)
.equiv  M_UATX,     (1 << B_UATX)
.equiv  M_RTC,      (1 << B_RTC)
.equiv  M_TIMER,    (1 << B_TIMER)  #WARN: If using "andi" trick !M_TIMER won't sign extend
.equiv  M_POSSIBLE, 0xFC00

# MEMORY-MAPPED IO locations
.equiv  MM_BASE,    0x80000000
.equiv  OW_UATX_READY,  0x0000
.equiv  OW_UARX_VALID,  0x0004
.equiv  OW_UATX_DATA,   0x0008
.equiv   OB_UATX_DATA,  (OW_UATX_DATA+3)
.equiv  OW_UARX_DATA,   0x000C
.equiv   OB_UARX_DATA,  (OW_UARX_DATA+3)
.equiv  OW_CNT_CYCLE,   0x0010
.equiv  OW_CNT_INST,    0x0014
.equiv  M_RVA_BIT,      0x0001
.equiv  M_DATA_BYTE,    0x000F

# SHARED memory locations
.equiv  SM_BASE,    0x10003000  #Some agreed upon spot in memory
.equiv  OB_MAGIC,       0x0000  #1-byte: Arbitrary value for sanity check
.equiv  OB_STATE,       0x0001  #1-byte: Application state (character code)
.equiv  OB_MINUTE,      0x0002  #1-byte: Minute (0-60)
.equiv  OB_SECOND,      0x0003  #1-byte: Second (0-60)
.equiv  OW_RTC,         0x0004  #4-byte: RTC "clock" (incremented 1 on Count rollover interrupt)
.equiv  OW_COUNT,       0x0008  #4-byte: COP0 Count register as of last TIMER interrupt
.equiv  OW_UNUSED0,     0x000C  #4-byte: Unused
.equiv  OW_STASH0,      0x0010  #4-byte: ISR reserved (save registers or temps)
.equiv  OW_STASH1,      0x0014  #4-byte:        "
.equiv  OW_STASH2,      0x0018  #4-byte:        "
.equiv  OW_STASH3,      0x001C  #4-byte:        "
.equiv  OW_HEAD,        0x0020  #4-byte: Byte-Pointer   (valid from SM_BUFBASE..SM_BUFLAST)
.equiv  OW_TAIL,        0x0024  #4-byte:        "       (if HEAD==TAIL, then empty)
.equiv  SM_BUFBASE, (SM_BASE + 0x0028)  #UART FIFO buffer starts here (inclusive)...
.equiv  K_BUFSIZEB,     0x0018          #...extending 24-bytes then...
.equiv  SM_BUFLAST, (SM_BUFBASE+K_BUFSIZEB-1)   #...ends here (inclusive) or just...
.equiv  SM_BUFPAST, (SM_BUFBASE+K_BUFSIZEB)     #...before here (non-inclusive).


# A simple jump-table for JAL-based manual control from BIOS
.=0x0000
_JUMPTABLE_:
    j       DO_INIT
    li      $a0, 0x0000
.=0x0010
    j       DO_ENABLE
    li      $a0, 0x0000
.=0x0020
    j       DO_DISABLE
    li      $a0, 0x0000
.=0x0030
    j       DO_INIT
    li      $a0, 0x0000



# Guard against accidentally falling through to ISR
.=0x0178
_halt:
    j       _halt
    nop

# ISR starts at 0xC000180
.=0x0180
_ISR0180_:      #ISR entry (hardware turns off global interrupt enable flag & stashes EPC for us):
    mfc0    $k0, Cause      #Grab the Cause & Status ASAP if not sooner.
    mfc0    $k1, Status     #NOTE: k0/k1 are OURS alone; No conflict! Must save EVERYTHING else tho.
    andi    $k1, $k1, M_POSSIBLE    #Mask current Status (enabled bits) with possible flags...
    and     $k0, $k0, $k1           #...and with Cause (IP flags/interrupts triggered) into $k0.
#Dispatch to routine for ONE active interrupt (prioritized check, will re-fire until all handled):
    andi    $k1, $k0, M_TIMER
    bne     $k1, $zero, ISR_TIMER
    andi    $k1, $k0, M_RTC     #NOTE: Each "andi" here is fine in the bne delay slot ($k1 changes)
    bne     $k1, $zero, ISR_RTC
    andi    $k1, $k0, M_UARX
    bne     $k1, $zero, ISR_UARX
    andi    $k1, $k0, M_UATX
    bne     $k1, $zero, ISR_UATX
#NONE active & enabled & implemented...lets clear the unknown interrupt...
    addiu   $k1, $zero, 0xFFFF  #Delay slot ok; Sign extended into all ones to invert...
    xor     $k1, $k1, $k0       #...all active flags into zeros to mask them below.
#...fallthrough (expects $k1 to be KEEP mask)...

done_cause:     #Jump here to reset certain Cause bits (set $k1 to BITS-TO-KEEP):
    mfc0    $k0, Cause
    and     $k0, $k0, $k1
    mtc0    $k0, Cause
#...fallthrough...

done_status:    #Jump here to re-enable interrupts (global Status bit) while returning to EPC:
    mfc0    $k1, Status         #Grab current enable flags...
    ori     $k1, $k1, M_GLOBAL  #...and get $k1 ready 
    mfc0    $k0, EPC            #EPC holds the PC we stepped in front of...
    jr      $k0                 #...so we jump to it as if it were $ra.
    mtc0    $k1, Status         #Delay slot ok; Re-enable global-interrupt flag while returning.
#END "return from interrupt" code.


ISR_TIMER:
    mfc0    $k1, Count          #LO-word of cycles-since-start
    la      $k0, SM_BASE
    sw      $k1, OW_COUNT($k0)  #=>SHARED memory
#Constant division tricks & 64-bit pre-truncated HI/LO contributions)!
# /50M ~= *((21.5 * 2^4) //2^30) //2^4   (truncate 4-bit remainder)
    srl     $k1, $k1, 22        #Seed the accumulator
    srl     $k0, $k1, 2         #...keep shifting in $k0...
    addu    $k1, $k1, $k0       #...and accumulating in $k1...
    srl     $k0, $k0, 2
    addu    $k1, $k1, $k0
    srl     $k0, $k0, 1
    addu    $k1, $k1, $k0
    la      $k0, SM_BASE
    lw      $k0, OW_RTC($k0)    #HI-word of cycles-since-start
    nop
    sll     $k0, $k0, 5
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 1
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 2
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 2
    addu    $k1, $k1, $k0       #Fixed-point 24.4-bit SECONDS-since-start, into $k1
    la      $k0, SM_BASE
    sw      $k1, OW_STASH0($k0) #=>STASH word#0
    srl     $k1, $k1, 4         #Truncate to 24-bit integer seconds, into $k1
#The above seems to work great for divinding by 50M quickly and pseudo 64-bit!

# /60 ~= *1092  //2^16  (16-bit remainder to recover second-hand later)
# <2+<4+<6 >>16 = Minutes
    sll     $k1, $k1, 2         #Seed the accumulator
    sll     $k0, $k1, 4
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 4
    addu    $k1, $k1, $k0       #Fixed-point 16.16-bit MINUTES-since-start, into $k1
    la      $k0, SM_BASE
    sw      $k1, OW_STASH3($k0) #=>STASH word#3
    srl     $k1, $k1, 16        #Truncate to integer MINUTE-HAND, into $k1
    la      $k0, SM_BASE
    sb      $k1, OB_MINUTE($k0) #=>SHARED memory

#0x0000FFFF <6-<2 >>16 = Seconds
    la      $k0, SM_BASE        #Restore fixed-point MINUTES-since-start
    lw      $k1, OW_STASH3($k0) #<=STASH word#3
    nop
    andi    $k0, $k1, 0xFFFF    #Grab fractional remainder only, into $k0
    sll     $k1, $k0, 6         #Seed the accumulator
    sll     $k0, $k0, 2         #Reshift original fewer bits (could also right shift without loss)
    subu    $k1, $k1, $k0       #Subtract since was a consolidated run-of-ones optimization
    srl     $k1, $k1, 16        #Truncate to integer SECOND-HAND, into $k0
    sltiu   $k0, $k1, 60        #Use flag to avoid branch (just for fun)
    addu    $k0, $k1, $k0       #Add 1 only if less than 60 (catch accidental rounding up)
    addiu   $k1, $k0, -1        #Subtract 1 always (back to 0:59 range), into $k1
    la      $k0, SM_BASE
    sb      $k1, OB_SECOND($k0)  #=>SHARED memory

#    ori     $k1, $zero, '+'
#    la      $k0, MM_BASE
#    sb      $k1, OB_UATX_DATA($k0)

    li      $k0, K_TIMER_CYC
    mfc0    $k1, Compare
    addu    $k1, $k1, $k0       #Advance to next compare value on which to fire...
    mtc0    $k1, Compare        #...without adjusting Count (avoid skewing things).
    lui     $k1, 0xFFFF         #Because !M_TIMER won't sign extend with "andi", just use lui/ori
    j       done_cause
    ori     $k1, $zero, !M_TIMER    #Delay slot ok
#END ISR_TIMER.


ISR_RTC:
    la      $k1, SM_BASE        #$k1 "points to" RTC clock counter word
    lw      $k0, OW_RTC($k1)    # or could point $k1 at all shared vars & index
    nop
    addiu   $k0, $k0, 1             #Increment clock
    sw      $k0, OW_RTC($k1)
    j       done_cause
    addiu   $k1, $zero, !M_RTC      #Delay slot ok
#END ISR_RTC.


ISR_UARX:
    la      $k0, MM_BASE
    lw      $k1, OW_UARX_VALID($k0)
    nop
    andi    $k1, $k1, M_RVA_BIT
    beq     $k1, $zero, _uarx_done

#    la      $k0, MM_BASE
#    lbu     $k1, OB_UARX_DATA($k0)
#    nop

    la      $k0, MM_BASE
    ori     $k1, $zero, '.'
    sb      $k1, OB_UATX_DATA($k0)

_uarx_done:
    j       done_cause
    addiu   $k1, $zero, !M_UARX     #Delay slot ok
#END ISR_UARX.


/*  BASED ON PLOP CIRCULAR BUFFER CODE FROM PRIOR FIDDLIN'!
u16 TxFromBuf(u8 *pB, u8 *pW, u8 *pH, u8 **ppT, int u_TX, u8 nl2cr, u16 maxBurst) {
    u8 *pT = *ppT; // Local temp for tail pointer
    if (pT == pH) break; // Buffer is empty (no work to do)
    if (XUartLite_IsTransmitFull(u_TX)) break; // We are behind (but not necessarily in trouble)
    u8 bX = *pT++; // Fetch from buffer & advance (post-increment)
    if (nl2cr && (bX == '\n')) bX = '\r'; // Translate nl->cr if requested (outbound)
    XUartLite_SendByte(u_TX, bX); // Get it closer to hardware ASAP (in case XMIT wasnt busy)
    if (pT >= pW) pT = pB; // Wrap-around if needed (hopefully never >)
    *ppT = pT; // Update the real tail pointer
}
*/

ISR_UATX:
    la      $k0, SM_BASE
#    sw      $s0, OW_STASH0($k0)     #$s0=>STASH word#0
    lw      $k1, OW_TAIL($k0)       #Grab TAIL
    lw      $k0, OW_HEAD($k0)       #Grab HEAD
    nop
    beq     $k1, $k0, _uatx_unstash #if buffer is empty, break
    la      $k0, MM_BASE
    lw      $k0, OW_UATX_READY($k0)
    nop
    andi    $k0, $k0, M_RVA_BIT
    beq     $k0, $zero, _uatx_unstash

    ori     $k1, $zero, '.'
    la      $k0, MM_BASE
    sb      $k1, OB_UATX_DATA($k0)

_uatx_unstash:
    la      $k0, SM_BASE
#    lw      $s0, OW_STASH0($k0)     #$s0<=STASH word#0
_uatx_done:
    j       done_cause              #Delay slot ok
    addiu   $k1, $zero, !M_UATX     #Delay slot ok
#END ISR_UATX.



DO_INIT:
##Prologue
#    addiu   $sp, $sp, -8
#    sw      $ra, 4($sp)
#Body
    mtc0    $zero, Status       #Totally disabled
    mtc0    $zero, Cause        #Zero any existing interrupts (is this OK?)
    la      $t0, SM_BASE
    sw      $zero, 0x00($t0)    #Blank shared memory (magic, state, minute, second)
    sw      $zero, OW_RTC($t0)
    sw      $zero, OW_COUNT($t0)
    sw      $zero, OW_UNUSED0($t0)
    sw      $zero, OW_STASH0($t0)
    sw      $zero, OW_STASH1($t0)
    sw      $zero, OW_STASH2($t0)
    sw      $zero, OW_STASH3($t0)
    sw      $zero, OW_HEAD($t0)
    sw      $zero, OW_TAIL($t0)
    ori     $t1, $zero, K_MAGICB
    sb      $t1, OB_MAGIC($t0)
    li      $t1, K_TIMER_CYC
    mtc0    $t1, Compare
    mtc0    $zero, Count
    ori     $t1, $zero, (M_TIMER | M_RTC | M_UATX | M_UARX | M_GLOBAL)
##Epilogue
#    lw      $ra, 4($sp)
#    nop
#    addiu   $sp, $sp, 8         #Delay slot ok;
    jr      $ra
    mtc0    $t1, Status


DO_ENABLE:
    ori     $t0, $zero, (M_TIMER | M_RTC | M_UATX | M_UARX | M_GLOBAL)
    jr      $ra
    mtc0    $t0, Status
#END DO_ENABLE.


DO_DISABLE:
    jr      $ra
    mtc0    $zero, Status
#END DO_DISABLE.




/*
::NOTES ON CONSTANT DIVISION/MULTIPLICATION CALCULATIONS::

divide by 50_000_000 = 0x02FAF080 = 0000_0010_1111_1010_1111_0000_1000_0000
0.00000002 = 21.47483648 / 2^30 ~= 344 / 2^34
n * 344 / 2^31
n*344 == n*10101 =(n<<4)+(n<<2)+(n<<0)
101
  101
    101
     10.1000
1101011.1000 = 107.5 (5*21.5)

<10 <8 <6 <5 | >>4
<5+<1+<2+<2 >>4
------
/60 = *0.016666667 = *1092/2^16
0.0000010001000100
<2 <6 <10 | >>16  (<10 >16 = >6 like /64 with additional fractions)
<2+<4+<4 >>16 Minutes
*60 = *111100 = *1000000 - *100
0x00FF <6-<2 >>16 = Seconds
*/