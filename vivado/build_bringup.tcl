# Builds the bring-up bitstream with no Vivado project: synthesis, place, route, reports, bitstream.
# Run from a terminal:  vivado -mode batch -source C:/Users/techcolly/Desktop/fpga_LM/vivado/build_bringup.tcl
# Output goes to vivado/build_bringup/ (bringup_top.bit, timing.rpt, utilization.rpt).
# If you run it inside the Vivado GUI Tcl console, run close_project first (non-project commands need no project open).

set root [file normalize [file join [file dirname [info script]] ..]]
set out  [file join $root vivado build_bringup]
file mkdir $out

read_verilog -sv [file join $root rtl uart uart_rx.sv]
read_verilog -sv [file join $root rtl uart uart_tx.sv]
read_verilog -sv [file join $root rtl top bringup_top.sv]
read_xdc [file join $root constraints bringup bringup.xdc]

synth_design -top bringup_top -part xc7a100tcsg324-1
opt_design
place_design
route_design

report_timing_summary -file [file join $out timing.rpt]
report_utilization    -file [file join $out utilization.rpt]
write_bitstream -force [file join $out bringup_top.bit]

puts "bitstream written to [file join $out bringup_top.bit]"
