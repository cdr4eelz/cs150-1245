#D_BLD ?= /scratch/q_build_$(USER)
#D_CFG ?= q_cfg
D_BLD ?= build
D_CFG ?= cfg
D_SRC ?= src
TOP ?= ml505top

BUILDDIR := $(D_BLD)/$(TOP)

SHELL := bash
RSYNC := rsync -ELAtg --verbose
TARGETS = all synth xst map par timing bitgen impact report schematic schem ise ngc ncd xdl printenv printvars clean
MAKEARGS := TOP=$(TOP) SRC=./_src TEMPLATES=./_cfg

$(TARGETS): sync
	$(MAKE) -C $(BUILDDIR) $(MAKEARGS) $@ > >(tee -a $(BUILDDIR)/log.out) 2> >(tee -a $(BUILDDIR)/log.err)

sync:
	mkdir -p $(BUILDDIR)
	$(RSYNC) --recursive --delete $(D_CFG)/ $(BUILDDIR)/_cfg
	$(RSYNC) --recursive --delete $(D_SRC)/ $(BUILDDIR)/_src
	ln -sf _cfg/Makefile $(BUILDDIR)/Makefile

cleaner:
	rm -rf $(BUILDDIR)

cleanest:
	rm -rf $(D_BLD)

cleanerer:
	-rm -rf build /scratch/*
	ls ./ /scratch

.PHONY := $(TARGETS) sync cleaner cleanest cleanerer
