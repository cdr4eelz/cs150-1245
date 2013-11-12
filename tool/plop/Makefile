# Convenient invocation of xps tasks (mostly through XPS makefiles)

PLATS ?= plop505top

PLAT_B ?= plop
PLAT_D ?= plat
EXPORT_D ?= export
STASH_D ?= stash

PASSTHRU_T ?= exporttosdk netlist bits download ace init_bram simmodel sim clean netlistclean bitsclean simclean hwclean all

PROJ_T = $(PLATS:%=$(PLAT_D)/%.xmp) $(PLATS:%=$(PLAT_D)/%.make)

export XIL_MAXLINEWIDTH=120

default: all #"all" just lists XPS makefile options (though XPS project created if needed)

#.DEFAULT: #Default & match-all seem like overkill (and need extra checks plus PHONY is tougher)
$(PASSTHRU_T): xmp
	for P in $(PLATS); do \
	  $(MAKE) -C "$(PLAT_D)" -f "$${P}.make" "$@" |tee -a "$${P}.log" ;\
	done

#Not needed unless something tampers with XMP in unusual way
$(PLAT_D)/%.make: $(PLAT_D)/%.xmp
	cd "$(PLAT_D)" && echo -e "save make\nexit" |xps -nw "$*.xmp" |tee -a "$*.log"
	touch "$@" -r $^ #Maybe $<??? Project .make is direcly based on .xmp

$(PLAT_D)/%.strap: $(PLAT_D)/%.mhs $(PLAT_D)/%.ucf
	$(error Project MHS/UCF files have become newer, please resolve manually)

$(PLAT_D)/%.xmp: strap_%.tcl $(PLAT_B).mhs $(PLAT_B).ucf | $(PLAT_D)
	-mkdir "$(PLAT_D)/$*.old" #Try to preserve key old files just in case
	-mv "$(PLAT_D)/$*.xmp" "$(PLAT_D)/$*.mhs" "$(PLAT_D)/$*.ucf" "$(PLAT_D)/$*.old"
	cd "$(PLAT_D)" && xps -nw -scr "../strap_$*.tcl" |tee "$*.log" #Fresh log
	#Figure newest mod date of strap prerequesites (remember it & make XMP match)
	touch "$(PLAT_D)/$*.strap" -r `stat --terse --format="%Y %n" $^ | sort --reverse | cut --delimiter=" " --fields=2`
	touch "$@" "$(PLAT_D)/$*.make" -r "$(PLAT_D)/$*.strap"

$(PLAT_D):
	mkdir -p "$(PLAT_D)"

# Paranoid intermediary file preservation (explicitly known & pattern matched references)
.PRECIOUS: $(PROJ_T) $(PLAT_D) $(PLAT_D)/%.make $(PLAT_D)/%.xmp
.SECONDARY: #Supposedly inhibits deletion?
.SUFFIX:

xmp: $(PROJ_T)

stash: exporttosdk #Just depend on system.xml & couple key items instead
	#ENV: STASH_D, EXPORT_D, PLAT_D
	#ARG: PLAT_B, PLAT(s)
	mkdir -p "$(STASH_D)"
	for P in $(PLATS); do                                   \
	  echo "PLAT: $${P}"                                    ;\
	    PX_D="$(EXPORT_D)/$${P}"                             ;\
	    PS_N="$(PLAT_B)_$${P}"                                ;\
	    PS_D="$${PX_D}/$${PS_N}"                               ;\
	    PP_IMP="$(PLAT_D)/implementation/$${P}"                 ;\
	    PP_HDL="$(PLAT_D)/hdl/$${P}"                             ;\
	  echo "Stash \"$${P}\" into \"$${PS_D}\":"                   ;\
	    mkdir -p "$${PS_D}" && rm -rf "$${PS_D}/*"                 ;\
	    cp --recursive --target-directory="$${PS_D}/"                \
	      $${PP_IMP}_*.ngc  $${PP_IMP}_*.ncf  $${PP_HDL}_*            \
	      $${PP_IMP}.ngc  $${PP_IMP}.ucf  $${PP_IMP}.pcf  $${PP_HDL}.* \
	      $${PP_IMP}_stub.bmm  $${PX_D}/hw/$${P}.xml  $${P}.log       ;\
	  echo "Archive w/stub:"                                          ;\
	    tar --exclude="*/$${P}.v" --directory="$${PX_D}"               \
		-cvjf $(STASH_D)/$${PS_N}_stub.tar.bz2 $${PS_N}           ;\
	  echo "Archive wo/stub:"                                         ;\
	    tar --exclude="*/$${P}_stub.v" --directory="$${PX_D}"          \
		-cvjf $(STASH_D)/$${PS_N}.tar.bz2 $${PS_N}                ;\
	done
	-cd "$(STASH_D)" && ls -alh . && md5sum $(PLATS:%=$(PLAT_B)_%[._]*)

cleaner:
	for P in $(PLATS); do \
	  rm -rf "$(PLAT_D)/$${P}.*" "$(EXPORT_D)/$${P}" "$${P}.log" ;\
	done

cleanerer:
	rm -rf "$(PLAT_D)" "$(EXPORT_D)" "*.log"

.PHONY: $(PASSTHRU_T) cleaner cleanerer xmp stash 
