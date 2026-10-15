#include "uart.h"

#include "vizard_host.h"
#include "vizard_uart.h"

#include <stdio.h>
#include <stdlib.h>

static void uart_contract_failure(const char *message) __attribute__((noreturn));

static void uart_contract_failure(const char *message)
{
    fprintf(stderr, "Vizard fatal: %s\n", message);
    abort();
}

static void validate_uart(const VizardUart *uart)
{
    if (uart->tx_head >= VIZARD_UART_CAPACITY || uart->tx_count > VIZARD_UART_CAPACITY ||
        uart->rx_head >= VIZARD_UART_CAPACITY || uart->rx_count > VIZARD_UART_CAPACITY) {
        uart_contract_failure("UART FIFO state is out of range");
    }
}

void vizard_uart_init(VizardUart *uart)
{
    if (uart == NULL) {
        uart_contract_failure("vizard_uart_init received a null UART");
    }
    *uart = (VizardUart){0};
}

uint32_t vizard_uart_read32(VizardUart *uart, uint32_t address)
{
    if (uart == NULL) {
        uart_contract_failure("vizard_uart_read32 received a null UART");
    }
    validate_uart(uart);
    switch (address) {
    case VIZARD_UART_TX_READY:
        return uart->tx_count < VIZARD_UART_CAPACITY;
    case VIZARD_UART_RX_VALID:
        return uart->rx_count != 0;
    case VIZARD_UART_RX_DATA:
        if (uart->rx_count == 0) {
            return 0;
        }
        uint8_t byte = uart->rx[uart->rx_head];
        uart->rx_head = (uart->rx_head + 1) % VIZARD_UART_CAPACITY;
        --uart->rx_count;
        return byte;
    default:
        uart_contract_failure("read from an unsupported UART register");
    }
}

void vizard_uart_write32(VizardUart *uart, uint32_t address, uint32_t value)
{
    if (uart == NULL) {
        uart_contract_failure("vizard_uart_write32 received a null UART");
    }
    validate_uart(uart);
    if (address != VIZARD_UART_TX_DATA) {
        uart_contract_failure("write to an unsupported UART register");
    }
    if (uart->tx_count == VIZARD_UART_CAPACITY) {
        uart_contract_failure("UART TX FIFO overflow");
    }
    size_t tail = (uart->tx_head + uart->tx_count) % VIZARD_UART_CAPACITY;
    uart->tx[tail] = (uint8_t)value;
    ++uart->tx_count;
}

bool vizard_uart_receive(VizardUart *uart, uint8_t byte)
{
    if (uart == NULL) {
        uart_contract_failure("vizard_uart_receive received a null UART");
    }
    validate_uart(uart);
    if (uart->rx_count == VIZARD_UART_CAPACITY) {
        return false;
    }
    size_t tail = (uart->rx_head + uart->rx_count) % VIZARD_UART_CAPACITY;
    uart->rx[tail] = byte;
    ++uart->rx_count;
    return true;
}

bool vizard_uart_transmit(VizardUart *uart, uint8_t *byte)
{
    if (uart == NULL || byte == NULL) {
        uart_contract_failure("vizard_uart_transmit received a null argument");
    }
    validate_uart(uart);
    if (uart->tx_count == 0) {
        return false;
    }
    *byte = uart->tx[uart->tx_head];
    uart->tx_head = (uart->tx_head + 1) % VIZARD_UART_CAPACITY;
    --uart->tx_count;
    return true;
}
