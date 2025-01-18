#!/bin/bash

export MODELSIM_LIBS=modelsim_libs
export MODELSIM_LIBD=..
export MODELSIM_GLBL=glbl.v
export XILINX_LIBS="xilinxcorelib_ver"
export XILINX_LIBS_MAP="../modelsim_libs/xilinxcorelib_ver"

export VLOG_COPS=""

make $@
