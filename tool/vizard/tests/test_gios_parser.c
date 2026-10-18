#include "parse.h"
#include "uart.h"

#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

static const char *input;
static size_t input_index;

int8_t uread_int8(void)
{
    return input[input_index++];
}

void uwrite_int8(int8_t byte)
{
    (void)byte;
}

void uwrite_int8s(const int8_t *text)
{
    (void)text;
}

static void set_input(const char *text)
{
    input = text;
    input_index = 0;
}

static void test_default_delimiters(void)
{
    char token[16];

    set_input("rect\rcolor\r");
    assert(read_token(token, sizeof(token), NULL) == token);
    assert(strcmp(token, "rect") == 0);
    assert(read_token(token, sizeof(token), NULL) == token);
    assert(strcmp(token, "color") == 0);
}

static void test_custom_delimiters(void)
{
    char token[16];

    set_input("first;second,");
    assert(read_token(token, sizeof(token), ",;") == token);
    assert(strcmp(token, "first") == 0);
    assert(read_token(token, sizeof(token), ",;") == token);
    assert(strcmp(token, "second") == 0);
}

static void test_buffer_boundary(void)
{
    char token[4];

    set_input("abcd,");
    assert(read_token(token, sizeof(token), ",") == token);
    assert(strcmp(token, "abc") == 0);
    assert(input_index == 3);
    assert(read_token(token, sizeof(token), ",") == token);
    assert(strcmp(token, "d") == 0);
}

static void test_command_lookup(void)
{
    bcmdspec_t *command = token_cmdspec("rect");
    assert(command->cmd == BC_RECT);
    assert(command->flags == 3);
    assert(token_cmdspec("not-a-command")->cmd == BC_UNKNOWN);
}

int main(void)
{
    test_default_delimiters();
    test_custom_delimiters();
    test_buffer_boundary();
    test_command_lookup();
    puts("GIOS parser tests passed.");
    return 0;
}
