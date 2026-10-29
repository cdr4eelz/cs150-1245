#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "graphics.h"

#include "shared7.h"

int8_t tbuff[TBUF_SIZE]; // Can be confusing as to where this gets located!


gpcode_p generate_sweeper(gpcode_p pINST, uint32_t frameCounter) {
    uint32_t sweepBase = 0; //TODO: Lock in at start of sweep
    if (1) { //(sweepForward || sweepReverse) {
        const uint32_t sweepFrame = (frameCounter >= sweepBase) ? frameCounter - sweepBase : 0;
        // Forward vs reverse x coordinates:
    //const int32_t x_something_f = ((sweepFrame*8) % 1024) - ((1024-800)/2);
        const int32_t x_something_f = (int32_t)((sweepFrame << 3) & 0x03FFu) - 112;
        const int32_t x_something_r = 1024 - x_something_f;

        // Loop through the "sweeping" x positions and draw lines and dots
        for (int32_t x = x_something_f; x <= x_something_f + 24; x += 4) { //+=4
            if ((x >= 0) && (x < 800)) { //If line/dots are on screen
                pINST = hwq_line(pINST, 0x00FF3018u, x,250, x,350);
                for (int32_t y = (sweepFrame % 16); y < 600; y += 16) { //+=16 freezes +=24 freezes later
                    if (0) { //sweepLines) {
                        pINST = hwq_line(pINST, 0x00FFFFFFu, 10,9, x,y);
                    } else {
                        pINST = hwq_pixl(pINST, 0x00FFFFFFu, x, y);
                    }
                }
            }
        }
        if (FALSE) { //End of range
            //sweepReverse = sweepForward;
            //sweepForward = FALSE;
        }
    }
    return pINST;
}

gpcode_p generate_borders(gpcode_p pINST) {
    // Draw the border rectangles 10-pixel thick around the edges of the screen
    pINST = hwq_rect(pINST, 0x00114488u,   0,  0,  799, 10, 0xFF114488u);
    pINST = hwq_rect(pINST, 0x00114488u,   0,  0,   10,599, 0xFF114488u);
    pINST = hwq_rect(pINST, 0x00114488u, 789,  0,  799,599, 0xFF114488u);
    pINST = hwq_rect(pINST, 0x00114488u,   0,589,  799,599, 0xFF114488u);
    return pINST;
}

gpcode_p generate_globe(gpcode_p pINST) {
    // Draw concentric ellipses that look vaguely like a "globe"
    pINST = hwq_elip(pINST, 0x0000FF00u, 400, 300, 100, 299, 0x00000000u);
    pINST = hwq_elip(pINST, 0x0000FF00u, 400, 300, 250, 299, 0x00000000u);
    pINST = hwq_elip(pINST, 0x0000FF00u, 400, 300, 398, 299, 0x00000000u);
    return pINST;
}

gpcode_p generate_bouncers(gpcode_p pINST) {
    return pINST;
}

gpcode_p generate_player(gpcode_p pINST, uint16_t x, uint16_t y) {
    pINST = hwq_elip(pINST, 0x00FF6644u, x,y, 5,7, 0xFF4466FFu);
    return pINST;
}

BOOL point_is_on_screen(int16_t x, int16_t y, int16_t border) {
    return (x >= border && x < (800 - border) && y >= border && y < (600 - border));
}

gpcode_p frame_gp_generate(uint32_t frame, uint32_t frameCounter) {
    struct SM_DATA* share = SM_BASE;
    const gpcode_p pSEQUENCE = (gpcode_p)FRAME_EXTRA_TAIL(frame);
    gpcode_p pINST = pSEQUENCE; // Start fresh graphics ops in this frame's tail

    pINST = hwq_fill(pINST, 0x00002233u); // Background clear to near black
    pINST = generate_borders(pINST);
    pINST = generate_globe(pINST);
    pINST = generate_bouncers(pINST);
    if (point_is_on_screen(share->player_x, share->player_y, 0)) {
        pINST = generate_player(pINST, (uint16_t)share->player_x, (uint16_t)share->player_y);
    }
    pINST = generate_sweeper(pINST, frameCounter);
    pINST = hwq_stop(pINST); // End of frame sequence
    return pSEQUENCE;
}

uint32_t frame_start_render(uint32_t frame, gpcode_p pSEQUENCE) {
    uint32_t startTime;
    GP_WAIT(); //Just in case, harmless if not needed
    GP_FRAME = FRAME_PTR(frame);
    startTime = 0; //TODO: Capture timestamp to measure duration of GPU rendering???
    GP_GCODE = pSEQUENCE; // Launch render (asynchronous with CPU)
    return startTime;
}


void main_imem(void) {
    struct SM_DATA* share = SM_BASE;
    uint32_t tClock, prevClock;
    uint32_t frameCounter = 0;
    gpcode_p pSEQUENCE = NULL;

    //TODO: Clear "Cause" register???
    //TODO: Should macro mask "Cause" based on enabled "Status" bits???
    //TODO: Should "Cause" bits be cleared while "Status" is enabled???
    ISR_STATUS(0x00000000, 0x00000000); // Disable ALL interrupts & global

    // Initialize the shared memory block (shared with ISR handler)
    SM_INIT7(share);
    
    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);
    uwait_ISR(); // Get off to a clean start with nobody sending yet

    uwrite_int8s_ISR("\r\n\r\nPROJ-6.8:\r\n");
    uwrite_int8s_ISR("MAGIC: ");
    uwrite_int8s_ISR(uint32_to_ascii_hex(share->magic, tbuff, TBUF_SIZE));
    uwrite_int8s_ISR("\n\r");
    uwait_ISR();

    ISR_COMPARE(K_TIMER_CYC); // This implicitly resets "Count" to zero
    //NOTE: We set "Compare" here on init, but after that the ISR handles it

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX | IM_UARX | IM_RTC | IM_TIMER); //GPU?

    // This allows us to "render" these tail sequences safely before their real content is generated
    pSEQUENCE = (gpcode_p)FRAME_EXTRA_TAIL(1);
    hwq_stop(pSEQUENCE);
    pSEQUENCE = (gpcode_p)FRAME_EXTRA_TAIL(2);
    hwq_stop(pSEQUENCE);

    tClock = prevClock = 0;
    while (ISR_POLL(share)) {
        tClock = share->clock;
        if (tClock != prevClock) {
            if (!(share->flags & SMM_flags_notimer)) uwrite_clock_ISR(tClock);
            prevClock = tClock; // Advance whether or not printing enabled
        }

        if (!(share->flags & SMM_flags_pause)) {
            uint32_t thisFrame = ((frameCounter & 0x01)       ) + 1;
            uint32_t nextFrame = ((frameCounter & 0x01) ^ 0x01) + 1;
            //TODO: Render and Generate simultaneously (overlap)
            //TODO: Add frame_prep which moves objects and such (prior to generate)
            //TODO: Change % 2 to a mask of first bit
            frame_start_render(nextFrame, pSEQUENCE); // Draw asynchronously to inactive frame
            pSEQUENCE = frame_gp_generate(thisFrame, frameCounter);
            GP_WAIT(); // Wait until GPU/GP render operations completed
            PF_WAIT(nextFrame); // Swap frame and wait until it is live
            frameCounter++;
        }

        //TODO: Count up frames and compute FPS or other performance metrics
    }

    uwait_ISR();
    ISR_STATUS(0x00000000, 0x00000000);
}

//TODO: Update this output to reflect the recent results of the program!
/* Resulting output..
> jal 60000000
...
...
[screen is terminating]
*/
