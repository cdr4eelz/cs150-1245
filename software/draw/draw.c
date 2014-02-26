#include "types.h"
#include "graphics.h"

typedef void (*entry_t)(void);

int main(int argc, char**argv) {
    PF_FRAME = 0;
    swfill(0x00002233, 1);
    swline(0xFFFFFFFF, 10,10, 700,300, 1);
    swline(0xFFFFFFFF, 10,10, 500,400, 1);
    swpixel(0xFFFFFFFF, 20,50, 1);
    PF_FRAME = 1;
    swfill(0x00FF0000, 2);
    swline(0x0000FF00, 10,10, 700,300, 2);
    swline(0x000000FF, 10,10, 500,400, 2);
    swline(0x00000000, 10,10, 400,500, 2);
    swpixel(0x00006666, 21,51, 2);
    PF_FRAME = 2;
//    uint32_t bios = ascii_hex_to_uint32("40000000");
//    entry_t start = (entry_t) (bios);
//    start();
    return 0;
}
