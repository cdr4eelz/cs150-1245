#include "uart.h"
#include "shared7.h"

// These nifty offset checks came from an AI recommendation...
#define SM_CHECK_OFFSET(member, expected) \
    typedef char sm_offset_check_##member[ \
        (__builtin_offsetof(struct SM_DATA, member) == (expected)) ? 1 : -1]
SM_CHECK_OFFSET(magic, SMO_magic);
SM_CHECK_OFFSET(stash0, SMO_stash0);
SM_CHECK_OFFSET(stash1, SMO_stash1);
SM_CHECK_OFFSET(stash2, SMO_stash2);
SM_CHECK_OFFSET(stash3, SMO_stash3);
SM_CHECK_OFFSET(flags, SMO_flags);
SM_CHECK_OFFSET(RTC_count, SMO_RTC_count);
SM_CHECK_OFFSET(seconds, SMO_seconds);
SM_CHECK_OFFSET(clock, SMO_clock);
SM_CHECK_OFFSET(player_y, SMO_player_y);
SM_CHECK_OFFSET(player_x, SMO_player_x);
SM_CHECK_OFFSET(buff_size, SMO_buff_size);
SM_CHECK_OFFSET(buff_head, SMO_buff_head);
SM_CHECK_OFFSET(buff_tail, SMO_buff_tail);
SM_CHECK_OFFSET(buff_data, SMO_buff_data);
typedef char sm_size_check[(sizeof(struct SM_DATA) == SMO_buff_data + K_SHBUF_SIZEB) ? 1 : -1];

void SM_INIT7(struct SM_DATA *sm)
{
    //TODO: Call entry point in ISR code to initialize "magic" field,
    //      then CONFIRM that it matches the expected magic value.
    //      This would also implicitly confirms the address of the
    //      shared memory structure.
    sm->magic = K_MAGIC_VERSION;
    sm->stash0 = -1u;
    sm->stash1 = -1u;
    sm->stash2 = -1u;
    sm->stash3 = -1u;
    sm->flags = 0x00000000;
        // "pause" default is zero... so not paused
        // "notimer" default is zero... so timer shown
    sm->seconds = 0;
    sm->clock = 0;
    sm->player_y = 300;
    sm->player_x = 400;
    sm->buff_size = K_SHBUF_SIZEB;
    sm->buff_head = 0;
    sm->buff_tail = 0;
}


//TODO: Rewrite this to properly handle critical sections or RACE conditions
//        between this function and the associated ISR actions.
//      Right now, it makes simplifications under assumption that corrupt output
//        is acceptable and will be extremely rare or not occur in the specific
//        use case.
void uwrite_int8s_ISR(int8_t* src) { //Should use MAX/TIMEOUT???
    struct SM_DATA* share = SM_BASE; //Should pass as argument???
    int8_t ch;

    while (ch = *src++) { // Repeat while not NULL
        if (UTRAN_CTRL) { // We can send directly, BUT...
            //...THIS IS A BIG SIMPLIFICATION...
            //  We assume that, with interrupts enabled, the ISR will
            //  get first (IMMEDIATE) opportunity to send out of the
            //  ring buffer when UART trans is ready and, therefore,
            //  if we catch the UART ready, we just ASSUME that the
            //  ring buffer must be empty (likely but not guaranteed)
            //  Strictly speaking, this send here could jump in front
            //  of any pending characters in the ring buffer.
            //  There is a subtle advantage that sending direct to
            //  UART here ensures that a subsequent interrupt will
            //  happen once the single char send is complete... which
            //  potentially gets things moving again if such an interrupt
            //  were ever missed and the buffer is not emptied properly.
            //  This is very sloppy!
            //  (See below for related comment about missed interrupt)
            UTRAN_DATA = ch; // Simple send direct to UART
        } else { // Utilize ring-buffer
            //NOTE: Since only the app writes to the buffer, manipulating
            //        "buff_head", and only the ISR reads/sends from the
            //        buffer, manipulating "buff_tail", 
            uint32_t head = share->buff_head;
            uint32_t nextHead = (head + 1) & K_SHBUF_ROLLOVERB;
            uint32_t cntr = 0;
            while (nextHead == share->buff_tail) { //Buffer is full
                //TODO: Check if interrupts are even enabled here!!!
                if ((cntr++) > DBG_UWAIT_MAX) {
                    //NOTE: In the future, if there were UART handshaking or
                    //        backpressure, then the wait for the buffer to
                    //        advance could be appropriately long and overrun
                    //        our max wait here.
                    //TODO: Drop a breadcrum or immediate "exception" into BIOS
                    continue; //WAS: return;
                }
            }
            // Reaching here should mean there is at least one free slot and
            //   it is right WHERE we expect it. Should be true.
            share->buff_data[head] = ch; // Be sure to write the character itself
            share->buff_head = nextHead; //   BEFORE advancing the head pointer.
            //NOTE: Possibly, we could reach here, having appended to the buffer
            //      yet there is NOT an impending interrupt to handle it, for
            //      example, if a char is not actively being sent.
            //      I havn't analyzed fully but it seems possible.
            //      (See above comment about how we implicitly restart this)
        }
    }
    // Should there be a return a value (indicating success vs. timeout)?
}

// FULLY drain the ring-buffer and ensure UART ready flag active:
void uwait_ISR(void) { //NOTE: Should probably mention "flush" or "drain" in name???
    struct SM_DATA* share = SM_BASE; //Should pass as argument???

    // Wait until interrupt based sending is done, BUT...
    //TODO: Should only check buffer IIF UATX interrupt on???
    uint32_t cntr = 0;
    while ((share->buff_tail != share->buff_head)
             || (!UTRAN_CTRL)) {
        if ((cntr++) > DBG_UWAIT_MAX) {
            //TODO: Drop a breadcrum or immediate "exception" into BIOS
            // See above note in "uwrite_int8s_ISR" about future handshaking.
            return;
        }
    } //Wait on prior sends and basically guarantee that a new send can proceed immediately
}

/*  UNNEEDED FUNCTION? Certainly should be optional or inline/macro if defined
//TODO: Put in simple string library (perhaps as INLINE)
int8_t* copy_string(int8_t* dst, int8_t* src, uint16_t maxLen) { //Add size check
    int8_t* base = dst;
    while ((*dst++ = *src++) && (maxLen--)) { }
    if (!maxLen) *dst = 0; // Null-terminate if max length reached
    return base;
}
*/

void uwrite_clock_ISR(uint32_t clk_bcd) {
    uwrite_int8s_ISR("\n\rCLK: ");
    // Assemble clock string "mm:ss" in tbuff
    tbuff[0] = '0' + ((clk_bcd >> 12) & 0x0F);
    tbuff[1] = '0' + ((clk_bcd >>  8) & 0x0F);
    tbuff[2] = ':';
    tbuff[3] = '0' + ((clk_bcd >>  4) & 0x0F);
    tbuff[4] = '0' + ((clk_bcd >>  0) & 0x0F);
    tbuff[5] = 0;
    uwrite_int8s_ISR(tbuff);
    uwrite_int8s_ISR("\n\r");
}
