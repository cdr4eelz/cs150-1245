# Icarus Verilog test rig (see README.md).
#
#   make [all]          run every test in tests/*.mk, print a summary, fail if any failed
#   make <test>         run one test, e.g. `make prng32lfsr`
#   make list           list tests
#   make clean          remove build/
#   WAVES=1             also dump build/<test>/<test>.vcd
#   DEFINES="A B=1"     extra `define`s for every compile (e.g. DEFINES=FORCE_FAIL)
#   PLUSARGS="+n=10"    extra vvp plusargs

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
DEFINES  ?=
PLUSARGS ?=
WAVES    ?=

TESTS := $(sort $(basename $(notdir $(wildcard tests/*.mk))))
include $(wildcard tests/*.mk)

# A test passes when vvp exits 0, the log has a line starting with "PASS",
# and nothing matches FAIL_RE.
PASS_RE ?= ^PASS
FAIL_RE ?= ERRORS: [1-9]|FAIL

.PHONY: all list clean $(TESTS)

all:
	@failed=(); \
	for t in $(TESTS); do \
	  $(MAKE) --no-print-directory $$t || failed+=($$t); \
	done; \
	echo "==================== sim-icarus summary ===================="; \
	for t in $(TESTS); do \
	  if [[ " $${failed[*]} " == *" $$t "* ]]; then echo "  FAIL  $$t   ($(BUILD)/$$t.log)"; \
	  else echo "  PASS  $$t   ($(BUILD)/$$t.log)"; fi; \
	done; \
	echo "  $$(( $(words $(TESTS)) - $${#failed[@]} ))/$(words $(TESTS)) passed"; \
	[ $${#failed[@]} -eq 0 ]

list:
	@$(foreach t,$(TESTS),printf '  %-20s top=%s  tb=%s\n' '$(t)' '$($(t).TOP)' '$($(t).TB)';)

clean:
	rm -rf $(BUILD)

# ---- per-test rule template -------------------------------------------------
# $(1) = test name; uses $(1).TOP $(1).TB $(1).SRCS $(1).INCS $(1).DEFS $(1).PLUSARGS
define TEST_template
$(1): $(BUILD)/$(1)/$(1).vvp
	@echo "---- $(1): running $$($(1).TOP) ----"
	@cd $(BUILD)/$(1) && \
	  timeout $(TIMEOUT) $(VVP) -n $(1).vvp $$($(1).PLUSARGS) $(PLUSARGS) \
	    $(if $(WAVES),+vcd=$(1).vcd) 2>&1 | tee ../$(1).log; \
	  st=$$$$?; \
	  if [ $$$$st -ne 0 ]; then echo "SIM-ICARUS FAIL: $(1) (vvp exit $$$$st)"; exit 1; fi; \
	  if grep -Eq '$(FAIL_RE)' ../$(1).log; then echo "SIM-ICARUS FAIL: $(1) (log matches '$(FAIL_RE)')"; exit 1; fi; \
	  if ! grep -Eq '$(PASS_RE)' ../$(1).log; then echo "SIM-ICARUS FAIL: $(1) (no PASS line in log)"; exit 1; fi; \
	  echo "SIM-ICARUS PASS: $(1)"

$(BUILD)/$(1)/$(1).vvp: $$($(1).TB) $$($(1).SRCS) tests/$(1).mk $(BUILD)/$(1)/flags
	@mkdir -p $(BUILD)/$(1)
	$(IVERILOG) $(STD) $(IFLAGS) $(WFLAGS) -s $$($(1).TOP) \
	  $$(addprefix -I,$$($(1).INCS)) $$(addprefix -D,$$($(1).DEFS) $(DEFINES)) \
	  -o $$@ $$($(1).TB) $$($(1).SRCS) 2>&1 | tee $(BUILD)/$(1)/compile.log

# Rebuild when compile-affecting knobs change (e.g. DEFINES=FORCE_FAIL).
$(BUILD)/$(1)/flags: FORCE_CHECK
	@mkdir -p $(BUILD)/$(1)
	@echo '$(IVERILOG) $(STD) $(IFLAGS) $(WFLAGS) $$($(1).DEFS) $(DEFINES)' > $$@.new; \
	 cmp -s $$@.new $$@ && rm -f $$@.new || mv -f $$@.new $$@
endef

.PHONY: FORCE_CHECK
FORCE_CHECK:

$(foreach t,$(TESTS),$(eval $(call TEST_template,$(t))))
