# Pin constraints for bringup_top only (kept in a subfolder so create_project.tcl does not load it into the accelerator project).

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK100MHZ }]

set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports { reset_button }]

set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports { uart_txd_in }]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { uart_rxd_out }]

set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

# Pmod JB pins 1 to 4 (pin 5 is GND, pin 6 is 3.3 V); fast slew so the 50 MHz output stays square on a scope.
# Pin numbers are in the order of Digilent's Arty-A7-100-Master.xdc: JB pins 1,2,3,4 then 7,8,9,10.
set_property -dict { PACKAGE_PIN E15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12 } [get_ports { jb[0] }]
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12 } [get_ports { jb[1] }]
set_property -dict { PACKAGE_PIN D15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12 } [get_ports { jb[2] }]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12 } [get_ports { jb[3] }]

# Pmod JB pin 10: a copy of the 100 MHz clock from an ODDR output register
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12 } [get_ports { clock_forward }]

set_false_path -from [get_ports { reset_button uart_txd_in }]
set_false_path -to [get_ports { uart_rxd_out led[*] jb[*] clock_forward }]
