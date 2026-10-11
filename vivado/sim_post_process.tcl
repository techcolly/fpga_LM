# Runs tb_post_process and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_post_process.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_post_process [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave -radix hex /tb_post_process/accumulator_word
add_wave -radix hex /tb_post_process/hidden_word
add_wave -radix decimal /tb_post_process/accumulator_values

restart
run all
wave_zoom_full
