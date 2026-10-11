# Replays the golden vectors (Python reference) through fpga_top with the real weights.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_fpga_golden.tcl   (project must already be open)
# Regenerate the .mem files first if the checkpoint changed:  python -m langModel.export_mem   (run from the repo root)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root mem *.mem]]
add_files -quiet -fileset sources_1 [glob [file join $root mem *.mem]]
set_property top tb_fpga_golden [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_fpga_golden/clk /tb_fpga_golden/uart_txd_in /tb_fpga_golden/uart_rxd_out
add_wave -radix unsigned /tb_fpga_golden/led
add_wave /tb_fpga_golden/dut/start /tb_fpga_golden/dut/done
add_wave -radix unsigned /tb_fpga_golden/dut/fsm_unit/state
add_wave -radix unsigned /tb_fpga_golden/dut/best_index

restart
run all
