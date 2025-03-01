# based mostly on 2019 skeleton version

SHELL                   := $(shell which bash) -o pipefail
ABS_TOP                 := $(subst /cygdrive/c/,C:/,$(shell pwd))
VIVADO                  ?= vivado
VIVADO_OPTS             ?= -nolog -nojournal -mode batch
FPGA_PART               ?= xc7a100tcsg324-1
BOARD_PART              ?= digilentinc.com:arty-a7-100:part0:1.1
RTL                     += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/src    -type f -name "*.v"))
CONSTRAINTS             += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/src    -type f -name "*.xdc"))
RTL_VHD                 += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/src    -type f -name "*.vhd"))
IP_CHECKPOINTS_DISABLE  += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/src    -type f -name "*.dcp"))
IP_XCI                  += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/gen -type f -name "*.xci" |egrep -v -e "\.cache")) #TODO: restrict find rather than grep
TOP                     ?= ArtyA7top
VCS                     := vcs -full64
VCS_OPTS                := -notice -PP -line +lint=all,noVCDE +v2k -timescale=1ns/10ps -debug -sverilog +define+ABS_TOP=$(ABS_TOP) +incdir+$(ABS_TOP)/src/riscv_core
SIM_RTL                 += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/sim -type f -name "*.v"))
SIM_MODELS              := $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/sim_models -type f -name "*.v"))
IVERILOG                := iverilog
IVERILOG_OPTS           := -Ttyp -D IVERILOG=1 -D ABS_TOP=$(ABS_TOP) -I $(ABS_TOP)/src/riscv_core -g2012
VVP                     := vvp

# Simulations
sim/%.tb: sim/%.v $(RTL) $(SIM_MODELS)
	cd sim && $(VCS) $(VCS_OPTS) -o $*.tb $(RTL) $(SIM_MODELS) $*.v -top $* -top glbl

sim/%.vpd: sim/%.tb
	cd sim && ./$*.tb +verbose=1 +vpdfile+$*.vpd |& tee $*.log

sim/%.tbi: sim/%.v $(RTL)
	cd sim && $(IVERILOG) $(IVERILOG_OPTS) -o $*.tbi $*.v $(RTL) $(SIM_MODELS)

sim/%.fst: sim/%.tbi
	cd sim && $(VVP) $*.tbi -fst |& tee $*.log

# ISA Tests
#sim/isa/isa_testbench.tbi: sim/isa_testbench.v $(RTL) $(SIM_MODELS)
#	mkdir -p sim/isa
#	cd sim/isa && $(IVERILOG) $(IVERILOG_OPTS) -o isa_testbench.tbi ../isa_testbench.v $(RTL) $(SIM_MODELS)
#
#sim/isa/%.fst: sim/isa/isa_testbench.tbi $(ABS_TOP)/../software/riscv-isa-tests/%.hex
#	cd sim/isa && $(VVP) isa_testbench.tbi -fst +hex_file=$(word 2,$^) +test_name=$(basename $(notdir $(word 2,$^))) |& tee $(basename $(notdir $(word 2,$^))).log

build/target.tcl: $(RTL) $(CONSTRAINTS) $(RTL_VHD) $(IP_XCI) # $(IP_CHECKPOINTS)
	mkdir -p build
	truncate -s 0 $@
	echo 'set VERBOSE                        "-verbose"'    >> $@
	echo "set ABS_TOP                        $(ABS_TOP)"    >> $@
	echo "set TOP                            $(TOP)"        >> $@
	echo "set BOARD_PART                     $(BOARD_PART)" >> $@
	echo "set FPGA_PART                      $(FPGA_PART)"  >> $@
	echo "set_param general.maxThreads       4"             >> $@
	echo "set_param general.maxBackupLogs    0"             >> $@
	echo -n "set RTL { " >> $@
	FLIST="$(RTL)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set RTL_VHD { " >> $@
	FLIST="$(RTL_VHD)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set CONSTRAINTS { " >> $@
	FLIST="$(CONSTRAINTS)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set IP_XCI { " >> $@
	FLIST="$(IP_XCI)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
