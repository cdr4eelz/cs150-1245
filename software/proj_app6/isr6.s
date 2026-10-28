.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _isr

.include "mmio_intr_cop0.s.inc"
.include "shared6.s.inc"

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
   

### This commented code leaves a tiny window in which a newly arrived
###   interrupt can be missed if we clear the Cause too early.
###   Note that masking in software is unnecessary because the hardware
###   handles it already and Cause write can only clear interrupt bits,
###   never set them.
###done_cause:     # Set $k1 to BITS-TO-KEEP mask for Cause
###    mfc0    $k0, COP0_Cause
###    and     $k0, $k0, $k1
###    mtc0    $k0, COP0_Cause
# Each handler returns here to clear related Cause bit
done_cause:     # $k1 = BITS-TO-KEEP mask (e.g. IM_POSSIBLE & ~IM_UATX)
    mtc0    $k1, COP0_Cause
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
    la      $k1, SM_BASE
    lw      $k0, SMO_seconds($k1)
    nop
    addiu   $k0, $k0, 1
    sw      $k0, SMO_seconds($k1)

    lw      $t0, SMO_clock($k1)
    nop

    # IN : $t0 = 0x0000_d3d2d1d0   packed BCD
    # OUT: $t0 = that value + 1    (BCD)
    # TMP: $t1, $k0, $k1
    # (This BCD code is from GROK and slightly tweaked)
timer_bcd4_inc:
    andi    $t1, $t0, 0x000F        # ones
    addiu   $t1, $t1, 1
    sltiu   $k0, $t1, 10            # 1 => no carry
    bne     $k0, $zero, timer_bcd4_ones
    andi    $t0, $t0, 0xFFF0        #D; clear ones

    # ones was 9 -> 0, carry into tens
    srl     $t1, $t0, 4
    andi    $t1, $t1, 0x000F
    addiu   $t1, $t1, 1
    sltiu   $k0, $t1, 6             # Normally 10
    bne     $k0, $zero, timer_bcd4_tens
    andi    $t0, $t0, 0xFF0F        #D; clear tens

    # tens was 9 -> 0, carry into hundreds
    srl     $t1, $t0, 8
    andi    $t1, $t1, 0x000F
    addiu   $t1, $t1, 1
    sltiu   $k0, $t1, 10
    bne     $k0, $zero, timer_bcd4_hundreds
    andi    $t0, $t0, 0xF0FF        #D; clear hundreds

    # hundreds was 9 -> 0, carry into thousands
    srl     $t1, $t0, 12
    andi    $t1, $t1, 0x000F
    addiu   $t1, $t1, 1
    sltiu   $k0, $t1, 6             # Normally 10
    bne     $k0, $zero, timer_bcd4_thousands
    andi    $t0, $t0, 0x0FFF        #D; clear thousands

    # 9999 + 1 -> 0000
    b       timer_bcd4_done
    or      $t0, $zero, $zero       #D;

timer_bcd4_thousands:
    sll     $t1, $t1, 12
    b       timer_bcd4_done
    or      $t0, $t0, $t1           #D;

timer_bcd4_hundreds:
    sll     $t1, $t1, 8
    b       timer_bcd4_done
    or      $t0, $t0, $t1           #D;

timer_bcd4_tens:
    sll     $t1, $t1, 4
    b       timer_bcd4_done
    or      $t0, $t0, $t1           #D;

timer_bcd4_ones:
    or      $t0, $t0, $t1
timer_bcd4_done:

    la      $k1, SM_BASE
    sw      $t0, SMO_clock($k1)

    mfc0    $k0, COP0_Compare
    la      $k1, K_TIMER_CYC        #Is large value (can't use IMMEDIATE)
    addu    $k0, $k0, $k1
    mtc0    $k0, COP0_Compare
    j       done_cause
    ori     $k1, $zero, (IM_POSSIBLE & ~IM_TIMER)   # 0x7C00
###BUGGY, sets extra bits: addi    $k1, $zero, (~IM_TIMER & 0x0000FFFF)


# Triggered when cpu-clock counter rolls over from "-1":
ISR_RTC:
    la      $k1, SM_BASE
    lw      $k0, SMO_RTC_count($k1)
    nop                             #Avoid load-use hazard
    addiu   $k0, $k0, 1
    sw      $k0, SMO_RTC_count($k1)
    j       done_cause
    ori     $k1, $zero, (IM_POSSIBLE & ~IM_RTC)     # 0xBC00
###BUGGY, sets extra bits: addi    $k1, $zero, (~IM_RTC & 0x0000FFFF)

#END: ISR_RTC


# Triggered when UART Character has arrived and is readable:
ISR_UARX:
#TODO: Go ahead and utilize $t0 and $t1 for temporary storage...
    la      $k0, MMIO_BASE
    lw      $k1, OW_UARX_VALID($k0) #UART recv truly/still valid?
    nop                             #H; Hazard below since $k1 loaded above
    andi    $k1, $k1, MM_UART_RVA_BIT
    beq     $k1, $zero, _uarx_done  #Interrupt without char so just return
    nop                             #D;
    lbu     $k1, OB_UARX_DATA($k0)  #UART recv byte
    la      $t1, SM_BASE            #Set up register for SM access below

#"switch/case" checking for controlling characters:
    # General graphics/timer controlling characters:
    ori     $k0, $zero, ' '
    beq     $k0, $k1, _uarx_toggle_pause
    ori     $k0, $zero, 'd'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_disable_timer
    ori     $k0, $zero, 'e'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_enable_timer
    # Player movement: /uio/j_l/m,./ => 3 rows on keyboard
    ori     $k0, $zero, 'u'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_upleft
    ori     $k0, $zero, 'i'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_up
    ori     $k0, $zero, 'o'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_upright
    ori     $k0, $zero, 'j'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_left
    ori     $k0, $zero, 'k'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_done    # Not implemented "center" key
    ori     $k0, $zero, 'l'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_right
    ori     $k0, $zero, 'm'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_downleft
    ori     $k0, $zero, ','         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_down
    ori     $k0, $zero, '.'         #D; Harmless if branch taken
    beq     $k0, $k1, _uarx_player_downright
    nop                             #D;
    # End of "keyboard" controls.
    b       _uarx_done              #H: ???
    nop                             #D;

