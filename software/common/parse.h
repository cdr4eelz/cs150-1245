#ifndef PARSE_H_
#define PARSE_H_

#include "types.h"

int8_t* read_n(int8_t*b, uint32_t n);
int8_t* read_token(int8_t* b, uint32_t n, int8_t* ds);
void store(uint32_t address, uint32_t length);
void show_block(uint32_t address, uint8_t numWords, int8_t* bufMEM, uint32_t bufLEN);
uint32_t copy_xor(uint32_t pSRC, uint32_t pDST, uint32_t length);

#endif
