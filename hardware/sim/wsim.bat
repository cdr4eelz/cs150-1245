@echo on
SETLOCAL ENABLEEXTENSIONS
SETLOCAL DISABLEDELAYEDEXPANSION

echo.
echo "Making fresh library:"
echo.
mkdir wbuild
cd wbuild
dir

vlib -unix -type flat work

vmap -modelsimini C:\A\ModelSim\CompXLib\modelsim.ini -c work work

vlog -quiet +acc -source -nocovercells -sfcu -note vlog-2605 ^
  ../glbl.v

REM   +incdir+../../src/bios_mem  ^
REM  +incdir+../../src/cache_data_blk_ram  ^
REM  +incdir+../../src/cache_tag_blk_ram  ^
REM  +incdir+../../src/mig_af  ^
REM  +incdir+../../src/mig_rdf  ^
REM  +incdir+../../src/mig_v3_61  ^
REM  +incdir+../../src/mig_wdf  ^
REM  +incdir+../../src/DVI  ^
REM  +incdir+../../src/pixel_fifo  ^
REM  +incdir+../../src/request_fifo  ^
REM ../../src/bios_mem/*.v ^
REM ../../src/cache_data_blk_ram/*.v ^
REM ../../src/cache_tag_blk_ram/*.v ^
REM ../../src/mig_af/*.v ^
REM ../../src/mig_rdf/*.v ^
REM ../../src/mig_v3_61/*.v ^
REM ../../src/mig_wdf/*.v ^
REM ../../src/DVI/*.v ^
REM ../../src/pixel_fifo/*.v ^
REM ../../src/request_fifo/*.v ^

vlog -quiet +acc -source -nocovercells -sfcu -note vlog-2605 ^
     -lint -vlog01compat -nodeglitchalways ^
  +incdir+../../src  ^  +incdir+../../src/dmem_blk_ram  ^  +incdir+../../src/imem_blk_ram  ^  +incdir+../../src/testbench  ^
-R -pedanticerrors ^
   -L unisims_ver ^
   -L unimacro_ver ^
   -L xilinxcorelib_ver ^
   -L secureip - ^
../../src/*.v ^../../src/testbench/*.v ^
../../src/dmem_blk_ram/*.v ^../../src/imem_blk_ram/*.v 

vmake >Makefile
