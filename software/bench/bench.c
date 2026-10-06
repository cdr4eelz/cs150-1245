#include "types.h"
#include "graphics.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "benchmark.h"

//typedef void (*entry_t)(void);

#define TIMER_REPS  (0x10u)    // Use power of 2, actually power of 16 for easy rounding

uint32_t sw_draw(void) {
    for (int i = 0; i < TIMER_REPS; i++) {
        gframe_pv sw_frame = FRAME_PTR(1);
        swfill(sw_frame, 0x00002233u);
        swline(sw_frame, 0x00FFFFFFu,  10, 10,  700,300);
        swline(sw_frame, 0x00FFFFFFu, 400, 10,   10,500);
        swpixl(sw_frame, 0x00FFFFFFu,  20,250);
        swelip(sw_frame, 0x00FF0000u, 100,100,   20, 30,    0xFF1A7F0Fu);
        swrect(sw_frame, 0x00FFFFFFu, 550,150,  750,250,    0xFFF0F020u);
        swcirc(sw_frame, 0x0000FF00u, 650,200,   50,        0xFF0000FFu);
        swcirc(sw_frame, 0x00222222u, 650,200,   40,        0x00000000u);
        swcirc(sw_frame, 0x00444444u, 650,200,   30,        0x00000000u);
        swcirc(sw_frame, 0x00AAAAAAu, 650,200,   20,        0xFF000000u);
        swcirc(sw_frame, 0x00DDDDDDu, 650,200,   10,        0x00000000u);
        swrect(sw_frame, 0x003FFF2Fu, 550,515,  310,333,    0xFFF300F2u);

        sw_frame = FRAME_PTR(4);
        swfill(sw_frame, 0x00FF2222u);
        swline(sw_frame, 0x0000FF00u,  10, 10,  700,300);
        swline(sw_frame, 0x000000FFu, 500,250,  200, 90);
        swline(sw_frame, 0x00000000u,  10,300,  400,500);
        swrect(sw_frame, 0x00FFFFFFu, 600,400,  799,599,    0xFF000000u);
        swrect(sw_frame, 0x000000FFu, 700,500,  799,599,    0xFF2F7FFFu);
        swrect(sw_frame, 0x0000FF00u, 650,450,  699,499,    0xFF2FFF2Fu);
        swrect(sw_frame, 0x00FF0000u, 625,425,  649,449,    0xFFFF2F2Fu);
        swelip(sw_frame, 0x00222222u, 200,300,   20, 20,    0x00000000u);
        swelip(sw_frame, 0x00008844u, 600,300,  100, 50,    0xFF7FFF1Fu);
        swpixl(sw_frame, 0x00023666u,  21, 51);
        swcirc(sw_frame, 0x00222222u, 650,200,   50,        0x00000000u);
    }
    return 0;
}

uint32_t hw_draw_per_shape(void) {
    for (int i = 0; i < TIMER_REPS; i++) {
        GP_FRAME = FRAME_PTR(2);
        hwfill(0x00002233u);
        hwline(0x00FFFFFFu,  10, 10,  700,300);
        hwline(0x00FFFFFFu, 400, 10,   10,500);
        hwpixl(0x00FFFFFFu,  20,250);
        hwelip(0x00FF0000u, 100,100,   20, 30,  0xFF1A7F0Fu);
        hwrect(0x00FFFFFFu, 550,150,  750,250,  0xFFF0F020u);
        hwcirc(0x0000FF00u, 650,200,   50,      0xFF0000FFu);
        hwcirc(0x00222222u, 650,200,   40,      0x00000000u);
        hwcirc(0x00444444u, 650,200,   30,      0x00000000u);
        hwcirc(0x00AAAAAAu, 650,200,   20,      0xFF000000u);
        hwcirc(0x00DDDDDDu, 650,200,   10,      0x00000000u);
        hwrect(0x003FFF2Fu, 550,515,  310,333,  0xFFF300F2u);

        GP_FRAME = FRAME_PTR(5);
        hwfill(0x00FF2222u);
        hwline(0x0000FF00u,  10, 10,  700,300);
        hwline(0x000000FFu, 500,250,  200, 90);
        hwline(0x00000000u,  10,300,  400,500);
        hwrect(0x00FFFFFFu, 600,400,  799,599,  0xFF000000u);
        hwrect(0x000000FFu, 700,500,  799,599,  0xFF2F7FFFu);
        hwrect(0x0000FF00u, 650,450,  699,499,  0xFF2FFF2Fu);
        hwrect(0x00FF0000u, 625,425,  649,449,  0xFFFF2F2Fu);
        hwelip(0x00222222u, 200,300,   20, 20,  0x00000000u);
        hwelip(0x00008844u, 600,300,  100, 50,  0xFF7FFF1Fu);
        hwpixl(0x00023666u,  21, 51);
        hwcirc(0x00222222u, 650,200,   50,      0x00000000u);
    }
    return 0;
}

