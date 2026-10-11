# Runs tb_roms and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_roms.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root mem *.mem]]
add_files -quiet -fileset sources_1 [glob [file join $root mem *.mem]]
set_property top tb_roms [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_roms/clk
add_wave -radix unsigned /tb_roms/weight_address
add_wave -radix hex /tb_roms/weight_data
add_wave -radix unsigned /tb_roms/bias_address
add_wave -radix hex /tb_roms/bias_data
add_wave -radix unsigned /tb_roms/embed_address
add_wave -radix hex /tb_roms/embed_data

restart
run all
wave_zoom_full
