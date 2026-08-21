#include "uart.h"


int main(void)
{
    for ( ; ; )
    {
        while (!URECV_CTRL) ;
        char byte = URECV_DATA;
        while (!UTRAN_CTRL) ;
        UTRAN_DATA = byte;
    }

    return 0;
}
