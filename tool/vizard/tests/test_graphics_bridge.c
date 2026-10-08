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

    cursor = hwq_rect(cursor, 0x00123456u, 1, 2, 10, 11, 0xffabcdefu);
    cursor = hwq_stop(cursor);
    assert((size_t)(cursor - queue) == 5);
    assert(queue[0].u32 == 0x40123456u);
    assert(queue[1].u32 == 0x00010002u);
    assert(queue[2].u32 == 0x000a000bu);
    assert(queue[3].u32 == 0xffabcdefu);
    assert(queue[4].u32 == 0);
    puts("Vizard graphics bridge tests passed.");
    return 0;
}