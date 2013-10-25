#include <string.h>
#include <stdio.h>

#include "platform.h"
#include "xparameters.h"
#include "xuartlite_l.h"
//#include <xiomodule.h>
#include "xil_types.h"
#include "xil_assert.h"
#include "xil_printf.h"
#include "xstatus.h"


#define U_DEFAULT STDIN_BASEADDRESS
#define U_DEBUG   XPAR_MDM_0_BASEADDR
#define U_SERIAL  XPAR_RS232_UART_2_BASEADDR

inline u8 pumpBytes_raw(int u_from, int u_to, u8 special)
{
	//u8 count = 0;
	while(!XUartLite_IsReceiveEmpty(u_from) && !XUartLite_IsTransmitFull(u_to)) {
		u8 bX = XUartLite_RecvByte(u_from);
		if (special && (bX=='\n')) {
			XUartLite_SendByte(u_to, '\r');
		} else XUartLite_SendByte(u_to, bX);
		//count++;
		return 1;
	}
	//return count;
	return 0;
}

u8 tX[256];
u8 rX[256];

int main()
{
    init_platform();

    print("\r\n[RELAY.x]\n\r");
	while (1) {
        while (!XUartLite_IsReceiveEmpty(U_DEBUG) && !XUartLite_IsTransmitFull(XPAR_RS232_UART_2_BASEADDR)) {
            tX[0] = XUartLite_RecvByte(U_DEBUG);
            if (tX[0] == '\n') tX[0] = '\r';
            if (tX[0] != 0) {
                //if (!XUartLite_IsTransmitFull(XPAR_RS232_UART_2_BASEADDR)) {
                    XUartLite_SendByte(XPAR_RS232_UART_2_BASEADDR, tX[0]);
                //}
            }
        }
        if (!XUartLite_IsReceiveEmpty(XPAR_RS232_UART_2_BASEADDR) && !XUartLite_IsTransmitFull(U_DEBUG)) {
            rX[0] = XUartLite_RecvByte(XPAR_RS232_UART_2_BASEADDR);
            if (rX[0] != 0) {
                //if (!XUartLite_IsTransmitFull(U_DEBUG)) {
                    XUartLite_SendByte(U_DEBUG, rX[0]);
                //}
            }
        }
	}
    print("\r\n[DONE]\r\n");

    cleanup_platform();
    return 0;
}
