#ifndef VIZARD_UART_H
#define VIZARD_UART_H

#include <stdbool.h>
#include "mmio_intr_cop0.h"

#define VIZARD_UART_CAPACITY 256

#define VIZARD_UART_TX_READY MM_UATX_READY
#define VIZARD_UART_RX_VALID MM_UARX_VALID
#define VIZARD_UART_TX_DATA  MM_UATX_DATA
#define VIZARD_UART_RX_DATA  MM_UARX_DATA

typedef struct {
    unsigned char tx[VIZARD_UART_CAPACITY];
    unsigned char rx[VIZARD_UART_CAPACITY];
    unsigned int tx_head;
    unsigned int tx_count;
    unsigned int rx_head;
    unsigned int rx_count;
} VizardUart;

void vizard_uart_init(VizardUart *uart);
unsigned int vizard_uart_read32(VizardUart *uart, unsigned int address);
void vizard_uart_write32(VizardUart *uart, unsigned int address, unsigned int value);
bool vizard_uart_receive(VizardUart *uart, unsigned char byte);
bool vizard_uart_transmit(VizardUart *uart, unsigned char *byte);

#endif