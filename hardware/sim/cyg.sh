#!/bin/bash

if [ "$OSTYPE"=="cygwin" ]; then
  MS="/cygdrive/c/Xilinx/current/ISE_DS/ISE/verilog/mti_pe/10.2c/nt64/modelsim.ini"
  if [ ! -r "$MS" ]; then
    XP = `cygpath -u "$XILINX"`
    MS = "$XP/verilog/mti_pe/10.2c/nt64/modelsim.ini"
    #Should hunt around a little (like with versions & find & such)
  fi
  export MODELSIM=`cygpath -w "$MS"`
else
  MSINI = "$MODELSIM" || "/opt/Xilinx/14.1/ISE_DS/ISE/verilog/mti_se/10.2a/lin64/modelsim.ini"
fi
echo "MODELSIM: $MODELSIM"

