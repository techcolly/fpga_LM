# Runs tb_activation_path and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_activation_path.tcl   (project must already be open)

set root [file normalize [file join [file dirname [info script]] ..]]

add_files -quiet -fileset sources_1 [glob [file join $root rtl * *.sv]]
add_files -quiet -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top tb_activation_path [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave /tb_activation_path/clk /tb_activation_path/input_vector_we /tb_activation_path/hidden_we
add_wave -radix unsigned /tb_activation_path/token_index /tb_activation_path/group_index /tb_activation_path/input_index
add_wave -radix hex /tb_activation_path/embed_data /tb_activation_path/hidden_word
add_wave /tb_activation_path/output_layer
add_wave -radix decimal /tb_activation_path/input_activation /tb_activation_path/hidden_activation /tb_activation_path/activation

restart
run all
wave_zoom_full
