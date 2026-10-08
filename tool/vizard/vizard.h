#ifndef VIZARD_H
#define VIZARD_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "vizard_uart.h"

#define VIZARD_SCREEN_WIDTH 800
#define VIZARD_SCREEN_HEIGHT 600
#define VIZARD_FRAME_COUNT 64
typedef struct {
    uint32_t *pixels;
} VizardFrame;

typedef struct {
    unsigned width;
    unsigned height;
    unsigned frame;
    bool fault;
    size_t commands_processed;
    VizardFrame frames[VIZARD_FRAME_COUNT];
} VizardGpu;

bool vizard_gpu_init(VizardGpu *gpu, unsigned width, unsigned height);
void vizard_gpu_dispose(VizardGpu *gpu);
bool vizard_gpu_submit(VizardGpu *gpu, const uint32_t *words, size_t word_count,
                       uint32_t frame);
const uint32_t *vizard_gpu_frame(const VizardGpu *gpu, unsigned frame);

#endif