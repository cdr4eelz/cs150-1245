
SUBS ?= $(shell find * -mindepth 1 -maxdepth 1 -name "Makefile" -printf '%h ')
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

