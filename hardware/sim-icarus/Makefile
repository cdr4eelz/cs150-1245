# Icarus Verilog test rig (see README.md).
#
#   make [all]          run every test in tests/*.mk (except SKIP ones), print a summary,
#                       exit nonzero if any test FAILed (or XPASSed)
#   make <test>         run one test, e.g. `make prng32lfsr` (SKIP is ignored when named)
#   make list           list tests
#   make clean          remove build/
#   WAVES=1             also dump build/<test>/<test>.vcd (testbenches that honor +vcd=<file>)
#   DEFINES="A B=1"     extra `define`s for every compile (e.g. DEFINES=FORCE_FAIL)
#   PLUSARGS="+n=10"    extra vvp plusargs
#   RUN_SKIPPED=1       make all also runs tests marked SKIP
#   make hex            rebuild tb/data/*.hex from the .s sources

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := all

IVERILOG ?= iverilog
VVP      ?= vvp
STD      ?= -g2005
# -Wtimescale is off: most repo sources (e.g. base_util/*.v) have no `timescale.
WFLAGS   ?= -Wall -Wno-timescale
IFLAGS   ?= -grelative-include
TIMEOUT  ?= 600
BUILD    := build
SRC      := ../src
TBSRC    := $(SRC)/testbench
# Library dirs for tests that let iverilog find modules by file name (<name>.YDIRS := $(SRC_YDIRS))
SRC_YDIRS := $(addprefix $(SRC)/,. cpu innerds base_util base_io base_mem gpu base_vid cross)
DEFINES  ?=
PLUSARGS ?=
WAVES    ?=
RUN_SKIPPED ?=

# Defaults for the per-test judging knobs (override per test as <name>.PASS_RE etc.)
PASS_RE ?= ^PASS
FAIL_RE ?= ERRORS: [1-9]|FAIL

TESTS := $(sort $(basename $(notdir $(wildcard tests/*.mk))))
include $(wildcard tests/*.mk)

# per-test value with fallback: $(call tv,<test>,<VAR>,<default>)
tv = $(if $(filter undefined,$(origin $(1).$(2))),$(3),$($(1).$(2)))

RUN_TESTS := $(if $(RUN_SKIPPED),$(TESTS),$(foreach t,$(TESTS),$(if $(strip $($(t).SKIP)),,$(t))))
SKIPPED   := $(filter-out $(RUN_TESTS),$(TESTS))

.PHONY: all list clean hex $(TESTS)

# Regenerate tb/data/*.hex from tb/data/*.s (needs mips-linux-gnu-as; the .hex files are checked in)
hex:
	$(MAKE) -C tb/data

all:
	@rm -f $(addprefix $(BUILD)/,$(addsuffix .status,$(TESTS)))
	@for t in $(RUN_TESTS); do $(MAKE) --no-print-directory $$t; done; \
	echo "==================== sim-icarus summary ===================="; \
	bad=0; np=0; \
	for t in $(RUN_TESTS); do \
	  s=$$(cat $(BUILD)/$$t.status 2>/dev/null || echo FAIL); \
	  printf '  %-6s %-24s %s\n' $$s $$t "$(BUILD)/$$t.log"; \
	  case $$s in PASS|XFAIL) np=$$((np+1));; *) bad=$$((bad+1));; esac; \
	done; \
	$(foreach t,$(SKIPPED),printf '  %-6s %-24s %s\n' SKIP $(t) '$(strip $($(t).SKIP))';) \
	echo "  $$np/$(words $(RUN_TESTS)) ok (PASS or expected XFAIL), $$bad failed, $(words $(SKIPPED)) skipped"; \
	[ $$bad -eq 0 ]

list:
	@$(foreach t,$(TESTS),printf '  %-24s %-28s %s\n' '$(t)' '$($(t).TOP)' '$(if $($(t).SKIP),[SKIP] )$(if $($(t).XFAIL),[XFAIL] )$($(t).TB)';)

clean:
	rm -rf $(BUILD)

# ---- per-test rule template -------------------------------------------------
# Per-test variables (tests/<name>.mk), all optional except TOP and TB:
#   TOP TB SRCS INCS DEFS PLUSARGS     what to compile / how to run
#   YDIRS     -y library dirs (modules found by file name)
#   RUNFILES  files copied into build/<name>/ (the sim's working dir) before running
#   PASS_RE FAIL_RE   judging regexes (defaults above); FAIL_RE may be empty
#   QUIET_RE  log lines matching this are dropped (counted) - for known noise
#   XFAIL     reason: test is expected to fail (known bug); XFAIL is ok, XPASS fails
#   SKIP      reason: not run by `make all` unless RUN_SKIPPED=1
#   TIMEOUT   wall-clock seconds
#   WFLAGS    iverilog warning flags (default $(WFLAGS))
define TEST_template
$(1): $(BUILD)/$(1)/$(1).vvp $$($(1).RUNFILES)
	@echo "---- $(1): running $$($(1).TOP) ----"
	@VVP='$(VVP)' TIMEOUT='$(call tv,$(1),TIMEOUT,$(TIMEOUT))' \
	 PLUSARGS='$$($(1).PLUSARGS) $(PLUSARGS) $(if $(WAVES),+vcd=$(1).vcd)' \
	 PASS_RE='$(call tv,$(1),PASS_RE,$(PASS_RE))' FAIL_RE='$(call tv,$(1),FAIL_RE,$(FAIL_RE))' \
	 QUIET_RE='$$($(1).QUIET_RE)' RUNFILES='$$($(1).RUNFILES)' XFAIL='$$(strip $$($(1).XFAIL))' \
	 scripts/run-test.sh $(1) $(BUILD)

$(BUILD)/$(1)/$(1).vvp: $$($(1).TB) $$($(1).SRCS) tests/$(1).mk $(BUILD)/$(1)/flags
	@mkdir -p $(BUILD)/$(1)
	$(IVERILOG) $(STD) $(IFLAGS) $(call tv,$(1),WFLAGS,$(WFLAGS)) -s $$($(1).TOP) \
	  $$(addprefix -I,$$($(1).INCS)) $$(addprefix -y ,$$($(1).YDIRS)) $$(if $$($(1).YDIRS),-Y .v) \
	  $$(addprefix -D,$$($(1).DEFS) $(DEFINES)) \
	  -o $$@ $$($(1).TB) $$($(1).SRCS) 2>&1 | tee $(BUILD)/$(1)/compile.log

# Rebuild when compile-affecting knobs change (e.g. DEFINES=FORCE_FAIL).
$(BUILD)/$(1)/flags: FORCE_CHECK
	@mkdir -p $(BUILD)/$(1)
	@echo '$(IVERILOG) $(STD) $(IFLAGS) $(call tv,$(1),WFLAGS,$(WFLAGS)) $$($(1).DEFS) $(DEFINES)' > $$@.new; \
	 cmp -s $$@.new $$@ && rm -f $$@.new || mv -f $$@.new $$@
endef

.PHONY: FORCE_CHECK
FORCE_CHECK:

$(foreach t,$(TESTS),$(eval $(call TEST_template,$(t))))
