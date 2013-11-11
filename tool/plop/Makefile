# Convenient invocation of xps tasks (mostly through it's makefiles)

PLATS ?= ml505top ml505sub
PLAT_D ?= ./plat
EXPORT_D ?= ./export

default: simmodel

#define pass-thru =
#echo $@
#echo $(PLATS:%=PASS-%)
#endef
#echo '$(foreach PASS,$(PASSTHRU),$(PASS): $$(PLATS:%=$(PASS)-%))'
#$(eval ...)

# PLATless invocations (expand to default PLATs)
exporttosdk: $(PLATS:%=exporttosdk-%)
netlist: $(PLATS:%=simmodel-%)
simmodel: $(PLATS:%=simmodel-%)
clean: $(PLATS:%=clean-%)
cleaner: $(PLATS:%=cleaner-%)

exporttosdk-% netlist-% simmodel-% clean-%: $(PLAT_D)/%.make
	echo $(subst -$*,,$@) $*

#$(PLAT_D)/%.mhs $(PLAT_D)/%.ucf: 

$(PLAT_D)/%.make: $(PLAT_D)/%.xmp
	( cd $(PLAT_D) && echo -e "save make\nexit" |xps -nw $*.xmp )

$(PLAT_D)/%.xmp: strap_%.tcl | $(PLAT_D)
	( cd $(PLAT_D) && xps -nw -scr ../strap_$*.tcl )

$(PLAT_D):
	mkdir -p $(PLAT_D)

.PRECIOUS: $(PLAT_D)/%.make $(PLAT_D)/%.xmp
.SECONDARY:
.DEFAULT:
FORCE: 

cleaner-%: FORCE
	rm -rf $(EXPORT_D)/$* $(PLAT_D)/$*.*

cleanerer: FORCE
	rm -rf $(PLAT_D) $(EXPORT_D)
