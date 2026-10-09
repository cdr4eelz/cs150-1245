CC ?= cc
CPPFLAGS ?= -I.
CFLAGS ?= -std=gnu99 -Wall -Wextra -O2
.DEFAULT_GOAL := all
RAYLIB_CFLAGS := $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LIBS := $(shell pkg-config --libs raylib 2>/dev/null)
CORE_SRC := src/gpu.c
COMMON_DIR := ../../software/common
VIZARD_COMMON_DIR := sw_common
COMMON_HEADERS := $(wildcard $(COMMON_DIR)/*.h)
APP5_SRC := ../../software/proj_app5/proj5.c
APP5_SHARED_SRC := ../../software/proj_app5/shared.c
APP5_OBJ := src/proj5_vizard.o
APP5_SHARED_OBJ := src/shared_vizard.o
GRAPHICS_OBJ := src/graphics_vizard.o
GRAPHICS_SRC := $(VIZARD_COMMON_DIR)/graphics_vizard.c
UART_SRC := $(COMMON_DIR)/uart.c
UART_VIZARD_SRC := $(VIZARD_COMMON_DIR)/uart_vizard.c

.PHONY: all check clean

all: vizard

vizard: src/main.c src/vizard_host.c src/vizard_host.h $(CORE_SRC) $(COMMON_DIR)/ascii.c $(GRAPHICS_SRC) $(UART_SRC) $(UART_VIZARD_SRC) $(COMMON_HEADERS) vizard.h src/vizard_uart.h $(APP5_OBJ) $(APP5_SHARED_OBJ) $(GRAPHICS_OBJ)
	@if ! pkg-config --exists raylib; then \
		echo "Raylib is required to build the graphical app (pkg-config package: raylib)." >&2; \
		exit 1; \
	fi
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD $(RAYLIB_CFLAGS) src/main.c src/vizard_host.c $(CORE_SRC) $(COMMON_DIR)/ascii.c $(GRAPHICS_SRC) $(UART_SRC) $(UART_VIZARD_SRC) $(APP5_OBJ) $(APP5_SHARED_OBJ) -o $@ $(RAYLIB_LIBS) -lm

$(APP5_OBJ): $(APP5_SRC) src/vizard_host.h $(COMMON_HEADERS)
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD -Dmain=vizard_app_main -c $< -o $@

$(APP5_SHARED_OBJ): $(APP5_SHARED_SRC) ../../software/proj_app5/shared.h src/vizard_host.h $(COMMON_HEADERS)
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD -c $< -o $@

$(GRAPHICS_OBJ): $(GRAPHICS_SRC) $(COMMON_DIR)/graphics.h src/vizard_host.h vizard.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD -c $< -o $@

check: tests/test_core tests/test_graphics_bridge
	./tests/test_core
	./tests/test_graphics_bridge

tests/test_core: tests/test_core.c $(CORE_SRC) $(UART_SRC) $(UART_VIZARD_SRC) $(COMMON_HEADERS) vizard.h src/vizard_uart.h src/vizard_host.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD tests/test_core.c $(CORE_SRC) $(UART_SRC) $(UART_VIZARD_SRC) -o $@ -lm

tests/test_graphics_bridge: tests/test_graphics_bridge.c $(GRAPHICS_OBJ) $(COMMON_DIR)/graphics.h src/vizard_host.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD $< $(GRAPHICS_OBJ) -o $@

clean:
	rm -f vizard tests/test_core tests/test_graphics_bridge $(APP5_OBJ) $(APP5_SHARED_OBJ) $(GRAPHICS_OBJ)