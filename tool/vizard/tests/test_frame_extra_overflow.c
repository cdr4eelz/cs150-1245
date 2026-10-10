#include "graphics.h"
#include "vizard_host.h"

volatile void * volatile vizard_pf_frame;
volatile void * volatile vizard_gp_frame;
void * volatile vizard_gp_gcode;
volatile uint32_t vizard_gp_state_storage;

bool vizard_host_gpu_submit(const unsigned int *words, size_t word_count,
                            unsigned int frame)
{
    (void)words;
    (void)word_count;
    (void)frame;
    return true;
}

void vizard_host_wait_gpu(void)
{
}

void vizard_host_wait_pf_frame(unsigned int frame)
{
    (void)frame;
}

int main(void)
{
    volatile uint32_t *tail = FRAME_EXTRA_TAIL(VIZARD_EXTRA_FRAME_COUNT - 1);
    tail[FRAME_XTRAP] = 0xdeadbeefu;
    return 0;
}
