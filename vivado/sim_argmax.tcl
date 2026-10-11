# Runs tb_argmax and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_argmax.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_argmax [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_argmax/clk /tb_argmax/argmax_clear /tb_argmax/compare_en
add_wave -radix unsigned /tb_argmax/group_index /tb_argmax/lane_index
add_wave -radix decimal /tb_argmax/dut/logit /tb_argmax/best_value
add_wave -radix unsigned /tb_argmax/best_index

restart
puts "running tb_argmax until \$finish"
run all
puts "simulation stopped at [current_time]"
wave_zoom_full
