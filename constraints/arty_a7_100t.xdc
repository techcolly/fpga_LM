# Arty A7-100T pin constraints for fpga_top. Pin numbers are from Digilent's Arty-A7-100-Master.xdc.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# 100 MHz clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK100MHZ }]

# reset: push button BTN0 (high while pressed)
set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports { reset_button }]

# on-board USB-UART (the micro-USB cable): uart_txd_in is the FPGA receive pin, uart_rxd_out is the FPGA transmit pin
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports { uart_txd_in }]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { uart_rxd_out }]

# LEDs LD4 to LD7: low 4 bits of the last predicted token
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

# asynchronous or slow human-facing pins are not timed against the clock
set_false_path -from [get_ports { reset_button uart_txd_in }]
set_false_path -to [get_ports { uart_rxd_out led[*] }]
