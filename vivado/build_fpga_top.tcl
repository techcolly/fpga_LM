# Builds the real accelerator bitstream with the ILA and VIO debug cores, the real weights from mem/, and no Vivado project.
# Run from a terminal:  vivado -mode batch -source C:/Users/techcolly/Desktop/fpga_LM/vivado/build_fpga_top.tcl
# Output goes to vivado/build_fpga_top/ (fpga_top.bit, fpga_top.ltx, timing.rpt, utilization.rpt).
# Inside the Vivado GUI Tcl console, run close_project first (non-project commands need no project open).
# Regenerate the .mem files first if the checkpoint changed:  python -m langModel.export_mem   (run from the repo root)

set root    [file normalize [file join [file dirname [info script]] ..]]
set mem_dir [file join $root mem]
set out     [file join $root vivado build_fpga_top]
set ip_dir  [file join $out ip]
set part    xc7a100tcsg324-1
file mkdir $out
file mkdir $ip_dir

foreach name {weight_rom.mem bias_rom.mem embed_rom.mem} {
    if {![file exists [file join $mem_dir $name]]} {
        error "missing $name in $mem_dir: run  python -m langModel.export_mem  from the repo root"
    }
}

create_project -in_memory -part $part

# VIO: 3 inputs (last token 6 bits, inference count 8 bits, FSM state 4 bits) and 2 outputs (4 tokens x 6 bits, go)
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0 -dir $ip_dir
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {3} \
    CONFIG.C_NUM_PROBE_OUT {2} \
    CONFIG.C_PROBE_IN0_WIDTH {6} \
    CONFIG.C_PROBE_IN1_WIDTH {8} \
    CONFIG.C_PROBE_IN2_WIDTH {4} \
    CONFIG.C_PROBE_OUT0_WIDTH {24} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x000000} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
] [get_ips vio_0]

# ILA: 12 probes, 2048 samples (one inference is 869 clock cycles)
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0 -dir $ip_dir
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {12} \
    CONFIG.C_DATA_DEPTH {2048} \
    CONFIG.C_PROBE0_WIDTH {4} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {10} \
    CONFIG.C_PROBE3_WIDTH {5} \
    CONFIG.C_PROBE4_WIDTH {3} \
    CONFIG.C_PROBE5_WIDTH {3} \
    CONFIG.C_PROBE6_WIDTH {9} \
    CONFIG.C_PROBE7_WIDTH {8} \
    CONFIG.C_PROBE8_WIDTH {32} \
    CONFIG.C_PROBE9_WIDTH {32} \
    CONFIG.C_PROBE10_WIDTH {6} \
    CONFIG.C_PROBE11_WIDTH {2} \
] [get_ips ila_0]

generate_target all [get_ips]
synth_ip [get_ips]

foreach file [glob [file join $root rtl * *.sv]] {
    if {[file tail $file] ne "bringup_top.sv"} {read_verilog -sv $file}
}
read_xdc [file join $root constraints arty_a7_100t.xdc]

# the ROM modules call $readmemh with relative file names, so synthesis must run from the mem folder
set start_dir [pwd]
cd $mem_dir
synth_design -top fpga_top -part $part -generic DEBUG=1
cd $start_dir

opt_design
place_design
route_design

report_timing_summary -file [file join $out timing.rpt]
report_utilization    -file [file join $out utilization.rpt]
report_utilization    -hierarchical -file [file join $out utilization_hierarchy.rpt]
write_debug_probes -force [file join $out fpga_top.ltx]

set worst_setup_slack [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
puts "worst setup slack: $worst_setup_slack ns (negative means the 100 MHz clock is not met)"
if {$worst_setup_slack < 0} {
    puts "WARNING: timing not met; no bitstream written. See $out/timing.rpt"
} else {
    write_bitstream -force [file join $out fpga_top.bit]
    puts "bitstream written to [file join $out fpga_top.bit]"
    puts "debug probes file written to [file join $out fpga_top.ltx]"
}
