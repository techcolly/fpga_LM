# Runs tb_mac_lane and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_mac_lane.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_mac_lane [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_mac_lane/clk /tb_mac_lane/load_bias /tb_mac_lane/accumulate_en
add_wave -radix decimal /tb_mac_lane/activation /tb_mac_lane/weight /tb_mac_lane/bias
add_wave -radix decimal /tb_mac_lane/accumulator /tb_mac_lane/expected_value

restart
run all
wave_zoom_full
