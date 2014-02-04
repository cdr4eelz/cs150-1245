.set noat
.set noreorder

# The location of these entries is forced below
.global ENTRY10X10, ISR0180

# Misc constants
.equiv  K_MAGICW,       0xE3BEEF10      #Arbitrary indicator value
.equiv  K_CPU_HZ,       (50000000)      #50 MHz
.equiv  K_TIMER_HZ,     (1)             # 1 Hz
.equiv  K_TIMER_CYC,    (K_TIMER_HZ * K_CPU_HZ)

# COP0 register names (also c0_sr, c0_cause, etc.)
.equiv  Count,          $9
.equiv  Compare,        $11
.equiv  Status,         $12
.equiv  Cause,          $13
.equiv  EPC,            $14

# COP0 interrupt BIT-offsets
.equiv  B_GLOBAL,       0
.equiv  B_UARX,         10
.equiv  B_UATX,         11
.equiv  B_RTC,          14
.equiv  B_TIMER,        15              #WARN: High bit of a short

# COP0 interrupt MASKs
.equiv  M_GLOBAL,       (1 << B_GLOBAL)
.equiv  M_UARX,         (1 << B_UARX)
.equiv  M_UATX,         (1 << B_UATX)
.equiv  M_RTC,          (1 << B_RTC)
.equiv  M_TIMER,        (1 << B_TIMER)  #WARN: If using "andi" trick !M_TIMER won't sign extend
.equiv  M_POSSIBLE,     0xFC00

# MEMORY-MAPPED IO locations
.equiv  MM_BASE,    0x80000000
.equiv  OW_UATX_READY,  0x0000
.equiv  OW_UARX_VALID,  0x0004
.equiv  OW_UATX_DATA,   0x0008
.equiv   OB_UATX_DATA,   (OW_UATX_DATA+3)
.equiv  OW_UARX_DATA,   0x000C
.equiv   OB_UARX_DATA,   (OW_UARX_DATA+3)
.equiv  OW_CNT_CYCLE,   0x0010
.equiv  OW_CNT_INST,    0x0014
.equiv  OW_CNT_RESET,   0x0018
.equiv  M_RVA_BIT,      0x0001
.equiv  M_DATA_BYTE,    0x000F

# SHARED memory locations
.equiv  SM_BASE,    0x10002000  #Some agreed upon spot in memory
.equiv  OW_MAGIC,       0x0000  #4-byte: Arbitrary value for sanity check
.equiv  OB_FLAGS,       0x0004  #1-byte: flag bitmask
.equiv   MF_TIMER,        0x01      #TIMER output enabled
.equiv  OB_MINUTE,      0x0005  #1-byte: Minute BCD (0-60)
.equiv  OB_SECOND,      0x0006  #1-byte: Second BCD (0-60)
.equiv  OB_STATE,       0x0007  #1-byte: Application state (character code)
.equiv  OW_RTC,         0x0008  #4-byte: RTC "clock" (incremented 1 on Count rollover interrupt)
.equiv  OW_COUNT,       0x000C  #4-byte: COP0 Count register as of last TIMER interrupt
.equiv  OW_STASH0,      0x0010  #4-byte: ISR reserved (save registers or temps)
.equiv  OW_STASH1,      0x0014  #4-byte:        "
.equiv  OW_HEAD,        0x0018  #4-byte: Byte-Pointer   (valid from SM_BUFBASE..SM_BUFLAST)
.equiv  OW_TAIL,        0x001C  #4-byte:        "       (if HEAD==TAIL, then empty)
.equiv  SM_BUFBASE, (SM_BASE+0x0020)    #UART FIFO buffer starts here (inclusive)...
.equiv  K_BUFSIZEB,     0x0020          #...extending 32-bytes then...
.equiv  SM_BUFLAST, (SM_BUFBASE+K_BUFSIZEB-1)   #...ends here (inclusive) or just...
.equiv  SM_BUFPAST, (SM_BUFBASE+K_BUFSIZEB)     #...before here (non-inclusive).


