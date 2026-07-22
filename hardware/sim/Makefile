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

all: $(TRANSCRIPT)

compile: $(STATUS)

$(STATUS): $(SRCS) | build/Makefile
	make -C ./build work/ml505top/_primary.dat
	touch $@

build/Makefile:
	mkdir -p /scratch/sim/build
	ln -sf /scratch/sim/build build
	ln -sf -T $(realpath $(SRCDIR)) /scratch/sim/src
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
	ln -sf /scratch/sim/results results
	ln -sf -T $(realpath $(SWDIR)) /scratch/sim/sw

$(DOFILES) : build/%.do : tests/%.do
	mkdir -p /scratch/sim/build
	ln -sf /scratch/sim/build build
	ln -sf -T $(realpath $(SRCDIR)) /scratch/sim/src
	echo 'proc start {m} {vsim $(XILINX_LIB_INC) work.glbl $$m}' \
	| cat - $< > $@ 

$(TESTINPUTSBUILD) : build/% : tests/%
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

.PHONY := all clean compile fresh
