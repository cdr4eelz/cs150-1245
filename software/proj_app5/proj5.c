#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "graphics.h"

#include "shared.h"

#ifdef VIZARD
#include "vizard_host.h"
#endif

int8_t tbuff[TBUF_SIZE]; // Can be confusing as to where this gets located

void frame_gp_generate(uint32_t frame) {
    gpcode_p pINST;
    const gpcode_p pSEQUENCE = GPTEMP_BIG; //TEMP: Calculate based on frame

    pINST = pSEQUENCE;
    pINST = hwq_fill(pINST, 0x00002233u);
    pINST = hwq_line(pINST, 0x00FFFFFFu,  10, 10,  700,300);
    pINST = hwq_line(pINST, 0x00FFFFFFu, 400, 10,   10,500);
    pINST = hwq_pixl(pINST, 0x00FFFFFFu,  20,250);
    pINST = hwq_rect(pINST, 0x00FFFFFFu, 550,150,  750,250,  0xFFF0F020u);

    for (int i = 0; i < 10; i++) {
        uint16_t xc = 100 + (i * 20);
        uint16_t yc = 300 - (i * 25);
        uint16_t r = 10 + (i * 6);
        pINST = hwq_elip(pINST, 0x00FF0000u, xc, yc, r, r, 0xFF1A7F0Fu);
    }

    pINST = hwq_stop(pINST);
    GP_WAIT();
}

void frame_gp_render(uint32_t frame) {
    GP_FRAME = frame;
    GP_GCODE = GPTEMP_BIG;
}


void main() {
    struct SM_DATA* share = SM_BASE;
    uint32_t tClock, prevClock;

    //TODO: Clear "Cause" register???
    //TODO: Should macro mask "Cause" based on enabled "Status" bits???
    //TODO: Should "Cause" bits be cleared while "Status" is enabled???
    ISR_STATUS(0x00000000, 0x00000000); // Disable ALL interrupts & global

    // Initialize the shared memory block (shared with ISR handler)
    SM_INIT(share);
    
    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);
    uwait_ISR(); // Get off to a clean start with nobody sending yet

    uwrite_int8s_ISR("\r\n\r\nPROJ-4:\r\n");
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
            if (1) uwrite_clock(tClock);
            prevClock = tClock; // Advance whether or not printing enabled
        }

        // Temporarily utilize just one frame
        frame_gp_generate(1);
        frame_gp_render(1);
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
