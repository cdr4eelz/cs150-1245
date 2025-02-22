source ../target.tcl

# Read Verilog source files
if {[string trim ${RTL}] ne ""} {
  read_verilog ${VERBOSE} -sv ${RTL}
}

# Read VHD source files
if {[string trim ${RTL_VHD}] ne ""} {
  read_vhdl ${VERBOSE} ${RTL_VHD}
}

# Read user constraints
if {[string trim ${CONSTRAINTS}] ne ""} {
  read_xdc ${VERBOSE} ${CONSTRAINTS}
}

## Read user IP files/archives (SHOULD LOOP THROUGH EACH ONE???)
if {[string trim ${IP_XCI}] ne ""} {
    read_ip ${VERBOSE} ${IP_XCI}
}


synth_design -name "script_synth" -part ${FPGA_PART} -top ${TOP} \
  -flatten_hierarchy full -directive default ${VERBOSE} \
  -verilog_define SYNTHESIS -verilog_define ABS_TOP=${ABS_TOP} \
  -include_dirs { ${ABS_TOP}/src ${ABS_TOP}/gen }
  
## -constrset worth specifying ${CONSTRAINTS} inside a fileset?

write_checkpoint -force ${TOP}.dcp
report_timing_summary -file post_synth_timing_summary.rpt
report_drc -file post_synth_drc.rpt
report_utilization -file post_synth_utilization.rpt
write_verilog -force -file post_synth.v
write_xdc -force -file post_synth.xdc
