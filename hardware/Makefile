#D_BLD ?= /scratch/q_build_$(USER)
#D_CFG ?= q_cfg
D_BLD ?= build
D_CFG ?= cfg
D_SRC ?= src
TOP ?= ml505top

BUILDDIR := $(D_BLD)/$(TOP)

RSYNC := rsync -EXrLAtg --verbose
TARGETS = all synth xst map par timing bitgen impact report schematic schem ise ngc ncd xdl printenv printvars
MAKEARGS := TOP=$(TOP) SRC=./_src TEMPLATES=./_cfg

$(TARGETS): sync
	$(MAKE) -C $(BUILDDIR) $(MAKEARGS) $@ | tee -a $(BUILDDIR)/log.out

sync:
	mkdir -p $(BUILDDIR)
	$(RSYNC) --delete $(D_CFG)/ $(BUILDDIR)/_cfg
	$(RSYNC) --delete $(D_SRC)/ $(BUILDDIR)/_src
	ln -sf -t $(BUILDDIR) _cfg/Makefile

clean:
	rm -rf $(BUILDDIR)

.PHONY := $(TARGETS) clean sync
