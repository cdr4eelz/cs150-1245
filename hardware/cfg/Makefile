# TOP, SRC, TEMPLATES are passed in
XST_DEFS ?= 
SRCS := $(shell find $(SRC) -type f -name '*.v')
UCF := $(wildcard $(SRC)/$(TOP).ucf)

PART := xc5vlx110t-ff1136-1

default: all

#XST
XST_TMPDIR := xst/tmp
XST_PRJ := $(TOP).prj
XST_BATCH := $(TOP).xst
XST_OUT := $(TOP).ngc

$(XST_PRJ): $(SRCS) | $(XST_TMPDIR)
	for src in $(SRCS); do\
		echo "verilog work \"$$src\"";\
	done > $@

$(XST_TMPDIR):
	mkdir -p $@

$(XST_BATCH): $(TEMPLATES)/xst.batch $(XST_PRJ)
	sed -e "s/##TOPMODULE##/$(TOP)/g" -e "s/##XSTDEFINES##/$(XST_DEFS)/g" < $< > $@

$(XST_OUT): $(XST_BATCH)
	xst -ifn $(TOP).xst -ofn $(TOP).syr

synth xst: $(XST_OUT)


#NGDBUILD
NGDBUILD_OUT := $(TOP).ngd
UCF_FLAG := $(if $(UCF),-uc $(UCF))
NGC_DIRS := $(shell find $(SRC) -type d -exec echo -n "-sd {} " \;)

$(NGDBUILD_OUT): $(XST_OUT) $(UCF)
	ngdbuild -dd _ngo $(NGC_DIRS) -nt timestamp $(UCF_FLAG) -p $(PART) $(XST_OUT) $@

ngc trans: $(NGDBUILD_OUT)


#MAP
MAP_OUT := $(TOP)_map.ncd
MAP_OPTS := $(shell cat $(TEMPLATES)/map.opts | tr '\n' ' ')

$(MAP_OUT) : $(NGDBUILD_OUT)
	map $(MAP_OPTS) -p $(PART) -o $@ $< $(TOP).pcf

map: $(MAP_OUT)

#PAR
PAR_OUT := $(TOP).ncd
PAR_OPTS := $(shell cat $(TEMPLATES)/par.opts | tr '\n' ' ')

$(PAR_OUT): $(MAP_OUT)
	par $(PAR_OPTS) $(MAP_OUT) $@ $(TOP).pcf

par: $(PAR_OUT)

#NCD
ncd: $(TOP)_map.ncd $(TOP).ncd

#XDL
xdl: $(TOP)_map.xdl $(TOP).ncd

%.xdl: %.ncd
	xdl -ncd2xdl $< $@


#TRCE
TCRE_OUT := $(TOP).twr

$(TCRE_OUT): $(PAR_OUT)
	trce -v 3 -s 1 -n 10 -fastpaths -xml $(TOP).twx $< -o $(TCRE_OUT) $(TOP).pcf

timing: $(TCRE_OUT)

#BITGEN
BITFILE := $(TOP).bit

$(BITFILE): $(PAR_OUT)
	bitgen -w -l $< $@ $(TOP).pcf

bitgen: $(BITFILE)

#IMPACT
IMPACT_BATCH := impact.batch

$(IMPACT_BATCH): $(TEMPLATES)/impact.batch
	sed "s/##BITFILE##/$(BITFILE)/" < $< > $@

impact: $(BITGEN_BIT) $(IMPACT_BATCH)
	impact -batch $(IMPACT_BATCH)

#MISC
report:
	xreport $(TOP) &

schematic schem ise:
	ise &

all: $(BITFILE) timing

.PHONY = all synth xst map par timing bitgen impact report schematic schem ise clean ngc trans ncd xdl
