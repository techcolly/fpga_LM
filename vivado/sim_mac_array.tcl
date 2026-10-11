# Runs tb_mac_array and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_mac_array.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_mac_array [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_mac_array/clk /tb_mac_array/load_bias /tb_mac_array/accumulate_en
add_wave -radix decimal /tb_mac_array/activation
add_wave -radix hex /tb_mac_array/weight_word /tb_mac_array/bias_word
add_wave_divider {lane accumulators}
foreach lane {0 1 2 3 4 5 6 7} {
    add_wave -radix decimal "/tb_mac_array/dut/lanes\[$lane\]/lane_unit/accumulator"
}
add_wave_divider {reference}
add_wave -radix decimal /tb_mac_array/expected_accumulator

restart
run all
wave_zoom_full
