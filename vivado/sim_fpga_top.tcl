# Runs tb_fpga_top (whole accelerator over the serial port) and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_fpga_top.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root mem *.mem]]
add_files -quiet -fileset sources_1 [glob [file join $root mem *.mem]]
set_property top tb_fpga_top [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_fpga_top/clk /tb_fpga_top/uart_txd_in /tb_fpga_top/uart_rxd_out
add_wave -radix unsigned /tb_fpga_top/led
add_wave_divider {request and control}
add_wave /tb_fpga_top/dut/rx_valid /tb_fpga_top/dut/start /tb_fpga_top/dut/done
add_wave -radix unsigned /tb_fpga_top/dut/fsm_unit/state
add_wave /tb_fpga_top/dut/output_layer
add_wave -radix unsigned /tb_fpga_top/dut/token_index /tb_fpga_top/dut/group_index /tb_fpga_top/dut/input_index /tb_fpga_top/dut/lane_index
add_wave -radix unsigned /tb_fpga_top/dut/weight_address /tb_fpga_top/dut/bias_address
add_wave_divider {datapath}
add_wave -radix decimal /tb_fpga_top/dut/activation
add_wave -radix hex /tb_fpga_top/dut/weight_word
add_wave -radix decimal /tb_fpga_top/dut/best_value
add_wave -radix unsigned /tb_fpga_top/dut/best_index

restart
run all
wave_zoom_full