# Simple function/jump table for JAL-based callins (like manually from BIOS)
.=0x0000
ENTRY10X10:
    j       DO_INIT
    li      $a0, 0x0000

.=0x0010
DO_ENABLE:      #Squeeze entry!
    ori     $t0, $zero, (M_TIMER | M_RTC | M_UATX | M_UARX | M_GLOBAL)  #Enable ALL we know
    mfc0    $v0, Status             #Return replaced status
    jr      $ra
    mtc0    $t0, Status             #D;

.=0x0020
DO_DISABLE:     #Squeeze entry!
    mfc0    $v0, Status             #Return replaced status
    jr      $ra
    mtc0    $zero, Status           #D; #Disable absolutely everything!

# Rest of table is one big dummy function returning -1
.org (0x0100 - 8), 0 #NOPs
    jr      $ra
    addiu   $v0, $zero, -1          #D;


DO_INIT:
##Prologue
#    addiu   $sp, $sp, -8
#    sw      $ra, 4($sp)
#Body
    mtc0    $zero, Status           #Totally disabled
    mtc0    $zero, Cause            #Zero any existing interrupts (is this OK?)
    la      $t0, SM_BASE            #Blank shared memory
    sw      $zero, OW_MAGIC($t0)
    sw      $zero, 0x0004($t0)      #(flags, minute, second, state)
    sw      $zero, OW_RTC($t0)
    sw      $zero, OW_COUNT($t0)
    sw      $zero, OW_STASH0($t0)
    sw      $zero, OW_STASH1($t0)
    la      $t1, SM_BUFBASE         #Reset HEAD & TAIL to BASE of buffer
    sw      $t1, OW_HEAD($t0)
    sw      $t1, OW_TAIL($t0)
    li      $t1, K_MAGICW           #Set magic value
    sw      $t1, OW_MAGIC($t0)
    mtc0    $zero, Count            #Count from zero
    li      $t1, K_TIMER_CYC        #...up to first timer interval
    mtc0    $t1, Compare
    ori     $t1, $zero, (M_TIMER | M_RTC | M_UATX | M_GLOBAL)  #Enable ALL but M_UARX
##Epilogue
#    lw      $ra, 4($sp)
#    nop                             #D;
#    addiu   $sp, $sp, 8             #D;
    jr      $ra
    mtc0    $t1, Status             #D;



# ISR starts at 0xC000180
.=0x0180
ISR0180:            #ISR entry (hardware turns off global interrupt enable flag & stashes EPC for us):
    mfc0    $k0, Cause      #Grab the Cause & Status ASAP if not sooner.
    mfc0    $k1, Status     #NOTE: k0/k1 are OURS alone; No conflict! Must save EVERYTHING else tho.
    andi    $k1, $k1, M_POSSIBLE    #Mask current Status (enabled bits) with possible flags...
    and     $k0, $k0, $k1           #...and with Cause (IP flags/interrupts triggered) into $k0.
#Dispatch to routine for ONE active interrupt (prioritized check, hardware re-fires as necessary):
    andi    $k1, $k0, M_TIMER
    bne     $k1, $zero, ISR_TIMER
    andi    $k1, $k0, M_RTC         #D;
    bne     $k1, $zero, ISR_RTC
    andi    $k1, $k0, M_UARX        #D;
    bne     $k1, $zero, ISR_UARX
    andi    $k1, $k0, M_UATX        #D;
    bne     $k1, $zero, ISR_UATX
#NONE active & enabled & implemented...lets clear the unknown interrupt...
    addiu   $k1, $zero, 0xFFFF      #D; #Sign extended into all ones to invert...
    xor     $k1, $k1, $k0           #...all active flags into zeros to mask them below.
#FALLTHROUGH...with $k1 as mask out of mysterious flags

