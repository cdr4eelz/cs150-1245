.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _isr

.include "mmio_intr_cop0.s.inc"


# SHARED memory locations between app and isr handler
.equiv K_BUFSIZEB,      0x0010
.equiv K_BUFROLLOVER,   0x000F
#.equiv K_BUFSIZEB,      0x0100
#.equiv K_BUFROLLOVER,   0x00FF
.equiv K_SHARED_MAGIC,  0xFEEDBEEF

#struct SM_DATA {
#    volatile uint32_t magic; // Sanity check after initialization
#    volatile uint32_t stash0; // Save registers during interrupt
#    volatile uint32_t stash1; // typically saving $t0 $t1
#    volatile uint32_t buff_size; // For dbl-check (use K_BUFSIZEB)
#    volatile uint32_t buff_head; // Offset to circular buffer head
#    volatile uint32_t buff_tail; // Likewise for tail
#    int8_t buff_data[K_BUFSIZEB]; // The buffer itself (bytes NOT words)
#};
.equiv  SM_BASE,        0x50000000  #Some agreed upon spot in memory
# Offsets from base address as in SMO_xyz($SM_BASE)
.equiv  SMO_magic,          0x0000
.equiv  SMO_stash0,         0x0004
.equiv  SMO_stash1,         0x0008
.equiv  SMO_buff_size,      0x000C
.equiv  SMO_buff_head,      0x0010
.equiv  SMO_buff_tail,      0x0014
.equiv  SMO_buff_data,      0x0018      #Start of buffer...
# Direct addresses of shared structure members
.equiv  SMA_magic,          (SM_BASE + SMO_magic)
.equiv  SMA_stash0,         (SM_BASE + SMO_stash0)
.equiv  SMA_stash1,         (SM_BASE + SMO_stash1)
.equiv  SMA_buff_size,      (SM_BASE + SMO_buff_size)
.equiv  SMA_buff_head,      (SM_BASE + SMO_buff_head)
.equiv  SMA_buff_tail,      (SM_BASE + SMO_buff_tail)
.equiv  SMA_buff_data,      (SM_BASE + SMO_buff_data)

# A simple jump-table for JALing in...
# ...from BIOS to utility functions
.=0x0000
_entry:
    j       DISPATCH
    li      $a0, 0x0000
.=0x0010
    j       DISPATCH
    li      $a0, 0x0001
.=0x0020
    j       DISPATCH
    li      $a0, 0x0002
.=0x0030
    j       DISPATCH
    li      $a0, 0x0003
.=0x0040
    j       DISPATCH
    li      $a0, 0x0004
.=0x0050
    j       DISPATCH
    li      $a0, 0x0005
.=0x0060
    j       DISPATCH
    li      $a0, 0x0006
.=0x0070
    j       DISPATCH
    li      $a0, 0x0007
.=0x0080
    j       DISPATCH
    li      $a0, 0x0008
.=0x0090
    j       DISPATCH
    li      $a0, 0x0009

# The actual dispatch based on $a0 code (keep smaller than 0x80 bytes!)
.=0x0100
DISPATCH:
    ori     $t0, $zero, 0x0000
    beq     $t0, $a0, DO_ENABLE
    nop
    ori     $t0, $zero, 0x0001
    beq     $t0, $a0, DO_DISABLE
    nop
    ori     $t0, $zero, 0x0002
    jr      $ra
    nop


# ISR starts at 0xC000180
.=0x0180
_isr:
# Stash $t0 & $t1 on behalf of all handlers for convenience
    la      $k1, SM_BASE            # Point at base of shared data
    sw      $t0, SMO_stash0($k1)    # Stash $t0
    sw      $t1, SMO_stash1($k1)    # Stash $t1

    mfc0    $k0, COP0_Cause
    mfc0    $k1, COP0_Status
    andi    $k1, $k1, 0xFF00
    and     $k0, $k0, $k1

    andi    $k1, $k0, IM_TIMER
    bne     $k1, $zero, ISR_TIMER
    nop

    andi    $k1, $k0, IM_RTC
    bne     $k1, $zero, ISR_RTC
    nop

    andi    $k1, $k0, IM_UARX
    bne     $k1, $zero, ISR_UARX
    nop

    andi    $k1, $k0, IM_UATX
    bne     $k1, $zero, ISR_UATX
    nop

