
SUBS ?= $(shell find * -mindepth 1 -maxdepth 1 -name "Makefile" -printf '%h ')
DEPS ?= gios bios150v3
NON-DEPS ?= $(filter-out $(DEPS),$(SUBS))
CLEANERS ?= $(SUBS:%=CLEAN-%)

.PHONY: all clean $(SUBS) $(CLEANERS)


all: $(SUBS)
	@echo ""
	@echo "====================================="
	@echo "DONE: $@ ($^)"
	@echo "====================================="

$(SUBS):
	@echo ""
	@echo "---------------- $@ ----------------"
	$(MAKE) -C $@ $(MAKECMDGOALS)
	@echo "-------------------------------------"
	@echo ""

$(NON-DEPS): $(DEPS)

clean: $(CLEANERS)
	@echo ""
	@echo "====================================="
	@echo "DONE: $@ ($^)"
	@echo "====================================="

$(CLEANERS):
	@echo ""
	@echo "---------------- $@ ----------------"
	@#echo "CLEANER: $(@:CLEAN-%=%)"
	$(MAKE) -C $(@:CLEAN-%=%) clean
	@echo "-------------------------------------"
	@echo ""

