#ifndef VIZARD_UART_H
#define VIZARD_UART_H

#include <stdbool.h>

#define VIZARD_UART_CAPACITY 256

#define VIZARD_UART_TX_READY 0x80000000u
#define VIZARD_UART_RX_VALID 0x80000004u
#define VIZARD_UART_TX_DATA  0x80000008u
#define VIZARD_UART_RX_DATA  0x8000000cu

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