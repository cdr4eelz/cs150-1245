BUILD_DIR := build

#KEY "MIPS CODE" NAME/LOCATION SETTINGS (Coordinated with main project):
APP_SRC_DIR := ../../software/proj_app6
APP_FNAME := proj6
APP_SNAME := shared6

#OTHER "MIPS CODE" RELATED SETTINGS (Code from main project):
APP_SRC := $(APP_SRC_DIR)/$(APP_FNAME).c
APP_SHARED_SRC := $(APP_SRC_DIR)/$(APP_SNAME).c
APP_SHARED_HEADER := $(APP_SRC_DIR)/$(APP_SNAME).h
APP_COMMON_DIR := ../../software/common
APP_COMMON_HEADERS := $(wildcard $(APP_COMMON_DIR)/*.h)
UART_SRC := $(APP_COMMON_DIR)/uart.c

APP_OBJ := $(BUILD_DIR)/$(notdir $(APP_SRC:.c=_vizard.o))
APP_SHARED_OBJ := $(BUILD_DIR)/$(notdir $(APP_SHARED_SRC:.c=_vizard.o))

RAYLIB_CFLAGS := $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LIBS := $(shell pkg-config --libs raylib 2>/dev/null)

CORE_SRC := src/vizard_gpu.c
VIZARD_SRCS := src/vizard_main.c src/vizard_host.c
VIZARD_HDRS := src/vizard_host.h src/vizard_uart.h vizard.h
VIZARD_COMMON_DIR := sw_common
GRAPHICS_SRC := $(VIZARD_COMMON_DIR)/graphics_vizard.c
UART_VIZARD_SRC := $(VIZARD_COMMON_DIR)/uart_vizard.c
GRAPHICS_OBJ := $(BUILD_DIR)/$(notdir $(GRAPHICS_SRC:.c=.o))

CC ?= gcc
CPPFLAGS ?= -I.
CFLAGS ?= -std=gnu99 -Wall -Wextra -O0 -g3 -fno-omit-frame-pointer \
	-fno-optimize-sibling-calls -fsanitize=address,undefined -fno-sanitize-recover=all

.PHONY: all fresh clean check clean-tests clean-main
.DEFAULT_GOAL := all

all: vizard
fresh: clean check all

clean: clean-tests clean-main
	rm -rf $(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $@

$(APP_OBJ) $(APP_SHARED_OBJ) $(GRAPHICS_OBJ): | $(BUILD_DIR)

check:

include makefile.main

include makefile.tests