_uarx_toggle_pause:
    lh      $k1, SMO_flags($t1)
    nop                             #H; Hazard below since $k1 loaded above
    xori    $k1, $k1, SMM_flags_pause
    b       _uarx_done
    sh      $k1, SMO_flags($t1)

_uarx_disable_timer:
    lh      $k1, SMO_flags($t1)
    nop                             #H; Hazard below since $k1 loaded above
    ori     $k1, $k1, SMM_flags_notimer
    b       _uarx_done
    sh      $k1, SMO_flags($t1)      #D;

_uarx_enable_timer:
    lh      $k1, SMO_flags($t1)
    nop                             #H; Hazard below since $k1 loaded above
    andi    $k1, $k1, SMI_flags_notimer
    b       _uarx_done
    sh      $k1, SMO_flags($t1)

_uarx_player_upleft:
    addiu   $k1, $zero, -4          # Delta-Y for "upleft" movement
    b       _uarx_player_move
    addiu   $k0, $zero, -4          #D; Delta-X for "upleft" movement

_uarx_player_up:
    addiu   $k1, $zero, -6
    b       _uarx_player_move
    addiu   $k0, $zero, 0           #D;

_uarx_player_upright:
    addiu   $k1, $zero, -4
    b       _uarx_player_move
    addiu   $k0, $zero, 4           #D;

_uarx_player_left:
    addiu   $k1, $zero, 0
    b       _uarx_player_move
    addiu   $k0, $zero, -6          #D;

_uarx_player_right:
    addiu   $k1, $zero, 0
    b       _uarx_player_move
    addiu   $k0, $zero, 6           #D;

_uarx_player_downleft:
    addiu   $k1, $zero, 4           # Delta-Y for "downleft" movement
    b       _uarx_player_move
    addiu   $k0, $zero, -4          #D; Delta-X

_uarx_player_down:
    addiu   $k1, $zero, 6
    b       _uarx_player_move
    addiu   $k0, $zero, 0           #D;

_uarx_player_downright:
    addiu   $k1, $zero, 4
#    b       _uarx_player_move
    addiu   $k0, $zero, 4           #D;
#    Fall through to _uarx_player_move

_uarx_player_move:      # Pass delta-X & delta-Y in $k0 & $K1 respectively
    lh      $t0, SMO_player_x($t1)  # Player x & y are signed 16-bit int
    nop                             #H; Hazard below since $t0 loaded above
    addu    $t0, $t0, $k0
    sh      $t0, SMO_player_x($t1)
    #nop                             #H; Not a hazard
    lh      $t0, SMO_player_y($t1)
    nop                             #H; Hazard below since $t0 loaded above
    addu    $t0, $t0, $k1
    sh      $t0, SMO_player_y($t1)
#    Fall through to _uarx_done
#    b       _uarx_done
#    nop

_uarx_done:
    b       done_cause
    ori     $k1, $zero, (IM_POSSIBLE & ~IM_UARX)    # 0xF800
###BUGGY: Sets extra bits: addiu   $k1, $zero, (~IM_UARX & 0x0000FFFF)

#END: ISR_UARX


# Triggered when UART Transmit transitions from busy to available:
ISR_UATX:
    la      $k1, SM_BASE
### If head == tail then buffer is empty
    lw      $t0, SMO_buff_head($k1)
    lw      $t1, SMO_buff_tail($k1)
    nop     #Delay Slot: Avoid hazard with $t1 fetch
    beq     $t0, $t1, _uatx_done        # Empty buffer
    nop

    la      $k1, SM_BASE #REDUNDANT
    lw      $t1, SMO_buff_tail($k1) #REDUNDANT
    nop     #Delay Slot if $t1 used next #REDUNDANT
    addu    $k0, $k1, $t1               # Pre-index from base...
    lbu     $k0, SMO_buff_data($k0)     # ...then furthur offset.
    nop     #Delay Slot: Ensure value is available in $k0
    #Unnecessary: andi    $k0, $k0, 0x00FF

### Consider sanity check regarding OW_UATX_READY(MMIO_BASE)???
    la      $k1, SM_BASE #REDUNDANT
    lw      $t1, SMO_buff_tail($k1) #REDUNDANT
    addi    $t0, $t1, 1                 # Advance to next char
    andi    $t0, $t0, K_SHBUF_ROLLOVERB
    sw      $t0, SMO_buff_tail($k1)     # Store new offset
    la      $k1, MMIO_BASE              # Memory mapped XMIT char
    sw      $k0, OW_UATX_DATA($k1)      # Send character
#    j       _uatx_done
#    nop
# ...FALLTHROUGH...
# ISR return here (restore stashed vals & reset cause)...
_uatx_done:
    j       done_cause
    ori     $k1, $zero, (IM_POSSIBLE & ~IM_UATX)    # 0xF400
###BUGGY: Sets extra bits: addi    $k1, $zero, (~IM_UATX & 0x0000FFFF)

#END: ISR_UATX


# Various utility functions reachable by "vector" jump-table above
DO_ENABLE:
    ori     $k1, $zero, (IM_UARX | IM_GLOBAL)
    jr      $ra
    mtc0    $k1, COP0_Status

DO_DISABLE:
    jr      $ra
    mtc0    $zero, COP0_Status
