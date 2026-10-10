CC ?= gcc
CPPFLAGS ?= -I.
CFLAGS ?= -std=gnu99 -Wall -Wextra -O0 -g3 -fno-omit-frame-pointer \
	-fno-optimize-sibling-calls -fsanitize=address,undefined -fno-sanitize-recover=all
.DEFAULT_GOAL := all
RAYLIB_CFLAGS := $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LIBS := $(shell pkg-config --libs raylib 2>/dev/null)
CORE_SRC := src/gpu.c
COMMON_DIR := ../../software/common
VIZARD_COMMON_DIR := sw_common
COMMON_HEADERS := $(wildcard $(COMMON_DIR)/*.h)
APP_SRC_DIR := ../../software/proj_app5
APP_FNAME := proj5
APP_SRC := $(APP_SRC_DIR)/$(APP_FNAME).c
APP_SHARED_SRC := $(APP_SRC_DIR)/shared.c
APP_OBJ := src/$(APP_FNAME)_vizard.o
APP_SHARED_OBJ := src/shared_vizard.o
APP_SHARED_HEADER := $(APP_SRC_DIR)/shared.h
GRAPHICS_OBJ := src/graphics_vizard.o
GRAPHICS_SRC := $(VIZARD_COMMON_DIR)/graphics_vizard.c
UART_SRC := $(COMMON_DIR)/uart.c
UART_VIZARD_SRC := $(VIZARD_COMMON_DIR)/uart_vizard.c

.PHONY: all check clean

all: vizard

vizard: src/main.c src/vizard_host.c src/vizard_host.h $(CORE_SRC) $(COMMON_DIR)/ascii.c $(GRAPHICS_SRC) $(UART_SRC) $(UART_VIZARD_SRC) $(COMMON_HEADERS) vizard.h src/vizard_uart.h $(APP_OBJ) $(APP_SHARED_OBJ) $(GRAPHICS_OBJ)
	@if ! pkg-config --exists raylib; then \
		echo "Raylib is required to build the graphical app (pkg-config package: raylib)." >&2; \
		exit 1; \
	fi
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD $(RAYLIB_CFLAGS) src/main.c src/vizard_host.c $(CORE_SRC) $(COMMON_DIR)/ascii.c $(GRAPHICS_SRC) $(UART_SRC) $(UART_VIZARD_SRC) $(APP_OBJ) $(APP_SHARED_OBJ) -o $@ $(RAYLIB_LIBS) -lm

$(APP_OBJ): $(APP_SRC) src/vizard_host.h $(COMMON_HEADERS)
	$(CC) $(CPPFLAGS) $(CFLAGS) -iquote $(COMMON_DIR) -Isrc -DVIZARD -Dmain=vizard_app_main -c $< -o $@

$(APP_SHARED_OBJ): $(APP_SHARED_SRC) $(APP_SHARED_HEADER) src/vizard_host.h $(COMMON_HEADERS)
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
	rm -f vizard tests/test_core tests/test_graphics_bridge $(APP_OBJ) $(APP_SHARED_OBJ) $(GRAPHICS_OBJ)
