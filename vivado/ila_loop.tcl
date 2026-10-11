# Re-arms the ILA after every capture so the waveform updates for each request.
# With the board programmed and the ILA dashboard open, in the Vivado Tcl console:
#   source C:/Users/techcolly/Desktop/fpga_LM/vivado/ila_loop.tcl
# Stop it with Ctrl+C in the Tcl console. 1 sample = 10 ns (the ILA runs on the 100 MHz clock).
# If it says the start probe was not found, run  get_hw_probes  and change the filter below.

set ila [lindex [get_hw_ilas] 0]
set start_probe [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*start*"}] 0]

set_property TRIGGER_COMPARE_VALUE eq1'bR $start_probe
set_property CONTROL.TRIGGER_POSITION 50 $ila

# show the counters and the state number in decimal (ignored if this Vivado version names the property differently)
foreach pattern {*state* *input_index* *weight_address* *group_index* *lane_index* *best_index*} {
    catch {set_property DISPLAY_RADIX UNSIGNED [get_hw_probes -of_objects $ila -filter "NAME =~ $pattern"]}
}

puts "ILA armed on a rising edge of $start_probe; waiting for requests (Ctrl+C to stop)"
while {1} {
    run_hw_ila $ila
    wait_on_hw_ila $ila
    display_hw_ila_data [upload_hw_ila_data $ila]
}
