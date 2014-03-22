#include "mutmath.h"

uint32_t mul32(uint32_t n, uint32_t m)
__attribute__ ((weak, alias ("mut_mul32") ));

uint32_t sqr32(uint32_t const n)
__attribute__ ((weak, alias ("mut_sqr32") ));


uint32_t mut_mul32(uint32_t n, uint32_t m)
{
//  return n*m;
    uint32_t prod = 0;

    if (n < m) {
        while (n--) prod += m;
    } else {
        while (m--) prod += n;
    }
    return prod;
}

uint32_t mut_sqr32(uint32_t const n)
{
    mut_mul32(n,n);
}
