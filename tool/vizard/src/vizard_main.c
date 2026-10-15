#include "vizard_host.h"
#include "vizard_gpu.h"

#include <stdio.h>

void main_imem(void);

int main(void)
{
    if (!vizard_host_init()) {
        if (!vizard_host_failed()) {
            vizard_host_report_error("unable to initialize the host");
        }
        return 1;
    }

    main_imem();
    bool failed = vizard_host_failed();
    vizard_host_shutdown();
    return failed ? 1 : 0;
}