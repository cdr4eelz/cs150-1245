#include "uart.h"
#ifdef VIZARD
#include "vizard_host.h"
#endif

void uwrite_int8(int8_t c)
{
#ifdef VIZARD
    vizard_host_uart_write((unsigned char)c);
#else
    while (!UTRAN_CTRL) ;
    UTRAN_DATA = c;
#endif
}

void uwrite_int8s(const int8_t* s)
{
    for (int i = 0; s[i] != '\0'; i++) {
        uwrite_int8(s[i]);
    }
}

int8_t uread_int8(void)
{
#ifdef VIZARD
    int8_t ch = (int8_t)vizard_host_uart_read();
#else
    while (!URECV_CTRL) ;
    int8_t ch = URECV_DATA;
#endif
    if ((ch == '\x0d') || (ch == '\x0a')) {
        uwrite_int8('\r');
        uwrite_int8('\n');
    } else {
        uwrite_int8(ch);
    }
    return ch;
}
