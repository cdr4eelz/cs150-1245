
SUBS ?= $(shell find * -mindepth 1 -maxdepth 1 -name "Makefile" -printf '%h ')
CLEANERS ?= $(SUBS:%=CLEAN-%)
TOUCHERS ?= $(SUBS:%=TOUCH-%)

.PHONY: all clean touch $(SUBS) $(CLEANERS) $(TOUCHERS)


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

touch: $(TOUCHERS)
	@echo ""
	@echo "====================================="
	@echo "DONE: $@ ($^)"
	@echo "====================================="

$(TOUCHERS):
	@echo ""
	@echo "---------------- $@ ----------------"
	@#echo "TOUCHERS: $(@:TOUCH-%=%)"
	$(MAKE) -C $(@:TOUCH-%=%) touch
	@echo "-------------------------------------"
	@echo ""

