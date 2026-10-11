# Builds the Vivado project in vivado/proj from the files in rtl/, tb/, mem/ and constraints/.
# Run from anywhere:  vivado -mode batch -source C:/Users/techcolly/Desktop/fpga_LM/vivado/create_project.tcl
# or in the Vivado GUI: Tools > Run Tcl Script. Delete vivado/proj and rerun to start clean.

set root [file normalize [file join [file dirname [info script]] ..]]

create_project -force fpga_lm [file join $root vivado proj] -part xc7a100tcsg324-1

set rtl_files  [glob -nocomplain [file join $root rtl * *.sv]]
set tb_files   [glob -nocomplain [file join $root tb *.sv]]
set mem_files  [glob -nocomplain [file join $root mem *.mem]]
set xdc_files  [glob -nocomplain [file join $root constraints *.xdc]]

add_files -fileset sources_1 $rtl_files
if {[llength $mem_files] > 0} {add_files -fileset sources_1 $mem_files}
if {[llength $tb_files]  > 0} {add_files -fileset sim_1 $tb_files}
if {[llength $xdc_files] > 0} {add_files -fileset constrs_1 $xdc_files}

set_property top fpga_top [get_filesets sources_1]
set_property top tb_inference_fsm [get_filesets sim_1]
set_property -name xsim.simulate.runtime -value {-all} -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
