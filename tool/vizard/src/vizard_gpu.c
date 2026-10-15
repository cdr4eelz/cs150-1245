#include "vizard_gpu.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    GOP_STOP = 0,
    GOP_FILL = 1,
    GOP_LINE = 2,
    GOP_ELLIPSE = 3,
    GOP_RECT = 4
};

static void gpu_contract_failure(const char *message) __attribute__((noreturn));

static void gpu_contract_failure(const char *message)
{
    fprintf(stderr, "Vizard fatal: %s\n", message);
    abort();
}

static unsigned frame_index(uint32_t frame)
{
    return (frame >> 28) ? ((frame >> 22) & 0x3fu) : (frame & 0x3fu);
}

static uint32_t *get_frame(VizardGpu *gpu, unsigned frame)
{
    if (frame >= VIZARD_FRAME_COUNT) {
        return NULL;
    }
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
    bool fill_active = (fill & 0xff000000u) != 0;
    fill = opaque_color(fill);
    int left = x0 < x1 ? x0 : x1;
    int right = x0 > x1 ? x0 : x1;
    int top = y0 < y1 ? y0 : y1;
    int bottom = y0 > y1 ? y0 : y1;

    for (int y = top; y <= bottom; ++y) {
        for (int x = left; x <= right; ++x) {
            bool is_edge = x == left || x == right || y == top || y == bottom;
            if (is_edge) {
                put_pixel(gpu, pixels, x, y, edge);
            } else if (fill_active) {
                put_pixel(gpu, pixels, x, y, fill);
            }
        }
    }
}

static void draw_ellipse_row(VizardGpu *gpu, uint32_t *pixels,
                             int xc, int row, int x,
                             uint32_t edge, uint32_t fill)
{
    bool fill_active = (fill & 0xff000000u) != 0;
    fill = opaque_color(fill);
    int left = xc - x;
    int right = xc + x;
    for (int column = left; column <= right; ++column) {
        if (column == left || column == right) {
            put_pixel(gpu, pixels, column, row, edge);
        } else if (fill_active) {
            put_pixel(gpu, pixels, column, row, fill);
        }
    }
}

static void draw_ellipse_scanlines(VizardGpu *gpu, uint32_t *pixels,
                                   uint16_t xc, uint16_t yc,
                                   uint16_t x, uint16_t y,
                                   uint32_t edge, uint32_t fill)
{
    draw_ellipse_row(gpu, pixels, xc, yc - y, x, edge, fill);
    if (y != 0) {
        draw_ellipse_row(gpu, pixels, xc, yc + y, x, edge, fill);
    }
}

static uint32_t swelip_mul32u_full(uint32_t left, uint32_t right)
{
    return left * right;
}

static void draw_ellipse(VizardGpu *gpu, uint32_t *pixels,
                         uint16_t xc, uint16_t yc,
                         uint16_t a, uint16_t b,
                         uint32_t edge, uint32_t fill)
{
    uint16_t x = 0, y = b;
    uint32_t const AA = (uint32_t)a * a;
    uint32_t const BB = (uint32_t)b * b;
    uint32_t const AABB = swelip_mul32u_full(AA, BB);
    uint32_t AAy = swelip_mul32u_full(AA, y);
    uint32_t BBx = 0;
    uint32_t BB2xp3 = (BB << 1) + BB;
    int32_t const stopper = (AA >> 1) + BB;
    int32_t dd = BB - AAy + (AA >> 2);

    draw_ellipse_scanlines(gpu, pixels, xc, yc, x, y, edge, fill);
    while ((AAy - BBx) > (uint32_t)stopper && y > 0 && x <= a) {
        if (dd >= 0) {
            dd += (AA << 1) - (AAy << 1);
            --y;
            AAy -= AA;
        }
        dd += BB2xp3;
        ++x;
        BBx += BB;
        BB2xp3 += BB << 1;
        draw_ellipse_scanlines(gpu, pixels, xc, yc, x, y, edge, fill);
    }

    uint32_t BB2xp2 = BB2xp3 - BB;
    uint16_t y_minus_one = y - 1;
    dd = swelip_mul32u_full(BB, (uint32_t)x * x + x) + (BB >> 2) +
         swelip_mul32u_full(AA, (uint32_t)y_minus_one * y_minus_one) - AABB;
    while (y > 0 && x <= a) {
        if (dd < 0) {
            dd += BB2xp2;
            ++x;
            BB2xp2 += BB << 1;
        }
        dd += (AA << 1) + AA - (AAy << 1);
        --y;
        AAy -= AA;
        draw_ellipse_scanlines(gpu, pixels, xc, yc, x, y, edge, fill);
    }
}

bool vizard_gpu_init(VizardGpu *gpu, unsigned width, unsigned height)
{
    if (gpu == NULL) {
        gpu_contract_failure("vizard_gpu_init received a null GPU");
    }
    if (width == 0 || height == 0 ||
        (size_t)width > SIZE_MAX / height / sizeof(uint32_t)) {
        gpu_contract_failure("vizard_gpu_init received invalid dimensions");
    }
    memset(gpu, 0, sizeof(*gpu));
    gpu->width = width;
    gpu->height = height;
    return true;
}

void vizard_gpu_dispose(VizardGpu *gpu)
{
    if (gpu == NULL) {
        gpu_contract_failure("vizard_gpu_dispose received a null GPU");
    }
    for (unsigned i = 0; i < VIZARD_FRAME_COUNT; ++i) {
        free(gpu->frames[i].pixels);
        gpu->frames[i].pixels = NULL;
    }
}

const uint32_t *vizard_gpu_frame(const VizardGpu *gpu, unsigned frame)
{
    if (gpu == NULL || frame >= VIZARD_FRAME_COUNT) {
        gpu_contract_failure("vizard_gpu_frame received an invalid GPU or frame");
    }
    return gpu->frames[frame].pixels;
}

bool vizard_gpu_stream_word_count(const uint32_t *words, size_t max_word_count,
                                  size_t *word_count)
{
    if (words == NULL || word_count == NULL) {
        gpu_contract_failure("vizard_gpu_stream_word_count received a null argument");
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
    if (gpu == NULL) {
        gpu_contract_failure("vizard_gpu_submit received a null GPU");
    }

    gpu->fault = false;
    gpu->commands_processed = 0;
    gpu->frame = frame_index(frame);
    if (words == NULL || word_count == 0 || gpu->frame >= VIZARD_FRAME_COUNT) {
        gpu->fault = true;
        return false;
    }

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
        if (opcode == GOP_LINE) {
            draw_line(gpu, pixels, x0, y0, x1, y1, edge);
            continue;
        }

        uint32_t fill = words[index++];
        if (opcode == GOP_RECT) {
            draw_rect(gpu, pixels, x0, y0, x1, y1, edge, fill);
        } else {
            draw_ellipse(gpu, pixels, (uint16_t)x0, (uint16_t)y0,
                         (uint16_t)x1, (uint16_t)y1, edge, fill);
        }
    }

    gpu->fault = true;
    return false;
}