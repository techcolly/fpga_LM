# Runs tb_inference_fsm and opens the timing diagram.
# In the Vivado Tcl console:  source C:/Users/techcolly/Desktop/fpga_LM/vivado/sim_fsm.tcl   (project must already be open)

set_property top tb_inference_fsm [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
catch {close_sim -force}
launch_simulation

add_wave_divider {control}
add_wave /tb_inference_fsm/clk /tb_inference_fsm/reset /tb_inference_fsm/start
add_wave /tb_inference_fsm/state_name
add_wave_divider {outputs}
add_wave /tb_inference_fsm/input_vector_we /tb_inference_fsm/load_bias /tb_inference_fsm/accumulate_en
add_wave /tb_inference_fsm/hidden_we /tb_inference_fsm/compare_en /tb_inference_fsm/argmax_clear /tb_inference_fsm/done
add_wave_divider {counters}
add_wave -radix unsigned /tb_inference_fsm/token_index /tb_inference_fsm/group_index /tb_inference_fsm/input_index
add_wave -radix unsigned /tb_inference_fsm/lane_index /tb_inference_fsm/weight_address /tb_inference_fsm/bias_address
add_wave /tb_inference_fsm/output_layer

restart
run all
wave_zoom_full