isr_ret_cause:      #EXPECT: $k1 == BITS-TO-KEEP mask; #Clear some Cause bits then isr_ret_enable...
    mfc0    $k0, Cause
    and     $k0, $k0, $k1
    mtc0    $k0, Cause
#FALLTHROUGH...

isr_ret_enable:     #Re-enable global interrupts (global Status bit) then isr_ret...
    mfc0    $k1, Status             #Grab current enable flags...
    ori     $k1, $k1, M_GLOBAL      #...and get $k1 ready
#FALLTHROUGH...with $k1 as new Status

isr_ret:            #EXPECT: $k1 == new Status; #Set Status then return to EPC
    mfc0    $k0, EPC                #EPC holds the PC we stepped in front of...
    jr      $k0                     #...so we jump to it as if it were $ra.
    mtc0    $k1, Status             #D; #Re-enable global-interrupt flag while returning.

#END: ISR.


ISR_TIMER:
    mfc0    $k0, Compare
    li      $k1, K_TIMER_CYC
    addu    $k0, $k0, $k1          #Advance to next compare value on which to fire...
    mfc0    $k1, Count              #LO-word of cycles-since-start (grab early)
    mtc0    $k0, Compare            #...without adjusting Count (avoid skewing things).
    la      $k0, SM_BASE
    sw      $ra, OW_STASH1($k0)     #$ra=>STASH1
    sw      $k1, OW_COUNT($k0)      #=>SHARED memory

#Constant division tricks & 64-bit pre-truncated HI/LO contributions)!
#cdiv /50M ~= *((21.5 * 2^4) //2^30) //2^4   (truncate 4-bit remainder)
#cmul <5+<1+<2+<2 [>>4 postponed] (in reverse to hi-bits of lo-word: 30-4=26 26=22+2+2+1)
    srl     $k1, $k1, 22            #Seed the accumulator
    srl     $k0, $k1, 2             #...keep shifting $k0...
    addu    $k1, $k1, $k0           #...and accumulating in $k1...
    srl     $k0, $k0, 2
    addu    $k1, $k1, $k0
    srl     $k0, $k0, 1
    addu    $k1, $k1, $k0
    la      $k0, SM_BASE
#cmul +<5+<1+<2+<2 >>4 (accumulate hi-word contribution into our 32-bit window & truncate)
    lw      $k0, OW_RTC($k0)        #HI-word of cycles-since-start
    nop                             #D;
    sll     $k0, $k0, 5
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 1
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 2
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 2
    addu    $k1, $k1, $k0           #Fixed-point 24.4-bit SECONDS-since-start, into $k1
    srl     $k1, $k1, 4             #Truncate to 24-bit integer seconds, into $k1
#Above is slick for divinding by 50M quickly and pseudo 64-bit!

#cdiv /60 ~= *1092  //2^16  (16-bit remainder to recover second-hand later)
#cmul <2+<4+<4 [>>16 postponed] (SECONDS-since-start => MINUTES-since-start)
    sll     $k1, $k1, 2             #Seed the accumulator
    sll     $k0, $k1, 4
    addu    $k1, $k1, $k0
    sll     $k0, $k0, 4
    addu    $k1, $k1, $k0           #Fixed-point 16.16-bit MINUTES-since-start, into $k1

#stash fixed-point result
    la      $k0, SM_BASE
    sw      $k1, OW_STASH0($k0)     #=>STASH0

#truncate & move-HI MINUTE-HAND
    srl     $k1, $k1, 16            #Truncate to integer MINUTE-HAND, into $k1
    andi    $k1, $k1, 0b00111111    #6-bit value
    sll     $k1, $k1, 16            #shift into high half

#stash MINUTE-HAND & unstash fixed-point (quick-swap of same memory & same register!)
    lw      $k1, OW_STASH0($k0)     #<=STASH0 #WARN:MEMORY-REG SWAP
    sw      $k1, OW_STASH0($k0)     #D; #WARN:LOAD-STORE CROSSOVER; #$s0=>STASH0

