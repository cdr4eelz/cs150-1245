#include "types.h"
#include "uart.h"

//#include <stdio.h>
extern int sprintf (char *__restrict __s,
                    __const char *__restrict __format, ...)
     __attribute__ ((__format__ (__printf__, 2, 3)));


#define DATA (int32_t *) 0x10018000

int main(int argc, char**argv) {
    char buf[100];
    int n = 82;
    uwrite_int8s("Weldome: ");
    sprintf(buf, "test: %h %d", n, n);
    uwrite_int8s(buf);
    return 0;
}
