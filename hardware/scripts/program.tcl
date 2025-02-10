source ../target.tcl

open_hw
# Some versions have open_hw_manager & close_hw_manager below
connect_hw_server -url localhost:3121
current_hw_target [get_hw_targets */xilinx_tcf/Digilent/*]
set_property PARAM.FREQUENCY 15000000 [get_hw_targets */xilinx_tcf/Digilent/*]
open_hw_target

current_hw_device [get_hw_devices xc7*]
# "xc7z" above, removed the "z" since Arty-A7 has an "a"
set_property PROBES.FILE {} [get_hw_devices xc7*]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7*]

# Hack to expand ${ABS_TOP} and ${TOP} properly, running set_property directly doesn't expand these variables
set set_cmd "set_property PROGRAM.FILE \{${ABS_TOP}/build/impl/${TOP}.bit\} \[get_hw_devices xc7*\]"
eval ${set_cmd}
program_hw_devices [get_hw_devices xc7*]
refresh_hw_device [get_hw_devices xc7*]

disconnect_hw_server localhost:3121
close_hw


#start_gui
## open_hw
## set_property PROBES.FILE {} [get_hw_devices xc7a100t_0]
## set_property FULL_PROBES.FILE {} [get_hw_devices xc7a100t_0]
## set_property PROGRAM.FILE {/home/ejr/f2019/makeooc/hardware/build/impl/top_VGA.bit} [get_hw_devices xc7a100t_0]
## program_hw_devices [get_hw_devices xc7a100t_0]
#### INFO: [Labtools 27-3164] End of startup status: HIGH
## refresh_hw_device [lindex [get_hw_devices xc7a100t_0] 0]
#### INFO: [Labtools 27-1434] Device xc7a100t (JTAG device index = 0) is programmed with a design that has no supported debug core(s) in it.
## close_hw