#mask 0x0000FFFF cmul <6-<2 >>16 = Seconds  (fraction => remainder)
    andi    $k0, $k1, 0xFFFF        #Grab fractional remainder only, into $k0
    sll     $k1, $k0, 6             #Seed the accumulator
    sll     $k0, $k0, 2             #Reshift original fewer bits (could also right shift without loss)
    subu    $k1, $k1, $k0           #Subtract since was a consolidated run-of-ones optimization

#truncate & clip SECOND-HAND
    srl     $k1, $k1, 16            #Truncate to integer SECOND-HAND, into $k0
    andi    $k1, $k1, 0b00111111    #6-bit value
    sltiu   $k0, $k1, 60            #Use flag to avoid branch (just for fun)
    addu    $k0, $k1, $k0           #Add 1 only if less than 60 (catch accidental rounding up)
    addiu   $k1, $k0, -1            #Subtract 1 always (back to 0:59 range), into $k1

#overlay upper & low binary halves
    la      $k0, SM_BASE
    lw      $k0, OW_STASH0($k0)     #<=STASH0
    nop                             #D;
    or      $k1, $k1, $k0

#double-dabble each half simultaneously to BCD (two digits each)
    jal     ROLL_BCD
    sll     $k1, $k1, 1             #D; #shift 1/6
    jal     ROLL_BCD
    sll     $k1, $k1, 1             #D; #shift 2/6
    jal     ROLL_BCD
    sll     $k1, $k1, 1             #D; #shift 3/6
    jal     ROLL_BCD
    sll     $k1, $k1, 1             #D; #shift 4/6
    jal     ROLL_BCD
    sll     $k1, $k1, 1             #D; #shift 5/6
#    sll     $k1, $k1, 1             #shift 6/6
#    srl     $k1, $k1, 6             #align to lower two BCD digits
    srl     $k1, $k1, (6-1)         #shift 6/6 #align to lower two BCD digits
    la      $k0, SM_BASE
    sb      $k1, OB_SECOND($k0)
    srl     $k1, $k1, 16            #align to upper two BCD digits
    sb      $k1, OB_MINUTE($k0)     #D;

#check if we skip output
    la      $k0, SM_BASE
    lbu     $k1, OB_FLAGS($k0)
    nop                             #D;
    andi    $k1, $k1, MF_TIMER
    beq     $k1, $zero, timer_unstash
    nop                             #D;

#send time as "mm:ss"
    la      $k0, SM_BASE
    lbu     $k0, OB_MINUTE($k0)
    nop
    srl     $k0, $k0, 4
    addiu   $k1, $k0, '0'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;
    la      $k0, SM_BASE
    lbu     $k0, OB_MINUTE($k0)
    nop
    andi    $k0, $k0, 0x000F
    addiu   $k1, $k0, '0'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;

    ori     $k1, $zero, ':'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;

    la      $k0, SM_BASE
    lbu     $k0, OB_SECOND($k0)
    nop
    srl     $k0, $k0, 4
    addiu   $k1, $k0, '0'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;
    la      $k0, SM_BASE
    lbu     $k0, OB_SECOND($k0)
    nop
    andi    $k0, $k0, 0x000F
    addiu   $k1, $k0, '0'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;

    ori     $k1, $zero, '\r'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;
    ori     $k1, $zero, '\n'
    jal     SEND                    #expects char-to-send in $k1
    nop                             #D;

timer_unstash:
    la      $k0, SM_BASE
    lw      $ra, OW_STASH1($k0)     #$ra<=STASH1
    lui     $k1, 0xFFFF             #D; #NOTE: !M_TIMER won't sign extend with "andi"
    j       isr_ret_cause
    ori     $k1, $zero, !M_TIMER    #D;

#END: ISR_TIMER.


