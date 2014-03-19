#include "string.h"

#define RUNAWAYSTRING 1024

int32_t strcmp150(const int8_t* const s0, const int8_t* const s1)
{
    register const uint8_t *p0 = (const uint8_t*)s0, *p1 = (const uint8_t*)s1;
    uint32_t remains = RUNAWAYSTRING;
    uint8_t c0, c1;

    do {
        c0 = *p0++;
        c1 = *p1++;
        if (c0 == '\0') break;
    } while ((c0 == c1) && (--remains));
    return (c0 - c1);
}

int32_t strlen150(const int8_t* const s)
{
    const int8_t *p = s;
    uint32_t i = 0;
    while (*p++) i++;
    return i;
}
