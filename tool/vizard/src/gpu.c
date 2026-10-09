#include "vizard.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

enum {
    GOP_STOP = 0,
    GOP_FILL = 1,
    GOP_LINE = 2,
    GOP_ELLIPSE = 3,
    GOP_RECT = 4
};

static unsigned frame_index(uint32_t frame)
{
    return (frame >> 28) ? ((frame >> 22) & 0x3fu) : (frame & 0x3fu);
}

static uint32_t *get_frame(VizardGpu *gpu, unsigned frame)
{
    if (gpu->frames[frame].pixels == NULL) {
        size_t pixel_count = (size_t)gpu->width * gpu->height;
        gpu->frames[frame].pixels = calloc(pixel_count, sizeof(uint32_t));
    }
    return gpu->frames[frame].pixels;
}

static uint32_t opaque_color(uint32_t color)
{
    return 0xff000000u | (color & 0x00ffffffu);
}

static void put_pixel(VizardGpu *gpu, uint32_t *pixels, int x, int y, uint32_t color)
{
    if (x >= 0 && y >= 0 && (unsigned)x < gpu->width && (unsigned)y < gpu->height) {
        pixels[(size_t)y * gpu->width + (unsigned)x] = color;
    }
}

static void draw_line(VizardGpu *gpu, uint32_t *pixels, int x0, int y0,
                      int x1, int y1, uint32_t color)
{
    int dx = abs(x1 - x0);
    int sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0);
    int sy = y0 < y1 ? 1 : -1;
    int error = dx + dy;

    for (;;) {
        put_pixel(gpu, pixels, x0, y0, color);
        if (x0 == x1 && y0 == y1) {
            break;
        }
        int twice_error = 2 * error;
        if (twice_error >= dy) {
            error += dy;
            x0 += sx;
        }
        if (twice_error <= dx) {
            error += dx;
            y0 += sy;
        }
    }
}

static void draw_rect(VizardGpu *gpu, uint32_t *pixels, int x0, int y0,
                      int x1, int y1, uint32_t edge, uint32_t fill)
{
    int left = x0 < x1 ? x0 : x1;
    int right = x0 > x1 ? x0 : x1;
    int top = y0 < y1 ? y0 : y1;
    int bottom = y0 > y1 ? y0 : y1;

    for (int y = top; y <= bottom; ++y) {
        for (int x = left; x <= right; ++x) {
            bool is_edge = x == left || x == right || y == top || y == bottom;
            put_pixel(gpu, pixels, x, y, is_edge ? edge : fill);
        }
    }
}

static void draw_ellipse(VizardGpu *gpu, uint32_t *pixels, int xc, int yc,
                         int a, int b, uint32_t edge, uint32_t fill)
{
    if (a == 0 || b == 0) {
        draw_line(gpu, pixels, xc - a, yc - b, xc + a, yc + b, edge);
        return;
    }

    double aa = (double)a * a;
    double bb = (double)b * b;
    for (int y = yc - b; y <= yc + b; ++y) {
        for (int x = xc - a; x <= xc + a; ++x) {
            double dx = (double)(x - xc);
            double dy = (double)(y - yc);
            double distance = dx * dx / aa + dy * dy / bb;
            if (distance <= 1.0) {
                put_pixel(gpu, pixels, x, y, distance >= 0.78 ? edge : fill);
            }
        }
    }
}

bool vizard_gpu_init(VizardGpu *gpu, unsigned width, unsigned height)
{
    if (gpu == NULL || width == 0 || height == 0 ||
        (size_t)width > SIZE_MAX / height / sizeof(uint32_t)) {
        return false;
    }
    memset(gpu, 0, sizeof(*gpu));
    gpu->width = width;
    gpu->height = height;
    return true;
}

void vizard_gpu_dispose(VizardGpu *gpu)
{
    if (gpu == NULL) {
        return;
    }
    for (unsigned i = 0; i < VIZARD_FRAME_COUNT; ++i) {
        free(gpu->frames[i].pixels);
        gpu->frames[i].pixels = NULL;
    }
}

const uint32_t *vizard_gpu_frame(const VizardGpu *gpu, unsigned frame)
{
    if (gpu == NULL || frame >= VIZARD_FRAME_COUNT) {
        return NULL;
    }
    return gpu->frames[frame].pixels;
}

bool vizard_gpu_stream_word_count(const uint32_t *words, size_t max_word_count,
                                  size_t *word_count)
{
    if (words == NULL || word_count == NULL) {
        return false;
    }

    size_t index = 0;
    while (index < max_word_count) {
        uint32_t instruction = words[index++];
        unsigned opcode = instruction >> 28;
        size_t trailing_words;

        if (opcode == GOP_STOP) {
            if (instruction != 0) {
                return false;
            }
            *word_count = index;
            return true;
        }
        if (opcode == GOP_FILL) {
            trailing_words = 0;
        } else if (opcode == GOP_LINE) {
            trailing_words = 2;
        } else if (opcode == GOP_ELLIPSE || opcode == GOP_RECT) {
            trailing_words = 3;
        } else {
            return false;
        }

        if (trailing_words > max_word_count - index) {
            return false;
        }
        index += trailing_words;
    }

    return false;
}

bool vizard_gpu_submit(VizardGpu *gpu, const uint32_t *words, size_t word_count,
                       uint32_t frame)
{
    if (gpu == NULL || words == NULL || word_count == 0) {
        return false;
    }

    gpu->fault = false;
    gpu->commands_processed = 0;
    gpu->frame = frame_index(frame);
    uint32_t *pixels = get_frame(gpu, gpu->frame);
    if (pixels == NULL) {
        gpu->fault = true;
        return false;
    }

    size_t index = 0;
    while (index < word_count) {
        uint32_t instruction = words[index++];
        unsigned opcode = instruction >> 28;
        uint32_t edge = opaque_color(instruction);
        ++gpu->commands_processed;

        if (opcode == GOP_STOP) {
            if (instruction != 0) {
                gpu->fault = true;
            }
            return !gpu->fault;
        }
        if (opcode == GOP_FILL) {
            uint32_t fill_color = opaque_color(instruction);
            size_t pixel_count = (size_t)gpu->width * gpu->height;
            for (size_t pixel = 0; pixel < pixel_count; ++pixel) {
                pixels[pixel] = fill_color;
            }
            continue;
        }
        if (opcode != GOP_LINE && opcode != GOP_ELLIPSE && opcode != GOP_RECT) {
            gpu->fault = true;
            return false;
        }

        size_t trailing_words = opcode == GOP_LINE ? 2u : 3u;
        if (word_count - index < trailing_words) {
            gpu->fault = true;
            return false;
        }

        uint32_t first = words[index++];
        uint32_t second = words[index++];
        int x0 = (int)((first >> 16) & 0x3ffu);
        int y0 = (int)(first & 0x3ffu);
        int x1 = (int)((second >> 16) & 0x3ffu);
        int y1 = (int)(second & 0x3ffu);
        ++gpu->commands_processed;
        ++gpu->commands_processed;

        if (opcode == GOP_LINE) {
            draw_line(gpu, pixels, x0, y0, x1, y1, edge);
            continue;
        }

        uint32_t fill = opaque_color(words[index++]);
        ++gpu->commands_processed;
        if (opcode == GOP_RECT) {
            draw_rect(gpu, pixels, x0, y0, x1, y1, edge, fill);
        } else {
            draw_ellipse(gpu, pixels, x0, y0, x1, y1, edge, fill);
        }
    }

    gpu->fault = true;
    return false;
}