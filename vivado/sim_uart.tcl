# Runs tb_uart and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_uart.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_uart [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_uart/clk
add_wave_divider {receiver test}
add_wave /tb_uart/rx_line /tb_uart/rx_valid
add_wave -radix hex /tb_uart/rx_data
add_wave_divider {transmitter test}
add_wave /tb_uart/send /tb_uart/tx_line /tb_uart/tx_busy
add_wave -radix hex /tb_uart/tx_data
add_wave_divider {loopback}
add_wave /tb_uart/loop_send /tb_uart/loop_line /tb_uart/loop_valid
add_wave -radix hex /tb_uart/loop_send_data /tb_uart/loop_data

restart
run all
wave_zoom_full
