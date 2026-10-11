# Programs the Arty over the micro-USB (JTAG) cable.
# From a terminal:   vivado -mode batch -source C:/Users/techcolly/Desktop/fpga_LM/vivado/program_bitstream.tcl -tclargs C:/Users/techcolly/Desktop/fpga_LM/vivado/build_bringup/bringup_top.bit
# In the Vivado GUI Tcl console:  set bitfile C:/Users/techcolly/Desktop/fpga_LM/vivado/build_bringup/bringup_top.bit  then  source C:/Users/techcolly/Desktop/fpga_LM/vivado/program_bitstream.tcl

if {![info exists bitfile]} {
    if {$argc > 0} {
        set bitfile [lindex $argv 0]
    } else {
        error "no bitstream given: set bitfile or pass the .bit path with -tclargs"
    }
}

open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices xc7a100t*] 0]
current_hw_device $device
set_property PROGRAM.FILE $bitfile $device
set probes_file [file rootname $bitfile].ltx
if {[file exists $probes_file]} {
    set_property PROBES.FILE $probes_file $device
}
program_hw_devices $device
puts "programmed $device with $bitfile"
close_hw_manager
