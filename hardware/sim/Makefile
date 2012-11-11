XILINX_BASE ?= /opt/Xilinx/14.1/ISE_DS

MODELSIM_LIBS ?= mti_se/10.1b_2/lin64
MODELSIM_LIBD ?= $(XILINX_BASE)/ISE/verilog
MODELSIM_GLBL ?= src/glbl.v

SRC ?= ../src
PRUNE ?= -type d -path "*_blk_ram" -prune -o
SRCD ?= $(shell find $(SRC) $(PRUNE) -type d)
SRCS ?= $(sort $(foreach dir,$(SRCD),$(wildcard $(dir)/*.v)))

VLOG_XOPS ?= +define+DEFMAKE=1
VLOG_COPS ?= -vopt #(not sure about the vopt thing)
VLOG_OPTS ?= -quiet +acc -source -nocovercells -sfcu -note vlog-2605 $(VLOG_COPS)
VLOG_SOPS ?= -lint -vlog01compat -pedanticerrors -nodeglitchalways $(VLOG_XOPS)
VLOG_LOGF ?= $(PWD)/build/comp_src.log

XILINX_LIBS ?= unisims_ver unimacro_ver xilinxcorelib_ver secureip
XILINX_LIBS_MAP ?= $(wildcard $(MODELSIM_LIBD)/$(MODELSIM_LIBS)/*)

CASES := $(wildcard tests/*.do)
TESTINPUTS := $(wildcard tests/*.input)
TRANSCRIPT := $(patsubst tests/%.do,results/%.transcript,$(CASES))
DOFILES := $(patsubst tests/%.do,build/%.do,$(CASES))
TESTINPUTSBUILD := $(patsubst tests/%.input,build/%.input,$(TESTINPUTS))

INC := $(foreach dir,$(SRCD),$(addprefix +incdir+../,$(dir)))
STATUS := build/.status
XILINX_LIB_INC := $(foreach lib,$(XILINX_LIBS),$(addprefix -L ,$(lib)))

BSRC := $(foreach dir,$(SRCS),$(addprefix ../,$(dir)))


default: all

all: $(TRANSCRIPT)

do: $(DOFILES)
	echo "Can cd to build then vsim < xyz.do"

prep: do results compile

fresh: clean do results build/Makefile
	echo "-----------------"
	grep -E "Warning" $(VLOG_LOGF) || echo "NO WARNINGS"
	grep -E "Error"   $(VLOG_LOGF) || echo "NO ERRORS"

compile: $(STATUS)

$(STATUS): $(SRCS) | build/Makefile
	make -C build
	touch $@

listlibs: builddir
	( cd build; ls -al $(MODELSIM_LIBD)/$(MODELSIM_LIBS) )
	echo $(XILINX_LIBS_MAP)
	echo $(XILINX_LIB_INC)

builddir:
	mkdir -p build

build/Makefile: build
	rm -f $(VLOG_LOGF)
	(cd build; vlib work; vmap work work)
	(cd build; for file in $(XILINX_LIBS_MAP); do \
	vmap $$(basename $$file) $$file || exit 1; done)
	(cd build; vlog $(VLOG_OPTS) $(MODELSIM_LIBD)/$(MODELSIM_GLBL) || exit 1)
	(cd build; vlog $(VLOG_OPTS) $(VLOG_SOPS) -l $(VLOG_LOGF) $(INC) $(BSRC) || exit 1)
	(cd build; vmake > Makefile)

results:
	mkdir -p results

$(DOFILES) : build/%.do : tests/%.do
	mkdir -p build
	echo 'proc start {m} {vsim $(XILINX_LIB_INC) work.glbl $$m}' \
	| cat - $< > $@ 

$(TESTINPUTSBUILD) : build/% : tests/%
	cp $< $@
	
$(TRANSCRIPT) : results/%.transcript : build/%.do $(STATUS) $(TESTINPUTSBUILD) | results
	(cd build; \
	vsim < ../$< | tee ../$@)
	cp build/vsim.wlf $(patsubst %.transcript,%.wlf,$@)

clean:
	rm -rf results build

printenv:
	set | grep -e '^[[:alnum:]]*='

# Tricks from http://www.cmcrossroads.com/ask-mr-make/6521-dumping-every-makefile-variable
print-%:
	echo $* = $($*)

printvars:
	@$(foreach V,$(sort $(.VARIABLES)), $(warning $V=$($V) ($(value $V))))

.PHONY := all clean results builddir listlibs compile do fresh prep