uint32_t hw_draw_per_frame(void) {
    uint32_t total_wait = 0;
    uint32_t inst_count;
    gpcode_p pINST;
    const gpcode_p pSEQUENCE = GPTEMP_BIG; //A large chunk of memory
//GPTEMP_BIG  GPTEMP_PTR

    //We add up total waiting instructions when SW could do other stuff...
    for (int i = 0; i < TIMER_REPS; i++) {
        GP_FRAME = FRAME_PTR(3);
        pINST = pSEQUENCE;       //Point at sequence buffer
        pINST = hwq_fill(pINST, 0x00002233u);
        pINST = hwq_line(pINST, 0x00FFFFFFu,  10, 10,  700,300);
        pINST = hwq_line(pINST, 0x00FFFFFFu, 400, 10,   10,500);
        pINST = hwq_pixl(pINST, 0x00FFFFFFu,  20,250);
        pINST = hwq_elip(pINST, 0x00FF0000u, 100,100,   20, 30,  0xFF1A7F0Fu);
        pINST = hwq_rect(pINST, 0x00FFFFFFu, 550,150,  750,250,  0xFFF0F020u);
        pINST = hwq_circ(pINST, 0x0000FF00u, 650,200,   50,      0xFF0000FFu);
        pINST = hwq_circ(pINST, 0x00222222u, 650,200,   40,      0x00000000u);
        pINST = hwq_circ(pINST, 0x00444444u, 650,200,   30,      0x00000000u);
        pINST = hwq_circ(pINST, 0x00AAAAAAu, 650,200,   20,      0xFF000000u);
        pINST = hwq_circ(pINST, 0x00DDDDDDu, 650,200,   10,      0x00000000u);
        pINST = hwq_rect(pINST, 0x003FFF2Fu, 550,515,  310,333,  0xFFF300F2u);
        pINST = hwq_stop(pINST);
        GP_GCODE = pSEQUENCE;    //Triggers GPU drawing
        inst_count = INSTRUCTION_COUNTER;
        GP_WAIT();  //Wait for all GPU OPs to complete
        total_wait += (INSTRUCTION_COUNTER - inst_count);

        GP_FRAME = FRAME_PTR(6);
        pINST = pSEQUENCE;       //Start fresh sequence reusing buffer
        pINST = hwq_fill(pINST, 0x00FF2222u);
        pINST = hwq_line(pINST, 0x0000FF00u,  10, 10,  700,300);
        pINST = hwq_line(pINST, 0x000000FFu, 500,250,  200, 90);
        pINST = hwq_line(pINST, 0x00000000u,  10,300,  400,500);
        pINST = hwq_rect(pINST, 0x00FFFFFFu, 600,400,  799,599,  0xFF000000u);
        pINST = hwq_rect(pINST, 0x000000FFu, 700,500,  799,599,  0xFF2F7FFFu);
        pINST = hwq_rect(pINST, 0x0000FF00u, 650,450,  699,499,  0xFF2FFF2Fu);
        pINST = hwq_rect(pINST, 0x00FF0000u, 625,425,  649,449,  0xFFFF2F2Fu);
        pINST = hwq_elip(pINST, 0x00222222u, 200,300,   20, 20,  0x00000000u);
        pINST = hwq_elip(pINST, 0x00008844u, 600,300,  100, 50,  0xFF7FFF1Fu);
        pINST = hwq_pixl(pINST, 0x00023666u,  21, 51);
        pINST = hwq_circ(pINST, 0x00222222u, 650,200,   50,      0x00000000u);
        pINST = hwq_stop(pINST);
        GP_GCODE = pSEQUENCE;
        inst_count = INSTRUCTION_COUNTER;
        GP_WAIT();
        total_wait += (INSTRUCTION_COUNTER - inst_count);
    }
    return total_wait;
}

void main()
{
    ISR_STATUS(0,0); // Disable all interrupts

    PF_FRAME = STD_FRAME1;
    run_and_time(&sw_draw);
    run_and_time(&hw_draw_per_shape);
    run_and_time(&hw_draw_per_frame);

    // Let "start.s" code re-launch BIOS
}