#	echo -n "set IP_CHECKPOINTS { " >> $@
#	FLIST="$(IP_CHECKPOINTS)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
#	echo "}" >> $@
	echo 'exec echo "#=========================================#"' >> $@
	echo 'create_project -part $(FPGA_PART) -in_memory "mem_proj"' >> $@
	echo 'set project_obj                                      [get_projects "mem_proj"]' >> $@
	echo 'set_property "part"               "$(FPGA_PART)"     [get_projects "mem_proj"]' >> $@
	echo 'set_property "board_part"         "$(BOARD_PART)"    [get_projects "mem_proj"]' >> $@
	echo 'set_property "default_lib"        "xil_defaultlib"   [get_projects "mem_proj"]' >> $@
	echo 'set_property "simulator_language" "Mixed"            [get_projects "mem_proj"]' >> $@
	echo 'set_property "target_language"    "Verilog"          [get_projects "mem_proj"]' >> $@
# CORE CONTAINERS hold generated IP files in zip archive. Difficult outside Vivado.
	echo 'set_property coreContainer.enable 0                  [get_projects "mem_proj"]' >> $@
	echo 'set_property DESIGN_MODE RTL                   [ current_fileset ]' >> $@
	echo 'exec echo "#=========================================#"' >> $@


setup: build/target.tcl

gen: build/target.tcl $(ABS_TOP)/../scripts/ips.tcl


ips: gen/ips

build/synth/$(TOP).dcp: build/target.tcl $(ABS_TOP)/../scripts/synth.tcl
	mkdir -p ./build/synth/
	cd ./build/synth/ && $(VIVADO) $(VIVADO_OPTS) -source $(ABS_TOP)/../scripts/synth.tcl |& tee synth.log

synth: build/synth/$(TOP).dcp

build/impl/$(TOP).bit: build/synth/$(TOP).dcp $(ABS_TOP)/../scripts/impl.tcl
	mkdir -p ./build/impl/
	cd ./build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(ABS_TOP)/../scripts/impl.tcl |& tee impl.log

impl: build/impl/$(TOP).bit
all: build/impl/$(TOP).bit

warn:
	mkdir -p build/synth/          build/impl/
	touch -m build/synth/synth.log build/impl/impl.log
	egrep -e '^WARNING|^CRITICAL WARNING' -C3 --color=always build/synth/synth.log build/impl/impl.log || \
		egrep -i -C0 -e 'Errors|Warnings|Critical Warnings' --color=always build/synth/synth.log build/impl/impl.log

program: build/impl/$(TOP).bit $(ABS_TOP)/../scripts/program.tcl
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(ABS_TOP)/../scripts/program.tcl

program-force:
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(ABS_TOP)/../scripts/program.tcl

vivado: build
	cd build && nohup $(VIVADO) </dev/null >/dev/null 2>&1 &

## TODO: Activate "-Wall" but have config file to handle lint_off actions as needed...
lint:
	verilator -DABS_TOP=$(ABS_TOP) --lint-only --top-module $(TOP) --top glbl \
		$(ABS_TOP)/sim_models/glbl.v -I$(ABS_TOP)/sim_models -I$(ABS_TOP)/gen \
		--bbox-unsup --timing -I$(ABS_TOP)/src -I$(ABS_TOP)/src/base_util \
		-I$(ABS_TOP)/src/innerds -I$(ABS_TOP)/src/gpu -I$(ABS_TOP)/src/base_mem \
		$(RTL)

sim_build/compile_simlib/synopsys_sim.setup:
	mkdir -p sim_build/compile_simlib
	cd build/sim_build/compile_simlib && $(VIVADO) $(VIVADO_OPTS) -source $(ABS_TOP)/../scripts/compile_simlib.tcl

compile_simlib: sim_build/compile_simlib/synopsys_sim.setup

clean:
	rm -rf ./build

clean-sim:
	rm -rf *daidir sim/output.txt \
	sim/*.tb sim/*.daidir sim/csrc \
	sim/ucli.key sim/*.vpd sim/*.vcd \
	sim/*.tbi sim/*.fst sim/*.jou sim/*.log sim/*.out


.PHONY: setup ips synth impl warn program program-force vivado all clean
.PRECIOUS: sim/%.tb sim/%.tbi sim/%.fst sim/%.vpd
