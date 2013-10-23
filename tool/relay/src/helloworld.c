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


//void print(char *str);

#define U_DEFAULT STDIN_BASEADDRESS
#define U_DEBUG   XPAR_MDM_0_BASEADDR
#define U_SERIAL  XPAR_RS232_UART_1_BASEADDR

/*
 * XUartLite UAL_1, UAL_d;
int init_device(XUartLite &id)
{
	Status = XUartLite_Initialize(&UartLite, id);
	if (Status == XST_SUCCESS) {
		Status = XUartLite_SelfTest(&UartLite);
	}
	return Status;
}
*/

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


int main()
{
	init_platform();

	print("\n\r\n\rGreetings Professor Falken, would you like to play a game?\r\n");
	XUartLite_SendByte(XPAR_RS232_UART_1_BASEADDR, '\r');

	while (1) {
		pumpBytes_raw(U_SERIAL, U_DEBUG , FALSE);
		pumpBytes_raw(U_DEBUG,  U_SERIAL, TRUE );
	}

	print("\r\nThank you for playing!\r\n");

	cleanup_platform();
	return 0;
}
