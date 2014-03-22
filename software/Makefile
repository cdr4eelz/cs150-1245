
SUBS ?= $(shell find * -mindepth 1 -maxdepth 1 -name "Makefile" -printf '%h ')

.PHONY: all clean $(SUBS)

all clean: $(SUBS)
	echo $(SUBS)
	echo $@

$(SUBS):
	@echo ""
	$(MAKE) -C $@ $(MAKECMDGOALS)
	@echo ""
