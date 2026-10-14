#include "vizard_host.h"
#include "vizard_gpu.h"

#include <stdio.h>

void main_imem(void);

int main(void)
{
    if (!vizard_host_init()) {
        fputs("Unable to initialize the Vizard host.\n", stderr);
        return 1;
    }

    main_imem();
    vizard_host_shutdown();
    return 0;
}