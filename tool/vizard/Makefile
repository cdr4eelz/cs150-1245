#KEY "MIPS CODE" NAME/LOCATION SETTINGS (Coordinated with main project):
APP_PROJ_VERSION := 6
APP_SRC_DIR := ../../software/proj_app$(APP_PROJ_VERSION)
APP_FNAME := proj$(APP_PROJ_VERSION)
APP_SNAME := shared$(APP_PROJ_VERSION)
APP_INAME := isr$(APP_PROJ_VERSION)

VIZARD_BUILD_DIR := build

#OTHER "MIPS CODE" RELATED SETTINGS (Code from main project):
APP_SRC := $(APP_SRC_DIR)/$(APP_FNAME).c
APP_SHARED_SRC := $(APP_SRC_DIR)/$(APP_SNAME).c
APP_SHARED_HEADER := $(APP_SRC_DIR)/$(APP_SNAME).h
APP_COMMON_DIR := ../../software/common
APP_COMMON_HEADERS := $(wildcard $(APP_COMMON_DIR)/*.h)
APP_ASCII_SRC := $(APP_COMMON_DIR)/ascii.c
APP_UART_SRC := $(APP_COMMON_DIR)/uart.c

APP_OBJ := $(VIZARD_BUILD_DIR)/$(notdir $(APP_SRC:.c=_vizard.o))
APP_SHARED_OBJ := $(VIZARD_BUILD_DIR)/$(notdir $(APP_SHARED_SRC:.c=_vizard.o))

#ISR image (built by the app's own makefile; Vizard only loads it):
APP_ISR_BIN := $(APP_SRC_DIR)/$(APP_INAME).bin
APP_ISR_SRC := $(addprefix $(APP_SRC_DIR)/,isr$(APP_PROJ_VERSION).s shared$(APP_PROJ_VERSION).s.inc)
VIZARD_SHARED_CPPFLAGS := -iquote $(APP_SRC_DIR) -iquote $(APP_COMMON_DIR) -DVIZARD_SHARED_HEADER='"$(APP_SNAME).h"'

VIZARD_GPU_SRC := src/vizard_gpu.c
VIZARD_SRCS := src/vizard_main.c src/vizard_host.c src/vizard_mips.c
VIZARD_HDRS := src/vizard_host.h src/vizard_uart.h src/vizard_gpu.h src/vizard_mips.h $(APP_COMMON_DIR)/mmio_intr_cop0.h
VIZARD_COMMON_DIR := sw_common
VIZARD_UART_SRC := $(VIZARD_COMMON_DIR)/uart_vizard.c
VIZARD_GRAPHICS_SRC := $(VIZARD_COMMON_DIR)/graphics_vizard.c
VIZARD_GRAPHICS_OBJ := $(VIZARD_BUILD_DIR)/$(notdir $(VIZARD_GRAPHICS_SRC:.c=.o))

#EXTERNAL LIBRARY DEPENDENCIES:
RAYLIB_CFLAGS := $(shell pkg-config --cflags raylib 2>/dev/null)
RAYLIB_LIBS := $(shell pkg-config --libs raylib 2>/dev/null)

CC ?= gcc
CPPFLAGS ?= -I.
CFLAGS ?= -std=gnu99 -Wall -Wextra -O0 -g3 -fno-omit-frame-pointer \
	-fno-optimize-sibling-calls -fsanitize=address,undefined -fno-sanitize-recover=all

.PHONY: isr-warn all fresh clean check clean-tests clean-main
.DEFAULT_GOAL := all

all: vizard
fresh: clean check all

clean: clean-tests clean-main
	rm -rf $(VIZARD_BUILD_DIR)

$(VIZARD_BUILD_DIR):
	mkdir -p $@

$(APP_OBJ) $(APP_SHARED_OBJ) $(VIZARD_GRAPHICS_OBJ): | $(VIZARD_BUILD_DIR)

check:

include makefile.main

include makefile.tests
