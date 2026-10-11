# Runs tb_request_collector and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_request_collector.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_request_collector [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_request_collector/clk /tb_request_collector/rx_valid /tb_request_collector/busy /tb_request_collector/start
add_wave -radix unsigned /tb_request_collector/rx_data /tb_request_collector/token_index /tb_request_collector/embed_address
add_wave -radix unsigned /tb_request_collector/dut/byte_count

restart
run all
wave_zoom_full