#...none active & enabled & implemented...
    j       done_stash
    nop
   

# Each handler returns here to clear related Cause bit
done_cause:     # Set $k1 to BITS-TO-KEEP mask for Cause
    mfc0    $k0, COP0_Cause
    and     $k0, $k0, $k1
    mtc0    $k0, COP0_Cause
# Drop-thru

done_stash:     # Return from handler to here to restore stashed vals
    la      $t1, SM_BASE
    lw      $t0, SMO_stash0($t1)
    lw      $t1, SMO_stash1($t1)
# Drop-thru

#done_status:   # Never return here, always restore stash above!
    mfc0    $k1, COP0_Status
    ori     $k1, $k1, IM_GLOBAL # Re-enable global interrupt flag
    mfc0    $k0, COP0_EPC       # Resume at instruction that was...
    jr      $k0                 # ...interrupted and re-enable...
    mtc0    $k1, COP0_Status    # ...interrupts "during" jump.



# Triggered when cpu-clock counter reaches desired "compare" value:
ISR_TIMER:
    j       done_cause
    addi    $k1, $zero, (~IM_TIMER & 0x0000FFFF)


# Triggered when cpu-clock counter rolls over from "-1":
ISR_RTC:
    j       done_cause
    addi    $k1, $zero, (~IM_RTC & 0x0000FFFF)


# Triggered when UART Character has arrived and is readable:
ISR_UARX:
    j       done_cause
    addi    $k1, $zero, (~IM_UARX & 0x0000FFFF)


# Triggered when UART Transmit transitions from busy to available:
ISR_UATX:
    la      $k1, SM_BASE
### If head == tail then buffer is empty
    lw      $t0, SMO_buff_head($k1)
    lw      $t1, SMO_buff_tail($k1)
    nop     #Delay Slot: Avoid hazard with $t1 fetch
    beq     $t0, $t1, UATX_DONE         # Empty buffer
    nop

    la      $k1, SM_BASE #REDUNDANT
    lw      $t1, SMO_buff_tail($k1) #REDUNDANT
    nop     #Delay Slot if $t1 used next #REDUNDANT
    addu    $k0, $k1, $t1               # Pre-index from base...
    lbu     $k0, SMO_buff_data($k0)     # ...then furthur offset.
    nop     #Delay Slot: Ensure value is available in $k0
    #Unnecessary: andi    $k0, $k0, 0x00FF
    j       UATX_SEND
    nop

#UATX_EMPTY:
###TEMP print char even if buffer is empty
#    la      $k1, MMIO_BASE
#    addi    $k0, $zero, '='
#    sw      $k0, OW_UATX_DATA($k1)
#    j       UATX_DONE
#    nop

UATX_SEND:
### Consider sanity check regarding OW_UATX_READY(MMIO_BASE)???
    la      $k1, SM_BASE #REDUNDANT
    lw      $t1, SMO_buff_tail($k1) #REDUNDANT
    addi    $t0, $t1, 1                 # Advance to next char
    andi    $t0, $t0, K_BUFROLLOVER
    sw      $t0, SMO_buff_tail($k1)     # Store new offset
    la      $k1, MMIO_BASE              # Memory mapped XMIT char

###    addi    $k0, $zero, '-'
    #nop

    sw      $k0, OW_UATX_DATA($k1)      # Send character
#    j       UATX_DONE
#    nop
# ...FALLTHROUGH...
# ISR return here (restore stashed vals & reset cause)...
UATX_DONE:
    j       done_cause
    addi    $k1, $zero, (~IM_UATX & 0x0000FFFF)


# Various utility functions reachable by "vector" jump-table above
DO_ENABLE:
    ori     $k1, $zero, (IM_UARX | IM_GLOBAL)
    jr      $ra
    mtc0    $k1, COP0_Status

DO_DISABLE:
    jr      $ra
    mtc0    $zero, COP0_Status
