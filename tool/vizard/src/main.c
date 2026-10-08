#include "vizard.h"
#include "vizard_host.h"

#include <stdio.h>

void vizard_app_main(void);

int main(void)
{
    if (!vizard_host_init()) {
        fputs("Unable to initialize the Vizard host.\n", stderr);
        return 1;
    }

    vizard_app_main();
    vizard_host_shutdown();
    return 0;
}