ISR_RTC:
    la      $k1, SM_BASE
    lw      $k0, OW_RTC($k1)
    nop                             #D;
    addiu   $k0, $k0, 1             #Increment clock
    sw      $k0, OW_RTC($k1)
    j       isr_ret_cause
    addiu   $k1, $zero, !M_RTC      #D;

#END: ISR_RTC.


ISR_UARX:
    la      $k0, MM_BASE
    lw      $k1, OW_UARX_VALID($k0) #UART recv truly/still valid?
    nop                             #D;
    andi    $k1, $k1, M_RVA_BIT
    beq     $k1, $zero, _uarx_done
    nop                             #D;
#custom search "case" checking (trying to be quick since interrupts disabled)
    lbu     $k1, OB_UARX_DATA($k0)  #UART recv byte
    ori     $k0, $zero, 0x01        #D; #control-A
    beq     $k0, $k1, _uarx_abort
    ori     $k0, $zero, 'd'         #D;
    beq     $k0, $k1, _uarx_disable
    ori     $k0, $zero, 'e'         #D;
    beq     $k0, $k1, _uarx_enable
    ori     $k0, $k1, 0b00100100    #D; #force don't-cares to 1's
    xori    $k0, $k0, 0b01110110    #toggle 1's from "match"
    bne     $k0, $zero, _uarx_done  #covers "RVrv" characters simultaneously!
    lui     $k0, %hi(SM_BASE)       #D;
    ori     $k0, $k0, %lo(SM_BASE)
    j       _uarx_done
    sb      $k1, OB_STATE($k0)      #D; #store STATE for application to see

_uarx_enable:
    la      $k0, SM_BASE
    lbu     $k1, OB_FLAGS($k0)
    nop                             #D;
    ori     $k1, $k1, MF_TIMER
    j       _uarx_done
    sb      $k1, OB_FLAGS($k0)      #D;

_uarx_disable:
    la      $k0, SM_BASE
    lbu     $k1, OB_FLAGS($k0)
    nop                             #D;
    andi    $k1, $k1, !MF_TIMER
    sb      $k1, OB_FLAGS($k0)
#    j       _uarx_done
#    nop                             #D;
#FALLTHROUGH...

_uarx_done:
    j       isr_ret_cause
    addiu   $k1, $zero, !M_UARX     #D;

_uarx_abort:
    mtc0    $zero, Cause            #blast the Cause register!
    j       isr_ret                 #expects new Status in $k1
    ori     $k1, $zero, 0           #D; #disable everything

#END: ISR_UARX.


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
    lw      $k1, OW_HEAD($k0)       #Grab HEAD & TAIL
    lw      $s0, OW_TAIL($k0)       #D; #REG: $s0 == TAIL
    sw      $s0, OW_STASH0($k0)     #D; #WARN:LOAD-STORE CROSSOVER; #$s0=>STASH0
    beq     $k1, $s0, _uatx_unstash #if buffer is empty, break
    la      $k0, MM_BASE            #D;
    lw      $k1, OW_UATX_READY($k0) #UART xmit truly/still ready?
    nop                             #D;
    andi    $k1, $k1, M_RVA_BIT
    beq     $k1, $zero, _uatx_unstash
    nop                             #D;
    lbu     $k1, 0($s0)             #load next byte to send from buffer
    addiu   $s0, $s0, 1             #D; #post-increment TAIL reg
    la      $k0, MM_BASE
    sb      $k1, OB_UATX_DATA($k0)  #UART xmit byte
    la      $k1, SM_BUFPAST
    sltu    $k1, $s0, $k1           #detect wraparound
    bne     $k1, $zero, _uatx_nowrap
    lui     $k0, %hi(SM_BASE)       #D; #1st half of "la" (always used)
    la      $s0, SM_BUFBASE
_uatx_nowrap:
    ori     $k0, $k0, %lo(SM_BASE)  #2nd half of "la" (reached eather way)
