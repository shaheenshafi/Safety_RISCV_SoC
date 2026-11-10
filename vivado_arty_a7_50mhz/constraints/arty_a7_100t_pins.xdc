## Digilent Arty A7-100T
## FPGA: xc7a100tcsg324-1
## Clock: Defined separately in clock_50mhz.xdc

## System clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }]

## Active-low CPU reset
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports { reset }]

## User LEDs
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## FPGA configuration bank voltage
## Verified against Digilent Arty A7-100T Rev E.2 schematic
## CFGBVS_0 is pulled up to VCC3V3 through R178.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
