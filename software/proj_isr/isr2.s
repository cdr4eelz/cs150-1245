.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _isr

.include "mmio_intr_cop0.s.inc"


# SHARED memory locations between app and isr handler
#define SM_BASE ((struct SM_DATA *) 0x50000000u)
#define K_BUFSIZEB 0x0100
.equiv K_BUFSIZEB, 0x0100
#struct SM_DATA {
#    volatile uint32_t stash0;
#    volatile uint32_t stash1;
#    volatile uint32_t buff_size;
#    volatile uint32_t buff_offset;
#    int8_t buff_data[K_BUFSIZEB];
#};
.equiv  SM_DATA,        0x50000000  #Some agreed upon spot in memory
# Offsets from base address as in SMO_xyz($SM_DATA)
.equiv  SMO_stash0,         0x0000
.equiv  SMO_stash1,         0x0004
.equiv  SMO_buff_size,      0x0008
.equiv  SMO_buff_offset,    0x000C
.equiv  SMO_buff_data,      0x0010
# Direct addresses of shared structure members
.equiv  SMA_stash0,         (SM_DATA + SMO_stash0)
.equiv  SMA_stash1,         (SM_DATA + SMO_stash1)
.equiv  SMA_buff_size,      (SM_DATA + SMO_buff_size)
.equiv  SMA_buff_offset,    (SM_DATA + SMO_buff_offset)
.equiv  SMA_buff_data,      (SM_DATA + SMO_buff_data)


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
    la      $k1, SM_DATA            # Point at base of shared data
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
    la      $t1, SM_DATA
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
    la      $k1, SM_DATA

###TEMP: Check if offset == size as temporary "done" indicator
#    la      $k1, SM_DATA
    lw      $t0, SMO_buff_offset($k1)
    ###lw      $t1, SMO_buff_size($k1)
    li      $t1, 64
    beq     $t0, $t1, UATX_ALL_SENT     ###UATX_DONE
    nop

#    la      $k1, SM_DATA
#    lw      $t0, SMO_buff_offset($k1)
    addu    $k0, $k1, $t0               # Pre-index from base...
    lbu     $k0, SMO_buff_data($k0)     # ...then furthur offset.
    #andi    $k0, $k0, 0x00FF
    bne     $k0, $zero, UATX_NOT_NULL
    nop

    sw      $t1, SMO_buff_offset($k1)   # Store buff_size when done
    ori     $k0, $zero, '='
    la      $k1, MMIO_BASE              # Memory mapped XMIT char
    sw      $k0, OW_UATX_DATA($k1)      # Send character
    j       UATX_DONE
    nop

UATX_NOT_NULL:
    addi    $t0, $t0, 1                 # Advance to next char
    sw      $t0, SMO_buff_offset($k1)   # Store new offset
    ###ori     $k0, $zero, '+'
    la      $k1, MMIO_BASE              # Memory mapped XMIT char
    sw      $k0, OW_UATX_DATA($k1)      # Send character
    j       UATX_DONE
    nop

UATX_ALL_SENT:
    la      $k1, SM_DATA
    li      $k0, K_BUFSIZEB
    sw      $k0, SMO_buff_offset($k1)
#    ori     $k0, $zero, '@'
#    la      $k1, MMIO_BASE              # Memory mapped XMIT char
#    sw      $k0, OW_UATX_DATA($k1)      # Send character

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
