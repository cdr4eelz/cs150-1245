#include "uart.h"


void _start(void) // Could ahve _start pass some basic info
{
	L_FOREVER:
		while (!UTRAN_CTRL); UTRAN_DATA = '.';
		while (!UTRAN_CTRL); UTRAN_DATA = '[';
	goto L_FOREVER;
}
