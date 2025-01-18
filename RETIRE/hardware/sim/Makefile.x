
VLOG_XOPS ?= +define+DEFMAKE=1
VLOG_OPTS ?= -quiet +acc -source -nocovercells -sfcu -note vlog-2605
VLOG_SOPS ?= -lint -vlog01compat -pedanticerrors -nodeglitchalways $(VLOG_XOPS)

XILINX_LIBS ?= unisims_ver unimacro_ver xilinxcorelib_ver secureip
XILINX_LIB_INC := $(foreach lib,$(XILINX_LIBS),$(addprefix -L ,$(lib)))

CASES := $(wildcard tests/*.do)
TESTINPUTS := $(wildcard tests/*.input)
TRANSCRIPT := $(patsubst tests/%.do,results/%.transcript,$(CASES))
DOFILES := $(patsubst tests/%.do,build/%.do,$(CASES))
TESTINPUTSBUILD := $(patsubst tests/%.input,build/%.input,$(TESTINPUTS))

SRCD := ../src ../src/testbench ../src/dmem_blk_ram ../src/imem_blk_ram
INCD := $(foreach dir,$(SRCD),$(addprefix +incdir+../,$(dir)))
SRCS := $(foreach dir,$(SRCD),$(wildcard $(dir)/*.v))
STATUS := build/.status
COMPLOG := build/compile.log

BSRC := $(foreach dir,$(SRCS),$(addprefix ../,$(dir)))


default: all

all: $(TRANSCRIPT)

do: $(DOFILES)
	echo "Can cd to build then vsim < xyz.do"

prep: do compile resultsdir

compile: $(STATUS)

$(STATUS): $(SRCS) | build/Makefile
	date >>$(COMPLOG)
	make -C build | tee -a $(COMPLOG)
	touch $@
	date >>$(COMPLOG)

builddir:
	mkdir -p build

build/Makefile: $(SRCS) | builddir
	(cd build; vlib -unix -type flat work; vmap work work)
	(cd build; vlog $(VLOG_OPTS) ../glbl.v || exit 1)
	(cd build; vlog $(VLOG_OPTS) $(VLOG_SOPS) $(INCD) $(BSRC) || exit 1)
	(cd build; vmake -cygdrive > Makefile)

resultsdir:
	mkdir -p results

$(DOFILES) : build/%.do : tests/%.do | builddir
	echo 'proc start {m} {vsim $(XILINX_LIB_INC) work.glbl $$m}' \
	| cat - $< > $@ 

$(TESTINPUTSBUILD) : build/% : tests/%
	cp $< $@

$(TRANSCRIPT) : results/%.transcript : build/%.do $(STATUS) $(TESTINPUTSBUILD) | resultsdir
	(cd build; vsim -wlf ../$(patsubst %.transcript,%.wlf,$@) -l ../$@ < ../$<)

clean:
	rm -rf results build

printenv:
	set | grep -e '^[[:alnum:]]*='

# Tricks from http://www.cmcrossroads.com/ask-mr-make/6521-dumping-every-makefile-variable
print-%:
	echo $* = $($*)

printvars:
	@$(foreach V,$(sort $(.VARIABLES)), $(warning $V=$($V) ($(value $V))))

.PHONY := all clean resultsdir builddir compile do prep

