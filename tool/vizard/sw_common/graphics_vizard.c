#include "graphics.h"
#include "vizard_host.h"

gpcode_t vizard_gptemp[GPTEMP_SZW + VIZARD_GPU_COMMAND_CAPACITY];
uint32_t vizard_frame_extra[VIZARD_EXTRA_FRAME_COUNT][FRAME_XTRAP]
    __attribute__((aligned(FRAME_ALIGN_BYTES)));

void pf_wait(uint32_t frame)
{
    vizard_host_wait_pf_frame((uint32_t)(unsigned long)FRAME_PTR(frame));
}

gpcode_p hw_OpRGB_PP_S(
    gpcode_p bINST,
    const cmd_orgb28_t orgb28,
    const cmd_pnt_t p0,
    const cmd_pnt_t p1,
    const cmd_xrgb32_t xrgb32
)
{
    if (!bINST) {
        GP_WAIT();
    }

    gpcode_p pINST = bINST ? bINST : GPTEMP_PTR;
    (*pINST++).u32 = CMD32_orgb28(orgb28.gop, orgb28.xrgb28);
    if (p0.flags1 != null_pnt.flags1) {
        (*pINST++).u32 = CMD32_pnt(p0.x, p0.y);
    }
    if (p1.flags1 != null_pnt.flags1) {
        (*pINST++).u32 = CMD32_pnt(p1.x, p1.y);
    }
    if (xrgb32.xrgb32 != null_xrgb32.xrgb32) {
        (*pINST++).fXRGB32 = xrgb32;
    }
    if (!bINST) {
        (*pINST++).fORGB28 = CMD_STOP();
        vizard_host_gpu_submit((const unsigned int *)GPTEMP_PTR,
                               (size_t)(pINST - GPTEMP_PTR),
                               (unsigned int)(unsigned long)GP_FRAME);
    }
    return pINST;
}

const cmd_pnt_t null_pnt = { .flags1 = 0x3F };
const cmd_xrgb32_t null_xrgb32 = { .xrgb32 = 0xF101234A };

static gframe_pv select_vizard_frame(gframe_pv frame)
{
    gframe_pv previous = (gframe_pv)GP_FRAME;
    GP_FRAME = (void *)frame;
    return previous;
}

static void restore_vizard_frame(gframe_pv frame)
{
    GP_FRAME = (void *)frame;
}

void swslr(gframe_pv frame, color_t color_edge,
           uint16_t Y, uint16_t L, uint16_t R, color_t color_fill)
{
    gframe_pv previous = select_vizard_frame(frame);
    hwrect(color_edge, L, Y, R, Y, color_fill);
    restore_vizard_frame(previous);
}

void swfill_unroll(gframe_pv frame, color_t color)
{
    gframe_pv previous = select_vizard_frame(frame);
    hwfill(color);
    restore_vizard_frame(previous);
}

void swrect(gframe_pv frame, color_t color_edge,
            uint16_t L, uint16_t T, uint16_t R, uint16_t B, color_t color_fill)
{
    gframe_pv previous = select_vizard_frame(frame);
    hwrect(color_edge, L, T, R, B, color_fill);
    restore_vizard_frame(previous);
}

void swline(gframe_pv frame, uint32_t color,
            uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1)
{
    gframe_pv previous = select_vizard_frame(frame);
    hwline(color, x0, y0, x1, y1);
    restore_vizard_frame(previous);
}

void swelip(gframe_pv frame, color_t color_edge,
            uint16_t xc, uint16_t yc, uint16_t a, uint16_t b, color_t color_fill)
{
    gframe_pv previous = select_vizard_frame(frame);
    hwelip(color_edge, xc, yc, a, b, color_fill);
    restore_vizard_frame(previous);
}