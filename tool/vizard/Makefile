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

.PHONY: all clean check

all: vizard

clean:
	rm -f vizard tests/test_core tests/test_graphics_bridge tests/test_frame_extra_overflow $(APP_OBJ) $(APP_SHARED_OBJ) $(GRAPHICS_OBJ)

check:

include makefile.main

include makefile.tests
