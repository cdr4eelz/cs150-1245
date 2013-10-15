vlib -unix -type flat work
vmap -c work work
vlog -quiet +acc -source -nocovercells -sfcu -note vlog-2605 ../glbl.v
find ../../src -name '*.v' | xargs vlog -quiet +acc -source -nocovercells -sfcu -note vlog-2605 +incdir+../../src +incdir+../../src/testbench
vmake -cygdrive work >Makefile
#vsim -L unisims_ver -L unimacro_ver -L xilinxcorelib_ver -L secureip -lib work
