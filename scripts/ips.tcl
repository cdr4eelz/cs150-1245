source ../target.tcl

create_project ${VERBOSE} -in_memory -ip -part "xc7a100tcsg324-1" "temp_proj"
set project_obj [get_projects "temp_proj"]
set_property "part"               "xc7a100tcsg324-1"                      $project_obj
set_property "board_part"         "digilentinc.com:arty-a7-100:part0:1.1" $project_obj
set_property "default_lib"        "xil_defaultlib"                        $project_obj
set_property "simulator_language" "Mixed"                                 $project_obj
set_property "target_language"    "Verilog"                               $project_obj
# CORE CONTAINERS hold generated IP files in zip archive. Difficult outside Vivado.
set_property coreContainer.enable 0                                       $project_obj
set_property DESIGN_MODE RTL [current_fileset]

read_ip ${VERBOSE} ...
#set_property GENERATE_SYNTH_CHECKPOINT 1 \
#[get_files ...hardware/src/ip/clk_wiz_0/clk_wiz_0/clk_wiz_0.xci]
# This file is inside the zip (.xcix) archive. Auto adjust file (xcix=>xci).
# Use name of .xcix archive file (clk_wiz_0) as if it is a directory.
#generate_target ${VERBOSE} all [get_ips]
#synth_ip ${VERBOSE} [get_ips]