#    la      $k0, SM_BASE
    sw      $s0, OW_TAIL($k0)       #REG: $s0 free; #update real TAIL pointer (in memory)
_uatx_unstash:
    la      $k0, SM_BASE
    lw      $s0, OW_STASH0($k0)     #$s0<=STASH0
_uatx_done:
    j       isr_ret_cause           #D;
    addiu   $k1, $zero, !M_UATX     #D;

#END: ISR_UATX.


ROLL_BCD:           #EXPECT: $k1 == BCD scratch; #FOUL: $ra, $k0, $k1
    andi    $k0, $k1, (0xF << 6)
    sltiu   $k0, $k0, (0x5 << 6)
    bne     $k0, $zero, _less00
    andi    $k0, $k1, (0xF << 10)   #D; #needn't include addiu contribution
    addiu   $k1, $k1, (0x3 << 6)
_less00:
    sltiu   $k0, $k0, (0x5 << 10)
    bne     $k0, $zero, _less10
    srl     $k0, $k1, (16 + 6)      #D; #needn't include addiu contribution
    addiu   $k1, $k1, (0x3 << 10)
_less10:
    andi    $k0, $k0, 0xF
    sltiu   $k0, $k0, 0x5
    bne     $k0, $zero, _less20
    lui     $k0, (3 << 6)           #D; #only used if no branch
    addu    $k1, $k1, $k0
_less20:
    srl     $k0, $k1, (16 + 10)
    andi    $k0, $k0, 0xF
    sltiu   $k0, $k0, 0x5
    bne     $k0, $zero, _less30
    lui     $k0, (3 << 10)          #D; #only used if no branch
    jr      $ra
    addu    $k1, $k1, $k0           #D;
_less30:
    jr      $ra
    nop

#END: ROLL_BCD.


SEND:               #EXPECT: $k1 = char-to-send; #FOUL: $ra, $k0, $k1
    la      $k0, MM_BASE
    lw      $k0, OW_UATX_READY($k0)
    nop                             #D;
    andi    $k0, $k0, M_RVA_BIT
    beq     $k0, $zero, _send_enqueue
    lui     $k0, %hi(MM_BASE)       #D; #1st half of "la" (used only if branch)
#TODO: If queue not empty, enqueue new & send HEAD instead
    ori     $k0, $k0, %lo(MM_BASE)  #2nd half of "la"
    sb      $k1, OB_UATX_DATA($k0)  #UART xmit, immediately
    jr      $ra
    nop                             #D;

_send_enqueue:
    la      $k0, SM_BASE
    lw      $k0, OW_HEAD($k0)       #grab HEAD
    nop                             #D;
#TODO: Ensure not full!
    sb      $k1, 0($k0)             #ensure $k1 safe until this point!
    addiu   $k1, $k0, 1             #advance HEAD
    la      $k0, SM_BUFPAST
    slt     $k0, $k1, $k0
    bne     $k0, $zero, _no_wrap
    lui     $k0, %hi(SM_BASE)       #D; #1st half of "la" (always used)
    la      $k1, SM_BUFBASE
_no_wrap:
    ori     $k0, $k0, %lo(SM_BASE)  #2nd half of "la" (reached eather way)
    sw      $k1, OW_HEAD($k0)       #store HEAD
    jr      $ra
    nop                             #D;

#END: SEND.




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


::NOTES ON CASE STATEMENT OPTIMIZATION::

#(ctl-a)RV][derv
~ 01    00000001

d 64    01100100
e 65    01100101
de      0110010x (covered)
mask    11111110
force   00000001 0x01 low-bit == enable
match   01100101 0x65
srl-1    0110010 0x32

R 52    01010010
V 56    01010110
r 72    01110010
v 76    01110110
rvRV    01x10x10 (covered)
mask    11011011 0xDB
force   00100100 0x24
match   01110110 0x76

30-39 '0'..'9' Digit: add/or 0x30
*/
