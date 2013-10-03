#D_BLD ?= /scratch/q_build_$(USER)
#D_CFG ?= q_cfg
D_BLD ?= build
D_CFG ?= cfg
D_SRC ?= src
D_INC ?= inc
TOP ?= ml505top

BUILDDIR := $(D_BLD)/$(TOP)

SHELL := bash
RSYNC := rsync -EXLAtg --verbose
TARGETS = all synth xst map par timing bitgen impact report schematic schem ise ngc ncd xdl printenv printvars clean
MAKEARGS := TOP=$(TOP) SRC=./_src INC=./_inc TEMPLATES=./_cfg

$(TARGETS): sync
	$(MAKE) -C $(BUILDDIR) $(MAKEARGS) $@ > >(tee -a $(BUILDDIR)/log.out) 2> >(tee -a $(BUILDDIR)/log.err)

sync:
	mkdir -p $(BUILDDIR)
	$(RSYNC) --recursive --delete $(D_CFG)/ $(BUILDDIR)/_cfg
	$(RSYNC) --recursive --delete $(D_SRC)/ $(BUILDDIR)/_src
	$(RSYNC) --dirs      --delete $(D_INC)/ $(BUILDDIR)/_inc
	ln -sf -t $(BUILDDIR) _cfg/Makefile

cleaner:
	rm -rf $(BUILDDIR)

cleanest: cleaner
	rm -rf $(D_BLD)

.PHONY := $(TARGETS) sync cleaner cleanest
