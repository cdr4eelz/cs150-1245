#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

#define BUFFER_LEN 128
#define VERSION_CHAR '4'

typedef void (*entry_t)(void);

int main(void)
{
    uwrite_int8s("\r\n\r\n[COLT45.");
    uwrite_int8(VERSION_CHAR);
    uwrite_int8s("]\r\n\r\n");

    int8_t buffer[BUFFER_LEN];
    uint32_t stash_addr1 = 0x10000000;

    for ( ; ; ) {
        uwrite_int8(VERSION_CHAR);
        uwrite_int8('>');
        uwrite_int8(' ');

        int8_t* input = read_token(buffer, BUFFER_LEN, " \x0d");

        if (strcmp150(input, "file") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t file_length = ascii_dec_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            store(address, file_length);
        } else if (strcmp150(input, "jal") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            entry_t start = (entry_t)(address);
            start();
        } else if (strcmp150(input, "lw") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            volatile uint32_t* p = (volatile uint32_t*)(address);

            uwrite_int8s(uint32_to_ascii_hex(address, buffer, BUFFER_LEN));
            uwrite_int8s(":");
            uwrite_int8s(uint32_to_ascii_hex(*p, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "lhu") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            volatile uint16_t* p = (volatile uint16_t*)(address);

            uwrite_int8s(uint32_to_ascii_hex(address, buffer, BUFFER_LEN));
            uwrite_int8s(":");
            uwrite_int8s(uint16_to_ascii_hex(*p, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "lbu") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            volatile uint8_t* p = (volatile uint8_t*)(address);

            uwrite_int8s(uint32_to_ascii_hex(address, buffer, BUFFER_LEN));
            uwrite_int8s(":");
            uwrite_int8s(uint8_to_ascii_hex(*p, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "sw") == 0) {
            uint32_t word = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            volatile uint32_t* p = (volatile uint32_t*)(address);
            *p = word;
        } else if (strcmp150(input, "sh") == 0) {
            uint16_t half = ascii_hex_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            volatile uint16_t* p = (volatile uint16_t*)(address);
            *p = half;
        } else if (strcmp150(input, "sb") == 0) {
            uint8_t byte = ascii_hex_to_uint8(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            volatile uint8_t* p = (volatile uint8_t*)(address);
            *p = byte;

//Graphics commands:
        } else if (strcmp150(input, "gs") == 0) {
            uint32_t status = GP_CONTROL;

            uwrite_int8s(uint32_to_ascii_hex(status, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "pf") == 0) {
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            PF_FRAME = frame;
        } else if (strcmp150(input, "gf") == 0) {
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            GP_FRAME = frame;
        } else if (strcmp150(input, "gc") == 0) {
            uint32_t code = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            GP_CODE = code;
        } else if (strcmp150(input, "hwfill") == 0) {
            uint32_t color = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            hwfill(color, frame);
        } else if (strcmp150(input, "hwline") == 0) {
            uint32_t color = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t x0 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t y0 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t x1 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t y1 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            hwline(color, x0, y0, x1, y1, frame);
        } else if (strcmp150(input, "swfill") == 0) {
            uint32_t color = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            swfill(color, frame);
        } else if (strcmp150(input, "swline") == 0) {
            uint32_t color = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t x0 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t y0 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t x1 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t y1 = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            swline(color, x0, y0, x1, y1, frame);
        } else if (strcmp150(input, "swpixel") == 0) {
            uint32_t color = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t x = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint16_t y = ascii_dec_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t frame = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            swpixel(color, x, y, frame);

//COLT45 "custom" extensions:
        } else if (strcmp150(input, "dump") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            if (address == 0) {
                address = stash_addr1;
                stash_addr1 += (16 * 4);
            } else {
                stash_addr1 = address;
            }

            show_block(address, 16, buffer, BUFFER_LEN);
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "cp") == 0) {
            uint32_t a_src = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t a_dst = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t l_cpy = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            uint32_t xor = copy_xor(a_src, a_dst, l_cpy);

            uwrite_int8s(uint32_to_ascii_hex(xor, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        }
    }

    return 0;
}
