#include "graphics.h"

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>

volatile void * volatile vizard_pf_frame;
volatile void * volatile vizard_gp_frame;
void * volatile vizard_gp_gcode;
volatile uint32_t vizard_gp_state_storage;

static unsigned int submitted[8];
static size_t submitted_count;
static unsigned int submitted_frame;
static unsigned int waited_frame;

bool vizard_host_gpu_submit(const unsigned int *words, size_t word_count,
                            unsigned int frame)
{
    assert(word_count <= sizeof(submitted) / sizeof(submitted[0]));
    for (size_t i = 0; i < word_count; ++i) {
        submitted[i] = words[i];
    }
    submitted_count = word_count;
    submitted_frame = frame;
    return true;
}

void vizard_host_wait_gpu(void)
{
}

void vizard_host_wait_pf_frame(unsigned int frame)
{
    waited_frame = frame;
    vizard_pf_frame = (volatile void *)(unsigned long)frame;
}

int main(void)
{
    gpcode_t queue[8];
    gpcode_p cursor = queue;
    GP_FRAME = FRAME_PTR(2);
    hwrect(0x00123456u, 1, 2, 10, 11, 0xffabcdefu);

    assert(submitted_count == 5);
    assert(submitted[0] == 0x40123456u);
    assert(submitted[1] == 0x00010002u);
    assert(submitted[2] == 0x000a000bu);
    assert(submitted[3] == 0xffabcdefu);
    assert(submitted[4] == 0);
    assert(submitted_frame == 0x10800000u);

    pixel_pv extra0 = FRAME_EXTRA_TAIL(0);
    pixel_pv extra1 = FRAME_EXTRA_TAIL(1);
    pixel_pv extra9 = FRAME_EXTRA_TAIL(9);
    assert((unsigned long)extra0 % FRAME_ALIGN_BYTES == 0);
    assert(extra1 - extra0 == FRAME_XTRAP);
    assert(extra9 - extra0 == 9 * FRAME_XTRAP);
    assert(FRAME_XTRAP == FRAME_XTRAR * ROW_OFFSETP + ROW_XTRAP);
    assert(FRAME_XTRAP == 434400);

    PF_WAIT(2);
    assert(waited_frame == 0x10800000u);
    assert((unsigned int)(unsigned long)vizard_pf_frame == waited_frame);

    cursor = hwq_rect(cursor, 0x00123456u, 1, 2, 10, 11, 0xffabcdefu);
    cursor = hwq_stop(cursor);
    assert((size_t)(cursor - queue) == 5);
    assert(queue[0].u32 == 0x40123456u);
    assert(queue[1].u32 == 0x00010002u);
    assert(queue[2].u32 == 0x000a000bu);
    assert(queue[3].u32 == 0xffabcdefu);
    assert(queue[4].u32 == 0);

    cursor = queue;
    cursor = hwq_pixl(cursor, 0x00a1b2c3u, 7, 9);
    cursor = hwq_stop(cursor);
    assert((size_t)(cursor - queue) == 4);
    assert(queue[0].u32 == 0x20a1b2c3u);
    assert(queue[1].u32 == 0x00070009u);
    assert(queue[2].u32 == 0x00070009u);
    assert(queue[3].u32 == 0);

    puts("Vizard graphics bridge tests passed.");
    return 0;
}