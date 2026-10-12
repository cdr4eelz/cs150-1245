#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "graphics.h"

#include "shared6.h"

#ifdef VIZARD
#include "vizard_host.h"
#endif

int8_t tbuff[TBUF_SIZE]; // Can be confusing as to where this gets located

void frame_gp_generate(uint32_t frame, uint32_t frameCounter) {
    gpcode_p pINST;
    const gpcode_p pSEQUENCE = (gpcode_p)FRAME_EXTRA_TAIL(frame);

    pINST = pSEQUENCE;
    // Background clear to near black
    pINST = hwq_fill(pINST, 0x00002233u);
    // Draw the border rectangles 10-pixel thick around the edges of the screen
    pINST = hwq_rect(pINST, 0x00114488u,   0,  0,  799, 10, 0xFF114488u);
    pINST = hwq_rect(pINST, 0x00114488u,   0,  0,   10,599, 0xFF114488u);
    pINST = hwq_rect(pINST, 0x00114488u, 789,  0,  799,599, 0xFF114488u);
    pINST = hwq_rect(pINST, 0x00114488u,   0,589,  799,599, 0xFF114488u);

    // Use for "sweeping" dots & lines
    const int x_something_r = 1024 - (((frameCounter*8) % 1024) - ((1024-800)/2));
    const int x_something_f = ((frameCounter*8) % 1024) - ((1024-800)/2);

    //uwrite_int8s_ISR(uint32_to_ascii_hex(x_something, tbuff, TBUF_SIZE));
    //uint32_to_ascii_hex(x_something, tbuff, TBUF_SIZE);
    // This prints a dot to the ISR to prevent lockup
    uwrite_int8s_ISR(".");

    // Loop through the "sweeping" x positions and draw lines and dots
    for (int x = x_something_f; x <= x_something_f + 24; x += 4) { //+=4
        if ((x >= 0) && (x < 800)) {
            pINST = hwq_line(pINST, 0x00FF3018u, x,250, x,350);
            for (int y = (frameCounter % 16); y < 600; y += 16) { //+=16 freezes +=24 freezes later
                pINST = hwq_pixl(pINST, 0x00FFFFFFu, x, y);
                //pINST = hwq_line(pINST, 0x00FFFFFFu, 10,9, x,y);
            }
        }
    }

    // Draw concentric ellipses that look vaguely like a "globe"
    pINST = hwq_elip(pINST, 0x0000FF00u, 400, 300, 100, 299, 0x00000000);
    pINST = hwq_elip(pINST, 0x0000FF00u, 400, 300, 250, 299, 0x00000000);
    pINST = hwq_elip(pINST, 0x0000FF00u, 400, 300, 398, 299, 0x00000000);

    //TODO: Add main "character" that moves based on keyboard
    
    //TODO: Add "bouncers" that can be added & removed dynamically

    // End of frame sequence
    pINST = hwq_stop(pINST);
    //GP_WAIT();
}

void frame_gp_render(uint32_t frame) {
    GP_WAIT(); //Just in case, harmless if not needed
    GP_FRAME = FRAME_PTR(frame);
    GP_GCODE = (gpcode_p)FRAME_EXTRA_TAIL(frame);
    GP_WAIT(); //TODO: Consider 3-frame flipping and performing CPU actions rather than waiting here
    PF_WAIT(frame); //WAS: PF_FRAME = frame;
}


void main_imem( void ) {
    struct SM_DATA* share = SM_BASE;
    uint32_t tClock, prevClock;
    uint32_t frameCounter = 0;

    //TODO: Clear "Cause" register???
    //TODO: Should macro mask "Cause" based on enabled "Status" bits???
    //TODO: Should "Cause" bits be cleared while "Status" is enabled???
    ISR_STATUS(0x00000000, 0x00000000); // Disable ALL interrupts & global

    // Initialize the shared memory block (shared with ISR handler)
    SM_INIT6(share);
    
    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);
    uwait_ISR(); // Get off to a clean start with nobody sending yet

    uwrite_int8s_ISR("\r\n\r\nPROJ-6.01:\r\n");
    uwrite_int8s_ISR("MAGIC: ");
    uwrite_int8s_ISR(uint32_to_ascii_hex(share->magic, tbuff, TBUF_SIZE));
    uwrite_int8s_ISR("\n\r");
    uwait_ISR();

    ISR_COMPARE(K_TIMER_CYC); // This implicitly resets "Count" to zero
    //NOTE: We set "Compare" here on init, but after that the ISR handles it

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX | IM_UARX | IM_RTC | IM_TIMER); //GPU?
    
    tClock = prevClock = 0;
    while (ISR_POLL(share)) {
        tClock = share->clock;
        if (tClock != prevClock) {
            //TODO: Conditional based on a flag
            if (!(share->flags & SMM_flags_notimer)) uwrite_clock_ISR(tClock);
            prevClock = tClock; // Advance whether or not printing enabled
        }

        if (share->flags & SMM_flags_pause) continue;
        // Skip frame if paused...
        frame_gp_generate((frameCounter % 2) + 1, frameCounter);
        frame_gp_render((frameCounter % 2) + 1);
        frameCounter++;
    }

    uwait_ISR();
    ISR_STATUS(0x00000000, 0x00000000);
}

/* Resulting output..
> jal 60000000
...
...
[screen is terminating]
*/
