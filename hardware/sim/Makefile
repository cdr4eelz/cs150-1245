CASES := $(wildcard tests/*.do)
TESTINPUTS := $(wildcard tests/*.input)
TRANSCRIPT := $(patsubst tests/%.do,results/%.transcript,$(CASES))
DOFILES := $(patsubst tests/%.do,build/%.do,$(CASES))
TESTINPUTSBUILD := $(patsubst tests/%.input,build/%.input,$(TESTINPUTS))
SRCDIR := ../src
SWDIR := ../../software
SRCS := $(shell find $(SRCDIR) -name '*.v' -type f)
INC := $(shell find $(SRCDIR) -type d -exec echo -n '+incdir+'{} \;)
STATUS := build/.status
XILINX_LIBS := unisims_ver unimacro_ver xilinxcorelib_ver secureip
XILINX_LIB_INC := $(foreach lib,$(XILINX_LIBS),$(addprefix -L ,$(lib)))
#XILINX_LIBS_MAP := $(wildcard $(XILINX)/verilog/mti_se/10.2b/lin64/*)
XILINX_LIBS_MAP := $(wildcard /opt/intelFPGA/xlib_14.7_10.1d/*)
#XILINX_LIBS_MAP := $(wildcard /opt/intelFPGA/xlib_14.7_10.5b/*)

# Simulator selection: SIM=modelsim (default, unchanged ModelSim flow) or
# SIM=icarus (Icarus Verilog flow, see the end of this file or `make help`).
SIM ?= modelsim

ifeq ($(SIM),icarus)
all: icarus
else
all: $(TRANSCRIPT)
endif

compile: $(STATUS)

$(STATUS): $(SRCS) | build/Makefile
	make -C ./build work/ml505top/_primary.dat
	touch $@

build/Makefile: | builddir
	[ -e /scratch/sim/src || ln -sf -T $(realpath $(SRCDIR)) /scratch/sim/src
	(cd build; vlib work; vmap work work)
	(cd build; for file in $(XILINX_LIBS_MAP); do \
	vmap $$(basename $$file) $$file || exit 1; done)
	(cd build; \
	vlog +acc -source -nocovercells  \
	$(XILINX)/verilog/src/glbl.v \
	|| exit 1)
	(cd build; for file in $(SRCS); do \
	vlog +acc -source -nocovercells $(INC) $$file || exit 1; done)
	(cd build; vmake > Makefile)

results:
	mkdir -p /scratch/sim/results
	[ -e results ] || ln -sf /scratch/sim/results results
	[ -e /scratch/sim/sw ] || ln -sf -T $(realpath $(SWDIR)) /scratch/sim/sw

$(DOFILES) : build/%.do : tests/%.do | builddir
	[ -e /scratch/sim/src ] || ln -sf -T $(realpath $(SRCDIR)) /scratch/sim/src
	echo 'proc start {m} {vsim $(XILINX_LIB_INC) work.glbl $$m}' \
	| cat - $< > $@ 

$(TESTINPUTSBUILD) : build/% : tests/% | builddir
	cp $< $@
	
$(TRANSCRIPT) : results/%.transcript : build/%.do $(STATUS) $(TESTINPUTSBUILD) | results
	(cd build; pwd; \
	vsim < ../$< | tee ../$@)
	cp build/vsim.wlf $(patsubst %.transcript,%.wlf,$@)

fresh:
	rm -rf /scratch/sim/results results sw
	$(MAKE) all

clean:
	rm -rf /scratch/sim results build sw

.PHONY := all clean compile fresh builddir results

builddir:
	mkdir -p /scratch/sim/build
	[ -e build ] || ln -sf /scratch/sim/build build

################################################################################
# Icarus Verilog flow (SIM=icarus)
#
#   make icarus TB=ALUTestbench          compile + run one testbench module
#   make icarus TB="ALUTestbench RegFileTestbench"
#   make SIM=icarus                      run every testbench started by the
#                                        tests/*.do files ("start X" or
#                                        "set MODULE X"), like `make all` does
#   make icarus TB=ALUTestbench VCD=1    also dump results_icarus/<TB>.vcd
#   make icarus-clean                    remove build_icarus/ results_icarus/
#
# Everything stays local (build_icarus/, results_icarus/); /scratch is not
# needed. vvp runs inside build_icarus/ with tests/*.input copied there, so
# relative $readmem paths behave like the ModelSim flow (which runs in build/).
# Output goes to results_icarus/<TB>.log; the target fails if iverilog or vvp
# fails, or if the log matches ICARUS_FAIL_RE (testbenches usually $finish
# with exit status 0 even when a check fails).
#
# Sources: by default only the file that defines module $(TB) is compiled and
# the other modules are found through -y library dirs (every directory under
# $(SRCDIR); file name must match module name). Override with
#   ICARUS_SRCS="file1.v file2.v"   explicit source list (-y dirs still apply;
#                                   set ICARUS_YDIRS= to turn that off)
#   ICARUS_SRCS='$$(SRCS)'          compile every source like ModelSim does
#
# Xilinx primitives (FDRE, RAMB36, BUFG, ...) and CoreGen cores need the
# Xilinx simulation library sources. If $(XILINX) is set (ISE settings script),
# $(XILINX)/verilog/src/unisims is added as a -y dir and glbl.v is compiled as
# an extra top. Point ICARUS_LIBDIRS at other dirs as needed, e.g.
#   make icarus TB=X ICARUS_LIBDIRS="$$XILINX/verilog/src/unisims $$XILINX/verilog/src/XilinxCoreLib"
#
# Other knobs: ICARUS_STD (default -g2005, use -g2012 for SystemVerilog),
# ICARUS_FLAGS, ICARUS_STOP_NS (sim-time limit, default 1000000 = the
# "run 1000us" used by tests/src/*.do, 0 = none), ICARUS_TIMEOUT (wall-clock
# seconds, default 600), ICARUS_FAIL_RE, ICARUS_IGNORE_RE (lines exempt from
# ICARUS_FAIL_RE, default the "ERRORS: 0" summary of util_elog.vh), IVERILOG, VVP.
################################################################################

IVERILOG ?= iverilog
VVP ?= vvp
ICARUS_BUILD ?= build_icarus
ICARUS_RESULTS ?= results_icarus
ICARUS_STD ?= -g2005
ICARUS_FLAGS ?= -grelative-include
ICARUS_DIRS := $(shell find $(SRCDIR) -type d)
ICARUS_INC ?= $(addprefix -I,$(ICARUS_DIRS))
ICARUS_YDIRS ?= $(ICARUS_DIRS)
ICARUS_LIBDIRS ?= $(if $(XILINX),$(wildcard $(XILINX)/verilog/src/unisims))
ICARUS_GLBL ?= $(if $(XILINX),$(wildcard $(XILINX)/verilog/src/glbl.v))
ICARUS_SRCS ?=
ICARUS_CTL := icarus_ctl.v
ICARUS_STOP_NS ?= 1000000
ICARUS_TIMEOUT ?= 600
ICARUS_FAIL_RE ?= FAIL|ERROR|Error|Want:
ICARUS_IGNORE_RE ?= ^ERRORS: 0[[:space:]]*$$
ICARUS_TBS ?= $(shell sed -n -E 's/^[[:space:]]*(start|set[[:space:]]+MODULE)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' $(CASES) /dev/null)
ICARUS_RUN = $(if $(TB),$(TB),$(ICARUS_TBS))
ICARUS_LOGS = $(addprefix $(ICARUS_RESULTS)/,$(addsuffix .log,$(ICARUS_RUN)))
ICARUS_INPUTS := $(patsubst tests/%,$(ICARUS_BUILD)/%,$(TESTINPUTS))

icarus: icarus-check $(ICARUS_LOGS)

icarus-check:
	@[ -n "$(strip $(ICARUS_RUN))" ] || { echo "No testbench: use 'make icarus TB=<TestbenchModule>' or copy tests/src/*.do to tests/"; exit 1; }
	@command -v $(IVERILOG) >/dev/null || { echo "$(IVERILOG) not found"; exit 1; }

$(ICARUS_BUILD) $(ICARUS_RESULTS):
	mkdir -p $@

$(ICARUS_INPUTS) : $(ICARUS_BUILD)/% : tests/% | $(ICARUS_BUILD)
	cp $< $@

ICARUS_COMPILE = $(IVERILOG) $(ICARUS_STD) $(ICARUS_FLAGS) -DICARUS_TOP=$* \
	-s $* -s icarus_ctl $(if $(ICARUS_GLBL),-s glbl) $(ICARUS_INC) \
	$(addprefix -y ,$(ICARUS_YDIRS) $(ICARUS_LIBDIRS)) -Y .v

# <TB>.cmd only changes when the compile options do, forcing a rebuild then.
$(ICARUS_BUILD)/%.cmd : icarus-force | $(ICARUS_BUILD)
	@echo '$(ICARUS_COMPILE) $(ICARUS_SRCS) $(ICARUS_CTL) $(ICARUS_GLBL)' > $@.new
	@cmp -s $@.new $@ && rm -f $@.new || mv -f $@.new $@

$(ICARUS_BUILD)/%.vvp : $(ICARUS_BUILD)/%.cmd $(SRCS) $(ICARUS_SRCS) $(ICARUS_CTL) | $(ICARUS_BUILD)
	@srcs="$(ICARUS_SRCS)"; \
	if [ -z "$$srcs" ]; then \
	srcs=$$(grep -lE '^[[:space:]]*module[[:space:]]+$*([^A-Za-z0-9_]|$$)' $(SRCS)); \
	[ -n "$$srcs" ] || { echo "module $* not found under $(SRCDIR)"; exit 1; }; \
	fi; \
	echo "$(IVERILOG) $(ICARUS_STD) $(ICARUS_FLAGS) -s $* ... -o $@ $$srcs (full command in $<)"; \
	$(ICARUS_COMPILE) -o $@ $$srcs $(ICARUS_CTL) $(ICARUS_GLBL) \
	> $(ICARUS_BUILD)/$*.compile.log 2>&1; \
	status=$$?; cat $(ICARUS_BUILD)/$*.compile.log; \
	[ $$status -eq 0 ] || { rm -f $@; echo "ICARUS COMPILE FAILED: $*"; exit 1; }

$(ICARUS_RESULTS)/%.log : $(ICARUS_BUILD)/%.vvp $(ICARUS_INPUTS) icarus-force | $(ICARUS_RESULTS)
	@(cd $(ICARUS_BUILD); \
	$$(command -v timeout >/dev/null && echo timeout $(ICARUS_TIMEOUT)) \
	$(VVP) -n $*.vvp +stop_ns=$(ICARUS_STOP_NS) \
	$(if $(VCD),+vcd=$(abspath $(ICARUS_RESULTS))/$*.vcd)) > $@ 2>&1; \
	status=$$?; cat $@; \
	if [ $$status -ne 0 ]; then echo "ICARUS FAILED: $* (vvp exit status $$status, see $@)"; exit 1; fi; \
	if $(if $(ICARUS_IGNORE_RE),grep -v -E '$(ICARUS_IGNORE_RE)' $@,cat $@) | grep -E -q '$(ICARUS_FAIL_RE)'; then echo "ICARUS FAILED: $* (output matches '$(ICARUS_FAIL_RE)', see $@)"; exit 1; fi; \
	echo "ICARUS PASSED: $* (log: $@)"

icarus-clean:
	rm -rf $(ICARUS_BUILD) $(ICARUS_RESULTS)

icarus-force:

help:
	@echo "make [all]                    ModelSim: run tests/*.do -> results/*.transcript (needs /scratch/sim)"
	@echo "make compile | fresh | clean  ModelSim helpers"
	@echo "make icarus TB=<Module> [VCD=1]  Icarus Verilog: build_icarus/, results_icarus/<Module>.log"
	@echo "make SIM=icarus               Icarus: run every testbench started by tests/*.do"
	@echo "make icarus-clean             remove Icarus build/results dirs"
	@echo "See the Icarus comment block at the end of this Makefile for ICARUS_* overrides."

.PHONY: icarus icarus-check icarus-clean icarus-force help
.PRECIOUS: $(ICARUS_BUILD)/%.vvp $(ICARUS_BUILD)/%.cmd
